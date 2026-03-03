## Why

The audit chain can now be created and queried per-account, but there's no way to verify its integrity. We need a verification engine that streams through an **account's** entire chain from genesis, recomputing checksums and checking sequence continuity. We also need a periodic worker that creates checkpoints automatically **for all active accounts**, providing regular anchor points for efficient partial verification.

## What Changes

1. **`GA.Audit.Verifier`** — Streaming verification engine that reads an account's chain in batches of 1000, recomputes HMAC checksums (including account_id in payload), detects sequence gaps, validates checkpoint anchors, and returns a detailed report. Always operates on a single account's chain.

2. **`GA.Audit.CheckpointWorker`** — GenServer that creates checkpoints **for all active accounts** on a configurable schedule (default: 1 hour). Iterates `GA.Accounts` to find active accounts, creates a checkpoint for each. Added to the supervision tree.

> **Production evolution note:** This change establishes baseline full verification and a simple worker loop. Default incremental verification is introduced in `incremental-verification`, and worker scale controls are introduced in `checkpoint-worker-scaling`.

3. **`GA.Audit.verify_chain(account_id)`** — Context function that delegates to the verifier for a specific account.

## Capabilities

### New Capabilities
- `verification-engine`: Per-account streaming chain integrity verification with gap detection, checksum validation, and checkpoint anchor checking
- `checkpoint-worker`: Periodic GenServer that creates chain checkpoints for all active accounts on a configurable schedule

### Modified Capabilities

## Impact

- **New files**: `lib/app/audit/verifier.ex`, `lib/app/audit/checkpoint_worker.ex`
- **Modified file**: `lib/app/application.ex` (add CheckpointWorker to supervision tree)
- **Modified file**: `lib/app/audit.ex` (add `verify_chain/1`)
- **New tests**: `test/app/audit/verifier_test.exs`, `test/app/audit/checkpoint_worker_test.exs`
