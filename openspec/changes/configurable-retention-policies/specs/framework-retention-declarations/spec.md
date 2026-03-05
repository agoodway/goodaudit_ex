## ADDED Requirements

### Requirement: Framework retention callback

Each compliance framework module MUST implement a `retention_policy/0` callback that returns a map describing the framework's retention requirements. The map MUST contain `minimum_days` (integer), `maximum_days` (integer or nil), `recommendation_days` (integer), and `description` (string).

#### Scenario: HIPAA retention declaration
- **WHEN** the HIPAA framework module's `retention_policy/0` is called
- **THEN** it returns `%{minimum_days: 2190, maximum_days: nil, recommendation_days: 2190, description: "HIPAA requires retention of audit records for a minimum of 6 years (2190 days)"}`

#### Scenario: SOC 2 retention declaration
- **WHEN** the SOC 2 framework module's `retention_policy/0` is called
- **THEN** it returns `%{minimum_days: 365, maximum_days: nil, recommendation_days: 365, description: "SOC 2 requires retention of audit logs for a minimum of 1 year (365 days)"}`

#### Scenario: PCI-DSS retention declaration
- **WHEN** the PCI-DSS framework module's `retention_policy/0` is called
- **THEN** it returns `%{minimum_days: 365, maximum_days: nil, recommendation_days: 1095, description: "PCI-DSS requires 1 year minimum retention; 3 years (1095 days) recommended for certain controls"}`

#### Scenario: GDPR retention declaration
- **WHEN** the GDPR framework module's `retention_policy/0` is called
- **THEN** it returns `%{minimum_days: 0, maximum_days: nil, recommendation_days: 365, description: "GDPR requires retention only as long as the processing purpose exists; data minimization principle applies"}`

#### Scenario: ISO 27001 retention declaration
- **WHEN** the ISO 27001 framework module's `retention_policy/0` is called
- **THEN** it returns `%{minimum_days: 1095, maximum_days: nil, recommendation_days: 1095, description: "ISO 27001 requires retention of information security event logs for a minimum of 3 years (1095 days)"}`

### Requirement: Retention policy structure validation

The retention policy map returned by `retention_policy/0` MUST be validated at compile time or load time. `minimum_days` MUST be a non-negative integer. `maximum_days` MUST be a positive integer or nil. `recommendation_days` MUST be a positive integer. If `maximum_days` is set, it MUST be >= `minimum_days`.

#### Scenario: Invalid minimum days
- **WHEN** a framework module returns `%{minimum_days: -1, maximum_days: nil, recommendation_days: 365, description: "..."}`
- **THEN** the system raises a validation error at load time indicating `minimum_days` must be non-negative

#### Scenario: Maximum below minimum
- **WHEN** a framework module returns `%{minimum_days: 365, maximum_days: 30, recommendation_days: 365, description: "..."}`
- **THEN** the system raises a validation error at load time indicating `maximum_days` must be >= `minimum_days`

### Requirement: Framework retention enumeration

`GA.Compliance.Retention.framework_policies(account_id)` MUST return a list of `{framework_name, retention_policy_map}` tuples for all frameworks active on the given account. If no frameworks are active, it MUST return an empty list.

#### Scenario: Account with multiple frameworks
- **WHEN** `framework_policies(account_id)` is called for an account with HIPAA and SOC 2 active
- **THEN** it returns `[{"hipaa", %{minimum_days: 2190, ...}}, {"soc2", %{minimum_days: 365, ...}}]`

#### Scenario: Account with no frameworks
- **WHEN** `framework_policies(account_id)` is called for an account with no active frameworks
- **THEN** it returns `[]`
