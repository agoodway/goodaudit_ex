defmodule GAWeb.Api.V1.CheckpointJSON do
  @moduledoc """
  JSON rendering for checkpoint API responses.
  """

  @doc false
  def index(%{checkpoints: checkpoints}) do
    %{data: Enum.map(checkpoints, &data/1)}
  end

  @doc false
  def show(%{checkpoint: checkpoint}), do: %{data: data(checkpoint)}

  @doc false
  def data(checkpoint) do
    %{
      id: checkpoint.id,
      account_id: checkpoint.account_id,
      sequence_number: checkpoint.sequence_number,
      checksum: checkpoint.checksum,
      signature: checkpoint.signature,
      verified_at: iso8601(checkpoint.verified_at),
      signing_key_id: Map.get(checkpoint, :signing_key_id),
      inserted_at: iso8601(checkpoint.inserted_at),
      updated_at: iso8601(checkpoint.updated_at)
    }
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
