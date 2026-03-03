## Why

Current action/outcome enums are too narrow for lead marketplaces and distribution pipelines. Teams need a stable, shared event vocabulary for capture, enrichment, scoring, deduplication, suppression checks, bidding, routing, delivery, retries, acknowledgements, and disputes.

## What Changes

1. **Canonical event taxonomy** - Define a controlled event type set for lead lifecycle stages with explicit semantics.
2. **Outcome and reason code model** - Introduce normalized success/failure/partial outcomes plus machine-readable reason codes.
3. **Actor model expansion** - Support actor types (`user`, `system`, `partner`, `policy`) and actor identifiers for automation-heavy workflows.
4. **Taxonomy governance** - Establish change control, deprecation policy, and compatibility guarantees for event type evolution.
5. **OpenAPI/schema alignment** - Expose taxonomy enums and reason code catalogs through API documentation.

## Capabilities

### New Capabilities
- `lead-event-taxonomy`: Canonical event types for end-to-end lead lifecycle auditing
- `decision-reason-codes`: Standardized reason/outcome coding for routing and compliance analysis

### Modified Capabilities
- `audit-log-endpoints`: Validate and document taxonomy fields in request/response schemas
- `entry-creation`: Enforce allowed event types and actor model constraints

## Impact

- **Modified files**: audit schema enums, controller/schema validators, OpenAPI schema modules
- **New files**: taxonomy catalog docs and version/deprecation policy
- **New tests**: enum validation, backward compatibility, and unknown-type handling
