## ADDED Requirements

### Requirement: ReportTemplate struct

`GA.Compliance.ReportTemplate` MUST be a struct with the following fields: `id` (string, dot-notation like `"hipaa.phi_access"`), `framework` (string, one of `"hipaa"`, `"soc2"`, `"pci"`, `"gdpr"`), `name` (human-readable string), `description` (string), `required_params` (list of atoms — `:from` and `:to` are always included), `optional_params` (list of atoms), `columns` (ordered list of field reference strings), `filters` (map of framework-specific default filters), `grouping` (optional list of field references for aggregation, or `nil`), `sort_order` (list of `{field, :asc | :desc}` tuples).

#### Scenario: Struct creation
- **WHEN** a `%GA.Compliance.ReportTemplate{}` is created with all required fields
- **THEN** it contains `id`, `framework`, `name`, `description`, `required_params`, `optional_params`, `columns`, `filters`, `grouping`, and `sort_order`

#### Scenario: Required params always include date range
- **WHEN** any template is defined
- **THEN** its `required_params` list includes `:from` and `:to`

### Requirement: Template registry lookup

`GA.Compliance.ReportTemplate.get(template_id)` MUST return `{:ok, %ReportTemplate{}}` for a known template ID or `{:error, :template_not_found}` for an unknown one. `GA.Compliance.ReportTemplate.list()` MUST return all registered templates. `GA.Compliance.ReportTemplate.list_by_framework(framework)` MUST return only templates for the given framework string.

#### Scenario: Get known template
- **WHEN** `ReportTemplate.get("hipaa.phi_access")` is called
- **THEN** it returns `{:ok, %ReportTemplate{id: "hipaa.phi_access", framework: "hipaa", ...}}`

#### Scenario: Get unknown template
- **WHEN** `ReportTemplate.get("nonexistent.template")` is called
- **THEN** it returns `{:error, :template_not_found}`

#### Scenario: List all templates
- **WHEN** `ReportTemplate.list()` is called
- **THEN** it returns a list of all registered `%ReportTemplate{}` structs across all frameworks

#### Scenario: List by framework
- **WHEN** `ReportTemplate.list_by_framework("hipaa")` is called
- **THEN** it returns only templates where `framework == "hipaa"`

### Requirement: HIPAA templates

The registry MUST include the following HIPAA templates:

**`hipaa.phi_access`** — All entries where `phi_accessed == true`. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `user_role`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`, `resource_type`.

**`hipaa.user_activity`** — All entries for a given `user_id`, chronological. Columns: `timestamp`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `session_id`. Sort: `timestamp` ascending. Required params: `from`, `to`, `actor_id`. Optional params: none.

**`hipaa.failed_auth`** — Entries where `action == "login"` and `outcome == "failure"`. Columns: `timestamp`, `user_id`, `source_ip`, `user_agent`, `failure_reason`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`, `source_ip`.

**`hipaa.system_access_summary`** — Aggregated report: unique actors per day, total events per action category. Grouping: `date(timestamp)`, `action`. Columns: `date`, `action`, `unique_actors`, `event_count`. Sort: `date` ascending, `action` ascending. Required params: `from`, `to`. Optional params: none.

**`hipaa.minimum_necessary`** — PHI access entries with role-based grouping to verify minimum necessary standard compliance. Grouping: `user_role`, `resource_type`. Columns: `user_role`, `resource_type`, `access_count`, `unique_actors`, `unique_resources`. Sort: `user_role` ascending, `resource_type` ascending. Required params: `from`, `to`. Optional params: `user_role`.

#### Scenario: HIPAA PHI access template content
- **WHEN** `ReportTemplate.get("hipaa.phi_access")` is called
- **THEN** the template's `filters` include `%{phi_accessed: true}` and `columns` include `"timestamp"`, `"user_id"`, `"action"`, `"resource_type"`, `"resource_id"`, `"outcome"`, `"source_ip"`, `"user_role"`

#### Scenario: HIPAA user activity requires actor_id
- **WHEN** `ReportTemplate.get("hipaa.user_activity")` is called
- **THEN** `required_params` includes `:actor_id` in addition to `:from` and `:to`

#### Scenario: HIPAA system access summary is aggregated
- **WHEN** `ReportTemplate.get("hipaa.system_access_summary")` is called
- **THEN** `grouping` is not nil and includes date and action grouping fields

### Requirement: SOC 2 templates

The registry MUST include the following SOC 2 templates:

**`soc2.change_management`** — Entries where `action` matches change category actions (`create`, `update`, `delete`). Columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `resource_type`, `user_id`.

**`soc2.production_access`** — Entries where `metadata` indicates production environment access. Columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `source_ip`, `outcome`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`.

**`soc2.incident_timeline`** — Entries categorized as incident-related, chronological. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `failure_reason`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `resource_id`.

**`soc2.control_activity_summary`** — Aggregated control evidence by action category. Grouping: `action`, `outcome`. Columns: `action`, `outcome`, `event_count`, `unique_actors`, `first_occurrence`, `last_occurrence`. Sort: `action` ascending. Required params: `from`, `to`. Optional params: none.

#### Scenario: SOC 2 change management template columns
- **WHEN** `ReportTemplate.get("soc2.change_management")` is called
- **THEN** `columns` include `"metadata"` for ticket reference visibility and `filters` scope to change category actions

#### Scenario: SOC 2 control activity summary is aggregated
- **WHEN** `ReportTemplate.get("soc2.control_activity_summary")` is called
- **THEN** `grouping` is not nil and includes action and outcome grouping

### Requirement: PCI-DSS templates

The registry MUST include the following PCI-DSS templates:

**`pci.cardholder_data_access`** — Entries related to cardholder data access. Columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`, `resource_type`.

**`pci.key_management`** — Key management operation entries. Columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`.

**`pci.privileged_user_activity`** — Entries where `user_role` matches admin/privileged roles. Columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `session_id`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`, `user_role`.

#### Scenario: PCI cardholder data access template
- **WHEN** `ReportTemplate.get("pci.cardholder_data_access")` is called
- **THEN** the template has `framework: "pci"` and `columns` include `"source_ip"` for network access tracking

#### Scenario: PCI privileged user activity filters by role
- **WHEN** `ReportTemplate.get("pci.privileged_user_activity")` is called
- **THEN** `optional_params` includes `:user_role` to allow role-specific filtering

### Requirement: GDPR templates

The registry MUST include the following GDPR templates:

**`gdpr.processing_activities`** — Records of Processing Activities (ROPA) — all data processing events. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `resource_type`, `action`.

**`gdpr.subject_requests`** — Data subject request fulfillment log. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`.

**`gdpr.consent_activity`** — Consent grant/withdrawal timeline. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `user_id`.

**`gdpr.cross_border_transfers`** — Transfer events with legal basis documentation. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `metadata`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `resource_type`.

**`gdpr.breach_timeline`** — Breach-related events for DPA notification preparation. Columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `failure_reason`, `metadata`, `source_ip`. Sort: `timestamp` ascending. Required params: `from`, `to`. Optional params: `resource_type`.

#### Scenario: GDPR processing activities template
- **WHEN** `ReportTemplate.get("gdpr.processing_activities")` is called
- **THEN** the template has `framework: "gdpr"` and includes `"metadata"` in `columns` for legal basis and purpose documentation

#### Scenario: GDPR breach timeline includes failure context
- **WHEN** `ReportTemplate.get("gdpr.breach_timeline")` is called
- **THEN** `columns` include `"failure_reason"` and `"source_ip"` for incident investigation

#### Scenario: GDPR consent activity tracks user-level timeline
- **WHEN** `ReportTemplate.get("gdpr.consent_activity")` is called
- **THEN** `optional_params` includes `:user_id` to filter consent events for a specific data subject

### Requirement: Template parameter validation

`GA.Compliance.ReportTemplate.validate_params(template, params)` MUST check that all `required_params` are present in the provided `params` map and that `from` and `to` are valid ISO 8601 datetimes with `from` before `to`. It MUST return `:ok` on success or `{:error, reasons}` with a list of validation failure descriptions.

#### Scenario: Valid params
- **WHEN** `validate_params(hipaa_phi_access, %{from: "2025-01-01T00:00:00Z", to: "2025-12-31T23:59:59Z"})` is called
- **THEN** it returns `:ok`

#### Scenario: Missing required param
- **WHEN** `validate_params(hipaa_user_activity, %{from: "2025-01-01T00:00:00Z", to: "2025-12-31T23:59:59Z"})` is called (missing `actor_id`)
- **THEN** it returns `{:error, ["missing required parameter: actor_id"]}`

#### Scenario: Invalid date range
- **WHEN** `validate_params(template, %{from: "2025-12-31T00:00:00Z", to: "2025-01-01T00:00:00Z"})` is called
- **THEN** it returns `{:error, ["from must be before to"]}`

#### Scenario: Invalid datetime format
- **WHEN** `validate_params(template, %{from: "not-a-date", to: "2025-12-31T23:59:59Z"})` is called
- **THEN** it returns `{:error, ["from is not a valid ISO 8601 datetime"]}`
