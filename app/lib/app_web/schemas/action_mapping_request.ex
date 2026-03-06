defmodule GAWeb.Schemas.ActionMappingRequest do
  @moduledoc """
  OpenAPI schema for action mapping create/update payloads.
  """

  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ActionMappingRequest",
    type: :object,
    properties: %{
      custom_action: %Schema{type: :string},
      framework: %Schema{type: :string},
      taxonomy_path: %Schema{type: :string}
    },
    required: [:custom_action, :framework, :taxonomy_path]
  })
end
