defmodule GAWeb.Schemas.CheckpointResponse do
  @moduledoc """
  OpenAPI schema for checkpoint response payloads.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CheckpointResponse",
    type: :object,
    properties: %{
      data: %Schema{
        oneOf: [
          %Schema{
            type: :object,
            properties: %{
              id: %Schema{type: :string, format: :uuid},
              account_id: %Schema{type: :string, format: :uuid},
              sequence_number: %Schema{type: :integer},
              checksum: %Schema{type: :string},
              signature: %Schema{type: :string, nullable: true},
              verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
              signing_key_id: %Schema{type: :string, format: :uuid, nullable: true},
              inserted_at: %Schema{type: :string, format: :"date-time"},
              updated_at: %Schema{type: :string, format: :"date-time"}
            },
            required: [
              :id,
              :account_id,
              :sequence_number,
              :checksum,
              :signature,
              :verified_at,
              :signing_key_id,
              :inserted_at,
              :updated_at
            ]
          },
          %Schema{
            type: :array,
            items: %Schema{
              type: :object,
              properties: %{
                id: %Schema{type: :string, format: :uuid},
                account_id: %Schema{type: :string, format: :uuid},
                sequence_number: %Schema{type: :integer},
                checksum: %Schema{type: :string},
                signature: %Schema{type: :string, nullable: true},
                verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
                signing_key_id: %Schema{type: :string, format: :uuid, nullable: true},
                inserted_at: %Schema{type: :string, format: :"date-time"},
                updated_at: %Schema{type: :string, format: :"date-time"}
              },
              required: [
                :id,
                :account_id,
                :sequence_number,
                :checksum,
                :signature,
                :verified_at,
                :signing_key_id,
                :inserted_at,
                :updated_at
              ]
            }
          }
        ]
      }
    },
    required: [:data]
  })
end
