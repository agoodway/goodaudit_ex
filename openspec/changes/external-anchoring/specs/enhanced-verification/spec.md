## ADDED Requirements

### Requirement: Anchor validation in verification report

When `GA.Audit.verify_chain(account_id)` is called and anchoring is enabled, the verifier MUST validate external signatures for all anchored checkpoints. The report MUST include an `anchor_results` list alongside the existing chain verification results.

#### Scenario: All anchors valid
- **WHEN** verification runs and all checkpoints with signatures pass Ed25519 verification
- **THEN** `anchor_results` contains entries with `status: :anchored, valid: true` for each, and overall `valid` remains unchanged by anchor validation

#### Scenario: Invalid anchor detected
- **WHEN** verification runs and a checkpoint's stored signature doesn't match the reconstructed payload
- **THEN** `anchor_results` contains `%{sequence_number: N, status: :anchored, valid: false}` and overall `valid` is set to `false`

#### Scenario: Revoked signing key detected
- **WHEN** verification runs and a checkpoint receipt verifies cryptographically but checksum.dev marks the signing key as revoked
- **THEN** `anchor_results` contains `%{sequence_number: N, status: :anchored, valid: false, key_status: :revoked}` and overall `valid` is set to `false`

#### Scenario: Unanchored checkpoints
- **WHEN** verification runs and some checkpoints have `signature: nil`
- **THEN** `anchor_results` contains `%{sequence_number: N, status: :unanchored, valid: nil}` for each, but overall `valid` is NOT affected (unanchored is informational, not a failure)

#### Scenario: Anchoring disabled
- **WHEN** verification runs and anchoring is not enabled
- **THEN** the `anchor_results` key is omitted from the report

### Requirement: Report structure extension

The verification report MUST be extended with the following structure when anchoring is enabled:

```elixir
%{
  valid: true | false,
  total_entries: integer,
  verified_entries: integer,
  first_failure: nil | map,
  sequence_gaps: list,
  checkpoint_results: list,
  anchor_results: [
    %{sequence_number: integer, status: :anchored | :unanchored, valid: true | false | nil, key_status: :active | :rotated | :revoked | nil},
    ...
  ],
  duration_ms: integer
}
```

#### Scenario: Mixed anchor states
- **WHEN** an account has 3 checkpoints: one anchored+valid, one anchored+invalid, one unanchored
- **THEN** `anchor_results` is `[%{sequence_number: 100, status: :anchored, valid: true, key_status: :active}, %{sequence_number: 200, status: :anchored, valid: false, key_status: :revoked}, %{sequence_number: 300, status: :unanchored, valid: nil, key_status: nil}]` and overall `valid` is `false` (due to invalid/revoked anchor trust)
