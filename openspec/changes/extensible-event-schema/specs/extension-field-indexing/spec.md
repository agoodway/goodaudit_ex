## ADDED Requirements

### Requirement: GIN index on extensions column

The `audit_logs` table MUST have a GIN index on the `extensions` JSONB column to support efficient containment queries (`@>` operator). The index MUST be created in the same migration that creates the `audit_logs` table.

#### Scenario: GIN index created
- **WHEN** the migration runs
- **THEN** a GIN index is created on `audit_logs.extensions`

#### Scenario: Containment query uses GIN index
- **WHEN** a query filters with `WHERE extensions @> '{"hipaa": {"phi_accessed": true}}'`
- **THEN** the query planner uses the GIN index rather than a sequential scan

#### Scenario: Multi-framework containment query
- **WHEN** a query filters with `WHERE extensions @> '{"hipaa": {"phi_accessed": true}, "soc2": {"change_ticket_id": "JIRA-123"}}'`
- **THEN** the GIN index supports the combined containment predicate

### Requirement: Partial expression indexes for high-frequency extension paths

Partial expression indexes MUST be created for known high-frequency query patterns on extension fields. Each index MUST be scoped to rows where the relevant framework sub-map exists (`extensions->'<framework>' IS NOT NULL`). Initial indexes MUST cover the HIPAA `phi_accessed` path. Additional framework-specific indexes are added as frameworks are onboarded.

#### Scenario: HIPAA phi_accessed partial index
- **WHEN** the migration runs
- **THEN** a partial B-tree index is created on `(extensions->'hipaa'->>'phi_accessed')` with condition `WHERE extensions->'hipaa' IS NOT NULL`

#### Scenario: Index used for HIPAA phi_accessed filter
- **WHEN** a query filters with `WHERE extensions->'hipaa'->>'phi_accessed' = 'true'`
- **THEN** the query planner uses the partial expression index

#### Scenario: Index not scanned for non-HIPAA accounts
- **WHEN** a query runs for an account whose entries have no `hipaa` key in extensions
- **THEN** the partial index condition (`extensions->'hipaa' IS NOT NULL`) excludes those rows from the index entirely, keeping the index compact

### Requirement: Account-scoped extension queries

Extension field queries MUST always include `account_id` in the predicate to leverage the existing composite indexes and maintain tenant isolation. The application MUST NOT allow cross-tenant extension queries.

#### Scenario: Extension query includes account scope
- **WHEN** `GA.Audit.list_entries(account_id, filters)` is called with an extension filter like `%{"hipaa" => %{"phi_accessed" => true}}`
- **THEN** the generated SQL includes `WHERE account_id = $1 AND extensions @> $2`

#### Scenario: Extension filter without account rejected
- **WHEN** a query builder attempts to filter on extensions without providing an account_id
- **THEN** the query is rejected at the application layer before execution

### Requirement: JSONB path query support in entry querying

The entry querying API MUST support filtering on extension fields using JSONB path expressions. Filters MUST be expressed as framework-namespaced paths: `extensions.hipaa.phi_accessed = true`, `extensions.soc2.change_ticket_id = "JIRA-123"`. The query builder MUST translate these into parameterized JSONB operators (`@>`, `->>`, `->`) to prevent SQL injection.

#### Scenario: Filter by boolean extension field
- **WHEN** entries are queried with filter `%{"extensions" => %{"hipaa" => %{"phi_accessed" => true}}}`
- **THEN** only entries where `extensions @> '{"hipaa": {"phi_accessed": true}}'` are returned

#### Scenario: Filter by string extension field
- **WHEN** entries are queried with filter `%{"extensions" => %{"soc2" => %{"change_ticket_id" => "JIRA-123"}}}`
- **THEN** only entries where `extensions @> '{"soc2": {"change_ticket_id": "JIRA-123"}}'` are returned

#### Scenario: Combined core and extension filters
- **WHEN** entries are queried with `%{"action" => "update", "extensions" => %{"hipaa" => %{"phi_accessed" => true}}}`
- **THEN** both the core field filter (`action = 'update'`) and the extension filter are applied

#### Scenario: Extension filter with no matches
- **WHEN** entries are queried with an extension filter that matches no rows
- **THEN** an empty list is returned (not an error)

#### Scenario: Invalid extension path rejected
- **WHEN** a query includes a malformed extension filter (e.g., deeply nested beyond framework/field or containing SQL injection attempts)
- **THEN** the filter is rejected with a validation error before query execution

### Requirement: Index maintenance observability

The system MUST log warnings when GIN index size exceeds a configurable threshold relative to table size (default: index size > 30% of table size). This surfaces index bloat early for operational response.

#### Scenario: Normal index size ratio
- **WHEN** the GIN index on `extensions` is 15% of the `audit_logs` table size
- **THEN** no warning is logged

#### Scenario: Index bloat warning
- **WHEN** the GIN index on `extensions` exceeds 30% of the `audit_logs` table size
- **THEN** a warning is logged with the index name, current size, table size, and ratio

### Requirement: Composite index for account + extension queries

A composite index MUST be created on `(account_id)` combined with the GIN index strategy to support the most common query pattern: tenant-scoped extension field filtering. This MAY be achieved through the existing `account_id` B-tree index combined with the GIN index (Postgres will use a BitmapAnd), or through a dedicated composite approach if query plans show sequential scans on large accounts.

#### Scenario: Tenant-scoped extension query performance
- **WHEN** an account with 1 million audit log entries is queried for `extensions @> '{"hipaa": {"phi_accessed": true}}'`
- **THEN** the query uses an index-based plan (BitmapAnd of account_id index and GIN index, or equivalent) rather than a sequential scan
