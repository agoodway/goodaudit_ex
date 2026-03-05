## 1. Report Template Registry

- [ ] 1.1 Create `lib/app/compliance/report_template.ex` — define `%GA.Compliance.ReportTemplate{}` struct with fields: `id`, `framework`, `name`, `description`, `required_params`, `optional_params`, `columns`, `filters`, `grouping`, `sort_order`
- [ ] 1.2 Implement `get(template_id)` — returns `{:ok, %ReportTemplate{}}` or `{:error, :template_not_found}`
- [ ] 1.3 Implement `list()` — returns all registered templates
- [ ] 1.4 Implement `list_by_framework(framework)` — returns templates filtered by framework string
- [ ] 1.5 Implement `validate_params(template, params)` — validates required params present, `from`/`to` are valid ISO 8601 datetimes with `from < to`, returns `:ok` or `{:error, reasons}`

## 2. HIPAA Templates

- [ ] 2.1 Create `lib/app/compliance/templates/hipaa.ex` — module returning list of HIPAA `%ReportTemplate{}` structs
- [ ] 2.2 Define `hipaa.phi_access` template — filter `phi_accessed == true`, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `user_role`
- [ ] 2.3 Define `hipaa.user_activity` template — all entries for a given `actor_id`, required param `:actor_id`, columns: `timestamp`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `session_id`
- [ ] 2.4 Define `hipaa.failed_auth` template — filter `action == "login"` and `outcome == "failure"`, columns: `timestamp`, `user_id`, `source_ip`, `user_agent`, `failure_reason`
- [ ] 2.5 Define `hipaa.system_access_summary` template — aggregated by date and action, columns: `date`, `action`, `unique_actors`, `event_count`, grouping on `date(timestamp)` and `action`
- [ ] 2.6 Define `hipaa.minimum_necessary` template — PHI access with role-based grouping, grouping on `user_role` and `resource_type`, columns: `user_role`, `resource_type`, `access_count`, `unique_actors`, `unique_resources`

## 3. SOC 2 Templates

- [ ] 3.1 Create `lib/app/compliance/templates/soc2.ex` — module returning list of SOC 2 `%ReportTemplate{}` structs
- [ ] 3.2 Define `soc2.change_management` template — filter on change category actions (`create`, `update`, `delete`), columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`
- [ ] 3.3 Define `soc2.production_access` template — production environment access events, columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `source_ip`, `outcome`
- [ ] 3.4 Define `soc2.incident_timeline` template — incident-related events, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `failure_reason`, `metadata`
- [ ] 3.5 Define `soc2.control_activity_summary` template — aggregated by action and outcome, columns: `action`, `outcome`, `event_count`, `unique_actors`, `first_occurrence`, `last_occurrence`

## 4. PCI-DSS Templates

- [ ] 4.1 Create `lib/app/compliance/templates/pci.ex` — module returning list of PCI-DSS `%ReportTemplate{}` structs
- [ ] 4.2 Define `pci.cardholder_data_access` template — cardholder data access events, columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`
- [ ] 4.3 Define `pci.key_management` template — key management events, columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`
- [ ] 4.4 Define `pci.privileged_user_activity` template — admin/privileged role events, columns: `timestamp`, `user_id`, `user_role`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `session_id`

## 5. GDPR Templates

- [ ] 5.1 Create `lib/app/compliance/templates/gdpr.ex` — module returning list of GDPR `%ReportTemplate{}` structs
- [ ] 5.2 Define `gdpr.processing_activities` template — ROPA data processing events, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`
- [ ] 5.3 Define `gdpr.subject_requests` template — data subject request fulfillment, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`
- [ ] 5.4 Define `gdpr.consent_activity` template — consent grant/withdrawal timeline, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `metadata`
- [ ] 5.5 Define `gdpr.cross_border_transfers` template — transfer events with legal basis, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `source_ip`, `metadata`
- [ ] 5.6 Define `gdpr.breach_timeline` template — breach events for DPA notification, columns: `timestamp`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `failure_reason`, `metadata`, `source_ip`

## 6. Compliance Export Schema and Migration

- [ ] 6.1 Create migration for `compliance_exports` table — `id` (UUID), `account_id` (UUID FK), `template_id` (string), `params` (JSONB), `format` (string), `status` (string), `file_path` (string nullable), `row_count` (integer nullable), `integrity_manifest` (JSONB nullable), `error_message` (string nullable), `started_at` (utc_datetime_usec nullable), `completed_at` (utc_datetime_usec nullable), timestamps
- [ ] 6.2 Add index on `(account_id, status)` for efficient polling queries
- [ ] 6.3 Create `lib/app/compliance/export.ex` — `GA.Compliance.Export` Ecto schema mapping to `compliance_exports` table with changeset validation for required fields and status enum

## 7. Export Query Execution

- [ ] 7.1 Create `lib/app/compliance/exporter.ex` — `GA.Compliance.Exporter` module
- [ ] 7.2 Implement `execute(template, account_id, params)` — builds Ecto query from template filters, columns, sort_order, and params (including date range), scoped to account_id
- [ ] 7.3 Implement non-aggregated query path — selects template columns from `audit_logs` with template filters and param-based filters applied
- [ ] 7.4 Implement aggregated query path — for templates with `grouping`, executes GROUP BY query with COUNT, COUNT(DISTINCT), MIN, MAX aggregates as appropriate
- [ ] 7.5 Implement `count(template, account_id, params)` — runs COUNT(*) with the same filters to determine inline vs async threshold

## 8. Export Formatters

- [ ] 8.1 Create `lib/app/compliance/formatters/json_formatter.ex` — produces JSON object with `template`, `meta`, `data`, and `manifest` keys
- [ ] 8.2 Create `lib/app/compliance/formatters/csv_formatter.ex` — produces RFC 4180 CSV with header row, data rows, and manifest comment block footer
- [ ] 8.3 Create `lib/app/compliance/formatters/pdf_formatter.ex` — produces PDF via `chromic_pdf` with header section, data table, and integrity manifest footer
- [ ] 8.4 Implement PDF availability check — return `{:error, :pdf_unavailable}` if `chromic_pdf` is not loaded or Chrome binary is not found

## 9. Integrity Manifest

- [ ] 9.1 Create `lib/app/compliance/manifest.ex` — `GA.Compliance.Manifest` module
- [ ] 9.2 Implement `generate(account_id, entries, params)` — orchestrates chain verification for exported range, loads checkpoint anchors, computes export checksum, assembles manifest map
- [ ] 9.3 Implement `compute_export_checksum(content)` — SHA-256 hex digest of export content (data array for JSON, header+data rows for CSV, full binary for PDF)
- [ ] 9.4 Implement chain verification for date range — uses `GA.Audit.Verifier` infrastructure scoped to the exported entries' sequence number range
- [ ] 9.5 Implement checkpoint anchor loading — queries checkpoints for account within the sequence number range, returns summaries with `sequence_number`, `checksum`, `anchored`, `signature`, `verified_at`, `signing_key_id`

## 10. Async Export Worker

- [ ] 10.1 Create `lib/app/compliance/export_worker.ex` — `GA.Compliance.ExportWorker` Oban worker
- [ ] 10.2 Implement `perform/1` — loads export record, transitions to `processing`, loads template, executes query in batches (1000), writes to temp file, computes manifest, transitions to `completed`
- [ ] 10.3 Implement failure handling — catch errors, set status to `failed` with `error_message`, clean up partial files
- [ ] 10.4 Add Oban queue configuration for `:compliance_exports` queue in `config/config.exs`

## 11. Export Context Functions

- [ ] 11.1 Create `lib/app/compliance.ex` — `GA.Compliance` context module
- [ ] 11.2 Implement `create_export(account_id, attrs)` — validates template exists, validates params, runs count query, returns inline result or creates export record + enqueues Oban job
- [ ] 11.3 Implement `get_export(account_id, export_id)` — fetches export record scoped to account, returns `{:ok, export}` or `{:error, :not_found}`
- [ ] 11.4 Implement `get_export_file(account_id, export_id)` — returns file path for completed export or error

## 12. OpenAPI Schemas

- [ ] 12.1 Create `lib/app_web/schemas/export_request.ex` — template_id, from, to, format, params
- [ ] 12.2 Create `lib/app_web/schemas/export_response.ex` — export record fields (id, status, template_id, format, params, row_count, manifest, etc.)
- [ ] 12.3 Create `lib/app_web/schemas/export_template_response.ex` — template listing fields (id, framework, name, description, required_params, optional_params)

## 13. Export Controller and JSON View

- [ ] 13.1 Create `lib/app_web/controllers/api/v1/export_controller.ex` — `create/2` (POST /exports), `show/2` (GET /exports/:id), `download/2` (GET /exports/:id/download)
- [ ] 13.2 Create `lib/app_web/controllers/api/v1/export_template_controller.ex` — `index/2` (GET /export-templates with optional framework filter)
- [ ] 13.3 Create `lib/app_web/controllers/api/v1/export_json.ex` — renders export records, inline export data, and template listings
- [ ] 13.4 Add OpenApiSpex operation annotations for all export and template endpoints — document both 200 (inline) and 202 (async) responses for `POST /exports`, and multiple content types (`application/json`, `text/csv`, `application/pdf`) for `GET /exports/:id/download`

## 14. Router Wiring

- [ ] 14.1 Add `resources "/exports", ExportController, only: [:create]` to `:api_write` scope
- [ ] 14.2 Add `resources "/exports", ExportController, only: [:show]` and `get "/exports/:id/download", ExportController, :download` to `:api_authenticated` scope
- [ ] 14.3 Add `resources "/export-templates", ExportTemplateController, only: [:index]` to `:api_authenticated` scope

## 15. Export File Storage and Cleanup

- [ ] 15.1 Add export directory config to `config/runtime.exs` — `EXPORT_STORAGE_DIR` with default `priv/exports`
- [ ] 15.2 Add export TTL config — `EXPORT_TTL_HOURS` with default 24
- [ ] 15.3 Create `lib/app/compliance/export_cleanup_worker.ex` — Oban cron worker that deletes export files and records older than TTL

## 16. PDF Dependency

- [ ] 16.1 Add `{:chromic_pdf, "~> 1.15", optional: true}` to `mix.exs` deps
- [ ] 16.2 Add ChromicPDF to application supervision tree (conditional on availability)

## 17. Tests

- [ ] 17.1 Test `ReportTemplate.get/1` — returns template for known IDs, error for unknown
- [ ] 17.2 Test `ReportTemplate.list/0` — returns all templates across all frameworks
- [ ] 17.3 Test `ReportTemplate.list_by_framework/1` — returns only templates for the given framework
- [ ] 17.4 Test `ReportTemplate.validate_params/2` — valid params return `:ok`, missing params return error, invalid dates return error, `from >= to` returns error
- [ ] 17.5 Test all HIPAA template definitions — correct IDs, columns, filters, grouping, sort_order, required/optional params
- [ ] 17.6 Test all SOC 2 template definitions — correct IDs, columns, filters, grouping, sort_order, required/optional params
- [ ] 17.7 Test all PCI-DSS template definitions — correct IDs, columns, filters, sort_order, required/optional params
- [ ] 17.8 Test all GDPR template definitions — correct IDs, columns, filters, sort_order, required/optional params
- [ ] 17.9 Test `Exporter.execute/3` — non-aggregated query returns entries matching template filters scoped to account and date range
- [ ] 17.10 Test `Exporter.execute/3` — aggregated query returns grouped results with correct aggregates
- [ ] 17.11 Test `Exporter.count/3` — returns correct count for template filters
- [ ] 17.12 Test JSON formatter — produces valid JSON with template, meta, data, and manifest keys
- [ ] 17.13 Test CSV formatter — produces RFC 4180 output with correct header, escaped fields, and manifest comment footer
- [ ] 17.14 Test PDF formatter — produces PDF binary (integration test with chromic_pdf if available, skip if not)
- [ ] 17.15 Test `Manifest.generate/3` — produces manifest with chain_verification, checkpoint_anchors, export_checksum, generated_at, generated_by
- [ ] 17.16 Test `Manifest.compute_export_checksum/1` — SHA-256 hex digest, deterministic for same input
- [ ] 17.17 Test manifest chain verification — valid chain produces `valid: true`, tampered chain produces `valid: false`
- [ ] 17.18 Test manifest checkpoint anchors — includes anchored and unanchored checkpoints in range
- [ ] 17.19 Test `Compliance.create_export/2` — inline return for < 10k rows, async job creation for >= 10k rows
- [ ] 17.20 Test `Compliance.get_export/2` — returns export for account, 404 for other account's export
- [ ] 17.21 Test ExportWorker — processes pending export through to completed with file and manifest
- [ ] 17.22 Test ExportWorker failure handling — sets status to failed, cleans up partial files
- [ ] 17.23 Test `POST /api/v1/exports` — 200 inline for small export, 202 for large, 422 for invalid template/params, 401/403 auth enforcement
- [ ] 17.24 Test `GET /api/v1/exports/:id` — returns export status for all states, 404 for cross-account
- [ ] 17.25 Test `GET /api/v1/exports/:id/download` — serves file for completed export, 404 for incomplete/cross-account
- [ ] 17.26 Test `GET /api/v1/export-templates` — returns all templates, filters by framework, empty list for unknown framework
- [ ] 17.27 Test export cleanup worker — deletes expired export files and records
