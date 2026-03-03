## ADDED Requirements

### Requirement: Lead-domain filter parameters

The query API MUST support account-scoped filtering by `lead_id`, `source_id`, `buyer_id`, `campaign_id`, `vertical`, `delivery_channel`, `event_type`, and `decision_reason_code`.

#### Scenario: Compound lead filters
- **WHEN** a request includes `lead_id`, `buyer_id`, and `event_type`
- **THEN** only entries matching all supplied predicates for the account are returned

### Requirement: Lifecycle/compliance status filters

The query API MUST support filtering by lifecycle statuses including dedup and suppression outcomes.

#### Scenario: Suppression-only results
- **WHEN** query includes `suppression_status=blocked`
- **THEN** only blocked suppression events are returned for the account
