# lib/frestyl/streaming/connection.ex

defmodule Frestyl.Streaming.Connection do
  @moduledoc """
  Manages individual WebRTC connections.
  Optimized for low latency and efficient memory usage.
  """
  use GenServer, restart: :temporary

  require Logger
  alias Frestyl.PubSub

  def start_link(init_args) do
    GenServer.start_link(__MODULE__, init_args)
  end

  @impl true
  def init(%{user_id: user_id, room_id: room_id, peer_id: peer_id} = state) do
    connection_id = "#{user_id}:#{peer_id}:#{room_id}"
    Logger.metadata(connection_id: connection_id)

    # Subscribe to relevant topics
    PubSub.subscribe(PubSub.user_topic(user_id))
    PubSub.subscribe(PubSub.user_topic(peer_id))
    PubSub.subscribe(PubSub.room_topic(room_id))

    state = Map.put(state, :connection_id, connection_id)

    # Set connection timeout
    Process.send_after(self(), :check_activity, 60_000)

    {:ok, Map.merge(state, %{last_activity: System.monotonic_time(), ice_candidates: []})}
  end

  @impl true
  def handle_info(:check_activity, state) do
    now = System.monotonic_time()
    diff = System.convert_time_unit(now - state.last_activity, :native, :millisecond)

    if diff > 300_000 do
      # 5 minutes of inactivity, terminate the connection
      Logger.info("Terminating inactive connection")
      {:stop, :normal, state}
    else
      # Schedule next check
      Process.send_after(self(), :check_activity, 60_000)
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:ice_candidate, from_id, candidate}, %{peer_id: peer_id} = state) when from_id == peer_id do
    # Forward ICE candidate to client
    PubSub.broadcast_from(
      self(),
      PubSub.user_topic(state.user_id),
      {:ice_candidate, peer_id, candidate}
    )

    ice_candidates = [candidate | state.ice_candidates]
    state = %{state | last_activity: System.monotonic_time(), ice_candidates: ice_candidates}
    {:noreply, state}
  end

  @impl true
  def handle_info({:sdp_offer, from_id, offer}, %{peer_id: peer_id} = state) when from_id == peer_id do
    # Forward SDP offer to client
    PubSub.broadcast_from(
      self(),
      PubSub.user_topic(state.user_id),
      {:sdp_offer, peer_id, offer}
    )

    state = %{state | last_activity: System.monotonic_time()}
    {:noreply, state}
  end

  @impl true
  def handle_info({:sdp_answer, from_id, answer}, %{peer_id: peer_id} = state) when from_id == peer_id do
    # Forward SDP answer to client
    PubSub.broadcast_from(
      self(),
      PubSub.user_topic(state.user_id),
      {:sdp_answer, peer_id, answer}
    )

    state = %{state | last_activity: System.monotonic_time()}
    {:noreply, state}
  end

  @impl true
  def handle_info({:connection_closed, from_id}, %{peer_id: peer_id} = state) when from_id == peer_id do
    # Notify client that the peer closed the connection
    PubSub.broadcast_from(
      self(),
      PubSub.user_topic(state.user_id),
      {:peer_disconnected, peer_id}
    )

    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_, state) do
    # Ignore other messages
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Cleanup when the connection terminates
    PubSub.broadcast(
      PubSub.room_topic(state.room_id),
      {:connection_closed, state.connection_id}
    )
    :ok
  end
end
