defmodule GAWeb.Components.AccountSwitcher do
  @moduledoc """
  LiveComponent for the account switcher dropdown in the dashboard header.
  """
  use GAWeb, :live_component

  alias GA.AccountContext

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <%= if @multiple_accounts? do %>
        <div class="dropdown dropdown-end">
          <button
            tabindex="0"
            class="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-base-200 transition-colors group"
          >
            <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/10">
              <.icon name="hero-building-office" class="size-4 text-primary" />
            </div>
            <div class="flex flex-col items-start min-w-0">
              <span class="text-xs font-medium text-base-content/70 truncate max-w-[140px]">
                {@current_account.name}
              </span>
              <span class="text-[10px] text-base-content/40">Switch account</span>
            </div>
            <.icon
              name="hero-chevron-down-mini"
              class="size-4 text-base-content/30 group-hover:text-base-content/50 transition-colors"
            />
          </button>

          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded-lg z-[1] w-64 p-1.5 shadow-xl ring-1 ring-base-300/50 mt-2"
          >
            <li class="px-2 py-1 text-[10px] font-semibold uppercase tracking-wider text-base-content/40">
              Your Accounts
            </li>
            <%= for {account, _role} <- @accessible_accounts do %>
              <li>
                <.link
                  navigate={~p"/dashboard/accounts/#{account.id}"}
                  class={[
                    "flex items-center justify-between px-2 py-2 rounded-md text-sm",
                    if(account.id == @current_account.id,
                      do: "bg-primary/10 text-primary",
                      else: "hover:bg-base-200"
                    )
                  ]}
                >
                  <span class="truncate">{account.name}</span>
                  <%= if account.id == @current_account.id do %>
                    <.icon name="hero-check-mini" class="size-4 text-primary shrink-0" />
                  <% end %>
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      <% else %>
        <div class="flex items-center gap-2 px-3 py-1.5">
          <div class="flex h-7 w-7 shrink-0 items-center justify-center rounded-lg bg-primary/10">
            <.icon name="hero-building-office" class="size-4 text-primary" />
          </div>
          <span class="text-sm font-medium text-base-content/70 truncate max-w-[140px]">
            {@current_account.name}
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if Map.has_key?(socket.assigns, :accessible_accounts) do
      {:ok, socket}
    else
      user = assigns.current_scope.user
      accessible_accounts = AccountContext.list_user_accounts(user)

      {:ok,
       socket
       |> assign(:accessible_accounts, accessible_accounts)
       |> assign(:multiple_accounts?, length(accessible_accounts) > 1)}
    end
  end
end
