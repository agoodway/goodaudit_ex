defmodule GA.Accounts.DashboardQueriesTest do
  use GA.DataCase, async: true

  import GA.AccountsFixtures

  alias GA.Accounts

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "API Keys Test"})
    account_user = Accounts.get_account_user(user, account)
    %{account: account, user: user, account_user: account_user}
  end

  describe "count_active_api_keys/1" do
    test "counts only active, non-expired keys", %{account: account, account_user: account_user} do
      # Create 2 active keys
      {:ok, _} = Accounts.create_api_key(account_user, %{name: "Key 1", type: :public})
      {:ok, _} = Accounts.create_api_key(account_user, %{name: "Key 2", type: :private})

      # Create a revoked key
      {:ok, {revoked_key, _}} =
        Accounts.create_api_key(account_user, %{name: "Revoked", type: :public})

      Accounts.revoke_api_key(revoked_key)

      # Create an expired key
      {:ok, _} =
        Accounts.create_api_key(account_user, %{
          name: "Expired",
          type: :public,
          expires_at: DateTime.add(DateTime.utc_now(), -1, :day)
        })

      assert Accounts.count_active_api_keys(account.id) == 2
    end

    test "counts keys with nil expires_at as active", %{
      account: account,
      account_user: account_user
    } do
      {:ok, _} = Accounts.create_api_key(account_user, %{name: "No Expiry", type: :public})

      assert Accounts.count_active_api_keys(account.id) == 1
    end

    test "returns 0 when no keys exist", %{account: _account} do
      {:ok, empty_account} = Accounts.create_account(%{name: "No Keys Account"})
      assert Accounts.count_active_api_keys(empty_account.id) == 0
    end

    test "returns 0 for non-binary input" do
      assert Accounts.count_active_api_keys(nil) == 0
      assert Accounts.count_active_api_keys(123) == 0
    end

    test "is scoped to account", %{account: account, account_user: account_user} do
      user2 = user_fixture()
      {:ok, other_account} = Accounts.create_account(user2, %{name: "Other Account"})
      other_au = Accounts.get_account_user(user2, other_account)

      {:ok, _} = Accounts.create_api_key(account_user, %{name: "Key A", type: :public})
      {:ok, _} = Accounts.create_api_key(other_au, %{name: "Key B", type: :public})
      {:ok, _} = Accounts.create_api_key(other_au, %{name: "Key C", type: :public})

      assert Accounts.count_active_api_keys(account.id) == 1
      assert Accounts.count_active_api_keys(other_account.id) == 2
    end
  end
end
