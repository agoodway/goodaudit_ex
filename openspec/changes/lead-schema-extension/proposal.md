## Why

The current audit schema is HIPAA-oriented and assumes user-driven events (`user_id`, `user_role`, `phi_accessed`) as first-class requirements. Lead generation and distribution systems are predominantly system-to-system flows that need durable identifiers for lead objects, routing decisions, partner entities, and compliance evidence without overfitting to PHI semantics.

## What Changes

1. **Domain-neutral base fields** - Generalize the event model so required fields support both human and system actors.
2. **Lead distribution dimensions** - Add first-class columns for lead flow context (for example: `lead_id`, `source_id`, `buyer_id`, `campaign_id`, `vertical`, `delivery_channel`).
3. **Decision evidence fields** - Add structured fields for routing/bid outcomes (decision code, reason, and policy version) while keeping append-only integrity.
4. **Versioned extensibility contract** - Define a schema version field and compatibility rules so producers can evolve payload shape safely.
5. **Backward compatibility path** - Keep existing HIPAA-oriented fields supported, but no longer mandatory for non-HIPAA workloads.

## Capabilities

### New Capabilities
- `lead-schema-dimensions`: First-class schema support for lead distribution entities and routing context
- `event-schema-versioning`: Versioned event schema contract for forward-compatible ingestion

### Modified Capabilities
- `audit-log-table`: Generalize required/optional field model beyond HIPAA-specific assumptions
- `entry-creation`: Validate and stamp schema version and lead dimensions on write

## Impact

- **Modified files**: audit log migration/schema modules and validation logic
- **New files**: schema contract docs and compatibility matrix
- **New tests**: field compatibility, required-field profiles, and migration/backfill safety
