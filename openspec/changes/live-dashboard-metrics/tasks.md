## 1. Context Query Functions

- [x] 1.1 Add `GA.Audit.count_logs(account_id, opts \\ [])` — count audit log entries for the account, default `since: 30 days ago`, accepts optional `since` datetime override
- [x] 1.2 Add `GA.Audit.recent_logs(account_id, limit \\ 5)` — return the most recent `limit` audit log entries for the account, ordered by `inserted_at` descending
- [x] 1.3 Add `GA.Accounts.count_active_api_keys(account_id)` — count API keys where status is not revoked and not expired
- [x] 1.4 Add `GA.Compliance.count_active_frameworks(account_id)` — count active compliance frameworks for the account

## 2. Dashboard LiveView Updates

- [x] 2.1 Update `DashboardLive.mount/3` to call all four context query functions and `GA.Audit.verify_chain/1`, assigning results to socket
- [x] 2.2 Replace "Compliance Score" metric card with "Active Frameworks" showing `@active_frameworks_count`
- [x] 2.3 Replace "Open Findings" metric card with "Chain Status" showing verification result from `@chain_status`
- [x] 2.4 Replace hardcoded "Audit Logs" metric card value with `@audit_log_count` and keep "last 30d" label
- [x] 2.5 Replace hardcoded "API Keys" metric card value with `@active_api_keys_count`
- [x] 2.6 Replace hardcoded recent activity rows with dynamic rendering of `@recent_logs`, mapping action to icon/color and formatting timestamps as relative
- [x] 2.7 Update getting started checklist: Step 1 `complete` bound to `@active_frameworks_count > 0`, Step 3 `complete` bound to `@active_api_keys_count > 0`, Step 2 stays `false`
- [x] 2.8 Add code comment to System Status section noting it awaits a health check system

## 3. Helper Functions

- [x] 3.1 Add `action_icon/1` private function in `DashboardLive` — maps audit log action strings to hero icon names
- [x] 3.2 Add `action_color/1` private function in `DashboardLive` — maps audit log action strings to Tailwind color classes
- [x] 3.3 Add `relative_time/1` private function in `DashboardLive` — formats a datetime as a human-readable relative string (e.g., "2 hours ago", "3 days ago")
- [x] 3.4 Add `format_activity_detail/1` private function in `DashboardLive` — builds detail string from audit log entry fields (resource_type, actor_id)

## 4. Tests

- [x] 4.1 Test `GA.Audit.count_logs/2` — returns correct count with default 30-day window, respects custom `since`, scoped to account, returns 0 for empty account
- [x] 4.2 Test `GA.Audit.recent_logs/2` — returns entries in descending order, respects limit, scoped to account, returns empty list for empty account
- [x] 4.3 Test `GA.Accounts.count_active_api_keys/1` — counts only non-revoked non-expired keys, excludes revoked keys, excludes expired keys, scoped to account
- [x] 4.4 Test `GA.Compliance.count_active_frameworks/1` — counts only active frameworks, scoped to account, returns 0 for no frameworks
- [x] 4.5 Test `DashboardLive` renders real metric values from database — mount with seeded data, assert metric card values match expected counts
- [x] 4.6 Test `DashboardLive` renders recent activity from audit logs — mount with seeded logs, assert activity rows contain real action and resource data
- [x] 4.7 Test `DashboardLive` getting started checklist reflects account state — assert step completion matches presence of frameworks and API keys
