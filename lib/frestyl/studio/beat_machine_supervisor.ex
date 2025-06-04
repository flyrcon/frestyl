# lib/frestyl/studio/beat_machine_supervisor.ex
defmodule Frestyl.Studio.BeatMachineSupervisor do
  @moduledoc """
  DynamicSupervisor for BeatMachine processes.
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
  Starts a BeatMachine for a session.
  """
  def start_beat_machine(session_id) do
    child_spec = {Frestyl.Studio.BeatMachine, session_id}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} ->
        Logger.info("Started BeatMachine for session #{session_id}")
        # Register in the registry
        Frestyl.Studio.BeatMachineRegistry.register(session_id, pid)
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Logger.debug("BeatMachine already running for session #{session_id}")
        {:ok, pid}
      {:error, reason} ->
        Logger.error("Failed to start BeatMachine for session #{session_id}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Stops a BeatMachine for a session.
  """
  def stop_beat_machine(session_id) do
    case Frestyl.Studio.BeatMachineRegistry.lookup(session_id) do
      {:ok, pid} ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
        Logger.info("Stopped BeatMachine for session #{session_id}")
        :ok
      {:error, :not_found} ->
        Logger.debug("No BeatMachine found for session #{session_id}")
        :ok
    end
  end

  @doc """
  Returns the count of active BeatMachine processes.
  """
  def count_active_machines do
    %{active: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end

  @doc """
  Lists all active BeatMachine session IDs.
  """
  def list_active_sessions do
    Frestyl.Studio.BeatMachineRegistry.list_sessions()
  end
end
