## Why

Each account needs its own HMAC key so that audit chain integrity is cryptographically isolated per tenant. If one account's key is compromised, only that account's chain is affected — other tenants remain secure. The `GA.Audit.Chain` module accepts the key as an explicit parameter; this change provides the key storage, generation, and retrieval that feeds it.

## What Changes

1. **Migration** — Add an `hmac_key` column to the existing `accounts` table. Encrypted at rest via `binary` type storing raw 32-byte keys.

2. **Schema update** — Add `hmac_key` field to `GA.Accounts.Account`. Excluded from public-facing serialization (redacted like `hashed_password` on users).

3. **Key generation** — Auto-generate a 32-byte random key when creating an account via `GA.Accounts.create_account/2`. Uses `:crypto.strong_rand_bytes(32)`.

4. **Key retrieval** — `GA.Accounts.get_hmac_key(account_id)` fetches only the key column for a given account. Used by the audit context when computing checksums.

> **Lifecycle note:** This change introduces the initial single-key model. Production key versioning and rotation are defined in the `key-rotation-v2` change.

## Capabilities

### New Capabilities
- `key-management`: Per-account HMAC key generation, storage, and retrieval

### Modified Capabilities

## Impact

- **New migration**: `AddHmacKeyToAccounts`
- **Modified file**: `lib/app/accounts/account.ex` — add `hmac_key` field, redact from inspect, auto-generate in changeset
- **Modified file**: `lib/app/accounts.ex` — add `get_hmac_key/1`, update `create_account/2` to generate key
- **New test**: `test/app/accounts/hmac_key_test.exs`
- **No new dependencies** — uses `:crypto` (already available)
