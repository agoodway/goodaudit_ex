## ADDED Requirements

### Requirement: Per-account HMAC key generation

Every account MUST have a unique 32-byte HMAC key generated at creation time using `:crypto.strong_rand_bytes(32)`. The key MUST be stored as raw binary in the `hmac_key` column of the `accounts` table. The key MUST NOT be settable via the account changeset or any external input.

#### Scenario: Key generated on account creation
- **WHEN** `GA.Accounts.create_account(user, %{name: "Acme"})` is called
- **THEN** the created account has a 32-byte `hmac_key` that was auto-generated

#### Scenario: Each account gets a unique key
- **WHEN** two accounts are created
- **THEN** their `hmac_key` values are different

#### Scenario: Key not externally settable
- **WHEN** `create_account/2` is called with `%{name: "Acme", hmac_key: "injected"}`
- **THEN** the `hmac_key` in attrs is ignored and a random key is generated instead

### Requirement: HMAC key storage

The `accounts` table MUST have an `hmac_key` column of type `:binary`, NOT NULL. Existing accounts MUST be backfilled with generated keys in the migration.

#### Scenario: Migration adds column
- **WHEN** the migration runs
- **THEN** the `hmac_key` column is added to `accounts` with NOT NULL constraint

#### Scenario: Existing accounts backfilled
- **WHEN** the migration runs and accounts already exist
- **THEN** all existing accounts receive unique 32-byte keys

### Requirement: HMAC key retrieval

`GA.Accounts.get_hmac_key(account_id)` MUST return `{:ok, binary}` with the raw 32-byte key for the given account, or `{:error, :not_found}` if the account doesn't exist. It MUST query only the `hmac_key` column for efficiency.

#### Scenario: Key retrieved
- **WHEN** `get_hmac_key(account_id)` is called with a valid account ID
- **THEN** it returns `{:ok, <<32 bytes>>}`

#### Scenario: Account not found
- **WHEN** `get_hmac_key(account_id)` is called with a nonexistent ID
- **THEN** it returns `{:error, :not_found}`

### Requirement: Key redaction

The `hmac_key` field MUST be redacted from `Inspect` output and MUST NOT appear in any JSON serialization, API responses, or log output.

#### Scenario: Inspect redaction
- **WHEN** an `%Account{}` struct is inspected (in IEx, logs, or error messages)
- **THEN** the `hmac_key` value is shown as `**redacted**`

#### Scenario: JSON exclusion
- **WHEN** an account is serialized to JSON for any API response
- **THEN** the `hmac_key` field is not included
