defmodule GA.Compliance.Taxonomies.PCIDSS do
  @moduledoc false
  @behaviour GA.Compliance.Taxonomy

  @taxonomy %{
    "cardholder" => %{
      "data" => ["data_access", "data_modification", "data_deletion"]
    },
    "authentication" => %{
      "session" => ["login", "logout", "failed_auth", "mfa_challenge"]
    },
    "key_management" => %{
      "lifecycle" => ["key_creation", "key_rotation", "key_destruction"]
    },
    "network" => %{
      "security" => ["firewall_change", "access_rule_change"]
    }
  }

  @impl true
  def framework, do: "pci_dss"

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
