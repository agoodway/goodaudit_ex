## 1. Context Function: update_framework_config

- [ ] 1.1 Add `update_framework_config(account_id, framework, attrs)` to `lib/app/compliance.ex` -- looks up the `AccountComplianceFramework` record by `(account_id, framework)`, applies changeset with `action_validation_mode` and `config_overrides` from `attrs`, returns `{:ok, association}` or `{:error, changeset}`. Returns `{:error, :not_found}` if no active record exists.
- [ ] 1.2 Add `get_active_framework(account_id, framework)` to `lib/app/compliance.ex` -- returns `{:ok, association}` or `{:error, :not_found}` for a single active framework record. Used by the LiveView to load individual framework state.

## 2. Sidebar Navigation Update

- [ ] 2.1 Add "Configuration" section to `sidebar_content/1` in `lib/app_web/components/layouts.ex` -- new `<li>` block between the "Developers" section and the bottom `mt-auto` section, with section heading "Configuration" and a `sidebar_nav_item` for "Compliance" linking to `"#{@account_base}/compliance"` with icon `hero-shield-check` and active state `@active_nav == :compliance`

## 3. Router and LiveView Setup

- [ ] 3.1 Add `live "/compliance", ComplianceLive.Index, :index` route inside the existing `live_session :account_scoped` block in `lib/app_web/router.ex`
- [ ] 3.2 Create `lib/app_web/live/compliance_live/index.ex` with `GAWeb.ComplianceLive.Index` module -- `use GAWeb, :live_view`, mount loads all framework data via `GA.Compliance.registry/0` and `GA.Compliance.list_active_frameworks/1` using `@current_account.id`, sets `active_nav: :compliance`, determines `can_edit?` from current user's account role

## 4. Framework Card Component

- [ ] 4.1 Create `lib/app_web/live/compliance_live/framework_card_component.ex` as a stateful `Phoenix.LiveComponent` -- receives `framework_id`, `framework_module`, `association` (nil if inactive), `can_edit?`, and `account_id` as assigns
- [ ] 4.2 Render card header with framework name (from `module.name/0`), active/inactive badge (DaisyUI `badge badge-success` / `badge badge-ghost`), and activate/deactivate toggle (DaisyUI `toggle toggle-success`) when `can_edit?` is true
- [ ] 4.3 Render expandable settings panel (visible only when framework is active) containing: validation mode selector (`select select-bordered select-sm` with "Flexible" and "Strict" options plus inline descriptions), retention days number input (`input input-bordered input-sm`), verification cadence hours number input (`input input-bordered input-sm`), additional required fields text input (comma-separated, `input input-bordered input-sm`)
- [ ] 4.4 Show framework defaults as placeholder text in inputs (e.g., placeholder="2555" for HIPAA retention days) so users see the default when no override is set
- [ ] 4.5 Add "Save" button (`btn btn-primary btn-sm`) per framework card, disabled when no changes detected. Handle `phx-click="save"` to call `GA.Compliance.update_framework_config/3` and show flash on success/error
- [ ] 4.6 Handle `phx-click="toggle_framework"` -- when activating, call `GA.Compliance.activate_framework/3`; when deactivating, show confirmation (JS confirm or modal) then call `GA.Compliance.deactivate_framework/2`. Update card state on success.
- [ ] 4.7 Render read-only view when `can_edit?` is false -- replace toggle with status text, replace inputs with plain text values, hide save button

## 5. Page Layout and Polish

- [ ] 5.1 Add page header in `index.ex` render -- title "Compliance Frameworks", subtitle "Manage which compliance standards are enforced for this account", breadcrumbs `[%{label: "Dashboard", href: account_base}, %{label: "Compliance"}]`
- [ ] 5.2 Render framework cards in a responsive grid (`grid grid-cols-1 lg:grid-cols-2 gap-4`) iterating over all frameworks from the registry, passing the matching association record (or nil) to each card component
- [ ] 5.3 Add strict mode warning text below validation mode selector: "Strict mode rejects audit log entries with actions not recognized by this framework's event taxonomy or your custom action mappings."

## 6. Tests

- [ ] 6.1 Test `GA.Compliance.update_framework_config/3` -- update validation mode from flexible to strict, update config_overrides retention_days, update with invalid override key (rejected), update non-existent framework (returns `{:error, :not_found}`)
- [ ] 6.2 Test `GA.Compliance.get_active_framework/2` -- returns association when active, returns `{:error, :not_found}` when not active
- [ ] 6.3 Test `ComplianceLive.Index` mount -- page renders with all five framework cards, active frameworks show enabled toggle, inactive frameworks show disabled toggle
- [ ] 6.4 Test framework activation via LiveView -- click toggle on inactive framework, verify `activate_framework` called, card updates to show active state with settings panel
- [ ] 6.5 Test framework deactivation via LiveView -- click toggle on active framework, verify `deactivate_framework` called, card updates to show inactive state
- [ ] 6.6 Test settings update via LiveView -- change validation mode and retention days, click save, verify `update_framework_config` called with correct attrs, flash shows success
- [ ] 6.7 Test read-only view for non-admin users -- mount as member role, verify toggles and inputs are not rendered, status and values shown as text
- [ ] 6.8 Test sidebar navigation -- "Compliance" link appears under "Configuration" section, links to correct path, shows active state when on compliance page
