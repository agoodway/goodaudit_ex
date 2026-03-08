defmodule GAWeb.Api.V1.TaxonomyController do
  @moduledoc """
  Taxonomy discovery endpoints.
  """

  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Compliance.Taxonomy
  alias GAWeb.Api.V1.TaxonomyJSON

  alias GAWeb.Schemas.{
    ErrorResponse,
    TaxonomyListResponse,
    TaxonomyShowResponse
  }

  tags(["Taxonomies"])
  security([%{"bearerAuth" => []}])

  operation(:index,
    summary: "List registered framework taxonomies",
    responses: [
      ok: {"Taxonomy list", "application/json", TaxonomyListResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  @doc false
  def index(conn, _params) do
    taxonomies =
      Taxonomy.list_frameworks()
      |> Enum.map(fn framework ->
        {:ok, module} = Taxonomy.get(framework)
        %{framework: framework, version: module.taxonomy_version()}
      end)

    conn
    |> put_view(json: TaxonomyJSON)
    |> render(:index, taxonomies: taxonomies)
  end

  operation(:show,
    summary: "Get taxonomy tree for a framework",
    parameters: [
      framework: [in: :path, schema: %OpenApiSpex.Schema{type: :string}, required: true]
    ],
    responses: [
      ok: {"Taxonomy", "application/json", TaxonomyShowResponse},
      not_found: {"Unknown framework", "application/json", ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", ErrorResponse}
    ]
  )

  @doc false
  def show(conn, %{"framework" => framework}) do
    case Taxonomy.get(framework) do
      {:ok, module} ->
        conn
        |> put_view(json: TaxonomyJSON)
        |> render(:show,
          framework: framework,
          version: module.taxonomy_version(),
          taxonomy: module.taxonomy()
        )

      {:error, :unknown_framework} ->
        conn
        |> put_status(:not_found)
        |> json(%{status: 404, message: "Unknown framework: #{framework}"})
    end
  end
end
