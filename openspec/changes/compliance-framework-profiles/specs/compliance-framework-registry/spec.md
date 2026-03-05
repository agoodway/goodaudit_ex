## ADDED Requirements

### Requirement: Framework behaviour definition

`GA.Compliance.Framework` MUST define a behaviour with the following callbacks:

- `name/0` -- returns the human-readable framework name (e.g., `"HIPAA"`)
- `required_fields/0` -- returns a list of atom field names that MUST be present on every audit log entry for accounts under this framework
- `recommended_fields/0` -- returns a list of atom field names that SHOULD be present but are not enforced
- `default_retention_days/0` -- returns an integer specifying the default retention period in days
- `verification_cadence_hours/0` -- returns an integer specifying how often chain verification should run
- `extension_schema/0` -- returns a map describing additional metadata fields the framework expects (informational, not enforced in this change)
- `event_taxonomy/0` -- returns a list of event action strings meaningful to this framework's audit requirements

#### Scenario: Behaviour compilation
- **WHEN** a module uses `@behaviour GA.Compliance.Framework` without implementing all callbacks
- **THEN** the compiler emits warnings for each missing callback

#### Scenario: Behaviour contract
- **WHEN** a module implements all seven callbacks
- **THEN** the module compiles without warnings and is usable as a framework definition

### Requirement: Built-in HIPAA framework

`GA.Compliance.Frameworks.HIPAA` MUST implement the `GA.Compliance.Framework` behaviour with:
- `required_fields/0` returning `[:user_id, :action, :resource_type, :resource_id, :timestamp, :phi_accessed, :source_ip, :user_role]`
- `default_retention_days/0` returning `2555` (7 years)
- `verification_cadence_hours/0` returning `24`

#### Scenario: HIPAA required fields
- **WHEN** `GA.Compliance.Frameworks.HIPAA.required_fields/0` is called
- **THEN** it returns a list including `:phi_accessed`, `:source_ip`, and `:user_role` among the required fields

#### Scenario: HIPAA retention
- **WHEN** `GA.Compliance.Frameworks.HIPAA.default_retention_days/0` is called
- **THEN** it returns `2555`

### Requirement: Built-in SOC 2 Type II framework

`GA.Compliance.Frameworks.SOC2` MUST implement the `GA.Compliance.Framework` behaviour with:
- `required_fields/0` returning `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip, :session_id]`
- `default_retention_days/0` returning `2555` (7 years)
- `verification_cadence_hours/0` returning `24`

#### Scenario: SOC 2 required fields
- **WHEN** `GA.Compliance.Frameworks.SOC2.required_fields/0` is called
- **THEN** it returns a list including `:outcome`, `:session_id`, and `:source_ip`

### Requirement: Built-in PCI-DSS v4 framework

`GA.Compliance.Frameworks.PCIDSS` MUST implement the `GA.Compliance.Framework` behaviour with:
- `required_fields/0` returning `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip, :user_role, :session_id]`
- `default_retention_days/0` returning `365` (1 year minimum, typically longer)
- `verification_cadence_hours/0` returning `12`

#### Scenario: PCI-DSS required fields
- **WHEN** `GA.Compliance.Frameworks.PCIDSS.required_fields/0` is called
- **THEN** it returns a list including `:user_role`, `:outcome`, `:source_ip`, and `:session_id`

#### Scenario: PCI-DSS verification cadence
- **WHEN** `GA.Compliance.Frameworks.PCIDSS.verification_cadence_hours/0` is called
- **THEN** it returns `12` (more frequent than HIPAA or SOC 2 due to PCI-DSS Requirement 10.4)

### Requirement: Built-in GDPR framework

`GA.Compliance.Frameworks.GDPR` MUST implement the `GA.Compliance.Framework` behaviour with:
- `required_fields/0` returning `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome]`
- `default_retention_days/0` returning `1825` (5 years)
- `verification_cadence_hours/0` returning `48`

#### Scenario: GDPR required fields
- **WHEN** `GA.Compliance.Frameworks.GDPR.required_fields/0` is called
- **THEN** it returns a list that does NOT include `:phi_accessed` (GDPR does not use HIPAA's PHI concept)

#### Scenario: GDPR retention
- **WHEN** `GA.Compliance.Frameworks.GDPR.default_retention_days/0` is called
- **THEN** it returns `1825`

### Requirement: Built-in ISO 27001 framework

`GA.Compliance.Frameworks.ISO27001` MUST implement the `GA.Compliance.Framework` behaviour with:
- `required_fields/0` returning `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip]`
- `default_retention_days/0` returning `1095` (3 years)
- `verification_cadence_hours/0` returning `24`

#### Scenario: ISO 27001 required fields
- **WHEN** `GA.Compliance.Frameworks.ISO27001.required_fields/0` is called
- **THEN** it returns a list including `:outcome` and `:source_ip` but not `:phi_accessed`

### Requirement: Framework registry

`GA.Compliance` MUST expose a `registry/0` function returning a map of `framework_id` (string) to framework module. The registry MUST include entries for `"hipaa"`, `"soc2"`, `"pci_dss"`, `"gdpr"`, and `"iso27001"`.

#### Scenario: Registry lookup
- **WHEN** `GA.Compliance.registry()` is called
- **THEN** it returns a map where `"hipaa"` maps to `GA.Compliance.Frameworks.HIPAA`

#### Scenario: Unknown framework ID
- **WHEN** `GA.Compliance.get_framework("unknown")` is called
- **THEN** it returns `{:error, :unknown_framework}`

#### Scenario: Valid framework ID
- **WHEN** `GA.Compliance.get_framework("soc2")` is called
- **THEN** it returns `{:ok, GA.Compliance.Frameworks.SOC2}`

### Requirement: Framework required fields union

`GA.Compliance` MUST expose `required_fields_for_frameworks(framework_ids)` that accepts a list of framework ID strings and returns the deduplicated union of all `required_fields/0` from the corresponding framework modules. Unknown framework IDs in the list MUST be silently skipped (they may represent deactivated custom frameworks).

#### Scenario: Single framework
- **WHEN** `required_fields_for_frameworks(["hipaa"])` is called
- **THEN** it returns the HIPAA required fields list

#### Scenario: Multi-framework union
- **WHEN** `required_fields_for_frameworks(["hipaa", "soc2"])` is called
- **THEN** it returns the union of HIPAA and SOC 2 required fields (deduplicated), which includes `:phi_accessed` from HIPAA and `:session_id` from SOC 2

#### Scenario: Empty list
- **WHEN** `required_fields_for_frameworks([])` is called
- **THEN** it returns `[]`

#### Scenario: Unknown framework in list
- **WHEN** `required_fields_for_frameworks(["hipaa", "unknown_framework"])` is called
- **THEN** it returns only the HIPAA required fields (unknown framework is skipped)
