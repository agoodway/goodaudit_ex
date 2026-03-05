defmodule GA.Repo.Migrations.CreateAccountComplianceFrameworks do
  use Ecto.Migration

  def change do
    create table(:account_compliance_frameworks, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:account_id, references(:accounts, type: :binary_id, on_delete: :delete_all),
        null: false
      )

      add(:framework_id, :string, null: false)

      add(:activated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() at time zone 'utc')")
      )

      add(:config_overrides, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:account_compliance_frameworks, [:account_id]))
    create(unique_index(:account_compliance_frameworks, [:account_id, :framework_id]))
  end
end
