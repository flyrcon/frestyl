# lib/frestyl/studio/beat_machine_registry.ex
defmodule Frestyl.Studio.BeatMachineRegistry do
  @moduledoc """
  Registry for BeatMachine processes, allowing lookup by session_id.
  Each session has exactly one BeatMachine instance.
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
  Find the BeatMachine process for a given session.
  """
  def lookup(session_id) do
    case Registry.lookup(__MODULE__, session_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Register a BeatMachine process for a session.
  """
  def register(session_id, pid) do
    Registry.register(__MODULE__, session_id, %{started_at: DateTime.utc_now()})
  end

  @doc """
  List all active BeatMachine sessions.
  """
  def list_sessions do
    Registry.select(__MODULE__, [{{:"$1", :"$2", :"$3"}, [], [:"$1"]}])
  end
end
