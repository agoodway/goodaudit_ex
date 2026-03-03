## Why

The single-loop checkpoint worker is simple but will degrade as active account counts and variance in account workload increase. We need explicit scaling behavior to keep checkpoint coverage reliable.

## What Changes

1. **Chunked iteration** - Process accounts in chunks with bounded concurrency.
2. **Concurrency limits** - Add max in-flight account checkpoint tasks per run.
3. **Jitter + lease/lock** - Add schedule jitter and run lease to avoid overlapping runs across nodes.
4. **Per-account backoff** - Apply adaptive retry/backoff for repeatedly failing accounts.

## Capabilities

### New Capabilities
- `worker-scaling`: Deterministic, bounded-concurrency checkpoint fan-out

### Modified Capabilities
- `checkpoint-worker`: Adds lease, jitter, chunking, and per-account backoff controls

## Impact

- **Modified files**: `lib/app/audit/checkpoint_worker.ex`, supervision/runtime config
- **New tests**: overlap avoidance, bounded concurrency, backoff correctness
