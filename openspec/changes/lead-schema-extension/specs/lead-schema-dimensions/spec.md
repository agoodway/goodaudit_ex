## ADDED Requirements

### Requirement: Lead distribution dimensions in audit log schema

The system MUST persist first-class lead dimensions on `audit_logs`: `lead_id`, `source_id`, `buyer_id`, `campaign_id`, `vertical`, and `delivery_channel`. These fields MUST be account-scoped data and MUST be included in append-only records.

#### Scenario: Insert lead-routed event
- **WHEN** an event is written with lead routing context
- **THEN** the resulting audit row stores all provided lead dimensions alongside existing chain fields

#### Scenario: Missing optional lead dimensions
- **WHEN** an event does not include lead dimensions
- **THEN** the insert succeeds and omitted lead fields are stored as null

### Requirement: Index support for lead investigation paths

The system MUST provide account-prefixed indexes for high-frequency lead query paths, including `[account_id, lead_id]`, `[account_id, source_id]`, and `[account_id, buyer_id]`.

#### Scenario: Query by lead id
- **WHEN** an account-scoped query filters by `lead_id`
- **THEN** results are returned with stable ordering and without scanning other-account rows
