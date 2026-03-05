defmodule GA.Compliance.Frameworks.HIPAA do
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

  @extension_schema %{
    required: %{
      "phi_accessed" => :boolean,
      "user_role" => :string
    },
    optional: %{
      "source_ip" => :string,
      "session_id" => :string,
      "failure_reason" => :string,
      "user_agent" => :string
    }
  }

  @impl true
  def name, do: "HIPAA"

  @impl true
  def required_fields, do: @required_fields

  @impl true
  def recommended_fields, do: [:session_id, :outcome, :user_agent]

  @impl true
  def default_retention_days, do: 2555

  @impl true
  def verification_cadence_hours, do: 24

  @impl true
  def extension_schema do
    @extension_schema
  end

  @impl true
  def event_taxonomy do
    ["ephi.access", "ephi.modify", "ephi.disclosure", "account.login", "account.logout"]
  end
end
