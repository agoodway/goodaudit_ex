defmodule GAWeb.Api.V1.ActionMappingControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit

  describe "action mapping CRUD + validation endpoints" do
    test "supports create/list/update/delete and dry-run validate", %{conn: conn} do
      %{account: account, public_token: public_token, private_token: private_token} = account_api_context()

      create_response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/action-mappings", %{
          "custom_action" => "patient_chart_viewed",
          "framework" => "hipaa",
          "taxonomy_path" => "access.phi.phi_read"
        })
        |> json_response(201)

      mapping_id = create_response["data"]["id"]
      assert create_response["data"]["framework"] == "hipaa"
      assert create_response["data"]["taxonomy_version"] == "1.0.0"

      list_response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/action-mappings")
        |> json_response(200)

      assert Enum.map(list_response["data"], & &1["id"]) == [mapping_id]

      update_response =
        conn
        |> api_key_conn(private_token)
        |> put("/api/v1/action-mappings/#{mapping_id}", %{
          "taxonomy_path" => "access.phi.phi_write"
        })
        |> json_response(200)

      assert update_response["data"]["taxonomy_path"] == "access.phi.phi_write"

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{action: "patient_chart_viewed"}))

      assert {:ok, _} = Audit.create_log_entry(account.id, valid_audit_attrs(%{action: "custom_event"}))

      validate_response =
        conn
        |> api_key_conn(public_token)
        |> post("/api/v1/action-mappings/validate", %{"framework" => "hipaa"})
        |> json_response(200)

      assert "patient_chart_viewed" in validate_response["data"]["recognized"]
      assert "custom_event" in validate_response["data"]["unmapped"]

      delete_response =
        conn
        |> api_key_conn(private_token)
        |> delete("/api/v1/action-mappings/#{mapping_id}")
        |> json_response(200)

      assert delete_response["data"]["id"] == mapping_id
    end

    test "enforces auth scopes and validation errors", %{conn: conn} do
      %{public_token: public_token, private_token: private_token} = account_api_context()

      conn
      |> api_key_conn(public_token)
      |> post("/api/v1/action-mappings", %{
        "custom_action" => "foo",
        "framework" => "hipaa",
        "taxonomy_path" => "access.phi.phi_read"
      })
      |> json_response(403)

      invalid_framework_response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/action-mappings", %{
          "custom_action" => "foo",
          "framework" => "unknown",
          "taxonomy_path" => "access.phi.phi_read"
        })
        |> json_response(422)

      assert invalid_framework_response["errors"]["framework"] == ["is invalid"]

      unknown_framework_response =
        conn
        |> api_key_conn(public_token)
        |> post("/api/v1/action-mappings/validate", %{"framework" => "unknown"})
        |> json_response(422)

      assert unknown_framework_response["status"] == 422
      assert unknown_framework_response["message"] == "Unknown framework: unknown"
    end
  end

  describe "GET /api/v1/openapi" do
    test "includes taxonomy and action mapping schemas and paths", %{conn: conn} do
      spec =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/openapi")
        |> json_response(200)

      schemas = get_in(spec, ["components", "schemas"])

      assert Map.has_key?(schemas, "TaxonomyListResponse")
      assert Map.has_key?(schemas, "TaxonomyShowResponse")
      assert Map.has_key?(schemas, "ActionMappingRequest")
      assert Map.has_key?(schemas, "ActionMappingResponse")
      assert Map.has_key?(schemas, "ActionMappingListResponse")
      assert Map.has_key?(schemas, "ActionMappingValidateResponse")

      assert get_in(spec, ["paths", "/api/v1/taxonomies", "get"]) != nil
      assert get_in(spec, ["paths", "/api/v1/taxonomies/{framework}", "get"]) != nil
      assert get_in(spec, ["paths", "/api/v1/action-mappings", "get"]) != nil
      assert get_in(spec, ["paths", "/api/v1/action-mappings", "post"]) != nil
      assert get_in(spec, ["paths", "/api/v1/action-mappings/{id}", "put"]) != nil
      assert get_in(spec, ["paths", "/api/v1/action-mappings/{id}", "delete"]) != nil
      assert get_in(spec, ["paths", "/api/v1/action-mappings/validate", "post"]) != nil
    end
  end

  defp account_api_context(user \\ nil) do
    user = user || user_fixture()

    {:ok, account} =
      Accounts.create_account(%{name: "Action Mapping API Account #{System.unique_integer([:positive])}"})

    {:ok, account_user} = Accounts.add_user_to_account(account, user, :owner)

    {:ok, {_public_key, public_token}} =
      Accounts.create_api_key(account_user, %{name: "Public Key", type: :public})

    {:ok, {_private_key, private_token}} =
      Accounts.create_api_key(account_user, %{name: "Private Key", type: :private})

    %{
      account: account,
      user: user,
      public_token: public_token,
      private_token: private_token
    }
  end

  defp api_key_conn(conn, token) do
    conn
    |> put_req_header("accept", "application/json")
    |> put_req_header("content-type", "application/json")
    |> put_req_header("authorization", "Bearer #{token}")
  end

  defp valid_audit_attrs(overrides \\ %{}) do
    defaults = %{
      actor_id: Ecto.UUID.generate(),
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-05 13:00:00Z],
      outcome: "success",
      extensions: %{},
      metadata: %{"source" => "action_mapping_controller_test"}
    }

    Map.merge(defaults, overrides)
  end
end
