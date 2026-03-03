## Context

`chain-verification` added an hourly worker that iterates all active accounts serially. This change hardens that worker for larger production fleets.

## Goals / Non-Goals

**Goals:**
- Keep each scheduled run bounded and predictable
- Prevent overlapping runs and duplicate work in multi-node deployments
- Isolate noisy/failing accounts via backoff

**Non-Goals:**
- Replacing the worker with external orchestration

## Decisions

### Lease-based overlap control
Acquire a run lease before processing; skip run if lease is held.

### Chunked + bounded concurrency
Iterate active accounts in chunks and process with capped `Task.async_stream` concurrency.

### Per-account backoff
Track recent failures and delay retries for only those accounts.

## Risks / Trade-offs

- Additional state/configuration complexity
- Requires robust metrics to tune chunk and concurrency settings
