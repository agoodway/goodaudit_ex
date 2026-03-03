## ALREADY IMPLEMENTED — No Changes Required

### Requirement: OpenAPI root specification (IMPLEMENTED)

`GAWeb.ApiSpec` implements the `OpenApiSpex.OpenApi` behaviour and returns a spec with title, version, a bearer security scheme, and paths resolved from `GAWeb.Router`.

### Requirement: OpenAPI JSON endpoint (IMPLEMENTED)

`GET /api/v1/openapi` returns the full OpenAPI specification as JSON. This endpoint does not require authentication.

### Requirement: Swagger UI (IMPLEMENTED)

`GET /api/v1/docs` serves Swagger UI in dev and test environments.
