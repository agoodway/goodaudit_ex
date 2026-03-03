## Why

The audit system has all backend logic (chain computation, schemas, context, verification) in place, all scoped per-account. The app already provides complete API infrastructure (per-account API keys, auth plugs, OpenAPI, error handling, router pipelines). Now we need the actual HTTP endpoints that expose the audit API — controllers, JSON views, OpenAPI schemas, and route wiring into the existing infrastructure.

## What Changes

1. **Audit log endpoints** — `POST /api/v1/audit-logs` (create entry), `GET /api/v1/audit-logs` (list with pagination + filters), `GET /api/v1/audit-logs/:id` (get single entry) — all scoped to the account resolved from the API key
2. **Checkpoint endpoints** — `POST /api/v1/checkpoints` (create checkpoint), `GET /api/v1/checkpoints` (list checkpoints) — scoped to account
3. **Verification endpoint** — `POST /api/v1/verify` (trigger per-account chain verification)
4. **OpenAPI schemas** — Request/response schema modules for all endpoints
5. **JSON views** — `AuditLogJSON`, `CheckpointJSON` for rendering responses
6. **FallbackController update** — Add `{:error, :no_entries}` handler to existing `GAWeb.FallbackController`

> **Multi-tenancy note:** Account context comes from the existing `GAWeb.Plugs.ApiAuth` — the API key resolves `conn.assigns.current_account`. No account_id in URL paths. Write endpoints (POST) use the `:api_write` pipeline (requires private `sk_*` key). Read endpoints (GET) use the `:api_authenticated` pipeline (allows both `pk_*` and `sk_*` keys).

## Capabilities

### New Capabilities
- `audit-log-endpoints`: Account-scoped REST endpoints for creating, listing, and retrieving audit log entries with OpenAPI annotations
- `checkpoint-endpoints`: Account-scoped REST endpoints for creating and listing chain checkpoints
- `verification-endpoint`: Account-scoped endpoint for triggering chain integrity verification

### Modified Capabilities

## Impact

- **New files**: `lib/app_web/controllers/audit_log_controller.ex`, `lib/app_web/controllers/audit_log_json.ex`, `lib/app_web/controllers/checkpoint_controller.ex`, `lib/app_web/controllers/checkpoint_json.ex`, `lib/app_web/controllers/verification_controller.ex`
- **New files**: `lib/app_web/schemas/audit_log_request.ex`, `lib/app_web/schemas/audit_log_response.ex`, `lib/app_web/schemas/audit_log_list_response.ex`, `lib/app_web/schemas/checkpoint_response.ex`, `lib/app_web/schemas/verification_response.ex`, `lib/app_web/schemas/error_response.ex`
- **Modified file**: `lib/app_web/router.ex` (add resource routes to existing authenticated/write API scopes)
- **Modified file**: `lib/app_web/controllers/fallback_controller.ex` (add `:no_entries` handler)
- **New tests**: `test/app_web/controllers/audit_log_controller_test.exs`, `test/app_web/controllers/checkpoint_controller_test.exs`, `test/app_web/controllers/verification_controller_test.exs`
