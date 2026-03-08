## Context

GoodAudit's compliance framework profile system (`GA.Compliance`) supports activating multiple frameworks per account, configuring action validation modes (flexible/strict), and setting per-framework config overrides (retention days, verification cadence hours, additional required fields). All five built-in frameworks (HIPAA, SOC 2 Type II, PCI-DSS v4, GDPR, ISO 27001) are defined as behaviour modules under `GA.Compliance.Frameworks.*` with a compile-time registry in `GA.Compliance.registry/0`.

Currently, framework management is only available through the Elixir context API. The dashboard has no compliance settings page. Account owners must use the API or developer console to activate frameworks, change validation strictness, or adjust overrides. This change adds a LiveView-based settings page to the existing dashboard.

## Goals / Non-Goals

**Goals:**
- Provide a dashboard page at `/dashboard/accounts/:account_id/compliance` for managing compliance framework settings.
- Display all five available frameworks as cards showing name, description, active/inactive status, and validation mode.
- Allow account owners and admins to activate/deactivate frameworks with a toggle control.
- Allow editing of validation mode (flexible/strict) and config overrides (retention days, verification cadence hours, additional required fields) for active frameworks.
- Enforce role-based access: owners and admins can modify; members see a read-only view.
- Add a "Configuration" section to the sidebar navigation with a "Compliance" link.

**Non-Goals:**
- Custom framework creation or registration through the UI (frameworks are code-defined).
- Bulk framework operations (activate/deactivate all at once).
- Framework-specific reporting or evidence export views (separate change).
- Real-time validation preview (showing what entries would pass/fail under a framework configuration).
- Audit log of framework configuration changes (future change).

## Decisions

### Framework cards with inline expandable settings

Each framework is rendered as a card component. Inactive frameworks show the framework name, description, and an activate toggle. Active frameworks show an expandable settings panel below the card header with validation mode selector, retention days input, verification cadence hours input, and additional required fields input. This keeps the page compact when most frameworks are inactive while providing full configuration access when needed.

### LiveView with phx-change for settings, explicit save per framework

Settings changes within each framework card are tracked in LiveView assigns but not persisted until the user clicks a "Save" button on that card. This avoids accidental configuration changes and gives users a clear commit point. The save button is disabled when no changes have been detected.

### New update_framework_config/3 context function

The existing `GA.Compliance` context has `activate_framework/3` and `deactivate_framework/2` but no function to update an active framework's settings. A new `update_framework_config(account_id, framework, attrs)` function updates the `action_validation_mode` and `config_overrides` fields on an existing `AccountComplianceFramework` record. It reuses the existing changeset validations (whitelisted override keys, type checks). Returns `{:ok, association}` or `{:error, changeset}`.

### Role-based rendering via current_account membership

The LiveView checks the current user's role on `@current_account` to determine edit vs. read-only rendering. The `on_mount` hook already loads `@current_account` with membership data. Owners and admins see toggle switches, form inputs, and save buttons. Members see the same card layout but with status badges and read-only values instead of interactive controls.

### Sidebar "Configuration" section placement

The new "Configuration" section sits between the existing "Developers" section and the bottom-pinned "Settings" link. This groups account-level configuration (compliance frameworks, and future configuration pages) separately from developer tools (API keys) and user-level settings. The "Compliance" nav item uses the `hero-shield-check` icon.

### Validation mode explanation inline

Each validation mode option (flexible/strict) includes a brief inline explanation so account owners understand the impact before changing modes. Flexible mode allows any action string; strict mode requires actions to match the framework's event taxonomy or a custom action mapping.

## Risks / Trade-offs

- [Activating a framework with strict validation may immediately break existing API integrations] -> The UI shows a warning when switching to strict mode explaining that unrecognized actions will be rejected. A future enhancement could add a dry-run preview.
- [No undo for deactivation] -> Deactivation deletes the `AccountComplianceFramework` record. Re-activating requires reconfiguring overrides. The UI shows a confirmation dialog before deactivation.
- [Config overrides are a flat map with string keys] -> The UI normalizes input values to the expected types (integer for retention/cadence, list of strings for additional fields) before sending to the context function.
- [Read-only mode relies on role check in LiveView] -> The context functions themselves do not enforce authorization. A malicious user could craft LiveView events. Adding authorization guards to the event handlers mitigates this.
