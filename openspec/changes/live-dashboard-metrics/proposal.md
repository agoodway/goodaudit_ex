## Why

The dashboard currently displays entirely hardcoded mock data — fake compliance scores, fake finding counts, fake audit log totals, and fake recent activity rows. This means the first screen an authenticated user sees tells them nothing real about their account. Replacing these mocks with live database queries makes the dashboard genuinely useful, gives users immediate feedback when they create API keys or activate frameworks, and removes a source of confusion where the UI implies capabilities (e.g., "Open Findings") that have no backing system yet.

## What Changes

1. **Real metric cards** — Replace the four hardcoded metric cards with live queries. "Audit Logs" shows the count of logs in the last 30 days via `GA.Audit.count_logs/2`. "API Keys" shows active (non-revoked, non-expired) keys via `GA.Accounts.count_active_api_keys/1`. "Compliance Score" is replaced by "Active Frameworks" showing the count of active compliance frameworks via `GA.Compliance.count_active_frameworks/1`. "Open Findings" is replaced by "Chain Status" showing the result of the last chain verification via `GA.Audit.verify_chain/1`.

2. **Live recent activity** — Replace the four hardcoded activity rows with the last 5 actual audit log entries from the database via `GA.Audit.recent_logs/2`, rendered with real action, actor, resource type, and relative timestamps.

3. **Dynamic getting started checklist** — Step 1 "Configure Framework" is complete when the account has at least one active compliance framework. Step 3 "Create API Key" is complete when the account has at least one active API key. Step 2 "Connect Integrations" stays incomplete (no integration system exists yet).

4. **System status annotation** — The System Status section remains hardcoded but receives a code comment noting it awaits a health check system. No user-facing change.

5. **New context functions** — Add `GA.Audit.count_logs/2`, `GA.Audit.recent_logs/2`, `GA.Accounts.count_active_api_keys/1`, and `GA.Compliance.count_active_frameworks/1` to support the dashboard queries.

## Capabilities

### New Capabilities
- `dashboard-metrics`: Live database-backed metric cards, recent activity feed, and dynamic getting started checklist on the authenticated dashboard

### Modified Capabilities
- `entry-querying`: New `count_logs/2` and `recent_logs/2` convenience functions added to `GA.Audit`

## Impact

- **Modified file**: `app/lib/app_web/live/dashboard_live.ex` — replace hardcoded assigns with live queries in `mount/3`, update template to render dynamic data
- **Modified file**: `app/lib/app/audit.ex` — add `count_logs/2` and `recent_logs/2`
- **Modified file**: `app/lib/app/accounts.ex` — add `count_active_api_keys/1`
- **Modified file**: `app/lib/app/compliance.ex` — add `count_active_frameworks/1`
- **New tests**: `app/test/app/audit/dashboard_queries_test.exs`, `app/test/app/accounts/dashboard_queries_test.exs`, `app/test/app/compliance/dashboard_queries_test.exs`, `app/test/app_web/live/dashboard_live_test.exs`
