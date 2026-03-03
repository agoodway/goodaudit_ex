## ADDED Requirements

### Requirement: Checkpoint table structure

The `audit_checkpoints` table MUST store chain anchor snapshots scoped to an account: `id` (binary_id), `account_id` (FK to `accounts`, NOT NULL, `on_delete: :nothing`), `sequence_number` (bigint), `checksum` (string/64), `signature` (text, nullable — for external anchoring), `verified_at` (utc_datetime_usec, nullable), and timestamps. The primary key MUST be `binary_id`. Additional external-anchoring lineage fields (for example `signing_key_id`) may be added in later changes.

#### Scenario: Table creation
- **WHEN** the migration runs
- **THEN** the `audit_checkpoints` table is created with all specified columns, the `account_id` foreign key, and a unique index on `[account_id, sequence_number]`

#### Scenario: Account foreign key enforced
- **WHEN** a checkpoint is inserted with an `account_id` that does not exist in the `accounts` table
- **THEN** the database rejects the insert with a foreign key violation

### Requirement: Checkpoint append-only enforcement

The `audit_checkpoints` table MUST have database triggers that raise exceptions on UPDATE, DELETE, and TRUNCATE operations, identical to the `audit_logs` protections.

#### Scenario: Update rejected
- **WHEN** any process attempts to UPDATE a row in `audit_checkpoints`
- **THEN** the database raises an exception and the update is rolled back

#### Scenario: Delete rejected
- **WHEN** any process attempts to DELETE a row from `audit_checkpoints`
- **THEN** the database raises an exception and the delete is rolled back

### Requirement: Checkpoint Ecto schema

The `GA.Audit.Checkpoint` schema MUST map all table columns including `belongs_to :account, GA.Accounts.Account`. The changeset MUST validate required fields (`sequence_number`, `checksum`) and enforce the unique constraint on `[account_id, sequence_number]`.

#### Scenario: Valid changeset
- **WHEN** a changeset is built with `sequence_number` and `checksum`
- **THEN** the changeset is valid

#### Scenario: Duplicate sequence per account rejected
- **WHEN** a checkpoint is inserted with an `[account_id, sequence_number]` pair that already exists
- **THEN** the insert fails with a unique constraint error

#### Scenario: Same sequence different accounts allowed
- **WHEN** checkpoints with the same `sequence_number` but different `account_id` values are inserted
- **THEN** both inserts succeed — checkpoints are scoped per-account
