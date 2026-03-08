defmodule GAWeb.ComplianceLive.FrameworkCardComponent do
  @moduledoc """
  LiveComponent for rendering a single compliance framework card with
  activation toggle and expandable settings panel.
  """
  use GAWeb, :live_component

  alias GA.Accounts
  alias GA.Accounts.AccountUser
  alias GA.Compliance

  @impl true
  def update(assigns, socket) do
    old_updated_at = socket.assigns[:association_updated_at]

    new_updated_at =
      case assigns[:association] do
        nil -> nil
        assoc -> assoc.updated_at
      end

    association_changed? = old_updated_at != new_updated_at

    socket = assign(socket, assigns)
    socket = assign(socket, association_updated_at: new_updated_at)

    socket =
      if not Map.has_key?(socket.assigns, :form_data) or association_changed? do
        assign(socket, form_data: initial_form_data(assigns[:association] || socket.assigns[:association]), dirty?: false)
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="dash-card animate-fade-up">
      <%!-- Card header --%>
      <div class="dash-card-header flex items-center justify-between">
        <div class="flex items-center gap-3">
          <span class="font-semibold text-sm text-base-content">{@framework_module.name()}</span>
          <.badge :if={@association} variant="success">Active</.badge>
          <.badge :if={!@association} variant={nil}>Inactive</.badge>
        </div>
        <div :if={@can_edit?}>
          <input
            type="checkbox"
            class="toggle toggle-success toggle-sm"
            checked={@association != nil}
            phx-click="toggle_framework"
            phx-target={@myself}
            data-confirm={if @association, do: "Deactivating will remove this framework's configuration. Continue?"}
          />
        </div>
        <div :if={!@can_edit?}>
          <span :if={@association} class="text-xs font-mono text-success">Enabled</span>
          <span :if={!@association} class="text-xs font-mono text-base-content/40">Disabled</span>
        </div>
      </div>

      <%!-- Settings panel (only for active frameworks) --%>
      <div :if={@association && @can_edit?} class="dash-card-body space-y-4">
        <div>
          <label class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
            Validation Mode
          </label>
          <select
            class="select select-bordered select-sm w-full font-mono text-xs"
            phx-change="update_field"
            phx-target={@myself}
            name="action_validation_mode"
          >
            <option value="flexible" selected={@form_data.action_validation_mode == "flexible"}>
              Flexible — allows any action string
            </option>
            <option value="strict" selected={@form_data.action_validation_mode == "strict"}>
              Strict — rejects unrecognized actions
            </option>
          </select>
          <p :if={@form_data.action_validation_mode == "strict"} class="mt-1 text-[0.625rem] font-mono text-warning/70">
            Strict mode rejects audit log entries with actions not recognized by this framework's
            event taxonomy or your custom action mappings.
          </p>
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          <div>
            <label class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
              Retention Days
            </label>
            <input
              type="number"
              name="retention_days"
              value={@form_data.retention_days}
              placeholder={to_string(@framework_module.default_retention_days())}
              min="1"
              phx-change="update_field"
              phx-target={@myself}
              class="input input-bordered input-sm w-full font-mono text-xs"
            />
          </div>
          <div>
            <label class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
              Verification Cadence (hours)
            </label>
            <input
              type="number"
              name="verification_cadence_hours"
              value={@form_data.verification_cadence_hours}
              placeholder={to_string(@framework_module.verification_cadence_hours())}
              min="1"
              phx-change="update_field"
              phx-target={@myself}
              class="input input-bordered input-sm w-full font-mono text-xs"
            />
          </div>
        </div>

        <div>
          <label class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
            Additional Required Fields
          </label>
          <input
            type="text"
            name="additional_required_fields"
            value={@form_data.additional_required_fields}
            placeholder="comma-separated field names"
            phx-change="update_field"
            phx-target={@myself}
            class="input input-bordered input-sm w-full font-mono text-xs"
          />
        </div>

        <div class="flex justify-end">
          <.button
            phx-click="save"
            phx-target={@myself}
            variant="primary"
            disabled={!@dirty?}
          >
            Save
          </.button>
        </div>
      </div>

      <%!-- Read-only settings panel --%>
      <div :if={@association && !@can_edit?} class="dash-card-body space-y-3">
        <div class="grid grid-cols-2 gap-3">
          <div>
            <span class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 block mb-0.5">
              Validation Mode
            </span>
            <span class="text-sm text-base-content/70 capitalize">{@association.action_validation_mode}</span>
          </div>
          <div>
            <span class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 block mb-0.5">
              Retention Days
            </span>
            <span class="text-sm text-base-content/70">
              {Map.get(@association.config_overrides || %{}, "retention_days", @framework_module.default_retention_days())}
            </span>
          </div>
          <div>
            <span class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 block mb-0.5">
              Verification Cadence
            </span>
            <span class="text-sm text-base-content/70">
              {Map.get(@association.config_overrides || %{}, "verification_cadence_hours", @framework_module.verification_cadence_hours())} hours
            </span>
          </div>
          <div>
            <span class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 block mb-0.5">
              Additional Fields
            </span>
            <span class="text-sm text-base-content/70">
              {display_additional_fields(@association.config_overrides)}
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_framework", _params, socket) do
    if not authorized?(socket) do
      {:noreply, put_flash(socket, :error, "You don't have permission to modify frameworks.")}
    else
      handle_toggle(socket)
    end
  end

  @impl true
  def handle_event("update_field", _params, socket) when not socket.assigns.can_edit? do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_field", params, socket) do
    form_data = update_form_data(socket.assigns.form_data, params)
    original = initial_form_data(socket.assigns.association)
    dirty? = form_data != original

    {:noreply, assign(socket, form_data: form_data, dirty?: dirty?)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    if not authorized?(socket) do
      {:noreply, put_flash(socket, :error, "You don't have permission to modify frameworks.")}
    else
      handle_save(socket)
    end
  end

  defp handle_toggle(%{assigns: %{association: nil}} = socket) do
    account_id = socket.assigns.account_id
    framework_id = socket.assigns.framework_id

    case Compliance.activate_framework(account_id, framework_id) do
      {:ok, association} ->
        send(self(), {:framework_updated, framework_id, association})

        {:noreply,
         socket
         |> assign(association: association, form_data: initial_form_data(association), dirty?: false)
         |> put_flash(:info, "#{socket.assigns.framework_module.name()} activated.")}

      {:error, changeset} ->
        msg = changeset_error_message(changeset)

        {:noreply, put_flash(socket, :error, "Failed to activate: #{msg}")}
    end
  end

  defp handle_toggle(socket) do
    account_id = socket.assigns.account_id
    framework_id = socket.assigns.framework_id

    case Compliance.deactivate_framework(account_id, framework_id) do
      {:ok, _} ->
        send(self(), {:framework_updated, framework_id, nil})

        {:noreply,
         socket
         |> assign(association: nil, form_data: initial_form_data(nil), dirty?: false)
         |> put_flash(:info, "#{socket.assigns.framework_module.name()} deactivated.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Framework not found.")}
    end
  end

  defp handle_save(socket) do
    account_id = socket.assigns.account_id
    framework_id = socket.assigns.framework_id
    form_data = socket.assigns.form_data

    config_overrides = build_config_overrides(form_data)

    attrs = %{
      action_validation_mode: form_data.action_validation_mode,
      config_overrides: config_overrides
    }

    case Compliance.update_framework_config(account_id, framework_id, attrs) do
      {:ok, association} ->
        send(self(), {:framework_updated, framework_id, association})

        {:noreply,
         socket
         |> assign(association: association, form_data: initial_form_data(association), dirty?: false)
         |> put_flash(:info, "#{socket.assigns.framework_module.name()} settings saved.")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Framework not found.")}

      {:error, changeset} ->
        msg = changeset_error_message(changeset)
        {:noreply, put_flash(socket, :error, "Failed to save: #{msg}")}
    end
  end

  defp initial_form_data(nil) do
    %{
      action_validation_mode: "flexible",
      retention_days: "",
      verification_cadence_hours: "",
      additional_required_fields: ""
    }
  end

  defp initial_form_data(association) do
    overrides = association.config_overrides || %{}

    %{
      action_validation_mode: association.action_validation_mode || "flexible",
      retention_days: override_value(overrides, "retention_days"),
      verification_cadence_hours: override_value(overrides, "verification_cadence_hours"),
      additional_required_fields: override_list_value(overrides, "additional_required_fields")
    }
  end

  defp override_value(overrides, key) do
    case Map.get(overrides, key) do
      nil -> ""
      value -> to_string(value)
    end
  end

  defp override_list_value(overrides, key) do
    case Map.get(overrides, key) do
      nil -> ""
      list when is_list(list) -> Enum.join(list, ", ")
      _ -> ""
    end
  end

  defp update_form_data(form_data, params) do
    Enum.reduce(params, form_data, fn
      {"action_validation_mode", value}, acc -> %{acc | action_validation_mode: value}
      {"retention_days", value}, acc -> %{acc | retention_days: value}
      {"verification_cadence_hours", value}, acc -> %{acc | verification_cadence_hours: value}
      {"additional_required_fields", value}, acc -> %{acc | additional_required_fields: value}
      _, acc -> acc
    end)
  end

  defp build_config_overrides(form_data) do
    %{}
    |> maybe_put_integer("retention_days", form_data.retention_days)
    |> maybe_put_integer("verification_cadence_hours", form_data.verification_cadence_hours)
    |> maybe_put_field_list("additional_required_fields", form_data.additional_required_fields)
  end

  defp maybe_put_integer(map, _key, ""), do: map
  defp maybe_put_integer(map, _key, nil), do: map

  defp maybe_put_integer(map, key, value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> Map.put(map, key, int)
      _ -> map
    end
  end

  defp maybe_put_field_list(map, _key, ""), do: map
  defp maybe_put_field_list(map, _key, nil), do: map

  defp maybe_put_field_list(map, key, value) when is_binary(value) do
    fields =
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    if fields == [], do: map, else: Map.put(map, key, fields)
  end

  defp display_additional_fields(nil), do: "None"

  defp display_additional_fields(overrides) do
    case Map.get(overrides, "additional_required_fields", []) do
      [] -> "None"
      fields -> Enum.join(fields, ", ")
    end
  end

  defp changeset_error_message(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end

  defp changeset_error_message(_), do: "unknown error"

  defp authorized?(socket) do
    user = socket.assigns[:current_user]
    account = socket.assigns[:current_account]

    if user && account do
      membership = Accounts.get_account_user(user, account)
      membership != nil and AccountUser.admin?(membership)
    else
      socket.assigns.can_edit?
    end
  end
end
