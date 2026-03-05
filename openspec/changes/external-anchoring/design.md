## Context

GoodAudit has per-account HMAC chains with checkpoints. checksum.dev is a separate service (also operated by Goodway) that provides Ed25519-signed receipts for chain checkpoints. The `checksum_ex` Elixir client library handles HTTP communication, retry logic, and offline signature verification.

## Goals / Non-Goals

**Goals:**
- Automatic anchoring of checkpoints as they're created (fire-and-forget, non-blocking)
- Graceful degradation when checksum.dev is unavailable (checkpoints still created, anchoring retried later)
- Retroactive anchoring of any checkpoint that missed its initial anchor
- Enhanced verification report that validates external signatures
- Feature is fully optional — zero impact when not configured

**Non-Goals:**
- Per-tenant checksum.dev accounts (one shared account is sufficient, chain_id provides isolation)
- Anchoring individual audit log entries (only checkpoints are anchored — they represent chain state)
- Merkle tree verification (that's checksum.dev's responsibility, not GoodAudit's)
- Auditor portal integration (that lives in checksum.dev)

## Decisions

### Optional dependency with runtime feature flag
`checksum_ex` is an optional dep in mix.exs (installed from `https://github.com/agoodway/checksum_ex`). `GA.Audit.Anchoring.enabled?/0` checks whether the library is loaded AND configured. All anchoring call sites check this before proceeding. When disabled, the system behaves exactly as before — checkpoints created without signatures.

### One checksum.dev account, per-tenant chain_ids
Rather than each GoodAudit account configuring its own checksum.dev credentials (complex key management), a single checksum.dev account is used for the whole GoodAudit deployment. Per-tenant isolation comes from the `chain_id` field: each GoodAudit account gets `ga-{env}-{account_id}` as its chain identifier. Within checksum.dev, anchors are unique on `(account_id, chain_id, sequence_number)`, so chains never collide.

### chain_id derived from environment + account_id, not slug
Using the account UUID with environment namespace (`ga-{env}-{account_id}`) rather than slug ensures chain IDs never change on rename and avoids cross-environment collisions when multiple GoodAudit deployments share checksum.dev infrastructure.

### Non-fatal anchoring in CheckpointWorker
Anchoring happens after the checkpoint is committed to the database. If checksum.dev is unreachable (network issue, maintenance), the checkpoint is already saved — only the signature is missing. A warning is logged. Retroactive anchoring via `anchor_all_unanchored/1` can fill in the gaps later (manually or via a scheduled job).

### Receipt stored in existing columns
Receipt lineage is stored on checkpoints: `signature` (base64 Ed25519 signature), `verified_at` (checksum.dev `anchored_at`), and `signing_key_id` (the checksum.dev key that signed the receipt). `signing_key_id` is required so verification remains deterministic across key rotations/revocations.

### Offline verification preferred
The verifier uses `ChecksumEx.verify_receipt/1` for local Ed25519 signature verification (reconstructs canonical payload, checks signature against cached public key). No network call to checksum.dev during chain verification. Key discovery follows checksum.dev key lifecycle semantics (active/rotated/revoked), with cache refresh on unknown `signing_key_id` or failed verification attributable to stale key cache.

### Explicit checksum.dev HTTP semantics
- `201 Created` means new anchor stored; checkpoint receipt fields are persisted.
- `409 Conflict` (duplicate anchor) is treated as idempotent success; local checkpoint is reconciled from returned anchor payload (`signature`, `anchored_at`, `signing_key_id`) if missing/stale.
- `429 Too Many Requests` is retried with bounded exponential backoff + jitter and treated as non-fatal in worker flows.

### Anchoring endpoints use existing auth
New endpoints (`POST /api/v1/checkpoints/:id/anchor`, `POST /api/v1/anchor-unanchored`, `GET /api/v1/anchor-status`) are added to the existing `:api_write` and `:api_authenticated` pipelines. Account context comes from the API key as usual.

## Risks / Trade-offs

### Single checksum.dev account is a shared secret
The checksum.dev API key is app-level config, not per-tenant. If compromised, anchors can be submitted for any GoodAudit account's chain. Mitigation: the anchors are append-only in checksum.dev, so an attacker can't modify existing receipts. They could only submit false future anchors — which would be detected when the checkpoint checksum doesn't match the chain.

### Anchoring lag during outages
If checksum.dev is down for hours, many checkpoints accumulate without signatures. `anchor_all_unanchored/1` catches up once the service recovers, but there's a window where checkpoints lack external proof. Mitigation: the HMAC chain is still intact — external anchoring adds a layer, it doesn't replace the existing integrity.

### Public key caching and rotation
The checksum.dev client caches account JWKS in ETS. If checksum.dev rotates or revokes signing keys, historical receipts still include `signing_key_id`. The client refreshes key material on unknown key IDs or verification failures that may indicate stale key cache.

### checksum_ex library must be available
If the GitHub dependency can't be fetched, the feature simply isn't available. The optional dependency pattern means compilation succeeds without it. `Code.ensure_loaded?(ChecksumEx)` gates all usage.
