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

      Frestyl.Storage.TempFileManager,
      {Task.Supervisor, name: Frestyl.TaskSupervisor},

      # StudioSupervisor handles ALL studio registries and supervisors
      Frestyl.Studio.StudioSupervisor,
      Frestyl.Streaming.Registry,

      # Dynamic supervisor for streaming engines
      Frestyl.Streaming.Supervisor,

      # Quality manager for processing streams
      Frestyl.Streaming.QualityManager,

      # Audio-Text Sync Registry and Supervisor
      {Registry, keys: :unique, name: Frestyl.Studio.AudioTextSyncRegistry},


      # Podcast & Editing Registries
      {Registry, keys: :unique, name: Frestyl.PodcastRegistry},
      {Registry, keys: :unique, name: Frestyl.EditingRegistry},

      # Podcast Processing Supervisor
      {DynamicSupervisor, strategy: :one_for_one, name: Frestyl.Podcasts.ProcessingSupervisor},

      # Content Editing Supervisor
      {DynamicSupervisor, strategy: :one_for_one, name: Frestyl.ContentEditing.ProjectSupervisor},

      # Render Job Queue
      {DynamicSupervisor, strategy: :one_for_one, name: Frestyl.ContentEditing.RenderSupervisor},

      {DynamicSupervisor, strategy: :one_for_one, name: Frestyl.Studio.AudioTextSyncSupervisor},

      {ChromicPDF, chromic_pdf_opts()},

      #{Oban, Application.fetch_env!(:frestyl, Oban)},

      # Supervisor for WebRTC connections
      Frestyl.Streaming.ConnectionSupervisor,
      # Analytics for streaming
      Frestyl.Streaming.Analytics,
      {Frestyl.Cache, []},
      {Frestyl.EventScheduler, []},
      # Start to serve requests, typically the last entry
      FrestylWeb.Endpoint,
    ]

    # Initialize sample library on startup (development only)
    if Mix.env() == :dev do
      Task.start(fn ->
        :timer.sleep(1000) # Wait for app to start
        Frestyl.Studio.SampleManager.initialize_sample_library()
      end)
    end

    # Initialize ETS tables for content campaigns Phase 2
    :ets.new(:improvement_periods, [:set, :public, :named_table])
    :ets.new(:peer_review_requests, [:set, :public, :named_table])
    :ets.new(:campaign_sessions, [:set, :public, :named_table])
    :ets.new(:live_campaign_metrics, [:set, :public, :named_table])
    :ets.new(:quality_gates_status, [:set, :public, :named_table])

    opts = [strategy: :one_for_one, name: Frestyl.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    FrestylWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Register MIME types that might not be included by default
  defp register_mime_types do
    # Audio formats
    MIME.register("audio/ogg", ["ogg"])
    MIME.register("audio/mpeg", ["mp3"])
    MIME.register("audio/wav", ["wav"])

    # Video formats
    MIME.register("video/ogg", ["ogv"])
    MIME.register("video/mp4", ["mp4"])
    MIME.register("video/quicktime", ["mov"])
    MIME.register("video/webm", ["webm"])

    # Document formats
    MIME.register("application/pdf", ["pdf"])
    MIME.register("application/msword", ["doc"])
    MIME.register("application/vnd.openxmlformats-officedocument.wordprocessingml.document", ["docx"])

    # Image formats (usually already registered, but just in case)
    MIME.register("image/jpeg", ["jpg", "jpeg"])
    MIME.register("image/png", ["png"])
    MIME.register("image/gif", ["gif"])

    :ok
  end

    # ChromicPDF configuration
  defp chromic_pdf_opts do
    case Mix.env() do
      :prod ->
        [
          # Production settings - assumes Chrome/Chromium is installed
          chrome_executable: System.get_env("CHROME_EXECUTABLE") || "/usr/bin/google-chrome",
          chrome_args: [
            "--no-sandbox",
            "--disable-dev-shm-usage",
            "--disable-gpu",
            "--headless"
          ]
        ]

      :test ->
        [
          # Test environment - might not have Chrome available
          chrome_executable: System.get_env("CHROME_EXECUTABLE"),
          chrome_args: ["--headless", "--no-sandbox", "--disable-gpu"]
        ]

      _ ->
        [
          # Development settings
          chrome_args: ["--headless", "--no-sandbox", "--disable-gpu"]
        ]
    end
  end
end
