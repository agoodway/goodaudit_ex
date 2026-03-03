## Context

Retention and archival exist, but the platform lacks first-class privacy workflow constructs for consent provenance, revocation/suppression, and DSAR handling. Lead systems need auditable evidence without breaking append-only chain integrity.

## Goals / Non-Goals

**Goals:**
- Capture immutable consent provenance metadata with policy lineage.
- Model opt-out and suppression enforcement as explicit audited events.
- Define DSAR lifecycle states and evidence for completion SLAs.
- Preserve append-only guarantees while supporting anonymization/tombstoning.

**Non-Goals:**
- Building legal policy authoring tooling.
- Supporting jurisdiction-specific legal advice in product logic.
- Performing destructive hard deletes of audit rows.

## Decisions

### Separate provenance fields from mutable profile state
Consent evidence is recorded on immutable audit events; mutable customer profile state remains outside this change.

### DSAR modeled as workflow records plus audit events
Track DSAR request lifecycle in dedicated records and emit immutable audit events for each state transition.

### Anonymization over deletion for audit integrity
Use deterministic tombstoning/anonymization of personal payload attributes while retaining chain and process evidence.

### Suppression enforcement is decision-audited
Suppression checks and outcomes are logged as reason-coded events to prove compliance behavior at decision time.

## Risks / Trade-offs

- [Regulatory interpretation variance] -> Keep fields jurisdiction-aware and configurable, not hardcoded to one law.
- [Over-redaction harming investigations] -> Define minimal retained fields and role-gated rehydration paths.
- [Workflow drift across teams] -> Use explicit DSAR state machine and SLA timestamps.

## Migration Plan

1. Add consent and DSAR schema elements.
2. Add suppression/consent event taxonomy and query filters.
3. Extend retention/archive logic with DSAR constraints.
4. Add compliance reports and evidence endpoints.

## Open Questions

- Should DSAR state machine be shared with non-audit customer data workflows or remain audit-local?
