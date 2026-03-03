## Context

`chain-verification` currently verifies from genesis. This change adds a production-default incremental path without removing full verification.

## Goals / Non-Goals

**Goals:**
- Reduce verification latency and compute cost for common API usage
- Preserve correctness via trusted checkpoint boundaries
- Keep a periodic full verification path for compliance confidence

**Non-Goals:**
- Replacing full verification entirely
- Introducing probabilistic verification

## Decisions

### Mode selection
`verify_chain(account_id)` defaults to incremental; `verify_chain(account_id, mode: :full)` remains available.

### Trusted checkpoint selection
Verifier selects latest checkpoint that passes trust criteria. If none exist, fallback to full verification from genesis.

### Compliance worker
A background worker executes full scans on a schedule and emits discrepancy alerts/metrics.

## Risks / Trade-offs

- Incorrect trust criteria could hide issues; criteria must be conservative
- Adds operational complexity (two verification modes)
