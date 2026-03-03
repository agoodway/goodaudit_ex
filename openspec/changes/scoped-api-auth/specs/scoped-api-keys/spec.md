## ADDED Requirements

### Requirement: API key scope grants

API keys MUST support explicit scope grants (for example `ingest`, `query`, `verify`, `checkpoint`, `anchor`, `admin`) stored and validated at request time.

#### Scenario: Key with limited scopes
- **WHEN** a key is created with `query` scope only
- **THEN** it can read permitted endpoints but cannot call ingest/write endpoints

### Requirement: Resource-constrained scopes

Scope grants MUST optionally support constraints for scoped resources (such as source or buyer identifiers).

#### Scenario: Buyer-constrained key
- **WHEN** a key constrained to `buyer_id=B1` requests data for `buyer_id=B2`
- **THEN** access is denied with HTTP 403
