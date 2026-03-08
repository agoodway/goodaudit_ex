defmodule GA.Audit.CheckpointWorker do
  @moduledoc """
  Periodically creates audit checkpoints for all active accounts.
  """

  use GenServer

  import Ecto.Query, warn: false

  require Logger

  alias GA.Accounts.Account
  alias GA.Audit
  alias GA.Repo

  @default_interval_ms :timer.hours(1)

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @impl true
  def init(opts) do
    interval_ms =
      opts
      |> Keyword.get(:interval_ms, configured_interval_ms())
      |> normalize_interval()

    schedule_tick(interval_ms)

    {:ok, %{interval_ms: interval_ms}}
  end

  @impl true
  def handle_info(:create_checkpoints, state) do
    active_account_ids()
    |> Enum.each(&create_checkpoint_for_account/1)

    schedule_tick(state.interval_ms)
    {:noreply, state}
  end

  defp active_account_ids do
    from(account in Account,
      where: account.status == :active,
      select: account.id
    )
    |> Repo.all()
  end

  defp create_checkpoint_for_account(account_id) do
    case Audit.create_checkpoint(account_id) do
      {:ok, _checkpoint} ->
        Logger.debug("checkpoint_worker created checkpoint for account=#{account_id}")

      {:error, :no_entries} ->
        Logger.debug("checkpoint_worker skipping account=#{account_id}: no audit entries")

      {:error, reason} ->
        Logger.error("checkpoint_worker failed for account=#{account_id}: #{inspect(reason)}")
    end
  rescue
    error ->
      Logger.error(
        "checkpoint_worker crashed for account=#{account_id}: #{Exception.message(error)}"
      )
  end

  defp schedule_tick(interval_ms) do
    Process.send_after(self(), :create_checkpoints, interval_ms)
  end

  defp configured_interval_ms do
    :app
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:interval_ms, @default_interval_ms)
  end

  defp normalize_interval(interval_ms) when is_integer(interval_ms) and interval_ms > 0,
    do: interval_ms

  defp normalize_interval(_), do: @default_interval_ms
end
