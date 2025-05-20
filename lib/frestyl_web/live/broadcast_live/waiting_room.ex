# Update your lib/frestyl_web/live/broadcast_live/waiting_room.ex

defmodule FrestylWeb.BroadcastLive.WaitingRoom do
  use FrestylWeb, :live_view

  alias Frestyl.Sessions
  alias Phoenix.PubSub

  @impl true
  def mount(%{"broadcast_id" => id} = params, _session, socket) do
    broadcast_id = String.to_integer(id)

    # Get the session without problematic preloads
    broadcast = Sessions.get_session(broadcast_id)

    if broadcast do
      # Manually get the host
      host = if broadcast.host_id do
        Frestyl.Accounts.get_user!(broadcast.host_id)
      else
        Frestyl.Accounts.get_user!(broadcast.creator_id)
      end

      # Add host to broadcast struct
      broadcast = Map.put(broadcast, :host, host)

      current_user = socket.assigns.current_user

      # Skip participant check for now to avoid schema issues
      # unless Sessions.is_session_participant?(broadcast_id, current_user.id) do
      #   Sessions.add_participant(broadcast_id, current_user.id, "participant")
      # end

      # Check if broadcast has already started
      if broadcast.status == "active" do
        channel_id = params["channel_id"] || broadcast.channel_id
        {:ok, redirect(socket, to: ~p"/channels/#{channel_id}/broadcasts/#{broadcast_id}/live")}
      else
        if connected?(socket) do
          # Subscribe to broadcast events
          PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast_id}")

          # Track presence if available
          if function_exported?(Frestyl.Presence, :track_user, 4) do
            Frestyl.Presence.track_user(self(), "broadcast:#{broadcast_id}:waiting", current_user.id, %{
              joined_waiting_at: DateTime.utc_now(),
              status: "waiting"
            })
          end

          # Start countdown timer
          if broadcast.scheduled_for do
            :timer.send_interval(1000, self(), :countdown_tick)
          end
        end

        # Use a simple count for now
        participant_count = 1 # Sessions.get_participants_count(broadcast_id)

        socket = socket
          |> assign(:broadcast, broadcast)
          |> assign(:host, host)
          |> assign(:current_user, current_user)
          |> assign(:participant_count, participant_count)
          |> assign(:is_host, (broadcast.host_id || broadcast.creator_id) == current_user.id)
          |> assign(:page_title, "Waiting Room - #{broadcast.title}")

        {:ok, socket}
      end
    else
      {:ok,
       socket
       |> put_flash(:error, "Broadcast not found")
       |> redirect(to: "/dashboard")}
    end
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(:countdown_tick, socket) do
    broadcast = socket.assigns.broadcast

    if broadcast.scheduled_for do
      now = DateTime.utc_now()
      time_remaining = DateTime.diff(broadcast.scheduled_for, now, :second)

      if time_remaining <= 0 and broadcast.status != "active" do
        # Time's up but broadcast hasn't started yet
        # The host should start the broadcast
        {:noreply, socket}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:stream_started}, socket) do
    # Redirect to live broadcast when it starts
    channel_id = socket.assigns.broadcast.channel_id
    broadcast_id = socket.assigns.broadcast.id
    {:noreply, redirect(socket, to: ~p"/channels/#{channel_id}/broadcasts/#{broadcast_id}/live")}
  end

  @impl true
  def handle_info({:broadcast_started, broadcast_id}, socket) do
    # Alternative message format
    if socket.assigns.broadcast.id == broadcast_id do
      channel_id = socket.assigns.broadcast.channel_id
      {:noreply, redirect(socket, to: ~p"/channels/#{channel_id}/broadcasts/#{broadcast_id}/live")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:broadcast_updated, updated_broadcast}, socket) do
    if updated_broadcast.id == socket.assigns.broadcast.id do
      # Check if the broadcast status changed to active
      if updated_broadcast.status == "active" do
        channel_id = socket.assigns.broadcast.channel_id
        {:noreply, redirect(socket, to: ~p"/channels/#{channel_id}/broadcasts/#{socket.assigns.broadcast.id}/live")}
      else
        {:noreply, assign(socket, :broadcast, updated_broadcast)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_joined, user_id}, socket) do
    # Update participant count when someone joins the waiting room
    participant_count = Sessions.get_participants_count(socket.assigns.broadcast.id)
    {:noreply, assign(socket, :participant_count, participant_count)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    # Update participant count when someone leaves the waiting room
    participant_count = Sessions.get_participants_count(socket.assigns.broadcast.id)
    {:noreply, assign(socket, :participant_count, participant_count)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    # Update participant count based on presence changes
    participant_count = Sessions.get_participants_count(socket.assigns.broadcast.id)
    {:noreply, assign(socket, :participant_count, participant_count)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-gray-900 to-indigo-900">
      <.live_component
        module={FrestylWeb.EventLive.WaitingRoomComponent}
        id="waiting-room"
        broadcast={@broadcast}
        host={@host}
        current_user={@current_user}
        participant_count={@participant_count}
        is_host={@is_host}
      />
    </div>
    """
  end
end
