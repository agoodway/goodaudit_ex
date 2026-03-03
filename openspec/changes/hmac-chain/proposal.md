## Why

GoodAudit needs a cryptographic foundation for tamper-evident audit logging. Before any database tables, API routes, or business logic can be built, we need a pure computation module that produces deterministic HMAC-SHA-256 checksums over a canonical payload format. This module is the cryptographic primitive that everything else chains through.

Getting this right first — with thorough unit tests — means the rest of the system can trust it as a black box.

## What Changes

A new module `GA.Audit.Chain` that:
- Defines the canonical pipe-delimited payload format for HMAC computation — **includes `account_id` as the first field** for multi-tenant isolation
- Accepts the HMAC key as an explicit parameter (keys are per-account, managed elsewhere)
- Computes HMAC-SHA-256 checksums over audit log field sets
- Verifies stored checksums against recomputed values (using constant-time comparison)
- Canonicalizes metadata maps (sorted keys, deterministic JSON)

**This module is pure computation.** No database, no web layer, no config reads, no dependencies beyond `:crypto` and `Jason` (already present). The key is always passed in by the caller — the module has no opinion on where keys come from.

## Capabilities

### New Capabilities
- `hmac-computation`: HMAC-SHA-256 chain computation with canonical payload format and verification. Key-agnostic — accepts any 32-byte key.

### Modified Capabilities

## Impact

- **New file**: `lib/app/audit/chain.ex`
- **New test**: `test/app/audit/chain_test.exs`
- **No config changes** — keys are per-account (see `account-hmac-keys` change)
- **No new dependencies**
