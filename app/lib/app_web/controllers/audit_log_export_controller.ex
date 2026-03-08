defmodule GAWeb.AuditLogExportController do
  @moduledoc """
  Serves audit log JSON exports as file downloads, avoiding WebSocket
  push_event for large payloads.
  """
  use GAWeb, :controller

  alias GA.Audit

  @valid_outcomes ~w(success failure denied error)

  @doc false
  def export(conn, params) do
    account = conn.assigns.current_account

    opts = build_export_opts(params)
    {entries, truncated} = Audit.export_logs(account.id, opts)

    json_data =
      entries
      |> Enum.map(&serialize_entry/1)
      |> Jason.encode!(pretty: true)

    filename = "audit-logs-#{Date.to_iso8601(Date.utc_today())}.json"

    conn =
      if truncated do
        put_resp_header(conn, "x-export-truncated", "true")
      else
        conn
      end

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("content-disposition", ~s[attachment; filename="#{filename}"])
    |> send_resp(200, json_data)
  end

  defp build_export_opts(params) do
    []
    |> put_opt(:from, parse_date_start(params["from"]))
    |> put_opt(:to, parse_date_end(params["to"]))
    |> put_opt(:actor_id, non_empty(params["actor_id"]))
    |> put_opt(:action, non_empty(params["action"]))
    |> put_opt(:resource_type, non_empty(params["resource_type"]))
    |> put_opt(:outcome, validate_outcome(params["outcome"]))
    |> then(fn opts ->
      if params["phi_accessed"] == "true" do
        Keyword.put(opts, :extensions, %{"hipaa" => %{"phi_accessed" => true}})
      else
        opts
      end
    end)
  end

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp non_empty(""), do: nil
  defp non_empty(nil), do: nil
  defp non_empty(value), do: value

  defp validate_outcome(value) when value in @valid_outcomes, do: value
  defp validate_outcome(_), do: nil

  defp parse_date_start(nil), do: nil

  defp parse_date_start(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_date_end(nil), do: nil

  defp parse_date_end(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp serialize_entry(entry) do
    %{
      id: entry.id,
      sequence_number: entry.sequence_number,
      checksum: entry.checksum,
      previous_checksum: entry.previous_checksum,
      actor_id: entry.actor_id,
      action: entry.action,
      resource_type: entry.resource_type,
      resource_id: entry.resource_id,
      timestamp: entry.timestamp && DateTime.to_iso8601(entry.timestamp),
      outcome: entry.outcome,
      phi_accessed: entry.phi_accessed,
      extensions: entry.extensions,
      frameworks: entry.frameworks,
      metadata: entry.metadata
    }
  end
end
