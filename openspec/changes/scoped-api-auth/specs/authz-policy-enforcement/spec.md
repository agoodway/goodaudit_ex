## ADDED Requirements

### Requirement: Endpoint-level scope enforcement

Each authenticated API operation MUST declare required scopes and enforce them after authentication succeeds.

#### Scenario: Missing required scope
- **WHEN** a request authenticates successfully but lacks endpoint-required scope
- **THEN** the request is rejected with HTTP 403

### Requirement: Environment-bound key usage

Keys with environment scope constraints MUST be rejected when used outside allowed environment context.

#### Scenario: Cross-environment credential use
- **WHEN** a key scoped to `sandbox` is used against `prod` endpoint context
- **THEN** request is denied with HTTP 403 and audit event is emitted
