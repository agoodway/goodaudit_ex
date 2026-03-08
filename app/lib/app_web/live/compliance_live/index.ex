defmodule GAWeb.ComplianceLive.Index do
  @moduledoc """
  LiveView for managing account-scoped compliance framework settings.
  Displays framework cards with activation toggles and configuration panels.
  """
  use GAWeb, :live_view

  alias GA.Accounts
  alias GA.Accounts.AccountUser
  alias GA.Compliance

  @impl true
  def mount(_params, _session, socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_scope.user
    membership = Accounts.get_account_user(user, account)
    can_edit? = membership != nil and AccountUser.admin?(membership)

    frameworks = load_frameworks(account.id)

    {:ok,
     assign(socket,
       page_title: "Compliance Frameworks",
       active_nav: :compliance,
       breadcrumbs: [%{label: "Compliance"}],
       can_edit?: can_edit?,
       frameworks: frameworks
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="compliance-settings" class="space-y-6">
      <%!-- Page header --%>
      <div class="animate-fade-up">
        <h1 class="text-lg font-semibold tracking-tight text-base-content">
          Compliance Frameworks
        </h1>
        <p class="mt-0.5 text-xs font-mono text-base-content/40">
          Manage which compliance standards are enforced for this account
        </p>
      </div>

      <%!-- Framework cards grid --%>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <.live_component
          :for={{framework_id, framework_module} <- sorted_registry()}
          module={GAWeb.ComplianceLive.FrameworkCardComponent}
          id={"framework-#{framework_id}"}
          framework_id={framework_id}
          framework_module={framework_module}
          association={Map.get(@frameworks, framework_id)}
          can_edit?={@can_edit?}
          account_id={@current_account.id}
          current_user={@current_scope.user}
          current_account={@current_account}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:framework_updated, framework_id, nil}, socket) do
    frameworks = Map.delete(socket.assigns.frameworks, framework_id)
    {:noreply, assign(socket, frameworks: frameworks)}
  end

  @impl true
  def handle_info({:framework_updated, framework_id, association}, socket) do
    frameworks = Map.put(socket.assigns.frameworks, framework_id, association)
    {:noreply, assign(socket, frameworks: frameworks)}
  end

  defp load_frameworks(account_id) do
    Compliance.list_active_frameworks(account_id)
    |> Map.new(&{&1.framework, &1})
  end

  defp sorted_registry do
    Compliance.registry()
    |> Enum.sort_by(fn {_id, mod} -> mod.name() end)
  end
end
