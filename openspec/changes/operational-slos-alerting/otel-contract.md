## OpenTelemetry Contract Appendix

This appendix is a normative mapping reference for implementation.

## Metrics Mapping

| Metric | Instrument | Unit | Required Labels | Notes |
|---|---|---|---|---|
| `goodaudit.audit.verification.duration` | Histogram | `ms` | `env`, `service`, `verification_mode`, `result` | Record one point per verification run |
| `goodaudit.audit.verification.requests` | Counter (monotonic) | `1` | `env`, `service`, `verification_mode`, `result` | Increment once per verification request |
| `goodaudit.audit.verification.failures` | Counter (monotonic) | `1` | `env`, `service`, `verification_mode`, `error_class` | Increment for integrity or execution failures |
| `goodaudit.audit.checkpoint_worker.account_duration` | Histogram | `ms` | `env`, `service`, `result` | Per-account processing latency |
| `goodaudit.audit.checkpoint_worker.checkpoints_created` | Counter (monotonic) | `1` | `env`, `service`, `result` | Successful checkpoint writes |
| `goodaudit.audit.checkpoint_worker.account_failures` | Counter (monotonic) | `1` | `env`, `service`, `error_class` | Per-account worker failures |
| `goodaudit.audit.checkpoint.staleness_seconds` | Gauge | `s` | `env`, `service` | Current oldest staleness among active accounts |
| `goodaudit.audit.anchoring.request.duration` | Histogram | `ms` | `env`, `service`, `result` | One point per anchor attempt |
| `goodaudit.audit.anchoring.requests` | Counter (monotonic) | `1` | `env`, `service`, `result` | Includes idempotent successes |
| `goodaudit.audit.anchoring.failures` | Counter (monotonic) | `1` | `env`, `service`, `error_class` | Service/network/validation failures |
| `goodaudit.audit.anchoring.backlog_count` | Gauge | `1` | `env`, `service` | Unanchored checkpoint count |
| `goodaudit.audit.anchoring.backlog_oldest_age_seconds` | Gauge | `s` | `env`, `service` | Age of oldest unanchored checkpoint |

## Traces Mapping

| Span Name | Kind | Required Attributes | Optional Attributes |
|---|---|---|---|
| `audit.verify_chain` | Internal | `verification.mode`, `verification.start_sequence`, `verification.total_entries`, `verification.valid` | `verification.first_failure_type`, `verification.duration_ms` |
| `audit.checkpoint_worker.run` | Internal | `worker.run_accounts_total`, `worker.run_accounts_succeeded`, `worker.run_accounts_failed` | `worker.run_duration_ms` |
| `audit.checkpoint_worker.account` | Internal | `account.status`, `checkpoint.created`, `anchoring.attempted`, `anchoring.result` | `worker.account_duration_ms` |
| `audit.anchor_checkpoint` | Internal | `anchor.sequence_number`, `anchor.result` | `anchor.error_class`, `anchor.duration_ms` |

## Label and Attribute Constraints

- Allowed metric labels: `env`, `service`, `verification_mode`, `result`, `error_class`, `key_type`.
- Disallowed metric labels: `account_id`, `user_id`, `checkpoint_id`, `api_key_id`, raw exception text.
- Sensitive data forbidden in traces and events: API key material, HMAC key material, bearer token values.
- `account_id` in traces is allowed only when sampling and data policies permit.

## Error Class Vocabulary

Use bounded `error_class` values only:

- `validation`
- `not_found`
- `timeout`
- `db`
- `network`
- `auth`
- `integrity`
- `service_unavailable`
- `unknown`

## Result Vocabulary

Use bounded `result` values:

- `success`
- `failure`
- `skipped`
- `idempotent`

## Validation Checklist

- Each required metric is emitted in success and failure paths.
- Counters are monotonic and never decremented.
- Histogram units are milliseconds.
- No high-cardinality identifiers appear as metric labels.
- Required span attributes are present for each span type.
- Sensitive fields are absent from telemetry payloads.

## Example Telemetry Payloads

### Example: Successful incremental verification

Metrics (conceptual):

```text
counter goodaudit.audit.verification.requests +1
  labels: env=prod service=goodaudit verification_mode=incremental result=success

histogram goodaudit.audit.verification.duration record 42
  labels: env=prod service=goodaudit verification_mode=incremental result=success
```

Trace span (conceptual):

```json
{
  "name": "audit.verify_chain",
  "attributes": {
    "verification.mode": "incremental",
    "verification.start_sequence": 120000,
    "verification.total_entries": 340,
    "verification.valid": true
  }
}
```

### Example: Anchoring failure (service unavailable)

Metrics (conceptual):

```text
counter goodaudit.audit.anchoring.requests +1
  labels: env=prod service=goodaudit result=failure

counter goodaudit.audit.anchoring.failures +1
  labels: env=prod service=goodaudit error_class=service_unavailable

histogram goodaudit.audit.anchoring.request.duration record 350
  labels: env=prod service=goodaudit result=failure
```

Trace span (conceptual):

```json
{
  "name": "audit.anchor_checkpoint",
  "attributes": {
    "anchor.sequence_number": 4021,
    "anchor.result": "failure",
    "anchor.error_class": "service_unavailable"
  },
  "events": [
    {"name": "anchor_failed", "attributes": {"reason": "upstream_unavailable"}}
  ]
}
```

Note: even in failure examples, do not include `account_id`, API keys, bearer tokens, or HMAC key data in metric labels or sensitive span attributes.
