# lib/frestyl/studio/audio_text_sync_supervisor.ex
defmodule Frestyl.Studio.AudioTextSyncSupervisor do
  @moduledoc """
  Supervisor for AudioTextSync processes.
  Manages the lifecycle of audio-text synchronization engines per session.
  """

  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_sync_engine(session_id, mode \\ "lyrics_with_audio") do
    child_spec = {Frestyl.Studio.AudioTextSync, {session_id, mode}}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_sync_engine(session_id) do
    case Registry.lookup(Frestyl.Studio.AudioTextSyncRegistry, session_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)
      [] ->
        {:error, :not_found}
    end
  end

  def list_active_engines do
    DynamicSupervisor.which_children(__MODULE__)
  end
end
