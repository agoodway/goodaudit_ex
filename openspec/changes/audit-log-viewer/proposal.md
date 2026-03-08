## Why

GoodAudit has a full audit log ingestion and verification pipeline, but no way for customers to browse their audit trail through the dashboard. Operators currently rely on the REST API or raw database queries to inspect log entries, which is inaccessible to compliance teams and auditors who need to review events during audit preparation. A built-in audit log viewer in the dashboard gives non-technical stakeholders direct visibility into the audit trail with filtering, search, and export capabilities — reducing audit preparation time and removing the need for custom tooling.

## What Changes

1. **Audit log list LiveView** — A new LiveView at `/dashboard/accounts/:account_id/audit-logs` displays a paginated, filterable table of audit log entries. The table shows sequence number, timestamp, actor, action, resource type + ID, outcome badge, and PHI accessed indicator. Cursor-based pagination uses the existing `after_sequence` parameter from `GA.Audit.list_logs/2`.

2. **Filter bar** — A collapsible filter bar above the table provides: date range pickers (from/to), actor text input, action text input, resource type text input, outcome dropdown (all/success/failure/error/denied), and a PHI accessed toggle. Filters map directly to the existing `list_logs/2` filter options.

3. **Inline detail expansion** — Clicking a table row expands an inline detail panel showing the full entry: metadata map, extensions map, checksum and previous checksum, framework tags, and all fields not shown in the summary row.

4. **JSON export** — An export button downloads the current filtered result set as a JSON file. The export uses the same filters currently applied in the UI and streams through the existing `list_logs/2` API.

5. **Sidebar navigation** — The dashboard sidebar gains an "Audit Logs" link with the `hero-document-text` icon, placed under the existing Overview section.

> **Note:** This change is purely a read-only dashboard view. It does not modify the audit log ingestion pipeline, verification system, or any API endpoints. All data access goes through the existing `GA.Audit` context functions.

## Capabilities

### New Capabilities
- `audit-log-list`: Paginated, filterable table of audit log entries in the dashboard
- `audit-log-detail`: Inline detail expansion showing full entry metadata, extensions, and checksums

### Modified Capabilities
- None

## Impact

- **New files**: `lib/app_web/live/audit_log_live/index.ex`, `lib/app_web/live/audit_log_live/index.html.heex`, `lib/app_web/live/audit_log_live/show_component.ex`
- **Modified file**: `lib/app_web/router.ex` — add `/audit-logs` route under dashboard scope
- **Modified file**: `lib/app_web/components/layouts/dashboard.html.heex` — add sidebar navigation link
- **New tests**: `test/app_web/live/audit_log_live_test.exs`
