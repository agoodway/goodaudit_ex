## Why

The existing `audit-log-lifecycle` proposal assumes a single retention policy. Different compliance frameworks mandate different retention periods: HIPAA requires 6 years, PCI-DSS requires 1 year (3 years for some controls), SOC 2 recommends 1 year minimum, GDPR requires retention only as long as the processing purpose exists (variable), and ISO 27001 typically requires 3 years. Accounts operating under multiple frameworks must satisfy the longest applicable period.

Without per-framework retention logic, accounts either over-retain (wasting storage and increasing GDPR exposure) or under-retain (violating compliance). Retention should be automatically computed from active frameworks with account-level overrides.

## What Changes

1. **Framework retention declarations** — Each compliance framework module (from compliance-framework-profiles) declares its minimum retention period, maximum retention recommendation (if any, relevant for GDPR's data minimization principle), and whether retention is fixed or purpose-dependent.

2. **Computed effective retention** — When an account has multiple frameworks, the system computes the effective retention as the union of all requirements: `max(minimums)` for the floor, `min(maximums)` for the ceiling (if any framework imposes a ceiling). Conflicts (e.g., HIPAA's 6-year minimum vs GDPR's minimize-retention principle) are surfaced as warnings in the account's compliance dashboard, not silently resolved.

3. **Account retention overrides** — Accounts can set a custom retention period that must be >= the computed minimum. Attempts to set retention below the minimum are rejected with an error explaining which framework requires the longer period.

4. **Retention policy enforcement** — Integrates with the `audit-log-lifecycle` partitioning strategy. Partitions older than the effective retention window are candidates for archival. Archival is a two-phase process: export to immutable archive storage, then drop partition. The archive export includes the chain verification manifest for the archived range.

5. **Retention compliance reporting** — API endpoint returns each account's effective retention policy, the contributing framework requirements, any overrides, and the current data age range. Useful for compliance officers verifying retention posture.

6. **GDPR retention purpose tracking** — For GDPR-active accounts, audit entries can be tagged with a `retention_purpose` in extensions. When the purpose expires (e.g., consent withdrawn), those entries become eligible for deletion after the mandatory archival period, subject to the union with other active frameworks.

## Capabilities

### New Capabilities
- `framework-retention-declarations`: Per-framework minimum/maximum retention periods with conflict detection
- `computed-effective-retention`: Automatic retention computation from active frameworks with override support
- `retention-compliance-reporting`: API for retention posture visibility

### Modified Capabilities
- `retention-archive-policy`: Archive cadence driven by per-account effective retention instead of global default
- `account-framework-association`: Framework activation triggers retention recomputation

## Impact

- **New file**: `lib/app/compliance/retention.ex` — retention computation, validation, and conflict detection
- **New migration**: `retention_policy` fields on accounts (effective_retention_days, retention_override_days, retention_computed_at)
- **Modified file**: `lib/app/compliance/frameworks/*.ex` — each framework declares retention requirements
- **New API endpoints**: retention policy view and override for accounts
- **Modified file**: lifecycle/partition management jobs — use per-account retention instead of global
- **New tests**: multi-framework retention computation, override validation, GDPR purpose expiry, conflict warnings
