## ADDED Requirements

### Requirement: Explicit retention and archival policy

The system MUST enforce configured online retention windows and archive aged partitions immutably.

#### Scenario: Retention boundary reached
- **WHEN** a partition exceeds online retention threshold
- **THEN** it is archived with integrity metadata before removal from hot storage

### Requirement: Controlled re-hydration

Archived data re-hydration MUST be time-bounded, approval-gated, and audit logged.

#### Scenario: Re-hydration request
- **WHEN** an authorized operator re-hydrates archived data for an investigation
- **THEN** the restore operation records actor, reason, window, and expiry
