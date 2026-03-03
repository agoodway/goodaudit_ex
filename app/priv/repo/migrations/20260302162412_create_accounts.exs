defmodule GA.Repo.Migrations.CreateAccounts do
  use Ecto.Migration

  def change do
    create table(:accounts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :slug, :string
      add :status, :string, null: false, default: "active"

      timestamps()
    end

    create unique_index(:accounts, [:slug])
  end
end
