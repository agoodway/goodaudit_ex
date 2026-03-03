## ADDED Requirements

### Requirement: Create checkpoint (account-scoped, write access)

`POST /api/v1/checkpoints` MUST read the account from `conn.assigns.current_account`, call `GA.Audit.create_checkpoint(account_id)`, and return HTTP 201 with the created checkpoint. If no audit entries exist for the account, it MUST return HTTP 422 via the fallback controller. It MUST require a private API key (`sk_*`) via the existing `:api_write` pipeline.

#### Scenario: Successful checkpoint creation
- **WHEN** a POST is made with a private key and audit entries exist for the account
- **THEN** the response is HTTP 201 with `{"data": {...}}` containing sequence_number, checksum, verified_at (nullable), account_id, and anchoring metadata fields when available (for example `signature`, `signing_key_id`)

#### Scenario: No entries for account
- **WHEN** a POST is made but no audit entries exist for the authenticated account
- **THEN** the response is HTTP 422 with `{"status": 422, "message": "No audit entries exist yet"}`

#### Scenario: Read-only key rejected
- **WHEN** a POST is made with a public key (`pk_*`)
- **THEN** the response is HTTP 403

### Requirement: List checkpoints (account-scoped, read access)

`GET /api/v1/checkpoints` MUST return all checkpoints **for the authenticated account only**, ordered by sequence_number descending. It MUST work with both public and private keys via the existing `:api_authenticated` pipeline.

#### Scenario: Checkpoint list
- **WHEN** a GET request is made
- **THEN** the response is HTTP 200 with `{"data": [...]}` — only checkpoints for the authenticated account

#### Scenario: Account isolation
- **WHEN** account A's API key is used to list checkpoints
- **THEN** no checkpoints from account B are returned

### Requirement: Checkpoint JSON rendering

`GAWeb.CheckpointJSON` MUST render checkpoint data including `id`, `account_id`, `sequence_number`, `checksum`, `signature`, `verified_at`, and `inserted_at`. If external anchoring metadata exists, it MUST also render `signing_key_id`.

Canonical checkpoint payload shape:

```json
{
  "data": {
    "id": "uuid",
    "account_id": "uuid",
    "sequence_number": 123,
    "checksum": "64-char-hex",
    "signature": "base64-or-null",
    "verified_at": "iso8601-or-null",
    "signing_key_id": "uuid-or-null",
    "inserted_at": "iso8601"
  }
}
```

#### Scenario: Full checkpoint rendering
- **WHEN** a checkpoint is rendered
- **THEN** the JSON includes all fields with correct types

#### Scenario: Unanchored checkpoint rendering
- **WHEN** a checkpoint has not been externally anchored yet
- **THEN** `signature`, `verified_at`, and `signing_key_id` are present as `null`
