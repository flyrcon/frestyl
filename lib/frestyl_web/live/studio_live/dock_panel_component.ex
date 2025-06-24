# lib/frestyl_web/live/studio_live/dock_panel_component.ex
defmodule FrestylWeb.StudioLive.DockPanelComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "bg-gray-900 bg-opacity-70 flex border-gray-800",
      dock_classes(@dock_position)
    ]} id={"#{@dock_position}-dock"}>
      <!-- Tool Tabs Header (if multiple tools) -->
      <%= if length(@tools) > 1 do %>
        <div class="flex border-b border-gray-800">
          <%= for tool_id <- @tools do %>
            <button
              phx-click="set_active_dock_tool"
              phx-value-dock={@dock_position}
              phx-value-tool={tool_id}
              class={[
                "flex-1 py-2 px-3 text-center text-sm font-medium transition-colors border-r border-gray-800 last:border-r-0",
                (Map.get(assigns, :active_dock_tool) || List.first(@tools)) == tool_id && "bg-indigo-600 text-white" || "text-gray-400 hover:text-white hover:bg-gray-700"
              ]}
            >
              <div class="flex items-center justify-center space-x-1">
                <.tool_icon icon={get_tool_icon(tool_id)} class="w-4 h-4" />
                <span class="hidden lg:inline"><%= get_tool_name(tool_id) %></span>
              </div>
            </button>
          <% end %>
        </div>
      <% else %>
        <!-- Single tool header -->
        <div class="flex items-center justify-between p-3 border-b border-gray-800">
          <div class="flex items-center space-x-2">
            <.tool_icon icon={get_tool_icon(List.first(@tools))} class="w-4 h-4 text-white" />
            <h3 class="text-white text-sm font-medium"><%= get_tool_name(List.first(@tools)) %></h3>
          </div>
          <button
            phx-click="toggle_dock_visibility"
            phx-value-dock={@dock_position}
            class="text-gray-400 hover:text-white"
            aria-label={"Toggle #{@dock_position} panel"}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
            </svg>
          </button>
        </div>
      <% end %>

      <!-- Tool Content Area -->
      <div class="flex-1 overflow-hidden">
        <%= if length(@tools) > 1 do %>
          <!-- Multi-tool view - show active tool -->
          <div class="h-full">
            <%= render_tool_content(assigns, Map.get(assigns, :active_dock_tool) || List.first(@tools)) %>
          </div>
        <% else %>
          <!-- Single tool view -->
          <%= for tool_id <- @tools do %>
            <div class="h-full">
              <%= render_tool_content(assigns, tool_id) %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # Tool Content Renderers

  defp render_tool_content(assigns, "chat") do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Chat messages area -->
      <div class="flex-1 overflow-y-auto p-3" id="tool-chat-messages" phx-hook="ChatScroll">
        <%= if length(@chat_messages || []) == 0 do %>
          <div class="text-center text-gray-500 text-sm my-8">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <p>No messages yet</p>
            <p class="text-xs text-gray-600 mt-1">Start the conversation!</p>
          </div>
        <% end %>

        <%= for message <- (@chat_messages || []) do %>
          <div class={[
            "flex mb-3 animate-fade-in",
            message.user_id == @current_user.id && "justify-end" || "justify-start"
          ]}>
            <%= if message.user_id != @current_user.id do %>
              <div class="flex-shrink-0 mr-2">
                <%= if message.avatar_url do %>
                  <img src={message.avatar_url} alt={message.username} class="h-6 w-6 rounded-full" />
                <% else %>
                  <div class="h-6 w-6 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-xs">
                    <%= String.at(message.username || "?", 0) %>
                  </div>
                <% end %>
              </div>
            <% end %>

            <div class={[
              "rounded-lg px-3 py-2 max-w-xs",
              message.user_id == @current_user.id && "bg-indigo-500 text-white" || "bg-gray-700 text-white"
            ]}>
              <%= if message.user_id != @current_user.id do %>
                <p class="text-xs font-medium text-gray-300 mb-1"><%= message.username %></p>
              <% end %>
              <p class="text-sm"><%= message.content %></p>
              <p class="text-xs mt-1 opacity-70">
                <%= if message.inserted_at do %>
                  <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                <% end %>
              </p>
            </div>
          </div>
        <% end %>

        <!-- Typing indicators -->
        <%= if MapSet.size(@typing_users || MapSet.new()) > 0 do %>
          <div class="flex items-center space-x-2 text-gray-400 text-sm mb-2">
            <div class="flex space-x-1">
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
              <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
            </div>
            <span>Someone is typing...</span>
          </div>
        <% end %>
      </div>

      <!-- Chat input area -->
      <div class="p-3 border-t border-gray-700">
        <form phx-submit="send_session_message" phx-target={@myself} class="flex space-x-2">
          <input
            type="text"
            name="message"
            value={@message_input || ""}
            phx-keyup="update_message_input"
            phx-focus="typing_start"
            phx-blur="typing_stop"
            phx-target={@myself}
            placeholder="Type a message..."
            class="flex-1 bg-gray-700 border-gray-600 rounded-lg px-3 py-2 text-white text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            autocomplete="off"
          />
          <button
            type="submit"
            class="bg-indigo-500 hover:bg-indigo-600 text-white rounded-lg px-3 py-2 transition-colors"
            disabled={String.trim(@message_input || "") == ""}
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
            </svg>
          </button>
        </form>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, "mixer") do
    tracks = get_in(assigns, [:workspace_state, :audio, :tracks]) || []

    ~H"""
    <div class="h-full flex flex-col">
      <!-- Mixer header -->
      <div class="p-3 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <h4 class="text-white font-medium">Audio Mixer</h4>
          <div class="flex items-center space-x-2">
            <button
              phx-click="audio_add_track"
              phx-target={@myself}
              class="text-xs bg-indigo-600 hover:bg-indigo-700 text-white px-2 py-1 rounded"
            >
              + Track
            </button>
          </div>
        </div>
      </div>

      <!-- Master controls -->
      <div class="p-3 border-b border-gray-700 bg-gray-800 bg-opacity-50">
        <div class="text-xs text-gray-400 mb-2">Master</div>
        <div class="flex items-center space-x-3">
          <div class="flex-1">
            <input
              type="range"
              min="0"
              max="1"
              step="0.01"
              value={get_in(assigns, [:workspace_state, :master_settings, :volume]) || 0.8}
              phx-change="audio_master_volume_change"
              phx-target={@myself}
              class="w-full"
            />
            <div class="text-xs text-gray-400 text-center mt-1">Volume</div>
          </div>
          <div class="w-8 h-8 bg-green-500 rounded opacity-75"></div>
        </div>
      </div>

      <!-- Track list -->
      <div class="flex-1 overflow-y-auto">
        <%= if length(tracks) == 0 do %>
          <div class="text-center py-8">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
            </svg>
            <p class="text-gray-500 text-sm">No tracks yet</p>
            <button
              phx-click="audio_add_track"
              phx-target={@myself}
              class="mt-2 text-indigo-400 hover:text-indigo-300 text-sm"
            >
              Add your first track
            </button>
          </div>
        <% else %>
          <div class="p-3 space-y-3">
            <%= for track <- tracks do %>
              <div class="bg-gray-800 rounded-lg p-3 border border-gray-700">
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center space-x-2">
                    <span class="text-white font-medium text-sm"><%= track.name || "Untitled Track" %></span>
                    <%= if Map.get(track, :recording, false) do %>
                      <div class="w-2 h-2 bg-red-500 rounded-full animate-pulse"></div>
                    <% end %>
                  </div>
                  <div class="flex items-center space-x-1">
                    <button
                      phx-click="audio_delete_track"
                      phx-value-track-id={track.id}
                      phx-target={@myself}
                      class="text-gray-400 hover:text-red-400 p-1"
                      title="Delete track"
                    >
                      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                    </button>
                  </div>
                </div>

                <!-- Volume fader -->
                <div class="mb-3">
                  <div class="flex justify-between items-center mb-1">
                    <label class="text-xs text-gray-400">Volume</label>
                    <span class="text-xs text-gray-300"><%= round((track.volume || 0.8) * 100) %>%</span>
                  </div>
                  <input
                    type="range"
                    min="0"
                    max="1"
                    step="0.01"
                    value={track.volume || 0.8}
                    phx-change="audio_update_track_volume"
                    phx-value-track-id={track.id}
                    phx-target={@myself}
                    class="w-full"
                  />
                </div>

                <!-- Pan control -->
                <div class="mb-3">
                  <div class="flex justify-between items-center mb-1">
                    <label class="text-xs text-gray-400">Pan</label>
                    <span class="text-xs text-gray-300">
                      <%= cond do %>
                        <% (track.pan || 0) < -0.1 -> %>L<%= abs(round((track.pan || 0) * 100)) %>
                        <% (track.pan || 0) > 0.1 -> %>R<%= round((track.pan || 0) * 100) %>
                        <% true -> %>Center
                      <% end %>
                    </span>
                  </div>
                  <input
                    type="range"
                    min="-1"
                    max="1"
                    step="0.01"
                    value={track.pan || 0}
                    phx-change="audio_update_track_pan"
                    phx-value-track-id={track.id}
                    phx-target={@myself}
                    class="w-full"
                  />
                </div>

                <!-- Mute/Solo buttons -->
                <div class="flex space-x-2">
                  <button
                    phx-click="audio_toggle_track_mute"
                    phx-value-track-id={track.id}
                    phx-target={@myself}
                    class={[
                      "flex-1 py-1 px-2 rounded text-xs font-medium transition-colors",
                      Map.get(track, :muted, false) && "bg-red-600 text-white" || "bg-gray-700 text-gray-300 hover:bg-gray-600"
                    ]}
                  >
                    <%= if Map.get(track, :muted, false), do: "Unmute", else: "Mute" %>
                  </button>

                  <button
                    phx-click="audio_toggle_track_solo"
                    phx-value-track-id={track.id}
                    phx-target={@myself}
                    class={[
                      "flex-1 py-1 px-2 rounded text-xs font-medium transition-colors",
                      Map.get(track, :solo, false) && "bg-yellow-600 text-white" || "bg-gray-700 text-gray-300 hover:bg-gray-600"
                    ]}
                  >
                    <%= if Map.get(track, :solo, false), do: "Unsolo", else: "Solo" %>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, "recorder") do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Recorder header -->
      <div class="p-3 border-b border-gray-700">
        <h4 class="text-white font-medium">Audio Recorder</h4>
      </div>

      <!-- Recording status -->
      <div class="p-3 border-b border-gray-700">
        <%= if Map.get(assigns, :recording_track) do %>
          <div class="flex items-center space-x-3 text-red-400">
            <div class="w-3 h-3 bg-red-500 rounded-full animate-pulse"></div>
            <div>
              <p class="font-medium">Recording</p>
              <p class="text-sm text-gray-400">Track: <%= Map.get(assigns, :recording_track) %></p>
            </div>
          </div>
        <% else %>
          <div class="flex items-center space-x-3 text-gray-400">
            <div class="w-3 h-3 bg-gray-500 rounded-full"></div>
            <div>
              <p class="font-medium">Ready to Record</p>
              <p class="text-sm">Select a track to start</p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Input monitoring -->
      <div class="p-3 border-b border-gray-700">
        <div class="mb-2">
          <label class="text-xs text-gray-400">Input Level</label>
        </div>
        <div class="w-full bg-gray-800 rounded-full h-4 overflow-hidden">
          <div
            class="h-full bg-gradient-to-r from-green-500 via-yellow-500 to-red-500 transition-all duration-150"
            style="width: 45%"
            id="input-level-meter"
          ></div>
        </div>
        <div class="flex justify-between text-xs text-gray-500 mt-1">
          <span>-60dB</span>
          <span>-12dB</span>
          <span>0dB</span>
        </div>
      </div>

      <!-- Track selection and controls -->
      <div class="flex-1 p-3 space-y-4">
        <!-- Track selector -->
        <div>
          <label class="block text-xs text-gray-400 mb-2">Record to Track</label>
          <select
            phx-change="select_recording_track"
            phx-target={@myself}
            class="w-full bg-gray-700 border-gray-600 rounded text-white text-sm"
          >
            <option value="">Select track...</option>
            <%= for track <- (get_in(assigns, [:workspace_state, :audio, :tracks]) || []) do %>
              <option value={track.id} selected={@recording_track == track.id}>
                <%= track.name || "Untitled Track" %>
              </option>
            <% end %>
          </select>
        </div>

        <!-- Recording controls -->
        <div class="space-y-3">
          <%= if Map.get(assigns, :recording_track) do %>
            <button
              phx-click="audio_stop_recording"
              phx-target={@myself}
              class="w-full bg-red-600 hover:bg-red-700 text-white py-3 rounded-lg font-medium transition-colors"
            >
              <div class="flex items-center justify-center space-x-2">
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <rect x="6" y="6" width="12" height="12" />
                </svg>
                <span>Stop Recording</span>
              </div>
            </button>
          <% else %>
            <button
              phx-click="audio_start_recording"
              phx-target={@myself}
              class="w-full bg-indigo-600 hover:bg-indigo-700 text-white py-3 rounded-lg font-medium transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
              disabled={length(get_in(assigns, [:workspace_state, :audio, :tracks]) || []) == 0}
            >
              <div class="flex items-center justify-center space-x-2">
                <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 24 24">
                  <circle cx="12" cy="12" r="8" />
                </svg>
                <span>Start Recording</span>
              </div>
            </button>
          <% end %>
        </div>

        <!-- Recording settings -->
        <div class="space-y-3 pt-3 border-t border-gray-700">
          <div>
            <label class="block text-xs text-gray-400 mb-2">Input Gain</label>
            <input
              type="range"
              min="0"
              max="2"
              step="0.1"
              value="1"
              class="w-full"
            />
          </div>

          <div class="flex items-center justify-between">
            <label class="text-xs text-gray-400">Monitor Input</label>
            <input
              type="checkbox"
              class="rounded border-gray-600 text-indigo-600 focus:ring-indigo-500"
              checked
            />
          </div>

          <div class="flex items-center justify-between">
            <label class="text-xs text-gray-400">Auto-punch</label>
            <input
              type="checkbox"
              class="rounded border-gray-600 text-indigo-600 focus:ring-indigo-500"
            />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, "effects") do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Effects header -->
      <div class="p-3 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <h4 class="text-white font-medium">Effects Rack</h4>
          <button class="text-xs text-gray-400 hover:text-white">
            Presets
          </button>
        </div>
      </div>

      <!-- Track selector -->
      <div class="p-3 border-b border-gray-700">
        <label class="block text-xs text-gray-400 mb-2">Apply to Track</label>
        <select class="w-full bg-gray-700 border-gray-600 rounded text-white text-sm">
          <option>Master Bus</option>
          <%= for track <- (get_in(assigns, [:workspace_state, :audio, :tracks]) || []) do %>
            <option value={track.id}><%= track.name || "Untitled Track" %></option>
          <% end %>
        </select>
      </div>

      <!-- Effects categories -->
      <div class="flex-1 overflow-y-auto p-3 space-y-4">
        <!-- EQ Section -->
        <div class="bg-gray-800 rounded-lg p-3">
          <div class="flex items-center justify-between mb-3">
            <h5 class="text-white font-medium text-sm">Equalizer</h5>
            <button class="text-xs text-indigo-400 hover:text-indigo-300">
              Reset
            </button>
          </div>
          <div class="space-y-3">
            <%= for {band, label} <- [{"low", "Low"}, {"mid", "Mid"}, {"high", "High"}] do %>
              <div>
                <div class="flex justify-between items-center mb-1">
                  <label class="text-xs text-gray-400"><%= label %></label>
                  <span class="text-xs text-gray-300">0dB</span>
                </div>
                <input
                  type="range"
                  min="-12"
                  max="12"
                  step="0.1"
                  value="0"
                  phx-change="audio_effect_parameter_update"
                  phx-value-effect-type="eq"
                  phx-value-parameter={band}
                  phx-target={@myself}
                  class="w-full"
                />
              </div>
            <% end %>
          </div>
        </div>

        <!-- Reverb Section -->
        <div class="bg-gray-800 rounded-lg p-3">
          <div class="flex items-center justify-between mb-3">
            <h5 class="text-white font-medium text-sm">Reverb</h5>
            <button class="text-xs text-indigo-400 hover:text-indigo-300">
              Bypass
            </button>
          </div>
          <div class="space-y-3">
            <div>
              <div class="flex justify-between items-center mb-1">
                <label class="text-xs text-gray-400">Room Size</label>
                <span class="text-xs text-gray-300">30%</span>
              </div>
              <input
                type="range"
                min="0"
                max="1"
                step="0.01"
                value="0.3"
                phx-change="audio_effect_parameter_update"
                phx-value-effect-type="reverb"
                phx-value-parameter="room_size"
                phx-target={@myself}
                class="w-full"
              />
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <label class="text-xs text-gray-400">Wet/Dry</label>
                <span class="text-xs text-gray-300">20%</span>
              </div>
              <input
                type="range"
                min="0"
                max="1"
                step="0.01"
                value="0.2"
                phx-change="audio_effect_parameter_update"
                phx-value-effect-type="reverb"
                phx-value-parameter="wet"
                phx-target={@myself}
                class="w-full"
              />
            </div>
          </div>
        </div>

        <!-- Compressor Section -->
        <div class="bg-gray-800 rounded-lg p-3">
          <div class="flex items-center justify-between mb-3">
            <h5 class="text-white font-medium text-sm">Compressor</h5>
            <button class="text-xs text-indigo-400 hover:text-indigo-300">
              Bypass
            </button>
          </div>
          <div class="space-y-3">
            <div>
              <div class="flex justify-between items-center mb-1">
                <label class="text-xs text-gray-400">Threshold</label>
                <span class="text-xs text-gray-300">-12dB</span>
              </div>
              <input
                type="range"
                min="-40"
                max="0"
                step="0.1"
                value="-12"
                class="w-full"
              />
            </div>
            <div>
              <div class="flex justify-between items-center mb-1">
                <label class="text-xs text-gray-400">Ratio</label>
                <span class="text-xs text-gray-300">4:1</span>
              </div>
              <input
                type="range"
                min="1"
                max="20"
                step="0.1"
                value="4"
                class="w-full"
              />
            </div>
          </div>
        </div>

        <!-- Quick Effect Buttons -->
        <div class="space-y-2">
          <div class="text-xs text-gray-400 mb-2">Quick Add</div>
          <div class="grid grid-cols-2 gap-2">
            <%= for {effect, label, color} <- [
              {"delay", "Delay", "blue"},
              {"distortion", "Distortion", "red"},
              {"chorus", "Chorus", "purple"},
              {"flanger", "Flanger", "green"}
            ] do %>
              <button
                phx-click="audio_add_effect"
                phx-value-effect-type={effect}
                phx-target={@myself}
                class={"text-xs py-2 px-3 rounded font-medium transition-colors bg-#{color}-600 hover:bg-#{color}-700 text-white"}
              >
                <%= label %>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, "editor") do
    ~H"""
    <div class="h-full flex flex-col bg-white">
      <!-- Editor header -->
      <div class="p-3 border-b border-gray-200 bg-gray-50">
        <div class="flex items-center justify-between">
          <h4 class="text-gray-900 font-medium">Text Editor</h4>
          <div class="flex items-center space-x-2">
            <button class="text-xs text-gray-600 hover:text-gray-900">
              Format
            </button>
            <button class="text-xs text-gray-600 hover:text-gray-900">
              Save
            </button>
          </div>
        </div>
      </div>

      <!-- Document type selector -->
      <div class="p-3 border-b border-gray-200">
        <label class="block text-xs text-gray-600 mb-2">Document Type</label>
        <select class="w-full border border-gray-300 rounded text-gray-900 text-sm">
          <option>Plain Text</option>
          <option>Song Lyrics</option>
          <option>Script/Dialogue</option>
          <option>Article/Blog</option>
          <option>Book Chapter</option>
        </select>
      </div>

      <!-- Formatting toolbar -->
      <div class="p-2 border-b border-gray-200 bg-gray-50">
        <div class="flex items-center space-x-1">
          <button class="p-1 hover:bg-gray-200 rounded" title="Bold">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 4h8a4 4 0 014 4 4 4 0 01-4 4H6z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 12h9" />
            </svg>
          </button>
          <button class="p-1 hover:bg-gray-200 rounded" title="Italic">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 4l-2 14m-4-6h8" />
            </svg>
          </button>
          <div class="w-px h-4 bg-gray-300"></div>
          <button class="p-1 hover:bg-gray-200 rounded" title="Bullet List">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <button class="p-1 hover:bg-gray-200 rounded" title="Link">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
            </svg>
          </button>
        </div>
      </div>

      <!-- Text editor area -->
      <div class="flex-1 relative">
        <textarea
          class="w-full h-full p-3 border-0 resize-none focus:outline-none text-gray-900 text-sm leading-relaxed"
          placeholder="Start writing your content here..."
          phx-blur="text_update"
          phx-keyup="text_update"
          phx-target={@myself}
        ><%= get_in(assigns, [:workspace_state, :text, :content]) || "" %></textarea>

        <!-- Collaboration cursors would be rendered here -->
        <div class="absolute inset-0 pointer-events-none">
          <!-- Remote user cursors -->
          <%= for {user_id, cursor_data} <- (get_in(assigns, [:workspace_state, :text, :cursors]) || %{}) do %>
            <%= if user_id != to_string(@current_user.id) do %>
              <div
                class="absolute w-0.5 h-5 bg-red-500 opacity-75"
                style={"top: #{cursor_data.line * 20 + 12}px; left: #{cursor_data.col * 8 + 12}px;"}
              >
                <div class="absolute -top-5 left-0 bg-red-500 text-white text-xs px-1 rounded whitespace-nowrap">
                  <%= get_username_for_user_id(user_id, assigns) %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Editor status bar -->
      <div class="p-2 border-t border-gray-200 bg-gray-50 text-xs text-gray-600 flex justify-between">
        <div class="flex items-center space-x-4">
          <span>
            <%= String.length(get_in(assigns, [:workspace_state, :text, :content]) || "") %> characters
          </span>
          <span>
            <%= (get_in(assigns, [:workspace_state, :text, :content]) || "") |> String.split() |> length() %> words
          </span>
        </div>
        <div class="flex items-center space-x-2">
          <%= if MapSet.size(assigns[:typing_users] || MapSet.new()) > 0 do %>
            <span class="text-blue-600">
              <%= MapSet.size(assigns[:typing_users]) %> user(s) typing
            </span>
          <% end %>
          <span class="text-green-600">Auto-saved</span>
        </div>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, "beat_machine") do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Beat machine header -->
      <div class="p-3 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <h4 class="text-white font-medium">Beat Machine</h4>
          <div class="flex items-center space-x-2">
            <button class="text-xs bg-green-600 hover:bg-green-700 text-white px-2 py-1 rounded">
              Play
            </button>
            <button class="text-xs bg-red-600 hover:bg-red-700 text-white px-2 py-1 rounded">
              Stop
            </button>
          </div>
        </div>
      </div>

      <!-- Transport and settings -->
      <div class="p-3 border-b border-gray-700 space-y-3">
        <div class="flex items-center space-x-4">
          <div class="flex-1">
            <label class="block text-xs text-gray-400 mb-1">BPM</label>
            <input
              type="number"
              min="60"
              max="200"
              value="120"
              class="w-full bg-gray-700 border-gray-600 rounded text-white text-sm"
              phx-change="beat_set_bpm"
              phx-target={@myself}
            />
          </div>
          <div class="flex-1">
            <label class="block text-xs text-gray-400 mb-1">Kit</label>
            <select class="w-full bg-gray-700 border-gray-600 rounded text-white text-sm">
              <option>Classic 808</option>
              <option>Hip Hop</option>
              <option>Rock</option>
              <option>Electronic</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Pattern grid -->
      <div class="flex-1 overflow-y-auto p-3">
        <div class="space-y-2">
          <%= for {instrument, label} <- [
            {"kick", "Kick"},
            {"snare", "Snare"},
            {"hihat", "Hi-Hat"},
            {"openhat", "Open Hat"},
            {"crash", "Crash"},
            {"clap", "Clap"}
          ] do %>
            <div class="flex items-center space-x-2">
              <div class="w-16 text-xs text-gray-400 font-medium">
                <%= label %>
              </div>
              <div class="flex space-x-1">
                <%= for step <- 1..16 do %>
                  <button
                    phx-click="beat_toggle_step"
                    phx-value-instrument={instrument}
                    phx-value-step={step}
                    phx-target={@myself}
                    class={[
                      "w-6 h-6 rounded border transition-colors",
                      rem(step - 1, 4) == 0 && "border-yellow-500" || "border-gray-600",
                      "bg-gray-700 hover:bg-gray-600"
                    ]}
                    title={"#{label} step #{step}"}
                  >
                    <span class="sr-only">Toggle <%= label %> step <%= step %></span>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Pattern controls -->
        <div class="mt-6 pt-4 border-t border-gray-700">
          <div class="text-xs text-gray-400 mb-2">Pattern Controls</div>
          <div class="grid grid-cols-2 gap-2">
            <button class="text-xs py-2 px-3 bg-gray-700 hover:bg-gray-600 text-white rounded">
              Clear All
            </button>
            <button class="text-xs py-2 px-3 bg-gray-700 hover:bg-gray-600 text-white rounded">
              Randomize
            </button>
            <button class="text-xs py-2 px-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded">
              Save Pattern
            </button>
            <button class="text-xs py-2 px-3 bg-gray-700 hover:bg-gray-600 text-white rounded">
              Load Pattern
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_tool_content(assigns, _tool_id) do
    ~H"""
    <div class="h-full flex items-center justify-center">
      <div class="text-center">
        <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
        </svg>
        <p class="text-gray-400">Tool panel coming soon</p>
        <p class="text-xs text-gray-500 mt-1">This tool is not yet implemented</p>
      </div>
    </div>
    """
  end

  # Event Handlers

  @impl true
  def handle_event("send_session_message", %{"message" => message}, socket) when message != "" do
    send(self(), {:send_session_message, message})
    {:noreply, assign(socket, :message_input, "")}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    send(self(), {:update_message_input, value})
    {:noreply, assign(socket, :message_input, value)}
  end

  @impl true
  def handle_event("typing_start", _, socket) do
    send(self(), :typing_start)
    {:noreply, socket}
  end

  @impl true
  def handle_event("typing_stop", _, socket) do
    send(self(), :typing_stop)
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_add_track", _, socket) do
    send(self(), :audio_add_track)
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_delete_track", %{"track-id" => track_id}, socket) do
    send(self(), {:audio_delete_track, track_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_update_track_volume", %{"track-id" => track_id, "value" => volume}, socket) do
    send(self(), {:audio_update_track_volume, track_id, String.to_float(volume)})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_update_track_pan", %{"track-id" => track_id, "value" => pan}, socket) do
    send(self(), {:audio_update_track_pan, track_id, String.to_float(pan)})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_toggle_track_mute", %{"track-id" => track_id}, socket) do
    send(self(), {:audio_toggle_track_mute, track_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_toggle_track_solo", %{"track-id" => track_id}, socket) do
    send(self(), {:audio_toggle_track_solo, track_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_start_recording", _, socket) do
    send(self(), :audio_start_recording)
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_stop_recording", _, socket) do
    send(self(), :audio_stop_recording)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_recording_track", %{"value" => track_id}, socket) do
    send(self(), {:select_recording_track, track_id})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_effect_parameter_update", params, socket) do
    send(self(), {:audio_effect_parameter_update, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("audio_add_effect", %{"effect-type" => effect_type}, socket) do
    send(self(), {:audio_add_effect, effect_type})
    {:noreply, socket}
  end

  @impl true
  def handle_event("text_update", %{"value" => content}, socket) do
    send(self(), {:text_update, content})
    {:noreply, socket}
  end

  @impl true
  def handle_event("beat_set_bpm", %{"value" => bpm}, socket) do
    send(self(), {:beat_set_bpm, String.to_integer(bpm)})
    {:noreply, socket}
  end

  @impl true
  def handle_event("beat_toggle_step", %{"instrument" => instrument, "step" => step}, socket) do
    send(self(), {:beat_toggle_step, instrument, String.to_integer(step)})
    {:noreply, socket}
  end

  # Helper Functions

  defp dock_classes("left"), do: "w-80 flex-col border-r"
  defp dock_classes("right"), do: "w-80 flex-col border-l"
  defp dock_classes("bottom"), do: "h-48 border-t"

  defp get_tool_icon("chat"), do: "chat-bubble-left-ellipsis"
  defp get_tool_icon("mixer"), do: "adjustments-horizontal"
  defp get_tool_icon("recorder"), do: "microphone"
  defp get_tool_icon("effects"), do: "sparkles"
  defp get_tool_icon("editor"), do: "document-text"
  defp get_tool_icon("beat_machine"), do: "musical-note"
  defp get_tool_icon(_), do: "squares-2x2"

  defp get_tool_name("chat"), do: "Chat"
  defp get_tool_name("mixer"), do: "Mixer"
  defp get_tool_name("recorder"), do: "Recorder"
  defp get_tool_name("effects"), do: "Effects"
  defp get_tool_name("editor"), do: "Editor"
  defp get_tool_name("beat_machine"), do: "Beats"
  defp get_tool_name(tool_id), do: String.capitalize(tool_id)

  defp get_username_for_user_id(user_id, assigns) do
    collaborators = assigns[:collaborators] || []
    case Enum.find(collaborators, &(to_string(&1.user_id) == user_id)) do
      %{username: username} -> username
      _ -> "User #{user_id}"
    end
  end

  defp tool_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% "chat-bubble-left-ellipsis" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
      <% "adjustments-horizontal" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
        </svg>
      <% "microphone" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
        </svg>
      <% "sparkles" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
        </svg>
      <% "document-text" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      <% "musical-note" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
        </svg>
      <% _ -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
    <% end %>
    """
  end
end
