## ADDED Requirements

### Requirement: Effective retention computation

`GA.Compliance.Retention.compute_effective(account_id)` MUST compute the effective retention policy from all active frameworks on the account. The result MUST be a map containing `effective_minimum` (max of all framework minimums), `effective_maximum` (min of all non-nil framework maximums, or nil), `effective_recommendation` (max of all framework recommendations), `contributing_frameworks` (list of framework names), and `conflicts` (list of human-readable conflict description strings).

#### Scenario: Single framework (HIPAA only)
- **WHEN** `compute_effective(account_id)` is called for an account with only HIPAA active
- **THEN** it returns `%{effective_minimum: 2190, effective_maximum: nil, effective_recommendation: 2190, contributing_frameworks: ["hipaa"], conflicts: []}`

#### Scenario: Multiple frameworks (HIPAA + GDPR)
- **WHEN** `compute_effective(account_id)` is called for an account with HIPAA and GDPR active
- **THEN** `effective_minimum` is 2190 (max of HIPAA's 2190, GDPR's 0), `effective_recommendation` is 2190, and `contributing_frameworks` contains both `"hipaa"` and `"gdpr"`

#### Scenario: Multiple frameworks (SOC 2 + ISO 27001 + PCI-DSS)
- **WHEN** `compute_effective(account_id)` is called for an account with SOC 2, ISO 27001, and PCI-DSS active
- **THEN** `effective_minimum` is 1095 (max of 365, 1095, 365), `effective_recommendation` is 1095 (max of 365, 1095, 1095), and `conflicts` is empty

#### Scenario: No active frameworks
- **WHEN** `compute_effective(account_id)` is called for an account with no frameworks active
- **THEN** it returns `%{effective_minimum: 0, effective_maximum: nil, effective_recommendation: 365, contributing_frameworks: [], conflicts: []}` using system defaults

#### Scenario: Conflict between minimum and maximum
- **WHEN** a framework combination produces `effective_minimum` of 2190 and `effective_maximum` of 365
- **THEN** `conflicts` contains a human-readable string identifying the conflicting frameworks and their values (e.g., `"Minimum retention of 2190 days (required by hipaa) exceeds maximum retention of 365 days (required by framework_x)"`)

### Requirement: Account retention schema

The `accounts` table MUST include `retention_effective_days` (integer), `retention_override_days` (integer, nullable), `retention_computed_at` (utc_datetime), and `retention_conflicts` (array of strings). These columns MUST be populated by recomputation and readable by partition aging jobs.

#### Scenario: Retention columns after recomputation
- **WHEN** recomputation runs for an account with HIPAA and SOC 2 active
- **THEN** `retention_effective_days` is 2190, `retention_override_days` is nil, `retention_computed_at` is the current UTC time, and `retention_conflicts` is `[]`

### Requirement: Retention override validation

`GA.Compliance.Retention.set_retention_override(account_id, days)` MUST validate the override against the effective minimum. If `days >= effective_minimum`, the override MUST be stored in `retention_override_days`. If `days < effective_minimum`, the function MUST return an error with a message naming the frameworks that require the longer period. If `days > effective_maximum` (when `effective_maximum` is non-nil), the override MUST be accepted with a warning (over-retention is less risky than under-retention).

#### Scenario: Valid override above minimum
- **WHEN** `set_retention_override(account_id, 2555)` is called for an account with `effective_minimum` of 2190
- **THEN** `retention_override_days` is set to 2555 and `{:ok, account}` is returned

#### Scenario: Override below minimum rejected
- **WHEN** `set_retention_override(account_id, 180)` is called for an account with `effective_minimum` of 2190 (HIPAA)
- **THEN** the function returns `{:error, "Retention of 180 days is below the minimum of 2190 days required by hipaa"}`

#### Scenario: Override exactly at minimum
- **WHEN** `set_retention_override(account_id, 2190)` is called for an account with `effective_minimum` of 2190
- **THEN** the override is accepted and `retention_override_days` is set to 2190

#### Scenario: Override above maximum (warning, not rejection)
- **WHEN** `set_retention_override(account_id, 3650)` is called for an account with `effective_maximum` of 2555
- **THEN** the override is accepted, `retention_override_days` is set to 3650, and `{:ok, account, warning: "Override of 3650 days exceeds maximum recommendation of 2555 days"}` is returned

### Requirement: Clear retention override

`GA.Compliance.Retention.clear_retention_override(account_id)` MUST set `retention_override_days` to nil and trigger recomputation of `retention_effective_days` from active frameworks.

#### Scenario: Override cleared
- **WHEN** `clear_retention_override(account_id)` is called for an account with `retention_override_days` of 3650
- **THEN** `retention_override_days` is set to nil, `retention_effective_days` is recomputed from active frameworks, and `{:ok, account}` is returned

### Requirement: Recomputation triggers

Recomputation of `retention_effective_days` MUST occur when a framework is activated on the account, when a framework is deactivated on the account, when a framework module's retention policy changes, or when an override is set or cleared. Recomputation MUST update `retention_effective_days`, `retention_conflicts`, and `retention_computed_at`.

#### Scenario: Framework activation triggers recomputation
- **WHEN** HIPAA is activated on an account that previously had only SOC 2
- **THEN** `retention_effective_days` is recomputed from 365 to 2190 and `retention_computed_at` is updated

#### Scenario: Framework deactivation triggers recomputation
- **WHEN** HIPAA is deactivated on an account that also has SOC 2 active
- **THEN** `retention_effective_days` is recomputed from 2190 to 365 and `retention_computed_at` is updated

#### Scenario: Override set triggers recomputation
- **WHEN** an override of 2555 is set on an account with `effective_minimum` of 2190
- **THEN** the account's effective retention for partition aging becomes 2555 (override takes precedence) and `retention_computed_at` is updated

### Requirement: Integration with audit-log-lifecycle partition aging

The `audit-log-lifecycle` partition aging jobs MUST read `retention_override_days` (when set) or `retention_effective_days` from each account record to determine the retention window. Each account's partitions MUST age independently based on its own effective retention.

#### Scenario: Per-account retention in partition aging
- **WHEN** the partition aging job runs for an account with `retention_effective_days` of 2190 and no override
- **THEN** partitions older than 2190 days are candidates for archival

#### Scenario: Override takes precedence in partition aging
- **WHEN** the partition aging job runs for an account with `retention_effective_days` of 2190 and `retention_override_days` of 2555
- **THEN** partitions older than 2555 days are candidates for archival

#### Scenario: Account with no retention columns populated
- **WHEN** the partition aging job runs for an account with `retention_effective_days` of 0 and no override
- **THEN** the account uses the system default retention (framework recomputation should be triggered for this account)

### Requirement: GDPR retention purpose tracking

For GDPR-active accounts, audit entries MAY include `extensions.gdpr.retention_purpose` (string). A `retention_purposes` table MUST track active purposes per account with `account_id`, `purpose` (string), `description` (string), and `expires_at` (utc_datetime, nullable). When a purpose expires, entries tagged with only that purpose become candidates for archival, subject to the union with other active framework minimums.

#### Scenario: Purpose-tagged entry within active purpose
- **WHEN** an audit entry has `extensions.gdpr.retention_purpose: "fraud_investigation"` and that purpose is active (not expired)
- **THEN** the entry is retained regardless of its age

#### Scenario: Purpose expired but other framework minimum applies
- **WHEN** a purpose expires on an account that also has HIPAA active (minimum 2190 days) and the entry is 400 days old
- **THEN** the entry is still retained because it is within the HIPAA minimum period

#### Scenario: Purpose expired and entry exceeds all framework minimums
- **WHEN** a purpose expires on an account, the entry is tagged with only that purpose, and the entry's age exceeds all active framework minimums
- **THEN** the entry becomes a candidate for archival through the standard `audit-log-lifecycle` archive workflow
