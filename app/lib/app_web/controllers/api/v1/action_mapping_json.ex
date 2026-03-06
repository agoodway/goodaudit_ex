defmodule GAWeb.Api.V1.ActionMappingJSON do
  @moduledoc """
  JSON rendering for action mapping responses.
  """

  def index(%{mappings: mappings}), do: %{data: Enum.map(mappings, &data/1)}
  def show(%{mapping: mapping}), do: %{data: data(mapping)}
  def validate(%{report: report}), do: %{data: report}

  def data(mapping) do
    %{
      id: mapping.id,
      custom_action: mapping.custom_action,
      framework: mapping.framework,
      taxonomy_path: mapping.taxonomy_path,
      taxonomy_version: mapping.taxonomy_version,
      created_at: iso8601(mapping.created_at)
    }
  end

  defp iso8601(nil), do: nil
  defp iso8601(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
end
