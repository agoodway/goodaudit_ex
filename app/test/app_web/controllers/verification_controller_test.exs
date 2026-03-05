defmodule GAWeb.Api.V1.VerificationControllerTest do
  use GAWeb.ConnCase, async: false

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit

  describe "POST /api/v1/verify" do
    test "returns verification report for valid chain with public key", %{conn: conn} do
      %{account: account, public_token: public_token} = account_api_context()

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "one"}))

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_audit_attrs(%{resource_id: "two"}))

      response =
        conn
        |> api_key_conn(public_token)
        |> post("/api/v1/verify", %{})
        |> json_response(200)

      assert response["valid"] == true
      assert response["total_entries"] == 2
      assert response["verified_entries"] == 2
      assert is_integer(response["duration_ms"])
      assert is_list(response["sequence_gaps"])
      assert is_list(response["checkpoint_results"])
    end

    test "verifies only the authenticated account scope", %{conn: conn} do
      user = user_fixture()
      %{account: account_a, public_token: public_token_a} = account_api_context(user)
      %{account: account_b} = account_api_context(user)

      assert {:ok, _} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "a-1"}))

      assert {:ok, _} =
               Audit.create_log_entry(account_a.id, valid_audit_attrs(%{resource_id: "a-2"}))

      assert {:ok, _} =
               Audit.create_log_entry(account_b.id, valid_audit_attrs(%{resource_id: "b-1"}))

      response =
        conn
        |> api_key_conn(public_token_a)
        |> post("/api/v1/verify", %{})
        |> json_response(200)

      assert response["valid"] == true
      assert response["total_entries"] == 2
      assert response["verified_entries"] == 2
    end

    test "returns 401 without token", %{conn: conn} do
      conn
      |> put_req_header("accept", "application/json")
      |> post("/api/v1/verify", %{})
      |> json_response(401)
    end
  end

  defp account_api_context(user \\ nil) do
    user = user || user_fixture()

    {:ok, account} =
      Accounts.create_account(%{name: "Verify API Account #{System.unique_integer([:positive])}"})

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
      metadata: %{"source" => "verification_controller_test"}
    }

    Map.merge(defaults, overrides)
  end
end
