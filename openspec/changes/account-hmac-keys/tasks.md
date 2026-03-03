## 1. Migration

- [x] 1.1 Create migration `AddHmacKeyToAccounts` — add `hmac_key` column as `:binary`, nullable initially
- [x] 1.2 Backfill existing accounts with `:crypto.strong_rand_bytes(32)` via `execute/1` or `Repo` calls in migration
- [x] 1.3 Alter column to `null: false` after backfill

## 2. Schema Update

- [x] 2.1 Add `field :hmac_key, :binary, redact: true` to `GA.Accounts.Account` schema
- [x] 2.2 Ensure `hmac_key` is NOT in the `cast/3` permitted fields — it is never set from external input
- [x] 2.3 Derive `Inspect` protocol or use `redact: true` to hide key from logs and IEx

## 3. Key Generation and Retrieval

- [x] 3.1 Update `GA.Accounts.create_account/2` to generate `hmac_key` via `:crypto.strong_rand_bytes(32)` and `put_change` it onto the changeset before insert
- [x] 3.2 Implement `GA.Accounts.get_hmac_key(account_id)` — `Repo.one(from a in Account, where: a.id == ^account_id, select: a.hmac_key)`, returns `{:ok, binary}` or `{:error, :not_found}`

## 4. Tests

- [x] 4.1 Test account creation generates a 32-byte hmac_key automatically
- [x] 4.2 Test `get_hmac_key/1` returns the key for a valid account
- [x] 4.3 Test `get_hmac_key/1` returns `{:error, :not_found}` for nonexistent account
- [x] 4.4 Test each account gets a unique key (create two accounts, keys differ)
- [x] 4.5 Test hmac_key is not present in Account inspect output
- [x] 4.6 Test hmac_key is not settable via changeset (external attrs ignored)
