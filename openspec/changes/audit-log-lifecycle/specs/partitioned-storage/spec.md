## ADDED Requirements

### Requirement: Partitioned audit log storage

`audit_logs` MUST support partitioned storage with predictable query behavior for account-scoped workloads.

#### Scenario: Query recent logs
- **WHEN** `list_logs(account_id, opts)` queries recent time windows
- **THEN** only relevant partitions are scanned and results remain correct

#### Scenario: Cross-boundary pagination
- **WHEN** a cursor page spans partition boundaries
- **THEN** ordering and `next_cursor` semantics remain unchanged
