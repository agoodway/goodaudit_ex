## Context

All backend logic and API infrastructure exist. The app has per-account API keys with read/write separation, OpenAPI spec generation, and standardized error handling. This change adds the HTTP surface — controllers, JSON views, OpenAPI schemas, and routes — completing the audit API.

## Goals / Non-Goals

**Goals:**
- Account-scoped RESTful endpoints for all audit operations
- Leverage existing `GAWeb.Plugs.ApiAuth` for account context (no new auth code)
- OpenAPI-annotated controllers for auto-generated documentation
- Consistent JSON response format: `{"data": ...}` for success, `{"errors": ...}` for validation failures
- Accept flat params (no wrapping key like `{"audit_log": {...}}` required)
- Controller-level parameter parsing (string query params -> typed values)
- Write operations require private keys (`sk_*`), read operations accept any key type

**Non-Goals:**
- Request validation via OpenApiSpex `cast_and_validate` — manual parsing is simpler for MVP
- Rate limiting — can be added per-account later
- Webhook notifications — out of scope
- Bulk operations — single entry creation only
- New auth mechanisms — existing per-account API keys are sufficient

## Decisions

### Account context from API key, not URL path
The account is resolved from the API key by the existing `GAWeb.Plugs.ApiAuth`. Controllers access it via `conn.assigns.current_account`. This means URLs stay flat (`/api/v1/audit-logs`) rather than nested (`/api/v1/accounts/:id/audit-logs`). Simpler for consumers and consistent with the existing API key model where one key = one account.

### Write vs read pipeline separation
- **Write endpoints** (POST audit-logs, POST checkpoints): Use `:api_write` pipeline, requiring private `sk_*` keys. This ensures only authorized server-to-server integrations can create audit entries.
- **Read endpoints** (GET audit-logs, GET checkpoints, POST verify): Use `:api_authenticated` pipeline, allowing both `pk_*` and `sk_*` keys. Verification is a read operation despite being POST (it doesn't mutate data).

### Flat params accepted
Controllers accept `{"user_id": "...", "action": "..."}` directly, not wrapped in `{"audit_log": {...}}`. This is simpler for API consumers.

### No UPDATE/DELETE/PATCH routes
`resources` is restricted to `only: [:create, :index, :show]` for audit logs and `only: [:create, :index]` for checkpoints. No update or delete routes exist. This is the API-layer enforcement of append-only semantics.

### Verification returns 200 even for invalid chains
The verification endpoint always returns 200 — the `valid` field in the response body indicates chain integrity. A 200 with `valid: false` means "verification succeeded in detecting a problem," not "the request failed."

### OpenAPI schemas as separate modules
One module per schema (e.g., `GAWeb.Schemas.AuditLogRequest`) rather than inline definitions. This keeps controller files focused on logic and makes schemas reusable.

### Parameter parsing in controller
Query string values arrive as strings. The controller parses them to correct types (integers, booleans, datetimes) before passing to the context. This keeps the context accepting clean typed values.

### Add `:no_entries` handler to existing FallbackController
Rather than creating a new fallback controller, add a `call/2` clause to the existing `GAWeb.FallbackController` for `{:error, :no_entries}` -> 422.

## Risks / Trade-offs

### Large verification responses
A chain with thousands of gaps would produce a large `sequence_gaps` array. Acceptable for MVP — in practice, gaps should be rare (zero in normal operation).

### No request body validation beyond changeset
Invalid JSON structure or extra fields are silently ignored. The changeset validates required fields and enums. Full OpenApiSpex validation can be added later without changing the API contract.
