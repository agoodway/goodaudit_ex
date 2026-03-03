## 1. Dependency and Configuration

- [ ] 1.1 Add `{:checksum_dev, "~> 0.1", optional: true}` to `mix.exs` deps
- [ ] 1.2 Add anchoring config to `config/runtime.exs` — optional `CHECKSUM_DEV_URL`, `CHECKSUM_DEV_API_KEY`, and `CHECKSUM_DEV_CHAIN_ENV` env vars (no raise when missing — feature is simply disabled)
- [ ] 1.3 Add anchoring config to `config/dev.exs` and `config/test.exs` — disabled by default, test config points to a mock/local instance
- [ ] 1.4 Add `CHECKSUM_DEV_CHAIN_ENV` (or equivalent runtime setting) used to namespace chain IDs as `ga-{env}-{account_id}`

## 2. Receipt Storage Schema

- [ ] 2.1 Add migration to include `signing_key_id` on `audit_checkpoints` (nullable for historical rows, required for newly anchored rows)
- [ ] 2.2 Update `GA.Audit.Checkpoint` schema and serialization to include `signing_key_id`

## 3. Anchoring Module

- [ ] 3.1 Create `lib/app/audit/anchoring.ex` with `GA.Audit.Anchoring` module
- [ ] 3.2 Implement `enabled?/0` — returns `true` only if `checksum_dev` library is loaded AND url + api_key are configured
- [ ] 3.3 Implement `chain_id_for_account(account_id)` — returns `"ga-#{env}-#{account_id}"`
- [ ] 3.4 Implement `anchor_checkpoint(account_id, checkpoint)` — calls `ChecksumDev.anchor(chain_id, checkpoint.sequence_number, checkpoint.checksum)`, stores `signature`, `verified_at` (`anchored_at`), and `signing_key_id` on new anchors
- [ ] 3.5 Implement idempotent 409 reconciliation — when checksum.dev returns existing anchor, return `{:ok, checkpoint}` and reconcile local receipt fields if missing/stale
- [ ] 3.6 Implement 429 handling with bounded exponential backoff + jitter; return non-fatal error after retry budget exhausted
- [ ] 3.7 Implement `anchor_all_unanchored(account_id)` — queries checkpoints for account where `signature IS NULL`, anchors each in sequence order, returns `{:ok, count}` with number successfully anchored
- [ ] 3.8 Implement `verify_anchor(checkpoint)` — reconstructs `%ChecksumDev.Receipt{}` from stored fields, calls `ChecksumDev.verify_receipt/1` for offline Ed25519 verification, returns `{:ok, :valid}` or `{:error, :invalid_signature}` or `{:error, :key_revoked}` or `{:error, :not_anchored}`

## 4. Context Integration

- [ ] 4.1 Add `anchor_checkpoint(account_id, checkpoint_id)` to `GA.Audit` context — loads checkpoint, delegates to `Anchoring.anchor_checkpoint/2`
- [ ] 4.2 Add `anchor_all_unanchored(account_id)` to `GA.Audit` context — delegates to `Anchoring.anchor_all_unanchored/1`

## 5. CheckpointWorker Enhancement

- [ ] 5.1 After `GA.Audit.create_checkpoint(account_id)` succeeds in the worker loop, call `GA.Audit.Anchoring.anchor_checkpoint(account_id, checkpoint)` if `Anchoring.enabled?/0`
- [ ] 5.2 Log warning on anchoring failure — include account_id and error reason
- [ ] 5.3 Continue to next account regardless of anchoring success/failure

## 6. Enhanced Verification

- [ ] 6.1 In `GA.Audit.Verifier.verify(account_id)`, after checkpoint validation add anchor validation: for each checkpoint with a `signature`, call `Anchoring.verify_anchor/1`
- [ ] 6.2 Add `anchor_results` to verification report when anchoring is enabled — list of `%{sequence_number: N, status: :anchored | :unanchored, valid: true | false | nil, key_status: :active | :rotated | :revoked | nil}`
- [ ] 6.3 An invalid anchor signature or revoked signing key sets overall `valid: false` in the report
- [ ] 6.4 Unanchored checkpoints are reported but do not affect overall validity (anchoring is optional enhancement)

## 7. API Endpoints

- [ ] 7.1 Create `lib/app_web/controllers/anchoring_controller.ex` — `create/2` (anchor single checkpoint), `create_batch/2` (anchor all unanchored), `status/2` (list checkpoint anchor status)
- [ ] 7.2 Create `lib/app_web/controllers/anchoring_json.ex` — renders anchor results
- [ ] 7.3 Add routes: `POST /api/v1/checkpoints/:id/anchor` and `POST /api/v1/anchor-unanchored` to `:api_write` scope, `GET /api/v1/anchor-status` to `:api_authenticated` scope
- [ ] 7.4 Add OpenApiSpex annotations for all anchoring endpoints
- [ ] 7.5 Return 503 if anchoring is not enabled (checksum_dev not configured)

## 8. Tests

- [ ] 8.1 Test `Anchoring.enabled?/0` — true when configured, false when not
- [ ] 8.2 Test `chain_id_for_account/1` — returns `"ga-{env}-{account_id}"`
- [ ] 8.3 Test `anchor_checkpoint/2` — stores signature, verified_at, and signing_key_id on success
- [ ] 8.4 Test `anchor_checkpoint/2` — 409 duplicate is treated as idempotent success and reconciles missing local receipt fields
- [ ] 8.5 Test `anchor_checkpoint/2` — 429 triggers backoff/retry and returns error after retry budget exhausted
- [ ] 8.6 Test `anchor_checkpoint/2` — returns error and leaves checkpoint unchanged on non-reconcilable failures
- [ ] 8.7 Test `anchor_all_unanchored/1` — anchors only checkpoints with nil signature, in sequence order
- [ ] 8.8 Test `verify_anchor/1` — returns `:valid` for authentic receipt, `:invalid_signature` for tampered, `:key_revoked` for revoked signing key
- [ ] 8.9 Test `verify_anchor/1` — returns `:not_anchored` for checkpoint without signature
- [ ] 8.10 Test CheckpointWorker anchoring — creates checkpoint and anchors it when enabled
- [ ] 8.11 Test CheckpointWorker continues on anchoring failure — checkpoint saved, warning logged, next account processed
- [ ] 8.12 Test enhanced verification report includes `anchor_results` with key status
- [ ] 8.13 Test invalid anchor signature or revoked key fails overall verification
- [ ] 8.14 Test unanchored checkpoints don't fail overall verification
- [ ] 8.15 Test API endpoints — anchor single, anchor batch, status, auth enforcement, 503 when disabled
