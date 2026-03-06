defmodule GA.Audit do
  @moduledoc """
  Business logic for account-scoped append-only audit logs and checkpoints.
  """

  import Ecto.Changeset, only: [put_change: 3]
  import Ecto.Query, warn: false

  alias GA.Accounts
  alias GA.Audit.{Chain, Checkpoint, Log, Verifier}
  alias GA.Compliance
  alias GA.Compliance.ActionMapping
  alias GA.Compliance.ExtensionSchema
  alias GA.Repo

  @default_limit 50
  @max_limit 1000
  @reserved_chain_keys [:account_id, :sequence_number, :checksum, :previous_checksum]

  @doc """
  Creates a new audit log entry with per-account chain fields in a single transaction.
  """
  def create_log_entry(account_id, attrs)
      when is_binary(account_id) and (is_map(attrs) or is_list(attrs)) do
    attrs = attrs |> normalize_attrs() |> drop_reserved_chain_keys() |> put_default_timestamp()
    active_frameworks = Compliance.list_active_frameworks(account_id)

    framework_ids =
      active_frameworks
      |> Enum.map(& &1.framework)
      |> Enum.sort()

    additional_required_by_framework = additional_required_fields_by_framework(active_frameworks)

    with {:ok, validated_extensions} <-
           ExtensionSchema.validate(
             framework_ids,
             get_opt(attrs, :extensions),
             additional_required_by_framework
           ),
         :ok <- Compliance.validate_action_for_strict_frameworks(account_id, get_opt(attrs, :action)) do
      attrs =
        attrs
        |> Map.delete("extensions")
        |> Map.delete("frameworks")
        |> Map.put(:extensions, validated_extensions)
        |> Map.put(:frameworks, framework_ids)
        |> hydrate_legacy_fields()

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
  end

  def create_log_entry(_, _), do: {:error, :invalid_arguments}

  @doc """
  Lists account-scoped audit entries with cursor pagination and optional filters.
  """
  def list_logs(account_id, opts \\ []) when is_binary(account_id) do
    with {:ok, category_actions} <- resolve_category_actions(account_id, get_opt(opts, :category)) do
      limit = opts |> get_opt(:limit) |> normalize_limit()

      query =
        from(log in Log,
          where: log.account_id == ^account_id,
          order_by: [asc: log.sequence_number]
        )
        |> apply_filters(opts, category_actions)
        |> limit(^(limit + 1))

      query
      |> Repo.all()
      |> paginate(limit)
    end
  end

  @doc """
  Fetches a single audit log entry scoped to an account.
  """
  def get_log(account_id, id) when is_binary(account_id) and is_binary(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} ->
        case Repo.get_by(Log, id: uuid, account_id: account_id) do
          nil -> {:error, :not_found}
          log -> {:ok, log}
        end

      :error ->
        {:error, :not_found}
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

  defp apply_filters(query, opts, category_actions) do
    query
    |> maybe_filter(category_actions, fn q, actions ->
      where(q, [log], log.action in ^actions)
    end)
    |> maybe_filter(get_opt(opts, :after_sequence), fn q, value ->
      where(q, [log], log.sequence_number > ^value)
    end)
    |> maybe_filter(get_opt(opts, :actor_id), fn q, value ->
      where(q, [log], log.actor_id == ^value)
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
    |> maybe_filter(normalize_extensions_filter(get_opt(opts, :extensions)), fn q, value ->
      where(q, [log], fragment("? @> ?", log.extensions, type(^value, :map)))
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

  defp drop_reserved_chain_keys(attrs) do
    Enum.reduce(@reserved_chain_keys, attrs, fn key, acc ->
      acc
      |> Map.delete(key)
      |> Map.delete(Atom.to_string(key))
    end)
  end

  defp unwrap_tx_result({:ok, result}), do: {:ok, result}
  defp unwrap_tx_result({:error, reason}), do: {:error, reason}

  defp normalize_extensions_filter(%{} = extensions), do: extensions
  defp normalize_extensions_filter(_), do: nil

  defp additional_required_fields(nil), do: []

  defp additional_required_fields(association) do
    (association.config_overrides || %{})
    |> Map.get("additional_required_fields", [])
    |> Enum.map(&to_string/1)
  end

  defp additional_required_fields_by_framework(active_frameworks) do
    Enum.reduce(active_frameworks, %{}, fn association, acc ->
      required_fields = additional_required_fields(association)

      if required_fields == [] do
        acc
      else
        Map.put(acc, association.framework, required_fields)
      end
    end)
  end

  defp hydrate_legacy_fields(attrs) do
    actor_id = get_opt(attrs, :actor_id)
    extensions = get_opt(attrs, :extensions) || %{}

    attrs
    |> put_if_missing(:user_id, actor_id)
    |> put_if_missing(:user_role, extension_value(extensions, "hipaa", "user_role") || "unknown")
    |> put_if_missing(:session_id, extension_value(extensions, "hipaa", "session_id"))
    |> put_if_missing(:source_ip, extension_value(extensions, "hipaa", "source_ip"))
    |> put_if_missing(:user_agent, extension_value(extensions, "hipaa", "user_agent"))
    |> put_if_missing(:failure_reason, extension_value(extensions, "hipaa", "failure_reason"))
    |> put_if_missing(:phi_accessed, extension_value(extensions, "hipaa", "phi_accessed") || false)
  end

  defp put_if_missing(attrs, _key, nil), do: attrs

  defp put_if_missing(attrs, key, value) when is_atom(key) do
    string_key = Atom.to_string(key)

    cond do
      Map.has_key?(attrs, key) and not is_nil(Map.get(attrs, key)) ->
        attrs

      Map.has_key?(attrs, string_key) and not is_nil(Map.get(attrs, string_key)) ->
        attrs

      Map.has_key?(attrs, key) ->
        Map.put(attrs, key, value)

      Map.has_key?(attrs, string_key) ->
        Map.put(attrs, string_key, value)

      true ->
        Map.put(attrs, key, value)
    end
  end

  defp extension_value(extensions, framework_id, field)
       when is_map(extensions) and is_binary(framework_id) and is_binary(field) do
    framework_extensions = Map.get(extensions, framework_id)

    case framework_extensions do
      %{} = framework_map ->
        Map.get(framework_map, field)

      _ ->
        nil
    end
  end

  defp extension_value(_extensions, _framework_id, _field), do: nil

  defp resolve_category_actions(_account_id, nil), do: {:ok, nil}

  defp resolve_category_actions(account_id, category_filter) when is_binary(category_filter) do
    with {:ok, framework, pattern} <- parse_category_filter(category_filter),
         {:ok, resolved} <- ActionMapping.resolve_actions(account_id, framework, pattern) do
      {:ok, Enum.uniq(resolved.taxonomy_actions ++ resolved.mapped_actions)}
    else
      {:error, :invalid_category_format} -> {:error, :invalid_category_format}
      {:error, :unknown_framework} -> {:error, :unknown_framework}
      {:error, :invalid_path} -> {:error, :invalid_category_path}
    end
  end

  defp resolve_category_actions(_account_id, _category_filter), do: {:error, :invalid_category_format}

  defp parse_category_filter(value) when is_binary(value) do
    case String.split(value, ":", parts: 2) do
      [framework, pattern] when framework != "" and pattern != "" ->
        {:ok, framework, pattern}

      _ ->
        {:error, :invalid_category_format}
    end
  end
end
