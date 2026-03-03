## Why

Current API access is split by read (`pk_*`) and write (`sk_*`) only. Lead distribution platforms typically require finer authorization boundaries across partners, environments, and resources so one credential cannot read or write all account data.

## What Changes

1. **Scope model for API keys** - Introduce explicit scopes (for example: ingest, query, verify, checkpoint, anchor, admin).
2. **Resource constraints** - Add optional scope constraints by source, buyer, campaign, or namespace.
3. **Environment isolation** - Support environment-level scoping to prevent cross-environment credential misuse.
4. **Least-privilege key lifecycle** - Add key issuance/review/revocation flows with scope metadata and audit requirements.
5. **Authorization enforcement contract** - Define consistent 401/403 behavior and OpenAPI documentation for scope failures.

## Capabilities

### New Capabilities
- `scoped-api-keys`: Fine-grained permission scopes and constraints for API credentials
- `authz-policy-enforcement`: Endpoint-level authorization checks based on declared scope requirements

### Modified Capabilities
- `bearer-auth`: Extend token verification to resolve and enforce scopes
- `audit-log-endpoints`: Require explicit scopes per operation instead of only pk/sk class

## Impact

- **Modified files**: API auth plug, account key management, router/controller auth guards, API docs
- **New files**: scope policy definitions and key scope schema modules
- **New tests**: scope denial/allow matrices, constrained-resource access, and migration safety for existing keys
