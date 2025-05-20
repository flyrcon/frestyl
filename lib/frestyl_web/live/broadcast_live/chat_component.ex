defmodule FrestylWeb.BroadcastLive.ChatComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Sessions
  alias Phoenix.PubSub

  def mount(socket) do
    socket = assign(socket,
      messages: [],
      message_input: "",
      reactions_enabled: true,
      is_typing: false,
      typing_users: []
    )

    {:ok, socket}
  end

  def update(%{broadcast_id: broadcast_id} = assigns, socket) do
    # Subscribe to chat events if not already subscribed
    if socket.assigns[:broadcast_id] != broadcast_id do
      if socket.assigns[:broadcast_id] do
        PubSub.unsubscribe(Frestyl.PubSub, "broadcast:#{socket.assigns.broadcast_id}:chat")
      end

      PubSub.subscribe(Frestyl.PubSub, "broadcast:#{broadcast_id}:chat")

      # Load existing messages
      messages = Sessions.list_recent_messages(broadcast_id, 50)
      socket = assign(socket, :messages, messages)
    end

    {:ok, assign(socket, assigns)}
  end

  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    user = socket.assigns.current_user
    broadcast_id = socket.assigns.broadcast_id

    # Check if user is muted
    if user.id in socket.assigns.muted_users do
      {:noreply, socket}
    else
      # Create the message
      message_params = %{
        content: message,
        user_id: user.id,
        session_id: broadcast_id
      }

      case Sessions.create_message(message_params) do
        {:ok, new_message} ->
          # Broadcast the message to all users
          message_data = %{
            id: new_message.id,
            content: new_message.content,
            user_id: new_message.user_id,
            username: user.username,
            avatar_url: user.avatar_url,
            inserted_at: new_message.inserted_at
          }

          PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}:chat",
            {:new_message, message_data}
          )

          # Clear input and stop typing indicator
          PubSub.broadcast(
            Frestyl.PubSub,
            "broadcast:#{broadcast_id}:chat",
            {:user_stopped_typing, user.id}
          )

          {:noreply, assign(socket, :message_input, "")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to send message")}
      end
    end
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  def handle_event("update_message_input", %{"value" => value}, socket) do
    user = socket.assigns.current_user
    broadcast_id = socket.assigns.broadcast_id

    # Handle typing indicators
    if value != "" and socket.assigns.message_input == "" do
      # User started typing
      PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{broadcast_id}:chat",
        {:user_typing, user.id, user.username}
      )
    end

    if value == "" and socket.assigns.message_input != "" do
      # User stopped typing
      PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{broadcast_id}:chat",
        {:user_stopped_typing, user.id}
      )
    end

    {:noreply, assign(socket, :message_input, value)}
  end

  def handle_event("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    if socket.assigns.reactions_enabled do
      user = socket.assigns.current_user
      broadcast_id = socket.assigns.broadcast_id

      # Broadcast the reaction
      PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{broadcast_id}:chat",
        {:message_reaction, message_id, emoji, user.id, user.username}
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("delete_message", %{"message_id" => message_id}, socket) do
    # Only allow hosts/moderators to delete messages
    if socket.assigns.is_host do
      broadcast_id = socket.assigns.broadcast_id

      PubSub.broadcast(
        Frestyl.PubSub,
        "broadcast:#{broadcast_id}:chat",
        {:message_deleted, message_id}
      )

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:new_message, message}, socket) do
    messages = socket.assigns.messages ++ [message]

    # Keep only the last 100 messages in memory
    messages = if length(messages) > 100 do
      Enum.take(messages, -100)
    else
      messages
    end

    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:user_typing, user_id, username}, socket) do
    if user_id != socket.assigns.current_user.id do
      typing_users = [username | socket.assigns.typing_users] |> Enum.uniq()
      {:noreply, assign(socket, :typing_users, typing_users)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:user_stopped_typing, user_id}, socket) do
    # Remove user from typing list
    {:noreply, assign(socket, :typing_users, [])}
  end

  def handle_info({:message_reaction, message_id, emoji, user_id, username}, socket) do
    # Handle message reactions (implementation depends on your message storage)
    {:noreply, socket}
  end

  def handle_info({:message_deleted, message_id}, socket) do
    messages = Enum.reject(socket.assigns.messages, &(&1.id == message_id))
    {:noreply, assign(socket, :messages, messages)}
  end

  def handle_info({:chat_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :chat_enabled, enabled)}
  end

  def handle_info({:reactions_state_changed, enabled}, socket) do
    {:noreply, assign(socket, :reactions_enabled, enabled)}
  end

  defp format_timestamp(timestamp) do
    Calendar.strftime(timestamp, "%I:%M %p")
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full">
      <!-- Chat messages -->
      <div id="chat-messages" class="flex-1 overflow-y-auto p-4 space-y-3" phx-update="append">
        <%= if Map.get(assigns, :chat_enabled, true) do %>
          <%= if @messages == [] do %>
            <div class="text-center text-gray-500 py-8">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto mb-2 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <p class="text-sm">No messages yet</p>
              <p class="text-xs text-gray-600 mt-1">Be the first to say something!</p>
            </div>
          <% end %>

          <%= for message <- @messages do %>
            <div id={"message-#{message.id}"} class="group">
              <div class="flex space-x-3">
                <div class="flex-shrink-0">
                  <%= if Map.get(message, :avatar_url) do %>
                    <img src={message.avatar_url} class="h-8 w-8 rounded-full" alt={message.username} />
                  <% else %>
                    <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                      <%= String.first(message.username || "?") %>
                    </div>
                  <% end %>
                </div>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center space-x-2">
                    <p class="text-sm font-medium text-white"><%= message.username %></p>
                    <p class="text-xs text-gray-400"><%= format_timestamp(message.inserted_at) %></p>

                    <%= if Map.get(assigns, :is_host, false) do %>
                      <button
                        phx-click="delete_message"
                        phx-value-message_id={message.id}
                        phx-target={@myself}
                        class="opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-300 text-xs"
                        title="Delete message"
                      >
                        Delete
                      </button>
                    <% end %>
                  </div>

                  <div class="mt-1">
                    <p class="text-sm text-gray-300 whitespace-pre-wrap"><%= message.content %></p>

                    <%= if @reactions_enabled do %>
                      <div class="mt-2 flex space-x-1">
                        <%= for emoji <- ["👍", "❤️", "😂", "🎉"] do %>
                          <button
                            phx-click="add_reaction"
                            phx-value-message_id={message.id}
                            phx-value-emoji={emoji}
                            phx-target={@myself}
                            class="text-xs bg-gray-800 hover:bg-gray-700 rounded-full px-2 py-1 transition-colors"
                            title={"React with #{emoji}"}
                          >
                            <%= emoji %>
                          </button>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Typing indicators -->
          <%= if @typing_users != [] do %>
            <div class="text-xs text-gray-500 italic">
              <%= Enum.join(@typing_users, ", ") %> <%= if length(@typing_users) == 1, do: "is", else: "are" %> typing...
            </div>
          <% end %>
        <% else %>
          <div class="flex-1 flex items-center justify-center">
            <div class="text-center">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 mx-auto text-gray-600 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M18.364 18.364A9 9 0 005.636 5.636m12.728 12.728A9 9 0 715.636 5.636m12.728 12.728L5.636 5.636" />
              </svg>
              <p class="text-gray-400">Chat is currently disabled</p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Chat input -->
      <%= if Map.get(assigns, :chat_enabled, true) do %>
        <div class="border-t border-gray-800 p-4">
          <form phx-submit="send_message" phx-target={@myself} class="flex">
            <input
              type="text"
              name="message"
              value={@message_input}
              phx-keyup="update_message_input"
              phx-target={@myself}
              placeholder={if @current_user.id in Map.get(assigns, :muted_users, []), do: "You are muted", else: "Type a message..."}
              class="block w-full bg-gray-800 border-gray-700 rounded-l-md text-white text-sm focus:border-indigo-500 focus:ring-indigo-500 disabled:opacity-50"
              maxlength="500"
              disabled={@current_user.id in Map.get(assigns, :muted_users, [])}
            />
            <button
              type="submit"
              class="bg-indigo-600 hover:bg-indigo-500 text-white rounded-r-md px-4 disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={@current_user.id in Map.get(assigns, :muted_users, []) or @message_input == ""}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                <path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" />
              </svg>
            </button>
          </form>

          <%= if @current_user.id in Map.get(assigns, :muted_users, []) do %>
            <div class="mt-2 text-xs text-center text-red-400">
              You have been muted by the host
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
