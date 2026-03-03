## Context

This change was originally designed to set up API infrastructure from scratch. The app now has comprehensive multi-tenant API infrastructure already in place. This document records the existing design decisions.

## Goals / Non-Goals

**Goals:**
- ~~Single bearer token auth~~ → **Achieved with per-account API keys** (superior to original proposal)
- OpenAPI spec auto-generated from controller annotations → **Already in place**
- Consistent JSON error format across all endpoints → **Already in place**
- Clear separation between authenticated and public routes → **Already in place**

**Non-Goals:**
- ~~Multi-user auth, API key rotation~~ → **Already supported** by the existing API key system

## Existing Design (No Changes Needed)

### Per-account API keys (replaces single env-var key)
The app uses `GA.Accounts.ApiKey` scoped to `account_users` membership. Each key pair (public `pk_*` / private `sk_*`) is tied to a specific user+account combination. `GAWeb.Plugs.ApiAuth` validates the bearer token, resolves the account and user context, and assigns `current_account`, `current_user`, `current_account_user`, and `current_api_key` to conn.assigns. This provides multi-tenant isolation out of the box.

### Router pipelines already exist
- `:api` — Base JSON pipeline with OpenAPI spec injection and CORS
- `:api_authenticated` — Adds `ApiAuth.require_api_auth/2` (both pk/sk keys)
- `:api_write` — Adds `ApiAuth.require_write_access/2` (sk keys only)

### Error handling already exists
- `GAWeb.FallbackController` handles `{:error, changeset}` → 422, `{:error, :not_found}` → 404
- `GAWeb.ChangesetJSON` renders changeset errors as field-to-messages maps

### OpenAPI already configured
- `GAWeb.ApiSpec` implements `OpenApiSpex.OpenApi` behaviour
- `GET /api/v1/openapi` serves the spec (public)
- `GET /api/v1/docs` serves Swagger UI (dev only)

## Risks / Trade-offs

No new risks — existing infrastructure is production-ready.
