defmodule GA.Audit.VerifierTest do
  use GA.DataCase, async: false

  alias GA.Accounts
  alias GA.Audit
  alias GA.Audit.{Chain, Checkpoint, Log}
  alias GA.Repo

  describe "verify_chain/1" do
    test "returns a valid report for an intact account chain" do
      account = account_fixture()

      assert {:ok, _first} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "r-1"}))

      assert {:ok, _second} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "r-2"}))

      assert {:ok, checkpoint} = Audit.create_checkpoint(account.id)

      report = Audit.verify_chain(account.id)

      assert report.valid == true
      assert report.total_entries == 2
      assert report.verified_entries == 2
      assert report.first_failure == nil
      assert report.sequence_gaps == []

      assert Enum.any?(
               report.checkpoint_results,
               &(&1.sequence_number == checkpoint.sequence_number and &1.valid)
             )

      assert is_integer(report.duration_ms)
      assert report.duration_ms >= 0
    end

    test "detects tampered checksum entries" do
      account = account_fixture()

      assert {:ok, first} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "seed"}))

      insert_raw_log(account.id, %{
        sequence_number: 2,
        previous_checksum: first.checksum,
        checksum: String.duplicate("0", 64),
        resource_id: "tampered"
      })

      report = Audit.verify_chain(account.id)

      assert report.valid == false
      assert report.first_failure.type == :checksum_mismatch
      assert report.first_failure.sequence_number == 2
      assert report.first_failure.stored_checksum == String.duplicate("0", 64)
      refute is_nil(report.first_failure.expected_checksum)
    end

    test "detects sequence gaps within an account" do
      account = account_fixture()

      assert {:ok, _first} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "gap-1"}))

      assert {:ok, second} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "gap-2"}))

      assert {:ok, hmac_key} = Accounts.get_hmac_key(account.id)

      checksum =
        checksum_for_sequence(
          account.id,
          hmac_key,
          4,
          second.checksum,
          %{resource_id: "gap-4"}
        )

      insert_raw_log(account.id, %{
        sequence_number: 4,
        previous_checksum: second.checksum,
        checksum: checksum,
        resource_id: "gap-4"
      })

      report = Audit.verify_chain(account.id)

      assert report.valid == false
      assert report.first_failure.type == :sequence_gap
      assert report.first_failure.missing_count == 1
      assert report.first_failure.missing_truncated == false
      assert report.first_failure.missing_range == %{from: 3, to: 3}
      assert [%{expected: 3, found: 4, missing: [3]}] = report.sequence_gaps
    end

    test "caps missing sequence samples for very large gaps" do
      account = account_fixture()

      assert {:ok, _first} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "large-gap-1"}))

      assert {:ok, second} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "large-gap-2"}))

      assert {:ok, hmac_key} = Accounts.get_hmac_key(account.id)

      far_sequence = 250_000

      checksum =
        checksum_for_sequence(
          account.id,
          hmac_key,
          far_sequence,
          second.checksum,
          %{resource_id: "large-gap-far"}
        )

      insert_raw_log(account.id, %{
        sequence_number: far_sequence,
        previous_checksum: second.checksum,
        checksum: checksum,
        resource_id: "large-gap-far"
      })

      report = Audit.verify_chain(account.id)

      assert report.valid == false
      assert report.first_failure.type == :sequence_gap
      assert report.first_failure.missing_count == far_sequence - 3
      assert report.first_failure.missing_truncated == true
      assert report.first_failure.missing_range == %{from: 3, to: far_sequence - 1}
      assert length(report.first_failure.missing) == 100
      assert hd(report.first_failure.missing) == 3
      assert List.last(report.first_failure.missing) == 102
    end

    test "validates checkpoint anchors and reports invalid anchors" do
      account = account_fixture()

      assert {:ok, first} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "cp-1"}))

      assert {:ok, second} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "cp-2"}))

      insert_checkpoint(account.id, first.sequence_number, first.checksum)
      insert_checkpoint(account.id, second.sequence_number, String.duplicate("f", 64))

      report = Audit.verify_chain(account.id)

      assert report.valid == false

      assert Enum.any?(
               report.checkpoint_results,
               &(&1.sequence_number == first.sequence_number and &1.valid)
             )

      assert Enum.any?(
               report.checkpoint_results,
               &(&1.sequence_number == second.sequence_number and not &1.valid)
             )
    end

    test "includes non-negative duration tracking" do
      account = account_fixture()

      assert {:ok, _} =
               Audit.create_log_entry(account.id, valid_attrs(%{resource_id: "duration"}))

      report = Audit.verify_chain(account.id)

      assert is_integer(report.duration_ms)
      assert report.duration_ms >= 0
    end

    test "verification remains account-scoped" do
      account_a = account_fixture()
      account_b = account_fixture()

      assert {:ok, _} = Audit.create_log_entry(account_a.id, valid_attrs(%{resource_id: "a-1"}))

      assert {:ok, first_b} =
               Audit.create_log_entry(account_b.id, valid_attrs(%{resource_id: "b-1"}))

      insert_raw_log(account_b.id, %{
        sequence_number: 2,
        previous_checksum: first_b.checksum,
        checksum: String.duplicate("a", 64),
        resource_id: "b-2-tampered"
      })

      report = Audit.verify_chain(account_a.id)

      assert report.valid == true
      assert report.total_entries == 1
      assert report.first_failure == nil
      assert report.sequence_gaps == []
    end
  end

  defp account_fixture(attrs \\ %{}) do
    defaults = %{name: "Verifier Account #{System.unique_integer([:positive])}"}
    {:ok, account} = Accounts.create_account(Map.merge(defaults, attrs))
    account
  end

  defp valid_attrs(overrides \\ %{}) do
    defaults = %{
      actor_id: Ecto.UUID.generate(),
      user_id: Ecto.UUID.generate(),
      user_role: "admin",
      session_id: "session-#{System.unique_integer([:positive])}",
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-03 16:30:00.000000Z],
      source_ip: "127.0.0.1",
      user_agent: "ExUnit",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: false,
      metadata: %{"source" => "verifier_test"}
    }

    Map.merge(defaults, overrides)
  end

  defp checksum_for_sequence(
         account_id,
         hmac_key,
         sequence_number,
         previous_checksum,
         overrides \\ %{}
       ) do
    attrs =
      valid_attrs(overrides)
      |> Map.put(:account_id, account_id)
      |> Map.put(:sequence_number, sequence_number)

    Chain.compute_checksum(hmac_key, attrs, previous_checksum)
  end

  defp insert_raw_log(account_id, attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)
    id = Ecto.UUID.generate()

    row =
      valid_attrs()
      |> Map.merge(attrs)
      |> Map.merge(%{
        id: id,
        account_id: account_id,
        inserted_at: now,
        updated_at: now
      })

    {1, _} = Repo.insert_all(Log, [row])
    Repo.get!(Log, id)
  end

  defp insert_checkpoint(account_id, sequence_number, checksum) do
    %Checkpoint{}
    |> Checkpoint.changeset(%{
      account_id: account_id,
      sequence_number: sequence_number,
      checksum: checksum
    })
    |> Repo.insert!()
  end
end
