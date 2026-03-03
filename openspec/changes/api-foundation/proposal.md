## Why

The audit system needs HTTP API infrastructure. **The app already provides all of this** — this proposal documents the existing infrastructure and confirms no additional work is needed.

## What Already Exists

The following components are **already implemented** in the app:

1. **`open_api_spex` dependency** — already in `mix.exs`
2. **`GAWeb.ApiSpec`** — Root OpenAPI specification module with security scheme (bearer token via per-account API keys)
3. **`GAWeb.Plugs.ApiAuth`** — Multi-tenant bearer token authentication plug that validates per-account API keys (`pk_*` for read, `sk_*` for read+write), resolves `current_account`, `current_user`, `current_account_user`, checks user confirmation and account active status
4. **Router pipelines** — `:api` (base), `:api_authenticated` (read access with any key type), `:api_write` (write access requiring private `sk_*` key)
5. **`GAWeb.FallbackController`** — Standardized error rendering for changeset errors, not-found, and custom error tuples
6. **`GAWeb.ChangesetJSON`** — JSON rendering for Ecto changeset errors
7. **Configuration** — Per-account API keys stored in `api_keys` table, scoped to `account_users` membership (far more capable than the originally proposed single env-var key)
8. **OpenAPI routes** — `GET /api/v1/openapi` (public) and `GET /api/v1/docs` (Swagger UI, dev only)

## What Changed From Original Proposal

The original proposal called for a single bearer token from an `AUDIT_API_KEY` environment variable. The app instead implements **per-account API keys** with:
- Public keys (`pk_*`) for read-only access
- Private keys (`sk_*`) for read+write access
- Keys scoped to user+account membership (multi-tenant)
- Token prefix + SHA256 hash storage (never stores plain tokens)
- Expiry, revocation, and last-used tracking
- User confirmation and account status enforcement at auth time

This is strictly superior to the original proposal and requires no changes.

## Capabilities

### New Capabilities
None — all capabilities already exist in the app.

### Modified Capabilities

## Impact

**No code changes required.** The audit-endpoints change will wire new controllers into the existing router pipelines.
