## ADDED Requirements

### Requirement: Entry creation stamps actor and schema fields

`create_log_entry(account_id, attrs)` MUST validate and persist `actor_type`, `actor_id`, and `schema_version` when present, and MUST apply defaults when omitted.

#### Scenario: Actor and version supplied
- **WHEN** a valid write includes `actor_type`, `actor_id`, and `schema_version`
- **THEN** the created row stores those values and returns them in the response payload

#### Scenario: Actor omitted
- **WHEN** actor fields are omitted
- **THEN** entry creation applies default actor semantics and still succeeds

### Requirement: Chain payload includes new deterministic fields

Checksum computation MUST include newly introduced lead and actor fields in deterministic canonical order.

#### Scenario: Field mutation detection
- **WHEN** a persisted lead dimension value is changed out of band
- **THEN** subsequent verification detects checksum mismatch
