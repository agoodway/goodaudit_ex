## ADDED Requirements

### Requirement: Create export (POST /api/v1/exports)

`POST /api/v1/exports` MUST accept a JSON body with `template_id` (string, required), `from` (ISO 8601 datetime, required), `to` (ISO 8601 datetime, required), `format` (string, one of `"json"`, `"csv"`, `"pdf"`, default `"json"`), and `params` (map, optional additional template parameters). The endpoint MUST validate the template exists, validate all required template parameters are present, and scope all queries to the authenticated account. It MUST require a private API key (`sk_*`) via the `:api_write` pipeline.

For exports with fewer than 10,000 matching rows, the endpoint MUST return HTTP 200 with inline export data. For exports with 10,000 or more matching rows, it MUST return HTTP 202 with a job record including `id`, `status: "pending"`, and a `Location` header pointing to `GET /api/v1/exports/:id`.

#### Scenario: Small inline export (JSON)
- **WHEN** a valid POST is made with `template_id: "hipaa.phi_access"`, valid date range, `format: "json"`, and fewer than 10,000 matching rows
- **THEN** the response is HTTP 200 with `{"data": [...], "manifest": {...}, "template": {...}, "meta": {"row_count": N, "generated_at": "..."}}`

#### Scenario: Small inline export (CSV)
- **WHEN** a valid POST is made with `format: "csv"` and fewer than 10,000 matching rows
- **THEN** the response is HTTP 200 with `Content-Type: text/csv`, `Content-Disposition: attachment; filename="hipaa-phi-access-2025-01-01-to-2025-12-31.csv"`, and RFC 4180 compliant CSV body with header row

#### Scenario: Large async export
- **WHEN** a valid POST is made and the count query returns 10,000 or more matching rows
- **THEN** the response is HTTP 202 with `{"data": {"id": "...", "status": "pending", "template_id": "...", "format": "...", "params": {...}}}`

#### Scenario: Unknown template
- **WHEN** a POST is made with `template_id: "nonexistent.template"`
- **THEN** the response is HTTP 422 with `{"errors": {"template_id": ["template not found"]}}`

#### Scenario: Missing required template parameter
- **WHEN** a POST is made for `hipaa.user_activity` without `actor_id` in params
- **THEN** the response is HTTP 422 with `{"errors": {"params": ["missing required parameter: actor_id"]}}`

#### Scenario: Invalid date range
- **WHEN** a POST is made with `from` after `to`
- **THEN** the response is HTTP 422 with `{"errors": {"from": ["must be before to"]}}`

#### Scenario: Unsupported format
- **WHEN** a POST is made with `format: "xml"`
- **THEN** the response is HTTP 422 with `{"errors": {"format": ["must be one of: json, csv, pdf"]}}`

#### Scenario: Auth enforcement
- **WHEN** a POST is made without a valid bearer token
- **THEN** the response is HTTP 401

#### Scenario: Read-only key rejected
- **WHEN** a POST is made with a public key (`pk_*`)
- **THEN** the response is HTTP 403

### Requirement: Get export status / download (GET /api/v1/exports/:id)

`GET /api/v1/exports/:id` MUST return the export job record for the authenticated account. If the export is completed, the response MUST include the download URL or inline content depending on format. The endpoint MUST use `:api_authenticated` pipeline (both `pk_*` and `sk_*` keys accepted). Export records from other accounts MUST return HTTP 404.

#### Scenario: Pending export
- **WHEN** `GET /api/v1/exports/:id` is called for a pending export
- **THEN** the response is HTTP 200 with `{"data": {"id": "...", "status": "pending", "template_id": "...", "format": "...", "params": {...}}}`

#### Scenario: Processing export
- **WHEN** `GET /api/v1/exports/:id` is called for a processing export
- **THEN** the response is HTTP 200 with `{"data": {"id": "...", "status": "processing", "started_at": "..."}}`

#### Scenario: Completed export
- **WHEN** `GET /api/v1/exports/:id` is called for a completed export
- **THEN** the response is HTTP 200 with `{"data": {"id": "...", "status": "completed", "row_count": N, "format": "...", "download_url": "/api/v1/exports/:id/download", "manifest": {...}, "completed_at": "..."}}`

#### Scenario: Failed export
- **WHEN** `GET /api/v1/exports/:id` is called for a failed export
- **THEN** the response is HTTP 200 with `{"data": {"id": "...", "status": "failed", "error_message": "..."}}`

#### Scenario: Cross-account access denied
- **WHEN** `GET /api/v1/exports/:id` is called with an export ID belonging to a different account
- **THEN** the response is HTTP 404 (do not leak existence)

#### Scenario: Export not found
- **WHEN** `GET /api/v1/exports/:id` is called with a nonexistent ID
- **THEN** the response is HTTP 404

### Requirement: Download completed export (GET /api/v1/exports/:id/download)

`GET /api/v1/exports/:id/download` MUST serve the completed export file with the appropriate `Content-Type` and `Content-Disposition` headers. It MUST return HTTP 404 if the export is not completed or does not belong to the authenticated account. It MUST use `:api_authenticated` pipeline.

#### Scenario: Download completed JSON export
- **WHEN** `GET /api/v1/exports/:id/download` is called for a completed JSON export
- **THEN** the response is HTTP 200 with `Content-Type: application/json` and the export file content

#### Scenario: Download completed CSV export
- **WHEN** `GET /api/v1/exports/:id/download` is called for a completed CSV export
- **THEN** the response is HTTP 200 with `Content-Type: text/csv` and `Content-Disposition: attachment; filename="..."` headers

#### Scenario: Download completed PDF export
- **WHEN** `GET /api/v1/exports/:id/download` is called for a completed PDF export
- **THEN** the response is HTTP 200 with `Content-Type: application/pdf` and `Content-Disposition: attachment; filename="..."` headers

#### Scenario: Export not yet completed
- **WHEN** `GET /api/v1/exports/:id/download` is called for a pending or processing export
- **THEN** the response is HTTP 404

### Requirement: List available templates (GET /api/v1/export-templates)

`GET /api/v1/export-templates` MUST return all registered report templates. It MUST accept an optional `framework` query parameter to filter by framework. The endpoint MUST use `:api_authenticated` pipeline.

#### Scenario: List all templates
- **WHEN** `GET /api/v1/export-templates` is called without filters
- **THEN** the response is HTTP 200 with `{"data": [...]}` containing all registered templates with `id`, `framework`, `name`, `description`, `required_params`, `optional_params`

#### Scenario: Filter by framework
- **WHEN** `GET /api/v1/export-templates?framework=hipaa` is called
- **THEN** the response includes only HIPAA templates

#### Scenario: Unknown framework filter
- **WHEN** `GET /api/v1/export-templates?framework=unknown` is called
- **THEN** the response is HTTP 200 with `{"data": []}` (empty list, not an error)

### Requirement: Compliance exports Ecto schema and migration

A `compliance_exports` table MUST be created with the following columns: `id` (UUID primary key), `account_id` (UUID foreign key to accounts, not null), `template_id` (string, not null), `params` (JSONB, not null, default `{}`), `format` (string, not null), `status` (string, not null, one of `"pending"`, `"processing"`, `"completed"`, `"failed"`), `file_path` (string, nullable), `row_count` (integer, nullable), `integrity_manifest` (JSONB, nullable), `error_message` (string, nullable), `started_at` (utc_datetime_usec, nullable), `completed_at` (utc_datetime_usec, nullable), `inserted_at` and `updated_at` (utc_datetime_usec). An index MUST exist on `(account_id, status)` for efficient polling queries.

`GA.Compliance.Export` MUST be an Ecto schema mapping to this table.

#### Scenario: Create export record
- **WHEN** an export record is inserted with valid fields
- **THEN** it is persisted with `status: "pending"` and timestamps

#### Scenario: Transition to processing
- **WHEN** an Oban worker picks up the export job
- **THEN** the record's `status` is updated to `"processing"` and `started_at` is set

#### Scenario: Transition to completed
- **WHEN** the export finishes successfully
- **THEN** the record's `status` is updated to `"completed"`, `row_count`, `file_path`, `integrity_manifest`, and `completed_at` are set

#### Scenario: Transition to failed
- **WHEN** the export encounters an unrecoverable error
- **THEN** the record's `status` is updated to `"failed"` and `error_message` describes the failure

### Requirement: Async export Oban worker

`GA.Compliance.ExportWorker` MUST be an Oban worker that processes export jobs. It MUST read the export record from the database, load the template, execute the query in batches (default batch size 1000), write output to a file in the configured export directory, compute the integrity manifest, and update the export record on completion or failure. The worker MUST set `status` to `"processing"` when it starts and `"completed"` or `"failed"` when it finishes.

#### Scenario: Successful async export
- **WHEN** the worker processes a pending export job
- **THEN** it transitions through `processing` to `completed`, writes the file, sets `row_count`, `file_path`, and `integrity_manifest`

#### Scenario: Worker handles query error
- **WHEN** the worker encounters a database error during export
- **THEN** it sets `status` to `"failed"` with an appropriate `error_message` and does not leave partial files

#### Scenario: Worker handles template not found
- **WHEN** the worker processes an export with an invalid `template_id` (e.g., template removed between creation and execution)
- **THEN** it sets `status` to `"failed"` with `error_message: "template not found"`

### Requirement: Export query execution

`GA.Compliance.Exporter.execute(template, account_id, params)` MUST build an Ecto query from the template's `filters`, `columns`, `sort_order`, and the provided `params` (including `from`/`to` date range), scoped to the given `account_id`. For templates with `grouping`, it MUST execute an aggregation query. For templates without grouping, it MUST return individual log entries.

#### Scenario: Non-aggregated query
- **WHEN** `execute/3` is called with `hipaa.phi_access` template
- **THEN** it queries `audit_logs` where `account_id` matches, `phi_accessed == true`, `timestamp` is within the date range, selects the template's columns, and orders by template's `sort_order`

#### Scenario: Aggregated query
- **WHEN** `execute/3` is called with `hipaa.system_access_summary` template
- **THEN** it queries `audit_logs` with grouping by date and action, computing `COUNT(*)` and `COUNT(DISTINCT user_id)` aggregates

#### Scenario: Template-specific parameter injection
- **WHEN** `execute/3` is called with `hipaa.user_activity` and `params` includes `actor_id: "user-123"`
- **THEN** the query includes `WHERE user_id = 'user-123'` in addition to template filters

### Requirement: JSON export format

JSON exports MUST produce a JSON object with `template` (template metadata: `id`, `framework`, `name`), `meta` (export metadata: `row_count`, `generated_at`, `account_id`, `from`, `to`), `data` (array of objects, one per entry/row, with keys matching template `columns`), and `manifest` (integrity manifest). Field values MUST be serialized as strings for timestamps and as their native types for others.

#### Scenario: JSON structure
- **WHEN** a JSON export is generated for `hipaa.phi_access` with 3 matching entries
- **THEN** the output is a valid JSON object with `template.id == "hipaa.phi_access"`, `data` is an array of 3 objects each having keys from the template's `columns`, and `manifest` contains integrity fields

### Requirement: CSV export format

CSV exports MUST follow RFC 4180: CRLF line endings, comma-separated values, double-quote escaping for fields containing commas/quotes/newlines. The first row MUST be a header row with column names matching the template's `columns`. Subsequent rows contain entry data in the same column order. The integrity manifest MUST be appended after the data rows as a comment block (lines prefixed with `#`).

#### Scenario: CSV header matches template columns
- **WHEN** a CSV export is generated for `hipaa.phi_access`
- **THEN** the first line is `timestamp,user_id,action,resource_type,resource_id,outcome,source_ip,user_role\r\n`

#### Scenario: CSV special character escaping
- **WHEN** a field value contains a comma
- **THEN** the field is enclosed in double quotes per RFC 4180

#### Scenario: CSV manifest footer
- **WHEN** a CSV export is generated
- **THEN** after the last data row, comment lines starting with `#` contain the integrity manifest as `# key: value` pairs

### Requirement: PDF export format

PDF exports MUST produce a formatted document using `chromic_pdf` with three sections: a **header** (account name, framework, template name, date range, generated_at timestamp), a **data table** (rows and columns matching the template's output), and an **integrity manifest footer** (chain verification status, checkpoint anchors, export checksum). If `chromic_pdf` or a Chrome binary is not available, PDF export requests MUST return HTTP 422 with `{"errors": {"format": ["PDF generation is not available"]}}`.

#### Scenario: PDF contains all sections
- **WHEN** a PDF export is generated
- **THEN** the PDF contains a header with report metadata, a data table, and a footer with the integrity manifest

#### Scenario: PDF unavailable
- **WHEN** a PDF export is requested but `chromic_pdf` is not available
- **THEN** the response is HTTP 422 with a clear error message

### Requirement: OpenAPI annotations

All export endpoints MUST have OpenApiSpex operation annotations with summary, parameters, request body schema, and response schemas so they appear in the generated OpenAPI spec.

#### Scenario: Spec includes export endpoints
- **WHEN** the OpenAPI spec is generated
- **THEN** it includes `POST /api/v1/exports`, `GET /api/v1/exports/:id`, `GET /api/v1/exports/:id/download`, and `GET /api/v1/export-templates` with correct schemas
