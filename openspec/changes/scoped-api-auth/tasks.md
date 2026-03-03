## 1. Scope Data Model

- [ ] 1.1 Extend API key schema/storage to persist scope grants and constraints
- [ ] 1.2 Add compatibility mapping for existing pk/sk keys
- [ ] 1.3 Add key management interfaces for creating and reviewing scoped keys

## 2. Auth and Authorization Enforcement

- [ ] 2.1 Update `GAWeb.Plugs.ApiAuth` to resolve/assign effective scopes on auth success
- [ ] 2.2 Add endpoint-level scope enforcement helpers and route/controller integration
- [ ] 2.3 Add environment and constrained-resource authorization checks

## 3. API Docs and Validation

- [ ] 3.1 Update OpenAPI docs with required scopes and 403 responses
- [ ] 3.2 Add tests for allow/deny matrices across scope combinations
- [ ] 3.3 Add migration tests ensuring legacy keys continue functioning during transition
