defmodule FrestylWeb.ChatLive.Index do
  use FrestylWeb, :live_view

  alias Frestyl.Chat
  alias Frestyl.Chat.{Conversation, Message}
  alias Frestyl.Accounts

  @impl true
  def mount(_params, _session, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)

    socket = socket
      |> assign(:conversations, conversations)
      |> assign(:selected_conversation, nil)
      |> assign(:conversation, nil)  # Add this line
      |> assign(:messages, [])
      |> assign(:changeset, Chat.change_message(%Message{}))  # Add this line

    if connected?(socket) do
      {:ok, subscribe_to_chat(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_params(%{"id" => conversation_id}, _uri, socket) do
    case Frestyl.Repo.get(Frestyl.Chat.Conversation, conversation_id) do
      nil ->
        # Handle non-existent conversation
        {:noreply,
         socket
         |> put_flash(:error, "Conversation not found")
         |> push_navigate(to: ~p"/chat")}

      conversation ->
        conversation = Chat.get_conversation!(conversation_id)
        messages = Chat.list_messages(conversation_id)

        {:noreply,
         socket
         |> assign(:conversation, conversation)
         |> assign(:messages, messages)
         |> assign(:changeset, Chat.change_message(%Message{}))
         |> stream(:messages, messages)}
    end
  end

  def handle_params(_params, _uri, socket) do
    conversations = Chat.list_user_conversations(socket.assigns.current_user.id)

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:selected_conversation, nil)
     |> assign(:messages, [])}
  end

  @impl true
  def handle_event("send_message", %{"message" => message_params}, socket) do
    user = socket.assigns.current_user
    conversation = socket.assigns.conversation

    case Chat.create_message(message_params, user, conversation) do
      {:ok, message} ->
        # Broadcast the message to all subscribers
        broadcast_message(conversation.id, message)

        {:noreply,
         socket
         |> assign(:changeset, Chat.change_message(%Message{}))
         |> stream_insert(:messages, message)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  def handle_event("create_conversation", %{"user_id" => recipient_id}, socket) do
    user = socket.assigns.current_user
    recipient = Accounts.get_user!(recipient_id)

    case Chat.find_or_create_conversation(user, recipient) do
      {:ok, conversation} ->
        messages = Chat.list_messages(conversation.id)

        {:noreply,
         socket
         |> push_navigate(to: ~p"/chat/#{conversation}")
         |> assign(:conversation, conversation)
         |> assign(:messages, messages)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Unable to create conversation")}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.conversation_id == socket.assigns.conversation.id do
      {:noreply, stream_insert(socket, :messages, message)}
    else
      {:noreply, socket}
    end
  end

  defp subscribe_to_chat(socket) do
    if conversation = socket.assigns[:conversation] do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "chat:#{conversation.id}")
    end

    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{socket.assigns.current_user.id}")
    socket
  end

  defp broadcast_message(conversation_id, message) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "chat:#{conversation_id}",
      {:new_message, message}
    )
  end
end
