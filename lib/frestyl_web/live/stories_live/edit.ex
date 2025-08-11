# lib/frestyl_web/live/stories_live/edit.ex (Enhanced Version)
defmodule FrestylWeb.StoriesLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Stories
  alias Frestyl.Stories.{EnhancedStoryStructure, Collaboration}
  alias Frestyl.StoryEngine.{FormatManager, AIIntegration, CollaborationModes}
  alias Frestyl.Features.TierManager
  alias Frestyl.Sessions
  alias Frestyl.Studio.WorkspaceManager
  alias Frestyl.Collaboration.OperationalTransform
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => story_id}, session, socket) do
    current_user = get_current_user_from_session(session)

    case Stories.get_enhanced_story_with_permissions(story_id, current_user.id) do
      {:ok, story, permissions} ->
        if connected?(socket) do
          # Subscribe to story updates and collaboration
          PubSub.subscribe(Frestyl.PubSub, "story:#{story_id}")
          PubSub.subscribe(Frestyl.PubSub, "story_collaboration:#{story_id}")
        end

        format_config = FormatManager.get_format_config(story.story_type)
        user_tier = TierManager.get_user_tier(current_user)
        collaboration_mode = CollaborationModes.get_collaboration_mode(story.story_type)

        socket = socket
        |> assign(:story, story)
        |> assign(:current_user, current_user)
        |> assign(:permissions, permissions)
        |> assign(:format_config, format_config)
        |> assign(:user_tier, user_tier)
        |> assign(:collaboration_mode, collaboration_mode)
        |> assign(:editor_mode, determine_editor_mode(story, format_config))
        |> assign(:active_section, get_current_section(story))
        |> assign(:collaborators, [])
        |> assign(:ai_enabled, permissions.can_use_ai)
        |> assign(:ai_suggestions, [])
        |> assign(:word_count, calculate_word_count(story))
        |> assign(:save_status, :saved)
        |> assign(:show_ai_panel, false)
        |> assign(:show_collaboration_panel, false)
        |> assign(:mobile_view, false)
        |> assign(:creation_source, nil)
        |> assign(:editor_state_params, %{})
        # NEW: Collaboration detection and progressive enhancement
        |> assign(:collaboration_enabled, false)
        |> assign(:writing_session, nil)
        |> assign(:workspace_state, nil)
        |> assign(:presence_data, %{})
        |> assign(:voice_notes, [])
        |> assign(:audio_features_enabled, false)

        {:ok, socket}

      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Story not found") |> redirect(to: ~p"/stories")}

      {:error, :access_denied} ->
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: ~p"/stories")}
    end
  end

  @impl true
  def handle_params(params, _url, socket) do
    # Enhanced: Handle editor state parameters and detect collaboration needs
    editor_state = parse_editor_state_params(params)

    socket = socket
    |> assign(:editor_state_params, editor_state)
    |> assign(:creation_source, Map.get(params, "source"))
    |> apply_editor_state_configuration(editor_state)
    |> maybe_enable_collaboration_features(params)

    {:noreply, socket}
  end

  # ============================================================================
  # NEW: Progressive Enhancement for Collaboration
  # ============================================================================

  defp maybe_enable_collaboration_features(socket, params) do
    story = socket.assigns.story
    current_user = socket.assigns.current_user

    should_enable_collaboration = detect_collaboration_need(story, params, current_user)

    if should_enable_collaboration do
      enable_collaborative_features(socket)
    else
      socket
    end
  end

  defp detect_collaboration_need(story, params, current_user) do
    cond do
      # Explicit collaboration request
      Map.get(params, "collaboration") == "true" -> true

      # Story has active session with multiple users
      story.session_id && collaboration_active?(story.session_id) -> true

      # Audio features requested (voice notes, narration)
      Map.get(params, "audio") == "true" -> true

      # Frestyl Originals that require sessions
      CollaborationModes.requires_active_session?(story.story_type) -> true

      # Story collaboration mode is not "owner_only"
      story.collaboration_mode != "owner_only" -> true

      # Default: solo editing mode
      true -> false
    end
  end

  defp collaboration_active?(session_id) do
    case Sessions.get_participants_count(session_id) do
      count when count > 1 -> true
      _ -> false
    end
  end

  defp enable_collaborative_features(socket) do
    story = socket.assigns.story
    current_user = socket.assigns.current_user

    # Get or create writing session
    writing_session = get_or_create_writing_session(story, current_user)

    # Initialize workspace state
    {workspace_state, collaboration_mode} = WorkspaceManager.initialize_workspace(
      writing_session,
      current_user,
      get_device_info(socket)
    )

    # Setup real-time subscriptions
    if connected?(socket) do
      WorkspaceManager.setup_subscriptions(writing_session.id, current_user.id)
      PubSub.subscribe(Frestyl.PubSub, "studio:#{writing_session.id}")
      PubSub.subscribe(Frestyl.PubSub, "studio:#{writing_session.id}:operations")
    end

    # Track presence
    WorkspaceManager.track_presence(writing_session.id, current_user, get_device_info(socket))

    # Load voice notes if audio features enabled
    voice_notes = load_story_voice_notes(story.id)

    socket
    |> assign(:collaboration_enabled, true)
    |> assign(:writing_session, writing_session)
    |> assign(:workspace_state, workspace_state)
    |> assign(:voice_notes, voice_notes)
    |> assign(:audio_features_enabled, has_audio_features?(story.story_type))
    |> assign(:collaborators, get_active_collaborators(writing_session.id))
  end

  defp get_or_create_writing_session(story, user) do
    case story.session_id do
      nil ->
        # Create new writing session
        workspace = get_or_create_personal_workspace(user)

        session_attrs = %{
          "title" => "Writing: #{story.title}",
          "session_type" => "regular",
          "channel_id" => workspace.id,
          "creator_id" => user.id,
          "collaboration_mode" => determine_session_collaboration_mode(story.story_type)
        }

        case Sessions.create_session(session_attrs) do
          {:ok, session} ->
            # Link story to session
            Stories.update_enhanced_story(story, %{"session_id" => session.id})
            session

          {:error, _} ->
            nil
        end

      session_id ->
        Sessions.get_session(session_id)
    end
  end

  defp determine_session_collaboration_mode(story_type) do
    case story_type do
      type when type in ["novel", "screenplay", "short_story"] -> "narrative_workshop"
      type when type in ["case_study", "data_story", "report"] -> "business_workflow"
      "live_story" -> "live_story_session"
      "voice_sketch" -> "voice_sketch_studio"
      "audio_portfolio" -> "audio_portfolio_builder"
      "data_jam" -> "data_jam_session"
      "story_remix" -> "story_remix_lab"
      "narrative_beats" -> "narrative_beats_studio"
      _ -> "narrative_workshop"
    end
  end

  defp has_audio_features?(story_type) do
    story_type in ["voice_sketch", "audio_portfolio", "narrative_beats", "live_story"]
  end

  # ============================================================================
  # Event Handlers - Enhanced with Collaboration
  # ============================================================================

  @impl true
  def handle_event("enable_collaboration", _params, socket) do
    if socket.assigns.collaboration_enabled do
      {:noreply, socket}
    else
      {:noreply, enable_collaborative_features(socket)}
    end
  end

  @impl true
  def handle_event("disable_collaboration", _params, socket) do
    if socket.assigns.writing_session do
      # End writing session but keep story
      Sessions.end_session(socket.assigns.writing_session.id)
    end

    socket = socket
    |> assign(:collaboration_enabled, false)
    |> assign(:writing_session, nil)
    |> assign(:workspace_state, nil)
    |> assign(:audio_features_enabled, false)
    |> assign(:collaborators, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("section_content_changed", %{"section_id" => section_id, "content" => new_content}, socket) do
    if socket.assigns.collaboration_enabled do
      handle_collaborative_text_change(socket, section_id, new_content)
    else
      handle_solo_text_change(socket, section_id, new_content)
    end
  end

  defp handle_collaborative_text_change(socket, section_id, new_content) do
    # Generate operational transform for real-time collaboration
    current_section = get_section_by_id(socket.assigns.story, section_id)
    current_content = current_section.content || ""

    # Create text operation
    text_ops = generate_text_operations(current_content, new_content)

    if length(text_ops) > 0 do
      user_id = socket.assigns.current_user.id
      session_id = socket.assigns.writing_session.id

      operation = OperationalTransform.TextOp.new(text_ops, user_id, 0)

      # Apply operation locally
      updated_story = update_section_content_in_story(socket.assigns.story, section_id, new_content)

      # Broadcast operation to collaborators
      PubSub.broadcast(
        Frestyl.PubSub,
        "studio:#{session_id}:operations",
        {:new_text_operation, operation, section_id}
      )

      # Save asynchronously
      Task.start(fn ->
        Stories.update_section_content(section_id, new_content)
      end)

      {:noreply, socket
       |> assign(:story, updated_story)
       |> assign(:save_status, :saving)
       |> push_event("section_updated", %{section_id: section_id, content: new_content})}
    else
      {:noreply, socket}
    end
  end

  defp handle_solo_text_change(socket, section_id, new_content) do
    # Simple auto-save for solo editing
    updated_story = update_section_content_in_story(socket.assigns.story, section_id, new_content)

    # Debounced save
    Process.send_after(self(), {:auto_save, section_id, new_content}, 2000)

    {:noreply, socket
     |> assign(:story, updated_story)
     |> assign(:save_status, :saving)}
  end

  @impl true
  def handle_event("record_voice_note", %{"section_id" => section_id}, socket) do
    if socket.assigns.audio_features_enabled do
      {:noreply, socket
       |> push_event("start_voice_recording", %{
           section_id: section_id,
           story_id: socket.assigns.story.id
         })}
    else
      # Enable audio features first
      socket = enable_audio_features(socket)
      {:noreply, socket
       |> push_event("start_voice_recording", %{
           section_id: section_id,
           story_id: socket.assigns.story.id
         })}
    end
  end

  @impl true
  def handle_event("invite_collaborator", %{"email" => email}, socket) do
    story = socket.assigns.story
    current_user = socket.assigns.current_user

    case Stories.invite_collaborator(story.id, email, current_user) do
      {:ok, invitation} ->
        # Enable collaboration if not already enabled
        socket = if not socket.assigns.collaboration_enabled do
          enable_collaborative_features(socket)
        else
          socket
        end

        {:noreply, socket
         |> put_flash(:info, "Invitation sent to #{email}")
         |> push_event("collaboration_invitation_sent", %{email: email})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation: #{reason}")}
    end
  end

  # ============================================================================
  # PubSub Message Handlers - Real-time Collaboration
  # ============================================================================

  @impl true
  def handle_info({:new_text_operation, operation, section_id}, socket) do
    # Received operational transform from another user
    if operation.user_id != socket.assigns.current_user.id do
      # Apply remote operation to local state
      updated_story = apply_text_operation_to_story(socket.assigns.story, section_id, operation)

      {:noreply, socket
       |> assign(:story, updated_story)
       |> push_event("apply_remote_operation", %{
           section_id: section_id,
           operation: operation,
           user_id: operation.user_id
         })}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:collaborator_joined, user, session_id}, socket) do
    if socket.assigns.writing_session && socket.assigns.writing_session.id == session_id do
      updated_collaborators = [user | socket.assigns.collaborators]

      {:noreply, socket
       |> assign(:collaborators, updated_collaborators)
       |> put_flash(:info, "#{user.username} joined the writing session")
       |> push_event("collaborator_joined", %{user: user})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:collaborator_left, user, session_id}, socket) do
    if socket.assigns.writing_session && socket.assigns.writing_session.id == session_id do
      updated_collaborators = Enum.reject(socket.assigns.collaborators, &(&1.id == user.id))

      {:noreply, socket
       |> assign(:collaborators, updated_collaborators)
       |> push_event("collaborator_left", %{user: user})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:voice_note_created, voice_note}, socket) do
    if voice_note.story_id == socket.assigns.story.id do
      updated_voice_notes = [voice_note | socket.assigns.voice_notes]

      {:noreply, socket
       |> assign(:voice_notes, updated_voice_notes)
       |> push_event("voice_note_added", %{voice_note: voice_note})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:auto_save, section_id, content}, socket) do
    # Debounced auto-save
    case Stories.update_section_content(section_id, content) do
      {:ok, _} ->
        {:noreply, assign(socket, :save_status, :saved)}

      {:error, _} ->
        {:noreply, socket
         |> assign(:save_status, :error)
         |> put_flash(:error, "Failed to auto-save")}
    end
  end

  # ============================================================================
  # Enhanced UI Rendering with Collaboration Features
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gray-50"
         phx-hook="StoryEditor"
         id="story-editor"
         data-collaboration-enabled={@collaboration_enabled}
         data-story-id={@story.id}
         data-user-id={@current_user.id}>

      <!-- Enhanced Header with Collaboration Status -->
      <div class="bg-white border-b border-gray-200 px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <div>
              <h1 class="text-xl font-semibold text-gray-900"><%= @story.title %></h1>
              <div class="flex items-center space-x-3 mt-1">
                <span class="text-sm text-gray-600">
                  <%= @story.story_type |> String.replace("_", " ") |> String.capitalize %>
                </span>

                <!-- Collaboration Status -->
                <%= if @collaboration_enabled do %>
                  <div class="flex items-center space-x-2">
                    <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                    <span class="text-sm text-green-600">Collaborative Session Active</span>
                  </div>
                <% else %>
                  <button phx-click="enable_collaboration"
                          class="text-sm text-blue-600 hover:text-blue-800">
                    Enable Collaboration
                  </button>
                <% end %>

                <!-- Save Status -->
                <div class="flex items-center space-x-1">
                  <%= case @save_status do %>
                    <% :saved -> %>
                      <svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <span class="text-sm text-green-600">Saved</span>
                    <% :saving -> %>
                      <div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
                      <span class="text-sm text-blue-600">Saving...</span>
                    <% :error -> %>
                      <svg class="w-4 h-4 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01"/>
                      </svg>
                      <span class="text-sm text-red-600">Error</span>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <div class="flex items-center space-x-4">
            <!-- Collaborators Display -->
            <%= if @collaboration_enabled and length(@collaborators) > 0 do %>
              <div class="flex -space-x-2">
                <%= for collaborator <- @collaborators do %>
                  <div class="w-8 h-8 rounded-full bg-blue-500 border-2 border-white flex items-center justify-center"
                       title={collaborator.username}>
                    <span class="text-sm text-white font-medium">
                      <%= String.first(collaborator.username) %>
                    </span>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- Voice Notes Toggle -->
            <%= if @audio_features_enabled do %>
              <button phx-click="toggle_voice_notes_panel"
                      class={["p-2 rounded-lg border",
                             if(@voice_notes_panel_open, do: "bg-blue-500 text-white border-blue-500", else: "bg-white text-gray-600 border-gray-300")]}>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                </svg>
              </button>
            <% end %>

            <!-- Mobile Toggle -->
            <button phx-click="toggle_mobile_view"
                    class="md:hidden p-2 rounded-lg bg-white border border-gray-300">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Mobile View -->
        <%= if @mobile_view do %>
          <.live_component
            module={FrestylWeb.StoriesLive.MobileComponents.VoiceStoryEditor}
            id="mobile-story-editor"
            story={@story}
            current_user={@current_user}
            collaboration_enabled={@collaboration_enabled}
            voice_notes={@voice_notes}
            collaborators={@collaborators}
            active_section={@active_section}
          />
        <% else %>
          <!-- Desktop View -->

          <!-- Left Sidebar - Story Tools -->
          <div class="w-80 bg-white border-r border-gray-200 flex flex-col">
            <div class="border-b border-gray-200 px-4 py-3">
              <h2 class="font-semibold text-gray-900">Story Tools</h2>
            </div>

            <div class="flex-1 overflow-y-auto">
              <!-- Story Sections -->
              <div class="p-4 border-b border-gray-200">
                <div class="flex items-center justify-between mb-3">
                  <h3 class="font-medium text-gray-900">Sections</h3>
                  <button phx-click="add_section"
                          class="text-blue-600 hover:text-blue-800 text-sm">
                    + Add
                  </button>
                </div>

                <div class="space-y-2">
                  <%= for section <- @story.sections || [] do %>
                    <button phx-click="select_section"
                            phx-value-section-id={section.id}
                            class={["w-full text-left p-2 rounded border",
                                   if(section.id == (@active_section && @active_section.id),
                                      do: "bg-blue-50 border-blue-200 text-blue-900",
                                      else: "bg-gray-50 border-gray-200 text-gray-700 hover:bg-gray-100")]}>
                      <div class="font-medium text-sm"><%= section.title %></div>
                      <div class="text-xs text-gray-500 mt-1">
                        <%= get_section_word_count(section) %> words
                      </div>
                    </button>
                  <% end %>
                </div>
              </div>

              <!-- Character Development (Novel/Screenplay) -->
              <%= if @story.story_type in ["novel", "screenplay"] do %>
                <div class="p-4 border-b border-gray-200">
                  <h3 class="font-medium text-gray-900 mb-3">Characters</h3>
                  <.render_character_tools story={@story} />
                </div>
              <% end %>

              <!-- Voice Notes (Audio-Enhanced Stories) -->
              <%= if @audio_features_enabled do %>
                <div class="p-4 border-b border-gray-200">
                  <h3 class="font-medium text-gray-900 mb-3">Voice Notes</h3>
                  <.render_voice_notes_list voice_notes={@voice_notes} active_section={@active_section} />
                </div>
              <% end %>

              <!-- AI Assistant -->
              <%= if @ai_enabled do %>
                <div class="p-4">
                  <h3 class="font-medium text-gray-900 mb-3">AI Assistant</h3>
                  <.render_ai_tools story={@story} active_section={@active_section} />
                </div>
              <% end %>
            </div>
          </div>

          <!-- Main Editor Area -->
          <div class="flex-1 flex flex-col">
            <%= if @active_section do %>
              <!-- Section Editor -->
              <div class="border-b border-gray-200 px-6 py-3 bg-gray-50">
                <div class="flex items-center justify-between">
                  <div>
                    <h3 class="font-medium text-gray-900"><%= @active_section.title %></h3>
                    <p class="text-sm text-gray-600">
                      <%= get_section_type(@editor_mode) %> • <%= get_section_word_count(@active_section) %> words
                    </p>
                  </div>

                  <div class="flex items-center space-x-2">
                    <!-- Voice Note Button -->
                    <%= if @audio_features_enabled do %>
                      <button phx-click="record_voice_note"
                              phx-value-section-id={@active_section.id}
                              class="p-2 rounded-lg bg-blue-100 text-blue-600 hover:bg-blue-200">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                        </svg>
                      </button>
                    <% end %>

                    <!-- Collaboration Cursors Info -->
                    <%= if @collaboration_enabled and length(@collaborators) > 0 do %>
                      <div class="flex items-center space-x-1 text-sm text-gray-500">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        </svg>
                        <span><%= length(@collaborators) %> active</span>
                      </div>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Text Editor with Collaboration -->
              <div class="flex-1 relative">
                <div phx-hook="CollaborativeTextEditor"
                     class="h-full"
                     id="collaborative-text-editor-#{@active_section.id}"
                     data-section-id={@active_section.id}
                     data-collaboration-enabled={@collaboration_enabled}
                     data-session-id={@writing_session && @writing_session.id}>

                  <textarea
                    phx-blur="section_content_changed"
                    phx-value-section-id={@active_section.id}
                    class="w-full h-full p-6 resize-none border-none outline-none text-lg leading-relaxed"
                    placeholder={get_placeholder_content(@editor_mode)}
                    style="font-family: 'Georgia', serif;"
                    ><%= @active_section.content %></textarea>

                  <!-- Collaboration Cursors Overlay -->
                  <%= if @collaboration_enabled do %>
                    <div id="collaboration-cursors-#{@active_section.id}" class="absolute inset-0 pointer-events-none">
                      <!-- Real-time cursors rendered by JavaScript hook -->
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <!-- No Section Selected -->
              <div class="flex-1 flex items-center justify-center">
                <div class="text-center">
                  <svg class="w-16 h-16 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <h3 class="text-lg font-medium text-gray-900 mb-2">Select a section to edit</h3>
                  <p class="text-gray-600 mb-4">Choose a section from the sidebar or create a new one</p>
                  <button phx-click="add_section"
                          class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600">
                    Create First Section
                  </button>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Right Sidebar - Context Tools -->
          <%= if @collaboration_enabled or @audio_features_enabled do %>
            <div class="w-80 bg-white border-l border-gray-200 flex flex-col">
              <div class="border-b border-gray-200 px-4 py-3">
                <h2 class="font-semibold text-gray-900">
                  <%= if @collaboration_enabled, do: "Collaboration", else: "Audio Tools" %>
                </h2>
              </div>

              <div class="flex-1 overflow-y-auto">
                <%= if @collaboration_enabled do %>
                  <.render_collaboration_panel
                    collaborators={@collaborators}
                    writing_session={@writing_session}
                    current_user={@current_user} />
                <% end %>

                <%= if @audio_features_enabled do %>
                  <.render_audio_tools_panel
                    voice_notes={@voice_notes}
                    story={@story}
                    active_section={@active_section} />
                <% end %>
              </div>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helper Components
  # ============================================================================

  defp render_voice_notes_list(assigns) do
    ~H"""
    <div class="space-y-2">
      <%= if length(@voice_notes) > 0 do %>
        <%= for voice_note <- @voice_notes do %>
          <div class="p-2 bg-gray-50 rounded border">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs text-gray-500">
                <%= format_timestamp(voice_note.created_at) %>
              </span>
              <button phx-click="play_voice_note" phx-value-note-id={voice_note.id}
                      class="text-blue-600 text-xs">
                Play
              </button>
            </div>
            <%= if voice_note.transcription do %>
              <p class="text-sm text-gray-700 mb-1"><%= voice_note.transcription %></p>
              <button phx-click="add_voice_note_to_section"
                      phx-value-note-id={voice_note.id}
                      phx-value-section-id={@active_section && @active_section.id}
                      class="text-xs text-blue-600 hover:text-blue-800">
                Add to Section
              </button>
            <% else %>
              <p class="text-sm text-gray-500 italic">Transcribing...</p>
            <% end %>
          </div>
        <% end %>
      <% else %>
        <p class="text-sm text-gray-500 italic">No voice notes yet</p>
      <% end %>
    </div>
    """
  end

  defp render_collaboration_panel(assigns) do
    ~H"""
    <div class="p-4">
      <!-- Active Collaborators -->
      <div class="mb-6">
        <h3 class="font-medium text-gray-900 mb-2">Active Collaborators</h3>
        <%= if length(@collaborators) > 0 do %>
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
      <div class="mb-6">
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

      <!-- Session Settings -->
      <div>
        <h3 class="font-medium text-gray-900 mb-2">Session Settings</h3>
        <div class="space-y-2">
          <button phx-click="toggle_real_time_cursors"
                  class="w-full text-left px-3 py-2 text-sm bg-gray-50 rounded hover:bg-gray-100">
            Real-time Cursors
          </button>
          <button phx-click="toggle_voice_chat"
                  class="w-full text-left px-3 py-2 text-sm bg-gray-50 rounded hover:bg-gray-100">
            Voice Chat
          </button>
          <button phx-click="disable_collaboration"
                  class="w-full text-left px-3 py-2 text-sm text-red-600 bg-red-50 rounded hover:bg-red-100">
            End Collaboration
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions - Missing Implementations
  # ============================================================================

  defp enable_audio_features(socket) do
    story = socket.assigns.story

    case Stories.update_enhanced_story(story, %{"audio_features_enabled" => true}) do
      {:ok, updated_story} ->
        voice_notes = load_story_voice_notes(story.id)

        socket
        |> assign(:story, updated_story)
        |> assign(:audio_features_enabled, true)
        |> assign(:voice_notes, voice_notes)

      {:error, _} ->
        socket |> put_flash(:error, "Failed to enable audio features")
    end
  end

  defp apply_text_operation_to_story(story, section_id, operation) do
    # Apply operational transform to specific story section
    updated_sections = Enum.map(story.sections, fn section ->
      if section.id == section_id do
        # Apply the operation to this section's content
        case operation.action do
          :replace ->
            %{section | content: operation.data.new}
          :insert ->
            current_content = section.content || ""
            new_content = String.slice(current_content, 0, operation.data.position) <>
                         operation.data.text <>
                         String.slice(current_content, operation.data.position..-1)
            %{section | content: new_content}
          :delete ->
            current_content = section.content || ""
            new_content = String.slice(current_content, 0, operation.data.position) <>
                         String.slice(current_content, operation.data.position + operation.data.length..-1)
            %{section | content: new_content}
          _ ->
            section
        end
      else
        section
      end
    end)

    %{story | sections: updated_sections}
  end

  defp load_story_voice_notes(story_id) do
    # Load voice notes for the story
    Stories.get_story_voice_notes(story_id)
  end

  defp get_or_create_personal_workspace(user) do
    Channels.get_or_create_personal_workspace(user)
  end

  defp get_ai_writing_style(intent) do
    case intent do
      "entertain" -> "creative"
      "persuade" -> "persuasive"
      "educate" -> "informative"
      "showcase" -> "professional"
      _ -> "balanced"
    end
  end

  defp parse_boolean_param(params, key) do
    case Map.get(params, key) do
      "true" -> true
      "false" -> false
      true -> true
      false -> false
      _ -> false
    end
  end

  defp get_placeholder_content(editor_mode) do
    case editor_mode do
      :manuscript ->
        "Once upon a time...\n\nStart writing your story here. Use the tools on the left to develop characters and plot points."

      :business ->
        "Executive Summary\n\nProvide a brief overview of the key findings...\n\nProblem Statement\n\nDescribe the challenge or opportunity..."

      :experimental ->
        "Welcome to your experimental story space!\n\nThis is where creativity meets technology. Start writing and explore the unique features available for this format."

      _ ->
        "Start writing your story here...\n\nUse the sidebar tools to organize your thoughts and collaborate with others."
    end
  end

  defp get_section_type(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapter"
      :business -> "Section"
      :experimental -> "Segment"
      _ -> "Section"
    end
  end

  # ============================================================================
  # Missing Render Components
  # ============================================================================

  defp render_character_tools(assigns) do
    ~H"""
    <div class="space-y-3">
      <%= if @story.character_data && length(@story.character_data) > 0 do %>
        <%= for character <- @story.character_data do %>
          <div class="p-3 bg-gray-50 rounded border">
            <div class="flex items-center justify-between mb-2">
              <h4 class="font-medium text-gray-900 text-sm"><%= character.name %></h4>
              <button phx-click="edit_character" phx-value-character-id={character.id}
                      class="text-blue-600 text-xs hover:text-blue-800">
                Edit
              </button>
            </div>
            <p class="text-xs text-gray-600"><%= character.description %></p>
          </div>
        <% end %>
      <% else %>
        <div class="text-center py-4">
          <p class="text-sm text-gray-500 mb-2">No characters yet</p>
          <button phx-click="add_character"
                  class="px-3 py-1 bg-blue-500 text-white rounded text-sm hover:bg-blue-600">
            Add Character
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_ai_tools(assigns) do
    ~H"""
    <div class="space-y-3">
      <button phx-click="generate_ai_suggestion"
              phx-value-type="character_development"
              class="w-full text-left p-3 bg-purple-50 rounded border border-purple-200 hover:bg-purple-100">
        <div class="font-medium text-purple-900 text-sm">Character Development</div>
        <div class="text-xs text-purple-600 mt-1">AI-powered character suggestions</div>
      </button>

      <button phx-click="generate_ai_suggestion"
              phx-value-type="plot_advancement"
              class="w-full text-left p-3 bg-purple-50 rounded border border-purple-200 hover:bg-purple-100">
        <div class="font-medium text-purple-900 text-sm">Plot Advancement</div>
        <div class="text-xs text-purple-600 mt-1">Story progression ideas</div>
      </button>

      <button phx-click="generate_ai_suggestion"
              phx-value-type="dialogue_enhancement"
              class="w-full text-left p-3 bg-purple-50 rounded border border-purple-200 hover:bg-purple-100">
        <div class="font-medium text-purple-900 text-sm">Dialogue Enhancement</div>
        <div class="text-xs text-purple-600 mt-1">Improve character dialogue</div>
      </button>

      <%= if @active_section && @active_section.content do %>
        <button phx-click="analyze_section_content"
                phx-value-section-id={@active_section.id}
                class="w-full text-left p-3 bg-green-50 rounded border border-green-200 hover:bg-green-100">
          <div class="font-medium text-green-900 text-sm">Analyze This Section</div>
          <div class="text-xs text-green-600 mt-1">Get AI feedback on current content</div>
        </button>
      <% end %>
    </div>
    """
  end

  defp render_audio_tools_panel(assigns) do
    ~H"""
    <div class="p-4">
      <!-- Voice Notes Section -->
      <div class="mb-6">
        <h3 class="font-medium text-gray-900 mb-3">Voice Notes</h3>

        <button phx-click="record_voice_note"
                phx-value-section-id={@active_section && @active_section.id}
                class="w-full p-3 bg-blue-50 rounded border border-blue-200 hover:bg-blue-100 mb-3">
          <div class="flex items-center justify-center space-x-2">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
            </svg>
            <span class="font-medium text-blue-600">Record Voice Note</span>
          </div>
        </button>

        <div class="space-y-2">
          <%= if length(@voice_notes) > 0 do %>
            <%= for voice_note <- @voice_notes do %>
              <div class="p-2 bg-gray-50 rounded border">
                <div class="flex items-center justify-between mb-1">
                  <span class="text-xs text-gray-500">
                    <%= format_timestamp(voice_note.created_at) %>
                  </span>
                  <button phx-click="play_voice_note" phx-value-note-id={voice_note.id}
                          class="text-blue-600 text-xs hover:text-blue-800">
                    Play
                  </button>
                </div>
                <%= if voice_note.transcription do %>
                  <p class="text-sm text-gray-700 mb-2"><%= voice_note.transcription %></p>
                  <button phx-click="add_voice_note_to_section"
                          phx-value-note-id={voice_note.id}
                          phx-value-section-id={@active_section && @active_section.id}
                          class="text-xs text-blue-600 hover:text-blue-800">
                    Add to Section
                  </button>
                <% else %>
                  <p class="text-sm text-gray-500 italic">Transcribing...</p>
                <% end %>
              </div>
            <% end %>
          <% else %>
            <p class="text-sm text-gray-500 italic">No voice notes yet</p>
          <% end %>
        </div>
      </div>

      <!-- Narration Tools -->
      <div>
        <h3 class="font-medium text-gray-900 mb-3">Narration Tools</h3>

        <button phx-click="start_narration_mode"
                class="w-full p-3 bg-green-50 rounded border border-green-200 hover:bg-green-100 mb-2">
          <div class="font-medium text-green-600 text-sm">Start Narration</div>
          <div class="text-xs text-green-500 mt-1">Read your story aloud</div>
        </button>

        <button phx-click="export_audio_story"
                class="w-full p-3 bg-orange-50 rounded border border-orange-200 hover:bg-orange-100">
          <div class="font-medium text-orange-600 text-sm">Export Audio Story</div>
          <div class="text-xs text-orange-500 mt-1">Create audiobook version</div>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions (continued from original file)
  # ============================================================================

  defp determine_editor_mode(story, format_config) do
    # Check if there's editor preference data in the story
    case Map.get(story, :editor_preferences) do
      %{editor_mode: mode} when mode in [:manuscript, :business, :experimental] ->
        mode

      _ ->
        # Fall back to format-based determination
        determine_editor_mode_from_format(story.story_type, format_config)
    end
  end

  defp determine_editor_mode_from_format(story_type, format_config) do
    cond do
      story_type in ["novel", "screenplay", "poetry"] -> :manuscript
      story_type in ["case_study", "data_story", "report"] -> :business
      story_type in ["live_story", "narrative_beats", "interactive"] -> :experimental
      format_config && Map.get(format_config, :default_editor_mode) ->
        String.to_atom(format_config.default_editor_mode)
      true -> :standard
    end
  end

  defp get_current_section(story) do
    case story.sections do
      [] -> nil
      [first | _] -> first
    end
  end

  defp calculate_word_count(story) do
    story.sections
    |> Enum.map(& &1.content || "")
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  defp get_active_collaborators(session_id) when is_binary(session_id) do
    Sessions.get_session_participants(session_id)
    |> Enum.map(&get_user_basic_info/1)
  end

  defp get_active_collaborators(_), do: []

  defp get_user_basic_info(user_id) do
    # Would fetch from Accounts context
    %{
      id: user_id,
      username: "User #{user_id}",  # Placeholder
      avatar_url: nil
    }
  end

  defp parse_editor_state_params(params) do
    %{
      mode: Map.get(params, "mode"),
      intent: Map.get(params, "intent"),
      collab: parse_boolean_param(params, "collab"),
      welcome: parse_boolean_param(params, "welcome"),
      focus: Map.get(params, "focus"),
      template: Map.get(params, "template"),
      audio: parse_boolean_param(params, "audio")
    }
  end

  defp apply_editor_state_configuration(socket, editor_state) do
    socket = socket
    |> maybe_apply_focus_mode(editor_state.focus)
    |> maybe_apply_intent_configuration(editor_state.intent)

    # Apply collaboration if requested
    if editor_state.collab do
      enable_collaborative_features(socket)
    else
      socket
    end
  end

  defp maybe_apply_focus_mode(socket, nil), do: socket
  defp maybe_apply_focus_mode(socket, focus_mode) do
    assign(socket, :focus_mode, focus_mode)
  end

  defp maybe_apply_intent_configuration(socket, nil), do: socket
  defp maybe_apply_intent_configuration(socket, intent) do
    socket
    |> apply_ai_assistance_level(intent)
    |> maybe_show_welcome_for_intent(intent)
  end

  defp apply_ai_assistance_level(socket, intent) do
    ai_level = case intent do
      "entertain" -> "creative"
      "persuade" -> "analytical"
      "educate" -> "structured"
      _ -> "balanced"
    end

    socket
    |> assign(:ai_assistance_level, ai_level)
    |> assign(:ai_writing_style, get_ai_writing_style(intent))
  end

  defp maybe_show_welcome_for_intent(socket, _intent) do
    # Could show intent-specific welcome messages
    socket
  end

  defp get_section_word_count(section) do
    (section.content || "")
    |> String.split()
    |> length()
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end

  defp get_current_user_from_session(session) do
    # Extract user from session - implementation depends on your auth system
    # This is a placeholder
    %{id: "user_id", username: "username"}
  end

  defp get_device_info(socket) do
    # Extract device information from socket assigns or headers
    %{
      is_mobile: false, # Would detect from user agent
      device_type: "desktop",
      screen_size: "large",
      supports_audio: true
    }
  end

  defp generate_text_operations(old_content, new_content) do
    # Simple diff algorithm - would use proper OT library in production
    if old_content != new_content do
      [%{type: :replace, old: old_content, new: new_content}]
    else
      []
    end
  end

  defp get_section_by_id(story, section_id) do
    Enum.find(story.sections, &(&1.id == section_id))
  end

  defp update_section_content_in_story(story, section_id, new_content) do
    updated_sections = Enum.map(story.sections, fn section ->
      if section.id == section_id do
        %{section | content: new_content}
      else
        section
      end
    end)

    %{story | sections: updated_sections}
  end

  defp get_section_word_count(section) do
    (section.content || "")
    |> String.split()
    |> length()
  end

  defp format_timestamp(datetime) do
    datetime
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 5)
  end

    # Helper Functions

    defp is_new_story?(story) do
    # Check if story has minimal content
    total_content = story.sections
    |> Enum.map(& &1.content || "")
    |> Enum.join("")
    |> String.trim()

    String.length(total_content) < 50
  end

  defp find_section_by_id(sections, section_id) when is_list(sections) do
    Enum.find(sections, fn section ->
      to_string(section.id) == to_string(section_id)
    end)
  end
  defp find_section_by_id(_, _), do: nil

  defp get_ai_config_for_intent(intent) do
    case intent do
      "entertain" ->
        %{
          level: "creative",
          suggestions_enabled: true,
          auto_suggestions: true,
          creativity_boost: true
        }

      "educate" ->
        %{
          level: "structured",
          suggestions_enabled: true,
          auto_suggestions: false,
          fact_checking: true
        }

      "persuade" ->
        %{
          level: "strategic",
          suggestions_enabled: true,
          auto_suggestions: false,
          argument_analysis: true
        }

      "document" ->
        %{
          level: "minimal",
          suggestions_enabled: false,
          auto_suggestions: false,
          grammar_only: true
        }

      _ ->
        %{
          level: "balanced",
          suggestions_enabled: true,
          auto_suggestions: false
        }
    end
  end

  defp apply_template_to_story(story, template_key) do
    case Templates.get_by_key(template_key) do
      nil ->
        {:error, :template_not_found}

      template ->
        # Apply template structure to story
        updated_sections = build_sections_from_template(template)
        updated_story = %{story | sections: updated_sections}

        # Save the updated story
        Stories.update_enhanced_story(story.id, %{sections: updated_sections})
    end
  end

  defp build_sections_from_template(template) do
    template.sections
    |> Enum.with_index(1)
    |> Enum.map(fn {section_template, index} ->
      %{
        id: System.unique_integer([:positive]),
        title: section_template.title,
        type: section_template.type,
        content: section_template.placeholder || "",
        order: index,
        created_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }
    end)
  end

  # ============================================================================
  # ENHANCED EDITOR MODE DETERMINATION
  # ============================================================================

  defp determine_editor_mode(story, format_config) do
    # Check if there's editor preference data in the story
    case Map.get(story, :editor_preferences) do
      %{editor_mode: mode} when mode in [:manuscript, :business, :experimental] ->
        mode

      _ ->
        # Fall back to format-based determination
        determine_editor_mode_from_format(story.story_type, format_config)
    end
  end

  defp determine_editor_mode_from_format(story_type, format_config) do
    cond do
      story_type in ["novel", "screenplay", "poetry"] -> :manuscript
      story_type in ["case_study", "data_story", "report"] -> :business
      story_type in ["live_story", "narrative_beats", "interactive"] -> :experimental
      format_config && Map.get(format_config, :default_editor_mode) ->
        String.to_atom(format_config.default_editor_mode)
      true -> :standard
    end
  end

  defp determine_editor_mode(story, format_config) do
    cond do
      story.story_type in ["novel", "screenplay"] -> :manuscript
      story.story_type in ["case_study", "data_story"] -> :business
      story.story_type in ["live_story", "narrative_beats"] -> :experimental
      true -> :standard
    end
  end

  defp get_current_section(story) do
    case story.sections do
      [] -> create_initial_section(story)
      [first | _] -> first
    end
  end

  defp create_initial_section(story) do
    %{
      id: System.unique_integer([:positive]),
      type: get_initial_section_type(story.story_type),
      title: get_initial_section_title(story.story_type),
      content: "",
      order: 1
    }
  end

  defp get_initial_section_type(story_type) do
    case story_type do
      "novel" -> "chapter"
      "screenplay" -> "scene"
      "case_study" -> "overview"
      "article" -> "introduction"
      _ -> "section"
    end
  end

  defp get_initial_section_title(story_type) do
    case story_type do
      "novel" -> "Chapter 1"
      "screenplay" -> "Scene 1"
      "case_study" -> "Executive Summary"
      "article" -> "Introduction"
      _ -> "Getting Started"
    end
  end

  defp get_active_collaborators(story_id) do
    # This would fetch from your collaboration system
    Collaboration.get_active_collaborators(story_id)
  end

  defp calculate_word_count(story) do
    story.sections
    |> Enum.map(& &1.content || "")
    |> Enum.join(" ")
    |> String.split()
    |> length()
  end

  defp update_story_section(story, section_id, content) do
    updated_sections = Enum.map(story.sections, fn section ->
      if section.id == String.to_integer(section_id) do
        %{section | content: content}
      else
        section
      end
    end)

    %{story | sections: updated_sections}
  end

  defp get_section_content(story, section_id) do
    story.sections
    |> Enum.find(fn section -> section.id == String.to_integer(section_id) end)
    |> case do
      nil -> ""
      section -> section.content || ""
    end
  end

  defp broadcast_content_change(story_id, section_id, content, user) do
    PubSub.broadcast(Frestyl.PubSub, "story_collaboration:#{story_id}",
      {:content_updated_by, user.id, section_id, content})
  end

  defp get_current_user_from_session(session) do
    # Your existing session handling
    session["current_user"]
  end

  # Render functions (simplified versions)
  defp render_manuscript_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Characters</h4>
        <button class="text-sm text-blue-600">Add Character</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Plot Points</h4>
        <button class="text-sm text-blue-600">Add Plot Point</button>
      </div>
    </div>
    """
  end

  defp render_business_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Data Sources</h4>
        <button class="text-sm text-blue-600">Connect Data</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Stakeholders</h4>
        <button class="text-sm text-blue-600">Add Stakeholder</button>
      </div>
    </div>
    """
  end

  defp render_experimental_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Live Features</h4>
        <button class="text-sm text-red-600">🔴 Go Live</button>
      </div>
    </div>
    """
  end

  defp render_standard_tools(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Outline</h4>
        <button class="text-sm text-blue-600">Add Item</button>
      </div>
      <div>
        <h4 class="text-sm font-medium text-gray-900 mb-2">Research</h4>
        <button class="text-sm text-blue-600">Add Note</button>
      </div>
    </div>
    """
  end

    @doc """
  Parse editor state parameters from URL params
  """
  defp parse_editor_state_params(params) do
    %{
      mode: Map.get(params, "mode"),
      intent: Map.get(params, "intent"),
      source: Map.get(params, "source"),
      template: Map.get(params, "template"),
      focus: Map.get(params, "focus"),
      section: Map.get(params, "section"),
      collaboration: Map.get(params, "collab") == "true",
      continue: Map.get(params, "continue") == "true"
    }
  end

  @doc """
  Apply editor state configuration based on parameters
  """
  defp apply_editor_state_configuration(socket, state_params) do
    socket
    |> maybe_override_editor_mode(state_params.mode)
    |> maybe_set_focus_mode(state_params.focus)
    |> maybe_enable_collaboration_panel(state_params.collaboration)
    |> maybe_show_welcome_for_new_story(state_params.source)
    |> maybe_navigate_to_section(state_params.section)
    |> maybe_configure_ai_assistance(state_params.intent)
  end

  @doc """
  Override editor mode if specified in params
  """
  defp maybe_override_editor_mode(socket, nil), do: socket
  defp maybe_override_editor_mode(socket, mode) when mode in ["manuscript", "business", "experimental", "standard"] do
    assign(socket, :editor_mode, String.to_atom(mode))
  end
  defp maybe_override_editor_mode(socket, _), do: socket

  @doc """
  Set focus mode based on parameters
  """
  defp maybe_set_focus_mode(socket, nil), do: socket
  defp maybe_set_focus_mode(socket, focus_mode) do
    socket
    |> assign(:focus_mode, focus_mode)
    |> push_event("set_focus_mode", %{mode: focus_mode})
  end

  @doc """
  Enable collaboration panel if requested
  """
  defp maybe_enable_collaboration_panel(socket, false), do: socket
  defp maybe_enable_collaboration_panel(socket, true) do
    assign(socket, :show_collaboration_panel, true)
  end

  @doc """
  Show welcome modal for stories created from hub
  """
  defp maybe_show_welcome_for_new_story(socket, "hub_creation") do
    story = socket.assigns.story

    # Show welcome if this is a brand new story (no content yet)
    if is_new_story?(story) do
      socket
      |> assign(:show_welcome_modal, true)
      |> push_event("show_getting_started_tips", %{
        story_type: story.story_type,
        intent: story.intent_category
      })
    else
      socket
    end
  end
  defp maybe_show_welcome_for_new_story(socket, _), do: socket

  @doc """
  Navigate to specific section if specified
  """
  defp maybe_navigate_to_section(socket, nil), do: socket
  defp maybe_navigate_to_section(socket, section_id) do
    story = socket.assigns.story

    case find_section_by_id(story.sections, section_id) do
      nil -> socket
      section ->
        socket
        |> assign(:active_section, section)
        |> push_event("navigate_to_section", %{section_id: section_id})
    end
  end

  @doc """
  Configure AI assistance based on intent
  """
  defp maybe_configure_ai_assistance(socket, nil), do: socket
  defp maybe_configure_ai_assistance(socket, intent) when socket.assigns.ai_enabled do
    ai_config = get_ai_config_for_intent(intent)

    socket
    |> assign(:ai_assistance_level, ai_config.level)
    |> assign(:ai_suggestions_enabled, ai_config.suggestions_enabled)
    |> push_event("configure_ai_assistance", ai_config)
  end
  defp maybe_configure_ai_assistance(socket, _), do: socket

  defp get_export_formats(format_config) do
    case format_config do
      %{export_formats: formats} when is_list(formats) ->
        Enum.map(formats, fn format ->
          %{key: format, name: format_name(format)}
        end)
      _ ->
        [%{key: "pdf", name: "PDF"}, %{key: "html", name: "HTML"}]
    end
  end

  defp format_name(format) do
    case format do
      "pdf" -> "PDF Document"
      "html" -> "Web Page"
      "epub" -> "eBook (EPUB)"
      "docx" -> "Word Document"
      _ -> String.upcase(format)
    end
  end

  defp get_section_label(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapters"
      :business -> "Sections"
      :experimental -> "Segments"
      _ -> "Sections"
    end
  end

  defp get_section_type(editor_mode) do
    case editor_mode do
      :manuscript -> "Chapter"
      :business -> "Section"
      :experimental -> "Segment"
      _ -> "Section"
    end
  end

  defp get_placeholder_content(editor_mode) do
    case editor_mode do
      :manuscript ->
        "<p>Once upon a time...</p><p>Start writing your story here. Use the tools on the left to develop characters and plot points.</p>"

      :business ->
        "<h2>Executive Summary</h2><p>Provide a brief overview of the key findings...</p><h2>Problem Statement</h2><p>Describe the challenge or opportunity...</p>"

      :experimental ->
        "<p>Welcome to your experimental story space!</p><p>This is where creativity meets technology. Start writing and explore the unique features available for this format.</p>"

      _ ->
        "<p>Start writing your story here...</p><p>Use the sidebar tools to organize your thoughts and collaborate with others.</p>"
    end
  end
end
