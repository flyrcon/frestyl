# lib/frestyl_web/live/studio_live/mobile_audio_component.ex

defmodule FrestylWeb.StudioLive.MobileAudioComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      current_track_index: 0,
      show_effects: false,
      show_advanced: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    total_tracks = length(assigns.workspace_state.audio.tracks)
    current_track_index = if total_tracks > 0, do: min(socket.assigns.current_track_index, total_tracks - 1), else: 0

    {:ok, assign(socket, assigns)
      |> assign(current_track_index: current_track_index)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="mobile-audio-container"
      class="flex-1 flex flex-col h-full bg-gradient-to-br from-gray-900/80 to-purple-900/80 backdrop-blur-sm"
      phx-hook="MobileAudioHook"
    >
      <%= if length(@workspace_state.audio.tracks) == 0 do %>
        <!-- Empty State -->
        <div class="flex-1 flex items-center justify-center p-8">
          <div class="text-center text-white">
            <div class="w-24 h-24 mx-auto mb-6 bg-gradient-to-br from-pink-500/20 to-purple-600/20 rounded-3xl flex items-center justify-center border border-pink-500/20">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-pink-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </div>
            <h3 class="text-xl font-bold mb-3">No Audio Tracks</h3>
            <p class="text-white/70 mb-6 text-sm leading-relaxed">
              Start creating by adding your first audio track. You can record directly or import audio files.
            </p>
            <%= if can_edit_audio?(@permissions) do %>
              <button
                phx-click="mobile_add_track"
                phx-target={@myself}
                class="inline-flex items-center px-6 py-3 bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 text-white font-semibold rounded-2xl shadow-lg transition-all duration-300 transform hover:scale-105"
              >
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
                Add First Track
              </button>
            <% end %>
          </div>
        </div>
      <% else %>
        <!-- Main Audio Interface -->
        <div class="flex-1 flex flex-col overflow-hidden">

          <!-- Track Info Header -->
          <div class="bg-black/30 backdrop-blur-sm border-b border-white/10 p-4">
            <div class="flex items-center justify-between">
              <!-- Current Track Info -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center space-x-3">
                  <!-- Track Navigation -->
                  <div class="flex items-center space-x-2">
                    <button
                      phx-click="mobile_prev_track"
                      phx-target={@myself}
                      class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
                      disabled={@current_track_index == 0}
                      aria-label="Previous track"
                    >
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M15.41 7.41L14 6l-6 6 6 6 1.41-1.41L10.83 12z"/>
                      </svg>
                    </button>

                    <div class="text-center min-w-[60px]">
                      <div id="track-indicator" class="text-white font-bold text-sm">
                        <%= @current_track_index + 1 %> / <%= length(@workspace_state.audio.tracks) %>
                      </div>
                      <div class="flex justify-center space-x-1 mt-1">
                        <%= for {_track, index} <- Enum.with_index(@workspace_state.audio.tracks) do %>
                          <div class={[
                            "track-dot w-1.5 h-1.5 rounded-full transition-colors",
                            (if index == @current_track_index, do: "bg-pink-400", else: "bg-white/30")
                          ]}></div>
                        <% end %>
                      </div>
                    </div>

                    <button
                      phx-click="mobile_next_track"
                      phx-target={@myself}
                      class="w-8 h-8 rounded-full bg-white/10 hover:bg-white/20 flex items-center justify-center text-white transition-colors"
                      disabled={@current_track_index >= length(@workspace_state.audio.tracks) - 1}
                      aria-label="Next track"
                    >
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/>
                      </svg>
                    </button>
                  </div>

                  <!-- Track Name -->
                  <div class="flex-1 min-w-0">
                    <h3 id="current-track-name" class="text-white font-medium truncate">
                      <%= get_current_track_name(@workspace_state.audio.tracks, @current_track_index) %>
                    </h3>
                  </div>
                </div>
              </div>

              <!-- Track Actions -->
              <div class="flex items-center space-x-2">
                <%= if can_edit_audio?(@permissions) do %>
                  <!-- Mute Button -->
                  <button
                    phx-click="mobile_toggle_mute"
                    phx-target={@myself}
                    class={[
                      "w-8 h-8 rounded-full flex items-center justify-center text-white transition-colors",
                      if get_current_track(@workspace_state.audio.tracks, @current_track_index)[:muted] do
                        "bg-red-500/30 border border-red-500/50"
                      else
                        "bg-white/10 hover:bg-white/20"
                      end
                    ]}
                    aria-label="Toggle mute"
                  >
                    <%= if get_current_track(@workspace_state.audio.tracks, @current_track_index)[:muted] do %>
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/>
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                        <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
                      </svg>
                    <% end %>
                  </button>

                  <!-- Solo Button -->
                  <button
                    phx-click="mobile_toggle_solo"
                    phx-target={@myself}
                    class={[
                      "w-8 h-8 rounded-full flex items-center justify-center text-white transition-colors",
                      if get_current_track(@workspace_state.audio.tracks, @current_track_index)[:solo] do
                        "bg-yellow-500/30 border border-yellow-500/50"
                      else
                        "bg-white/10 hover:bg-white/20"
                      end
                    ]}
                    aria-label="Toggle solo"
                  >
                    <span class="text-xs font-bold">S</span>
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Main Control Area -->
          <div class="flex-1 p-4 space-y-6">

            <!-- Volume Control -->
            <div class="space-y-3">
              <label class="block text-white text-sm font-medium">Volume</label>
              <div class="space-y-2">
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.01"
                  value={get_current_track(@workspace_state.audio.tracks, @current_track_index)[:volume] || 0.8}
                  phx-change="mobile_volume_change"
                  phx-target={@myself}
                  class="mobile-slider w-full h-3 bg-white/20 rounded-lg appearance-none slider-thumb"
                  data-control="volume"
                />
                <div class="flex justify-between text-xs text-white/60">
                  <span>0%</span>
                  <span class="font-medium"><%= round((get_current_track(@workspace_state.audio.tracks, @current_track_index)[:volume] || 0.8) * 100) %>%</span>
                  <span>100%</span>
                </div>
              </div>
            </div>

            <!-- Level Meter -->
            <div class="space-y-2">
              <label class="block text-white text-sm font-medium">Input Level</label>
              <div id="mobile-level-meter" class="h-4 bg-white/20 rounded-lg overflow-hidden">
                <div class="level-fill level-green h-full transition-all duration-100 rounded-lg" style="width: 0%"></div>
              </div>
            </div>

            <!-- Effects Toggle -->
            <%= if @device_info.screen_size != "small" && can_edit_audio?(@permissions) do %>
              <div class="space-y-3">
                <button
                  phx-click="toggle_mobile_effects"
                  phx-target={@myself}
                  class="flex items-center justify-between w-full text-white text-sm font-medium"
                >
                  <span>Audio Effects</span>
                  <svg class={[
                    "w-4 h-4 transition-transform",
                    @show_effects && "rotate-180" || "rotate-0"
                  ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                  </svg>
                </button>

                <%= if @show_effects do %>
                  <div id="mobile-effects" class="grid grid-cols-2 gap-2 mobile-collapsible">
                    <%= for effect <- ["reverb", "eq", "compressor", "delay"] do %>
                      <button
                        phx-click="mobile_toggle_effect"
                        phx-value-effect={effect}
                        phx-target={@myself}
                        data-effect={effect}
                        class="mobile-touch-btn px-3 py-2 bg-white/10 hover:bg-white/20 rounded-lg text-white text-sm font-medium transition-colors"
                      >
                        <%= String.capitalize(effect) %>
                      </button>
                    <% end %>
                  </div>
                <% end %>
              </div>
            <% end %>

            <!-- Quick Actions -->
            <div id="mobile-quick-actions" class="space-y-3">
              <label class="block text-white text-sm font-medium">Quick Actions</label>
              <div class="grid grid-cols-2 gap-3">
                <%= if can_edit_audio?(@permissions) do %>
                  <button
                    id="mute-all-btn"
                    phx-click="mobile_mute_all"
                    phx-target={@myself}
                    class="mobile-touch-btn px-4 py-3 bg-gradient-to-r from-red-500/20 to-red-600/20 border border-red-500/30 rounded-xl text-white text-sm font-medium hover:from-red-500/30 hover:to-red-600/30 transition-all"
                  >
                    <svg class="w-4 h-4 mx-auto mb-1" fill="currentColor" viewBox="0 0 24 24">
                      <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z"/>
                    </svg>
                    Mute All
                  </button>

                  <button
                    id="solo-current-btn"
                    phx-click="mobile_solo_current"
                    phx-target={@myself}
                    class="mobile-touch-btn px-4 py-3 bg-gradient-to-r from-yellow-500/20 to-orange-500/20 border border-yellow-500/30 rounded-xl text-white text-sm font-medium hover:from-yellow-500/30 hover:to-orange-500/30 transition-all"
                  >
                    <span class="block text-lg font-bold mb-1">S</span>
                    Solo Track
                  </button>
                <% end %>
              </div>
            </div>
          </div>

        </div>
      <% end %>

      <!-- Status Indicators -->
      <div class="absolute top-4 right-4 space-y-2">
        <!-- Recording Indicator -->
        <div id="recording-indicator" class="hidden flex items-center space-x-2 bg-red-500/90 backdrop-blur-sm px-3 py-1 rounded-full text-white text-xs font-medium">
          <div class="w-2 h-2 bg-white rounded-full animate-pulse"></div>
          <span>Recording</span>
        </div>

        <!-- Power Save Indicator -->
        <div id="power-save-indicator" class="hidden flex items-center space-x-2 bg-orange-500/90 backdrop-blur-sm px-3 py-1 rounded-full text-white text-xs font-medium">
          <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
            <path d="M15.67 4H14V2h-4v2H8.33C7.6 4 7 4.6 7 5.33v15.33C7 21.4 7.6 22 8.33 22h7.33c.74 0 1.34-.6 1.34-1.33V5.33C17 4.6 16.4 4 15.67 4z"/>
          </svg>
          <span>Power Save</span>
        </div>
      </div>

      <!-- Error Display -->
      <div id="mobile-error" class="hidden absolute bottom-20 left-4 right-4 bg-red-500/90 backdrop-blur-sm p-3 rounded-lg text-white text-sm"></div>
    </div>
    """
  end

  @impl true
  def handle_event("mobile_prev_track", _, socket) do
    new_index = max(0, socket.assigns.current_track_index - 1)
    send(self(), {:mobile_track_changed, new_index})
    {:noreply, assign(socket, current_track_index: new_index)}
  end

  def handle_event("mobile_next_track", _, socket) do
    max_index = length(socket.assigns.workspace_state.audio.tracks) - 1
    new_index = min(max_index, socket.assigns.current_track_index + 1)
    send(self(), {:mobile_track_changed, new_index})
    {:noreply, assign(socket, current_track_index: new_index)}
  end

  def handle_event("mobile_volume_change", %{"value" => volume}, socket) do
    volume_float = String.to_float(volume)
    send(self(), {:mobile_track_volume_change, socket.assigns.current_track_index, volume_float})
    {:noreply, socket}
  end

  def handle_event("mobile_toggle_mute", _, socket) do
    send(self(), {:mobile_toggle_mute, socket.assigns.current_track_index})
    {:noreply, socket}
  end

  def handle_event("mobile_toggle_solo", _, socket) do
    send(self(), {:mobile_toggle_solo, socket.assigns.current_track_index})
    {:noreply, socket}
  end

  def handle_event("mobile_toggle_effect", %{"effect" => effect}, socket) do
    send(self(), {:mobile_toggle_effect, socket.assigns.current_track_index, effect})
    {:noreply, socket}
  end

  def handle_event("mobile_mute_all", _, socket) do
    send(self(), :mobile_mute_all_tracks)
    {:noreply, socket}
  end

  def handle_event("mobile_solo_current", _, socket) do
    send(self(), {:mobile_solo_track, socket.assigns.current_track_index})
    {:noreply, socket}
  end

  def handle_event("mobile_add_track", _, socket) do
    send(self(), :mobile_add_track)
    {:noreply, socket}
  end

  def handle_event("toggle_mobile_effects", _, socket) do
    {:noreply, assign(socket, show_effects: !socket.assigns.show_effects)}
  end

  # Helper functions
  defp get_current_track(tracks, index) when is_list(tracks) and is_integer(index) do
    Enum.at(tracks, index, %{})
  end

  defp get_current_track_name(tracks, index) do
    case get_current_track(tracks, index) do
      %{name: name} when is_binary(name) -> name
      _ -> "Track #{index + 1}"
    end
  end

  defp can_edit_audio?(permissions), do: :edit_audio in permissions
end
