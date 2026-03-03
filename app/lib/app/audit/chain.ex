defmodule GA.Audit.Chain do
  @moduledoc """
  Deterministic HMAC-SHA-256 chain checksum computation utilities.
  """

  @genesis_previous "genesis"
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
  def compute_checksum(key, attrs, previous_checksum) when is_binary(key) and is_map(attrs) do
    payload = canonical_payload(attrs, previous_checksum)

    :crypto.mac(:hmac, :sha256, key, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a stored checksum for a log entry using constant-time comparison.
  """
  @spec verify_checksum(binary(), struct() | map(), binary() | nil) :: boolean()
  def verify_checksum(key, entry, previous_checksum) when is_binary(key) and is_map(entry) do
    expected = compute_checksum(key, entry_to_attrs(entry), previous_checksum)

    case get_value(entry, "checksum") do
      checksum when is_binary(checksum) ->
        Plug.Crypto.secure_compare(expected, checksum)

      _ ->
        false
    end
  end

  @doc """
  Builds the canonical payload string used for checksum computation.
  """
  @spec canonical_payload(map(), binary() | nil) :: binary()
  def canonical_payload(attrs, previous_checksum) when is_map(attrs) do
    normalized_attrs = normalize_keys(attrs)

    fields =
      @payload_fields
      |> Enum.map(&render_value(get_value(normalized_attrs, &1)))

    previous = previous_checksum || @genesis_previous
    metadata = canonical_metadata(get_value(normalized_attrs, "metadata"))

    [Enum.at(fields, 0), Enum.at(fields, 1), previous] ++ Enum.drop(fields, 2) ++ [metadata]
    |> Enum.join("|")
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
      :error -> Map.get(attrs, String.to_atom(key))
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
end
