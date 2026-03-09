# GoodauditEx

Elixir client for the GoodAudit API. Provides typed structs and functions for audit logging, checkpoints, verification, taxonomies, and action mappings.

## Installation

Add `goodaudit_ex` to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:goodaudit_ex, "~> 0.1.0"}
  ]
end
```

## Configuration

### Application config

```elixir
# config/config.exs
config :goodaudit_ex,
  base_url: "https://api.goodaudit.io",
  api_key: "your-api-key"
```

### Runtime / per-request

```elixir
client = GoodauditEx.client(
  base_url: "https://api.goodaudit.io",
  api_key: "sk_..."
)
```

You can also pass `req_options` to customize the underlying [Req](https://hexdocs.pm/req) HTTP client:

```elixir
client = GoodauditEx.client(
  api_key: "sk_...",
  req_options: [receive_timeout: 30_000]
)
```

## Usage

Every function takes a `%GoodauditEx.Client{}` as the first argument and returns `{:ok, struct}` or `{:error, reason}`.

```elixir
client = GoodauditEx.client(api_key: "sk_...")

# Create an audit log entry
{:ok, entry} = GoodauditEx.create_audit_log(client, %{
  actor_id: "user_123",
  action: "user.login",
  resource_type: "session",
  resource_id: "sess_456",
  outcome: "success"
})

# List audit logs with filters
{:ok, logs} = GoodauditEx.list_audit_logs(client, action: "user.login", limit: 50)

# Get a single entry
{:ok, entry} = GoodauditEx.get_audit_log(client, "550e8400-...")

# Create a checkpoint
{:ok, checkpoint} = GoodauditEx.create_checkpoint(client)

# Verify chain integrity
{:ok, report} = GoodauditEx.verify(client)

# List taxonomies
{:ok, taxonomies} = GoodauditEx.list_taxonomies(client)

# Get a taxonomy tree
{:ok, taxonomy} = GoodauditEx.get_taxonomy(client, "hipaa")

# Action mappings
{:ok, mappings} = GoodauditEx.list_action_mappings(client, framework: "hipaa")
{:ok, mapping} = GoodauditEx.create_action_mapping(client, %{
  custom_action: "user.login",
  framework: "hipaa",
  taxonomy_path: "access.authentication.login"
})
{:ok, report} = GoodauditEx.validate_action_mappings(client, %{framework: "hipaa"})
```

## Error handling

API errors return `{:error, %{status: integer, body: map}}`:

```elixir
case GoodauditEx.create_audit_log(client, params) do
  {:ok, result} ->
    # handle success

  {:error, %{status: 422, body: body}} ->
    # validation error

  {:error, %{status: 401}} ->
    # invalid API key

  {:error, %{status: 403}} ->
    # insufficient permissions (public key for write operation)

  {:error, %Req.TransportError{reason: reason}} ->
    # connection error (:econnrefused, :timeout, etc.)
end
```

## Response types

All responses are typed structs under `GoodauditEx.Schemas`. Schemas are generated at compile time from `openapi.json` and recompile automatically when the spec changes.

| Function | Response struct |
|----------|---------------|
| `list_audit_logs/2` | `AuditLogListResponse` |
| `create_audit_log/2` | `AuditLogResponse` |
| `get_audit_log/2` | `AuditLogResponse` |
| `list_checkpoints/1` | `CheckpointResponse` |
| `create_checkpoint/1` | `CheckpointResponse` |
| `verify/1` | `VerificationResponse` |
| `list_taxonomies/1` | `TaxonomyListResponse` |
| `get_taxonomy/2` | `TaxonomyShowResponse` |
| `list_action_mappings/2` | `ActionMappingListResponse` |
| `create_action_mapping/2` | `ActionMappingResponse` |
| `validate_action_mappings/2` | `ActionMappingValidateResponse` |
| `update_action_mapping/3` | `ActionMappingResponse` |
| `delete_action_mapping/2` | `ActionMappingResponse` |

## Testing

```sh
mix test
```

## License

See [LICENSE](LICENSE) for details.
