defmodule GA.Compliance.Frameworks.PCIDSS do
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
  def name, do: "PCI-DSS v4"

  @impl true
  def required_fields, do: @required_fields

  @impl true
  def recommended_fields, do: [:failure_reason, :user_agent]

  @impl true
  def default_retention_days, do: 365

  @impl true
  def verification_cadence_hours, do: 12

  @impl true
  def extension_schema do
    %{}
  end

  @impl true
  def event_taxonomy do
    ["cardholder.access", "cardholder.change", "payment.auth", "payment.capture", "payment.refund"]
  end
end
