## ADDED Requirements

### Requirement: Canonical lead lifecycle event types

The system MUST define and validate a canonical `event_type` catalog for lead lifecycle stages, including capture, enrich, deduplicate, score, suppress, route, deliver, acknowledge, retry, and dispute events.

#### Scenario: Valid taxonomy event accepted
- **WHEN** an event is submitted with a supported `event_type`
- **THEN** the event is persisted and returned with the same canonical type

#### Scenario: Unknown taxonomy event rejected
- **WHEN** an event is submitted with an unsupported `event_type`
- **THEN** the request fails with HTTP 422 and an error on `event_type`
