## ADDED Requirements

### Requirement: Taxonomy fields in API contracts

`POST /api/v1/audit-logs` MUST accept taxonomy fields (`event_type`, `event_family`, `decision_reason_code`) and MUST return them in audit log responses.

#### Scenario: Create event with taxonomy fields
- **WHEN** a valid create request includes taxonomy fields
- **THEN** the response includes the same canonical values in `data`

### Requirement: OpenAPI taxonomy enum publication

The generated OpenAPI spec MUST document taxonomy and reason-code enums used by audit endpoints.

#### Scenario: OpenAPI includes taxonomy enums
- **WHEN** OpenAPI is generated
- **THEN** taxonomy-related schema properties include enum constraints
