# lib/frestyl_web/live/stories_live/mobile_components/voice_story_editor.ex
defmodule FrestylWeb.StoriesLive.MobileComponents.VoiceStoryEditor do
  @moduledoc """
  Mobile-optimized story editor with voice-first interface for on-the-go story creation.

  Features:
  - Voice note recording with automatic transcription
  - Intelligent voice note organization by story section
  - Offline voice note storage with sync
  - Voice command recognition for basic editing
  - Mobile-optimized collaborative features
  """

  use FrestylWeb, :live_component

  alias Frestyl.Stories
  alias Frestyl.Audio.VoiceNoteManager
  alias Frestyl.Mobile.VoiceCommands

  @impl true
  def mount(socket) do
    {:ok, socket
     |> assign(:recording_state, :idle)
     |> assign(:voice_notes, [])
     |> assign(:transcription_status, :ready)
     |> assign(:mobile_tools_expanded, false)
     |> assign(:active_section, nil)
     |> assign(:voice_command_mode, false)
     |> assign(:offline_sync_pending, [])}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-gray-50 mobile-story-editor"
         phx-hook="MobileStoryEditor"
         id="mobile-story-editor">

      <!-- Mobile Header with Story Context -->
      <div class="bg-white border-b border-gray-200 px-4 py-3 flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <button phx-click="toggle_mobile_tools" class="p-2 rounded-lg bg-gray-100">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>
          <div>
            <h1 class="font-semibold text-gray-900 text-sm"><%= @story.title %></h1>
            <p class="text-xs text-gray-500"><%= @story.story_type |> String.replace("_", " ") |> String.capitalize %></p>
          </div>
        </div>

        <!-- Voice Recording Button - Always Accessible -->
        <button phx-click="toggle_voice_recording"
                class={["p-3 rounded-full transition-all duration-200",
                       if(@recording_state == :recording, do: "bg-red-500 animate-pulse", else: "bg-blue-500"),
                       "shadow-lg"]}
                id="voice-recording-button">
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <%= if @recording_state == :recording do %>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 10a1 1 0 011-1h4a1 1 0 011 1v4a1 1 0 01-1 1h-4a1 1 0 01-1-1v-4z"/>
            <% else %>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
            <% end %>
          </svg>
        </button>
      </div>

      <!-- Mobile Tools Drawer -->
      <%= if @mobile_tools_expanded do %>
        <div class="bg-white border-b border-gray-200 p-4 mobile-tools-drawer"
             phx-click-away="collapse_mobile_tools">
          <div class="grid grid-cols-4 gap-3">
            <button phx-click="activate_tool" phx-value-tool="voice_notes"
                    class="flex flex-col items-center p-3 rounded-lg bg-blue-50 border border-blue-200">
              <svg class="w-6 h-6 text-blue-600 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2M7 4h10M7 4l-2 14h14l-2-14"/>
              </svg>
              <span class="text-xs text-blue-600">Voice Notes</span>
            </button>

            <button phx-click="activate_tool" phx-value-tool="characters"
                    class="flex flex-col items-center p-3 rounded-lg bg-green-50 border border-green-200">
              <svg class="w-6 h-6 text-green-600 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197"/>
              </svg>
              <span class="text-xs text-green-600">Characters</span>
            </button>

            <button phx-click="activate_tool" phx-value-tool="outline"
                    class="flex flex-col items-center p-3 rounded-lg bg-purple-50 border border-purple-200">
              <svg class="w-6 h-6 text-purple-600 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 10h16M4 14h16M4 18h16"/>
              </svg>
              <span class="text-xs text-purple-600">Outline</span>
            </button>

            <button phx-click="activate_tool" phx-value-tool="collaboration"
                    class="flex flex-col items-center p-3 rounded-lg bg-orange-50 border border-orange-200">
              <svg class="w-6 h-6 text-orange-600 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
              </svg>
              <span class="text-xs text-orange-600">Share</span>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Main Content Area -->
      <div class="flex-1 overflow-hidden">
        <%= case @active_tool do %>
          <% "voice_notes" -> %>
            <.render_voice_notes_panel assigns={assigns} />
          <% "characters" -> %>
            <.render_characters_panel assigns={assigns} />
          <% "outline" -> %>
            <.render_outline_panel assigns={assigns} />
          <% "collaboration" -> %>
            <.render_collaboration_panel assigns={assigns} />
          <% _ -> %>
            <.render_story_editor assigns={assigns} />
        <% end %>
      </div>

      <!-- Bottom Action Bar -->
      <div class="bg-white border-t border-gray-200 px-4 py-2 flex items-center justify-between">
        <!-- Quick Actions -->
        <div class="flex items-center space-x-4">
          <button phx-click="quick_save" class="flex items-center space-x-1 text-gray-600">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2h-3m-1 4l-3-3m0 0l-3 3m3-3v12"/>
            </svg>
            <span class="text-xs">Save</span>
          </button>

          <%= if length(@offline_sync_pending) > 0 do %>
            <button phx-click="sync_offline_content" class="flex items-center space-x-1 text-blue-600">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
              </svg>
              <span class="text-xs">Sync (<%= length(@offline_sync_pending) %>)</span>
            </button>
          <% end %>
        </div>

        <!-- Voice Command Indicator -->
        <%= if @voice_command_mode do %>
          <div class="flex items-center space-x-2 bg-blue-100 px-3 py-1 rounded-full">
            <div class="w-2 h-2 bg-blue-500 rounded-full animate-pulse"></div>
            <span class="text-xs text-blue-700">Listening...</span>
          </div>
        <% end %>

        <!-- Word Count / Progress -->
        <div class="text-xs text-gray-500">
          <%= get_word_count(@story) %> words
        </div>
      </div>

      <!-- Voice Recording Overlay -->
      <%= if @recording_state != :idle do %>
        <div class="absolute inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-lg p-6 mx-4 max-w-sm w-full">
            <div class="text-center">
              <div class="w-16 h-16 bg-red-500 rounded-full mx-auto mb-4 flex items-center justify-center animate-pulse">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                </svg>
              </div>

              <%= case @recording_state do %>
                <% :recording -> %>
                  <h3 class="font-semibold text-gray-900 mb-2">Recording Voice Note</h3>
                  <p class="text-gray-600 text-sm mb-4">Tap to stop and save</p>
                  <div class="text-lg font-mono text-red-600" id="recording-timer">00:00</div>
                <% :processing -> %>
                  <h3 class="font-semibold text-gray-900 mb-2">Processing Audio</h3>
                  <p class="text-gray-600 text-sm">Transcribing your voice note...</p>
                <% :saving -> %>
                  <h3 class="font-semibold text-gray-900 mb-2">Saving Note</h3>
                  <p class="text-gray-600 text-sm">Organizing your voice note...</p>
              <% end %>

              <button phx-click="stop_recording"
                      class="mt-4 px-6 py-2 bg-red-500 text-white rounded-lg">
                Stop Recording
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Voice Notes Panel - Core mobile feature
  defp render_voice_notes_panel(assigns) do
    ~H"""
    <div class="h-full bg-white">
      <!-- Voice Notes Header -->
      <div class="border-b border-gray-200 px-4 py-3">
        <h2 class="font-semibold text-gray-900">Voice Notes</h2>
        <p class="text-sm text-gray-600">Organize your story ideas by voice</p>
      </div>

      <!-- Section Selector -->
      <div class="border-b border-gray-200 px-4 py-2">
        <div class="flex space-x-2 overflow-x-auto">
          <%= for section <- @story.sections || [] do %>
            <button phx-click="select_voice_section"
                    phx-value-section-id={section.id}
                    class={["px-3 py-1 rounded-full text-sm whitespace-nowrap",
                           if(section.id == @active_section,
                              do: "bg-blue-500 text-white",
                              else: "bg-gray-100 text-gray-700")]}>
              <%= section.title %>
            </button>
          <% end %>
          <button phx-click="add_story_section"
                  class="px-3 py-1 rounded-full text-sm bg-gray-200 text-gray-600 whitespace-nowrap">
            + Add Section
          </button>
        </div>
      </div>

      <!-- Voice Notes List -->
      <div class="flex-1 overflow-y-auto">
        <%= if length(@voice_notes) > 0 do %>
          <%= for voice_note <- @voice_notes do %>
            <div class="border-b border-gray-100 p-4">
              <div class="flex items-start space-x-3">
                <button phx-click="play_voice_note"
                        phx-value-note-id={voice_note.id}
                        class="mt-1 p-2 bg-blue-100 rounded-full">
                  <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h8m2-10v12a2 2 0 01-2 2H6a2 2 0 01-2-2V4a2 2 0 012-2h8l4 4z"/>
                  </svg>
                </button>

                <div class="flex-1 min-w-0">
                  <div class="flex items-center justify-between mb-1">
                    <span class="text-xs text-gray-500">
                      <%= format_timestamp(voice_note.created_at) %>
                    </span>
                    <span class="text-xs text-blue-600">
                      <%= voice_note.duration %>s
                    </span>
                  </div>

                  <%= if voice_note.transcription do %>
                    <p class="text-sm text-gray-900 mb-2">
                      <%= voice_note.transcription %>
                    </p>
                  <% else %>
                    <p class="text-sm text-gray-500 italic mb-2">
                      Transcribing...
                    </p>
                  <% end %>

                  <div class="flex items-center space-x-2">
                    <button phx-click="add_to_story"
                            phx-value-note-id={voice_note.id}
                            class="text-xs text-blue-600 hover:text-blue-800">
                      Add to Story
                    </button>
                    <button phx-click="edit_transcription"
                            phx-value-note-id={voice_note.id}
                            class="text-xs text-gray-600 hover:text-gray-800">
                      Edit
                    </button>
                    <button phx-click="delete_voice_note"
                            phx-value-note-id={voice_note.id}
                            class="text-xs text-red-600 hover:text-red-800">
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        <% else %>
          <div class="flex-1 flex items-center justify-center p-8">
            <div class="text-center">
              <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
              </svg>
              <h3 class="font-medium text-gray-900 mb-2">No Voice Notes Yet</h3>
              <p class="text-gray-600 text-sm mb-4">Start recording to capture your story ideas</p>
              <button phx-click="toggle_voice_recording"
                      class="px-4 py-2 bg-blue-500 text-white rounded-lg">
                Record First Note
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Story Editor Panel - Mobile-optimized text editing
  defp render_story_editor(assigns) do
    ~H"""
    <div class="h-full bg-white flex flex-col">
      <!-- Story Editor Header -->
      <div class="border-b border-gray-200 px-4 py-3 flex items-center justify-between">
        <div>
          <h2 class="font-semibold text-gray-900">Story Editor</h2>
          <p class="text-sm text-gray-600">
            <%= if @active_section do %>
              Editing: <%= @active_section.title %>
            <% else %>
              Select a section to edit
            <% end %>
          </p>
        </div>

        <button phx-click="toggle_voice_command_mode"
                class={["p-2 rounded-lg",
                       if(@voice_command_mode, do: "bg-blue-500 text-white", else: "bg-gray-100 text-gray-600")]}>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
          </svg>
        </button>
      </div>

      <!-- Section Tabs -->
      <div class="border-b border-gray-200 px-4 py-2">
        <div class="flex space-x-2 overflow-x-auto">
          <%= for section <- @story.sections || [] do %>
            <button phx-click="select_section"
                    phx-value-section-id={section.id}
                    class={["px-3 py-1 rounded-full text-sm whitespace-nowrap",
                           if(section.id == (@active_section && @active_section.id),
                              do: "bg-blue-500 text-white",
                              else: "bg-gray-100 text-gray-700")]}>
              <%= section.title %>
            </button>
          <% end %>
          <button phx-click="add_section"
                  class="px-3 py-1 rounded-full text-sm bg-gray-200 text-gray-600 whitespace-nowrap">
            + Add
          </button>
        </div>
      </div>

      <!-- Text Editor -->
      <div class="flex-1 overflow-hidden">
        <%= if @active_section do %>
          <div class="h-full">
            <!-- Mobile-optimized text editor with voice integration -->
            <div phx-hook="MobileTextEditor"
                 class="h-full p-4"
                 id="mobile-text-editor-#{@active_section.id}"
                 data-section-id={@active_section.id}
                 data-collaboration-enabled={@collaboration_enabled || false}>

              <textarea
                phx-blur="auto_save_section"
                phx-value-section-id={@active_section.id}
                class="w-full h-full resize-none border-none outline-none text-base leading-relaxed"
                placeholder={get_section_placeholder(@story.story_type, @active_section.type)}
                style="font-family: system-ui, -apple-system, sans-serif;"
                ><%= @active_section.content %></textarea>

              <!-- Collaboration Cursors Overlay -->
              <%= if @collaboration_enabled do %>
                <div id="collaboration-cursors-#{@active_section.id}" class="absolute pointer-events-none">
                  <!-- Real-time cursors will be rendered here -->
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="flex-1 flex items-center justify-center p-8">
            <div class="text-center">
              <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
              <h3 class="font-medium text-gray-900 mb-2">No Sections Yet</h3>
              <p class="text-gray-600 text-sm mb-4">Create your first story section</p>
              <button phx-click="add_section"
                      class="px-4 py-2 bg-blue-500 text-white rounded-lg">
                Add First Section
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Mobile Writing Tools -->
      <div class="border-t border-gray-200 bg-gray-50 px-4 py-2">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <button phx-click="format_text" phx-value-format="bold"
                    class="p-2 rounded bg-white border border-gray-200">
              <span class="font-bold text-sm">B</span>
            </button>
            <button phx-click="format_text" phx-value-format="italic"
                    class="p-2 rounded bg-white border border-gray-200">
              <span class="italic text-sm">I</span>
            </button>
            <button phx-click="add_voice_note_inline"
                    class="p-2 rounded bg-blue-100 border border-blue-200">
              <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
              </svg>
            </button>
          </div>

          <div class="flex items-center space-x-2">
            <%= if @collaboration_enabled do %>
              <div class="flex -space-x-2">
                <%= for collaborator <- @collaborators do %>
                  <div class="w-6 h-6 rounded-full bg-blue-500 border-2 border-white flex items-center justify-center">
                    <span class="text-xs text-white font-medium">
                      <%= String.first(collaborator.username) %>
                    </span>
                  </div>
                <% end %>
              </div>
            <% end %>

            <span class="text-xs text-gray-500">
              <%= get_section_word_count(@active_section) %> words
            </span>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Outline Management Panel
  defp render_outline_panel(assigns) do
    ~H"""
    <div class="h-full bg-white">
      <div class="border-b border-gray-200 px-4 py-3">
        <h2 class="font-semibold text-gray-900">Story Outline</h2>
        <p class="text-sm text-gray-600">Organize your story structure</p>
      </div>

      <div class="flex-1 overflow-y-auto p-4">
        <%= if @story.plot_data && length(@story.plot_data) > 0 do %>
          <%= for plot_point <- @story.plot_data do %>
            <div class="mb-4 p-3 border border-gray-200 rounded-lg">
              <div class="flex items-center justify-between mb-2">
                <h3 class="font-medium text-gray-900"><%= plot_point.title %></h3>
                <button phx-click="edit_plot_point" phx-value-plot-id={plot_point.id}
                        class="text-blue-600 text-sm">
                  Edit
                </button>
              </div>
              <p class="text-sm text-gray-600"><%= plot_point.description %></p>
            </div>
          <% end %>
        <% else %>
          <div class="text-center py-8">
            <p class="text-gray-600 mb-4">No outline yet</p>
            <button phx-click="add_plot_point"
                    class="px-4 py-2 bg-blue-500 text-white rounded-lg">
              Add Plot Point
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Collaboration Management Panel
  defp render_collaboration_panel(assigns) do
    ~H"""
    <div class="h-full bg-white">
      <div class="border-b border-gray-200 px-4 py-3">
        <h2 class="font-semibold text-gray-900">Collaboration</h2>
        <p class="text-sm text-gray-600">Share and collaborate on your story</p>
      </div>

      <div class="flex-1 overflow-y-auto p-4 space-y-6">
        <!-- Active Collaborators -->
        <div>
          <h3 class="font-medium text-gray-900 mb-2">Active Collaborators</h3>
          <%= if length(@collaborators || []) > 0 do %>
            <div class="space-y-2">
              <%= for collaborator <- @collaborators do %>
                <div class="flex items-center space-x-2 p-2 bg-gray-50 rounded">
                  <div class="w-6 h-6 rounded-full bg-blue-500 flex items-center justify-center">
                    <span class="text-xs text-white font-medium">
                      <%= String.first(collaborator.username) %>
                    </span>
                  </div>
                  <span class="text-sm text-gray-900"><%= collaborator.username %></span>
                  <div class="w-2 h-2 bg-green-500 rounded-full"></div>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-sm text-gray-500">You're working solo</p>
          <% end %>
        </div>

        <!-- Invite Collaborators -->
        <div>
          <h3 class="font-medium text-gray-900 mb-2">Invite Collaborators</h3>
          <form phx-submit="invite_collaborator" class="space-y-2">
            <input type="email"
                   name="email"
                   placeholder="Email address"
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg text-sm"
                   required />
            <button type="submit"
                    class="w-full px-3 py-2 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600">
              Send Invitation
            </button>
          </form>
        </div>

        <!-- Collaboration Settings -->
        <div>
          <h3 class="font-medium text-gray-900 mb-2">Settings</h3>
          <div class="space-y-2">
            <button phx-click="toggle_real_time_editing"
                    class="w-full text-left px-3 py-2 text-sm bg-gray-50 rounded hover:bg-gray-100">
              Real-time Editing
            </button>
            <button phx-click="share_story_link"
                    class="w-full text-left px-3 py-2 text-sm bg-gray-50 rounded hover:bg-gray-100">
              Share Story Link
            </button>
            <button phx-click="disable_collaboration"
                    class="w-full text-left px-3 py-2 text-sm text-red-600 bg-red-50 rounded hover:bg-red-100">
              End Collaboration
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Character Management Panel
  defp render_characters_panel(assigns) do
    ~H"""
    <div class="h-full bg-white">
      <div class="border-b border-gray-200 px-4 py-3">
        <h2 class="font-semibold text-gray-900">Characters</h2>
        <p class="text-sm text-gray-600">Manage your story characters</p>
      </div>

      <div class="flex-1 overflow-y-auto p-4">
        <%= if length(@story.character_data || []) > 0 do %>
          <%= for character <- @story.character_data do %>
            <div class="mb-4 p-3 border border-gray-200 rounded-lg">
              <div class="flex items-center justify-between mb-2">
                <h3 class="font-medium text-gray-900"><%= character.name %></h3>
                <button phx-click="edit_character" phx-value-character-id={character.id}
                        class="text-blue-600 text-sm">
                  Edit
                </button>
              </div>
              <p class="text-sm text-gray-600"><%= character.description %></p>

              <%= if character.voice_notes do %>
                <div class="mt-2 flex items-center space-x-2">
                  <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                  </svg>
                  <span class="text-xs text-blue-600">Voice notes available</span>
                </div>
              <% end %>
            </div>
          <% end %>
        <% else %>
          <div class="text-center py-8">
            <p class="text-gray-600 mb-4">No characters yet</p>
            <button phx-click="add_character"
                    class="px-4 py-2 bg-blue-500 text-white rounded-lg">
              Add Character
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("toggle_voice_recording", _params, socket) do
    new_state = case socket.assigns.recording_state do
      :idle -> :recording
      :recording -> :processing
      _ -> :idle
    end

    socket = assign(socket, :recording_state, new_state)

    # Handle voice recording logic
    case new_state do
      :recording ->
        {:noreply, socket |> push_event("start_voice_recording", %{})}

      :processing ->
        {:noreply, socket |> push_event("stop_voice_recording", %{})}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_mobile_tools", _params, socket) do
    {:noreply, assign(socket, :mobile_tools_expanded, !socket.assigns.mobile_tools_expanded)}
  end

  @impl true
  def handle_event("collapse_mobile_tools", _params, socket) do
    {:noreply, assign(socket, :mobile_tools_expanded, false)}
  end

  @impl true
  def handle_event("activate_tool", %{"tool" => tool}, socket) do
    {:noreply, socket
     |> assign(:active_tool, tool)
     |> assign(:mobile_tools_expanded, false)}
  end

  @impl true
  def handle_event("voice_note_recorded", %{"audio_data" => audio_data, "duration" => duration}, socket) do
    # Process voice note
    case VoiceNoteManager.process_voice_note(audio_data, %{
      story_id: socket.assigns.story.id,
      section_id: socket.assigns.active_section && socket.assigns.active_section.id,
      user_id: socket.assigns.current_user.id,
      duration: duration
    }) do
      {:ok, voice_note} ->
        updated_voice_notes = [voice_note | socket.assigns.voice_notes]

        {:noreply, socket
         |> assign(:voice_notes, updated_voice_notes)
         |> assign(:recording_state, :idle)
         |> put_flash(:info, "Voice note saved!")}

      {:error, reason} ->
        {:noreply, socket
         |> assign(:recording_state, :idle)
         |> put_flash(:error, "Failed to save voice note: #{reason}")}
    end
  end

  @impl true
  def handle_event("add_to_story", %{"note-id" => note_id}, socket) do
    # Find the voice note and add its transcription to the current section
    case Enum.find(socket.assigns.voice_notes, &(&1.id == note_id)) do
      %{transcription: transcription} when not is_nil(transcription) ->
        if socket.assigns.active_section do
          # Add transcription to section content
          updated_content = socket.assigns.active_section.content <> "\n\n" <> transcription

          case Stories.update_section_content(socket.assigns.active_section.id, updated_content) do
            {:ok, updated_section} ->
              {:noreply, socket
               |> assign(:active_section, updated_section)
               |> put_flash(:info, "Voice note added to story!")}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Failed to add voice note to story")}
          end
        else
          {:noreply, put_flash(socket, :error, "Please select a section first")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Voice note transcription not ready")}
    end
  end

  @impl true
  def handle_event("toggle_voice_command_mode", _params, socket) do
    new_mode = !socket.assigns.voice_command_mode

    socket = assign(socket, :voice_command_mode, new_mode)

    if new_mode do
      {:noreply, socket |> push_event("start_voice_commands", %{})}
    else
      {:noreply, socket |> push_event("stop_voice_commands", %{})}
    end
  end

  # Helper functions
  defp get_word_count(story) do
    story.sections
    |> Enum.map(& &1.content || "")
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  defp get_section_word_count(nil), do: 0
  defp get_section_word_count(section) do
    (section.content || "")
    |> String.split()
    |> length()
  end

  defp get_section_placeholder(story_type, section_type) do
    case {story_type, section_type} do
      {"novel", "chapter"} -> "Chapter content... Describe the scene, develop characters, advance the plot..."
      {"screenplay", "scene"} -> "SCENE HEADING\n\nAction lines describe what we see...\n\nCHARACTER\nDialogue goes here."
      {"case_study", "section"} -> "Section content... Present your analysis, data, and insights..."
      _ -> "Start writing your story here..."
    end
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end
end
