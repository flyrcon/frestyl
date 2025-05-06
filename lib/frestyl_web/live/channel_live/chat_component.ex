defmodule FrestylWeb.ChannelLive.ChatComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Chat
  alias Frestyl.Chat.Message
  alias Frestyl.Channels
  alias Frestyl.Presence
  alias Frestyl.Repo

  @impl true
  def update(%{channel: channel, current_user: user} = assigns, socket) do
    # Check if user has permission to send messages
    has_send_permission = Channels.can_send_messages?(user, channel)

    # Get recent messages
    messages = Chat.list_recent_channel_messages(channel.id)

    # Create a map of users for quick lookups
    users_map = if assigns[:users_map] do
      assigns[:users_map]
    else
      create_users_map(messages)
    end

    # Subscribe to channel messages and presence
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}:typing")

      # Track user presence using Presence module
      Presence.track(self(), "channel:#{channel.id}", to_string(user.id), %{
        online_at: inspect(System.system_time(:second)),
        typing: false
      })
    end

    # Get initial online users
    online_users = Presence.list_users("channel:#{channel.id}")

    # Get initial typing users
    typing_users = Presence.list_typing_users("channel:#{channel.id}")

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:channel, channel)
     |> assign(:current_user, user)
     |> assign(:has_send_permission, has_send_permission)
     |> assign(:messages, messages)
     |> assign(:users_map, users_map)
     |> assign(:changeset, Message.changeset(%Message{}, %{}))
     |> assign(:typing_users, MapSet.new(typing_users))
     |> assign(:online_users, online_users)
     |> assign(:typing_timer, nil)
     |> assign(:message_text, "")
     |> assign(:loading_messages, false)
     |> assign(:has_more, length(messages) >= 50)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_params}, socket) do
    user = socket.assigns.current_user
    channel = socket.assigns.channel

    # Extract content from params
    content = message_params["content"] || ""

    if String.trim(content) != "" do
      case Chat.create_channel_message(%{
        content: content,
        channel_id: channel.id,
        user_id: user.id,
        message_type: "text"
      }, user, channel) do
        {:ok, message} ->
          # Stop typing indicator when sending
          broadcast_typing(socket, false)

          {:noreply,
           socket
           |> assign(:changeset, Message.changeset(%Message{}, %{}))
           |> assign(:message_text, "")
           |> push_event("chat-message-sent", %{})}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, :changeset, changeset)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("typing", %{"typing" => typing}, socket) do
    typing_boolean = typing == "true"
    broadcast_typing(socket, typing_boolean)

    # Update user's typing status in presence
    Presence.update(self(), "channel:#{socket.assigns.channel.id}",
      to_string(socket.assigns.current_user.id), fn meta ->
      Map.put(meta, :typing, typing_boolean)
    end)

    # Reset typing timer
    if socket.assigns.typing_timer do
      Process.cancel_timer(socket.assigns.typing_timer)
    end

    # Set new timer to stop typing indicator after 3 seconds
    timer = if typing_boolean do
      Process.send_after(self(), {:stop_typing, socket.assigns.current_user.id}, 3000)
    else
      nil
    end

    {:noreply, assign(socket, :typing_timer, timer)}
  end

  @impl true
  def handle_event("validate", %{"message" => message_params}, socket) do
    changeset = Message.changeset(%Message{}, message_params)
    {:noreply,
     socket
     |> assign(:changeset, changeset)
     |> assign(:message_text, message_params["content"] || "")}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    if socket.assigns.has_more && !socket.assigns.loading_messages do
      socket = assign(socket, loading_messages: true)

      # Get the oldest message ID we have
      oldest_id = socket.assigns.messages
        |> Enum.sort_by(& &1.id)
        |> List.first()
        |> Map.get(:id)

      # Load messages before this one
      case Chat.list_channel_messages_before(socket.assigns.channel.id, oldest_id, 50) do
        messages when is_list(messages) ->
          has_more = length(messages) >= 50
          all_messages = messages ++ socket.assigns.messages

          # Update users map with any new users
          users_map = update_users_map(socket.assigns.users_map, messages)

          socket = socket
            |> assign(messages: all_messages)
            |> assign(users_map: users_map)
            |> assign(has_more: has_more)
            |> assign(loading_messages: false)

          {:noreply, socket}

        _ ->
          socket = socket
            |> assign(has_more: false)
            |> assign(loading_messages: false)

          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("delete_message", %{"id" => id}, socket) do
    message_id = String.to_integer(id)
    user = socket.assigns.current_user

    case Chat.delete_message(message_id, user) do
      {:ok, _} ->
        # Message is deleted on the server, we'll get a broadcast
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, reason)}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.channel_id == socket.assigns.channel.id do
      # Update users map if needed
      users_map =
        if Map.has_key?(socket.assigns.users_map, to_string(message.user_id)) do
          socket.assigns.users_map
        else
          Map.put(socket.assigns.users_map, to_string(message.user_id), message.user)
        end

      {:noreply,
       socket
       |> assign(:messages, socket.assigns.messages ++ [message])
       |> assign(:users_map, users_map)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    updated_messages = Enum.reject(socket.assigns.messages, fn msg -> msg.id == message_id end)

    {:noreply,
     socket
     |> assign(:messages, updated_messages)}
  end

  @impl true
  def handle_info({:typing_status, user_id, typing}, socket) do
    typing_users =
      if typing do
        MapSet.put(socket.assigns.typing_users, user_id)
      else
        MapSet.delete(socket.assigns.typing_users, user_id)
      end

    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_info({:stop_typing, user_id}, socket) do
    if socket.assigns.current_user.id == user_id do
      broadcast_typing(socket, false)

      # Update presence to stop typing
      Presence.update(self(), "channel:#{socket.assigns.channel.id}",
        to_string(socket.assigns.current_user.id), fn meta ->
        Map.put(meta, :typing, false)
      end)
    end
    {:noreply, socket}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: _diff}, socket) do
    # Update online users list
    online_users = Presence.list_users("channel:#{socket.assigns.channel.id}")
    typing_users = Presence.list_typing_users("channel:#{socket.assigns.channel.id}")

    {:noreply,
     socket
     |> assign(:online_users, online_users)
     |> assign(:typing_users, MapSet.new(typing_users))}
  end

  defp broadcast_typing(socket, typing) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{socket.assigns.channel.id}:typing",
      {:typing_status, socket.assigns.current_user.id, typing}
    )
  end

  # Helper function to create a map of users from messages
  defp create_users_map(messages) do
    messages
    |> Enum.map(fn message -> message.user end)
    |> Enum.uniq_by(fn user -> user.id end)
    |> Enum.reduce(%{}, fn user, acc -> Map.put(acc, to_string(user.id), user) end)
  end

  # Helper function to update the users map with new users
  defp update_users_map(users_map, messages) do
    messages
    |> Enum.reduce(users_map, fn message, acc ->
      if Map.has_key?(acc, to_string(message.user_id)) do
        acc
      else
        Map.put(acc, to_string(message.user_id), message.user)
      end
    end)
  end

  # Helper function to get user info for a message
  def get_message_user(message, users_map) do
    Map.get(users_map, to_string(message.user_id))
  end

  # Helper function to format message time
  def format_message_time(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(datetime, "%b %d at %H:%M")
    end
  end

  # Helper function for typing indicator text
  defp typing_indicator_text(typing_users, current_user, users_map) do
    # Remove current user from typing list
    other_typing =
      typing_users
      |> MapSet.to_list()
      |> Enum.reject(fn id -> id == current_user.id end)

    case length(other_typing) do
      0 -> ""
      1 -> "Someone is typing..."
      n when n <= 3 ->
        typing_names = other_typing
          |> Enum.map(fn id -> get_user_name(Map.get(users_map, to_string(id))) end)
          |> Enum.join(", ")
        "#{typing_names} are typing..."
      _ -> "Several people are typing..."
    end
  end

  defp get_user_name(nil), do: "Someone"
  defp get_user_name(user), do: user.name || user.email

end
