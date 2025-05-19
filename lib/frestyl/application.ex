defmodule Frestyl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Frestyl.Repo,
      FrestylWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:frestyl, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Frestyl.PubSub, adapter_name: Phoenix.PubSub.PG2},
      Frestyl.Presence,
      #{Absinthe.Subscription, FrestylWeb.Endpoint},
      Frestyl.Scheduler,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Frestyl.Finch},
      # Supervisor for WebRTC connections
      Frestyl.Streaming.ConnectionSupervisor,
      # Analytics for streaming
      Frestyl.Streaming.Analytics,
      {Frestyl.Cache, []},
      # Start a worker by calling: Frestyl.Worker.start_link(arg)
      # {Frestyl.Worker, arg},
      # Start to serve requests, typically the last entry
      FrestylWeb.Endpoint,
      {Frestyl.EventScheduler, []}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Frestyl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FrestylWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
