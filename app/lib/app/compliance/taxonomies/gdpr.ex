defmodule GA.Compliance.Taxonomies.GDPR do
  @moduledoc false
  @behaviour GA.Compliance.Taxonomy

  @taxonomy %{
    "processing" => %{
      "lifecycle" => ["collection", "storage", "use", "disclosure", "erasure"]
    },
    "subject_request" => %{
      "rights" => ["access", "rectification", "erasure", "portability", "restriction", "objection"]
    },
    "consent" => %{
      "management" => ["grant", "withdraw", "renewal"]
    },
    "transfer" => %{
      "cross_border" => ["cross_border", "adequacy_decision", "standard_clauses"]
    }
  }

  @impl true
  def framework, do: "gdpr"

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
