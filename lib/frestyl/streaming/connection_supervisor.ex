# lib/frestyl/streaming/connection_supervisor.ex

defmodule Frestyl.Streaming.ConnectionSupervisor do
  @moduledoc """
  Supervises WebRTC connection processes.
  Implements dynamic supervision with adaptive scaling based on load.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    # Configure for maximum performance
    DynamicSupervisor.init(
      strategy: :one_for_one,
      max_restarts: 5,
      max_seconds: 5,
      max_children: 10000
    )
  end

  @doc """
  Starts a new connection process.
  """
  def start_connection(connection_params) do
    child_spec = {Frestyl.Streaming.Connection, connection_params}
    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  @doc """
  Terminates a connection process.
  """
  def terminate_connection(pid) when is_pid(pid) do
    DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  @doc """
  Returns the count of active connections.
  """
  def connection_count do
    %{active: count} = DynamicSupervisor.count_children(__MODULE__)
    count
  end
end
