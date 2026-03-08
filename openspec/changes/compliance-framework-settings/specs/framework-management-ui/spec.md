## ADDED Requirements

### Requirement: Compliance settings page route and mount

A LiveView MUST be accessible at `/dashboard/accounts/:account_id/compliance` within the existing `live_session :account_scoped` block. The LiveView MUST set `active_nav: :compliance` and load all framework data on mount.

#### Scenario: Page loads with framework data
- **WHEN** an authenticated user navigates to `/dashboard/accounts/:account_id/compliance`
- **THEN** the page renders with a card for each of the five registered frameworks (HIPAA, SOC 2 Type II, PCI-DSS v4, GDPR, ISO 27001)
- **THEN** each card displays the framework display name from `module.name/0`
- **THEN** each card shows an active or inactive status badge based on whether an `AccountComplianceFramework` record exists for the account

#### Scenario: Page title and breadcrumbs
- **WHEN** the compliance settings page is mounted
- **THEN** the page title is "Compliance Frameworks"
- **THEN** breadcrumbs show "Dashboard" linking to the account dashboard and "Compliance" as the current page

#### Scenario: Sidebar active state
- **WHEN** the user is on the compliance settings page
- **THEN** the "Compliance" sidebar nav item is highlighted as active

### Requirement: Sidebar navigation with Configuration section

The dashboard sidebar MUST include a "Configuration" section between the "Developers" section and the bottom-pinned settings area. The section MUST contain a "Compliance" nav item.

#### Scenario: Configuration section renders
- **WHEN** the dashboard sidebar is rendered for any dashboard page
- **THEN** a "Configuration" section heading appears after the "Developers" section
- **THEN** a "Compliance" nav item with the `hero-shield-check` icon appears under "Configuration"
- **THEN** the "Compliance" link navigates to `/dashboard/accounts/:account_id/compliance`

### Requirement: Framework activation toggle

Each framework card MUST include a toggle control for activating and deactivating the framework. The toggle MUST only be interactive for users with owner or admin roles on the account.

#### Scenario: Activate inactive framework
- **WHEN** an owner or admin clicks the toggle on an inactive framework card
- **THEN** `GA.Compliance.activate_framework(account_id, framework_id)` is called
- **THEN** on success, the card updates to show active status badge and the expandable settings panel becomes visible
- **THEN** a success flash message is displayed

#### Scenario: Deactivate active framework
- **WHEN** an owner or admin clicks the toggle on an active framework card
- **THEN** a confirmation prompt is shown warning that deactivation will remove the framework configuration
- **WHEN** the user confirms deactivation
- **THEN** `GA.Compliance.deactivate_framework(account_id, framework_id)` is called
- **THEN** on success, the card updates to show inactive status badge and the settings panel is hidden
- **THEN** a success flash message is displayed

#### Scenario: Activation failure
- **WHEN** `activate_framework/3` returns `{:error, changeset}`
- **THEN** an error flash message is displayed with the validation error
- **THEN** the toggle remains in the inactive position

### Requirement: Framework settings panel for active frameworks

Each active framework card MUST display an expandable settings panel with controls for validation mode, retention days, verification cadence hours, and additional required fields.

#### Scenario: Settings panel content
- **WHEN** a framework is active
- **THEN** the settings panel shows a validation mode selector with options "Flexible" and "Strict"
- **THEN** the settings panel shows a retention days number input with the framework default as placeholder
- **THEN** the settings panel shows a verification cadence hours number input with the framework default as placeholder
- **THEN** the settings panel shows an additional required fields text input (comma-separated)

#### Scenario: Current values displayed
- **WHEN** a framework is active with `action_validation_mode: "strict"` and `config_overrides: %{"retention_days" => 3650}`
- **THEN** the validation mode selector shows "Strict" as selected
- **THEN** the retention days input shows `3650` as the current value
- **THEN** the verification cadence hours input shows the framework default as placeholder (no override set)

#### Scenario: Validation mode descriptions
- **WHEN** the settings panel is rendered
- **THEN** "Flexible" option includes a description: allows any action string
- **THEN** "Strict" option includes a description and warning: rejects actions not in the framework taxonomy or custom action mappings

### Requirement: Save framework settings

Each active framework card MUST have a "Save" button that persists validation mode and config override changes.

#### Scenario: Save updated settings
- **WHEN** an owner or admin changes the validation mode to "strict" and sets retention days to 3650, then clicks "Save"
- **THEN** `GA.Compliance.update_framework_config(account_id, framework_id, attrs)` is called with `%{action_validation_mode: "strict", config_overrides: %{"retention_days" => 3650}}`
- **THEN** on success, a flash message confirms the settings were saved
- **THEN** the save button returns to a disabled state (no pending changes)

#### Scenario: Save with invalid config
- **WHEN** an owner or admin enters a non-integer value for retention days and clicks "Save"
- **THEN** the changeset error is displayed inline or as a flash message
- **THEN** the invalid value remains in the input for correction

#### Scenario: Save button disabled state
- **WHEN** no changes have been made to the framework settings
- **THEN** the "Save" button is disabled (not clickable)

### Requirement: update_framework_config context function

`GA.Compliance.update_framework_config(account_id, framework_id, attrs)` MUST update an active framework's `action_validation_mode` and `config_overrides` fields.

#### Scenario: Update validation mode
- **WHEN** `update_framework_config(account_id, "hipaa", %{action_validation_mode: "strict"})` is called for an account with HIPAA active
- **THEN** the record is updated with `action_validation_mode: "strict"`
- **THEN** `{:ok, association}` is returned

#### Scenario: Update config overrides
- **WHEN** `update_framework_config(account_id, "hipaa", %{config_overrides: %{"retention_days" => 3650}})` is called
- **THEN** the record's `config_overrides` is updated to `%{"retention_days" => 3650}`
- **THEN** `{:ok, association}` is returned

#### Scenario: Update with invalid override key
- **WHEN** `update_framework_config(account_id, "hipaa", %{config_overrides: %{"bad_key" => "value"}})` is called
- **THEN** `{:error, changeset}` is returned with a validation error on `:config_overrides`

#### Scenario: Update non-existent framework
- **WHEN** `update_framework_config(account_id, "hipaa", %{action_validation_mode: "strict"})` is called but the account does not have HIPAA active
- **THEN** `{:error, :not_found}` is returned

### Requirement: Role-based access control

The compliance settings page MUST enforce role-based rendering. Only account owners and admins can modify framework settings. Members see a read-only view.

#### Scenario: Owner or admin view
- **WHEN** a user with owner or admin role on the account views the compliance settings page
- **THEN** framework toggle switches are interactive
- **THEN** settings inputs are editable
- **THEN** save buttons are visible

#### Scenario: Member read-only view
- **WHEN** a user with member role on the account views the compliance settings page
- **THEN** framework status is shown as a text badge (no toggle)
- **THEN** settings values are shown as plain text (no input fields)
- **THEN** no save buttons are rendered

#### Scenario: Member cannot send modification events
- **WHEN** a member crafts a `toggle_framework` or `save` LiveView event
- **THEN** the event handler checks the user's role and returns an error flash without modifying data
