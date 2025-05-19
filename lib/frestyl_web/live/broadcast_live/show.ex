# Create lib/frestyl_web/live/broadcast_live/show.ex
defmodule FrestylWeb.BroadcastLive.Show do
  use FrestylWeb, :live_view
  alias Frestyl.Sessions

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    broadcast_id = String.to_integer(id)
    broadcast = Sessions.get_session_with_details!(broadcast_id)
    current_user = socket.assigns.current_user

    is_host = broadcast.host_id == current_user.id

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast_id}")

      # Track presence
      if function_exported?(Frestyl.Presence, :track_user, 4) do
        Frestyl.Presence.track_user(self(), "broadcast:#{broadcast_id}", current_user.id, %{
          online_at: DateTime.utc_now(),
          role: if(is_host, do: "host", else: "viewer")
        })
      end
    end

    participants = Sessions.list_session_participants(broadcast_id)
    participant_count = length(participants)

    # Initial statistics
    waiting_count = Enum.count(participants, &(&1.joined_at == nil))
    active_count = Enum.count(participants, &(&1.joined_at != nil && &1.left_at == nil))
    left_count = Enum.count(participants, &(&1.left_at != nil))

    audience_stats = %{
      waiting: waiting_count,
      active: active_count,
      left: left_count,
      total: participant_count
    }

    socket = socket
      |> assign(:broadcast, broadcast)
      |> assign(:is_host, is_host)
      |> assign(:participant_count, participant_count)
      |> assign(:audience_stats, audience_stats)
      |> assign(:current_tab, "stream")
      |> assign(:stream_started, broadcast.status == "active")
      |> assign(:chat_enabled, true)
      |> assign(:reactions_enabled, true)
      |> assign(:muted_users, [])
      |> assign(:blocked_users, [])
      |> assign(:current_quality, "auto")
      |> assign(:audio_only, false)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      case Sessions.update_session(socket.assigns.broadcast, %{status: "active"}) do
        {:ok, updated_broadcast} ->
          # Broadcast stream start event
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}",
            {:stream_started}
          )

          {:noreply,
           socket
           |> assign(:broadcast, updated_broadcast)
           |> assign(:stream_started, true)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to start the stream")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("end_stream", _params, socket) do
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast.id

      case Sessions.update_session(socket.assigns.broadcast, %{
        status: "ended",
        ended_at: DateTime.utc_now()
      }) do
        {:ok, updated_broadcast} ->
          # Broadcast stream end event
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}",
            {:stream_ended}
          )

          {:noreply,
           socket
           |> assign(:broadcast, updated_broadcast)
           |> assign(:stream_started, false)}

        {:error, _} ->
          {:noreply,
           socket
           |> put_flash(:error, "Failed to end the stream")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  @impl true
  def handle_event("set_quality", %{"quality" => quality}, socket) do
    {:noreply, assign(socket, :current_quality, quality)}
  end

  @impl true
  def handle_event("toggle_audio_only", _params, socket) do
    {:noreply, assign(socket, :audio_only, !socket.assigns.audio_only)}
  end

  @impl true
  def handle_info({:stream_started}, socket) do
    {:noreply, assign(socket, :stream_started, true)}
  end

  @impl true
  def handle_info({:stream_ended}, socket) do
    {:noreply, assign(socket, :stream_started, false)}
  end

  @impl true
  def handle_info({:user_joined, user_id}, socket) do
    # Update audience stats
    stats = socket.assigns.audience_stats
    new_stats = %{stats | active: stats.active + 1, waiting: stats.waiting - 1}

    {:noreply, assign(socket, :audience_stats, new_stats)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # Update audience stats
    stats = socket.assigns.audience_stats
    new_stats = %{stats | active: stats.active - 1, left: stats.left + 1}

    {:noreply, assign(socket, :audience_stats, new_stats)}
  end

  @impl true
  def handle_info({:chat_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :chat_enabled, enabled)}
  end

  @impl true
  def handle_info({:reactions_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :reactions_enabled, enabled)}
  end

  @impl true
  def handle_info({:user_muted, user_id}, socket) do
    {:noreply, assign(socket, :muted_users, [user_id | socket.assigns.muted_users])}
  end

  @impl true
  def handle_info({:user_unmuted, user_id}, socket) do
    muted_users = Enum.reject(socket.assigns.muted_users, &(&1 == user_id))
    {:noreply, assign(socket, :muted_users, muted_users)}
  end

  @impl true
  def handle_info({:user_blocked, user_id}, socket) do
    {:noreply, assign(socket, :blocked_users, [user_id | socket.assigns.blocked_users])}
  end

  @impl true
  def handle_info({:user_unblocked, user_id}, socket) do
    blocked_users = Enum.reject(socket.assigns.blocked_users, &(&1 == user_id))
    {:noreply, assign(socket, :blocked_users, blocked_users)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    broadcast_id = socket.assigns.broadcast.id

    # Get current audience statistics
    participants = Sessions.list_session_participants(broadcast_id)
    participant_count = length(participants)

    # Updated statistics
    waiting_count = Enum.count(participants, &(&1.joined_at == nil))
    active_count = Enum.count(participants, &(&1.joined_at != nil && &1.left_at == nil))
    left_count = Enum.count(participants, &(&1.left_at != nil))

    audience_stats = %{
      waiting: waiting_count,
      active: active_count,
      left: left_count,
      total: participant_count
    }

    {:noreply,
     socket
     |> assign(:participant_count, participant_count)
     |> assign(:audience_stats, audience_stats)}
  end
end
