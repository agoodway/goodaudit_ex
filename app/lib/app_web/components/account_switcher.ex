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
            class="flex items-center gap-2 px-2 py-1 rounded hover:bg-base-200 transition-colors group cursor-pointer"
          >
            <div class="flex h-5 w-5 shrink-0 items-center justify-center rounded bg-base-300/80">
              <.icon name="hero-building-office" class="size-3 text-base-content/50" />
            </div>
            <span class="text-xs font-mono font-medium text-base-content/60 truncate max-w-[120px]">
              {@current_account.name}
            </span>
            <.icon
              name="hero-chevron-down-mini"
              class="size-3 text-base-content/30 group-hover:text-base-content/50 transition-colors"
            />
          </button>

          <ul
            tabindex="0"
            class="dropdown-content menu bg-base-100 rounded z-[1] w-56 p-1 shadow-xl ring-1 ring-base-300 mt-1"
          >
            <li class="px-2 py-1.5">
              <span class="font-mono text-[0.6rem] font-semibold uppercase tracking-[0.12em] text-base-content/35 pointer-events-none">
                Your Accounts
              </span>
            </li>
            <%= for {account, _role} <- @accessible_accounts do %>
              <li>
                <.link
                  navigate={~p"/dashboard/accounts/#{account.id}"}
                  class={[
                    "flex items-center justify-between px-2 py-1.5 rounded text-xs font-mono",
                    if(account.id == @current_account.id,
                      do: "bg-primary/8 text-primary",
                      else: "hover:bg-base-200"
                    )
                  ]}
                >
                  <span class="truncate">{account.name}</span>
                  <%= if account.id == @current_account.id do %>
                    <.icon name="hero-check-mini" class="size-3.5 text-primary shrink-0" />
                  <% end %>
                </.link>
              </li>
            <% end %>
          </ul>
        </div>
      <% else %>
        <div class="flex items-center gap-2 px-2 py-1">
          <div class="flex h-5 w-5 shrink-0 items-center justify-center rounded bg-base-300/80">
            <.icon name="hero-building-office" class="size-3 text-base-content/50" />
          </div>
          <span class="text-xs font-mono font-medium text-base-content/60 truncate max-w-[120px]">
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
