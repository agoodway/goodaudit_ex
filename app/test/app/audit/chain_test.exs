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
      :frameworks,
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
      frameworks: [],
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
    baseline = Chain.compute_checksum(@key_1, attrs, nil)

    mutated_checksums =
      [
        {:account_id, Map.put(attrs, :account_id, "acct_999")},
        {:sequence_number, Map.put(attrs, :sequence_number, attrs.sequence_number + 1)},
        {:timestamp, Map.put(attrs, :timestamp, DateTime.add(attrs.timestamp, 1, :second))},
        {:user_id, Map.put(attrs, :user_id, "user_2")},
        {:user_role, Map.put(attrs, :user_role, "staff")},
        {:session_id, Map.put(attrs, :session_id, "sess_2")},
        {:action, Map.put(attrs, :action, "write")},
        {:resource_type, Map.put(attrs, :resource_type, "encounter")},
        {:resource_id, Map.put(attrs, :resource_id, "pt_2")},
        {:outcome, Map.put(attrs, :outcome, "failure")},
        {:failure_reason, Map.put(attrs, :failure_reason, "denied")},
        {:phi_accessed, Map.put(attrs, :phi_accessed, false)},
        {:source_ip, Map.put(attrs, :source_ip, "10.0.0.1")},
        {:user_agent, Map.put(attrs, :user_agent, "curl/8.6.0")},
        {:frameworks, Map.put(attrs, :frameworks, ["hipaa"])},
        {:metadata, Map.put(attrs, :metadata, %{"alpha" => 1, "zeta" => 3})}
      ]
      |> Enum.map(fn {field, mutated_attrs} ->
        {field, Chain.compute_checksum(@key_1, mutated_attrs, nil)}
      end)

    Enum.each(mutated_checksums, fn {field, checksum} ->
      refute checksum == baseline, "expected #{field} mutation to change checksum"
    end)
  end

  test "previous_checksum sensitivity changes checksum" do
    attrs = base_attrs()
    checksum_1 = Chain.compute_checksum(@key_1, attrs, String.duplicate("a", 64))
    checksum_2 = Chain.compute_checksum(@key_1, attrs, String.duplicate("b", 64))

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

    assert Enum.at(parts, 6) == ""
    assert Enum.at(parts, 11) == ""
    assert Enum.at(parts, 13) == ""
    assert Enum.at(parts, 14) == ""
  end

  test "frameworks segment is canonicalized as sorted comma-joined values" do
    payload =
      base_attrs()
      |> Map.put(:frameworks, ["soc2", "hipaa"])
      |> Chain.canonical_payload(nil)

    parts = String.split(payload, "|")
    assert Enum.at(parts, 15) == "hipaa,soc2"
  end

  test "empty frameworks serialize as empty canonical segment" do
    payload = Chain.canonical_payload(base_attrs(), nil)
    parts = String.split(payload, "|")
    assert Enum.at(parts, 15) == ""
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

  test "compute_checksum rejects invalid key values" do
    attrs = base_attrs()

    assert_raise ArgumentError, ~r/key must be a non-empty binary/, fn ->
      Chain.compute_checksum("", attrs, nil)
    end

    assert_raise ArgumentError, ~r/key must be a non-empty binary/, fn ->
      Chain.compute_checksum(nil, attrs, nil)
    end
  end

  test "compute_checksum rejects invalid previous_checksum values" do
    attrs = base_attrs()

    assert_raise ArgumentError,
                 ~r/previous_checksum must be nil or a 64-character lowercase hex checksum/,
                 fn ->
                   Chain.compute_checksum(@key_1, attrs, "not-a-checksum")
                 end

    assert_raise ArgumentError,
                 ~r/previous_checksum must be nil or a 64-character lowercase hex checksum/,
                 fn ->
                   Chain.compute_checksum(@key_1, attrs, 123)
                 end
  end

  test "canonical payload rejects pipe delimiters in canonical fields" do
    attrs_a =
      base_attrs()
      |> Map.put(:user_id, "user|admin")
      |> Map.put(:user_role, "clinician")

    attrs_b =
      base_attrs()
      |> Map.put(:user_id, "user")
      |> Map.put(:user_role, "admin|clinician")

    assert_raise ArgumentError, ~r/must not contain the pipe delimiter/, fn ->
      Chain.compute_checksum(@key_1, attrs_a, nil)
    end

    assert_raise ArgumentError, ~r/must not contain the pipe delimiter/, fn ->
      Chain.compute_checksum(@key_1, attrs_b, nil)
    end
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

  test "verify_checksum returns false for malformed stored checksum" do
    attrs = base_attrs()
    entry = struct(AuditLog, Map.put(attrs, :checksum, "invalid"))

    refute Chain.verify_checksum(@key_1, entry, nil)
  end

  test "verify_checksum returns false when frameworks are tampered" do
    attrs = base_attrs() |> Map.put(:frameworks, ["hipaa"])
    checksum = Chain.compute_checksum(@key_1, attrs, nil)
    entry = struct(AuditLog, Map.put(attrs, :checksum, checksum))
    tampered = %{entry | frameworks: ["hipaa", "soc2"]}

    refute Chain.verify_checksum(@key_1, tampered, nil)
  end
end
