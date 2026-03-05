defmodule GA.Repo.Migrations.AddFrameworksToAuditLogs do
  use Ecto.Migration

  def change do
    alter table(:audit_logs) do
      add(:frameworks, {:array, :string}, null: false, default: [])
    end
  end
end
