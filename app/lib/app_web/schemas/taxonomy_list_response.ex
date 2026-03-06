defmodule GAWeb.Schemas.TaxonomyListResponse do
  @moduledoc """
  OpenAPI schema for listing taxonomy frameworks and versions.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "TaxonomyListResponse",
    type: :object,
    properties: %{
      data: %Schema{
        type: :array,
        items: %Schema{
          type: :object,
          properties: %{
            framework: %Schema{type: :string},
            version: %Schema{type: :string}
          },
          required: [:framework, :version]
        }
      }
    },
    required: [:data]
  })
end
