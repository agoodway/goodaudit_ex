## ADDED Requirements

### Requirement: Create audit log entry (account-scoped, write access)

`POST /api/v1/audit-logs` MUST accept a JSON body with audit log fields, read the account from `conn.assigns.current_account`, call `GA.Audit.create_log_entry(account_id, attrs)`, and return HTTP 201 with the created entry including chain fields. The endpoint MUST accept flat params (no wrapping key required). It MUST require a private API key (`sk_*`) via the existing `:api_write` pipeline.

#### Scenario: Successful creation
- **WHEN** a valid POST is made with a private key and required fields (user_id, user_role, action, resource_type, resource_id)
- **THEN** the response is HTTP 201 with `{"data": {...}}` containing the entry with sequence_number, checksum, and account_id

#### Scenario: Validation error
- **WHEN** a POST is made with missing required fields
- **THEN** the response is HTTP 422 with `{"errors": {...}}`

#### Scenario: Unauthorized
- **WHEN** a POST is made without a valid bearer token
- **THEN** the response is HTTP 401

#### Scenario: Read-only key rejected
- **WHEN** a POST is made with a public key (`pk_*`)
- **THEN** the response is HTTP 403 (write access required)

### Requirement: List audit log entries (account-scoped, read access)

`GET /api/v1/audit-logs` MUST return paginated entries **for the authenticated account only**. It MUST accept query parameters: `after_sequence`, `limit`, `user_id`, `action`, `resource_type`, `resource_id`, `outcome`, `phi_accessed`, `from`, `to`. The response MUST include a `meta` object with `next_cursor` and `count`. It MUST work with both public (`pk_*`) and private (`sk_*`) keys via the existing `:api_authenticated` pipeline.

#### Scenario: Paginated list
- **WHEN** a GET request is made with `limit=10`
- **THEN** the response is HTTP 200 with `{"data": [...], "meta": {"next_cursor": N, "count": 10}}` — only entries for the authenticated account

#### Scenario: Filtered list
- **WHEN** a GET request includes `user_id=user-1&action=read`
- **THEN** only matching entries within the authenticated account are returned

#### Scenario: Empty result
- **WHEN** filters match no entries for the account
- **THEN** the response is HTTP 200 with `{"data": [], "meta": {"next_cursor": null, "count": 0}}`

#### Scenario: Account isolation
- **WHEN** account A's API key is used to list audit logs
- **THEN** no entries from account B are returned

### Requirement: Get single audit log entry (account-scoped, read access)

`GET /api/v1/audit-logs/:id` MUST return a single entry by UUID, verified against the authenticated account. It MUST return HTTP 404 if the entry does not exist or belongs to a different account.

#### Scenario: Entry found
- **WHEN** a GET request is made with a valid entry ID belonging to the authenticated account
- **THEN** the response is HTTP 200 with `{"data": {...}}`

#### Scenario: Entry not found
- **WHEN** a GET request is made with a nonexistent UUID
- **THEN** the response is HTTP 404

#### Scenario: Cross-account access denied
- **WHEN** a GET request is made with an entry ID belonging to a different account
- **THEN** the response is HTTP 404 (not 403 — do not leak existence)

### Requirement: Parameter parsing

The controller MUST parse query string parameters into the correct types: integers for `after_sequence` and `limit`, boolean for `phi_accessed`, ISO 8601 datetime for `from` and `to`.

#### Scenario: Type coercion
- **WHEN** `after_sequence=50&limit=25&phi_accessed=true` is passed as query params
- **THEN** the values are parsed as integer 50, integer 25, and boolean true before passing to the context

### Requirement: OpenAPI annotations

All audit log endpoints MUST have OpenApiSpex operation annotations with summary, parameters, request body schema, and response schemas so they appear in the generated OpenAPI spec.

#### Scenario: Spec includes endpoints
- **WHEN** the OpenAPI spec is generated
- **THEN** it includes all three audit log endpoints with correct schemas
