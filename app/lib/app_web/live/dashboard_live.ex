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
      <div class="flex items-end justify-between">
        <div>
          <h1 class="text-xl font-bold tracking-tight text-base-content">{@current_account.name}</h1>
          <p class="mt-0.5 text-sm text-base-content/50">
            Welcome to your dashboard.
          </p>
        </div>
      </div>

      <div class="rounded-xl border border-base-300/60 bg-base-100">
        <div class="flex items-center justify-between border-b border-base-300/40 px-5 py-3.5">
          <h2 class="text-sm font-semibold text-base-content">Getting Started</h2>
        </div>
        <div class="p-5">
          <p class="text-sm text-base-content/60">Your dashboard is ready. Start building!</p>
        </div>
      </div>
    </div>
    """
  end
end
