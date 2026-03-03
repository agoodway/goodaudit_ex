defmodule GA.Audit.CheckpointWorkerTest do
  use GA.DataCase, async: false

  import ExUnit.CaptureLog

  alias GA.Accounts
  alias GA.Audit
  alias GA.Audit.CheckpointWorker

  describe "checkpoint worker ticks" do
    test "creates checkpoints for all active accounts" do
      account_a = account_fixture()
      account_b = account_fixture()
      add_log(account_a.id, "active-a")
      add_log(account_b.id, "active-b")

      worker = start_worker()
      send(worker, :create_checkpoints)

      assert_eventually(fn ->
        length(Audit.list_checkpoints(account_a.id)) == 1 and
          length(Audit.list_checkpoints(account_b.id)) == 1
      end)
    end

    test "skips suspended accounts" do
      active_account = account_fixture()
      suspended_account = account_fixture(%{status: :suspended})
      add_log(active_account.id, "active")
      add_log(suspended_account.id, "suspended")

      worker = start_worker()
      send(worker, :create_checkpoints)

      assert_eventually(fn ->
        length(Audit.list_checkpoints(active_account.id)) == 1
      end)

      assert Audit.list_checkpoints(suspended_account.id) == []
    end

    test "logs no-entry accounts and continues processing" do
      empty_account = account_fixture()
      populated_account = account_fixture()
      add_log(populated_account.id, "populated")

      worker = start_worker()

      log =
        capture_log([level: :debug], fn ->
          send(worker, :create_checkpoints)

          assert_eventually(fn ->
            length(Audit.list_checkpoints(populated_account.id)) == 1
          end)
        end)

      assert log =~ "checkpoint_worker skipping"
      assert log =~ empty_account.id
      assert Audit.list_checkpoints(empty_account.id) == []
    end
  end

  defp start_worker do
    start_supervised!(
      {CheckpointWorker,
       [
         name: {:global, {:checkpoint_worker_test, System.unique_integer([:positive])}},
         interval_ms: 60_000
       ]}
    )
  end

  defp account_fixture(attrs \\ %{}) do
    defaults = %{name: "Worker Account #{System.unique_integer([:positive])}"}
    {:ok, account} = Accounts.create_account(Map.merge(defaults, attrs))
    account
  end

  defp add_log(account_id, resource_id) do
    attrs = %{
      user_id: Ecto.UUID.generate(),
      user_role: "admin",
      session_id: "session-#{System.unique_integer([:positive])}",
      action: "read",
      resource_type: "patient",
      resource_id: resource_id,
      timestamp: ~U[2026-03-03 16:30:00Z],
      source_ip: "127.0.0.1",
      user_agent: "ExUnit",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: false,
      metadata: %{"source" => "checkpoint_worker_test"}
    }

    assert {:ok, _} = Audit.create_log_entry(account_id, attrs)
  end

  defp assert_eventually(fun, attempts \\ 50)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(20)
      assert_eventually(fun, attempts - 1)
    end
  end
end
