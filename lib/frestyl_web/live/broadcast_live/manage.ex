# Create lib/frestyl_web/live/broadcast_live/manage.ex

defmodule FrestylWeb.BroadcastLive.Manage do
  use FrestylWeb, :live_view

  alias Frestyl.Sessions
  alias Frestyl.Channels
  alias Frestyl.Accounts
  alias Frestyl.Chat
  alias Phoenix.PubSub
  alias Frestyl.Timezone


  @impl true
  def mount(%{"slug" => channel_slug, "id" => broadcast_id} = params, session, socket) do
    # Get current user from session
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    if is_nil(current_user) do
      socket =
        socket
        |> put_flash(:error, "You must be logged in to manage broadcasts")
        |> redirect(to: ~p"/login")
      {:ok, socket}
    else
      try do
        # Convert string to integer if needed
        broadcast_id_int = if is_binary(broadcast_id), do: String.to_integer(broadcast_id), else: broadcast_id

        # Get broadcast by ID
        broadcast = Sessions.get_session(broadcast_id_int)

        # Get channel by slug
        channel = Channels.get_channel_by_slug(channel_slug)

        cond do
          is_nil(broadcast) ->
            socket =
              socket
              |> put_flash(:error, "Broadcast not found")
              |> redirect(to: ~p"/channels/#{channel_slug}")
            {:ok, socket}

          is_nil(channel) ->
            socket =
              socket
              |> put_flash(:error, "Channel not found")
              |> redirect(to: ~p"/dashboard")
            {:ok, socket}

          # Verify broadcast belongs to the channel
          broadcast.channel_id != channel.id ->
            socket =
              socket
              |> put_flash(:error, "Broadcast not found in this channel")
              |> redirect(to: ~p"/channels/#{channel_slug}")
            {:ok, socket}

          # Check if user can manage (using your existing helper function)
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
              PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
            end

            # Get basic data with error handling
            participants = try do
              Sessions.list_session_participants(broadcast.id) || []
            rescue
              _ -> []
            end

            stats = try do
              Sessions.get_broadcast_stats(broadcast.id)
            rescue
              _ -> %{total: 0, active: 0, waiting: 0}
            end

            # Get host information
            host = if broadcast.host_id do
              Accounts.get_user(broadcast.host_id)
            else
              Accounts.get_user(broadcast.creator_id)
            end

            # Initialize form changesets
            broadcast_changeset = Sessions.change_session(broadcast, %{})

            # Use your existing helper functions with error handling
            available_hosts = try do
              get_available_hosts(channel)
            rescue
              _ -> []
            end

            chat_messages = try do
              # Use your existing Chat context to get channel messages
              Chat.list_recent_channel_messages(channel.id, 50)
            rescue
              _ -> []
            end

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
            |> assign(:available_hosts, available_hosts)
            |> assign(:chat_messages, chat_messages)
            |> assign(:muted_users, [])
            |> assign(:blocked_users, [])
            |> assign(:chat_enabled, true)
            |> assign(:reactions_enabled, true)}
        end
      rescue
        Ecto.NoResultsError ->
          socket =
            socket
            |> put_flash(:error, "Broadcast not found")
            |> redirect(to: ~p"/channels/#{channel_slug}")
          {:ok, socket}
        ArgumentError ->
          socket =
            socket
            |> put_flash(:error, "Invalid broadcast ID")
            |> redirect(to: ~p"/channels/#{channel_slug}")
          {:ok, socket}
      end
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
    processed_params = process_datetime_params(params)

    case Sessions.update_session(broadcast, processed_params) do
      {:ok, updated_broadcast} ->
        # Determine what was changed for better feedback
        changes = get_changes_description(broadcast, updated_broadcast)

        # Notify participants if schedule changed
        if schedule_changed?(broadcast, updated_broadcast) do
          notify_schedule_change(updated_broadcast, socket.assigns.channel)
        end

        {:noreply,
        socket
        |> assign(:broadcast, updated_broadcast)
        |> assign(:show_edit_form, false)
        |> put_flash(:info, "✅ Broadcast updated successfully! #{changes}")}

      {:error, changeset} ->
        {:noreply,
        socket
        |> assign(:broadcast_changeset, changeset)
        |> put_flash(:error, "❌ Failed to update broadcast. Please check your inputs.")}
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

  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    try do
      case Chat.delete_message(message_id) do
        {:ok, _} ->
          # Remove message from local state
          chat_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == String.to_integer(message_id)))

          # Broadcast message deletion
          PubSub.broadcast(
            Frestyl.PubSub,
            "channel:#{socket.assigns.channel.id}",
            {:message_deleted, String.to_integer(message_id)}
          )

          {:noreply, assign(socket, :chat_messages, chat_messages)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete message")}
      end
    rescue
      _ ->
        {:noreply, put_flash(socket, :error, "Message deletion not available yet")}
    end
  end

  # Enhanced chat management event handlers
  @impl true
  def handle_event("clear_all_messages", _params, socket) do
    try do
      case Sessions.clear_session_messages(socket.assigns.broadcast.id) do
        {:ok, count} ->
          # Broadcast chat clear event to all participants
          PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{socket.assigns.broadcast.id}:chat",
            {:chat_cleared}
          )

          # Update local chat messages
          {:noreply,
           socket
           |> assign(:chat_messages, [])
           |> put_flash(:info, "Cleared #{count} messages")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to clear messages")}
      end
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error clearing messages: #{inspect(e)}")}
    end
  end

  # Enhanced mute/unmute with chat integration
  @impl true
  def handle_event("mute_user", %{"user_id" => user_id}, socket) do
    user_id = String.to_integer(user_id)
    muted_users = [user_id | socket.assigns.muted_users] |> Enum.uniq()

    # Broadcast mute event to chat component
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}:chat",
      {:user_muted, user_id}
    )

    # Also broadcast to management interface
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

    # Broadcast unmute event to chat component
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}:chat",
      {:user_unmuted, user_id}
    )

    # Also broadcast to management interface
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

  # Enhanced toggle handlers with chat component integration
  @impl true
  def handle_event("toggle_chat", _params, socket) do
    new_state = !socket.assigns.chat_enabled

    # Broadcast chat state change to chat component
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}:chat",
      {:chat_state_changed, new_state}
    )

    # Also broadcast to management interface
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:chat_state_changed, new_state}
    )

    message = if new_state, do: "Chat enabled", else: "Chat disabled"

    {:noreply,
     socket
     |> assign(:chat_enabled, new_state)
     |> put_flash(:info, message)}
  end

  @impl true
  def handle_event("toggle_reactions", _params, socket) do
    new_state = !socket.assigns.reactions_enabled

    # Broadcast reactions state change to chat component
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}:chat",
      {:reactions_state_changed, new_state}
    )

    # Also broadcast to management interface
    PubSub.broadcast(
      Frestyl.PubSub,
      "broadcast:#{socket.assigns.broadcast.id}",
      {:reactions_state_changed, new_state}
    )

    message = if new_state, do: "Reactions enabled", else: "Reactions disabled"

    {:noreply,
     socket
     |> assign(:reactions_enabled, new_state)
     |> put_flash(:info, message)}
  end

  # Handle real-time chat updates from the ChatComponent
  @impl true
  def handle_info({:new_message, message}, socket) do
    # Update the local chat messages for the stats
    chat_messages = socket.assigns.chat_messages ++ [message]
    {:noreply, assign(socket, :chat_messages, chat_messages)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Remove message from local state
    chat_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == message_id))
    {:noreply, assign(socket, :chat_messages, chat_messages)}
  end

  @impl true
  def handle_info({:chat_cleared}, socket) do
    {:noreply, assign(socket, :chat_messages, [])}
  end

  # Enhanced error handling for start_broadcast
  @impl true
  def handle_event("start_broadcast", _params, socket) do
    %{broadcast: broadcast, channel: channel} = socket.assigns

    try do
      case Sessions.start_broadcast(broadcast) do
        {:ok, updated_broadcast} ->
          # Broadcast start event to all participants
          PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast.id}",
            {:stream_started}
          )

          # Notify registered participants that they can now join
          PubSub.broadcast(
            Frestyl.PubSub,
            "channel:#{channel.id}",
            {:broadcast_live, broadcast.id, updated_broadcast.title}
          )

          {:noreply,
          socket
          |> assign(:broadcast, updated_broadcast)
          |> put_flash(:info, "Broadcast started successfully!")
          |> push_navigate(to: ~p"/channels/#{channel.slug}/broadcasts/#{broadcast.id}")}

        {:error, changeset} ->
          error_msg = case changeset do
            %Ecto.Changeset{} -> "Validation errors occurred"
            _ -> "Failed to start broadcast: #{inspect(changeset)}"
          end

          {:noreply, put_flash(socket, :error, error_msg)}
      end
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error starting broadcast: #{inspect(e)}")}
    end
  end

  # Enhanced error handling for end_broadcast
  @impl true
  def handle_event("end_broadcast", _params, socket) do
    %{broadcast: broadcast} = socket.assigns

    try do
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

        {:error, changeset} ->
          error_msg = case changeset do
            %Ecto.Changeset{} -> "Failed to end broadcast"
            _ -> "Error: #{inspect(changeset)}"
          end

          {:noreply, put_flash(socket, :error, error_msg)}
      end
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error ending broadcast: #{inspect(e)}")}
    end
  end

  # Enhanced error handling for update_broadcast
  @impl true
  def handle_event("update_broadcast", %{"session" => params}, socket) do
    %{broadcast: broadcast} = socket.assigns

    try do
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
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error updating broadcast: #{inspect(e)}")}
    end
  end

  # Enhanced participant management with error handling
  @impl true
  def handle_event("promote_participant", %{"user_id" => user_id}, socket) do
    try do
      case Sessions.update_participant_role(socket.assigns.broadcast.id, user_id, "moderator") do
        {:ok, _} ->
          participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
          {:noreply,
           socket
           |> assign(:participants, participants)
           |> put_flash(:info, "Participant promoted to moderator")}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Participant not found")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to promote participant")}
      end
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error promoting participant: #{inspect(e)}")}
    end
  end

  @impl true
  def handle_event("remove_participant", %{"user_id" => user_id}, socket) do
    try do
      case Sessions.remove_participant(socket.assigns.broadcast.id, user_id) do
        {:ok, _} ->
          participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
          stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

          {:noreply,
           socket
           |> assign(:participants, participants)
           |> assign(:stats, stats)
           |> put_flash(:info, "Participant removed")}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Participant not found")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove participant")}
      end
    rescue
      e ->
        {:noreply, put_flash(socket, :error, "Error removing participant: #{inspect(e)}")}
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
    %{broadcast: broadcast, channel: channel} = socket.assigns

    case Sessions.start_broadcast(broadcast) do
      {:ok, updated_broadcast} ->
        # Broadcast start event to all participants
        PubSub.broadcast(
          Frestyl.PubSub,
          "broadcast:#{broadcast.id}",
          {:stream_started}
        )

        # Notify registered participants that they can now join
        PubSub.broadcast(
          Frestyl.PubSub,
          "channel:#{channel.id}",
          {:broadcast_live, broadcast.id, updated_broadcast.title}
        )

        # Redirect to the live view
        {:noreply,
        socket
        |> put_flash(:info, "Broadcast started successfully!")
        |> redirect(to: ~p"/channels/#{channel.slug}/broadcasts/#{broadcast.id}/live")}

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

  # Add this PubSub handler to your manage.ex
  @impl true
  def handle_info({:user_registered_for_broadcast, broadcast_id, user_id}, socket) do
    if broadcast_id == socket.assigns.broadcast.id do
      # Refresh participants and stats
      participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
      stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

      {:noreply,
      socket
      |> assign(:participants, participants)
      |> assign(:stats, stats)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_unregistered_from_broadcast, broadcast_id, user_id}, socket) do
    if broadcast_id == socket.assigns.broadcast.id do
      # Refresh participants and stats
      participants = Sessions.list_session_participants(socket.assigns.broadcast.id)
      stats = Sessions.get_broadcast_stats(socket.assigns.broadcast.id)

      {:noreply,
      socket
      |> assign(:participants, participants)
      |> assign(:stats, stats)}
    else
      {:noreply, socket}
    end
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
  def handle_info({:new_channel_message, message}, socket) do
    # Add new chat message to list if it's for this channel
    if message.channel_id == socket.assigns.channel.id do
      chat_messages = socket.assigns.chat_messages ++ [message]
      {:noreply, assign(socket, :chat_messages, chat_messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Remove message from chat
    chat_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == message_id))
    {:noreply, assign(socket, :chat_messages, chat_messages)}
  end

  @impl true
  def handle_info({:chat_cleared}, socket) do
    {:noreply, assign(socket, :chat_messages, [])}
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
    try do
      # Get channel members who can be hosts
      Channels.list_channel_members(channel.id)
      |> Enum.filter(fn member ->
        member.role in ["owner", "admin", "moderator", "content_creator"]
      end)
      |> Enum.map(& &1.user)
    rescue
      _ ->
        # Fallback to channel creator if members function doesn't exist
        [channel.creator]
    end
  end

  defp format_timestamp(timestamp) do
    try do
      case timestamp do
        nil -> "Not scheduled"

        %DateTime{} = dt ->
          timezone = "America/New_York"  # Get from user if available
          Timezone.format_with_timezone(dt, timezone)

        %NaiveDateTime{} = naive_dt ->
          # Convert to DateTime first
          utc_datetime = DateTime.from_naive!(naive_dt, "Etc/UTC")
          timezone = "America/New_York"
          Timezone.format_with_timezone(utc_datetime, timezone)

        _ -> "Invalid date"
      end
    rescue
      _ -> "Invalid date"
    end
  end

  defp get_changes_description(old_broadcast, new_broadcast) do
    changes = []

    changes = if old_broadcast.title != new_broadcast.title, do: ["Title updated" | changes], else: changes
    changes = if old_broadcast.scheduled_for != new_broadcast.scheduled_for, do: ["Schedule changed" | changes], else: changes
    changes = if old_broadcast.description != new_broadcast.description, do: ["Description updated" | changes], else: changes

    case changes do
      [] -> ""
      [single] -> single
      multiple -> Enum.join(multiple, ", ")
    end
  end

  defp time_ago(datetime) do
    try do
      case datetime do
        nil -> ""

        %DateTime{} = dt ->
          diff = DateTime.diff(DateTime.utc_now(), dt, :second)
          format_time_diff(diff)

        %NaiveDateTime{} = naive_dt ->
          # Convert NaiveDateTime to DateTime in UTC
          utc_datetime = DateTime.from_naive!(naive_dt, "Etc/UTC")
          diff = DateTime.diff(DateTime.utc_now(), utc_datetime, :second)
          format_time_diff(diff)

        _ -> ""
      end
    rescue
      _ -> ""
    end
  end

  defp time_duration(start_time, end_time) do
    try do
      case {start_time, end_time} do
        {nil, _} -> "Unknown"
        {_, nil} -> "Unknown"
        {start_dt, end_dt} ->
          # Normalize both to DateTime
          start_normalized = case start_dt do
            %DateTime{} -> start_dt
            %NaiveDateTime{} -> DateTime.from_naive!(start_dt, "Etc/UTC")
            _ -> DateTime.utc_now()
          end

          end_normalized = case end_dt do
            %DateTime{} -> end_dt
            %NaiveDateTime{} -> DateTime.from_naive!(end_dt, "Etc/UTC")
            _ -> DateTime.utc_now()
          end

          diff = DateTime.diff(end_normalized, start_normalized, :second)

          cond do
            diff < 60 -> "#{diff}s"
            diff < 3600 -> "#{div(diff, 60)}m #{rem(diff, 60)}s"
            diff < 86400 -> "#{div(diff, 3600)}h #{rem(div(diff, 60), 60)}m"
            true -> "#{div(diff, 86400)}d #{rem(div(diff, 3600), 24)}h"
          end
      end
    rescue
      _ -> "Unknown"
    end
  end

  defp process_datetime_params(params) do
    case {params["scheduled_date"], params["scheduled_time"], params["timezone"]} do
      {date, time, timezone} when not is_nil(date) and not is_nil(time) and not is_nil(timezone) ->
        case combine_datetime(date, time, timezone) do
          {:ok, datetime} ->
            params
            |> Map.put("scheduled_for", datetime)
            |> Map.delete("scheduled_date")
            |> Map.delete("scheduled_time")
            |> Map.delete("timezone")

          {:error, _} ->
            params
        end

      _ ->
        params
    end
  end

  defp combine_datetime(date_str, time_str, timezone) do
    try do
      # Parse date and time
      {:ok, date} = Date.from_iso8601(date_str)
      {:ok, time} = Time.from_iso8601(time_str <> ":00")

      # Combine into naive datetime
      naive_datetime = NaiveDateTime.new!(date, time)

      # Convert to DateTime in specified timezone, then to UTC
      timezone_datetime = DateTime.from_naive!(naive_datetime, timezone)
      utc_datetime = DateTime.shift_zone!(timezone_datetime, "Etc/UTC")

      {:ok, utc_datetime}
    rescue
      _ -> {:error, :invalid_datetime}
    end
  end

  defp schedule_changed?(old_broadcast, new_broadcast) do
    old_broadcast.scheduled_for != new_broadcast.scheduled_for
  end

  defp notify_schedule_change(broadcast, channel) do
    # Broadcast to all registered participants
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel.id}",
      {:broadcast_rescheduled, broadcast.id, broadcast.title, broadcast.scheduled_for}
    )
  end

  defp format_date_for_input(nil), do: ""
  defp format_date_for_input(%DateTime{} = datetime) do
    user_timezone = "America/New_York"  # Get from current user if available
    local_datetime = DateTime.shift_zone!(datetime, user_timezone)
    Date.to_string(local_datetime)
  end
  defp format_date_for_input(%NaiveDateTime{} = naive_dt) do
    Date.to_string(naive_dt)
  end

  defp format_time_for_input(nil), do: ""
  defp format_time_for_input(%DateTime{} = datetime) do
    user_timezone = "America/New_York"  # Get from current user if available
    local_datetime = DateTime.shift_zone!(datetime, user_timezone)
    time_string = Time.to_string(local_datetime)
    String.slice(time_string, 0, 5)  # Return HH:MM format
  end
  defp format_time_for_input(%NaiveDateTime{} = naive_dt) do
    time_string = Time.to_string(naive_dt)
    String.slice(time_string, 0, 5)  # Return HH:MM format
  end

  defp get_user_timezone(user) do
    # Return user's timezone or default
    user && user.timezone || "America/New_York"
  end

  defp format_time_diff(diff) when diff < 0, do: "in the future"
  defp format_time_diff(diff) when diff < 60, do: "just now"
  defp format_time_diff(diff) when diff < 3600 do
    minutes = div(diff, 60)
    "#{minutes}m ago"
  end
  defp format_time_diff(diff) when diff < 86400 do
    hours = div(diff, 3600)
    "#{hours}h ago"
  end
  defp format_time_diff(diff) when diff < 2_592_000 do
    days = div(diff, 86400)
    "#{days}d ago"
  end
  defp format_time_diff(diff) do
    months = div(diff, 2_592_000)
    "#{months}mo ago"
  end

end
