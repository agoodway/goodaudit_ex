## ADDED Requirements

### Requirement: Multi-account periodic checkpoint creation

The `GA.Audit.CheckpointWorker` GenServer MUST create chain checkpoints for all active accounts on a configurable interval (default: 1 hour). It MUST be added to the application's supervision tree so it starts automatically. On each tick, it iterates all accounts with `status: :active` and calls `GA.Audit.create_checkpoint/1` for each.

#### Scenario: Scheduled checkpoint for all accounts
- **WHEN** the configured interval elapses
- **THEN** the worker creates a checkpoint for each active account that has audit entries

#### Scenario: Account with no entries yet
- **WHEN** the worker processes an active account with no audit entries
- **THEN** it logs a debug message for that account and continues to the next account

#### Scenario: Checkpoint failure for one account
- **WHEN** `create_checkpoint/1` returns an error for one account
- **THEN** the worker logs an error for that account but continues processing remaining accounts (does not crash)

#### Scenario: Suspended accounts skipped
- **WHEN** the worker fires and some accounts have `status: :suspended`
- **THEN** suspended accounts are skipped — only active accounts receive checkpoints

### Requirement: Supervision tree integration

The `CheckpointWorker` MUST be added to `GA.Application`'s children list before the endpoint, so it starts on application boot.

#### Scenario: Application boot
- **WHEN** the application starts
- **THEN** the `CheckpointWorker` process is running and scheduled
