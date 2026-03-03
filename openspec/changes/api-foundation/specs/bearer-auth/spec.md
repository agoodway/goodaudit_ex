## ALREADY IMPLEMENTED — No Changes Required

The following requirements are met by the existing `GAWeb.Plugs.ApiAuth` implementation, which is **superior** to the original spec (per-account API keys instead of a single env-var key).

### Requirement: Bearer token authentication (IMPLEMENTED)

`GAWeb.Plugs.ApiAuth` extracts the bearer token from the `Authorization` header and validates it against the `api_keys` table via `GA.Accounts.verify_api_token/1`. Valid tokens resolve the associated account, user, and account_user. Invalid or missing tokens halt with HTTP 401.

#### Scenario: Valid token
- **WHEN** a request includes `Authorization: Bearer <valid-api-key>`
- **THEN** the request passes through with `current_account`, `current_user`, `current_account_user`, and `current_api_key` assigned to conn

#### Scenario: Missing header
- **WHEN** a request has no `Authorization` header
- **THEN** the plug returns HTTP 401

#### Scenario: Invalid token
- **WHEN** a request includes `Authorization: Bearer wrong-key`
- **THEN** the plug returns HTTP 401

#### Scenario: Expired or revoked key
- **WHEN** a request includes a valid-format token that has been revoked or expired
- **THEN** the plug returns HTTP 401

#### Scenario: Suspended account
- **WHEN** a valid API key belongs to a suspended account
- **THEN** the plug returns HTTP 401

### Requirement: Write access enforcement (IMPLEMENTED)

`GAWeb.Plugs.ApiAuth.require_write_access/2` ensures the API key is a private key (`sk_*`). Public keys (`pk_*`) are read-only.

#### Scenario: Private key allows write
- **WHEN** a request uses a private key (`sk_*`) on a write endpoint
- **THEN** the request passes through

#### Scenario: Public key denied write
- **WHEN** a request uses a public key (`pk_*`) on a write endpoint
- **THEN** the plug returns HTTP 403

### Requirement: Multi-tenant API key system (IMPLEMENTED)

API keys are stored in the `api_keys` table, scoped to `account_users` (user+account pair). Keys are created via `GA.Accounts.create_api_key/2` and managed per-account. No env-var configuration needed.
