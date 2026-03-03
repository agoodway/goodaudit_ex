## ADDED Requirements

### Requirement: Scope requirements on audit endpoints

Audit endpoints MUST enforce explicit scope requirements per operation rather than only key class (`pk_*` or `sk_*`).

#### Scenario: Query-scoped key reads logs
- **WHEN** a key has `query` scope
- **THEN** it can call read endpoints and receives HTTP 200 for authorized requests

#### Scenario: Ingest-only key denied on read
- **WHEN** a key has `ingest` scope only and calls list endpoint
- **THEN** request is rejected with HTTP 403

### Requirement: Scope metadata in OpenAPI docs

OpenAPI operation docs MUST describe required scopes and 403 scope-failure responses.

#### Scenario: OpenAPI scope annotations
- **WHEN** OpenAPI is generated
- **THEN** audit operations include required-scope metadata and 403 response docs
