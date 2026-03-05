## Context

GoodAudit hardcodes HIPAA-specific fields (`phi_accessed`, `user_role`, `source_ip`, etc.) into the audit log schema and chain computation. Organizations operating under SOC 2, PCI-DSS, GDPR, ISO 27001, or overlapping combinations cannot use GoodAudit without carrying HIPAA-specific baggage or missing framework-specific requirements. A compliance framework profile system lets each account declare which standards it operates under and adapts validation, retention defaults, and verification cadence accordingly.

## Goals / Non-Goals

**Goals:**
- Define a `GA.Compliance.Framework` behaviour that standardizes framework declarations (required fields, recommended fields, retention, verification cadence, extension schema, event taxonomy).
- Ship built-in framework modules for HIPAA, SOC 2 Type II, PCI-DSS v4, GDPR, and ISO 27001.
- Allow accounts to associate with one or more active frameworks simultaneously.
- Validate audit log entries against the union of required fields from all active frameworks before chain insertion.
- Record which frameworks were active at entry creation time for historical attribution and chain integrity.
- Support per-account configuration overrides on framework defaults.

**Non-Goals:**
- Custom framework registration API (the behaviour is public for internal use, but customer-facing custom framework registration is out of scope).
- Framework-specific reporting templates (separate future change).
- Retroactively applying framework attribution to entries.
- Per-framework retention enforcement (retention defaults are informational; enforcement lives in the audit-log-lifecycle change).
- FedRAMP framework (listed in the proposal motivation but deferred to a follow-up).

## Decisions

### Framework behaviour module with compile-time callbacks

`GA.Compliance.Framework` defines a behaviour with six callbacks: `name/0`, `required_fields/0`, `recommended_fields/0`, `default_retention_days/0`, `verification_cadence_hours/0`, `extension_schema/0`, and `event_taxonomy/0`. Each built-in framework is a module that implements this behaviour (e.g., `GA.Compliance.Frameworks.HIPAA`). This keeps framework definitions declarative, testable, and composable without a database-backed registry.

### Account association via join table

A new `account_compliance_frameworks` table stores `account_id`, `framework_id` (string like `"hipaa"`, `"soc2"`), `activated_at`, and `config_overrides` (JSONB). This is a join table, not a framework registry table -- the framework definitions live in code. The `framework_id` string maps to a module via `GA.Compliance.registry/0`. Multiple rows per account enable multi-framework compliance (e.g., HIPAA + SOC 2 for a healthcare SaaS).

### Union-based required field validation on entry creation

When `create_log_entry/2` is called, the system looks up the account's active frameworks, computes the union of all `required_fields/0` across those frameworks, and validates presence before chain insertion. If any required field is missing, the entry is rejected with a 422 containing framework-attributed error messages: `{"errors": {"field": ["required by HIPAA", "required by SOC 2"]}}`. Accounts with no active frameworks skip framework validation (frameworks field is still set to `[]`).

### Frameworks field on audit_logs for historical attribution

A new `frameworks` column (string array, `{:array, :string}`) on `audit_logs` records which framework IDs were active at creation time. This field is included in the canonical payload for chain integrity -- meaning the checksum covers the frameworks that were active when the entry was written. This ensures historical entries remain correctly attributed even if the account changes frameworks later.

### Config overrides are scoped to framework defaults

The `config_overrides` JSONB column on `account_compliance_frameworks` allows per-account overrides of framework defaults (e.g., extending retention from the default 2555 days to 3650 days, or adding extra required fields). Overrides merge with framework defaults at runtime. Only whitelisted keys are accepted: `retention_days`, `verification_cadence_hours`, `additional_required_fields`.

### Built-in framework module naming

Framework modules live under `lib/app/compliance/frameworks/` with filenames matching the framework ID: `hipaa.ex`, `soc2.ex`, `pci_dss.ex`, `gdpr.ex`, `iso27001.ex`. The `GA.Compliance` context module maintains a compile-time registry mapping framework IDs to modules.

## Risks / Trade-offs

- [Union of required fields across frameworks may be overly strict for some accounts] -> Per-account `config_overrides` can relax requirements.
- [Framework behaviour is public, risking unstable API surface] -> The behaviour callbacks are simple value-returning functions (no side effects). Marking the behaviour as `@moduledoc false` initially and stabilizing the interface before documenting it publicly.
- [JSONB config_overrides could become a dumping ground] -> Whitelist accepted override keys and validate structure on write. Unknown keys are rejected.
- [Multi-framework field conflicts (same field required with different semantics)] -> Required fields are purely presence-based (field must be non-nil). Semantic validation per-framework is a future concern, not addressed in this change.

## Migration Plan

1. Add migration creating `account_compliance_frameworks` table with `account_id` (references accounts), `framework_id` (string), `activated_at` (utc_datetime_usec), `config_overrides` (map/JSONB), and a unique index on `(account_id, framework_id)`.
2. Add migration adding `frameworks` column (`{:array, :string}`, default `[]`) to `audit_logs`.
3. Deploy framework behaviour and built-in modules.
4. Deploy framework-aware validation in `create_log_entry/2`.
5. Update canonical payload computation to include `frameworks` field.
6. Update OpenApiSpex schemas (`AuditLogResponse`, `AuditLogListResponse`) to include `frameworks` field and update `AuditLogController` error documentation for framework-attributed validation errors.

## Open Questions

- Should framework activation require confirmation (e.g., dry-run validation of recent entries against the new framework's required fields) to prevent accidental lockout?
- Should `recommended_fields` trigger warnings in the API response or only surface in compliance reports?
- What is the upgrade path for `extension_schema/0` -- should it feed into a future JSON Schema validation layer on the `metadata` field?
