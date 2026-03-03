defmodule GAWeb.Schemas.VerificationResponse do
  @moduledoc """
  OpenAPI schema for chain verification response payloads.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "VerificationResponse",
    type: :object,
    properties: %{
      valid: %Schema{type: :boolean},
      total_entries: %Schema{type: :integer},
      verified_entries: %Schema{type: :integer},
      first_failure: %Schema{type: :object, additionalProperties: true, nullable: true},
      sequence_gaps: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            expected: %Schema{type: :integer},
            found: %Schema{type: :integer},
            missing: %Schema{type: :array, items: %Schema{type: :integer}},
            missing_count: %Schema{type: :integer},
            missing_truncated: %Schema{type: :boolean},
            missing_range: %Schema{
              type: :object,
              nullable: true,
              properties: %{
                from: %Schema{type: :integer},
                to: %Schema{type: :integer}
              }
            }
          },
          required: [:expected, :found, :missing, :missing_count, :missing_truncated]
        }
      },
      checkpoint_results: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            sequence_number: %Schema{type: :integer},
            valid: %Schema{type: :boolean}
          },
          required: [:sequence_number, :valid]
        }
      },
      duration_ms: %Schema{type: :integer}
    },
    required: [
      :valid,
      :total_entries,
      :verified_entries,
      :first_failure,
      :sequence_gaps,
      :checkpoint_results,
      :duration_ms
    ]
  })
end
