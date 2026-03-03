## ADDED Requirements

### Requirement: Account-scoped cursor-based pagination

`list_logs(account_id, opts)` MUST always filter by `account_id` and support cursor-based pagination using an `after_sequence` parameter. It MUST return `{entries, next_cursor}` where `next_cursor` is the last entry's sequence number if more pages exist, or `nil` if this is the final page. The default limit MUST be 50 and the maximum MUST be 1000. Entries from other accounts MUST never be included.

#### Scenario: First page for an account
- **WHEN** `list_logs(account_id)` is called without `after_sequence`
- **THEN** it returns entries for that account starting from sequence 1, ordered ascending, up to the limit

#### Scenario: Next page via cursor
- **WHEN** `list_logs(account_id, after_sequence: 50)` is called
- **THEN** it returns entries for that account with `sequence_number > 50`

#### Scenario: Last page
- **WHEN** `list_logs(account_id)` returns fewer entries than the limit
- **THEN** `next_cursor` is `nil`

#### Scenario: Limit clamping
- **WHEN** `list_logs(account_id, limit: 5000)` is called
- **THEN** the effective limit is clamped to 1000

#### Scenario: Account isolation
- **WHEN** `list_logs(account_a_id)` is called
- **THEN** no entries belonging to account B are returned

### Requirement: Multi-field filtering within account

`list_logs(account_id, opts)` MUST accept filter options: `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `phi_accessed` (boolean), `from` (datetime, inclusive), `to` (datetime, inclusive). Filters MUST be combinable. All filtering is in addition to the implicit `account_id` filter.

#### Scenario: Single filter
- **WHEN** `list_logs(account_id, user_id: "user-1")` is called
- **THEN** only entries for that account with `user_id == "user-1"` are returned

#### Scenario: Combined filters
- **WHEN** `list_logs(account_id, user_id: "user-1", action: "read", phi_accessed: true)` is called
- **THEN** only entries for that account matching all three filters are returned

#### Scenario: Date range filter
- **WHEN** `list_logs(account_id, from: ~U[2025-01-01 00:00:00Z], to: ~U[2025-01-31 23:59:59Z])` is called
- **THEN** only entries for that account with timestamp within the range (inclusive) are returned

### Requirement: Account-scoped single entry retrieval

`get_log(account_id, id)` MUST accept an account_id and entry ID, querying with both to enforce tenant isolation. It MUST return `{:ok, %Log{}}` if found within the account or `{:error, :not_found}` if not.

#### Scenario: Entry found in account
- **WHEN** `get_log(account_id, id)` is called with a valid existing ID belonging to that account
- **THEN** it returns `{:ok, %Log{}}` with the full entry

#### Scenario: Entry not found
- **WHEN** `get_log(account_id, id)` is called with a nonexistent ID
- **THEN** it returns `{:error, :not_found}`

#### Scenario: Entry exists but belongs to different account
- **WHEN** `get_log(account_a_id, entry_id)` is called where `entry_id` belongs to account B
- **THEN** it returns `{:error, :not_found}` (tenant isolation enforced)
