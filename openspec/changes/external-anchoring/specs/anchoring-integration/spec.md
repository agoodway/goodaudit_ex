## ADDED Requirements

### Requirement: Optional checksum_ex dependency

The `checksum_ex` Elixir client library (installed from `https://github.com/agoodway/checksum_ex`) MUST be an optional dependency. When not installed or not configured, all anchoring features MUST be inert — no errors, no log noise, no behavioral changes.

#### Scenario: Anchoring enabled
- **WHEN** `checksum_ex` is installed and `CHECKSUM_DEV_URL` + `CHECKSUM_DEV_API_KEY` are set
- **THEN** `GA.Audit.Anchoring.enabled?/0` returns `true`

#### Scenario: Anchoring disabled (no dep)
- **WHEN** `checksum_ex` is not installed
- **THEN** `GA.Audit.Anchoring.enabled?/0` returns `false` and no anchoring code is called

#### Scenario: Anchoring disabled (no config)
- **WHEN** `checksum_ex` is installed but env vars are not set
- **THEN** `GA.Audit.Anchoring.enabled?/0` returns `false`

### Requirement: Per-account chain_id derivation

Each GoodAudit account MUST have a deterministic, unique `chain_id` for use with checksum.dev, derived as `"ga-#{env}-#{account_id}"`. This MUST NOT change if the account is renamed.

#### Scenario: Chain ID format
- **WHEN** `chain_id_for_account("550e8400-e29b-41d4-a716-446655440000")` is called in `prod`
- **THEN** it returns `"ga-prod-550e8400-e29b-41d4-a716-446655440000"`

### Requirement: Checkpoint anchoring

`anchor_checkpoint(account_id, checkpoint)` MUST call `ChecksumEx.anchor(chain_id, sequence_number, checksum)` and store receipt fields: `signature` (base64), `anchored_at` (`verified_at`), and `signing_key_id`. It MUST return `{:ok, updated_checkpoint}` when a new anchor is stored, `{:ok, checkpoint}` for idempotent already-anchored checkpoints, or `{:error, reason}` on service/network failure without modifying the checkpoint.

#### Scenario: Successful anchoring
- **WHEN** `anchor_checkpoint/2` is called and checksum.dev responds with a signed receipt
- **THEN** the checkpoint's `signature`, `verified_at`, and `signing_key_id` are updated in the database and the updated checkpoint is returned

#### Scenario: checksum.dev unavailable
- **WHEN** `anchor_checkpoint/2` is called and checksum.dev is unreachable (after retries)
- **THEN** it returns `{:error, :service_unavailable}` and the checkpoint remains unchanged (signature stays nil)

#### Scenario: Already anchored (idempotent)
- **WHEN** `anchor_checkpoint/2` is called for a checkpoint that already has a signature
- **THEN** checksum.dev returns the existing anchor (409 Conflict → existing receipt), `anchor_checkpoint/2` returns `{:ok, checkpoint}`, and local receipt fields are reconciled from the existing anchor if missing or stale

#### Scenario: Rate limited by checksum.dev
- **WHEN** `anchor_checkpoint/2` receives HTTP 429 from checksum.dev
- **THEN** it retries with bounded exponential backoff + jitter and returns `{:error, :rate_limited}` if the retry budget is exhausted

### Requirement: Retroactive anchoring

`anchor_all_unanchored(account_id)` MUST query all checkpoints for the account where `signature IS NULL`, ordered by `sequence_number ASC`, and anchor each one. It MUST return `{:ok, count}` with the number successfully anchored. Individual failures MUST be logged but MUST NOT stop processing of remaining checkpoints.

#### Scenario: Catch-up after outage
- **WHEN** `anchor_all_unanchored(account_id)` is called and 5 checkpoints lack signatures
- **THEN** all 5 are submitted to checksum.dev, signatures stored, and `{:ok, 5}` is returned

#### Scenario: Partial failure
- **WHEN** 3 of 5 unanchored checkpoints are successfully anchored before checksum.dev becomes unavailable
- **THEN** 3 checkpoints get signatures, 2 remain unanchored, `{:ok, 3}` is returned, failures are logged

#### Scenario: No unanchored checkpoints
- **WHEN** all checkpoints already have signatures
- **THEN** `{:ok, 0}` is returned

### Requirement: Non-fatal anchoring in CheckpointWorker

After creating a checkpoint for an account, the `CheckpointWorker` MUST attempt to anchor it if `Anchoring.enabled?/0` is true. Anchoring failure MUST be logged as a warning but MUST NOT affect checkpoint creation or processing of other accounts.

#### Scenario: Worker anchors checkpoint
- **WHEN** the worker creates a checkpoint and anchoring is enabled
- **THEN** it calls `anchor_checkpoint/2` and continues regardless of the result

#### Scenario: Worker handles anchoring failure
- **WHEN** anchoring fails for one account
- **THEN** a warning is logged with the account_id and error reason, and the worker proceeds to the next account

#### Scenario: Worker skips anchoring when disabled
- **WHEN** anchoring is not enabled
- **THEN** the worker creates checkpoints without attempting to anchor them

### Requirement: Anchor verification (offline)

`verify_anchor(checkpoint)` MUST reconstruct a `%ChecksumEx.Receipt{}` from the checkpoint's stored fields (`chain_id_for_account(checkpoint.account_id)`, `sequence_number`, `checksum`, `signature`, `verified_at`, `signing_key_id`) and call `ChecksumEx.verify_receipt/1` for local Ed25519 signature verification. No network call to checksum.dev.

#### Scenario: Valid anchor
- **WHEN** `verify_anchor/1` is called on a checkpoint with a valid signature
- **THEN** it returns `{:ok, :valid}`

#### Scenario: Tampered anchor
- **WHEN** `verify_anchor/1` is called on a checkpoint whose signature doesn't match the reconstructed payload
- **THEN** it returns `{:error, :invalid_signature}`

#### Scenario: Signing key revoked
- **WHEN** `verify_anchor/1` is called and receipt verification indicates the signing key is revoked
- **THEN** it returns `{:error, :key_revoked}`

#### Scenario: Not anchored
- **WHEN** `verify_anchor/1` is called on a checkpoint with `signature: nil`
- **THEN** it returns `{:error, :not_anchored}`

### Requirement: Key discovery and cache refresh

Offline verification MUST use checksum.dev key discovery that is read-key authenticated and key-lifecycle aware (`active`, `rotated`, `revoked`). If a receipt references an unknown `signing_key_id`, the client MUST refresh key material before concluding verification failure.

#### Scenario: Unknown key ID in cached keyset
- **WHEN** `verify_anchor/1` processes a receipt signed by a key not found in local cache
- **THEN** the client refreshes checksum.dev key material and retries verification once before returning an error

### Requirement: Anchoring API endpoints

The following endpoints MUST be added to the existing router using existing auth pipelines:

- `POST /api/v1/checkpoints/:id/anchor` — Anchor a specific checkpoint. Requires write access (`sk_*` key). Returns 201 with anchored checkpoint or 503 if anchoring not enabled.
- `POST /api/v1/anchor-unanchored` — Anchor all unanchored checkpoints for the account. Requires write access. Returns 200 with `{"anchored_count": N}`.
- `GET /api/v1/anchor-status` — List all checkpoints for the account with their anchor status. Requires read access (`pk_*` or `sk_*` key). Returns 200 with list of `{checkpoint_id, sequence_number, anchored: bool, valid: bool | nil, key_status: active | rotated | revoked | nil}`.

#### Scenario: Anchor single checkpoint
- **WHEN** `POST /api/v1/checkpoints/:id/anchor` is called with a write key
- **THEN** the checkpoint is anchored and the updated checkpoint is returned in `{"data": {...}}` with `signature`, `verified_at`, and `signing_key_id` populated

#### Scenario: Anchoring not configured
- **WHEN** any anchoring endpoint is called but checksum_ex is not enabled
- **THEN** the response is HTTP 503 with `{"status": 503, "message": "External anchoring is not configured"}`

#### Scenario: Anchor status
- **WHEN** `GET /api/v1/anchor-status` is called
- **THEN** all checkpoints for the account are returned with their anchor status

### Requirement: Checkpoint response shape consistency

Anchoring endpoints returning checkpoint records MUST use the same checkpoint payload shape as checkpoint endpoints (`id`, `account_id`, `sequence_number`, `checksum`, `signature`, `verified_at`, `signing_key_id`, `inserted_at` inside `{"data": ...}`).

#### Scenario: Consistent checkpoint rendering across endpoints
- **WHEN** a checkpoint is returned by `POST /api/v1/checkpoints/:id/anchor` and by `GET /api/v1/checkpoints`
- **THEN** both responses use the same checkpoint field names and nullability rules
