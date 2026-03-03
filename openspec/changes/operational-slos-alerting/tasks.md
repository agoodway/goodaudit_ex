## 1. SLO/SLI Definition

- [ ] 1.1 Define SLOs for verification latency, checkpoint freshness, and anchoring backlog age
- [ ] 1.2 Define SLI formulas and measurement windows

## 2. Telemetry Contract

- [ ] 2.1 Add metric names, types, and label constraints to specs
- [ ] 2.2 Emit metrics from verifier/worker/anchoring paths
- [ ] 2.3 Add OTEL unit conventions (ms, seconds, count) and monotonic counter semantics
- [ ] 2.4 Enforce low-cardinality labels; reject high-cardinality identifiers in metrics

## 3. Tracing Contract

- [ ] 3.1 Add span names and required attributes for verifier/worker/anchoring flows
- [ ] 3.2 Instrument endpoint-to-context trace propagation for verification and checkpoint APIs
- [ ] 3.3 Add redaction rules to prevent API key/HMAC key material in span attributes/events

## 4. Alert Policy + Runbooks

- [ ] 4.1 Define warning/critical thresholds and routing
- [ ] 4.2 Author remediation runbooks for each alert family

## 5. Tests

- [ ] 5.1 Verify metric emission for success/failure paths
- [ ] 5.2 Verify metric labels conform to cardinality policy
- [ ] 5.3 Verify span creation and required attributes for key flows
- [ ] 5.4 Verify alert condition evaluation with synthetic fixtures
