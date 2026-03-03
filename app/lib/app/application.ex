defmodule GA.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GAWeb.Telemetry,
      GA.Repo,
      {DNSCluster, query: Application.get_env(:app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GA.PubSub},
      # Start a worker by calling: GA.Worker.start_link(arg)
      # {GA.Worker, arg},
      {GA.Audit.CheckpointWorker, checkpoint_worker_opts()},
      # Start to serve requests, typically the last entry
      GAWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GA.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GAWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp checkpoint_worker_opts do
    Application.get_env(:app, GA.Audit.CheckpointWorker, [])
  end
end
