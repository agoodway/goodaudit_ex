## ADDED Requirements

### Requirement: Atomic entry creation with per-account chaining

`create_log_entry(account_id, attrs)` MUST acquire a PostgreSQL advisory lock scoped to the account (`pg_advisory_xact_lock(:erlang.phash2(account_id))`), fetch the account's HMAC key via `GA.Accounts.get_hmac_key(account_id)`, compute the next sequence number as `COALESCE(MAX(sequence_number) WHERE account_id = ?, 0) + 1`, retrieve the previous entry's checksum within the account, compute the new HMAC checksum via `GA.Audit.Chain.compute_checksum(hmac_key, attrs, previous_checksum)`, set the `account_id` on the record, and insert the entry — all within a single database transaction. It MUST return `{:ok, %Log{}}` on success or `{:error, changeset}` on validation failure.

#### Scenario: First entry (genesis) for an account
- **WHEN** `create_log_entry(account_id, attrs)` is called for an account with no existing entries
- **THEN** the entry is created with `account_id` set, `sequence_number: 1`, `previous_checksum: nil`, and a valid checksum

#### Scenario: Chained entry within an account
- **WHEN** `create_log_entry(account_id, attrs)` is called after existing entries for that account
- **THEN** the entry's `sequence_number` is one greater than the account's current max, `previous_checksum` equals the account's previous entry's checksum, and the checksum chains correctly

#### Scenario: Validation failure
- **WHEN** `create_log_entry(account_id, attrs)` is called with invalid attrs (missing required fields or bad enum values)
- **THEN** it returns `{:error, changeset}` and no row is inserted

#### Scenario: Cross-account independence
- **WHEN** entries exist for account A with sequence 1..5, and `create_log_entry(account_b_id, attrs)` is called
- **THEN** the new entry for account B has `sequence_number: 1` (independent chain)

### Requirement: Per-account gap-free sequence numbers

The per-account advisory lock strategy MUST guarantee no sequence gaps within an account even under concurrent writes or transaction rollbacks. Unlike `BIGSERIAL`, rolled-back transactions MUST NOT consume sequence numbers.

#### Scenario: Concurrent writers within same account
- **WHEN** 20 concurrent processes each call `create_log_entry(same_account_id, attrs)` simultaneously
- **THEN** all 20 entries are created with sequence numbers 1 through 20 with no gaps

#### Scenario: Concurrent writers across different accounts
- **WHEN** processes write to account A and account B simultaneously
- **THEN** both accounts' writes proceed concurrently without blocking each other

#### Scenario: Rollback safety
- **WHEN** a transaction containing `create_log_entry/2` is rolled back due to validation failure
- **THEN** the sequence number is not consumed and the next successful insert for that account uses it

### Requirement: Default timestamp

If no `timestamp` is provided in attrs, `create_log_entry/2` MUST default to `DateTime.utc_now()`.

#### Scenario: Timestamp defaulting
- **WHEN** `create_log_entry(account_id, attrs)` is called without a `:timestamp` key in attrs
- **THEN** the entry's timestamp is set to the current UTC time
