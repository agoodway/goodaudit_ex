## Context

`audit_logs` currently encodes HIPAA-centric assumptions that treat user-driven actions as the default. Lead distribution workloads are predominantly system-to-system and need durable routing dimensions and versioned payload contracts while preserving append-only chain guarantees.

## Goals / Non-Goals

**Goals:**
- Generalize required fields so both user and system actors are valid.
- Add first-class lead distribution columns for stable querying and reporting.
- Introduce schema version stamping and validation at write time.
- Preserve backward compatibility for existing HIPAA-oriented producers.

**Non-Goals:**
- Replacing metadata JSONB for every domain-specific attribute.
- Introducing partner billing, settlement, or payout models.
- Changing cryptographic checksum logic beyond canonical payload updates.

## Decisions

### Add explicit lead dimensions to `audit_logs`
Use nullable, indexed columns (`lead_id`, `source_id`, `buyer_id`, `campaign_id`, `vertical`, `delivery_channel`) instead of metadata-only storage for high-selectivity investigation paths.

### Shift actor requirements from user-only to actor model
Add `actor_type` (`user|system|partner|policy`) + `actor_id`; retain `user_id`/`user_role` as optional compatibility fields. This supports automation while preserving current consumers.

### Stamp and validate `schema_version`
Add `schema_version` with default `1`; reject unknown future versions unless explicitly configured. This keeps ingestion deterministic across producer upgrades.

### Extend canonical payload to include new deterministic fields
Canonical checksum payload will include new columns in fixed order, using empty-string rendering for nils. This preserves tamper-evidence for all newly introduced fields.

## Risks / Trade-offs

- [Migration lock and table churn] -> Use additive migration with nullable columns first, then phased validation tightening.
- [Producer breakage from stricter validation] -> Keep compatibility profile where legacy fields remain accepted for v1.
- [Index bloat from new dimensions] -> Add only query-backed indexes and measure cardinality before adding composites.

## Migration Plan

1. Add new columns and baseline indexes with no destructive changes.
2. Update schema/changeset and context write path to set `schema_version` and actor model fields.
3. Update canonical payload and verifier parity tests.
4. Roll out producer guidance for lead dimensions and actor_type.

## Open Questions

- Should `vertical` be free-text or constrained enum from taxonomy?
- Should `delivery_channel` be normalized to a lookup table in a later change?
