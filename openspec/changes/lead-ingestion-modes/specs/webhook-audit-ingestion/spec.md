## ADDED Requirements

### Requirement: Signed webhook ingestion

The system MUST expose a webhook ingestion endpoint that requires cryptographic signature verification over canonical request payload and timestamp.

#### Scenario: Valid signed webhook
- **WHEN** a webhook request includes a valid signature and acceptable timestamp skew
- **THEN** events are accepted and persisted under the authenticated account context

#### Scenario: Invalid signature
- **WHEN** a webhook request includes an invalid signature
- **THEN** the request is rejected with HTTP 401 and no events are written

### Requirement: Replay protection

Webhook ingestion MUST detect and reject replayed requests using nonce/event identifiers within a configured replay window.

#### Scenario: Replayed webhook request
- **WHEN** the same signed webhook payload is resent within replay window
- **THEN** the second request is treated as duplicate and does not create additional audit rows
