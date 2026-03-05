defmodule GAWeb.Api.V1.CheckpointControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit

  describe "POST /api/v1/checkpoints" do
    test "returns 201 with checkpoint data when entries exist", %{conn: conn} do
      %{account: account, private_token: private_token} = account_api_context()

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "entry-1"}))

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/checkpoints", %{})
        |> json_response(201)

      data = response["data"]
      assert data["account_id"] == account.id
      assert data["sequence_number"] == 1
      assert is_binary(data["checksum"])
      assert data["signature"] == nil
      assert data["verified_at"] == nil
      assert data["signing_key_id"] == nil
    end

    test "returns 422 when account has no entries", %{conn: conn} do
      %{private_token: private_token} = account_api_context()

      response =
        conn
        |> api_key_conn(private_token)
        |> post("/api/v1/checkpoints", %{})
        |> json_response(422)

      assert response == %{
               "status" => 422,
               "message" => "No audit entries exist yet"
             }
    end

    test "returns 403 for public key", %{conn: conn} do
      %{public_token: public_token} = account_api_context()

      conn
      |> api_key_conn(public_token)
      |> post("/api/v1/checkpoints", %{})
      |> json_response(403)
    end
  end

  describe "GET /api/v1/checkpoints" do
    test "returns checkpoints for authenticated account only with public key", %{conn: conn} do
      user = user_fixture()
      %{account: account_a, public_token: public_token_a} = account_api_context(user)
      %{account: account_b} = account_api_context(user)

      assert {:ok, _} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "a-1"}))

      assert {:ok, _} = Audit.create_checkpoint(account_a.id)

      assert {:ok, _} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "a-2"}))

      assert {:ok, _} = Audit.create_checkpoint(account_a.id)

      assert {:ok, _} =
               Audit.create_log_entry(account_b.id, valid_audit_attrs(%{resource_id: "b-1"}))

      assert {:ok, _} = Audit.create_checkpoint(account_b.id)

      response =
        conn
        |> api_key_conn(public_token_a)
        |> get("/api/v1/checkpoints")
        |> json_response(200)

      assert length(response["data"]) == 2
      assert Enum.all?(response["data"], &(&1["account_id"] == account_a.id))
      assert Enum.map(response["data"], & &1["sequence_number"]) == [2, 1]
    end
  end

  describe "auth enforcement" do
    test "checkpoint endpoints return 401 without token", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/v1/checkpoints", %{})
      |> json_response(401)

      conn
      |> put_req_header("accept", "application/json")
      |> get("/api/v1/checkpoints")
      |> json_response(401)
    end
  end

  defp account_api_context(user \\ nil) do
    user = user || user_fixture()

    {:ok, account} =
      Accounts.create_account(%{
        name: "Checkpoint API Account #{System.unique_integer([:positive])}"
      })

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
      timestamp: ~U[2026-03-03 16:00:00Z],
      outcome: "success",
      extensions: %{},
      metadata: %{"source" => "checkpoint_controller_test"}
    }

    Map.merge(defaults, overrides)
  end
end
