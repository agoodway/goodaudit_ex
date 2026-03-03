## Context

The `GA.Audit.Chain` module accepts HMAC keys as explicit parameters. The app has an existing `accounts` table and `GA.Accounts` context. This change adds per-account key storage so each tenant has its own cryptographic identity for audit chain integrity.

## Goals / Non-Goals

**Goals:**
- Every account gets a unique 32-byte HMAC key generated at creation time
- Key retrieval is efficient (single column SELECT by primary key)
- Keys are never exposed in API responses, logs, or inspect output
- Existing accounts get keys via backfill in the migration

**Non-Goals:**
- Key rotation in this change (implemented by `key-rotation-v2` with versioned keys and cutover workflow)
- Key derivation from a master key (unnecessary complexity for isolated per-account keys)
- Hardware security module (HSM) integration — raw keys in DB are acceptable for MVP with DB-level encryption at rest
- Encryption of the key column at the application layer (rely on PostgreSQL encryption at rest)

## Decisions

### Column on accounts table, not a separate table
A single `hmac_key` binary column on the existing `accounts` table is the simplest approach. One account = one key. No join needed. No extra table to manage. If key rotation is added later, a separate `account_keys` table with versioning can replace this.

### 32-byte random key via `:crypto.strong_rand_bytes/1`
32 bytes (256 bits) matches the HMAC-SHA-256 key size recommendation. `:crypto.strong_rand_bytes/1` uses the OS CSPRNG. No base64 encoding in storage — store raw binary, decode/encode only at API boundaries if needed.

### Auto-generate on account creation
The key is generated in `GA.Accounts.create_account/2` before insert — not in a changeset callback. This keeps the changeset pure (no side effects) and makes the generation explicit and testable.

### Backfill existing accounts in migration
The migration adds the column as nullable, backfills all existing accounts with generated keys, then sets the column to NOT NULL. This is safe for production deploys.

### Redact from inspect and serialization
The `hmac_key` field uses `redact: true` in the schema (like `hashed_password` on users) so it never appears in logs, inspect output, or IEx sessions. It is excluded from all JSON serialization.

### Dedicated retrieval function
`GA.Accounts.get_hmac_key(account_id)` does a `SELECT hmac_key FROM accounts WHERE id = ?` — fetching only the column needed. The audit context calls this when computing checksums rather than loading the full account struct.

## Risks / Trade-offs

### Key stored in database
If the database is compromised, all keys are exposed. Mitigation: PostgreSQL encryption at rest (standard practice), database access controls, and the external anchoring layer (checksum.dev, future change) provides a second verification path independent of HMAC keys.

### No key rotation
If a key is compromised, the account's entire historical chain can be reforged. Mitigation: checkpoints with external signatures anchor the chain at regular intervals, making full-chain reforging detectable. Key rotation and key versioning are implemented in `key-rotation-v2`.

### Migration backfill on large accounts table
Backfilling existing accounts requires an UPDATE per row. For the expected number of accounts (hundreds to low thousands), this is instant. For millions, the migration should use batched updates.
