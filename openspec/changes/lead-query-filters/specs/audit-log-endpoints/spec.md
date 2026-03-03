## ADDED Requirements

### Requirement: Lead filter query params in endpoint contract

`GET /api/v1/audit-logs` MUST accept and document lead-oriented query parameters introduced by this change.

#### Scenario: Endpoint accepts lead filter params
- **WHEN** a request includes supported lead filter query params
- **THEN** params are parsed and applied before delegating to context querying

### Requirement: Query diagnostics metadata

Response `meta` MUST include applied filters, effective limit, and cursor mode diagnostics for client verification.

#### Scenario: Meta includes diagnostics
- **WHEN** filtered list endpoint responds
- **THEN** `meta` includes normalized applied filter keys and effective pagination controls
