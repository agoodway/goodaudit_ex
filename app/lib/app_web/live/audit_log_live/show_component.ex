defmodule GAWeb.AuditLogLive.ShowComponent do
  @moduledoc """
  Stateless function component that renders the inline detail panel
  for an expanded audit log entry.
  """
  use Phoenix.Component

  import GAWeb.CoreComponents, only: [badge: 1]

  attr :entry, :map, required: true

  def show(assigns) do
    ~H"""
    <div class="dash-card-body bg-base-200/40 border-t border-base-300/60">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 p-4">
        <%!-- Checksums --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Checksums
          </h4>
          <div class="space-y-2">
            <.kv_row label="Checksum" value={@entry.checksum} mono />
            <.kv_row label="Previous" value={@entry.previous_checksum || "none (first entry)"} mono />
          </div>
        </div>

        <%!-- Timestamps --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Timestamps
          </h4>
          <div class="space-y-2">
            <.kv_row label="Event time" value={format_iso(@entry.timestamp)} />
            <.kv_row label="Recorded" value={format_iso(@entry.inserted_at)} />
          </div>
        </div>

        <%!-- Metadata --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Metadata
          </h4>
          <div :if={@entry.metadata && @entry.metadata != %{}} class="space-y-1.5">
            <.kv_row :for={{k, v} <- @entry.metadata} label={k} value={format_value(v)} />
          </div>
          <p
            :if={!@entry.metadata || @entry.metadata == %{}}
            class="text-xs text-base-content/30 font-mono"
          >
            No metadata
          </p>
        </div>

        <%!-- Extensions --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Extensions
          </h4>
          <div :if={@entry.extensions && @entry.extensions != %{}} class="space-y-1.5">
            <.kv_row :for={{k, v} <- @entry.extensions} label={k} value={format_value(v)} />
          </div>
          <p
            :if={!@entry.extensions || @entry.extensions == %{}}
            class="text-xs text-base-content/30 font-mono"
          >
            No extensions
          </p>
        </div>

        <%!-- Frameworks --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Frameworks
          </h4>
          <div :if={@entry.frameworks && @entry.frameworks != []} class="flex flex-wrap gap-1.5">
            <.badge :for={fw <- @entry.frameworks}>{fw}</.badge>
          </div>
          <p
            :if={!@entry.frameworks || @entry.frameworks == []}
            class="text-xs text-base-content/30 font-mono"
          >
            No frameworks
          </p>
        </div>

        <%!-- Additional fields --%>
        <div>
          <h4 class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-2">
            Additional
          </h4>
          <div class="space-y-1.5">
            <.kv_row label="User ID" value={@entry.user_id} />
            <.kv_row label="User Role" value={@entry.user_role} />
            <.kv_row label="Session ID" value={@entry.session_id} />
            <.kv_row label="Source IP" value={@entry.source_ip} />
            <.kv_row label="PHI Accessed" value={to_string(@entry.phi_accessed)} />
            <.kv_row :if={@entry.failure_reason} label="Failure Reason" value={@entry.failure_reason} />
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :mono, :boolean, default: false

  defp kv_row(assigns) do
    ~H"""
    <div class="flex gap-2 text-xs">
      <span class="font-mono text-base-content/40 shrink-0 min-w-[5rem]">{@label}</span>
      <span class={[
        "text-base-content/70 break-all",
        @mono && "font-mono text-[0.6875rem]"
      ]}>
        {display_value(@value)}
      </span>
    </div>
    """
  end

  defp display_value(nil), do: "-"
  defp display_value(value) when is_binary(value), do: value
  defp display_value(value), do: inspect(value)

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value) when is_number(value), do: to_string(value)
  defp format_value(value) when is_boolean(value), do: to_string(value)
  defp format_value(nil), do: nil
  defp format_value(value), do: Jason.encode!(value, pretty: true)

  defp format_iso(nil), do: "-"
  defp format_iso(datetime), do: DateTime.to_iso8601(datetime)
end
