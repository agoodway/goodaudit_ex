## Context

Audit entries can be created and queried per-account. Now we need the integrity verification system that proves an account's chain is intact, and automated checkpoint creation across all accounts for regular anchoring.

## Goals / Non-Goals

**Goals:**
- Per-account full chain verification from genesis in streaming batches (memory-efficient for large chains)
- Detect all tamper types: modified checksums, deleted entries (sequence gaps), altered checkpoints — within an account's chain
- Detailed report suitable for API response and compliance auditing
- Automatic periodic checkpoints for all active accounts with zero operator intervention

**Non-Goals:**
- Partial/incremental verification in this change (implemented in `incremental-verification`)
- External anchoring (checksum.dev integration) — separate proposal
- Real-time tamper alerting — verification is on-demand or periodic
- Cross-account verification or aggregation

## Decisions

### Per-account verification
`verify/1` takes an `account_id` and only verifies that account's chain. The query uses `WHERE account_id = ? AND sequence_number > last_seq ORDER BY sequence_number ASC LIMIT 1000`, hitting the composite unique index on `[account_id, sequence_number]`. This ensures complete tenant isolation during verification.

### Batch size of 1000
Large enough for throughput (minimizes round-trips), small enough to keep memory bounded. Each batch is a simple cursor query hitting the composite index.

### Accumulator-based state threading
The verifier uses `Enum.reduce` over each batch, threading state (previous_checksum, expected_sequence, failures) through. This is functional, testable, and handles the streaming nature without GenServer complexity.

### CheckpointWorker iterates all active accounts
Rather than one worker per account (which doesn't scale), a single GenServer iterates all active accounts on each tick. It calls `GA.Accounts.list_active_accounts/0` (or queries directly), then `GA.Audit.create_checkpoint/1` for each. Failures for individual accounts are logged but don't stop processing of other accounts.

### CheckpointWorker as simple GenServer with `Process.send_after`
No need for a scheduler library. `Process.send_after/3` is sufficient for hourly intervals. The worker is self-rescheduling and crash-resilient under the supervisor.

### Worker logs but does not crash on failure
Checkpoint creation failure for any account (unlikely but possible under extreme DB load) should not take down the worker. It logs the error per account and continues to the next account.

## Risks / Trade-offs

### Full verification is O(n) per account
Verifying millions of entries takes time. The `duration_ms` field in the report makes this visible. For very large chains, consider adding a `from_sequence` option in a future change.

### CheckpointWorker iteration time
With many active accounts, the checkpoint creation loop may take significant time. This is acceptable for hourly intervals as a baseline. Scaled worker controls (chunking, bounded concurrency, jitter, lease/lock, and per-account backoff) are implemented in `checkpoint-worker-scaling`.

### CheckpointWorker in test environment
The worker will start during tests. Either disable it in test config or ensure it doesn't interfere with test isolation. Recommendation: start it in the supervision tree unconditionally, but use a very long interval in test config.
