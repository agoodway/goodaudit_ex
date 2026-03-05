## Context

API authorization currently distinguishes only read (`pk_*`) vs write (`sk_*`). Lead platforms require least-privilege controls so credentials can be constrained by operation type and resource boundaries.

## Goals / Non-Goals

**Goals:**
- Add explicit scopes to API keys and enforce them at endpoint boundaries.
- Support optional resource constraints (source, buyer, campaign, namespace).
- Introduce environment scoping to prevent credential cross-use.
- Preserve compatibility for existing keys during migration.

**Non-Goals:**
- Replacing bearer token architecture.
- Introducing third-party OAuth flows.
- Building ABAC policy DSL in this change.

## Decisions

### Extend API keys with scope grants
Persist structured scope grants per key and resolve grants at auth time in `ApiAuth`.

### Support core and profile scope namespaces
Scope grants can target core capabilities and optional domain profile capabilities (for example `query:core`, `query:lead`).

### Keep authn and authz separate in plug flow
Authentication resolves key/account/user context first; authorization checks required scopes per route/controller action.

### Add optional resource constraints
Scope grants may include constrained resource selectors to enforce partner-specific boundaries.

### Compatibility mode for legacy keys
Legacy pk/sk keys map to default broad scopes until explicitly migrated.

## Risks / Trade-offs

- [Policy misconfiguration can cause outages] -> Provide safe defaults and dry-run validation tooling.
- [Increased auth latency] -> Cache resolved scope grants with bounded TTL.
- [Migration confusion] -> Expose key introspection endpoint showing effective scopes.

## Migration Plan

1. Add schema support for scope grants and constraints.
2. Implement authz checks with compatibility fallback for existing keys.
3. Annotate routes with required scopes and update OpenAPI docs.
4. Roll out granular key issuance and revoke broad defaults over time.

## Open Questions

- Should constrained-resource selectors support wildcard patterns at launch?
