## 1. Framework Behaviour and Built-in Modules

- [x] 1.1 Create `lib/app/compliance/framework.ex` defining the `GA.Compliance.Framework` behaviour with callbacks: `name/0`, `required_fields/0`, `recommended_fields/0`, `default_retention_days/0`, `verification_cadence_hours/0`, `extension_schema/0`, `event_taxonomy/0`
- [x] 1.2 Create `lib/app/compliance/frameworks/hipaa.ex` implementing `GA.Compliance.Framework` -- required fields: `[:user_id, :action, :resource_type, :resource_id, :timestamp, :phi_accessed, :source_ip, :user_role]`, retention: 2555 days, cadence: 24h
- [x] 1.3 Create `lib/app/compliance/frameworks/soc2.ex` implementing `GA.Compliance.Framework` -- required fields: `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip, :session_id]`, retention: 2555 days, cadence: 24h
- [x] 1.4 Create `lib/app/compliance/frameworks/pci_dss.ex` implementing `GA.Compliance.Framework` -- required fields: `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip, :user_role, :session_id]`, retention: 365 days, cadence: 12h
- [x] 1.5 Create `lib/app/compliance/frameworks/gdpr.ex` implementing `GA.Compliance.Framework` -- required fields: `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome]`, retention: 1825 days, cadence: 48h
- [x] 1.6 Create `lib/app/compliance/frameworks/iso27001.ex` implementing `GA.Compliance.Framework` -- required fields: `[:user_id, :action, :resource_type, :resource_id, :timestamp, :outcome, :source_ip]`, retention: 1095 days, cadence: 24h

## 2. Compliance Context Module

- [x] 2.1 Create `lib/app/compliance.ex` with `GA.Compliance` context module
- [x] 2.2 Implement `registry/0` returning `%{"hipaa" => GA.Compliance.Frameworks.HIPAA, "soc2" => GA.Compliance.Frameworks.SOC2, "pci_dss" => GA.Compliance.Frameworks.PCIDSS, "gdpr" => GA.Compliance.Frameworks.GDPR, "iso27001" => GA.Compliance.Frameworks.ISO27001}`
- [x] 2.3 Implement `get_framework(framework_id)` returning `{:ok, module}` or `{:error, :unknown_framework}`
- [x] 2.4 Implement `required_fields_for_frameworks(framework_ids)` computing the deduplicated union of required fields from all known framework IDs, skipping unknown IDs
- [x] 2.5 Implement `active_framework_ids(account_id)` querying the join table for the account's active framework ID strings
- [x] 2.6 Implement `activate_framework(account_id, framework_id, opts \\ [])` creating an `AccountComplianceFramework` record with validation
- [x] 2.7 Implement `deactivate_framework(account_id, framework_id)` deleting the association record
- [x] 2.8 Implement `list_active_frameworks(account_id)` returning ordered association records
- [x] 2.9 Implement `effective_config(account_id, framework_id)` merging framework defaults with account overrides

## 3. Schema and Migration

- [x] 3.1 Create `lib/app/compliance/account_compliance_framework.ex` Ecto schema with `account_id`, `framework_id`, `activated_at`, `config_overrides` fields, changeset validation (framework_id must be in registry, config_overrides whitelist: `retention_days`, `verification_cadence_hours`, `additional_required_fields`), and unique constraint on `(account_id, framework_id)`
- [x] 3.2 Create migration adding `account_compliance_frameworks` table with all columns, foreign key to `accounts`, and unique index on `(account_id, framework_id)`
- [x] 3.3 Create migration adding `frameworks` column (`{:array, :string}`, default `[]`) to `audit_logs` table
- [x] 3.4 Update `GA.Audit.Log` schema to include `field(:frameworks, {:array, :string}, default: [])` and update the changeset to cast the new field

## 4. Framework-Aware Validation in Entry Creation

- [x] 4.1 Add framework validation step to `GA.Audit.create_log_entry/2` -- before acquiring advisory lock, call `GA.Compliance.active_framework_ids(account_id)` and `GA.Compliance.required_fields_for_frameworks/1` to compute required fields
- [x] 4.2 Implement `validate_framework_fields(attrs, framework_ids)` that checks presence of all required fields (non-nil), returning `{:ok, framework_ids}` or `{:error, changeset}` with framework-attributed errors
- [x] 4.3 On validation success, set `frameworks` field on the entry attrs to the sorted list of active framework IDs before chain computation
- [x] 4.4 On validation failure, return `{:error, changeset}` with per-field errors in format `"required by Framework Name"` without acquiring the advisory lock

## 5. Canonical Payload Update

- [x] 5.1 Update `GA.Audit.Chain` `@payload_fields` or `canonical_payload/2` to conditionally include the `frameworks` field -- serialize as sorted comma-joined string (e.g., `"hipaa,soc2"`)
- [x] 5.2 When `frameworks` is `[]`, include an empty frameworks segment in the payload
- [x] 5.3 Update `entry_to_attrs/1` to include `frameworks` in the extracted fields
- [x] 5.4 Update `verify_checksum/3` to include frameworks field in verification

## 6. OpenAPI Schema Updates

- [x] 6.1 Update `lib/app_web/schemas/audit_log_response.ex` to add `frameworks` property (array of strings) to the response schema
- [x] 6.2 Update `lib/app_web/schemas/audit_log_list_response.ex` to include `frameworks` field on each item in the data array
- [x] 6.3 Update `AuditLogController.operation(:create)` error response documentation to describe framework-attributed 422 errors (e.g., `{"errors": {"field": ["required by HIPAA"]}}`)
- [x] 6.4 Verify `frameworks` field appears in `GET /api/v1/openapi` output for audit log endpoints

## 7. Tests

- [x] 7.1 Test all five built-in framework modules return correct values for each callback
- [x] 7.2 Test `GA.Compliance.registry/0` returns expected mapping
- [x] 7.3 Test `GA.Compliance.get_framework/1` for known and unknown framework IDs
- [x] 7.4 Test `GA.Compliance.required_fields_for_frameworks/1` for single, multiple, empty, and unknown framework IDs
- [x] 7.5 Test `GA.Compliance.activate_framework/2` -- known framework, unknown framework, duplicate activation, with config overrides
- [x] 7.6 Test `GA.Compliance.deactivate_framework/2` -- active framework, inactive framework
- [x] 7.7 Test `GA.Compliance.list_active_frameworks/1` and `active_framework_ids/1`
- [x] 7.8 Test `GA.Compliance.effective_config/2` -- no overrides, with retention override, with additional required fields, framework not active
- [x] 7.9 Test config_overrides validation -- valid keys, invalid keys, invalid value types
- [x] 7.10 Test `create_log_entry/2` with active frameworks and all required fields present -- entry created with `frameworks` field set
- [x] 7.11 Test `create_log_entry/2` with active frameworks and missing required fields -- returns framework-attributed errors
- [x] 7.12 Test `create_log_entry/2` with multiple active frameworks and fields missing from multiple frameworks -- error messages attribute each framework
- [x] 7.13 Test `create_log_entry/2` with no active frameworks -- no framework validation, `frameworks: []`
- [x] 7.14 Test `create_log_entry/2` with additional_required_fields override -- override fields validated and attributed
- [x] 7.15 Test nil vs absent vs empty string vs false field handling in framework validation
- [x] 7.16 Test canonical payload includes frameworks segment for entries with active frameworks
- [x] 7.17 Test canonical payload includes empty frameworks segment for entries with `frameworks: []`
- [x] 7.18 Test chain verification succeeds for entries with frameworks field
- [x] 7.19 Test chain verification detects tampered frameworks field
- [x] 7.20 Test chain with entries that have different framework sets verifies correctly
- [x] 7.21 Test OpenAPI schema includes `frameworks` field on audit log response objects

## Progress Notes

- 2026-03-05: `/prepare-for-landing` implemented review findings `td-f18d3e`, `td-9d75c6`, `td-f09b67`, `td-7c01cd`, `td-1f4da1`, and `td-5a2432`; all checklist items above now map to code/tests in this branch.
