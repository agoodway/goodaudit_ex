## Context

GoodAudit stores tamper-evident audit logs with HMAC chains, checkpoints, and optional external anchoring. Compliance audits (HIPAA, SOC 2, PCI-DSS, GDPR) require specific evidence artifacts — not raw database dumps. Auditors expect pre-formatted reports scoped to their framework: HIPAA auditors need PHI access logs, SOC 2 auditors need change management evidence, PCI-DSS QSAs want cardholder data access logs, and GDPR DPAs require records of processing activities. Today, customers must write their own queries and format their own reports from raw audit log entries. This change adds framework-specific report templates, an export API, and integrity manifests so customers can generate audit-ready evidence packages with a single API call.

## Goals / Non-Goals

**Goals:**
- Report template registry with built-in templates for HIPAA, SOC 2, PCI-DSS, and GDPR
- Export API that accepts a template ID, date range, and optional parameters, returning formatted evidence
- Three output formats: JSON (machine-readable for GRC tool integration), CSV (RFC 4180 for auditor spreadsheets), and PDF (formatted evidence package)
- Each export includes an integrity manifest proving the exported data matches the tamper-evident chain
- Small exports (< 10k rows) return inline; large exports are processed asynchronously via Oban with a polling endpoint
- Templates are structs with well-defined fields — not arbitrary query builders

**Non-Goals:**
- Custom user-defined templates (built-in templates only for now)
- Real-time streaming exports (batch only)
- Email delivery of completed exports (polling/download only)
- Auditor portal or external sharing links
- Template versioning across framework taxonomy versions (templates are static for this change)
- Export scheduling or recurring report generation

## Decisions

### Report templates as structs, not database records

Templates are defined as Elixir structs in code, not stored in a database table. Each template module returns a list of `%GA.Compliance.ReportTemplate{}` structs with `id`, `framework`, `name`, `description`, `required_params`, `optional_params`, `columns`, `filters`, `grouping`, and `sort_order`. This keeps templates version-controlled, testable, and deployable without migrations. Custom user-defined templates can be added later by persisting to a table with the same struct shape.

### Template ID convention: `framework.report_name`

Template IDs use dot notation (`hipaa.phi_access`, `soc2.change_management`) to namespace by framework and make the API self-documenting. The framework prefix allows `GET /api/v1/export-templates` to filter by active frameworks without parsing template metadata.

### date_range always required, other params optional per template

Every template requires `from` and `to` as ISO 8601 datetime parameters. Compliance evidence is always time-bounded. Additional parameters (like `actor_id` for user activity reports) are defined per-template in `required_params` and `optional_params`. The export API validates that all required params are present before executing.

### Inline vs async threshold at 10k rows

Exports under 10,000 rows return HTTP 200 with inline data. Exports over 10,000 rows return HTTP 202 with a job ID for polling. The threshold is checked by running a `COUNT(*)` query with the template's filters before executing the full export. This prevents timeout issues on large date ranges while keeping small exports snappy.

### Async exports via Oban worker and compliance_exports table

Large exports are enqueued as Oban jobs. The `compliance_exports` table tracks job state: `id`, `account_id`, `template_id`, `params` (JSONB), `format`, `status` (pending/processing/completed/failed), `file_path`, `row_count`, `integrity_manifest` (JSONB), `error_message`, `started_at`, `completed_at`. The Oban worker reads entries in batches, writes to a temp file, computes the integrity manifest, and updates the record on completion.

### Export file storage in local filesystem (MVP)

Completed async exports are stored in a configured directory on the local filesystem. The `file_path` column stores the relative path. A future change can swap to S3/GCS by changing the storage backend without altering the API contract. Files are cleaned up after a configurable TTL (default 24 hours).

### CSV follows RFC 4180

CSV exports use standard RFC 4180 formatting: CRLF line endings, double-quote escaping, header row matching the template's `columns` list. This ensures compatibility with Excel, Google Sheets, and common ETL tools.

### PDF includes header, data table, and integrity manifest footer

PDF exports use `chromic_pdf` (Chrome-based HTML-to-PDF rendering). Each PDF has: a header section (account name, framework, template name, date range, generated_at timestamp), a data table section matching the template columns, and a footer section showing the integrity manifest (chain verification status, checkpoint anchors, export checksum). This provides a single self-contained evidence document.

### Integrity manifest embedded in every export

Every export — regardless of format — includes an integrity manifest containing: the chain verification result for the exported date range, checkpoint anchors that fall within the range, the SHA-256 checksum of the export content, the generation timestamp, and the GoodAudit version. For JSON, the manifest is a top-level key. For CSV, it's appended as a comment block. For PDF, it's rendered as a footer section.

### Export API uses existing auth pipelines

`POST /api/v1/exports` requires write access (`sk_*` key) via `:api_write` because it creates a resource (the export job). `GET /api/v1/exports/:id` and `GET /api/v1/export-templates` use `:api_authenticated` (either key type). Account scoping comes from the API key as with all other endpoints.

### Template columns reference Log schema fields and metadata paths

Template `columns` are an ordered list of field references. Top-level fields (e.g., `timestamp`, `action`, `outcome`) map directly to `GA.Audit.Log` schema fields. Nested fields (e.g., `metadata.hipaa.phi_accessed`) use dot-path notation and are extracted from the `metadata` JSONB column. This avoids coupling templates to a specific schema extension approach.

## Risks / Trade-offs

### PDF generation requires Chrome/Chromium

`chromic_pdf` needs a Chrome or Chromium binary available at runtime. This adds an infrastructure dependency. Mitigation: PDF is an optional format — JSON and CSV work without it. If Chrome is not available, PDF export requests return a clear error rather than crashing.

### Large exports consume memory during batch processing

Even with batched reads, very large exports (millions of rows) accumulate data in the output file. Mitigation: the Oban worker streams batches to the file incrementally and does not hold the full dataset in memory. The row count from the pre-check COUNT query can be used to reject exports over a hard ceiling (configurable, default 1M rows).

### Integrity manifest verification adds latency

Running chain verification for the exported date range adds time to export generation. For small exports this is negligible. For large ranges, verification is the bottleneck. Mitigation: the manifest includes verification of the chain segment within the exported range, not the full chain. Checkpoint anchors are included if they exist but their absence does not block the export.

### File cleanup requires a scheduled job

Async export files accumulate on disk until cleaned up. A separate cleanup job (Oban cron or similar) must be configured to delete expired exports. Forgetting this leads to disk exhaustion. Mitigation: the `completed_at` timestamp and configurable TTL make cleanup straightforward, and the migration documentation calls it out.

## Migration Plan

1. Add `compliance_exports` table migration with status enum, params JSONB, and integrity_manifest JSONB.
2. Deploy report template registry and export modules (no database changes needed for templates).
3. Add export API routes and controller.
4. Add Oban worker for async exports.
5. Configure export file storage directory and cleanup job.
6. Enable PDF export after verifying Chrome/Chromium is available in deployment environment.

## Open Questions

- Should there be an API endpoint to delete/cancel a pending export job?
- Should the row count ceiling for exports be configurable per-account or global?
- Should completed export files be encrypted at rest?
