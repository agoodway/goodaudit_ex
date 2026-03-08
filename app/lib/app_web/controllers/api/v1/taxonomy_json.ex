defmodule GAWeb.Api.V1.TaxonomyJSON do
  @moduledoc """
  JSON rendering for taxonomy API responses.
  """

  @doc false
  def index(%{taxonomies: taxonomies}) do
    %{data: Enum.map(taxonomies, &summary/1)}
  end

  @doc false
  def show(%{framework: framework, version: version, taxonomy: taxonomy}) do
    %{
      data: %{
        framework: framework,
        version: version,
        taxonomy: taxonomy
      }
    }
  end

  defp summary(%{framework: framework, version: version}) do
    %{
      framework: framework,
      version: version
    }
  end
end
