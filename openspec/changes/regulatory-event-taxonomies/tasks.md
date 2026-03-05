## 1. Taxonomy Behaviour and Registry

- [ ] 1.1 Create `lib/app/compliance/taxonomy.ex` with `GA.Compliance.Taxonomy` behaviour — define callbacks `framework/0`, `taxonomy_version/0`, `taxonomy/0`, `actions/0`
- [ ] 1.2 Implement `GA.Compliance.Taxonomy.get/1` — registry lookup from framework string to module
- [ ] 1.3 Implement `GA.Compliance.Taxonomy.list_frameworks/0` — returns sorted list of registered framework identifiers
- [ ] 1.4 Implement `GA.Compliance.Taxonomy.resolve_path/2` — resolve dot-separated path (with wildcard support) to list of actions

## 2. Framework Taxonomy Modules

- [ ] 2.1 Create `lib/app/compliance/taxonomies/hipaa.ex` — `GA.Compliance.Taxonomies.HIPAA` implementing taxonomy behaviour with access/admin/disclosure categories
- [ ] 2.2 Create `lib/app/compliance/taxonomies/soc2.ex` — `GA.Compliance.Taxonomies.SOC2` implementing taxonomy behaviour with change/access/incident/monitoring categories
- [ ] 2.3 Create `lib/app/compliance/taxonomies/pci_dss.ex` — `GA.Compliance.Taxonomies.PCIDSS` implementing taxonomy behaviour with cardholder/authentication/key_management/network categories
- [ ] 2.4 Create `lib/app/compliance/taxonomies/gdpr.ex` — `GA.Compliance.Taxonomies.GDPR` implementing taxonomy behaviour with processing/subject_request/consent/transfer categories
- [ ] 2.5 Create `lib/app/compliance/taxonomies/iso_27001.ex` — `GA.Compliance.Taxonomies.ISO27001` implementing taxonomy behaviour with access_control/asset_management/incident_management/change_management categories

## 3. Database Schema

- [ ] 3.1 Create migration for `account_compliance_frameworks` table — `account_id`, `framework`, `action_validation_mode` (default `"flexible"`), `enabled_at`, unique index on `[account_id, framework]`
- [ ] 3.2 Create `lib/app/compliance/account_framework.ex` — Ecto schema for `account_compliance_frameworks` with changeset validation
- [ ] 3.3 Create migration for `account_action_mappings` table — `account_id`, `custom_action`, `framework`, `taxonomy_path`, `taxonomy_version`, `created_at`, unique index on `[account_id, custom_action, framework]`
- [ ] 3.4 Create `lib/app/compliance/action_mapping.ex` — Ecto schema for `account_action_mappings` with changeset validation including framework and taxonomy_path validation

## 4. Action Mapping Context

- [ ] 4.1 Implement `GA.Compliance.ActionMapping.create_mapping/2` — validate framework exists, validate taxonomy_path resolves, record taxonomy_version, insert
- [ ] 4.2 Implement `GA.Compliance.ActionMapping.list_mappings/2` — list mappings for account with optional `framework` and `custom_action` filters
- [ ] 4.3 Implement `GA.Compliance.ActionMapping.update_mapping/3` — update taxonomy_path with validation and version recording
- [ ] 4.4 Implement `GA.Compliance.ActionMapping.delete_mapping/2` — account-scoped deletion
- [ ] 4.5 Implement `GA.Compliance.ActionMapping.resolve_actions/3` — resolve taxonomy pattern to combined set of taxonomy actions and mapped custom actions
- [ ] 4.6 Implement `GA.Compliance.ActionMapping.validate_actions/2` — dry-run scan of recent log actions against framework taxonomy and mappings

## 5. Strict Mode Validation Integration

- [ ] 5.1 Add strict-mode validation helper in `GA.Compliance` — given account_id and action, check all strict-mode frameworks for the account
- [ ] 5.2 Integrate strict-mode check into `GA.Audit.create_log_entry/2` — after changeset validation, before insert, reject unrecognized actions for strict-mode frameworks
- [ ] 5.3 Update `GA.Audit.Log` changeset to relax `validate_inclusion(:action, @valid_actions)` when taxonomy validation is active — allow any action string through changeset, let strict-mode validation handle framework-specific checks

## 6. Taxonomy-Aware Querying

- [ ] 6.1 Implement category filter parser — parse `"framework:pattern"` format, validate framework, resolve pattern to action set
- [ ] 6.2 Add `category` filter to `GA.Audit.apply_filters/2` — expand category to `WHERE action IN (taxonomy_actions ++ mapped_actions)` clause
- [ ] 6.3 Handle category validation errors in `list_logs/2` — return `{:error, :unknown_framework}`, `{:error, :invalid_category_path}`, or `{:error, :invalid_category_format}` as appropriate

## 7. API Endpoints — Taxonomies

- [ ] 7.1 Create `lib/app_web/controllers/taxonomy_controller.ex` — `index/2` (list all frameworks), `show/2` (get specific framework taxonomy)
- [ ] 7.2 Create `lib/app_web/controllers/taxonomy_json.ex` — renders framework list and taxonomy tree
- [ ] 7.3 Add routes: `GET /api/v1/taxonomies` and `GET /api/v1/taxonomies/:framework` to `:api_authenticated` scope

## 8. API Endpoints — Action Mappings

- [ ] 8.1 Create `lib/app_web/controllers/action_mapping_controller.ex` — `index/2`, `create/2`, `update/2`, `delete/2`, `validate/2`, `check_compatibility/2`
- [ ] 8.2 Create `lib/app_web/controllers/action_mapping_json.ex` — renders mapping records, validation reports, and compatibility reports
- [ ] 8.3 Add routes: `GET /api/v1/action-mappings` to `:api_authenticated` scope, `POST /api/v1/action-mappings`, `PUT /api/v1/action-mappings/:id`, `DELETE /api/v1/action-mappings/:id` to `:api_write` scope
- [ ] 8.4 Add route: `POST /api/v1/action-mappings/validate` to `:api_authenticated` scope
- [ ] 8.5 Add `category` query parameter support to existing `GET /api/v1/audit-logs` endpoint and update `AuditLogController.operation(:index)` annotation to document the new parameter

## 9. OpenAPI Schemas

- [ ] 9.1 Create `lib/app_web/schemas/taxonomy_list_response.ex` — list of `%{framework: string, version: string}`
- [ ] 9.2 Create `lib/app_web/schemas/taxonomy_show_response.ex` — single framework taxonomy tree with categories/subcategories/actions
- [ ] 9.3 Create `lib/app_web/schemas/action_mapping_request.ex` — `custom_action`, `framework`, `taxonomy_path` fields
- [ ] 9.4 Create `lib/app_web/schemas/action_mapping_response.ex` — single mapping object with `id`, `custom_action`, `framework`, `taxonomy_path`, `taxonomy_version`
- [ ] 9.5 Create `lib/app_web/schemas/action_mapping_list_response.ex` — paginated list of mapping objects
- [ ] 9.6 Create `lib/app_web/schemas/action_mapping_validate_response.ex` — `recognized` and `unmapped` action lists
- [ ] 9.7 Add OpenApiSpex operation annotations to `TaxonomyController` (`index`, `show`)
- [ ] 9.8 Add OpenApiSpex operation annotations to `ActionMappingController` (`index`, `create`, `update`, `delete`, `validate`)

## 10. Tests

- [ ] 10.1 Test taxonomy behaviour enforcement — modules without all callbacks produce warnings
- [ ] 10.2 Test each framework taxonomy module — `taxonomy/0` returns correct structure, `actions/0` returns correct flat list, `taxonomy_version/0` returns valid version
- [ ] 10.3 Test `GA.Compliance.Taxonomy.get/1` — returns correct module for known frameworks, error for unknown
- [ ] 10.4 Test `GA.Compliance.Taxonomy.resolve_path/2` — exact path, subcategory wildcard, category wildcard, invalid path
- [ ] 10.5 Test action mapping CRUD — create with valid/invalid framework and path, list with filters, update, delete, account isolation
- [ ] 10.6 Test `resolve_actions/3` — taxonomy actions, mapped actions, combined set, unknown framework
- [ ] 10.7 Test strict-mode validation — canonical action accepted, mapped action accepted, unknown action rejected, flexible mode allows any action, mixed-mode frameworks
- [ ] 10.8 Test `validate_actions/2` dry-run — full coverage, partial coverage, no mappings
- [ ] 10.9 Test category filter in `list_logs/2` — category wildcard, subcategory wildcard, exact path, combined with other filters, cursor pagination
- [ ] 10.10 Test category filter validation — unknown framework, invalid path, missing framework prefix
- [ ] 10.11 Test taxonomy API endpoints — list frameworks, get specific taxonomy, unknown framework returns 404
- [ ] 10.12 Test action mapping API endpoints — CRUD operations, validation endpoint, auth enforcement
- [ ] 10.13 Test category query parameter on `GET /api/v1/audit-logs` — valid category, invalid category returns 422
- [ ] 10.14 Test OpenAPI schemas render correctly for taxonomy and action mapping endpoints
