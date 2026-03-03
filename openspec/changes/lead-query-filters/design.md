## Context

Audit querying currently supports generic filters but lacks lead-distribution dimensions needed for routing investigations, partner reconciliation, and compliance evidence retrieval.

## Goals / Non-Goals

**Goals:**
- Add lead-specific query filters for operational and compliance workflows.
- Preserve account-scoped isolation and cursor pagination semantics.
- Add index strategy for predictable performance on high-cardinality dimensions.
- Expose applied-filter metadata so clients can verify query intent.

**Non-Goals:**
- Building an ad hoc analytics engine or OLAP cube.
- Introducing cross-account federated query features.
- Replacing cursor pagination with offset pagination.

## Decisions

### Expand filter grammar in context query builder
Support filter options for lead/domain dimensions (`lead_id`, `source_id`, `buyer_id`, `campaign_id`, `vertical`, `delivery_channel`, `event_type`, `decision_reason_code`, `suppression_status`, `dedup_status`).

### Keep account filter as mandatory first predicate
All lead filters are additive to implicit account scope to preserve tenant isolation and index locality.

### Add targeted account-prefixed composite indexes
Introduce only composites tied to common multi-predicate paths to avoid index explosion.

### Return diagnostics metadata
Include applied filters, effective limit, and cursor boundary info in response `meta` for client correctness.

## Risks / Trade-offs

- [Index proliferation] -> Start with minimal composite set and iterate from telemetry.
- [Filter parsing complexity] -> Centralize coercion with strict validation and clear errors.
- [Large predicate combinations] -> Enforce bounded limit and deterministic sort path.

## Migration Plan

1. Add schema/index support for lead filter dimensions.
2. Extend query parser and builder with strict coercion.
3. Update endpoint schemas/docs with new parameters and metadata.
4. Add correctness/performance tests for compound filters.

## Open Questions

- Should multi-value filters (IN semantics) be introduced now or in a follow-up?
