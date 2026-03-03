## ADDED Requirements

### Requirement: DSAR lifecycle tracking

The system MUST track DSAR workflows with lifecycle states (received, validated, in_progress, completed, rejected) and SLA timestamps.

#### Scenario: DSAR completion
- **WHEN** a DSAR is completed
- **THEN** completion state, actor, timestamp, and evidence reference are persisted and auditable

### Requirement: DSAR action evidence

Each DSAR state transition MUST emit a corresponding immutable audit event linked to the DSAR record.

#### Scenario: DSAR rejected
- **WHEN** a DSAR is rejected due to validation failure
- **THEN** an audit event records rejection reason and reviewer identity
