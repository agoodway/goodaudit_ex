defmodule GA.Accounts.Account do
  @moduledoc """
  Schema for accounts (organizations/tenants).
  Users can belong to multiple accounts.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Inspect, except: [:hmac_key]}
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "accounts" do
    field :name, :string
    field :slug, :string
    field :status, Ecto.Enum, values: [:active, :suspended], default: :active
    field :hmac_key, :binary, redact: true

    has_many :account_users, GA.Accounts.AccountUser
    has_many :users, through: [:account_users, :user]

    timestamps()
  end

  @doc "Creates a changeset for an account."
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:name, :slug, :status])
    |> validate_required([:name])
    |> maybe_generate_slug()
    |> validate_required([:slug])
    |> unique_constraint(:slug)
  end

  defp maybe_generate_slug(changeset) do
    case get_field(changeset, :slug) do
      nil ->
        name = get_field(changeset, :name)

        if name do
          slug =
            name
            |> String.downcase()
            |> String.replace(~r/[^a-z0-9]+/, "-")
            |> String.trim("-")

          put_change(changeset, :slug, slug)
        else
          changeset
        end

      _ ->
        changeset
    end
  end
end
