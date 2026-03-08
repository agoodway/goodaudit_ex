defmodule GAWeb.AuditLogLive.Index do
  @moduledoc """
  LiveView for browsing account-scoped audit log entries with filtering,
  cursor-based pagination, inline detail expansion, and JSON export.
  """
  use GAWeb, :live_view

  alias GA.Audit

  @page_size 50
  @valid_outcomes ~w(success failure denied error)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Audit Logs",
       active_nav: :audit_logs,
       breadcrumbs: [%{label: "Audit Logs"}],
       expanded_id: nil,
       expanded_entry: nil
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    account_id = socket.assigns.current_account.id

    filters = parse_filters(params)
    opts = build_query_opts(filters)

    {entries, next_cursor} = Audit.list_logs(account_id, opts)

    {:noreply,
     assign(socket,
       filters: filters,
       entries: entries,
       next_cursor: next_cursor,
       expanded_id: nil,
       expanded_entry: nil
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    query_params =
      %{}
      |> put_if_present("from", params["from"])
      |> put_if_present("to", params["to"])
      |> put_if_present("actor_id", params["actor_id"])
      |> put_if_present("action", params["action"])
      |> put_if_present("resource_type", params["resource_type"])
      |> put_if_present("outcome", params["outcome"])
      |> put_if_present("phi_accessed", params["phi_accessed"])

    {:noreply, push_patch(socket, to: current_path(socket, query_params), replace: true)}
  end

  @impl true
  def handle_event("next_page", _params, socket) do
    case socket.assigns.next_cursor do
      nil ->
        {:noreply, socket}

      cursor ->
        query_params =
          socket.assigns.filters
          |> filters_to_params()
          |> Map.put("after_sequence", Integer.to_string(cursor))

        {:noreply, push_patch(socket, to: current_path(socket, query_params))}
    end
  end

  @impl true
  def handle_event("back_to_start", _params, socket) do
    query_params = filters_to_params(socket.assigns.filters)
    {:noreply, push_patch(socket, to: current_path(socket, query_params))}
  end

  @impl true
  def handle_event("toggle_detail", %{"id" => id}, socket) do
    if socket.assigns.expanded_id == id do
      {:noreply, assign(socket, expanded_id: nil, expanded_entry: nil)}
    else
      account_id = socket.assigns.current_account.id

      case Audit.get_log(account_id, id) do
        {:ok, entry} ->
          {:noreply, assign(socket, expanded_id: id, expanded_entry: entry)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Unable to load entry details.")}
      end
    end
  end

  @impl true
  def handle_event("export_json", _params, socket) do
    account_id = socket.assigns.current_account.id
    export_params = filters_to_params(socket.assigns.filters)

    export_path =
      ~p"/dashboard/accounts/#{account_id}/audit-logs/export"
      |> then(fn base ->
        case URI.encode_query(export_params) do
          "" -> base
          qs -> "#{base}?#{qs}"
        end
      end)

    {:noreply, redirect(socket, to: export_path)}
  end

  # --- Render ---

  @impl true
  def render(assigns) do
    ~H"""
    <div id="audit-log-viewer" class="space-y-6">
      <%!-- Page header --%>
      <div class="flex items-end justify-between animate-fade-up">
        <div>
          <h1 class="text-lg font-semibold tracking-tight text-base-content">Audit Logs</h1>
          <p class="mt-0.5 text-xs font-mono text-base-content/40">
            Browse and export audit trail entries
          </p>
        </div>
        <.button phx-click="export_json" variant="primary">
          <.icon name="hero-arrow-down-tray" class="size-3.5" /> Export JSON
        </.button>
      </div>

      <%!-- Filter bar --%>
      <.filter_bar filters={@filters} />

      <%!-- Table or empty state --%>
      <div :if={@entries == []}><.empty_state has_filters={has_active_filters?(@filters)} /></div>
      <div :if={@entries != []}>
        <div class="dash-card overflow-hidden animate-fade-up animate-delay-1">
          <div class="responsive-table">
            <table class="w-full">
              <thead>
                <tr>
                  <th>Seq #</th>
                  <th>Timestamp</th>
                  <th>Actor</th>
                  <th>Action</th>
                  <th>Resource</th>
                  <th>Outcome</th>
                  <th>PHI</th>
                </tr>
              </thead>
              <tbody>
                <.entry_rows
                  :for={entry <- @entries}
                  entry={entry}
                  expanded_id={@expanded_id}
                  expanded_entry={@expanded_entry}
                />
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Pagination --%>
        <div class="flex items-center justify-between animate-fade-up animate-delay-2 mt-6">
          <p class="text-xs font-mono text-base-content/40">
            Showing {length(@entries)} entries
          </p>
          <div class="flex items-center gap-2">
            <.button
              :if={@filters.after_sequence}
              phx-click="back_to_start"
              variant="ghost"
            >
              Back to start
            </.button>
            <.button
              :if={@next_cursor}
              phx-click="next_page"
              variant="ghost"
            >
              Next page <.icon name="hero-arrow-right-mini" class="size-3.5" />
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # --- Components ---

  attr :entry, :map, required: true
  attr :expanded_id, :string, required: true
  attr :expanded_entry, :map, required: true

  defp entry_rows(assigns) do
    ~H"""
    <tr
      id={"log-#{@entry.id}"}
      phx-click="toggle_detail"
      phx-value-id={@entry.id}
      class={[
        "cursor-pointer hover:bg-base-200/50 transition-colors",
        @expanded_id == @entry.id && "bg-base-200/30"
      ]}
    >
      <td data-label="Seq #" class="font-mono text-base-content/60">
        {@entry.sequence_number}
      </td>
      <td data-label="Timestamp" class="text-xs font-mono text-base-content/50">
        {format_timestamp(@entry.timestamp)}
      </td>
      <td data-label="Actor" class="text-sm text-base-content/70 truncate max-w-[10rem]">
        {@entry.actor_id}
      </td>
      <td data-label="Action" class="text-sm font-medium text-base-content/80">
        {@entry.action}
      </td>
      <td data-label="Resource" class="text-xs font-mono text-base-content/50">
        {@entry.resource_type}/{@entry.resource_id}
      </td>
      <td data-label="Outcome">
        <.outcome_badge outcome={@entry.outcome} />
      </td>
      <td data-label="PHI">
        <.badge :if={@entry.phi_accessed} variant="error">PHI</.badge>
      </td>
    </tr>
    <tr :if={@expanded_entry && @expanded_id == @entry.id}>
      <td colspan="7" class="!p-0">
        <GAWeb.AuditLogLive.ShowComponent.show entry={@expanded_entry} />
      </td>
    </tr>
    """
  end

  attr :filters, :map, required: true

  defp filter_bar(assigns) do
    ~H"""
    <div class="dash-card animate-fade-up animate-delay-1">
      <details class="group" open>
        <summary class="dash-card-header cursor-pointer select-none flex items-center justify-between">
          <span>Filters</span>
          <.icon
            name="hero-chevron-down"
            class="size-4 text-base-content/30 transition-transform group-open:rotate-180"
          />
        </summary>
        <div class="dash-card-body">
          <.form for={%{}} phx-change="filter" phx-submit="filter" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3">
            <div>
              <label for="filter-from" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                From
              </label>
              <input
                type="date"
                id="filter-from"
                name="from"
                value={@filters.from}
                class="input input-bordered input-sm w-full font-mono text-xs"
              />
            </div>
            <div>
              <label for="filter-to" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                To
              </label>
              <input
                type="date"
                id="filter-to"
                name="to"
                value={@filters.to}
                class="input input-bordered input-sm w-full font-mono text-xs"
              />
            </div>
            <div>
              <label for="filter-actor-id" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                Actor
              </label>
              <input
                type="text"
                id="filter-actor-id"
                name="actor_id"
                value={@filters.actor_id}
                placeholder="Actor ID"
                phx-debounce="300"
                class="input input-bordered input-sm w-full font-mono text-xs"
              />
            </div>
            <div>
              <label for="filter-action" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                Action
              </label>
              <input
                type="text"
                id="filter-action"
                name="action"
                value={@filters.action}
                placeholder="Action name"
                phx-debounce="300"
                class="input input-bordered input-sm w-full font-mono text-xs"
              />
            </div>
            <div>
              <label for="filter-resource-type" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                Resource Type
              </label>
              <input
                type="text"
                id="filter-resource-type"
                name="resource_type"
                value={@filters.resource_type}
                placeholder="Resource type"
                phx-debounce="300"
                class="input input-bordered input-sm w-full font-mono text-xs"
              />
            </div>
            <div>
              <label for="filter-outcome" class="text-[0.625rem] font-mono font-semibold uppercase tracking-wider text-base-content/40 mb-1 block">
                Outcome
              </label>
              <select
                id="filter-outcome"
                name="outcome"
                class="select select-bordered select-sm w-full font-mono text-xs"
              >
                <option value="" selected={@filters.outcome == nil}>All</option>
                <option value="success" selected={@filters.outcome == "success"}>Success</option>
                <option value="failure" selected={@filters.outcome == "failure"}>Failure</option>
              </select>
            </div>
            <div class="flex items-end">
              <label class="flex items-center gap-2 cursor-pointer pb-1">
                <input
                  type="checkbox"
                  name="phi_accessed"
                  value="true"
                  checked={@filters.phi_accessed}
                  class="checkbox checkbox-sm checkbox-error"
                />
                <span class="text-xs font-mono text-base-content/60">PHI only</span>
              </label>
            </div>
          </.form>
        </div>
      </details>
    </div>
    """
  end

  attr :has_filters, :boolean, required: true

  defp empty_state(assigns) do
    ~H"""
    <div class="dash-card animate-fade-up animate-delay-1">
      <div class="flex flex-col items-center py-16 px-6">
        <div class="flex h-12 w-12 items-center justify-center rounded bg-base-200/80 mb-4">
          <.icon name="hero-document-text" class="size-6 text-base-content/20" />
        </div>
        <h3 class="text-sm font-semibold text-base-content/70">
          <span :if={@has_filters}>No entries match the current filters</span>
          <span :if={!@has_filters}>No audit log entries yet</span>
        </h3>
        <p class="mt-1 text-xs font-mono text-base-content/40 text-center max-w-xs">
          <span :if={@has_filters}>Try adjusting your filters to see more results.</span>
          <span :if={!@has_filters}>
            Audit log entries will appear here once your application starts logging events.
          </span>
        </p>
      </div>
    </div>
    """
  end

  attr :outcome, :string, required: true

  defp outcome_badge(assigns) do
    variant =
      case assigns.outcome do
        "success" -> "success"
        "failure" -> "error"
        "denied" -> "error"
        "error" -> "warning"
        _ -> nil
      end

    assigns = assign(assigns, :variant, variant)

    ~H"""
    <.badge variant={@variant}>{@outcome}</.badge>
    """
  end

  # --- Helpers ---

  defp parse_filters(params) do
    %{
      from: non_empty(params["from"]),
      to: non_empty(params["to"]),
      actor_id: non_empty(params["actor_id"]),
      action: non_empty(params["action"]),
      resource_type: non_empty(params["resource_type"]),
      outcome: validate_outcome(params["outcome"]),
      phi_accessed: params["phi_accessed"] == "true",
      after_sequence: parse_integer(params["after_sequence"])
    }
  end

  defp build_query_opts(filters) do
    opts = [limit: @page_size]

    opts
    |> put_opt(:from, parse_date_start(filters.from))
    |> put_opt(:to, parse_date_end(filters.to))
    |> put_opt(:actor_id, filters.actor_id)
    |> put_opt(:action, filters.action)
    |> put_opt(:resource_type, filters.resource_type)
    |> put_opt(:outcome, filters.outcome)
    |> put_opt(:after_sequence, filters.after_sequence)
    |> then(fn opts ->
      if filters.phi_accessed do
        Keyword.put(opts, :extensions, %{"hipaa" => %{"phi_accessed" => true}})
      else
        opts
      end
    end)
  end

  defp put_opt(opts, _key, nil), do: opts
  defp put_opt(opts, key, value), do: Keyword.put(opts, key, value)

  defp filters_to_params(filters) do
    %{}
    |> put_if_present("from", filters.from)
    |> put_if_present("to", filters.to)
    |> put_if_present("actor_id", filters.actor_id)
    |> put_if_present("action", filters.action)
    |> put_if_present("resource_type", filters.resource_type)
    |> put_if_present("outcome", filters.outcome)
    |> then(fn params ->
      if filters.phi_accessed, do: Map.put(params, "phi_accessed", "true"), else: params
    end)
  end

  defp put_if_present(map, _key, nil), do: map
  defp put_if_present(map, _key, ""), do: map
  defp put_if_present(map, _key, false), do: map
  defp put_if_present(map, key, value), do: Map.put(map, key, value)

  defp non_empty(""), do: nil
  defp non_empty(nil), do: nil
  defp non_empty(value), do: value

  defp validate_outcome(value) when value in @valid_outcomes, do: value
  defp validate_outcome(_), do: nil

  defp parse_integer(nil), do: nil
  defp parse_integer(""), do: nil

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp parse_date_start(nil), do: nil

  defp parse_date_start(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_date_end(nil), do: nil

  defp parse_date_end(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp has_active_filters?(filters) do
    filters.from != nil ||
      filters.to != nil ||
      filters.actor_id != nil ||
      filters.action != nil ||
      filters.resource_type != nil ||
      filters.outcome != nil ||
      filters.phi_accessed
  end

  defp current_path(socket, params) do
    account_id = socket.assigns.current_account.id
    base = ~p"/dashboard/accounts/#{account_id}/audit-logs"

    case URI.encode_query(params) do
      "" -> base
      qs -> "#{base}?#{qs}"
    end
  end

  defp format_timestamp(nil), do: "-"

  defp format_timestamp(datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
  end
end
