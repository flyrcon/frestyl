defmodule FrestylWeb.Studio.MobileChatComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Chat
  alias Frestyl.Presence

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      message_input: "",
      show_emoji_picker: false,
      typing_users: MapSet.new(),
      scroll_to_bottom: false,
      show_chat: false,
      unread_count: 0,
      last_seen_message_id: nil
    )}
  end

  @impl true
  def update(%{session_id: session_id, current_user: current_user} = assigns, socket) do
    if connected?(socket) do
      # Subscribe to chat updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:chat")
    end

    # Set last seen message if we have messages
    last_seen_id = case assigns.chat_messages do
      [] -> nil
      messages -> List.last(messages).id
    end

    {:ok, assign(socket, Map.put(assigns, :last_seen_message_id, last_seen_id))}
  end

  @impl true
  def handle_event("toggle_chat", _, socket) do
    show_chat = !socket.assigns.show_chat

    # Reset unread count when opening chat
    unread_count = if show_chat, do: 0, else: socket.assigns.unread_count

    # Update last seen message when opening
    last_seen_id = if show_chat and length(socket.assigns.chat_messages) > 0 do
      List.last(socket.assigns.chat_messages).id
    else
      socket.assigns.last_seen_message_id
    end

    {:noreply,
      socket
      |> assign(show_chat: show_chat, unread_count: unread_count, last_seen_message_id: last_seen_id)
      |> push_event("mobile_chat_toggled", %{open: show_chat})}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    session_id = socket.assigns.session_id
    user = socket.assigns.current_user

    # Create message using existing chat system
    message_params = %{
      "content" => message,
      "message_type" => "text",
      "session_id" => session_id
    }

    case Chat.create_session_message(message_params, user) do
      {:ok, new_message} ->
        # Clear input, stop typing, and trigger haptic feedback
        send(self(), {:chat_stop_typing, user.id})

        {:noreply,
          socket
          |> assign(message_input: "", scroll_to_bottom: true)
          |> push_event("mobile_haptic_feedback", %{type: "light"})
          |> push_event("clear_message_input", %{})}

      {:error, _changeset} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to send message")
          |> push_event("mobile_haptic_feedback", %{type: "error"})}
    end
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("typing_start", _, socket) do
    user_id = socket.assigns.current_user.id
    send(self(), {:chat_start_typing, user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("typing_stop", _, socket) do
    user_id = socket.assigns.current_user.id
    send(self(), {:chat_stop_typing, user_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    # Send typing status based on whether user is typing
    user_id = socket.assigns.current_user.id
    prev_value = socket.assigns.message_input

    cond do
      value != "" and prev_value == "" ->
        send(self(), {:chat_start_typing, user_id})

      value == "" and prev_value != "" ->
        send(self(), {:chat_stop_typing, user_id})

      true ->
        :ok
    end

    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("toggle_emoji_picker", _, socket) do
    {:noreply,
      socket
      |> assign(show_emoji_picker: !socket.assigns.show_emoji_picker)
      |> push_event("mobile_haptic_feedback", %{type: "light"})}
  end

  @impl true
  def handle_event("add_emoji", %{"emoji" => emoji}, socket) do
    current_input = socket.assigns.message_input
    new_input = current_input <> emoji

    {:noreply,
      socket
      |> assign(message_input: new_input, show_emoji_picker: false)
      |> push_event("mobile_haptic_feedback", %{type: "light"})
      |> push_event("update_message_input_value", %{value: new_input})}
  end

  @impl true
  def handle_event("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_user.id

    case Chat.add_reaction(message_id, user_id, emoji) do
      {:ok, _reaction} ->
        {:noreply, push_event(socket, "mobile_haptic_feedback", %{type: "light"})}
      {:error, _} ->
        {:noreply,
          socket
          |> put_flash(:error, "Failed to add reaction")
          |> push_event("mobile_haptic_feedback", %{type: "error"})}
    end
  end

  @impl true
  def handle_event("swipe_close", _, socket) do
    {:noreply,
      socket
      |> assign(show_chat: false)
      |> push_event("mobile_haptic_feedback", %{type: "medium"})}
  end

  @impl true
  def handle_event("long_press_message", %{"message_id" => message_id}, socket) do
    # Show message actions on long press
    {:noreply,
      socket
      |> push_event("mobile_haptic_feedback", %{type: "heavy"})
      |> push_event("show_message_actions", %{message_id: message_id})}
  end

  # Handle incoming messages to update unread count
  @impl true
  def handle_info({:new_message, message}, socket) do
    # Only increment unread if chat is closed and message is not from current user
    unread_count = if !socket.assigns.show_chat and message.user_id != socket.assigns.current_user.id do
      socket.assigns.unread_count + 1
    else
      socket.assigns.unread_count
    end

    {:noreply, assign(socket, unread_count: unread_count)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
        id="mobile-chat-container"
        class="mobile-chat-container relative"
        phx-hook="MobileChatHook"
    >
      <!-- Chat Toggle Button (Floating Action Button) -->
      <button
        phx-click="toggle_chat"
        phx-target={@myself}
        class={[
          "fixed bottom-6 right-6 z-40 w-14 h-14 rounded-full shadow-2xl transition-all duration-300 transform",
          @show_chat && "bg-gradient-to-r from-red-500 to-red-600 scale-110 rotate-45",
          !@show_chat && "bg-gradient-to-r from-purple-500 to-pink-600 hover:scale-110"
        ]}
        style="box-shadow: 0 8px 32px rgba(168, 85, 247, 0.4);"
      >
        <!-- Unread Badge -->
        <%= if @unread_count > 0 and !@show_chat do %>
          <div class="absolute -top-1 -right-1 bg-red-500 text-white text-xs font-bold rounded-full min-w-[1.25rem] h-5 flex items-center justify-center px-1 shadow-lg">
            <%= if @unread_count > 99, do: "99+", else: @unread_count %>
          </div>
        <% end %>

        <!-- Icon -->
        <div class="text-white">
          <%= if @show_chat do %>
            <svg class="h-6 w-6 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          <% else %>
            <svg class="h-6 w-6 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          <% end %>
        </div>
      </button>

      <!-- Mobile Chat Panel -->
      <div class={[
        "fixed inset-0 z-30 bg-black/95 backdrop-blur-xl transition-all duration-300",
        @show_chat && "opacity-100 pointer-events-auto",
        !@show_chat && "opacity-0 pointer-events-none"
      ]}>
        <!-- Swipe Handle -->
        <div class="absolute top-4 left-1/2 transform -translate-x-1/2 w-12 h-1 bg-white/30 rounded-full"></div>

        <!-- Chat Header -->
        <div class="flex items-center justify-between p-4 pt-12 border-b border-white/10 bg-black/50">
          <div class="flex items-center gap-3">
            <div class="p-2 bg-gradient-to-r from-purple-500 to-pink-600 rounded-xl">
              <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
            </div>
            <div>
              <h3 class="text-white font-bold text-lg">Session Chat</h3>
              <p class="text-white/60 text-sm"><%= length(@chat_messages) %> messages</p>
            </div>
          </div>

          <button
            phx-click="toggle_chat"
            phx-target={@myself}
            class="p-2 text-white/70 hover:text-white rounded-lg transition-colors"
          >
            <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Messages Area -->
        <div
          id="mobile-chat-messages"
          class="flex-1 overflow-y-auto p-4 pb-32 space-y-4 scroll-smooth max-h-[calc(100vh-200px)]"
          phx-hook="MobileChatScroll"
          phx-update={if @scroll_to_bottom, do: "append", else: "ignore"}
        >
          <%= if length(@chat_messages) == 0 do %>
            <div class="text-center text-white/50 py-12">
              <svg class="h-16 w-16 mx-auto mb-4 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
              <p class="text-lg">No messages yet</p>
              <p class="text-sm text-white/30 mt-2">Start the conversation!</p>
            </div>
          <% end %>

          <%= for message <- @chat_messages do %>
            <div
              id={"message-#{message.id}"}
              class={[
                "flex gap-3 touch-manipulation",
                message.user_id == @current_user.id && "flex-row-reverse"
              ]}
              phx-hook="LongPressMessage"
              data-message-id={message.id}
            >
              <!-- Avatar -->
              <div class="flex-shrink-0">
                <%= if message.user_id != @current_user.id do %>
                  <%= if Map.get(message, :avatar_url) do %>
                    <img src={message.avatar_url} class="h-10 w-10 rounded-full" alt={message.username} />
                  <% else %>
                    <div class="h-10 w-10 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white font-bold">
                      <%= String.at(message.username || "U", 0) %>
                    </div>
                  <% end %>
                <% else %>
                  <div class="h-10 w-10 rounded-full bg-gradient-to-br from-green-500 to-emerald-600 flex items-center justify-center text-white font-bold">
                    <%= String.at(@current_user.username || "Y", 0) %>
                  </div>
                <% end %>
              </div>

              <!-- Message Content -->
              <div class={[
                "flex-1 min-w-0 max-w-[80%]",
                message.user_id == @current_user.id && "text-right"
              ]}>
                <!-- Message Header -->
                <%= if message.user_id != @current_user.id do %>
                  <div class="flex items-center gap-2 mb-1">
                    <span class="text-white/80 font-medium text-sm"><%= message.username %></span>
                    <span class="text-white/40 text-xs">
                      <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                    </span>
                  </div>
                <% end %>

                <!-- Message Bubble -->
                <div class={[
                  "inline-block rounded-2xl px-4 py-3 text-sm leading-relaxed",
                  message.user_id == @current_user.id && "bg-gradient-to-r from-purple-500 to-pink-600 text-white rounded-br-lg",
                  message.user_id != @current_user.id && "bg-white/10 backdrop-blur-sm text-white border border-white/20 rounded-bl-lg"
                ]}>
                  <p class="whitespace-pre-wrap break-words"><%= message.content %></p>

                  <%= if message.user_id == @current_user.id do %>
                    <div class="text-right mt-2">
                      <span class="text-white/60 text-xs">
                        <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                      </span>
                    </div>
                  <% end %>
                </div>

                <!-- Quick Reactions -->
                <div class="mt-2 flex items-center gap-1">
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="👍"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                  >
                    👍
                  </button>
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="❤️"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                  >
                    ❤️
                  </button>
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="😄"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-2 rounded-full hover:bg-white/10 transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                  >
                    😄
                  </button>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Typing Indicators -->
          <%= if MapSet.size(@typing_users) > 0 do %>
            <div class="flex items-center gap-3 px-4">
              <div class="flex gap-1">
                <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce"></div>
                <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
                <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
              </div>
              <span class="text-white/60 text-sm">
                <%= case MapSet.size(@typing_users) do %>
                  <% 1 -> %>Someone is typing...
                  <% 2 -> %>2 people are typing...
                  <% n -> %><%= n %> people are typing...
                <% end %>
              </span>
            </div>
          <% end %>
        </div>

        <!-- Message Input (Fixed at bottom) -->
        <div class="fixed bottom-0 left-0 right-0 p-4 border-t border-white/10 bg-black/80 backdrop-blur-xl">
          <form phx-submit="send_message" phx-target={@myself} class="relative">
            <div class="flex items-end gap-3">
              <!-- Emoji Picker Button -->
              <button
                type="button"
                phx-click="toggle_emoji_picker"
                phx-target={@myself}
                class="flex-shrink-0 p-3 text-white/60 hover:text-white rounded-xl hover:bg-white/10 transition-colors touch-manipulation"
                style="min-width: 44px; min-height: 44px;"
                title="Add emoji"
              >
                <svg class="h-6 w-6 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>

              <!-- Message Input -->
              <div class="flex-1 relative">
                <textarea
                  id="mobile-message-input"
                  name="message"
                  value={@message_input}
                  phx-keyup="update_message_input"
                  phx-focus="typing_start"
                  phx-blur="typing_stop"
                  phx-target={@myself}
                  placeholder="Type a message..."
                  rows="1"
                  class="w-full bg-white/10 backdrop-blur-sm border border-white/20 rounded-2xl text-white placeholder-white/50 px-4 py-3 pr-14 resize-none focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent text-base"
                  style="max-height: 120px; font-size: 16px;"
                  phx-hook="MobileAutoResizeTextarea"
                ></textarea>

                <!-- Send Button -->
                <button
                  type="submit"
                  disabled={@message_input == ""}
                  class={[
                    "absolute right-2 bottom-2 p-2 rounded-xl transition-all duration-200 touch-manipulation",
                    @message_input != "" && "bg-gradient-to-r from-purple-500 to-pink-600 text-white shadow-lg transform scale-100",
                    @message_input == "" && "text-white/30 cursor-not-allowed scale-90"
                  ]}
                  style="min-width: 40px; min-height: 40px;"
                  title="Send message"
                >
                  <svg class="h-5 w-5 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                  </svg>
                </button>
              </div>
            </div>

            <!-- Mobile Emoji Picker -->
            <%= if @show_emoji_picker do %>
              <div class="absolute bottom-full left-0 right-0 mb-2 bg-black/95 backdrop-blur-xl border border-white/20 rounded-2xl shadow-2xl max-h-64 overflow-y-auto">
                <div class="p-4">
                  <div class="grid grid-cols-8 gap-2">
                    <%= for emoji <- ~w(
                      😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕
                      👋 🤚 🖐️ ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️ 👍 👎 👊 ✊ 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🦿 🦵 🦶
                      👶 🧒 👦 👧 🧑 👱 👨 🧔 👨‍🦰 👨‍🦱 👨‍🦳 👨‍🦲 👩 👩‍🦰 🧑‍🦰 👩‍🦱 🧑‍🦱 👩‍🦳 🧑‍🦳 👩‍🦲 🧑‍🦲 👱‍♀️ 👱‍♂️ 🧓 👴 👵
                      👶🏻 👶🏼 👶🏽 👶🏾 👶🏿 🧒🏻 🧒🏼 🧒🏽 🧒🏾 🧒🏿 👦🏻 👦🏼 👦🏽 👦🏾 👦🏿 👧🏻 👧🏼 👧🏽 👧🏾 👧🏿 🧑🏻 🧑🏼 🧑🏽 🧑🏾 🧑🏿 👨🏻 👨🏼 👨🏽 👨🏾 👨🏿 👩🏻 👩🏼 👩🏽 👩🏾 👩🏿
                      🧑‍⚕️ 👨‍⚕️ 👩‍⚕️ 🧑‍🎓 👨‍🎓 👩‍🎓 🧑‍🎤 👨‍🎤 👩‍🎤 🧑‍🏫 👨‍🏫 👩‍🏫 🧑‍🌾 👨‍🌾 👩‍🌾 🧑‍🍳 👨‍🍳 👩‍🍳 🧑‍🔧 👨‍🔧 👩‍🔧 🧑‍🏭 👨‍🏭 👩‍🏭 🧑‍💼 👨‍💼 👩‍💼 🧑‍🔬 👨‍🔬 👩‍🔬 🧑‍💻 👨‍💻 👩‍💻 🧑‍🎨 👨‍🎨 👩‍🎨
                      💆‍♀️ 💆‍♂️ 💇‍♀️ 💇‍♂️ 🚶‍♀️ 🚶‍♂️ 🧍‍♀️ 🧍‍♂️ 🧎‍♀️ 🧎‍♂️ 🧑‍🦯 👨‍🦯 👩‍🦯 🧑‍🦼 👨‍🦼 👩‍🦼 🧑‍🦽 👨‍🦽 👩‍🦽 🏃‍♀️ 🏃‍♂️ 💃 🕺
                      👫 👭 👬 💑 💏 👪 👨‍👩‍👧 👨‍👩‍👧‍👦 👨‍👩‍👦‍👦 👨‍👩‍👧‍👧 👨‍👨‍👦 👨‍👨‍👧 👨‍👨‍👧‍👦 👨‍👨‍👦‍👦 👨‍👨‍👧‍👧 👩‍👩‍👦 👩‍👩‍👧 👩‍👩‍👧‍👦 👩‍👩‍👦‍👦 👩‍👩‍👧‍👧
                      🤎 🖤 🤍 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐
                      🎵 🎶 🎼 🎹 🥁 🎷 🎺 🎸 🪕 🎻 🎤 🎧 📻 🎬 🎭 🎨 🖼️ 🎪 💻 📱 ⌨️ 🖥️ 🖨️ 📸 📹 📽️ 🎥 📞 ☎️ 📠 📺 📻 🎙️ 🎚️ 🎛️
                      🏳️ 🏴 🏁 🚩 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️
                    ) do %>
                      <button
                        type="button"
                        phx-click="add_emoji"
                        phx-value-emoji={emoji}
                        phx-target={@myself}
                        class="p-2 hover:bg-white/10 rounded-xl text-xl transition-colors touch-manipulation"
                        style="min-width: 44px; min-height: 44px;"
                        title={emoji}
                      >
                        <%= emoji %>
                      </button>
                    <% end %>
                  </div>
                </div>
              </div>
            <% end %>
          </form>
        </div>
      </div>
    </div>
    """
  end
end
