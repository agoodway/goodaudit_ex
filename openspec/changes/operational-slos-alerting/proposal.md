## Why

The current proposals define behavior but do not define operational targets. Production operation requires explicit SLOs, metrics, and alert thresholds for checkpointing, anchoring, and verification.

## What Changes

1. **SLO definitions** - Add measurable SLOs for verification latency, checkpoint freshness, and anchoring backlog.
2. **Metric contract** - Standardize counters/histograms/gauges and labels.
3. **Alert policy** - Define warning/critical thresholds and paging behavior.
4. **Runbook linkage** - Each alert maps to a concrete remediation runbook.
5. **OpenTelemetry contract** - Define concrete OTEL metric names, units, label set, and tracing spans/attributes.

## Capabilities

### New Capabilities
- `operability-slos`: Explicit reliability and latency objectives for audit subsystems
- `operability-alerting`: Threshold-driven alerts with runbook mapping

### Modified Capabilities
- `checkpoint-worker`: Emits freshness, success, and backlog metrics
- `verification-engine`: Emits mode-aware latency and failure metrics
- `anchoring-integration`: Emits anchoring success/failure and backlog-age metrics
- `audit-endpoints`: Emits request spans and verification mode/result attributes

## Impact

- **Modified files**: worker/verifier/anchoring modules to emit telemetry
- **New files**: alert/runbook docs and dashboards
- **New tests**: metric emission and threshold evaluation
- **New docs**: OTEL metric/trace contract with cardinality limits and units (`openspec/changes/operational-slos-alerting/otel-contract.md`)
