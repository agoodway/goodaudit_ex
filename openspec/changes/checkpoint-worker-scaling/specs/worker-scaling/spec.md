## ADDED Requirements

### Requirement: Non-overlapping worker runs

Checkpoint worker runs MUST not overlap for the same scope.

#### Scenario: Overlap prevented
- **WHEN** a scheduled tick fires while a prior run is still active
- **THEN** the new run is skipped or deferred based on lease policy

### Requirement: Bounded fan-out with per-account backoff

Worker account processing MUST use bounded concurrency and isolate failing accounts via backoff.

#### Scenario: One noisy account
- **WHEN** one account repeatedly fails checkpoint creation
- **THEN** that account enters backoff while other accounts continue processing normally
