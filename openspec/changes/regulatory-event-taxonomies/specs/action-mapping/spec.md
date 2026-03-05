## ADDED Requirements

### Requirement: Action mapping schema

The `account_action_mappings` table MUST have columns: `id` (binary_id, primary key), `account_id` (binary_id, references accounts, not null), `custom_action` (string, not null), `framework` (string, not null), `taxonomy_path` (string, not null, dot-separated like `"access.phi.phi_read"`), `taxonomy_version` (string, not null), `created_at` (utc_datetime_usec, not null). A unique index MUST exist on `[account_id, custom_action, framework]`.

#### Scenario: Schema structure
- **WHEN** the migration runs
- **THEN** the `account_action_mappings` table is created with all specified columns and the unique index

#### Scenario: Duplicate mapping prevention
- **WHEN** a mapping is inserted for `(account_id, "patient_chart_viewed", "hipaa")` and another insert is attempted for the same triple
- **THEN** the second insert fails with a unique constraint violation

### Requirement: Account compliance frameworks join table

The `account_compliance_frameworks` table MUST have columns: `id` (binary_id, primary key), `account_id` (binary_id, references accounts, not null), `framework` (string, not null), `action_validation_mode` (string, not null, default `"flexible"`), `enabled_at` (utc_datetime_usec, not null). A unique index MUST exist on `[account_id, framework]`. Valid values for `action_validation_mode` are `"flexible"` and `"strict"`.

#### Scenario: Default validation mode
- **WHEN** a framework is enabled for an account without specifying validation mode
- **THEN** the `action_validation_mode` is set to `"flexible"`

#### Scenario: Framework uniqueness per account
- **WHEN** HIPAA is already enabled for an account and a second enable for HIPAA is attempted
- **THEN** the insert fails with a unique constraint violation

### Requirement: Create action mapping

`GA.Compliance.ActionMapping.create_mapping(account_id, attrs)` MUST accept `%{custom_action: string, framework: string, taxonomy_path: string}`, validate that the framework exists in the taxonomy registry, validate that the taxonomy_path resolves to a valid action in the framework's taxonomy, record the current `taxonomy_version` from the framework module, and insert the mapping. It MUST return `{:ok, %ActionMapping{}}` on success or `{:error, changeset}` on validation failure.

#### Scenario: Valid mapping creation
- **WHEN** `create_mapping(account_id, %{custom_action: "patient_chart_viewed", framework: "hipaa", taxonomy_path: "access.phi.phi_read"})` is called
- **THEN** the mapping is created with `taxonomy_version: "1.0.0"` and returned as `{:ok, %ActionMapping{}}`

#### Scenario: Invalid framework
- **WHEN** `create_mapping(account_id, %{custom_action: "foo", framework: "unknown", taxonomy_path: "a.b.c"})` is called
- **THEN** it returns `{:error, changeset}` with an error on the `framework` field

#### Scenario: Invalid taxonomy path
- **WHEN** `create_mapping(account_id, %{custom_action: "foo", framework: "hipaa", taxonomy_path: "nonexistent.path.action"})` is called
- **THEN** it returns `{:error, changeset}` with an error on the `taxonomy_path` field

#### Scenario: Duplicate mapping
- **WHEN** a mapping already exists for `(account_id, "patient_chart_viewed", "hipaa")` and `create_mapping` is called with the same triple
- **THEN** it returns `{:error, changeset}` with a unique constraint error

### Requirement: List action mappings

`GA.Compliance.ActionMapping.list_mappings(account_id, opts \\ [])` MUST return all mappings for the account. It MUST accept optional filters: `framework` (string) to filter by framework, and `custom_action` (string) to filter by custom action name.

#### Scenario: All mappings for account
- **WHEN** `list_mappings(account_id)` is called for an account with 5 mappings across 2 frameworks
- **THEN** all 5 mappings are returned

#### Scenario: Framework-filtered mappings
- **WHEN** `list_mappings(account_id, framework: "hipaa")` is called
- **THEN** only mappings for the HIPAA framework are returned

#### Scenario: Action-filtered mappings
- **WHEN** `list_mappings(account_id, custom_action: "patient_chart_viewed")` is called
- **THEN** all mappings for that custom action across all frameworks are returned

### Requirement: Delete action mapping

`GA.Compliance.ActionMapping.delete_mapping(account_id, mapping_id)` MUST delete the mapping if it exists and belongs to the account. It MUST return `{:ok, %ActionMapping{}}` on success or `{:error, :not_found}` if the mapping does not exist or belongs to a different account.

#### Scenario: Successful deletion
- **WHEN** `delete_mapping(account_id, mapping_id)` is called for an existing mapping belonging to the account
- **THEN** the mapping is deleted and `{:ok, %ActionMapping{}}` is returned

#### Scenario: Not found
- **WHEN** `delete_mapping(account_id, nonexistent_id)` is called
- **THEN** `{:error, :not_found}` is returned

#### Scenario: Account isolation
- **WHEN** `delete_mapping(account_a_id, mapping_id)` is called where `mapping_id` belongs to account B
- **THEN** `{:error, :not_found}` is returned

### Requirement: Update action mapping

`GA.Compliance.ActionMapping.update_mapping(account_id, mapping_id, attrs)` MUST update the `taxonomy_path` of an existing mapping. It MUST validate the new path against the framework's taxonomy and update the `taxonomy_version` to the current version. It MUST return `{:ok, %ActionMapping{}}` on success or `{:error, changeset}` on validation failure.

#### Scenario: Valid update
- **WHEN** `update_mapping(account_id, mapping_id, %{taxonomy_path: "access.phi.phi_write"})` is called for a HIPAA mapping
- **THEN** the mapping's `taxonomy_path` and `taxonomy_version` are updated

#### Scenario: Invalid new path
- **WHEN** `update_mapping(account_id, mapping_id, %{taxonomy_path: "nonexistent.path"})` is called
- **THEN** it returns `{:error, changeset}` with an error on the `taxonomy_path` field

### Requirement: Resolve custom actions to taxonomy actions

`GA.Compliance.ActionMapping.resolve_actions(account_id, framework, taxonomy_pattern)` MUST accept a taxonomy pattern (e.g., `"access.*"` or `"access.phi.*"`), resolve it to canonical taxonomy actions via the framework's taxonomy, then find all custom actions mapped to those taxonomy paths for the account, and return both sets: `{:ok, %{taxonomy_actions: [String.t()], mapped_actions: [String.t()]}}`.

#### Scenario: Full resolution
- **WHEN** `resolve_actions(account_id, "hipaa", "access.*")` is called and the account has mapped `"patient_chart_viewed"` to `"access.phi.phi_read"` and `"nurse_login"` to `"access.system.login"`
- **THEN** it returns `{:ok, %{taxonomy_actions: ["phi_read", "phi_write", "phi_delete", "login", "logout", "session_timeout"], mapped_actions: ["patient_chart_viewed", "nurse_login"]}}`

#### Scenario: No mappings exist
- **WHEN** `resolve_actions(account_id, "hipaa", "access.*")` is called and the account has no mappings
- **THEN** it returns `{:ok, %{taxonomy_actions: ["phi_read", "phi_write", "phi_delete", "login", "logout", "session_timeout"], mapped_actions: []}}`

#### Scenario: Unknown framework
- **WHEN** `resolve_actions(account_id, "unknown", "access.*")` is called
- **THEN** it returns `{:error, :unknown_framework}`

### Requirement: Strict mode validation

When `create_log_entry/2` is called for an account that has any framework in `strict` validation mode, the provided `action` MUST either be a canonical taxonomy action for that framework OR have an explicit mapping in `account_action_mappings` for that framework. If the action fails validation for any strict-mode framework, the entry MUST be rejected with `{:error, changeset}` containing an error on the `action` field.

#### Scenario: Valid taxonomy action in strict mode
- **WHEN** an account has HIPAA in strict mode and `create_log_entry(account_id, %{action: "phi_read", ...})` is called
- **THEN** the entry is accepted because `"phi_read"` is a canonical HIPAA taxonomy action

#### Scenario: Valid mapped action in strict mode
- **WHEN** an account has HIPAA in strict mode, a mapping exists from `"patient_chart_viewed"` to `"access.phi.phi_read"`, and `create_log_entry(account_id, %{action: "patient_chart_viewed", ...})` is called
- **THEN** the entry is accepted because the action has an explicit mapping

#### Scenario: Unknown action in strict mode
- **WHEN** an account has HIPAA in strict mode and `create_log_entry(account_id, %{action: "random_action", ...})` is called with no mapping for `"random_action"`
- **THEN** the entry is rejected with `{:error, changeset}` and an error on the `action` field indicating it is not recognized in strict-mode frameworks

#### Scenario: Flexible mode allows any action
- **WHEN** an account has HIPAA in flexible mode and `create_log_entry(account_id, %{action: "random_action", ...})` is called
- **THEN** the entry is accepted without validation against the taxonomy

#### Scenario: Multiple frameworks with mixed modes
- **WHEN** an account has HIPAA in strict mode and SOC 2 in flexible mode, and the action is recognized by HIPAA but not SOC 2
- **THEN** the entry is accepted because only strict-mode frameworks reject unknown actions

### Requirement: Mapping validation dry-run

`GA.Compliance.ActionMapping.validate_actions(account_id, framework)` MUST scan recent audit log entries for the account (last 1000), check each unique `action` value against the framework's taxonomy and existing mappings, and return a report of `%{recognized: [action], unmapped: [action]}`. This allows accounts to audit their action coverage before enabling strict mode.

#### Scenario: Dry-run with full coverage
- **WHEN** `validate_actions(account_id, "hipaa")` is called and all unique actions in recent logs are either taxonomy actions or mapped
- **THEN** it returns `%{recognized: ["phi_read", "login", ...], unmapped: []}`

#### Scenario: Dry-run with gaps
- **WHEN** `validate_actions(account_id, "hipaa")` is called and `"custom_event"` has no mapping
- **THEN** it returns `%{recognized: [...], unmapped: ["custom_event"]}`

### Requirement: Action mapping CRUD API endpoints

The following endpoints MUST be added using existing auth pipelines:

- `GET /api/v1/action-mappings` — List mappings for the account. Accepts optional `framework` query parameter. Requires read access.
- `POST /api/v1/action-mappings` — Create a new mapping. Requires write access. Body: `{"custom_action": "...", "framework": "...", "taxonomy_path": "..."}`.
- `PUT /api/v1/action-mappings/:id` — Update a mapping's taxonomy path. Requires write access. Body: `{"taxonomy_path": "..."}`.
- `DELETE /api/v1/action-mappings/:id` — Delete a mapping. Requires write access.
- `POST /api/v1/action-mappings/validate` — Dry-run validation. Requires read access. Body: `{"framework": "..."}`. Returns recognized and unmapped actions.
#### Scenario: List mappings
- **WHEN** `GET /api/v1/action-mappings` is called with a valid read key
- **THEN** it returns `{"data": [{"id": "...", "custom_action": "...", "framework": "...", "taxonomy_path": "...", "taxonomy_version": "...", "created_at": "..."}]}`

#### Scenario: Create mapping
- **WHEN** `POST /api/v1/action-mappings` is called with valid body and a write key
- **THEN** it returns HTTP 201 with `{"data": {"id": "...", ...}}`

#### Scenario: Create mapping with invalid framework
- **WHEN** `POST /api/v1/action-mappings` is called with `"framework": "unknown"`
- **THEN** it returns HTTP 422 with validation errors

#### Scenario: Delete mapping
- **WHEN** `DELETE /api/v1/action-mappings/:id` is called for an existing mapping
- **THEN** it returns HTTP 200 with the deleted mapping data

#### Scenario: Delete mapping not found
- **WHEN** `DELETE /api/v1/action-mappings/:id` is called for a nonexistent ID
- **THEN** it returns HTTP 404

#### Scenario: Validate actions
- **WHEN** `POST /api/v1/action-mappings/validate` is called with `{"framework": "hipaa"}`
- **THEN** it returns HTTP 200 with `{"data": {"recognized": [...], "unmapped": [...]}}`

