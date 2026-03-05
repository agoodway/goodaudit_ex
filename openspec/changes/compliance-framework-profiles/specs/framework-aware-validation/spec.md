## ADDED Requirements

### Requirement: Framework-aware field validation on entry creation

`GA.Audit.create_log_entry(account_id, attrs)` MUST, before chain insertion, look up the account's active framework IDs via `GA.Compliance.active_framework_ids(account_id)`, compute the union of required fields via `GA.Compliance.required_fields_for_frameworks(framework_ids)`, and validate that all required fields are present and non-nil in the attrs. If any required field is missing, the entry MUST be rejected before chain computation.

#### Scenario: All required fields present
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with HIPAA active and all HIPAA required fields are present in attrs
- **THEN** the entry is created successfully with `frameworks: ["hipaa"]` set on the record

#### Scenario: Missing required field for single framework
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with HIPAA active and `phi_accessed` is missing from attrs
- **THEN** it returns `{:error, changeset}` with `phi_accessed: ["required by HIPAA"]`

#### Scenario: Missing required field for multiple frameworks
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with HIPAA and SOC 2 active and `source_ip` is missing from attrs
- **THEN** it returns `{:error, changeset}` with `source_ip: ["required by HIPAA", "required by SOC 2"]`

#### Scenario: Multiple missing fields
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with PCI-DSS active and both `source_ip` and `session_id` are missing
- **THEN** it returns `{:error, changeset}` with errors on both fields: `source_ip: ["required by PCI-DSS"]` and `session_id: ["required by PCI-DSS"]`

#### Scenario: No active frameworks
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with no active frameworks
- **THEN** no framework validation is performed and `frameworks: []` is set on the record

### Requirement: Framework-attributed error messages

When framework validation fails, the error response MUST attribute each missing field to the specific framework(s) that require it. The error format MUST be `{"errors": {"field_name": ["required by Framework Name", ...]}}` where Framework Name is the value returned by the framework module's `name/0` callback.

#### Scenario: Error attribution format
- **WHEN** an entry is rejected due to HIPAA requiring `phi_accessed`
- **THEN** the error includes `"phi_accessed": ["required by HIPAA"]`

#### Scenario: Multi-framework error attribution
- **WHEN** an entry is rejected due to both HIPAA and SOC 2 requiring `source_ip`
- **THEN** the error includes `"source_ip": ["required by HIPAA", "required by SOC 2"]`

#### Scenario: Mixed fields from different frameworks
- **WHEN** an account has HIPAA and GDPR active, and `phi_accessed` (HIPAA-only) and `outcome` (GDPR-required, HIPAA-not-required) are both missing
- **THEN** the error includes `"phi_accessed": ["required by HIPAA"]` and `"outcome": ["required by GDPR"]`

### Requirement: Additional required fields from config overrides

When computing the effective required fields for an account, `create_log_entry/2` MUST include any `additional_required_fields` from the account's framework config overrides. These additional fields MUST be attributed to the framework whose override added them.

#### Scenario: Override adds required field
- **WHEN** an account has HIPAA active with `config_overrides: %{"additional_required_fields" => ["department"]}` and `department` is missing from attrs
- **THEN** it returns `{:error, changeset}` with `department: ["required by HIPAA"]`

#### Scenario: Override field present
- **WHEN** an account has HIPAA active with `config_overrides: %{"additional_required_fields" => ["department"]}` and `department` is present in attrs
- **THEN** the entry is created successfully

### Requirement: Frameworks recorded on entry

When an audit log entry is created, the `frameworks` field MUST be set to the list of active framework IDs for the account at creation time. This list MUST be sorted alphabetically for deterministic canonical payload computation.

#### Scenario: Single framework recorded
- **WHEN** an entry is created for an account with only HIPAA active
- **THEN** the entry's `frameworks` field is `["hipaa"]`

#### Scenario: Multiple frameworks recorded
- **WHEN** an entry is created for an account with HIPAA and SOC 2 active
- **THEN** the entry's `frameworks` field is `["hipaa", "soc2"]` (sorted alphabetically)

#### Scenario: No frameworks recorded
- **WHEN** an entry is created for an account with no active frameworks
- **THEN** the entry's `frameworks` field is `[]`

#### Scenario: Framework change after entry creation
- **WHEN** an entry was created with `frameworks: ["hipaa"]` and the account later activates SOC 2
- **THEN** the original entry's `frameworks` field remains `["hipaa"]` (immutable historical record)

### Requirement: Canonical payload includes frameworks

The `GA.Audit.Chain` canonical payload computation MUST include the `frameworks` field. The `frameworks` field MUST be serialized as a sorted, comma-joined string in the canonical payload. For entries with `frameworks: []`, the frameworks segment MUST be an empty string in the payload position.

#### Scenario: Payload with frameworks
- **WHEN** `canonical_payload(attrs, previous_checksum)` is called with `frameworks: ["hipaa", "soc2"]`
- **THEN** the payload includes a `"hipaa,soc2"` segment in the canonical string

#### Scenario: Payload without frameworks
- **WHEN** `canonical_payload(attrs, previous_checksum)` is called with `frameworks: []`
- **THEN** the frameworks segment in the canonical string is empty (e.g., `"||"` with empty value between delimiters)

#### Scenario: Chain integrity with frameworks
- **WHEN** an entry is created with `frameworks: ["hipaa"]` and the checksum is computed
- **THEN** verifying the checksum with the same entry data (including `frameworks: ["hipaa"]`) succeeds
- **AND** verifying the checksum with tampered frameworks (e.g., `["hipaa", "soc2"]`) fails

### Requirement: Validation happens before chain computation

Framework field validation MUST occur before the advisory lock is acquired and before checksum computation. This ensures that invalid entries are rejected cheaply without holding the per-account lock.

#### Scenario: Validation before lock
- **WHEN** `create_log_entry(account_id, attrs)` is called with missing required fields
- **THEN** the error is returned without acquiring the advisory lock or computing a checksum

#### Scenario: Valid entry proceeds to chain
- **WHEN** `create_log_entry(account_id, attrs)` is called with all required fields present
- **THEN** framework validation passes, the advisory lock is acquired, and chain computation proceeds normally

### Requirement: Nil vs absent field handling

Framework validation MUST treat both absent fields (key not in attrs) and explicitly nil fields as missing. A field set to an empty string `""` MUST be considered present (some frameworks may accept empty strings for optional-but-tracked fields).

#### Scenario: Absent field
- **WHEN** attrs does not contain the key `:phi_accessed` at all
- **THEN** validation reports `phi_accessed` as missing

#### Scenario: Nil field
- **WHEN** attrs contains `phi_accessed: nil`
- **THEN** validation reports `phi_accessed` as missing

#### Scenario: Empty string field
- **WHEN** attrs contains `source_ip: ""`
- **THEN** validation considers `source_ip` as present (not missing)

#### Scenario: Boolean false field
- **WHEN** attrs contains `phi_accessed: false`
- **THEN** validation considers `phi_accessed` as present (false is a valid value)
