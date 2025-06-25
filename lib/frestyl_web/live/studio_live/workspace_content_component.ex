# lib/frestyl_web/live/studio_live/workspace_content_component.ex
defmodule FrestylWeb.StudioLive.WorkspaceContentComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 overflow-hidden" id="workspace-content">
      <%= case Map.get(assigns, :active_tool, "audio") do %>
        <% "audio" -> %>
          <.render_audio_workspace assigns={assigns} />

        <% tool when tool in ["text", "editor"] -> %>
          <.render_text_workspace assigns={assigns} />

        <% "audio_text" -> %>
          <.render_audio_text_workspace assigns={assigns} />

        <% "visual" -> %>
          <.render_visual_workspace assigns={assigns} />

        <% "midi" -> %>
          <.render_midi_workspace assigns={assigns} />

        <% _ -> %>
          <.render_default_workspace assigns={assigns} />
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Don't filter out legitimate assigns like active_tool
    # Only filter out the reserved LiveView keys
    clean_assigns = Map.drop(assigns, [:socket, :flash, :myself])
    {:ok, assign(socket, clean_assigns)}
  end

  @impl true
  def handle_info({:initialize_story_outline, outline_data}, socket) do
    # Update workspace state with new story outline
    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:story, :outline],
      outline_data
    )

    # Broadcast to collaborators
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:story_outline_initialized, outline_data, socket.assigns.current_user.id}
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_info({:update_story_outline, outline_data}, socket) do
    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:story, :outline],
      outline_data
    )

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:story_outline_updated, outline_data, socket.assigns.current_user.id}
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_info({:update_characters, characters_data}, socket) do
    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:story, :characters],
      characters_data
    )

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:story_characters_updated, characters_data, socket.assigns.current_user.id}
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_info({:update_world_bible, world_bible_data}, socket) do
    new_workspace_state = put_in(
      socket.assigns.workspace_state,
      [:story, :world_bible],
      world_bible_data
    )

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "studio:#{socket.assigns.session.id}",
      {:story_world_bible_updated, world_bible_data, socket.assigns.current_user.id}
    )

    {:noreply, assign(socket, workspace_state: new_workspace_state)}
  end

  @impl true
  def handle_info({:update_story_template, template}, socket) do
    # When template changes, reinitialize the outline with new structure
    send_update(FrestylWeb.StudioLive.StoryOutlineComponent,
      id: "story-outline",
      selected_template: template
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:open_character_editor, character_id}, socket) do
    # Could open a detailed character editing modal or switch to character tool
    send(self(), {:show_character_detail_modal, character_id})
    {:noreply, socket}
  end

  @impl true
  def handle_info({:open_world_entry_editor, entry_id}, socket) do
    # Could open a detailed world entry editing modal
    send(self(), {:show_world_entry_detail_modal, entry_id})
    {:noreply, socket}
  end

  defp ensure_story_workspace_state(workspace_state) do
    story_state = Map.get(workspace_state, :story, %{})

    default_story_state = %{
      outline: %{template: "three_act", sections: []},
      characters: [],
      world_bible: %{},
      timeline: %{events: []},
      comments: []
    }

    updated_story_state = Map.merge(default_story_state, story_state)
    Map.put(workspace_state, :story, updated_story_state)
  end

  # Audio Workspace Implementation
  defp render_audio_workspace(assigns) do
    tracks = get_in(assigns, [:workspace_state, :audio, :tracks]) || []
    assigns = assign(assigns, :tracks, tracks)

    ~H"""
    <div class="h-full flex flex-col bg-gray-900">
      <!-- Transport Controls -->
      <div class="flex items-center justify-between p-4 border-b border-gray-700 bg-gray-800">
        <div class="flex items-center space-x-4">
          <!-- Play/Pause/Stop -->
          <div class="flex items-center space-x-2">
            <%= if get_in(assigns, [:workspace_state, :audio, :playing]) do %>
              <button
                phx-click="audio_pause_playback"
                phx-target={assigns[:myself]}
                class="w-10 h-10 bg-yellow-600 hover:bg-yellow-700 rounded-full flex items-center justify-center text-white"
                title="Pause"
              >
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
                </svg>
              </button>
            <% else %>
              <button
                phx-click="audio_start_playback"
                phx-target={assigns[:myself]}
                class="w-10 h-10 bg-green-600 hover:bg-green-700 rounded-full flex items-center justify-center text-white"
                title="Play"
              >
                <svg class="w-5 h-5 ml-1" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              </button>
            <% end %>

            <button
              phx-click="audio_stop_playback"
              phx-target={assigns[:myself]}
              class="w-10 h-10 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
              title="Stop"
            >
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <rect x="6" y="6" width="12" height="12"/>
              </svg>
            </button>
          </div>

          <!-- Record Button -->
          <button
            phx-click="audio_toggle_recording"
            phx-target={assigns[:myself]}
            class={[
              "w-10 h-10 rounded-full flex items-center justify-center text-white border-2",
              get_in(assigns, [:workspace_state, :audio, :recording]) && "bg-red-600 border-red-400 animate-pulse" || "bg-gray-700 border-gray-500 hover:bg-red-600 hover:border-red-400"
            ]}
            title="Record"
          >
            <div class="w-4 h-4 bg-current rounded-full"></div>
          </button>

          <!-- Loop Toggle -->
          <button
            phx-click="audio_toggle_loop"
            phx-target={assigns[:myself]}
            class={[
              "px-3 py-2 rounded text-sm font-medium",
              get_in(assigns, [:workspace_state, :audio, :loop_enabled]) && "bg-indigo-600 text-white" || "bg-gray-700 text-gray-300 hover:bg-gray-600"
            ]}
            title="Loop"
          >
            Loop
          </button>
        </div>

        <!-- Timeline Position and BPM -->
        <div class="flex items-center space-x-6">
          <div class="text-white font-mono text-lg">
            <%= format_time(get_in(assigns, [:workspace_state, :audio, :current_time]) || 0) %>
          </div>

          <div class="flex items-center space-x-2">
            <label class="text-gray-400 text-sm">BPM:</label>
            <input
              type="number"
              min="60"
              max="200"
              value={get_in(assigns, [:workspace_state, :audio, :bpm]) || 120}
              phx-change="audio_set_bpm"
              phx-target={assigns[:myself]}
              class="w-16 bg-gray-700 border-gray-600 rounded text-white text-sm text-center"
            />
          </div>

          <!-- Zoom Controls -->
          <div class="flex items-center space-x-2">
            <button
              phx-click="audio_zoom_out"
              phx-target={assigns[:myself]}
              class="p-1 text-gray-400 hover:text-white"
              title="Zoom Out"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM13 10h-6" />
              </svg>
            </button>
            <span class="text-gray-400 text-sm"><%= round((get_in(assigns, [:workspace_state, :audio, :zoom_level]) || 1.0) * 100) %>%</span>
            <button
              phx-click="audio_zoom_in"
              phx-target={assigns[:myself]}
              class="p-1 text-gray-400 hover:text-white"
              title="Zoom In"
            >
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Timeline and Tracks -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Track Headers -->
        <div class="w-48 bg-gray-800 border-r border-gray-700 overflow-y-auto">
          <div class="p-3 border-b border-gray-700">
            <button
              phx-click="audio_add_track"
              phx-target={assigns[:myself]}
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-2 rounded text-sm font-medium"
            >
              + Add Track
            </button>
          </div>

          <%= if length(@tracks) == 0 do %>
            <div class="p-6 text-center">
              <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
              </svg>
              <p class="text-gray-500 text-sm">No tracks yet</p>
              <p class="text-xs text-gray-600 mt-1">Add your first track to start</p>
            </div>
          <% else %>
            <%= for track <- @tracks do %>
              <div class="p-3 border-b border-gray-700 hover:bg-gray-750">
                <div class="flex items-center justify-between mb-2">
                  <input
                    type="text"
                    value={track.name || "Untitled Track"}
                    phx-blur="audio_update_track_name"
                    phx-value-track-id={track.id}
                    phx-target={assigns[:myself]}
                    class="bg-transparent text-white text-sm font-medium border-none focus:outline-none focus:ring-1 focus:ring-indigo-500 rounded px-1"
                  />
                  <div class="flex items-center space-x-1">
                    <%= if Map.get(track, :recording, false) do %>
                      <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                    <% end %>
                    <%= if Map.get(track, :selected, false) do %>
                      <div class="w-2 h-2 bg-indigo-500 rounded-full"></div>
                    <% end %>
                  </div>
                </div>

                <div class="flex items-center space-x-2">
                  <!-- Mute -->
                  <button
                    phx-click="audio_toggle_track_mute"
                    phx-value-track-id={track.id}
                    phx-target={assigns[:myself]}
                    class={[
                      "w-6 h-6 rounded text-xs font-medium",
                      Map.get(track, :muted, false) && "bg-red-600 text-white" || "bg-gray-600 text-gray-300"
                    ]}
                    title="Mute"
                  >
                    M
                  </button>

                  <!-- Solo -->
                  <button
                    phx-click="audio_toggle_track_solo"
                    phx-value-track-id={track.id}
                    phx-target={assigns[:myself]}
                    class={[
                      "w-6 h-6 rounded text-xs font-medium",
                      Map.get(track, :solo, false) && "bg-yellow-600 text-white" || "bg-gray-600 text-gray-300"
                    ]}
                    title="Solo"
                  >
                    S
                  </button>

                  <!-- Record Arm -->
                  <button
                    phx-click="audio_toggle_track_record_arm"
                    phx-value-track-id={track.id}
                    phx-target={assigns[:myself]}
                    class={[
                      "w-6 h-6 rounded text-xs font-medium",
                      Map.get(track, :record_armed, false) && "bg-red-600 text-white" || "bg-gray-600 text-gray-300"
                    ]}
                    title="Record Arm"
                  >
                    R
                  </button>

                  <!-- Volume -->
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.01"
                    value={track.volume || 0.8}
                    phx-change="audio_update_track_volume"
                    phx-value-track-id={track.id}
                    phx-target={assigns[:myself]}
                    class="flex-1 h-2"
                  />
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Timeline Area -->
        <div class="flex-1 overflow-auto" id="audio-timeline" phx-hook="AudioTimeline">
          <!-- Time Ruler -->
          <div class="h-8 bg-gray-800 border-b border-gray-700 flex items-center px-4 text-xs text-gray-400 font-mono">
            <%= for minute <- 0..10 do %>
              <div class="flex-shrink-0 w-24 border-r border-gray-600 text-center">
                <%= format_time(minute * 60000) %>
              </div>
            <% end %>
          </div>

          <!-- Track Lanes -->
          <%= if length(@tracks) > 0 do %>
            <%= for track <- @tracks do %>
              <div class="h-20 border-b border-gray-700 relative" data-track-id={track.id}>
                <!-- Waveform/Clips Container -->
                <div class="absolute inset-0 p-2">
                  <%= for clip <- (track.clips || []) do %>
                    <div
                      class="absolute h-16 bg-indigo-600 bg-opacity-80 rounded border border-indigo-400 cursor-move"
                      style={"left: #{clip.start_time * 0.1}px; width: #{clip.duration * 0.1}px;"}
                      draggable="true"
                      phx-click="audio_select_clip"
                      phx-value-clip-id={clip.id}
                      phx-target={assigns[:myself]}
                    >
                      <div class="p-1">
                        <div class="text-xs text-white font-medium truncate">
                          <%= clip.name || "Audio Clip" %>
                        </div>
                        <div class="h-8 bg-indigo-700 bg-opacity-50 rounded mt-1">
                          <!-- Simplified waveform visualization -->
                          <div class="h-full flex items-center justify-around px-1">
                            <%= for _ <- 1..20 do %>
                              <div class="w-px bg-white opacity-60" style={"height: #{:rand.uniform(100)}%;"}></div>
                            <% end %>
                          </div>
                        </div>
                      </div>
                    </div>
                  <% end %>
                </div>

                <!-- Drop Zone for new clips -->
                <div
                  class="absolute inset-0 opacity-0 hover:opacity-100 bg-indigo-500 bg-opacity-20 border-2 border-dashed border-indigo-400 rounded m-2 flex items-center justify-center transition-opacity"
                  phx-drop-target={track.id}
                >
                  <span class="text-indigo-300 text-sm font-medium">Drop audio file here</span>
                </div>
              </div>
            <% end %>
          <% else %>
            <div class="flex-1 flex items-center justify-center">
              <div class="text-center">
                <svg class="w-16 h-16 mx-auto mb-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
                </svg>
                <h3 class="text-white text-lg font-medium mb-2">Audio Workspace</h3>
                <p class="text-gray-400 mb-4">Create tracks and record audio to get started</p>
                <button
                  phx-click="audio_add_track"
                  phx-target={assigns[:myself]}
                  class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded font-medium"
                >
                  Create Your First Track
                </button>
              </div>
            </div>
          <% end %>

          <!-- Playhead -->
          <div
            class="absolute top-0 bottom-0 w-px bg-red-500 z-10 pointer-events-none"
            style={"left: #{(get_in(assigns, [:workspace_state, :audio, :current_time]) || 0) * 0.1 + 192}px;"}
          >
            <div class="absolute -top-2 -left-2 w-4 h-4 bg-red-500 rotate-45"></div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Text Workspace Implementation
  defp render_text_workspace(assigns) do
    document = get_in(assigns, [:workspace_state, :text, :document])

    ~H"""
    <div class="h-full flex flex-col bg-white">
      <%= if document do %>
        <!-- Document Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
          <div class="flex items-center space-x-4">
            <input
              type="text"
              value={document.title || "Untitled Document"}
              phx-blur="text_update_document_title"
              phx-target={assigns[:myself]}
              class="text-lg font-semibold bg-transparent border-none focus:outline-none focus:ring-2 focus:ring-indigo-500 rounded px-2 py-1"
            />
            <span class="text-sm text-gray-500 bg-gray-200 px-2 py-1 rounded">
              <%= String.capitalize(document.document_type || "text") %>
            </span>
          </div>

          <div class="flex items-center space-x-3">
            <!-- Collaboration Status -->
            <div class="flex items-center space-x-2">
              <%= if MapSet.size(get_in(assigns, [:typing_users]) || MapSet.new()) > 0 do %>
                <div class="flex items-center space-x-1 text-blue-600">
                  <div class="flex space-x-1">
                    <div class="w-1 h-1 bg-blue-600 rounded-full animate-bounce"></div>
                    <div class="w-1 h-1 bg-blue-600 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
                    <div class="w-1 h-1 bg-blue-600 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                  </div>
                  <span class="text-xs"><%= MapSet.size(get_in(assigns, [:typing_users]) || MapSet.new()) %> typing</span>
                </div>
              <% end %>

              <!-- Collaborator Avatars -->
              <div class="flex -space-x-1">
                <%= for collaborator <- Enum.take(get_in(assigns, [:collaborators]) || [], 3) do %>
                  <%= if collaborator.user_id != get_in(assigns, [:current_user, :id]) do %>
                    <div class="w-6 h-6 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 border-2 border-white flex items-center justify-center text-white text-xs font-medium">
                      <%= String.at(collaborator.username || "?", 0) %>
                    </div>
                  <% end %>
                <% end %>
              </div>
            </div>

            <!-- Document Actions -->
            <div class="flex items-center space-x-2">
              <button
                phx-click="text_export_document"
                phx-target={assigns[:myself]}
                class="text-sm text-gray-600 hover:text-gray-900 px-3 py-1 border border-gray-300 rounded hover:bg-gray-50"
              >
                Export
              </button>
              <button
                phx-click="text_save_document"
                phx-target={assigns[:myself]}
                class="text-sm bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1 rounded"
              >
                Save
              </button>
            </div>
          </div>
        </div>

        <!-- Main Editor -->
        <div class="flex-1 relative">
          <div class="h-full overflow-y-auto p-8" id="text-editor-container" phx-hook="TextEditor">
            <div class="max-w-4xl mx-auto">
              <!-- Collaborative Cursors Overlay -->
              <div class="absolute inset-0 pointer-events-none z-10">
                <%= for {user_id, cursor_data} <- (get_in(assigns, [:workspace_state, :text, :cursors]) || %{}) do %>
                  <%= if user_id != to_string(get_in(assigns, [:current_user, :id])) do %>
                    <div
                      class="absolute w-0.5 bg-opacity-75 z-20"
                      style={"height: 20px; background-color: #{get_user_color(user_id)}; top: #{cursor_data[:line] || 0}px; left: #{cursor_data[:col] || 0}px;"}
                    >
                      <div
                        class="absolute -top-6 left-0 px-2 py-1 rounded text-white text-xs whitespace-nowrap"
                        style={"background-color: #{get_user_color(user_id)};"}
                      >
                        <%= get_username_for_user_id(user_id, assigns) %>
                      </div>
                    </div>
                  <% end %>
                <% end %>
              </div>

              <!-- Document Content -->
              <textarea
                class="w-full min-h-full border-none resize-none focus:outline-none text-gray-900 text-base leading-7"
                style="font-family: 'Georgia', serif; line-height: 1.8;"
                placeholder="Start writing your document..."
                phx-blur="text_update_content"
                phx-keyup="text_update_content"
                phx-focus="text_editor_focus"
                phx-target={assigns[:myself]}
                phx-debounce="300"
              ><%= get_in(assigns, [:workspace_state, :text, :content]) || "" %></textarea>
            </div>
          </div>
        </div>

        <!-- Status Bar -->
        <div class="flex items-center justify-between p-2 border-t border-gray-200 bg-gray-50 text-xs text-gray-600">
          <div class="flex items-center space-x-4">
            <span>
              <%= String.length(get_in(assigns, [:workspace_state, :text, :content]) || "") %> characters
            </span>
            <span>
              <%= (get_in(assigns, [:workspace_state, :text, :content]) || "") |> String.split() |> length() %> words
            </span>
            <span>
              Line <%= get_current_line(assigns) %>
            </span>
          </div>
          <div class="flex items-center space-x-4">
            <%= if length(get_in(assigns, [:pending_operations]) || []) > 0 do %>
              <span class="text-yellow-600">
                <%= length(get_in(assigns, [:pending_operations]) || []) %> changes syncing...
              </span>
            <% end %>
            <span class="text-green-600">✓ Auto-saved</span>
            <span>Last saved: <%= format_last_saved(document.updated_at) %></span>
          </div>
        </div>
      <% else %>
        <!-- No Document - Creation Interface -->
        <div class="h-full flex items-center justify-center bg-gray-50">
          <div class="text-center max-w-md">
            <svg class="w-16 h-16 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
            </svg>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Start Writing</h3>
            <p class="text-gray-600 mb-6">Create a new document or open an existing one</p>

            <div class="space-y-4">
              <button
                phx-click="text_create_document"
                phx-value-type="plain_text"
                phx-target={assigns[:myself]}
                class="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 px-4 rounded-lg font-medium"
              >
                Create New Document
              </button>

              <div class="grid grid-cols-2 gap-3">
                <button
                  phx-click="text_create_document"
                  phx-value-type="blog_post"
                  phx-target={assigns[:myself]}
                  class="p-3 border border-gray-300 rounded-lg hover:border-indigo-300 hover:bg-indigo-50"
                >
                  <div class="text-2xl mb-1">📝</div>
                  <div class="text-sm font-medium">Blog Post</div>
                </button>
                <button
                  phx-click="text_create_document"
                  phx-value-type="book_chapter"
                  phx-target={assigns[:myself]}
                  class="p-3 border border-gray-300 rounded-lg hover:border-indigo-300 hover:bg-indigo-50"
                >
                  <div class="text-2xl mb-1">📚</div>
                  <div class="text-sm font-medium">Book Chapter</div>
                </button>
              </div>

              <button
                phx-click="text_load_existing"
                phx-target={assigns[:myself]}
                class="text-indigo-600 hover:text-indigo-700 text-sm font-medium"
              >
                Or open an existing document →
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Audio-Text Sync Workspace Implementation
  defp render_audio_text_workspace(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-gradient-to-br from-gray-900 to-indigo-900">
      <!-- Audio-Text Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-700 bg-gray-800 bg-opacity-70">
        <div class="flex items-center space-x-4">
          <h2 class="text-white font-semibold">
            <%= if get_in(assigns, [:workspace_state, :audio_text, :mode]) == "lyrics_with_audio" do %>
              🎵 Lyrics Studio
            <% else %>
              🎙️ Script Studio
            <% end %>
          </h2>

          <!-- Mode Switcher -->
          <select
            phx-change="audio_text_set_mode"
            phx-target={assigns[:myself]}
            class="bg-gray-700 border-gray-600 text-white rounded text-sm"
          >
            <option value="lyrics_with_audio" selected={get_in(assigns, [:workspace_state, :audio_text, :mode]) == "lyrics_with_audio"}>
              Lyrics with Audio
            </option>
            <option value="audio_with_script" selected={get_in(assigns, [:workspace_state, :audio_text, :mode]) == "audio_with_script"}>
              Audio with Script
            </option>
          </select>
        </div>

        <div class="flex items-center space-x-4">
          <!-- Sync Status -->
          <%= if get_in(assigns, [:workspace_state, :audio_text, :sync_enabled]) do %>
            <div class="flex items-center space-x-2 text-green-400">
              <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
              <span class="text-sm">Sync Active</span>
            </div>
          <% else %>
            <span class="text-gray-400 text-sm">Sync Disabled</span>
          <% end %>

          <!-- BPM Display -->
          <%= if get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :enabled]) do %>
            <div class="text-purple-400 text-sm">
              🎵 <%= get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :bpm]) || 120 %> BPM
            </div>
          <% end %>

          <!-- Sync Controls -->
          <div class="flex items-center space-x-2">
            <button
              phx-click="audio_text_toggle_sync"
              phx-target={assigns[:myself]}
              class={[
                "px-3 py-1 rounded text-sm font-medium",
                get_in(assigns, [:workspace_state, :audio_text, :sync_enabled]) && "bg-green-600 text-white" || "bg-gray-600 text-gray-300"
              ]}
            >
              Sync
            </button>
            <button
              phx-click="audio_text_detect_beats"
              phx-target={assigns[:myself]}
              class="px-3 py-1 bg-purple-600 hover:bg-purple-700 text-white rounded text-sm font-medium"
            >
              Detect Beats
            </button>
          </div>
        </div>
      </div>

      <!-- Main Workspace Layout -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Text/Script Panel -->
        <div class="w-1/2 border-r border-gray-700 flex flex-col">
          <!-- Text Controls -->
          <div class="p-3 border-b border-gray-700 bg-gray-800 bg-opacity-50">
            <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
               <button
                 phx-click="audio_text_add_block"
                 phx-value-type="verse"
                 phx-target={assigns[:myself]}
                 class="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-2 py-1 rounded"
               >
                 + Verse
               </button>
               <button
                 phx-click="audio_text_add_block"
                 phx-value-type="chorus"
                 phx-target={assigns[:myself]}
                 class="text-xs bg-purple-600 hover:bg-purple-700 text-white px-2 py-1 rounded"
               >
                 + Chorus
               </button>
               <button
                 phx-click="audio_text_add_block"
                 phx-value-type="bridge"
                 phx-target={assigns[:myself]}
                 class="text-xs bg-green-600 hover:bg-green-700 text-white px-2 py-1 rounded"
               >
                 + Bridge
               </button>
             </div>

             <div class="flex items-center space-x-2">
               <button
                 phx-click="audio_text_auto_align"
                 phx-target={assigns[:myself]}
                 class="text-xs bg-yellow-600 hover:bg-yellow-700 text-white px-2 py-1 rounded"
                 disabled={!get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :enabled])}
               >
                 Auto-Align
               </button>
             </div>
           </div>
         </div>

         <!-- Text Content -->
         <div class="flex-1 overflow-y-auto p-4 space-y-4" id="audio-text-content">
           <%= for block <- (get_in(assigns, [:workspace_state, :audio_text, :text_sync, :blocks]) || []) do %>
             <div
               class={[
                 "p-4 rounded-lg border-2 cursor-pointer transition-all",
                 block.id == get_in(assigns, [:workspace_state, :audio_text, :current_text_block]) && "border-indigo-500 bg-indigo-900 bg-opacity-30" || "border-gray-600 bg-gray-800 bg-opacity-50 hover:border-gray-500"
               ]}
               phx-click="audio_text_select_block"
               phx-value-block-id={block.id}
               phx-target={assigns[:myself]}
             >
               <div class="flex items-center justify-between mb-2">
                 <div class="flex items-center space-x-2">
                   <span class={[
                     "text-xs font-medium px-2 py-1 rounded",
                     get_block_type_color(block.type)
                   ]}>
                     <%= String.capitalize(block.type) %>
                   </span>
                   <%= if block.sync_point do %>
                     <span class="text-xs text-green-400">
                       ⏰ <%= format_time(block.sync_point.start_time) %>
                     </span>
                   <% end %>
                 </div>

                 <div class="flex items-center space-x-1">
                   <button
                     phx-click="audio_text_sync_block"
                     phx-value-block-id={block.id}
                     phx-target={assigns[:myself]}
                     class="text-gray-400 hover:text-green-400 text-xs"
                     title="Sync to current time"
                   >
                     🎯
                   </button>
                   <button
                     phx-click="audio_text_delete_block"
                     phx-value-block-id={block.id}
                     phx-target={assigns[:myself]}
                     class="text-gray-400 hover:text-red-400 text-xs"
                     title="Delete block"
                   >
                     🗑️
                   </button>
                 </div>
               </div>

               <textarea
                 class="w-full bg-transparent text-white resize-none border-none focus:outline-none"
                 rows="3"
                 placeholder="Enter lyrics or script content..."
                 phx-blur="audio_text_update_block"
                 phx-value-block-id={block.id}
                 phx-target={assigns[:myself]}
               ><%= block.content %></textarea>
             </div>
           <% end %>

           <!-- Add Block Button -->
           <%= if length(get_in(assigns, [:workspace_state, :audio_text, :text_sync, :blocks]) || []) == 0 do %>
             <div class="text-center py-8">
               <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                 <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
               </svg>
               <p class="text-gray-400 mb-4">No text blocks yet</p>
               <button
                 phx-click="audio_text_add_block"
                 phx-value-type="verse"
                 phx-target={assigns[:myself]}
                 class="bg-indigo-600 hover:bg-indigo-700 text-white px-4 py-2 rounded font-medium"
               >
                 Add Your First <%= if get_in(assigns, [:workspace_state, :audio_text, :mode]) == "lyrics_with_audio", do: "Verse", else: "Scene" %>
               </button>
             </div>
           <% end %>
         </div>
       </div>

       <!-- Audio Timeline Panel -->
       <div class="w-1/2 flex flex-col">
         <!-- Transport Controls -->
         <div class="p-3 border-b border-gray-700 bg-gray-800 bg-opacity-50">
           <div class="flex items-center justify-between">
             <div class="flex items-center space-x-3">
               <button
                 phx-click="audio_text_play"
                 phx-target={assigns[:myself]}
                 class="w-8 h-8 bg-green-600 hover:bg-green-700 rounded-full flex items-center justify-center text-white"
               >
                 ▶️
               </button>
               <button
                 phx-click="audio_text_pause"
                 phx-target={assigns[:myself]}
                 class="w-8 h-8 bg-yellow-600 hover:bg-yellow-700 rounded-full flex items-center justify-center text-white"
               >
                 ⏸️
               </button>
               <button
                 phx-click="audio_text_stop"
                 phx-target={assigns[:myself]}
                 class="w-8 h-8 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
               >
                 ⏹️
               </button>
             </div>

             <div class="flex items-center space-x-4">
               <span class="text-white font-mono">
                 <%= format_time(get_in(assigns, [:workspace_state, :audio_text, :timeline, :current_position]) || 0) %>
               </span>
               <span class="text-gray-400">/</span>
               <span class="text-gray-400 font-mono">
                 <%= format_time(get_in(assigns, [:workspace_state, :audio_text, :timeline, :duration]) || 0) %>
               </span>
             </div>
           </div>
         </div>

         <!-- Synchronized Timeline -->
         <div class="flex-1 overflow-auto bg-gray-800 bg-opacity-30" id="audio-text-timeline" phx-hook="AudioTextTimeline">
           <!-- Time ruler -->
           <div class="h-8 bg-gray-700 border-b border-gray-600 flex items-center px-4 text-xs text-gray-400 font-mono">
             <%= for second <- 0..60 do %>
               <div class="flex-shrink-0 w-24 border-r border-gray-600 text-center">
                 <%= format_time(second * 1000) %>
               </div>
             <% end %>
           </div>

           <!-- Audio waveform -->
           <div class="h-24 bg-gray-800 border-b border-gray-600 relative p-2">
             <div class="h-full bg-gray-700 rounded flex items-center justify-around px-2">
               <!-- Simplified waveform -->
               <%= for i <- 1..100 do %>
                 <div
                   class="w-px bg-indigo-400 opacity-70"
                   style={"height: #{:rand.uniform(80)}%;"}
                 ></div>
               <% end %>
             </div>

             <!-- Beat markers -->
             <%= for beat <- (get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :detected_beats]) || []) do %>
               <div
                 class="absolute top-0 bottom-0 w-px bg-purple-500 opacity-75"
                 style={"left: #{beat.time * 0.4}px;"}
                 title={"Beat at #{format_time(beat.time)}"}
               ></div>
             <% end %>

             <!-- Sync points -->
             <%= for sync_point <- (get_in(assigns, [:workspace_state, :audio_text, :timeline, :sync_points]) || []) do %>
               <div
                 class="absolute top-0 bottom-0 w-0.5 bg-green-500"
                 style={"left: #{sync_point.start_time * 0.4}px;"}
               >
                 <div class="absolute -top-1 -left-2 w-4 h-4 bg-green-500 rounded-full"></div>
                 <div class="absolute top-6 -left-8 bg-green-500 text-white text-xs px-1 rounded whitespace-nowrap">
                   <%= sync_point.block_type %>
                 </div>
               </div>
             <% end %>

             <!-- Playhead -->
             <div
               class="absolute top-0 bottom-0 w-px bg-red-500 z-10"
               style={"left: #{(get_in(assigns, [:workspace_state, :audio_text, :timeline, :current_position]) || 0) * 0.4}px;"}
             >
               <div class="absolute -top-2 -left-2 w-4 h-4 bg-red-500 rotate-45"></div>
             </div>
           </div>

           <!-- Text block timeline -->
           <div class="min-h-32 p-4">
             <div class="text-xs text-gray-400 mb-2">Text Blocks Timeline</div>
             <div class="relative h-16 bg-gray-700 bg-opacity-50 rounded">
               <%= for block <- (get_in(assigns, [:workspace_state, :audio_text, :text_sync, :blocks]) || []) do %>
                 <%= if block.sync_point do %>
                   <div
                     class={[
                       "absolute h-12 rounded border-2 cursor-pointer",
                       get_block_timeline_color(block.type)
                     ]}
                     style={"left: #{block.sync_point.start_time * 0.4}px; width: #{(block.sync_point.duration || 10000) * 0.4}px;"}
                     phx-click="audio_text_select_block"
                     phx-value-block-id={block.id}
                     phx-target={assigns[:myself]}
                     title={block.content}
                   >
                     <div class="p-1 text-xs text-white font-medium truncate">
                       <%= String.capitalize(block.type) %>
                     </div>
                   </div>
                 <% end %>
               <% end %>
             </div>
           </div>
         </div>
       </div>
     </div>

     <!-- Bottom Panel - Recording/Analysis -->
     <div class="h-32 border-t border-gray-700 bg-gray-800 bg-opacity-50 p-4">
       <div class="flex items-center justify-between h-full">
         <div class="flex items-center space-x-6">
           <!-- Recording Controls -->
           <div class="flex items-center space-x-2">
             <button
               phx-click="audio_text_start_recording"
               phx-target={assigns[:myself]}
               class="w-10 h-10 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
             >
               ⚫
             </button>
             <span class="text-gray-400 text-sm">Record with sync</span>
           </div>

           <!-- Auto-scroll toggle -->
           <label class="flex items-center space-x-2 text-gray-400 text-sm">
             <input
               type="checkbox"
               checked={get_in(assigns, [:workspace_state, :audio_text, :text_sync, :auto_scroll])}
               phx-click="audio_text_toggle_auto_scroll"
               phx-target={assigns[:myself]}
               class="rounded border-gray-600 text-indigo-600"
             />
             <span>Auto-scroll text</span>
           </label>

           <!-- Highlight current toggle -->
           <label class="flex items-center space-x-2 text-gray-400 text-sm">
             <input
               type="checkbox"
               checked={get_in(assigns, [:workspace_state, :audio_text, :text_sync, :highlight_current])}
               phx-click="audio_text_toggle_highlight"
               phx-target={assigns[:myself]}
               class="rounded border-gray-600 text-indigo-600"
             />
             <span>Highlight current</span>
           </label>
         </div>

         <!-- Beat Detection Results -->
         <%= if get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :enabled]) do %>
           <div class="text-right">
             <div class="text-sm text-purple-400">
               Beat Detection: <%= get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :confidence]) || 0 %>% confidence
             </div>
             <div class="text-xs text-gray-400">
               <%= length(get_in(assigns, [:workspace_state, :audio_text, :beat_detection, :detected_beats]) || []) %> beats detected
             </div>
           </div>
         <% end %>
       </div>
     </div>
   </div>
   """
 end

 # Visual Workspace Implementation
 defp render_visual_workspace(assigns) do
   ~H"""
   <div class="h-full flex flex-col bg-gray-100">
     <!-- Visual Tools Header -->
     <div class="flex items-center justify-between p-4 border-b border-gray-300 bg-white">
       <div class="flex items-center space-x-4">
         <h2 class="text-gray-900 font-semibold">Visual Workspace</h2>

         <!-- Tool Palette -->
         <div class="flex items-center space-x-2">
           <%= for {tool, icon, label} <- [
             {"brush", "✏️", "Brush"},
             {"pen", "🖊️", "Pen"},
             {"eraser", "🧽", "Eraser"},
             {"shapes", "🔷", "Shapes"},
             {"text", "📝", "Text"}
           ] do %>
             <button
               phx-click="visual_set_tool"
               phx-value-tool={tool}
               phx-target={assigns[:myself]}
               class={[
                 "p-2 rounded border-2 transition-colors",
                 get_in(assigns, [:workspace_state, :visual, :tool]) == tool && "border-indigo-500 bg-indigo-50" || "border-gray-300 hover:border-gray-400"
               ]}
               title={label}
             >
               <span class="text-lg"><%= icon %></span>
             </button>
           <% end %>
         </div>
       </div>

       <div class="flex items-center space-x-4">
         <!-- Color Picker -->
         <div class="flex items-center space-x-2">
           <label class="text-sm text-gray-600">Color:</label>
           <input
             type="color"
             value={get_in(assigns, [:workspace_state, :visual, :color]) || "#4f46e5"}
             phx-change="visual_set_color"
             phx-target={assigns[:myself]}
             class="w-8 h-8 rounded border border-gray-300"
           />
         </div>

         <!-- Brush Size -->
         <div class="flex items-center space-x-2">
           <label class="text-sm text-gray-600">Size:</label>
           <input
             type="range"
             min="1"
             max="50"
             value={get_in(assigns, [:workspace_state, :visual, :brush_size]) || 5}
             phx-change="visual_set_brush_size"
             phx-target={assigns[:myself]}
             class="w-20"
           />
           <span class="text-sm text-gray-600 w-8"><%= get_in(assigns, [:workspace_state, :visual, :brush_size]) || 5 %>px</span>
         </div>

         <!-- Actions -->
         <div class="flex items-center space-x-2">
           <button
             phx-click="visual_clear_canvas"
             phx-target={assigns[:myself]}
             class="text-sm text-gray-600 hover:text-gray-900 px-3 py-1 border border-gray-300 rounded hover:bg-gray-50"
           >
             Clear
           </button>
           <button
             phx-click="visual_save_canvas"
             phx-target={assigns[:myself]}
             class="text-sm bg-indigo-600 hover:bg-indigo-700 text-white px-3 py-1 rounded"
           >
             Save
           </button>
         </div>
       </div>
     </div>

     <!-- Canvas Area -->
     <div class="flex-1 relative overflow-hidden">
       <canvas
         id="visual-canvas"
         class="absolute inset-0 w-full h-full cursor-crosshair"
         phx-hook="VisualCanvas"
         data-tool={get_in(assigns, [:workspace_state, :visual, :tool]) || "brush"}
         data-color={get_in(assigns, [:workspace_state, :visual, :color]) || "#4f46e5"}
         data-brush-size={get_in(assigns, [:workspace_state, :visual, :brush_size]) || 5}
       ></canvas>

       <!-- Collaboration Cursors -->
       <%= for {user_id, cursor_data} <- (get_in(assigns, [:workspace_state, :visual, :cursors]) || %{}) do %>
         <%= if user_id != to_string(get_in(assigns, [:current_user, :id])) do %>
           <div
             class="absolute w-4 h-4 pointer-events-none z-10"
             style={"left: #{cursor_data.x}px; top: #{cursor_data.y}px; color: #{get_user_color(user_id)};"}
           >
             <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
               <path d="M6 2l3 6h5l-8 14-2-7-6-1z"/>
             </svg>
             <div class="absolute top-4 left-4 bg-black bg-opacity-75 text-white text-xs px-1 rounded whitespace-nowrap">
               <%= get_username_for_user_id(user_id, assigns) %>
             </div>
           </div>
         <% end %>
       <% end %>
     </div>

     <!-- Layers Panel -->
     <div class="h-32 border-t border-gray-300 bg-white p-4">
       <div class="text-sm text-gray-600 mb-2">Elements</div>
       <div class="flex space-x-2 overflow-x-auto">
         <%= for element <- (get_in(assigns, [:workspace_state, :visual, :elements]) || []) do %>
           <div class="flex-shrink-0 w-16 h-16 bg-gray-100 border border-gray-300 rounded cursor-pointer hover:border-indigo-500">
             <!-- Element preview would go here -->
           </div>
         <% end %>
       </div>
     </div>
   </div>
   """
 end

 # MIDI Workspace Implementation
 defp render_midi_workspace(assigns) do
   ~H"""
   <div class="h-full flex flex-col bg-gray-900">
     <!-- MIDI Header -->
     <div class="flex items-center justify-between p-4 border-b border-gray-700 bg-gray-800">
       <div class="flex items-center space-x-4">
         <h2 class="text-white font-semibold">🎹 MIDI Editor</h2>

         <!-- Instrument Selector -->
         <select
           phx-change="midi_set_instrument"
           phx-target={assigns[:myself]}
           class="bg-gray-700 border-gray-600 text-white rounded text-sm"
         >
           <option value="piano" selected={get_in(assigns, [:workspace_state, :midi, :current_instrument]) == "piano"}>Piano</option>
           <option value="synth" selected={get_in(assigns, [:workspace_state, :midi, :current_instrument]) == "synth"}>Synth</option>
           <option value="bass" selected={get_in(assigns, [:workspace_state, :midi, :current_instrument]) == "bass"}>Bass</option>
           <option value="strings" selected={get_in(assigns, [:workspace_state, :midi, :current_instrument]) == "strings"}>Strings</option>
         </select>

         <!-- Octave Control -->
         <div class="flex items-center space-x-2">
           <button
             phx-click="midi_octave_down"
             phx-target={assigns[:myself]}
             class="w-6 h-6 bg-gray-600 hover:bg-gray-500 rounded text-white text-xs"
           >
             -
           </button>
           <span class="text-white text-sm">Oct <%= get_in(assigns, [:workspace_state, :midi, :octave]) || 4 %></span>
           <button
             phx-click="midi_octave_up"
             phx-target={assigns[:myself]}
             class="w-6 h-6 bg-gray-600 hover:bg-gray-500 rounded text-white text-xs"
           >
             +
           </button>
         </div>
       </div>

       <div class="flex items-center space-x-4">
         <!-- Grid Size -->
         <div class="flex items-center space-x-2">
           <label class="text-gray-400 text-sm">Grid:</label>
           <select
             phx-change="midi_set_grid_size"
             phx-target={assigns[:myself]}
             class="bg-gray-700 border-gray-600 text-white rounded text-sm"
           >
             <option value="4">1/4</option>
             <option value="8">1/8</option>
             <option value="16" selected={get_in(assigns, [:workspace_state, :midi, :grid_size]) == 16}>1/16</option>
             <option value="32">1/32</option>
           </select>
         </div>

         <!-- Play Controls -->
         <div class="flex items-center space-x-2">
           <button
             phx-click="midi_play"
             phx-target={assigns[:myself]}
             class="w-8 h-8 bg-green-600 hover:bg-green-700 rounded-full flex items-center justify-center text-white"
           >
             ▶️
           </button>
           <button
             phx-click="midi_stop"
             phx-target={assigns[:myself]}
             class="w-8 h-8 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
           >
             ⏹️
           </button>
         </div>
       </div>
     </div>

     <!-- Piano Roll Editor -->
     <div class="flex-1 flex overflow-hidden">
       <!-- Piano Keys -->
       <div class="w-20 bg-gray-800 border-r border-gray-700 overflow-y-auto">
         <div class="sticky top-0 h-8 bg-gray-700 border-b border-gray-600"></div>
         <%= for note <- midi_notes_descending() do %>
           <div
             class={[
               "h-4 border-b border-gray-600 flex items-center justify-end pr-2 text-xs cursor-pointer",
               String.contains?(note, "#") && "bg-gray-900 text-gray-400" || "bg-gray-700 text-white",
               "hover:bg-indigo-600"
             ]}
             phx-click="midi_preview_note"
             phx-value-note={note}
             phx-target={assigns[:myself]}
           >
             <%= note %>
           </div>
         <% end %>
       </div>

       <!-- Note Grid -->
       <div class="flex-1 overflow-auto" id="midi-grid" phx-hook="MIDIGrid">
         <!-- Time Ruler -->
         <div class="h-8 bg-gray-700 border-b border-gray-600 flex">
           <%= for beat <- 1..32 do %>
             <div class="w-16 border-r border-gray-600 flex items-center justify-center text-xs text-gray-400">
               <%= beat %>
             </div>
           <% end %>
         </div>

         <!-- Note Lanes -->
         <div class="relative">
           <%= for {note, index} <- Enum.with_index(midi_notes_descending()) do %>
             <div class="h-4 border-b border-gray-600 flex relative">
               <%= for beat <- 1..32 do %>
                 <div
                   class="w-16 border-r border-gray-600 hover:bg-indigo-900 hover:bg-opacity-30 cursor-pointer"
                   phx-click="midi_toggle_note"
                   phx-value-note={note}
                   phx-value-beat={beat}
                   phx-target={assigns[:myself]}
                   data-note={note}
                   data-beat={beat}
                 ></div>
               <% end %>

               <!-- Existing Notes -->
               <%= for midi_note <- get_notes_for_pitch(assigns, note) do %>
                 <div
                   class="absolute h-3 bg-indigo-500 border border-indigo-400 rounded cursor-move top-0.5"
                   style={"left: #{midi_note.start_beat * 16}px; width: #{midi_note.duration * 16}px;"}
                   phx-click="midi_select_note"
                   phx-value-note-id={midi_note.id}
                   phx-target={assigns[:myself]}
                 ></div>
               <% end %>
             </div>
           <% end %>

           <!-- Playhead -->
           <div
             class="absolute top-0 bottom-0 w-px bg-red-500 z-10 pointer-events-none"
             style={"left: #{(get_in(assigns, [:workspace_state, :midi, :current_beat]) || 0) * 16}px;"}
           >
             <div class="absolute -top-2 -left-2 w-4 h-4 bg-red-500 rotate-45"></div>
           </div>
         </div>
       </div>
     </div>

     <!-- Virtual Keyboard -->
     <div class="h-24 border-t border-gray-700 bg-gray-800 p-4">
       <div class="h-full flex items-center justify-center">
         <div class="flex">
           <!-- White Keys -->
           <%= for note <- ["C", "D", "E", "F", "G", "A", "B"] do %>
             <button
               phx-click="midi_play_note"
               phx-value-note={"#{note}#{get_in(assigns, [:workspace_state, :midi, :octave]) || 4}"}
               phx-target={assigns[:myself]}
               class="w-8 h-16 bg-white border border-gray-400 hover:bg-gray-100 text-gray-900 text-xs flex items-end justify-center pb-1"
             >
               <%= note %>
             </button>

             <!-- Black Keys -->
             <%= if note in ["C", "D", "F", "G", "A"] do %>
               <button
                 phx-click="midi_play_note"
                 phx-value-note={"#{note}##{get_in(assigns, [:workspace_state, :midi, :octave]) || 4}"}
                 phx-target={assigns[:myself]}
                 class="w-6 h-10 bg-gray-900 hover:bg-gray-800 text-white text-xs -ml-3 -mr-3 z-10 relative"
               >
               </button>
             <% end %>
           <% end %>
         </div>
       </div>
     </div>
   </div>
   """
 end

 # Default/Fallback Workspace
 defp render_default_workspace(assigns) do
   ~H"""
   <div class="h-full flex items-center justify-center bg-gradient-to-br from-gray-800 to-gray-900">
     <div class="text-center">
       <div class="w-24 h-24 mx-auto mb-6 bg-gradient-to-br from-indigo-500 to-purple-600 rounded-full flex items-center justify-center">
         <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
           <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A22 0 009 10.172V5L8 4z" />
         </svg>
       </div>
       <h3 class="text-2xl font-bold text-white mb-2">
         <%= String.capitalize(Map.get(assigns, :active_tool, "unknown")) %> Workspace
       </h3>
       <p class="text-gray-400 mb-6">
         This workspace is being prepared for you
       </p>
       <div class="flex items-center justify-center space-x-2 text-gray-500">
         <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce"></div>
         <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
         <div class="w-2 h-2 bg-gray-500 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
       </div>
     </div>
   </div>
   """
 end

 defp render_workspace_content(assigns, "story_outline") do
  ~H"""
  <.live_component
    module={FrestylWeb.StudioLive.StoryOutlineComponent}
    id="story-outline"
    workspace_state={@workspace_state}
    current_user={@current_user}
    session={@session}
    permissions={@permissions}
    collaboration_mode={@collaboration_mode}
  />
  """
end

defp render_workspace_content(assigns, "character_sheets") do
  ~H"""
  <.live_component
    module={FrestylWeb.StudioLive.CharacterSheetsComponent}
    id="character-sheets"
    workspace_state={@workspace_state}
    current_user={@current_user}
    session={@session}
    permissions={@permissions}
    collaboration_mode={@collaboration_mode}
  />
  """
end

defp render_workspace_content(assigns, "world_building") do
  ~H"""
  <.live_component
    module={FrestylWeb.StudioLive.WorldBuildingComponent}
    id="world-building"
    workspace_state={@workspace_state}
    current_user={@current_user}
    session={@session}
    permissions={@permissions}
    collaboration_mode={@collaboration_mode}
  />
  """
end

defp render_workspace_content(assigns, "story_timeline") do
  ~H"""
  <div class="h-full flex flex-col bg-white">
    <!-- Story Timeline Header -->
    <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center space-x-3">
        <div class="w-8 h-8 rounded-lg bg-orange-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
        </div>
        <div>
          <h3 class="font-semibold text-gray-900">Story Timeline</h3>
          <p class="text-sm text-gray-600">Chronological story events</p>
        </div>
      </div>

      <button class="bg-orange-600 hover:bg-orange-700 text-white px-3 py-2 rounded-lg text-sm font-medium">
        Add Event
      </button>
    </div>

    <!-- Timeline Content -->
    <div class="flex-1 overflow-y-auto p-4">
      <div class="space-y-4">
        <!-- Timeline events would go here -->
        <div class="text-center py-12">
          <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No Timeline Events</h3>
          <p class="text-gray-600 mb-6">Create a chronological timeline of your story events.</p>
          <button class="bg-orange-600 hover:bg-orange-700 text-white px-6 py-3 rounded-lg font-medium">
            Create First Event
          </button>
        </div>
      </div>
    </div>
  </div>
  """
end

defp render_workspace_content(assigns, "story_comments") do
  ~H"""
  <div class="h-full flex flex-col bg-white">
    <!-- Comments Header -->
    <div class="flex items-center justify-between p-4 border-b border-gray-200 bg-gray-50">
      <div class="flex items-center space-x-3">
        <div class="w-8 h-8 rounded-lg bg-yellow-100 flex items-center justify-center">
          <svg class="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
          </svg>
        </div>
        <div>
          <h3 class="font-semibold text-gray-900">Story Review</h3>
          <p class="text-sm text-gray-600">Collaborative feedback and suggestions</p>
        </div>
      </div>

      <div class="flex items-center space-x-2">
        <select class="text-sm border border-gray-300 rounded-lg px-3 py-1 focus:ring-2 focus:ring-yellow-500">
          <option>All Comments</option>
          <option>Unresolved</option>
          <option>Suggestions</option>
          <option>My Comments</option>
        </select>
      </div>
    </div>

    <!-- Comments List -->
    <div class="flex-1 overflow-y-auto p-4">
      <div class="space-y-4">
        <!-- Comments would go here -->
        <div class="text-center py-12">
          <div class="w-16 h-16 mx-auto bg-gray-100 rounded-full flex items-center justify-center mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No Comments Yet</h3>
          <p class="text-gray-600 mb-6">Start collaborating by adding feedback and suggestions.</p>
        </div>
      </div>
    </div>

    <!-- Comment Input -->
    <div class="border-t border-gray-200 p-4">
      <form class="flex space-x-3">
        <div class="flex-1">
          <textarea
            rows="2"
            placeholder="Add a comment or suggestion..."
            class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-yellow-500 focus:border-yellow-500 resize-none"
          ></textarea>
        </div>
        <button
          type="submit"
          class="bg-yellow-600 hover:bg-yellow-700 text-white px-4 py-2 rounded-lg text-sm font-medium"
        >
          Add Comment
        </button>
      </form>
    </div>
  </div>
  """
end

 # Event Handlers
 @impl true
 def handle_event(event_name, params, socket) do
   # Forward all events to parent LiveView with component context
   send(self(), {:workspace_event, String.to_atom(event_name), params})
   {:noreply, socket}
 end

 # Helper Functions
 defp format_time(milliseconds) when is_number(milliseconds) do
   total_seconds = div(trunc(milliseconds), 1000)
   minutes = div(total_seconds, 60)
   seconds = rem(total_seconds, 60)
   "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(seconds), 2, "0")}"
 end
 defp format_time(_), do: "00:00"

 defp format_last_saved(datetime) when is_struct(datetime) do
   now = DateTime.utc_now()
   diff = DateTime.diff(now, datetime, :second)

   cond do
     diff < 60 -> "just now"
     diff < 3600 -> "#{div(diff, 60)}m ago"
     diff < 86400 -> "#{div(diff, 3600)}h ago"
     true -> Calendar.strftime(datetime, "%m/%d %H:%M")
   end
 end
 defp format_last_saved(_), do: "never"

 defp get_current_line(assigns) do
   content = get_in(assigns, [:workspace_state, :text, :content]) || ""
   content |> String.split("\n") |> length()
 end

 defp get_user_color(user_id) do
   # Generate consistent colors for users
   colors = ["#ef4444", "#f97316", "#eab308", "#22c55e", "#06b6d4", "#3b82f6", "#8b5cf6", "#ec4899"]
   index = :erlang.phash2(user_id, length(colors))
   Enum.at(colors, index)
 end

 defp get_username_for_user_id(user_id, assigns) do
   collaborators = assigns[:collaborators] || []
   case Enum.find(collaborators, &(to_string(&1.user_id) == user_id)) do
     %{username: username} -> username
     _ -> "User"
   end
 end

 defp get_block_type_color("verse"), do: "bg-blue-600 text-white"
 defp get_block_type_color("chorus"), do: "bg-purple-600 text-white"
 defp get_block_type_color("bridge"), do: "bg-green-600 text-white"
 defp get_block_type_color("intro"), do: "bg-yellow-600 text-white"
 defp get_block_type_color("outro"), do: "bg-red-600 text-white"
 defp get_block_type_color(_), do: "bg-gray-600 text-white"

 defp get_block_timeline_color("verse"), do: "bg-blue-500 border-blue-400"
 defp get_block_timeline_color("chorus"), do: "bg-purple-500 border-purple-400"
 defp get_block_timeline_color("bridge"), do: "bg-green-500 border-green-400"
 defp get_block_timeline_color("intro"), do: "bg-yellow-500 border-yellow-400"
 defp get_block_timeline_color("outro"), do: "bg-red-500 border-red-400"
 defp get_block_timeline_color(_), do: "bg-gray-500 border-gray-400"

 defp midi_notes_descending do
   notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
   for octave <- 7..1, note <- Enum.reverse(notes), do: "#{note}#{octave}"
 end

 defp get_notes_for_pitch(assigns, pitch) do
   notes = get_in(assigns, [:workspace_state, :midi, :notes]) || []
   Enum.filter(notes, &(&1.pitch == pitch))
 end
end
