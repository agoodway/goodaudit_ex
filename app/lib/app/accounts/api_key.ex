defmodule GA.Accounts.ApiKey do
  @moduledoc """
  Schema for API keys used for programmatic authentication.
  Supports public (read-only) and private (read/write) keys.
  Keys are scoped to a user's membership in an account.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          type: :public | :private,
          token_prefix: String.t() | nil,
          token_hash: String.t() | nil,
          status: :active | :revoked,
          last_used_at: DateTime.t() | NaiveDateTime.t() | nil,
          expires_at: DateTime.t() | NaiveDateTime.t() | nil,
          account_user_id: Ecto.UUID.t() | nil,
          account_user: GA.Accounts.AccountUser.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "api_keys" do
    field :name, :string
    field :type, Ecto.Enum, values: [:public, :private], default: :public
    field :token_prefix, :string
    field :token_hash, :string
    field :status, Ecto.Enum, values: [:active, :revoked], default: :active
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime

    belongs_to :account_user, GA.Accounts.AccountUser

    timestamps()
  end

  @doc "Check if API key can perform write operations."
  def can_write?(%__MODULE__{type: :private}), do: true
  def can_write?(_), do: false

  @doc "Generate a new API key token."
  def generate_token(type) do
    prefix = if type == :private, do: "sk_", else: "pk_"
    random_bytes = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    prefix <> random_bytes
  end

  @doc "Hash a token for storage."
  def hash_token(token) do
    :crypto.hash(:sha256, token) |> Base.encode64()
  end

  @doc "Creates a changeset for an API key."
  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:name, :type, :expires_at, :account_user_id])
    |> validate_required([:name, :type, :account_user_id])
    |> foreign_key_constraint(:account_user_id)
  end
end
