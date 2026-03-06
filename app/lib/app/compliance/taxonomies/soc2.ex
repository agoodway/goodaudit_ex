defmodule GA.Compliance.Taxonomies.SOC2 do
  @moduledoc false
  @behaviour GA.Compliance.Taxonomy

  @taxonomy %{
    "change" => %{
      "deployment" => ["deploy", "config_update", "rollback"]
    },
    "access" => %{
      "production" => ["production_access", "privilege_escalation", "data_export"]
    },
    "incident" => %{
      "lifecycle" => ["detection", "response", "resolution"]
    },
    "monitoring" => %{
      "alerts" => ["alert_triggered", "alert_acknowledged"]
    }
  }

  @impl true
  def framework, do: "soc2"

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
