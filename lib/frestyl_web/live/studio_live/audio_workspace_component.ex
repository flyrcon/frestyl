# lib/frestyl_web/live/studio_live/audio_workspace_component.ex

defmodule FrestylWeb.StudioLive.AudioWorkspaceComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      show_beat_machine: false,
      selected_track: nil,
      zoom_level: 1.0
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-black/20 backdrop-blur-sm">

      <!-- Audio Workspace Header -->
      <div class="flex items-center justify-between p-4 border-b border-white/10 bg-black/30 backdrop-blur-xl">
        <div class="flex items-center gap-4">
          <h2 class="text-white text-xl font-bold flex items-center gap-3">
            <div class="p-2 bg-gradient-to-r from-pink-500 to-purple-600 rounded-xl">
              <svg class="h-6 w-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </div>
            Audio Workspace
          </h2>

          <div class="flex items-center gap-2 text-sm text-purple-300 bg-purple-900/30 px-3 py-1.5 rounded-full border border-purple-500/30">
            <span>Next: Track <%= @workspace_state.audio.track_counter + 1 %></span>
          </div>

          <!-- Recording Status -->
          <%= if @recording_mode do %>
            <div class="flex items-center gap-2 text-red-400 text-sm bg-red-900/30 px-3 py-1.5 rounded-full border border-red-500/30">
              <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
              <span class="font-medium">Recording Mode</span>
            </div>
          <% end %>
        </div>

        <div class="flex items-center space-x-3">

          <!-- Transport Controls -->
          <div class="flex items-center space-x-2 bg-white/10 rounded-2xl p-2">
            <!-- Play/Stop Button -->
            <A11y.a11y_button
              variant="primary"
              size="sm"
              class={[
                "w-10 h-10 rounded-xl transition-all duration-200 border-0",
                if @workspace_state.audio.playing do
                  "bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
                else
                  "bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700"
                end
              ]}
              phx-click="audio_toggle_playback"
              phx-target={@myself}
              aria_label={if @workspace_state.audio.playing, do: "Stop playback", else: "Start playback"}
            >
              <%= if @workspace_state.audio.playing do %>
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
                </svg>
              <% else %>
                <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M8 5v14l11-7z"/>
                </svg>
              <% end %>
            </A11y.a11y_button>

            <!-- Record Button -->
            <%= if can_record_audio?(@permissions) do %>
              <A11y.a11y_button
                variant="primary"
                size="sm"
                class={[
                  "w-10 h-10 rounded-xl border-0 transition-all duration-200",
                  if @recording_mode do
                    "bg-gradient-to-r from-red-500 to-red-600 animate-pulse"
                  else
                    "bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
                  end
                ]}
                phx-click="toggle_recording_mode"
                phx-target={@myself}
                aria_label={if @recording_mode, do: "Exit recording mode", else: "Enter recording mode"}
              >
                <%= if @recording_mode do %>
                  <div class="w-4 h-4 bg-white rounded-sm"></div>
                <% else %>
                  <div class="w-4 h-4 bg-white rounded-full"></div>
                <% end %>
              </A11y.a11y_button>
            <% end %>
          </div>

          <!-- Beat Machine Toggle -->
          <A11y.a11y_button
            variant="outline"
            size="sm"
            class={[
              "px-3 py-2 text-sm font-medium border-white/20 transition-all duration-200",
              if @show_beat_machine do
                "bg-white/20 text-white border-white/40"
              else
                "text-white/70 hover:text-white hover:bg-white/10"
              end
            ]}
            phx-click="toggle_beat_machine"
            phx-target={@myself}
          >
            Beat Machine
          </A11y.a11y_button>

          <!-- Add Track Button -->
          <%= if can_edit_audio?(@permissions) do %>
            <A11y.a11y_button
              variant="primary"
              size="sm"
              class="bg-gradient-to-r from-indigo-500 to-purple-600 hover:from-indigo-600 hover:to-purple-700 border-0 shadow-lg shadow-indigo-500/25 hover:shadow-xl hover:shadow-indigo-500/40 transition-all duration-300 transform hover:scale-110"
              phx-click="audio_add_track"
              phx-target={@myself}
              aria_label="Add track"
            >
              <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" viewBox="0 0 20 20" fill="currentColor">
                <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
              </svg>
              Add Track
            </A11y.a11y_button>
          <% end %>
        </div>
      </div>

      <!-- Beat Machine Panel (Collapsible) -->
      <%= if @show_beat_machine do %>
        <.live_component
          module={FrestylWeb.StudioLive.BeatMachineComponent}
          id="beat-machine"
          beat_machine_state={@beat_machine_state}
          current_user={@current_user}
          permissions={@permissions}
          session={@session}
        />
      <% end %>

      <!-- Main Audio Content -->
      <div class="flex-1 overflow-hidden">
        <%= if @recording_mode do %>
          <!-- Recording Interface -->
          <.live_component
            module={FrestylWeb.StudioLive.RecordingWorkspaceComponent}
            id="recording-workspace"
            workspace_state={@workspace_state}
            current_user={@current_user}
            permissions={@permissions}
            session={@session}
            recording_track={@recording_track}
            audio_engine_state={@audio_engine_state}
          />
        <% else %>
          <!-- Standard Track View -->
          <div class="flex-1 overflow-y-auto p-4">
            <%= if length(@workspace_state.audio.tracks) == 0 do %>
              <!-- Empty State -->
              <div class="h-full flex flex-col items-center justify-center text-white/70">
                <div class="w-24 h-24 mb-8 bg-gradient-to-br from-pink-500/20 to-purple-600/20 rounded-3xl flex items-center justify-center border border-pink-500/20">
                  <svg xmlns="http://www.w3.org/2000/svg" class="h-12 w-12 text-pink-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
                  </svg>
                </div>
                <h3 class="text-2xl font-bold mb-4 text-white">No audio tracks yet</h3>
                <p class="text-white/50 mb-8 text-center max-w-md">Start your audio journey by adding your first track. Collaborate with others in real-time!</p>

                <%= if can_edit_audio?(@permissions) do %>
                  <div class="space-y-4">
                    <A11y.a11y_button
                      variant="primary"
                      size="lg"
                      class="bg-gradient-to-r from-pink-500 to-purple-600 hover:from-pink-600 hover:to-purple-700 border-0 shadow-2xl shadow-pink-500/50 hover:shadow-pink-500/70 transition-all duration-300 transform hover:scale-105 px-8 py-4"
                      phx-click="audio_add_track"
                      phx-target={@myself}
                    >
                      <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                      </svg>
                      Add your first track
                    </A11y.a11y_button>

                    <A11y.a11y_button
                      variant="outline"
                      size="lg"
                      class="border-white/20 text-white/70 hover:text-white hover:bg-white/10 px-8 py-4"
                      phx-click="toggle_recording_mode"
                      phx-target={@myself}
                    >
                      <svg class="w-5 h-5 mr-2" fill="currentColor" viewBox="0 0 24 24">
                        <circle cx="12" cy="12" r="3"/>
                      </svg>
                      Start Recording Session
                    </A11y.a11y_button>
                  </div>
                <% else %>
                  <div class="text-center">
                    <p class="text-white/50 bg-white/5 px-6 py-3 rounded-2xl border border-white/10">
                      You don't have permission to add tracks
                    </p>
                  </div>
                <% end %>
              </div>
            <% else %>
              <!-- Track List -->
              <div id="audio-track" class="space-y-3" phx-hook="AudioTrackManager">
                <%= for {track, index} <- Enum.with_index(@workspace_state.audio.tracks) do %>
                  <.live_component
                    module={FrestylWeb.StudioLive.AudioTrackComponent}
                    id={"track-#{track.id}"}
                    track={track}
                    index={index}
                    selected={@selected_track == track.id}
                    current_user={@current_user}
                    permissions={@permissions}
                    zoom_level={@zoom_level}
                    recording_track={@recording_track}
                  />
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("audio_toggle_playback", _, socket) do
    if socket.assigns.workspace_state.audio.playing do
      send(self(), {:audio_stop_playback})
    else
      send(self(), {:audio_start_playback, 0})
    end
    {:noreply, socket}
  end

  def handle_event("audio_add_track", _, socket) do
    send(self(), :audio_add_track)
    {:noreply, socket}
  end

  def handle_event("toggle_recording_mode", _, socket) do
    send(self(), :toggle_recording_mode)
    {:noreply, socket}
  end

  def handle_event("toggle_beat_machine", _, socket) do
    {:noreply, assign(socket, show_beat_machine: !socket.assigns.show_beat_machine)}
  end

  # Helper functions
  defp can_edit_audio?(permissions), do: :edit_audio in permissions
  defp can_record_audio?(permissions), do: :record_audio in permissions
end
