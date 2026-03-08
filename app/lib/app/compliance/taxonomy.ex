defmodule GA.Compliance.Taxonomy do
  @moduledoc """
  Behaviour for framework event taxonomies used by compliance action mapping.
  """

  @typedoc """
  Nested taxonomy tree where leaf nodes are action string lists.
  """
  @type taxonomy_tree :: %{optional(String.t()) => taxonomy_tree() | [String.t()]}

  @callback framework() :: String.t()
  @callback taxonomy_version() :: String.t()
  @callback taxonomy() :: taxonomy_tree()
  @callback actions() :: [String.t()]

  @registry %{
    "gdpr" => GA.Compliance.Taxonomies.GDPR,
    "hipaa" => GA.Compliance.Taxonomies.HIPAA,
    "iso_27001" => GA.Compliance.Taxonomies.ISO27001,
    "pci_dss" => GA.Compliance.Taxonomies.PCIDSS,
    "soc2" => GA.Compliance.Taxonomies.SOC2
  }

  @doc """
  Resolves a framework identifier to a taxonomy module.
  """
  @spec get(String.t()) :: {:ok, module()} | {:error, :unknown_framework}
  def get("iso27001"), do: {:ok, GA.Compliance.Taxonomies.ISO27001}

  def get(framework) when is_binary(framework) do
    case Map.fetch(@registry, framework) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unknown_framework}
    end
  end

  def get(_framework), do: {:error, :unknown_framework}

  @doc """
  Lists registered framework identifiers.
  """
  @spec list_frameworks() :: [String.t()]
  def list_frameworks, do: @registry |> Map.keys() |> Enum.sort()

  @doc """
  Resolves a taxonomy path (exact or wildcard) to matching canonical actions.
  """
  @spec resolve_path(module(), String.t()) :: {:ok, [String.t()]} | {:error, :invalid_path}
  def resolve_path(module, path) when is_atom(module) and is_binary(path) do
    with true <- Code.ensure_loaded?(module),
         true <- function_exported?(module, :taxonomy, 0),
         taxonomy when is_map(taxonomy) <- module.taxonomy() do
      resolve_segments(taxonomy, String.split(path, ".", trim: true))
    else
      _ -> {:error, :invalid_path}
    end
  end

  def resolve_path(_module, _path), do: {:error, :invalid_path}

  defp resolve_segments(taxonomy, [category, "*"]) do
    with %{} = subcategories <- Map.get(taxonomy, category) do
      {:ok,
       subcategories
       |> Map.keys()
       |> Enum.sort()
       |> Enum.flat_map(fn subcategory ->
         subcategories
         |> Map.get(subcategory, [])
         |> normalize_actions()
       end)}
    else
      _ -> {:error, :invalid_path}
    end
  end

  defp resolve_segments(taxonomy, [category, subcategory, "*"]) do
    with %{} = subcategories <- Map.get(taxonomy, category),
         actions when is_list(actions) <- Map.get(subcategories, subcategory) do
      {:ok, normalize_actions(actions)}
    else
      _ -> {:error, :invalid_path}
    end
  end

  defp resolve_segments(taxonomy, [category, subcategory, action]) do
    with %{} = subcategories <- Map.get(taxonomy, category),
         actions when is_list(actions) <- Map.get(subcategories, subcategory),
         true <- action in actions do
      {:ok, [action]}
    else
      _ -> {:error, :invalid_path}
    end
  end

  defp resolve_segments(_taxonomy, _segments), do: {:error, :invalid_path}

  defp normalize_actions(actions) do
    actions
    |> Enum.map(&to_string/1)
    |> Enum.uniq()
  end
end
