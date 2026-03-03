## Context

Current enums (`action`, `outcome`) are oriented to generic CRUD/login events and do not represent lead-marketplace workflows. Without a canonical taxonomy, producers invent incompatible values and downstream analytics/compliance become brittle.

## Goals / Non-Goals

**Goals:**
- Define canonical lead lifecycle event types with stable semantics.
- Standardize outcome and decision reason codes for routing and suppression paths.
- Expand actor semantics for human and automated decision makers.
- Publish taxonomy through OpenAPI-visible enums and docs.

**Non-Goals:**
- Building a full ontology management service.
- Supporting arbitrary custom enums per tenant in this change.
- Altering auth or ingestion transport behavior.

## Decisions

### Introduce `event_type` and `event_family`
Use explicit event taxonomy values (for example capture, dedup, score, route, deliver, reject, suppress) and family grouping for simpler filtering.

### Add normalized `decision_reason_code`
Use machine-readable codes separate from free-text reason strings to support deterministic reporting.

### Preserve backward compatibility with existing `action`
Map legacy action values into taxonomy defaults during migration period; do not remove `action` immediately.

### Enforce actor type compatibility
Validation rules tie `actor_type` to required fields (for example `partner` requires partner identifier).

## Risks / Trade-offs

- [Taxonomy lock-in] -> Use versioned catalog with additive evolution and deprecation windows.
- [Producer migration complexity] -> Provide compatibility mapping and clear validation errors.
- [Enum churn in APIs] -> Keep stable public codes; reserve internal aliases for translation.

## Migration Plan

1. Add taxonomy fields and catalogs.
2. Implement compatibility mapper for legacy `action` values.
3. Update endpoint schemas and docs with enums.
4. Enforce strict validation after migration window.

## Open Questions

- Should partner-specific reason codes be namespaced or globally cataloged?
