defmodule FrestylWeb.ChannelLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel
  alias Frestyl.Accounts
  alias Frestyl.Media
  alias Frestyl.Sessions
  alias Frestyl.Timezone

  # Helper functions
  def can_edit_channel?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator]
  end

  def can_edit_channel?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator"]
  end

  def can_edit_channel?(_), do: false

  def can_create_broadcast?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator, :content_creator]
  end

  def can_create_broadcast?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator", "content_creator"]
  end

  def can_create_broadcast?(_), do: false

  def can_create_session?(user_role) when is_atom(user_role) do
    user_role in [:owner, :admin, :moderator, :content_creator]
  end

  def can_create_session?(user_role) when is_binary(user_role) do
    user_role in ["owner", "admin", "moderator", "content_creator"]
  end

  def can_create_session?(_), do: false

  def error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # Compact date format (e.g., "5.11.25")
  def compact_date(nil), do: ""
  def compact_date(datetime) do
    Calendar.strftime(datetime, "%-d.%-m.%y")
  end

  def time_until(nil, _timezone), do: ""
  def time_until(datetime, user_timezone) do
    now = DateTime.utc_now()
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone || "UTC")
    diff = DateTime.diff(local_datetime, now, :second)

    cond do
      diff < 0 -> "Past event"
      diff < 60 -> "Less than a minute"
      diff < 3600 ->
        minutes = div(diff, 60)
        "#{minutes} #{pluralize("minute", minutes)}"
      diff < 86400 ->
        hours = div(diff, 3600)
        "#{hours} #{pluralize("hour", hours)}"
      diff < 2_592_000 ->
        days = div(diff, 86400)
        "#{days} #{pluralize("day", days)}"
      true ->
        months = div(diff, 2_592_000)
        "#{months} #{pluralize("month", months)}"
    end
  end

  # Helper function for proper pluralization
  defp pluralize(word, 1), do: word
  defp pluralize(word, _), do: word <> "s"

  # Add these event handlers to the same file

  @impl true
  def handle_event("toggle_upcoming_expanded", _, socket) do
    current_state = Map.get(socket.assigns, :upcoming_expanded, false)
    {:noreply, assign(socket, :upcoming_expanded, !current_state)}
  end

  @impl true
  def handle_event("toggle_broadcast_details", %{"id" => id}, socket) do
    current_id = Map.get(socket.assigns, :expanded_broadcast_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_broadcast_id, new_id)}
  end

  def format_channel_datetime(nil), do: "Not scheduled"
  def format_channel_datetime(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %I:%M %p")
  end

  def time_ago(nil), do: ""
  def time_ago(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 2_592_000 -> "#{div(diff, 86400)} days ago"
      diff < 31_536_000 -> "#{div(diff, 2_592_000)} months ago"
      true -> "#{div(diff, 31_536_000)} years ago"
    end
  end

  # Format date and time
  def format_date_time(nil), do: ""
  def format_date_time(datetime) do
    datetime
    |> Calendar.strftime("%b %d, %I:%M %p")
  end

  # Format date only
  def format_date(nil), do: ""
  def format_date(datetime) do
    datetime
    |> Calendar.strftime("%b %d, %Y")
  end

  # Format time only
  def format_time(nil), do: ""
  def format_time(datetime) do
    datetime
    |> Calendar.strftime("%I:%M %p")
  end

  # Format date with day of week (e.g., "Mon, 5.11.25")
  def format_date_with_day(nil, _timezone), do: ""
  def format_date_with_day(datetime, user_timezone) do
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone || "UTC")
    Calendar.strftime(local_datetime, "%a, %-d.%-m.%y")
  end

  # Add these new event handlers:

  @impl true
  def handle_event("toggle_happening_expanded", _, socket) do
    current_state = Map.get(socket.assigns, :happening_expanded, false)
    {:noreply, assign(socket, :happening_expanded, !current_state)}
  end

  @impl true
  def handle_event("toggle_session_details", %{"id" => id, "type" => "session"}, socket) do
    current_id = Map.get(socket.assigns, :expanded_session_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_session_id, new_id)}
  end

  @impl true
  def handle_event("toggle_session_details", %{"id" => id, "type" => "broadcast"}, socket) do
    current_id = Map.get(socket.assigns, :expanded_broadcast_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_broadcast_id, new_id)}
  end

  @impl true
  def handle_event("edit_session", %{"id" => id}, socket) do
    # Redirect to session edit page or show edit modal
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{id}/edit")}
  end

  @impl true
  def handle_event("edit_broadcast", %{"id" => id}, socket) do
    # Show broadcast edit form or redirect to edit page
    broadcast = Sessions.get_session(id)
    changeset = Sessions.change_session(broadcast, %{})

    {:noreply,
    socket
    |> assign(:editing_broadcast, broadcast)
    |> assign(:broadcast_changeset, changeset)
    |> assign(:show_broadcast_edit_form, true)}
  end

  @impl true
  def handle_event("manage_broadcast", %{"id" => id}, socket) do
    # Redirect to broadcast management page
    {:noreply, redirect(socket, to: ~p"/channels/#{socket.assigns.channel.slug}/broadcasts/#{id}/manage")}
  end

  @impl true
  def handle_event("register_for_broadcast", %{"id" => id}, socket) do
    broadcast_id = String.to_integer(id)
    current_user = socket.assigns.current_user

    case Sessions.join_session(broadcast_id, current_user.id) do
      {:ok, _} ->
        # Refresh the upcoming broadcasts to show updated registration count
        upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(socket.assigns.channel.id)

        {:noreply,
        socket
        |> put_flash(:info, "Successfully registered for the broadcast!")
        |> assign(:upcoming_broadcasts, upcoming_broadcasts)}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Could not register for broadcast: #{reason}")}
    end
  end

  def compact_date(nil, _timezone), do: ""
  def compact_date(datetime, user_timezone) do
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone || "UTC")
    Calendar.strftime(local_datetime, "%-d.%-m.%y")
  end

  # Time until event with timezone awareness
  def time_until(nil, _timezone), do: ""
  def time_until(datetime, user_timezone) do
    Timezone.time_until_with_timezone(datetime, user_timezone || "UTC")
  end

  def get_user_name(user_id, users_map) do
    case Map.get(users_map, user_id) do
      %{name: name} when not is_nil(name) -> name
      %{email: email} when not is_nil(email) -> email
      user when is_struct(user) ->
        # Handle User struct
        user.name || user.email || user.username || "Unknown User"
      %{} = user_map ->
        # Handle map
        user_map[:name] || user_map[:email] || user_map[:username] || "Unknown User"
      _ ->
        "Unknown User"
    end
  end

  # Check if there are active sessions
  def has_active_sessions?(sessions) do
    Enum.any?(sessions, fn session -> session.status == "active" end)
  end

  # Check if there are active broadcasts
  def has_active_broadcasts?(broadcasts) do
    Enum.any?(broadcasts, fn broadcast -> broadcast.status == "active" end)
  end

  # Filter active sessions
  def active_sessions(sessions) do
    Enum.filter(sessions, fn session -> session.status == "active" end)
  end

  # Filter active broadcasts
  def active_broadcasts(broadcasts) do
    Enum.filter(broadcasts, fn broadcast -> broadcast.status == "active" end)
  end

  # Get upcoming/scheduled sessions
  def upcoming_sessions(sessions) do
    Enum.filter(sessions, fn session ->
      session.status == "scheduled" ||
      (session.status == "active" && session.participants_count == 0)
    end)
  end

  def calendar_string(datetime) do
    Calendar.strftime(datetime, "%b %d, %Y")
  end

  def get_user_email(user) do
    case user do
      %{email: email} -> email
      _ -> nil
    end
  end

  # Helper function to get member role from channel
  defp get_member_role(channel, user) do
    case Channels.get_channel_membership(user, channel) do
      %{role: role} -> role
      _ -> "guest"
    end
  end

  defp list_channel_sessions(channel_id) do
    Sessions.list_active_sessions_for_channel(channel_id)
  end

  defp list_channel_broadcasts(channel_id) do
    Sessions.list_upcoming_broadcasts_for_channel(channel_id)
  end

  # Helper function to get channel members
  defp get_channel_members(channel) do
    Channels.list_channel_members(channel.id)
  end

  @impl true
  def mount(params, session, socket) do
    # Get current user from session
    current_user = session["user_token"] && Accounts.get_user_by_session_token(session["user_token"])

    # Get channel by id or slug
    channel_identifier = params["slug"] || params["id"]

    if is_nil(channel_identifier) do
      socket =
        socket
        |> put_flash(:error, "Channel not found")
        |> redirect(to: ~p"/dashboard")

      {:ok, socket}
    else
      # Try to get channel by slug first, then by id if that fails
      channel =
        if params["slug"] do
          Channels.get_channel_by_slug(params["slug"])
        else
          Channels.get_channel(params["id"])
        end

      case channel do
        nil ->
          socket =
            socket
            |> put_flash(:error, "Channel not found")
            |> redirect(to: ~p"/dashboard")

          {:ok, socket}

        channel ->
          # Check if user is restricted from this channel
          blocked = if current_user, do: Channels.is_blocked?(channel, current_user), else: false

          # Check if channel is restricted and if user has access
          is_member = if current_user, do: Channels.user_member?(current_user, channel), else: false
          is_admin = if current_user, do: Channels.can_edit_channel?(channel, current_user), else: false

          # Get member role if they are a member
          user_role = if is_member, do: get_member_role(channel, current_user), else: "guest"

          can_edit = can_edit_channel?(user_role)
          can_view_branding = can_edit
          show_invite_button = can_edit

          # Check if channel is restricted for this user
          restricted = cond do
            is_member -> false
            is_admin -> false
            blocked -> true
            channel.visibility == "public" -> false
            channel.visibility == "unlisted" -> false
            true -> true
          end

          # Set initial tabs
          active_tab = "content"
          activity_tab = "happening_now"

          # Only load additional data if user has access
          socket = if !restricted do
            # Get channel members
            members = get_channel_members(channel)

            # Get blocked users
            blocked_users = if can_edit, do: Channels.list_blocked_users(channel.id), else: []
            blocked_emails = if can_edit, do: Channels.list_blocked_emails(channel.id), else: []

            # Get active media
            active_media = Channels.get_active_media(channel) || %{}

            # Get media files
            media_files = Media.list_channel_files(channel.id) || []

            # Get chat messages - using room_id instead of channel_id and avoiding attachment_url
            chat_messages = list_channel_messages(channel.id, limit: 50) || []

            # Load sessions and broadcasts
            sessions = Sessions.list_active_sessions_for_channel(channel.id)
            broadcasts = Sessions.list_active_sessions_for_channel(channel.id)
              |> Enum.filter(&(!is_nil(&1.broadcast_type)))
            upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(channel.id)

            # Create users map for easier lookup
            users = get_users_for_messages(chat_messages)
            users_map = Enum.reduce(users, %{}, fn user, acc -> Map.put(acc, user.id, user) end)

            # Add member users to the map
            users_map = Enum.reduce(members, users_map, fn member, acc ->
              Map.put_new(acc, member.user_id, member.user)
            end)

            can_create_session = can_create_session?(user_role)
            can_create_broadcast = can_create_broadcast?(user_role)

            socket
            |> assign(:active_tab, active_tab)
            |> assign(:activity_tab, activity_tab)  # Added for the tabbed Happening Now/Upcoming
            |> assign(:members, members)
            |> assign(:users_map, users_map)
            |> assign(:blocked_users, blocked_users)
            |> assign(:blocked_emails, blocked_emails)
            |> assign(:chat_messages, chat_messages)
            |> assign(:active_media, active_media)
            |> assign(:media_files, media_files)
            |> assign(:show_options_panel, false)
            |> assign(:can_create_session, can_create_session)
            |> assign(:can_create_broadcast, can_create_broadcast)
            |> assign(:message_text, "")
            |> assign(:sessions, sessions)
            |> assign(:broadcasts, broadcasts)
            |> assign(:upcoming_broadcasts, upcoming_broadcasts)
            |> assign(:show_session_form, false)
            |> assign(:show_broadcast_form, false)
            |> assign(:session_changeset, nil)
            |> assign(:broadcast_changeset, nil)
            |> assign(:viewing_session, nil)
            |> assign(:viewing_broadcast, nil)
            |> assign(:online_members, [])  # Added for chat section
            |> assign(:upcoming_expanded, false)
            |> assign(:expanded_broadcast_id, nil)
            |> assign(:happening_expanded, false)
            |> assign(:expanded_session_id, nil)
            |> assign(:show_broadcast_edit_form, false)
            |> assign(:editing_broadcast, nil)

          else
            socket
          end

          # Common assigns for all users
          socket = socket
            |> assign(:current_user, current_user)
            |> assign(:channel, channel)
            |> assign(:restricted, restricted)
            |> assign(:is_member, is_member)
            |> assign(:is_admin, is_admin)
            |> assign(:user_role, user_role)
            |> assign(:can_edit, can_edit)
            |> assign(:can_view_branding, can_view_branding)
            |> assign(:show_invite_button, show_invite_button)
            |> assign(:show_block_modal, false)
            |> assign(:show_invite_modal, false)
            |> assign(:show_media_upload, false)
            |> assign(:viewing_media, nil)
            |> assign(:user_to_block, nil)
            |> assign(:blocking_member, false)

          # If this is a connected mount, subscribe to the channel topic
          if connected?(socket) && !restricted do
            Channels.subscribe(channel.id)
          end

          {:ok, socket}
      end
    end
  end

  @impl true
  def handle_info({:session_created, session}, socket) do
    %{sessions: sessions} = socket.assigns

    # Add session to list
    updated_sessions = [session | sessions]

    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:session_updated, session}, socket) do
    %{sessions: sessions} = socket.assigns

    # Update session in list
    updated_sessions = Enum.map(sessions, fn s ->
      if s.id == session.id, do: session, else: s
    end)

    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:session_deleted, session_id}, socket) do
    %{sessions: sessions} = socket.assigns

    # Remove session from list
    updated_sessions = Enum.reject(sessions, &(&1.id == session_id))

    {:noreply, assign(socket, :sessions, updated_sessions)}
  end

  @impl true
  def handle_info({:broadcast_created, broadcast}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    # Add broadcast to lists
    updated_broadcasts = [broadcast | broadcasts]

    # Update upcoming broadcasts if applicable
    updated_upcoming_broadcasts =
      if broadcast.scheduled_for && DateTime.compare(broadcast.scheduled_for, DateTime.utc_now()) == :gt do
        [broadcast | upcoming_broadcasts]
      else
        upcoming_broadcasts
      end

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_info({:broadcast_updated, broadcast}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    # Update broadcast in list
    updated_broadcasts = Enum.map(broadcasts, fn b ->
      if b.id == broadcast.id, do: broadcast, else: b
    end)

    # Update upcoming broadcasts
    is_upcoming = broadcast.scheduled_for && DateTime.compare(broadcast.scheduled_for, DateTime.utc_now()) == :gt
    already_in_upcoming = Enum.any?(upcoming_broadcasts, &(&1.id == broadcast.id))

    updated_upcoming_broadcasts = cond do
      is_upcoming && already_in_upcoming ->
        # Update in the list
        Enum.map(upcoming_broadcasts, fn b ->
          if b.id == broadcast.id, do: broadcast, else: b
        end)

      is_upcoming && !already_in_upcoming ->
        # Add to the list
        [broadcast | upcoming_broadcasts]

      !is_upcoming && already_in_upcoming ->
        # Remove from the list
        Enum.reject(upcoming_broadcasts, &(&1.id == broadcast.id))

      true ->
        # No change needed
        upcoming_broadcasts
    end

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_info({:broadcast_deleted, broadcast_id}, socket) do
    %{broadcasts: broadcasts, upcoming_broadcasts: upcoming_broadcasts} = socket.assigns

    # Remove broadcast from lists
    updated_broadcasts = Enum.reject(broadcasts, &(&1.id == broadcast_id))
    updated_upcoming_broadcasts = Enum.reject(upcoming_broadcasts, &(&1.id == broadcast_id))

    {:noreply,
    socket
    |> assign(:broadcasts, updated_broadcasts)
    |> assign(:upcoming_broadcasts, updated_upcoming_broadcasts)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  # Fixed helper function for chat messages
  # Fixed helper function for chat messages
# Fixed helper function for chat messages
defp list_channel_messages(channel_id, opts \\ []) do
  limit = Keyword.get(opts, :limit, 50)

  import Ecto.Query, warn: false
  alias Frestyl.Channels.Message

  # When using preload with select, we have two options:
  # Option 1: Don't use preload with a customized select
  Message
  |> where([m], m.room_id == ^channel_id)
  |> order_by([m], desc: m.inserted_at)
  |> limit(^limit)
  |> Frestyl.Repo.all()
  |> Enum.map(fn message ->
    # Create a map without the attachment_url field
    %{
      id: message.id,
      content: message.content,
      message_type: message.message_type,
      user_id: message.user_id,
      room_id: message.room_id,
      inserted_at: message.inserted_at,
      updated_at: message.updated_at,
      user: Frestyl.Repo.get(Frestyl.Accounts.User, message.user_id)
    }
  end)

  # Option 2: Use preload in a separate query
  # query = Message
  # |> where([m], m.room_id == ^channel_id)
  # |> order_by([m], desc: m.inserted_at)
  # |> limit(^limit)
  #
  # Frestyl.Repo.all(query)
  # |> Frestyl.Repo.preload(:user)
  # |> Enum.map(fn message ->
  #   # Create a map without the attachment_url field
  #   %{
  #     id: message.id,
  #     content: message.content,
  #     message_type: message.message_type,
  #     user_id: message.user_id,
  #     room_id: message.room_id,
  #     inserted_at: message.inserted_at,
  #     updated_at: message.updated_at,
  #     user: message.user
  #   }
  # end)
end

  # Helper to get users for messages
  defp get_users_for_messages(messages) do
    user_ids = Enum.map(messages, & &1.user_id)
    Accounts.get_users_by_ids(user_ids)
  end

  # Apply action functions for different routes
  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, "Channel - #{socket.assigns.channel.name}")
  end

  defp apply_action(socket, :edit, _params) do
    # Check if user can edit the channel
    if can_edit_channel?(socket.assigns.user_role) do
      socket
      |> assign(:page_title, "Edit Channel - #{socket.assigns.channel.name}")
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this channel.")
      |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}")
    end
  end

  # Fall back action for other routes
  defp apply_action(socket, _action, _params) do
    socket
    |> assign(:page_title, "Channel - #{socket.assigns.channel.name}")
  end

  # UI Navigation Event Handlers
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("switch_activity_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :activity_tab, tab)}
  end

  @impl true
  def handle_event("toggle_options", _, socket) do
    {:noreply, assign(socket, :show_options_panel, !socket.assigns.show_options_panel)}
  end

  @impl true
  def handle_event("show_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  @impl true
  def handle_event("show_block_modal", _, socket) do
    {:noreply, assign(socket, :show_block_modal, true)}
  end

  @impl true
  def handle_event("hide_block_modal", _, socket) do
    {:noreply, assign(socket, :show_block_modal, false)}
  end

  @impl true
  def handle_event("show_media_upload", _, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  @impl true
  def handle_event("hide_media_upload", _, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  # Channel Membership Event Handlers
  @impl true
  def handle_event("join_channel", _, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.join_channel(current_user, channel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have joined the channel.")
         |> redirect(to: ~p"/channels/#{channel.slug}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not join channel: #{reason}")
         |> redirect(to: ~p"/channels/#{channel.slug}")}
    end
  end

  @impl true
  def handle_event("leave_channel", _, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.leave_channel(current_user, channel) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have left the channel.")
         |> redirect(to: ~p"/dashboard")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not leave channel: #{reason}")
         |> redirect(to: ~p"/channels/#{channel.slug}")}
    end
  end

  @impl true
  def handle_event("request_access", _, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    # Implement request_access function call
    # This might need to be added to your Channels context
    # For now, we'll just show a flash message
    {:noreply,
     socket
     |> put_flash(:info, "Access request sent. You will be notified when approved.")
     |> redirect(to: ~p"/dashboard")}
  end

  # Broadcast management
  @impl true
  def handle_event("delete_session", %{"id" => id}, socket) do
    session = Sessions.get_session(id)

    if session && session.creator_id == socket.assigns.current_user.id do
      case Sessions.delete_session(session) do
        {:ok, _} ->
          updated_sessions = Enum.reject(socket.assigns.sessions, &(&1.id == String.to_integer(id)))

          {:noreply,
          socket
          |> put_flash(:info, "Session deleted successfully.")
          |> assign(:sessions, updated_sessions)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete session")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own sessions")}
    end
  end

  @impl true
  def handle_event("delete_broadcast", %{"id" => id}, socket) do
    # First get the session (broadcast)
    session = Sessions.get_session(id)

    if session && session.host_id == socket.assigns.current_user.id do
      case Sessions.delete_session(session) do
        {:ok, _} ->
          updated_broadcasts = Enum.reject(socket.assigns.broadcasts, &(&1.id == String.to_integer(id)))
          updated_upcoming = Enum.reject(socket.assigns.upcoming_broadcasts, &(&1.id == String.to_integer(id)))

          {:noreply,
          socket
          |> put_flash(:info, "Broadcast deleted successfully.")
          |> assign(:broadcasts, updated_broadcasts)
          |> assign(:upcoming_broadcasts, updated_upcoming)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not delete broadcast")}
      end
    else
      {:noreply, put_flash(socket, :error, "You can only delete your own broadcasts")}
    end
  end

  # Chat Events
  @impl true
  def handle_event("send_message", %{"message" => content}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    # Skip empty messages
    case String.trim(content) do
      "" -> {:noreply, socket}

      message_content ->
        # Create message with room_id instead of channel_id
        case Frestyl.Repo.insert(%Frestyl.Channels.Message{
          content: message_content,
          message_type: "text",
          user_id: current_user.id,
          room_id: channel.id
        }) do
          {:ok, _message} ->
            # Refresh messages after sending
            chat_messages = list_channel_messages(channel.id, limit: 50)

            {:noreply,
             socket
             |> assign(:message_text, "")
             |> assign(:chat_messages, chat_messages)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Error sending message: #{error_message(changeset)}")
             |> assign(:message_text, content)}
        end
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    %{current_user: current_user, is_admin: is_admin} = socket.assigns

    # Convert id to integer
    {message_id, _} = Integer.parse(id)

    # Get the message
    message = Frestyl.Repo.get(Frestyl.Channels.Message, message_id)

    # Only allow deletion if user owns the message or is an admin
    if message && (message.user_id == current_user.id || is_admin) do
      case Frestyl.Repo.delete(message) do
        {:ok, _} ->
          # Refresh messages after deletion
          chat_messages = list_channel_messages(socket.assigns.channel.id, limit: 50)

          {:noreply,
           socket
           |> assign(:chat_messages, chat_messages)}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Could not delete message")}
      end
    else
      {:noreply, put_flash(socket, :error, "Not authorized to delete this message")}
    end
  end

  @impl true
  def handle_event("typing", _params, socket) do
    # Could implement a typing indicator here if needed
    {:noreply, socket}
  end

  # Invitation Events
  @impl true
  def handle_event("invite_to_channel", %{"email" => email}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    case Channels.invite_to_channel(current_user.id, channel.id, email) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{email}.")
         |> assign(:show_invite_modal, false)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not send invitation: #{reason}")
         |> assign(:show_invite_modal, false)}
    end
  end

  # Member Management Events
  @impl true
  def handle_event("promote_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    # Get member's current role
    membership = Channels.get_channel_membership(%{id: user_id}, channel)

    if membership do
      # Determine new role based on current role
      new_role = case membership.role do
        "member" -> "moderator"
        "moderator" -> "member"
        role -> role
      end

      case Channels.update_member_role(membership, new_role) do
        {:ok, _} ->
          # Refresh members list
          members = get_channel_members(channel)

          {:noreply,
           socket
           |> put_flash(:info, "Member role updated.")
           |> assign(:members, members)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not update member role: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Membership not found")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    # Try to get the membership
    membership = Channels.get_channel_membership(%{id: user_id}, channel)

    if membership do
      case Frestyl.Repo.delete(membership) do
        {:ok, _} ->
          # Refresh members list
          members = get_channel_members(channel)

          {:noreply,
           socket
           |> put_flash(:info, "Member removed from channel.")
           |> assign(:members, members)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not remove member: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Membership not found")}
    end
  end

  # User Blocking Events
  @impl true
  def handle_event("block_member", %{"user-id" => user_id}, socket) do
    %{channel: channel} = socket.assigns

    # Get the user
    user = Accounts.get_user(user_id)

    if user do
      {:noreply,
       socket
       |> assign(:show_block_modal, true)
       |> assign(:blocking_member, true)
       |> assign(:user_to_block, user)}
    else
      {:noreply, put_flash(socket, :error, "User not found")}
    end
  end

  @impl true
  def handle_event("block_email", %{"email" => email, "reason" => reason, "duration" => duration}, socket) do
    %{channel: channel, current_user: current_user, blocking_member: blocking_member, user_to_block: user_to_block} = socket.assigns

    block_attrs = %{reason: reason}
    # Convert duration to an actual expiration date
    block_attrs = case duration do
      "permanent" -> block_attrs
      "1d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 1, :day))
      "7d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 7, :day))
      "30d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 30, :day))
      "90d" -> Map.put(block_attrs, :expires_at, DateTime.add(DateTime.utc_now(), 90, :day))
      _ -> block_attrs
    end

    block_result = if blocking_member && user_to_block do
      Channels.block_user(channel, user_to_block, current_user, block_attrs)
    else
      Channels.block_email(channel, email, current_user, block_attrs)
    end

    case block_result do
      {:ok, _} ->
        # Refresh the blocked users list
        blocked_users = Channels.list_blocked_users(channel.id)
        blocked_emails = Channels.list_blocked_emails(channel.id)

        {:noreply,
         socket
         |> put_flash(:info, "#{if blocking_member, do: user_to_block.email, else: email} has been blocked from the channel.")
         |> assign(:show_block_modal, false)
         |> assign(:blocking_member, false)
         |> assign(:user_to_block, nil)
         |> assign(:blocked_users, blocked_users)
         |> assign(:blocked_emails, blocked_emails)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not block user: #{reason}")
         |> assign(:show_block_modal, false)
         |> assign(:blocking_member, false)
         |> assign(:user_to_block, nil)}
    end
  end

  @impl true
  def handle_event("unblock_user", %{"id" => id}, socket) do
    %{channel: channel} = socket.assigns

    # Get the block record
    block = Frestyl.Repo.get(Frestyl.Channels.BlockedUser, id)

    if block do
      case Frestyl.Repo.delete(block) do
        {:ok, _} ->
          # Refresh the blocked users list
          blocked_users = Channels.list_blocked_users(channel.id)
          blocked_emails = Channels.list_blocked_emails(channel.id)

          {:noreply,
           socket
           |> put_flash(:info, "User has been unblocked.")
           |> assign(:blocked_users, blocked_users)
           |> assign(:blocked_emails, blocked_emails)}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Could not unblock user: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Block not found")}
    end
  end

  @impl true
  def handle_event("toggle_upcoming_expanded", _, socket) do
    current_state = Map.get(socket.assigns, :upcoming_expanded, false)
    {:noreply, assign(socket, :upcoming_expanded, !current_state)}
  end

  @impl true
  def handle_event("toggle_broadcast_details", %{"id" => id}, socket) do
    current_id = Map.get(socket.assigns, :expanded_broadcast_id)
    new_id = if current_id == String.to_integer(id), do: nil, else: String.to_integer(id)
    {:noreply, assign(socket, :expanded_broadcast_id, new_id)}
  end

  # Media Management Events
  @impl true
  def handle_event("start_broadcast", _, socket) do
    %{channel: channel} = socket.assigns

    # Redirect to the broadcast page
    {:noreply, redirect(socket, to: ~p"/channels/#{channel.slug}/broadcast")}
  end

  @impl true
  def handle_event("view_media", %{"id" => id}, socket) do
    {:noreply, assign(socket, :viewing_media, id)}
  end

  @impl true
  def handle_event("clear_active_media", %{"category" => category}, socket) do
    %{channel: channel} = socket.assigns

    # Convert category string to atom
    category_atom = String.to_existing_atom(category)

    case Channels.clear_active_media(channel, category_atom) do
      {:ok, _} ->
        # Refresh active media
        active_media = Channels.get_active_media(channel) || %{}

        {:noreply, assign(socket, :active_media, active_media)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Could not clear media: #{reason}")}
    end
  end

  @impl true
  def handle_event("browse_media_for_category", %{"category" => category}, socket) do
    # Store the category and show media browser
    {:noreply,
     socket
     |> assign(:media_category, category)
     |> assign(:show_media_browser, true)}
  end

  @impl true
  def handle_event("schedule_broadcast", %{"broadcast" => broadcast_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    IO.inspect(broadcast_params, label: "Original broadcast_params")

    # Add required fields that were missing
    complete_params = broadcast_params
      |> Map.put("channel_id", channel.id)
      |> Map.put("host_id", current_user.id)
      |> Map.put("creator_id", current_user.id)
      |> Map.put("session_type", "broadcast")
      |> Map.put("status", "scheduled")

    # Convert scheduled_for datetime from user's timezone to UTC
    complete_params = if Map.has_key?(complete_params, "scheduled_for") and
                        complete_params["scheduled_for"] != "" do
      user_timezone = Frestyl.Timezone.get_user_timezone(current_user)

      case NaiveDateTime.from_iso8601(complete_params["scheduled_for"] <> ":00") do
        {:ok, naive_dt} ->
          case Frestyl.Timezone.naive_to_utc(naive_dt, user_timezone) do
            {:ok, utc_datetime} ->
              # Truncate microseconds to match database precision
              truncated_datetime = DateTime.truncate(utc_datetime, :second)
              Map.put(complete_params, "scheduled_for", truncated_datetime)
            {:error, _} ->
              # If conversion fails, remove the field and let validation catch it
              Map.delete(complete_params, "scheduled_for")
          end
        {:error, _} ->
          # If parsing fails, remove the field
          Map.delete(complete_params, "scheduled_for")
      end
    else
      complete_params
    end

    # Convert checkbox values
    complete_params = complete_params
      |> convert_checkbox("is_public")
      |> convert_checkbox("waiting_room_enabled")

    IO.inspect(complete_params, label: "Complete broadcast params")

    case Sessions.create_session(complete_params) do
      {:ok, session} ->
        # Reload broadcasts to show the new one
        broadcasts = Sessions.list_channel_sessions(channel.id, %{session_type: "broadcast"})
        upcoming_broadcasts = Sessions.list_upcoming_broadcasts_for_channel(channel.id)

        {:noreply,
        socket
        |> assign(:broadcasts, broadcasts)
        |> assign(:upcoming_broadcasts, upcoming_broadcasts)
        |> assign(:show_broadcast_form, false)
        |> put_flash(:info, "Broadcast scheduled successfully!")}

      {:error, changeset} ->
        # Log the changeset for debugging
        IO.inspect(changeset, label: "Broadcast creation failed")

        {:noreply,
        socket
        |> put_flash(:error, "Failed to schedule broadcast: #{error_message(changeset)}")
        |> assign(:broadcast_changeset, changeset)}
    end
  end

  # Make sure you have this helper function (it should already be in your file)
  defp convert_checkbox(params, key) do
    case Map.get(params, key) do
      "on" -> Map.put(params, key, true)
      nil -> Map.put(params, key, false)
      value -> Map.put(params, key, value)
    end
  end

  def format_date_time(nil, _timezone), do: ""
  def format_date_time(datetime, user_timezone) do
    Timezone.compact_format_with_timezone(datetime, user_timezone)
  end

  def time_until(nil, _timezone), do: ""
  def time_until(datetime, user_timezone) do
    Timezone.time_until_with_timezone(datetime, user_timezone)
  end

  def compact_date(nil, _timezone), do: ""
  def compact_date(datetime, user_timezone) do
    local_datetime = Timezone.to_user_timezone(datetime, user_timezone)
    Calendar.strftime(local_datetime, "%-d.%-m.%y")
  end

  # Add this helper function to your show.ex file
  defp convert_broadcast_params(params) do
    params
    |> convert_checkbox("is_public")
    |> convert_checkbox("waiting_room_enabled")
    |> convert_datetime("scheduled_for")
  end

  defp convert_datetime(params, key) do
    case Map.get(params, key) do
      datetime_string when is_binary(datetime_string) ->
        user_timezone = Timezone.get_user_timezone(params["current_user"])

        case NaiveDateTime.from_iso8601(datetime_string <> ":00") do
          {:ok, naive_datetime} ->
            case Timezone.naive_to_utc(naive_datetime, user_timezone) do
              {:ok, utc_datetime} ->
                Map.put(params, key, utc_datetime)
              {:error, _} ->
                params
            end
          _ -> params
        end
      _ -> params
    end
  end

  @impl true
  def handle_event("create_session", %{"session" => session_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    IO.inspect(session_params, label: "Original session_params")

    # Add channel_id and creator_id to params
    converted_params = session_params
      |> Map.put("channel_id", channel.id)
      |> Map.put("creator_id", current_user.id)
      |> convert_session_params()  # We'll need to create this function

    IO.inspect(converted_params, label: "Converted session params")

    case Sessions.create_session(converted_params) do
      {:ok, session} ->
        {:noreply,
        socket
        |> put_flash(:info, "Session created successfully.")
        |> assign(:show_session_form, false)
        |> assign(:sessions, [session | socket.assigns.sessions])}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Session creation errors")

        {:noreply,
        socket
        |> put_flash(:error, "Error creating session: #{error_message(changeset)}")
        |> assign(:session_changeset, changeset)
        |> assign(:show_session_form, true)}
    end
  end

  # Add this helper function for sessions
  defp convert_session_params(params) do
    params
    |> convert_checkbox("is_public")
    # Sessions don't need datetime conversion since they start immediately
  end

  @impl true
  def handle_event("show_session_form", _, socket) do
    # Instead of using the Session struct directly
    changeset = Channels.change_session(nil)

    {:noreply,
    socket
    |> assign(:show_session_form, true)
    |> assign(:session_changeset, changeset)}
  end

  @impl true
  def handle_event("show_broadcast_form", _, socket) do
    # Instead of using the Broadcast struct directly
    changeset = Channels.change_broadcast(nil)

    {:noreply,
    socket
    |> assign(:show_broadcast_form, true)
    |> assign(:broadcast_changeset, changeset)}
  end

  @impl true
  def handle_event("hide_session_form", _, socket) do
    {:noreply, assign(socket, :show_session_form, false)}
  end

  @impl true
  def handle_event("hide_broadcast_form", _, socket) do
    {:noreply, assign(socket, :show_broadcast_form, false)}
  end

  @impl true
  def handle_event("view_session", %{"id" => id}, socket) do
    session = Channels.get_session!(id)

    {:noreply,
    socket
    |> assign(:viewing_session, session)}
  end

  @impl true
  def handle_event("view_broadcast", %{"id" => id}, socket) do
    broadcast = Channels.get_broadcast!(id)

    {:noreply,
    socket
    |> assign(:viewing_broadcast, broadcast)}
  end

  @impl true
  def handle_event("close_session_view", _, socket) do
    {:noreply, assign(socket, :viewing_session, nil)}
  end

  @impl true
  def handle_event("close_broadcast_view", _, socket) do
    {:noreply, assign(socket, :viewing_broadcast, nil)}
  end

  @impl true
  def handle_event("start_session", %{"id" => id}, socket) do
    session = Channels.get_session!(id)

    case Channels.start_session(session) do
      {:ok, _} ->
        {:noreply,
        socket
        |> put_flash(:info, "Session started successfully.")
        |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}/sessions/#{id}")}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error starting session: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_broadcast", %{"id" => id}, socket) do
    broadcast = Channels.get_broadcast!(id)

    case Channels.start_broadcast(broadcast) do
      {:ok, _} ->
        {:noreply,
        socket
        |> put_flash(:info, "Broadcast started successfully.")
        |> redirect(to: ~p"/channels/#{socket.assigns.channel.slug}/broadcasts/#{id}")}

      {:error, reason} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error starting broadcast: #{reason}")}
    end
  end

  # PubSub Handlers for Real-time Updates
  @impl true
  def handle_info({:message_created, message}, socket) do
    %{chat_messages: messages, users_map: users_map} = socket.assigns

    # Add user to the users map if not present
    users_map = if Map.has_key?(users_map, message.user_id) do
      users_map
    else
      user = Accounts.get_user(message.user_id)
      Map.put(users_map, message.user_id, user)
    end

    # Add message to list
    updated_messages = [message | messages]

    {:noreply,
     socket
     |> assign(:chat_messages, updated_messages)
     |> assign(:users_map, users_map)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    # Remove message from list
    updated_messages = Enum.reject(socket.assigns.chat_messages, &(&1.id == message_id))

    {:noreply, assign(socket, :chat_messages, updated_messages)}
  end

  @impl true
  def handle_info({:member_added, member}, socket) do
    %{members: members, users_map: users_map} = socket.assigns

    # Add user to users map if not present
    users_map = if Map.has_key?(users_map, member.user_id) do
      users_map
    else
      Map.put(users_map, member.user_id, member.user)
    end

    # Add member to list (avoid duplicates)
    updated_members = if Enum.any?(members, &(&1.id == member.id)) do
      members
    else
      [member | members]
    end

    {:noreply,
     socket
     |> assign(:members, updated_members)
     |> assign(:users_map, users_map)}
  end

  @impl true
  def handle_info({:member_removed, member_id}, socket) do
    # Remove member from list
    updated_members = Enum.reject(socket.assigns.members, &(&1.id == member_id))

    {:noreply, assign(socket, :members, updated_members)}
  end

  @impl true
  def handle_info({:media_updated}, socket) do
    # Refresh media files
    media_files = Media.list_channel_files(socket.assigns.channel.id)

    {:noreply, assign(socket, :media_files, media_files)}
  end

  @impl true
  def handle_info({:close_media_viewer}, socket) do
    {:noreply, assign(socket, :viewing_media, nil)}
  end

  @impl true
  def handle_info({:close_media_upload}, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  @impl true
  def handle_info({:active_media_updated, category, media}, socket) do
    %{active_media: active_media} = socket.assigns

    # Update active media
    updated_active_media = Map.put(active_media, category, media)

    {:noreply, assign(socket, :active_media, updated_active_media)}
  end

  @impl true
  def handle_info({:view_media, id}, socket) do
    # Set viewing media
    {:noreply, assign(socket, :viewing_media, id)}
  end

  # Final catch-all handle_info for any other messages
  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end
end
