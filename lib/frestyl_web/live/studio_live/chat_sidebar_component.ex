# lib/frestyl_web/live/studio_live/chat_sidebar_component.ex

defmodule FrestylWeb.StudioLive.ChatSidebarComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      active_tab: "chat",
      file_upload_open: false,
      message_draft: "",
      emoji_picker_open: false,
      auto_scroll: true
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "bg-black/30 backdrop-blur-xl flex flex-col border-l border-white/10 transition-all duration-300",
      (if @collapsed, do: "w-0 opacity-0 overflow-hidden", else: "w-80")
    ]}>

      <!-- Collapse Toggle -->
      <button
        phx-click="toggle_chat_sidebar"
        phx-target={@myself}
        class="absolute -left-3 top-6 w-6 h-6 bg-black/50 backdrop-blur-sm rounded-full flex items-center justify-center text-white/70 hover:text-white hover:bg-black/70 transition-all duration-200 z-10"
        aria-label={if @collapsed, do: "Expand chat", else: "Collapse chat"}
      >
        <svg class={[
          "w-3 h-3 transition-transform duration-200",
          (if @collapsed, do: "rotate-180", else: "rotate-0")
        ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
        </svg>
      </button>

      <!-- Header with Tabs -->
      <div class="border-b border-white/10 bg-black/20">
        <!-- Tab Navigation -->
        <div class="flex">
          <button
            phx-click="switch_tab"
            phx-value-tab="chat"
            phx-target={@myself}
            class={[
              "flex-1 py-3 text-center text-sm font-medium transition-all duration-200 flex items-center justify-center gap-2",
              if @active_tab == "chat" do
                "text-white bg-purple-500/20 border-b-2 border-purple-400"
              else
                "text-white/70 hover:text-white hover:bg-white/5"
              end
            ]}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            Chat
            <%= if length(@chat_messages) > 0 do %>
              <span class="text-xs bg-purple-500/30 px-1.5 py-0.5 rounded-full"><%= length(@chat_messages) %></span>
            <% end %>
          </button>

          <button
            phx-click="switch_tab"
            phx-value-tab="files"
            phx-target={@myself}
            class={[
              "flex-1 py-3 text-center text-sm font-medium transition-all duration-200 flex items-center justify-center gap-2",
              if @active_tab == "files" do
                "text-white bg-purple-500/20 border-b-2 border-purple-400"
              else
                "text-white/70 hover:text-white hover:bg-white/5"
              end
            ]}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            Files
          </button>
        </div>

        <!-- Online Users Indicator -->
        <div class="px-4 py-2 border-t border-white/5">
          <div class="flex items-center justify-between">
            <span class="text-xs text-white/60 font-medium">
              <%= length(@collaborators) %> online
            </span>
            <div class="flex -space-x-1">
              <%= for {collaborator, index} <- Enum.with_index(Enum.take(@collaborators, 4)) do %>
                <div
                  class="w-6 h-6 rounded-full bg-gradient-to-br from-purple-500 to-pink-500 flex items-center justify-center text-white text-xs font-bold border border-white/20"
                  title={collaborator.username}
                >
                  <%= String.first(collaborator.username || "U") %>
                </div>
              <% end %>
              <%= if length(@collaborators) > 4 do %>
                <div class="w-6 h-6 rounded-full bg-gray-600 flex items-center justify-center text-white text-xs font-bold">
                  +<%= length(@collaborators) - 4 %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Content Area -->
      <div class="flex-1 overflow-hidden flex flex-col">
        <%= case @active_tab do %>
          <% "chat" -> %>
            <!-- Chat Messages -->
            <div
              id="chat-messages"
              class="flex-1 overflow-y-auto p-4 space-y-3"
              phx-hook="ChatScroller"
              phx-update="stream"
            >
              <%= if length(@chat_messages) == 0 do %>
                <!-- Empty Chat State -->
                <div class="text-center py-8">
                  <div class="w-12 h-12 mx-auto mb-4 bg-white/10 rounded-2xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-white/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                    </svg>
                  </div>
                  <h3 class="text-white font-medium mb-2">Start the conversation</h3>
                  <p class="text-white/60 text-sm">Send a message to collaborate with your team.</p>
                </div>
              <% else %>
                <!-- Message List -->
                <%= for message <- @chat_messages do %>
                  <div
                    id={"message-#{message.id}"}
                    class={[
                      "flex chat-message transition-all duration-200 hover:bg-white/5 rounded-lg p-2 -m-2",
                      (if message.user_id == @current_user.id, do: "justify-end", else: "justify-start")
                    ]}
                  >
                    <%= if message.user_id != @current_user.id do %>
                      <!-- Other User Message -->
                      <div class="flex gap-3 max-w-[85%]">
                        <!-- Avatar -->
                        <div class="flex-shrink-0">
                          <%= if Map.get(message, :avatar_url) do %>
                            <img
                              src={message.avatar_url}
                              class="w-8 h-8 rounded-full"
                              alt={message.username}
                            />
                          <% else %>
                            <div class="w-8 h-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                              <%= String.at(message.username || "U", 0) %>
                            </div>
                          <% end %>

                          <!-- Online indicator -->
                          <%= if user_online?(@collaborators, message.user_id) do %>
                            <div class="w-2 h-2 bg-green-400 rounded-full -mt-1 ml-6 shadow-lg shadow-green-400/50"></div>
                          <% end %>
                        </div>

                        <!-- Message Content -->
                        <div class="flex-1 min-w-0">
                          <!-- Message Header -->
                          <div class="flex items-center gap-2 mb-1">
                            <span class="text-xs font-medium text-white/80">
                              <%= message.username %>
                            </span>
                            <span class="text-xs text-white/50">
                              <%= format_message_time(message.inserted_at) %>
                            </span>
                          </div>

                          <!-- Message Bubble -->
                          <div class="bg-white/10 backdrop-blur-sm rounded-2xl rounded-bl-md px-4 py-2 border border-white/5">
                            <p class="text-sm text-white whitespace-pre-wrap leading-relaxed">
                              <%= message.content %>
                            </p>
                          </div>
                        </div>
                      </div>
                    <% else %>
                      <!-- Own Message -->
                      <div class="flex gap-3 max-w-[85%]">
                        <!-- Message Content -->
                        <div class="flex-1 min-w-0">
                          <!-- Message Header -->
                          <div class="flex items-center justify-end gap-2 mb-1">
                            <span class="text-xs text-white/50">
                              <%= format_message_time(message.inserted_at) %>
                            </span>
                            <span class="text-xs font-medium text-white/80">You</span>
                          </div>

                          <!-- Message Bubble -->
                          <div class="bg-gradient-to-r from-purple-500 to-pink-500 rounded-2xl rounded-br-md px-4 py-2 shadow-lg">
                            <p class="text-sm text-white whitespace-pre-wrap leading-relaxed">
                              <%= message.content %>
                            </p>
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                <% end %>
              <% end %>

              <!-- Typing Indicators -->
              <%= if MapSet.size(@typing_users) > 0 do %>
                <div class="flex items-center gap-2 text-white/60 text-xs px-2">
                  <div class="flex space-x-1">
                    <div class="w-1 h-1 bg-white/60 rounded-full animate-bounce"></div>
                    <div class="w-1 h-1 bg-white/60 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
                    <div class="w-1 h-1 bg-white/60 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                  </div>
                  <span>
                    <%= format_typing_users(@typing_users, @collaborators) %>
                  </span>
                </div>
              <% end %>
            </div>

          <% "files" -> %>
            <!-- Files Tab Content -->
            <div class="flex-1 overflow-y-auto p-4">
              <div class="text-center py-8">
                <div class="w-12 h-12 mx-auto mb-4 bg-white/10 rounded-2xl flex items-center justify-center">
                  <svg class="w-6 h-6 text-white/60" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                </div>
                <h3 class="text-white font-medium mb-2">File Sharing</h3>
                <p class="text-white/60 text-sm mb-4">Share audio files, images, and documents with your team.</p>
                <A11y.a11y_button
                  variant="outline"
                  size="sm"
                  class="border-white/20 text-white/70 hover:text-white hover:bg-white/10"
                  phx-click="open_file_upload"
                  phx-target={@myself}
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  Upload Files
                </A11y.a11y_button>
              </div>
            </div>
        <% end %>
      </div>

      <!-- Message Input Area -->
      <%= if @active_tab == "chat" do %>
        <div class="border-t border-white/10 p-4 bg-black/20">
          <!-- Message Composition -->
          <form phx-submit="send_message" phx-target={@myself} class="space-y-3">
            <!-- Message Input -->
            <div class="relative">
              <textarea
                id="message-input"
                name="message"
                value={@message_input}
                phx-keydown="handle_message_keydown"
                phx-focus="start_typing"
                phx-blur="stop_typing"
                phx-target={@myself}
                placeholder="Type a message..."
                rows="1"
                class="w-full bg-white/10 border border-white/20 rounded-xl text-white text-sm focus:outline-none focus:ring-2 focus:ring-purple-400 focus:border-transparent resize-none px-4 py-3 pr-12 placeholder-white/50 backdrop-blur-sm"
                style="min-height: 44px; max-height: 120px;"
                phx-hook="AutoResizeTextarea"
              ></textarea>

              <!-- Emoji Button -->
              <button
                type="button"
                phx-click="toggle_emoji_picker"
                phx-target={@myself}
                class="absolute right-2 top-1/2 transform -translate-y-1/2 w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 flex items-center justify-center text-white/70 hover:text-white transition-colors"
                aria-label="Add emoji"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </button>
            </div>

            <!-- Action Row -->
            <div class="flex items-center justify-between">
              <!-- File Upload & Actions -->
              <div class="flex items-center space-x-2">
                <button
                  type="button"
                  phx-click="open_file_upload"
                  phx-target={@myself}
                  class="w-8 h-8 rounded-lg bg-white/10 hover:bg-white/20 flex items-center justify-center text-white/70 hover:text-white transition-colors"
                  aria-label="Attach file"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                  </svg>
                </button>
              </div>

              <!-- Send Button -->
              <A11y.a11y_button
                type="submit"
                variant="primary"
                size="sm"
                class="bg-gradient-to-r from-purple-500 to-pink-500 hover:from-purple-600 hover:to-pink-600 border-0 shadow-lg px-6"
                disabled={String.trim(@message_input) == ""}
              >
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                </svg>
                Send
              </A11y.a11y_button>
            </div>
          </form>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_chat_sidebar", _, socket) do
    send(self(), :toggle_chat_sidebar)
    {:noreply, socket}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, active_tab: tab)}
  end

  def handle_event("send_message", %{"message" => message}, socket) do
    if String.trim(message) != "" do
      send(self(), {:send_session_message, String.trim(message)})
    end
    {:noreply, assign(socket, message_input: "")}
  end

  def handle_event("handle_message_keydown", %{"key" => "Enter", "shiftKey" => false}, socket) do
    # Send message on Enter (without Shift)
    if String.trim(socket.assigns.message_input) != "" do
      send(self(), {:send_session_message, String.trim(socket.assigns.message_input)})
      {:noreply, assign(socket, message_input: "")}
    else
      {:noreply, socket}
    end
  end

  def handle_event("handle_message_keydown", _, socket) do
    {:noreply, socket}
  end

  def handle_event("start_typing", _, socket) do
    send(self(), :typing_start)
    {:noreply, socket}
  end

  def handle_event("stop_typing", _, socket) do
    send(self(), :typing_stop)
    {:noreply, socket}
  end

  def handle_event("toggle_emoji_picker", _, socket) do
    {:noreply, assign(socket, emoji_picker_open: !socket.assigns.emoji_picker_open)}
  end

  def handle_event("open_file_upload", _, socket) do
    {:noreply, assign(socket, file_upload_open: true)}
  end

  # Helper functions
  defp format_message_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :minute) do
      diff when diff < 1 -> "just now"
      diff when diff < 60 -> "#{diff}m ago"
      diff when diff < 1440 -> "#{div(diff, 60)}h ago"
      _ -> Calendar.strftime(datetime, "%m/%d %H:%M")
    end
  end

  defp user_online?(collaborators, user_id) do
    Enum.any?(collaborators, fn collab ->
      to_string(collab.user_id) == to_string(user_id)
    end)
  end

  defp format_typing_users(typing_users, collaborators) do
    typing_list = typing_users
    |> MapSet.to_list()
    |> Enum.map(fn user_id ->
      collaborator = Enum.find(collaborators, fn c -> to_string(c.user_id) == to_string(user_id) end)
      collaborator && collaborator.username || "Someone"
    end)

    case length(typing_list) do
      1 -> "#{Enum.at(typing_list, 0)} is typing..."
      2 -> "#{Enum.join(typing_list, " and ")} are typing..."
      n when n > 2 -> "#{n} people are typing..."
      _ -> ""
    end
  end
end
