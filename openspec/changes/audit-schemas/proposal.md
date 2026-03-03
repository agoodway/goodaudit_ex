## Why

The HMAC chain module needs somewhere to persist audit entries and checkpoints. Before any business logic can create or query records, we need the database tables, Ecto schemas, indexes, and append-only enforcement triggers. These are the data foundation for the entire audit system.

## What Changes

Two new database tables with corresponding Ecto schemas:

1. **`audit_logs`** — Stores every audit event scoped to an account via `account_id` (FK to `accounts`). Includes HIPAA-required fields (who/what/when/where/outcome) plus chain integrity fields (sequence_number, checksum, previous_checksum). Sequence numbers are **per-account** (unique on `[account_id, sequence_number]`), giving each tenant an independent chain. Protected by triggers preventing UPDATE, DELETE, and TRUNCATE.

2. **`audit_checkpoints`** — Periodic chain anchors scoped to an account via `account_id` (FK to `accounts`). Stores a snapshot of the account's chain state at a given sequence number. Also append-only with the same trigger protections.

> **Multi-tenancy note:** Both tables reference the existing `accounts` table. Each account maintains its own independent audit chain with its own sequence numbering starting at 1. The app already has accounts, account_users, and per-account API keys — these schemas integrate with that existing infrastructure.

> **Lifecycle note:** This change defines the baseline unpartitioned schema. Long-term partitioning/retention/archive policy is defined in `audit-log-lifecycle`. Controlled break-glass repair governance for exceptional operations is defined in `append-only-repair-governance`.

## Capabilities

### New Capabilities
- `audit-log-table`: PostgreSQL table, Ecto schema, indexes, and append-only triggers for audit log entries
- `checkpoint-table`: PostgreSQL table, Ecto schema, and append-only triggers for chain checkpoints

### Modified Capabilities

## Impact

- **New migrations**: `CreateAuditLogs`, `CreateAuditCheckpoints`
- **New files**: `lib/app/audit/log.ex`, `lib/app/audit/checkpoint.ex`
- **New tests**: `test/app/audit/log_test.exs`, `test/app/audit/checkpoint_test.exs`
- **No new dependencies**
