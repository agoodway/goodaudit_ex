defmodule GA.Repo.Migrations.CreateAuditCheckpoints do
  use Ecto.Migration

  def up do
    create table(:audit_checkpoints, primary_key: false) do
      add(:id, :binary_id, primary_key: true)

      add(:account_id, references(:accounts, type: :binary_id, on_delete: :nothing), null: false)

      add(:sequence_number, :bigint, null: false)
      add(:checksum, :string, size: 64, null: false)
      add(:signature, :text)
      add(:verified_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:audit_checkpoints, [:account_id, :sequence_number]))

    create(
      constraint(:audit_checkpoints, :audit_checkpoints_checksum_format_check,
        check: "checksum ~ '^[0-9a-f]{64}$'"
      )
    )

    execute("""
    CREATE FUNCTION audit_checkpoints_prevent_update_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_checkpoints is append-only: UPDATE is not allowed';
      RETURN OLD;
    END;
    $$;
    """)

    execute("""
    CREATE FUNCTION audit_checkpoints_prevent_delete_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_checkpoints is append-only: DELETE is not allowed';
      RETURN OLD;
    END;
    $$;
    """)

    execute("""
    CREATE FUNCTION audit_checkpoints_prevent_truncate_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
      RAISE EXCEPTION 'audit_checkpoints is append-only: TRUNCATE is not allowed';
      RETURN NULL;
    END;
    $$;
    """)

    execute("""
    CREATE TRIGGER audit_checkpoints_prevent_update
    BEFORE UPDATE ON audit_checkpoints
    FOR EACH ROW
    EXECUTE FUNCTION audit_checkpoints_prevent_update_fn();
    """)

    execute("""
    CREATE TRIGGER audit_checkpoints_prevent_delete
    BEFORE DELETE ON audit_checkpoints
    FOR EACH ROW
    EXECUTE FUNCTION audit_checkpoints_prevent_delete_fn();
    """)

    execute("""
    CREATE TRIGGER audit_checkpoints_prevent_truncate
    BEFORE TRUNCATE ON audit_checkpoints
    FOR EACH STATEMENT
    EXECUTE FUNCTION audit_checkpoints_prevent_truncate_fn();
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS audit_checkpoints_prevent_update ON audit_checkpoints;")
    execute("DROP TRIGGER IF EXISTS audit_checkpoints_prevent_delete ON audit_checkpoints;")
    execute("DROP TRIGGER IF EXISTS audit_checkpoints_prevent_truncate ON audit_checkpoints;")

    execute("DROP FUNCTION IF EXISTS audit_checkpoints_prevent_update_fn();")
    execute("DROP FUNCTION IF EXISTS audit_checkpoints_prevent_delete_fn();")
    execute("DROP FUNCTION IF EXISTS audit_checkpoints_prevent_truncate_fn();")

    drop(table(:audit_checkpoints))
  end
end
