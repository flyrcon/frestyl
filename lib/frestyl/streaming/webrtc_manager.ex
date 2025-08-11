# lib/frestyl/streaming/webrtc_manager.ex
defmodule Frestyl.Streaming.WebRTCManager do
  @moduledoc """
  Manages WebRTC signaling for video broadcasting.
  Handles peer connections, offer/answer exchange, and ICE candidates.
  """

  use GenServer
  require Logger
  alias Phoenix.PubSub

  defstruct [
    :broadcast_id,
    :host_user_id,
    :viewers,
    :peer_connections,
    :connection_states,
    :stream_quality,
    :started_at
  ]

  # Client API

  def start_link(broadcast_id) do
    GenServer.start_link(__MODULE__, broadcast_id, name: via_tuple(broadcast_id))
  end

  def join_broadcast(broadcast_id, user_id, is_host \\ false) do
    GenServer.call(via_tuple(broadcast_id), {:join_broadcast, user_id, is_host})
  end

  def leave_broadcast(broadcast_id, user_id) do
    GenServer.call(via_tuple(broadcast_id), {:leave_broadcast, user_id})
  end

  def send_offer(broadcast_id, from_user_id, to_user_id, offer) do
    GenServer.cast(via_tuple(broadcast_id), {:send_offer, from_user_id, to_user_id, offer})
  end

  def send_answer(broadcast_id, from_user_id, to_user_id, answer) do
    GenServer.cast(via_tuple(broadcast_id), {:send_answer, from_user_id, to_user_id, answer})
  end

  def send_ice_candidate(broadcast_id, from_user_id, to_user_id, candidate) do
    GenServer.cast(via_tuple(broadcast_id), {:send_ice_candidate, from_user_id, to_user_id, candidate})
  end

  def update_stream_quality(broadcast_id, quality) do
    GenServer.cast(via_tuple(broadcast_id), {:update_stream_quality, quality})
  end

  def get_broadcast_state(broadcast_id) do
    try do
      GenServer.call(via_tuple(broadcast_id), :get_state)
    catch
      :exit, {:noproc, _} -> {:error, :not_found}
    end
  end

  def stop_broadcast(broadcast_id) do
    try do
      GenServer.stop(via_tuple(broadcast_id), :normal)
    catch
      :exit, {:noproc, _} -> :ok
    end
  end

  # GenServer Callbacks

  @impl true
  def init(broadcast_id) do
    state = %__MODULE__{
      broadcast_id: broadcast_id,
      host_user_id: nil,
      viewers: MapSet.new(),
      peer_connections: %{},
      connection_states: %{},
      stream_quality: "720p",
      started_at: DateTime.utc_now()
    }

    Logger.info("WebRTC Manager started for broadcast #{broadcast_id}")
    {:ok, state}
  end

  @impl true
  def handle_call({:join_broadcast, user_id, is_host}, _from, state) do
    cond do
      is_host and state.host_user_id == nil ->
        # Set as host
        new_state = %{state | host_user_id: user_id}

        # Broadcast host joined event
        broadcast_event(state.broadcast_id, {:host_joined, user_id})

        Logger.info("Host #{user_id} joined broadcast #{state.broadcast_id}")
        {:reply, {:ok, :host}, new_state}

      is_host and state.host_user_id != nil ->
        # Host already exists
        {:reply, {:error, :host_exists}, state}

      not is_host and state.host_user_id != nil ->
        # Add as viewer
        new_viewers = MapSet.put(state.viewers, user_id)
        new_state = %{state | viewers: new_viewers}

        # Notify host about new viewer
        send_to_user(state.host_user_id, {:viewer_joined, user_id})

        # Notify other viewers
        Enum.each(state.viewers, fn viewer_id ->
          if viewer_id != user_id do
            send_to_user(viewer_id, {:new_viewer_joined, user_id})
          end
        end)

        Logger.info("Viewer #{user_id} joined broadcast #{state.broadcast_id}")
        {:reply, {:ok, :viewer}, new_state}

      true ->
        # No host yet, can't join as viewer
        {:reply, {:error, :no_host}, state}
    end
  end

  @impl true
  def handle_call({:leave_broadcast, user_id}, _from, state) do
    cond do
      user_id == state.host_user_id ->
        # Host is leaving, end the broadcast
        broadcast_event(state.broadcast_id, {:host_left, user_id})
        broadcast_event(state.broadcast_id, {:broadcast_ended})

        # Notify all viewers
        Enum.each(state.viewers, fn viewer_id ->
          send_to_user(viewer_id, {:broadcast_ended})
        end)

        Logger.info("Host #{user_id} left broadcast #{state.broadcast_id}")
        {:reply, :ok, state}

      MapSet.member?(state.viewers, user_id) ->
        # Viewer is leaving
        new_viewers = MapSet.delete(state.viewers, user_id)
        new_peer_connections = Map.delete(state.peer_connections, user_id)
        new_connection_states = Map.delete(state.connection_states, user_id)

        new_state = %{state |
          viewers: new_viewers,
          peer_connections: new_peer_connections,
          connection_states: new_connection_states
        }

        # Notify host
        if state.host_user_id do
          send_to_user(state.host_user_id, {:viewer_left, user_id})
        end

        Logger.info("Viewer #{user_id} left broadcast #{state.broadcast_id}")
        {:reply, :ok, new_state}

      true ->
        # User not in broadcast
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    public_state = %{
      broadcast_id: state.broadcast_id,
      host_user_id: state.host_user_id,
      viewer_count: MapSet.size(state.viewers),
      stream_quality: state.stream_quality,
      started_at: state.started_at,
      connection_states: state.connection_states
    }
    {:reply, {:ok, public_state}, state}
  end

  @impl true
  def handle_cast({:send_offer, from_user_id, to_user_id, offer}, state) do
    # Validate that from_user is authorized to send offer
    if from_user_id == state.host_user_id or MapSet.member?(state.viewers, from_user_id) do
      # Send offer to target user
      send_to_user(to_user_id, {:webrtc_offer, from_user_id, offer})

      # Track peer connection
      connection_key = {from_user_id, to_user_id}
      new_peer_connections = Map.put(state.peer_connections, connection_key, %{
        status: :offer_sent,
        created_at: DateTime.utc_now()
      })

      new_state = %{state | peer_connections: new_peer_connections}
      Logger.debug("Offer sent from #{from_user_id} to #{to_user_id}")
      {:noreply, new_state}
    else
      Logger.warning("Unauthorized offer attempt from #{from_user_id}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:send_answer, from_user_id, to_user_id, answer}, state) do
    if from_user_id == state.host_user_id or MapSet.member?(state.viewers, from_user_id) do
      # Send answer to target user
      send_to_user(to_user_id, {:webrtc_answer, from_user_id, answer})

      # Update peer connection status
      connection_key = {to_user_id, from_user_id}  # Note: reversed for answer
      new_peer_connections = Map.update(state.peer_connections, connection_key, %{}, fn connection ->
        Map.put(connection, :status, :answer_sent)
      end)

      new_state = %{state | peer_connections: new_peer_connections}
      Logger.debug("Answer sent from #{from_user_id} to #{to_user_id}")
      {:noreply, new_state}
    else
      Logger.warning("Unauthorized answer attempt from #{from_user_id}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_cast({:send_ice_candidate, from_user_id, to_user_id, candidate}, state) do
    if from_user_id == state.host_user_id or MapSet.member?(state.viewers, from_user_id) do
      # Send ICE candidate to target user
      send_to_user(to_user_id, {:webrtc_ice_candidate, from_user_id, candidate})
      Logger.debug("ICE candidate sent from #{from_user_id} to #{to_user_id}")
    else
      Logger.warning("Unauthorized ICE candidate from #{from_user_id}")
    end
    {:noreply, state}
  end

  @impl true
  def handle_cast({:update_stream_quality, quality}, state) do
    # Validate quality setting
    valid_qualities = ["480p", "720p", "1080p", "4K"]

    if quality in valid_qualities do
      new_state = %{state | stream_quality: quality}

      # Broadcast quality change to all participants
      broadcast_event(state.broadcast_id, {:stream_quality_changed, quality})

      if state.host_user_id do
        send_to_user(state.host_user_id, {:stream_quality_change, quality})
      end

      Enum.each(state.viewers, fn viewer_id ->
        send_to_user(viewer_id, {:stream_quality_change, quality})
      end)

      Logger.info("Stream quality changed to #{quality} for broadcast #{state.broadcast_id}")
      {:noreply, new_state}
    else
      Logger.warning("Invalid quality setting: #{quality}")
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:connection_state_update, user_id, connection_state}, state) do
    new_connection_states = Map.put(state.connection_states, user_id, %{
      state: connection_state,
      updated_at: DateTime.utc_now()
    })

    new_state = %{state | connection_states: new_connection_states}

    # If connection failed, attempt cleanup
    if connection_state in ["failed", "disconnected"] do
      cleanup_failed_connection(state.broadcast_id, user_id)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:cleanup_inactive_connections, state) do
    # Remove connections that haven't been updated in 30 seconds
    cutoff_time = DateTime.add(DateTime.utc_now(), -30, :second)

    active_connections = Enum.filter(state.connection_states, fn {_user_id, connection_info} ->
      DateTime.compare(connection_info.updated_at, cutoff_time) == :gt
    end) |> Enum.into(%{})

    new_state = %{state | connection_states: active_connections}

    # Schedule next cleanup
    Process.send_after(self(), :cleanup_inactive_connections, 30_000)

    {:noreply, new_state}
  end

  # Private Functions

  defp via_tuple(broadcast_id) do
    {:via, Registry, {Frestyl.Streaming.WebRTCRegistry, broadcast_id}}
  end

  defp broadcast_event(broadcast_id, event) do
    PubSub.broadcast(Frestyl.PubSub, "broadcast:#{broadcast_id}", event)
    PubSub.broadcast(Frestyl.PubSub, "webrtc:#{broadcast_id}", event)
  end

  defp send_to_user(user_id, message) do
    PubSub.broadcast(Frestyl.PubSub, "user:#{user_id}", message)
  end

  defp cleanup_failed_connection(broadcast_id, user_id) do
    # Notify other users about connection failure
    broadcast_event(broadcast_id, {:connection_failed, user_id})

    # Log for monitoring
    Logger.warning("Connection failed for user #{user_id} in broadcast #{broadcast_id}")
  end
end
