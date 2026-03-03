defmodule GA.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    create table(:audit_logs, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false)

      add(:sequence_number, :bigint, null: false)
      add(:checksum, :string, size: 64, null: false)
      add(:previous_checksum, :string, size: 64)
      add(:user_id, :string, null: false)
      add(:user_role, :string, null: false)
      add(:session_id, :string)
      add(:action, :string, null: false)
      add(:resource_type, :string, null: false)
      add(:resource_id, :string, null: false)
      add(:timestamp, :utc_datetime_usec, null: false)
      add(:source_ip, :string)
      add(:user_agent, :text)
      add(:outcome, :string, null: false)
      add(:failure_reason, :text)
      add(:phi_accessed, :boolean, null: false, default: false)
      add(:metadata, :map, null: false, default: %{})

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:audit_logs, [:account_id, :sequence_number]))
    create(index(:audit_logs, [:account_id]))
    create(index(:audit_logs, [:account_id, :timestamp]))
    create(index(:audit_logs, [:account_id, :user_id]))
    create(index(:audit_logs, [:account_id, :resource_type, :resource_id]))
    create(index(:audit_logs, [:account_id, :action]))
    create(index(:audit_logs, [:account_id, :phi_accessed], where: "phi_accessed = true"))

    create(
      constraint(:audit_logs, :audit_logs_checksum_format_check,
        check: "checksum ~ '^[0-9a-f]{64}$'"
      )
    )

    create(
      constraint(:audit_logs, :audit_logs_previous_checksum_format_check,
        check: "previous_checksum IS NULL OR previous_checksum ~ '^[0-9a-f]{64}$'"
      )
    )

    create(
      constraint(:audit_logs, :audit_logs_action_valid_check,
        check: "action IN ('create', 'read', 'update', 'delete', 'export', 'login', 'logout')"
      )
    )

    create(
      constraint(:audit_logs, :audit_logs_outcome_valid_check,
        check: "outcome IN ('success', 'failure')"
      )
    )

    execute("""
    CREATE FUNCTION audit_logs_prevent_update_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_logs is append-only: UPDATE is not allowed';
      RETURN OLD;
    END;
    $$;
    """)

    execute("""
    CREATE FUNCTION audit_logs_prevent_delete_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_logs is append-only: DELETE is not allowed';
      RETURN OLD;
    END;
    $$;
    """)

    execute("""
    CREATE FUNCTION audit_logs_prevent_truncate_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_logs is append-only: TRUNCATE is not allowed';
      RETURN NULL;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER audit_logs_prevent_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION audit_logs_prevent_update_fn();
    """)

    execute("""
    CREATE TRIGGER audit_logs_prevent_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW
    EXECUTE FUNCTION audit_logs_prevent_delete_fn();
    """)

    execute("""
    CREATE TRIGGER audit_logs_prevent_truncate
    BEFORE TRUNCATE ON audit_logs
    FOR EACH STATEMENT
    EXECUTE FUNCTION audit_logs_prevent_truncate_fn();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS audit_logs_prevent_update ON audit_logs;")
    execute("DROP TRIGGER IF EXISTS audit_logs_prevent_delete ON audit_logs;")
    execute("DROP TRIGGER IF EXISTS audit_logs_prevent_truncate ON audit_logs;")

    execute("DROP FUNCTION IF EXISTS audit_logs_prevent_update_fn();")
    execute("DROP FUNCTION IF EXISTS audit_logs_prevent_delete_fn();")
    execute("DROP FUNCTION IF EXISTS audit_logs_prevent_truncate_fn();")

    drop(table(:audit_logs))
  end
end
