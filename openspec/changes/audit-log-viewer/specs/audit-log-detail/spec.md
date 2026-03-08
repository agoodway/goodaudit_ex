## ADDED Requirements

### Requirement: Inline detail expansion

Clicking a row in the audit log table MUST toggle an inline detail panel below that row. Only one row MUST be expanded at a time — expanding a new row collapses the previously expanded row. The detail panel MUST display the full audit log entry fetched via `GA.Audit.get_log/2`.

#### Scenario: Expand row
- **WHEN** the user clicks on an audit log table row
- **THEN** a detail panel expands below the clicked row showing full entry details

#### Scenario: Collapse row
- **WHEN** the user clicks on an already expanded row
- **THEN** the detail panel collapses

#### Scenario: Switch expansion
- **WHEN** row A is expanded and the user clicks on row B
- **THEN** row A's detail panel collapses and row B's detail panel expands

### Requirement: Detail panel content

The expanded detail panel MUST display the following information from the audit log entry:

- **Checksums**: `checksum` and `previous_checksum` displayed in monospace font
- **Metadata**: The full `metadata` map rendered as key-value pairs
- **Extensions**: The full `extensions` map rendered as key-value pairs
- **Framework tags**: The `frameworks` array displayed as badges
- **Full timestamps**: The `timestamp` in full ISO 8601 format with timezone

#### Scenario: Checksum display
- **WHEN** the detail panel is expanded for an entry
- **THEN** the `checksum` and `previous_checksum` values are displayed in monospace font with labels

#### Scenario: Metadata rendering
- **WHEN** the entry has a metadata map with keys `ip_address`, `user_agent`, and `request_id`
- **THEN** the detail panel displays each key-value pair from the metadata map

#### Scenario: Empty metadata
- **WHEN** the entry has an empty metadata map (`%{}`)
- **THEN** the metadata section displays "No metadata" or is omitted

#### Scenario: Extensions rendering
- **WHEN** the entry has an extensions map with custom fields
- **THEN** the detail panel displays each key-value pair from the extensions map

#### Scenario: Empty extensions
- **WHEN** the entry has an empty extensions map (`%{}`)
- **THEN** the extensions section displays "No extensions" or is omitted

#### Scenario: Framework tags
- **WHEN** the entry has `frameworks: ["hipaa", "soc2"]`
- **THEN** the detail panel displays "hipaa" and "soc2" as badge elements

#### Scenario: No framework tags
- **WHEN** the entry has an empty frameworks list (`[]`)
- **THEN** the frameworks section displays "No frameworks" or is omitted

### Requirement: Detail panel styling

The detail panel MUST use the project's existing DaisyUI and utility class conventions. It MUST be visually distinct from the table rows to clearly indicate it is supplementary detail.

#### Scenario: Visual distinction
- **WHEN** a detail panel is expanded
- **THEN** it uses a `dash-card-body` wrapper with a subtle background color distinct from the table rows

#### Scenario: Responsive layout
- **WHEN** the detail panel is viewed on a narrow screen
- **THEN** the content reflows to a single-column layout without horizontal overflow

### Requirement: Show component implementation

The detail panel MUST be implemented as a stateless function component at `GAWeb.AuditLogLive.ShowComponent`. It MUST accept an audit log entry as an assign and render the detail layout. This keeps the detail rendering reusable and testable independent of the list LiveView.

#### Scenario: Component rendering
- **WHEN** `ShowComponent` is called with a full audit log entry
- **THEN** it renders all detail sections (checksums, metadata, extensions, frameworks, timestamp)

#### Scenario: Component isolation
- **WHEN** `ShowComponent` is rendered with an entry that has nil or empty optional fields
- **THEN** it handles missing data gracefully without errors
