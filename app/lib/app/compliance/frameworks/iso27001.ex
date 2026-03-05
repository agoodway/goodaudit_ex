defmodule GA.Compliance.Frameworks.ISO27001 do
  @moduledoc false
  @behaviour GA.Compliance.Framework

  @required_fields [
    :actor_id,
    :action,
    :resource_type,
    :resource_id,
    :timestamp,
    :outcome
  ]

  @impl true
  def name, do: "ISO 27001"

  @impl true
  def required_fields, do: @required_fields

  @impl true
  def recommended_fields, do: [:session_id, :user_role, :user_agent]

  @impl true
  def default_retention_days, do: 1095

  @impl true
  def verification_cadence_hours, do: 24

  @impl true
  def extension_schema do
    %{}
  end

  @impl true
  def event_taxonomy do
    ["ism.access", "ism.change", "ism.exception", "ism.auth"]
  end
end
