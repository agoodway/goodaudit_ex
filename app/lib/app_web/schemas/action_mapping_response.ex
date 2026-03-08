defmodule GAWeb.Schemas.ActionMappingResponse do
  @moduledoc """
  OpenAPI schema for a single action mapping.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ActionMappingResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          id: %Schema{type: :string, format: :uuid},
          custom_action: %Schema{type: :string},
          framework: %Schema{type: :string},
          taxonomy_path: %Schema{type: :string},
          taxonomy_version: %Schema{type: :string},
          created_at: %Schema{type: :string, format: :"date-time"}
        },
        required: [
          :id,
          :custom_action,
          :framework,
          :taxonomy_path,
          :taxonomy_version,
          :created_at
        ]
      }
    },
    required: [:data]
  })
end
