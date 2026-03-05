defmodule GA.Audit.CheckpointTest do
  use GA.DataCase, async: false

  import Ecto.Query

  alias Ecto.Adapters.SQL
  alias GA.Accounts
  alias GA.Audit.Checkpoint
  alias GA.Audit.Log
  alias GA.Repo

  defp account_fixture do
    {:ok, account} =
      Accounts.create_account(%{name: "Account #{System.unique_integer([:positive])}"})

    account
  end

  test "changeset is valid with required fields" do
    changeset =
      Checkpoint.changeset(%Checkpoint{}, %{
        sequence_number: 1,
        checksum: String.duplicate("a", 64)
      })

    assert changeset.valid?
  end

  test "changeset requires sequence_number and checksum" do
    changeset = Checkpoint.changeset(%Checkpoint{}, %{})
    errors = errors_on(changeset)

    assert "can't be blank" in errors.sequence_number
    assert "can't be blank" in errors.checksum
  end

  test "duplicate sequence_number within the same account is rejected" do
    account = account_fixture()
    checksum = String.duplicate("a", 64)

    Repo.insert!(
      Checkpoint.changeset(%Checkpoint{}, %{
        account_id: account.id,
        sequence_number: 5,
        checksum: checksum
      })
    )

    assert {:error, changeset} =
             %Checkpoint{}
             |> Checkpoint.changeset(%{
               account_id: account.id,
               sequence_number: 5,
               checksum: checksum
             })
             |> Repo.insert()

    assert "has already been taken" in errors_on(changeset).account_id
  end

  test "same sequence_number in different accounts is allowed" do
    account_a = account_fixture()
    account_b = account_fixture()

    assert {:ok, _checkpoint_a} =
             %Checkpoint{}
             |> Checkpoint.changeset(%{
               account_id: account_a.id,
               sequence_number: 10,
               checksum: String.duplicate("a", 64)
             })
             |> Repo.insert()

    assert {:ok, _checkpoint_b} =
             %Checkpoint{}
             |> Checkpoint.changeset(%{
               account_id: account_b.id,
               sequence_number: 10,
               checksum: String.duplicate("b", 64)
             })
             |> Repo.insert()
  end

  test "append-only triggers reject update and delete for audit_logs and audit_checkpoints" do
    account = account_fixture()

    log =
      Repo.insert!(%Log{
        account_id: account.id,
        sequence_number: 1,
        checksum: String.duplicate("a", 64),
        previous_checksum: nil,
        actor_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        user_role: "admin",
        session_id: "session_1",
        action: "read",
        resource_type: "patient",
        resource_id: Ecto.UUID.generate(),
        timestamp: ~U[2026-03-03 15:00:00Z],
        source_ip: "127.0.0.1",
        user_agent: "ExUnit",
        outcome: "success",
        failure_reason: nil,
        phi_accessed: false,
        metadata: %{}
      })

    checkpoint =
      Repo.insert!(%Checkpoint{
        account_id: account.id,
        sequence_number: 1,
        checksum: String.duplicate("c", 64)
      })

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.update_all(
        from(l in Log, where: l.id == ^log.id),
        set: [outcome: "failure", failure_reason: "denied"]
      )
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.delete_all(from(l in Log, where: l.id == ^log.id))
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.update_all(
        from(c in Checkpoint, where: c.id == ^checkpoint.id),
        set: [signature: "updated"]
      )
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      Repo.delete_all(from(c in Checkpoint, where: c.id == ^checkpoint.id))
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      SQL.query!(Repo, "TRUNCATE TABLE audit_logs", [])
    end

    assert_raise Postgrex.Error, ~r/append-only/, fn ->
      SQL.query!(Repo, "TRUNCATE TABLE audit_checkpoints", [])
    end
  end
end
