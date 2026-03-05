defmodule GAWeb.Schemas.AuditLogListResponse do
  @moduledoc """
  OpenAPI schema for a paginated audit log list response.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogListResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            id: %Schema{type: :string, format: :uuid},
            account_id: %Schema{type: :string, format: :uuid},
            sequence_number: %Schema{type: :integer},
            checksum: %Schema{type: :string},
            previous_checksum: %Schema{type: :string, nullable: true},
            user_id: %Schema{type: :string},
            user_role: %Schema{type: :string},
            session_id: %Schema{type: :string, nullable: true},
            action: %Schema{type: :string},
            resource_type: %Schema{type: :string},
            resource_id: %Schema{type: :string},
            timestamp: %Schema{type: :string, format: :"date-time"},
            source_ip: %Schema{type: :string, nullable: true},
            user_agent: %Schema{type: :string, nullable: true},
            outcome: %Schema{type: :string},
            failure_reason: %Schema{type: :string, nullable: true},
            phi_accessed: %Schema{type: :boolean},
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
            :user_id,
            :user_role,
            :action,
            :resource_type,
            :resource_id,
            :timestamp,
            :outcome,
            :phi_accessed,
            :frameworks,
            :metadata,
            :inserted_at,
            :updated_at
          ]
        }
      },
      meta: %Schema{
        type: :object,
        properties: %{
          next_cursor: %Schema{type: :integer, nullable: true},
          count: %Schema{type: :integer}
        },
        required: [:next_cursor, :count]
      }
    },
    required: [:data, :meta]
  })
end
