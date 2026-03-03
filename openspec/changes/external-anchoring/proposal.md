## Why

GoodAudit's HMAC chain is self-contained — the same system that stores audit data also proves it hasn't been tampered with. Anyone with database access and the account's HMAC key can silently rewrite the entire chain with valid checksums. HIPAA auditors and legal proceedings require independent proof that audit records existed at a specific time.

checksum.dev (a separate service we operate) solves this by acting as an external witness. It signs checkpoint data with per-organization Ed25519 keypairs and stores the receipts independently. Once a checkpoint is anchored externally, the chain up to that point is provably intact — even if the GoodAudit database is fully compromised.

## What Changes

1. **Optional dependency** — Add `checksum_dev` Elixir client library to `mix.exs` as an optional dep. The feature is inert when not configured.

2. **`GA.Audit.Anchoring` module** — Handles communication with checksum.dev. Submits checkpoints for anchoring, stores receipts, supports retroactive anchoring of missed checkpoints, and handles 409/429 semantics from checksum.dev. Derives an environment-namespaced per-account `chain_id`.

3. **`CheckpointWorker` enhancement** — After creating a checkpoint for each account, attempt to anchor it via checksum.dev. Anchoring failure is non-fatal: the checkpoint is already created, a warning is logged, and the checkpoint can be anchored retroactively later.

4. **Receipt storage** — Store full receipt metadata on checkpoints: base64 signature, `anchored_at` timestamp (`verified_at`), and `signing_key_id` from checksum.dev so verification remains robust across checksum.dev key rotation/revocation.

5. **Enhanced verification** — `GA.Audit.verify_chain/1` report gains an `anchor_results` section showing which checkpoints are anchored, signature validity, key trust status (`key_status`), and which checkpoints are missing anchors.

6. **Anchoring API endpoints** — New endpoints for triggering manual anchoring and listing anchor status, using existing auth infrastructure.

7. **JWKS/key lifecycle awareness** — Offline verification path supports checksum.dev key lifecycle (`active`, `rotated`, `revoked`) and refreshes cached key material when receipts reference unknown keys.

## Architecture

```
GoodAudit (per account)         checksum.dev
─────────────────────           ──────────────
CheckpointWorker creates
checkpoint for account A
        │
        ▼
GA.Audit.Anchoring sends
chain_id + seq + checksum ────► POST /api/v1/anchors
                                 Ed25519 signs receipt
        ◄──────────────────── Returns {signature, anchored_at, signing_key_id}
         │
Stores receipt fields in        Stores anchor independently
checkpoint columns              (append-only, Merkle trees)
```

One checksum.dev account serves all GoodAudit tenants. Per-tenant isolation is via `chain_id` — each GoodAudit account gets `ga-{env}-{account_id}` as its chain identifier within checksum.dev.

## Capabilities

### New Capabilities
- `anchoring-integration`: Automatic and manual checkpoint anchoring via checksum.dev with receipt storage
- `enhanced-verification`: Chain verification report includes external anchor validation

### Modified Capabilities
- `checkpoint-worker`: Enhanced to auto-anchor after creating checkpoints (from chain-verification change)

## Impact

- **Modified file**: `mix.exs` — add optional `checksum_dev` dep
- **New file**: `lib/app/audit/anchoring.ex` — `GA.Audit.Anchoring` module
- **Modified file**: `lib/app/audit/checkpoint_worker.ex` — add anchoring step after checkpoint creation
- **Modified file**: `lib/app/audit/verifier.ex` — add anchor validation to report
- **Modified file**: `lib/app/audit.ex` — add `anchor_checkpoint/2`, `anchor_all_unanchored/1`, expose anchoring in context
- **New migration**: add `signing_key_id` to `audit_checkpoints` for checksum.dev receipt key lineage
- **New files**: `lib/app_web/controllers/anchoring_controller.ex`, `lib/app_web/controllers/anchoring_json.ex`
- **Modified file**: `lib/app_web/router.ex` — add anchoring routes
- **Config changes**: `config/runtime.exs` — optional `CHECKSUM_DEV_URL`, `CHECKSUM_DEV_API_KEY`, and `CHECKSUM_DEV_CHAIN_ENV` env vars
- **New tests**: `test/app/audit/anchoring_test.exs`, `test/app_web/controllers/anchoring_controller_test.exs`
