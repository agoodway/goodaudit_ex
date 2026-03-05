## Context

The audit log schema hardcodes HIPAA-specific fields (`phi_accessed`, `user_role`, `source_ip`, `session_id`, `failure_reason`, `user_agent`) as top-level columns on `audit_logs`. Non-HIPAA tenants carry unused columns and pay for indexes they never query. Other compliance frameworks (PCI-DSS, SOC 2, GDPR) have required fields (`cardholder_data_accessed`, `change_ticket_id`, `legal_basis`, `data_subject_id`) with no structured home — they end up in the untyped `metadata` JSONB blob where they cannot be validated or efficiently queried. The upcoming `compliance-framework-profiles` change will define per-framework extension schemas, but the storage layer has no mechanism to receive them.

## Goals / Non-Goals

**Goals:**
- Separate universal audit fields (who/what/when/outcome + chain integrity) from framework-specific extension fields.
- Introduce a validated, namespaced `extensions` JSONB column that framework modules populate with typed fields.
- Enable efficient querying of extension fields via GIN and partial expression indexes.

**Non-Goals:**
- Defining the full set of framework extension schemas (that belongs to `compliance-framework-profiles`).
- Changing the chain verification algorithm (HMAC-SHA-256 stays).
- Supporting per-field encryption within extensions (field-level encryption is a separate concern).
- Building a UI for extension schema management.

## Decisions

### Use actor_id instead of user_id

The field is named `actor_id` (not `user_id`) because audit events may be triggered by service accounts, automated jobs, or API keys -- not just human users. The schema uses `actor_id` from the start.

### Extensions column namespaced by framework

The `extensions` column is a JSONB map where each top-level key is a framework identifier (e.g., `hipaa`, `soc2`, `pci`, `gdpr`). Each framework's sub-map contains only the fields defined by that framework's extension schema. This prevents field name collisions across frameworks and makes it clear which framework owns which data. Example: `{"hipaa": {"phi_accessed": true, "user_role": "nurse", "source_ip": "10.0.1.5"}, "soc2": {"change_ticket_id": "JIRA-123"}}`.

### Application-layer validation, not database constraints

Extension fields are validated by `GA.Compliance.ExtensionSchema.validate/2` at the application layer before insertion. Database-level JSON schema constraints are brittle, hard to version, and not portable across Postgres versions. The application layer can provide rich error messages, support schema evolution, and integrate with the framework profile system.

### Direct schema with extensions

The schema includes `extensions` JSONB column (default `{}`) and `actor_id` column from the start. There are no legacy HIPAA-specific columns to migrate from -- the schema is designed with extensions from day one. No feature flags or phased rollout needed.

### Canonical payload format

The HMAC canonical payload format is: `"#{account_id}|#{sequence_number}|#{previous_checksum}|#{actor_id}|#{action}|#{resource_type}|#{resource_id}|#{outcome}|#{timestamp}|#{sorted_extensions_json}|#{sorted_metadata_json}"`. There is only one canonical payload format -- no legacy format detection or format versioning needed.

### Sorted extensions JSON for deterministic hashing

The `sorted_extensions_json` representation sorts keys at every nesting level (framework keys sorted alphabetically, then each framework's field keys sorted alphabetically) using the same `sort_keys_recursive/1` utility already used for metadata canonicalization. This ensures deterministic HMAC computation regardless of map insertion order.

### GIN index with targeted partial expression indexes

A GIN index on the `extensions` column enables `@>` containment queries across all frameworks. For high-frequency query patterns, partial expression indexes target specific paths: e.g., `(extensions->'hipaa'->>'phi_accessed') WHERE extensions->'hipaa' IS NOT NULL`. These are added per-framework as usage patterns emerge rather than created speculatively for every possible field.

## Risks / Trade-offs

### Extension validation depends on framework profiles
`GA.Compliance.ExtensionSchema.validate/2` needs framework schema definitions from the `compliance-framework-profiles` change. Until that change lands, HIPAA extension validation can be hardcoded as a bootstrap schema. Other frameworks are validated only after their profiles are defined.

### JSONB query performance on large datasets
GIN indexes add write overhead and the index size grows with extension data variety. Mitigation: partial indexes constrained to non-null framework sub-maps reduce index size. Monitor index bloat and vacuum frequency.

### OpenAPI schema rewrite

The existing `AuditLogRequest`, `AuditLogResponse`, and `AuditLogListResponse` OpenApiSpex schemas must be rewritten to reflect the new field structure: `actor_id` replaces `user_id`, HIPAA-specific flat fields are removed, and `extensions` (object) is added. The `AuditLogController` operation annotations must update query parameters: remove `user_id` and `phi_accessed` filters, add `extensions` JSONB containment filter support.

## Migration Plan

1. Create `audit_logs` table with `extensions` JSONB column (default `{}`), `actor_id` column, and GIN index on `extensions`.
2. Deploy extension validation and canonical payload format.
3. Rewrite OpenApiSpex request/response schemas and controller annotations.
4. Add partial expression indexes for high-frequency extension paths as frameworks are onboarded.

## Open Questions

- Should extension schema definitions be stored in the database (for runtime configurability) or in code (for version control and deploy-time validation)?
