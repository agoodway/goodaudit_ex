## ADDED Requirements

### Requirement: Endpoint surface for all ingestion modes

The API MUST expose mode-specific ingestion endpoints for single write, bulk write, and webhook intake, each with OpenAPI-documented request/response schemas.

#### Scenario: OpenAPI lists ingestion modes
- **WHEN** OpenAPI is generated
- **THEN** single, bulk, and webhook ingestion operations appear with mode-specific schemas

### Requirement: Consistent error envelope across modes

All ingestion endpoints MUST return consistent error envelopes for validation, auth, rate-limit, and idempotency conflicts.

#### Scenario: Validation error in bulk mode
- **WHEN** bulk ingestion includes invalid items
- **THEN** response includes standard error structure plus per-item validation details
