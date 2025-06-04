defmodule Frestyl.Application do
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
      Frestyl.Scheduler,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Frestyl.Finch},

      # StudioSupervisor handles ALL studio registries and supervisors
      Frestyl.Studio.StudioSupervisor,

      # Supervisor for WebRTC connections
      Frestyl.Streaming.ConnectionSupervisor,
      # Analytics for streaming
      Frestyl.Streaming.Analytics,
      {Frestyl.Cache, []},
      # Start to serve requests, typically the last entry
      FrestylWeb.Endpoint,
      {Frestyl.EventScheduler, []}
    ]

    # Initialize sample library on startup (development only)
    if Mix.env() == :dev do
      Task.start(fn ->
        :timer.sleep(1000) # Wait for app to start
        Frestyl.Studio.SampleManager.initialize_sample_library()
      end)
    end

    opts = [strategy: :one_for_one, name: Frestyl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    FrestylWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
