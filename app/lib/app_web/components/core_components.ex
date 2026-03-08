defmodule GAWeb.CoreComponents do
  @moduledoc """
  Provides core UI components styled with the "Institutional Precision" design system.

  Typography: IBM Plex Mono (data/labels) + Plus Jakarta Sans (body).
  Palette: cool slate bases, emerald primary accent.
  Cards: 1px borders, monospace uppercase headers, flat depth.
  """
  use Phoenix.Component
  use Gettext, backend: GAWeb.Gettext

  alias Phoenix.LiveView.JS

  ## ═══════════════════════════════════════════
  ## MODAL
  ## ═══════════════════════════════════════════

  @doc """
  Renders a modal dialog.

  ## Examples

      <.modal id="confirm-modal" on_cancel={JS.navigate(~p"/")}>
        <:title>Are you sure?</:title>
        <p>This action cannot be undone.</p>
        <:actions>
          <.button variant="primary" phx-click="confirm">Confirm</.button>
        </:actions>
      </.modal>
  """
  attr :id, :string, required: true
  attr :on_cancel, :any, default: nil
  attr :class, :any, default: nil

  slot :title
  slot :inner_block, required: true
  slot :actions

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      class="fixed inset-0 z-50 flex items-center justify-center p-4"
      role="dialog"
      aria-modal="true"
    >
      <%!-- Backdrop --%>
      <div
        class="fixed inset-0 bg-black/50 backdrop-blur-[2px]"
        phx-click={@on_cancel}
        aria-hidden="true"
      />

      <%!-- Panel --%>
      <div class={[
        "relative w-full max-w-md bg-base-100 border border-base-300 rounded shadow-2xl",
        @class
      ]}>
        <%!-- Header --%>
        <div :if={@title != []} class="flex items-center justify-between px-5 py-3.5 border-b border-base-300">
          <h3 class="text-sm font-semibold text-base-content">
            {render_slot(@title)}
          </h3>
          <button
            :if={@on_cancel}
            type="button"
            phx-click={@on_cancel}
            class="flex items-center justify-center h-6 w-6 rounded hover:bg-base-200 transition-colors cursor-pointer"
            aria-label={gettext("close")}
          >
            <.icon name="hero-x-mark" class="size-3.5 text-base-content/40" />
          </button>
        </div>

        <%!-- Body --%>
        <div class="px-5 py-4">
          {render_slot(@inner_block)}
        </div>

        <%!-- Actions --%>
        <div :if={@actions != []} class="flex items-center justify-end gap-2 px-5 py-3.5 border-t border-base-300 bg-base-200/30">
          {render_slot(@actions)}
        </div>
      </div>
    </div>
    """
  end

  ## ═══════════════════════════════════════════
  ## FLASH
  ## ═══════════════════════════════════════════

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="fixed top-3 right-3 z-[60] animate-fade-up"
      {@rest}
    >
      <div class={[
        "flex items-start gap-3 w-80 sm:w-96 px-4 py-3 rounded border shadow-lg",
        @kind == :info && "bg-base-100 border-primary/30 text-base-content",
        @kind == :error && "bg-base-100 border-error/30 text-base-content"
      ]}>
        <div class={[
          "flex h-5 w-5 shrink-0 items-center justify-center rounded mt-0.5",
          @kind == :info && "text-primary",
          @kind == :error && "text-error"
        ]}>
          <.icon :if={@kind == :info} name="hero-check-circle" class="size-4" />
          <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-4" />
        </div>
        <div class="flex-1 min-w-0">
          <p :if={@title} class="text-xs font-semibold">{@title}</p>
          <p class="text-xs text-base-content/70 text-wrap">{msg}</p>
        </div>
        <button
          type="button"
          class="flex items-center justify-center h-5 w-5 shrink-0 rounded hover:bg-base-200 transition-colors cursor-pointer"
          aria-label={gettext("close")}
        >
          <.icon name="hero-x-mark" class="size-3 text-base-content/30 hover:text-base-content/60" />
        </button>
      </div>
    </div>
    """
  end

  ## ═══════════════════════════════════════════
  ## BUTTON
  ## ═══════════════════════════════════════════

  @doc """
  Renders a button.

  ## Variants

    - `"primary"` — filled emerald button for primary actions
    - `"danger"` — filled error button for destructive actions
    - `"ghost"` — transparent button with hover state
    - `nil` (default) — outlined secondary button

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled type form)
  attr :class, :any, default: nil
  attr :variant, :string, values: ~w(primary danger ghost) ++ [nil], default: nil
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    base = "inline-flex items-center justify-center gap-1.5 px-3.5 py-1.5 text-xs font-semibold rounded border transition-all cursor-pointer disabled:opacity-40 disabled:cursor-not-allowed"

    variant_classes = %{
      "primary" => "bg-primary text-primary-content border-primary hover:brightness-110 active:brightness-95",
      "danger" => "bg-error text-error-content border-error hover:brightness-110 active:brightness-95",
      "ghost" => "bg-transparent text-base-content/60 border-transparent hover:bg-base-200 hover:text-base-content",
      nil => "bg-base-100 text-base-content/70 border-base-300 hover:bg-base-200 hover:text-base-content active:bg-base-300"
    }

    assigns = assign(assigns, :computed_class, [base, variant_classes[assigns.variant], assigns.class])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@computed_class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  ## ═══════════════════════════════════════════
  ## INPUT
  ## ═══════════════════════════════════════════

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as radio, are best
  written directly in your templates.

  ## Examples

  ```heex
  <.input field={@form[:email]} type="email" />
  <.input name="my-input" errors={["oh no!"]} />
  ```
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week hidden)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :any, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :any, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> assign(:input_base, input_base_class())
    |> assign(:input_error, input_error_class())
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="mb-3">
      <label class="flex items-center gap-2.5 cursor-pointer group">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={@class || "h-4 w-4 rounded border-base-300 text-primary focus:ring-primary/20 cursor-pointer"}
          {@rest}
        />
        <span class="text-sm text-base-content/70 group-hover:text-base-content transition-colors">
          {@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    assigns = ensure_input_classes(assigns)

    ~H"""
    <div class="mb-3">
      <label>
        <span :if={@label} class="block mb-1.5 text-xs font-mono font-semibold uppercase tracking-wider text-base-content/50">
          {@label}
        </span>
        <select
          id={@id}
          name={@name}
          class={[@class || @input_base, @errors != [] && (@error_class || @input_error)]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    assigns = ensure_input_classes(assigns)

    ~H"""
    <div class="mb-3">
      <label>
        <span :if={@label} class="block mb-1.5 text-xs font-mono font-semibold uppercase tracking-wider text-base-content/50">
          {@label}
        </span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || [@input_base, "min-h-[5rem] resize-y"],
            @errors != [] && (@error_class || @input_error)
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(assigns) do
    assigns = ensure_input_classes(assigns)

    ~H"""
    <div class="mb-3">
      <label>
        <span :if={@label} class="block mb-1.5 text-xs font-mono font-semibold uppercase tracking-wider text-base-content/50">
          {@label}
        </span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || @input_base,
            @errors != [] && (@error_class || @input_error)
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  defp ensure_input_classes(assigns) do
    assigns
    |> assign_new(:input_base, fn -> input_base_class() end)
    |> assign_new(:input_error, fn -> input_error_class() end)
  end

  defp input_base_class, do: "w-full px-3 py-2 text-sm bg-base-100 border border-base-300 rounded text-base-content placeholder:text-base-content/30 focus:outline-none focus:border-primary/50 focus:ring-1 focus:ring-primary/20 transition-colors"
  defp input_error_class, do: "border-error/50 focus:border-error/50 focus:ring-error/20"

  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex items-center gap-1.5 text-xs text-error">
      <.icon name="hero-exclamation-circle" class="size-3.5 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  ## ═══════════════════════════════════════════
  ## HEADER
  ## ═══════════════════════════════════════════

  @doc """
  Renders a page header with title, subtitle, and actions.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={["flex items-end justify-between gap-6 animate-fade-up", @actions != [] && "mb-6"]}>
      <div>
        <h1 class="text-lg font-semibold tracking-tight text-base-content">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="mt-0.5 text-xs font-mono text-base-content/40">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex items-center gap-2 shrink-0">
        {render_slot(@actions)}
      </div>
    </header>
    """
  end

  ## ═══════════════════════════════════════════
  ## TABLE
  ## ═══════════════════════════════════════════

  @doc """
  Renders a table with the Institutional Precision design.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <div class="dash-card overflow-hidden">
      <div class="responsive-table">
        <table class="w-full">
          <thead>
            <tr>
              <th :for={col <- @col} class="text-left">{col[:label]}</th>
              <th :if={@action != []}>
                <span class="sr-only">{gettext("Actions")}</span>
              </th>
            </tr>
          </thead>
          <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
            <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
              <td
                :for={col <- @col}
                phx-click={@row_click && @row_click.(row)}
                class={@row_click && "hover:cursor-pointer"}
              >
                {render_slot(col, @row_item.(row))}
              </td>
              <td :if={@action != []} class="table-actions">
                <div class="flex items-center gap-2">
                  <%= for action <- @action do %>
                    {render_slot(action, @row_item.(row))}
                  <% end %>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  ## ═══════════════════════════════════════════
  ## LIST
  ## ═══════════════════════════════════════════

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <div class="dash-card">
      <dl class="divide-y divide-base-300/60">
        <div :for={item <- @item} class="flex items-start gap-4 px-5 py-3">
          <dt class="w-1/4 shrink-0 text-xs font-mono font-semibold uppercase tracking-wider text-base-content/40 pt-0.5">
            {item.title}
          </dt>
          <dd class="flex-1 text-sm text-base-content/80">
            {render_slot(item)}
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  ## ═══════════════════════════════════════════
  ## BADGE
  ## ═══════════════════════════════════════════

  @doc """
  Renders a badge/tag.

  ## Variants

    - `"success"` — green for active/ok states
    - `"warning"` — amber for caution states
    - `"error"` — red for error/revoked states
    - `"info"` — blue for informational states
    - `nil` (default) — neutral/muted badge

  ## Examples

      <.badge>Draft</.badge>
      <.badge variant="success">Active</.badge>
  """
  attr :variant, :string, values: ~w(success warning error info) ++ [nil], default: nil
  slot :inner_block, required: true

  def badge(assigns) do
    base = "inline-flex items-center gap-1 px-2 py-0.5 rounded text-[0.625rem] font-mono font-semibold uppercase tracking-wider"

    variant_classes = %{
      "success" => "bg-success/10 text-success border border-success/20",
      "warning" => "bg-warning/10 text-warning border border-warning/20",
      "error" => "bg-error/10 text-error border border-error/20",
      "info" => "bg-info/10 text-info border border-info/20",
      nil => "bg-base-200 text-base-content/50 border border-base-300"
    }

    assigns = assign(assigns, :computed_class, [base, variant_classes[assigns.variant]])

    ~H"""
    <span class={@computed_class}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  ## ═══════════════════════════════════════════
  ## ICON
  ## ═══════════════════════════════════════════

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## ═══════════════════════════════════════════
  ## JS COMMANDS
  ## ═══════════════════════════════════════════

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-out duration-200",
         "opacity-0 scale-[0.98]",
         "opacity-100 scale-100"}
    )
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 150,
      transition:
        {"transition-all ease-in duration-150",
         "opacity-100 scale-100",
         "opacity-0 scale-[0.98]"}
    )
  end

  ## ═══════════════════════════════════════════
  ## BREADCRUMBS
  ## ═══════════════════════════════════════════

  @doc """
  Renders breadcrumbs for dashboard navigation.

  ## Examples

      <.breadcrumbs items={[
        %{label: "Companies", to: ~p"/dashboard/accounts/\#{@account.id}/companies"},
        %{label: "Acme Corp"}
      ]} />
  """
  attr :items, :list, required: true

  def breadcrumbs(assigns) do
    ~H"""
    <nav aria-label="Breadcrumb" class="flex items-center gap-1.5 min-w-0">
      <%= for {item, idx} <- Enum.with_index(@items) do %>
        <%= if idx > 0 do %>
          <span class="text-base-content/20 font-mono text-xs shrink-0">/</span>
        <% end %>
        <%= if Map.has_key?(item, :to) do %>
          <.link
            navigate={item.to}
            class="text-xs font-mono text-base-content/40 hover:text-base-content/60 transition-colors truncate"
          >
            {item.label}
          </.link>
        <% else %>
          <span class="text-xs font-mono font-semibold text-base-content/70 truncate">
            {item.label}
          </span>
        <% end %>
      <% end %>
    </nav>
    """
  end

  ## ═══════════════════════════════════════════
  ## I18N
  ## ═══════════════════════════════════════════

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    if count = opts[:count] do
      Gettext.dngettext(GAWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(GAWeb.Gettext, "errors", msg, opts)
    end
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end
end
