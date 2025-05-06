defmodule FrestylWeb.ChannelLive.Show do
  use FrestylWeb, :live_view

  # Add this line to ensure authentication
  on_mount {FrestylWeb.UserAuth, :ensure_authenticated}

  alias Frestyl.Channels
  alias Frestyl.Chat
  alias Frestyl.Media
  alias Frestyl.Presence
  alias Frestyl.Repo
  import FrestylWeb.Navigation, only: [nav: 1]

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Fetch the channel by ID or slug
    channel = case Integer.parse(id) do
      {channel_id, _} -> Channels.get_channel!(channel_id)
      :error -> Channels.get_channel_by_slug!(id)
    end

    # Check if the user has access
    current_user = socket.assigns.current_user
    is_member = Channels.is_member?(channel.id, current_user.id)
    restricted = channel.visibility != "public" && !is_member
    can_edit = Channels.can_edit_channel?(channel, current_user)

    # Fetch members if not restricted
    members = if !restricted, do: Channels.list_channel_members(channel.id), else: []

    # Fetch chat messages if member
    chat_messages = if is_member, do: Chat.list_recent_messages(channel.id), else: []
    users = if is_member, do: Accounts.get_users_by_ids(Enum.map(chat_messages, & &1.user_id)), else: []
    users_map = Enum.reduce(users, %{}, fn user, acc -> Map.put(acc, user.id, user) end)

    # Fetch media files if member
    media_files = if is_member, do: Media.list_channel_files(channel.id), else: []

    # Setup for typing indicators
    if is_member && connected?(socket) do
      Chat.subscribe("channel:#{channel.id}")
    end

    # Media-related assigns
    socket = socket
      |> assign(:show_media_upload, false)
      |> assign(:viewing_media, nil)
      |> assign(:is_admin, is_admin?(current_user))
      |> assign(:active_tab, "content")

    {:ok,
      socket
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
      |> assign(:media_files, media_files)}
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

  defp apply_action(socket, :edit, _params) do
    if Channels.can_edit_channel?(socket.assigns.channel, socket.assigns.current_user) do
      socket
      |> assign(:page_title, "Edit #{socket.assigns.channel.name}")
      |> assign(:changeset, Channels.change_channel(socket.assigns.channel))
    else
      socket
      |> put_flash(:error, "You don't have permission to edit this channel")
      |> push_navigate(to: ~p"/channels/#{socket.assigns.channel.id}")
    end
  end

  defp reload_media(socket) do
    channel_id = socket.assigns.channel.id
    media_files = Media.list_channel_files(channel_id)
    assign(socket, :media_files, media_files)
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
         |> put_flash(:info, "Left #{channel.name}")
         |> push_navigate(to: ~p"/channels")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, error)}
    end
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
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
    # Implementation would depend on your invitation system

    # Hide the modal
    socket = assign(socket, :show_invite_modal, false)
            |> put_flash(:info, "Invitation sent to #{email}")

    {:noreply, socket}
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
