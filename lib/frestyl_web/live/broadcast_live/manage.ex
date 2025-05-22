# Create lib/frestyl_web/live/broadcast_live/manage.ex

defmodule FrestylWeb.BroadcastLive.Manage do
  use FrestylWeb, :live_view

  alias Frestyl.Sessions
  alias Frestyl.Channels
  alias Frestyl.Accounts
  alias Frestyl.Chat
  alias Phoenix.PubSub

  @impl true
  def mount(%{"broadcast_id" => broadcast_id} = params, session, socket) do
    # Get current user from session
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    # Get broadcast by ID
    broadcast = Sessions.get_session(broadcast_id)

    # Get channel (could be from params or broadcast)
    channel = if params["channel_id"] do
      Channels.get_channel(params["channel_id"])
    else
      broadcast && Channels.get_channel(broadcast.channel_id)
    end

    cond do
      is_nil(broadcast) ->
        socket =
          socket
          |> put_flash(:error, "Broadcast not found")
          |> redirect(to: ~p"/dashboard")
        {:ok, socket}

      is_nil(channel) ->
        socket =
          socket
          |> put_flash(:error, "Channel not found")
          |> redirect(to: ~p"/dashboard")
        {:ok, socket}

      not can_manage_broadcast?(broadcast, current_user) ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to manage this broadcast")
          |> redirect(to: ~p"/channels/#{channel.slug}")
        {:ok, socket}

      true ->
        if connected?(socket) do
          # Subscribe to broadcast events
          PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}")
          PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast.id}:participants")

          # Subscribe to chat if using integrated chat
          PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
        end

        # Get broadcast stats and participants
        participants = Sessions.list_session_participants(broadcast.id)
        stats = Sessions.get_broadcast_stats(broadcast.id)

        # Get host information
        host = if broadcast.host_id do
          Accounts.get_user(broadcast.host_id)
        else
          Accounts.get_user(broadcast.creator_id)
        end

        # Initialize form changesets
        broadcast_changeset = Sessions.change_session(broadcast, %{})

        {:ok,
         socket
         |> assign(:current_user, current_user)
         |> assign(:broadcast, broadcast)
         |> assign(:channel, channel)
         |> assign(:host, host)
         |> assign(:participants, participants)
         |> assign(:stats, stats)
         |> assign(:broadcast_changeset, broadcast_changeset)
         |> assign(:page_title, "Manage Broadcast - #{broadcast.title}")
         |> assign(:active_tab, "overview")
         |> assign(:show_edit_form, false)
         |> assign(:show_host_assignment, false)
         |> assign(:selected_participant, nil)
         |> assign(:available_hosts, get_available_hosts(channel))
         |> assign(:chat_messages, get_broadcast_chat_messages(broadcast.id))
         |> assign(:muted_users, [])
         |> assign(:blocked_users, [])
         |> assign(:chat_enabled, true)
         |> assign(:reactions_enabled, true)}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  # Tab Navigation
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Basic Broadcast Settings
  @impl true
  def handle_event("show_edit_form", _params, socket) do
    changeset = Sessions.change_session(socket.assigns.broadcast, %{})
    {:noreply,
     socket
     |> assign(:show_edit_form, true)
     |> assign(:broadcast_changeset, changeset)}
  end

  @impl true
  def handle_event("hide_edit_form", _params, socket) do
    {:noreply, assign(socket, :show_edit_form, false)}
  end

  @impl true
  def handle_event("update_broadcast", %{"session" => params}, socket) do
    %{broadcast: broadcast} = socket.assigns

    case Sessions.update_session(broadcast, params) do
      {:ok, updated_broadcast} ->
        {:noreply,
         socket
         |> assign(:broadcast, updated_broadcast)
         |> assign(:show_edit_form, false)
         |> put_flash(:info, "Broadcast updated successfully")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:broadcast_changeset, changeset)
         |> put_flash(:error, "Failed to update broadcast")}
    end
  end

  # Host Assignment
  @impl true
  def handle_event("show_host_assignment", _params, socket) do
    {:noreply, assign(socket, :show_host_assignment, true)}
  end

  @impl true
  def handle_event("hide_host_assignment", _params, socket) do
    {:noreply, assign(socket, :show_host_assignment, false)}
  end

  @impl true
  def handle_event("assign_host", %{"user_id" => user_id}, socket) do
    %{broadcast: broadcast} = socket.assigns

    case Sessions.update_session(broadcast, %{host_id: user_id}) do
      {:ok, updated_broadcast} ->
        new_host = Accounts.get_user(user_id)

        {:noreply,
         socket
         |> assign(:broadcast, updated_broadcast)
         |> assign(:host, new_host)
         |> assign(:show_host_assignment, false)
         |> put_flash(:info, "Host assigned successfully")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to assign host")}
    end
  end

  # Participant Management
  @impl true
  def handle_event("select_participant", %{"user_id" => user_id}, socket) do
    participant = Enum.find(socket.assigns.participants, &(&1.user_id == String.to_integer(user_id)))
    {:noreply, assign(socket, :selected_participant, participant)}
  end

  @impl true
  def handle_event("promote_participant", %{"user_id" => user_id}, socket) do
    case Sessions.update_participant_role(socket.assigns.broadcast.id, user_id, "moderator") do
      {:ok, _} ->
        participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
        {:noreply,
         socket
         |> assign(:participants, participants)
         |> put_flash(:info, "Participant promoted to moderator")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to promote participant")}
    end
  end

  @impl true
  def handle_event("demote_participant", %{"user_id" => user_id}, socket) do
    case Sessions.update_participant_role(socket.assigns.broadcast.id, user_id, "participant") do
      {:ok, _} ->
        participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
        {:noreply,
         socket
         |> assign(:participants, participants)
         |> put_flash(:info, "Participant demoted")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to demote participant")}
    end
  end

  @impl true
  def handle_event("remove_participant", %{"user_id" => user_id}, socket) do
    case Sessions.remove_participant(socket.assigns.broadcast.id, user_id) do
      {:ok, _} ->
        participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
        stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

        {:noreply,
         socket
         |> assign(:participants, participants)
         |> assign(:stats, stats)
         |> put_flash(:info, "Participant removed")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to remove participant")}
    end
  end

  # Chat Moderation (leveraging your existing chat system)
  @impl true
  def handle_event("mute_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    muted_users = [user_id | socket.assigns.muted_users]

    # Broadcast mute event
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:user_muted, user_id}
    )

    {:noreply,
     socket
     |> assign(:muted_users, muted_users)
     |> put_flash(:info, "User muted")}
  end

  @impl true
  def handle_event("unmute_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    muted_users = Enum.reject(socket.assigns.muted_users, &(&1 == user_id))

    # Broadcast unmute event
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:user_unmuted, user_id}
    )

    {:noreply,
     socket
     |> assign(:muted_users, muted_users)
     |> put_flash(:info, "User unmuted")}
  end

  @impl true
  def handle_event("toggle_chat", _params, socket) do
    new_state = !socket.assigns.chat_enabled

    # Broadcast chat state change
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:chat_state_changed, new_state}
    )

    {:noreply, assign(socket, :chat_enabled, new_state)}
  end

  @impl true
  def handle_event("toggle_reactions", _params, socket) do
    new_state = !socket.assigns.reactions_enabled

    # Broadcast reactions state change
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:reactions_state_changed, new_state}
    )

    {:noreply, assign(socket, :reactions_enabled, new_state)}
  end

  # Broadcast Control
  @impl true
  def handle_event("start_broadcast", _params, socket) do
    %{broadcast: broadcast} = socket.assigns

    case Sessions.start_broadcast(broadcast) do
      {:ok, updated_broadcast} ->
        # Broadcast start event to all participants
        PubSub.broadcast(
          Frestyl.PubSub,
          "broadcast:#{broadcast.id}",
          {:stream_started}
        )

        {:noreply,
         socket
         |> assign(:broadcast, updated_broadcast)
         |> put_flash(:info, "Broadcast started successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start broadcast: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("end_broadcast", _params, socket) do
    %{broadcast: broadcast} = socket.assigns

    case Sessions.end_session(broadcast) do
      {:ok, updated_broadcast} ->
        # Broadcast end event to all participants
        PubSub.broadcast(
          Frestyl.PubSub,
          "broadcast:#{broadcast.id}",
          {:stream_ended}
        )

        {:noreply,
         socket
         |> assign(:broadcast, updated_broadcast)
         |> put_flash(:info, "Broadcast ended successfully!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to end broadcast: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("delete_broadcast", _params, socket) do
    %{broadcast: broadcast, channel: channel} = socket.assigns

    case Sessions.delete_session(broadcast) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Broadcast deleted successfully")
         |> redirect(to: ~p"/channels/#{channel.slug}")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete broadcast")}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    %{channel: channel} = socket.assigns
    {:noreply, redirect(socket, to: ~p"/channels/#{channel.slug}")}
  end

  # PubSub event handlers
  @impl true
  def handle_info({:user_joined, user_id}, socket) do
    participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
    stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

    {:noreply,
     socket
     |> assign(:participants, participants)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_info({:user_left, user_id}, socket) do
    participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
    stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

    {:noreply,
     socket
     |> assign(:participants, participants)
     |> assign(:stats, stats)}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Add new chat message to list
    chat_messages = socket.assigns.chat_messages ++ [message]
    {:noreply, assign(socket, :chat_messages, chat_messages)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Remove message from chat
    chat_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == message_id))
    {:noreply, assign(socket, :chat_messages, chat_messages)}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # Helper functions
  defp can_manage_broadcast?(broadcast, user) do
    broadcast.creator_id == user.id ||
    broadcast.host_id == user.id ||
    user.role in ["admin", "channel_owner"]
  end

  defp get_available_hosts(channel) do
    # Get channel members who can be hosts
    Channels.list_channel_members(channel.id)
    |> Enum.filter(fn member ->
      member.role in ["owner", "admin", "moderator", "content_creator"]
    end)
    |> Enum.map(& &1.user)
  end

  defp get_broadcast_chat_messages(broadcast_id) do
    # Use your existing chat system to get messages
    # This might need adjustment based on your chat message structure
    Chat.list_recent_messages(broadcast_id, 50) || []
  end

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%b %d, %Y at %I:%M %p")
  end

  defp time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      true -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp time_duration(start_time, end_time) do
    diff = DateTime.diff(end_time, start_time, :second)

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m"
      diff < 86400 -> "#{div(diff, 3600)}h #{rem(div(diff, 60), 60)}m"
      true -> "#{div(diff, 86400)}d"
    end
  end
end
