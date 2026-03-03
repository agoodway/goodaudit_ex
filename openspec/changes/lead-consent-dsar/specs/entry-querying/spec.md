## ADDED Requirements

### Requirement: Consent and DSAR filter support

`list_logs(account_id, opts)` MUST support account-scoped filtering by consent and DSAR-related predicates, including consent status, suppression status, and dsar_request_id.

#### Scenario: Filter by suppression status
- **WHEN** a query includes suppression-status filter options
- **THEN** only matching entries from the authenticated account are returned

### Requirement: Compliance evidence retrieval

Query APIs MUST support retrieval patterns needed for compliance exports, including deterministic ordering and complete evidence fields.

#### Scenario: DSAR evidence export
- **WHEN** an operator queries events for a DSAR record
- **THEN** returned entries include all linked lifecycle and action-evidence events in sequence order
