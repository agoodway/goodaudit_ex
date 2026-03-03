defmodule GA.Audit.Chain do
  @moduledoc """
  Deterministic HMAC-SHA-256 chain checksum computation utilities.
  """

  @genesis_previous "genesis"
  @checksum_pattern ~r/\A[0-9a-f]{64}\z/
  @payload_fields [
    "account_id",
    "sequence_number",
    "timestamp",
    "user_id",
    "user_role",
    "session_id",
    "action",
    "resource_type",
    "resource_id",
    "outcome",
    "failure_reason",
    "phi_accessed",
    "source_ip",
    "user_agent"
  ]

  @doc """
  Computes a lowercase hex-encoded HMAC-SHA-256 checksum for audit attributes.
  """
  @spec compute_checksum(binary(), map(), binary() | nil) :: binary()
  def compute_checksum(key, attrs, previous_checksum) when is_map(attrs) do
    validated_key = validate_key!(key)
    validated_previous_checksum = validate_previous_checksum!(previous_checksum)
    payload = canonical_payload(attrs, validated_previous_checksum)

    :crypto.mac(:hmac, :sha256, validated_key, payload)
    |> Base.encode16(case: :lower)
  end

  def compute_checksum(_key, _attrs, _previous_checksum) do
    raise ArgumentError, "attrs must be a map"
  end

  @doc """
  Verifies a stored checksum for a log entry using constant-time comparison.
  """
  @spec verify_checksum(binary(), struct() | map(), binary() | nil) :: boolean()
  def verify_checksum(key, entry, previous_checksum) when is_map(entry) do
    validated_key = validate_key!(key)
    validated_previous_checksum = validate_previous_checksum!(previous_checksum)
    expected = compute_checksum(validated_key, entry_to_attrs(entry), validated_previous_checksum)

    case get_value(entry, "checksum") do
      checksum when valid_checksum?(checksum) ->
        Plug.Crypto.secure_compare(expected, checksum)

      _ ->
        false
    end
  end

  def verify_checksum(_key, _entry, _previous_checksum), do: false

  @doc """
  Builds the canonical payload string used for checksum computation.
  """
  @spec canonical_payload(map(), binary() | nil) :: binary()
  def canonical_payload(attrs, previous_checksum) when is_map(attrs) do
    validated_previous_checksum = validate_previous_checksum!(previous_checksum)
    normalized_attrs = normalize_keys(attrs)

    fields =
      @payload_fields
      |> Enum.map(&render_value(get_value(normalized_attrs, &1)))

    previous = validated_previous_checksum || @genesis_previous
    metadata = canonical_metadata(get_value(normalized_attrs, "metadata"))

    [Enum.at(fields, 0), Enum.at(fields, 1), previous] ++ Enum.drop(fields, 2) ++ [metadata]
    |> Enum.map(&reject_payload_delimiter!/1)
    |> Enum.join("|")
  end

  def canonical_payload(_attrs, _previous_checksum) do
    raise ArgumentError, "attrs must be a map"
  end

  defp entry_to_attrs(entry) when is_map(entry) do
    entry
    |> maybe_from_struct()
    |> normalize_keys()
    |> Map.take(@payload_fields ++ ["metadata"])
  end

  defp maybe_from_struct(%{__struct__: _} = struct), do: Map.from_struct(struct)
  defp maybe_from_struct(map), do: map

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end

  defp get_value(attrs, key) when is_map(attrs) do
    case Map.fetch(attrs, key) do
      {:ok, value} -> value
      :error -> Map.get(attrs, to_existing_atom(key))
    end
  end

  defp render_value(%DateTime{} = timestamp), do: DateTime.to_iso8601(timestamp)
  defp render_value(nil), do: ""
  defp render_value(value), do: to_string(value)

  defp canonical_metadata(nil), do: "{}"
  defp canonical_metadata(metadata) when metadata == %{}, do: "{}"

  defp canonical_metadata(metadata) when is_map(metadata) do
    metadata
    |> sort_keys_recursive()
    |> Jason.encode!()
  end

  defp canonical_metadata(other), do: other |> sort_keys_recursive() |> Jason.encode!()

  defp sort_keys_recursive(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> {to_string(key), sort_keys_recursive(value)} end)
    |> Jason.OrderedObject.new()
  end

  defp sort_keys_recursive(list) when is_list(list) do
    Enum.map(list, &sort_keys_recursive/1)
  end

  defp sort_keys_recursive(value), do: value

  defp reject_payload_delimiter!(value) when is_binary(value) do
    if String.contains?(value, "|") do
      raise ArgumentError, "canonical payload fields must not contain the pipe delimiter"
    end

    value
  end

  defp validate_key!(key) when is_binary(key) and byte_size(key) > 0, do: key
  defp validate_key!(key) when is_binary(key), do: raise(ArgumentError, "key must be a non-empty binary")
  defp validate_key!(_key), do: raise(ArgumentError, "key must be a non-empty binary")

  defp validate_previous_checksum!(nil), do: nil

  defp validate_previous_checksum!(checksum) when is_binary(checksum) do
    if valid_checksum?(checksum) do
      checksum
    else
      raise ArgumentError, "previous_checksum must be nil or a 64-character lowercase hex checksum"
    end
  end

  defp validate_previous_checksum!(_value) do
    raise ArgumentError, "previous_checksum must be nil or a 64-character lowercase hex checksum"
  end

  defp valid_checksum?(checksum) when is_binary(checksum), do: String.match?(checksum, @checksum_pattern)
  defp valid_checksum?(_checksum), do: false

  defp to_existing_atom(key) do
    try do
      String.to_existing_atom(key)
    rescue
      ArgumentError -> nil
    end
  end
end
