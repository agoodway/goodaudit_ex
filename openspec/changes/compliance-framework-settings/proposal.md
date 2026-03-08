## Why

GoodAudit has a full compliance framework profile system -- accounts can activate frameworks (HIPAA, SOC 2, PCI-DSS, GDPR, ISO 27001), configure validation modes, and set per-framework overrides. But all of this configuration is only accessible through the Elixir context API (`GA.Compliance`). There is no UI for account owners to activate frameworks, choose validation strictness, or tune retention and cadence settings. Compliance teams must ask developers to run console commands or build custom tooling to manage framework configuration.

A compliance framework settings page in the dashboard gives account owners and admins direct control over which frameworks are active, how strictly actions are validated, and what retention/cadence overrides apply -- all through a visual interface that surfaces framework descriptions, defaults, and current state at a glance.

## What Changes

1. **Compliance settings LiveView** -- A new LiveView at `/dashboard/accounts/:account_id/compliance` displays all five available compliance frameworks as cards. Each card shows the framework name, description, active/inactive status badge, and current validation mode. Account owners and admins can toggle frameworks on/off, configure validation mode (flexible/strict), and adjust config overrides (retention days, verification cadence, additional required fields).

2. **Sidebar navigation update** -- The dashboard sidebar gains a new "Configuration" section with a "Compliance" link (icon: `hero-shield-check`), placed between the existing "Developers" section and the bottom "Settings" link.

3. **Framework config update function** -- A new `GA.Compliance.update_framework_config/3` context function to update an active framework's `action_validation_mode` and `config_overrides` in a single changeset, enabling the LiveView to persist settings changes.

4. **Role-based access control** -- The compliance settings page renders in read-only mode for account members who are not owners or admins. Only owners and admins see toggle controls and editable settings.

## Capabilities

### New Capabilities
- `framework-management-ui`: Dashboard page for viewing, activating/deactivating, and configuring compliance frameworks per account

### Modified Capabilities
- `account-framework-association`: Add `update_framework_config/3` to the `GA.Compliance` context for updating validation mode and config overrides on an active framework

## Impact

- **New files**: `lib/app_web/live/compliance_live/index.ex`, `lib/app_web/live/compliance_live/framework_card_component.ex`
- **Modified file**: `lib/app_web/router.ex` -- add `/compliance` route under account-scoped dashboard live session
- **Modified file**: `lib/app_web/components/layouts.ex` -- add "Configuration" section with "Compliance" nav item to sidebar
- **Modified file**: `lib/app/compliance.ex` -- add `update_framework_config/3` function
- **New tests**: `test/app_web/live/compliance_live_test.exs`, `test/app/compliance_update_config_test.exs`
