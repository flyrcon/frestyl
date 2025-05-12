defmodule FrestylWeb.ChannelLive.Show do
  use FrestylWeb, :live_view

  # Add this line to ensure authentication
  on_mount {FrestylWeb.UserAuth, :ensure_authenticated}

  alias Frestyl.Channels
  alias Frestyl.Accounts
  alias Frestyl.Chat
  alias Frestyl.Media
  alias Frestyl.Presence
  alias Frestyl.Repo
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Fetch the channel by ID or slug
    channel = case Integer.parse(id) do
      {channel_id, _} -> Frestyl.Channels.get_channel!(channel_id)
      :error -> Frestyl.Channels.get_channel_by_slug!(id)
    end

    # Get current user from socket assigns
    current_user = socket.assigns.current_user

    # Check if the user has access
    is_member = Frestyl.Channels.user_member?(current_user, channel)
    restricted = channel.visibility != "public" && !is_member
    can_edit = Frestyl.Channels.can_edit_channel?(channel, current_user)

    # Check if user can view branding assets - ONLY ADMINS CAN VIEW NOW
    is_admin = is_admin?(current_user)
    can_view_branding = is_admin  # Changed to admin-only as requested

    # Fetch members if not restricted
    members = if !restricted, do: Frestyl.Channels.list_channel_members(channel.id), else: []
    blocked_users = if is_admin || can_edit, do: Channels.list_blocked_users(channel.id), else: []
    blocked_emails = if is_admin || can_edit, do: Channels.list_blocked_emails(channel.id), else: []

    # Fetch chat messages if member
    chat_messages = if is_member, do: Frestyl.Chat.list_recent_channel_messages(channel.id), else: []
    users = if is_member, do: Frestyl.Accounts.get_users_by_ids(Enum.map(chat_messages, & &1.user_id)), else: []
    users_map = Enum.reduce(users, %{}, fn user, acc -> Map.put(acc, user.id, user) end)

    # Fetch media files if member
    media_files = if is_member, do: Frestyl.Media.list_channel_files(channel.id), else: []

    # Load active media data
    active_media = if is_member do
      try do
        Frestyl.Channels.get_active_media(channel)
      rescue
        _ -> %{}
      end
    else
      %{}
    end

    # Setup for typing indicators
    if is_member && connected?(socket) do
      # Use Phoenix.PubSub directly
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
    end

    # Assign all variables to socket - keeping all your original assigns
    socket = socket
      |> assign(:show_media_upload, false)
      |> assign(:viewing_media, nil)
      |> assign(:is_admin, is_admin)
      |> assign(:active_tab, "content")
      |> assign(:active_media, active_media)
      |> assign(:page_title, channel.name)
      |> assign(:channel, channel)
      |> assign(:is_member, is_member)
      |> assign(:restricted, restricted)
      |> assign(:can_edit, can_edit)
      |> assign(:members, members)
      |> assign(:chat_messages, chat_messages)
      |> assign(:users_map, users_map)
      |> assign(:message_text, "")
      |> assign(:typing_users, [])
      |> assign(:show_invite_modal, false)
      |> assign(:media_files, media_files)
      |> assign(:show_block_modal, false)
      |> assign(:blocked_users, blocked_users)
      |> assign(:blocked_emails, blocked_emails)
      |> assign(:user_to_block, nil)
      |> assign(:blocking_member, false)
      |> assign(:active_media, active_media)
      |> assign(:can_view_branding, is_admin)  # Only admins can view branding
      |> assign(:show_options_panel, false)  # For toggling options panel
      |> assign(:show_invite_button, channel.visibility == "public" && is_member && !is_admin)  # For invite button

    {:ok, socket}
  end

  # Added this new event handler for dropdown toggle
  @impl true
  def handle_event("toggle_options", _, socket) do
    {:noreply, assign(socket, :show_options_panel, !socket.assigns.show_options_panel)}
  end

  defp is_admin?(user) do
    user.role in ["admin", "moderator", "channel_owner"]
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :show, _params) do
    # Most of the work is already done in mount
    socket
  end

  # Find this function in your channel_live/show.ex file
  defp apply_action(socket, :show, %{"id" => id}) do
    channel = Frestyl.Channels.get_channel!(id)

    messages = Frestyl.Channels.list_channel_messages(channel.id)

    socket
    |> assign(:page_title, channel.name)
    |> assign(:channel, channel)
    |> assign(:messages, messages)
    |> ensure_typing_users_is_map()
    |> assign(:draft_message, "")
  end

  # Add this helper function to your module
  defp ensure_typing_users_is_map(socket) do
    # Check if typing_users exists and is a map, otherwise set it to %{}
    case socket.assigns[:typing_users] do
      nil -> assign(socket, :typing_users, %{})
      map when is_map(map) -> socket
      _not_a_map -> assign(socket, :typing_users, %{})
    end
  end

  defp reload_media(socket) do
    channel_id = socket.assigns.channel.id
    media_files = Media.list_channel_files(channel_id)
    assign(socket, :media_files, media_files)
  end

  # Mount function - make sure this integrates with your existing mount implementation
  @impl true
  def mount(_params, _session, socket) do
    socket = assign(socket, :page_title, "Channel Form")

    # Check if we need to fetch the current user
    socket =
      if is_nil(socket.assigns[:current_user]) do
        # If the socket doesn't have current_user, we need to fetch it
        case Frestyl.Accounts.get_user_by_session_token(socket.assigns.user_token) do
          %Frestyl.Accounts.User{} = user -> assign(socket, :current_user, user)
          _ -> socket
        end
      else
        # Current user is already assigned
        socket
      end

    {:ok, socket}
  end

  # Handle typing events
  @impl true
  def handle_event("typing", %{"key" => _key, "value" => value}, socket) do
    # Store the current draft message
    socket = assign(socket, :draft_message, value)

    # Only broadcast typing if there's actual content
    if String.trim(value) != "" do
      user_id = socket.assigns.current_user.id
      channel_id = socket.assigns.channel.id

      # Broadcast that this user is typing
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "channel:#{channel_id}",
        {:user_typing, user_id, channel_id}
      )
    end

    {:noreply, socket}
  end

  # Handle message sending
  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    # Only process non-empty messages
    if String.trim(message) != "" do
      user = socket.assigns.current_user
      channel = socket.assigns.channel

      # Create the message in your database
      case Frestyl.Channels.create_message(%{
        content: message,
        user_id: user.id,
        channel_id: channel.id
      }) do
        {:ok, new_message} ->
          # Broadcast the new message to all channel members
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "channel:#{channel.id}",
            {:new_message, new_message}
          )

          # Clear the draft message and update messages list
          messages = socket.assigns.messages ++ [new_message]
          socket = socket
            |> assign(:draft_message, "")
            |> assign(:messages, messages)

          {:noreply, socket}

        {:error, changeset} ->
          # Handle errors from message creation
          error_msg = format_error(changeset)
          {:noreply, put_flash(socket, :error, "Failed to send message: #{error_msg}")}
      end
    else
      # Don't do anything for empty messages
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:user_typing, user_id, channel_id}, socket) do
    # Make sure the channel matches
    if socket.assigns[:channel] && channel_id == socket.assigns.channel.id do
      # Skip self-notifications
      if user_id != socket.assigns.current_user.id do
        # CRITICAL FIX: Convert typing_users to a map if it's not already
        # This ensures we handle the case where it might be [] instead of %{}
        typing_users = case socket.assigns[:typing_users] do
          nil -> %{}
          map when is_map(map) -> map
          _ -> %{}  # Convert any non-map (like []) to %{}
        end

        # Now proceed with the typing logic
        typing_users = Map.put(typing_users, user_id, System.os_time(:second))

        # Clean up users who haven't typed in 5 seconds
        current_time = System.os_time(:second)
        typing_users = typing_users
          |> Enum.filter(fn {_id, timestamp} ->
            current_time - timestamp < 5
          end)
          |> Map.new()

        {:noreply, assign(socket, :typing_users, typing_users)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Handle new messages
  @impl true
  def handle_info({:new_message, message}, socket) do
    # Only process messages for the current channel
    if socket.assigns[:channel] && message.channel_id == socket.assigns.channel.id do
      # Add the new message to our list
      messages = socket.assigns.messages ++ [message]

      # Remove the sender from typing users
      typing_users = Map.delete(socket.assigns[:typing_users] || %{}, message.user_id)

      # Update the socket
      socket = socket
        |> assign(:messages, messages)
        |> assign(:typing_users, typing_users)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Add a catch-all handler for other messages
  @impl true
  def handle_info(msg, socket) do
    IO.inspect(msg, label: "Unhandled message in ChannelLive.Show")
    {:noreply, socket}
  end

  # Helper function for formatting error messages
  defp format_error(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  # Helper for formatting typing indicator messages
  defp typing_message(typing_users) do
    # Get user information - adjust this to match your app's user retrieval
    typing_usernames = Enum.map(Map.keys(typing_users), fn user_id ->
      case Frestyl.Accounts.get_user(user_id) do
        %{username: username} when not is_nil(username) -> username
        %{email: email} -> email |> String.split("@") |> List.first()
        _ -> "Someone"
      end
    end)

    case length(typing_usernames) do
      1 -> "#{List.first(typing_usernames)} is typing..."
      2 -> "#{List.first(typing_usernames)} and #{List.last(typing_usernames)} are typing..."
      n when n > 2 -> "Several people are typing..."
      _ -> ""
    end
  end

  @impl true
  def handle_info({:media_changed, %{category: category, media_id: media_id}}, socket) do
    if media_id do
      # Find the media item in the existing files
      media_item = Enum.find(socket.assigns.media_files, &(&1.id == media_id))
      {:noreply, update(socket, :active_media, fn current -> Map.put(current, category, media_item) end)}
    else
      {:noreply, update(socket, :active_media, fn current -> Map.put(current, category, nil) end)}
    end
  end

  @impl true
  def handle_event("join_channel", _params, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel

    case Channels.join_channel(user, channel) do
      {:ok, _membership} ->
        members = Channels.list_channel_members(channel.id)
        chat_messages = Chat.list_recent_channel_messages(channel.id)

        # Subscribe to channel messages
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
        end

        {:noreply,
         socket
         |> assign(:is_member, true)
         |> assign(:restricted, false)
         |> assign(:members, members)
         |> assign(:chat_messages, chat_messages)
         |> put_flash(:info, "Successfully joined #{channel.name}")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  @impl true
  def handle_event("leave_channel", _params, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel
    members = socket.assigns.members

    # Get the admins from the members list
    admins = Enum.filter(members, fn member ->
      member.role in ["admin", "owner"]
    end)

    # Check if this user is an admin and if there's only one admin
    current_user_member = Enum.find(members, fn m -> m.user_id == user.id end)
    is_admin = current_user_member && current_user_member.role in ["admin", "owner"]
    is_last_admin = is_admin && length(admins) == 1

    if is_last_admin do
      {:noreply,
        socket
        |> put_flash(:error, "You cannot leave the channel as you are the only admin. Please promote another member to admin first.")
      }
    else
      case Channels.leave_channel(user, channel) do
        {:ok, _} ->
          # Unsubscribe from channel messages
          if connected?(socket) do
            Phoenix.PubSub.unsubscribe(Frestyl.PubSub, "channel:#{channel.id}")
          end

          {:noreply,
           socket
           |> assign(:is_member, false)
           |> assign(:restricted, channel.visibility != "public")
           |> assign(:members, [])
           |> assign(:chat_messages, [])
           |> assign(:media_files, [])
           |> put_flash(:info, "You have left #{channel.name}")
           |> push_navigate(to: ~p"/channels")}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, error)}
      end
    end
  end

  @impl true
  def handle_event("archive_channel", _params, socket) do
    current_user = socket.assigns.current_user
    channel = socket.assigns.channel

    case Channels.archive_channel(channel, current_user) do
      {:ok, archived_channel} ->
        {:noreply,
          socket
          |> assign(:channel, archived_channel)
          |> put_flash(:info, "Channel has been archived")
          |> push_navigate(to: ~p"/channels")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("unarchive_channel", _params, socket) do
    current_user = socket.assigns.current_user
    channel = socket.assigns.channel

    case Channels.unarchive_channel(channel, current_user) do
      {:ok, unarchived_channel} ->
        {:noreply,
          socket
          |> assign(:channel, unarchived_channel)
          |> put_flash(:info, "Channel has been restored")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("delete_channel", _params, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel

    # Check if user has permission to delete
    if Channels.can_edit_channel?(channel, user) do
      case Channels.delete_channel(channel) do
        {:ok, _} ->
          {:noreply,
          socket
          |> put_flash(:info, "Channel deleted successfully")
          |> push_navigate(to: ~p"/channels")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, reason)}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete this channel")}
    end
  end

  @impl true
  def handle_event("permanently_delete_channel", _params, socket) do
    current_user = socket.assigns.current_user
    channel = socket.assigns.channel

    case Channels.permanently_delete_channel(channel, current_user) do
      {:ok, _deleted_channel} ->
        {:noreply,
          socket
          |> put_flash(:info, "Channel has been permanently deleted")
          |> push_navigate(to: ~p"/channels")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, reason)}
    end
  end

  @impl true
  def handle_event("typing", %{"key" => _key, "value" => value}, socket) do
    # Store the current draft message value in the socket assigns
    # This allows you to keep track of what the user is currently typing
    socket = assign(socket, :draft_message, value)

    # Only broadcast typing events if there's a meaningful message being typed
    if String.trim(value) != "" do
      user_id = socket.assigns.current_user.id
      channel_id = socket.assigns.channel.id

      # Optional: Broadcast to other users that this user is typing
      # This helps implement a "User is typing..." indicator
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "channel:#{channel_id}",
        {:user_typing, user_id, channel_id}
      )

      # You could also use a debounced approach to avoid too many broadcasts
      # by setting a "typing_since" timestamp and only broadcasting every few seconds
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    # Skip empty messages
    if String.trim(message) != "" do
      user = socket.assigns.current_user
      channel = socket.assigns.channel

      # Create and save the new message
      case Frestyl.Channels.create_message(%{
        content: message,
        user_id: user.id,
        channel_id: channel.id
      }) do
        {:ok, new_message} ->
          # Broadcast the new message to all channel members
          Phoenix.PubSub.broadcast(
            Frestyl.PubSub,
            "channel:#{channel.id}",
            {:new_message, new_message}
          )

          # Clear the draft message
          socket = assign(socket, :draft_message, "")

          # Optionally refresh the messages list if you're not handling new_message in handle_info
          # socket = assign(socket, :messages, Frestyl.Channels.list_messages(channel.id))

          {:noreply, socket}

        {:error, changeset} ->
          # Handle message creation error
          {:noreply, put_flash(socket, :error, "Failed to send message: #{error_message(changeset)}")}
      end
    else
      # Empty message - just return the socket unchanged
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    # Skip if it's not for the current channel
    if message.channel_id == socket.assigns.channel.id do
      # Add the new message to the messages list
      messages = socket.assigns.messages ++ [message]

      # Remove the sender from typing users (they've completed typing)
      typing_users = Map.delete(socket.assigns.typing_users, message.user_id)

      socket = assign(socket, messages: messages, typing_users: typing_users)

      # If this is from the current user, we can clear the draft
      if message.user_id == socket.assigns.current_user.id do
        socket = assign(socket, :draft_message, "")
      end

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Helper function to format error messages
  defp error_message(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {k, v} -> "#{k}: #{Enum.join(v, ", ")}" end)
    |> Enum.join("; ")
  end

  @impl true
  def handle_info({:user_typing, user_id, channel_id}, socket) do
    # Skip if it's not for the current channel
    if channel_id == socket.assigns.channel.id do
      # Skip if it's the current user typing (to avoid self-notifications)
      if user_id != socket.assigns.current_user.id do
        # Get the current map of typing users or initialize an empty map
        typing_users = socket.assigns[:typing_users] || %{}

        # Add this user to the typing users map with the current timestamp
        typing_users = Map.put(typing_users, user_id, System.os_time(:second))

        # Clean up users who haven't typed in a while (e.g., 5 seconds)
        current_time = System.os_time(:second)
        typing_users = Enum.filter(typing_users, fn {_id, timestamp} ->
          current_time - timestamp < 5
        end) |> Map.new()

        # Update the socket with the new typing_users map
        {:noreply, assign(socket, :typing_users, typing_users)}
      else
        # It's the current user typing, no need to update anything
        {:noreply, socket}
      end
    else
      # Not for this channel, ignore
      {:noreply, socket}
    end
  end

  # Make sure to initialize typing_users in your mount function
  @impl true
  def mount(_params, _session, socket) do
    # Your existing mount code...

    socket = assign(socket, :typing_users, %{})
    socket = assign(socket, :draft_message, "")

    # Your existing code...
    {:ok, socket}
  end

  # You should also add a catch-all handle_info function to handle any other messages
  @impl true
  def handle_info(message, socket) do
    # Log unexpected messages for debugging
    IO.inspect(message, label: "Unexpected message in ChannelLive.Show")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:media_changed, %{category: category, media_id: media_id}}, socket) do
    if media_id do
      # Find the media item in the existing files
      media_item = Enum.find(socket.assigns.media_files, &(&1.id == media_id))
      {:noreply, update(socket, :active_media, fn current -> Map.put(current, category, media_item) end)}
    else
      {:noreply, update(socket, :active_media, fn current -> Map.put(current, category, nil) end)}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("show_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, true)}
  end

  @impl true
  def handle_event("hide_invite_modal", _params, socket) do
    {:noreply, assign(socket, :show_invite_modal, false)}
  end

  @impl true
  def handle_event("invite_to_channel", %{"email" => email}, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel

    case Channels.invite_to_channel(user.id, channel.id, email) do
      {:ok, _invitation} ->
        {:noreply,
         socket
         |> assign(:show_invite_modal, false)
         |> put_flash(:info, "Invitation sent to #{email}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send invitation")}
    end
  end

  # Helper function to create a channel invitation
  defp create_channel_invitation(channel, email, current_user) do
    # You'll need to implement this function based on your invitation system
    # This is a placeholder assuming you have a similar function in your app
    Channels.create_invitation(%{
      email: email,
      channel_id: channel.id,
      role_id: get_member_role_id(),
      token: generate_token(),
      expires_at: DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second), # 7 days
      status: "pending"
    })
  end

  # Helper function to get the member role ID
  defp get_member_role_id do
    # This is a placeholder - replace with your actual implementation
    # to get the ID of the "member" role
    Channels.get_role_by_name("member").id
  end

  # Helper function to get user email by ID
  defp get_user_email(user_id) when is_binary(user_id) do
    case Accounts.get_user(user_id) do
      %{email: email} -> email
      _ -> ""
    end
  end
  defp get_user_email(nil), do: ""

  # Helper function to generate a secure token
  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  @impl true
  def handle_event("change_role", %{"member_id" => member_id, "role" => role}, socket) do
    # Get the membership and update role
    membership = Repo.get!(Frestyl.Channels.ChannelMembership, member_id)

    if Channels.can_edit_channel?(socket.assigns.channel, socket.assigns.current_user) do
      case Channels.update_member_role(membership, role) do
        {:ok, _} ->
          members = Channels.list_channel_members(socket.assigns.channel.id)
          {:noreply,
           socket
           |> assign(:members, members)
           |> put_flash(:info, "Member role updated successfully")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update member role")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to change member roles")}
    end
  end

  @impl true
  def handle_event("remove_member", %{"member_id" => member_id}, socket) do
    # Get the membership and delete it
    membership = Repo.get!(Frestyl.Channels.ChannelMembership, member_id)

    if Channels.can_edit_channel?(socket.assigns.channel, socket.assigns.current_user) do
      case Repo.delete(membership) do
        {:ok, _} ->
          members = Channels.list_channel_members(socket.assigns.channel.id)
          {:noreply,
           socket
           |> assign(:members, members)
           |> put_flash(:info, "Member removed successfully")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to remove member")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to remove members")}
    end
  end

  @impl true
  def handle_event("block_member", %{"user-id" => user_id}, socket) do
    # Instead of blocking immediately, store the user ID and show the block modal
    {:noreply,
     socket
     |> assign(:user_to_block, user_id)
     |> assign(:show_block_modal, true)
     |> assign(:blocking_member, true)}  # Flag to indicate we're blocking an existing member
  end

  # Update the block_email handler to handle both email and member blocking
  @impl true
  def handle_event("block_email", %{"email" => email, "reason" => reason, "duration" => duration}, socket) do
    channel = socket.assigns.channel
    current_user = socket.assigns.current_user

    # Calculate expires_at based on duration
    expires_at = case duration do
      "permanent" -> nil
      "1d" -> DateTime.utc_now() |> DateTime.add(1 * 24 * 60 * 60, :second)
      "7d" -> DateTime.utc_now() |> DateTime.add(7 * 24 * 60 * 60, :second)
      "30d" -> DateTime.utc_now() |> DateTime.add(30 * 24 * 60 * 60, :second)
      "90d" -> DateTime.utc_now() |> DateTime.add(90 * 24 * 60 * 60, :second)
      _ -> nil # Default to permanent
    end

    if Channels.can_edit_channel?(channel, current_user) do
      # Check if we're blocking an existing member
      if socket.assigns[:blocking_member] && socket.assigns[:user_to_block] do
        user_id = socket.assigns.user_to_block
        user_to_block = Accounts.get_user!(user_id)

        case Channels.block_user(channel, user_to_block, current_user, %{
          reason: reason,
          expires_at: expires_at,
          block_level: "channel"
        }) do
          {:ok, _} ->
            # Update members and blocked users lists
            members = Channels.list_channel_members(channel.id)
            blocked_users = Channels.list_blocked_users(channel.id)

            {:noreply,
             socket
             |> assign(:members, members)
             |> assign(:blocked_users, blocked_users)
             |> assign(:user_to_block, nil)
             |> assign(:blocking_member, false)
             |> assign(:show_block_modal, false)
             |> put_flash(:info, "User blocked successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:user_to_block, nil)
             |> assign(:blocking_member, false)
             |> put_flash(:error, format_error(changeset))}
        end
      else
        # We're blocking by email (original functionality)
        case Accounts.get_user_by_email(email) do
          nil ->
            # Just block the email
            case Channels.block_email(channel, email, current_user, %{
              reason: reason,
              expires_at: expires_at,
              block_level: "channel"
            }) do
              {:ok, _} ->
                blocked_emails = Channels.list_blocked_emails(channel.id)

                {:noreply,
                 socket
                 |> assign(:blocked_emails, blocked_emails)
                 |> assign(:show_block_modal, false)
                 |> put_flash(:info, "Email #{email} blocked successfully")}

              {:error, changeset} ->
                {:noreply,
                 socket
                 |> put_flash(:error, format_error(changeset))}
            end

          user ->
            # Block the actual user
            case Channels.block_user(channel, user, current_user, %{
              reason: reason,
              expires_at: expires_at,
              block_level: "channel"
            }) do
              {:ok, _} ->
                blocked_users = Channels.list_blocked_users(channel.id)

                {:noreply,
                 socket
                 |> assign(:blocked_users, blocked_users)
                 |> assign(:show_block_modal, false)
                 |> put_flash(:info, "User #{email} blocked successfully")}

              {:error, changeset} ->
                {:noreply,
                 socket
                 |> put_flash(:error, format_error(changeset))}
            end
        end
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to block users")}
    end
  end

  @impl true
  def handle_event("unblock_user", %{"id" => blocked_id}, socket) do
    channel = socket.assigns.channel
    current_user = socket.assigns.current_user

    if Channels.can_edit_channel?(channel, current_user) do
      blocked = Repo.get!(Frestyl.Channels.BlockedUser, blocked_id)

      case Repo.delete(blocked) do
        {:ok, _} ->
          # Update blocked users list
          blocked_users = Channels.list_blocked_users(channel.id)

          {:noreply,
          socket
          |> assign(:blocked_users, blocked_users)
          |> put_flash(:info, "User unblocked successfully")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to unblock user")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to unblock users")}
    end
  end

  @impl true
  def handle_event("show_block_modal", _params, socket) do
    {:noreply, assign(socket, :show_block_modal, true)}
  end

  @impl true
  def handle_event("hide_block_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_block_modal, false)
     |> assign(:user_to_block, nil)
     |> assign(:blocking_member, false)}
  end

  @impl true
  def handle_event("set_active_media", %{"category" => category, "id" => id}, socket) do
    category_atom = String.to_existing_atom(category)

    if socket.assigns.can_edit do
      case Channels.set_active_media(socket.assigns.channel, category_atom, String.to_integer(id)) do
        {:ok, _updated_channel} ->
          media_item = Enum.find(socket.assigns.media_files, fn m ->
            m.id == String.to_integer(id)
          end)

          {:noreply,
          socket
          |> put_flash(:info, "#{String.capitalize(category)} media set")
          |> update(:active_media, fn media ->
              Map.put(media, category_atom, media_item)
            end)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not set active media")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to set active media")}
    end
  end

  @impl true
  def handle_event("clear_active_media", %{"category" => category}, socket) do
    category_atom = String.to_existing_atom(category)

    if socket.assigns.can_edit do
      case Channels.clear_active_media(socket.assigns.channel, category_atom) do
        {:ok, _updated_channel} ->
          {:noreply,
          socket
          |> put_flash(:info, "#{String.capitalize(category)} media cleared")
          |> update(:active_media, fn media ->
              Map.put(media, category_atom, nil)
            end)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Could not clear active media")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to clear active media")}
    end
  end

  @impl true
  def handle_info({:media_changed, %{category: category, media_id: media_id}}, socket) do
    if media_id do
      media_item = Enum.find(socket.assigns.media_files, fn m ->
        m.id == media_id
      end)

      {:noreply, update(socket, :active_media, fn media ->
        Map.put(media, category, media_item)
      end)}
    else
      {:noreply, update(socket, :active_media, fn media ->
        Map.put(media, category, nil)
      end)}
    end
  end

  @impl true
  def handle_info({:media_changed, %{category: category, media_id: media_id}}, socket) do
    media_item = if media_id, do: Media.get_media_file!(media_id), else: nil
    {:noreply, update_active_media(socket, category, media_item)}
  end

  # Helper function for updating active media in socket
  defp update_active_media(socket, category, media_item) do
    update(socket, :active_media, fn media ->
      Map.put(media, category, media_item)
    end)
  end

  @impl true
  def handle_event("start_broadcast", _params, socket) do
    # Placeholder for broadcast functionality
    {:noreply, socket |> put_flash(:info, "Broadcasting functionality will be implemented soon.")}
  end

  def handle_event("show_media_upload", _params, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  def handle_event("hide_media_upload", _params, socket) do
    {:noreply, assign(socket, :show_media_upload, false)}
  end

  # Add these message handlers
  def handle_info(:show_media_upload, socket) do
    {:noreply, assign(socket, :show_media_upload, true)}
  end

  def handle_info(:close_media_viewer, socket) do
    {:noreply, assign(socket, :viewing_media, nil)}
  end

  def handle_info({:view_media, file_id}, socket) do
    {:noreply, assign(socket, :viewing_media, file_id)}
  end

  def handle_info({:media_uploaded, files}, socket) do
    {:noreply, socket
      |> put_flash(:info, "#{length(files)} file(s) uploaded successfully")
      |> assign(:show_media_upload, false)
      |> reload_media()}
  end

  def handle_info({:media_deleted, _file}, socket) do
    {:noreply, socket
      |> put_flash(:info, "File deleted successfully")
      |> assign(:viewing_media, nil)
      |> reload_media()}
  end

  @impl true
  def handle_info({:channel_updated, updated_channel}, socket) do
    if updated_channel.id == socket.assigns.channel.id do
      {:noreply,
       socket
       |> assign(:channel, updated_channel)
       |> assign(:page_title, updated_channel.name)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.channel_id == socket.assigns.channel.id do
      {:noreply,
       socket
       |> update(:chat_messages, fn messages -> messages ++ [message] end)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    updated_messages = Enum.reject(socket.assigns.chat_messages, fn msg -> msg.id == message_id end)

    {:noreply,
     socket
     |> assign(:chat_messages, updated_messages)}
  end

  @impl true
  def handle_info({:presence_diff, diff}, socket) do
    # Update presence in channel
    {:noreply, socket}
  end

  defp calendar_string(datetime) do
    Calendar.strftime(datetime, "%B %d, %Y at %H:%M")
  end

    # Helper functions
  defp reload_media(socket) do
    channel_id = socket.assigns.channel.id
    media_files = Media.list_channel_files(channel_id)
    assign(socket, :media_files, media_files)
  end

  # Helper function to format relative time
  def format_relative_time(timestamp) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, timestamp, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      diff < 2592000 -> "#{div(diff, 604800)} weeks ago"
      diff < 31536000 -> "#{div(diff, 2592000)} months ago"
      true -> "#{div(diff, 31536000)} years ago"
    end
  end
end
