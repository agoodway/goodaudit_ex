## ADDED Requirements

### Requirement: Cross-mode idempotency contract

Single, bulk, and webhook ingestion paths MUST support account-scoped idempotency keys that guarantee exactly-once write effects for duplicate submissions.

#### Scenario: Duplicate single ingest key
- **WHEN** a client retries the same single-ingest request with the same idempotency key
- **THEN** the second request returns the original result without creating a new row

#### Scenario: Duplicate bulk ingest key
- **WHEN** the same bulk request is retried with the same idempotency key
- **THEN** each item returns its original status and no duplicate rows are inserted
