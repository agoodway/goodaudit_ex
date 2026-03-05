## Why

The audit log schema hardcodes HIPAA-specific fields (`phi_accessed`, `user_role`, `source_ip`, `session_id`, `failure_reason`) as top-level columns. This creates two problems: (1) non-HIPAA users carry unused columns and pay for indexes they don't need, and (2) other frameworks' required fields (PCI's `cardholder_data_accessed`, SOC 2's `change_ticket_id`, GDPR's `legal_basis`, `data_subject_id`) have nowhere to live except the untyped `metadata` JSONB blob.

The schema should separate universal audit fields that every framework needs from framework-specific extension fields that are validated and queryable but only present when relevant.

## What Changes

1. **Universal core fields** — Keep as top-level columns: `account_id`, `sequence_number`, `checksum`, `previous_checksum`, `actor_id`, `action`, `resource_type`, `resource_id`, `outcome`, `timestamp`, `metadata`. These are the "who did what to which thing and when" fields every audit standard requires.

2. **Extension fields via typed JSONB** — Replace `phi_accessed`, `user_role`, `source_ip`, `session_id`, `failure_reason`, `user_agent` with a validated `extensions` JSONB column. Framework modules (from compliance-framework-profiles) define JSON schemas for their extension fields. Validation happens at the application layer before insertion.

3. **Extension field indexing** — GIN index on `extensions` for framework-specific queries. Partial indexes for high-value extension paths (e.g., `extensions->'hipaa'->>'phi_accessed'` for HIPAA accounts).

4. **Canonical payload update** — The HMAC chain canonical format includes extensions in a deterministic sorted representation.

## Capabilities

### New Capabilities
- `extension-field-schema`: Typed, validated JSONB extension fields driven by compliance framework definitions
- `extension-field-indexing`: GIN and partial indexes for queryable extension fields

### Modified Capabilities
- `audit-log-table`: Schema uses universal core fields + extensions JSONB
- `entry-creation`: Validate extensions against active framework schemas before insertion
- `entry-querying`: Support filtering on extension fields via JSONB path queries
- `hmac-chain`: Canonical payload format uses universal core + sorted extensions

## Impact

- **Migration**: Schema includes `extensions` JSONB column and `actor_id` column from the start
- **Modified file**: `lib/app/audit/log.ex` — schema uses core fields + extensions
- **Modified file**: `lib/app/audit/chain.ex` — canonical payload format uses extensions
- **Modified file**: `lib/app/audit.ex` — entry creation and querying use extensions
- **New file**: `lib/app/compliance/extension_schema.ex` — JSON schema validation for framework extensions
- **New tests**: extension validation, chain integrity, extension querying
