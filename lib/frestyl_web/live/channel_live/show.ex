defmodule FrestylWeb.ChannelLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Channels
  alias Frestyl.Channels.Channel
  alias Frestyl.Accounts
  alias Frestyl.Media

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

  # Get user name from users map
  def get_user_name(user_id, users_map) do
    user = Map.get(users_map, user_id, %{})
    user[:name] || user[:email] || "Unknown User"
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

  defp safe_list_channel_sessions(channel_id) do
    if function_exported?(Channels, :list_channel_sessions, 1) do
      Channels.list_channel_sessions(channel_id)
    else
      []  # Return empty list if function doesn't exist
    end
  rescue
    _ -> []  # Catch any errors and return empty list
  end

  defp safe_list_channel_broadcasts(channel_id) do
    if function_exported?(Channels, :list_channel_broadcasts, 1) do
      Channels.list_channel_broadcasts(channel_id)
    else
      []  # Return empty list if function doesn't exist
    end
  rescue
    _ -> []  # Catch any errors and return empty list
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
            sessions = safe_list_channel_sessions(channel.id)
            broadcasts = safe_list_channel_broadcasts(channel.id)
            upcoming_broadcasts = Enum.filter(broadcasts, fn b ->
              Map.get(b, :scheduled_for) && DateTime.compare(Map.get(b, :scheduled_for), DateTime.utc_now()) == :gt
            end)

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
  def handle_event("create_session", %{"session" => session_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    # Add channel_id and user_id to params
    session_params = Map.merge(session_params, %{
      "channel_id" => channel.id,
      "user_id" => current_user.id
    })

    case Channels.create_session(session_params) do
      {:ok, session} ->
        {:noreply,
        socket
        |> put_flash(:info, "Session created successfully.")
        |> redirect(to: ~p"/channels/#{channel.slug}")}

      {:error, changeset} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error creating session: #{error_message(changeset)}")
        |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("schedule_broadcast", %{"broadcast" => broadcast_params}, socket) do
    %{channel: channel, current_user: current_user} = socket.assigns

    # Add channel_id and user_id to params
    broadcast_params = Map.merge(broadcast_params, %{
      "channel_id" => channel.id,
      "user_id" => current_user.id
    })

    case Channels.create_broadcast(broadcast_params) do
      {:ok, broadcast} ->
        {:noreply,
        socket
        |> put_flash(:info, "Broadcast scheduled successfully.")
        |> redirect(to: ~p"/channels/#{channel.slug}")}

      {:error, changeset} ->
        {:noreply,
        socket
        |> put_flash(:error, "Error scheduling broadcast: #{error_message(changeset)}")
        |> assign(:changeset, changeset)}
    end
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
