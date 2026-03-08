defmodule GA.Audit.Checkpoint do
  @moduledoc """
  Ecto schema for append-only account-scoped audit checkpoints.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_checkpoints" do
    belongs_to(:account, GA.Accounts.Account)

    field(:sequence_number, :integer)
    field(:checksum, :string)
    field(:signature, :string)
    field(:verified_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [:account_id, :sequence_number, :checksum, :signature, :verified_at])
    |> validate_required([:sequence_number, :checksum])
    |> unique_constraint([:account_id, :sequence_number],
      name: :audit_checkpoints_account_id_sequence_number_index
    )
    |> check_constraint(:checksum, name: :audit_checkpoints_checksum_format_check)
    |> foreign_key_constraint(:account_id)
  end
end
