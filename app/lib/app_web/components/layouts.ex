defmodule GAWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use GAWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8">
      <div class="flex-1">
        <a href="/" class="flex-1 flex w-fit items-center gap-2">
          <img src={~p"/images/logo.svg"} width="36" />
          <span class="text-sm font-semibold">v{Application.spec(:phoenix, :vsn)}</span>
        </a>
      </div>
      <div class="flex-none">
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li>
            <a href="https://phoenixframework.org/" class="btn btn-ghost">Website</a>
          </li>
          <li>
            <a href="https://github.com/phoenixframework/phoenix" class="btn btn-ghost">GitHub</a>
          </li>
          <li>
            <.theme_toggle />
          </li>
          <li>
            <a href="https://hexdocs.pm/phoenix/overview.html" class="btn btn-primary">
              Get Started <span aria-hidden="true">&rarr;</span>
            </a>
          </li>
        </ul>
      </div>
    </header>

    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  # --- Sidebar ---

  attr :active_nav, :atom, required: true
  attr :current_scope, :map, required: true
  attr :current_account, :map, default: nil

  def sidebar_content(assigns) do
    assigns = assign(assigns, :account_base, account_dashboard_path(assigns[:current_account]))

    ~H"""
    <%!-- Brand --%>
    <div class="flex h-14 shrink-0 items-center gap-3 px-5 border-b border-white/[0.06]">
      <.link href={~p"/dashboard"} class="flex items-center gap-3 group">
        <div class="flex h-7 w-7 items-center justify-center rounded bg-emerald-500/20 border border-emerald-400/30">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="none" class="text-emerald-400">
            <path
              d="M2 4h10M2 7h7M2 10h5"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
            />
          </svg>
        </div>
        <span class="font-mono text-xs font-bold tracking-wider text-white/80 uppercase group-hover:text-white transition-colors">
          GoodAudit
        </span>
      </.link>
    </div>

    <%!-- Navigation --%>
    <nav class="flex flex-1 flex-col px-3 py-5">
      <ul role="list" class="flex flex-1 flex-col gap-y-6">
        <li>
          <p class="px-2 mb-2 font-mono text-[0.6rem] font-semibold uppercase tracking-[0.15em] text-white/25">
            Overview
          </p>
          <ul role="list" class="space-y-0.5">
            <.sidebar_nav_item
              href={@account_base}
              icon="hero-squares-2x2"
              label="Dashboard"
              active={@active_nav == :dashboard}
            />
            <.sidebar_nav_item
              href={~p"/dashboard/accounts/#{@current_account}/audit-logs"}
              icon="hero-document-text"
              label="Audit Logs"
              active={@active_nav == :audit_logs}
            />
          </ul>
        </li>

        <li>
          <p class="px-2 mb-2 font-mono text-[0.6rem] font-semibold uppercase tracking-[0.15em] text-white/25">
            Developers
          </p>
          <ul role="list" class="space-y-0.5">
            <.sidebar_nav_item
              href={"#{@account_base}/api-keys"}
              icon="hero-key"
              label="API Keys"
              active={@active_nav == :api_keys}
            />
          </ul>
        </li>

        <li>
          <p class="px-2 mb-2 font-mono text-[0.6rem] font-semibold uppercase tracking-[0.15em] text-white/25">
            Configuration
          </p>
          <ul role="list" class="space-y-0.5">
            <.sidebar_nav_item
              href={~p"/dashboard/accounts/#{@current_account}/compliance"}
              icon="hero-shield-check"
              label="Compliance"
              active={@active_nav == :compliance}
            />
          </ul>
        </li>

        <%!-- Bottom section --%>
        <li class="mt-auto">
          <ul role="list" class="space-y-0.5">
            <.sidebar_nav_item
              href={~p"/users/settings"}
              icon="hero-cog-6-tooth"
              label="Settings"
              active={@active_nav == :settings}
            />
          </ul>

          <%!-- User info --%>
          <div class="mt-4 pt-4 border-t border-white/[0.06]">
            <div class="flex items-center gap-2.5 px-2 py-1.5">
              <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded bg-white/[0.07] text-[0.65rem] font-mono font-bold text-white/50 border border-white/[0.08]">
                {String.first(@current_scope.user.email) |> String.upcase()}
              </div>
              <div class="min-w-0 flex-1">
                <p class="truncate text-xs text-white/50 font-mono">
                  {@current_scope.user.email}
                </p>
              </div>
            </div>
          </div>
        </li>
      </ul>
    </nav>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true
  attr :active, :boolean, default: false

  def sidebar_nav_item(assigns) do
    ~H"""
    <li>
      <.link
        href={@href}
        class={[
          "group flex items-center gap-x-2.5 rounded px-2 py-1.5 text-[0.8125rem] font-medium transition-colors",
          if(@active,
            do:
              "bg-white/[0.08] text-white border-l-2 border-emerald-400 -ml-px pl-[calc(0.5rem-1px)]",
            else: "text-white/50 hover:bg-white/[0.04] hover:text-white/70"
          )
        ]}
      >
        <.icon
          name={@icon}
          class={[
            "size-[1.125rem] shrink-0",
            if(@active,
              do: "text-emerald-400",
              else: "text-white/25 group-hover:text-white/50"
            )
          ]}
        />
        {@label}
      </.link>
    </li>
    """
  end

  # --- Mobile Sidebar JS ---

  @doc false
  def show_mobile_sidebar do
    JS.show(
      to: "#mobile-sidebar-backdrop",
      transition: {"transition-opacity ease-linear duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#mobile-sidebar-overlay",
      transition: {"transition-opacity ease-linear duration-300", "opacity-0", "opacity-100"}
    )
    |> JS.show(
      to: "#mobile-sidebar-panel",
      transition:
        {"transition ease-in-out duration-300 transform", "-translate-x-full", "translate-x-0"}
    )
    |> JS.focus_first(to: "#mobile-sidebar-panel")
  end

  @doc false
  def hide_mobile_sidebar do
    JS.hide(
      to: "#mobile-sidebar-panel",
      transition:
        {"transition ease-in-out duration-300 transform", "translate-x-0", "-translate-x-full"}
    )
    |> JS.hide(
      to: "#mobile-sidebar-overlay",
      transition: {"transition-opacity ease-linear duration-300", "opacity-100", "opacity-0"}
    )
    |> JS.hide(
      to: "#mobile-sidebar-backdrop",
      transition: {"transition-opacity ease-linear duration-300", "opacity-100", "opacity-0"},
      time: 300
    )
  end

  # --- Theme Toggle ---

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="flex items-center gap-0.5 rounded border border-base-300 bg-base-200/50 p-0.5">
      <button
        class="flex items-center justify-center h-6 w-6 rounded-sm cursor-pointer transition-all hover:bg-base-300 [[data-theme=light]_&]:bg-base-100 [[data-theme=light]_&]:shadow-sm"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Light theme"
      >
        <.icon name="hero-sun-micro" class="size-3.5 text-base-content/50" />
      </button>

      <button
        class="flex items-center justify-center h-6 w-6 rounded-sm cursor-pointer transition-all hover:bg-base-300"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="System theme"
      >
        <.icon name="hero-computer-desktop-micro" class="size-3.5 text-base-content/50" />
      </button>

      <button
        class="flex items-center justify-center h-6 w-6 rounded-sm cursor-pointer transition-all hover:bg-base-300 [[data-theme=dark]_&]:bg-base-100 [[data-theme=dark]_&]:shadow-sm"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Dark theme"
      >
        <.icon name="hero-moon-micro" class="size-3.5 text-base-content/50" />
      </button>
    </div>
    """
  end

  defp account_dashboard_path(nil), do: "/dashboard"
  defp account_dashboard_path(account), do: "/dashboard/accounts/#{account.id}"
end
