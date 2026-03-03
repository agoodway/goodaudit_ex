## ADDED Requirements

### Requirement: Controlled key rotation API

The system MUST provide controlled key rotation operations that capture actor identity and reason.

#### Scenario: Rotate key
- **WHEN** an authorized operator triggers rotation for an account with a reason
- **THEN** a new key version is generated, activated, and an audit event is recorded

#### Scenario: Rollback key activation
- **WHEN** an authorized operator rolls back during a cutover window
- **THEN** previous active key is restored and rollback is audit logged

### Requirement: Runbook-backed execution

Rotation operations MUST follow a documented runbook with pre-check, cutover validation, and rollback steps.

#### Scenario: Missing runbook metadata
- **WHEN** a rotation request omits required runbook metadata (ticket/reason/actor)
- **THEN** the operation is rejected
