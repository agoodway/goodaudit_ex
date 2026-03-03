## ADDED Requirements

### Requirement: Immutable consent provenance capture

Consent-related events MUST capture immutable provenance metadata including capture timestamp, capture source, consent text/version reference, and jurisdiction context.

#### Scenario: Consent capture event
- **WHEN** a consent grant event is ingested
- **THEN** provenance metadata is persisted and included in the signed chain payload

### Requirement: Consent lineage queryability

The system MUST support account-scoped retrieval of consent lineage for a subject or lead identifier.

#### Scenario: Retrieve consent lineage
- **WHEN** a query requests consent history for a lead
- **THEN** events are returned in sequence order with complete provenance fields
