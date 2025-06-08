# lib/frestyl_web/live/studio_live/components/audio_text_editor_component.ex
defmodule FrestylWeb.StudioLive.AudioTextEditorComponent do
  @moduledoc """
  Specialized text editor for lyrics writing and script recording.
  Features real-time sync highlighting, teleprompter mode, and mobile optimization.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Studio.AudioTextSync

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("text_content_changed", %{"content" => content, "block_id" => block_id}, socket) do
    session_id = socket.assigns.session_id

    # Update the text block in sync engine
    AudioTextSync.update_text_block(session_id, block_id, content)

    # Send to parent for workspace state update
    send(self(), {:audio_text_content_changed, block_id, content})

    {:noreply, socket}
  end

  @impl true
  def handle_event("create_new_block", %{"content" => content, "type" => type}, socket) do
    session_id = socket.assigns.session_id

    block = %{
      content: content,
      type: type, # "verse", "chorus", "bridge", "line", etc.
      created_at: DateTime.utc_now()
    }

    case AudioTextSync.add_text_block(session_id, block) do
      {:ok, new_block} ->
        send(self(), {:audio_text_block_added, new_block})
        {:noreply, put_flash(socket, :info, "New #{type} added")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{reason}")}
    end
  end

  @impl true
  def handle_event("sync_current_block", %{"block_id" => block_id}, socket) do
    session_id = socket.assigns.session_id
    current_position = socket.assigns.sync_state.current_position

    case AudioTextSync.sync_text_block(session_id, block_id, current_position) do
      {:ok, sync_point} ->
        send(self(), {:sync_point_created, sync_point})
        {:noreply, put_flash(socket, :info, "Block synced to current position")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Sync failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("toggle_teleprompter", _params, socket) do
    current_mode = socket.assigns[:teleprompter_mode] || false
    send(self(), {:teleprompter_toggled, !current_mode})
    {:noreply, assign(socket, :teleprompter_mode, !current_mode)}
  end

  @impl true
  def handle_event("adjust_teleprompter_speed", %{"speed" => speed}, socket) do
    speed_float = String.to_float(speed)
    send(self(), {:teleprompter_speed_changed, speed_float})
    {:noreply, assign(socket, :teleprompter_speed, speed_float)}
  end

  @impl true
  def handle_event("highlight_word_at_position", %{"position" => position}, socket) do
    position_float = String.to_float(position)
    # Find word at current audio position and highlight it
    send(self(), {:highlight_word_at_position, position_float})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="audio-text-editor h-full flex flex-col" id="audio-text-editor">
      <!-- Editor Header -->
      <div class="flex items-center justify-between p-3 bg-gray-50 border-b">
        <div class="flex items-center space-x-4">
          <h3 class="text-gray-900 font-medium">
            <%= if @sync_state.mode == "lyrics_with_audio", do: "Lyrics Editor", else: "Script Editor" %>
          </h3>

          <!-- Block type selector (for lyrics mode) -->
          <%= if @sync_state.mode == "lyrics_with_audio" do %>
            <select
              id="block-type-selector"
              class="text-sm border-gray-300 rounded focus:border-indigo-500"
            >
              <option value="verse">Verse</option>
              <option value="chorus">Chorus</option>
              <option value="bridge">Bridge</option>
              <option value="outro">Outro</option>
              <option value="freestyle">Freestyle</option>
            </select>
          <% end %>
        </div>

        <div class="flex items-center space-x-2">
          <!-- Teleprompter mode (for script mode) -->
          <%= if @sync_state.mode == "audio_with_script" do %>
            <button
              phx-click="toggle_teleprompter"
              phx-target={@myself}
              class={[
                "px-3 py-1 rounded text-sm font-medium transition-colors",
                @teleprompter_mode && "bg-indigo-600 text-white" || "bg-gray-200 text-gray-700 hover:bg-gray-300"
              ]}
            >
              📺 Teleprompter
            </button>

            <%= if @teleprompter_mode do %>
              <div class="flex items-center space-x-2">
                <label class="text-sm text-gray-600">Speed:</label>
                <input
                  type="range"
                  min="0.5"
                  max="2.0"
                  step="0.1"
                  value={@teleprompter_speed || 1.0}
                  phx-change="adjust_teleprompter_speed"
                  phx-target={@myself}
                  class="w-16"
                />
                <span class="text-sm text-gray-600"><%= @teleprompter_speed || 1.0 %>x</span>
              </div>
            <% end %>
          <% end %>

          <!-- Auto-scroll toggle -->
          <button
            phx-click="toggle_auto_scroll"
            phx-target={@myself}
            class={[
              "px-3 py-1 rounded text-sm",
              @sync_state.text_sync.auto_scroll && "bg-green-100 text-green-700" || "bg-gray-100 text-gray-600"
            ]}
            title="Auto-scroll during playback"
          >
            🔄 Auto-scroll
          </button>
        </div>
      </div>

      <!-- Mobile Recording Panel (when on mobile) -->
      <%= if @is_mobile and @sync_state.mode == "audio_with_script" do %>
        <.render_mobile_recording_panel
          recording_track={@recording_track}
          permissions={@permissions}
          current_user={@current_user}
        />
      <% end %>

      <!-- Editor Content Area -->
      <div class="flex-1 overflow-hidden">
        <%= if @teleprompter_mode do %>
          <!-- Teleprompter Mode -->
          <.render_teleprompter_view
            text_blocks={@sync_state.text_blocks}
            current_block={@sync_state.current_block}
            teleprompter_speed={@teleprompter_speed || 1.0}
            current_position={@sync_state.current_position}
            sync_points={@sync_state.sync_points}
          />
        <% else %>
          <!-- Standard Editor Mode -->
          <.render_standard_editor
            text_blocks={@sync_state.text_blocks}
            current_block={@sync_state.current_block}
            mode={@sync_state.mode}
            sync_points={@sync_state.sync_points}
            current_position={@sync_state.current_position}
            is_mobile={@is_mobile}
            myself={@myself}
          />
        <% end %>
      </div>

      <!-- Editor Footer -->
      <div class="p-3 bg-gray-50 border-t flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <!-- Block count -->
          <span class="text-sm text-gray-600">
            <%= length(@sync_state.text_blocks) %>
            <%= if @sync_state.mode == "lyrics_with_audio", do: "verses/lines", else: "paragraphs" %>
          </span>

          <!-- Sync status -->
          <span class="text-sm text-gray-600">
            <%= length(@sync_state.sync_points) %> synced
          </span>

          <!-- Current block indicator -->
          <%= if @sync_state.current_block do %>
            <span class="text-sm text-indigo-600 font-medium">
              📍 <%= get_block_name(@sync_state.text_blocks, @sync_state.current_block) %>
            </span>
          <% end %>
        </div>

        <div class="flex items-center space-x-2">
          <!-- Quick sync button -->
          <%= if @sync_state.current_block do %>
            <button
              phx-click="sync_current_block"
              phx-value-block-id={@sync_state.current_block}
              phx-target={@myself}
              class="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded text-sm"
              title="Sync current block to audio position"
            >
              🎯 Sync Now
            </button>
          <% end %>

          <!-- Add new block -->
          <button
            phx-click="show_new_block_modal"
            phx-target={@myself}
            class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white rounded text-sm"
          >
            ➕ Add Block
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Render teleprompter view for script recording
  defp render_teleprompter_view(assigns) do
    ~H"""
    <div class="h-full bg-black text-white overflow-hidden" id="teleprompter-view">
      <div
        id="teleprompter-scroll-container"
        class="h-full flex flex-col justify-center text-center px-8"
        phx-hook="TeleprompterScroll"
        data-speed={@teleprompter_speed}
        data-current-position={@current_position}
      >
        <%= for {block, index} <- Enum.with_index(@text_blocks) do %>
          <% sync_point = find_sync_point_for_block(@sync_points, block.id) %>
          <div
            class={[
              "mb-8 transition-all duration-500",
              block.id == @current_block && "text-yellow-300 text-2xl scale-110" || "text-gray-300 text-xl opacity-70"
            ]}
            data-block-id={block.id}
            data-start-time={sync_point && sync_point.start_time}
          >
            <%= case block.type do %>
              <% "paragraph" -> %>
                <p class="leading-relaxed"><%= block.content %></p>
              <% "heading" -> %>
                <h2 class="text-3xl font-bold mb-4"><%= block.content %></h2>
              <% _ -> %>
                <p class="leading-relaxed"><%= block.content %></p>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Teleprompter controls overlay -->
      <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2">
        <div class="flex items-center space-x-4 bg-black bg-opacity-50 rounded-lg px-4 py-2">
          <button
            phx-click="audio_start_playback"
            class="text-green-400 hover:text-green-300"
            title="Start reading"
          >
            ▶️
          </button>

          <button
            phx-click="audio_stop_playback"
            class="text-red-400 hover:text-red-300"
            title="Stop"
          >
            ⏹️
          </button>

          <span class="text-white text-sm">
            <%= format_time(@current_position) %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # Render standard block-based editor
  defp render_standard_editor(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-4" id="standard-editor">
      <!-- Lyrics/Script blocks -->
      <%= if length(@text_blocks) == 0 do %>
        <div class="text-center py-12">
          <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <h3 class="mt-4 text-lg font-medium text-gray-900">
            <%= if @mode == "lyrics_with_audio", do: "Start writing lyrics", else: "Begin your script" %>
          </h3>
          <p class="mt-2 text-gray-500">
            <%= if @mode == "lyrics_with_audio" do %>
              Add verses, choruses, and bridges. Sync them to your beat as you go.
            <% else %>
              Write your script and sync sections to audio for teleprompter recording.
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for block <- @text_blocks do %>
            <.render_text_block
              block={block}
              is_current={block.id == @current_block}
              sync_point={find_sync_point_for_block(@sync_points, block.id)}
              mode={@mode}
              is_mobile={@is_mobile}
              myself={@myself}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Render individual text block
  defp render_text_block(assigns) do
    ~H"""
    <div class={[
      "border rounded-lg p-4 transition-all duration-300",
      @is_current && "border-indigo-500 bg-indigo-50 shadow-md" || "border-gray-200 hover:border-gray-300"
    ]}>
      <!-- Block header -->
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-2">
          <!-- Block type badge -->
          <span class={[
            "px-2 py-1 rounded text-xs font-medium",
            case @block.type do
              "verse" -> "bg-blue-100 text-blue-700"
              "chorus" -> "bg-purple-100 text-purple-700"
              "bridge" -> "bg-green-100 text-green-700"
              "paragraph" -> "bg-gray-100 text-gray-700"
              _ -> "bg-gray-100 text-gray-700"
            end
          ]}>
            <%= String.capitalize(@block.type || "text") %>
          </span>

          <!-- Sync status -->
          <%= if @sync_point do %>
            <span class="text-xs text-green-600 flex items-center">
              ✓ Synced at <%= format_time(@sync_point.start_time) %>
            </span>
          <% else %>
            <span class="text-xs text-gray-400">Not synced</span>
          <% end %>
        </div>

        <div class="flex items-center space-x-1">
          <!-- Sync button -->
          <%= if !@sync_point do %>
            <button
              phx-click="sync_current_block"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="text-indigo-600 hover:text-indigo-700 text-sm"
              title="Sync to current audio position"
            >
              🎯
            </button>
          <% end %>

          <!-- More options -->
          <button class="text-gray-400 hover:text-gray-600 text-sm">⋯</button>
        </div>
      </div>

      <!-- Block content -->
      <div class="relative">
        <%= if @mode == "lyrics_with_audio" do %>
          <!-- Lyrics-specific rendering with line breaks -->
          <textarea
            phx-blur="text_content_changed"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class={[
              "w-full min-h-24 resize-none border-0 focus:ring-0 bg-transparent",
              @is_mobile && "text-lg" || "text-base",
              @is_current && "text-indigo-900" || "text-gray-900"
            ]}
            placeholder="Write your lyrics here..."
          ><%= @block.content %></textarea>
        <% else %>
          <!-- Script-specific rendering -->
          <textarea
            phx-blur="text_content_changed"
            phx-value-block-id={@block.id}
            phx-target={@myself}
            class={[
              "w-full min-h-32 resize-none border-0 focus:ring-0 bg-transparent leading-relaxed",
              @is_mobile && "text-lg" || "text-base",
              @is_current && "text-indigo-900" || "text-gray-900"
            ]}
            placeholder="Write your script content..."
          ><%= @block.content %></textarea>
        <% end %>

        <!-- Word-level highlighting overlay (for precise sync) -->
        <%= if @is_current and @sync_point do %>
          <div class="absolute inset-0 pointer-events-none">
            <!-- Word highlighting would go here -->
          </div>
        <% end %>
      </div>

      <!-- Block footer -->
      <div class="mt-3 flex items-center justify-between text-xs text-gray-500">
        <span>
          <%= word_count(@block.content) %> words
          <%= if @mode == "lyrics_with_audio", do: "• #{line_count(@block.content)} lines" %>
        </span>

        <%= if @block.updated_at do %>
          <span>Updated <%= relative_time(@block.updated_at) %></span>
        <% end %>
      </div>
    </div>
    """
  end

  # Mobile recording panel for script mode
  defp render_mobile_recording_panel(assigns) do
    ~H"""
    <div class="lg:hidden bg-gray-900 text-white p-3 border-b border-gray-700">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <div class={[
            "w-3 h-3 rounded-full",
            @recording_track && "bg-red-500 animate-pulse" || "bg-gray-600"
          ]}></div>

          <span class="text-sm">
            <%= if @recording_track, do: "Recording...", else: "Ready to record" %>
          </span>
        </div>

        <div class="flex items-center space-x-2">
          <%= if @recording_track do %>
            <button
              phx-click="mobile_stop_recording"
              phx-value-track-index="0"
              class="px-3 py-1 bg-red-600 hover:bg-red-700 rounded text-sm"
            >
              ⏹️ Stop
            </button>
          <% else %>
            <button
              phx-click="mobile_start_recording"
              phx-value-track-index="0"
              class="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 rounded text-sm"
            >
              🎤 Record
            </button>
          <% end %>

          <button
            phx-click="audio_start_playback"
            phx-value-position="0"
            class="px-3 py-1 bg-green-600 hover:bg-green-700 rounded text-sm"
          >
            ▶️ Play
          </button>
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

    "#{String.pad_leading(to_string(minutes), 2, "0")}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_time(_), do: "00:00"

  defp find_sync_point_for_block(sync_points, block_id) do
    Enum.find(sync_points, &(&1.block_id == block_id))
  end

  defp get_block_name(text_blocks, current_block_id) do
    case Enum.find(text_blocks, &(&1.id == current_block_id)) do
      nil -> "Unknown"
      block -> "#{String.capitalize(block.type || "Block")} #{String.slice(block.content, 0, 20)}..."
    end
  end

  defp word_count(content) when is_binary(content) do
    content
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end
  defp word_count(_), do: 0

  defp line_count(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> length()
  end
  defp line_count(_), do: 0

  defp relative_time(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "#{diff}s ago"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff -> "#{div(diff, 3600)}h ago"
    end
  end
end
