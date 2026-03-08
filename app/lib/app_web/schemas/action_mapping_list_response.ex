defmodule GAWeb.Schemas.ActionMappingListResponse do
  @moduledoc """
  OpenAPI schema for action mapping lists.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ActionMappingListResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
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
      }
    },
    required: [:data]
  })
end
