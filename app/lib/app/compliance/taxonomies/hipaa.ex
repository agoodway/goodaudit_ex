defmodule GA.Compliance.Taxonomies.HIPAA do
  @moduledoc false
  @behaviour GA.Compliance.Taxonomy

  @taxonomy %{
    "access" => %{
      "phi" => ["phi_read", "phi_write", "phi_delete"],
      "system" => ["login", "logout", "session_timeout"]
    },
    "admin" => %{
      "user" => ["user_provision", "user_deprovision", "role_change"],
      "system" => ["config_change", "key_rotation"]
    },
    "disclosure" => %{
      "authorized" => ["treatment", "payment", "operations"],
      "unauthorized" => ["breach"]
    }
  }

  @impl true
  def framework, do: "hipaa"

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
