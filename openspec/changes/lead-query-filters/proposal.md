## Why

Current query filters are generic and do not support common lead operations investigations. Teams need fast, account-scoped retrieval by routing path, commercial outcome, partner entities, and consent state to debug delivery issues, reconcile billing, and answer compliance requests.

## What Changes

1. **Lead-domain filter set** - Add filters for lead, source, buyer, campaign, vertical, decision code, and delivery channel.
2. **Lifecycle and status slicing** - Add filters for event type families, retry state, dedup status, and suppression/consent outcomes.
3. **Windowed and compound querying** - Support composable filters with stable pagination semantics.
4. **Index strategy for lead workloads** - Add index requirements tuned for high-cardinality lead dimensions while preserving account isolation.
5. **Response metadata extensions** - Add query diagnostics metadata (applied filters, bounded limits, cursor mode) for client correctness.

## Capabilities

### New Capabilities
- `lead-query-filters`: Account-scoped filtering by lead lifecycle and routing dimensions
- `lead-query-indexing`: Query/index contract for predictable performance on lead-oriented dimensions

### Modified Capabilities
- `entry-querying`: Extend filter grammar and pagination behavior for lead-specific predicates
- `audit-log-endpoints`: Expose and document expanded filter parameters and response metadata

## Impact

- **Modified files**: context query builder, endpoint param parsing, OpenAPI schemas, DB indexes
- **New files**: filter reference docs and query compatibility notes
- **New tests**: combined-filter correctness, cross-account isolation under expanded predicates, and index-backed performance checks
