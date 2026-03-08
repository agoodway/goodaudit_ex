defmodule GAWeb.SettingsLive.DangerZoneComponent do
  @moduledoc false

  use GAWeb, :live_component

  require Logger

  alias GA.Accounts

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:show_delete_modal, fn -> false end)
     |> assign_new(:delete_confirmation, fn -> "" end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="danger-zone" class="border-2 border-error/30 rounded-lg p-6 space-y-4">
      <h3 class="text-sm font-semibold text-error">Danger Zone</h3>
      <p class="text-sm text-base-content/60">
        Deleting this account is permanent and cannot be undone. All data, members, and API keys will be removed.
      </p>
      <button
        class="btn btn-error btn-sm"
        phx-click="show_delete_modal"
        phx-target={@myself}
      >
        Delete Account
      </button>

      <%!-- Delete Confirmation Modal --%>
      <div
        :if={@show_delete_modal}
        class="modal modal-open"
        phx-window-keydown="close_delete_modal"
        phx-key="Escape"
        phx-target={@myself}
      >
        <div class="modal-box">
          <h3 class="text-lg font-bold text-error">Delete Account</h3>
          <div class="py-4 space-y-3">
            <div class="alert alert-error">
              <.icon name="hero-exclamation-triangle" class="size-5" />
              <span class="text-sm">
                This action is permanent and cannot be undone. All account data will be deleted.
              </span>
            </div>
            <p class="text-sm text-base-content/70">
              Type <strong>{@account.name}</strong> to confirm:
            </p>
            <input
              type="text"
              class="input input-bordered w-full"
              phx-keyup="update_delete_confirmation"
              phx-target={@myself}
              value={@delete_confirmation}
              autocomplete="off"
            />
          </div>
          <div class="modal-action">
            <button class="btn btn-ghost" phx-click="close_delete_modal" phx-target={@myself}>
              Cancel
            </button>
            <button
              class="btn btn-error"
              phx-click="confirm_delete"
              phx-target={@myself}
              disabled={@delete_confirmation != @account.name}
            >
              Delete Account
            </button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_delete_modal" phx-target={@myself}></div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("show_delete_modal", _params, socket)
      when socket.assigns.role == :owner do
    {:noreply, assign(socket, show_delete_modal: true, delete_confirmation: "")}
  end

  @impl true
  def handle_event("close_delete_modal", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false, delete_confirmation: "")}
  end

  @impl true
  def handle_event("update_delete_confirmation", %{"value" => value}, socket) do
    {:noreply, assign(socket, delete_confirmation: value)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket)
      when socket.assigns.role == :owner do
    if Accounts.sudo_mode?(socket.assigns.current_user) do
      confirm_delete(socket)
    else
      {:noreply, put_flash(socket, :error, "Please re-authenticate to perform this action.")}
    end
  end

  # Catch-all for unauthorized actions
  def handle_event(event, _params, socket)
      when event in ["show_delete_modal", "confirm_delete"] do
    {:noreply, put_flash(socket, :error, "You are not authorized to perform this action.")}
  end

  defp confirm_delete(
         %{assigns: %{delete_confirmation: confirmation, account: %{name: name}}} = socket
       )
       when confirmation == name do
    case Accounts.delete_account(socket.assigns.account) do
      {:ok, _} ->
        send(self(), :account_deleted)
        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to delete account",
          account_id: socket.assigns.account.id,
          error: inspect(reason)
        )

        {:noreply, put_flash(socket, :error, "Failed to delete account.")}
    end
  end

  defp confirm_delete(socket), do: {:noreply, socket}
end
