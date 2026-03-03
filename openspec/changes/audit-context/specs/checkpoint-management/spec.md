## ADDED Requirements

### Requirement: Per-account checkpoint creation

`create_checkpoint(account_id)` MUST read the latest audit log entry for the given account, create a checkpoint record with that entry's `sequence_number` and `checksum` plus the `account_id`, leave `verified_at` as `nil` at creation time, and return `{:ok, %Checkpoint{}}`. If no audit entries exist for the account, it MUST return `{:error, :no_entries}`.

#### Scenario: Successful checkpoint for account
- **WHEN** `create_checkpoint(account_id)` is called with existing audit entries for that account
- **THEN** a checkpoint is created at the account's current chain head with the correct sequence_number, checksum, and account_id

#### Scenario: No entries yet for account
- **WHEN** `create_checkpoint(account_id)` is called for an account with no audit_logs entries
- **THEN** it returns `{:error, :no_entries}`

#### Scenario: Checkpoint isolation
- **WHEN** `create_checkpoint(account_a_id)` is called
- **THEN** the checkpoint references only account A's chain head, not entries from other accounts

### Requirement: Per-account checkpoint listing

`list_checkpoints(account_id)` MUST return all checkpoints for the given account ordered by sequence_number descending (newest first). Checkpoints from other accounts MUST never be included.

#### Scenario: List checkpoints for account
- **WHEN** `list_checkpoints(account_id)` is called with existing checkpoints for that account
- **THEN** only that account's checkpoints are returned ordered by sequence_number descending

#### Scenario: Checkpoint account isolation
- **WHEN** `list_checkpoints(account_a_id)` is called
- **THEN** no checkpoints belonging to account B are returned
