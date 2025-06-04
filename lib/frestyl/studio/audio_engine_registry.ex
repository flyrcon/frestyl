# lib/frestyl/studio/audio_engine_registry.ex
defmodule Frestyl.Studio.AudioEngineRegistry do
  @moduledoc """
  Registry for AudioEngine processes, allowing lookup by session_id.
  Each session has exactly one AudioEngine instance.
  """

  def start_link(_opts) do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Find the AudioEngine process for a given session.
  """
  def lookup(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Register an AudioEngine process for a session.
  """
  def register(session_id, pid) do
    Registry.register(__MODULE__, session_id, %{started_at: DateTime.utc_now()})
  end

  @doc """
  List all active AudioEngine sessions.
  """
  def list_sessions do
    Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end

  @doc """
  Get metadata for a registered AudioEngine.
  """
  def get_metadata(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{_pid, metadata}] -> {:ok, metadata}
      [] -> {:error, :not_found}
    end
  end
end
