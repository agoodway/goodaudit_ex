## ADDED Requirements

### Requirement: DSAR-aware lifecycle constraints

Retention and archival jobs MUST respect DSAR workflow constraints, including holds for in-progress requests and evidence retention for completed requests.

#### Scenario: Archive candidate with active DSAR
- **WHEN** a partition is eligible for archival but contains records tied to active DSAR workflows
- **THEN** archival is deferred or segmented according to configured hold policy

### Requirement: Privacy-safe rehydration

Rehydration workflows MUST preserve anonymization/tombstoning state and MUST not reintroduce redacted personal values.

#### Scenario: Rehydrate anonymized records
- **WHEN** archived data containing anonymized records is rehydrated
- **THEN** anonymized values remain anonymized after restore
