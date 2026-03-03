## ADDED Requirements

### Requirement: Audit log table structure

The `audit_logs` table MUST store all HIPAA-required fields organized by category: TENANT (`account_id` as FK to `accounts`), WHO (`user_id`, `user_role`, `session_id`), WHAT (`action`, `resource_type`, `resource_id`), WHEN (`timestamp`), WHERE (`source_ip`, `user_agent`), OUTCOME (`outcome`, `failure_reason`), plus PHI tracking (`phi_accessed`), extensible metadata (`metadata` as JSONB), and chain integrity fields (`sequence_number`, `checksum`, `previous_checksum`). The primary key MUST be `binary_id`. The `account_id` column MUST be a NOT NULL foreign key referencing the `accounts` table with `on_delete: :nothing` (audit logs must never be cascade-deleted).

#### Scenario: Table creation
- **WHEN** the migration runs
- **THEN** the `audit_logs` table is created with all specified columns, correct types, nullability constraints, and the `account_id` foreign key

#### Scenario: Required fields enforced
- **WHEN** an insert is attempted without `account_id`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `timestamp`, `sequence_number`, or `checksum`
- **THEN** the database rejects the insert with a NOT NULL violation

#### Scenario: Account foreign key enforced
- **WHEN** an insert is attempted with an `account_id` that does not exist in the `accounts` table
- **THEN** the database rejects the insert with a foreign key violation

### Requirement: Audit log indexes

The table MUST have indexes on: `[account_id, sequence_number]` (unique — per-account chain ordering), `account_id` (efficient per-tenant queries), `timestamp`, `[account_id, user_id]` (per-account user lookup), `[account_id, resource_type, resource_id]` composite (per-account resource lookup), `[account_id, action]` (per-account action filter), and `phi_accessed` (partial, where true). All query-pattern indexes include `account_id` as prefix for efficient tenant-scoped queries.

#### Scenario: Unique per-account sequence number
- **WHEN** two rows with the same `account_id` and `sequence_number` are inserted
- **THEN** the database rejects the second insert with a unique constraint violation

#### Scenario: Cross-account sequence numbers are independent
- **WHEN** two rows with different `account_id` values but the same `sequence_number` are inserted
- **THEN** both inserts succeed — sequence numbers are scoped per-account

### Requirement: Audit log append-only enforcement

The `audit_logs` table MUST have database triggers that raise exceptions on UPDATE, DELETE, and TRUNCATE operations. This MUST be enforced at the database level regardless of application behavior.

#### Scenario: Update rejected
- **WHEN** any process attempts to UPDATE a row in `audit_logs`
- **THEN** the database raises an exception and the update is rolled back

#### Scenario: Delete rejected
- **WHEN** any process attempts to DELETE a row from `audit_logs`
- **THEN** the database raises an exception and the delete is rolled back

#### Scenario: Truncate rejected
- **WHEN** any process attempts to TRUNCATE `audit_logs`
- **THEN** the database raises an exception and the truncate is rolled back

### Requirement: Audit log Ecto schema

The `GA.Audit.Log` schema MUST map all table columns with correct Ecto types, including `belongs_to :account, GA.Accounts.Account`. The changeset MUST validate required fields (`user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `timestamp`, `outcome`), validate `action` inclusion in `[create, read, update, delete, export, login, logout]`, validate `outcome` inclusion in `[success, failure]`, and require `failure_reason` when outcome is `failure`. Chain fields (`sequence_number`, `checksum`, `previous_checksum`) and `account_id` MUST NOT be settable through the changeset — they are computed/injected by the context layer.

#### Scenario: Valid changeset
- **WHEN** a changeset is built with all required fields and valid enum values
- **THEN** the changeset is valid

#### Scenario: Invalid action rejected
- **WHEN** a changeset is built with an action not in the allowed list
- **THEN** the changeset has a validation error on `:action`

#### Scenario: Failure requires reason
- **WHEN** a changeset has `outcome: "failure"` but no `failure_reason`
- **THEN** the changeset has a validation error on `:failure_reason`
