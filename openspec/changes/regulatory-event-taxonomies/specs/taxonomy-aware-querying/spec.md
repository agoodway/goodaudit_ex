## ADDED Requirements

### Requirement: Category filter on list_logs

`list_logs(account_id, opts)` MUST accept a `category` filter option. The category filter value is a string in the format `"framework:pattern"` where `framework` is a registered framework identifier and `pattern` is a dot-separated taxonomy path that may end with `"*"` for wildcard matching. Examples: `"hipaa:access.*"`, `"hipaa:access.phi.*"`, `"hipaa:access.phi.phi_read"`, `"soc2:change.*"`.

#### Scenario: Category filter with category wildcard
- **WHEN** `list_logs(account_id, category: "hipaa:access.*")` is called
- **THEN** the query resolves `"access.*"` against the HIPAA taxonomy to find all access actions, also finds custom actions mapped to any HIPAA access path for this account, and returns entries where `action` is in the combined set

#### Scenario: Category filter with subcategory wildcard
- **WHEN** `list_logs(account_id, category: "hipaa:access.phi.*")` is called
- **THEN** only entries whose `action` matches PHI-specific access actions (`"phi_read"`, `"phi_write"`, `"phi_delete"`) or custom actions mapped to `"access.phi.*"` paths are returned

#### Scenario: Category filter with exact path
- **WHEN** `list_logs(account_id, category: "hipaa:access.phi.phi_read")` is called
- **THEN** only entries whose `action` is `"phi_read"` or custom actions mapped to `"access.phi.phi_read"` are returned

#### Scenario: Category filter combined with other filters
- **WHEN** `list_logs(account_id, category: "hipaa:access.*", user_id: "user-1", from: ~U[2025-01-01 00:00:00Z])` is called
- **THEN** all filters are applied conjunctively: the entry must match the category, user_id, and date range

#### Scenario: Category filter with no matching entries
- **WHEN** `list_logs(account_id, category: "hipaa:disclosure.unauthorized.*")` is called and no entries have matching actions
- **THEN** an empty result set is returned with `next_cursor: nil`

### Requirement: Category filter resolution through mappings

When resolving a category filter, `list_logs/2` MUST include both canonical taxonomy actions and any custom actions that the account has mapped to matching taxonomy paths. This ensures that accounts using custom action names see their events in category-based queries without renaming historical data.

#### Scenario: Custom-mapped actions included
- **WHEN** an account has mapped `"patient_chart_viewed"` to HIPAA path `"access.phi.phi_read"` and `list_logs(account_id, category: "hipaa:access.phi.*")` is called
- **THEN** entries with `action: "patient_chart_viewed"` are included alongside entries with `action: "phi_read"`, `"phi_write"`, or `"phi_delete"`

#### Scenario: Multiple mappings to same category
- **WHEN** an account has mapped both `"view_chart"` and `"open_record"` to HIPAA path `"access.phi.phi_read"`
- **THEN** entries with either `action: "view_chart"` or `action: "open_record"` are included when filtering by `"hipaa:access.phi.*"`

#### Scenario: No mappings exist for account
- **WHEN** an account has no action mappings and `list_logs(account_id, category: "hipaa:access.*")` is called
- **THEN** only entries with canonical HIPAA access actions are returned

### Requirement: Category filter validation

The `category` filter value MUST be validated before query execution. If the framework prefix is not a registered framework, the query MUST return `{:error, :unknown_framework}`. If the pattern after the framework prefix does not resolve to any taxonomy paths, the query MUST return `{:error, :invalid_category_path}`.

#### Scenario: Unknown framework in category filter
- **WHEN** `list_logs(account_id, category: "unknown:access.*")` is called
- **THEN** it returns `{:error, :unknown_framework}`

#### Scenario: Invalid path in category filter
- **WHEN** `list_logs(account_id, category: "hipaa:nonexistent.*")` is called
- **THEN** it returns `{:error, :invalid_category_path}`

#### Scenario: Missing framework prefix
- **WHEN** `list_logs(account_id, category: "access.*")` is called without a framework prefix
- **THEN** it returns `{:error, :invalid_category_format}` indicating the `"framework:pattern"` format is required

### Requirement: Category filter generates bounded IN clause

The category resolution MUST produce a bounded set of action strings for the SQL `WHERE action IN (...)` clause. The set is the union of canonical taxonomy actions matching the pattern and custom-mapped actions for the account. The total number of actions in the set is bounded by the taxonomy size plus the account's mapping count, which are both administratively limited.

#### Scenario: Action set construction
- **WHEN** HIPAA `"access.*"` resolves to 6 taxonomy actions and the account has 3 custom actions mapped to access paths
- **THEN** the generated query uses `WHERE action IN ('phi_read', 'phi_write', 'phi_delete', 'login', 'logout', 'session_timeout', 'patient_chart_viewed', 'nurse_login', 'doctor_login')`

#### Scenario: No wildcard — single action
- **WHEN** `"hipaa:access.phi.phi_read"` resolves to 1 taxonomy action and 1 mapped action
- **THEN** the generated query uses `WHERE action IN ('phi_read', 'patient_chart_viewed')`

### Requirement: Category filter in audit log API endpoint

The `GET /api/v1/audit-logs` endpoint MUST accept an optional `category` query parameter with the same `"framework:pattern"` format. Invalid category values MUST return HTTP 422 with a descriptive error message.

#### Scenario: API category filter
- **WHEN** `GET /api/v1/audit-logs?category=hipaa:access.*` is called with a valid read key
- **THEN** the response contains only entries matching the category filter, with standard pagination

#### Scenario: API invalid category
- **WHEN** `GET /api/v1/audit-logs?category=badformat` is called
- **THEN** the response is HTTP 422 with `{"status": 422, "message": "Invalid category format. Expected 'framework:pattern'"}`

#### Scenario: API unknown framework in category
- **WHEN** `GET /api/v1/audit-logs?category=unknown:access.*` is called
- **THEN** the response is HTTP 422 with `{"status": 422, "message": "Unknown framework: unknown"}`

### Requirement: Category filter with cursor pagination

The `category` filter MUST work correctly with existing cursor-based pagination. The cursor (`after_sequence`) MUST be applied after the category filter, producing consistent page boundaries.

#### Scenario: Paginated category query
- **WHEN** `list_logs(account_id, category: "hipaa:access.*", limit: 10)` returns 10 entries with `next_cursor: 42`
- **THEN** `list_logs(account_id, category: "hipaa:access.*", after_sequence: 42, limit: 10)` returns the next page of matching entries
