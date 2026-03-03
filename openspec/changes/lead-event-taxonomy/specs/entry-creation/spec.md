## ADDED Requirements

### Requirement: Entry creation enforces taxonomy constraints

`create_log_entry(account_id, attrs)` MUST validate taxonomy fields against the canonical catalogs before insert.

#### Scenario: Invalid reason code
- **WHEN** a request includes a reason code not allowed for the specified event type
- **THEN** creation fails with validation errors and no row is inserted

### Requirement: Actor model compatibility rules

Entry creation MUST enforce actor-specific requirements (for example, partner actors require a partner identifier).

#### Scenario: Partner actor without identifier
- **WHEN** `actor_type=partner` is provided without required actor identifier
- **THEN** creation fails with HTTP 422 and an error on actor identity fields
