## Why

Lead platforms ingest high-volume events from multiple producers. Single-event POST endpoints are necessary but insufficient for throughput, integration ergonomics, and operational resilience. The platform needs explicit ingestion modes with consistent idempotency, ordering, and error semantics.

## What Changes

1. **Single-event ingestion contract** - Preserve existing synchronous single-write API for low-latency use cases.
2. **Bulk ingestion endpoint** - Add bounded batch ingestion with per-item status reporting and partial-failure semantics.
3. **Webhook ingestion mode** - Add signed webhook intake path for partner push integrations with replay protection.
4. **Idempotency and dedup keys** - Define deterministic idempotency rules across single, bulk, and webhook paths.
5. **Rate limit and backpressure policy** - Define per-account ingestion quotas, retry guidance, and overload behavior.

## Capabilities

### New Capabilities
- `bulk-audit-ingestion`: High-throughput batch ingest with itemized success/failure reporting
- `webhook-audit-ingestion`: Signed webhook intake with replay detection and idempotent processing
- `ingestion-idempotency`: Cross-mode deduplication and exactly-once effect at the audit layer

### Modified Capabilities
- `audit-log-endpoints`: Extend endpoint surface to support batch and webhook contracts
- `operability-slos`: Add ingestion throughput/error SLOs and mode-specific telemetry

## Impact

- **Modified files**: router, controllers, endpoint schemas, context write paths
- **New files**: webhook signature verifier, idempotency key store/policy modules
- **New tests**: partial batch failures, retry safety, replay attacks, and quota enforcement
