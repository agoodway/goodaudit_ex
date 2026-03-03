defmodule GA.Audit.ContextTest do
  use GA.DataCase, async: false

  import Ecto.Query

  alias GA.Accounts
  alias GA.Audit
  alias GA.Audit.{Chain, Checkpoint, Log}
  alias GA.Repo

  describe "create_log_entry/2" do
    test "creates genesis entry with sequence 1 and nil previous_checksum" do
      account = account_fixture()

      assert {:ok, log} = Audit.create_log_entry(account.id, valid_attrs())
      assert log.account_id == account.id
      assert log.sequence_number == 1
      assert is_nil(log.previous_checksum)

      assert {:ok, hmac_key} = Accounts.get_hmac_key(account.id)
      assert Chain.verify_checksum(hmac_key, log, nil)
    end

    test "creates chained entries with per-account sequencing" do
      account = account_fixture()

      assert {:ok, first} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "r-1"}))
      assert {:ok, second} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "r-2"}))

      assert second.sequence_number == first.sequence_number + 1
      assert second.previous_checksum == first.checksum

      assert {:ok, hmac_key} = Accounts.get_hmac_key(account.id)
      assert Chain.verify_checksum(hmac_key, second, first.checksum)
    end

    test "ignores caller-provided chain fields before checksum generation" do
      account = account_fixture()

      poisoned_attrs =
        valid_attrs(%{resource_id: "reserved-keys"})
        |> Map.merge(%{
          account_id: Ecto.UUID.generate(),
          sequence_number: 999,
          previous_checksum: String.duplicate("a", 64),
          checksum: String.duplicate("f", 64),
          "account_id" => Ecto.UUID.generate(),
          "sequence_number" => 555,
          "previous_checksum" => String.duplicate("b", 64),
          "checksum" => String.duplicate("e", 64)
        })

      assert {:ok, first} = Audit.create_log_entry(account.id, poisoned_attrs)
      assert {:ok, _second} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "follow-up"}))

      assert first.account_id == account.id
      assert first.sequence_number == 1
      assert is_nil(first.previous_checksum)
      refute first.checksum == String.duplicate("f", 64)
      refute first.checksum == String.duplicate("e", 64)

      report = Audit.verify_chain(account.id)
      assert report.valid == true
      assert report.first_failure == nil
    end

    test "defaults timestamp when missing" do
      account = account_fixture()
      attrs = valid_attrs() |> Map.delete(:timestamp)
      before = DateTime.utc_now()

      assert {:ok, log} = Audit.create_log_entry(account.id, attrs)

      after_time = DateTime.utc_now()
      assert DateTime.compare(log.timestamp, before) in [:eq, :gt]
      assert DateTime.compare(log.timestamp, after_time) in [:eq, :lt]
    end

    test "returns error changeset on validation failure and does not insert" do
      account = account_fixture()

      assert {:error, changeset} = Audit.create_log_entry(account.id, %{action: "read"})
      assert "can't be blank" in errors_on(changeset).user_id

      count =
        from(log in Log, where: log.account_id == ^account.id)
        |> Repo.aggregate(:count, :id)

      assert count == 0
    end

    test "returns structured error when checksum payload contains delimiter characters" do
      account = account_fixture()
      attrs = valid_attrs(%{resource_id: "patient|123"})

      assert {:error, changeset} = Audit.create_log_entry(account.id, attrs)

      assert {"invalid checksum payload: canonical payload fields must not contain the pipe delimiter",
              []} in Keyword.get_values(changeset.errors, :base)

      assert {:ok, log} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "patient-123"}))
      assert log.sequence_number == 1
    end

    test "does not consume sequence numbers when a write rolls back" do
      account = account_fixture()

      assert {:ok, first} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "seq-1"}))
      assert {:error, _changeset} = Audit.create_log_entry(account.id, %{action: "read"})
      assert {:ok, second} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "seq-2"}))

      assert second.sequence_number == first.sequence_number + 1
      assert sequence_numbers_for(account.id) == [1, 2]
    end

    test "concurrent writers in same account produce gap-free sequence numbers" do
      account = account_fixture()

      results =
        1..20
        |> Task.async_stream(
          fn index ->
            attrs =
              valid_attrs(%{
                session_id: "session-#{index}",
                resource_id: "resource-#{index}"
              })

            Audit.create_log_entry(account.id, attrs)
          end,
          max_concurrency: 20,
          timeout: 30_000,
          ordered: false
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, %Log{}}, &1))

      sequence_numbers =
        from(log in Log,
          where: log.account_id == ^account.id,
          order_by: [asc: log.sequence_number],
          select: log.sequence_number
        )
        |> Repo.all()

      assert sequence_numbers == Enum.to_list(1..20)
    end

    test "concurrent writers across accounts are independently sequenced" do
      account_a = account_fixture()
      account_b = account_fixture()

      writes =
        for index <- 1..10, account_id <- [account_a.id, account_b.id] do
          {account_id, index}
        end

      results =
        writes
        |> Task.async_stream(
          fn {account_id, index} ->
            attrs =
              valid_attrs(%{
                session_id: "session-#{account_id}-#{index}",
                resource_id: "resource-#{account_id}-#{index}"
              })

            Audit.create_log_entry(account_id, attrs)
          end,
          max_concurrency: 20,
          timeout: 30_000,
          ordered: false
        )
        |> Enum.map(fn {:ok, result} -> result end)

      assert Enum.all?(results, &match?({:ok, %Log{}}, &1))

      assert sequence_numbers_for(account_a.id) == Enum.to_list(1..10)
      assert sequence_numbers_for(account_b.id) == Enum.to_list(1..10)
    end
  end

  describe "list_logs/2" do
    test "enforces account isolation" do
      account_a = account_fixture()
      account_b = account_fixture()

      assert {:ok, _} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a-1"}))
      assert {:ok, _} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a-2"}))
      assert {:ok, _} = Audit.create_log_entry(account_b.id, valid_attrs(%{resource_id: "b-1"}))

      {entries, next_cursor} = Audit.list_logs(account_a.id)

      assert next_cursor == nil
      assert length(entries) == 2
      assert Enum.all?(entries, &(&1.account_id == account_a.id))
    end

    test "supports cursor pagination across multiple pages" do
      account = account_fixture()

      for index <- 1..5 do
        assert {:ok, _} =
                 Audit.create_log_entry(
                   account.id,
                   valid_attrs(%{
                     resource_id: "resource-#{index}",
                     session_id: "session-#{index}"
                   })
                 )
      end

      {page_1, cursor_1} = Audit.list_logs(account.id, limit: 2)
      assert Enum.map(page_1, & &1.sequence_number) == [1, 2]
      assert cursor_1 == 2

      {page_2, cursor_2} = Audit.list_logs(account.id, after_sequence: cursor_1, limit: 2)
      assert Enum.map(page_2, & &1.sequence_number) == [3, 4]
      assert cursor_2 == 4

      {page_3, cursor_3} = Audit.list_logs(account.id, after_sequence: cursor_2, limit: 2)
      assert Enum.map(page_3, & &1.sequence_number) == [5]
      assert cursor_3 == nil
    end

    test "clamps limits greater than 1000 to 1000" do
      account = account_fixture()
      insert_bulk_logs(account.id, 1005)

      {entries, next_cursor} = Audit.list_logs(account.id, limit: 5000)

      assert length(entries) == 1000
      assert List.first(entries).sequence_number == 1
      assert List.last(entries).sequence_number == 1000
      assert next_cursor == 1000
    end

    test "normalizes non-positive and invalid limits" do
      account = account_fixture()
      insert_bulk_logs(account.id, 3)

      {zero_entries, zero_cursor} = Audit.list_logs(account.id, limit: 0)
      assert Enum.map(zero_entries, & &1.sequence_number) == [1]
      assert zero_cursor == 1

      {negative_entries, negative_cursor} = Audit.list_logs(account.id, limit: -10)
      assert Enum.map(negative_entries, & &1.sequence_number) == [1]
      assert negative_cursor == 1

      {invalid_entries, invalid_cursor} = Audit.list_logs(account.id, limit: "invalid")
      assert Enum.map(invalid_entries, & &1.sequence_number) == [1, 2, 3]
      assert invalid_cursor == nil
    end

    test "supports field filters and combined date-range filters within account scope" do
      account = account_fixture()
      other_account = account_fixture()

      in_window = ~U[2026-01-20 11:30:00Z]
      before_window = ~U[2025-12-30 10:00:00Z]

      assert {:ok, target} =
               Audit.create_log_entry(
                 account.id,
                 valid_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
                   resource_id: "target",
                   timestamp: in_window
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_attrs(%{
                   user_id: "user-2",
                   action: "read",
                   phi_accessed: true,
                   resource_id: "wrong-user",
                   timestamp: in_window
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_attrs(%{
                   user_id: "user-1",
                   action: "update",
                   phi_accessed: true,
                   resource_id: "wrong-action",
                   timestamp: in_window
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 account.id,
                 valid_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
                   resource_id: "wrong-time",
                   timestamp: before_window
                 })
               )

      assert {:ok, _} =
               Audit.create_log_entry(
                 other_account.id,
                 valid_attrs(%{
                   user_id: "user-1",
                   action: "read",
                   phi_accessed: true,
                   resource_id: "other-account",
                   timestamp: in_window
                 })
               )

      {single_filter_entries, _} = Audit.list_logs(account.id, user_id: "user-1")
      assert Enum.all?(single_filter_entries, &(&1.user_id == "user-1"))

      {filtered_entries, _} =
        Audit.list_logs(
          account.id,
          user_id: "user-1",
          action: "read",
          phi_accessed: true,
          from: ~U[2026-01-01 00:00:00Z],
          to: ~U[2026-01-31 23:59:59Z]
        )

      assert Enum.map(filtered_entries, & &1.id) == [target.id]
    end
  end

  describe "get_log/2" do
    test "returns in-account entry and not_found for missing or cross-account id" do
      account_a = account_fixture()
      account_b = account_fixture()

      assert {:ok, log_a} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a"}))
      assert {:ok, log_b} = Audit.create_log_entry(account_b.id, valid_attrs(%{resource_id: "b"}))

      assert {:ok, fetched} = Audit.get_log(account_a.id, log_a.id)
      assert fetched.id == log_a.id

      assert {:error, :not_found} = Audit.get_log(account_a.id, Ecto.UUID.generate())
      assert {:error, :not_found} = Audit.get_log(account_a.id, log_b.id)
    end
  end

  describe "checkpoints" do
    test "create_checkpoint/1 creates checkpoint at account chain head" do
      account = account_fixture()
      assert {:ok, _} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "first"}))
      assert {:ok, head} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "second"}))

      assert {:ok, checkpoint} = Audit.create_checkpoint(account.id)
      assert checkpoint.account_id == account.id
      assert checkpoint.sequence_number == head.sequence_number
      assert checkpoint.checksum == head.checksum
      assert checkpoint.verified_at == nil
    end

    test "create_checkpoint/1 returns :no_entries for empty account" do
      account = account_fixture()
      assert {:error, :no_entries} = Audit.create_checkpoint(account.id)
    end

    test "list_checkpoints/1 is account-scoped and ordered descending" do
      account_a = account_fixture()
      account_b = account_fixture()

      assert {:ok, _} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a-1"}))
      assert {:ok, checkpoint_1} = Audit.create_checkpoint(account_a.id)

      assert {:ok, _} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a-2"}))
      assert {:ok, checkpoint_2} = Audit.create_checkpoint(account_a.id)

      assert {:ok, _} = Audit.create_log_entry(account_b.id, valid_attrs(%{resource_id: "b-1"}))
      assert {:ok, _} = Audit.create_checkpoint(account_b.id)

      checkpoints = Audit.list_checkpoints(account_a.id)

      assert Enum.map(checkpoints, & &1.id) == [checkpoint_2.id, checkpoint_1.id]
      assert Enum.map(checkpoints, & &1.sequence_number) == [2, 1]
      assert Enum.all?(checkpoints, &(&1.account_id == account_a.id))
    end

    test "create_checkpoint/1 serializes with concurrent writers and captures committed head" do
      account = account_fixture()
      parent = self()

      assert {:ok, _} = Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "seed"}))

      locker_task =
        Task.async(fn ->
          Repo.transaction(fn ->
            {key_a, key_b} = account_lock_keys(account.id)
            {:ok, _} = Repo.query("SELECT pg_advisory_xact_lock($1, $2)", [key_a, key_b])
            send(parent, :locker_ready)

            receive do
              :release_locker -> :ok
            after
              5_000 -> raise "timed out waiting to release advisory lock"
            end
          end)
        end)

      assert_receive :locker_ready, 5_000

      writer_task =
        Task.async(fn ->
          Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "during-checkpoint"}))
        end)

      assert Task.yield(writer_task, 100) == nil

      checkpoint_task =
        Task.async(fn ->
          Audit.create_checkpoint(account.id)
        end)

      assert Task.yield(checkpoint_task, 100) == nil

      send(locker_task.pid, :release_locker)
      assert {:ok, :ok} = Task.await(locker_task, 5_000)

      assert {:ok, %Log{} = latest_log} = Task.await(writer_task, 5_000)
      assert {:ok, %Checkpoint{} = checkpoint} = Task.await(checkpoint_task, 5_000)

      assert checkpoint.sequence_number == latest_log.sequence_number
      assert checkpoint.checksum == latest_log.checksum
      assert checkpoint.sequence_number == latest_sequence_number(account.id)
    end
  end

  defp account_fixture do
    {:ok, account} =
      Accounts.create_account(%{name: "Audit Account #{System.unique_integer([:positive])}"})

    account
  end

  defp valid_attrs(overrides \\ %{}) do
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
      metadata: %{"source" => "context_test"}
    }

    Map.merge(defaults, overrides)
  end

  defp sequence_numbers_for(account_id) do
    from(log in Log,
      where: log.account_id == ^account_id,
      order_by: [asc: log.sequence_number],
      select: log.sequence_number
    )
    |> Repo.all()
  end

  defp latest_sequence_number(account_id) do
    from(log in Log,
      where: log.account_id == ^account_id,
      select: max(log.sequence_number)
    )
    |> Repo.one()
  end

  defp account_lock_keys(account_id) do
    <<key_a::signed-32, key_b::signed-32, _rest::binary>> = :crypto.hash(:sha256, account_id)
    {key_a, key_b}
  end

  defp insert_bulk_logs(account_id, count) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    rows =
      for sequence <- 1..count do
        %{
          id: Ecto.UUID.generate(),
          account_id: account_id,
          sequence_number: sequence,
          checksum: sequence |> Integer.to_string(16) |> String.pad_leading(64, "0"),
          previous_checksum: nil,
          user_id: "bulk-user",
          user_role: "admin",
          session_id: "bulk-session-#{sequence}",
          action: "read",
          resource_type: "patient",
          resource_id: "bulk-resource-#{sequence}",
          timestamp: now,
          source_ip: "127.0.0.1",
          user_agent: "ExUnit",
          outcome: "success",
          failure_reason: nil,
          phi_accessed: false,
          metadata: %{},
          inserted_at: now,
          updated_at: now
        }
      end

    {inserted, _} = Repo.insert_all(Log, rows)
    inserted
  end
end
