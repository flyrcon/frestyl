# lib/frestyl/studio/audio_engine_supervisor.ex
defmodule Frestyl.Studio.AudioEngineSupervisor do
  @moduledoc """
  DynamicSupervisor for AudioEngine processes.
  Manages lifecycle of audio engines for each session.
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
  Starts an AudioEngine for a session.
  Returns {:ok, pid} or {:error, reason}.
  """
  def start_audio_engine(session_id) do
    child_spec = {Frestyl.Studio.AudioEngine, session_id}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started AudioEngine for session #{session_id}")
        # Register in the registry
        Frestyl.Studio.AudioEngineRegistry.register(session_id, pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("AudioEngine already running for session #{session_id}")
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Failed to start AudioEngine for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops an AudioEngine for a session.
  """
  def stop_audio_engine(session_id) do
    case Frestyl.Studio.AudioEngineRegistry.lookup(session_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Stopped AudioEngine for session #{session_id}")
        :ok
      {:error, :not_found} ->
        Logger.debug("No AudioEngine found for session #{session_id}")
        :ok
    end
  end

  @doc """
  Gracefully stops an AudioEngine, allowing it to save state.
  """
  def stop_audio_engine_graceful(session_id, timeout \\ 5000) do
    case Frestyl.Studio.AudioEngineRegistry.lookup(session_id) do
      {:ok, pid} ->
        # Send graceful shutdown signal
        GenServer.call(pid, :prepare_shutdown, timeout)
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Gracefully stopped AudioEngine for session #{session_id}")
        :ok
      {:error, :not_found} ->
        Logger.debug("No AudioEngine found for session #{session_id}")
        :ok
    end
  end

  @doc """
  Returns the count of active AudioEngine processes.
  """
  def count_active_engines do
    %{active: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end

  @doc """
  Lists all active AudioEngine session IDs.
  """
  def list_active_sessions do
    Frestyl.Studio.AudioEngineRegistry.list_sessions()
  end

  @doc """
  Health check for a specific AudioEngine.
  """
  def health_check(session_id) do
    case Frestyl.Studio.AudioEngineRegistry.lookup(session_id) do
      {:ok, pid} ->
        if Process.alive?(pid) do
          try do
            GenServer.call(pid, :health_check, 1000)
          catch
            :exit, {:timeout, _} -> {:error, :timeout}
            :exit, reason -> {:error, reason}
          end
        else
          {:error, :dead}
        end
      {:error, :not_found} ->
        {:error, :not_found}
    end
  end
end
