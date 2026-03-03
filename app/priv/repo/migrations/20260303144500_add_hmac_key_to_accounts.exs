defmodule GA.Repo.Migrations.AddHmacKeyToAccounts do
  use Ecto.Migration

  alias Ecto.Adapters.SQL

  def up do
    alter table(:accounts) do
      add :hmac_key, :binary
    end

    flush()
    backfill_hmac_keys()

    alter table(:accounts) do
      modify :hmac_key, :binary, null: false
    end
  end

  def down do
    alter table(:accounts) do
      remove :hmac_key
    end
  end

  defp backfill_hmac_keys do
    %{rows: rows} = SQL.query!(repo(), "SELECT id FROM accounts WHERE hmac_key IS NULL", [])

    Enum.each(rows, fn [account_id] ->
      SQL.query!(
        repo(),
        "UPDATE accounts SET hmac_key = $1 WHERE id = $2",
        [:crypto.strong_rand_bytes(32), account_id]
      )
    end)
  end
end
