## ADDED Requirements

### Requirement: Account compliance frameworks table

A new `account_compliance_frameworks` table MUST exist with the following columns:
- `id` (UUID primary key)
- `account_id` (UUID, references `accounts`, NOT NULL)
- `framework_id` (string, NOT NULL) -- e.g., `"hipaa"`, `"soc2"`, `"pci_dss"`, `"gdpr"`, `"iso27001"`
- `activated_at` (utc_datetime_usec, NOT NULL, defaults to current time)
- `config_overrides` (map/JSONB, default `%{}`)
- `inserted_at`, `updated_at` (timestamps)

A unique index MUST exist on `(account_id, framework_id)` to prevent duplicate framework activations.

#### Scenario: Table structure
- **WHEN** the migration runs
- **THEN** the `account_compliance_frameworks` table exists with all required columns and the unique index

#### Scenario: Foreign key constraint
- **WHEN** a row is inserted referencing a non-existent `account_id`
- **THEN** the insert fails with a foreign key violation

### Requirement: Activate framework for account

`GA.Compliance.activate_framework(account_id, framework_id, opts \\ [])` MUST create an `AccountComplianceFramework` record linking the account to the framework. It MUST validate that the `framework_id` exists in the registry. It MUST return `{:ok, association}` on success or `{:error, changeset}` on failure.

#### Scenario: Activate a known framework
- **WHEN** `activate_framework(account_id, "hipaa")` is called for an account with no active frameworks
- **THEN** a record is created with `framework_id: "hipaa"`, `activated_at` set to the current time, and `config_overrides: %{}`

#### Scenario: Activate with config overrides
- **WHEN** `activate_framework(account_id, "hipaa", config_overrides: %{"retention_days" => 3650})` is called
- **THEN** a record is created with `config_overrides: %{"retention_days" => 3650}`

#### Scenario: Activate unknown framework
- **WHEN** `activate_framework(account_id, "unknown_framework")` is called
- **THEN** it returns `{:error, changeset}` with an error on `:framework_id` indicating the framework is not recognized

#### Scenario: Duplicate activation
- **WHEN** `activate_framework(account_id, "hipaa")` is called but the account already has HIPAA activated
- **THEN** it returns `{:error, changeset}` with a uniqueness error (not a crash)

#### Scenario: Multiple frameworks
- **WHEN** `activate_framework(account_id, "hipaa")` and then `activate_framework(account_id, "soc2")` are called
- **THEN** both records exist and the account has two active frameworks

### Requirement: Deactivate framework for account

`GA.Compliance.deactivate_framework(account_id, framework_id)` MUST delete the `AccountComplianceFramework` record for the given account and framework. It MUST return `{:ok, association}` if the record existed or `{:error, :not_found}` if not.

#### Scenario: Deactivate active framework
- **WHEN** `deactivate_framework(account_id, "hipaa")` is called and the account has HIPAA activated
- **THEN** the record is deleted and `{:ok, association}` is returned

#### Scenario: Deactivate inactive framework
- **WHEN** `deactivate_framework(account_id, "hipaa")` is called but the account does not have HIPAA activated
- **THEN** it returns `{:error, :not_found}`

### Requirement: List active frameworks for account

`GA.Compliance.list_active_frameworks(account_id)` MUST return a list of `AccountComplianceFramework` records for the account, ordered by `activated_at ASC`.

#### Scenario: Account with frameworks
- **WHEN** `list_active_frameworks(account_id)` is called for an account with HIPAA and SOC 2 active
- **THEN** it returns a list of two records with `framework_id` values `"hipaa"` and `"soc2"`

#### Scenario: Account with no frameworks
- **WHEN** `list_active_frameworks(account_id)` is called for an account with no active frameworks
- **THEN** it returns `[]`

### Requirement: Get active framework IDs for account

`GA.Compliance.active_framework_ids(account_id)` MUST return a list of framework ID strings for the account's active frameworks. This is the lightweight query used during entry creation validation.

#### Scenario: Framework IDs
- **WHEN** `active_framework_ids(account_id)` is called for an account with HIPAA and GDPR active
- **THEN** it returns `["hipaa", "gdpr"]` (or equivalent order)

#### Scenario: No frameworks
- **WHEN** `active_framework_ids(account_id)` is called for an account with no active frameworks
- **THEN** it returns `[]`

### Requirement: Config override validation

The `config_overrides` field MUST only accept whitelisted keys: `"retention_days"` (integer), `"verification_cadence_hours"` (integer), and `"additional_required_fields"` (list of strings). Unknown keys MUST be rejected during changeset validation.

#### Scenario: Valid overrides
- **WHEN** an association is created with `config_overrides: %{"retention_days" => 3650}`
- **THEN** the record is created successfully

#### Scenario: Invalid override key
- **WHEN** an association is created with `config_overrides: %{"arbitrary_key" => "value"}`
- **THEN** it returns `{:error, changeset}` with an error on `:config_overrides`

#### Scenario: Invalid override value type
- **WHEN** an association is created with `config_overrides: %{"retention_days" => "not_a_number"}`
- **THEN** it returns `{:error, changeset}` with a type error on `:config_overrides`

#### Scenario: Additional required fields override
- **WHEN** an association is created with `config_overrides: %{"additional_required_fields" => ["custom_field_1"]}`
- **THEN** the record is created and the additional fields are included when computing the effective required fields for the account

### Requirement: Effective framework configuration

`GA.Compliance.effective_config(account_id, framework_id)` MUST merge the framework module's defaults with the account's `config_overrides` for that framework. Account overrides take precedence over framework defaults.

#### Scenario: No overrides
- **WHEN** `effective_config(account_id, "hipaa")` is called and the account has no config overrides
- **THEN** it returns the HIPAA framework defaults: `%{retention_days: 2555, verification_cadence_hours: 24, required_fields: [...]}`

#### Scenario: With retention override
- **WHEN** `effective_config(account_id, "hipaa")` is called and the account has `config_overrides: %{"retention_days" => 3650}`
- **THEN** it returns HIPAA defaults with `retention_days: 3650` overridden

#### Scenario: With additional required fields
- **WHEN** `effective_config(account_id, "hipaa")` is called and the account has `config_overrides: %{"additional_required_fields" => ["department"]}`
- **THEN** the returned `required_fields` includes both the HIPAA defaults and `"department"`

#### Scenario: Framework not active for account
- **WHEN** `effective_config(account_id, "hipaa")` is called but the account does not have HIPAA activated
- **THEN** it returns `{:error, :not_active}`

### Requirement: Frameworks column on audit_logs

The `audit_logs` table MUST have a `frameworks` column of type `{:array, :string}` with a default of `[]`. This column records which framework IDs were active for the account at the time the entry was created.

#### Scenario: Migration adds column
- **WHEN** the migration runs
- **THEN** the `frameworks` column exists on `audit_logs` with a default of `[]`

#### Scenario: Default value on new entries
- **WHEN** an audit log entry is inserted without specifying `frameworks`
- **THEN** the entry has `frameworks: []` (the default)
