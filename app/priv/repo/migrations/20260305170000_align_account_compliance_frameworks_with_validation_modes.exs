defmodule GA.Repo.Migrations.AlignAccountComplianceFrameworksWithValidationModes do
  use Ecto.Migration

  def up do
    rename(table(:account_compliance_frameworks), :framework_id, to: :framework)
    rename(table(:account_compliance_frameworks), :activated_at, to: :enabled_at)

    alter table(:account_compliance_frameworks) do
      add(:action_validation_mode, :string, null: false, default: "flexible")
    end

    drop_if_exists(
      unique_index(:account_compliance_frameworks, [:account_id, :framework_id],
        name: :account_compliance_frameworks_account_id_framework_id_index
      )
    )

    create_if_not_exists(
      unique_index(:account_compliance_frameworks, [:account_id, :framework],
        name: :account_compliance_frameworks_account_id_framework_index
      )
    )
  end

  def down do
    drop_if_exists(
      unique_index(:account_compliance_frameworks, [:account_id, :framework],
        name: :account_compliance_frameworks_account_id_framework_index
      )
    )

    alter table(:account_compliance_frameworks) do
      remove(:action_validation_mode)
    end

    rename(table(:account_compliance_frameworks), :framework, to: :framework_id)
    rename(table(:account_compliance_frameworks), :enabled_at, to: :activated_at)

    create_if_not_exists(
      unique_index(:account_compliance_frameworks, [:account_id, :framework_id],
        name: :account_compliance_frameworks_account_id_framework_id_index
      )
    )
  end
end
