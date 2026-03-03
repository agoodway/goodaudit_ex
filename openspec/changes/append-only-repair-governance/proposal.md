## Why

Append-only triggers are correct for integrity, but production incidents may require rare, tightly governed repair operations. Today there is no standardized, auditable break-glass process.

## What Changes

1. **Break-glass policy** - Define a controlled workflow for exceptional repair/bypass operations.
2. **Signed intent + approval** - Require signed repair intent with actor, reason, ticket, scope, and expiry.
3. **Audit trail for bypass** - Every bypass operation emits immutable repair audit events.
4. **Post-repair verification** - Mandatory verification/reporting after any repair window.

## Capabilities

### New Capabilities
- `repair-governance`: Controlled, approval-gated append-only bypass workflow
- `repair-audit-trail`: Signed repair intent and immutable event trail

### Modified Capabilities
- `audit-log-table`: Adds governance for exceptional admin operations without weakening default append-only behavior
- `checkpoint-table`: Same governance model for checkpoint table operations

## Impact

- **New files**: governance policy docs, repair command workflow, signed intent schema
- **Modified files**: admin/ops tooling, audit event emitters
- **New tests**: policy enforcement, signed intent validation, post-repair verification requirements
