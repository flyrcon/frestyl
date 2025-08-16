# lib/frestyl_web/live/podcast_live/studio.ex
defmodule FrestylWeb.PodcastLive.Studio do
  @moduledoc """
  Unified podcast creation and editing studio.
  Integrates recording, editing, and publishing in one interface.
  """

  use FrestylWeb, :live_view

  alias Frestyl.{Podcasts, ContentEditing, Sessions}
  alias Frestyl.Features.{FeatureGate, TierManager}
  alias Frestyl.Features.SessionManager

  @impl true
  def mount(%{"slug" => channel_slug, "show_id" => show_id}, _session, socket) do
    show = Podcasts.get_show!(show_id)
    user = socket.assigns.current_user
    tier = TierManager.get_account_tier(user)

    if show.creator_id == user.id do
      socket = socket
      |> assign(:page_title, "Podcast Studio - #{show.title}")
      |> assign(:show, show)
      |> assign(:user_tier, tier)
      |> assign(:feature_gates, build_podcast_feature_gates(tier))
      |> assign(:studio_mode, :overview) # overview, recording, editing, publishing
      |> assign(:current_episode, nil)
      |> assign(:editing_project, nil)
      |> assign(:episodes, list_recent_episodes(show_id))
      |> assign(:studio_state, initialize_studio_state())

      {:ok, socket}
    else
      {:ok, redirect(socket, to: ~p"/channels/#{channel_slug}")}
    end
  end

  @impl true
  def handle_params(%{"episode_id" => episode_id}, _uri, socket) do
    episode = Podcasts.get_episode!(episode_id)

    # Determine studio mode based on episode status
    studio_mode = case episode.status do
      status when status in ["draft", "scheduled"] -> :recording
      status when status in ["recording", "processing"] -> :editing
      "ready" -> :publishing
      _ -> :overview
    end

    socket = socket
    |> assign(:current_episode, episode)
    |> assign(:studio_mode, studio_mode)
    |> load_episode_context(episode)

    {:noreply, socket}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, :studio_mode, :overview)}
  end

  # Studio Mode Switching
  @impl true
  def handle_event("switch_mode", %{"mode" => mode}, socket) do
    new_mode = String.to_atom(mode)

    socket = case new_mode do
      :recording -> switch_to_recording_mode(socket)
      :editing -> switch_to_editing_mode(socket)
      :publishing -> switch_to_publishing_mode(socket)
      _ -> assign(socket, :studio_mode, :overview)
    end

    {:noreply, socket}
  end

  # Episode Management
  @impl true
  def handle_event("create_episode", %{"episode" => episode_params}, socket) do
    case Podcasts.create_episode(socket.assigns.show.id, episode_params, socket.assigns.current_user) do
      {:ok, episode} ->
        {:noreply,
         socket
         |> assign(:current_episode, episode)
         |> assign(:studio_mode, :recording)
         |> put_flash(:info, "Episode created! Ready to start recording.")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create episode")}
    end
  end

  @impl true
  def handle_event("start_recording", _params, socket) do
    episode = socket.assigns.current_episode

    case Podcasts.start_live_recording(episode.id, socket.assigns.current_user) do
      {:ok, session_manager} ->
        # Redirect to integrated recording interface
        {:noreply,
         socket
         |> assign(:recording_session, session_manager)
         |> assign(:studio_mode, :recording)
         |> put_flash(:info, "Recording started!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("stop_recording", _params, socket) do
    episode = socket.assigns.current_episode

    # Stop recording and process to editing
    case process_recording_to_editing(episode) do
      {:ok, editing_project} ->
        {:noreply,
         socket
         |> assign(:editing_project, editing_project)
         |> assign(:studio_mode, :editing)
         |> put_flash(:info, "Recording stopped. Ready for editing!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to process recording: #{reason}")}
    end
  end

  # Publishing
  @impl true
  def handle_event("publish_episode", %{"publish_settings" => settings}, socket) do
    episode = socket.assigns.current_episode

    case Podcasts.publish_episode(episode.id, socket.assigns.current_user) do
      {:ok, published_episode} ->
        {:noreply,
         socket
         |> assign(:current_episode, published_episode)
         |> put_flash(:info, "Episode published successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to publish: #{reason}")}
    end
  end

  # Guest Management
  @impl true
  def handle_event("invite_guest", %{"guest" => guest_params}, socket) do
    episode = socket.assigns.current_episode

    case Podcasts.invite_guest(episode.id, guest_params, socket.assigns.current_user) do
      {:ok, guest} ->
        {:noreply,
         socket
         |> update_episode_guests([guest | socket.assigns.current_episode.guests])
         |> put_flash(:info, "Guest invitation sent!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to invite guest")}
    end
  end

  # Helper Functions

  defp switch_to_recording_mode(socket) do
    socket
    |> assign(:studio_mode, :recording)
    |> load_recording_interface()
  end

  defp switch_to_editing_mode(socket) do
    episode = socket.assigns.current_episode

    if episode do
      editing_project = get_or_create_editing_project(episode)
      socket
      |> assign(:studio_mode, :editing)
      |> assign(:editing_project, editing_project)
      |> load_editing_interface()
    else
      socket
      |> assign(:studio_mode, :editing)
      |> put_flash(:info, "Select an episode to edit")
    end
  end

  defp switch_to_publishing_mode(socket) do
    socket
    |> assign(:studio_mode, :publishing)
    |> load_publishing_interface()
  end

  defp load_episode_context(socket, episode) do
    socket
    |> assign(:episode_guests, episode.guests)
    |> assign(:episode_media, load_episode_media(episode))
    |> assign(:episode_analytics, load_episode_analytics(episode))
  end

  defp process_recording_to_editing(episode) do
    # Process recorded audio and create editing project
    case Podcasts.process_recording_to_episode(episode.id) do
      {:ok, processed_episode} ->
        # Create editing project from processed recording
        create_editing_project_from_episode(processed_episode)

      error -> error
    end
  end

  defp create_editing_project_from_episode(episode) do
    project_params = %{
      name: "Edit: #{episode.title}",
      description: "Editing project for podcast episode",
      project_type: "podcast",
      channel_id: episode.show.channel_id,
      metadata: %{
        episode_id: episode.id,
        show_id: episode.show_id,
        podcast_project: true
      }
    }

    ContentEditing.create_project(project_params, episode.creator)
  end

  defp get_or_create_editing_project(episode) do
    # Look for existing editing project for this episode
    case find_existing_editing_project(episode.id) do
      nil -> create_editing_project_from_episode(episode) |> elem(1)
      project -> project
    end
  end

  defp build_podcast_feature_gates(tier) do
    %{
      recording: true, # All tiers can record
      multi_track: FeatureGate.feature_available?(tier, :multi_track_recording),
      guest_invites: FeatureGate.feature_available?(tier, :podcast_guests),
      ai_editing: FeatureGate.feature_available?(tier, :ai_editing_assistance),
      advanced_effects: FeatureGate.feature_available?(tier, :premium_effects),
      auto_chapters: FeatureGate.feature_available?(tier, :automatic_chapters),
      auto_transcription: FeatureGate.feature_available?(tier, :auto_transcription),
      distribution: FeatureGate.feature_available?(tier, :podcast_distribution),
      analytics: FeatureGate.feature_available?(tier, :podcast_analytics),
      custom_branding: FeatureGate.feature_available?(tier, :custom_branding)
    }
  end

  defp initialize_studio_state do
    %{
      recording_active: false,
      editing_active: false,
      auto_save_enabled: true,
      collaboration_enabled: true,
      ai_assistance_enabled: false
    }
  end

  defp load_recording_interface(socket) do
    # Load recording-specific UI state
    socket
    |> assign(:recording_tracks, [])
    |> assign(:guest_connections, [])
    |> assign(:recording_duration, 0)
  end

  defp load_editing_interface(socket) do
    # Load editing-specific UI state
    editing_project = socket.assigns.editing_project

    socket
    |> assign(:timeline_data, load_timeline_data(editing_project))
    |> assign(:available_effects, load_available_effects(socket.assigns.user_tier))
    |> assign(:editing_tools, load_editing_tools(socket.assigns.user_tier))
  end

  defp load_publishing_interface(socket) do
    # Load publishing-specific UI state
    socket
    |> assign(:distribution_platforms, get_available_platforms(socket.assigns.user_tier))
    |> assign(:publishing_analytics, load_publishing_analytics(socket.assigns.show))
  end

  # Placeholder functions
  defp list_recent_episodes(show_id), do: []
  defp load_episode_media(_episode), do: []
  defp load_episode_analytics(_episode), do: %{}
  defp find_existing_editing_project(_episode_id), do: nil
  defp update_episode_guests(socket, guests), do: assign(socket, :episode_guests, guests)
  defp load_timeline_data(_project), do: %{}
  defp load_available_effects(_tier), do: []
  defp load_editing_tools(_tier), do: []
  defp get_available_platforms(_tier), do: []
  defp load_publishing_analytics(_show), do: %{}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="podcast-studio min-h-screen bg-gray-900 text-white">
      <!-- Studio Header -->
      <div class="studio-header bg-gray-800 border-b border-gray-700 px-6 py-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <h1 class="text-2xl font-bold"><%= @show.title %> Studio</h1>
            <div class="flex items-center space-x-2">
              <div class="w-3 h-3 bg-green-500 rounded-full animate-pulse"></div>
              <span class="text-sm text-green-400">Studio Active</span>
            </div>
          </div>

          <!-- Studio Mode Switcher -->
          <div class="flex items-center space-x-2 bg-gray-700 rounded-lg p-1">
            <.mode_button mode={:overview} current={@studio_mode} />
            <.mode_button mode={:recording} current={@studio_mode} />
            <.mode_button mode={:editing} current={@studio_mode} />
            <.mode_button mode={:publishing} current={@studio_mode} />
          </div>
        </div>
      </div>

      <!-- Studio Content -->
      <div class="studio-content flex-1 flex">
        <%= case @studio_mode do %>
          <% :overview -> %>
            <.overview_interface
              show={@show}
              episodes={@episodes}
              feature_gates={@feature_gates}
            />

          <% :recording -> %>
            <.recording_interface
              episode={@current_episode}
              feature_gates={@feature_gates}
              studio_state={@studio_state}
            />

          <% :editing -> %>
            <.editing_interface
              episode={@current_episode}
              editing_project={@editing_project}
              feature_gates={@feature_gates}
            />

          <% :publishing -> %>
            <.publishing_interface
              episode={@current_episode}
              show={@show}
              feature_gates={@feature_gates}
            />
        <% end %>
      </div>
    </div>
    """
  end

  # UI Components

  def mode_button(assigns) do
    active = assigns.current == assigns.mode

    ~H"""
    <button
      phx-click="switch_mode"
      phx-value-mode={@mode}
      class={[
        "px-4 py-2 rounded-md text-sm font-medium transition-colors",
        active && "bg-blue-600 text-white" || "text-gray-300 hover:text-white hover:bg-gray-600"
      ]}
    >
      <%= String.capitalize(to_string(@mode)) %>
    </button>
    """
  end

  def overview_interface(assigns) do
    ~H"""
    <div class="overview-interface flex-1 p-6">
      <!-- Quick Stats -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        <.stat_card title="Total Episodes" value={length(@episodes)} />
        <.stat_card title="Monthly Listens" value="1.2K" />
        <.stat_card title="Avg. Duration" value="45m" />
        <.stat_card title="Growth Rate" value="+12%" />
      </div>

      <!-- Recent Episodes -->
      <div class="bg-gray-800 rounded-lg p-6 mb-8">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-xl font-semibold">Recent Episodes</h2>
          <button
            phx-click="create_episode"
            class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-md transition-colors"
          >
            + New Episode
          </button>
        </div>

        <div class="space-y-4">
          <div
            :for={episode <- @episodes}
            class="episode-card flex items-center justify-between p-4 bg-gray-700 rounded-lg hover:bg-gray-600 transition-colors"
          >
            <div class="flex items-center space-x-4">
              <div class="w-12 h-12 bg-gray-600 rounded-lg flex items-center justify-center">
                <span class="text-lg font-bold"><%= episode.episode_number %></span>
              </div>
              <div>
                <h3 class="font-medium"><%= episode.title %></h3>
                <p class="text-sm text-gray-400"><%= episode.status %> • <%= format_duration(episode.duration) %></p>
              </div>
            </div>

            <div class="flex items-center space-x-2">
              <.status_badge status={episode.status} />
              <button class="p-2 text-gray-400 hover:text-white">
                <.icon name="hero-ellipsis-horizontal" class="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Feature Highlights -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <.feature_highlight
          title="AI-Powered Editing"
          description="Automatic noise reduction, chapter detection, and show notes generation"
          available={@feature_gates.ai_editing}
        />
        <.feature_highlight
          title="Multi-Platform Distribution"
          description="Publish to Spotify, Apple Podcasts, Google Podcasts, and more"
          available={@feature_gates.distribution}
        />
      </div>
    </div>
    """
  end

  def recording_interface(assigns) do
    ~H"""
    <div class="recording-interface flex-1 flex">
      <!-- Recording Controls -->
      <div class="recording-controls w-80 bg-gray-800 border-r border-gray-700 p-6">
        <h2 class="text-xl font-semibold mb-6">Recording Studio</h2>

        <div :if={@episode} class="episode-info mb-6 p-4 bg-gray-700 rounded-lg">
          <h3 class="font-medium mb-2"><%= @episode.title %></h3>
          <p class="text-sm text-gray-400">Episode <%= @episode.episode_number %></p>
        </div>

        <!-- Recording Status -->
        <div class="recording-status mb-6">
          <div class="flex items-center justify-between mb-4">
            <span class="text-sm font-medium">Status</span>
            <div class={[
              "px-2 py-1 rounded text-xs font-medium",
              @studio_state.recording_active && "bg-red-600 text-white" || "bg-gray-600 text-gray-300"
            ]}>
              <%= if @studio_state.recording_active, do: "Recording", else: "Ready" %>
            </div>
          </div>

          <div class="text-2xl font-mono font-bold mb-2">
            <%= format_recording_time(@studio_state[:recording_duration] || 0) %>
          </div>

          <button
            phx-click={if @studio_state.recording_active, do: "stop_recording", else: "start_recording"}
            class={[
              "w-full py-3 rounded-lg font-medium transition-colors",
              @studio_state.recording_active && "bg-red-600 hover:bg-red-700" || "bg-blue-600 hover:bg-blue-700"
            ]}
          >
            <%= if @studio_state.recording_active, do: "Stop Recording", else: "Start Recording" %>
          </button>
        </div>

        <!-- Guest Management -->
        <div class="guest-management">
          <h3 class="font-medium mb-4">Guests</h3>

          <div class="space-y-2 mb-4">
            <div
              :for={guest <- @episode_guests || []}
              class="flex items-center justify-between p-3 bg-gray-700 rounded"
            >
              <div class="flex items-center space-x-2">
                <div class="w-8 h-8 bg-gray-600 rounded-full flex items-center justify-center">
                  <span class="text-xs font-medium"><%= String.first(guest.name) %></span>
                </div>
                <span class="text-sm"><%= guest.name %></span>
              </div>
              <.guest_status_indicator status={guest.status} />
            </div>
          </div>

          <.feature_gate feature={:guest_invites} gates={@feature_gates}>
            <button
              phx-click="show_invite_guest_modal"
              class="w-full py-2 border border-gray-600 rounded hover:bg-gray-700 transition-colors text-sm"
            >
              + Invite Guest
            </button>
            <:locked>
              <.locked_feature_button feature="Guest Invites" />
            </:locked>
          </.feature_gate>
        </div>
      </div>

      <!-- Main Recording Area -->
      <div class="recording-workspace flex-1 p-6">
        <!-- Integrated Session Hub for Recording -->
        <div class="session-container">
          <%= if @episode && @episode.recording_session_id do %>
            <.live_component
              module={FrestylWeb.SessionComponents}
              id="recording-session"
              session_id={@episode.recording_session_id}
              mode="podcast_recording"
              feature_gates={@feature_gates}
            />
          <% else %>
            <div class="empty-state text-center py-12">
              <.icon name="hero-microphone" class="w-16 h-16 text-gray-500 mx-auto mb-4" />
              <h3 class="text-lg font-medium mb-2">Ready to Record</h3>
              <p class="text-gray-400 mb-6">Click "Start Recording" to begin your podcast session</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def editing_interface(assigns) do
    ~H"""
    <div class="editing-interface flex-1 flex">
      <!-- Editing Tools Sidebar -->
      <div class="editing-tools w-64 bg-gray-800 border-r border-gray-700 p-4">
        <h3 class="font-semibold mb-4">Editing Tools</h3>

        <!-- Tool Categories -->
        <div class="space-y-4">
          <.tool_category title="Audio Tools">
            <.editing_tool
              name="Noise Reduction"
              icon="hero-speaker-wave"
              available={true}
            />
            <.editing_tool
              name="EQ & Filters"
              icon="hero-adjustments-horizontal"
              available={true}
            />
            <.editing_tool
              name="Compression"
              icon="hero-arrow-trending-up"
              available={@feature_gates.advanced_effects}
            />
          </.tool_category>

          <.tool_category title="AI Tools">
            <.editing_tool
              name="Auto Chapters"
              icon="hero-bookmark"
              available={@feature_gates.auto_chapters}
            />
            <.editing_tool
              name="Transcription"
              icon="hero-document-text"
              available={@feature_gates.auto_transcription}
            />
            <.editing_tool
              name="Smart Edit"
              icon="hero-sparkles"
              available={@feature_gates.ai_editing}
            />
          </.tool_category>
        </div>
      </div>

      <!-- Timeline Editor -->
      <div class="timeline-editor flex-1 flex flex-col">
        <!-- Editor Header -->
        <div class="editor-header bg-gray-700 px-6 py-3 border-b border-gray-600">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              <h3 class="font-medium">
                <%= if @episode, do: @episode.title, else: "Select Episode to Edit" %>
              </h3>
              <div class="text-sm text-gray-400">
                Duration: <%= if @episode, do: format_duration(@episode.duration), else: "00:00" %>
              </div>
            </div>

            <div class="flex items-center space-x-2">
              <button class="px-3 py-1 bg-gray-600 hover:bg-gray-500 rounded text-sm">
                Preview
              </button>
              <button class="px-3 py-1 bg-blue-600 hover:bg-blue-700 rounded text-sm">
                Export
              </button>
            </div>
          </div>
        </div>

        <!-- Timeline -->
        <div class="timeline-container flex-1 overflow-hidden">
          <%= if @editing_project do %>
            <.live_component
              module={FrestylWeb.EditingComponents.Timeline}
              id="podcast-timeline"
              project={@editing_project}
              feature_gates={@feature_gates}
            />
          <% else %>
            <div class="empty-timeline flex items-center justify-center h-full">
              <div>
                              <.icon name="hero-film" class="w-16 h-16 text-gray-500 mx-auto mb-4" />
                <h3 class="text-lg font-medium mb-2">No Episode Selected</h3>
                <p class="text-gray-400">Choose an episode to start editing</p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Properties Panel -->
      <div class="properties-panel w-80 bg-gray-800 border-l border-gray-700 p-4">
        <h3 class="font-semibold mb-4">Properties</h3>

        <%= if @episode do %>
          <div class="space-y-4">
            <!-- Episode Info -->
            <div class="episode-properties p-4 bg-gray-700 rounded">
              <h4 class="font-medium mb-3">Episode Details</h4>
              <div class="space-y-2 text-sm">
                <div><span class="text-gray-400">Title:</span> <%= @episode.title %></div>
                <div><span class="text-gray-400">Number:</span> #<%= @episode.episode_number %></div>
                <div><span class="text-gray-400">Status:</span> <%= @episode.status %></div>
              </div>
            </div>

            <!-- Transcript Preview -->
            <div class="transcript-preview p-4 bg-gray-700 rounded">
              <h4 class="font-medium mb-3">Auto Transcript</h4>
              <%= if @feature_gates.auto_transcription do %>
                <div class="text-sm text-gray-300 max-h-40 overflow-y-auto">
                  <%= @episode.transcript || "Transcript will appear here after processing..." %>
                </div>
              <% else %>
                <.upgrade_prompt feature="Auto Transcription" />
              <% end %>
            </div>

            <!-- Chapter Markers -->
            <div class="chapters-panel p-4 bg-gray-700 rounded">
              <h4 class="font-medium mb-3">Chapters</h4>
              <%= if @feature_gates.auto_chapters do %>
                <div class="space-y-2">
                  <div
                    :for={chapter <- @episode.chapters || []}
                    class="chapter-marker p-2 bg-gray-600 rounded text-sm"
                  >
                    <div class="font-medium"><%= chapter["title"] %></div>
                    <div class="text-gray-400 text-xs"><%= format_timestamp(chapter["start_time"]) %></div>
                  </div>

                  <button class="w-full py-2 border border-gray-600 rounded hover:bg-gray-600 transition-colors text-sm">
                    + Add Chapter
                  </button>
                </div>
              <% else %>
                <.upgrade_prompt feature="Auto Chapters" />
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  def publishing_interface(assigns) do
    ~H"""
    <div class="publishing-interface flex-1 p-6">
      <%= if @episode do %>
        <!-- Publishing Status -->
        <div class="publishing-status bg-gray-800 rounded-lg p-6 mb-8">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-xl font-semibold">Publish Episode</h2>
            <.status_badge status={@episode.status} />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <!-- Episode Ready Check -->
            <div class="readiness-check">
              <h3 class="font-medium mb-3">Episode Ready</h3>
              <div class="space-y-2">
                <.check_item
                  label="Audio Processed"
                  completed={@episode.audio_url != nil}
                />
                <.check_item
                  label="Show Notes"
                  completed={@episode.show_notes != nil}
                />
                <.check_item
                  label="Thumbnail"
                  completed={@episode.thumbnail_url != nil}
                />
                <.check_item
                  label="Chapters"
                  completed={length(@episode.chapters || []) > 0}
                />
              </div>
            </div>

            <!-- Distribution Platforms -->
            <div class="distribution-platforms">
              <h3 class="font-medium mb-3">Distribution</h3>
              <%= if @feature_gates.distribution do %>
                <div class="space-y-2">
                  <.platform_toggle
                    platform="Spotify"
                    enabled={true}
                    status="connected"
                  />
                  <.platform_toggle
                    platform="Apple Podcasts"
                    enabled={true}
                    status="connected"
                  />
                  <.platform_toggle
                    platform="Google Podcasts"
                    enabled={false}
                    status="available"
                  />
                  <.platform_toggle
                    platform="YouTube"
                    enabled={false}
                    status="premium"
                  />
                </div>
              <% else %>
                <.upgrade_prompt feature="Multi-Platform Distribution" />
              <% end %>
            </div>

            <!-- Publishing Schedule -->
            <div class="publishing-schedule">
              <h3 class="font-medium mb-3">Schedule</h3>
              <div class="space-y-3">
                <div>
                  <label class="block text-sm font-medium mb-2">Publish Date</label>
                  <input
                    type="datetime-local"
                    class="w-full px-3 py-2 bg-gray-700 border border-gray-600 rounded focus:border-blue-500 focus:outline-none"
                    value={format_datetime_local(@episode.scheduled_for)}
                  />
                </div>
                <button
                  phx-click="publish_episode"
                  disabled={@episode.status != "ready"}
                  class={[
                    "w-full py-2 rounded font-medium transition-colors",
                    @episode.status == "ready" && "bg-green-600 hover:bg-green-700" || "bg-gray-600 cursor-not-allowed"
                  ]}
                >
                  <%= if @episode.status == "published", do: "Published", else: "Publish Now" %>
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- Show Notes Editor -->
        <div class="show-notes-editor bg-gray-800 rounded-lg p-6 mb-8">
          <h3 class="text-lg font-semibold mb-4">Show Notes</h3>
          <textarea
            rows="10"
            placeholder="Write your show notes here... (AI can help generate these)"
            class="w-full px-4 py-3 bg-gray-700 border border-gray-600 rounded focus:border-blue-500 focus:outline-none resize-none"
            value={@episode.show_notes}
          ><%= @episode.show_notes %></textarea>

          <%= if @feature_gates.ai_editing do %>
            <div class="flex items-center justify-between mt-4">
              <button class="px-4 py-2 bg-purple-600 hover:bg-purple-700 rounded transition-colors">
                Generate with AI
              </button>
              <span class="text-sm text-gray-400">AI can generate show notes from your transcript</span>
            </div>
          <% end %>
        </div>

        <!-- Analytics Preview -->
        <%= if @feature_gates.analytics do %>
          <div class="analytics-preview bg-gray-800 rounded-lg p-6">
            <h3 class="text-lg font-semibold mb-4">Expected Performance</h3>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
              <.metric_card
                title="Estimated Listens"
                value="850"
                subtitle="Based on show average"
              />
              <.metric_card
                title="Completion Rate"
                value="72%"
                subtitle="Predicted from duration"
              />
              <.metric_card
                title="Share Potential"
                value="High"
                subtitle="Trending topic detected"
              />
            </div>
          </div>
        <% end %>
      <% else %>
        <div class="empty-state text-center py-12">
          <.icon name="hero-megaphone" class="w-16 h-16 text-gray-500 mx-auto mb-4" />
          <h3 class="text-lg font-medium mb-2">No Episode Selected</h3>
          <p class="text-gray-400">Choose an episode to publish</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper Components

  def stat_card(assigns) do
    ~H"""
    <div class="stat-card bg-gray-800 rounded-lg p-6">
      <div class="text-2xl font-bold mb-1"><%= @value %></div>
      <div class="text-sm text-gray-400"><%= @title %></div>
    </div>
    """
  end

  def status_badge(assigns) do
    color_class = case assigns.status do
      "draft" -> "bg-gray-600"
      "recording" -> "bg-red-600"
      "processing" -> "bg-yellow-600"
      "ready" -> "bg-green-600"
      "published" -> "bg-blue-600"
      _ -> "bg-gray-600"
    end

    assigns = assign(assigns, :color_class, color_class)

    ~H"""
    <span class={["px-2 py-1 rounded text-xs font-medium text-white", @color_class]}>
      <%= String.capitalize(@status) %>
    </span>
    """
  end

  def feature_highlight(assigns) do
    ~H"""
    <div class={[
      "feature-highlight p-6 rounded-lg border",
      @available && "bg-gray-800 border-gray-700" || "bg-gray-800 border-gray-600 opacity-60"
    ]}>
      <div class="flex items-center justify-between mb-3">
        <h3 class="font-medium"><%= @title %></h3>
        <%= if not @available do %>
          <span class="px-2 py-1 bg-purple-600 text-xs rounded">Pro</span>
        <% end %>
      </div>
      <p class="text-sm text-gray-400"><%= @description %></p>
      <%= if not @available do %>
        <button class="mt-4 text-sm text-purple-400 hover:text-purple-300">
          Upgrade to unlock →
        </button>
      <% end %>
    </div>
    """
  end

  def guest_status_indicator(assigns) do
    {color, text} = case assigns.status do
      "invited" -> {"bg-yellow-600", "Invited"}
      "confirmed" -> {"bg-green-600", "Confirmed"}
      "declined" -> {"bg-red-600", "Declined"}
      "attended" -> {"bg-blue-600", "Attended"}
      _ -> {"bg-gray-600", "Unknown"}
    end

    assigns = assign(assigns, :color, color) |> assign(:text, text)

    ~H"""
    <span class={["px-2 py-1 rounded text-xs font-medium text-white", @color]}>
      <%= @text %>
    </span>
    """
  end

  def tool_category(assigns) do
    ~H"""
    <div class="tool-category">
      <h4 class="text-sm font-medium text-gray-400 mb-2"><%= @title %></h4>
      <div class="space-y-1">
        <%= render_slot(@inner_block) %>
      </div>
    </div>
    """
  end

  def editing_tool(assigns) do
    ~H"""
    <button class={[
      "editing-tool w-full flex items-center space-x-2 p-2 rounded text-sm transition-colors",
      @available && "hover:bg-gray-700 text-white" || "text-gray-500 cursor-not-allowed"
    ]}>
      <.icon name={@icon} class="w-4 h-4" />
      <span><%= @name %></span>
      <%= if not @available do %>
        <.icon name="hero-lock-closed" class="w-3 h-3 ml-auto" />
      <% end %>
    </button>
    """
  end

  def check_item(assigns) do
    ~H"""
    <div class="check-item flex items-center space-x-2">
      <div class={[
        "w-4 h-4 rounded-full flex items-center justify-center",
        @completed && "bg-green-600" || "bg-gray-600"
      ]}>
        <%= if @completed do %>
          <.icon name="hero-check" class="w-3 h-3 text-white" />
        <% end %>
      </div>
      <span class={[
        "text-sm",
        @completed && "text-white" || "text-gray-400"
      ]}>
        <%= @label %>
      </span>
    </div>
    """
  end

  def platform_toggle(assigns) do
    ~H"""
    <div class="platform-toggle flex items-center justify-between p-2 bg-gray-700 rounded">
      <span class="text-sm"><%= @platform %></span>
      <div class="flex items-center space-x-2">
        <%= case @status do %>
          <% "connected" -> %>
            <span class="text-xs text-green-400">Connected</span>
            <input type="checkbox" checked={@enabled} class="toggle" />
          <% "available" -> %>
            <span class="text-xs text-gray-400">Available</span>
            <input type="checkbox" checked={@enabled} class="toggle" />
          <% "premium" -> %>
            <span class="text-xs text-purple-400">Pro</span>
            <.icon name="hero-lock-closed" class="w-4 h-4 text-gray-500" />
        <% end %>
      </div>
    </div>
    """
  end

  def metric_card(assigns) do
    ~H"""
    <div class="metric-card text-center p-4 bg-gray-700 rounded">
      <div class="text-xl font-bold mb-1"><%= @value %></div>
      <div class="text-sm font-medium mb-1"><%= @title %></div>
      <div class="text-xs text-gray-400"><%= @subtitle %></div>
    </div>
    """
  end

  def locked_feature_button(assigns) do
    ~H"""
    <button class="w-full py-2 border border-gray-600 rounded text-sm text-gray-400 cursor-not-allowed">
      <.icon name="hero-lock-closed" class="w-4 h-4 inline mr-2" />
      <%= @feature %> (Upgrade Required)
    </button>
    """
  end

  def upgrade_prompt(assigns) do
    ~H"""
    <div class="upgrade-prompt text-center p-4 border border-gray-600 rounded">
      <.icon name="hero-star" class="w-8 h-8 text-purple-400 mx-auto mb-2" />
      <div class="text-sm text-gray-400 mb-2">
        <%= @feature %> requires upgrade
      </div>
      <button class="text-sm text-purple-400 hover:text-purple-300">
        Upgrade Now →
      </button>
    </div>
    """
  end

  # Helper Functions

  defp format_duration(nil), do: "00:00"
  defp format_duration(seconds) when is_integer(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    "#{pad_zero(minutes)}:#{pad_zero(seconds)}"
  end

  defp format_recording_time(milliseconds) do
    total_seconds = div(milliseconds, 1000)
    hours = div(total_seconds, 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    if hours > 0 do
      "#{pad_zero(hours)}:#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    else
      "#{pad_zero(minutes)}:#{pad_zero(seconds)}"
    end
  end

  defp format_timestamp(seconds) do
    minutes = div(seconds, 60)
    seconds = rem(seconds, 60)
    "#{pad_zero(minutes)}:#{pad_zero(seconds)}"
  end

  defp format_datetime_local(nil), do: ""
  defp format_datetime_local(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)
  end

  defp pad_zero(num) when num < 10, do: "0#{num}"
  defp pad_zero(num), do: to_string(num)

  # Add missing component functions
  def feature_gate(assigns) do
    available = Map.get(assigns.gates, assigns.feature, false)
    assigns = assign(assigns, :available, available)

    ~H"""
    <%= if @available do %>
      <%= render_slot(@inner_block) %>
    <% else %>
      <%= render_slot(@locked) %>
    <% end %>
    """
  end

  def locked_feature_button(assigns) do
    ~H"""
    <button class="w-full py-2 border border-gray-600 rounded text-sm text-gray-400 cursor-not-allowed">
      <.icon name="hero-lock-closed" class="w-4 h-4 inline mr-2" />
      <%= @feature %> (Upgrade Required)
    </button>
    """
  end
end
