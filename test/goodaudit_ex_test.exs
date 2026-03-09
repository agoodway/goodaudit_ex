defmodule GoodauditExTest do
  use ExUnit.Case

  alias GoodauditEx.Client
  alias GoodauditEx.Schemas

  describe "client/1" do
    test "creates client with defaults" do
      client = GoodauditEx.client()
      assert %Client{base_url: "http://localhost:4000", api_key: nil} = client
    end

    test "creates client with explicit options" do
      client = GoodauditEx.client(base_url: "https://api.goodaudit.io", api_key: "sk_test")
      assert client.base_url == "https://api.goodaudit.io"
      assert client.api_key == "sk_test"
    end

    test "creates client with req_options" do
      client = GoodauditEx.client(req_options: [receive_timeout: 30_000])
      assert client.req_options == [receive_timeout: 30_000]
    end
  end

  describe "AuditLogResponse schema" do
    test "from_map/1 converts a map to struct" do
      map = %{
        "data" => %{
          "id" => "550e8400-e29b-41d4-a716-446655440000",
          "account_id" => "660e8400-e29b-41d4-a716-446655440000",
          "sequence_number" => 1,
          "checksum" => "abc123",
          "actor_id" => "user_1",
          "action" => "user.login",
          "resource_type" => "session",
          "resource_id" => "sess_1",
          "timestamp" => "2026-01-01T00:00:00Z",
          "outcome" => "success",
          "extensions" => %{},
          "frameworks" => ["hipaa"],
          "metadata" => %{"ip" => "127.0.0.1"},
          "inserted_at" => "2026-01-01T00:00:00Z",
          "updated_at" => "2026-01-01T00:00:00Z"
        }
      }

      result = Schemas.AuditLogResponse.from_map(map)
      assert %Schemas.AuditLogResponse{data: data} = result
      assert is_map(data)
      assert data["action"] == "user.login"
    end

    test "from_map/1 handles nil" do
      assert nil == Schemas.AuditLogResponse.from_map(nil)
    end
  end

  describe "VerificationResponse schema" do
    test "from_map/1 converts verification result" do
      map = %{
        "valid" => true,
        "total_entries" => 100,
        "verified_entries" => 100,
        "first_failure" => nil,
        "sequence_gaps" => [],
        "checkpoint_results" => [],
        "duration_ms" => 42
      }

      result = Schemas.VerificationResponse.from_map(map)
      assert %Schemas.VerificationResponse{} = result
      assert result.valid == true
      assert result.total_entries == 100
      assert result.duration_ms == 42
    end
  end

  describe "ErrorResponse schema" do
    test "from_map/1 converts error" do
      map = %{
        "status" => 422,
        "message" => "Validation failed",
        "errors" => %{"action" => ["is required"]}
      }

      result = Schemas.ErrorResponse.from_map(map)
      assert %Schemas.ErrorResponse{} = result
      assert result.status == 422
      assert result.message == "Validation failed"
    end

    test "ignores unknown fields" do
      map = %{"status" => 400, "message" => "Bad request", "unknown_field" => "ignored"}
      result = Schemas.ErrorResponse.from_map(map)
      assert result.status == 400
      assert result.message == "Bad request"
    end
  end

  describe "generated API functions" do
    test "all expected functions are exported" do
      Code.ensure_loaded!(GoodauditEx)

      assert function_exported?(GoodauditEx, :list_audit_logs, 1)
      assert function_exported?(GoodauditEx, :list_audit_logs, 2)
      assert function_exported?(GoodauditEx, :create_audit_log, 2)
      assert function_exported?(GoodauditEx, :get_audit_log, 2)
      assert function_exported?(GoodauditEx, :list_checkpoints, 1)
      assert function_exported?(GoodauditEx, :create_checkpoint, 1)
      assert function_exported?(GoodauditEx, :verify, 1)
      assert function_exported?(GoodauditEx, :list_taxonomies, 1)
      assert function_exported?(GoodauditEx, :get_taxonomy, 2)
      assert function_exported?(GoodauditEx, :list_action_mappings, 1)
      assert function_exported?(GoodauditEx, :list_action_mappings, 2)
      assert function_exported?(GoodauditEx, :create_action_mapping, 2)
      assert function_exported?(GoodauditEx, :validate_action_mappings, 2)
      assert function_exported?(GoodauditEx, :update_action_mapping, 3)
      assert function_exported?(GoodauditEx, :delete_action_mapping, 2)
    end
  end
end
