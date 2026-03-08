## ADDED Requirements

### Requirement: Count audit logs for account

`GA.Audit.count_logs(account_id, opts \\ [])` MUST return the integer count of audit log entries for the given account. By default it MUST count only entries with `inserted_at` within the last 30 days. It MUST accept an optional `since` datetime in `opts` to override the time window. It MUST return `0` if no entries match.

#### Scenario: Default 30-day count
- **WHEN** `count_logs(account_id)` is called for an account with 10 logs in the last 30 days and 5 logs older than 30 days
- **THEN** it returns `10`

#### Scenario: Custom since parameter
- **WHEN** `count_logs(account_id, since: ~U[2026-01-01 00:00:00Z])` is called
- **THEN** it returns the count of entries with `inserted_at >= 2026-01-01`

#### Scenario: Empty account
- **WHEN** `count_logs(account_id)` is called for an account with no audit logs
- **THEN** it returns `0`

#### Scenario: Account isolation
- **WHEN** `count_logs(account_a_id)` is called and account B has 100 logs
- **THEN** account B's logs are not included in the count

### Requirement: Recent audit logs for account

`GA.Audit.recent_logs(account_id, limit \\ 5)` MUST return a list of the most recent audit log entries for the given account, ordered by `inserted_at` descending, limited to `limit` entries. It MUST return an empty list if the account has no logs.

#### Scenario: Default limit
- **WHEN** `recent_logs(account_id)` is called for an account with 20 logs
- **THEN** it returns the 5 most recent entries ordered newest first

#### Scenario: Custom limit
- **WHEN** `recent_logs(account_id, 3)` is called
- **THEN** it returns at most 3 entries

#### Scenario: Fewer entries than limit
- **WHEN** `recent_logs(account_id)` is called for an account with 2 logs
- **THEN** it returns 2 entries

#### Scenario: Empty account
- **WHEN** `recent_logs(account_id)` is called for an account with no logs
- **THEN** it returns `[]`

#### Scenario: Account isolation
- **WHEN** `recent_logs(account_a_id)` is called
- **THEN** only logs belonging to account A are returned

### Requirement: Count active API keys for account

`GA.Accounts.count_active_api_keys(account_id)` MUST return the integer count of API keys for the given account that are not revoked and not expired. A key is considered expired if `expires_at` is not nil and `expires_at < now()`. It MUST return `0` if no active keys exist.

#### Scenario: Mixed key states
- **WHEN** `count_active_api_keys(account_id)` is called for an account with 2 active keys, 1 revoked key, and 1 expired key
- **THEN** it returns `2`

#### Scenario: Key with no expiry
- **WHEN** an API key has `expires_at = nil` and `status != "revoked"`
- **THEN** it is counted as active

#### Scenario: No keys
- **WHEN** `count_active_api_keys(account_id)` is called for an account with no API keys
- **THEN** it returns `0`

#### Scenario: Account isolation
- **WHEN** `count_active_api_keys(account_a_id)` is called and account B has 5 active keys
- **THEN** account B's keys are not included in the count

### Requirement: Count active compliance frameworks for account

`GA.Compliance.count_active_frameworks(account_id)` MUST return the integer count of compliance frameworks activated for the given account where `active = true`. It MUST return `0` if no active frameworks exist.

#### Scenario: Active and inactive frameworks
- **WHEN** `count_active_frameworks(account_id)` is called for an account with 2 active frameworks and 1 inactive framework
- **THEN** it returns `2`

#### Scenario: No frameworks
- **WHEN** `count_active_frameworks(account_id)` is called for an account with no framework activations
- **THEN** it returns `0`

#### Scenario: Account isolation
- **WHEN** `count_active_frameworks(account_a_id)` is called and account B has 3 active frameworks
- **THEN** account B's frameworks are not included in the count

## MODIFIED Requirements

### Requirement: Dashboard metric cards display live data

The dashboard metric cards MUST display real data from the database instead of hardcoded values. The "Compliance Score" card MUST be replaced with "Active Frameworks" showing `count_active_frameworks`. The "Open Findings" card MUST be replaced with "Chain Status" showing the verification result. The "Audit Logs" card MUST show `count_logs` with the "last 30d" label. The "API Keys" card MUST show `count_active_api_keys`.

#### Scenario: Dashboard with seeded data
- **WHEN** the dashboard is loaded for an account with 42 audit logs in the last 30 days, 3 active API keys, 2 active frameworks, and a verified chain
- **THEN** the metric cards show "42" for Audit Logs, "3" for API Keys, "2" for Active Frameworks, and "verified" for Chain Status

#### Scenario: Dashboard with empty account
- **WHEN** the dashboard is loaded for a new account with no data
- **THEN** the metric cards show "0" for Audit Logs, "0" for API Keys, "0" for Active Frameworks, and "no logs" for Chain Status

### Requirement: Dashboard recent activity shows real audit logs

The recent activity section MUST display the last 5 audit log entries from the database. Each row MUST show the log entry's action as the title, resource type and actor as the detail, and inserted_at as a relative timestamp. If no logs exist, the section MUST show an empty state.

#### Scenario: Recent activity with logs
- **WHEN** the dashboard is loaded for an account with audit logs
- **THEN** the recent activity section shows up to 5 log entries with real action, resource type, actor, and relative time

#### Scenario: Recent activity empty
- **WHEN** the dashboard is loaded for an account with no audit logs
- **THEN** the recent activity section shows an empty state message

### Requirement: Getting started checklist reflects account state

The getting started checklist MUST dynamically determine step completion. Step 1 "Configure Framework" MUST be complete when the account has at least one active compliance framework. Step 3 "Create API Key" MUST be complete when the account has at least one active API key. Step 2 "Connect Integrations" MUST remain incomplete.

#### Scenario: New account with no setup
- **WHEN** the dashboard is loaded for an account with no frameworks and no API keys
- **THEN** all three steps show as incomplete

#### Scenario: Fully configured account
- **WHEN** the dashboard is loaded for an account with at least one active framework and at least one active API key
- **THEN** Step 1 and Step 3 show as complete, Step 2 shows as incomplete

#### Scenario: Partial setup — framework only
- **WHEN** the dashboard is loaded for an account with an active framework but no API keys
- **THEN** Step 1 shows as complete, Steps 2 and 3 show as incomplete
