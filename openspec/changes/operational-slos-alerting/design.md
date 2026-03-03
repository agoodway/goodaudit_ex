## Context

As volume grows, reliability depends on clear objectives and fast detection of drift. This change treats operability as a first-class capability.

## Goals / Non-Goals

**Goals:**
- Define objective, measurable SLOs
- Standardize metric names/dimensions for long-term maintainability
- Tie alerts to actionable runbooks

**Non-Goals:**
- Building a specific vendor dashboard stack in this proposal

## Decisions

### SLI dimensions
Track success rate, latency, freshness, backlog depth/age, and integrity failure counts.

### OpenTelemetry metric contract
Use stable, dot-delimited metric names under `goodaudit.audit.*` with explicit units:
- Histogram (ms):
  - `goodaudit.audit.verification.duration`
  - `goodaudit.audit.checkpoint_worker.account_duration`
  - `goodaudit.audit.anchoring.request.duration`
- Counter (count):
  - `goodaudit.audit.verification.requests`
  - `goodaudit.audit.verification.failures`
  - `goodaudit.audit.checkpoint_worker.checkpoints_created`
  - `goodaudit.audit.checkpoint_worker.account_failures`
  - `goodaudit.audit.anchoring.requests`
  - `goodaudit.audit.anchoring.failures`
- Gauge:
  - `goodaudit.audit.checkpoint.staleness_seconds`
  - `goodaudit.audit.anchoring.backlog_count`
  - `goodaudit.audit.anchoring.backlog_oldest_age_seconds`

### Label cardinality policy
Allowed low-cardinality labels: `env`, `service`, `verification_mode`, `result`, `error_class`, `key_type`.
Disallowed as labels (high cardinality): `account_id`, `user_id`, `checkpoint_id`, `api_key_id`, raw exception text.
High-cardinality identifiers may appear in sampled traces/logs, not metrics.

### OpenTelemetry tracing contract
Emit spans with stable names and attributes:
- `audit.verify_chain`
  - attrs: `verification.mode`, `verification.start_sequence`, `verification.total_entries`, `verification.valid`
- `audit.checkpoint_worker.run`
  - attrs: `worker.run_accounts_total`, `worker.run_accounts_succeeded`, `worker.run_accounts_failed`
- `audit.checkpoint_worker.account`
  - attrs: `account.status`, `checkpoint.created`, `anchoring.attempted`, `anchoring.result`
- `audit.anchor_checkpoint`
  - attrs: `anchor.sequence_number`, `anchor.result`, `anchor.error_class`

Trace attributes may include `account_id` only when sampling and data handling policies permit; never include API key material or HMAC key data.

### Threshold tiers
Define warning and critical thresholds with explicit evaluation windows.

### Runbook ownership
Each alert references owner/team and runbook URL/id.

## Risks / Trade-offs

- Initial threshold tuning may require multiple iterations
- Excessive cardinality must be controlled in labels
