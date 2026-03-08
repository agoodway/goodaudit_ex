defmodule GA.Compliance.DashboardQueriesTest do
  use GA.DataCase, async: true

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Compliance

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Frameworks Test"})
    %{account: account}
  end

  describe "count_active_frameworks/1" do
    test "counts active frameworks for the account", %{account: account} do
      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")
      {:ok, _} = Compliance.activate_framework(account.id, "soc2")

      assert Compliance.count_active_frameworks(account.id) == 2
    end

    test "returns 0 when no frameworks are active", %{account: account} do
      assert Compliance.count_active_frameworks(account.id) == 0
    end

    test "is scoped to account", %{account: account} do
      user2 = user_fixture()
      {:ok, other_account} = Accounts.create_account(user2, %{name: "Other Account"})

      {:ok, _} = Compliance.activate_framework(account.id, "hipaa")
      {:ok, _} = Compliance.activate_framework(other_account.id, "soc2")
      {:ok, _} = Compliance.activate_framework(other_account.id, "gdpr")

      assert Compliance.count_active_frameworks(account.id) == 1
      assert Compliance.count_active_frameworks(other_account.id) == 2
    end
  end
end
