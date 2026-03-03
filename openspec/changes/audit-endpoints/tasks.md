## 1. OpenAPI Schemas

- [ ] 1.1 Create `lib/app_web/schemas/audit_log_request.ex` — required and optional fields with types and enums
- [ ] 1.2 Create `lib/app_web/schemas/audit_log_response.ex` — full entry including chain fields and account_id
- [ ] 1.3 Create `lib/app_web/schemas/audit_log_list_response.ex` — data array + meta (next_cursor, count)
- [ ] 1.4 Create `lib/app_web/schemas/checkpoint_response.ex` — checkpoint fields including account_id, `signature`, `verified_at`, and `signing_key_id` (nullable where not anchored)
- [ ] 1.5 Create `lib/app_web/schemas/verification_response.ex` — valid, totals, failures, gaps, checkpoints, duration
- [ ] 1.6 Create `lib/app_web/schemas/error_response.ex` — errors object

## 2. FallbackController Update

- [ ] 2.1 Add `{:error, :no_entries}` handler to existing `GAWeb.FallbackController` — returns HTTP 422 with `{"status": 422, "message": "No audit entries exist yet"}`

## 3. Audit Log Controller

- [ ] 3.1 Create `lib/app_web/controllers/audit_log_controller.ex` with `action_fallback GAWeb.FallbackController`
- [ ] 3.2 Implement `create/2` — reads `conn.assigns.current_account.id`, accepts flat params, calls `GA.Audit.create_log_entry(account_id, attrs)`, returns 201
- [ ] 3.3 Implement `index/2` — reads `conn.assigns.current_account.id`, parses query params (after_sequence, limit, filters, date range), calls `GA.Audit.list_logs(account_id, opts)`
- [ ] 3.4 Implement parameter parsing helpers — `parse_integer/1`, `parse_boolean/1`, `parse_datetime/1`
- [ ] 3.5 Implement `show/2` — reads `conn.assigns.current_account.id`, calls `GA.Audit.get_log(account_id, id)`
- [ ] 3.6 Add OpenApiSpex operation annotations for all three actions

## 4. Audit Log JSON View

- [ ] 4.1 Create `lib/app_web/controllers/audit_log_json.ex` — `index/1` (data + meta), `show/1` (data), `data/1` (full entry map including account_id)

## 5. Checkpoint Controller

- [ ] 5.1 Create `lib/app_web/controllers/checkpoint_controller.ex` — `create/2` reads `conn.assigns.current_account.id`, calls `GA.Audit.create_checkpoint(account_id)`, and `index/2` calls `GA.Audit.list_checkpoints(account_id)`, with OpenApiSpex annotations
- [ ] 5.2 Create `lib/app_web/controllers/checkpoint_json.ex` — `index/1`, `show/1`, `data/1` including account_id plus optional anchoring metadata (`signature`, `verified_at`, `signing_key_id`)

## 6. Verification Controller

- [ ] 6.1 Create `lib/app_web/controllers/verification_controller.ex` — `create/2` reads `conn.assigns.current_account.id`, calls `GA.Audit.verify_chain(account_id)`, returns result as JSON

## 7. Router Wiring

- [ ] 7.1 Add `resources "/audit-logs", AuditLogController, only: [:create]` to `:api_write` scope (write access via sk_ key)
- [ ] 7.2 Add `resources "/audit-logs", AuditLogController, only: [:index, :show]` to `:api_authenticated` scope (read access via pk_ or sk_ key)
- [ ] 7.3 Add `resources "/checkpoints", CheckpointController, only: [:create]` to `:api_write` scope
- [ ] 7.4 Add `resources "/checkpoints", CheckpointController, only: [:index]` to `:api_authenticated` scope
- [ ] 7.5 Add `post "/verify", VerificationController, :create` to `:api_authenticated` scope (verification is read-only despite being POST)

## 8. Controller Tests

- [ ] 8.1 Test `POST /api/v1/audit-logs` — 201 on valid data with sk_ key, 422 on invalid, 401 without auth, 403 with pk_ key (write required)
- [ ] 8.2 Test `GET /api/v1/audit-logs` — paginated response with meta, filter application, works with pk_ key
- [ ] 8.3 Test `GET /api/v1/audit-logs/:id` — 200 on found, 404 on missing, 404 on cross-account access attempt
- [ ] 8.4 Test `POST /api/v1/checkpoints` — 201 with entries, 422 without entries, requires sk_ key
- [ ] 8.5 Test `GET /api/v1/checkpoints` — 200 with checkpoint list, works with pk_ key
- [ ] 8.6 Test `POST /api/v1/verify` — 200 with verification result (valid chain), works with pk_ key
- [ ] 8.7 Test auth enforcement — all endpoints return 401 without token
- [ ] 8.8 Test account isolation — entries/checkpoints from account A not visible via account B's API key
