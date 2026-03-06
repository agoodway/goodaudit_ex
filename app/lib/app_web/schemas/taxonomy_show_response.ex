defmodule GAWeb.Schemas.TaxonomyShowResponse do
  @moduledoc """
  OpenAPI schema for a single framework taxonomy payload.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "TaxonomyShowResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :object,
        properties: %{
          framework: %Schema{type: :string},
          version: %Schema{type: :string},
          taxonomy: %Schema{type: :object, additionalProperties: true}
        },
        required: [:framework, :version, :taxonomy]
      }
    },
    required: [:data]
  })
end
