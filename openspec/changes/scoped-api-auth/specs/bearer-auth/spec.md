## ADDED Requirements

### Requirement: Bearer auth resolves effective scopes

`GAWeb.Plugs.ApiAuth` MUST resolve effective scopes and constraints for the authenticated API key and assign them to connection context for downstream authorization checks.

#### Scenario: Scope assignment on auth success
- **WHEN** bearer token auth succeeds
- **THEN** `conn.assigns.current_api_key_scopes` contains resolved effective scope grants

### Requirement: Legacy key compatibility

Legacy pk/sk keys MUST map to compatibility scopes until migrated, without breaking existing integrations.

#### Scenario: Legacy private key request
- **WHEN** a legacy `sk_*` key calls existing write endpoint
- **THEN** request remains authorized under compatibility scope mapping
