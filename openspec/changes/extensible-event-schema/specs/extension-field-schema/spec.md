## ADDED Requirements

### Requirement: Extensions JSONB column

The `audit_logs` table MUST have an `extensions` column of type JSONB with a default value of `'{}'::jsonb`. The column MUST be NOT NULL. The column MUST store a map where each top-level key is a framework identifier (e.g., `hipaa`, `soc2`, `pci`, `gdpr`) and each value is a map of that framework's extension fields.

#### Scenario: Column exists with correct type and default
- **WHEN** the migration runs
- **THEN** the `extensions` column exists on `audit_logs` as JSONB, NOT NULL, defaulting to `'{}'::jsonb`

#### Scenario: Empty extensions on insert
- **WHEN** an audit log entry is inserted without specifying `extensions`
- **THEN** the stored value is `{}` (empty JSON object)

#### Scenario: Namespaced framework extensions
- **WHEN** an audit log entry is inserted with `extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}, "soc2" => %{"change_ticket_id" => "JIRA-123"}}`
- **THEN** the stored JSONB preserves the namespaced structure with each framework's fields nested under its key

### Requirement: Actor ID column

The `audit_logs` table MUST have an `actor_id` column of type `string` (varchar), NOT NULL. There is no `user_id` column -- `actor_id` is the canonical field name from the start.

#### Scenario: Actor ID column exists
- **WHEN** the migration runs
- **THEN** the `actor_id` column exists on `audit_logs` as varchar, NOT NULL

### Requirement: Extension field validation

`GA.Compliance.ExtensionSchema.validate(frameworks, extensions)` MUST validate that the `extensions` map contains all required fields for each active framework, that field types match the schema definition, and that no unrecognized framework keys are present. It MUST return `{:ok, extensions}` when valid or `{:error, changeset}` with descriptive errors when invalid.

#### Scenario: Valid HIPAA extensions
- **WHEN** `validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}})` is called
- **THEN** it returns `{:ok, %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}}}`

#### Scenario: Missing required extension field
- **WHEN** `validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => true}})` is called and `user_role` is required by the HIPAA schema
- **THEN** it returns `{:error, changeset}` with an error indicating `user_role` is required under `hipaa`

#### Scenario: Wrong field type
- **WHEN** `validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => "yes"}})` is called and `phi_accessed` must be boolean
- **THEN** it returns `{:error, changeset}` with a type error on `hipaa.phi_accessed`

#### Scenario: Unrecognized framework key
- **WHEN** `validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => true}, "unknown_framework" => %{"field" => "value"}})` is called
- **THEN** it returns `{:error, changeset}` with an error indicating `unknown_framework` is not a recognized framework

#### Scenario: Multiple frameworks validated independently
- **WHEN** `validate(["hipaa", "soc2"], %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}, "soc2" => %{"change_ticket_id" => "JIRA-456"}})` is called
- **THEN** both framework extensions are validated independently and `{:ok, extensions}` is returned

#### Scenario: Empty extensions for account with no frameworks
- **WHEN** `validate([], %{})` is called
- **THEN** it returns `{:ok, %{}}`

#### Scenario: Inactive framework fields accepted but not required
- **WHEN** `validate(["hipaa"], %{"hipaa" => %{"phi_accessed" => false, "user_role" => "viewer"}, "soc2" => %{"change_ticket_id" => "JIRA-789"}})` is called and `soc2` is not in the active frameworks list
- **THEN** it returns `{:error, changeset}` because `soc2` is not an active framework for this account

### Requirement: Ecto schema for extensions and actor_id

The `GA.Audit.Log` Ecto schema MUST include `field(:extensions, :map, default: %{})` and `field(:actor_id, :string)`. The changeset MUST cast `extensions` and `actor_id`. The changeset MUST validate `actor_id` as required.

#### Scenario: Schema includes extensions field
- **WHEN** `%GA.Audit.Log{}` is constructed
- **THEN** it has an `extensions` field defaulting to `%{}`

#### Scenario: Changeset casts extensions
- **WHEN** a changeset is built with `extensions: %{"hipaa" => %{"phi_accessed" => true}}`
- **THEN** the changeset includes the extensions value

#### Scenario: Actor ID required
- **WHEN** a changeset is built without `actor_id`
- **THEN** the changeset has a validation error on `:actor_id`

### Requirement: Entry creation with extension validation

When creating an audit log entry, the context layer MUST call `GA.Compliance.ExtensionSchema.validate/2` with the account's active frameworks and the provided extensions before insertion. If validation fails, the entry MUST NOT be inserted and the error MUST be returned to the caller.

#### Scenario: Valid extensions accepted during creation
- **WHEN** `GA.Audit.create_entry(account, attrs)` is called with valid extensions for the account's active frameworks
- **THEN** the entry is inserted with the extensions stored in the `extensions` column

#### Scenario: Invalid extensions rejected during creation
- **WHEN** `GA.Audit.create_entry(account, attrs)` is called with extensions that fail validation
- **THEN** the entry is not inserted and `{:error, changeset}` is returned with extension validation errors

### Requirement: Canonical payload format

The HMAC canonical payload format MUST be: `"#{account_id}|#{sequence_number}|#{previous_checksum}|#{actor_id}|#{action}|#{resource_type}|#{resource_id}|#{outcome}|#{timestamp}|#{sorted_extensions_json}|#{sorted_metadata_json}"`. The `sorted_extensions_json` MUST serialize the extensions map with keys sorted alphabetically at every nesting level (framework keys sorted, then each framework's field keys sorted) using compact JSON encoding. Empty extensions MUST produce `"{}"`. There is only one canonical payload format -- no legacy format handling is needed.

#### Scenario: Canonical payload with extensions
- **WHEN** `canonical_payload/2` is called for an entry with `extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "nurse"}}`
- **THEN** the payload includes `{"hipaa":{"phi_accessed":true,"user_role":"nurse"}}` in the extensions position with keys sorted

#### Scenario: Extension key ordering independence
- **WHEN** two entries have identical extensions but constructed with different key insertion order
- **THEN** their canonical payloads are identical and produce the same checksum

#### Scenario: Empty extensions in payload
- **WHEN** an entry has `extensions: %{}`
- **THEN** the extensions position in the canonical payload is `"{}"`

#### Scenario: Multiple frameworks sorted by framework key
- **WHEN** an entry has `extensions: %{"soc2" => %{"change_ticket_id" => "X"}, "hipaa" => %{"phi_accessed" => true}}`
- **THEN** the sorted extensions JSON has `hipaa` before `soc2`: `{"hipaa":{"phi_accessed":true},"soc2":{"change_ticket_id":"X"}}`

