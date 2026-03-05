## Context

The `action` field on audit log entries is currently freeform text validated against a fixed allowlist (`create`, `read`, `update`, `delete`, `export`, `login`, `logout`). Compliance frameworks like HIPAA, SOC 2, PCI-DSS, GDPR, and ISO 27001 each define specific event categories that auditors expect in compliance reports. Without standardized action taxonomies tied to these frameworks, customers must invent their own event naming and auditors must manually map freeform actions to regulatory categories. This increases audit preparation cost and makes compliance reporting error-prone.

GoodAudit already has per-account HMAC chains, checkpoints, and scoped API keys. This change adds a per-framework event taxonomy layer that provides standard action vocabularies, allows accounts to map their custom events to regulatory categories, and enables framework-specific querying.

## Goals / Non-Goals

**Goals:**
- Define per-framework event taxonomies as structured category/subcategory/action trees.
- Allow accounts to map custom action names to taxonomy paths.
- Support strict and flexible validation modes per account per framework.
- Enable taxonomy-aware queries that resolve categories through mappings.
- Version taxonomies so updates are additive.

**Non-Goals:**
- Replacing the existing freeform `action` field or breaking existing integrations.
- Enforcing strict mode by default (flexible is the default for easy adoption).
- Building a UI for taxonomy browsing or mapping management (API only).
- Per-entry taxonomy resolution at ingestion time (resolution happens at query/report time).
- Cross-framework taxonomy unification (each framework maintains its own tree).

## Decisions

### Taxonomy as module-level data structures

Each compliance framework has a dedicated Elixir module under `GA.Compliance.Taxonomies` (e.g., `GA.Compliance.Taxonomies.HIPAA`). Each module implements the `GA.Compliance.Taxonomy` behaviour, exporting a taxonomy as a three-level map: `%{category => %{subcategory => [action_names]}}`. This keeps taxonomy definitions in code (version-controlled, testable, no runtime DB dependency) while the behaviour contract ensures consistency.

### Three-level taxonomy hierarchy

Taxonomies use a fixed three-level hierarchy: category, subcategory, action. Paths are expressed as dot-separated strings (e.g., `"access.phi.phi_read"`). This provides enough granularity for regulatory reporting without the complexity of arbitrary-depth trees. The string path format enables pattern matching in queries (e.g., `"access.*"` matches all access subcategories and actions).

### Action mappings stored per-account, resolved at query time

Custom action-to-taxonomy mappings are stored in the `account_action_mappings` table with `account_id`, `custom_action`, `framework`, and `taxonomy_path`. Mappings are applied at query/report time, not at ingestion. This means ingestion performance is unaffected, mappings can be retroactively applied to historical data, and the same audit log entry can be categorized differently across frameworks.

### Validation modes on the account-framework join

Per-account validation mode (`flexible` or `strict`) is stored on the `account_compliance_frameworks` join table as `action_validation_mode`. In `flexible` mode (default), any action string is accepted and non-taxonomy actions are flagged as `uncategorized` in reports. In `strict` mode, `create_log_entry/2` rejects actions that don't match a taxonomy entry or have an explicit mapping for the account's active frameworks.

### Category query filter with glob-style resolution

`list_logs/2` gains a `category` filter that accepts patterns like `"hipaa:access.*"`. Resolution: parse the framework prefix and pattern, look up taxonomy paths matching the pattern, find all custom actions mapped to those paths, then filter `audit_logs` where `action IN (taxonomy_actions ++ mapped_custom_actions)`. This is a read-time expansion — no denormalized columns needed.

### Taxonomy versioning via module-level version function

Each taxonomy module declares `taxonomy_version/0` returning a semantic version string. The `account_action_mappings` table includes a `taxonomy_version` column recording which version the mapping was created against. Taxonomy updates are additive only -- new actions are added, existing actions are never renamed or removed.

## Risks / Trade-offs

- [Category query performance on large datasets] -> Taxonomy path resolution expands to an `action IN (...)` clause. For frameworks with many actions and accounts with many mappings, this list can grow. Mitigation: the expansion is bounded by the taxonomy size (tens of actions, not thousands), and the `action` column already has an index from existing filter support.
- [Strict mode blocks ingestion on misconfiguration] -> If an account enables strict mode without mapping their custom actions first, legitimate audit entries will be rejected. Mitigation: provide a dry-run validation endpoint that checks all recent actions against active frameworks before enabling strict mode.
- [Taxonomy version upgrades and existing mappings] -> Taxonomy updates follow an additive-only policy. Existing paths are never removed or renamed, so mappings remain valid across versions.
- [Multiple framework taxonomies may have overlapping semantics] -> An action like "login" exists in HIPAA, SOC 2, PCI-DSS, and ISO 27001 taxonomies with slightly different paths. Mitigation: mappings are per-framework, so one custom action can map to different paths in each framework. No cross-framework deduplication is attempted.

## Migration Plan

1. Create `account_compliance_frameworks` join table with `account_id`, `framework`, `action_validation_mode` (default `:flexible`), and `enabled_at`.
2. Create `account_action_mappings` table with `account_id`, `custom_action`, `framework`, `taxonomy_path`, `taxonomy_version`, `created_at`. Unique index on `[account_id, custom_action, framework]`.
3. Implement taxonomy behaviour and per-framework taxonomy modules.
4. Add mapping CRUD to `GA.Compliance` context and expose via API endpoints.
5. Integrate `category` filter into `list_logs/2` query pipeline.
6. Add optional strict-mode validation to `create_log_entry/2`.
7. Add taxonomy listing and mapping validation endpoints.
8. Create OpenApiSpex schema modules for taxonomy and action mapping request/response types, and add operation annotations to all new controllers.

## Open Questions

- Should the `account_compliance_frameworks` table be added in this change or does it already exist from a prior compliance-framework-profiles change?
- Should category queries support multi-framework patterns (e.g., `"hipaa:access.* OR soc2:access.*"`) or only single-framework patterns at launch?
