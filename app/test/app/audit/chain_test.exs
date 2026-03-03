defmodule GA.Audit.ChainTest do
  use ExUnit.Case, async: true

  alias GA.Audit.Chain

  defmodule AuditLog do
    defstruct [
      :account_id,
      :sequence_number,
      :timestamp,
      :user_id,
      :user_role,
      :session_id,
      :action,
      :resource_type,
      :resource_id,
      :outcome,
      :failure_reason,
      :phi_accessed,
      :source_ip,
      :user_agent,
      :metadata,
      :checksum
    ]
  end

  @key_1 "0123456789abcdef0123456789abcdef"
  @key_2 "fedcba9876543210fedcba9876543210"

  defp base_attrs do
    %{
      account_id: "acct_123",
      sequence_number: 1,
      timestamp: ~U[2026-03-01 12:00:00Z],
      user_id: "user_1",
      user_role: "admin",
      session_id: "sess_1",
      action: "read",
      resource_type: "patient",
      resource_id: "pt_1",
      outcome: "success",
      failure_reason: nil,
      phi_accessed: true,
      source_ip: "127.0.0.1",
      user_agent: "Mozilla/5.0",
      metadata: %{"zeta" => 2, "alpha" => 1}
    }
  end

  test "deterministic output returns same lowercase 64-char checksum for same input" do
    attrs = base_attrs()

    checksum_1 = Chain.compute_checksum(@key_1, attrs, nil)
    checksum_2 = Chain.compute_checksum(@key_1, attrs, nil)

    assert checksum_1 == checksum_2
    assert checksum_1 =~ ~r/\A[0-9a-f]{64}\z/
  end

  test "single-field sensitivity changes checksum" do
    attrs = base_attrs()
    original = Chain.compute_checksum(@key_1, attrs, nil)
    mutated = Chain.compute_checksum(@key_1, %{attrs | action: "write"}, nil)

    refute original == mutated
  end

  test "previous_checksum sensitivity changes checksum" do
    attrs = base_attrs()
    checksum_1 = Chain.compute_checksum(@key_1, attrs, "prev_a")
    checksum_2 = Chain.compute_checksum(@key_1, attrs, "prev_b")

    refute checksum_1 == checksum_2
  end

  test "genesis handling uses literal genesis when previous_checksum is nil" do
    payload = Chain.canonical_payload(base_attrs(), nil)
    [_account_id, _sequence_number, previous | _rest] = String.split(payload, "|")

    assert previous == "genesis"
  end

  test "nil optional fields render as empty strings in payload" do
    attrs =
      base_attrs()
      |> Map.put(:session_id, nil)
      |> Map.put(:failure_reason, nil)
      |> Map.put(:source_ip, nil)
      |> Map.put(:user_agent, nil)

    payload = Chain.canonical_payload(attrs, nil)
    parts = String.split(payload, "|")

    assert Enum.at(parts, 5) == ""
    assert Enum.at(parts, 10) == ""
    assert Enum.at(parts, 12) == ""
    assert Enum.at(parts, 13) == ""
  end

  test "metadata key ordering independence yields same checksum" do
    attrs_1 = Map.put(base_attrs(), :metadata, %{"a" => 1, "b" => 2})
    attrs_2 = Map.put(base_attrs(), :metadata, %{"b" => 2, "a" => 1})

    checksum_1 = Chain.compute_checksum(@key_1, attrs_1, nil)
    checksum_2 = Chain.compute_checksum(@key_1, attrs_2, nil)

    assert checksum_1 == checksum_2
  end

  test "nested metadata maps are sorted recursively" do
    attrs =
      Map.put(base_attrs(), :metadata, %{
        "outer_b" => %{"z" => 1, "a" => 2},
        "outer_a" => 1
      })

    payload = Chain.canonical_payload(attrs, nil)
    metadata_json = payload |> String.split("|") |> List.last()

    assert metadata_json == ~s({"outer_a":1,"outer_b":{"a":2,"z":1}})
  end

  test "empty or nil metadata canonicalizes to empty object JSON" do
    with_nil = Chain.canonical_payload(Map.put(base_attrs(), :metadata, nil), nil)
    with_empty = Chain.canonical_payload(Map.put(base_attrs(), :metadata, %{}), nil)

    assert String.ends_with?(with_nil, "|{}")
    assert String.ends_with?(with_empty, "|{}")
  end

  test "different keys produce different checksums for same payload" do
    attrs = base_attrs()
    checksum_1 = Chain.compute_checksum(@key_1, attrs, nil)
    checksum_2 = Chain.compute_checksum(@key_2, attrs, nil)

    refute checksum_1 == checksum_2
  end

  test "different account_ids produce different checksums with same key and data" do
    attrs_1 = Map.put(base_attrs(), :account_id, "acct_1")
    attrs_2 = Map.put(base_attrs(), :account_id, "acct_2")

    checksum_1 = Chain.compute_checksum(@key_1, attrs_1, nil)
    checksum_2 = Chain.compute_checksum(@key_1, attrs_2, nil)

    refute checksum_1 == checksum_2
  end

  test "verify_checksum returns true for valid entry" do
    attrs = base_attrs()
    checksum = Chain.compute_checksum(@key_1, attrs, nil)
    entry = struct(AuditLog, Map.put(attrs, :checksum, checksum))

    assert Chain.verify_checksum(@key_1, entry, nil)
  end

  test "verify_checksum returns false for tampered entry" do
    attrs = base_attrs()
    checksum = Chain.compute_checksum(@key_1, attrs, nil)
    entry = struct(AuditLog, Map.put(attrs, :checksum, checksum))
    tampered = %{entry | action: "delete"}

    refute Chain.verify_checksum(@key_1, tampered, nil)
  end

  test "verify_checksum returns false with wrong key" do
    attrs = base_attrs()
    checksum = Chain.compute_checksum(@key_1, attrs, nil)
    entry = struct(AuditLog, Map.put(attrs, :checksum, checksum))

    refute Chain.verify_checksum(@key_2, entry, nil)
  end
end
