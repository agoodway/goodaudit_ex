defmodule GAWeb.SettingsLive.SecurityComponent do
  use GAWeb, :live_component

  require Logger

  alias GA.Accounts

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:hmac_revealed, fn -> false end)
     |> assign_new(:hmac_key, fn -> nil end)
     |> assign_new(:show_rotate_modal, fn -> false end)
     |> assign_new(:rotate_confirmation, fn -> "" end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="security-settings" class="space-y-6">
      <%!-- HMAC Key Section --%>
      <div class="space-y-3">
        <h3 class="text-sm font-semibold text-base-content">HMAC Signing Key</h3>
        <div class="flex items-center gap-3">
          <code id="hmac-key-display" class="text-sm font-mono bg-base-200 px-3 py-1.5 rounded select-all">
            <%= if @hmac_revealed do %>
              {Base.encode16(@hmac_key, case: :lower)}
            <% else %>
              hmac_••••••••
            <% end %>
          </code>

          <%= if @hmac_revealed do %>
            <button
              type="button"
              class="btn btn-ghost btn-xs"
              phx-click={JS.dispatch("phx:copy", to: "#hmac-key-display")}
              title="Copy to clipboard"
            >
              <.icon name="hero-clipboard-document" class="size-4" />
            </button>
            <button class="btn btn-ghost btn-xs" phx-click="hide_hmac" phx-target={@myself}>
              Hide
            </button>
          <% else %>
            <button class="btn btn-ghost btn-xs" phx-click="reveal_hmac" phx-target={@myself}>
              Reveal
            </button>
          <% end %>

          <button
            class="btn btn-warning btn-xs"
            phx-click="show_rotate_modal"
            phx-target={@myself}
          >
            Rotate Key
          </button>
        </div>
      </div>

      <%!-- Account Status --%>
      <div class="space-y-3">
        <h3 class="text-sm font-semibold text-base-content">Account Status</h3>
        <.status_badge status={@account.status} />
      </div>

      <%!-- Rotate Key Modal --%>
      <div
        :if={@show_rotate_modal}
        class="modal modal-open"
        phx-window-keydown="close_rotate_modal"
        phx-key="Escape"
        phx-target={@myself}
      >
        <div class="modal-box">
          <h3 class="text-lg font-bold text-warning">Rotate HMAC Key</h3>
          <div class="py-4 space-y-3">
            <div class="alert alert-warning">
              <.icon name="hero-exclamation-triangle" class="size-5" />
              <span class="text-sm">
                Rotating the HMAC key will break chain verification for all existing audit log entries.
                This action cannot be undone.
              </span>
            </div>
            <p class="text-sm text-base-content/70">
              Type <strong>ROTATE</strong> to confirm:
            </p>
            <input
              type="text"
              class="input input-bordered w-full"
              phx-keyup="update_rotate_confirmation"
              phx-target={@myself}
              value={@rotate_confirmation}
              autocomplete="off"
            />
          </div>
          <div class="modal-action">
            <button class="btn btn-ghost" phx-click="close_rotate_modal" phx-target={@myself}>
              Cancel
            </button>
            <button
              class="btn btn-warning"
              phx-click="confirm_rotate"
              phx-target={@myself}
              disabled={@rotate_confirmation != "ROTATE"}
            >
              Rotate Key
            </button>
          </div>
        </div>
        <div class="modal-backdrop" phx-click="close_rotate_modal" phx-target={@myself}></div>
      </div>
    </div>
    """
  end

  defp status_badge(assigns) do
    {color, label} = case assigns.status do
      :active -> {"badge-success", "Active"}
      :suspended -> {"badge-error", "Suspended"}
      _ -> {"badge-ghost", to_string(assigns.status)}
    end

    assigns = assign(assigns, color: color, label: label)

    ~H"""
    <span class={"badge #{@color}"}>{@label}</span>
    """
  end

  @impl true
  def handle_event("reveal_hmac", _params, socket)
      when socket.assigns.role == :owner do
    if Accounts.sudo_mode?(socket.assigns.current_user) do
      case Accounts.get_hmac_key(socket.assigns.account.id) do
        {:ok, key} ->
          {:noreply, assign(socket, hmac_revealed: true, hmac_key: key)}

        {:error, reason} ->
          Logger.error("Failed to retrieve HMAC key", account_id: socket.assigns.account.id, error: inspect(reason))
          {:noreply, put_flash(socket, :error, "Failed to retrieve HMAC key.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please re-authenticate to perform this action.")}
    end
  end

  @impl true
  def handle_event("hide_hmac", _params, socket) do
    {:noreply, assign(socket, hmac_revealed: false, hmac_key: nil)}
  end

  @impl true
  def handle_event("show_rotate_modal", _params, socket)
      when socket.assigns.role == :owner do
    {:noreply, assign(socket, show_rotate_modal: true, rotate_confirmation: "")}
  end

  @impl true
  def handle_event("close_rotate_modal", _params, socket) do
    {:noreply, assign(socket, show_rotate_modal: false, rotate_confirmation: "")}
  end

  @impl true
  def handle_event("update_rotate_confirmation", %{"value" => value}, socket) do
    {:noreply, assign(socket, rotate_confirmation: value)}
  end

  @impl true
  def handle_event("confirm_rotate", _params, socket)
      when socket.assigns.role == :owner do
    if not Accounts.sudo_mode?(socket.assigns.current_user) do
      {:noreply, put_flash(socket, :error, "Please re-authenticate to perform this action.")}
    else
      if socket.assigns.rotate_confirmation == "ROTATE" do
        case Accounts.rotate_hmac_key(socket.assigns.account) do
          {:ok, _account} ->
            {:noreply,
             socket
             |> assign(show_rotate_modal: false, rotate_confirmation: "", hmac_revealed: false, hmac_key: nil)
             |> put_flash(:info, "HMAC key rotated successfully.")}

          {:error, reason} ->
            Logger.error("Failed to rotate HMAC key", account_id: socket.assigns.account.id, error: inspect(reason))
            {:noreply, put_flash(socket, :error, "Failed to rotate HMAC key.")}
        end
      else
        {:noreply, socket}
      end
    end
  end

  # Catch-all for unauthorized actions
  def handle_event(event, _params, socket)
      when event in ["reveal_hmac", "show_rotate_modal", "confirm_rotate"] do
    {:noreply, put_flash(socket, :error, "You are not authorized to perform this action.")}
  end
end
