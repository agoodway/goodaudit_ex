## ADDED Requirements

### Requirement: Per-account streaming chain verification

The verifier MUST accept an `account_id`, fetch the account's HMAC key via `GA.Accounts.get_hmac_key(account_id)`, and read that account's audit log entries in batches (default 1000) ordered by sequence number ascending, starting from genesis. For each entry it MUST: check sequence continuity (expected vs actual sequence number within the account), recompute the HMAC checksum using `GA.Audit.Chain.verify_checksum(hmac_key, entry, previous_checksum)` and compare against the stored checksum, and check any checkpoint anchors at that sequence number for the account. The verifier MUST return a report map. Entries from other accounts MUST never be included in verification.

#### Scenario: Valid chain for account
- **WHEN** `verify(account_id)` is called on an intact chain for that account
- **THEN** it returns `%{valid: true, total_entries: N, verified_entries: N, first_failure: nil, sequence_gaps: [], checkpoint_results: [...], duration_ms: M}`

#### Scenario: Tampered checksum detected
- **WHEN** an entry's stored checksum has been altered (e.g., directly in the database with triggers disabled)
- **THEN** the report has `valid: false` and `first_failure` contains `%{type: :checksum_mismatch, sequence_number: N, stored_checksum: ..., expected_checksum: ...}`

#### Scenario: Sequence gap detected within account
- **WHEN** entries exist for an account with sequence numbers 1, 2, 4 (3 is missing)
- **THEN** the report has `valid: false`, `sequence_gaps` contains `%{expected: 3, found: 4, missing: [3]}`

#### Scenario: Account isolation during verification
- **WHEN** `verify(account_a_id)` is called and account B has entries
- **THEN** only account A's entries are verified; account B's entries are ignored

### Requirement: Per-account checkpoint anchor validation

During verification, when the verifier encounters a sequence number that has a corresponding checkpoint for the same account, it MUST compare the checkpoint's stored checksum against the chain entry's checksum at that position.

#### Scenario: Valid checkpoint
- **WHEN** a checkpoint for the account at sequence N has the same checksum as the chain entry at sequence N
- **THEN** `checkpoint_results` includes `%{sequence_number: N, valid: true}`

#### Scenario: Invalid checkpoint
- **WHEN** a checkpoint's checksum differs from the chain entry's checksum at that sequence number
- **THEN** `checkpoint_results` includes `%{sequence_number: N, valid: false}` and `valid` is `false`

### Requirement: Verification report timing

The report MUST include `duration_ms` — the wall-clock time taken for the full verification in milliseconds.

#### Scenario: Duration tracking
- **WHEN** verification completes for an account
- **THEN** the report includes a non-negative `duration_ms` value
