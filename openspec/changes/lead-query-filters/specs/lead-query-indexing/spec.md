## ADDED Requirements

### Requirement: Account-prefixed lead query indexes

The system MUST provide account-prefixed indexes for common lead query combinations used in operations and compliance workflows.

#### Scenario: Query by buyer and campaign
- **WHEN** queries filter by `buyer_id` and `campaign_id`
- **THEN** results are returned with predictable latency targets and correct ordering

### Requirement: Index safety with pagination

Index strategy MUST preserve cursor pagination semantics across all supported lead filters.

#### Scenario: Cursor pagination under filtered query
- **WHEN** filtered query spans multiple pages
- **THEN** `next_cursor` semantics remain stable and no duplicates/misses occur
