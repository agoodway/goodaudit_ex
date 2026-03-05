defmodule GA.Repo.Migrations.AddActorIdAndExtensionsToAuditLogs do
  use Ecto.Migration

  def up do
    alter table(:audit_logs) do
      add(:actor_id, :string)
      add(:extensions, :map, null: false, default: %{})
    end

    execute("""
    UPDATE audit_logs
    SET actor_id = user_id
    WHERE actor_id IS NULL
    """)

    alter table(:audit_logs) do
      modify(:actor_id, :string, null: false)
    end

    create_if_not_exists(unique_index(:audit_logs, [:account_id, :sequence_number]))

    execute("""
    CREATE INDEX IF NOT EXISTS audit_logs_extensions_gin_index
    ON audit_logs
    USING GIN (extensions);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS audit_logs_hipaa_phi_accessed_index
    ON audit_logs ((extensions->'hipaa'->>'phi_accessed'))
    WHERE extensions->'hipaa' IS NOT NULL;
    """)
  end

  def down do
    execute("DROP INDEX IF EXISTS audit_logs_hipaa_phi_accessed_index")
    execute("DROP INDEX IF EXISTS audit_logs_extensions_gin_index")

    alter table(:audit_logs) do
      remove(:extensions)
      remove(:actor_id)
    end
  end
end
