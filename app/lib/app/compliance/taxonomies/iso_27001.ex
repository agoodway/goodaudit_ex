defmodule GA.Compliance.Taxonomies.ISO27001 do
  @moduledoc false
  @behaviour GA.Compliance.Taxonomy

  @taxonomy %{
    "access_control" => %{
      "identity" => ["authentication", "authorization", "privilege_change"]
    },
    "asset_management" => %{
      "lifecycle" => ["classification", "handling", "disposal"]
    },
    "incident_management" => %{
      "lifecycle" => ["detection", "assessment", "response", "lessons_learned"]
    },
    "change_management" => %{
      "workflow" => ["request", "approval", "implementation", "review"]
    }
  }

  @impl true
  def framework, do: "iso_27001"

  @impl true
  def taxonomy_version, do: "1.0.0"

  @impl true
  def taxonomy, do: @taxonomy

  @impl true
  def actions do
    @taxonomy
    |> Map.values()
    |> Enum.flat_map(fn subcategories ->
      subcategories
      |> Map.values()
      |> List.flatten()
    end)
    |> Enum.uniq()
  end
end
