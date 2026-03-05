defmodule GAWeb.Schemas.AuditLogRequest do
  @moduledoc """
  OpenAPI schema for creating an audit log entry.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogRequest",
    type: :object,
    properties: %{
      actor_id: %Schema{type: :string},
      action: %Schema{
        type: :string,
        enum: GA.Audit.Log.valid_actions()
      },
      resource_type: %Schema{type: :string},
      resource_id: %Schema{type: :string},
      timestamp: %Schema{type: :string, format: :"date-time", nullable: true},
      outcome: %Schema{
        type: :string,
        enum: GA.Audit.Log.valid_outcomes()
      },
      extensions: %Schema{type: :object, additionalProperties: true},
      metadata: %Schema{type: :object, additionalProperties: true}
    },
    required: [:actor_id, :action, :resource_type, :resource_id, :outcome]
  })
end
