## ADDED Requirements

### Requirement: Suppression and opt-out lifecycle events

The system MUST record suppression lifecycle events for opt-out receipt, suppression check execution, and enforcement outcome.

#### Scenario: Suppression hit
- **WHEN** lead routing is blocked due to suppression list match
- **THEN** an immutable event is recorded with reason code and enforcement timestamp

### Requirement: Suppression state evidence

Suppression events MUST include sufficient evidence fields to prove why a lead was blocked or allowed.

#### Scenario: Enforcement audit review
- **WHEN** a compliance reviewer inspects a suppression decision
- **THEN** the event contains decision code, source list reference, and actor context
