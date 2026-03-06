defmodule GAWeb.Schemas.ActionMappingValidateResponse do
  @moduledoc """
  OpenAPI schema for action mapping dry-run validation.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ActionMappingValidateResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          recognized: %Schema{type: :array, items: %Schema{type: :string}},
          unmapped: %Schema{type: :array, items: %Schema{type: :string}}
        },
        required: [:recognized, :unmapped]
      }
    },
    required: [:data]
  })
end
