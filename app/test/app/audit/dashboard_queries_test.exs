defmodule GA.Audit.DashboardQueriesTest do
  use GA.DataCase, async: true

  import GA.AccountsFixtures

  alias GA.Accounts
  alias GA.Audit
  alias GA.Compliance

  setup do
    user = user_fixture()
    {:ok, account} = Accounts.create_account(user, %{name: "Dashboard Queries Test"})
    {:ok, _} = Compliance.activate_framework(account.id, "hipaa")
    %{account: account, user: user}
  end

  defp create_log(account_id, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          actor_id: Ecto.UUID.generate(),
          action: "read",
          resource_type: "patient",
          resource_id: Ecto.UUID.generate(),
          timestamp: DateTime.utc_now(),
          outcome: "success",
          extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}}
        },
        overrides
      )

    {:ok, log} = Audit.create_log_entry(account_id, attrs)
    log
  end

  describe "count_logs/2" do
    test "returns count of logs within the default 30-day window", %{account: account} do
      create_log(account.id)
      create_log(account.id)
      create_log(account.id)

      assert Audit.count_logs(account.id) == 3
    end

    test "respects custom since parameter", %{account: account} do
      create_log(account.id)

      # Count only logs since far in the future — should be 0
      future = DateTime.add(DateTime.utc_now(), 1, :day)
      assert Audit.count_logs(account.id, since: future) == 0
    end

    test "since parameter includes logs at the boundary timestamp", %{account: account} do
      boundary = DateTime.utc_now() |> DateTime.add(-10, :second)

      # Log before boundary
      create_log(account.id, %{timestamp: DateTime.add(boundary, -1, :second)})
      # Log at boundary
      create_log(account.id, %{timestamp: boundary})
      # Log after boundary
      create_log(account.id, %{timestamp: DateTime.add(boundary, 1, :second)})

      # Should include the boundary log and the one after it
      assert Audit.count_logs(account.id, since: boundary) == 2
    end

    test "returns 0 for an account with no logs", %{account: _account} do
      {:ok, empty_account} = Accounts.create_account(%{name: "Empty Account"})
      assert Audit.count_logs(empty_account.id) == 0
    end

    test "is scoped to account", %{account: account} do
      user2 = user_fixture()
      {:ok, other_account} = Accounts.create_account(user2, %{name: "Other Account"})
      {:ok, _} = Compliance.activate_framework(other_account.id, "hipaa")

      create_log(account.id)
      create_log(other_account.id)
      create_log(other_account.id)

      assert Audit.count_logs(account.id) == 1
      assert Audit.count_logs(other_account.id) == 2
    end
  end

  describe "recent_logs/2" do
    test "returns entries in descending order by inserted_at", %{account: account} do
      log1 = create_log(account.id)
      _log2 = create_log(account.id)
      log3 = create_log(account.id)

      recent = Audit.recent_logs(account.id)
      ids = Enum.map(recent, & &1.id)

      # Most recent should be first
      assert List.last(ids) == log1.id
      assert List.first(ids) == log3.id
    end

    test "respects the limit parameter", %{account: account} do
      for _ <- 1..5, do: create_log(account.id)

      assert length(Audit.recent_logs(account.id, 3)) == 3
    end

    test "returns fewer entries than limit when not enough exist", %{account: account} do
      create_log(account.id)
      create_log(account.id)

      assert length(Audit.recent_logs(account.id)) == 2
    end

    test "returns empty list for account with no logs", %{account: _account} do
      {:ok, empty_account} = Accounts.create_account(%{name: "Empty Account"})
      assert Audit.recent_logs(empty_account.id) == []
    end

    test "is scoped to account", %{account: account} do
      user2 = user_fixture()
      {:ok, other_account} = Accounts.create_account(user2, %{name: "Other Account"})
      {:ok, _} = Compliance.activate_framework(other_account.id, "hipaa")

      create_log(account.id)
      create_log(other_account.id)

      recent = Audit.recent_logs(account.id)
      assert length(recent) == 1
      assert hd(recent).account_id == account.id
    end
  end
end
