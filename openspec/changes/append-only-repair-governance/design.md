## Context

`audit-schemas` enforces append-only with DB triggers. This remains the default. This change defines rare exception handling with strict governance.

## Goals / Non-Goals

**Goals:**
- Permit emergency repair only through explicit, auditable process
- Preserve chain-of-custody for every exceptional operation
- Enforce mandatory post-repair verification and disclosure metadata

**Non-Goals:**
- Routine mutation of audit records
- Broad admin bypass permissions

## Decisions

### Time-bounded break-glass window
Repairs require an approved, expiring window bound to a specific scope.

### Signed intent artifact
Each repair operation references a signed intent payload with ticket, actor, approver, scope, and reason.

### Mandatory after-action verification
Any repair window closes with verification results and immutable postmortem metadata.

## Risks / Trade-offs

- Operational overhead for emergencies
- Requires disciplined key/identity handling for signatures
