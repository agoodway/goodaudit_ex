defmodule GA.Audit.LogTest do
  use GA.DataCase, async: true

  alias GA.Audit.Log

  defp valid_attrs do
    %{
      user_id: Ecto.UUID.generate(),
      user_role: "admin",
      session_id: "sess_123",
      action: "read",
      resource_type: "patient",
      resource_id: Ecto.UUID.generate(),
      timestamp: ~U[2026-03-03 15:00:00Z],
      source_ip: "127.0.0.1",
      user_agent: "ExUnit",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: true,
      metadata: %{"source" => "test"}
    }
  end

  test "changeset is valid with required fields and valid enum values" do
    changeset = Log.changeset(%Log{}, valid_attrs())

    assert changeset.valid?
  end

  test "changeset requires required fields" do
    changeset = Log.changeset(%Log{}, %{})
    errors = errors_on(changeset)

    assert "can't be blank" in errors.user_id
    assert "can't be blank" in errors.user_role
    assert "can't be blank" in errors.action
    assert "can't be blank" in errors.resource_type
    assert "can't be blank" in errors.resource_id
    assert "can't be blank" in errors.timestamp
    assert "can't be blank" in errors.outcome
  end

  test "changeset rejects invalid action" do
    attrs = Map.put(valid_attrs(), :action, "archive")
    changeset = Log.changeset(%Log{}, attrs)

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).action
  end

  test "changeset rejects invalid outcome" do
    attrs = Map.put(valid_attrs(), :outcome, "partial")
    changeset = Log.changeset(%Log{}, attrs)

    refute changeset.valid?
    assert "is invalid" in errors_on(changeset).outcome
  end

  test "changeset requires failure_reason when outcome is failure" do
    attrs =
      valid_attrs()
      |> Map.put(:outcome, "failure")
      |> Map.put(:failure_reason, nil)

    changeset = Log.changeset(%Log{}, attrs)

    refute changeset.valid?
    assert "can't be blank" in errors_on(changeset).failure_reason
  end

  test "changeset ignores account and chain fields" do
    attrs =
      valid_attrs()
      |> Map.put(:account_id, Ecto.UUID.generate())
      |> Map.put(:sequence_number, 10)
      |> Map.put(:checksum, String.duplicate("a", 64))
      |> Map.put(:previous_checksum, String.duplicate("b", 64))

    changeset = Log.changeset(%Log{}, attrs)

    refute Map.has_key?(changeset.changes, :account_id)
    refute Map.has_key?(changeset.changes, :sequence_number)
    refute Map.has_key?(changeset.changes, :checksum)
    refute Map.has_key?(changeset.changes, :previous_checksum)
  end
end