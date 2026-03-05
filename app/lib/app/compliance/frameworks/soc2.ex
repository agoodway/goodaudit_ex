defmodule GA.Compliance.Frameworks.SOC2 do
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
  def name, do: "SOC 2 Type II"

  @impl true
  def required_fields, do: @required_fields

  @impl true
  def recommended_fields, do: [:user_role, :user_agent]

  @impl true
  def default_retention_days, do: 2555

  @impl true
  def verification_cadence_hours, do: 24

  @impl true
  def extension_schema do
    %{}
  end

  @impl true
  def event_taxonomy do
    ["security.access", "security.change", "security.exception", "security.auth"]
  end
end
