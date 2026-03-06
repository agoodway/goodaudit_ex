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
end
