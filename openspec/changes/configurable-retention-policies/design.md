## Context

The `audit-log-lifecycle` change manages partition aging and archival using a single global retention constant. In practice, accounts operate under different compliance frameworks with incompatible retention requirements: HIPAA mandates 6 years, PCI-DSS requires 1 year (3 years for some controls), SOC 2 recommends at least 1 year, ISO 27001 typically requires 3 years, and GDPR requires retention only as long as the processing purpose exists. Accounts under multiple frameworks must satisfy the longest applicable period while not over-retaining data unnecessarily (particularly relevant under GDPR's data minimization principle).

Without per-framework retention logic the system either over-retains for all accounts (wasting storage and increasing GDPR exposure) or under-retains (violating framework requirements). Retention should be automatically computed from active frameworks, surfaced transparently, and overridable per account within compliance bounds.

## Goals / Non-Goals

**Goals:**
- Each compliance framework module declares its retention requirements (minimum, maximum, recommendation)
- The system computes an effective retention policy from all frameworks active on an account
- Conflicts between framework requirements (e.g., HIPAA minimum vs GDPR minimization) are surfaced as human-readable warnings, not silently resolved
- Accounts can override the computed retention if the override satisfies the minimum floor
- The `audit-log-lifecycle` partition aging uses per-account effective retention instead of a global constant
- Retention posture is visible through an API for compliance officers
- GDPR-active accounts can track purpose-dependent retention with expiry

**Non-Goals:**
- Automatic data deletion without the existing archive-first workflow from `audit-log-lifecycle`
- Per-entry retention periods (retention is per-account, not per-row)
- Building a full GDPR consent management system (purpose tracking is limited to retention tagging)
- Real-time retention enforcement on write path (retention is enforced by background partition aging jobs)

## Decisions

### Framework retention callback

Each framework module implements a `retention_policy/0` callback returning a map with `minimum_days`, `maximum_days` (integer or nil), `recommendation_days`, and `description`. This keeps retention declarations co-located with framework definitions and avoids a separate configuration table.

Specific framework values:
- **HIPAA**: min 2190 (6 years), max nil, rec 2190
- **SOC 2**: min 365 (1 year), max nil, rec 365
- **PCI-DSS**: min 365 (1 year), max nil, rec 1095 (3 years for some controls)
- **GDPR**: min 0 (purpose-dependent), max nil (data minimization principle applies via warnings), rec 365
- **ISO 27001**: min 1095 (3 years), max nil, rec 1095

### Effective retention computation as max/min aggregation

The effective policy is computed from all active frameworks on an account:
- `effective_minimum = max(all framework minimums)` -- the strictest floor wins
- `effective_maximum = min(all framework maximums that are non-nil)` or nil if no framework sets a ceiling
- `effective_recommendation = max(all framework recommendations)` -- most conservative suggestion

If `effective_minimum > effective_maximum`, a conflict is flagged. This situation requires human resolution (the account cannot satisfy both constraints simultaneously).

### Account-level retention columns

Add to the `accounts` table:
- `retention_effective_days` (integer, computed from active frameworks)
- `retention_override_days` (integer, nullable -- account-level override when set)
- `retention_computed_at` (utc_datetime -- last recomputation timestamp)
- `retention_conflicts` (array of strings -- human-readable conflict descriptions)

These are denormalized for fast reads by partition aging jobs. Recomputation is triggered by framework activation/deactivation changes, not on every query.

### Override validation with asymmetric strictness

`set_retention_override(account_id, days)`:
- If `days >= effective_minimum`: accept and store the override.
- If `days < effective_minimum`: reject with error naming the framework(s) that require the longer period.
- If `days > effective_maximum` (when set): warn but accept. Over-retention is less risky than under-retention and may be a deliberate business decision.

### Recomputation triggers

Recompute `retention_effective_days` when:
- A framework is activated or deactivated on the account
- A framework module's retention policy changes (version/code update)
- An override is set or cleared

This is event-driven, not polled. Framework activation already goes through a known code path that can trigger recomputation.

### Integration with audit-log-lifecycle partition aging

The `audit-log-lifecycle` change's partition aging jobs read `retention_effective_days` (or `retention_override_days` when set) from the account record. Each account's partitions age independently based on its own effective retention. This replaces the single global retention constant.

### GDPR purpose tracking via extensions and a purposes table

For GDPR-active accounts, audit entries can include `extensions.gdpr.retention_purpose` (string). A `retention_purposes` table tracks active purposes per account with expiry dates. When a purpose expires, entries tagged with only that purpose become candidates for archival -- but still subject to the union with other active framework minimums (e.g., if the account also has HIPAA active, the HIPAA 6-year minimum still applies regardless of purpose expiry).

### Retention compliance API

Three endpoints under existing auth:
- `GET /api/v1/retention-policy` -- returns effective retention, contributing frameworks, override (if any), conflicts, and data age range
- `PUT /api/v1/retention-policy` -- set retention override (validated against minimum)
- `DELETE /api/v1/retention-policy` -- clear override, revert to computed

These use the existing `:api_authenticated` and `:api_write` pipelines. Read access for GET, write access for PUT/DELETE.

## Risks / Trade-offs

- [Denormalized retention columns can drift from framework definitions] -> Recomputation is triggered on framework changes and can be forced via admin tooling. `retention_computed_at` makes staleness visible.
- [GDPR purpose tracking adds schema complexity for a single framework] -> Purpose tracking is optional (only relevant when GDPR is active). The `retention_purposes` table is small and isolated.
- [Override validation only enforces the minimum floor, not the maximum ceiling] -> Over-retention is a business decision with lower compliance risk than under-retention. Warnings are surfaced but not blocking.
- [Multi-framework conflict resolution requires human judgment] -> Conflicts are surfaced as warnings with framework names and specific day counts. The system does not guess -- it flags and waits.
- [Partition aging jobs become per-account instead of global] -> Existing `audit-log-lifecycle` jobs already iterate accounts for partitioning. Adding a retention lookup per account is minimal overhead.

## Migration Plan

1. Add retention columns to `accounts` table (`retention_effective_days`, `retention_override_days`, `retention_computed_at`, `retention_conflicts`).
2. Add `retention_policy/0` callback to each framework module.
3. Implement retention computation module (`GA.Compliance.Retention`) with effective policy calculation and override validation.
4. Create `retention_purposes` table for GDPR purpose tracking.
5. Update `audit-log-lifecycle` partition aging to read per-account retention instead of global constant.
6. Add retention compliance API endpoints with OpenApiSpex schemas (`RetentionPolicyResponse`, `RetentionPolicyUpdateRequest`) and controller annotations.

## Open Questions

- Should framework retention values be configurable at the deployment level (environment variables) in addition to being defined in code? This would allow operators to adjust framework minimums without code changes, but adds configuration surface area.
- What is the archival behavior when a GDPR purpose expires but other framework minimums haven't been met? Current design says the entry stays until all framework minimums are satisfied -- is that sufficient for GDPR compliance officers?
