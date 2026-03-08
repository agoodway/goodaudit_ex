## Context

GoodAudit provides tamper-evident audit logging with HMAC chains, checkpoints, and scoped API keys. The existing `GA.Audit` context exposes `list_logs/2` and `get_log/2` with comprehensive filtering (date range, actor, action, resource type, outcome, PHI accessed, cursor-based pagination via `after_sequence`). However, there is no dashboard UI for browsing audit entries — customers must use the REST API or database access. This change adds a LiveView-based audit log viewer to the existing dashboard, giving compliance teams and auditors direct access to the audit trail.

## Goals / Non-Goals

**Goals:**
- Provide a searchable, filterable, paginated audit log table in the dashboard.
- Support all existing `list_logs/2` filter parameters through the UI.
- Show full entry detail (metadata, extensions, checksums, frameworks) via inline row expansion.
- Enable JSON export of filtered results for offline review and audit evidence.
- Integrate naturally into the existing dashboard layout and DaisyUI theming.

**Non-Goals:**
- Adding new query capabilities beyond what `GA.Audit.list_logs/2` already supports.
- Real-time streaming or live-updating log entries via PubSub.
- Editing, deleting, or annotating audit log entries from the UI.
- Building a separate detail page with its own route (inline expansion is sufficient for v1).
- Adding chain verification UI (that is a separate concern).
- Full-text search across metadata/extensions content.

## Decisions

### LiveView with server-side filtering and pagination

All filtering and pagination happens server-side through the existing `GA.Audit.list_logs/2` function. The LiveView sends filter changes as events that update socket assigns and re-query. This keeps the client thin, ensures consistent results with the API, and avoids duplicating query logic. Cursor-based pagination using `after_sequence` is a natural fit since LiveView can track the current cursor position in assigns.

### Inline detail expansion instead of separate route

Clicking a row toggles an expanded detail section below it rather than navigating to a separate page. This keeps the user in context (they can see surrounding entries), reduces route complexity, and matches the pattern used by other dashboard tools. The expanded section uses `GA.Audit.get_log/2` to fetch the full entry including metadata and extensions.

### Filter state in URL query parameters

Filter values are pushed to the URL as query parameters via `push_patch/2`. This makes filtered views bookmarkable and shareable, and the browser back button works naturally. The `handle_params/3` callback parses query parameters into the filter struct on every navigation.

### DaisyUI table and form components

The table uses DaisyUI's `table` component classes with the project's existing `dash-card`, `dash-card-header`, and `dash-card-body` utility classes for the container. Filter inputs use DaisyUI form controls. Outcome badges use DaisyUI `badge` variants (success/error/warning/info). The PHI indicator uses a small `badge badge-error` when `phi_accessed` is true.

### JSON export via temporary download

The export button triggers a `handle_event` that calls `list_logs/2` with the current filters (no limit), serializes to JSON, and sends the file via `push_event` to a client-side hook that triggers a download. This avoids a separate controller endpoint while keeping the export consistent with the displayed filters.

## Risks / Trade-offs

### Large result sets on export

Exporting without a limit could produce large JSON files for accounts with millions of entries. Mitigation: cap the export at 10,000 entries and show a warning if the result set is truncated. A future iteration could add background export with download links.

### Filter bar complexity

Six filter fields plus a toggle may feel overwhelming on smaller screens. Mitigation: the filter bar is collapsible (hidden by default on mobile) and uses a responsive grid layout. The most common filters (date range and action) are positioned first.

### No real-time updates

The table shows a point-in-time snapshot. New entries arriving after page load are not shown until the user refreshes or paginates. This is acceptable for an audit review workflow where users are examining historical data, not monitoring a live stream.

### Cursor pagination is forward-only

The existing `after_sequence` cursor only supports forward pagination. Users cannot page backward to previous results. Mitigation: display a "Back to start" button that resets the cursor, and show the current page range. Backward pagination can be added later if needed by supporting a `before_sequence` parameter in `list_logs/2`.
