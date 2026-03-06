defmodule GA.Repo.Migrations.RelaxAuditLogActionConstraint do
  use Ecto.Migration

  def up do
    drop_if_exists(constraint(:audit_logs, :audit_logs_action_valid_check))
  end

  def down do
    create(
      constraint(:audit_logs, :audit_logs_action_valid_check,
        check: "action IN ('create', 'read', 'update', 'delete', 'export', 'login', 'logout')"
      )
    )
  end
end
