defmodule GAWeb.SettingsLive.GeneralComponent do
  @moduledoc false

  use GAWeb, :live_component

  alias GA.Accounts

  @impl true
  def update(assigns, socket) do
    account = assigns.account
    changeset = Accounts.Account.changeset(account, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(form: to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="general-settings" class="space-y-6">
      <.form for={@form} phx-submit="save_name" phx-change="validate_name" phx-target={@myself}>
        <div class="space-y-4">
          <div>
            <label class="label" for="account_name">Account Name</label>
            <input
              type="text"
              id="account_name"
              name="account[name]"
              value={@form[:name].value}
              class="input input-bordered w-full max-w-md"
              phx-debounce="300"
              disabled={@role not in [:owner, :admin]}
            />
            <p
              :for={msg <- Enum.map(@form[:name].errors, &translate_error/1)}
              class="text-sm text-error mt-1"
            >
              {msg}
            </p>
            <p
              :for={msg <- Enum.map(@form[:slug].errors, &translate_error/1)}
              class="text-sm text-error mt-1"
            >
              Slug {msg}
            </p>
          </div>

          <div>
            <label class="label">Slug</label>
            <p class="text-sm font-mono text-base-content/60">{@account.slug}</p>
          </div>

          <div>
            <label class="label">Account ID</label>
            <div class="flex items-center gap-2">
              <code
                id="account-id-display"
                class="text-sm font-mono bg-base-200 px-3 py-1.5 rounded select-all"
              >
                {@account.id}
              </code>
              <button
                type="button"
                phx-click={JS.dispatch("phx:copy", to: "#account-id-display")}
                class="btn btn-ghost btn-xs"
                title="Copy to clipboard"
              >
                <.icon name="hero-clipboard-document" class="size-4" />
              </button>
            </div>
          </div>

          <div :if={@role in [:owner, :admin]}>
            <button type="submit" class="btn btn-primary btn-sm">
              Save Changes
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate_name", %{"account" => attrs}, socket) do
    changeset =
      socket.assigns.account
      |> Accounts.Account.changeset(attrs)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save_name", %{"account" => attrs}, socket)
      when socket.assigns.role in [:owner, :admin] do
    case Accounts.update_account(socket.assigns.account, attrs) do
      {:ok, account} ->
        send(self(), {:account_updated, account})

        {:noreply,
         socket
         |> assign(account: account, form: to_form(Accounts.Account.changeset(account, %{})))
         |> put_flash(:info, "Account updated successfully.")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("save_name", _params, socket) do
    {:noreply, put_flash(socket, :error, "You are not authorized to perform this action.")}
  end
end
