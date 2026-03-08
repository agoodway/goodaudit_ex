defmodule GAWeb.ApiKeyLive.Index do
  @moduledoc """
  LiveView for managing API keys scoped to the current user's account membership.
  """
  use GAWeb, :live_view

  alias GA.Accounts
  alias GA.Accounts.ApiKey

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    account = socket.assigns.current_account
    account_user = Accounts.get_account_user(user, account)

    {:ok,
     socket
     |> assign(
       page_title: "API Keys",
       active_nav: :api_keys,
       breadcrumbs: [%{label: "API Keys"}],
       account_user: account_user,
       api_keys: list_keys(account_user),
       show_create_modal: false,
       raw_token: nil,
       form: to_form(ApiKey.changeset(%ApiKey{}, %{})),
       revoke_key_id: nil
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-end justify-between animate-fade-up">
        <div>
          <h1 class="text-lg font-semibold tracking-tight text-base-content">API Keys</h1>
          <p class="mt-0.5 text-xs font-mono text-base-content/40">
            Manage API keys for programmatic access
          </p>
        </div>
        <.button phx-click="show_create_modal" variant="primary">
          <.icon name="hero-plus" class="size-3.5" /> Create Key
        </.button>
      </div>

      <%= if @api_keys == [] do %>
        <.empty_state />
      <% else %>
        <.key_table keys={@api_keys} />
      <% end %>
    </div>

    <.create_key_modal :if={@show_create_modal} form={@form} />
    <.token_display_modal :if={@raw_token} raw_token={@raw_token} />
    <.revoke_confirm_modal :if={@revoke_key_id} />
    """
  end

  # --- Components ---

  defp empty_state(assigns) do
    ~H"""
    <div class="dash-card animate-fade-up animate-delay-1">
      <div class="flex flex-col items-center py-16 px-6">
        <div class="flex h-12 w-12 items-center justify-center rounded bg-base-200/80 mb-4">
          <.icon name="hero-key" class="size-6 text-base-content/20" />
        </div>
        <h3 class="text-sm font-semibold text-base-content/70">No API keys</h3>
        <p class="mt-1 text-xs font-mono text-base-content/40 text-center max-w-xs">
          Create your first API key to start using the GoodAudit API programmatically.
        </p>
        <div class="mt-5">
          <.button phx-click="show_create_modal" variant="primary">
            <.icon name="hero-plus" class="size-3.5" /> Create Key
          </.button>
        </div>
      </div>
    </div>
    """
  end

  attr :keys, :list, required: true

  defp key_table(assigns) do
    ~H"""
    <div class="dash-card overflow-hidden animate-fade-up animate-delay-1">
      <div class="responsive-table">
        <table class="w-full">
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th>Prefix</th>
              <th>Status</th>
              <th>Last Used</th>
              <th>Created</th>
              <th><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={key <- @keys} id={"key-#{key.id}"}>
              <td data-label="Name" class="font-medium text-base-content/80">{key.name}</td>
              <td data-label="Type">
                <.type_badge type={key.type} />
              </td>
              <td data-label="Prefix">
                <code class="text-xs font-mono bg-base-200/80 text-base-content/50 px-1.5 py-0.5 rounded border border-base-300/60">
                  {key.token_prefix}...
                </code>
              </td>
              <td data-label="Status">
                <.status_badge status={key.status} />
              </td>
              <td data-label="Last Used" class="text-xs font-mono text-base-content/40">
                {format_datetime(key.last_used_at) || "Never"}
              </td>
              <td data-label="Created" class="text-xs font-mono text-base-content/40">
                {format_datetime(key.inserted_at)}
              </td>
              <td data-label="" class="table-actions">
                <.button
                  :if={key.status == :active}
                  phx-click="confirm_revoke"
                  phx-value-id={key.id}
                  variant="ghost"
                  class="!text-error !text-[0.6875rem] !px-2 !py-1"
                >
                  Revoke
                </.button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  attr :type, :atom, required: true

  defp type_badge(assigns) do
    ~H"""
    <.badge variant={if @type == :private, do: "warning", else: "info"}>
      {if @type == :private, do: "Private", else: "Public"}
    </.badge>
    """
  end

  attr :status, :atom, required: true

  defp status_badge(assigns) do
    ~H"""
    <.badge variant={if @status == :active, do: "success", else: "error"}>
      <span class={[
        "status-dot",
        if(@status == :active, do: "status-dot--ok", else: "status-dot--error")
      ]} />
      {if @status == :active, do: "Active", else: "Revoked"}
    </.badge>
    """
  end

  attr :form, :map, required: true

  defp create_key_modal(assigns) do
    ~H"""
    <.modal id="create-key-modal" on_cancel={JS.push("hide_create_modal")}>
      <:title>Create API Key</:title>

      <.form for={@form} id="create-key-form" phx-submit="create_key" class="space-y-1">
        <.input
          field={@form[:name]}
          type="text"
          label="Key Name"
          placeholder="e.g. Production API"
          required
        />
        <.input
          field={@form[:type]}
          type="select"
          label="Key Type"
          options={[{"Public (read-only)", :public}, {"Private (read-write)", :private}]}
        />
        <.input field={@form[:expires_at]} type="datetime-local" label="Expiration (optional)" />
      </.form>

      <:actions>
        <.button phx-click="hide_create_modal">Cancel</.button>
        <.button type="submit" form="create-key-form" variant="primary">Create Key</.button>
      </:actions>
    </.modal>
    """
  end

  attr :raw_token, :string, required: true

  defp token_display_modal(assigns) do
    ~H"""
    <.modal id="token-display-modal" on_cancel={JS.push("dismiss_token")}>
      <:title>Your API Key</:title>

      <div class="space-y-4">
        <div class="flex items-start gap-2.5 p-3 rounded border border-warning/30 bg-warning/5">
          <.icon name="hero-exclamation-triangle" class="size-4 text-warning shrink-0 mt-0.5" />
          <p class="text-xs text-base-content/70">
            Copy this key now. You won't be able to see it again.
          </p>
        </div>

        <div class="flex items-center gap-2">
          <input
            id="token-value"
            type="text"
            value={@raw_token}
            readonly
            class="flex-1 px-3 py-2 text-xs font-mono bg-base-200/50 border border-base-300 rounded text-base-content/70"
          />
          <button
            id="copy-token-btn"
            type="button"
            phx-hook=".CopyToClipboard"
            data-copy-target="#token-value"
            class="flex items-center justify-center h-8 w-8 rounded border border-base-300 bg-base-100 hover:bg-base-200 transition-colors cursor-pointer"
            phx-update="ignore"
          >
            <.icon name="hero-clipboard-document" class="size-3.5 text-base-content/50" />
          </button>
        </div>
      </div>

      <:actions>
        <.button phx-click="dismiss_token" variant="primary">Done</.button>
      </:actions>
    </.modal>

    <script :type={Phoenix.LiveView.ColocatedHook} name=".CopyToClipboard">
      export default {
        mounted() {
          this.el.addEventListener("click", () => {
            const target = document.querySelector(this.el.dataset.copyTarget);
            if (target) {
              navigator.clipboard.writeText(target.value).then(() => {
                this.el.classList.add("text-success");
                setTimeout(() => this.el.classList.remove("text-success"), 2000);
              }).catch(() => {
                this.el.classList.add("text-error");
                setTimeout(() => this.el.classList.remove("text-error"), 2000);
              });
            }
          });
        }
      }
    </script>
    """
  end

  defp revoke_confirm_modal(assigns) do
    ~H"""
    <.modal id="revoke-confirm-modal" on_cancel={JS.push("cancel_revoke")}>
      <:title>Revoke API Key</:title>

      <div class="flex items-start gap-2.5 p-3 rounded border border-error/30 bg-error/5">
        <.icon name="hero-exclamation-triangle" class="size-4 text-error shrink-0 mt-0.5" />
        <p class="text-xs text-base-content/70">
          Are you sure you want to revoke this API key? This action cannot be undone.
          Any applications using this key will lose access immediately.
        </p>
      </div>

      <:actions>
        <.button phx-click="cancel_revoke">Cancel</.button>
        <.button phx-click="revoke_key" variant="danger">Revoke Key</.button>
      </:actions>
    </.modal>
    """
  end

  # --- Events ---

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    {:noreply, assign(socket, show_create_modal: true)}
  end

  @impl true
  def handle_event("hide_create_modal", _params, socket) do
    {:noreply,
     assign(socket,
       show_create_modal: false,
       form: to_form(ApiKey.changeset(%ApiKey{}, %{}))
     )}
  end

  @impl true
  def handle_event("create_key", %{"api_key" => params}, socket) do
    account_user = socket.assigns.account_user

    with {:ok, expires_at} <- parse_expires_at(params["expires_at"]) do
      attrs = %{
        name: params["name"],
        type: parse_type(params["type"]),
        expires_at: expires_at
      }

      case Accounts.create_api_key(account_user, attrs) do
        {:ok, {_api_key, token}} ->
          {:noreply,
           socket
           |> assign(
             api_keys: list_keys(account_user),
             raw_token: token,
             show_create_modal: false,
             form: to_form(ApiKey.changeset(%ApiKey{}, %{}))
           )}

        {:error, changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:error, :invalid_date} ->
        {:noreply, put_flash(socket, :error, "Invalid expiration date format.")}
    end
  end

  @impl true
  def handle_event("dismiss_token", _params, socket) do
    {:noreply, assign(socket, raw_token: nil)}
  end

  @impl true
  def handle_event("confirm_revoke", %{"id" => id}, socket) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         true <- Enum.any?(socket.assigns.api_keys, &(&1.id == uuid)) do
      {:noreply, assign(socket, revoke_key_id: uuid)}
    else
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_revoke", _params, socket) do
    {:noreply, assign(socket, revoke_key_id: nil)}
  end

  @impl true
  def handle_event("revoke_key", _params, socket) do
    key = Enum.find(socket.assigns.api_keys, &(&1.id == socket.assigns.revoke_key_id))

    case key do
      nil ->
        {:noreply,
         socket
         |> assign(revoke_key_id: nil)
         |> put_flash(:error, "API key not found.")}

      key ->
        case Accounts.revoke_api_key(key) do
          {:ok, _revoked_key} ->
            {:noreply,
             socket
             |> assign(
               api_keys: list_keys(socket.assigns.account_user),
               revoke_key_id: nil
             )
             |> put_flash(:info, "API key revoked successfully.")}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(revoke_key_id: nil)
             |> put_flash(:error, "Failed to revoke API key.")}
        end
    end
  end

  # --- Helpers ---

  defp list_keys(account_user) do
    account_user
    |> Accounts.list_api_keys()
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
  end

  defp parse_type("private"), do: :private
  defp parse_type(_), do: :public

  defp parse_expires_at(nil), do: {:ok, nil}
  defp parse_expires_at(""), do: {:ok, nil}

  defp parse_expires_at(datetime_string) do
    case NaiveDateTime.from_iso8601(datetime_string) do
      {:ok, naive} -> {:ok, DateTime.from_naive!(naive, "Etc/UTC")}
      _ -> {:error, :invalid_date}
    end
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%b %d, %Y %H:%M")
end
