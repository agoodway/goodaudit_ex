defmodule GA.Repo.Migrations.CreateAccountActionMappings do
  use Ecto.Migration

  def change do
    create table(:account_action_mappings, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:custom_action, :string, null: false)
      add(:framework, :string, null: false)
      add(:taxonomy_path, :string, null: false)
      add(:taxonomy_version, :string, null: false)

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: false)
    end

    create(index(:account_action_mappings, [:account_id]))
    create(index(:account_action_mappings, [:account_id, :framework]))

    create(
      unique_index(:account_action_mappings, [:account_id, :custom_action, :framework],
        name: :account_action_mappings_account_id_custom_action_framework_index
      )
    )
  end
end
