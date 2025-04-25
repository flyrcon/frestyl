# lib/frestyl_web/live/studio_live.ex
defmodule FrestylWeb.StudioLive do
  use FrestylWeb, :live_view

  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to necessary topics for real-time updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "studio:updates")
    end

    {:ok, assign(socket,
      page_title: "Collaboration Studio",
      active_tool: "audio",
      tracks: [],
      collaborators: [],
      chat_messages: [],
      message_input: "",
      show_invite_modal: false,
      studio_name: "Untitled Project",
      tools: [
        %{id: "audio", name: "Audio", icon: "microphone"},
        %{id: "midi", name: "MIDI", icon: "music-note"},
        %{id: "text", name: "Lyrics", icon: "document-text"},
        %{id: "drawing", name: "Visual", icon: "pencil"}
      ]
    )}
  end

  @impl true
  def handle_event("set_active_tool", %{"tool" => tool}, socket) do
    {:noreply, assign(socket, active_tool: tool)}
  end

  @impl true
  def handle_event("toggle_invite_modal", _, socket) do
    {:noreply, assign(socket, show_invite_modal: !socket.assigns.show_invite_modal)}
  end

  @impl true
  def handle_event("send_invite", %{"email" => email}, socket) when email != "" do
    # In a real app, this would send an invitation to the collaborator
    # through a context module

    {:noreply, socket
      |> assign(show_invite_modal: false)
      |> put_flash(:info, "Invitation sent to #{email}")
    }
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # In a real app, this would broadcast the message to all collaborators
    new_message = %{
      id: System.unique_integer([:positive]) |> to_string(),
      username: "Current User", # Would come from authentication
      content: message,
      timestamp: DateTime.utc_now(),
      avatar: nil
    }

    {:noreply, assign(socket,
      chat_messages: socket.assigns.chat_messages ++ [new_message],
      message_input: ""
    )}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    {:noreply, assign(socket, message_input: value)}
  end

  @impl true
  def handle_event("update_studio_name", %{"value" => value}, socket) do
    {:noreply, assign(socket, studio_name: value)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <A11y.skip_to_content />

      <div class="flex h-[calc(100vh-56px)]">
        <!-- Left sidebar - Tools -->
        <div class="w-16 bg-gray-900 flex flex-col items-center py-4 space-y-4">
          <%= for tool <- @tools do %>
            <button
              type="button"
              phx-click="set_active_tool"
              phx-value-tool={tool.id}
              class={[
                "p-2 rounded-md",
                @active_tool == tool.id && "bg-indigo-500 text-white",
                @active_tool != tool.id && "text-gray-400 hover:text-white"
              ]}
              aria-label={tool.name}
              aria-pressed={@active_tool == tool.id}
              title={tool.name}
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <%= case tool.icon do %>
                  <% "microphone" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  <% "music-note" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                  <% "document-text" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  <% "pencil" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                <% end %>
              </svg>
            </button>
          <% end %>
        </div>

        <!-- Main content area -->
        <div class="flex-1 bg-gray-800 flex flex-col" id="main-content">
          <!-- Header -->
          <div class="bg-gray-900 text-white px-4 py-2 flex items-center justify-between">
            <div class="flex items-center space-x-2">
              <input
                type="text"
                value={@studio_name}
                phx-blur="update_studio_name"
                phx-value-key="studio_name"
                class="bg-transparent border-b border-gray-700 focus:border-indigo-500 text-white focus:outline-none"
                aria-label="Project name"
              />
            </div>

            <div class="flex items-center space-x-4">
              <button
                type="button"
                phx-click="toggle_invite_modal"
                class="bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1 rounded-md text-sm"
                aria-label="Invite collaborators"
              >
                Invite
              </button>
            </div>
          </div>

          <!-- Workspace -->
          <div class="flex-1 overflow-hidden">
            <%= case @active_tool do %>
              <% "audio" -> %>
                <div class="p-4 h-full flex flex-col">
                  <h2 class="text-white text-lg font-medium">Audio Tracks</h2>
                  <div class="mt-4 flex-1 bg-gray-700 rounded-lg overflow-y-auto p-4">
                    <!-- Here would be the actual audio interface -->
                    <div class="flex justify-center items-center h-full text-gray-400">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-24 w-24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                        </svg>
                        <p class="mt-4 text-lg">Audio workspace goes here</p>
                        <p class="mt-2">This would be replaced with the actual audio interface</p>
                      </div>
                    </div>
                  </div>
                </div>

              <% "midi" -> %>
                <div class="p-4 h-full flex flex-col">
                  <h2 class="text-white text-lg font-medium">MIDI Sequencer</h2>
                  <div class="mt-4 flex-1 bg-gray-700 rounded-lg overflow-y-auto p-4">
                    <div class="flex justify-center items-center h-full text-gray-400">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-24 w-24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                        </svg>
                        <p class="mt-4 text-lg">MIDI workspace goes here</p>
                        <p class="mt-2">This would be replaced with the actual MIDI interface</p>
                      </div>
                    </div>
                  </div>
                </div>

              <% "text" -> %>
                <div class="p-4 h-full flex flex-col">
                  <h2 class="text-white text-lg font-medium">Lyrics Editor</h2>
                  <div class="mt-4 flex-1 bg-gray-700 rounded-lg overflow-y-auto p-4">
                    <div class="h-full">
                      <textarea
                        class="w-full h-full bg-gray-800 text-white p-4 rounded-lg border border-gray-600 focus:border-indigo-500 focus:ring-indigo-500"
                        placeholder="Write your lyrics here..."
                        aria-label="Lyrics editor"
                      ></textarea>
                    </div>
                  </div>
                </div>

              <% "drawing" -> %>
                <div class="p-4 h-full flex flex-col">
                  <h2 class="text-white text-lg font-medium">Visual Editor</h2>
                  <div class="mt-4 flex-1 bg-gray-700 rounded-lg overflow-y-auto p-4">
                    <div class="flex justify-center items-center h-full text-gray-400">
                      <div class="text-center">
                        <svg xmlns="http://www.w3.org/2000/svg" class="mx-auto h-24 w-24" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
                        </svg>
                        <p class="mt-4 text-lg">Drawing workspace goes here</p>
                        <p class="mt-2">This would be replaced with the actual drawing interface</p>
                      </div>
                    </div>
                  </div>
                </div>
            <% end %>
          </div>
        </div>

        <!-- Right sidebar - Chat & Collaborators -->
        <div class="w-64 bg-gray-900 border-l border-gray-700 flex flex-col">
          <!-- Collaborators -->
          <div class="p-4 border-b border-gray-700">
            <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Collaborators</h3>
            <div class="mt-3 space-y-2">
              <!-- Show collaborators here -->
              <div class="flex items-center">
                <div class="h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center text-white font-medium">
                  Y
                </div>
                <div class="ml-2">
                  <p class="text-sm font-medium text-white">You</p>
                  <p class="text-xs text-gray-400">Owner</p>
                </div>
              </div>
            </div>
          </div>

          <!-- Chat -->
          <div class="flex-1 flex flex-col overflow-hidden">
            <div class="p-4 border-b border-gray-700">
              <h3 class="text-sm font-medium text-gray-400 uppercase tracking-wider">Chat</h3>
            </div>

            <div class="flex-1 overflow-y-auto p-4">
              <div class="space-y-4">
                <%= for message <- @chat_messages do %>
                  <div class="flex">
                    <div class="flex-shrink-0 mr-3">
                      <div class="h-8 w-8 rounded-full bg-gray-700 flex items-center justify-center text-white font-medium">
                        <%= String.first(message.username) %>
                      </div>
                    </div>
                    <div>
                      <div class="flex items-center">
                        <h5 class="text-sm font-medium text-white"><%= message.username %></h5>
                        <span class="ml-2 text-xs text-gray-400"><%= Calendar.strftime(message.timestamp, "%I:%M %p") %></span>
                      </div>
                      <p class="text-sm text-gray-300"><%= message.content %></p>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <div class="p-4 border-t border-gray-700">
              <form phx-submit="send_message" class="flex">
                <input
                  type="text"
                  name="message"
                  value={@message_input}
                  phx-keyup="update_message_input"
                  placeholder="Type a message..."
                  class="block w-full bg-gray-800 border-gray-700 rounded-md text-white text-sm focus:border-indigo-500 focus:ring-indigo-500"
                  aria-label="Chat message"
                >
              </form>
            </div>
          </div>
        </div>
      </div>

      <!-- Invite Modal -->
      <A11y.a11y_dialog
        id="invite-modal"
        show={@show_invite_modal}
        title="Invite Collaborators"
        on_cancel="toggle_invite_modal"
        confirm_label="Send Invitation"
        on_confirm="send_invite"
      >
        <div class="mt-2">
          <p class="text-sm text-gray-500">
            Enter the email address of the person you want to invite to collaborate on this project.
          </p>
          <div class="mt-4">
            <label for="email" class="block text-sm font-medium text-gray-700">Email address</label>
            <div class="mt-1">
              <input
                type="email"
                name="email"
                id="email"
                class="shadow-sm focus:ring-indigo-500 focus:border-indigo-500 block w-full sm:text-sm border-gray-300 rounded-md"
                placeholder="collaborator@example.com"
              />
            </div>
          </div>
        </div>
      </A11y.a11y_dialog>
    </div>
    """
  end
end
