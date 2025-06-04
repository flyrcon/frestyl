# lib/frestyl/studio/recording_engine_supervisor.ex
defmodule Frestyl.Studio.RecordingEngineSupervisor do
  @moduledoc """
  DynamicSupervisor for RecordingEngine processes.
  """

  use DynamicSupervisor
  require Logger

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 3,
      max_seconds: 5,
      max_children: 1000
    )
  end

  @doc """
  Starts a RecordingEngine for a session.
  """
  def start_recording_engine(session_id) do
    child_spec = {Frestyl.Studio.RecordingEngine, session_id}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started RecordingEngine for session #{session_id}")
        # Register in the registry
        Frestyl.Studio.RecordingEngineRegistry.register(session_id, pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("RecordingEngine already running for session #{session_id}")
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Failed to start RecordingEngine for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops a RecordingEngine for a session.
  """
  def stop_recording_engine(session_id) do
    case Frestyl.Studio.RecordingEngineRegistry.lookup(session_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Stopped RecordingEngine for session #{session_id}")
        :ok
      {:error, :not_found} ->
        Logger.debug("No RecordingEngine found for session #{session_id}")
        :ok
    end
  end

  @doc """
  Returns the count of active RecordingEngine processes.
  """
  def count_active_engines do
    %{active: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end

  @doc """
  Lists all active RecordingEngine session IDs.
  """
  def list_active_sessions do
    Frestyl.Studio.RecordingEngineRegistry.list_sessions()
  end
end
