defmodule GAWeb.Schemas.AuditLogResponse do
  @moduledoc """
  OpenAPI schema for a single audit log response payload.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, format: :uuid},
          account_id: %Schema{type: :string, format: :uuid},
          sequence_number: %Schema{type: :integer},
          checksum: %Schema{type: :string},
          previous_checksum: %Schema{type: :string, nullable: true},
          actor_id: %Schema{type: :string},
          action: %Schema{type: :string},
          resource_type: %Schema{type: :string},
          resource_id: %Schema{type: :string},
          timestamp: %Schema{type: :string, format: :"date-time"},
          outcome: %Schema{type: :string},
          extensions: %Schema{type: :object, additionalProperties: true},
          frameworks: %Schema{type: :array, items: %Schema{type: :string}},
          metadata: %Schema{type: :object, additionalProperties: true},
          inserted_at: %Schema{type: :string, format: :"date-time"},
          updated_at: %Schema{type: :string, format: :"date-time"}
        },
        required: [
          :id,
          :account_id,
          :sequence_number,
          :checksum,
          :actor_id,
          :action,
          :resource_type,
          :resource_id,
          :timestamp,
          :outcome,
          :extensions,
          :frameworks,
          :metadata,
          :inserted_at,
          :updated_at
        ]
      }
    },
    required: [:data]
  })
end
