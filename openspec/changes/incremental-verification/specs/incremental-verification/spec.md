## ADDED Requirements

### Requirement: Default incremental verification

Verification MUST default to incremental mode starting from the latest trusted checkpoint for the account.

#### Scenario: Trusted checkpoint exists
- **WHEN** verification runs for an account with a trusted checkpoint at sequence N
- **THEN** only entries with `sequence_number > N` are verified by default

#### Scenario: No trusted checkpoint
- **WHEN** verification runs and no trusted checkpoint exists
- **THEN** verifier falls back to full mode from genesis

### Requirement: Mode-aware report

Verification reports MUST include the mode and effective start boundary.

#### Scenario: Incremental report
- **WHEN** default verification is used
- **THEN** report includes `%{mode: :incremental, start_sequence: N}`
