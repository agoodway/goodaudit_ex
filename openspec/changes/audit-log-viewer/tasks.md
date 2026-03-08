## 1. Route and Navigation

- [ ] 1.1 Add `live "/audit-logs", AuditLogLive.Index, :index` route under the dashboard account scope in `lib/app_web/router.ex`
- [ ] 1.2 Add "Audit Logs" sidebar link with `hero-document-text` icon to `lib/app_web/components/layouts/dashboard.html.heex` under the Overview section

## 2. Audit Log List LiveView

- [ ] 2.1 Create `lib/app_web/live/audit_log_live/index.ex` — mount with default filters, implement `handle_params/3` to parse URL query params into filter assigns
- [ ] 2.2 Implement filter-to-query mapping — convert socket assigns (from, to, user_id, action, resource_type, outcome, phi_accessed) to `GA.Audit.list_logs/2` opts
- [ ] 2.3 Implement cursor-based pagination — track `after_sequence` in assigns, handle "Next page" and "Back to start" events
- [ ] 2.4 Implement filter change handlers — `handle_event` for each filter field that pushes updated query params via `push_patch/2`
- [ ] 2.5 Implement empty state — show a message with icon when no log entries match current filters

## 3. Audit Log List Template

- [ ] 3.1 Create `lib/app_web/live/audit_log_live/index.html.heex` — page layout using `dash-card`, `dash-card-header`, `dash-card-body` wrappers
- [ ] 3.2 Build filter bar component — collapsible section with date range inputs, actor input, action input, resource type input, outcome dropdown, PHI toggle
- [ ] 3.3 Build log entries table — columns: Sequence #, Timestamp, Actor, Action, Resource (type + id), Outcome badge, PHI badge
- [ ] 3.4 Style outcome badges — `badge badge-success` for success, `badge badge-error` for failure/denied, `badge badge-warning` for error
- [ ] 3.5 Style PHI indicator — `badge badge-error badge-sm` shown when `phi_accessed` is true
- [ ] 3.6 Add pagination controls — "Next page" button, "Back to start" button, entry count display

## 4. Inline Detail Expansion

- [ ] 4.1 Create `lib/app_web/live/audit_log_live/show_component.ex` — stateless function component that renders full entry detail
- [ ] 4.2 Implement row click toggle — `handle_event("toggle_detail", ...)` that tracks expanded row ID in assigns
- [ ] 4.3 Render detail panel — show metadata map, extensions map, checksum, previous_checksum, framework tags in a structured layout below the expanded row
- [ ] 4.4 Style detail panel — use `dash-card-body` with subtle background differentiation, key-value pairs for metadata, code blocks for checksums

## 5. JSON Export

- [ ] 5.1 Implement export handler — `handle_event("export_json", ...)` that queries `list_logs/2` with current filters and a 10,000 entry cap
- [ ] 5.2 Serialize filtered entries to JSON with all fields (metadata, extensions, checksums, frameworks)
- [ ] 5.3 Trigger browser download via `push_event` to a client-side JS hook
- [ ] 5.4 Show truncation warning when export result set exceeds 10,000 entries

## 6. Tests

- [ ] 6.1 Test LiveView mount — renders table structure, shows sidebar link as active
- [ ] 6.2 Test filter application — applying each filter type updates displayed results
- [ ] 6.3 Test cursor pagination — "Next page" advances cursor, "Back to start" resets
- [ ] 6.4 Test inline detail expansion — clicking row shows detail panel with metadata and checksums
- [ ] 6.5 Test empty state — no entries renders empty state message
- [ ] 6.6 Test JSON export — export event returns JSON with correct entries matching filters
- [ ] 6.7 Test URL query parameter round-trip — filter state is preserved in URL and restored on navigation
- [ ] 6.8 Test account scoping — entries from other accounts are not visible
