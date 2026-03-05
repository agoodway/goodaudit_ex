defmodule GAWeb.Api.V1.AuditLogControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance

  describe "POST /api/v1/audit-logs" do
    test "returns 201 for valid payload with private key", %{conn: conn} do
      %{account: account, private_token: private_token} = account_api_context()

      assert {:ok, _association} = Compliance.activate_framework(account.id, "hipaa")

      payload =
        valid_audit_payload(%{
          "resource_id" => "patient-123"
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
      assert response["errors"]["user_id"] == ["can't be blank"]
    end

    test "returns framework-attributed 422 errors for missing framework-required fields", %{
      conn: conn
    } do
      %{account: account, private_token: private_token} = account_api_context()
      assert {:ok, _hipaa} = Compliance.activate_framework(account.id, "hipaa")
      assert {:ok, _soc2} = Compliance.activate_framework(account.id, "soc2")

      payload =
        valid_audit_payload()
        |> Map.delete("source_ip")

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/audit-logs", payload)
        |> json_response(422)

      assert "required by HIPAA" in response["errors"]["source_ip"]
      assert "required by SOC 2 Type II" in response["errors"]["source_ip"]
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

      in_window = ~U[2026-03-03 10:00:00Z]
      out_of_window = ~U[2026-03-01 10:00:00Z]

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
                   timestamp: in_window,
                   resource_id: "first-match"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
                   timestamp: in_window,
                   resource_id: "second-match"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: false,
                   timestamp: in_window,
                   resource_id: "wrong-phi"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   user_id: "user-2",
                   action: "read",
                   phi_accessed: true,
                   timestamp: in_window,
                   resource_id: "wrong-user"
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_audit_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
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
          "user_id" => "user-1",
          "action" => "read",
          "phi_accessed" => "true",
          "from" => DateTime.to_iso8601(~U[2026-03-03 00:00:00Z]),
          "to" => DateTime.to_iso8601(~U[2026-03-03 23:59:59Z])
        })
        |> json_response(200)

      assert response["meta"]["count"] == 1
      assert response["meta"]["next_cursor"] == 2
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
    test "includes frameworks field on audit responses and framework-attributed 422 docs", %{
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

      assert is_map(response_fields)
      assert is_map(list_fields)
      assert Map.has_key?(response_fields, "frameworks")
      assert Map.has_key?(list_fields, "frameworks")
      assert post_422_description =~ "required by HIPAA"
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
      user_id: Ecto.UUID.generate(),
      user_role: "admin",
      session_id: "session-#{System.unique_integer([:positive])}",
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-03 16:00:00Z],
      source_ip: "127.0.0.1",
      user_agent: "ExUnit",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: false,
      metadata: %{"source" => "audit_log_controller_test"}
    }

    Map.merge(defaults, overrides)
  end
end
