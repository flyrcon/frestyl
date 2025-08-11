# lib/frestyl_web/live/studio_live/creator_studio_component.ex
defmodule FrestylWeb.StudioLive.CreatorStudioComponent do
  @moduledoc """
  Creator Studio component for Portfolio Hub - launches studio sessions
  with full integration to audio, video, and beat machine systems.
  """

  use FrestylWeb, :live_component
  alias Frestyl.{Sessions, Studio, Accounts}
  alias Frestyl.Studio.{AudioEngine, EnhancedBeatMachine, EnhancedRecordingEngine}

  @impl true
  def update(assigns, socket) do
    current_user = assigns.current_user
    current_account = assigns.current_account

    # Load recent studio sessions
    recent_sessions = load_recent_studio_sessions(current_user.id)

    # Get studio analytics
    studio_analytics = get_studio_analytics(current_user.id)

    # Check feature access
    has_access = can_access_creator_studio?(current_account)

    socket = socket
    |> assign(assigns)
    |> assign(:recent_sessions, recent_sessions)
    |> assign(:studio_analytics, studio_analytics)
    |> assign(:has_access, has_access)
    |> assign(:creating_session, false)
    |> assign(:session_error, nil)

    {:ok, socket}
  end

  @impl true
  def handle_event("launch_studio_tool", %{"tool" => tool}, socket) do
    if socket.assigns.has_access do
      current_user = socket.assigns.current_user

      case create_studio_session(tool, current_user) do
        {:ok, session} ->
          # Start appropriate studio engines
          start_studio_engines(session.id, tool)

          {:noreply,
           socket
           |> assign(:creating_session, false)
           |> push_navigate(to: ~p"/studio/#{session.id}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:creating_session, false)
           |> assign(:session_error, "Failed to create session: #{reason}")}
      end
    else
      {:noreply,
       socket
       |> assign(:session_error, "Upgrade to Creator tier to access Studio tools")}
    end
  end

  @impl true
  def handle_event("launch_quick_session", %{"template" => template}, socket) do
    if socket.assigns.has_access do
      current_user = socket.assigns.current_user

      case create_template_session(template, current_user) do
        {:ok, session} ->
          # Start engines based on template
          start_template_engines(session.id, template)

          {:noreply,
           socket
           |> assign(:creating_session, false)
           |> push_navigate(to: ~p"/studio/#{session.id}")}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:session_error, "Failed to create session: #{reason}")}
      end
    else
      {:noreply,
       socket
       |> assign(:session_error, "Upgrade to Creator tier to access Studio")}
    end
  end

  @impl true
  def handle_event("resume_session", %{"session_id" => session_id}, socket) do
    # Resume existing session
    {:noreply, push_navigate(socket, to: ~p"/studio/#{session_id}")}
  end

  @impl true
  def handle_event("delete_session", %{"session_id" => session_id}, socket) do
    case Sessions.delete_session(session_id) do
      {:ok, _} ->
        # Reload recent sessions
        recent_sessions = load_recent_studio_sessions(socket.assigns.current_user.id)

        {:noreply,
         socket
         |> assign(:recent_sessions, recent_sessions)
         |> assign(:session_error, nil)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:session_error, "Failed to delete session: #{reason}")}
    end
  end

  @impl true
  def handle_event("clear_error", _params, socket) do
    {:noreply, assign(socket, :session_error, nil)}
  end

  # Private Functions

  defp create_studio_session(tool, user) do
    session_params = case tool do
      "audio_studio" ->
        %{
          title: "Audio Studio Session",
          description: "Multi-track audio production session",
          session_type: "audio_production",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            beat_machine: false,
            max_tracks: 16
          }
        }

      "beat_machine" ->
        %{
          title: "Beat Machine Session",
          description: "Drum pattern creation and sequencing",
          session_type: "beat_production",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            beat_machine: true,
            max_patterns: 8
          }
        }

      "podcast_studio" ->
        %{
          title: "Podcast Recording Session",
          description: "Professional podcast recording and editing",
          session_type: "podcast",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            beat_machine: false,
            voice_enhancement: true,
            max_tracks: 4
          }
        }

      "music_production" ->
        %{
          title: "Music Production Session",
          description: "Complete music production suite",
          session_type: "music",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            beat_machine: true,
            effects_suite: true,
            max_tracks: 32
          }
        }

      "live_broadcast" ->
        %{
          title: "Live Broadcast Session",
          description: "Live streaming and broadcasting",
          session_type: "broadcast",
          created_by_id: user.id,
          status: "active",
          settings: %{
            webrtc_enabled: true,
            audio_engine: true,
            streaming: true
          }
        }

      _ ->
        %{
          title: "Studio Session",
          description: "General studio session",
          session_type: "general",
          created_by_id: user.id,
          status: "active",
          settings: %{}
        }
    end

    try do
      Sessions.create_session(session_params)
    rescue
      UndefinedFunctionError ->
        # Sessions.create_session doesn't exist yet
        # Create a mock session for now
        mock_session = %{
          id: "mock_#{:rand.uniform(10000)}",
          title: session_params.title,
          session_type: session_params.session_type
        }
        {:ok, mock_session}
      _ ->
        {:error, "Failed to create session"}
    end
  end

  defp create_template_session(template, user) do
    session_params = case template do
      "podcast_interview" ->
        %{
          title: "Podcast Interview",
          description: "2-person interview setup with professional audio",
          session_type: "podcast",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            preset_tracks: ["Host", "Guest"],
            auto_leveling: true
          }
        }

      "solo_music" ->
        %{
          title: "Solo Music Creation",
          description: "Single artist music production",
          session_type: "music",
          created_by_id: user.id,
          status: "active",
          settings: %{
            audio_engine: true,
            recording_engine: true,
            beat_machine: true,
            preset_tracks: ["Vocals", "Guitar", "Bass", "Drums"]
          }
        }

      "beat_creation" ->
        %{
          title: "Beat Creation",
          description: "Hip-hop/electronic beat making",
          session_type: "beat_production",
          created_by_id: user.id,
          status: "active",
          settings: %{
            beat_machine: true,
            audio_engine: true,
            recording_engine: true,
            kit_presets: ["808", "trap", "boom_bap"]
          }
        }

      _ ->
        create_studio_session("audio_studio", user)
    end

    Sessions.create_session(session_params)
  end

  defp start_studio_engines(session_id, tool) do
    case tool do
      "audio_studio" ->
        AudioEngine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "beat_machine" ->
        AudioEngine.start_link(session_id)
        EnhancedBeatMachine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "podcast_studio" ->
        AudioEngine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "music_production" ->
        AudioEngine.start_link(session_id)
        EnhancedBeatMachine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "live_broadcast" ->
        AudioEngine.start_link(session_id)
        # WebRTC manager would be started in the broadcast LiveView

      _ ->
        AudioEngine.start_link(session_id)
    end
  end

  defp start_template_engines(session_id, template) do
    case template do
      "podcast_interview" ->
        AudioEngine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "solo_music" ->
        AudioEngine.start_link(session_id)
        EnhancedBeatMachine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      "beat_creation" ->
        EnhancedBeatMachine.start_link(session_id)
        AudioEngine.start_link(session_id)
        EnhancedRecordingEngine.start_link(session_id)

      _ ->
        AudioEngine.start_link(session_id)
    end
  end

  defp load_recent_studio_sessions(user_id) do
    # Get recent studio sessions for this user
    try do
      case Sessions.list_user_sessions(user_id, limit: 5) do
        sessions when is_list(sessions) ->
          sessions
          |> Enum.filter(&(&1.session_type in ["audio_production", "beat_production", "podcast", "music", "broadcast"]))
          |> Enum.map(&format_session_for_display/1)

        _ -> []
      end
    rescue
      UndefinedFunctionError ->
        # Function doesn't exist yet, return empty list
        []
      _ ->
        # Other errors, return empty list
        []
    end
  end

  defp format_session_for_display(session) do
    %{
      id: session.id,
      title: session.title,
      type: session.session_type,
      created_at: session.inserted_at,
      status: session.status,
      duration: calculate_session_duration(session),
      icon: get_session_icon(session.session_type)
    }
  end

  defp calculate_session_duration(session) do
    if session.ended_at do
      DateTime.diff(session.ended_at, session.inserted_at, :minute)
    else
      DateTime.diff(DateTime.utc_now(), session.inserted_at, :minute)
    end
  end

  defp get_session_icon(session_type) do
    case session_type do
      "audio_production" -> "microphone"
      "beat_production" -> "musical-note"
      "podcast" -> "chat-bubble-left-right"
      "music" -> "speaker-wave"
      "broadcast" -> "signal"
      _ -> "beaker"
    end
  end

  defp get_studio_analytics(user_id) do
    # Calculate studio usage analytics
    %{
      total_sessions: count_user_sessions(user_id),
      total_recordings: count_user_recordings(user_id),
      total_studio_time: calculate_total_studio_time(user_id),
      favorite_tool: get_most_used_tool(user_id)
    }
  end

  defp count_user_sessions(user_id) do
    # Would count from Sessions context
    try do
      case Sessions.count_user_sessions(user_id) do
        count when is_integer(count) -> count
        _ -> 0
      end
    rescue
      UndefinedFunctionError ->
        # Function doesn't exist yet, return 0
        0
      _ ->
        0
    end
  end

  defp count_user_recordings(_user_id) do
    # Would count from Media context
    0  # Placeholder
  end

  defp calculate_total_studio_time(_user_id) do
    # Would calculate from session durations
    "12h 34m"  # Placeholder
  end

  defp get_most_used_tool(_user_id) do
    # Would analyze session types
    "Audio Studio"  # Placeholder
  end

  defp can_access_creator_studio?(account) do
    tier = Frestyl.Features.TierManager.get_account_tier(account)
    tier in ["creator", "professional", "enterprise"]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="frestyl-creator-studio-container">
      <%= if @has_access do %>
        <!-- Studio Tools Available -->
        <div class="space-y-6">
          <!-- Header (matching portfolio_hub_live.heex pattern) -->
          <div class="bg-white rounded-xl p-6 shadow-sm border">
            <div class="flex flex-col lg:flex-row lg:items-center justify-between">
              <div>
                <h1 class="text-2xl font-bold text-gray-900">Creator Studio</h1>
                <p class="text-gray-600 mt-1">Professional audio & video production suite</p>
              </div>

              <!-- Quick Stats -->
              <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mt-4 lg:mt-0">
                <div class="text-center">
                  <div class="text-xl font-bold text-gray-900"><%= @studio_analytics.total_sessions %></div>
                  <div class="text-xs text-gray-500">Sessions</div>
                </div>
                <div class="text-center">
                  <div class="text-xl font-bold text-gray-900"><%= @studio_analytics.total_recordings %></div>
                  <div class="text-xs text-gray-500">Recordings</div>
                </div>
                <div class="text-center">
                  <div class="text-xl font-bold text-gray-900"><%= @studio_analytics.total_studio_time %></div>
                  <div class="text-xs text-gray-500">Studio Time</div>
                </div>
                <div class="text-center lg:text-left">
                  <div class="text-sm font-medium text-gray-900"><%= @studio_analytics.favorite_tool %></div>
                  <div class="text-xs text-gray-500">Most Used</div>
                </div>
              </div>
            </div>
          </div>

          <!-- Studio Tools Grid -->
          <div class="bg-white rounded-xl shadow-sm border">
            <div class="p-6 border-b border-gray-200">
              <h2 class="text-xl font-bold text-gray-900">Studio Tools</h2>
              <p class="text-gray-600 text-sm mt-1">Professional creation tools at your fingertips</p>
            </div>

            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6">
                <!-- Audio Studio -->
                <div class="group bg-gradient-to-br from-blue-50 to-cyan-50 rounded-xl p-6 border border-blue-100 hover:shadow-lg hover:border-blue-200 transition-all duration-300">
                  <div class="flex items-center justify-between mb-4">
                    <div class="w-12 h-12 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                      </svg>
                    </div>
                    <span class="bg-blue-100 text-blue-600 text-xs font-medium px-2 py-1 rounded">Studio</span>
                  </div>
                  <h3 class="text-lg font-bold text-gray-900 mb-2">Audio Studio</h3>
                  <p class="text-gray-600 text-sm mb-4 leading-relaxed">Multi-track recording, mixing, and professional audio production</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-blue-500 rounded-full mr-2"></div>
                      Up to 16 tracks
                    </div>
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-cyan-500 rounded-full mr-2"></div>
                      Professional effects
                    </div>
                  </div>

                  <button phx-click="launch_studio_tool" phx-value-tool="audio_studio" phx-target={@myself}
                          class="w-full bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700 text-white py-3 rounded-lg font-semibold transition-all transform hover:scale-105">
                    Launch Audio Studio
                  </button>
                </div>

                <!-- Beat Machine -->
                <div class="group bg-gradient-to-br from-emerald-50 to-teal-50 rounded-xl p-6 border border-emerald-100 hover:shadow-lg hover:border-emerald-200 transition-all duration-300">
                  <div class="flex items-center justify-between mb-4">
                    <div class="w-12 h-12 bg-gradient-to-br from-emerald-600 to-teal-600 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"/>
                      </svg>
                    </div>
                    <span class="bg-emerald-100 text-emerald-600 text-xs font-medium px-2 py-1 rounded">Beats</span>
                  </div>
                  <h3 class="text-lg font-bold text-gray-900 mb-2">Beat Machine</h3>
                  <p class="text-gray-600 text-sm mb-4 leading-relaxed">Create infectious rhythms with professional drum sequencing and sampling</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-emerald-500 rounded-full mr-2"></div>
                      8-pattern sequencer
                    </div>
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-teal-500 rounded-full mr-2"></div>
                      Sample library included
                    </div>
                  </div>

                  <button phx-click="launch_studio_tool" phx-value-tool="beat_machine" phx-target={@myself}
                          class="w-full bg-gradient-to-r from-emerald-600 to-teal-600 hover:from-emerald-700 hover:to-teal-700 text-white py-3 rounded-lg font-semibold transition-all transform hover:scale-105">
                    Launch Beat Machine
                  </button>
                </div>

                <!-- Podcast Studio -->
                <div class="group bg-gradient-to-br from-purple-50 to-pink-50 rounded-xl p-6 border border-purple-100 hover:shadow-lg hover:border-purple-200 transition-all duration-300">
                  <div class="flex items-center justify-between mb-4">
                    <div class="w-12 h-12 bg-gradient-to-br from-purple-600 to-pink-600 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.625 12a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H8.25m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0H12m4.125 0a.375.375 0 11-.75 0 .375.375 0 01.75 0zm0 0h-.375M21 12c0 4.556-4.03 8.25-9 8.25a9.764 9.764 0 01-2.555-.337A5.972 5.972 0 015.41 20.97a5.969 5.969 0 01-.474-.065 4.48 4.48 0 00.978-2.025c.09-.457-.133-.901-.467-1.226C3.93 16.178 3 14.189 3 12c0-4.556 4.03-8.25 9-8.25s9 3.694 9 8.25z"/>
                      </svg>
                    </div>
                    <span class="bg-purple-100 text-purple-600 text-xs font-medium px-2 py-1 rounded">Podcast</span>
                  </div>
                  <h3 class="text-lg font-bold text-gray-900 mb-2">Podcast Studio</h3>
                  <p class="text-gray-600 text-sm mb-4 leading-relaxed">Professional podcast recording with voice enhancement and auto-leveling</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-purple-500 rounded-full mr-2"></div>
                      Voice enhancement
                    </div>
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-pink-500 rounded-full mr-2"></div>
                      Multi-guest support
                    </div>
                  </div>

                  <button phx-click="launch_studio_tool" phx-value-tool="podcast_studio" phx-target={@myself}
                          class="w-full bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white py-3 rounded-lg font-semibold transition-all transform hover:scale-105">
                    Launch Podcast Studio
                  </button>
                </div>

                <!-- Music Production -->
                <div class="group bg-gradient-to-br from-orange-50 to-red-50 rounded-xl p-6 border border-orange-100 hover:shadow-lg hover:border-orange-200 transition-all duration-300">
                  <div class="flex items-center justify-between mb-4">
                    <div class="w-12 h-12 bg-gradient-to-br from-orange-600 to-red-600 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.75 5.25a3 3 0 013 3m3 0a6 6 0 01-7.029 5.912c-.563-.097-1.159.026-1.563.43L10.5 17.25H8.25v2.25H6v2.25H2.25v-2.818c0-.597.237-1.17.659-1.591l6.499-6.499c.404-.404.527-1 .43-1.563A6 6 0 1721.75 8.25z"/>
                      </svg>
                    </div>
                    <span class="bg-orange-100 text-orange-600 text-xs font-medium px-2 py-1 rounded">Production</span>
                  </div>
                  <h3 class="text-lg font-bold text-gray-900 mb-2">Music Production</h3>
                  <p class="text-gray-600 text-sm mb-4 leading-relaxed">Complete music creation suite with instruments, effects, and mastering</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-orange-500 rounded-full mr-2"></div>
                      32 tracks available
                    </div>
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-red-500 rounded-full mr-2"></div>
                      Full effects suite
                    </div>
                  </div>

                  <button phx-click="launch_studio_tool" phx-value-tool="music_production" phx-target={@myself}
                          class="w-full bg-gradient-to-r from-orange-600 to-red-600 hover:from-orange-700 hover:to-red-700 text-white py-3 rounded-lg font-semibold transition-all transform hover:scale-105">
                    Launch Music Suite
                  </button>
                </div>

                <!-- Live Broadcast -->
                <div class="group bg-gradient-to-br from-violet-50 to-purple-50 rounded-xl p-6 border border-violet-100 hover:shadow-lg hover:border-violet-200 transition-all duration-300">
                  <div class="flex items-center justify-between mb-4">
                    <div class="w-12 h-12 bg-gradient-to-br from-violet-600 to-purple-600 rounded-xl flex items-center justify-center group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.75 10.5l4.72-4.72a.75.75 0 011.28.53v11.38a.75.75 0 01-1.28.53l-4.72-4.72M4.5 18.75h9a2.25 2.25 0 002.25-2.25v-9a2.25 2.25 0 00-2.25-2.25h-9A2.25 2.25 0 002.25 7.5v9a2.25 2.25 0 002.25 2.25z"/>
                      </svg>
                    </div>
                    <span class="bg-violet-100 text-violet-600 text-xs font-medium px-2 py-1 rounded">Live</span>
                  </div>
                  <h3 class="text-lg font-bold text-gray-900 mb-2">Live Broadcast</h3>
                  <p class="text-gray-600 text-sm mb-4 leading-relaxed">Professional live streaming with real-time audio processing</p>

                  <div class="space-y-2 mb-4">
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-violet-500 rounded-full mr-2"></div>
                      HD streaming
                    </div>
                    <div class="flex items-center text-xs text-gray-600">
                      <div class="w-2 h-2 bg-purple-500 rounded-full mr-2"></div>
                      Multi-platform
                    </div>
                  </div>

                  <button phx-click="launch_studio_tool" phx-value-tool="live_broadcast" phx-target={@myself}
                          class="w-full bg-gradient-to-r from-violet-600 to-purple-600 hover:from-violet-700 hover:to-purple-700 text-white py-3 rounded-lg font-semibold transition-all transform hover:scale-105">
                    Go Live
                  </button>
                </div>

                <!-- Quick Templates -->
                <div class="group bg-gradient-to-br from-gray-50 to-gray-100 rounded-xl p-6 border-2 border-dashed border-gray-300 hover:border-gray-400 transition-all duration-300">
                  <div class="text-center">
                    <div class="w-12 h-12 bg-gradient-to-br from-gray-100 to-gray-200 rounded-xl flex items-center justify-center mx-auto mb-3 group-hover:scale-105 transition-transform">
                      <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                    </div>
                    <span class="bg-gray-100 text-gray-600 text-xs font-medium px-2 py-1 rounded mb-2 inline-block">Templates</span>
                    <h3 class="text-lg font-bold text-gray-900 mb-2">Quick Start</h3>
                    <p class="text-gray-600 text-sm mb-4 leading-relaxed">Jump into pre-configured studio setups</p>

                    <div class="space-y-2">
                      <button phx-click="launch_quick_session" phx-value-template="podcast_interview" phx-target={@myself}
                              class="w-full text-sm bg-white border border-gray-200 text-gray-700 py-2 rounded-lg hover:bg-gray-50 transition-colors">
                        Podcast Interview
                      </button>
                      <button phx-click="launch_quick_session" phx-value-template="solo_music" phx-target={@myself}
                              class="w-full text-sm bg-white border border-gray-200 text-gray-700 py-2 rounded-lg hover:bg-gray-50 transition-colors">
                        Solo Music
                      </button>
                      <button phx-click="launch_quick_session" phx-value-template="beat_creation" phx-target={@myself}
                              class="w-full text-sm bg-white border border-gray-200 text-gray-700 py-2 rounded-lg hover:bg-gray-50 transition-colors">
                        Beat Creation
                      </button>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- My Recordings Section -->
          <div class="bg-white rounded-xl shadow-sm border">
            <div class="p-6 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-xl font-bold text-gray-900">My Recordings</h2>
                  <p class="text-gray-600 text-sm mt-1">Your latest creative works</p>
                </div>

                <!-- View Toggle -->
                <div class="flex rounded-lg bg-gray-100 p-1">
                  <button class="px-3 py-1 text-sm font-medium bg-white text-gray-900 rounded-md shadow-sm">
                    Grid
                  </button>
                  <button class="px-3 py-1 text-sm font-medium text-gray-600 hover:text-gray-900">
                    List
                  </button>
                </div>
              </div>
            </div>

            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <div class="group bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors">
                  <div class="flex items-center space-x-3 mb-3">
                    <div class="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h8m2-10.586l-12 12-2-2L8.586 8 20 8z"/>
                      </svg>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900">Summer Vibes Beat</h4>
                      <p class="text-sm text-gray-600">Hip-hop • 3:24</p>
                    </div>
                  </div>
                  <div class="flex items-center justify-between text-sm text-gray-500">
                    <span>2 days ago</span>
                    <button class="text-blue-600 hover:text-blue-700 font-medium">Play</button>
                  </div>
                </div>

                <div class="group bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors">
                  <div class="flex items-center space-x-3 mb-3">
                    <div class="w-10 h-10 bg-purple-600 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                      </svg>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900">Podcast Episode 12</h4>
                      <p class="text-sm text-gray-600">Interview • 45:12</p>
                    </div>
                  </div>
                  <div class="flex items-center justify-between text-sm text-gray-500">
                    <span>1 week ago</span>
                    <button class="text-blue-600 hover:text-blue-700 font-medium">Play</button>
                  </div>
                </div>

                <div class="group bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors">
                  <div class="flex items-center space-x-3 mb-3">
                    <div class="w-10 h-10 bg-emerald-600 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"/>
                      </svg>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900">Acoustic Demo</h4>
                      <p class="text-sm text-gray-600">Song • 2:45</p>
                    </div>
                  </div>
                  <div class="flex items-center justify-between text-sm text-gray-500">
                    <span>2 weeks ago</span>
                    <button class="text-blue-600 hover:text-blue-700 font-medium">Play</button>
                  </div>
                </div>
              </div>

              <div class="mt-6 text-center">
                <button class="text-blue-600 hover:text-blue-700 font-medium text-sm">
                  View All Recordings →
                </button>
              </div>
            </div>
          </div>

          <!-- Open to Collaborate Section -->
          <div class="bg-white rounded-xl shadow-sm border">
            <div class="p-6 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-xl font-bold text-gray-900">Open to Collaborate</h2>
                  <p class="text-gray-600 text-sm mt-1">Connect with fellow creators</p>
                </div>

                <button class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 font-medium text-sm">
                  Find Collaborators
                </button>
              </div>
            </div>

            <div class="p-6">
              <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                <!-- Collaboration Opportunities -->
                <div>
                  <h3 class="font-semibold text-gray-900 mb-4">Looking for Collaborators</h3>
                  <div class="space-y-3">
                    <div class="bg-blue-50 rounded-lg p-4 border border-blue-100">
                      <div class="flex items-center space-x-3 mb-2">
                        <div class="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center">
                          <span class="text-white text-sm font-medium">M</span>
                        </div>
                        <div>
                          <h4 class="font-medium text-gray-900">Producer for Hip-Hop Track</h4>
                          <p class="text-sm text-gray-600">Looking for beats and mixing help</p>
                        </div>
                      </div>
                      <div class="flex items-center justify-between">
                        <span class="text-xs text-blue-600 bg-blue-100 px-2 py-1 rounded">Hip-Hop</span>
                        <button class="text-blue-600 hover:text-blue-700 text-sm font-medium">Connect</button>
                      </div>
                    </div>

                    <div class="bg-purple-50 rounded-lg p-4 border border-purple-100">
                      <div class="flex items-center space-x-3 mb-2">
                        <div class="w-8 h-8 bg-purple-600 rounded-full flex items-center justify-center">
                          <span class="text-white text-sm font-medium">S</span>
                        </div>
                        <div>
                          <h4 class="font-medium text-gray-900">Vocalist for Indie Project</h4>
                          <p class="text-sm text-gray-600">Need female vocals for acoustic songs</p>
                        </div>
                      </div>
                      <div class="flex items-center justify-between">
                        <span class="text-xs text-purple-600 bg-purple-100 px-2 py-1 rounded">Indie</span>
                        <button class="text-purple-600 hover:text-purple-700 text-sm font-medium">Connect</button>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Your Collaboration Requests -->
                <div>
                  <h3 class="font-semibold text-gray-900 mb-4">Your Requests</h3>
                  <div class="space-y-3">
                    <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
                      <h4 class="font-medium text-gray-900 mb-2">Podcast Co-Host Wanted</h4>
                      <p class="text-sm text-gray-600 mb-3">Weekly tech podcast, looking for technical co-host</p>
                      <div class="flex items-center justify-between">
                        <span class="text-xs text-gray-600 bg-gray-200 px-2 py-1 rounded">Podcast</span>
                        <span class="text-sm text-green-600 font-medium">3 Responses</span>
                      </div>
                    </div>

                    <button class="w-full bg-gray-100 border-2 border-dashed border-gray-300 rounded-lg p-4 text-gray-600 hover:text-gray-700 hover:border-gray-400 transition-colors">
                      <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                      </svg>
                      <span class="text-sm font-medium">Post Collaboration Request</span>
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Recent Sessions -->
          <%= if length(@recent_sessions) > 0 do %>
            <div class="bg-white rounded-xl shadow-sm border">
              <div class="p-6 border-b border-gray-200">
                <div class="flex items-center justify-between">
                  <div>
                    <h2 class="text-xl font-bold text-gray-900">Recent Sessions</h2>
                    <p class="text-gray-600 text-sm mt-1">Pick up where you left off</p>
                  </div>
                  <.link navigate={~p"/studio/sessions"} class="text-sm text-blue-600 hover:text-blue-700 font-medium">
                    View All
                  </.link>
                </div>
              </div>

              <div class="p-6">
                <div class="space-y-3">
                  <%= for session <- @recent_sessions do %>
                    <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors">
                      <div class="flex items-center space-x-3">
                        <div class="w-10 h-10 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
                          <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                          </svg>
                        </div>
                        <div>
                          <h4 class="font-medium text-gray-900"><%= session.title %></h4>
                          <p class="text-sm text-gray-600">
                            <%= String.capitalize(String.replace(session.type, "_", " ")) %> •
                            <%= session.duration %> min •
                            <%= Timex.from_now(session.created_at) %>
                          </p>
                        </div>
                      </div>

                      <div class="flex items-center space-x-2">
                        <button phx-click="resume_session" phx-value-session_id={session.id} phx-target={@myself}
                                class="text-sm bg-blue-600 text-white px-3 py-1 rounded-lg hover:bg-blue-700 transition-colors">
                          Resume
                        </button>
                        <button phx-click="delete_session" phx-value-session_id={session.id} phx-target={@myself}
                                class="text-sm text-gray-400 hover:text-red-600 p-1">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                          </svg>
                        </button>
                      </div>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Upgrade Required -->
        <div class="bg-white rounded-xl shadow-sm border">
          <div class="p-12 text-center">
            <div class="w-20 h-20 bg-gradient-to-br from-amber-100 to-orange-100 rounded-full flex items-center justify-center mx-auto mb-6">
              <svg class="w-10 h-10 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>
            <h2 class="text-2xl font-bold text-gray-900 mb-4">Upgrade to Creator Tier</h2>
            <p class="text-gray-600 mb-8 max-w-2xl mx-auto">
              Unlock the Creator Studio with professional audio production, beat machine, podcast recording, live streaming tools, and collaboration features.
            </p>
            <button class="bg-blue-600 text-white px-6 py-3 rounded-lg hover:bg-blue-700 font-semibold">
              Upgrade Now
            </button>
          </div>
        </div>
      <% end %>

      <!-- Error Display -->
      <%= if @session_error do %>
        <div class="fixed top-4 right-4 z-50 bg-red-600 text-white p-4 rounded-lg shadow-lg">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <span><%= @session_error %></span>
            </div>
            <button phx-click="clear_error" phx-target={@myself} class="ml-4 text-white hover:text-gray-300">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Loading State -->
      <%= if @creating_session do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
          <div class="bg-white rounded-xl p-8 text-center shadow-xl">
            <div class="animate-spin w-8 h-8 border-4 border-blue-600 border-t-transparent rounded-full mx-auto mb-4"></div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Creating Studio Session</h3>
            <p class="text-gray-600">Setting up your creative workspace...</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
