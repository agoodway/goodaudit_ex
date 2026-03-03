## ADDED Requirements

### Requirement: Bulk audit ingestion endpoint

The system MUST provide a bulk ingestion endpoint that accepts multiple audit events in one request and returns per-item result objects.

#### Scenario: Partial success bulk ingest
- **WHEN** a bulk request contains valid and invalid items
- **THEN** valid items are written, invalid items return itemized errors, and overall response is HTTP 207-style equivalent JSON semantics

### Requirement: Bulk ordering and account isolation

Bulk processing MUST preserve request item order in response reporting and MUST enforce account scoping for all items.

#### Scenario: Cross-account payload attempt
- **WHEN** a bulk payload includes entries referencing another account context
- **THEN** those items are rejected and no cross-account writes occur
