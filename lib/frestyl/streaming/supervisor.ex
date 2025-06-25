# lib/frestyl/streaming/supervisor.ex
defmodule Frestyl.Streaming.Supervisor do
  @moduledoc """
  Supervisor for the streaming system, managing streaming engines and related processes.

  Follows the pattern established by RecordingEngineSupervisor but for streaming.
  """

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    Logger.info("Starting Streaming Supervisor")
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Start a streaming engine for a specific stream session
  """
  def start_streaming_engine(stream_session_id) do
    child_spec = {Frestyl.Streaming.Engine, stream_session_id}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started streaming engine for session #{stream_session_id}")
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        Logger.info("Streaming engine already running for session #{stream_session_id}")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start streaming engine for session #{stream_session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stop a streaming engine for a specific stream session
  """
  def stop_streaming_engine(stream_session_id) do
    case Registry.lookup(Frestyl.Streaming.Registry, stream_session_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Stopped streaming engine for session #{stream_session_id}")
        :ok

      [] ->
        Logger.warning("No streaming engine found for session #{stream_session_id}")
        :ok
    end
  end

  @doc """
  Get all running streaming engines
  """
  def list_streaming_engines do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(Frestyl.Streaming.Registry, pid) do
        [stream_session_id] -> {stream_session_id, pid}
        _ -> nil
      end
    end)
    |> Enum.filter(& &1)
  end

  @doc """
  Get streaming engine stats for monitoring
  """
  def get_system_stats do
    engines = list_streaming_engines()

    %{
      active_engines: length(engines),
      total_streams: count_active_streams(engines),
      total_viewers: count_total_viewers(engines),
      system_load: get_system_load()
    }
  end

  # Private helpers

  defp count_active_streams(engines) do
    engines
    |> Enum.map(fn {stream_session_id, _pid} ->
      case Frestyl.Streaming.Engine.get_stream_stats(stream_session_id) do
        %{active_streams: count} -> count
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp count_total_viewers(engines) do
    engines
    |> Enum.map(fn {stream_session_id, _pid} ->
      case Frestyl.Streaming.Engine.get_stream_stats(stream_session_id) do
        %{current_viewers: count} -> count
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp get_system_load do
    # Basic system metrics - would integrate with telemetry in production
    %{
      memory_usage: :erlang.memory(:total),
      process_count: :erlang.system_info(:process_count),
      scheduler_utilization: :scheduler.utilization(1)
    }
  end
end

# lib/frestyl/streaming/registry.ex
defmodule Frestyl.Streaming.Registry do
  @moduledoc """
  Registry for streaming engines, following the pattern used by the recording system.
  """

  def child_spec(_) do
    Registry.child_spec(
      keys: :unique,
      name: __MODULE__
    )
  end
end

# lib/frestyl/streaming/application.ex
defmodule Frestyl.Streaming.Application do
  @moduledoc """
  Streaming system application component.

  This would be added to the main application supervision tree.
  """

  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      # Registry for streaming engines
      Frestyl.Streaming.Registry,

      # Dynamic supervisor for streaming engines
      Frestyl.Streaming.Supervisor,

      # Quality manager for processing streams
      Frestyl.Streaming.QualityManager,

      # RTMP handler for stream output
      Frestyl.Streaming.RTMPHandler,

      # Distribution manager for multi-platform streaming
      Frestyl.Streaming.DistributionManager,

      # Analytics engine for stream metrics
      Frestyl.Streaming.AnalyticsEngine
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
