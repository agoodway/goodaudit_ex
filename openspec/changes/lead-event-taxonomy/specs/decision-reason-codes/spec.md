## ADDED Requirements

### Requirement: Machine-readable decision reason codes

Routing, suppression, and delivery outcomes MUST support a normalized `decision_reason_code` field from a controlled catalog.

#### Scenario: Route rejection with reason code
- **WHEN** a routing event is recorded with rejection outcome
- **THEN** `decision_reason_code` is present and maps to a documented catalog value

### Requirement: Cataloged outcome model

Outcome values MUST support `success`, `failure`, and `partial` for multi-step lead processing.

#### Scenario: Partial delivery outcome
- **WHEN** a batch delivery operation partially succeeds
- **THEN** the persisted outcome is `partial` with supporting reason code
