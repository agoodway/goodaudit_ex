defmodule GAWeb.SettingsLive.Index do
  use GAWeb, :live_view

  alias GA.Accounts

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_scope.user
    membership = Accounts.get_account_user(user, account)

    if membership do
      {:ok,
       assign(socket,
         page_title: "Settings",
         active_nav: :settings,
         breadcrumbs: [%{label: "Settings"}],
         role: membership.role,
         membership: membership,
         members: load_members(account, membership.role)
       )}
    else
      {:ok,
       socket
       |> put_flash(:error, "You do not have access to this account.")
       |> redirect(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    tab = socket.assigns.live_action
    role = socket.assigns.role

    if tab_allowed?(tab, role) do
      {:noreply, assign(socket, active_tab: tab)}
    else
      account = socket.assigns.current_account

      {:noreply,
       socket
       |> put_flash(:info, "You don't have access to that section.")
       |> push_patch(to: ~p"/dashboard/accounts/#{account}/settings")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="account-settings" class="space-y-6">
      <div class="animate-fade-up">
        <h1 class="text-lg font-semibold tracking-tight text-base-content">
          Account Settings
        </h1>
        <p class="mt-0.5 text-xs font-mono text-base-content/40">
          Manage your account configuration
        </p>
      </div>

      <%!-- Tabbed navigation --%>
      <div class="border-b border-base-300">
        <nav class="-mb-px flex space-x-6" aria-label="Tabs">
          <.tab_link
            label="General"
            tab={:general}
            active={@active_tab == :general}
            account={@current_account}
          />
          <.tab_link
            :if={@role in [:owner, :admin]}
            label="Members"
            tab={:members}
            active={@active_tab == :members}
            account={@current_account}
          />
          <.tab_link
            :if={@role == :owner}
            label="Security"
            tab={:security}
            active={@active_tab == :security}
            account={@current_account}
          />
        </nav>
      </div>

      <%!-- Active tab content --%>
      <div class="animate-fade-up" style="animation-delay: 100ms">
        <.live_component
          :if={@active_tab == :general}
          module={GAWeb.SettingsLive.GeneralComponent}
          id="settings-general"
          account={@current_account}
          role={@role}
        />
        <.live_component
          :if={@active_tab == :members}
          module={GAWeb.SettingsLive.MembersComponent}
          id="settings-members"
          account={@current_account}
          role={@role}
          members={@members}
          current_user={@current_scope.user}
        />
        <.live_component
          :if={@active_tab == :security}
          module={GAWeb.SettingsLive.SecurityComponent}
          id="settings-security"
          account={@current_account}
          role={@role}
          current_user={@current_scope.user}
        />
      </div>

      <%!-- Danger Zone --%>
      <.live_component
        :if={@role == :owner}
        module={GAWeb.SettingsLive.DangerZoneComponent}
        id="settings-danger-zone"
        account={@current_account}
        role={@role}
        current_user={@current_scope.user}
      />
    </div>
    """
  end

  defp tab_link(assigns) do
    path = case assigns.tab do
      :general -> ~p"/dashboard/accounts/#{assigns.account}/settings"
      :members -> ~p"/dashboard/accounts/#{assigns.account}/settings/members"
      :security -> ~p"/dashboard/accounts/#{assigns.account}/settings/security"
    end

    assigns = assign(assigns, :path, path)

    ~H"""
    <.link
      patch={@path}
      class={[
        "whitespace-nowrap border-b-2 py-3 px-1 text-sm font-medium transition-colors",
        if(@active,
          do: "border-emerald-500 text-emerald-600",
          else: "border-transparent text-base-content/50 hover:border-base-300 hover:text-base-content/70"
        )
      ]}
    >
      {@label}
    </.link>
    """
  end

  @impl true
  def handle_info({:account_updated, account}, socket) do
    {:noreply, assign(socket, current_account: account)}
  end

  @impl true
  def handle_info(:members_updated, socket) do
    members = load_members(socket.assigns.current_account, socket.assigns.role)
    {:noreply, assign(socket, members: members)}
  end

  @impl true
  def handle_info(:account_deleted, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "Account deleted successfully.")
     |> redirect(to: ~p"/dashboard")}
  end

  defp tab_allowed?(:general, _role), do: true
  defp tab_allowed?(:members, role), do: role in [:owner, :admin]
  defp tab_allowed?(:security, role), do: role == :owner
  defp tab_allowed?(_, _), do: false

  defp load_members(account, role) when role in [:owner, :admin] do
    Accounts.list_account_members(account)
  end

  defp load_members(_account, _role), do: []
end
