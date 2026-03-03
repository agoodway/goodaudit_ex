defmodule GA.Audit do
  @moduledoc """
  Business logic for account-scoped append-only audit logs and checkpoints.
  """

  import Ecto.Changeset, only: [put_change: 3]
  import Ecto.Query, warn: false

  alias GA.Accounts
  alias GA.Audit.{Chain, Checkpoint, Log, Verifier}
  alias GA.Repo

  @default_limit 50
  @max_limit 1000

  @doc """
  Creates a new audit log entry with per-account chain fields in a single transaction.
  """
  def create_log_entry(account_id, attrs)
      when is_binary(account_id) and (is_map(attrs) or is_list(attrs)) do
    attrs = attrs |> normalize_attrs() |> put_default_timestamp()

    Repo.transaction(fn ->
      with :ok <- lock_account(account_id),
           {:ok, hmac_key} <- Accounts.get_hmac_key(account_id),
           sequence_number <- next_sequence_number(account_id),
           previous_checksum <- get_previous_checksum(account_id, sequence_number),
           {:ok, checksum} <-
             compute_checksum(
               hmac_key,
               attrs,
               account_id,
               sequence_number,
               previous_checksum
             ),
           changeset <-
             Log.changeset(%Log{}, attrs)
             |> apply_chain_fields(account_id, %{
               sequence_number: sequence_number,
               checksum: checksum,
               previous_checksum: previous_checksum
             }),
           {:ok, log} <- Repo.insert(changeset) do
        log
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_tx_result()
  end

  def create_log_entry(_, _), do: {:error, :invalid_arguments}

  @doc """
  Lists account-scoped audit entries with cursor pagination and optional filters.
  """
  def list_logs(account_id, opts \\ []) when is_binary(account_id) do
    limit = opts |> get_opt(:limit) |> normalize_limit()

    query =
      from(log in Log,
        where: log.account_id == ^account_id,
        order_by: [asc: log.sequence_number]
      )
      |> apply_filters(opts)
      |> limit(^(limit + 1))

    query
    |> Repo.all()
    |> paginate(limit)
  end

  @doc """
  Fetches a single audit log entry scoped to an account.
  """
  def get_log(account_id, id) when is_binary(account_id) and is_binary(id) do
    case Repo.get_by(Log, id: id, account_id: account_id) do
      nil -> {:error, :not_found}
      log -> {:ok, log}
    end
  end

  def get_log(_, _), do: {:error, :not_found}

  @doc """
  Creates an audit checkpoint at the account's latest log sequence.
  """
  def create_checkpoint(account_id) when is_binary(account_id) do
    Repo.transaction(fn ->
      with :ok <- lock_account(account_id),
           %Log{} = log <- latest_log(account_id),
           {:ok, checkpoint} <- insert_checkpoint(account_id, log) do
        checkpoint
      else
        nil -> Repo.rollback(:no_entries)
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> unwrap_tx_result()
  end

  def create_checkpoint(_), do: {:error, :no_entries}

  @doc """
  Lists checkpoints for an account from newest to oldest.
  """
  def list_checkpoints(account_id) when is_binary(account_id) do
    from(checkpoint in Checkpoint,
      where: checkpoint.account_id == ^account_id,
      order_by: [desc: checkpoint.sequence_number]
    )
    |> Repo.all()
  end

  def list_checkpoints(_), do: []

  @doc """
  Verifies chain integrity for a single account.
  """
  def verify_chain(account_id) when is_binary(account_id), do: Verifier.verify(account_id)
  def verify_chain(_), do: {:error, :invalid_id}

  defp lock_account(account_id) do
    {key_a, key_b} = account_lock_keys(account_id)

    case Repo.query("SELECT pg_advisory_xact_lock($1, $2)", [key_a, key_b]) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp account_lock_keys(account_id) do
    <<key_a::signed-32, key_b::signed-32, _rest::binary>> = :crypto.hash(:sha256, account_id)
    {key_a, key_b}
  end

  defp next_sequence_number(account_id) do
    from(log in Log,
      where: log.account_id == ^account_id,
      select: max(log.sequence_number)
    )
    |> Repo.one()
    |> case do
      nil -> 1
      max_sequence -> max_sequence + 1
    end
  end

  defp get_previous_checksum(_account_id, sequence_number) when sequence_number <= 1, do: nil

  defp get_previous_checksum(account_id, sequence_number) do
    from(log in Log,
      where:
        log.account_id == ^account_id and
          log.sequence_number == ^(sequence_number - 1),
      select: log.checksum
    )
    |> Repo.one()
  end

  defp apply_chain_fields(changeset, account_id, chain_fields) do
    changeset
    |> put_change(:account_id, account_id)
    |> put_change(:sequence_number, chain_fields.sequence_number)
    |> put_change(:checksum, chain_fields.checksum)
    |> put_change(:previous_checksum, chain_fields.previous_checksum)
  end

  defp chain_attrs(attrs, account_id, sequence_number) do
    attrs
    |> Map.put(:account_id, account_id)
    |> Map.put(:sequence_number, sequence_number)
  end

  defp compute_checksum(hmac_key, attrs, account_id, sequence_number, previous_checksum) do
    checksum =
      Chain.compute_checksum(
        hmac_key,
        chain_attrs(attrs, account_id, sequence_number),
        previous_checksum
      )

    {:ok, checksum}
  rescue
    error in ArgumentError ->
      {:error,
       checksum_error_changeset(
         attrs,
         Exception.message(error)
       )}
  end

  defp checksum_error_changeset(attrs, reason) do
    %Log{}
    |> Log.changeset(attrs)
    |> Ecto.Changeset.add_error(:base, "invalid checksum payload: #{reason}")
  end

  defp insert_checkpoint(account_id, %Log{} = log) do
    %Checkpoint{}
    |> Checkpoint.changeset(%{
      account_id: account_id,
      sequence_number: log.sequence_number,
      checksum: log.checksum
    })
    |> Repo.insert()
  end

  defp latest_log(account_id) do
    from(log in Log,
      where: log.account_id == ^account_id,
      order_by: [desc: log.sequence_number],
      limit: 1
    )
    |> Repo.one()
  end

  defp apply_filters(query, opts) do
    query
    |> maybe_filter(get_opt(opts, :after_sequence), fn q, value ->
      where(q, [log], log.sequence_number > ^value)
    end)
    |> maybe_filter(get_opt(opts, :user_id), fn q, value ->
      where(q, [log], log.user_id == ^value)
    end)
    |> maybe_filter(get_opt(opts, :action), fn q, value ->
      where(q, [log], log.action == ^value)
    end)
    |> maybe_filter(get_opt(opts, :resource_type), fn q, value ->
      where(q, [log], log.resource_type == ^value)
    end)
    |> maybe_filter(get_opt(opts, :resource_id), fn q, value ->
      where(q, [log], log.resource_id == ^value)
    end)
    |> maybe_filter(get_opt(opts, :outcome), fn q, value ->
      where(q, [log], log.outcome == ^value)
    end)
    |> maybe_filter(get_opt(opts, :phi_accessed), fn q, value ->
      where(q, [log], log.phi_accessed == ^value)
    end)
    |> maybe_filter(get_opt(opts, :from), fn q, value ->
      where(q, [log], log.timestamp >= ^value)
    end)
    |> maybe_filter(get_opt(opts, :to), fn q, value ->
      where(q, [log], log.timestamp <= ^value)
    end)
  end

  defp maybe_filter(query, nil, _fun), do: query
  defp maybe_filter(query, value, fun), do: fun.(query, value)

  defp get_opt(opts, key) when is_list(opts), do: Keyword.get(opts, key)

  defp get_opt(opts, key) when is_map(opts) do
    case Map.fetch(opts, key) do
      {:ok, value} -> value
      :error -> Map.get(opts, Atom.to_string(key))
    end
  end

  defp get_opt(_opts, _key), do: nil

  defp normalize_limit(limit) when is_integer(limit) do
    limit
    |> max(1)
    |> min(@max_limit)
  end

  defp normalize_limit(_), do: @default_limit

  defp paginate(entries, limit) do
    {page_entries, overflow} = Enum.split(entries, limit)

    next_cursor =
      case {page_entries, overflow} do
        {[_ | _], [_ | _]} -> List.last(page_entries).sequence_number
        _ -> nil
      end

    {page_entries, next_cursor}
  end

  defp put_default_timestamp(attrs) do
    if Map.has_key?(attrs, :timestamp) or Map.has_key?(attrs, "timestamp") do
      attrs
    else
      Map.put(attrs, :timestamp, DateTime.utc_now())
    end
  end

  defp normalize_attrs(attrs) when is_map(attrs), do: attrs
  defp normalize_attrs(attrs) when is_list(attrs), do: Map.new(attrs)

  defp unwrap_tx_result({:ok, result}), do: {:ok, result}
  defp unwrap_tx_result({:error, reason}), do: {:error, reason}
end
