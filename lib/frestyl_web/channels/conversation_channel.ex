# lib/frestyl_web/channels/conversation_channel.ex

defmodule FrestylWeb.ConversationChannel do
  @moduledoc """
  Individual conversation channel for real-time messaging within specific conversations
  """

  use Phoenix.Channel
  alias Frestyl.{Chat, Accounts}
  alias FrestylWeb.Presence

  def join("conversation:" <> conversation_id, _params, socket) do
    conversation_id = String.to_integer(conversation_id)
    user_id = socket.assigns.user_id

    case authorize_conversation_access(user_id, conversation_id) do
      {:ok, conversation} ->
        send(self(), :after_join)
        {:ok, %{conversation: conversation}, assign(socket, :conversation_id, conversation_id)}
      {:error, reason} ->
        {:error, %{reason: reason}}
    end
  end

  def handle_info(:after_join, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    conversation_id = socket.assigns.conversation_id

    # Track presence in conversation
    {:ok, _} = Presence.track(socket, socket.assigns.user_id, %{
      online_at: inspect(System.system_time(:second)),
      user_id: user.id,
      username: user.username,
      avatar_url: user.avatar_url,
      is_typing: false,
      last_activity: DateTime.utc_now()
    })

    push(socket, "presence_state", Presence.list(socket))

    # Mark conversation as read
    Chat.mark_conversation_read(conversation_id, user.id)

    # Load recent messages
    messages = Chat.get_conversation_messages(conversation_id, limit: 50)
    push(socket, "recent_messages", %{messages: messages})

    {:noreply, socket}
  end

  def handle_in("new_message", %{"content" => content}, socket) do
    user = Accounts.get_user!(socket.assigns.user_id)
    conversation_id = socket.assigns.conversation_id

    case Chat.send_message(conversation_id, user.id, content) do
      {:ok, message} ->
        # Message is already broadcasted by Chat.send_message
        {:reply, :ok, socket}

      {:error, _changeset} ->
        {:reply, {:error, %{reason: "Failed to save message"}}, socket}
    end
  end

  def handle_in("typing_start", _params, socket) do
    user_id = socket.assigns.user_id

    # Update presence with typing status
    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :is_typing, true)
    end)

    # Broadcast typing status to other participants
    broadcast_from!(socket, "user_typing", %{user_id: user_id, typing: true})

    {:noreply, socket}
  end

  def handle_in("typing_stop", _params, socket) do
    user_id = socket.assigns.user_id

    # Update presence with typing status
    Presence.update(socket, user_id, fn meta ->
      Map.put(meta, :is_typing, false)
    end)

    # Broadcast typing status to other participants
    broadcast_from!(socket, "user_typing", %{user_id: user_id, typing: false})

    {:noreply, socket}
  end

  def handle_in("mark_read", _params, socket) do
    user_id = socket.assigns.user_id
    conversation_id = socket.assigns.conversation_id

    Chat.mark_conversation_read(conversation_id, user_id)

    {:reply, :ok, socket}
  end

  def handle_in("load_older_messages", %{"offset" => offset}, socket) do
    conversation_id = socket.assigns.conversation_id

    messages = Chat.get_conversation_messages(conversation_id, limit: 25, offset: offset)

    push(socket, "older_messages", %{messages: messages, offset: offset})

    {:reply, :ok, socket}
  end

  defp authorize_conversation_access(user_id, conversation_id) do
    case Chat.get_conversation_with_participant_check(conversation_id, user_id) do
      nil -> {:error, "Conversation not found or access denied"}
      conversation -> {:ok, conversation}
    end
  end
end
