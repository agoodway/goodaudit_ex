defmodule GA.Audit.ChainTest do
  use ExUnit.Case, async: true

  alias GA.Audit.Chain

  defmodule AuditLog do
    defstruct [
      :account_id,
      :sequence_number,
      :actor_id,
      :action,
      :resource_type,
      :resource_id,
      :outcome,
      :timestamp,
      :extensions,
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
      actor_id: "actor_1",
      action: "read",
      resource_type: "patient",
      resource_id: "pt_1",
      outcome: "success",
      timestamp: ~U[2026-03-01 12:00:00Z],
      extensions: %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}},
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
        {:actor_id, Map.put(attrs, :actor_id, "actor_2")},
        {:action, Map.put(attrs, :action, "update")},
        {:resource_type, Map.put(attrs, :resource_type, "encounter")},
        {:resource_id, Map.put(attrs, :resource_id, "pt_2")},
        {:outcome, Map.put(attrs, :outcome, "failure")},
        {:timestamp, Map.put(attrs, :timestamp, DateTime.add(attrs.timestamp, 1, :second))},
        {:extensions, put_in(attrs, [:extensions, "hipaa", "phi_accessed"], false)},
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

  test "canonical payload order includes sorted extensions before metadata" do
    payload = Chain.canonical_payload(base_attrs(), nil)
    parts = String.split(payload, "|")

    assert Enum.at(parts, 0) == "acct_123"
    assert Enum.at(parts, 1) == "1"
    assert Enum.at(parts, 2) == "genesis"
    assert Enum.at(parts, 3) == "actor_1"
    assert Enum.at(parts, 9) == ~s({"hipaa":{"phi_accessed":true,"user_role":"admin"}})
    assert Enum.at(parts, 10) == ~s({"alpha":1,"zeta":2})
  end

  test "extensions key ordering independence yields same checksum" do
    attrs_1 = Map.put(base_attrs(), :extensions, %{"hipaa" => %{"phi_accessed" => true, "user_role" => "admin"}})

    attrs_2 =
      Map.put(base_attrs(), :extensions, %{
        "hipaa" => %{"user_role" => "admin", "phi_accessed" => true}
      })

    checksum_1 = Chain.compute_checksum(@key_1, attrs_1, nil)
    checksum_2 = Chain.compute_checksum(@key_1, attrs_2, nil)

    assert checksum_1 == checksum_2
  end

  test "empty extensions serialize to empty object JSON" do
    payload = Chain.canonical_payload(Map.put(base_attrs(), :extensions, %{}), nil)
    parts = String.split(payload, "|")

    assert Enum.at(parts, 9) == "{}"
  end

  test "metadata key ordering independence yields same checksum" do
    attrs_1 = Map.put(base_attrs(), :metadata, %{"a" => 1, "b" => 2})
    attrs_2 = Map.put(base_attrs(), :metadata, %{"b" => 2, "a" => 1})

    checksum_1 = Chain.compute_checksum(@key_1, attrs_1, nil)
    checksum_2 = Chain.compute_checksum(@key_1, attrs_2, nil)

    assert checksum_1 == checksum_2
  end

  test "different keys produce different checksums for same payload" do
    attrs = base_attrs()
    checksum_1 = Chain.compute_checksum(@key_1, attrs, nil)
    checksum_2 = Chain.compute_checksum(@key_2, attrs, nil)

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
    attrs_a = Map.put(base_attrs(), :actor_id, "actor|admin")
    attrs_b = Map.put(base_attrs(), :resource_id, "patient|123")

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

  test "verify_checksum returns false when extensions are tampered" do
    attrs = base_attrs()
    checksum = Chain.compute_checksum(@key_1, attrs, nil)
    entry = struct(AuditLog, Map.put(attrs, :checksum, checksum))

    tampered = put_in(entry.extensions["hipaa"]["phi_accessed"], false)

    refute Chain.verify_checksum(@key_1, tampered, nil)
  end
end
