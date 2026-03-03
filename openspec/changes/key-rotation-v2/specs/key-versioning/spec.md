## ADDED Requirements

### Requirement: Versioned per-account HMAC keys

Each account MUST support multiple HMAC keys with explicit versions, with exactly one active key at a time.

#### Scenario: Key activation
- **WHEN** key version 2 is activated for an account
- **THEN** version 1 is marked retired and version 2 becomes the sole active key

### Requirement: Key version stamped on audit records

`audit_logs` and `audit_checkpoints` MUST persist the signing `key_version` used for each row.

#### Scenario: Log creation
- **WHEN** a new audit log entry is created
- **THEN** the row stores the account's active `key_version`

#### Scenario: Checkpoint creation
- **WHEN** a new checkpoint is created
- **THEN** the row stores the `key_version` used for the checkpoint checksum lineage
