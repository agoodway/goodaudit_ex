## 1. Schema Migration

- [x] 1.1 Create Ecto migration with `extensions` JSONB column on `audit_logs` with `NOT NULL DEFAULT '{}'::jsonb`
- [x] 1.2 Create Ecto migration with `actor_id` varchar column on `audit_logs` (NOT NULL)
- [x] 1.3 Create GIN index on `audit_logs.extensions`
- [x] 1.4 Create partial B-tree index on `(extensions->'hipaa'->>'phi_accessed') WHERE extensions->'hipaa' IS NOT NULL`
- [x] 1.5 Add unique index on `[account_id, sequence_number]` if not already present (verify existing indexes)

## 2. Ecto Schema and Changeset Updates

- [x] 2.1 Add `field(:extensions, :map, default: %{})` to `GA.Audit.Log` schema
- [x] 2.2 Add `field(:actor_id, :string)` to `GA.Audit.Log` schema
- [x] 2.3 Update `changeset/2` to cast `:extensions` and `:actor_id`
- [x] 2.4 Update `changeset/2` to validate `:actor_id` as required
- [x] 2.5 Update `valid_actions/0` and `valid_outcomes/0` if any additions needed

## 3. Extension Validation Module

- [x] 3.1 Create `lib/app/compliance/extension_schema.ex` with `GA.Compliance.ExtensionSchema` module
- [x] 3.2 Implement `validate(frameworks, extensions)` — validates extension map against active framework schemas, returns `{:ok, extensions}` or `{:error, changeset}`
- [x] 3.3 Implement HIPAA bootstrap schema definition (required fields: `phi_accessed` boolean, `user_role` string; optional fields: `source_ip` string, `session_id` string, `failure_reason` string, `user_agent` string)
- [x] 3.4 Implement type checking for extension field values (boolean, string, integer, etc.)
- [x] 3.5 Implement unrecognized framework key rejection
- [x] 3.6 Implement descriptive error messages with framework-namespaced field paths (e.g., `hipaa.user_role is required`)

## 4. Canonical Payload

- [x] 4.1 Define `@payload_fields` in `GA.Audit.Chain`: `["account_id", "sequence_number", "actor_id", "action", "resource_type", "resource_id", "outcome", "timestamp"]`
- [x] 4.2 Implement `canonical_extensions/1` — sorts extensions map keys recursively and encodes as compact JSON (reuse `sort_keys_recursive/1`); empty maps produce `"{}"`
- [x] 4.3 Implement `canonical_payload/2` with field order: `account_id|sequence_number|previous_checksum|actor_id|action|resource_type|resource_id|outcome|timestamp|sorted_extensions_json|sorted_metadata_json`
- [x] 4.4 Update `entry_to_attrs/1` to include `extensions` and `actor_id` fields

## 5. Context Layer Integration

- [x] 5.1 Update `GA.Audit.create_entry/2` to call `GA.Compliance.ExtensionSchema.validate/2` before insertion
- [x] 5.2 Update entry querying to support extension field filters via JSONB containment queries
- [x] 5.3 Add account_id guard to all extension queries — reject queries without account scope

## 6. OpenAPI Schema Updates

- [x] 6.1 Rewrite `lib/app_web/schemas/audit_log_request.ex` — remove `user_id`, `user_role`, `session_id`, `source_ip`, `user_agent`, `phi_accessed`, `failure_reason`; add `actor_id` (required string) and `extensions` (object, framework-namespaced)
- [x] 6.2 Rewrite `lib/app_web/schemas/audit_log_response.ex` — same field restructuring: `actor_id` replaces `user_id`, `extensions` replaces flat HIPAA fields
- [x] 6.3 Rewrite `lib/app_web/schemas/audit_log_list_response.ex` — update item schema to match new response shape
- [x] 6.4 Update `AuditLogController.operation(:create)` — update request body and response references, document extension validation 422 errors
- [x] 6.5 Update `AuditLogController.operation(:index)` — remove `user_id` and `phi_accessed` query parameters, document `extensions` containment filter parameter
- [x] 6.6 Update `AuditLogController.operation(:show)` — update response schema reference
- [x] 6.7 Verify updated schemas render correctly in `GET /api/v1/openapi` and Swagger UI

## 7. Tests

- [x] 7.1 Test `ExtensionSchema.validate/2` — valid HIPAA extensions accepted
- [x] 7.2 Test `ExtensionSchema.validate/2` — missing required field rejected with descriptive error
- [x] 7.3 Test `ExtensionSchema.validate/2` — wrong field type rejected
- [x] 7.4 Test `ExtensionSchema.validate/2` — unrecognized framework key rejected
- [x] 7.5 Test `ExtensionSchema.validate/2` — multiple frameworks validated independently
- [x] 7.6 Test `ExtensionSchema.validate/2` — empty extensions with no active frameworks accepted
- [x] 7.7 Test `GA.Audit.Log` changeset casts `extensions` and `actor_id`
- [x] 7.8 Test `GA.Audit.Log` changeset requires `actor_id`
- [x] 7.9 Test canonical payload format — deterministic output with sorted extension keys
- [x] 7.10 Test canonical payload — empty extensions produce `"{}"`
- [x] 7.11 Test canonical payload — multiple frameworks sorted alphabetically by framework key
- [x] 7.12 Test entry creation with valid extensions — entry inserted with extensions stored
- [x] 7.13 Test entry creation with invalid extensions — entry rejected with validation errors
- [x] 7.14 Test entry querying with extension containment filters
- [x] 7.15 Test entry querying rejects extension filter without account scope
- [x] 7.16 Test GIN index is used for extension containment queries (EXPLAIN ANALYZE)
- [x] 7.17 Test OpenAPI spec reflects `actor_id`, `extensions`, and removed HIPAA fields
