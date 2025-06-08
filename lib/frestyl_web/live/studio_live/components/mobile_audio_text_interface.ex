# lib/frestyl_web/live/studio_live/components/mobile_audio_text_interface.ex
defmodule FrestylWeb.StudioLive.MobileAudioTextInterface do
  @moduledoc """
  Mobile-optimized interface for audio-text workflows.
  Provides gesture controls, voice activation, and streamlined recording.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Studio.AudioTextSync

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("mobile_gesture", %{"gesture" => gesture, "direction" => direction}, socket) do
    case {gesture, direction} do
      {"swipe", "up"} ->
        # Swipe up to start/stop recording
        if socket.assigns.recording_track do
          send(self(), {:mobile_stop_recording})
        else
          send(self(), {:mobile_start_recording})
        end

      {"swipe", "right"} ->
        # Swipe right to play/pause
        if socket.assigns.sync_state.playing do
          send(self(), {:audio_stop_playback})
        else
          send(self(), {:audio_start_playback, socket.assigns.sync_state.current_position})
        end

      {"swipe", "down"} ->
        # Swipe down to create sync point
        if socket.assigns.sync_state.current_block do
          send(self(), {:create_sync_point_gesture, socket.assigns.sync_state.current_block})
        end

      {"double_tap", _} ->
        # Double tap to toggle teleprompter mode
        send(self(), {:toggle_mobile_teleprompter})

      {"long_press", _} ->
        # Long press to activate voice commands
        send(self(), {:activate_voice_commands})

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("voice_command", %{"command" => command, "text" => text}, socket) do
    case command do
      "add_verse" ->
        block = %{content: text, type: "verse"}
        AudioTextSync.add_text_block(socket.assigns.session_id, block)

      "add_chorus" ->
        block = %{content: text, type: "chorus"}
        AudioTextSync.add_text_block(socket.assigns.session_id, block)

      "sync_now" ->
        if socket.assigns.sync_state.current_block do
          AudioTextSync.sync_text_block(
            socket.assigns.session_id,
            socket.assigns.sync_state.current_block,
            socket.assigns.sync_state.current_position
          )
        end

      "start_recording" ->
        send(self(), {:mobile_start_recording})

      "stop_recording" ->
        send(self(), {:mobile_stop_recording})

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_simplified_mode", _params, socket) do
    current_mode = socket.assigns[:simplified_mode] || false
    send(self(), {:mobile_simplified_mode_toggled, !current_mode})
    {:noreply, assign(socket, :simplified_mode, !current_mode)}
  end

  @impl true
  def handle_event("adjust_mobile_text_size", %{"size" => size}, socket) do
    send(self(), {:mobile_text_size_changed, size})
    {:noreply, assign(socket, :mobile_text_size, size)}
  end

  @impl true
  def handle_event("mobile_block_focus", %{"block_id" => block_id}, socket) do
    send(self(), {:mobile_block_focused, block_id})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mobile-audio-text-interface h-full flex flex-col bg-gray-900 text-white">
      <!-- Mobile Header -->
      <div class="flex items-center justify-between p-3 bg-gray-800 border-b border-gray-700">
        <div class="flex items-center space-x-2">
          <div class={[
            "w-3 h-3 rounded-full",
            @sync_state.playing && "bg-green-500 animate-pulse" || "bg-gray-500"
          ]}></div>

          <span class="text-sm font-medium">
            <%= if @sync_state.mode == "lyrics_with_audio", do: "Lyrics Studio", else: "Script Studio" %>
          </span>
        </div>

        <div class="flex items-center space-x-2">
          <!-- Simplified mode toggle -->
          <button
            phx-click="toggle_simplified_mode"
            phx-target={@myself}
            class={[
              "p-1 rounded text-xs",
              @simplified_mode && "bg-indigo-600" || "bg-gray-700"
            ]}
            title="Toggle simplified mode"
          >
            💡
          </button>

          <!-- Text size adjustment -->
          <select
            phx-change="adjust_mobile_text_size"
            phx-target={@myself}
            class="bg-gray-700 border-gray-600 rounded text-xs text-white"
          >
            <option value="sm">Small</option>
            <option value="base" selected={@mobile_text_size == "base"}>Normal</option>
            <option value="lg" selected={@mobile_text_size == "lg"}>Large</option>
            <option value="xl" selected={@mobile_text_size == "xl"}>X-Large</option>
          </select>
        </div>
      </div>

      <!-- Quick Status Bar -->
      <div class="flex items-center justify-between p-2 bg-gray-800 text-xs">
        <div class="flex items-center space-x-3">
          <span><%= format_time(@sync_state.current_position) %></span>
          <span>•</span>
          <span><%= length(@sync_state.text_blocks) %> blocks</span>
          <span>•</span>
          <span><%= length(@sync_state.sync_points) %> synced</span>
        </div>

        <div class="flex items-center space-x-2">
          <%= if @recording_track do %>
            <div class="flex items-center space-x-1 text-red-400">
              <div class="w-2 h-2 bg-red-400 rounded-full animate-pulse"></div>
              <span>REC</span>
            </div>
          <% end %>

          <%= if @sync_state.beat_detection.enabled do %>
            <span class="text-purple-400"><%= @sync_state.beat_detection.bpm %> BPM</span>
          <% end %>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="flex-1 overflow-hidden" phx-hook="MobileGestures" id="mobile-content-area">
        <%= if @simplified_mode do %>
          <!-- Simplified Mode: Focus on current block only -->
          <.render_simplified_mode
            sync_state={@sync_state}
            current_block={get_current_block(@sync_state)}
            mobile_text_size={@mobile_text_size}
            recording_track={@recording_track}
            myself={@myself}
          />
        <% else %>
          <!-- Full Mode: All blocks with timeline -->
          <.render_full_mode
            sync_state={@sync_state}
            mobile_text_size={@mobile_text_size}
            recording_track={@recording_track}
            myself={@myself}
          />
        <% end %>
      </div>

      <!-- Mobile Control Bar -->
      <div class="p-3 bg-gray-800 border-t border-gray-700">
        <div class="grid grid-cols-4 gap-2">
          <!-- Record Button -->
          <button
            phx-click={if @recording_track, do: "mobile_stop_recording", else: "mobile_start_recording"}
            phx-value-track-index="0"
            class={[
              "flex flex-col items-center p-2 rounded-lg transition-colors",
              @recording_track && "bg-red-600 hover:bg-red-700" || "bg-gray-700 hover:bg-gray-600"
            ]}
          >
            <div class="text-lg"><%= if @recording_track, do: "⏹️", else: "🎤" %></div>
            <span class="text-xs"><%= if @recording_track, do: "Stop", else: "Record" %></span>
          </button>

          <!-- Play/Pause Button -->
          <button
            phx-click={if @sync_state.playing, do: "audio_stop_playback", else: "audio_start_playback"}
            phx-value-position={@sync_state.current_position}
            class="flex flex-col items-center p-2 rounded-lg bg-gray-700 hover:bg-gray-600 transition-colors"
          >
            <div class="text-lg"><%= if @sync_state.playing, do: "⏸️", else: "▶️" %></div>
            <span class="text-xs"><%= if @sync_state.playing, do: "Pause", else: "Play" %></span>
          </button>

          <!-- Sync Button -->
          <button
            phx-click="sync_current_block_mobile"
            phx-target={@myself}
            disabled={!@sync_state.current_block}
            class={[
              "flex flex-col items-center p-2 rounded-lg transition-colors",
              @sync_state.current_block && "bg-indigo-600 hover:bg-indigo-700" || "bg-gray-600 opacity-50"
            ]}
          >
            <div class="text-lg">🎯</div>
            <span class="text-xs">Sync</span>
          </button>

          <!-- Add Block Button -->
          <button
            phx-click="show_mobile_add_block"
            phx-target={@myself}
            class="flex flex-col items-center p-2 rounded-lg bg-green-600 hover:bg-green-700 transition-colors"
          >
            <div class="text-lg">➕</div>
            <span class="text-xs">Add</span>
          </button>
        </div>

        <!-- Voice Commands Hint -->
        <div class="mt-2 text-center">
          <p class="text-xs text-gray-400">
            💡 Long press anywhere for voice commands • Swipe gestures enabled
          </p>
        </div>
      </div>

      <!-- Voice Command Modal (when active) -->
      <%= if @voice_commands_active do %>
        <div class="absolute inset-0 bg-black bg-opacity-75 flex items-center justify-center">
          <div class="bg-gray-800 rounded-lg p-6 text-center">
            <div class="text-4xl mb-3">🎤</div>
            <h3 class="text-white font-medium mb-2">Voice Commands</h3>
            <p class="text-gray-400 text-sm mb-4">Say: "Add verse", "Sync now", "Start recording"</p>
            <div class="flex space-x-2">
              <button
                phx-click="cancel_voice_commands"
                phx-target={@myself}
                class="px-4 py-2 bg-gray-600 hover:bg-gray-700 text-white rounded"
              >
                Cancel
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Simplified mode: Focus on current block with large text
  defp render_simplified_mode(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4">
      <%= if @current_block do %>
        <!-- Current Block Focus -->
        <div class="flex-1 flex flex-col justify-center">
          <div class="text-center mb-4">
            <span class="text-sm text-gray-400 uppercase tracking-wider">
              <%= String.capitalize(@current_block.type || "Block") %>
            </span>
          </div>

          <div class={[
            "text-center leading-relaxed p-6 rounded-lg bg-gray-800",
            case @mobile_text_size do
              "sm" -> "text-lg"
              "base" -> "text-xl"
              "lg" -> "text-2xl"
              "xl" -> "text-3xl"
              _ -> "text-xl"
            end
          ]}>
            <p><%= @current_block.content %></p>
          </div>

          <!-- Progress indicator -->
          <div class="mt-6 text-center">
            <div class="text-sm text-gray-400 mb-2">
              Block <%= get_current_block_index(@sync_state) %> of <%= length(@sync_state.text_blocks) %>
            </div>

            <div class="w-full bg-gray-700 rounded-full h-2">
              <div
                class="bg-indigo-600 h-2 rounded-full transition-all duration-300"
                style={"width: #{get_progress_percentage(@sync_state)}%"}
              ></div>
            </div>
          </div>

          <!-- Sync status -->
          <div class="mt-4 text-center">
            <%= if has_sync_point?(@sync_state.sync_points, @current_block.id) do %>
              <span class="text-green-400 text-sm">✓ Synced</span>
            <% else %>
              <span class="text-yellow-400 text-sm">⚠️ Not synced</span>
            <% end %>
          </div>
        </div>

        <!-- Quick navigation -->
        <div class="flex justify-between items-center mt-4">
          <button
            phx-click="navigate_previous_block"
            phx-target={@myself}
            class="p-3 bg-gray-700 hover:bg-gray-600 rounded-lg"
            disabled={is_first_block?(@sync_state)}
          >
            ← Previous
          </button>

          <span class="text-gray-400 text-sm">
            Swipe ↕️ to navigate
          </span>

          <button
            phx-click="navigate_next_block"
            phx-target={@myself}
            class="p-3 bg-gray-700 hover:bg-gray-600 rounded-lg"
            disabled={is_last_block?(@sync_state)}
          >
            Next →
          </button>
        </div>
      <% else %>
        <!-- No current block -->
        <div class="flex-1 flex items-center justify-center">
          <div class="text-center">
            <div class="text-6xl mb-4">📝</div>
            <h3 class="text-xl font-medium text-white mb-2">Ready to Create</h3>
            <p class="text-gray-400">Add your first block to get started</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Full mode: Timeline view with all blocks
  defp render_full_mode(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Mini Timeline -->
      <div class="h-16 bg-gray-800 border-b border-gray-700 p-2">
        <div class="relative h-full bg-gray-900 rounded overflow-x-auto">
          <!-- Timeline markers -->
          <div class="absolute inset-0">
            <%= for sync_point <- @sync_state.sync_points do %>
              <div
                class="absolute top-0 bottom-0 w-0.5 bg-yellow-400"
                style={"left: #{mobile_position_to_pixels(sync_point.start_time)}px;"}
              ></div>
            <% end %>

            <!-- Current position -->
            <div
              class="absolute top-0 bottom-0 w-0.5 bg-red-500 z-10"
              style={"left: #{mobile_position_to_pixels(@sync_state.current_position)}px;"}
            ></div>
          </div>
        </div>
      </div>

      <!-- Scrollable Block List -->
      <div class="flex-1 overflow-y-auto p-3">
        <div class="space-y-3">
          <%= for block <- @sync_state.text_blocks do %>
            <.render_mobile_block
              block={block}
              is_current={block.id == @sync_state.current_block}
              sync_point={find_sync_point_for_block(@sync_state.sync_points, block.id)}
              mobile_text_size={@mobile_text_size}
              myself={@myself}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Mobile-optimized text block
  defp render_mobile_block(assigns) do
    ~H"""
    <div
      class={[
        "rounded-lg border transition-all duration-300",
        @is_current && "border-indigo-500 bg-indigo-900 bg-opacity-20" || "border-gray-600 bg-gray-800"
      ]}
      phx-click="mobile_block_focus"
      phx-value-block-id={@block.id}
      phx-target={@myself}
    >
      <!-- Block header -->
      <div class="p-3 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <span class={[
            "px-2 py-1 rounded text-xs font-medium",
            case @block.type do
              "verse" -> "bg-blue-600 text-white"
              "chorus" -> "bg-purple-600 text-white"
              "bridge" -> "bg-green-600 text-white"
              _ -> "bg-gray-600 text-white"
            end
          ]}>
            <%= String.capitalize(@block.type || "text") %>
          </span>

          <%= if @sync_point do %>
            <span class="text-xs text-green-400">✓ <%= format_time(@sync_point.start_time) %></span>
          <% else %>
            <span class="text-xs text-gray-400">Not synced</span>
          <% end %>
        </div>
      </div>

      <!-- Block content -->
      <div class="p-3">
        <div class={[
          "text-white leading-relaxed",
          case @mobile_text_size do
            "sm" -> "text-sm"
            "base" -> "text-base"
            "lg" -> "text-lg"
            "xl" -> "text-xl"
            _ -> "text-base"
          end
        ]}>
          <%= @block.content %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_current_block(sync_state) do
    if sync_state.current_block do
      Enum.find(sync_state.text_blocks, &(&1.id == sync_state.current_block))
    end
  end

  defp get_current_block_index(sync_state) do
    if sync_state.current_block do
      case Enum.find_index(sync_state.text_blocks, &(&1.id == sync_state.current_block)) do
        nil -> 0
        index -> index + 1
      end
    else
      0
    end
  end

  defp get_progress_percentage(sync_state) do
    total_blocks = length(sync_state.text_blocks)
    if total_blocks > 0 do
      current_index = get_current_block_index(sync_state)
      round((current_index / total_blocks) * 100)
    else
      0
    end
  end

  defp has_sync_point?(sync_points, block_id) do
    Enum.any?(sync_points, &(&1.block_id == block_id))
  end

  defp find_sync_point_for_block(sync_points, block_id) do
    Enum.find(sync_points, &(&1.block_id == block_id))
  end

  defp is_first_block?(sync_state) do
    get_current_block_index(sync_state) <= 1
  end

  defp is_last_block?(sync_state) do
    get_current_block_index(sync_state) >= length(sync_state.text_blocks)
  end

  defp mobile_position_to_pixels(position_ms) do
    # Simplified mobile timeline - 1 second = 10 pixels
    (position_ms / 1000) * 10
  end

  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"
end
