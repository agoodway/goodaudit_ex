## ADDED Requirements

### Requirement: Scheduled full verification for compliance

The system MUST run periodic full verification scans independent of request-time incremental verification.

#### Scenario: Scheduled full scan
- **WHEN** the compliance schedule fires
- **THEN** verifier runs in full mode from genesis for each in-scope account

#### Scenario: Discrepancy detected
- **WHEN** a full scan finds integrity issues
- **THEN** a high-severity alert/event is emitted with account and failure details
