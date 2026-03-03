## Context

The HMAC chain module (`GA.Audit.Chain`) exists as a pure computation module. Now we need the persistence layer — database tables and Ecto schemas — before the context module can wire them together.

## Goals / Non-Goals

**Goals:**
- HIPAA-complete field set covering who/what/when/where/outcome
- Database-level immutability enforcement via triggers (defense in depth)
- Indexes that support the planned query patterns (sequence scan, timestamp range, user lookup, resource lookup, action filter, PHI filter)
- Clean separation between the changeset (external input validation) and chain fields (computed by context)

**Non-Goals:**
- Business logic (creating entries, computing checksums) — that's the context layer
- API validation — that's the controller/OpenAPI layer
- Partitioning or archival lifecycle in this change — implemented in `audit-log-lifecycle`

## Decisions

### Two separate migrations
`audit_logs` and `audit_checkpoints` are separate migrations rather than one combined migration. They represent distinct concerns (logging vs anchoring) and could be evolved independently.

### Triggers over application-only enforcement
Application code can have bugs, be bypassed via `iex`, or be changed by future developers. Database triggers are the last line of defense. Even `Repo.update_all` and raw SQL will be blocked.

### Account-scoped sequence numbers
The unique constraint on `sequence_number` is compound: `[account_id, sequence_number]`. Each account starts its chain at sequence 1. This avoids cross-tenant contention on the advisory lock and allows independent chain verification per account. The `account_id` is also indexed individually for efficient per-account queries.

### Chain fields excluded from changeset
`sequence_number`, `checksum`, `previous_checksum`, and `account_id` are never set by external callers. The changeset validates user-provided fields only. The context layer adds chain and account fields via `Ecto.Changeset.put_change/3` after computing them.

### Partial index on phi_accessed
A partial index (`WHERE phi_accessed = true`) is more efficient than a full index because PHI access is typically the minority of entries. Queries filtering for `phi_accessed = true` benefit; queries not filtering on this field are unaffected.

## Risks / Trade-offs

### Append-only triggers complicate testing
Test cleanup (`Ecto.Adapters.SQL.Sandbox`) uses transactions that rollback, which is fine. But any test that needs to UPDATE or DELETE audit records for setup will fail. Mitigation: tests should only INSERT and assert — never modify audit records.

### Migration rollback drops all data
The `down` function drops triggers then drops tables. This is destructive but acceptable for development. In production, audit tables should never be dropped. Exceptional repair/bypass governance is defined in `append-only-repair-governance`.
