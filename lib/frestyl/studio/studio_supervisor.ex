# lib/frestyl/studio/studio_supervisor.ex
defmodule Frestyl.Studio.StudioSupervisor do
  @moduledoc """
  Main supervisor for all Studio-related processes.
  Coordinates AudioEngine and BeatMachine supervision.
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Registries first - other processes depend on them
      Frestyl.Studio.AudioEngineRegistry,
      Frestyl.Studio.BeatMachineRegistry,
      Frestyl.Studio.RecordingEngineRegistry,

      # Dynamic Supervisors
      Frestyl.Studio.AudioEngineSupervisor,
      Frestyl.Studio.BeatMachineSupervisor,
      Frestyl.Studio.RecordingEngineSupervisor
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Starts complete studio session (AudioEngine + BeatMachine + RecordingEngine).
  Used when a user first joins a studio session.
  """
  def start_studio_session(session_id) do
    with {:ok, _audio_pid} <- Frestyl.Studio.AudioEngineSupervisor.start_audio_engine(session_id),
         {:ok, _beat_pid} <- Frestyl.Studio.BeatMachineSupervisor.start_beat_machine(session_id),
         {:ok, _recording_pid} <- Frestyl.Studio.RecordingEngineSupervisor.start_recording_engine(session_id) do
      Logger.info("Started complete studio session for #{session_id}")
      {:ok, :studio_session_started}
    else
      {:error, reason} ->
        Logger.error("Failed to start studio session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops complete studio session (all engines).
  Used when a session ends or times out.
  """
  def stop_studio_session(session_id) do
    Frestyl.Studio.AudioEngineSupervisor.stop_audio_engine(session_id)
    Frestyl.Studio.BeatMachineSupervisor.stop_beat_machine(session_id)
    Frestyl.Studio.RecordingEngineSupervisor.stop_recording_engine(session_id)
    Logger.info("Stopped complete studio session for #{session_id}")
    :ok
  end

  @doc """
  Gracefully stops a studio session, allowing processes to save state.
  """
  def stop_studio_session_graceful(session_id, timeout \\ 5000) do
    # Stop AudioEngine gracefully first (it has more state to save)
    Frestyl.Studio.AudioEngineSupervisor.stop_audio_engine_graceful(session_id, timeout)
    Frestyl.Studio.BeatMachineSupervisor.stop_beat_machine(session_id)
    Frestyl.Studio.RecordingEngineSupervisor.stop_recording_engine(session_id)
    Logger.info("Gracefully stopped complete studio session for #{session_id}")
    :ok
  end

  @doc """
  Get status information for all studio processes.
  """
  def get_studio_status do
    %{
      audio_engines: Frestyl.Studio.AudioEngineSupervisor.count_active_engines(),
      beat_machines: Frestyl.Studio.BeatMachineSupervisor.count_active_machines(),
      recording_engines: Frestyl.Studio.RecordingEngineSupervisor.count_active_engines(),
      active_sessions: Frestyl.Studio.AudioEngineSupervisor.list_active_sessions()
    }
  end

  @doc """
  Health check for a specific studio session.
  """
  def health_check(session_id) do
    audio_health = Frestyl.Studio.AudioEngineSupervisor.health_check(session_id)
    beat_health = case Frestyl.Studio.BeatMachineRegistry.lookup(session_id) do
      {:ok, pid} -> if Process.alive?(pid), do: :ok, else: {:error, :dead}
      {:error, :not_found} -> {:error, :not_found}
    end
    recording_health = case Frestyl.Studio.RecordingEngineRegistry.lookup(session_id) do
      {:ok, pid} -> if Process.alive?(pid), do: :ok, else: {:error, :dead}
      {:error, :not_found} -> {:error, :not_found}
    end

    %{
      session_id: session_id,
      audio_engine: audio_health,
      beat_machine: beat_health,
      recording_engine: recording_health,
      overall: if(audio_health == :ok and beat_health == :ok and recording_health == :ok, do: :healthy, else: :degraded)
    }
  end
end
