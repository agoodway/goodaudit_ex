## Context

The authenticated dashboard (`GAWeb.DashboardLive`) is the first screen users see after login. It currently renders entirely hardcoded mock data: a fake 98% compliance score, 3 fake open findings, 1,247 fake audit logs, 2 fake API keys, four fabricated recent activity rows, and a partially hardcoded getting started checklist. The underlying database tables and context modules (`GA.Audit`, `GA.Accounts`, `GA.Compliance`) already exist with real data, but the dashboard does not query them. This change wires the dashboard to live data.

## Goals / Non-Goals

**Goals:**
- Replace all four metric cards with live database queries scoped to the current account.
- Replace hardcoded recent activity with actual audit log entries.
- Make the getting started checklist reflect real account state (active frameworks, active API keys).
- Add thin convenience query functions to existing context modules rather than putting query logic in the LiveView.
- Keep the dashboard mount fast — simple indexed queries only.

**Non-Goals:**
- Adding real-time PubSub updates to the dashboard (polling or push can come later).
- Building a health check system for the System Status panel (stays hardcoded).
- Adding a real compliance scoring engine (the card is renamed to "Active Frameworks" instead).
- Adding a real findings/issues tracker (the card is renamed to "Chain Status" instead).
- Changing the visual design or CSS of the dashboard.
- Adding new routes or API endpoints.

## Decisions

### Convenience functions in context modules, not in the LiveView

Dashboard queries are added as dedicated functions in `GA.Audit`, `GA.Accounts`, and `GA.Compliance` rather than inlining Ecto queries in the LiveView. This keeps the LiveView thin, makes the queries testable in isolation, and follows the existing pattern where all data access goes through context modules.

### count_logs uses a 30-day rolling window by default

`GA.Audit.count_logs(account_id, opts)` defaults to `since: 30 days ago` to match the dashboard label "last 30d". The `opts` parameter accepts an explicit `since` datetime for flexibility. The query uses `Repo.aggregate/3` with `:count` on the `audit_logs` table filtered by `account_id` and `inserted_at >= since`.

### Chain status replaces "Open Findings"

There is no findings/issues system in the codebase. Rather than showing a fake count, the card is renamed to "Chain Status" and shows the result of calling `GA.Audit.verify_chain(account_id)` — either "verified" (green) or "broken" (red). This surfaces real, useful integrity information. If the account has no audit logs yet, it shows "no logs" in a neutral state.

### Active Frameworks replaces "Compliance Score"

There is no scoring engine. The card is renamed to "Active Frameworks" and shows the count from `GA.Compliance.count_active_frameworks(account_id)`, which counts rows in `account_compliance_frameworks` where `active = true` for the account. This is honest and immediately useful.

### Active API keys count excludes revoked and expired

`GA.Accounts.count_active_api_keys(account_id)` counts API keys where `status != "revoked"` and (`expires_at IS NULL` or `expires_at > now()`). This matches what a user would consider "active" keys.

### Recent activity maps audit log fields to display attributes

Each recent audit log entry is rendered with: the `action` as the title, `resource_type` and `actor_id` as the detail line, and `inserted_at` formatted as a relative timestamp. Icon and color are derived from the `action` field using a simple mapping (e.g., `create` gets a plus icon, `delete` gets a trash icon, `login`/`logout` get key icons, default gets a document icon).

### Getting started checklist is computed from counts

Step 1 complete = `count_active_frameworks > 0`. Step 3 complete = `count_active_api_keys > 0`. Step 2 stays `false` (no integration system). This avoids extra queries since the framework and API key counts are already fetched for the metric cards.

## Risks / Trade-offs

### Dashboard mount adds database queries

The current mount does zero database work. After this change, mount performs 4 queries: count_logs, count_active_api_keys, count_active_frameworks, and recent_logs (plus verify_chain which may do its own query). All queries are indexed and scoped to a single account_id, so they should complete in low single-digit milliseconds. If performance becomes a concern, results can be cached or loaded asynchronously via `assign_async` in a follow-up.

### Chain verification on every mount may be expensive for large accounts

`GA.Audit.verify_chain/1` traverses the HMAC chain. For accounts with many logs this could be slow. Mitigation: if the existing implementation is a full scan, the dashboard should call it and handle the result, but a follow-up change could cache the last verification result or use the incremental verification system. For now, we call it and accept the cost since most accounts are small.

### No real-time updates

The dashboard shows data as of mount time. If a user creates an API key in another tab, the dashboard will not update until refresh. This is acceptable for an initial implementation. PubSub-driven updates can be added later.
