## 1. Audit Logs Migration

- [x] 1.1 Create migration `CreateAuditLogs` with `up/down` functions (not `change`) to support trigger SQL
- [x] 1.2 Define all columns: id (binary_id PK), `account_id` (references accounts, type: binary_id, null: false), chain fields, HIPAA WHO/WHAT/WHEN/WHERE/OUTCOME fields, phi_accessed, metadata, timestamps
- [x] 1.3 Create indexes: unique on `[account_id, sequence_number]`, `account_id`, `timestamp`, `[account_id, user_id]`, `[account_id, resource_type, resource_id]`, `[account_id, action]`, partial on `phi_accessed` where `account_id` is included
- [x] 1.4 Create append-only triggers: `audit_logs_prevent_update`, `audit_logs_prevent_delete`, `audit_logs_prevent_truncate`
- [x] 1.5 Implement `down` function — drop triggers, drop functions, drop table

## 2. Audit Checkpoints Migration

- [x] 2.1 Create migration `CreateAuditCheckpoints` with `up/down` functions
- [x] 2.2 Define baseline columns: id (binary_id PK), `account_id` (references accounts, type: binary_id, null: false), sequence_number, checksum, signature, verified_at, timestamps (later anchoring changes may add receipt lineage fields such as `signing_key_id`)
- [x] 2.3 Create unique index on `[account_id, sequence_number]`
- [x] 2.4 Create append-only triggers: `audit_checkpoints_prevent_update`, `audit_checkpoints_prevent_delete`, `audit_checkpoints_prevent_truncate`
- [x] 2.5 Implement `down` function — drop triggers, drop functions, drop table

## 3. Ecto Schemas

- [x] 3.1 Create `lib/app/audit/log.ex` — `GA.Audit.Log` schema with all fields including `belongs_to :account, GA.Accounts.Account`, `@valid_actions`, `@valid_outcomes`, `changeset/2`
- [x] 3.2 Implement changeset validation: required fields (excluding account_id and chain fields which are set by context), action inclusion, outcome inclusion, conditional failure_reason requirement
- [x] 3.3 Create `lib/app/audit/checkpoint.ex` — `GA.Audit.Checkpoint` schema with `belongs_to :account, GA.Accounts.Account`, changeset validating sequence_number and checksum

## 4. Tests

- [x] 4.1 Test `GA.Audit.Log` changeset — valid attrs, missing required fields, invalid action, invalid outcome, failure without reason
- [x] 4.2 Test `GA.Audit.Checkpoint` changeset — valid attrs, missing required fields, duplicate sequence_number within same account
- [x] 4.3 Test append-only triggers — verify UPDATE/DELETE on audit_logs raises, verify UPDATE/DELETE on audit_checkpoints raises
- [x] 4.4 Run `mix ecto.migrate` and verify both tables created successfully with account_id foreign keys
