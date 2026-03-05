## Why

Compliance audits require specific evidence artifacts — not raw database dumps. HIPAA auditors expect access reports showing who viewed PHI and when. SOC 2 auditors need change management evidence with approval chains. PCI-DSS QSAs want cardholder data access logs in specific formats. GDPR DPAs expect records of processing activities (ROPA) and data subject request fulfillment logs.

Currently, customers must write their own queries and format their own reports from raw audit log data. Framework-specific export templates let customers generate audit-ready evidence packages with one API call, reducing audit preparation from weeks to minutes.

## What Changes

1. **Report template registry** — Each compliance framework module defines report templates. A template specifies: name, description, required filters (date range, resource scope), query parameters, column selection, grouping/aggregation, and output format. Templates are versioned alongside framework taxonomy versions.

2. **Built-in report templates per framework**:
   - **HIPAA**: PHI Access Report, User Activity Report, Failed Authentication Report, System Access Summary, Minimum Necessary Compliance Report
   - **SOC 2**: Change Management Evidence, Production Access Log, Incident Response Timeline, Control Activity Summary
   - **PCI-DSS**: Cardholder Data Access Log, Key Management Activity Report, Network Access Log, Privileged User Activity
   - **GDPR**: Records of Processing Activities (ROPA), Data Subject Request Log, Consent Activity Report, Cross-Border Transfer Log, Data Breach Notification Timeline

3. **Export API endpoints** — `POST /api/v1/exports` accepts a template ID, date range, and optional scope filters. Returns a streaming export in the requested format (JSON, CSV, PDF). Large exports are processed asynchronously with a polling endpoint for status.

4. **Export formats** — JSON (machine-readable, for integration with GRC tools), CSV (spreadsheet-compatible for auditor review), and PDF (formatted evidence package with chain verification summary, timestamp certification, and optional external anchor proof).

5. **Evidence integrity** — Each export includes a verification manifest: the chain verification result for the exported range, checkpoint anchoring status, and a checksum of the export file itself. This proves the exported data matches the tamper-evident chain.

## Capabilities

### New Capabilities
- `report-template-registry`: Framework-specific report templates with query definitions and output formats
- `compliance-export-api`: API endpoints for generating and downloading compliance evidence exports
- `evidence-integrity-manifest`: Export-level verification proving data integrity from chain through export

### Modified Capabilities
- `entry-querying`: Report templates leverage existing query infrastructure with template-defined filters

## Impact

- **New files**: `lib/app/compliance/report_template.ex` (behaviour + registry), `lib/app/compliance/templates/*.ex` (per-framework templates)
- **New file**: `lib/app/compliance/exporter.ex` — export orchestration (query, format, verify, package)
- **New files**: `lib/app_web/controllers/api/v1/export_controller.ex`, `export_json.ex`
- **New migration**: `compliance_exports` table for async export job tracking
- **Modified file**: `lib/app_web/router.ex` — add export routes
- **New dependency**: PDF generation library (e.g., `chromic_pdf` or `pdf_generator`)
- **New tests**: template rendering, export integrity manifest, async export lifecycle, format correctness
