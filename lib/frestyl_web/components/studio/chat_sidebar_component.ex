defmodule FrestylWeb.Studio.ChatSidebarComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Chat
  alias Frestyl.Presence

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      message_input: "",
      show_emoji_picker: false,
      typing_users: MapSet.new(),
      scroll_to_bottom: false
    )}
  end

  @impl true
  def update(%{session_id: session_id, current_user: current_user} = assigns, socket) do
    if connected?(socket) do
      # Subscribe to chat updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}:chat")
    end

    {:ok, assign(socket, assigns)}
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
        # Clear input and stop typing
        send(self(), {:chat_stop_typing, user.id})

        {:noreply,
          socket
          |> assign(message_input: "", scroll_to_bottom: true)
          |> push_event("clear_message_input", %{})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to send message")}
    end
  end

  def handle_event("send_message", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("typing_start", _, socket) do
    user_id = socket.assigns.current_user.id
    session_id = socket.assigns.session_id

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
    user_id = socket.assigns.current_user.id

    if value != "" and socket.assigns.message_input == "" do
      send(self(), {:chat_start_typing, user_id})
    else
      if value == "" and socket.assigns.message_input != "" do
        send(self(), {:chat_stop_typing, user_id})
      end
    end

    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("toggle_emoji_picker", _, socket) do
    {:noreply, assign(socket, show_emoji_picker: !socket.assigns.show_emoji_picker)}
  end

  @impl true
  def handle_event("add_emoji", %{"emoji" => emoji}, socket) do
    current_input = socket.assigns.message_input
    new_input = current_input <> emoji

    {:noreply,
      socket
      |> assign(message_input: new_input, show_emoji_picker: false)
      |> push_event("update_message_input_value", %{value: new_input})}
  end

  @impl true
  def handle_event("add_reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    user_id = socket.assigns.current_user.id

    case Chat.add_reaction(message_id, user_id, emoji) do
      {:ok, _reaction} -> {:noreply, socket}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add reaction")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-full bg-black/30 backdrop-blur-xl border-l border-white/10">
      <!-- Chat Header -->
      <div class="flex items-center justify-between p-4 border-b border-white/10 bg-black/20">
        <div class="flex items-center gap-3">
          <div class="p-2 bg-gradient-to-r from-purple-500 to-pink-600 rounded-xl">
            <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
          </div>
          <h3 class="text-white font-bold text-lg">Session Chat</h3>
        </div>

        <div class="flex items-center gap-2">
          <span class="text-white/60 text-sm">
            <%= length(@chat_messages) %> messages
          </span>
        </div>
      </div>

      <!-- Messages Area -->
      <div
        id="chat-messages"
        class="flex-1 overflow-y-auto p-4 space-y-4 scroll-smooth"
        phx-hook="ChatScrollManager"
        phx-update={if @scroll_to_bottom, do: "append", else: "ignore"}
      >
        <%= if length(@chat_messages) == 0 do %>
          <div class="text-center text-white/50 py-8">
            <svg class="h-12 w-12 mx-auto mb-4 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <p>No messages yet</p>
            <p class="text-sm text-white/30 mt-1">Start the conversation!</p>
          </div>
        <% end %>

        <%= for message <- @chat_messages do %>
          <div class={[
            "group flex gap-3 hover:bg-white/5 rounded-lg p-2 -m-2 transition-colors",
            message.user_id == @current_user.id && "flex-row-reverse" || nil
          ]}>
            <!-- Avatar -->
            <div class="flex-shrink-0">
              <%= if message.user_id != @current_user.id do %>
                <%= if Map.get(message, :avatar_url) do %>
                  <img src={message.avatar_url} class="h-8 w-8 rounded-full" alt={message.username} />
                <% else %>
                  <div class="h-8 w-8 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white font-bold text-sm">
                    <%= String.at(message.username || "U", 0) %>
                  </div>
                <% end %>
              <% else %>
                <div class="h-8 w-8 rounded-full bg-gradient-to-br from-green-500 to-emerald-600 flex items-center justify-center text-white font-bold text-sm">
                  <%= String.at(@current_user.username || "Y", 0) %>
                </div>
              <% end %>
            </div>

            <!-- Message Content -->
            <div class={[
              "flex-1 min-w-0",
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
                "inline-block max-w-xs lg:max-w-sm xl:max-w-md rounded-2xl px-4 py-2 text-sm",
                message.user_id == @current_user.id && "bg-gradient-to-r from-purple-500 to-pink-600 text-white rounded-br-md",
                message.user_id != @current_user.id && "bg-white/10 backdrop-blur-sm text-white border border-white/20 rounded-bl-md"
              ]}>
                <p class="whitespace-pre-wrap break-words"><%= message.content %></p>

                <%= if message.user_id == @current_user.id do %>
                  <div class="text-right mt-1">
                    <span class="text-white/60 text-xs">
                      <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                    </span>
                  </div>
                <% end %>
              </div>

              <!-- Message Actions (shown on hover) -->
              <div class="opacity-0 group-hover:opacity-100 transition-opacity mt-1">
                <div class="flex items-center gap-1 text-xs">
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="👍"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-1 rounded"
                    title="Add reaction"
                  >
                    👍
                  </button>
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="❤️"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-1 rounded"
                    title="Add reaction"
                  >
                    ❤️
                  </button>
                  <button
                    phx-click="add_reaction"
                    phx-value-message_id={message.id}
                    phx-value-emoji="😄"
                    phx-target={@myself}
                    class="text-white/50 hover:text-white p-1 rounded"
                    title="Add reaction"
                  >
                    😄
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>

        <!-- Typing Indicators -->
        <%= if MapSet.size(@typing_users) > 0 do %>
          <div class="flex items-center gap-2 text-white/60 text-sm">
            <div class="flex gap-1">
              <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce"></div>
              <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
              <div class="w-2 h-2 bg-white/40 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
            </div>
            <span>
              <%= case MapSet.size(@typing_users) do %>
                <% 1 -> %>Someone is typing...
                <% 2 -> %>2 people are typing...
                <% n -> %><%= n %> people are typing...
              <% end %>
            </span>
          </div>
        <% end %>
      </div>

      <!-- Message Input -->
      <div class="p-4 border-t border-white/10 bg-black/20">
        <form phx-submit="send_message" phx-target={@myself} class="relative">
          <div class="flex items-end gap-2">
            <!-- Emoji Picker Button -->
            <button
              type="button"
              phx-click="toggle_emoji_picker"
              phx-target={@myself}
              class="flex-shrink-0 p-2 text-white/60 hover:text-white rounded-lg hover:bg-white/10 transition-colors"
              title="Add emoji"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </button>

            <!-- Message Input -->
            <div class="flex-1 relative">
              <textarea
                id="message-input"
                name="message"
                value={@message_input}
                phx-keyup="update_message_input"
                phx-focus="typing_start"
                phx-blur="typing_stop"
                phx-target={@myself}
                placeholder="Type a message..."
                rows="1"
                class="w-full bg-white/10 backdrop-blur-sm border border-white/20 rounded-xl text-white placeholder-white/50 px-4 py-3 pr-12 resize-none focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent"
                style="max-height: 120px;"
                phx-hook="AutoResizeTextarea"
              ></textarea>

              <!-- Send Button -->
              <button
                type="submit"
                disabled={@message_input == ""}
                class={[
                  "absolute right-2 bottom-2 p-2 rounded-lg transition-all duration-200",
                  @message_input != "" && "bg-gradient-to-r from-purple-500 to-pink-600 text-white shadow-lg hover:shadow-xl transform hover:scale-105",
                  @message_input == "" && "text-white/30 cursor-not-allowed"
                ]}
                title="Send message"
              >
                <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
              </button>
            </div>
          </div>

          <!-- Emoji Picker -->
          <%= if @show_emoji_picker do %>
            <div class="absolute bottom-full left-0 mb-2 p-3 bg-black/90 backdrop-blur-xl border border-white/20 rounded-xl shadow-2xl max-h-48 overflow-y-auto">
              <div class="grid grid-cols-8 gap-1">
                <%= for emoji <- ~w(
                  😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕
                  👋 🤚 🖐️ ✋ 🖖 👌 🤌 🤏 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 🖕 👇 ☝️ 👍 👎 👊 ✊ 🤛 🤜 👏 🙌 👐 🤲 🤝 🙏 ✍️ 💅 🤳 💪 🦾 🦿 🦵 🦶
                  👶 🧒 👦 👧 🧑 👱 👨 🧔 👨‍🦰 👨‍🦱 👨‍🦳 👨‍🦲 👩 👩‍🦰 🧑‍🦰 👩‍🦱 🧑‍🦱 👩‍🦳 🧑‍🦳 👩‍🦲 🧑‍🦲 👱‍♀️ 👱‍♂️ 🧓 👴 👵
                  👶🏻 👶🏼 👶🏽 👶🏾 👶🏿 🧒🏻 🧒🏼 🧒🏽 🧒🏾 🧒🏿 👦🏻 👦🏼 👦🏽 👦🏾 👦🏿 👧🏻 👧🏼 👧🏽 👧🏾 👧🏿 🧑🏻 🧑🏼 🧑🏽 🧑🏾 🧑🏿 👨🏻 👨🏼 👨🏽 👨🏾 👨🏿 👩🏻 👩🏼 👩🏽 👩🏾 👩🏿
                  🧑‍⚕️ 👨‍⚕️ 👩‍⚕️ 🧑‍🎓 👨‍🎓 👩‍🎓 🧑‍🎤 👨‍🎤 👩‍🎤 🧑‍🏫 👨‍🏫 👩‍🏫 🧑‍🌾 👨‍🌾 👩‍🌾 🧑‍🍳 👨‍🍳 👩‍🍳 🧑‍🔧 👨‍🔧 👩‍🔧 🧑‍🏭 👨‍🏭 👩‍🏭 🧑‍💼 👨‍💼 👩‍💼 🧑‍🔬 👨‍🔬 👩‍🔬 🧑‍💻 👨‍💻 👩‍💻 🧑‍🎨 👨‍🎨 👩‍🎨
                  👮‍♀️ 👮‍♂️ 🕵️‍♀️ 🕵️‍♂️ 💂‍♀️ 💂‍♂️ 🥷 👷‍♀️ 👷‍♂️ 🤴 👸 👳‍♀️ 👳‍♂️ 👲 🧕 🤵‍♀️ 🤵‍♂️ 👰‍♀️ 👰‍♂️ 🤰 🤱 👼
                  🎅 🤶 🧑‍🎄 🦸‍♀️ 🦸‍♂️ 🦹‍♀️ 🦹‍♂️ 🧙‍♀️ 🧙‍♂️ 🧚‍♀️ 🧚‍♂️ 🧛‍♀️ 🧛‍♂️ 🧜‍♀️ 🧜‍♂️ 🧝‍♀️ 🧝‍♂️ 🧞‍♀️ 🧞‍♂️ 🧟‍♀️ 🧟‍♂️
                  💆‍♀️ 💆‍♂️ 💇‍♀️ 💇‍♂️ 🚶‍♀️ 🚶‍♂️ 🧍‍♀️ 🧍‍♂️ 🧎‍♀️ 🧎‍♂️ 🧑‍🦯 👨‍🦯 👩‍🦯 🧑‍🦼 👨‍🦼 👩‍🦼 🧑‍🦽 👨‍🦽 👩‍🦽 🏃‍♀️ 🏃‍♂️ 💃 🕺
                  👫 👭 👬 💑 💏 👪 👨‍👩‍👧 👨‍👩‍👧‍👦 👨‍👩‍👦‍👦 👨‍👩‍👧‍👧 👨‍👨‍👦 👨‍👨‍👧 👨‍👨‍👧‍👦 👨‍👨‍👦‍👦 👨‍👨‍👧‍👧 👩‍👩‍👦 👩‍👩‍👧 👩‍👩‍👧‍👦 👩‍👩‍👦‍👦 👩‍👩‍👧‍👧
                  🤎 🖤 🤍 ❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 💟 ☮️ ✝️ ☪️ 🕉️ ☸️ ✡️ 🔯 🕎 ☯️ ☦️ 🛐 ⛎ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓
                  🎵 🎶 🎼 🎹 🥁 🎷 🎺 🎸 🪕 🎻 🎤 🎧 📻 🎬 🎭 🎨 🖼️ 🎪 💻 📱 ⌨️ 🖥️ 🖨️ 📸 📹 📽️ 🎥 📞 ☎️ 📠 📺 📻 🎙️ 🎚️ 🎛️
                  🏳️ 🏴 🏁 🚩 🏳️‍🌈 🏳️‍⚧️ 🏴‍☠️
                ) do %>
                  <button
                    type="button"
                    phx-click="add_emoji"
                    phx-value-emoji={emoji}
                    phx-target={@myself}
                    class="p-1 hover:bg-white/10 rounded text-lg transition-colors"
                    title={emoji}
                  >
                    <%= emoji %>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </form>
      </div>
    </div>
    """
  end
end
