## Status: Already Implemented

All tasks in this proposal are already implemented in the app. No code changes needed.

## 1. Dependency — ALREADY EXISTS

- [x] 1.1 `open_api_spex` is already in `mix.exs` deps
- [x] 1.2 Dependencies already installed

## 2. Authentication Plug — ALREADY EXISTS (superior implementation)

- [x] 2.1 `GAWeb.Plugs.ApiAuth` exists at `lib/app_web/plugs/api_auth.ex` — per-account API key validation
- [x] 2.2 Bearer token extraction implemented
- [x] 2.3 Token validation via prefix+hash lookup against `api_keys` table (not single env var)
- [x] 2.4 Per-account API keys configured in database, not config files
- [x] 2.5 No `AUDIT_API_KEY` env var needed — keys managed per-account via `GA.Accounts.create_api_key/2`

## 3. OpenAPI Setup — ALREADY EXISTS

- [x] 3.1 `GAWeb.ApiSpec` exists at `lib/app_web/api_spec.ex`
- [x] 3.2 OpenAPI controller exists
- [x] 3.3 `GET /api/v1/openapi` route configured (public, no auth)
- [x] 3.4 `GET /api/v1/docs` Swagger UI route configured (dev only)

## 4. Error Handling — ALREADY EXISTS

- [x] 4.1 `GAWeb.FallbackController` exists at `lib/app_web/controllers/fallback_controller.ex`
- [x] 4.2 `GAWeb.ChangesetJSON` exists at `lib/app_web/controllers/changeset_json.ex`

## 5. Router — ALREADY EXISTS

- [x] 5.1 `:api_authenticated` and `:api_write` pipelines exist in router
- [x] 5.2 Public API scope exists for OpenAPI endpoint
- [x] 5.3 Authenticated API scopes exist (ready for audit endpoint routes)
- [x] 5.4 Dev-only Swagger UI scope exists
