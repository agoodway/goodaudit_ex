defmodule GA.Audit.Verifier do
  @moduledoc """
  Streams and verifies account-scoped audit chains.
  """

  import Ecto.Query, warn: false

  alias GA.Accounts
  alias GA.Audit.{Chain, Checkpoint, Log}
  alias GA.Repo

  @batch_size 1000

  @doc """
  Verifies an account's audit chain and returns a report map.
  """
  @spec verify(binary()) :: map() | {:error, :invalid_id | :not_found}
  def verify(account_id) when is_binary(account_id) do
    started_at = System.monotonic_time(:millisecond)

    with {:ok, hmac_key} <- Accounts.get_hmac_key(account_id) do
      checkpoints_by_sequence = load_checkpoints(account_id)
      report = stream_and_verify(account_id, hmac_key, checkpoints_by_sequence)

      Map.put(report, :duration_ms, elapsed_ms(started_at))
    end
  end

  def verify(_), do: {:error, :invalid_id}

  defp stream_and_verify(account_id, hmac_key, checkpoints_by_sequence) do
    initial =
      new_accumulator()
      |> Map.put(:account_id, account_id)

    account_id
    |> do_verify_batches(hmac_key, checkpoints_by_sequence, initial)
    |> finalize_report()
  end

  defp do_verify_batches(account_id, hmac_key, checkpoints_by_sequence, acc) do
    batch = load_batch(account_id, acc.last_sequence)

    case batch do
      [] ->
        acc

      _entries ->
        next_acc =
          Enum.reduce(batch, acc, fn entry, state ->
            verify_entry(entry, hmac_key, checkpoints_by_sequence, state)
          end)

        do_verify_batches(account_id, hmac_key, checkpoints_by_sequence, next_acc)
    end
  end

  defp verify_entry(%Log{} = entry, hmac_key, checkpoints_by_sequence, acc) do
    acc
    |> verify_sequence(entry)
    |> verify_checksum(entry, hmac_key)
    |> verify_checkpoint(entry, checkpoints_by_sequence)
    |> advance_state(entry)
  end

  defp verify_sequence(acc, %Log{sequence_number: found_sequence}) do
    expected_sequence = acc.expected_sequence

    if found_sequence == expected_sequence do
      %{acc | expected_sequence: expected_sequence + 1}
    else
      missing =
        if found_sequence > expected_sequence do
          Enum.to_list(expected_sequence..(found_sequence - 1))
        else
          []
        end

      gap = %{
        expected: expected_sequence,
        found: found_sequence,
        missing: missing
      }

      acc
      |> mark_invalid(%{
        type: :sequence_gap,
        expected: expected_sequence,
        found: found_sequence,
        missing: missing
      })
      |> Map.update!(:sequence_gaps, &[gap | &1])
      |> Map.put(:expected_sequence, max(found_sequence, expected_sequence) + 1)
    end
  end

  defp verify_checksum(acc, %Log{} = entry, hmac_key) do
    if Chain.verify_checksum(hmac_key, entry, acc.previous_checksum) do
      acc
    else
      mark_invalid(acc, %{
        type: :checksum_mismatch,
        sequence_number: entry.sequence_number,
        stored_checksum: entry.checksum,
        expected_checksum: expected_checksum(hmac_key, entry, acc.previous_checksum)
      })
    end
  end

  defp verify_checkpoint(acc, %Log{} = entry, checkpoints_by_sequence) do
    case Map.get(checkpoints_by_sequence, entry.sequence_number) do
      nil ->
        acc

      %Checkpoint{} = checkpoint ->
        valid? = checkpoint.checksum == entry.checksum
        result = %{sequence_number: entry.sequence_number, valid: valid?}
        next_acc = Map.update!(acc, :checkpoint_results, &[result | &1])

        if valid? do
          next_acc
        else
          mark_invalid(next_acc, %{
            type: :checkpoint_mismatch,
            sequence_number: entry.sequence_number,
            checkpoint_checksum: checkpoint.checksum,
            entry_checksum: entry.checksum
          })
        end
    end
  end

  defp advance_state(acc, %Log{} = entry) do
    %{
      acc
      | previous_checksum: entry.checksum,
        last_sequence: entry.sequence_number,
        total_entries: acc.total_entries + 1,
        verified_entries: acc.verified_entries + 1
    }
  end

  defp expected_checksum(hmac_key, entry, previous_checksum) do
    Chain.compute_checksum(hmac_key, Map.from_struct(entry), previous_checksum)
  rescue
    _ -> nil
  end

  defp load_batch(account_id, after_sequence) do
    from(log in Log,
      where: log.account_id == ^account_id and log.sequence_number > ^after_sequence,
      order_by: [asc: log.sequence_number],
      limit: @batch_size
    )
    |> Repo.all()
  end

  defp load_checkpoints(account_id) do
    from(checkpoint in Checkpoint, where: checkpoint.account_id == ^account_id)
    |> Repo.all()
    |> Map.new(fn checkpoint -> {checkpoint.sequence_number, checkpoint} end)
  end

  defp new_accumulator do
    %{
      account_id: nil,
      valid: true,
      total_entries: 0,
      verified_entries: 0,
      expected_sequence: 1,
      previous_checksum: nil,
      last_sequence: 0,
      first_failure: nil,
      sequence_gaps: [],
      checkpoint_results: []
    }
  end

  defp finalize_report(acc) do
    %{
      valid: acc.valid,
      total_entries: acc.total_entries,
      verified_entries: acc.verified_entries,
      first_failure: acc.first_failure,
      sequence_gaps: Enum.reverse(acc.sequence_gaps),
      checkpoint_results: Enum.reverse(acc.checkpoint_results),
      duration_ms: 0
    }
  end

  defp mark_invalid(acc, failure) do
    case acc.first_failure do
      nil -> %{acc | valid: false, first_failure: failure}
      _existing -> %{acc | valid: false}
    end
  end

  defp elapsed_ms(started_at) do
    System.monotonic_time(:millisecond)
    |> Kernel.-(started_at)
    |> max(0)
  end
end
