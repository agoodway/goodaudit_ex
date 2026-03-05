defmodule GA.Audit.Log do
  @moduledoc """
  Ecto schema for append-only audit log entries.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_actions ~w(create read update delete export login logout)
  @valid_outcomes ~w(success failure)

  schema "audit_logs" do
    belongs_to(:account, GA.Accounts.Account)

    field(:sequence_number, :integer)
    field(:checksum, :string)
    field(:previous_checksum, :string)
    field(:user_id, :string)
    field(:user_role, :string)
    field(:session_id, :string)
    field(:action, :string)
    field(:resource_type, :string)
    field(:resource_id, :string)
    field(:timestamp, :utc_datetime_usec)
    field(:source_ip, :string)
    field(:user_agent, :string)
    field(:outcome, :string)
    field(:failure_reason, :string)
    field(:phi_accessed, :boolean, default: false)
    field(:frameworks, {:array, :string}, default: [])
    field(:metadata, :map, default: %{})

    timestamps(type: :utc_datetime_usec)
  end

  def valid_actions, do: @valid_actions
  def valid_outcomes, do: @valid_outcomes

  @doc """
  Validates externally provided audit log attributes.
  Chain and tenant fields are injected by the context layer.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :user_id,
      :user_role,
      :session_id,
      :action,
      :resource_type,
      :resource_id,
      :timestamp,
      :source_ip,
      :user_agent,
      :outcome,
      :failure_reason,
      :phi_accessed,
      :frameworks,
      :metadata
    ])
    |> validate_required([
      :user_id,
      :user_role,
      :action,
      :resource_type,
      :resource_id,
      :timestamp,
      :outcome
    ])
    |> validate_inclusion(:action, @valid_actions)
    |> validate_inclusion(:outcome, @valid_outcomes)
    |> validate_failure_reason()
    |> check_constraint(:action, name: :audit_logs_action_valid_check)
    |> check_constraint(:outcome, name: :audit_logs_outcome_valid_check)
  end

  defp validate_failure_reason(changeset) do
    case get_field(changeset, :outcome) do
      "failure" -> validate_required(changeset, [:failure_reason])
      _ -> changeset
    end
  end
end
