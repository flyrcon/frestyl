# lib/frestyl_web/live/broadcast_live/audio_mixer_component.ex
defmodule FrestylWeb.BroadcastLive.AudioMixerComponent do
  use FrestylWeb, :live_component
  alias Frestyl.Studio.AudioEngine
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      # Mixer state
      mixer_open: false,
      mixer_mode: "simple", # simple, advanced, mobile
      recording_enabled: false,

      # Audio state
      master_volume: 0.8,
      master_muted: false,
      input_gain: 0.7,
      output_level: 0.0,

      # Track management
      tracks: [],
      active_track: nil,
      max_tracks: 8,

      # Mobile optimizations
      is_mobile: false,
      touch_controls: true,
      simplified_ui: false,

      # Performance monitoring
      cpu_usage: 0,
      buffer_health: "good",

      # Effects
      master_effects: [],
      available_effects: get_available_effects()
    )}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    # Check if we need to initialize audio engine
    socket = if not Map.get(socket.assigns, :audio_engine_initialized, false) do
      initialize_audio_engine(socket)
    else
      socket
    end

    # Update mobile detection
    socket = detect_mobile_context(socket)

    {:ok, socket}
  end

  @impl true
  def handle_event("toggle_mixer", _params, socket) do
    new_state = !socket.assigns.mixer_open

    # Initialize audio engine when opening mixer
    socket = if new_state and not Map.get(socket.assigns, :audio_engine_initialized, false) do
      initialize_audio_engine(socket)
    else
      socket
    end

    {:noreply, assign(socket, mixer_open: new_state)}
  end


  @impl true
  def handle_event("switch_mixer_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, mixer_mode: mode)}
  end

  @impl true
  def handle_event("create_track", %{"type" => track_type}, socket) do
    if length(socket.assigns.tracks) < socket.assigns.max_tracks do
      # Send message to parent to create track in audio engine
      track_params = %{
        name: "Track #{length(socket.assigns.tracks) + 1}",
        input_source: track_type,
        connect_input: true
      }

      send(self(), {:create_audio_track, track_params})

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Maximum #{socket.assigns.max_tracks} tracks allowed")}
    end
  end

  @impl true
  def handle_event("set_master_volume", %{"volume" => volume}, socket) do
    volume_float = String.to_float(volume) / 100.0

    # Update local state
    socket = assign(socket, master_volume: volume_float)

    # Send to audio engine
    send(self(), {:set_master_volume, volume_float})

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_master_mute", _params, socket) do
    new_muted = !socket.assigns.master_muted

    volume = if new_muted, do: 0.0, else: socket.assigns.master_volume
    send(self(), {:set_master_volume, volume})

    {:noreply, assign(socket, master_muted: new_muted)}
  end

  @impl true
  def handle_event("toggle_recording", _params, socket) do
    new_state = !socket.assigns.recording_enabled

    if new_state do
      send(self(), {:start_mixer_recording})
    else
      send(self(), {:stop_mixer_recording})
    end

    {:noreply, assign(socket, recording_enabled: new_state)}
  end

  @impl true
  def handle_event("add_master_effect", %{"effect_type" => effect_type}, socket) do
    send(self(), {:add_master_effect, effect_type})
    {:noreply, socket}
  end

  @impl true
  def handle_event("mobile_quick_action", %{"action" => action}, socket) do
    case action do
      "toggle_mute" -> handle_event("toggle_master_mute", %{}, socket)
      "start_record" -> handle_event("toggle_recording", %{}, socket)
      "add_track" -> handle_event("create_track", %{"type" => "microphone"}, socket)
      _ -> {:noreply, socket}
    end
  end

  # Handle updates from audio engine
  @impl true
  def handle_info({:audio_engine_update, update}, socket) do
    case update do
      {:tracks_updated, tracks} ->
        {:noreply, assign(socket, tracks: tracks)}

      {:master_level_update, level} ->
        {:noreply, assign(socket, output_level: level)}

      {:performance_update, stats} ->
        {:noreply, assign(socket,
          cpu_usage: stats.cpu_usage,
          buffer_health: stats.buffer_health
        )}

      _ ->
        {:noreply, socket}
    end
  end

  defp initialize_audio_engine(socket) do
    # This would integrate with your existing audio engine
    # For now, just mark as initialized
    assign(socket, audio_engine_initialized: true)
  end

  defp detect_mobile_context(socket) do
    # You could check user agent or screen size
    # For now, default to false
    assign(socket, is_mobile: false)
  end

  defp get_available_effects do
    [
      %{id: "reverb", name: "Reverb", category: "spatial"},
      %{id: "delay", name: "Delay", category: "temporal"},
      %{id: "compressor", name: "Compressor", category: "dynamics"},
      %{id: "eq", name: "EQ", category: "frequency"},
      %{id: "chorus", name: "Chorus", category: "modulation"},
      %{id: "distortion", name: "Distortion", category: "saturation"}
    ]
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <!-- Mixer Toggle Button -->
      <button
        phx-click="toggle_mixer"
        phx-target={@myself}
        class={[
          "fixed bottom-6 right-6 z-50 w-14 h-14 rounded-full shadow-xl transition-all duration-300",
          "flex items-center justify-center backdrop-blur-lg border border-white/20",
          @mixer_open && "bg-purple-600/90 text-white" || "bg-black/60 text-white/80 hover:bg-purple-600/70"
        ]}
        title={@mixer_open && "Close Audio Mixer" || "Open Audio Mixer"}
      >
        <%= if @mixer_open do %>
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        <% else %>
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
          </svg>
        <% end %>
      </button>

      <!-- Mixer Panel -->
      <%= if @mixer_open do %>
        <div class={[
          "fixed inset-x-4 bottom-24 z-40 max-h-96 bg-black/90 backdrop-blur-xl",
          "border border-white/20 rounded-2xl shadow-2xl transition-all duration-300",
          @is_mobile && "inset-x-2 bottom-20 max-h-80" || "max-w-6xl mx-auto"
        ]}>
          <!-- Mobile vs Desktop Layout -->
          <%= if @is_mobile do %>
            <%= render_mobile_mixer(assigns) %>
          <% else %>
            <%= render_desktop_mixer(assigns) %>
          <% end %>
        </div>
      <% end %>

      <!-- Recording Indicator -->
      <%= if @recording_enabled do %>
        <div class="fixed top-4 right-4 z-50 bg-red-600 text-white px-4 py-2 rounded-full shadow-lg animate-pulse">
          <div class="flex items-center gap-2 text-sm font-medium">
            <div class="w-2 h-2 bg-white rounded-full"></div>
            Recording Audio
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_mobile_mixer(assigns) do
    ~H"""
    <div class="p-4">
      <!-- Mobile Header -->
      <div class="flex items-center justify-between mb-4">
        <h3 class="text-white font-semibold text-lg">Audio Mixer</h3>

        <!-- Mode Switcher -->
        <div class="flex bg-white/10 rounded-lg p-1">
          <button
            phx-click="switch_mixer_mode"
            phx-value-mode="simple"
            phx-target={@myself}
            class={[
              "px-3 py-1 rounded text-sm font-medium transition-colors",
              @mixer_mode == "simple" && "bg-white/20 text-white" || "text-white/60"
            ]}
          >
            Simple
          </button>
          <button
            phx-click="switch_mixer_mode"
            phx-value-mode="advanced"
            phx-target={@myself}
            class={[
              "px-3 py-1 rounded text-sm font-medium transition-colors",
              @mixer_mode == "advanced" && "bg-white/20 text-white" || "text-white/60"
            ]}
          >
            Pro
          </button>
        </div>
      </div>

      <%= if @mixer_mode == "simple" do %>
        <!-- Simple Mobile Layout -->
        <div class="space-y-4">
          <!-- Master Controls -->
          <div class="bg-white/10 rounded-xl p-4">
            <div class="flex items-center justify-between mb-3">
              <span class="text-white font-medium">Master</span>
              <div class="flex items-center gap-2">
                <span class="text-white/70 text-sm"><%= round(@master_volume * 100) %>%</span>
                <%= if @output_level > 0 do %>
                  <div class="w-8 h-2 bg-black/30 rounded-full overflow-hidden">
                    <div
                      class={[
                        "h-full transition-all duration-75 rounded-full",
                        @output_level > 0.8 && "bg-red-500" || @output_level > 0.6 && "bg-yellow-500" || "bg-green-500"
                      ]}
                      style={"width: #{@output_level * 100}%;"}
                    ></div>
                  </div>
                <% end %>
              </div>
            </div>

            <input
              type="range"
              min="0"
              max="100"
              value={round(@master_volume * 100)}
              phx-change="set_master_volume"
              phx-target={@myself}
              class="w-full h-3 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
            />
          </div>

          <!-- Quick Actions -->
          <div class="grid grid-cols-2 gap-3">
            <button
              phx-click="mobile_quick_action"
              phx-value-action={@master_muted && "toggle_mute" || "toggle_mute"}
              phx-target={@myself}
              class={[
                "flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-colors",
                @master_muted && "bg-red-500/20 text-red-300" || "bg-white/10 text-white/80 hover:bg-white/20"
              ]}
            >
              <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= if @master_muted do %>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                <% else %>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                <% end %>
              </svg>
              <span><%= @master_muted && "Unmute" || "Mute" %></span>
            </button>

            <button
              phx-click="mobile_quick_action"
              phx-value-action={@recording_enabled && "stop_record" || "start_record"}
              phx-target={@myself}
              class={[
                "flex items-center justify-center gap-2 py-3 rounded-xl font-medium transition-colors",
                @recording_enabled && "bg-red-500 text-white animate-pulse" || "bg-purple-500/20 text-purple-300 hover:bg-purple-500/30"
              ]}
            >
              <%= if @recording_enabled do %>
                <div class="w-3 h-3 bg-white rounded-sm"></div>
                <span>Stop</span>
              <% else %>
                <div class="w-3 h-3 bg-current rounded-full"></div>
                <span>Record</span>
              <% end %>
            </button>
          </div>

          <!-- Track Summary -->
          <div class="bg-white/10 rounded-xl p-4">
            <div class="flex items-center justify-between mb-2">
              <span class="text-white font-medium">Tracks</span>
              <span class="text-white/70 text-sm"><%= length(@tracks) %>/<%= @max_tracks %></span>
            </div>

            <%= if length(@tracks) > 0 do %>
              <div class="space-y-2">
                <%= for track <- Enum.take(@tracks, 3) do %>
                  <div class="flex items-center justify-between py-1">
                    <span class="text-white/80 text-sm truncate flex-1"><%= track.name %></span>
                    <div class="flex items-center gap-1">
                      <%= if track.muted do %>
                        <div class="w-1.5 h-1.5 bg-red-500 rounded-full"></div>
                      <% end %>
                      <%= if track.solo do %>
                        <div class="w-1.5 h-1.5 bg-yellow-500 rounded-full"></div>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if length(@tracks) > 3 do %>
                  <div class="text-center text-white/60 text-sm">
                    +<%= length(@tracks) - 3 %> more tracks
                  </div>
                <% end %>
              </div>
            <% else %>
              <button
                phx-click="mobile_quick_action"
                phx-value-action="add_track"
                phx-target={@myself}
                class="w-full py-2 text-purple-400 hover:text-purple-300 text-sm"
              >
                + Add your first track
              </button>
            <% end %>
          </div>
        </div>

      <% else %>
        <!-- Advanced Mobile Layout -->
        <div class="space-y-3 max-h-64 overflow-y-auto">
          <!-- Master Section -->
          <div class="bg-white/10 rounded-xl p-3">
            <div class="flex items-center justify-between mb-2">
              <span class="text-white font-medium text-sm">Master Output</span>
              <div class="flex items-center gap-2">
                <button
                  phx-click="toggle_master_mute"
                  phx-target={@myself}
                  class={[
                    "w-6 h-6 rounded flex items-center justify-center",
                    @master_muted && "bg-red-500/20 text-red-400" || "bg-white/10 text-white/70"
                  ]}
                >
                  <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <%= if @master_muted do %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
                    <% else %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728" />
                    <% end %>
                  </svg>
                </button>

                <span class="text-white/70 text-xs"><%= round(@master_volume * 100) %>%</span>
              </div>
            </div>

            <div class="flex items-center gap-2">
              <input
                type="range"
                min="0"
                max="100"
                value={round(@master_volume * 100)}
                phx-change="set_master_volume"
                phx-target={@myself}
                class="flex-1 h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider"
              />

              <%= if @output_level > 0 do %>
                <div class="w-12 h-2 bg-black/30 rounded-full overflow-hidden">
                  <div
                    class={[
                      "h-full transition-all duration-75 rounded-full",
                      @output_level > 0.8 && "bg-red-500" || @output_level > 0.6 && "bg-yellow-500" || "bg-green-500"
                    ]}
                    style={"width: #{@output_level * 100}%;"}
                  ></div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Individual Tracks -->
          <%= for track <- @tracks do %>
            <.live_component
              module={FrestylWeb.Studio.AudioTrackComponent}
              id={"mobile-track-#{track.id}"}
              track={track}
              is_mobile={true}
              permissions={[:edit_audio, :record_audio]}
              current_user={@current_user}
              recording_track={@recording_enabled && track.id}
            />
          <% end %>

          <!-- Add Track Button -->
          <%= if length(@tracks) < @max_tracks do %>
            <button
              phx-click="create_track"
              phx-value-type="microphone"
              phx-target={@myself}
              class="w-full py-3 border-2 border-dashed border-white/20 rounded-xl text-white/60 hover:text-white hover:border-white/40 transition-colors"
            >
              + Add Audio Track
            </button>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_desktop_mixer(assigns) do
    ~H"""
    <div class="p-6">
      <!-- Desktop Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center gap-4">
          <h3 class="text-white font-semibold text-xl">Live Audio Mixer</h3>

          <!-- Performance Indicators -->
          <div class="flex items-center gap-3 text-sm">
            <div class="flex items-center gap-1 text-white/70">
              <div class={[
                "w-2 h-2 rounded-full",
                @buffer_health == "good" && "bg-green-500" || @buffer_health == "warning" && "bg-yellow-500" || "bg-red-500"
              ]}></div>
              <span>Audio: <%= String.capitalize(@buffer_health) %></span>
            </div>

            <%= if @cpu_usage > 0 do %>
              <div class="text-white/70">
                CPU: <%= round(@cpu_usage) %>%
              </div>
            <% end %>
          </div>
        </div>

        <!-- Master Controls -->
        <div class="flex items-center gap-4">
          <!-- Recording Toggle -->
          <button
            phx-click="toggle_recording"
            phx-target={@myself}
            class={[
              "flex items-center gap-2 px-4 py-2 rounded-lg font-medium transition-all duration-200",
              @recording_enabled && "bg-red-600 text-white animate-pulse" || "bg-red-600/20 text-red-300 hover:bg-red-600/30"
            ]}
          >
            <%= if @recording_enabled do %>
              <div class="w-3 h-3 bg-white rounded-sm"></div>
              <span>Stop Recording</span>
            <% else %>
              <div class="w-3 h-3 bg-current rounded-full"></div>
              <span>Start Recording</span>
            <% end %>
          </button>

          <!-- Master Mute -->
          <button
            phx-click="toggle_master_mute"
            phx-target={@myself}
            class={[
              "w-10 h-10 rounded-lg flex items-center justify-center transition-colors",
              @master_muted && "bg-red-500/20 text-red-400" || "bg-white/10 text-white/70 hover:text-white hover:bg-white/20"
            ]}
            title={@master_muted && "Unmute Master" || "Mute Master"}
          >
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <%= if @master_muted do %>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />
              <% else %>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
              <% end %>
            </svg>
          </button>
        </div>
      </div>

      <!-- Desktop Mixer Layout -->
      <div class="grid grid-cols-12 gap-6 max-h-80 overflow-hidden">
        <!-- Individual Tracks -->
        <div class="col-span-10 flex gap-3 overflow-x-auto pb-2">
          <%= for track <- @tracks do %>
            <div class="flex-shrink-0 w-20">
              <.live_component
                module={FrestylWeb.Studio.AudioTrackComponent}
                id={"desktop-track-#{track.id}"}
                track={track}
                is_mobile={false}
                permissions={[:edit_audio, :record_audio]}
                current_user={@current_user}
                recording_track={@recording_enabled && track.id}
              />
            </div>
          <% end %>

          <!-- Add Track Button -->
          <%= if length(@tracks) < @max_tracks do %>
            <div class="flex-shrink-0 w-20">
              <button
                phx-click="create_track"
                phx-value-type="microphone"
                phx-target={@myself}
                class="w-full h-64 border-2 border-dashed border-white/20 rounded-xl text-white/60 hover:text-white hover:border-white/40 transition-colors flex flex-col items-center justify-center gap-2"
              >
                <svg class="h-8 w-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                <span class="text-xs">Add Track</span>
              </button>
            </div>
          <% end %>
        </div>

        <!-- Master Section -->
        <div class="col-span-2 bg-white/10 rounded-xl p-4">
          <div class="text-center mb-4">
            <h4 class="text-white font-medium mb-2">Master</h4>

            <!-- Master Level Meter -->
            <div class="w-4 h-48 bg-black/30 rounded-full mx-auto mb-3 relative overflow-hidden">
              <div
                class={[
                  "absolute bottom-0 w-full transition-all duration-75 rounded-full",
                  @output_level > 0.9 && "bg-red-500" || @output_level > 0.7 && "bg-yellow-500" || "bg-green-500"
                ]}
                style={"height: #{@output_level * 100}%;"}
              ></div>

              <!-- Peak indicator lines -->
              <div class="absolute inset-0">
                <div class="absolute w-full h-px bg-red-500/50" style="top: 10%;"></div>
                <div class="absolute w-full h-px bg-yellow-500/50" style="top: 30%;"></div>
              </div>
            </div>

            <!-- Master Volume -->
            <div class="mb-4">
              <div class="text-white/70 text-sm mb-1"><%= round(@master_volume * 100) %>%</div>
              <input
                type="range"
                min="0"
                max="100"
                value={round(@master_volume * 100)}
                phx-change="set_master_volume"
                phx-target={@myself}
                class="w-full h-2 bg-white/20 rounded-lg appearance-none cursor-pointer slider vertical-slider"
                orient="vertical"
              />
            </div>

            <!-- Master Effects -->
            <div class="space-y-2">
              <%= for effect <- @master_effects do %>
                <div class="bg-white/10 rounded px-2 py-1 text-xs text-white/80">
                  <%= String.capitalize(effect.type) %>
                </div>
              <% end %>

              <!-- Add Effect Button -->
              <button class="w-full py-1 text-xs text-purple-400 hover:text-purple-300 border border-dashed border-purple-500/30 rounded">
                + FX
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
