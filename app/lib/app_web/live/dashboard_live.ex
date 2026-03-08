defmodule GAWeb.DashboardLive do
  @moduledoc """
  Dashboard LiveView — the authenticated user's home page.
  """
  use GAWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Dashboard",
       active_nav: :dashboard,
       breadcrumbs: [%{label: "Dashboard"}]
     )}
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
            <p class="metric-label">Compliance Score</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value text-primary">98%</span>
              <span class="flex items-center gap-1 text-xs font-mono text-success">
                <.icon name="hero-arrow-up-mini" class="size-3" /> 2.1%
              </span>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">Open Findings</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value">3</span>
              <span class="flex items-center gap-1 text-xs font-mono text-warning">
                <span class="status-dot status-dot--warn status-dot--pulse" /> needs review
              </span>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">Audit Logs</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value">1,247</span>
              <span class="text-xs font-mono text-base-content/30">last 30d</span>
            </div>
          </div>
        </div>

        <div class="dash-card">
          <div class="dash-card-body">
            <p class="metric-label">API Keys</p>
            <div class="mt-2 flex items-baseline gap-2">
              <span class="metric-value">2</span>
              <span class="flex items-center gap-1 text-xs font-mono text-success">
                <span class="status-dot status-dot--ok" /> all active
              </span>
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
            <.activity_row
              icon="hero-shield-check"
              icon_color="text-success"
              title="SOC 2 evidence collected"
              detail="Access control policy reviewed and approved"
              time="2 hours ago"
            />
            <.activity_row
              icon="hero-key"
              icon_color="text-primary"
              title="API key created"
              detail="Production API key — ga_pk_prod_..."
              time="5 hours ago"
            />
            <.activity_row
              icon="hero-exclamation-triangle"
              icon_color="text-warning"
              title="Finding opened"
              detail="Missing encryption at rest for user PII"
              time="1 day ago"
            />
            <.activity_row
              icon="hero-document-check"
              icon_color="text-info"
              title="Policy updated"
              detail="Data retention policy v2.3 published"
              time="2 days ago"
            />
          </div>
        </div>

        <%!-- Quick actions / status panel --%>
        <div class="dash-card">
          <div class="dash-card-header">System Status</div>
          <div class="dash-card-body space-y-4">
            <.status_row label="API" status="operational" />
            <.status_row label="Audit Pipeline" status="operational" />
            <.status_row label="Evidence Store" status="operational" />
            <.status_row label="Webhook Delivery" status="degraded" />
          </div>
          <div class="border-t border-base-300 px-5 py-3">
            <p class="text-[0.625rem] font-mono uppercase tracking-wider text-base-content/30">
              Last checked: 2 min ago
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
              complete={false}
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
              complete={true}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

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

  attr :label, :string, required: true
  attr :status, :string, required: true

  defp status_row(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-xs font-medium text-base-content/60">{@label}</span>
      <div class="flex items-center gap-1.5">
        <span class={[
          "status-dot",
          if(@status == "operational", do: "status-dot--ok", else: "status-dot--warn status-dot--pulse")
        ]} />
        <span class={[
          "text-[0.625rem] font-mono uppercase tracking-wider",
          if(@status == "operational", do: "text-success", else: "text-warning")
        ]}>
          {@status}
        </span>
      </div>
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
