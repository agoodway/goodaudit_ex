## ADDED Requirements

### Requirement: Per-account chain verification endpoint

`POST /api/v1/verify` MUST read the account from `conn.assigns.current_account`, call `GA.Audit.verify_chain(account_id)`, and return HTTP 200 with the verification result map. It MUST work with both public and private keys via the existing `:api_authenticated` pipeline (verification is a read-only operation despite using POST).

#### Scenario: Valid chain
- **WHEN** a POST is made and the account's chain is intact
- **THEN** the response is HTTP 200 with `{"valid": true, "total_entries": N, "verified_entries": N, ...}`

#### Scenario: Tampered chain
- **WHEN** a POST is made and the account's chain has integrity failures
- **THEN** the response is HTTP 200 with `{"valid": false, "first_failure": {...}, ...}`

#### Scenario: Empty chain for account
- **WHEN** a POST is made and no entries exist for the account
- **THEN** the response is HTTP 200 with `{"valid": true, "total_entries": 0, "verified_entries": 0}`

#### Scenario: Account isolation
- **WHEN** verification is triggered with account A's API key
- **THEN** only account A's chain is verified; account B's entries are not included

### Requirement: OpenAPI schema for verification response

The `GAWeb.Schemas.VerificationResponse` schema MUST document the verification result structure including `valid`, `total_entries`, `verified_entries`, `first_failure`, `sequence_gaps`, `checkpoint_results`, and `duration_ms`.

#### Scenario: Schema in spec
- **WHEN** the OpenAPI spec is generated
- **THEN** the verification response schema is included with all fields documented
