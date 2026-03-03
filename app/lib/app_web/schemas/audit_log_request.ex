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
      user_id: %Schema{type: :string, format: :uuid},
      user_role: %Schema{type: :string},
      session_id: %Schema{type: :string, nullable: true},
      action: %Schema{
        type: :string,
        enum: GA.Audit.Log.valid_actions()
      },
      resource_type: %Schema{type: :string},
      resource_id: %Schema{type: :string},
      timestamp: %Schema{type: :string, format: :"date-time", nullable: true},
      source_ip: %Schema{type: :string, nullable: true},
      user_agent: %Schema{type: :string, nullable: true},
      outcome: %Schema{
        type: :string,
        enum: GA.Audit.Log.valid_outcomes()
      },
      failure_reason: %Schema{type: :string, nullable: true},
      phi_accessed: %Schema{type: :boolean},
      metadata: %Schema{type: :object, additionalProperties: true}
    },
    required: [:user_id, :user_role, :action, :resource_type, :resource_id, :outcome]
  })
end
