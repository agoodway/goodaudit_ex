defmodule GAWeb.Schemas.ErrorResponse do
  @moduledoc """
  OpenAPI schema for error response payloads.
  """
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ErrorResponse",
    type: :object,
    properties: %{
      errors: %Schema{
        type: :object,
        additionalProperties: true,
        nullable: true
      },
      status: %Schema{type: :integer, nullable: true},
      message: %Schema{type: :string, nullable: true}
    }
  })
end
