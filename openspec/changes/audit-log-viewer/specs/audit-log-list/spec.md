## ADDED Requirements

### Requirement: Audit log list route

A new LiveView route MUST exist at `/dashboard/accounts/:account_id/audit-logs` using `AuditLogLive.Index` with the `:index` action. The route MUST be within the authenticated dashboard scope and have access to `@current_account` in socket assigns.

#### Scenario: Route accessibility
- **WHEN** an authenticated user navigates to `/dashboard/accounts/:account_id/audit-logs`
- **THEN** the `AuditLogLive.Index` LiveView is mounted and renders the audit log table

#### Scenario: Unauthenticated access
- **WHEN** an unauthenticated user navigates to `/dashboard/accounts/:account_id/audit-logs`
- **THEN** they are redirected to the login page

### Requirement: Sidebar navigation link

The dashboard sidebar MUST include an "Audit Logs" link with the `hero-document-text` icon. The link MUST point to the audit log list route for the current account and MUST appear under the existing Overview section.

#### Scenario: Sidebar rendering
- **WHEN** the dashboard layout is rendered for any dashboard page
- **THEN** the sidebar contains an "Audit Logs" link with the `hero-document-text` icon

#### Scenario: Active state
- **WHEN** the user is on the audit log list page
- **THEN** the "Audit Logs" sidebar link is styled as active

### Requirement: Audit log table

The audit log list page MUST display a table of audit log entries with the following columns: Sequence # (`sequence_number`), Timestamp (`timestamp`), Actor (`actor_id`), Action (`action`), Resource (`resource_type` + `resource_id`), Outcome (`outcome`), PHI (`phi_accessed`). Entries MUST be fetched via `GA.Audit.list_logs/2` scoped to `@current_account.id`.

#### Scenario: Table rendering with entries
- **WHEN** the account has audit log entries
- **THEN** the table displays rows with sequence number, formatted timestamp, actor ID, action name, resource type and ID, outcome badge, and PHI badge

#### Scenario: Outcome badge styling
- **WHEN** an entry has outcome `"success"`
- **THEN** the outcome column displays a green success badge
- **WHEN** an entry has outcome `"failure"` or `"denied"`
- **THEN** the outcome column displays a red error badge
- **WHEN** an entry has outcome `"error"`
- **THEN** the outcome column displays a yellow warning badge

#### Scenario: PHI badge
- **WHEN** an entry has `phi_accessed: true`
- **THEN** a small red "PHI" badge is displayed in the PHI column
- **WHEN** an entry has `phi_accessed: false`
- **THEN** the PHI column is empty for that row

### Requirement: Filter bar

The audit log list page MUST include a filter bar with the following controls: date range (from and to date inputs), actor (text input), action (text input), resource type (text input), outcome (dropdown with options: All, Success, Failure, Error, Denied), and PHI accessed (toggle). Changing any filter MUST update the displayed results and push the filter state to URL query parameters via `push_patch/2`.

#### Scenario: Date range filter
- **WHEN** the user sets a "from" date of 2026-01-01 and a "to" date of 2026-01-31
- **THEN** only entries with `timestamp` within that range are displayed
- **AND** the URL query parameters include `from=2026-01-01&to=2026-01-31`

#### Scenario: Actor filter
- **WHEN** the user enters an actor ID in the actor input
- **THEN** only entries with a matching `actor_id` are displayed

#### Scenario: Action filter
- **WHEN** the user enters an action name in the action input
- **THEN** only entries with a matching `action` are displayed

#### Scenario: Resource type filter
- **WHEN** the user enters a resource type in the resource type input
- **THEN** only entries with a matching `resource_type` are displayed

#### Scenario: Outcome filter
- **WHEN** the user selects "Failure" from the outcome dropdown
- **THEN** only entries with `outcome: "failure"` are displayed

#### Scenario: PHI accessed toggle
- **WHEN** the user enables the PHI accessed toggle
- **THEN** only entries with `phi_accessed: true` are displayed

#### Scenario: Combined filters
- **WHEN** the user applies multiple filters simultaneously
- **THEN** all filters are combined with AND logic and only matching entries are shown

#### Scenario: Filter reset
- **WHEN** the user clears all filter values
- **THEN** all entries are displayed without filtering

### Requirement: Cursor-based pagination

The audit log list MUST use cursor-based pagination via the `after_sequence` parameter of `GA.Audit.list_logs/2`. A "Next page" button MUST load the next page of results using the last entry's sequence number as the cursor. A "Back to start" button MUST reset the cursor to load from the beginning. The default page size MUST be 50 entries.

#### Scenario: Initial load
- **WHEN** the page is first loaded with no cursor parameter
- **THEN** the first 50 entries are displayed (ordered by sequence number)

#### Scenario: Next page
- **WHEN** the user clicks "Next page" and the last displayed entry has sequence number 50
- **THEN** the next 50 entries (starting after sequence 50) are loaded and displayed

#### Scenario: Back to start
- **WHEN** the user has paginated forward and clicks "Back to start"
- **THEN** the cursor is reset and the first 50 entries are displayed

#### Scenario: Last page
- **WHEN** the current page returns fewer than 50 entries
- **THEN** the "Next page" button is disabled or hidden

### Requirement: Empty state

When no audit log entries match the current filters (or the account has no entries at all), the page MUST display an empty state message instead of an empty table.

#### Scenario: No entries in account
- **WHEN** the account has zero audit log entries
- **THEN** the page displays an empty state with a message like "No audit log entries yet"

#### Scenario: No matching entries
- **WHEN** filters are applied but no entries match
- **THEN** the page displays an empty state with a message like "No entries match the current filters"

### Requirement: URL query parameter persistence

All active filters and the current pagination cursor MUST be reflected in URL query parameters. Navigating to a URL with query parameters MUST restore the corresponding filter state and results.

#### Scenario: Bookmark and restore
- **WHEN** a user bookmarks a URL with filters `?action=login&outcome=failure`
- **THEN** navigating to that URL restores the action filter to "login", the outcome filter to "failure", and displays matching results

#### Scenario: Browser back button
- **WHEN** the user applies a filter (which pushes a new URL via `push_patch`) and then clicks the browser back button
- **THEN** the previous filter state is restored

### Requirement: Account scoping

All audit log queries MUST be scoped to the current account (`@current_account.id`). Entries belonging to other accounts MUST NOT be visible.

#### Scenario: Account isolation
- **WHEN** account A has 100 entries and account B has 50 entries
- **THEN** a user viewing account A's audit logs sees only account A's 100 entries

### Requirement: JSON export

The audit log list page MUST include an "Export JSON" button that downloads the current filtered result set as a JSON file. The export MUST use the same filters currently applied in the UI. The export MUST be capped at 10,000 entries, and a warning MUST be shown if results are truncated.

#### Scenario: Export with filters
- **WHEN** the user has applied filters and clicks "Export JSON"
- **THEN** a JSON file is downloaded containing entries matching the current filters

#### Scenario: Export content
- **WHEN** the JSON file is downloaded
- **THEN** each entry includes all fields: id, sequence_number, checksum, previous_checksum, actor_id, action, resource_type, resource_id, timestamp, outcome, phi_accessed, extensions, frameworks, metadata

#### Scenario: Export truncation
- **WHEN** the filtered result set exceeds 10,000 entries
- **THEN** only the first 10,000 entries are included in the export and a warning is displayed to the user indicating the results were truncated
