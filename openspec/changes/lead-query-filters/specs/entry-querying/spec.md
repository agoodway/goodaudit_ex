## ADDED Requirements

### Requirement: Extended filter grammar in `list_logs/2`

`list_logs(account_id, opts)` MUST parse and apply the lead-oriented filters defined by this change while keeping the implicit account constraint.

#### Scenario: Filter coercion and validation
- **WHEN** invalid typed values are provided for lead filters
- **THEN** the API returns HTTP 422 with field-specific parsing errors

### Requirement: Deterministic ordering under compound filters

Compound filters MUST still return records in deterministic ascending sequence order for cursor-based pagination.

#### Scenario: Multi-filter pagination
- **WHEN** `list_logs/2` is called with several lead filters and `after_sequence`
- **THEN** returned entries continue strictly after the cursor with no reordering
