## ADDED Requirements

### Requirement: Approval-gated break-glass bypass

Any append-only bypass operation MUST be approval-gated, scope-limited, and time-bounded.

#### Scenario: Missing approval
- **WHEN** an operator attempts a bypass without required approval metadata
- **THEN** the bypass request is rejected

#### Scenario: Expired window
- **WHEN** a bypass operation is attempted after window expiry
- **THEN** the operation is rejected

### Requirement: Signed intent and immutable repair trail

Each repair operation MUST reference a signed intent artifact and emit immutable audit events.

#### Scenario: Repair executed
- **WHEN** a repair operation is executed
- **THEN** repair-start and repair-end events are recorded with actor, scope, and ticket linkage

### Requirement: Mandatory post-repair verification

Repair workflows MUST require post-repair chain verification before closure.

#### Scenario: Verification missing
- **WHEN** a repair workflow attempts closure without verification results
- **THEN** closure is rejected
