defmodule GoodauditEx.IntegrationTest do
  use ExUnit.Case, async: true
  use Mimic

  alias GoodauditEx.Schemas

  setup :verify_on_exit!

  @client GoodauditEx.client(base_url: "http://localhost:4000", api_key: "sk_test_123")

  defp json_response(status, body) do
    {:ok, %Req.Response{status: status, body: body}}
  end

  # --- Audit Logs ---

  describe "list_audit_logs/2" do
    test "returns audit log list" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/audit-logs"
        assert opts[:headers] == [{"authorization", "Bearer sk_test_123"}]

        json_response(200, %{
          "data" => [
            %{
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
              "metadata" => %{},
              "inserted_at" => "2026-01-01T00:00:00Z",
              "updated_at" => "2026-01-01T00:00:00Z",
              "previous_checksum" => nil
            }
          ],
          "meta" => %{"next_cursor" => nil, "count" => 1}
        })
      end)

      assert {:ok, result} = GoodauditEx.list_audit_logs(@client)
      assert %Schemas.AuditLogListResponse{} = result
    end

    test "returns error on 401" do
      expect(Req, :request, fn _opts ->
        json_response(401, %{"status" => 401, "message" => "Unauthorized"})
      end)

      assert {:error, %{status: 401}} = GoodauditEx.list_audit_logs(@client)
    end
  end

  describe "create_audit_log/2" do
    test "creates an audit log entry" do
      params = %{
        actor_id: "user_1",
        action: "user.login",
        resource_type: "session",
        resource_id: "sess_1",
        outcome: "success"
      }

      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/audit-logs"
        assert opts[:json] == params

        json_response(201, %{
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
            "frameworks" => [],
            "metadata" => %{},
            "inserted_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-01-01T00:00:00Z",
            "previous_checksum" => nil
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.create_audit_log(@client, params)
      assert %Schemas.AuditLogResponse{} = result
    end

    test "returns validation error on 422" do
      expect(Req, :request, fn _opts ->
        json_response(422, %{
          "status" => 422,
          "message" => "Validation failed",
          "errors" => %{"action" => ["is required"]}
        })
      end)

      assert {:error, %{status: 422, body: body}} = GoodauditEx.create_audit_log(@client, %{})
      assert body["errors"]["action"] == ["is required"]
    end
  end

  describe "get_audit_log/2" do
    test "returns a single audit log entry" do
      id = "550e8400-e29b-41d4-a716-446655440000"

      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/audit-logs/#{id}"

        json_response(200, %{
          "data" => %{
            "id" => id,
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
            "frameworks" => [],
            "metadata" => %{},
            "inserted_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-01-01T00:00:00Z",
            "previous_checksum" => nil
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.get_audit_log(@client, id)
      assert %Schemas.AuditLogResponse{} = result
    end

    test "returns 404 for unknown ID" do
      expect(Req, :request, fn _opts ->
        json_response(404, %{"status" => 404, "message" => "Not found"})
      end)

      assert {:error, %{status: 404}} = GoodauditEx.get_audit_log(@client, "unknown")
    end
  end

  # --- Checkpoints ---

  describe "list_checkpoints/1" do
    test "returns checkpoint list" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/checkpoints"

        json_response(200, %{
          "data" => [
            %{
              "id" => "770e8400-e29b-41d4-a716-446655440000",
              "account_id" => "660e8400-e29b-41d4-a716-446655440000",
              "sequence_number" => 10,
              "checksum" => "chk_abc",
              "signature" => nil,
              "verified_at" => nil,
              "signing_key_id" => nil,
              "inserted_at" => "2026-01-01T00:00:00Z",
              "updated_at" => "2026-01-01T00:00:00Z"
            }
          ]
        })
      end)

      assert {:ok, result} = GoodauditEx.list_checkpoints(@client)
      assert %Schemas.CheckpointResponse{} = result
    end
  end

  describe "create_checkpoint/1" do
    test "creates a checkpoint" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/checkpoints"

        json_response(201, %{
          "data" => %{
            "id" => "770e8400-e29b-41d4-a716-446655440000",
            "account_id" => "660e8400-e29b-41d4-a716-446655440000",
            "sequence_number" => 10,
            "checksum" => "chk_abc",
            "signature" => nil,
            "verified_at" => nil,
            "signing_key_id" => nil,
            "inserted_at" => "2026-01-01T00:00:00Z",
            "updated_at" => "2026-01-01T00:00:00Z"
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.create_checkpoint(@client)
      assert %Schemas.CheckpointResponse{} = result
    end
  end

  # --- Verification ---

  describe "verify/1" do
    test "returns verification report" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/verify"

        json_response(200, %{
          "valid" => true,
          "total_entries" => 100,
          "verified_entries" => 100,
          "first_failure" => nil,
          "sequence_gaps" => [],
          "checkpoint_results" => [],
          "duration_ms" => 42
        })
      end)

      assert {:ok, result} = GoodauditEx.verify(@client)
      assert %Schemas.VerificationResponse{} = result
      assert result.valid == true
    end
  end

  # --- Taxonomies ---

  describe "list_taxonomies/1" do
    test "returns taxonomy list" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/taxonomies"

        json_response(200, %{
          "data" => [
            %{"framework" => "hipaa", "version" => "1.0.0"},
            %{"framework" => "soc2", "version" => "1.0.0"}
          ]
        })
      end)

      assert {:ok, result} = GoodauditEx.list_taxonomies(@client)
      assert %Schemas.TaxonomyListResponse{} = result
    end
  end

  describe "get_taxonomy/2" do
    test "returns taxonomy tree" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/taxonomies/hipaa"

        json_response(200, %{
          "data" => %{
            "framework" => "hipaa",
            "version" => "1.0.0",
            "taxonomy" => %{"access" => %{"read" => %{}, "write" => %{}}}
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.get_taxonomy(@client, "hipaa")
      assert %Schemas.TaxonomyShowResponse{} = result
    end
  end

  # --- Action Mappings ---

  describe "list_action_mappings/2" do
    test "returns action mapping list" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :get
        assert opts[:url] == "http://localhost:4000/api/v1/action-mappings"

        json_response(200, %{
          "data" => [
            %{
              "id" => "880e8400-e29b-41d4-a716-446655440000",
              "custom_action" => "user.login",
              "framework" => "hipaa",
              "taxonomy_path" => "access.authentication.login",
              "taxonomy_version" => "1.0.0",
              "created_at" => "2026-01-01T00:00:00Z"
            }
          ]
        })
      end)

      assert {:ok, result} = GoodauditEx.list_action_mappings(@client)
      assert %Schemas.ActionMappingListResponse{} = result
    end
  end

  describe "create_action_mapping/2" do
    test "creates an action mapping" do
      params = %{
        custom_action: "user.login",
        framework: "hipaa",
        taxonomy_path: "access.authentication.login"
      }

      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:json] == params

        json_response(201, %{
          "data" => %{
            "id" => "880e8400-e29b-41d4-a716-446655440000",
            "custom_action" => "user.login",
            "framework" => "hipaa",
            "taxonomy_path" => "access.authentication.login",
            "taxonomy_version" => "1.0.0",
            "created_at" => "2026-01-01T00:00:00Z"
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.create_action_mapping(@client, params)
      assert %Schemas.ActionMappingResponse{} = result
    end
  end

  describe "validate_action_mappings/2" do
    test "returns validation report" do
      expect(Req, :request, fn opts ->
        assert opts[:method] == :post
        assert opts[:url] == "http://localhost:4000/api/v1/action-mappings/validate"

        json_response(200, %{
          "data" => %{
            "recognized" => ["user.login"],
            "unmapped" => ["custom.action"]
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.validate_action_mappings(@client, %{framework: "hipaa"})
      assert %Schemas.ActionMappingValidateResponse{} = result
    end
  end

  describe "update_action_mapping/3" do
    test "updates an action mapping" do
      id = "880e8400-e29b-41d4-a716-446655440000"

      expect(Req, :request, fn opts ->
        assert opts[:method] == :put
        assert opts[:url] == "http://localhost:4000/api/v1/action-mappings/#{id}"
        assert opts[:json] == %{taxonomy_path: "access.authentication.logout"}

        json_response(200, %{
          "data" => %{
            "id" => id,
            "custom_action" => "user.login",
            "framework" => "hipaa",
            "taxonomy_path" => "access.authentication.logout",
            "taxonomy_version" => "1.0.0",
            "created_at" => "2026-01-01T00:00:00Z"
          }
        })
      end)

      assert {:ok, result} =
               GoodauditEx.update_action_mapping(@client, id, %{
                 taxonomy_path: "access.authentication.logout"
               })

      assert %Schemas.ActionMappingResponse{} = result
    end
  end

  describe "delete_action_mapping/2" do
    test "deletes an action mapping" do
      id = "880e8400-e29b-41d4-a716-446655440000"

      expect(Req, :request, fn opts ->
        assert opts[:method] == :delete
        assert opts[:url] == "http://localhost:4000/api/v1/action-mappings/#{id}"

        json_response(200, %{
          "data" => %{
            "id" => id,
            "custom_action" => "user.login",
            "framework" => "hipaa",
            "taxonomy_path" => "access.authentication.login",
            "taxonomy_version" => "1.0.0",
            "created_at" => "2026-01-01T00:00:00Z"
          }
        })
      end)

      assert {:ok, result} = GoodauditEx.delete_action_mapping(@client, id)
      assert %Schemas.ActionMappingResponse{} = result
    end
  end

  # --- Transport errors ---

  describe "transport errors" do
    test "returns error on connection failure" do
      expect(Req, :request, fn _opts ->
        {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:error, %Req.TransportError{reason: :econnrefused}} =
               GoodauditEx.list_audit_logs(@client)
    end

    test "returns error on timeout" do
      expect(Req, :request, fn _opts ->
        {:error, %Req.TransportError{reason: :timeout}}
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               GoodauditEx.verify(@client)
    end
  end

  # --- Client configuration ---

  describe "client configuration" do
    test "does not send auth header when api_key is nil" do
      client = GoodauditEx.client(base_url: "http://localhost:4000")

      expect(Req, :request, fn opts ->
        assert opts[:headers] == []
        json_response(200, %{"data" => []})
      end)

      assert {:ok, _} = GoodauditEx.list_taxonomies(client)
    end

    test "req_options are merged into requests" do
      client =
        GoodauditEx.client(
          base_url: "http://localhost:4000",
          api_key: "sk_test_123",
          req_options: [receive_timeout: 30_000]
        )

      expect(Req, :request, fn opts ->
        assert opts[:receive_timeout] == 30_000
        json_response(200, %{"data" => []})
      end)

      assert {:ok, _} = GoodauditEx.list_taxonomies(client)
    end
  end
end
