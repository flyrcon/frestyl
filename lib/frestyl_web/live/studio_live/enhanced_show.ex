# lib/frestyl_web/live/studio_live/enhanced_show.ex
defmodule FrestylWeb.StudioLive.EnhancedShow do
  @moduledoc """
  Enhanced Frestyl Studio interface with complete audio/video production capabilities
  and proper Frestyl branding throughout.
  """

  use FrestylWeb, :live_view
  alias Frestyl.{Sessions, Studio}
  alias Frestyl.Studio.{AudioEngine, BeatMachine, EnhancedRecordingEngine}
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => session_id}, _session, socket) do
    # Get session info
    session = Sessions.get_session!(session_id)
    current_user = socket.assigns.current_user

    # Check permissions
    can_access = session.created_by_id == current_user.id or
                 Sessions.is_collaborator?(session_id, current_user.id)

    if not can_access do
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this studio session")
       |> redirect(to: ~p"/dashboard")}
    else
      # Subscribe to studio events
      if connected?(socket) do
        PubSub.subscribe(Frestyl.PubSub, "session:#{session_id}")
        PubSub.subscribe(Frestyl.PubSub, "audio_engine:#{session_id}")
        PubSub.subscribe(Frestyl.PubSub, "recording_engine:#{session_id}")
        PubSub.subscribe(Frestyl.PubSub, "beat_machine:#{session_id}")
      end

      # Initialize studio engines
      if connected?(socket) do
        initialize_studio_engines(session_id)
      end

      # Get initial state
      audio_state = get_audio_engine_state(session_id)
      recording_state = get_recording_engine_state(session_id)
      beat_machine_state = get_beat_machine_state(session_id)

      socket = socket
      |> assign(:session, session)
      |> assign(:session_id, session_id)
      |> assign(:current_tab, "mixer")
      |> assign(:audio_engine_state, audio_state)
      |> assign(:recording_state, recording_state)
      |> assign(:beat_machine_state, beat_machine_state)
      |> assign(:active_tracks, %{})
      |> assign(:master_volume, 0.8)
      |> assign(:is_recording, false)
      |> assign(:is_playing, false)
      |> assign(:current_bpm, 120)
      |> assign(:metronome_enabled, false)
      |> assign(:collaborators, get_session_collaborators(session_id))
      |> assign(:notifications, [])

      {:ok, socket}
    end
  end

  # Audio Engine Events

  @impl true
  def handle_event("audio_create_track", %{"name" => name, "type" => type}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    track_params = %{
      name: name,
      type: type,
      volume: 0.8,
      pan: 0.0,
      muted: false,
      solo: false
    }

    case AudioEngine.add_track(session_id, user_id, track_params) do
      {:ok, track} ->
        {:noreply,
         socket
         |> add_notification("Track '#{name}' created", :success)
         |> push_event("track_created", %{track: track})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create track: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_delete_track", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id

    case AudioEngine.delete_track(session_id, track_id) do
      :ok ->
        {:noreply,
         socket
         |> add_notification("Track deleted", :info)
         |> push_event("track_deleted", %{track_id: track_id})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete track: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_update_track_volume", params, socket) do
    %{"track_id" => track_id, "volume" => volume_str} = params
    session_id = socket.assigns.session_id

    volume = String.to_float(volume_str)

    case AudioEngine.update_track_volume(session_id, track_id, volume) do
      :ok ->
        {:noreply, push_event(socket, "track_volume_updated", %{track_id: track_id, volume: volume})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update volume: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_toggle_mute", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id

    # Get current mute state from audio engine
    current_muted = get_track_mute_state(session_id, track_id)
    new_muted = not current_muted

    case AudioEngine.mute_track(session_id, track_id, new_muted) do
      :ok ->
        {:noreply, push_event(socket, "track_muted", %{track_id: track_id, muted: new_muted})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle mute: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_toggle_solo", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id

    current_solo = get_track_solo_state(session_id, track_id)
    new_solo = not current_solo

    case AudioEngine.solo_track(session_id, track_id, new_solo) do
      :ok ->
        {:noreply, push_event(socket, "track_solo_changed", %{track_id: track_id, solo: new_solo})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle solo: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_start_playback", _params, socket) do
    session_id = socket.assigns.session_id

    case AudioEngine.start_playback(session_id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:is_playing, true)
         |> push_event("playback_started", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start playback: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_stop_playback", _params, socket) do
    session_id = socket.assigns.session_id

    case AudioEngine.stop_playback(session_id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:is_playing, false)
         |> push_event("playback_stopped", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop playback: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_set_master_volume", %{"volume" => volume_str}, socket) do
    session_id = socket.assigns.session_id
    volume = String.to_float(volume_str)

    case AudioEngine.set_master_volume(session_id, volume) do
      :ok ->
        {:noreply,
         socket
         |> assign(:master_volume, volume)
         |> push_event("master_volume_changed", %{volume: volume})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to set master volume: #{reason}")}
    end
  end

  @impl true
  def handle_event("audio_toggle_metronome", _params, socket) do
    session_id = socket.assigns.session_id
    current_enabled = socket.assigns.metronome_enabled
    new_enabled = not current_enabled
    bpm = socket.assigns.current_bpm

    case AudioEngine.toggle_metronome(session_id, new_enabled, bpm) do
      :ok ->
        {:noreply,
         socket
         |> assign(:metronome_enabled, new_enabled)
         |> add_notification("Metronome #{if new_enabled, do: "enabled", else: "disabled"}", :info)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle metronome: #{reason}")}
    end
  end

  # Recording Events

  @impl true
  def handle_event("recording_start", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    recording_opts = [
      quality: "high",
      format: "mp3",
      auto_upload: true,
      monitoring: true
    ]

    case EnhancedRecordingEngine.start_recording(session_id, track_id, user_id, recording_opts) do
      {:ok, recording_session} ->
        {:noreply,
         socket
         |> assign(:is_recording, true)
         |> add_notification("Recording started on track #{track_id}", :success)
         |> push_event("recording_started", %{track_id: track_id, session: recording_session})}

      {:error, :recording_limit_exceeded} ->
        {:noreply,
         socket
         |> put_flash(:error, "Recording limit exceeded for your tier")
         |> push_event("show_upgrade_modal", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("recording_stop", %{"track_id" => track_id}, socket) do
    session_id = socket.assigns.session_id
    user_id = socket.assigns.current_user.id

    case EnhancedRecordingEngine.stop_recording(session_id, track_id, user_id) do
      {:ok, recording_metadata} ->
        {:noreply,
         socket
         |> assign(:is_recording, false)
         |> add_notification("Recording stopped and processing...", :info)
         |> push_event("recording_stopped", %{track_id: track_id, metadata: recording_metadata})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop recording: #{reason}")}
    end
  end

  @impl true
  def handle_event("recording_export", %{"track_id" => track_id, "format" => format}, socket) do
    session_id = socket.assigns.session_id

    case EnhancedRecordingEngine.export_recording(session_id, track_id, format) do
      {:ok, recording} ->
        {:noreply,
         socket
         |> add_notification("Recording exported successfully", :success)
         |> push_event("recording_exported", %{recording: recording})}

      {:ok, :processing} ->
        {:noreply, add_notification(socket, "Export processing, please wait...", :info)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to export recording: #{reason}")}
    end
  end

  # Beat Machine Events

  @impl true
  def handle_event("beat_create_pattern", %{"name" => name, "steps" => steps}, socket) do
    session_id = socket.assigns.session_id
    steps_int = String.to_integer(steps)

    case BeatMachine.create_pattern(session_id, name, steps_int) do
      {:ok, pattern} ->
        {:noreply,
         socket
         |> add_notification("Pattern '#{name}' created", :success)
         |> push_event("beat_pattern_created", %{pattern: pattern})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create pattern: #{reason}")}
    end
  end

  @impl true
  def handle_event("beat_update_step", params, socket) do
    %{"pattern_id" => pattern_id, "instrument" => instrument, "step" => step, "velocity" => velocity} = params
    session_id = socket.assigns.session_id

    step_int = String.to_integer(step)
    velocity_int = String.to_integer(velocity)

    case BeatMachine.update_step(session_id, pattern_id, instrument, step_int, velocity_int) do
      :ok ->
        {:noreply, push_event(socket, "beat_step_updated", %{
          pattern_id: pattern_id,
          instrument: instrument,
          step: step_int,
          velocity: velocity_int
        })}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update step: #{reason}")}
    end
  end

  @impl true
  def handle_event("beat_play_pattern", %{"pattern_id" => pattern_id}, socket) do
    session_id = socket.assigns.session_id

    case BeatMachine.play_pattern(session_id, pattern_id) do
      :ok ->
        {:noreply, push_event(socket, "beat_pattern_started", %{pattern_id: pattern_id})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to play pattern: #{reason}")}
    end
  end

  @impl true
  def handle_event("beat_stop_pattern", _params, socket) do
    session_id = socket.assigns.session_id

    case BeatMachine.stop_pattern(session_id) do
      :ok ->
        {:noreply, push_event(socket, "beat_pattern_stopped", %{})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop pattern: #{reason}")}
    end
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :current_tab, tab)}
  end

  # Handle info messages from engines

  @impl true
  def handle_info({:track_created, track}, socket) do
    {:noreply, push_event(socket, "track_created", %{track: track})}
  end

  @impl true
  def handle_info({:recording_compiled, recording_key, recording}, socket) do
    {:noreply,
     socket
     |> add_notification("Recording compiled and ready for export", :success)
     |> push_event("recording_compiled", %{recording: recording})}
  end

  @impl true
  def handle_info({:recording_uploaded, recording_key, upload_info}, socket) do
    {:noreply,
     socket
     |> add_notification("Recording uploaded to cloud storage", :success)
     |> push_event("recording_uploaded", %{upload_info: upload_info})}
  end

  @impl true
  def handle_info({:beat_machine, {:step_triggered, step, instruments}}, socket) do
    {:noreply, push_event(socket, "beat_step_triggered", %{step: step, instruments: instruments})}
  end

  @impl true
  def handle_info({:collaborator_joined, user_id}, socket) do
    collaborators = [user_id | socket.assigns.collaborators] |> Enum.uniq()
    {:noreply,
     socket
     |> assign(:collaborators, collaborators)
     |> add_notification("Collaborator joined the session", :info)}
  end

  @impl true
  def handle_info({:collaborator_left, user_id}, socket) do
    collaborators = List.delete(socket.assigns.collaborators, user_id)
    {:noreply,
     socket
     |> assign(:collaborators, collaborators)
     |> add_notification("Collaborator left the session", :info)}
  end

  # Helper Functions

  defp initialize_studio_engines(session_id) do
    # Start audio engine
    case AudioEngine.start_link(session_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> Logger.error("Failed to start AudioEngine: #{inspect(error)}")
    end

    # Start recording engine
    case EnhancedRecordingEngine.start_link(session_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> Logger.error("Failed to start RecordingEngine: #{inspect(error)}")
    end

    # Start beat machine
    case BeatMachine.start_link(session_id) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      error -> Logger.error("Failed to start BeatMachine: #{inspect(error)}")
    end
  end

  defp get_audio_engine_state(session_id) do
    case AudioEngine.get_engine_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{}
    end
  end

  defp get_recording_engine_state(session_id) do
    case EnhancedRecordingEngine.get_recording_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{}
    end
  end

  defp get_beat_machine_state(session_id) do
    case BeatMachine.get_state(session_id) do
      {:ok, state} -> state
      {:error, _} -> %{}
    end
  end

  defp get_session_collaborators(session_id) do
    Sessions.get_session_participants(session_id)
  end

  defp get_track_mute_state(_session_id, _track_id) do
    # This would get the actual mute state from the audio engine
    false
  end

  defp get_track_solo_state(_session_id, _track_id) do
    # This would get the actual solo state from the audio engine
    false
  end

  defp add_notification(socket, message, type \\ :info) do
    notification = %{
      id: System.unique_integer([:positive]),
      type: type,
      message: message,
      timestamp: DateTime.utc_now()
    }
    notifications = [notification | socket.assigns.notifications] |> Enum.take(5)
    assign(socket, notifications: notifications)
  end

  # Render Function with Frestyl Branding

  @impl true
  def render(assigns) do
    ~H"""
    <div class="frestyl-studio-container min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
      <!-- Studio Header -->
      <div class="frestyl-studio-header">
        <div class="frestyl-studio-panel">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold frestyl-text-cosmic mb-2">
                Frestyl Studio
              </h1>
              <p class="text-purple-200">Professional Audio & Video Production Suite</p>
              <div class="flex items-center space-x-4 mt-2 text-sm text-purple-300">
                <span>Session: <%= @session.title %></span>
                <span>•</span>
                <span><%= length(@collaborators) %> collaborators</span>
                <span>•</span>
                <span class={["flex items-center space-x-1", if(@is_recording, do: "text-red-400", else: "text-gray-400")]}>
                  <div class={["w-2 h-2 rounded-full", if(@is_recording, do: "bg-red-400 animate-pulse", else: "bg-gray-400")]}></div>
                  <span><%= if @is_recording, do: "RECORDING", else: "READY" %></span>
                </span>
              </div>
            </div>

            <div class="flex items-center space-x-4">
              <!-- Master Controls -->
              <div class="frestyl-card-glass p-4 rounded-xl">
                <div class="flex items-center space-x-4">
                  <!-- Master Volume -->
                  <div class="flex items-center space-x-2">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 14.142M5 17.5l1.5-1.5V8l-1.5-1.5v11z"/>
                    </svg>
                    <input type="range"
                           class="frestyl-volume-slider w-20"
                           min="0" max="1" step="0.01"
                           value={@master_volume}
                           phx-change="audio_set_master_volume">
                    <span class="text-sm text-white w-8"><%= round(@master_volume * 100) %>%</span>
                  </div>

                  <!-- Transport Controls -->
                  <div class="flex items-center space-x-2">
                    <%= if @is_playing do %>
                      <button phx-click="audio_stop_playback" class="frestyl-btn frestyl-btn-glass frestyl-btn-sm">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M6 6h12v12H6z"/>
                        </svg>
                        Stop
                      </button>
                    <% else %>
                      <button phx-click="audio_start_playback" class="frestyl-btn frestyl-btn-emerald frestyl-btn-sm">
                        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                          <path d="m7 4 10 8L7 20V4z"/>
                        </svg>
                        Play
                      </button>
                    <% end %>

                    <button phx-click="audio_toggle_metronome"
                            class={["frestyl-btn frestyl-btn-sm", if(@metronome_enabled, do: "frestyl-btn-primary", else: "frestyl-btn-glass")]}>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                      </svg>
                      <%= @current_bpm %>
                    </button>
                  </div>
                </div>
              </div>

              <!-- Session Actions -->
              <.link navigate={~p"/dashboard"} class="frestyl-btn frestyl-btn-outline frestyl-btn-sm">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
                </svg>
                Exit Studio
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Studio Workspace -->
      <div class="flex h-screen pt-4">
        <!-- Left Sidebar - Track List -->
        <div class="w-80 p-4 space-y-4">
          <div class="frestyl-studio-panel">
            <div class="flex items-center justify-between mb-4">
              <h3 class="text-lg font-semibold text-white">Tracks</h3>
              <button phx-click="show_create_track_modal" class="frestyl-btn frestyl-btn-primary frestyl-btn-sm">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Track
              </button>
            </div>

            <div class="space-y-2">
              <!-- Sample tracks for demo -->
              <div class="frestyl-track">
                <div class="flex items-center justify-between mb-2">
                  <div class="flex items-center space-x-3">
                    <div class="w-10 h-10 bg-gradient-to-br from-purple-600 to-blue-600 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M12 3v10.55c-.59-.34-1.27-.55-2-.55-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4V7h4V3h-6z"/>
                      </svg>
                    </div>
                    <div>
                      <h4 class="font-medium text-white">Vocal Track</h4>
                      <p class="text-sm text-purple-300">Audio • Stereo</p>
                    </div>
                  </div>
                  <div class="flex items-center space-x-1">
                    <button class="w-8 h-8 bg-white/10 hover:bg-white/20 rounded-lg flex items-center justify-center transition-colors"
                            phx-click="recording_start" phx-value-track_id="vocal_1">
                      <svg class="w-4 h-4 text-red-400" fill="currentColor" viewBox="0 0 24 24">
                        <circle cx="12" cy="12" r="10"/>
                      </svg>
                    </button>
                    <button class="w-8 h-8 bg-white/10 hover:bg-white/20 rounded-lg flex items-center justify-center transition-colors"
                            phx-click="audio_toggle_mute" phx-value-track_id="vocal_1">
                      <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/>
                      </svg>
                    </button>
                  </div>
                </div>
                <input type="range" class="frestyl-volume-slider w-full" min="0" max="1" step="0.01" value="0.8"
                       phx-change="audio_update_track_volume" phx-value-track_id="vocal_1">
              </div>

              <div class="frestyl-track">
                <div class="flex items-center justify-between mb-2">
                  <div class="flex items-center space-x-3">
                    <div class="w-10 h-10 bg-gradient-to-br from-emerald-600 to-teal-600 rounded-lg flex items-center justify-center">
                      <svg class="w-5 h-5 text-white" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M9 11H7v2h2v-2zm4 0h-2v2h2v-2zm4 0h-2v2h2v-2zm2-7h-2V2a1 1 0 00-2 0v2H9V2a1 1 0 00-2 0v2H5a2 2 0 00-2 2v14a2 2 0 002 2h14a2 2 0 002-2V6a2 2 0 00-2-2z"/>
                      </svg>
                    </div>
                    <div>
                      <h4 class="font-medium text-white">Beat Machine</h4>
                      <p class="text-sm text-emerald-300">Drum Kit • 16 Steps</p>
                    </div>
                  </div>
                  <div class="flex items-center space-x-1">
                    <button class="w-8 h-8 bg-white/10 hover:bg-white/20 rounded-lg flex items-center justify-center transition-colors">
                      <svg class="w-4 h-4 text-emerald-400" fill="currentColor" viewBox="0 0 24 24">
                        <path d="m7 4 10 8L7 20V4z"/>
                      </svg>
                    </button>
                  </div>
                </div>
                <input type="range" class="frestyl-volume-slider w-full" min="0" max="1" step="0.01" value="0.6">
              </div>
            </div>
          </div>

          <!-- Collaborators Panel -->
          <div class="frestyl-studio-panel">
            <h3 class="text-lg font-semibold text-white mb-4">Collaborators</h3>
            <div class="space-y-2">
              <%= for collaborator_id <- @collaborators do %>
                <div class="flex items-center space-x-3 p-2 bg-white/5 rounded-lg">
                  <div class="w-8 h-8 bg-gradient-to-br from-purple-600 to-pink-600 rounded-full flex items-center justify-center">
                    <span class="text-white text-sm font-medium">U</span>
                  </div>
                  <div>
                    <p class="text-white text-sm font-medium">User <%= collaborator_id %></p>
                    <p class="text-purple-300 text-xs">Online</p>
                  </div>
                </div>
              <% end %>
              <%= if @collaborators == [] do %>
                <p class="text-purple-300 text-sm italic">No collaborators online</p>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Main Content Area -->
        <div class="flex-1 p-4">
          <!-- Tab Navigation -->
          <div class="flex space-x-1 mb-6 bg-white/5 p-1 rounded-xl backdrop-blur-sm">
            <button phx-click="change_tab" phx-value-tab="mixer"
                    class={["px-6 py-3 rounded-lg font-medium transition-all",
                           if(@current_tab == "mixer", do: "bg-white text-purple-900", else: "text-white hover:bg-white/10")]}>
              <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
              </svg>
              Mixer
            </button>
            <button phx-click="change_tab" phx-value-tab="beat_machine"
                    class={["px-6 py-3 rounded-lg font-medium transition-all",
                           if(@current_tab == "beat_machine", do: "bg-white text-purple-900", else: "text-white hover:bg-white/10")]}>
              <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"/>
              </svg>
              Beat Machine
            </button>
            <button phx-click="change_tab" phx-value-tab="recordings"
                    class={["px-6 py-3 rounded-lg font-medium transition-all",
                           if(@current_tab == "recordings", do: "bg-white text-purple-900", else: "text-white hover:bg-white/10")]}>
              <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
              </svg>
              Recordings
            </button>
          </div>

          <!-- Tab Content -->
          <div class="frestyl-studio-panel min-h-96">
            <%= case @current_tab do %>
              <% "mixer" -> %>
                <div class="p-6">
                  <h2 class="text-2xl font-bold text-white mb-6">Audio Mixer</h2>
                  <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
                    <!-- Waveform Display -->
                    <div class="frestyl-waveform">
                      <div class="flex items-center justify-center h-full text-purple-300">
                        <div class="text-center">
                          <svg class="w-12 h-12 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2z"/>
                          </svg>
                          <p>Audio waveform will appear here</p>
                        </div>
                      </div>
                    </div>

                    <!-- Effects Panel -->
                    <div class="space-y-4">
                      <h3 class="text-lg font-semibold text-white">Effects</h3>
                      <div class="space-y-3">
                        <div class="frestyl-card-glass p-4 rounded-xl">
                          <div class="flex items-center justify-between mb-2">
                            <span class="text-white font-medium">Reverb</span>
                            <button class="text-purple-300 hover:text-white">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                              </svg>
                            </button>
                          </div>
                          <input type="range" class="frestyl-volume-slider w-full" min="0" max="1" step="0.01" value="0.3">
                        </div>

                        <div class="frestyl-card-glass p-4 rounded-xl">
                          <div class="flex items-center justify-between mb-2">
                            <span class="text-white font-medium">Delay</span>
                            <button class="text-purple-300 hover:text-white">
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                              </svg>
                            </button>
                          </div>
                          <input type="range" class="frestyl-volume-slider w-full" min="0" max="1" step="0.01" value="0.1">
                        </div>
                      </div>
                    </div>
                  </div>
                </div>

              <% "beat_machine" -> %>
                <div class="p-6">
                  <div class="flex items-center justify-between mb-6">
                    <h2 class="text-2xl font-bold text-white">Beat Machine</h2>
                    <div class="flex items-center space-x-4">
                      <button class="frestyl-btn frestyl-btn-primary frestyl-btn-sm" phx-click="beat_create_pattern" phx-value-name="New Pattern" phx-value-steps="16">
                        Create Pattern
                      </button>
                    </div>
                  </div>

                  <div class="frestyl-beat-machine">
                    <!-- Step Sequencer -->
                    <div class="mb-8">
                      <h3 class="text-lg font-semibold text-white mb-4">16-Step Sequencer</h3>
                      <div class="grid grid-cols-16 gap-1 mb-4">
                        <%= for step <- 1..16 do %>
                          <div class={["frestyl-sequencer-step", if(rem(step, 4) == 1, do: "border-purple-400")]}
                               phx-click="beat_update_step"
                               phx-value-pattern_id="default"
                               phx-value-instrument="kick"
                               phx-value-step={step}
                               phx-value-velocity="127">
                            <span class="text-xs text-purple-300"><%= step %></span>
                          </div>
                        <% end %>
                      </div>
                    </div>

                    <!-- Drum Pads -->
                    <div class="grid grid-cols-4 gap-4">
                      <%= for {instrument, label} <- [{"kick", "Kick"}, {"snare", "Snare"}, {"hihat", "Hi-Hat"}, {"crash", "Crash"}] do %>
                        <div class="frestyl-beat-pad" phx-click="beat_trigger_pad" phx-value-instrument={instrument}>
                          <%= label %>
                        </div>
                      <% end %>
                    </div>

                    <!-- Pattern Controls -->
                    <div class="flex items-center justify-center space-x-4 mt-8">
                      <button class="frestyl-btn frestyl-btn-emerald" phx-click="beat_play_pattern" phx-value-pattern_id="default">
                        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                          <path d="m7 4 10 8L7 20V4z"/>
                        </svg>
                        Play
                      </button>
                      <button class="frestyl-btn frestyl-btn-outline" phx-click="beat_stop_pattern">
                        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                          <path d="M6 6h12v12H6z"/>
                        </svg>
                        Stop
                      </button>
                    </div>
                  </div>
                </div>

              <% "recordings" -> %>
                <div class="p-6">
                  <h2 class="text-2xl font-bold text-white mb-6">Recordings</h2>
                  <div class="space-y-4">
                    <div class="frestyl-card-glass p-4 rounded-xl">
                      <div class="flex items-center justify-between">
                        <div>
                          <h3 class="text-white font-medium">Vocal Take 1</h3>
                          <p class="text-purple-300 text-sm">Recorded 2 minutes ago • 3:24 duration</p>
                        </div>
                        <div class="flex items-center space-x-2">
                          <button class="frestyl-btn frestyl-btn-sm frestyl-btn-glass">
                            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                              <path d="m7 4 10 8L7 20V4z"/>
                            </svg>
                            Play
                          </button>
                          <button class="frestyl-btn frestyl-btn-sm frestyl-btn-outline"
                                  phx-click="recording_export" phx-value-track_id="vocal_1" phx-value-format="mp3">
                            Export
                          </button>
                        </div>
                      </div>
                    </div>

                    <div class="text-center py-12 text-purple-300">
                      <svg class="w-16 h-16 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
                      </svg>
                      <p>Start recording to see your tracks here</p>
                    </div>
                  </div>
                </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Notifications -->
      <div class="fixed top-4 right-4 space-y-2 z-50">
        <%= for notification <- @notifications do %>
          <div class={["frestyl-notification", notification.type]}>
            <div class="flex items-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= case notification.type do %>
                  <% :success -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  <% :error -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  <% :warning -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01"/>
                  <% _ -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01"/>
                <% end %>
              </svg>
              <span><%= notification.message %></span>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
