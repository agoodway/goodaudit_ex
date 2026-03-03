## Context

Audit ingestion currently emphasizes single synchronous writes. Lead distribution platforms need flexible transport modes (single, bulk, webhook) with uniform idempotency and predictable failure semantics.

## Goals / Non-Goals

**Goals:**
- Support single, bulk, and webhook ingestion with shared validation semantics.
- Provide deterministic idempotency behavior across all ingestion paths.
- Define rate-limit and backpressure behavior per account.
- Preserve append-only and account-isolation guarantees.

**Non-Goals:**
- Building streaming ingestion via Kafka/SQS in this change.
- Introducing async eventual-write queues for all requests.
- Redesigning existing authentication primitives.

## Decisions

### Add dedicated bulk endpoint with per-item results
Bulk requests return itemized status to support partial successes without hiding failed events.

### Add signed webhook endpoint with replay protection
Webhook requests require signature verification and timestamp/nonce checks; replayed payloads are rejected idempotently.

### Centralize idempotency in context layer
Use idempotency keys resolved at account scope so all modes share dedup behavior and observable outcomes.

### Enforce quota-aware backpressure
Define per-account request and item throughput limits with explicit `429` response and retry guidance.

## Risks / Trade-offs

- [Bulk amplification of bad payloads] -> Validate per item and return granular failures.
- [Webhook signature drift across partners] -> Provide strict canonical signing docs and test fixtures.
- [Hot-account starvation] -> Use account-scoped quotas and fair scheduling metrics.

## Migration Plan

1. Add endpoint schemas and routing for bulk/webhook ingestion.
2. Implement shared idempotency service used by all write paths.
3. Add rate-limit enforcement and telemetry dimensions per ingestion mode.
4. Roll out partner webhook signatures in staged environment before production.

## Open Questions

- Should bulk endpoint support atomic mode in addition to partial mode?
