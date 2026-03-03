## ADDED Requirements

### Requirement: Domain-neutral actor fields

The `audit_logs` table MUST support domain-neutral actor identity via `actor_type` and `actor_id` and MUST allow system-generated events that do not require `user_id` or `user_role`.

#### Scenario: System actor event
- **WHEN** an event is recorded with `actor_type=system` and no `user_id`
- **THEN** the row is accepted and remains fully verifiable in the chain

### Requirement: Backward compatibility for legacy fields

Existing HIPAA-oriented columns (`user_id`, `user_role`, `phi_accessed`) MUST remain readable and writable for compatibility.

#### Scenario: Legacy event producer
- **WHEN** a producer sends only legacy fields
- **THEN** the event is accepted under compatibility rules without migration errors
