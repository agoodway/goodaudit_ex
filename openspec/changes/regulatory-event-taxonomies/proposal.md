## Why

The `action` field on audit log entries is currently freeform text. HIPAA, SOC 2, PCI-DSS, and GDPR each define specific event categories that auditors expect to see in compliance reports. Without standardized action taxonomies, customers must invent their own event naming and auditors must manually map freeform actions to regulatory categories. This makes compliance reporting error-prone and increases audit preparation cost.

A per-framework event taxonomy provides standard action vocabularies, maps customer events to regulatory categories, and enables framework-specific reporting out of the box.

## What Changes

1. **Taxonomy registry** — Each compliance framework module (from compliance-framework-profiles) exports an event taxonomy: a tree of categories, subcategories, and standard action names. For example, HIPAA defines `access.phi_read`, `access.phi_write`, `auth.login`, `auth.logout`, `admin.user_provision`; SOC 2 defines `change.deploy`, `change.config_update`, `access.production_access`; PCI-DSS defines `access.cardholder_data`, `access.key_management`; GDPR defines `processing.collection`, `processing.erasure`, `subject_request.access`, `subject_request.portability`.

2. **Action validation mode** — Accounts can operate in `strict` mode (action must match a taxonomy entry for their active frameworks) or `flexible` mode (any action accepted, but non-taxonomy actions are flagged as `uncategorized` in reports). Default is `flexible` for easy adoption.

3. **Action mapping rules** — Accounts can define custom mappings from their internal action names to taxonomy categories. For example, map `"patient_chart_viewed"` to `hipaa:access.phi_read`. Mappings are stored per-account and applied at query/report time, not at ingestion.

4. **Taxonomy-aware queries** — New query filter `category` that matches all actions mapped to a taxonomy category. For example, filtering by `hipaa:access.*` returns all PHI access events regardless of the specific action string.

5. **Taxonomy versioning** — Framework taxonomies are versioned. When a taxonomy is updated, new categories are additive.

## Capabilities

### New Capabilities
- `event-taxonomy-registry`: Per-framework standard event categories and action names
- `action-mapping`: Account-level custom action-to-taxonomy mappings
- `taxonomy-aware-querying`: Filter audit logs by taxonomy category across action names

### Modified Capabilities
- `entry-creation`: Optional strict-mode validation against active framework taxonomies
- `entry-querying`: Support `category` filter that resolves through taxonomy and mappings

## Impact

- **New files**: `lib/app/compliance/taxonomy.ex` (behaviour + registry), `lib/app/compliance/taxonomies/*.ex` (per-framework taxonomy definitions)
- **New file**: `lib/app/compliance/action_mapping.ex` — account-level action mapping management
- **New migration**: `account_action_mappings` table for custom mappings
- **Modified file**: `lib/app/audit.ex` — optional strict validation, category-aware querying
- **New API endpoints**: CRUD for action mappings, taxonomy listing
- **New tests**: strict/flexible validation, mapping resolution, category queries
