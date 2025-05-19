defmodule FrestylWeb.ChatLive.Show do
  use FrestylWeb, :live_view
  require Logger

  alias Frestyl.Chat
  alias Frestyl.Channels
  alias Frestyl.Presence

  @impl true
  def mount(%{"channel_id" => channel_id}, _session, socket) do
    Logger.info("ChatLive.Show: Mounting with channel_id=#{channel_id}")

    socket = assign(socket,
      draft_message: "",
      typing_users: MapSet.new(),
      messages: [],
      online_users: []
    )

    # For debugging
    if !socket.assigns[:current_user] do
      # For testing, create a mock user
      mock_user = %{id: 1, email: "test@example.com"}
      socket = assign(socket, :current_user, mock_user)
    end

    # Convert channel ID to integer
    channel_id = String.to_integer(channel_id)

    # Fetch the channel
    channel = try do
      Channels.get_channel!(channel_id)
    rescue
      e ->
        Logger.error("Error fetching channel: #{inspect(e)}")
        nil
    end

    if channel do
      if connected?(socket) do
        Logger.info("ChatLive.Show: Socket connected, subscribing to channel:#{channel_id}")

        # Subscribe to channel messages
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}")

        # Subscribe to typing notifications
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel_id}:typing")

        # Subscribe to presence
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "presence:channel:#{channel_id}")

        # Track user presence if Presence module exists
        if function_exported?(Presence, :track_user, 4) do
          Presence.track_user(self(), "channel:#{channel_id}", socket.assigns.current_user.id, %{typing: false})
        end
      end

      # Get recent messages
      messages = try do
        Chat.list_recent_channel_messages(channel_id)
      rescue
        e ->
          Logger.error("Error fetching messages: #{inspect(e)}")
          []
      end

      Logger.info("ChatLive.Show: Loaded #{length(messages)} messages")

      {:ok,
       socket
       |> assign(:channel, channel)
       |> assign(:channel_id, channel_id)
       |> assign(:messages, messages)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Channel not found")
       |> push_navigate(to: "/")}
    end
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    Logger.info("ChatLive.Show: Sending message '#{message}'")

    user = socket.assigns.current_user
    channel = socket.assigns.channel

    # Prepare message params
    message_params = %{
      "content" => message,
      "message_type" => "text"
    }

    # Create the message
    case Chat.create_channel_message(message_params, user, channel) do
      {:ok, saved_message} ->
        Logger.info("ChatLive.Show: Message saved successfully")
        {:noreply, assign(socket, :draft_message, "")}

      {:error, changeset} ->
        Logger.error("ChatLive.Show: Failed to save message: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  @impl true
  def handle_event("typing", %{"typing" => typing}, socket) do
    typing_boolean = typing == "true"
    user_id = socket.assigns.current_user.id
    channel_id = socket.assigns.channel_id

    Logger.info("ChatLive.Show: User #{user_id} typing status: #{typing_boolean}")

    # Broadcast typing status
    if function_exported?(Chat, :broadcast_typing_status, 3) do
      Chat.broadcast_typing_status(channel_id, user_id, typing_boolean)
    end

    # Update presence
    if function_exported?(Presence, :update, 4) do
      Presence.update(self(), "channel:#{channel_id}",
        to_string(user_id), fn meta ->
          Map.put(meta, :typing, typing_boolean)
        end)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    Logger.info("ChatLive.Show: Received new message")

    # Add the new message to the list
    messages = socket.assigns.messages ++ [message]

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:message_deleted, message_id}, socket) do
    Logger.info("ChatLive.Show: Message #{message_id} deleted")

    # Remove the deleted message from the list
    messages = Enum.reject(socket.assigns.messages, fn msg -> msg.id == message_id end)

    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:typing_status, user_id, typing}, socket) do
    Logger.info("ChatLive.Show: User #{user_id} typing status changed to #{typing}")

    typing_users =
      if typing do
        MapSet.put(socket.assigns.typing_users, user_id)
      else
        MapSet.delete(socket.assigns.typing_users, user_id)
      end

    {:noreply, assign(socket, :typing_users, typing_users)}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff"}, socket) do
    channel_id = socket.assigns.channel_id

    # Update online users list if Presence module exists
    socket = if function_exported?(Presence, :list_users, 1) do
      online_users = Presence.list_users("channel:#{channel_id}")
      assign(socket, :online_users, online_users)
    else
      socket
    end

    # Update typing users if Presence module exists
    socket = if function_exported?(Presence, :list_typing_users, 1) do
      typing_users = Presence.list_typing_users("channel:#{channel_id}")
      assign(socket, :typing_users, MapSet.new(typing_users))
    else
      socket
    end

    {:noreply, socket}
  end
end
