## ADDED Requirements

### Requirement: Explicit SLOs for audit operations

The system MUST define and publish SLO targets for key production behaviors.

#### Scenario: Verification latency SLO
- **WHEN** verification requests are measured over the SLO window
- **THEN** p95 latency meets the configured target threshold

#### Scenario: Checkpoint freshness SLO
- **WHEN** active accounts are evaluated
- **THEN** checkpoint staleness remains under configured freshness target

### Requirement: OpenTelemetry metric contract

The system MUST emit OpenTelemetry metrics with stable names, units, and low-cardinality labels.

Required metrics:
- `goodaudit.audit.verification.duration` (histogram, ms)
- `goodaudit.audit.verification.requests` (counter)
- `goodaudit.audit.verification.failures` (counter)
- `goodaudit.audit.checkpoint_worker.account_duration` (histogram, ms)
- `goodaudit.audit.checkpoint_worker.checkpoints_created` (counter)
- `goodaudit.audit.checkpoint_worker.account_failures` (counter)
- `goodaudit.audit.checkpoint.staleness_seconds` (gauge)
- `goodaudit.audit.anchoring.request.duration` (histogram, ms)
- `goodaudit.audit.anchoring.requests` (counter)
- `goodaudit.audit.anchoring.failures` (counter)
- `goodaudit.audit.anchoring.backlog_count` (gauge)
- `goodaudit.audit.anchoring.backlog_oldest_age_seconds` (gauge)

Allowed metric labels: `env`, `service`, `verification_mode`, `result`, `error_class`, `key_type`.
Disallowed metric labels: `account_id`, `user_id`, `checkpoint_id`, `api_key_id`, and raw error text.

#### Scenario: Verification metrics emitted
- **WHEN** `verify_chain` runs in incremental mode and succeeds
- **THEN** `goodaudit.audit.verification.requests` increments with `verification_mode=incremental,result=success` and `goodaudit.audit.verification.duration` records latency in milliseconds

#### Scenario: Label cardinality guard
- **WHEN** metrics are emitted for account-scoped operations
- **THEN** no high-cardinality identifiers (for example `account_id`) are attached as metric labels

### Requirement: OpenTelemetry tracing contract

The system MUST emit spans with stable names and required attributes for core audit flows.

Required span names:
- `audit.verify_chain`
- `audit.checkpoint_worker.run`
- `audit.checkpoint_worker.account`
- `audit.anchor_checkpoint`

#### Scenario: Verification span attributes
- **WHEN** `audit.verify_chain` span is emitted
- **THEN** span includes `verification.mode`, `verification.start_sequence`, `verification.total_entries`, and `verification.valid`

#### Scenario: Sensitive data excluded from traces
- **WHEN** spans/events are emitted from auth, key, or anchoring paths
- **THEN** API key material and HMAC key data are never included in attributes or events

### Requirement: Alert thresholds and runbook mapping

Each critical SLI MUST have warning/critical alert thresholds and linked runbook remediation steps.

#### Scenario: Anchoring backlog breach
- **WHEN** anchoring backlog age exceeds critical threshold
- **THEN** a critical alert fires with runbook reference and owning team
