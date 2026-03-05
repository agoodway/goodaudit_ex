defmodule GA.Compliance.Framework do
  @moduledoc """
  Behaviour contract for built-in and custom compliance framework profiles.
  """

  @callback name() :: String.t()
  @callback required_fields() :: [atom()]
  @callback recommended_fields() :: [atom()]
  @callback default_retention_days() :: pos_integer()
  @callback verification_cadence_hours() :: pos_integer()
  @callback extension_schema() :: map()
  @callback event_taxonomy() :: [String.t()]
end
