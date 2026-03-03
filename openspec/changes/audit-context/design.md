## Context

The HMAC chain module (`GA.Audit.Chain`) and database schemas (`GA.Audit.Log`, `GA.Audit.Checkpoint`) exist. This change creates the context module that wires them together — the business logic layer. The app already has multi-tenancy via `GA.Accounts` with accounts, account_users, and per-account API keys.

## Goals / Non-Goals

**Goals:**
- Atomic entry creation that guarantees per-account chain integrity (advisory lock + HMAC computation + insert in one transaction)
- Gap-free per-account sequence numbers under concurrent load
- Efficient cursor-based pagination suitable for large audit tables, always scoped to an account
- Flexible filtering for HIPAA compliance queries within an account's data

**Non-Goals:**
- Chain verification (separate change: chain-verification)
- Periodic checkpoint scheduling (separate change: chain-verification)
- HTTP API (separate change: audit-endpoints)
- Cross-account queries or aggregation

## Decisions

### Per-account advisory lock via hashed account_id
Rather than a single global advisory lock (which would serialize writes across all tenants), each account gets its own lock key derived from hashing its UUID: `:erlang.phash2(account_id)`. This allows concurrent writes across different accounts while serializing writes within the same account. The lock is transaction-scoped (`pg_advisory_xact_lock`) so it auto-releases on commit or rollback.

### All public functions take account_id as first argument
Consistent API: `create_log_entry(account_id, attrs)`, `list_logs(account_id, opts)`, `get_log(account_id, id)`, `create_checkpoint(account_id)`, `list_checkpoints(account_id)`. The account boundary is enforced at the context level, not just the controller level.

### Per-account sequence numbers
`MAX(sequence_number) WHERE account_id = ?` computes the next sequence for a specific account. Each account starts at 1. The unique index on `[account_id, sequence_number]` prevents cross-account interference.

### Fetch limit + 1 for pagination
To determine if more pages exist without a separate COUNT query, we fetch `limit + 1` rows. If we get more than `limit`, there's a next page. This is O(1) overhead versus a full count.

### Filter composition via `maybe_filter/3` pattern
Each filter is applied conditionally via a helper that checks if the option is present. This keeps the query composition readable and extensible without deeply nested conditionals. All queries implicitly include `WHERE account_id = ?`.

### `Repo.transaction` wraps the full creation flow
The advisory lock, sequence computation, previous checksum fetch, and insert all happen in one transaction. If any step fails, everything rolls back cleanly — including the advisory lock release.

## Risks / Trade-offs

### Per-account advisory lock under high write volumes
Under very high write volumes for a single account (10k+ per second), the advisory lock becomes a bottleneck. For HIPAA audit logging volumes (typically hundreds per second at peak per tenant), this is acceptable. Different accounts can write concurrently without contention.

### MAX(sequence_number) query on large tables
This query is O(log n) with the composite unique index on `[account_id, sequence_number]`. Acceptable up to billions of rows per account. If it becomes slow, a separate sequence counter table (one row per account, locked) could replace it.

### get_log enforces account ownership
`get_log(account_id, id)` queries with both `account_id` and `id`. This prevents one account from reading another account's audit entries, even if they know the UUID.
