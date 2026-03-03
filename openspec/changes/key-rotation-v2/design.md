## Context

`account-hmac-keys` introduced one key per account. This change evolves that model to support safe rotation while preserving historical verification fidelity.

## Goals / Non-Goals

**Goals:**
- Rotate per-account keys without rewriting historical audit rows
- Keep verification deterministic for historical entries
- Provide an operationally safe, auditable rotation flow

**Non-Goals:**
- Re-signing existing audit chains with new keys
- Automatic periodic rotation policy (manual/explicit first)

## Decisions

### Versioned key table
Store keys in an account-scoped versioned table (`version`, `status`, `activated_at`, `retired_at`, `created_by`). Keep exactly one `active` key per account.

### Stamp `key_version` on writes
Each new audit log/checkpoint stores the signing `key_version` so verification can look up the exact key used at write time.

### Dual-verify during rotation
For bounded cutover windows, verifier may attempt active key and previous key where version metadata is missing or transitional.

### Rotation is explicit and auditable
Rotation API requires actor identity and reason. Emit explicit audit events for key generation, activation, retirement, and rollback.

## Risks / Trade-offs

- Extra joins/lookups for verification by key version
- More operational states to reason about (active/retired/revoked)
- Requires clear runbook discipline to avoid partial cutovers
