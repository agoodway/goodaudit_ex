# Technical Implementation Plan: HIPAA-Compliant Tamper-Evident Audit Logging API

## 1. Architecture Overview

**Stack**: Phoenix 1.8 / Elixir on PostgreSQL
**Namespaces**: `GA.Audit` (context), `GAWeb` (API layer)
**OTP app atom**: `:app`
**Auth model**: Single bearer token from environment variable — no API keys table

### Dependencies to Add

```elixir
# mix.exs — add to deps/0
{:open_api_spex, "~> 3.21"}
```

### Cryptographic Approach

Every audit log entry carries an HMAC-SHA-256 checksum computed over a canonical payload that includes the previous entry's checksum. This creates a hash chain — modifying, inserting, or deleting any entry breaks the chain from that point forward. Gap-free sequence numbers (enforced by advisory lock, not `BIGSERIAL`) guarantee no silent deletions. Periodic checkpoints anchor the chain for efficient partial verification.

---

## 2. Database Design

### 2.1 `audit_logs` Table

Append-only. Protected by database triggers that prevent UPDATE, DELETE, and TRUNCATE.

#### Migration

```elixir
defmodule GA.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def up do
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")

      # Chain fields
      add :sequence_number, :bigint, null: false
      add :checksum, :string, size: 64, null: false
      add :previous_checksum, :string, size: 64  # nil for genesis entry

      # HIPAA WHO
      add :user_id, :string, null: false
      add :user_role, :string, null: false
      add :session_id, :string

      # HIPAA WHAT
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :string, null: false

      # HIPAA WHEN
      add :timestamp, :utc_datetime_usec, null: false

      # HIPAA WHERE
      add :source_ip, :string
      add :user_agent, :string

      # HIPAA OUTCOME
      add :outcome, :string, null: false, default: "success"
      add :failure_reason, :string

      # PHI tracking
      add :phi_accessed, :boolean, null: false, default: false

      # Extensible metadata
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:audit_logs, [:sequence_number])
    create index(:audit_logs, [:timestamp])
    create index(:audit_logs, [:user_id])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:action])
    create index(:audit_logs, [:phi_accessed], where: "phi_accessed = true")

    # Append-only enforcement triggers
    execute """
    CREATE OR REPLACE FUNCTION audit_logs_prevent_update()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'UPDATE on audit_logs is prohibited — audit log entries are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_logs_no_update
    BEFORE UPDATE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION audit_logs_prevent_update();
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_logs_prevent_delete()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'DELETE on audit_logs is prohibited — audit log entries are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_logs_no_delete
    BEFORE DELETE ON audit_logs
    FOR EACH ROW EXECUTE FUNCTION audit_logs_prevent_delete();
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_logs_prevent_truncate()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'TRUNCATE on audit_logs is prohibited — audit log entries are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_logs_no_truncate
    BEFORE TRUNCATE ON audit_logs
    EXECUTE FUNCTION audit_logs_prevent_truncate();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS audit_logs_no_truncate ON audit_logs"
    execute "DROP TRIGGER IF EXISTS audit_logs_no_delete ON audit_logs"
    execute "DROP TRIGGER IF EXISTS audit_logs_no_update ON audit_logs"
    execute "DROP FUNCTION IF EXISTS audit_logs_prevent_truncate()"
    execute "DROP FUNCTION IF EXISTS audit_logs_prevent_delete()"
    execute "DROP FUNCTION IF EXISTS audit_logs_prevent_update()"
    drop table(:audit_logs)
  end
end
```

### 2.2 `audit_checkpoints` Table

Periodic chain anchors. Also append-only with the same trigger protections.

#### Migration

```elixir
defmodule GA.Repo.Migrations.CreateAuditCheckpoints do
  use Ecto.Migration

  def up do
    create table(:audit_checkpoints, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :sequence_number, :bigint, null: false
      add :checksum, :string, size: 64, null: false
      add :signature, :text  # for external anchoring / notarization
      add :verified_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:audit_checkpoints, [:sequence_number])

    # Append-only enforcement triggers
    execute """
    CREATE OR REPLACE FUNCTION audit_checkpoints_prevent_update()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'UPDATE on audit_checkpoints is prohibited — checkpoints are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_checkpoints_no_update
    BEFORE UPDATE ON audit_checkpoints
    FOR EACH ROW EXECUTE FUNCTION audit_checkpoints_prevent_update();
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_checkpoints_prevent_delete()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'DELETE on audit_checkpoints is prohibited — checkpoints are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_checkpoints_no_delete
    BEFORE DELETE ON audit_checkpoints
    FOR EACH ROW EXECUTE FUNCTION audit_checkpoints_prevent_delete();
    """

    execute """
    CREATE OR REPLACE FUNCTION audit_checkpoints_prevent_truncate()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'TRUNCATE on audit_checkpoints is prohibited — checkpoints are immutable';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_checkpoints_no_truncate
    BEFORE TRUNCATE ON audit_checkpoints
    EXECUTE FUNCTION audit_checkpoints_prevent_truncate();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS audit_checkpoints_no_truncate ON audit_checkpoints"
    execute "DROP TRIGGER IF EXISTS audit_checkpoints_no_delete ON audit_checkpoints"
    execute "DROP TRIGGER IF EXISTS audit_checkpoints_no_update ON audit_checkpoints"
    execute "DROP FUNCTION IF EXISTS audit_checkpoints_prevent_truncate()"
    execute "DROP FUNCTION IF EXISTS audit_checkpoints_prevent_delete()"
    execute "DROP FUNCTION IF EXISTS audit_checkpoints_prevent_update()"
    drop table(:audit_checkpoints)
  end
end
```

---

## 3. Ecto Schemas

### 3.1 `GA.Audit.Log`

```elixir
defmodule GA.Audit.Log do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @valid_actions ~w(create read update delete export login logout)
  @valid_outcomes ~w(success failure)

  schema "audit_logs" do
    # Chain
    field :sequence_number, :integer
    field :checksum, :string
    field :previous_checksum, :string

    # HIPAA WHO
    field :user_id, :string
    field :user_role, :string
    field :session_id, :string

    # HIPAA WHAT
    field :action, :string
    field :resource_type, :string
    field :resource_id, :string

    # HIPAA WHEN
    field :timestamp, :utc_datetime_usec

    # HIPAA WHERE
    field :source_ip, :string
    field :user_agent, :string

    # HIPAA OUTCOME
    field :outcome, :string, default: "success"
    field :failure_reason, :string

    # PHI tracking
    field :phi_accessed, :boolean, default: false

    # Extensible
    field :metadata, :map, default: %{}

    timestamps(type: :utc_datetime_usec)
  end

  @required_fields ~w(user_id user_role action resource_type resource_id timestamp outcome)a
  @optional_fields ~w(session_id source_ip user_agent failure_reason phi_accessed metadata)a

  @doc """
  Changeset for external input. Does NOT set chain fields (sequence_number,
  checksum, previous_checksum) — those are computed by GA.Audit.Chain.
  """
  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:action, @valid_actions)
    |> validate_inclusion(:outcome, @valid_outcomes)
    |> validate_failure_reason()
  end

  defp validate_failure_reason(changeset) do
    case get_field(changeset, :outcome) do
      "failure" ->
        validate_required(changeset, [:failure_reason])

      _ ->
        changeset
    end
  end
end
```

### 3.2 `GA.Audit.Checkpoint`

```elixir
defmodule GA.Audit.Checkpoint do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audit_checkpoints" do
    field :sequence_number, :integer
    field :checksum, :string
    field :signature, :string
    field :verified_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(checkpoint, attrs) do
    checkpoint
    |> cast(attrs, [:sequence_number, :checksum, :signature, :verified_at])
    |> validate_required([:sequence_number, :checksum])
    |> unique_constraint(:sequence_number)
  end
end
```

---

## 4. HMAC Chain Module — `GA.Audit.Chain`

### 4.1 Canonical Payload Format

Fields are pipe-delimited in a fixed order. Nil fields become empty strings (producing `||`). Metadata is canonicalized by sorting keys alphabetically and encoding as compact JSON.

```
{sequence_number}|{previous_checksum}|{ISO8601_timestamp}|{user_id}|{user_role}|{session_id}|{action}|{resource_type}|{resource_id}|{outcome}|{failure_reason}|{phi_accessed}|{source_ip}|{user_agent}|{canonical_json_metadata}
```

The genesis entry (sequence_number = 1) uses the literal string `"genesis"` as its `previous_checksum` field value in the payload computation.

### 4.2 Implementation

```elixir
defmodule GA.Audit.Chain do
  @moduledoc """
  HMAC-SHA-256 hash chain for tamper-evident audit logs.

  Each entry's checksum is computed over a canonical payload that includes
  the previous entry's checksum, creating a forward-linked chain. Modifying
  any entry invalidates all subsequent checksums.
  """

  @genesis_previous "genesis"

  @doc """
  Returns the HMAC key from application config.
  """
  def hmac_key do
    Application.fetch_env!(:app, __MODULE__)
    |> Keyword.fetch!(:hmac_key)
    |> Base.decode64!()
  end

  @doc """
  Computes the HMAC-SHA-256 checksum for a log entry's attributes.

  `attrs` is a map with string or atom keys containing all audit log fields.
  `previous_checksum` is the checksum of the preceding entry, or nil for genesis.

  Returns a lowercase hex-encoded 64-character string.
  """
  def compute_checksum(attrs, previous_checksum) do
    payload = canonical_payload(attrs, previous_checksum)

    :crypto.mac(:hmac, :sha256, hmac_key(), payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies that a log entry's stored checksum matches a fresh computation.
  Returns `true` if valid, `false` if tampered.
  """
  def verify_checksum(log_entry, previous_checksum) do
    expected = compute_checksum(entry_to_attrs(log_entry), previous_checksum)
    Plug.Crypto.secure_compare(expected, log_entry.checksum)
  end

  @doc """
  Builds the canonical payload string for HMAC computation.
  """
  def canonical_payload(attrs, previous_checksum) do
    prev = previous_checksum || @genesis_previous
    attrs = normalize_keys(attrs)

    [
      to_string(attrs["sequence_number"]),
      prev,
      format_timestamp(attrs["timestamp"]),
      attrs["user_id"] || "",
      attrs["user_role"] || "",
      attrs["session_id"] || "",
      attrs["action"] || "",
      attrs["resource_type"] || "",
      attrs["resource_id"] || "",
      attrs["outcome"] || "",
      attrs["failure_reason"] || "",
      to_string(attrs["phi_accessed"] || false),
      attrs["source_ip"] || "",
      attrs["user_agent"] || "",
      canonical_metadata(attrs["metadata"])
    ]
    |> Enum.join("|")
  end

  defp normalize_keys(attrs) when is_map(attrs) do
    Map.new(attrs, fn {k, v} -> {to_string(k), v} end)
  end

  defp format_timestamp(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_timestamp(ts) when is_binary(ts), do: ts
  defp format_timestamp(nil), do: ""

  defp canonical_metadata(nil), do: "{}"
  defp canonical_metadata(metadata) when metadata == %{}, do: "{}"

  defp canonical_metadata(metadata) when is_map(metadata) do
    metadata
    |> sort_keys_recursive()
    |> Jason.encode!()
  end

  defp sort_keys_recursive(map) when is_map(map) do
    map
    |> Enum.sort_by(fn {k, _v} -> k end)
    |> Enum.map(fn {k, v} -> {k, sort_keys_recursive(v)} end)
    |> Jason.OrderedObject.new()
  end

  defp sort_keys_recursive(list) when is_list(list) do
    Enum.map(list, &sort_keys_recursive/1)
  end

  defp sort_keys_recursive(value), do: value

  defp entry_to_attrs(%GA.Audit.Log{} = log) do
    %{
      "sequence_number" => log.sequence_number,
      "timestamp" => log.timestamp,
      "user_id" => log.user_id,
      "user_role" => log.user_role,
      "session_id" => log.session_id,
      "action" => log.action,
      "resource_type" => log.resource_type,
      "resource_id" => log.resource_id,
      "outcome" => log.outcome,
      "failure_reason" => log.failure_reason,
      "phi_accessed" => log.phi_accessed,
      "source_ip" => log.source_ip,
      "user_agent" => log.user_agent,
      "metadata" => log.metadata
    }
  end
end
```

### 4.3 Key Management

| Environment | Configuration |
|---|---|
| Dev / Test | Static base64-encoded key in `config/dev.exs` and `config/test.exs` |
| Production | `AUDIT_HMAC_KEY` environment variable (base64-encoded) |

**Generating a production key:**

```bash
elixir -e ':crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()'
```

**Config entries:**

```elixir
# config/dev.exs and config/test.exs
config :app, GA.Audit.Chain,
  hmac_key: "dGVzdC1obWFjLWtleS1mb3ItZGV2ZWxvcG1lbnQtMzI="  # 32 bytes, base64

# config/runtime.exs (inside `if config_env() == :prod`)
config :app, GA.Audit.Chain,
  hmac_key:
    System.get_env("AUDIT_HMAC_KEY") ||
      raise "AUDIT_HMAC_KEY environment variable is not set"
```

---

## 5. Gap-Free Sequence Numbers

Standard PostgreSQL sequences (`BIGSERIAL`) can produce gaps on transaction rollback. For a tamper-evident audit chain, gaps are indistinguishable from deleted entries, so they must be prevented.

### Strategy: Advisory Lock + MAX Query

```elixir
# Inside GA.Audit context, within the create_log_entry transaction:

defp next_sequence_number do
  # Acquire a transaction-scoped advisory lock (key = 1 for audit_logs).
  # All writers serialize here. Lock auto-releases on COMMIT/ROLLBACK.
  GA.Repo.query!("SELECT pg_advisory_xact_lock(1)")

  result = GA.Repo.query!(
    "SELECT COALESCE(MAX(sequence_number), 0) + 1 FROM audit_logs"
  )

  [[next_seq]] = result.rows
  next_seq
end
```

**Why advisory lock over `FOR UPDATE` or `SERIALIZABLE`?**
- `FOR UPDATE` requires a row to lock — fails on empty table
- `SERIALIZABLE` isolation causes frequent serialization failures under concurrency
- Advisory lock is explicit, lightweight, and deterministic. The lock key `1` is dedicated to audit log sequencing.

**Throughput note:** This serializes all audit writes. For typical HIPAA audit volumes (hundreds to low thousands per second), this is sufficient. If throughput becomes a bottleneck, a partitioned advisory lock scheme (lock per partition) can be introduced later.

---

## 6. Phoenix Context — `GA.Audit`

```elixir
defmodule GA.Audit do
  @moduledoc """
  Context for HIPAA-compliant tamper-evident audit logging.
  """

  import Ecto.Query
  alias GA.Repo
  alias GA.Audit.{Log, Checkpoint, Chain, Verifier}

  @doc """
  Creates a new audit log entry with chain integrity.

  Acquires an advisory lock, computes the next sequence number,
  chains the HMAC checksum, and inserts atomically.

  Returns `{:ok, %Log{}}` or `{:error, changeset}`.
  """
  def create_log_entry(attrs) do
    Repo.transaction(fn ->
      # Serialize writers
      Repo.query!("SELECT pg_advisory_xact_lock(1)")

      # Get next sequence number
      %{rows: [[next_seq]]} =
        Repo.query!("SELECT COALESCE(MAX(sequence_number), 0) + 1 FROM audit_logs")

      # Get previous checksum (nil for genesis)
      previous_checksum = get_previous_checksum(next_seq)

      # Build full attrs with chain fields
      timestamp = Map.get(attrs, :timestamp) || Map.get(attrs, "timestamp") || DateTime.utc_now()

      chain_attrs =
        attrs
        |> Map.put(:sequence_number, next_seq)
        |> Map.put(:timestamp, timestamp)

      checksum = Chain.compute_checksum(chain_attrs, previous_checksum)

      chain_attrs =
        chain_attrs
        |> Map.put(:checksum, checksum)
        |> Map.put(:previous_checksum, previous_checksum)

      case %Log{} |> Log.changeset(chain_attrs) |> apply_chain_fields(chain_attrs) |> Repo.insert() do
        {:ok, log} -> log
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
  end

  defp apply_chain_fields(changeset, attrs) do
    changeset
    |> Ecto.Changeset.put_change(:sequence_number, attrs[:sequence_number] || attrs["sequence_number"])
    |> Ecto.Changeset.put_change(:checksum, attrs[:checksum] || attrs["checksum"])
    |> Ecto.Changeset.put_change(:previous_checksum, attrs[:previous_checksum] || attrs["previous_checksum"])
  end

  defp get_previous_checksum(1), do: nil

  defp get_previous_checksum(seq) do
    Log
    |> where([l], l.sequence_number == ^(seq - 1))
    |> select([l], l.checksum)
    |> Repo.one!()
  end

  @doc """
  Lists audit log entries with cursor-based pagination and filtering.

  ## Options

    * `:after_sequence` — cursor: return entries after this sequence number
    * `:limit` — max entries to return (default 50, max 1000)
    * `:user_id` — filter by user_id
    * `:action` — filter by action
    * `:resource_type` — filter by resource_type
    * `:resource_id` — filter by resource_id
    * `:outcome` — filter by outcome
    * `:phi_accessed` — filter by phi_accessed flag
    * `:from` — filter entries at or after this datetime
    * `:to` — filter entries at or before this datetime

  Returns `{entries, next_cursor}` where `next_cursor` is the last entry's
  sequence number (nil if no more pages).
  """
  def list_logs(opts \\ []) do
    limit = opts |> Keyword.get(:limit, 50) |> min(1000) |> max(1)

    query =
      Log
      |> order_by(asc: :sequence_number)
      |> limit(^(limit + 1))

    query = apply_filters(query, opts)

    entries = Repo.all(query)
    {page, has_more} = if length(entries) > limit do
      {Enum.take(entries, limit), true}
    else
      {entries, false}
    end

    next_cursor = if has_more do
      page |> List.last() |> Map.get(:sequence_number)
    end

    {page, next_cursor}
  end

  defp apply_filters(query, opts) do
    query
    |> maybe_filter(:after_sequence, opts)
    |> maybe_filter(:user_id, opts)
    |> maybe_filter(:action, opts)
    |> maybe_filter(:resource_type, opts)
    |> maybe_filter(:resource_id, opts)
    |> maybe_filter(:outcome, opts)
    |> maybe_filter(:phi_accessed, opts)
    |> maybe_filter(:from, opts)
    |> maybe_filter(:to, opts)
  end

  defp maybe_filter(query, :after_sequence, opts) do
    case Keyword.get(opts, :after_sequence) do
      nil -> query
      seq -> where(query, [l], l.sequence_number > ^seq)
    end
  end

  defp maybe_filter(query, :from, opts) do
    case Keyword.get(opts, :from) do
      nil -> query
      dt -> where(query, [l], l.timestamp >= ^dt)
    end
  end

  defp maybe_filter(query, :to, opts) do
    case Keyword.get(opts, :to) do
      nil -> query
      dt -> where(query, [l], l.timestamp <= ^dt)
    end
  end

  defp maybe_filter(query, field, opts) do
    case Keyword.get(opts, field) do
      nil -> query
      value -> where(query, [l], field(l, ^field) == ^value)
    end
  end

  @doc """
  Gets a single audit log entry by ID.
  Returns `{:ok, %Log{}}` or `{:error, :not_found}`.
  """
  def get_log(id) do
    case Repo.get(Log, id) do
      nil -> {:error, :not_found}
      log -> {:ok, log}
    end
  end

  @doc """
  Creates a checkpoint at the current chain head.
  """
  def create_checkpoint do
    case Repo.one(from l in Log, order_by: [desc: l.sequence_number], limit: 1) do
      nil ->
        {:error, :no_entries}

      log ->
        %Checkpoint{}
        |> Checkpoint.changeset(%{
          sequence_number: log.sequence_number,
          checksum: log.checksum,
          verified_at: DateTime.utc_now()
        })
        |> Repo.insert()
    end
  end

  @doc """
  Lists all checkpoints, newest first.
  """
  def list_checkpoints do
    Checkpoint
    |> order_by(desc: :sequence_number)
    |> Repo.all()
  end

  @doc """
  Runs full chain verification. Delegates to `GA.Audit.Verifier`.
  """
  def verify_chain do
    Verifier.verify()
  end
end
```

---

## 7. Verification Engine — `GA.Audit.Verifier`

```elixir
defmodule GA.Audit.Verifier do
  @moduledoc """
  Streaming chain verification engine.

  Reads audit logs in batches, recomputing the HMAC chain from genesis.
  Detects:
  - Checksum mismatches (tampered entries)
  - Sequence number gaps (deleted entries)
  - Invalid checkpoint anchors
  """

  import Ecto.Query
  alias GA.Repo
  alias GA.Audit.{Log, Checkpoint, Chain}

  @batch_size 1000

  @doc """
  Verifies the entire audit chain from genesis to head.

  Returns a result map:
    %{
      valid: boolean,
      total_entries: integer,
      verified_entries: integer,
      first_failure: map | nil,
      sequence_gaps: [map],
      checkpoint_results: [map],
      duration_ms: integer
    }
  """
  def verify do
    start_time = System.monotonic_time(:millisecond)
    checkpoints = load_checkpoints()

    result =
      stream_and_verify(checkpoints)
      |> Map.put(:duration_ms, System.monotonic_time(:millisecond) - start_time)

    result
  end

  defp load_checkpoints do
    Checkpoint
    |> order_by(asc: :sequence_number)
    |> Repo.all()
    |> Map.new(&{&1.sequence_number, &1})
  end

  defp stream_and_verify(checkpoints) do
    initial_state = %{
      valid: true,
      total_entries: 0,
      verified_entries: 0,
      first_failure: nil,
      sequence_gaps: [],
      checkpoint_results: [],
      previous_checksum: nil,
      expected_sequence: 1
    }

    final_state = do_verify_batches(0, initial_state, checkpoints)

    Map.drop(final_state, [:previous_checksum, :expected_sequence])
  end

  defp do_verify_batches(after_seq, state, checkpoints) do
    batch =
      Log
      |> where([l], l.sequence_number > ^after_seq)
      |> order_by(asc: :sequence_number)
      |> limit(@batch_size)
      |> Repo.all()

    case batch do
      [] ->
        state

      entries ->
        new_state = Enum.reduce(entries, state, fn entry, acc ->
          verify_entry(entry, acc, checkpoints)
        end)

        last_seq = List.last(entries).sequence_number
        do_verify_batches(last_seq, new_state, checkpoints)
    end
  end

  defp verify_entry(entry, state, checkpoints) do
    state = %{state | total_entries: state.total_entries + 1}

    # Check sequence continuity
    state =
      if entry.sequence_number != state.expected_sequence do
        gap = %{
          expected: state.expected_sequence,
          found: entry.sequence_number,
          missing: Enum.to_list(state.expected_sequence..(entry.sequence_number - 1))
        }

        %{state |
          valid: false,
          sequence_gaps: state.sequence_gaps ++ [gap],
          first_failure: state.first_failure || %{
            type: :sequence_gap,
            sequence_number: entry.sequence_number,
            detail: gap
          }
        }
      else
        state
      end

    # Verify HMAC checksum
    checksum_valid = Chain.verify_checksum(entry, state.previous_checksum)

    state =
      if checksum_valid do
        %{state | verified_entries: state.verified_entries + 1}
      else
        %{state |
          valid: false,
          first_failure: state.first_failure || %{
            type: :checksum_mismatch,
            sequence_number: entry.sequence_number,
            stored_checksum: entry.checksum,
            expected_checksum: Chain.compute_checksum(
              chain_entry_attrs(entry), state.previous_checksum
            )
          }
        }
      end

    # Check checkpoint anchor if one exists at this sequence
    state =
      case Map.get(checkpoints, entry.sequence_number) do
        nil ->
          state

        checkpoint ->
          cp_result = %{
            sequence_number: checkpoint.sequence_number,
            valid: checkpoint.checksum == entry.checksum,
            checkpoint_checksum: checkpoint.checksum,
            chain_checksum: entry.checksum
          }

          state = %{state | checkpoint_results: state.checkpoint_results ++ [cp_result]}

          if not cp_result.valid do
            %{state |
              valid: false,
              first_failure: state.first_failure || %{
                type: :checkpoint_mismatch,
                sequence_number: entry.sequence_number,
                detail: cp_result
              }
            }
          else
            state
          end
      end

    %{state |
      previous_checksum: entry.checksum,
      expected_sequence: entry.sequence_number + 1
    }
  end

  defp chain_entry_attrs(entry) do
    %{
      sequence_number: entry.sequence_number,
      timestamp: entry.timestamp,
      user_id: entry.user_id,
      user_role: entry.user_role,
      session_id: entry.session_id,
      action: entry.action,
      resource_type: entry.resource_type,
      resource_id: entry.resource_id,
      outcome: entry.outcome,
      failure_reason: entry.failure_reason,
      phi_accessed: entry.phi_accessed,
      source_ip: entry.source_ip,
      user_agent: entry.user_agent,
      metadata: entry.metadata
    }
  end
end
```

---

## 8. Checkpoint Worker — `GA.Audit.CheckpointWorker`

```elixir
defmodule GA.Audit.CheckpointWorker do
  @moduledoc """
  Periodic GenServer that creates chain checkpoints.
  Default interval: 1 hour.
  """

  use GenServer
  require Logger

  @default_interval_ms :timer.hours(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    interval = Keyword.get(opts, :interval_ms, @default_interval_ms)
    schedule_checkpoint(interval)
    {:ok, %{interval_ms: interval}}
  end

  @impl true
  def handle_info(:create_checkpoint, state) do
    case GA.Audit.create_checkpoint() do
      {:ok, checkpoint} ->
        Logger.info(
          "Audit checkpoint created at sequence #{checkpoint.sequence_number}"
        )

      {:error, :no_entries} ->
        Logger.debug("No audit entries yet — skipping checkpoint")

      {:error, reason} ->
        Logger.error("Failed to create audit checkpoint: #{inspect(reason)}")
    end

    schedule_checkpoint(state.interval_ms)
    {:noreply, state}
  end

  defp schedule_checkpoint(interval_ms) do
    Process.send_after(self(), :create_checkpoint, interval_ms)
  end
end
```

Add to supervision tree in `GA.Application`:

```elixir
# lib/app/application.ex — add to children list
children = [
  GA.Repo,
  GAWeb.Telemetry,
  {DNSCluster, query: Application.get_env(:app, :dns_cluster_query) || :ignore},
  {Phoenix.PubSub, name: GA.PubSub},
  GA.Audit.CheckpointWorker,  # <-- add before Endpoint
  GAWeb.Endpoint
]
```

---

## 9. API Authentication — `GAWeb.Plugs.ApiAuth`

```elixir
defmodule GAWeb.Plugs.ApiAuth do
  @moduledoc """
  Bearer token authentication plug for the audit API.
  Validates the token against a single API key from config.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    expected_key = api_key()

    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] when token == expected_key ->
        conn

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.put_view(json: GAWeb.ErrorJSON)
        |> Phoenix.Controller.render(:error, %{status: 401, message: "Invalid or missing API key"})
        |> halt()
    end
  end

  defp api_key do
    Application.fetch_env!(:app, __MODULE__)
    |> Keyword.fetch!(:api_key)
  end
end
```

**Config entries:**

```elixir
# config/dev.exs and config/test.exs
config :app, GAWeb.Plugs.ApiAuth,
  api_key: "dev-api-key-not-for-production"

# config/runtime.exs (inside `if config_env() == :prod`)
config :app, GAWeb.Plugs.ApiAuth,
  api_key:
    System.get_env("AUDIT_API_KEY") ||
      raise "AUDIT_API_KEY environment variable is not set"
```

---

## 10. Router

```elixir
defmodule GAWeb.Router do
  use GAWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GAWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authenticated_api do
    plug :accepts, ["json"]
    plug GAWeb.Plugs.ApiAuth
  end

  scope "/", GAWeb do
    pipe_through :browser
    get "/", PageController, :home
  end

  scope "/api/v1", GAWeb do
    pipe_through :api

    get "/openapi", OpenApiSpexController, :index
  end

  scope "/api/v1", GAWeb do
    pipe_through :authenticated_api

    resources "/audit-logs", AuditLogController, only: [:create, :index, :show]
    resources "/checkpoints", CheckpointController, only: [:create, :index]
    post "/verify", VerificationController, :create
  end

  # Dev only routes
  if Mix.env() in [:dev, :test] do
    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: GAWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/api/v1" do
      pipe_through :browser
      get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/v1/openapi"
    end
  end
end
```

---

## 11. OpenAPI Spec — `GAWeb.ApiSpec`

```elixir
defmodule GAWeb.ApiSpec do
  alias OpenApiSpex.{Info, OpenApi, Paths, Server, SecurityScheme, Components}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "GoodAudit API",
        version: "1.0.0",
        description: "HIPAA-compliant tamper-evident audit logging API"
      },
      servers: [%Server{url: "/api/v1"}],
      paths: Paths.from_router(GAWeb.Router),
      components: %Components{
        securitySchemes: %{
          "bearer" => %SecurityScheme{
            type: "http",
            scheme: "bearer",
            description: "API key passed as Bearer token"
          }
        }
      },
      security: [%{"bearer" => []}]
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
```

### OpenAPI Controller

```elixir
defmodule GAWeb.OpenApiSpexController do
  use GAWeb, :controller

  def index(conn, _params) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(GAWeb.ApiSpec.spec()))
  end
end
```

---

## 12. OpenAPI Schemas

### 12.1 `GAWeb.Schemas.AuditLogRequest`

```elixir
defmodule GAWeb.Schemas.AuditLogRequest do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogRequest",
    description: "Request body for creating an audit log entry",
    type: :object,
    required: [:user_id, :user_role, :action, :resource_type, :resource_id],
    properties: %{
      user_id: %Schema{type: :string, description: "ID of the user performing the action"},
      user_role: %Schema{type: :string, description: "Role of the user (e.g., physician, nurse, admin)"},
      session_id: %Schema{type: :string, description: "Session identifier"},
      action: %Schema{
        type: :string,
        enum: ["create", "read", "update", "delete", "export", "login", "logout"],
        description: "Type of action performed"
      },
      resource_type: %Schema{type: :string, description: "Type of resource accessed (e.g., patient_record, lab_result)"},
      resource_id: %Schema{type: :string, description: "ID of the specific resource accessed"},
      timestamp: %Schema{type: :string, format: :"date-time", description: "ISO 8601 timestamp (defaults to now)"},
      source_ip: %Schema{type: :string, description: "IP address of the request origin"},
      user_agent: %Schema{type: :string, description: "User-Agent string of the client"},
      outcome: %Schema{type: :string, enum: ["success", "failure"], default: "success"},
      failure_reason: %Schema{type: :string, description: "Required when outcome is 'failure'"},
      phi_accessed: %Schema{type: :boolean, default: false, description: "Whether PHI was accessed"},
      metadata: %Schema{type: :object, description: "Additional key-value metadata"}
    }
  })
end
```

### 12.2 `GAWeb.Schemas.AuditLogResponse`

```elixir
defmodule GAWeb.Schemas.AuditLogResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogResponse",
    description: "An audit log entry with chain integrity fields",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      sequence_number: %Schema{type: :integer},
      checksum: %Schema{type: :string, description: "HMAC-SHA-256 chain checksum (64 hex chars)"},
      previous_checksum: %Schema{type: :string, nullable: true},
      user_id: %Schema{type: :string},
      user_role: %Schema{type: :string},
      session_id: %Schema{type: :string, nullable: true},
      action: %Schema{type: :string},
      resource_type: %Schema{type: :string},
      resource_id: %Schema{type: :string},
      timestamp: %Schema{type: :string, format: :"date-time"},
      source_ip: %Schema{type: :string, nullable: true},
      user_agent: %Schema{type: :string, nullable: true},
      outcome: %Schema{type: :string},
      failure_reason: %Schema{type: :string, nullable: true},
      phi_accessed: %Schema{type: :boolean},
      metadata: %Schema{type: :object},
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end
```

### 12.3 `GAWeb.Schemas.AuditLogListResponse`

```elixir
defmodule GAWeb.Schemas.AuditLogListResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "AuditLogListResponse",
    description: "Paginated list of audit log entries",
    type: :object,
    properties: %{
      data: %Schema{type: :array, items: GAWeb.Schemas.AuditLogResponse},
      meta: %Schema{
        type: :object,
        properties: %{
          next_cursor: %Schema{type: :integer, nullable: true, description: "Sequence number for next page"},
          count: %Schema{type: :integer, description: "Number of entries in this page"}
        }
      }
    }
  })
end
```

### 12.4 `GAWeb.Schemas.CheckpointResponse`

```elixir
defmodule GAWeb.Schemas.CheckpointResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "CheckpointResponse",
    description: "A chain checkpoint anchor",
    type: :object,
    properties: %{
      id: %Schema{type: :string, format: :uuid},
      sequence_number: %Schema{type: :integer},
      checksum: %Schema{type: :string},
      signature: %Schema{type: :string, nullable: true},
      verified_at: %Schema{type: :string, format: :"date-time", nullable: true},
      inserted_at: %Schema{type: :string, format: :"date-time"}
    }
  })
end
```

### 12.5 `GAWeb.Schemas.VerificationResponse`

```elixir
defmodule GAWeb.Schemas.VerificationResponse do
  require OpenApiSpex
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "VerificationResponse",
    description: "Result of a full chain verification",
    type: :object,
    properties: %{
      valid: %Schema{type: :boolean, description: "Whether the entire chain is intact"},
      total_entries: %Schema{type: :integer},
      verified_entries: %Schema{type: :integer},
      first_failure: %Schema{type: :object, nullable: true, description: "Details of the first integrity failure"},
      sequence_gaps: %Schema{type: :array, items: %Schema{type: :object}},
      checkpoint_results: %Schema{type: :array, items: %Schema{type: :object}},
      duration_ms: %Schema{type: :integer, description: "Verification duration in milliseconds"}
    }
  })
end
```

### 12.6 `GAWeb.Schemas.ErrorResponse`

```elixir
defmodule GAWeb.Schemas.ErrorResponse do
  require OpenApiSpex

  OpenApiSpex.schema(%{
    title: "ErrorResponse",
    description: "Error response",
    type: :object,
    properties: %{
      errors: %OpenApiSpex.Schema{type: :object, description: "Error details"}
    }
  })
end
```

---

## 13. Controllers

### 13.1 `GAWeb.FallbackController`

```elixir
defmodule GAWeb.FallbackController do
  use GAWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GAWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: GAWeb.ErrorJSON)
    |> render(:error, %{status: 404, message: "Not found"})
  end

  def call(conn, {:error, :no_entries}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(json: GAWeb.ErrorJSON)
    |> render(:error, %{status: 422, message: "No audit entries exist yet"})
  end
end
```

### 13.2 `GAWeb.ChangesetJSON`

```elixir
defmodule GAWeb.ChangesetJSON do
  def error(%{changeset: changeset}) do
    %{errors: Ecto.Changeset.traverse_errors(changeset, &translate_error/1)}
  end

  defp translate_error({msg, opts}) do
    Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
      opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
    end)
  end
end
```

### 13.3 `GAWeb.AuditLogController`

```elixir
defmodule GAWeb.AuditLogController do
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit

  action_fallback GAWeb.FallbackController

  tags ["Audit Logs"]
  security [%{"bearer" => []}]

  operation :create,
    summary: "Create audit log entry",
    request_body: {"Audit log entry", "application/json", GAWeb.Schemas.AuditLogRequest},
    responses: [
      created: {"Created", "application/json", GAWeb.Schemas.AuditLogResponse},
      unprocessable_entity: {"Validation error", "application/json", GAWeb.Schemas.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def create(conn, %{"audit_log" => params}) do
    with {:ok, log} <- Audit.create_log_entry(params) do
      conn
      |> put_status(:created)
      |> render(:show, log: log)
    end
  end

  def create(conn, params) do
    # Accept flat params (no wrapping key required)
    with {:ok, log} <- Audit.create_log_entry(params) do
      conn
      |> put_status(:created)
      |> render(:show, log: log)
    end
  end

  operation :index,
    summary: "List audit log entries",
    parameters: [
      after_sequence: [in: :query, type: :integer, required: false],
      limit: [in: :query, type: :integer, required: false],
      user_id: [in: :query, type: :string, required: false],
      action: [in: :query, type: :string, required: false],
      resource_type: [in: :query, type: :string, required: false],
      resource_id: [in: :query, type: :string, required: false],
      outcome: [in: :query, type: :string, required: false],
      phi_accessed: [in: :query, type: :boolean, required: false],
      from: [in: :query, type: :string, format: :"date-time", required: false],
      to: [in: :query, type: :string, format: :"date-time", required: false]
    ],
    responses: [
      ok: {"Audit logs", "application/json", GAWeb.Schemas.AuditLogListResponse},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def index(conn, params) do
    opts =
      params
      |> parse_list_params()

    {entries, next_cursor} = Audit.list_logs(opts)

    render(conn, :index, entries: entries, next_cursor: next_cursor)
  end

  defp parse_list_params(params) do
    []
    |> maybe_put(:after_sequence, params, &parse_integer/1)
    |> maybe_put(:limit, params, &parse_integer/1)
    |> maybe_put(:user_id, params, & &1)
    |> maybe_put(:action, params, & &1)
    |> maybe_put(:resource_type, params, & &1)
    |> maybe_put(:resource_id, params, & &1)
    |> maybe_put(:outcome, params, & &1)
    |> maybe_put(:phi_accessed, params, &parse_boolean/1)
    |> maybe_put(:from, params, &parse_datetime/1)
    |> maybe_put(:to, params, &parse_datetime/1)
  end

  defp maybe_put(opts, key, params, parser) do
    case Map.get(params, to_string(key)) do
      nil -> opts
      value -> Keyword.put(opts, key, parser.(value))
    end
  end

  defp parse_integer(val) when is_integer(val), do: val
  defp parse_integer(val) when is_binary(val), do: String.to_integer(val)

  defp parse_boolean(true), do: true
  defp parse_boolean("true"), do: true
  defp parse_boolean(_), do: false

  defp parse_datetime(val) when is_binary(val) do
    {:ok, dt, _} = DateTime.from_iso8601(val)
    dt
  end

  operation :show,
    summary: "Get audit log entry",
    parameters: [
      id: [in: :path, type: :string, format: :uuid, required: true]
    ],
    responses: [
      ok: {"Audit log", "application/json", GAWeb.Schemas.AuditLogResponse},
      not_found: {"Not found", "application/json", GAWeb.Schemas.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def show(conn, %{"id" => id}) do
    with {:ok, log} <- Audit.get_log(id) do
      render(conn, :show, log: log)
    end
  end
end
```

### 13.4 `GAWeb.AuditLogJSON`

```elixir
defmodule GAWeb.AuditLogJSON do
  alias GA.Audit.Log

  def index(%{entries: entries, next_cursor: next_cursor}) do
    %{
      data: Enum.map(entries, &data/1),
      meta: %{
        next_cursor: next_cursor,
        count: length(entries)
      }
    }
  end

  def show(%{log: log}) do
    %{data: data(log)}
  end

  defp data(%Log{} = log) do
    %{
      id: log.id,
      sequence_number: log.sequence_number,
      checksum: log.checksum,
      previous_checksum: log.previous_checksum,
      user_id: log.user_id,
      user_role: log.user_role,
      session_id: log.session_id,
      action: log.action,
      resource_type: log.resource_type,
      resource_id: log.resource_id,
      timestamp: log.timestamp,
      source_ip: log.source_ip,
      user_agent: log.user_agent,
      outcome: log.outcome,
      failure_reason: log.failure_reason,
      phi_accessed: log.phi_accessed,
      metadata: log.metadata,
      inserted_at: log.inserted_at,
      updated_at: log.updated_at
    }
  end
end
```

### 13.5 `GAWeb.CheckpointController`

```elixir
defmodule GAWeb.CheckpointController do
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit

  action_fallback GAWeb.FallbackController

  tags ["Checkpoints"]
  security [%{"bearer" => []}]

  operation :create,
    summary: "Create chain checkpoint",
    responses: [
      created: {"Created", "application/json", GAWeb.Schemas.CheckpointResponse},
      unprocessable_entity: {"Error", "application/json", GAWeb.Schemas.ErrorResponse},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def create(conn, _params) do
    with {:ok, checkpoint} <- Audit.create_checkpoint() do
      conn
      |> put_status(:created)
      |> render(:show, checkpoint: checkpoint)
    end
  end

  operation :index,
    summary: "List chain checkpoints",
    responses: [
      ok: {"Checkpoints", "application/json", %OpenApiSpex.Schema{
        type: :object,
        properties: %{
          data: %OpenApiSpex.Schema{
            type: :array,
            items: GAWeb.Schemas.CheckpointResponse
          }
        }
      }},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def index(conn, _params) do
    checkpoints = Audit.list_checkpoints()
    render(conn, :index, checkpoints: checkpoints)
  end
end
```

### 13.6 `GAWeb.CheckpointJSON`

```elixir
defmodule GAWeb.CheckpointJSON do
  alias GA.Audit.Checkpoint

  def index(%{checkpoints: checkpoints}) do
    %{data: Enum.map(checkpoints, &data/1)}
  end

  def show(%{checkpoint: checkpoint}) do
    %{data: data(checkpoint)}
  end

  defp data(%Checkpoint{} = cp) do
    %{
      id: cp.id,
      sequence_number: cp.sequence_number,
      checksum: cp.checksum,
      signature: cp.signature,
      verified_at: cp.verified_at,
      inserted_at: cp.inserted_at
    }
  end
end
```

### 13.7 `GAWeb.VerificationController`

```elixir
defmodule GAWeb.VerificationController do
  use GAWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias GA.Audit

  tags ["Verification"]
  security [%{"bearer" => []}]

  operation :create,
    summary: "Verify chain integrity",
    description: "Runs full chain verification from genesis to head. May take time for large chains.",
    responses: [
      ok: {"Verification result", "application/json", GAWeb.Schemas.VerificationResponse},
      unauthorized: {"Unauthorized", "application/json", GAWeb.Schemas.ErrorResponse}
    ]

  def create(conn, _params) do
    result = Audit.verify_chain()

    conn
    |> put_status(:ok)
    |> json(result)
  end
end
```

---

## 14. Module Structure Summary

```
lib/
  app.ex                                # GA module
  app/
    application.ex                      # Add CheckpointWorker to supervision tree
    repo.ex
    audit.ex                            # GA.Audit context
    audit/
      chain.ex                          # GA.Audit.Chain — HMAC computation
      log.ex                            # GA.Audit.Log — Ecto schema
      checkpoint.ex                     # GA.Audit.Checkpoint — Ecto schema
      verifier.ex                       # GA.Audit.Verifier — streaming verification
      checkpoint_worker.ex              # GA.Audit.CheckpointWorker — periodic GenServer
  app_web.ex
  app_web/
    router.ex                           # Updated with API routes
    api_spec.ex                         # GAWeb.ApiSpec — OpenApiSpex root
    plugs/
      api_auth.ex                       # GAWeb.Plugs.ApiAuth — bearer token plug
    schemas/
      audit_log_request.ex
      audit_log_response.ex
      audit_log_list_response.ex
      checkpoint_response.ex
      verification_response.ex
      error_response.ex
    controllers/
      audit_log_controller.ex
      audit_log_json.ex
      checkpoint_controller.ex
      checkpoint_json.ex
      verification_controller.ex
      fallback_controller.ex
      changeset_json.ex
      open_api_spex_controller.ex

priv/repo/migrations/
  YYYYMMDDHHMMSS_create_audit_logs.exs
  YYYYMMDDHHMMSS_create_audit_checkpoints.exs
```

---

## 15. Configuration Summary

### `config/dev.exs`

```elixir
config :app, GA.Audit.Chain,
  hmac_key: "dGVzdC1obWFjLWtleS1mb3ItZGV2ZWxvcG1lbnQtMzI="

config :app, GAWeb.Plugs.ApiAuth,
  api_key: "dev-api-key-not-for-production"
```

### `config/test.exs`

```elixir
config :app, GA.Audit.Chain,
  hmac_key: "dGVzdC1obWFjLWtleS1mb3ItZGV2ZWxvcG1lbnQtMzI="

config :app, GAWeb.Plugs.ApiAuth,
  api_key: "test-api-key"
```

### `config/runtime.exs` (production block)

```elixir
config :app, GA.Audit.Chain,
  hmac_key:
    System.get_env("AUDIT_HMAC_KEY") ||
      raise "AUDIT_HMAC_KEY environment variable is not set"

config :app, GAWeb.Plugs.ApiAuth,
  api_key:
    System.get_env("AUDIT_API_KEY") ||
      raise "AUDIT_API_KEY environment variable is not set"
```

---

## 16. Testing Strategy

### 16.1 Unit Tests — Chain HMAC

```elixir
defmodule GA.Audit.ChainTest do
  use GA.DataCase

  alias GA.Audit.Chain

  describe "compute_checksum/2" do
    test "produces deterministic 64-char hex output" do
      attrs = %{
        sequence_number: 1,
        timestamp: ~U[2025-01-15 10:30:00.000000Z],
        user_id: "user-1",
        user_role: "physician",
        session_id: "sess-1",
        action: "read",
        resource_type: "patient_record",
        resource_id: "rec-123",
        outcome: "success",
        failure_reason: nil,
        phi_accessed: true,
        source_ip: "10.0.0.1",
        user_agent: "EMR/2.0",
        metadata: %{}
      }

      checksum1 = Chain.compute_checksum(attrs, nil)
      checksum2 = Chain.compute_checksum(attrs, nil)

      assert checksum1 == checksum2
      assert String.length(checksum1) == 64
      assert String.match?(checksum1, ~r/^[0-9a-f]{64}$/)
    end

    test "changing any field produces a different checksum" do
      base = %{
        sequence_number: 1,
        timestamp: ~U[2025-01-15 10:30:00.000000Z],
        user_id: "user-1",
        user_role: "physician",
        session_id: nil,
        action: "read",
        resource_type: "patient_record",
        resource_id: "rec-123",
        outcome: "success",
        failure_reason: nil,
        phi_accessed: false,
        source_ip: nil,
        user_agent: nil,
        metadata: %{}
      }

      base_checksum = Chain.compute_checksum(base, nil)

      # Each field change must produce a different checksum
      assert Chain.compute_checksum(%{base | user_id: "user-2"}, nil) != base_checksum
      assert Chain.compute_checksum(%{base | action: "update"}, nil) != base_checksum
      assert Chain.compute_checksum(%{base | resource_id: "rec-999"}, nil) != base_checksum
      assert Chain.compute_checksum(%{base | phi_accessed: true}, nil) != base_checksum
      assert Chain.compute_checksum(%{base | outcome: "failure"}, nil) != base_checksum
    end

    test "different previous_checksum produces different result" do
      attrs = %{
        sequence_number: 2,
        timestamp: ~U[2025-01-15 10:30:00.000000Z],
        user_id: "user-1",
        user_role: "physician",
        session_id: nil,
        action: "read",
        resource_type: "patient_record",
        resource_id: "rec-123",
        outcome: "success",
        failure_reason: nil,
        phi_accessed: false,
        source_ip: nil,
        user_agent: nil,
        metadata: %{}
      }

      cs1 = Chain.compute_checksum(attrs, "aaaa")
      cs2 = Chain.compute_checksum(attrs, "bbbb")

      assert cs1 != cs2
    end

    test "metadata key ordering does not affect checksum" do
      attrs = %{
        sequence_number: 1,
        timestamp: ~U[2025-01-15 10:30:00.000000Z],
        user_id: "user-1",
        user_role: "physician",
        session_id: nil,
        action: "read",
        resource_type: "patient_record",
        resource_id: "rec-123",
        outcome: "success",
        failure_reason: nil,
        phi_accessed: false,
        source_ip: nil,
        user_agent: nil,
        metadata: %{"zebra" => 1, "apple" => 2}
      }

      # Same metadata with different insertion order should yield same checksum
      attrs2 = %{attrs | metadata: %{"apple" => 2, "zebra" => 1}}

      assert Chain.compute_checksum(attrs, nil) == Chain.compute_checksum(attrs2, nil)
    end
  end
end
```

### 16.2 Integration Tests — Entry Creation & Chaining

```elixir
defmodule GA.AuditTest do
  use GA.DataCase

  alias GA.Audit

  @valid_attrs %{
    user_id: "user-1",
    user_role: "physician",
    action: "read",
    resource_type: "patient_record",
    resource_id: "rec-123",
    timestamp: ~U[2025-01-15 10:30:00.000000Z],
    outcome: "success",
    phi_accessed: true,
    source_ip: "10.0.0.1",
    user_agent: "EMR/2.0"
  }

  describe "create_log_entry/1" do
    test "creates first entry with sequence_number 1 and nil previous_checksum" do
      assert {:ok, log} = Audit.create_log_entry(@valid_attrs)
      assert log.sequence_number == 1
      assert log.previous_checksum == nil
      assert is_binary(log.checksum)
      assert String.length(log.checksum) == 64
    end

    test "chains entries sequentially" do
      {:ok, log1} = Audit.create_log_entry(@valid_attrs)
      {:ok, log2} = Audit.create_log_entry(%{@valid_attrs | resource_id: "rec-456"})

      assert log2.sequence_number == 2
      assert log2.previous_checksum == log1.checksum
    end

    test "validates required fields" do
      assert {:error, changeset} = Audit.create_log_entry(%{})
      errors = errors_on(changeset)
      assert "can't be blank" in errors[:user_id]
      assert "can't be blank" in errors[:action]
    end

    test "validates action enum" do
      attrs = Map.put(@valid_attrs, :action, "invalid_action")
      assert {:error, changeset} = Audit.create_log_entry(attrs)
      assert "is invalid" in errors_on(changeset)[:action]
    end

    test "requires failure_reason when outcome is failure" do
      attrs = %{@valid_attrs | outcome: "failure"}
      assert {:error, changeset} = Audit.create_log_entry(attrs)
      assert "can't be blank" in errors_on(changeset)[:failure_reason]
    end
  end

  describe "create_log_entry/1 concurrency" do
    test "concurrent writers produce gap-free sequence" do
      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            Audit.create_log_entry(%{@valid_attrs | resource_id: "rec-#{i}"})
          end)
        end

      results = Task.await_many(tasks, 30_000)
      assert Enum.all?(results, &match?({:ok, _}, &1))

      sequences =
        results
        |> Enum.map(fn {:ok, log} -> log.sequence_number end)
        |> Enum.sort()

      assert sequences == Enum.to_list(1..20)
    end
  end

  describe "list_logs/1" do
    test "returns entries with cursor pagination" do
      for i <- 1..5 do
        Audit.create_log_entry(%{@valid_attrs | resource_id: "rec-#{i}"})
      end

      {page1, cursor} = Audit.list_logs(limit: 3)
      assert length(page1) == 3
      assert cursor == 3

      {page2, cursor2} = Audit.list_logs(limit: 3, after_sequence: cursor)
      assert length(page2) == 2
      assert cursor2 == nil
    end

    test "filters by user_id" do
      Audit.create_log_entry(@valid_attrs)
      Audit.create_log_entry(%{@valid_attrs | user_id: "user-2", resource_id: "rec-2"})

      {entries, _} = Audit.list_logs(user_id: "user-2")
      assert length(entries) == 1
      assert hd(entries).user_id == "user-2"
    end
  end

  describe "verify_chain/0" do
    test "valid chain passes verification" do
      for i <- 1..5 do
        Audit.create_log_entry(%{@valid_attrs | resource_id: "rec-#{i}"})
      end

      result = Audit.verify_chain()
      assert result.valid == true
      assert result.total_entries == 5
      assert result.verified_entries == 5
      assert result.first_failure == nil
      assert result.sequence_gaps == []
    end
  end
end
```

### 16.3 Controller Tests

```elixir
defmodule GAWeb.AuditLogControllerTest do
  use GAWeb.ConnCase

  @valid_attrs %{
    "user_id" => "user-1",
    "user_role" => "physician",
    "action" => "read",
    "resource_type" => "patient_record",
    "resource_id" => "rec-123",
    "outcome" => "success",
    "phi_accessed" => true
  }

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "Bearer test-api-key")

    {:ok, conn: conn}
  end

  describe "POST /api/v1/audit-logs" do
    test "creates entry and returns 201", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/audit-logs", @valid_attrs)
      assert %{"data" => data} = json_response(conn, 201)
      assert data["sequence_number"] == 1
      assert data["checksum"] |> String.length() == 64
    end

    test "returns 401 without auth header" do
      conn =
        build_conn()
        |> put_req_header("accept", "application/json")
        |> post(~p"/api/v1/audit-logs", @valid_attrs)

      assert json_response(conn, 401)
    end

    test "returns 422 for invalid data", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/audit-logs", %{})
      assert json_response(conn, 422)["errors"]
    end
  end

  describe "GET /api/v1/audit-logs" do
    test "returns paginated entries", %{conn: conn} do
      post(conn, ~p"/api/v1/audit-logs", @valid_attrs)

      conn = get(conn, ~p"/api/v1/audit-logs")
      assert %{"data" => [_entry], "meta" => meta} = json_response(conn, 200)
      assert meta["count"] == 1
    end
  end

  describe "GET /api/v1/audit-logs/:id" do
    test "returns the entry", %{conn: conn} do
      conn_post = post(conn, ~p"/api/v1/audit-logs", @valid_attrs)
      %{"data" => %{"id" => id}} = json_response(conn_post, 201)

      conn = get(conn, ~p"/api/v1/audit-logs/#{id}")
      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == id
    end

    test "returns 404 for nonexistent ID", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/audit-logs/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/verify" do
    test "returns verification result", %{conn: conn} do
      post(conn, ~p"/api/v1/audit-logs", @valid_attrs)

      conn = post(conn, ~p"/api/v1/verify")
      result = json_response(conn, 200)
      assert result["valid"] == true
    end
  end
end
```

---

## 17. API Endpoint Summary

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `POST` | `/api/v1/audit-logs` | Bearer | Create audit log entry |
| `GET` | `/api/v1/audit-logs` | Bearer | List entries (cursor pagination + filters) |
| `GET` | `/api/v1/audit-logs/:id` | Bearer | Get single entry by ID |
| `POST` | `/api/v1/checkpoints` | Bearer | Create chain checkpoint |
| `GET` | `/api/v1/checkpoints` | Bearer | List all checkpoints |
| `POST` | `/api/v1/verify` | Bearer | Run full chain verification |
| `GET` | `/api/v1/openapi` | None | OpenAPI spec JSON |
| `GET` | `/api/v1/docs` | None | Swagger UI (dev/test only) |

### Pagination

Cursor-based using `after_sequence` query parameter. The response includes `meta.next_cursor` — pass this as `after_sequence` for the next page. Default `limit` is 50, max 1000.

### Filters (on `GET /api/v1/audit-logs`)

| Parameter | Type | Description |
|-----------|------|-------------|
| `after_sequence` | integer | Cursor: entries after this sequence number |
| `limit` | integer | Max entries per page (default 50, max 1000) |
| `user_id` | string | Filter by user ID |
| `action` | string | Filter by action type |
| `resource_type` | string | Filter by resource type |
| `resource_id` | string | Filter by resource ID |
| `outcome` | string | Filter by outcome (success/failure) |
| `phi_accessed` | boolean | Filter by PHI access flag |
| `from` | ISO 8601 datetime | Entries at or after this time |
| `to` | ISO 8601 datetime | Entries at or before this time |

---

## 18. HIPAA Compliance Checklist

| Requirement | Field(s) | Coverage |
|---|---|---|
| **WHO** performed the action | `user_id`, `user_role`, `session_id` | User identity and role captured on every entry |
| **WHAT** was accessed | `action`, `resource_type`, `resource_id`, `phi_accessed` | Full action + resource identification, PHI flag |
| **WHEN** it happened | `timestamp` | Microsecond-precision UTC timestamp |
| **WHERE** it came from | `source_ip`, `user_agent` | Network origin and client identification |
| **OUTCOME** of the action | `outcome`, `failure_reason` | Success/failure with reason for failures |
| **Immutability** | DB triggers, no UPDATE/DELETE routes | Enforced at database and API layers |
| **Tamper evidence** | `checksum`, `previous_checksum`, `sequence_number` | HMAC chain + gap-free sequences |
| **Auditability** | Verification endpoint, checkpoints | On-demand and periodic integrity verification |
| **Retention** | Append-only storage | Entries cannot be deleted; retention policy configurable at infrastructure level |

---

## 19. Implementation Order

1. Add `open_api_spex` dependency to `mix.exs`
2. Run migrations (audit_logs, audit_checkpoints)
3. Implement `GA.Audit.Chain` (HMAC computation)
4. Implement Ecto schemas (`Log`, `Checkpoint`)
5. Implement `GA.Audit` context (create, list, get, verify)
6. Implement `GA.Audit.Verifier` (streaming verification)
7. Implement `GA.Audit.CheckpointWorker` (periodic GenServer)
8. Implement `GAWeb.Plugs.ApiAuth` (bearer token auth)
9. Implement OpenAPI schemas
10. Implement controllers + JSON views
11. Wire up router
12. Add configuration entries
13. Write and run tests
14. Manual verification with sample data
