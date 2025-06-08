# lib/frestyl_web/live/studio_live/components/timeline_component.ex
defmodule FrestylWeb.StudioLive.TimelineComponent do
  @moduledoc """
  Interactive timeline component for audio-text synchronization.
  Shows audio waveform, text blocks, sync points, and playback position.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Studio.AudioTextSync

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("seek_to_position", %{"position" => position}, socket) do
    position_float = String.to_float(position)
    session_id = socket.assigns.session_id

    # Update audio engine position
    Frestyl.Studio.AudioEngine.seek_to_position(session_id, position_float)

    # Update sync engine
    AudioTextSync.update_audio_position(session_id, position_float)

    send(self(), {:timeline_seek, position_float})
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_sync_point", %{"block_id" => block_id, "position" => position}, socket) do
    position_float = String.to_float(position)
    session_id = socket.assigns.session_id

    case AudioTextSync.sync_text_block(session_id, block_id, position_float) do
      {:ok, sync_point} ->
        send(self(), {:sync_point_created, sync_point})
        {:noreply, put_flash(socket, :info, "Text synced to #{format_time(position_float)}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create sync point: #{reason}")}
    end
  end

  @impl true
  def handle_event("delete_sync_point", %{"block_id" => block_id}, socket) do
    session_id = socket.assigns.session_id

    # Remove sync point (you'd implement this in AudioTextSync)
    send(self(), {:sync_point_deleted, block_id})
    {:noreply, put_flash(socket, :info, "Sync point removed")}
  end

  @impl true
  def handle_event("auto_detect_beats", _params, socket) do
    session_id = socket.assigns.session_id

    # Trigger beat detection on current audio
    case get_current_audio_data(session_id) do
      {:ok, audio_data} ->
        case AudioTextSync.detect_beats(session_id, audio_data) do
          {:ok, beat_data} ->
            send(self(), {:beats_detected, beat_data})
            {:noreply, put_flash(socket, :info, "Detected #{length(beat_data.beats)} beats at #{beat_data.bpm} BPM")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Beat detection failed: #{reason}")}
        end

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "No audio data available")}
    end
  end

  @impl true
  def handle_event("auto_align_lyrics", _params, socket) do
    session_id = socket.assigns.session_id
    sync_state = socket.assigns.sync_state

    if sync_state.beat_detection.enabled do
      lyrics = get_current_lyrics_text(sync_state.text_blocks)

      case AudioTextSync.auto_align_lyrics(session_id, lyrics, sync_state.beat_detection) do
        {:ok, aligned_blocks} ->
          send(self(), {:lyrics_auto_aligned, aligned_blocks})
          {:noreply, put_flash(socket, :info, "Lyrics automatically aligned to beats")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Auto-alignment failed: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Beat detection required for auto-alignment")}
    end
  end

  @impl true
  def handle_event("toggle_zoom", %{"zoom_level" => zoom}, socket) do
    zoom_float = String.to_float(zoom)
    send(self(), {:timeline_zoom_changed, zoom_float})
    {:noreply, assign(socket, :zoom_level, zoom_float)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="timeline-component bg-gray-900 border-t border-gray-700" id="audio-text-timeline">
      <!-- Timeline Header -->
      <div class="flex items-center justify-between p-3 bg-gray-800">
        <div class="flex items-center space-x-4">
          <h3 class="text-white font-medium">Timeline</h3>

          <!-- Mode indicator -->
          <span class={[
            "px-2 py-1 rounded text-xs font-medium",
            @sync_state.mode == "lyrics_with_audio" && "bg-purple-600 text-white" || "bg-blue-600 text-white"
          ]}>
            <%= if @sync_state.mode == "lyrics_with_audio", do: "Lyrics Mode", else: "Script Mode" %>
          </span>

          <!-- Current position -->
          <span class="text-gray-300 text-sm font-mono">
            <%= format_time(@sync_state.current_position) %>
          </span>
        </div>

        <div class="flex items-center space-x-2">
          <!-- Auto-alignment tools -->
          <%= if @sync_state.mode == "lyrics_with_audio" do %>
            <button
              phx-click="auto_detect_beats"
              phx-target={@myself}
              class="px-3 py-1 bg-purple-600 hover:bg-purple-700 text-white rounded text-xs"
              title="Detect beats in audio"
            >
              🎵 Detect Beats
            </button>

            <%= if @sync_state.beat_detection.enabled do %>
              <button
                phx-click="auto_align_lyrics"
                phx-target={@myself}
                class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white rounded text-xs"
                title="Auto-align lyrics to detected beats"
              >
                ✨ Auto-Align
              </button>
            <% end %>
          <% end %>

          <!-- Zoom controls -->
          <div class="flex items-center space-x-1">
            <label class="text-gray-400 text-xs">Zoom:</label>
            <input
              type="range"
              min="0.1"
              max="5.0"
              step="0.1"
              value={@zoom_level || 1.0}
              phx-change="toggle_zoom"
              phx-target={@myself}
              class="w-16 h-1"
            />
          </div>
        </div>
      </div>

      <!-- Timeline Canvas -->
      <div class="relative h-32 bg-gray-900 overflow-x-auto" id="timeline-canvas">
        <canvas
          id="timeline-waveform"
          phx-hook="TimelineWaveform"
          data-session-id={@session_id}
          data-zoom-level={@zoom_level || 1.0}
          data-current-position={@sync_state.current_position}
          class="absolute inset-0 w-full h-full cursor-crosshair"
          phx-click="seek_to_position"
          phx-target={@myself}
        >
        </canvas>

        <!-- Sync points overlay -->
        <div class="absolute inset-0 pointer-events-none">
          <%= for sync_point <- @sync_state.sync_points do %>
            <div
              class="absolute top-0 bottom-0 w-0.5 bg-yellow-400 opacity-75"
              style={"left: #{position_to_pixels(sync_point.start_time, @zoom_level || 1.0)}px;"}
              title={"Sync point at #{format_time(sync_point.start_time)}"}
            >
              <div class="absolute -top-1 -left-1 w-2 h-2 bg-yellow-400 rounded-full"></div>
            </div>
          <% end %>
        </div>

        <!-- Beat markers (if detected) -->
        <%= if @sync_state.beat_detection.enabled do %>
          <div class="absolute inset-0 pointer-events-none">
            <%= for beat_time <- @sync_state.beat_detection.beats do %>
              <div
                class="absolute top-0 bottom-0 w-px bg-purple-300 opacity-50"
                style={"left: #{position_to_pixels(beat_time, @zoom_level || 1.0)}px;"}
              >
              </div>
            <% end %>
          </div>
        <% end %>

        <!-- Current position indicator -->
        <div
          class="absolute top-0 bottom-0 w-0.5 bg-red-500 pointer-events-none z-10"
          style={"left: #{position_to_pixels(@sync_state.current_position, @zoom_level || 1.0)}px;"}
        >
          <div class="absolute -top-2 -left-2 w-4 h-4 bg-red-500 rounded-full flex items-center justify-center">
            <div class="w-2 h-2 bg-white rounded-full"></div>
          </div>
        </div>
      </div>

      <!-- Text blocks track -->
      <div class="bg-gray-800 border-t border-gray-700 p-2">
        <div class="flex items-center space-x-2 mb-2">
          <span class="text-gray-400 text-xs">Text Blocks:</span>
          <%= if @sync_state.mode == "lyrics_with_audio" do %>
            <span class="text-purple-400 text-xs">
              BPM: <%= @sync_state.beat_detection.bpm || "—" %>
            </span>
          <% end %>
        </div>

        <div class="relative h-8 bg-gray-900 rounded overflow-x-auto">
          <%= for block <- @sync_state.text_blocks do %>
            <% sync_point = find_sync_point_for_block(@sync_state.sync_points, block.id) %>
            <%= if sync_point do %>
              <div
                class={[
                  "absolute top-1 bottom-1 rounded px-2 text-xs flex items-center cursor-pointer group",
                  block.id == @sync_state.current_block && "bg-indigo-600 text-white" || "bg-gray-700 text-gray-300 hover:bg-gray-600"
                ]}
                style={generate_block_style(sync_point, @zoom_level || 1.0)}
                phx-click="seek_to_position"
                phx-value-position={sync_point.start_time}
                phx-target={@myself}
                title={block.content}
              >
                <span class="truncate"><%= String.slice(block.content, 0, 20) %></span>

                <!-- Delete sync point button -->
                <button
                  phx-click="delete_sync_point"
                  phx-value-block-id={block.id}
                  phx-target={@myself}
                  class="ml-1 opacity-0 group-hover:opacity-100 text-red-400 hover:text-red-300"
                  title="Remove sync point"
                >
                  ×
                </button>
              </div>
            <% else %>
              <!-- Unsynced block -->
              <div
                class="absolute top-1 bottom-1 bg-gray-600 text-gray-400 rounded px-2 text-xs flex items-center opacity-50"
                title={"Unsynced: #{block.content}"}
                style="right: 10px; width: 80px;"
              >
                <span class="truncate"><%= String.slice(block.content, 0, 10) %></span>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Timeline controls -->
      <div class="flex items-center justify-between p-2 bg-gray-800 border-t border-gray-700">
        <div class="flex items-center space-x-2">
          <!-- Playback controls -->
          <button
            phx-click="audio_start_playback"
            phx-value-position={@sync_state.current_position}
            class="p-1 bg-green-600 hover:bg-green-700 text-white rounded"
            title="Play"
          >
            ▶️
          </button>

          <button
            phx-click="audio_stop_playback"
            class="p-1 bg-red-600 hover:bg-red-700 text-white rounded"
            title="Stop"
          >
            ⏹️
          </button>
        </div>

        <div class="flex items-center space-x-2 text-xs text-gray-400">
          <%= if length(@sync_state.sync_points) > 0 do %>
            <span><%= length(@sync_state.sync_points) %> sync points</span>
          <% else %>
            <span>No sync points</span>
          <% end %>

          <%= if @sync_state.beat_detection.enabled do %>
            <span>• <%= length(@sync_state.beat_detection.beats) %> beats detected</span>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp format_time(milliseconds) when is_number(milliseconds) do
    seconds = div(trunc(milliseconds), 1000)
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    ms = rem(trunc(milliseconds), 1000)

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}.#{String.pad_leading(to_string(div(ms, 10)), 2, "0")}"
  end
  defp format_time(_), do: "00:00.00"

  defp position_to_pixels(position_ms, zoom_level) do
    # Convert milliseconds to pixels (base: 1 second = 100 pixels at 1x zoom)
    (position_ms / 1000) * 100 * zoom_level
  end

  defp find_sync_point_for_block(sync_points, block_id) do
    Enum.find(sync_points, &(&1.block_id == block_id))
  end

  defp generate_block_style(sync_point, zoom_level) do
    start_px = position_to_pixels(sync_point.start_time, zoom_level)
    width_px = if sync_point.end_time do
      position_to_pixels(sync_point.end_time - sync_point.start_time, zoom_level)
    else
      80 # Default width for blocks without end time
    end

    "left: #{start_px}px; width: #{max(width_px, 40)}px;"
  end

  defp get_current_audio_data(session_id) do
    # Mock implementation - in production you'd get actual audio data
    # from the audio engine or file storage
    {:ok, <<1, 2, 3, 4>>}  # Mock audio data
  end

  defp get_current_lyrics_text(text_blocks) do
    text_blocks
    |> Enum.map(& &1.content)
    |> Enum.join(" ")
  end
end
