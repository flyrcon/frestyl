defmodule FrestylWeb.Studio.MobileTextComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Chat

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show_keyboard_toolbar: false,
      cursor_position: %{line: 0, column: 0},
      selection: nil,
      is_typing: false,
      last_sync: DateTime.utc_now()
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("text_update", %{"content" => content, "cursor" => cursor, "selection" => selection}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      # Send text update to parent StudioLive
      send(self(), {:mobile_text_update, %{
        content: content,
        cursor: cursor,
        selection: selection,
        user_id: socket.assigns.current_user.id
      }})

      {:noreply, assign(socket,
        cursor_position: cursor,
        selection: selection,
        is_typing: content != socket.assigns.workspace_state.text.content,
        last_sync: DateTime.utc_now()
      )}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_keyboard_toolbar", _, socket) do
    {:noreply, assign(socket, show_keyboard_toolbar: true)}
  end

  @impl true
  def handle_event("hide_keyboard_toolbar", _, socket) do
    {:noreply, assign(socket, show_keyboard_toolbar: false)}
  end

  @impl true
  def handle_event("insert_text", %{"text" => text}, socket) do
    {:noreply, push_event(socket, "mobile_insert_text", %{text: text})}
  end

  @impl true
  def handle_event("format_text", %{"format" => format}, socket) do
    case format do
      "bold" -> {:noreply, push_event(socket, "mobile_format_bold", %{})}
      "italic" -> {:noreply, push_event(socket, "mobile_format_italic", %{})}
      "heading" -> {:noreply, push_event(socket, "mobile_format_heading", %{})}
      "bullet" -> {:noreply, push_event(socket, "mobile_format_bullet", %{})}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("undo", _, socket) do
    send(self(), {:mobile_text_undo})
    {:noreply, socket}
  end

  @impl true
  def handle_event("redo", _, socket) do
    send(self(), {:mobile_text_redo})
    {:noreply, socket}
  end

  defp can_edit_text?(permissions), do: :edit_text in permissions

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-black/20 backdrop-blur-sm">
      <!-- Mobile Text Header -->
      <div class="flex items-center justify-between p-4 border-b border-white/10 bg-black/30">
        <div class="flex items-center gap-3">
          <div class="p-2 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl">
            <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <div>
            <h3 class="text-white font-bold text-lg">Lyrics Editor</h3>
            <p class="text-white/60 text-sm">
              <%= if @is_typing, do: "Editing...", else: "#{String.length(@workspace_state.text.content)} characters" %>
            </p>
          </div>
        </div>

        <!-- Sync Status -->
        <div class="flex items-center gap-2">
          <%= if length(@pending_operations) > 0 do %>
            <div class="flex items-center gap-1 text-yellow-300 text-xs">
              <svg class="h-3 w-3 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
              </svg>
              <span>Syncing</span>
            </div>
          <% else %>
            <div class="flex items-center gap-1 text-green-300 text-xs">
              <div class="w-2 h-2 bg-green-400 rounded-full"></div>
              <span>Synced</span>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Text Editor Area -->
      <div class="flex-1 relative overflow-hidden">
        <%= if can_edit_text?(@permissions) do %>
          <textarea
            id="mobile-text-editor"
            phx-hook="MobileTextEditor"
            phx-target={@myself}
            class="w-full h-full bg-transparent text-white p-6 resize-none focus:outline-none text-base leading-relaxed"
            style="font-size: 16px; line-height: 1.6;"
            placeholder="Start writing your lyrics..."
            autocomplete="off"
            autocorrect="on"
            autocapitalize="sentences"
            spellcheck="true"
          ><%= @workspace_state.text.content %></textarea>

          <!-- Collaboration Cursors -->
          <%= for {user_id, cursor_data} <- @workspace_state.text.cursors do %>
            <%= if user_id != to_string(@current_user.id) do %>
              <% username = get_username_from_collaborators(user_id, @collaborators) %>
              <div
                id={"cursor-#{user_id}"}
                class="absolute pointer-events-none z-10"
                style={"transform: translate(#{cursor_data.x || 0}px, #{cursor_data.y || 0}px);"}
                phx-hook="CollaboratorCursor"
                data-user-id={user_id}
              >
                <div class="w-0.5 h-6 bg-purple-500 animate-pulse"></div>
                <div class="absolute -top-6 left-0 bg-purple-500 text-white text-xs px-2 py-1 rounded whitespace-nowrap">
                  <%= username %>
                </div>
              </div>
            <% end %>
          <% end %>

          <!-- Mobile Keyboard Toolbar -->
          <%= if @show_keyboard_toolbar do %>
            <div class="absolute bottom-0 left-0 right-0 bg-black/95 backdrop-blur-xl border-t border-white/20 p-3">
              <div class="flex items-center justify-between">
                <!-- Formatting Tools -->
                <div class="flex items-center gap-2">
                  <button
                    phx-click="format_text"
                    phx-value-format="bold"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Bold"
                  >
                    <svg class="h-5 w-5 mx-auto font-bold" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 4h8a4 4 0 014 4 3 3 0 01-3 3 3 3 0 013 3 4 4 0 01-4 4H6z" />
                    </svg>
                  </button>

                  <button
                    phx-click="format_text"
                    phx-value-format="italic"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Italic"
                  >
                    <svg class="h-5 w-5 mx-auto italic" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 5l8 14M9 19h6M15 5h-6" />
                    </svg>
                  </button>

                  <button
                    phx-click="format_text"
                    phx-value-format="heading"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Heading"
                  >
                    <span class="text-sm font-bold">H</span>
                  </button>

                  <button
                    phx-click="format_text"
                    phx-value-format="bullet"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Bullet List"
                  >
                    <svg class="h-5 w-5 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                    </svg>
                  </button>
                </div>

                <!-- Quick Text Inserts -->
                <div class="flex items-center gap-2">
                  <button
                    phx-click="insert_text"
                    phx-value-text="[Verse]"
                    phx-target={@myself}
                    class="px-3 py-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors text-xs touch-manipulation"
                    style="min-height: 44px;"
                  >
                    Verse
                  </button>

                  <button
                    phx-click="insert_text"
                    phx-value-text="[Chorus]"
                    phx-target={@myself}
                    class="px-3 py-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors text-xs touch-manipulation"
                    style="min-height: 44px;"
                  >
                    Chorus
                  </button>

                  <button
                    phx-click="insert_text"
                    phx-value-text="[Bridge]"
                    phx-target={@myself}
                    class="px-3 py-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors text-xs touch-manipulation"
                    style="min-height: 44px;"
                  >
                    Bridge
                  </button>
                </div>

                <!-- Undo/Redo -->
                <div class="flex items-center gap-2">
                  <button
                    phx-click="undo"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Undo"
                  >
                    <svg class="h-5 w-5 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
                    </svg>
                  </button>

                  <button
                    phx-click="redo"
                    phx-target={@myself}
                    class="p-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors touch-manipulation"
                    style="min-width: 44px; min-height: 44px;"
                    title="Redo"
                  >
                    <svg class="h-5 w-5 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 10h-10a8 8 0 00-8 8v2m18-10l-6-6m6 6l-6 6" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>

        <% else %>
          <!-- Read-only view -->
          <div class="w-full h-full bg-black/10 p-6 overflow-auto">
            <%= if @workspace_state.text.content != "" do %>
              <div class="text-white text-base leading-relaxed whitespace-pre-wrap font-mono">
                <%= @workspace_state.text.content %>
              </div>
            <% else %>
              <div class="text-center text-white/50 py-12">
                <svg class="h-16 w-16 mx-auto mb-4 text-white/30" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p class="text-lg">No content yet</p>
                <p class="text-sm text-white/30 mt-1">Waiting for someone to start writing...</p>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Word Count & Stats -->
      <div class="p-4 border-t border-white/10 bg-black/20">
        <div class="flex items-center justify-between text-white/60 text-sm">
          <div class="flex items-center gap-4">
            <span><%= String.length(@workspace_state.text.content) %> characters</span>
            <span><%= length(String.split(@workspace_state.text.content, ~r/\s+/, trim: true)) %> words</span>
            <span><%= length(String.split(@workspace_state.text.content, "\n")) %> lines</span>
          </div>

          <div class="flex items-center gap-2">
            <%= if map_size(@workspace_state.text.cursors) > 1 do %>
              <div class="flex items-center gap-1 text-purple-300">
                <div class="w-2 h-2 bg-purple-400 rounded-full animate-pulse"></div>
                <span class="text-xs"><%= map_size(@workspace_state.text.cursors) - 1 %> editing</span>
              </div>
            <% end %>

            <span class="text-xs">
              Last synced: <%= Calendar.strftime(@last_sync, "%H:%M:%S") %>
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to get username from collaborators
  defp get_username_from_collaborators(user_id, collaborators) do
    case Enum.find(collaborators, fn c -> to_string(c.user_id) == to_string(user_id) end) do
      %{username: username} -> username
      _ -> "User #{user_id}"
    end
  end
end
