defmodule GA.Compliance.Frameworks.GDPR do
  @moduledoc false
  @behaviour GA.Compliance.Framework

  @required_fields [:actor_id, :action, :resource_type, :resource_id, :timestamp, :outcome]

  @impl true
  def name, do: "GDPR"

  @impl true
  def required_fields, do: @required_fields

  @impl true
  def recommended_fields, do: [:source_ip, :session_id, :user_agent]

  @impl true
  def default_retention_days, do: 1825

  @impl true
  def verification_cadence_hours, do: 48

  @impl true
  def extension_schema do
    %{}
  end

  @impl true
  def event_taxonomy do
    ["privacy.access", "privacy.export", "privacy.delete", "privacy.restrict", "privacy.rectify"]
  end
end
