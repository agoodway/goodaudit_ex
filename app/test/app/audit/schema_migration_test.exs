defmodule GA.Audit.SchemaMigrationTest do
  use GA.DataCase, async: true

  alias Ecto.Adapters.SQL
  alias GA.Accounts
  alias GA.Repo

  defp account_fixture do
    {:ok, account} =
      Accounts.create_account(%{name: "Audit Test Account #{System.unique_integer([:positive])}"})

    account
  end

  defp insert_audit_log(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      sequence_number: 1,
      checksum: String.duplicate("a", 64),
      previous_checksum: nil,
      user_id: Ecto.UUID.generate(),
      user_role: "admin",
      session_id: "session_1",
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: now,
      source_ip: "127.0.0.1",
      user_agent: "ExUnit",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: false,
      metadata: %{"source" => "test"},
      inserted_at: now,
      updated_at: now
    }

    attrs = Map.merge(defaults, attrs)

    SQL.query(
      Repo,
      """
      INSERT INTO audit_logs (
        id, account_id, sequence_number, checksum, previous_checksum, user_id, user_role,
        session_id, action, resource_type, resource_id, "timestamp", source_ip, user_agent,
        outcome, failure_reason, phi_accessed, metadata, inserted_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
        $11, $12, $13, $14, $15, $16, $17, $18, $19, $20
      )
      """,
      [
        attrs.id,
        attrs.account_id,
        attrs.sequence_number,
        attrs.checksum,
        attrs.previous_checksum,
        attrs.user_id,
        attrs.user_role,
        attrs.session_id,
        attrs.action,
        attrs.resource_type,
        attrs.resource_id,
        attrs.timestamp,
        attrs.source_ip,
        attrs.user_agent,
        attrs.outcome,
        attrs.failure_reason,
        attrs.phi_accessed,
        attrs.metadata,
        attrs.inserted_at,
        attrs.updated_at
      ]
    )
  end

  defp insert_audit_checkpoint(attrs) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    defaults = %{
      id: Ecto.UUID.generate(),
      sequence_number: 1,
      checksum: String.duplicate("a", 64),
      signature: nil,
      verified_at: nil,
      inserted_at: now,
      updated_at: now
    }

    attrs = Map.merge(defaults, attrs)

    SQL.query(
      Repo,
      """
      INSERT INTO audit_checkpoints (
        id, account_id, sequence_number, checksum, signature, verified_at, inserted_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8
      )
      """,
      [
        attrs.id,
        attrs.account_id,
        attrs.sequence_number,
        attrs.checksum,
        attrs.signature,
        attrs.verified_at,
        attrs.inserted_at,
        attrs.updated_at
      ]
    )
  end

  test "audit tables exist with account_id foreign keys" do
    assert {:ok, %{rows: [[1]]}} =
             SQL.query(
               Repo,
               "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_logs'",
               []
             )

    assert {:ok, %{rows: [[1]]}} =
             SQL.query(
               Repo,
               "SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'audit_checkpoints'",
               []
             )

    assert {:ok, %{rows: [[1]]}} =
             SQL.query(
               Repo,
               """
               SELECT 1
               FROM information_schema.table_constraints tc
               JOIN information_schema.key_column_usage kcu
                 ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
               JOIN information_schema.constraint_column_usage ccu
                 ON tc.constraint_name = ccu.constraint_name
                 AND tc.table_schema = ccu.table_schema
               WHERE tc.constraint_type = 'FOREIGN KEY'
                 AND tc.table_schema = 'public'
                 AND tc.table_name = 'audit_logs'
                 AND kcu.column_name = 'account_id'
                 AND ccu.table_name = 'accounts'
               LIMIT 1
               """,
               []
             )

    assert {:ok, %{rows: [[1]]}} =
             SQL.query(
               Repo,
               """
               SELECT 1
               FROM information_schema.table_constraints tc
               JOIN information_schema.key_column_usage kcu
                 ON tc.constraint_name = kcu.constraint_name
                 AND tc.table_schema = kcu.table_schema
               JOIN information_schema.constraint_column_usage ccu
                 ON tc.constraint_name = ccu.constraint_name
                 AND tc.table_schema = ccu.table_schema
               WHERE tc.constraint_type = 'FOREIGN KEY'
                 AND tc.table_schema = 'public'
                 AND tc.table_name = 'audit_checkpoints'
                 AND kcu.column_name = 'account_id'
                 AND ccu.table_name = 'accounts'
               LIMIT 1
               """,
               []
             )
  end

  test "audit_logs has tenant-scoped timestamp index" do
    assert {:ok, %{rows: [[index_def]]}} =
             SQL.query(
               Repo,
               """
               SELECT indexdef
               FROM pg_indexes
               WHERE schemaname = 'public'
                 AND tablename = 'audit_logs'
                 AND indexname = 'audit_logs_account_id_timestamp_index'
               """,
               []
             )

    assert index_def =~ "(account_id, \"timestamp\")"
  end

  test "duplicate [account_id, sequence_number] in audit_logs is rejected" do
    account = account_fixture()

    assert {:ok, _result} =
             insert_audit_log(%{
               account_id: account.id,
               sequence_number: 42
             })

    assert {:error, %Postgrex.Error{postgres: %{code: :unique_violation}}} =
             insert_audit_log(%{
               account_id: account.id,
               sequence_number: 42
             })
  end

  test "same sequence_number across different accounts is allowed for audit_logs" do
    account_a = account_fixture()
    account_b = account_fixture()

    assert {:ok, _result} =
             insert_audit_log(%{
               account_id: account_a.id,
               sequence_number: 9
             })

    assert {:ok, _result} =
             insert_audit_log(%{
               account_id: account_b.id,
               sequence_number: 9,
               checksum: String.duplicate("b", 64)
             })
  end

  test "audit_logs rejects non-existent account_id foreign key" do
    assert {:error, %Postgrex.Error{postgres: %{code: :foreign_key_violation}}} =
             insert_audit_log(%{
               account_id: Ecto.UUID.generate()
             })
  end

  test "audit_logs checksum check constraint rejects invalid checksum" do
    account = account_fixture()

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             insert_audit_log(%{
               account_id: account.id,
               checksum: "not-a-valid-checksum"
             })
  end

  test "audit_logs previous_checksum check constraint rejects invalid previous_checksum" do
    account = account_fixture()

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             insert_audit_log(%{
               account_id: account.id,
               previous_checksum: "BAD"
             })
  end

  test "audit_logs action check constraint rejects invalid action" do
    account = account_fixture()

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             insert_audit_log(%{
               account_id: account.id,
               action: "archive"
             })
  end

  test "audit_logs outcome check constraint rejects invalid outcome" do
    account = account_fixture()

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             insert_audit_log(%{
               account_id: account.id,
               outcome: "partial"
             })
  end

  test "audit_checkpoints checksum check constraint rejects invalid checksum" do
    account = account_fixture()

    assert {:error, %Postgrex.Error{postgres: %{code: :check_violation}}} =
             insert_audit_checkpoint(%{
               account_id: account.id,
               checksum: "bad-checksum"
             })
  end
end
