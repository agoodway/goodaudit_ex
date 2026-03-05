## Why

GoodAudit is currently designed exclusively around HIPAA compliance requirements. The HIPAA field set (phi_accessed, user_role, source_ip, etc.) is hardcoded into the audit log schema and chain computation. Organizations operating under SOC 2, PCI-DSS, GDPR, ISO 27001, FedRAMP, or multiple overlapping frameworks cannot use GoodAudit without carrying HIPAA-specific baggage or missing framework-specific requirements.

A compliance framework profile system lets each account declare which standards it operates under, and GoodAudit adapts its behavior — required fields, validation rules, retention defaults, verification cadence, and reporting templates — accordingly. This transforms GoodAudit from a HIPAA audit logger into a multi-framework compliance platform.

## What Changes

1. **Framework registry** — Define a `GA.Compliance.Framework` behaviour and ship built-in implementations for HIPAA, SOC 2 Type II, PCI-DSS v4, GDPR, and ISO 27001. Each framework module declares its required fields, recommended fields, default retention period, verification cadence, and event taxonomy namespace.

2. **Account framework associations** — New `account_compliance_frameworks` join table linking accounts to one or more active frameworks. Accounts can operate under multiple frameworks simultaneously (e.g., HIPAA + SOC 2 for a healthcare SaaS).

3. **Framework-aware validation** — Audit log entry creation validates that all required fields for the account's active frameworks are present. Missing required fields return a 422 with framework-specific error messages indicating which standard requires the field.

4. **Framework defaults on account creation** — When an account activates a framework, apply sensible defaults: retention window, checkpoint frequency, required field set. These can be overridden per-account.

5. **Framework metadata on entries** — Each audit log entry records which framework(s) were active at creation time in a `frameworks` field, ensuring historical entries remain correctly attributed even if the account changes frameworks later.

## Capabilities

### New Capabilities
- `compliance-framework-registry`: Pluggable framework definitions with required fields, retention, and validation rules
- `account-framework-association`: Multi-framework account configuration with defaults and overrides
- `framework-aware-validation`: Entry creation validates against active framework requirements

### Modified Capabilities
- `entry-creation`: Validate required fields against account's active frameworks before chain insertion
- `audit-log-table`: Add `frameworks` column to record active frameworks at entry creation time

## Impact

- **New files**: `lib/app/compliance/framework.ex` (behaviour), `lib/app/compliance/frameworks/*.ex` (HIPAA, SOC2, PCI-DSS, GDPR, ISO 27001)
- **New file**: `lib/app/compliance.ex` — context module for framework management
- **New migration**: `account_compliance_frameworks` join table, `frameworks` column on `audit_logs`
- **Modified file**: `lib/app/audit.ex` — entry creation validates against active frameworks
- **Modified file**: `lib/app/audit/chain.ex` — canonical payload includes frameworks field
- **Modified files**: `lib/app_web/schemas/audit_log_response.ex`, `audit_log_list_response.ex` — add `frameworks` field to response schemas
- **New tests**: framework validation, multi-framework accounts, historical framework attribution, OpenAPI schema correctness
