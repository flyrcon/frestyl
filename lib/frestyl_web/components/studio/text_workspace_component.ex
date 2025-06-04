defmodule FrestylWeb.Studio.TextWorkspaceComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Chat

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      cursor_position: %{line: 0, column: 0},
      selection: nil,
      is_typing: false,
      show_format_toolbar: false,
      word_count: 0,
      character_count: 0,
      line_count: 1,
      last_sync: DateTime.utc_now(),
      collaboration_mode: true,
      zen_mode: false,
      auto_save_enabled: true
    )}
  end

  @impl true
  def update(assigns, socket) do
    # Calculate text statistics
    content = assigns.workspace_state.text.content
    stats = calculate_text_stats(content)

    {:ok, assign(socket, Map.merge(assigns, stats))}
  end

  @impl true
  def handle_event("text_update", %{"content" => content, "cursor" => cursor, "selection" => selection}, socket) do
    if can_edit_text?(socket.assigns.permissions) do
      # Send text update with OT to parent StudioLive
      send(self(), {:text_update_ot, %{
        content: content,
        cursor: cursor,
        selection: selection,
        user_id: socket.assigns.current_user.id
      }})

      stats = calculate_text_stats(content)

      {:noreply, assign(socket, Map.merge(%{
        cursor_position: cursor,
        selection: selection,
        is_typing: content != socket.assigns.workspace_state.text.content,
        last_sync: DateTime.utc_now()
      }, stats))}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cursor_update", %{"cursor" => cursor, "selection" => selection}, socket) do
    # Send cursor position to other collaborators
    send(self(), {:text_cursor_update, %{
      cursor: cursor,
      selection: selection,
      user_id: socket.assigns.current_user.id
    }})

    {:noreply, assign(socket, cursor_position: cursor, selection: selection)}
  end

  @impl true
  def handle_event("toggle_format_toolbar", _, socket) do
    {:noreply, assign(socket, show_format_toolbar: !socket.assigns.show_format_toolbar)}
  end

  @impl true
  def handle_event("toggle_collaboration_mode", _, socket) do
    {:noreply, assign(socket, collaboration_mode: !socket.assigns.collaboration_mode)}
  end

  @impl true
  def handle_event("toggle_zen_mode", _, socket) do
    {:noreply, assign(socket, zen_mode: !socket.assigns.zen_mode)}
  end

  @impl true
  def handle_event("export_text", %{"format" => format}, socket) do
    content = socket.assigns.workspace_state.text.content
    filename = "lyrics_#{Date.utc_today()}"

    case format do
      "txt" ->
        {:noreply, push_event(socket, "download_file", %{
          content: content,
          filename: "#{filename}.txt",
          mimetype: "text/plain"
        })}
      "md" ->
        {:noreply, push_event(socket, "download_file", %{
          content: content,
          filename: "#{filename}.md",
          mimetype: "text/markdown"
        })}
      "pdf" ->
        # Would need to implement PDF generation
        {:noreply, put_flash(socket, :info, "PDF export coming soon!")}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("insert_template", %{"template" => template}, socket) do
    template_content = get_template_content(template)

    {:noreply, push_event(socket, "insert_text_template", %{
      content: template_content
    })}
  end

  @impl true
  def handle_event("find_and_replace", %{"find" => find, "replace" => replace}, socket) do
    current_content = socket.assigns.workspace_state.text.content
    new_content = String.replace(current_content, find, replace, global: true)

    if new_content != current_content do
      send(self(), {:text_update_ot, %{
        content: new_content,
        cursor: socket.assigns.cursor_position,
        selection: nil,
        user_id: socket.assigns.current_user.id
      }})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :info, "No matches found")}
    end
  end

  defp can_edit_text?(permissions), do: :edit_text in permissions

  defp calculate_text_stats(content) do
    %{
      character_count: String.length(content),
      word_count: content |> String.split(~r/\s+/, trim: true) |> length(),
      line_count: content |> String.split("\n") |> length()
    }
  end

  defp get_template_content("verse_chorus") do
    """
    [Verse 1]


    [Chorus]


    [Verse 2]


    [Chorus]


    [Bridge]


    [Chorus]

    """
  end

  defp get_template_content("simple_song") do
    """
    [Intro]


    [Verse]


    [Chorus]


    [Outro]

    """
  end

  defp get_template_content("rap_structure") do
    """
    [Intro]


    [Verse 1]


    [Hook]


    [Verse 2]


    [Hook]


    [Bridge]


    [Hook]


    [Outro]

    """
  end

  defp get_template_content(_), do: ""

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "h-full flex flex-col bg-black/20 backdrop-blur-sm transition-all duration-300",
      @zen_mode && "bg-black/80"
    ]}>
      <!-- Text Workspace Header -->
      <div class={[
        "flex items-center justify-between p-4 border-b border-white/10 bg-black/30 transition-all duration-300",
        @zen_mode && "opacity-0 pointer-events-none"
      ]}>
        <div class="flex items-center gap-3">
          <div class="p-2 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl">
            <svg class="h-5 w-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
          </div>
          <div>
            <h3 class="text-white font-bold text-lg">Lyrics Editor</h3>
            <p class="text-white/60 text-sm">
              <%= @word_count %> words • <%= @character_count %> characters • <%= @line_count %> lines
            </p>
          </div>
        </div>

        <div class="flex items-center gap-3">
          <!-- Collaboration Status -->
          <%= if @collaboration_mode do %>
            <div class="flex items-center gap-2">
              <%= if map_size(@workspace_state.text.cursors) > 1 do %>
                <div class="flex -space-x-1">
                  <%= for {user_id, _cursor} <- Enum.take(@workspace_state.text.cursors, 3) do %>
                    <%= if user_id != to_string(@current_user.id) do %>
                      <% username = get_username_from_collaborators(user_id, @collaborators) %>
                      <div class="w-6 h-6 rounded-full bg-gradient-to-br from-purple-500 to-pink-600 flex items-center justify-center text-white text-xs font-bold border-2 border-black/20">
                        <%= String.at(username, 0) %>
                      </div>
                    <% end %>
                  <% end %>
                </div>
              <% end %>

              <div class="text-white/60 text-sm">
                <%= case map_size(@workspace_state.text.cursors) - 1 do %>
                  <% 0 -> %>Writing solo
                  <% 1 -> %>1 person editing
                  <% n -> %><%= n %> people editing
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Sync Status -->
          <div class="flex items-center gap-2">
            <%= if length(@pending_operations) > 0 do %>
              <div class="flex items-center gap-1 text-yellow-300 text-sm">
                <svg class="h-4 w-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                </svg>
                <span>Syncing...</span>
              </div>
            <% else %>
              <div class="flex items-center gap-1 text-green-300 text-sm">
                <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                <span>Synced</span>
              </div>
            <% end %>
          </div>

          <!-- Toolbar Controls -->
          <div class="flex items-center gap-2">
            <button
              phx-click="toggle_format_toolbar"
              phx-target={@myself}
              class={[
                "p-2 rounded-lg transition-colors",
                @show_format_toolbar && "bg-white/20 text-white" || "text-white/60 hover:text-white hover:bg-white/10"
              ]}
              title="Format toolbar"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM7 3H5a2 2 0 00-2 2v12a4 4 0 004 4h2V3zM21 21v-9a2 2 0 00-2-2h-4a2 2 0 00-2 2v9" />
              </svg>
            </button>

            <button
              phx-click="toggle_collaboration_mode"
              phx-target={@myself}
              class={[
                "p-2 rounded-lg transition-colors",
                @collaboration_mode && "bg-purple-500/20 text-purple-300" || "text-white/60 hover:text-white hover:bg-white/10"
              ]}
              title="Toggle collaboration"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 515.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 919.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
              </svg>
            </button>

            <button
              phx-click="toggle_zen_mode"
              phx-target={@myself}
              class={[
                "p-2 rounded-lg transition-colors",
                @zen_mode && "bg-indigo-500/20 text-indigo-300" || "text-white/60 hover:text-white hover:bg-white/10"
              ]}
              title="Zen mode"
            >
              <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Format Toolbar -->
      <%= if @show_format_toolbar and !@zen_mode do %>
        <div class="flex items-center justify-between p-3 border-b border-white/10 bg-black/20">
          <div class="flex items-center gap-2">
            <!-- Templates -->
            <div class="relative group">
              <button class="flex items-center gap-2 px-3 py-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors text-sm">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z" />
                </svg>
                Templates
              </button>

              <div class="absolute top-full left-0 mt-1 hidden group-hover:block bg-black/95 backdrop-blur-xl border border-white/20 rounded-lg shadow-xl min-w-48 z-10">
                <button
                  phx-click="insert_template"
                  phx-value-template="verse_chorus"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  Verse-Chorus Structure
                </button>
                <button
                  phx-click="insert_template"
                  phx-value-template="simple_song"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  Simple Song
                </button>
                <button
                  phx-click="insert_template"
                  phx-value-template="rap_structure"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  Rap Structure
                </button>
              </div>
            </div>

            <div class="w-px h-6 bg-white/20"></div>

            <!-- Export Options -->
            <div class="relative group">
              <button class="flex items-center gap-2 px-3 py-2 text-white/70 hover:text-white hover:bg-white/10 rounded-lg transition-colors text-sm">
                <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                Export
              </button>

              <div class="absolute top-full left-0 mt-1 hidden group-hover:block bg-black/95 backdrop-blur-xl border border-white/20 rounded-lg shadow-xl min-w-32 z-10">
                <button
                  phx-click="export_text"
                  phx-value-format="txt"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  Text (.txt)
                </button>
                <button
                  phx-click="export_text"
                  phx-value-format="md"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  Markdown (.md)
                </button>
                <button
                  phx-click="export_text"
                  phx-value-format="pdf"
                  phx-target={@myself}
                  class="w-full text-left px-3 py-2 text-white/80 hover:text-white hover:bg-white/10 transition-colors text-sm"
                >
                  PDF
                </button>
              </div>
            </div>
          </div>

          <div class="text-white/60 text-sm">
            Version <%= @workspace_state.text.version %>
          </div>
        </div>
      <% end %>

      <!-- Text Editor Area -->
      <div class="flex-1 relative overflow-hidden">
        <%= if can_edit_text?(@permissions) do %>
          <textarea
            id="text-editor"
            phx-hook="TextEditorOT"
            phx-target={@myself}
            class={[
              "w-full h-full bg-transparent text-white p-6 resize-none focus:outline-none transition-all duration-300",
              @zen_mode && "p-12 text-xl leading-relaxed",
              !@zen_mode && "text-base leading-relaxed"
            ]}
            placeholder="Start writing your lyrics..."
            autocomplete="off"
            spellcheck="true"
          ><%= @workspace_state.text.content %></textarea>

          <!-- Collaboration Cursors -->
          <%= if @collaboration_mode do %>
            <%= for {user_id, cursor_data} <- @workspace_state.text.cursors do %>
              <%= if user_id != to_string(@current_user.id) do %>
                <% username = get_username_from_collaborators(user_id, @collaborators) %>
                <div
                  id={"cursor-#{user_id}"}
                  class="absolute pointer-events-none z-10 transition-all duration-200"
                  style={"transform: translate(#{cursor_data.x || 0}px, #{cursor_data.y || 0}px);"}
                  phx-hook="CollaboratorCursor"
                  data-user-id={user_id}
                >
                  <div class="w-0.5 h-6 bg-purple-500 animate-pulse"></div>
                  <div class="absolute -top-7 left-0 bg-purple-500 text-white text-xs px-2 py-1 rounded whitespace-nowrap shadow-lg">
                    <%= username %>
                  </div>
                </div>
              <% end %>
            <% end %>
          <% end %>

        <% else %>
          <!-- Read-only view -->
          <div class="w-full h-full overflow-auto p-6">
            <%= if @workspace_state.text.content != "" do %>
              <div class={[
                "text-white whitespace-pre-wrap font-mono transition-all duration-300",
                @zen_mode && "text-xl leading-relaxed p-6",
                !@zen_mode && "text-base leading-relaxed"
              ]}>
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

        <!-- Zen Mode Exit Button -->
        <%= if @zen_mode do %>
          <button
            phx-click="toggle_zen_mode"
            phx-target={@myself}
            class="fixed top-4 right-4 p-3 bg-black/50 backdrop-blur-sm rounded-full text-white/60 hover:text-white hover:bg-black/70 transition-all duration-200 z-20"
            title="Exit zen mode"
          >
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        <% end %>
      </div>

      <!-- Status Bar -->
      <%= if !@zen_mode do %>
        <div class="p-3 border-t border-white/10 bg-black/20">
          <div class="flex items-center justify-between text-white/60 text-sm">
            <div class="flex items-center gap-4">
              <span>Line <%= @cursor_position.line + 1 %>:<%= @cursor_position.column + 1 %></span>
              <span><%= @character_count %> characters</span>
              <span><%= @word_count %> words</span>
              <span><%= @line_count %> lines</span>
            </div>

            <div class="flex items-center gap-4">
              <%= if @auto_save_enabled do %>
                <div class="flex items-center gap-1 text-green-400">
                  <div class="w-2 h-2 bg-green-400 rounded-full"></div>
                  <span>Auto-saved</span>
                </div>
              <% end %>

              <span>Last synced: <%= Calendar.strftime(@last_sync, "%H:%M:%S") %></span>
            </div>
          </div>
        </div>
      <% end %>
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
