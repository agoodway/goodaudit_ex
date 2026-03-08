defmodule GAWeb.DashboardLive do
  @moduledoc """
  Dashboard LiveView — the authenticated user's home page.
  """
  use GAWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.current_account.id

    tasks = [
      Task.async(fn -> {:audit_log_count, GA.Audit.count_logs(account_id)} end),
      Task.async(fn -> {:active_api_keys_count, GA.Accounts.count_active_api_keys(account_id)} end),
      Task.async(fn ->
        {:active_frameworks_count, GA.Compliance.count_active_frameworks(account_id)}
      end),
      Task.async(fn -> {:recent_logs, GA.Audit.recent_logs(account_id)} end)
    ]

    results = tasks |> Task.await_many(5_000) |> Map.new()

    if connected?(socket), do: send(self(), :verify_chain)

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       active_nav: :dashboard,
       breadcrumbs: [%{label: "Dashboard"}],
       audit_log_count: results.audit_log_count,
       active_api_keys_count: results.active_api_keys_count,
       active_frameworks_count: results.active_frameworks_count,
       recent_logs: results.recent_logs,
       chain_status: :loading
     )}
  end

  @impl true
  def handle_info(:verify_chain, socket) do
    account_id = socket.assigns.current_account.id
    chain_result = GA.Audit.verify_chain(account_id)
    chain_status = chain_status(chain_result)
    {:noreply, assign(socket, chain_status: chain_status)}
  end

  defp chain_status(%{total_entries: 0}), do: :no_logs
  defp chain_status(%{valid: true}), do: :verified
  defp chain_status(%{valid: false}), do: :broken

  defp chain_status({:error, reason}) do
    Logger.error("Chain verification failed: #{inspect(reason)}")
    :error
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Page header --%>
      <div class="flex items-end justify-between animate-fade-up">
        <div>
          <h1 class="text-lg font-semibold tracking-tight text-base-content">
            {@current_account.name}
          </h1>
          <p class="mt-0.5 text-xs font-mono text-base-content/40">
            Account overview and compliance status
          </p>
        </div>
      </div>

      <%!-- Metric cards row --%>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 animate-fade-up animate-delay-1">
        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">Active Frameworks</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value text-primary">{@active_frameworks_count}</span>
              <%= if @active_frameworks_count > 0 do %>
                <span class="flex items-center gap-1 text-xs font-mono text-success">
                  <span class="status-dot status-dot--ok" /> configured
                </span>
              <% else %>
                <span class="text-xs font-mono text-base-content/30">none configured</span>
              <% end %>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">Chain Status</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class={[
                "metric-value",
                chain_status_color(@chain_status)
              ]}>
                {chain_status_label(@chain_status)}
              </span>
              <span class="flex items-center gap-1 text-xs font-mono">
                <span class={chain_status_dot_classes(@chain_status)} />
              </span>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">Audit Logs</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value">{format_number(@audit_log_count)}</span>
              <span class="text-xs font-mono text-base-content/30">last 30d</span>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">API Keys</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value">{@active_api_keys_count}</span>
              <%= if @active_api_keys_count > 0 do %>
                <span class="flex items-center gap-1 text-xs font-mono text-success">
                  <span class="status-dot status-dot--ok" /> active
                </span>
              <% else %>
                <span class="text-xs font-mono text-base-content/30">none active</span>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Two-column content --%>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-3 animate-fade-up animate-delay-2">
        <%!-- Recent activity --%>
        <div class="dash-card lg:col-span-2">
          <div class="dash-card-header">Recent Activity</div>
          <div class="divide-y divide-base-300/60">
            <%= if @recent_logs == [] do %>
              <div class="px-5 py-8 text-center">
                <p class="text-sm text-base-content/40">No audit log entries yet</p>
              </div>
            <% else %>
              <.activity_row
                :for={log <- @recent_logs}
                icon={action_icon(log.action)}
                icon_color={action_color(log.action)}
                title={log.action}
                detail={format_activity_detail(log)}
                time={relative_time(log.inserted_at)}
              />
            <% end %>
          </div>
        </div>

        <%!-- System Status — placeholder until health check system is built --%>
        <div class="dash-card">
          <div class="dash-card-header">System Status</div>
          <div class="dash-card-body">
            <p class="text-sm text-base-content/40 py-4 text-center">
              Health checks coming soon
            </p>
          </div>
        </div>
      </div>

      <%!-- Getting started --%>
      <div class="dash-card animate-fade-up animate-delay-3">
        <div class="dash-card-header">Getting Started</div>
        <div class="dash-card-body">
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <.setup_step
              number="01"
              title="Configure Framework"
              description="Set up your compliance framework (SOC 2, ISO 27001, etc.)"
              complete={@active_frameworks_count > 0}
            />
            <.setup_step
              number="02"
              title="Connect Integrations"
              description="Link your cloud providers and SaaS tools for automated evidence collection"
              complete={false}
            />
            <.setup_step
              number="03"
              title="Create API Key"
              description="Generate an API key for programmatic audit log ingestion"
              complete={@active_api_keys_count > 0}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Helper functions ---

  defp action_icon(action) when is_binary(action) do
    cond do
      action_contains?(action, ~w(create)) -> "hero-plus-circle"
      action_contains?(action, ~w(delete)) -> "hero-trash"
      action_contains?(action, ~w(update)) -> "hero-pencil-square"
      action_contains?(action, ~w(login logout auth)) -> "hero-key"
      action_contains?(action, ~w(access read)) -> "hero-eye"
      action_contains?(action, ~w(export)) -> "hero-arrow-down-tray"
      true -> "hero-document-text"
    end
  end

  defp action_icon(_), do: "hero-document-text"

  defp action_color(action) when is_binary(action) do
    cond do
      action_contains?(action, ~w(create)) -> "text-success"
      action_contains?(action, ~w(delete)) -> "text-error"
      action_contains?(action, ~w(update export)) -> "text-info"
      action_contains?(action, ~w(login logout auth)) -> "text-primary"
      action_contains?(action, ~w(access read)) -> "text-warning"
      true -> "text-base-content/50"
    end
  end

  defp action_color(_), do: "text-base-content/50"

  defp action_contains?(action, keywords) do
    tokens = String.split(action, ~r/[._]/)
    Enum.any?(keywords, fn kw -> Enum.any?(tokens, &String.starts_with?(&1, kw)) end)
  end

  @doc false
  def relative_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} min ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      true -> Calendar.strftime(datetime, "%b %d, %Y")
    end
  end

  defp format_activity_detail(log) do
    parts =
      [log.resource_type, log.actor_id]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" \u00b7 ")

    if parts == "", do: "\u2014", else: parts
  end

  @doc false
  def format_number(n) when is_integer(n) and n >= 1000 do
    Integer.to_string(n)
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  def format_number(n) when is_integer(n), do: Integer.to_string(n)

  defp chain_status_label(:verified), do: "verified"
  defp chain_status_label(:broken), do: "broken"
  defp chain_status_label(:no_logs), do: "no logs"
  defp chain_status_label(:loading), do: "checking…"
  defp chain_status_label(:error), do: "unavailable"

  defp chain_status_color(:verified), do: "text-success"
  defp chain_status_color(:broken), do: "text-error"
  defp chain_status_color(:no_logs), do: "text-base-content/40"
  defp chain_status_color(:loading), do: "text-base-content/40"
  defp chain_status_color(:error), do: "text-warning"

  defp chain_status_dot_classes(:verified), do: "status-dot status-dot--ok"
  defp chain_status_dot_classes(:broken), do: "status-dot status-dot--error status-dot--pulse"
  defp chain_status_dot_classes(:no_logs), do: ""
  defp chain_status_dot_classes(:loading), do: ""
  defp chain_status_dot_classes(:error), do: "status-dot status-dot--warn"

  # --- Dashboard components ---

  attr :icon, :string, required: true
  attr :icon_color, :string, required: true
  attr :title, :string, required: true
  attr :detail, :string, required: true
  attr :time, :string, required: true

  defp activity_row(assigns) do
    ~H"""
    <div class="flex items-start gap-3 px-5 py-3.5">
      <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded bg-base-200/80 mt-0.5">
        <.icon name={@icon} class={"size-3.5 #{@icon_color}"} />
      </div>
      <div class="min-w-0 flex-1">
        <p class="text-sm font-medium text-base-content/80">{@title}</p>
        <p class="text-xs text-base-content/40 mt-0.5 truncate">{@detail}</p>
      </div>
      <span class="text-[0.625rem] font-mono text-base-content/30 shrink-0 mt-0.5">{@time}</span>
    </div>
    """
  end

  attr :number, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :complete, :boolean, required: true

  defp setup_step(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-3 p-4 rounded border transition-colors",
      if(@complete,
        do: "border-success/20 bg-success/[0.03]",
        else: "border-base-300/60 hover:border-base-300"
      )
    ]}>
      <div class="flex items-center justify-between">
        <span class="font-mono text-xs font-bold text-base-content/20">{@number}</span>
        <%= if @complete do %>
          <div class="flex h-5 w-5 items-center justify-center rounded-full bg-success/15">
            <.icon name="hero-check-mini" class="size-3 text-success" />
          </div>
        <% else %>
          <div class="h-5 w-5 rounded-full border border-base-300" />
        <% end %>
      </div>
      <div>
        <p class={[
          "text-sm font-semibold",
          if(@complete, do: "text-base-content/40 line-through", else: "text-base-content/80")
        ]}>
          {@title}
        </p>
        <p class="text-xs text-base-content/40 mt-1 leading-relaxed">{@description}</p>
      </div>
    </div>
    """
  end
end
