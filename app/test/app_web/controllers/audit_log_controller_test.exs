defmodule GAWeb.Api.V1.AuditLogControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance
  alias GA.Compliance.ActionMapping

  describe "POST /api/v1/audit-logs" do
    test "returns 201 for valid payload with private key", %{conn: conn} do
      %{account: account, private_token: private_token} = account_api_context()

      assert {:ok, _association} = Compliance.activate_framework(account.id, "hipaa")

      payload =
        valid_audit_payload(%{
          "resource_id" => "patient-123",
          "extensions" => %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}}
        })

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/audit-logs", payload)
        |> json_response(201)

      data = response["data"]
      assert data["account_id"] == account.id
      assert data["resource_id"] == "patient-123"
      assert data["sequence_number"] == 1
      assert is_binary(data["checksum"])
      assert String.length(data["checksum"]) == 64
      assert data["frameworks"] == ["hipaa"]
    end

    test "returns 422 for invalid payload", %{conn: conn} do
      %{private_token: private_token} = account_api_context()

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/audit-logs", %{"action" => "read"})
        |> json_response(422)

      assert is_map(response["errors"])
      assert response["errors"]["actor_id"] == ["can't be blank"]
    end

    test "returns framework-attributed 422 errors for missing framework-required fields", %{
      conn: conn
    } do
      %{account: account, private_token: private_token} = account_api_context()
      assert {:ok, _hipaa} = Compliance.activate_framework(account.id, "hipaa")
      assert {:ok, _soc2} = Compliance.activate_framework(account.id, "soc2")

      payload =
        valid_audit_payload()
        |> Map.put("extensions", %{"hipaa" => %{"phi_accessed" => true}})

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/audit-logs", payload)
        |> json_response(422)

      assert "hipaa.user_role is required" in response["errors"]["extensions"]
    end

    test "returns 401 without token", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/v1/audit-logs", %{})
      |> json_response(401)
    end

    test "returns 403 for read-only key", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      conn
      |> api_key_conn(public_token)
      |> post("/api/v1/audit-logs", valid_audit_payload())
      |> json_response(403)
    end
  end

  describe "GET /api/v1/audit-logs" do
    test "returns paginated list with meta using public key", %{conn: conn} do
      %{account: account, public_token: public_token} = account_api_context()

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "r-1"}))

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "r-2"}))

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "r-3"}))

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/audit-logs", %{"limit" => "2"})
        |> json_response(200)

      assert length(response["data"]) == 2
      assert response["meta"]["count"] == 2
      assert response["meta"]["next_cursor"] == 2
      assert Enum.all?(response["data"], &(&1["account_id"] == account.id))
      assert Enum.all?(response["data"], &is_list(&1["frameworks"]))
    end

    test "applies query filters with typed parameter parsing", %{conn: conn} do
      %{account: account, public_token: public_token} = account_api_context()
      assert {:ok, _association} = Compliance.activate_framework(account.id, "hipaa")

      in_window = ~U[2026-03-03 10:00:00Z]
      out_of_window = ~U[2026-03-01 10:00:00Z]

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   actor_id: "actor-1",
                   action: "read",
                   extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}},
                   timestamp: in_window,
                   resource_id: "first-match"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   actor_id: "actor-1",
                   action: "read",
                   extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}},
                   timestamp: in_window,
                   resource_id: "second-match"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   actor_id: "actor-1",
                   action: "read",
                   extensions: %{"hipaa" => %{"phi_accessed" => false, "user_role" => "admin"}},
                   timestamp: in_window,
                   resource_id: "wrong-phi"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   actor_id: "actor-2",
                   action: "read",
                   extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}},
                   timestamp: in_window,
                   resource_id: "wrong-user"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   actor_id: "actor-1",
                   action: "read",
                   extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}},
                   timestamp: out_of_window,
                   resource_id: "wrong-time"
                 })
               )

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/audit-logs", %{
          "after_sequence" => "1",
          "limit" => "1",
          "actor_id" => "actor-1",
          "action" => "read",
          "extensions" => Jason.encode!(%{"hipaa" => %{"phi_accessed" => true}}),
          "from" => DateTime.to_iso8601(~U[2026-03-03 00:00:00Z]),
          "to" => DateTime.to_iso8601(~U[2026-03-03 23:59:59Z])
        })
        |> json_response(200)

      assert response["meta"]["count"] == 1
      assert response["meta"]["next_cursor"] == nil
      assert Enum.map(response["data"], & &1["resource_id"]) == ["second-match"]
    end

    test "enforces account isolation for list responses", %{conn: conn} do
      user = user_fixture()
      %{account: account_a, public_token: public_token_a} = account_api_context(user)
      %{account: account_b} = account_api_context(user)

      assert {:ok, _} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "a-only"}))

      assert {:ok, _} =
               Audit.create_log_entry(account_b.id, valid_audit_attrs(%{resource_id: "b-only"}))

      response =
        conn
        |> api_key_conn(public_token_a)
        |> get("/api/v1/audit-logs")
        |> json_response(200)

      assert Enum.map(response["data"], & &1["resource_id"]) == ["a-only"]
      assert Enum.all?(response["data"], &(&1["account_id"] == account_a.id))
    end

    test "supports taxonomy category filtering with mapped actions", %{conn: conn} do
      %{account: account, public_token: public_token} = account_api_context()

      assert {:ok, _mapping} =
               ActionMapping.create_mapping(account.id, %{
                 custom_action: "patient_chart_viewed",
                 framework: "hipaa",
                 taxonomy_path: "access.phi.phi_read"
               })

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{action: "phi_read", resource_id: "canonical"})
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{action: "patient_chart_viewed", resource_id: "mapped"})
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{action: "treatment", resource_id: "other"})
               )

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/audit-logs", %{"category" => "hipaa:access.phi.*"})
        |> json_response(200)

      assert Enum.map(response["data"], & &1["resource_id"]) == ["canonical", "mapped"]
    end

    test "returns 422 for invalid category format", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/audit-logs", %{"category" => "badformat"})
        |> json_response(422)

      assert response["status"] == 422
      assert response["message"] == "Invalid category format. Expected 'framework:pattern'"
    end

    test "returns 422 for unknown framework in category", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      response =
        conn
        |> api_key_conn(public_token)
        |> get("/api/v1/audit-logs", %{"category" => "unknown:access.*"})
        |> json_response(422)

      assert response["status"] == 422
      assert response["message"] == "Unknown framework: unknown"
    end
  end

  describe "GET /api/v1/audit-logs/:id" do
    test "returns 200 for own entry and 404 for missing/cross-account", %{conn: conn} do
      user = user_fixture()
      %{account: account_a, public_token: public_token_a} = account_api_context(user)
      %{account: account_b} = account_api_context(user)

      assert {:ok, own_log} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "mine"}))

      assert {:ok, other_log} =
               Audit.create_log_entry(account_b.id, valid_audit_attrs(%{resource_id: "theirs"}))

      own_response =
        conn
        |> api_key_conn(public_token_a)
        |> get("/api/v1/audit-logs/#{own_log.id}")
        |> json_response(200)

      assert own_response["data"]["id"] == own_log.id
      assert own_response["data"]["resource_id"] == "mine"

      conn
      |> api_key_conn(public_token_a)
      |> get("/api/v1/audit-logs/#{Ecto.UUID.generate()}")
      |> json_response(404)

      conn
      |> api_key_conn(public_token_a)
      |> get("/api/v1/audit-logs/#{other_log.id}")
      |> json_response(404)
    end

    test "returns 404 for malformed id", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      conn
      |> api_key_conn(public_token)
      |> get("/api/v1/audit-logs/not-a-uuid")
      |> json_response(404)
    end
  end

  describe "auth enforcement" do
    test "all audit-log endpoints return 401 without a token", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/v1/audit-logs", valid_audit_payload())
      |> json_response(401)

      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/audit-logs")
      |> json_response(401)

      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/audit-logs/#{Ecto.UUID.generate()}")
      |> json_response(401)
    end
  end

  describe "GET /api/v1/openapi" do
    test "includes actor_id and extensions fields on audit responses and 422 docs", %{
      conn: conn
    } do
      spec =
        conn
        |> put_req_header("accept", "application/json")
        |> get("/api/v1/openapi")
        |> json_response(200)

      response_fields =
        get_in(spec, [
          "components",
          "schemas",
          "AuditLogResponse",
          "properties",
          "data",
          "properties"
        ])

      list_fields =
        get_in(spec, [
          "components",
          "schemas",
          "AuditLogListResponse",
          "properties",
          "data",
          "items",
          "properties"
        ])

      post_422_description =
        get_in(spec, ["paths", "/api/v1/audit-logs", "post", "responses", "422", "description"])

      category_param =
        spec
        |> get_in(["paths", "/api/v1/audit-logs", "get", "parameters"])
        |> Enum.find(&(&1["name"] == "category"))

      assert is_map(response_fields)
      assert is_map(list_fields)
      assert Map.has_key?(response_fields, "actor_id")
      assert Map.has_key?(response_fields, "extensions")
      assert Map.has_key?(list_fields, "actor_id")
      assert Map.has_key?(list_fields, "extensions")
      assert Map.has_key?(response_fields, "frameworks")
      assert Map.has_key?(list_fields, "frameworks")
      assert post_422_description =~ "hipaa.user_role is required"
      assert is_map(category_param)
      assert category_param["description"] =~ "framework:pattern"
    end
  end

  defp account_api_context(user \\ nil) do
    user = user || user_fixture()

    {:ok, account} =
      Accounts.create_account(%{name: "Audit API Account #{System.unique_integer([:positive])}"})

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

  defp valid_audit_payload(overrides \\ %{}) do
    valid_audit_attrs(overrides)
    |> Enum.into(%{}, fn {key, value} -> {to_string(key), value} end)
  end

  defp valid_audit_attrs(overrides) do
    defaults = %{
      actor_id: Ecto.UUID.generate(),
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-03 16:00:00Z],
      outcome: "success",
      extensions: %{},
      metadata: %{"source" => "audit_log_controller_test"}
    }

    Map.merge(defaults, overrides)
  end
end
