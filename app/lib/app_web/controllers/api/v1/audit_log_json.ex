defmodule GAWeb.Api.V1.AuditLogJSON do
  @moduledoc """
  JSON rendering for audit log API responses.
  """

  def index(%{logs: logs, next_cursor: next_cursor}) do
    %{
      data: Enum.map(logs, &data/1),
      meta: %{
        next_cursor: next_cursor,
        count: length(logs)
      }
    }
  end

  def show(%{log: log}), do: %{data: data(log)}

  def data(log) do
    %{
      id: log.id,
      account_id: log.account_id,
      sequence_number: log.sequence_number,
      checksum: log.checksum,
      previous_checksum: log.previous_checksum,
      actor_id: log.actor_id,
      action: log.action,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      timestamp: iso8601(log.timestamp),
      outcome: log.outcome,
      extensions: log.extensions || %{},
      frameworks: Enum.sort(log.frameworks || []),
      metadata: log.metadata || %{},
      inserted_at: iso8601(log.inserted_at),
      updated_at: iso8601(log.updated_at)
    }
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
