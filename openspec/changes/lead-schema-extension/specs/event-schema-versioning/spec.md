## ADDED Requirements

### Requirement: Event schema version stamping

Every created audit event MUST include a `schema_version` value. If no version is supplied, the system MUST stamp the current default version.

#### Scenario: Version omitted by producer
- **WHEN** create audit log is called without `schema_version`
- **THEN** the persisted row includes `schema_version` set to the platform default

### Requirement: Version compatibility enforcement

The write path MUST reject unsupported schema versions with a validation error that identifies the unsupported version.

#### Scenario: Unsupported version submitted
- **WHEN** an event is submitted with `schema_version` not in the allowed set
- **THEN** the request fails with HTTP 422 and an error on `schema_version`
