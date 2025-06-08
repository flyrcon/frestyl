# lib/frestyl_web/live/studio_live/components/mobile_interface_component.ex
defmodule FrestylWeb.StudioLive.Components.MobileInterfaceComponent do
  use FrestylWeb, :live_component

  @moduledoc """
  Mobile-specific interface components for the Studio LiveView.

  This component provides:
  - Mobile tool drawer and modal rendering
  - Touch gesture interfaces and controls
  - Mobile-optimized UI components
  - Simplified mobile tool controls
  - Integration with MobileEventHandler
  - Responsive mobile layouts
  """

  @impl true
  def render(assigns) do
    ~H"""
    <div class="lg:hidden" id="mobile-interface">
      <!-- Mobile Tool Trigger Button (Floating) -->
      <button
        phx-click="toggle_mobile_drawer"
        phx-target={@myself}
        class={[
          "fixed bottom-6 right-6 z-40 w-14 h-14 rounded-full shadow-lg flex items-center justify-center transition-all duration-300",
          @mobile_tool_drawer_open && "bg-gray-600 rotate-45" || "bg-indigo-600 hover:bg-indigo-700"
        ]}
        aria-label="Toggle collaboration tools"
      >
        <%= if @mobile_tool_drawer_open do %>
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        <% else %>
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
          </svg>
        <% end %>
      </button>

      <!-- Mobile Tool Bottom Sheet -->
      <div
        class={[
          "fixed inset-x-0 bottom-0 z-30 transform transition-transform duration-300 ease-out",
          @mobile_tool_drawer_open && "translate-y-0" || "translate-y-full"
        ]}
        id="mobile-tool-bottom-sheet"
        phx-hook="MobileGestures"
      >
        <.render_mobile_tool_drawer
          mobile_layout={@mobile_layout}
          available_tools={@available_tools}
          mobile_active_tool={@mobile_active_tool}
          collaboration_mode={@collaboration_mode}
          myself={@myself}
        />
      </div>

      <!-- Mobile Drawer Overlay -->
      <%= if @mobile_tool_drawer_open do %>
        <div
          class="fixed inset-0 bg-black bg-opacity-50 z-20"
          phx-click="toggle_mobile_drawer"
          phx-target={@myself}
        ></div>
      <% end %>

      <!-- Mobile Tool Modals -->
      <%= if @show_mobile_tool_modal do %>
        <div class="fixed inset-0 z-50 bg-black bg-opacity-75 flex items-center justify-center p-4">
          <.render_mobile_tool_modal
            mobile_modal_tool={@mobile_modal_tool}
            workspace_state={@workspace_state}
            current_user={@current_user}
            permissions={@permissions}
            chat_messages={@chat_messages}
            message_input={@message_input}
            typing_users={@typing_users}
            recording_track={@recording_track}
            myself={@myself}
          />
        </div>
      <% end %>

      <!-- Mobile Audio Text Interface (when in audio_text mode) -->
      <%= if @active_tool == "audio_text" do %>
        <.render_mobile_audio_text_interface
          workspace_state={@workspace_state}
          session={@session}
          current_user={@current_user}
          permissions={@permissions}
          mobile_simplified_mode={@mobile_simplified_mode}
          mobile_text_size={@mobile_text_size}
          voice_commands_active={@voice_commands_active}
          myself={@myself}
        />
      <% end %>

      <!-- Mobile Quick Actions Bar -->
      <div class="fixed bottom-20 left-4 right-20 z-30">
        <.render_mobile_quick_actions
          active_tool={@active_tool}
          recording_track={@recording_track}
          workspace_state={@workspace_state}
          permissions={@permissions}
          myself={@myself}
        />
      </div>
    </div>
    """
  end

  # Mobile Tool Drawer Component
  defp render_mobile_tool_drawer(assigns) do
    ~H"""
    <div class="bg-gray-800 rounded-t-xl shadow-2xl">
      <!-- Bottom Sheet Handle -->
      <div class="flex justify-center py-2">
        <div class="w-12 h-1 bg-gray-600 rounded-full"></div>
      </div>

      <!-- Tool Header -->
      <div class="px-4 pb-3 border-b border-gray-700">
        <div class="flex items-center justify-between">
          <h3 class="text-white font-semibold">Collaboration Tools</h3>
          <div class="flex items-center space-x-2">
            <!-- Mode indicator -->
            <span class="text-xs text-gray-400 bg-gray-700 px-2 py-1 rounded">
              <%= String.replace(@collaboration_mode, "_", " ") |> String.capitalize() %>
            </span>
            <button
              phx-click="toggle_mobile_drawer"
              phx-target={@myself}
              class="text-gray-400 hover:text-white p-1"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Primary Tools -->
      <div class="px-4 py-3">
        <div class="text-xs text-gray-400 uppercase tracking-wider mb-2">Primary Tools</div>
        <div class="grid grid-cols-3 gap-3">
          <%= for tool_id <- @mobile_layout.primary_tools do %>
            <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
            <%= if tool do %>
              <button
                phx-click="activate_mobile_tool"
                phx-value-tool-id={tool_id}
                phx-target={@myself}
                class={[
                  "flex flex-col items-center p-3 rounded-lg transition-all duration-200",
                  @mobile_active_tool == tool_id && "bg-indigo-600 scale-105" || "bg-gray-700 hover:bg-gray-600"
                ]}
              >
                <div class="w-8 h-8 mb-2 flex items-center justify-center">
                  <.tool_icon icon={tool.icon} class="w-6 h-6 text-white" />
                </div>
                <span class="text-white text-xs font-medium"><%= tool.name %></span>
              </button>
            <% end %>
          <% end %>
        </div>
      </div>

      <!-- Quick Access Tools -->
      <%= if length(@mobile_layout.quick_access) > 0 do %>
        <div class="px-4 py-3 border-t border-gray-700">
          <div class="text-xs text-gray-400 uppercase tracking-wider mb-2">Quick Access</div>
          <div class="flex space-x-3 overflow-x-auto">
            <%= for tool_id <- @mobile_layout.quick_access do %>
              <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
              <%= if tool do %>
                <button
                  phx-click="activate_mobile_tool"
                  phx-value-tool-id={tool_id}
                  phx-target={@myself}
                  class="flex-shrink-0 flex items-center space-x-2 bg-gray-700 hover:bg-gray-600 px-3 py-2 rounded-lg"
                >
                  <.tool_icon icon={tool.icon} class="w-4 h-4 text-white" />
                  <span class="text-white text-sm"><%= tool.name %></span>
                </button>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- More Tools (Collapsible) -->
      <%= if length(@mobile_layout.hidden_tools) > 0 do %>
        <div class="px-4 py-3 border-t border-gray-700">
          <button
            phx-click="toggle_more_mobile_tools"
            phx-target={@myself}
            class="flex items-center justify-between w-full text-left"
          >
            <span class="text-xs text-gray-400 uppercase tracking-wider">More Tools</span>
            <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>

          <div class="mt-2 space-y-2" id="mobile-more-tools" style="display: none;">
            <%= for tool_id <- @mobile_layout.hidden_tools do %>
              <% tool = Enum.find(@available_tools, &(&1.id == tool_id)) %>
              <%= if tool do %>
                <button
                  phx-click="activate_mobile_tool"
                  phx-value-tool-id={tool_id}
                  phx-target={@myself}
                  class="w-full flex items-center space-x-3 p-2 text-left bg-gray-700 hover:bg-gray-600 rounded"
                >
                  <.tool_icon icon={tool.icon} class="w-4 h-4 text-white" />
                  <div>
                    <div class="text-white text-sm"><%= tool.name %></div>
                    <div class="text-gray-400 text-xs"><%= tool.description %></div>
                  </div>
                </button>
              <% end %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Mobile Tool Modal Component
  defp render_mobile_tool_modal(assigns) do
    ~H"""
    <div class="w-full max-w-sm bg-gray-900 rounded-xl shadow-2xl max-h-[80vh] flex flex-col">
      <!-- Modal Header -->
      <div class="flex items-center justify-between p-4 border-b border-gray-700">
        <div class="flex items-center space-x-2">
          <.tool_icon icon={get_tool_icon_class(@mobile_modal_tool)} class="w-5 h-5 text-white" />
          <h3 class="text-white font-semibold"><%= get_tool_display_name(@mobile_modal_tool) %></h3>
        </div>
        <button
          phx-click="hide_mobile_tool_modal"
          phx-target={@myself}
          class="text-gray-400 hover:text-white p-1"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <!-- Modal Content -->
      <div class="flex-1 overflow-hidden">
        <%= case @mobile_modal_tool do %>
          <% "chat" -> %>
            <.render_mobile_chat_modal
              chat_messages={@chat_messages}
              message_input={@message_input}
              current_user={@current_user}
              typing_users={@typing_users}
              myself={@myself}
            />

          <% "editor" -> %>
            <.render_mobile_editor_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              current_user={@current_user}
              myself={@myself}
            />

          <% "recorder" -> %>
            <.render_mobile_recorder_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              recording_track={@recording_track}
              current_user={@current_user}
              myself={@myself}
            />

          <% "mixer" -> %>
            <.render_mobile_mixer_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              myself={@myself}
            />

          <% "effects" -> %>
            <.render_mobile_effects_modal
              workspace_state={@workspace_state}
              permissions={@permissions}
              myself={@myself}
            />

          <% _ -> %>
            <div class="p-4 text-center">
              <p class="text-gray-400">Mobile interface for <%= @mobile_modal_tool %> coming soon</p>
            </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Mobile Audio-Text Interface Component
  defp render_mobile_audio_text_interface(assigns) do
    ~H"""
    <div class="fixed inset-0 z-20 bg-gray-900 bg-opacity-95 lg:hidden">
      <div class="h-full flex flex-col">
        <!-- Mobile Audio-Text Header -->
        <div class="flex items-center justify-between p-4 border-b border-gray-700 bg-gray-800">
          <div class="flex items-center space-x-2">
            <h2 class="text-white font-semibold text-lg">
              <%= if get_in(@workspace_state, [:audio_text, :mode]) == "lyrics_with_audio" do %>
                🎵 Lyrics
              <% else %>
                🎙️ Script
              <% end %>
            </h2>
            <%= if @voice_commands_active do %>
              <div class="flex items-center space-x-1 text-green-400">
                <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
                <span class="text-xs">Listening...</span>
              </div>
            <% end %>
          </div>

          <button
            phx-click="close_mobile_audio_text"
            phx-target={@myself}
            class="text-gray-400 hover:text-white p-2"
          >
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>

        <!-- Mobile Text Blocks -->
        <div class="flex-1 overflow-y-auto p-4 space-y-3">
          <%= for block <- (get_in(@workspace_state, [:audio_text, :text_sync, :blocks]) || []) do %>
            <div class={[
              "p-4 rounded-lg border-2 transition-all",
              @mobile_text_size == "large" && "text-lg",
              @mobile_text_size == "small" && "text-sm",
              block.id == get_in(@workspace_state, [:audio_text, :current_text_block]) && "border-indigo-500 bg-indigo-900 bg-opacity-30" || "border-gray-600 bg-gray-800 bg-opacity-50"
            ]}>
              <div class="flex items-center justify-between mb-2">
                <span class="text-xs font-medium px-2 py-1 rounded bg-purple-600 text-white">
                  <%= String.capitalize(block.type) %>
                </span>

                <div class="flex items-center space-x-2">
                  <%= if block.sync_point do %>
                    <span class="text-xs text-green-400">🎯</span>
                  <% end %>

                  <button
                    phx-click="mobile_sync_gesture"
                    phx-value-block-id={block.id}
                    phx-target={@myself}
                    class="text-gray-400 hover:text-green-400 p-1"
                    title="Tap to sync"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                  </button>
                </div>
              </div>

              <textarea
                class="w-full bg-transparent text-white resize-none border-none focus:outline-none focus:ring-2 focus:ring-indigo-500 rounded p-2"
                rows="3"
                placeholder="Tap to edit..."
                phx-blur="audio_text_update_block"
                phx-value-block-id={block.id}
                phx-target={@myself}
              ><%= block.content %></textarea>
            </div>
          <% end %>

          <!-- Add Block Button -->
          <div class="flex space-x-2">
            <button
              phx-click="audio_text_add_block"
              phx-value-type="verse"
              phx-target={@myself}
              class="flex-1 py-3 bg-indigo-600 hover:bg-indigo-700 text-white rounded-lg font-medium"
            >
              + Verse
            </button>
            <button
              phx-click="audio_text_add_block"
              phx-value-type="chorus"
              phx-target={@myself}
              class="flex-1 py-3 bg-purple-600 hover:bg-purple-700 text-white rounded-lg font-medium"
            >
              + Chorus
            </button>
          </div>
        </div>

        <!-- Mobile Audio Controls -->
        <div class="p-4 border-t border-gray-700 bg-gray-800">
          <div class="flex items-center justify-between mb-4">
            <!-- Transport Controls -->
            <div class="flex items-center space-x-3">
              <button
                phx-click="audio_text_play"
                phx-target={@myself}
                class="w-12 h-12 bg-green-600 hover:bg-green-700 rounded-full flex items-center justify-center text-white"
              >
                ▶️
              </button>
              <button
                phx-click="audio_text_stop"
                phx-target={@myself}
                class="w-10 h-10 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
              >
                ⏹️
              </button>
            </div>

            <!-- Recording Button -->
            <button
              phx-click="mobile_audio_text_record"
              phx-value-with-script="true"
              phx-target={@myself}
              class="w-12 h-12 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
            >
              ⚫
            </button>

            <!-- Voice Commands -->
            <button
              phx-click="toggle_voice_commands"
              phx-target={@myself}
              class={[
                "w-10 h-10 rounded-full flex items-center justify-center",
                @voice_commands_active && "bg-green-600 text-white" || "bg-gray-600 text-gray-300"
              ]}
            >
              🎤
            </button>
          </div>

          <!-- Settings Row -->
          <div class="flex items-center justify-between text-sm">
            <label class="flex items-center space-x-2 text-gray-400">
              <input
                type="checkbox"
                checked={@mobile_simplified_mode}
                phx-click="mobile_simplified_mode_toggle"
                phx-target={@myself}
                class="rounded border-gray-600 text-indigo-600"
              />
              <span>Simple Mode</span>
            </label>

            <select
              phx-change="mobile_text_size_change"
              phx-target={@myself}
              class="bg-gray-700 border-gray-600 text-white rounded text-xs"
            >
              <option value="small" selected={@mobile_text_size == "small"}>Small Text</option>
              <option value="base" selected={@mobile_text_size == "base"}>Normal Text</option>
              <option value="large" selected={@mobile_text_size == "large"}>Large Text</option>
            </select>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Mobile Quick Actions Component
  defp render_mobile_quick_actions(assigns) do
    ~H"""
    <div class="bg-gray-800 bg-opacity-90 rounded-full px-4 py-2 flex items-center justify-center space-x-4">
      <%= case @active_tool do %>
        <% "audio" -> %>
          <!-- Audio Quick Actions -->
          <button
            phx-click="audio_toggle_recording"
            phx-target={@myself}
            class={[
              "w-10 h-10 rounded-full flex items-center justify-center transition-colors",
              @recording_track && "bg-red-600 animate-pulse" || "bg-gray-600 hover:bg-red-600"
            ]}
          >
            <div class="w-4 h-4 bg-white rounded-full"></div>
          </button>

          <button
            phx-click="audio_start_playback"
            phx-target={@myself}
            class="w-8 h-8 bg-green-600 hover:bg-green-700 rounded-full flex items-center justify-center text-white"
          >
            ▶️
          </button>

          <button
            phx-click="audio_stop_playback"
            phx-target={@myself}
            class="w-8 h-8 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
          >
            ⏹️
          </button>

        <% "text" -> %>
          <!-- Text Quick Actions -->
          <button
            phx-click="text_save_document"
            phx-target={@myself}
            class="px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full text-sm"
          >
            Save
          </button>

          <button
            phx-click="text_voice_input"
            phx-target={@myself}
            class="w-8 h-8 bg-purple-600 hover:bg-purple-700 rounded-full flex items-center justify-center text-white"
          >
            🎤
          </button>

        <% "audio_text" -> %>
          <!-- Audio-Text Quick Actions -->
          <button
            phx-click="audio_text_sync_current"
            phx-target={@myself}
            class="px-3 py-1 bg-green-600 hover:bg-green-700 text-white rounded-full text-sm"
          >
            Sync
          </button>

          <button
            phx-click="mobile_audio_text_record"
            phx-target={@myself}
            class="w-8 h-8 bg-red-600 hover:bg-red-700 rounded-full flex items-center justify-center text-white"
          >
            ⚫
          </button>

        <% _ -> %>
          <!-- Default Quick Actions -->
          <div class="text-gray-400 text-xs">
            <%= String.capitalize(@active_tool) %> tools
          </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("toggle_mobile_drawer", _params, socket) do
    new_state = !socket.assigns.mobile_tool_drawer_open
    {:noreply, socket
      |> assign(mobile_tool_drawer_open: new_state)
      |> push_event("mobile_drawer_toggled", %{open: new_state})}
  end

  @impl true
  def handle_event("activate_mobile_tool", %{"tool_id" => tool_id}, socket) do
    send(self(), {:activate_mobile_tool, tool_id})
    {:noreply, socket
      |> assign(mobile_tool_drawer_open: false)
      |> assign(mobile_active_tool: tool_id)}
  end

  @impl true
  def handle_event("show_mobile_tool_modal", %{"tool_id" => tool_id}, socket) do
    {:noreply, socket
      |> assign(show_mobile_tool_modal: true)
      |> assign(mobile_modal_tool: tool_id)}
  end

  @impl true
  def handle_event("hide_mobile_tool_modal", _params, socket) do
    {:noreply, socket
      |> assign(show_mobile_tool_modal: false)
      |> assign(mobile_modal_tool: nil)}
  end

  @impl true
  def handle_event("toggle_more_mobile_tools", _params, socket) do
    {:noreply, socket |> push_event("toggle_more_tools", %{})}
  end

  @impl true
  def handle_event("close_mobile_audio_text", _params, socket) do
    send(self(), {:set_active_tool, "audio"})
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_voice_commands", _params, socket) do
    current_state = socket.assigns[:voice_commands_active] || false
    new_state = !current_state

    send(self(), {:toggle_voice_commands, new_state})
    {:noreply, assign(socket, voice_commands_active: new_state)}
  end

  # Forward all other events to parent
  @impl true
  def handle_event(event_name, params, socket) do
    send(self(), {:mobile_event, String.to_atom(event_name), params})
    {:noreply, socket}
  end

  # Helper Functions
    defp tool_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% "chat-bubble-left-ellipsis" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
        </svg>
      <% "document-text" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
        </svg>
      <% "microphone" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
        </svg>
      <% "adjustments-horizontal" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4" />
        </svg>
      <% "sparkles" -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z" />
        </svg>
      <% _ -> %>
        <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z" />
        </svg>
    <% end %>
    """
  end

  # Helper functions missing from the component
  defp get_tool_icon_class(tool_id) do
    case tool_id do
      "chat" -> "chat-bubble-left-ellipsis"
      "editor" -> "document-text"
      "recorder" -> "microphone"
      "mixer" -> "adjustments-horizontal"
      "effects" -> "sparkles"
      _ -> "squares-2x2"
    end
  end

  defp get_tool_display_name(tool_id) do
    case tool_id do
      "chat" -> "Chat"
      "editor" -> "Editor"
      "recorder" -> "Recorder"
      "mixer" -> "Audio Mixer"
      "effects" -> "Effects"
      _ -> String.capitalize(tool_id)
    end
  end

  # Additional mobile modal components referenced but missing
  defp render_mobile_chat_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Chat Messages -->
      <div class="flex-1 overflow-y-auto p-4 space-y-3">
        <%= if length(@chat_messages) == 0 do %>
          <div class="text-center text-gray-500 py-8">
            <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            <p class="text-sm">No messages yet</p>
            <p class="text-xs text-gray-600 mt-1">Start the conversation!</p>
          </div>
        <% end %>

        <%= for message <- @chat_messages do %>
          <div class={[
            "flex",
            message.user_id == @current_user.id && "justify-end" || "justify-start"
          ]}>
            <%= if message.user_id != @current_user.id do %>
              <div class="flex-shrink-0 mr-3">
                <div class="h-8 w-8 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center text-white font-medium text-sm">
                  <%= String.at(message.username, 0) %>
                </div>
              </div>
            <% end %>

            <div class="max-w-xs">
              <%= if message.user_id != @current_user.id do %>
                <p class="text-xs text-gray-400 mb-1 ml-1"><%= message.username %></p>
              <% end %>
              <div class={[
                "rounded-2xl px-4 py-2",
                message.user_id == @current_user.id && "bg-indigo-600 text-white rounded-br-md" || "bg-gray-700 text-white rounded-bl-md"
              ]}>
                <p class="text-sm"><%= message.content %></p>
                <p class="text-xs mt-1 opacity-70">
                  <%= Calendar.strftime(message.inserted_at, "%H:%M") %>
                </p>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Typing Indicator -->
      <%= if MapSet.size(@typing_users) > 0 do %>
        <div class="px-4 py-2 text-xs text-gray-400">
          Someone is typing...
        </div>
      <% end %>

      <!-- Chat Input -->
      <div class="p-4 border-t border-gray-700">
        <form phx-submit="send_session_message" phx-target={@myself}>
          <div class="flex space-x-2">
            <input
              type="text"
              name="message"
              value={@message_input}
              phx-keyup="update_message_input"
              phx-focus="typing_start"
              phx-blur="typing_stop"
              phx-target={@myself}
              placeholder="Type your message..."
              class="flex-1 bg-gray-800 border-gray-600 rounded-full px-4 py-2 text-white text-sm focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
            />
            <button
              type="submit"
              class="bg-indigo-600 hover:bg-indigo-700 text-white rounded-full p-2 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
              </svg>
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp render_mobile_editor_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4">
      <!-- Document Type Selector -->
      <div class="mb-4">
        <label class="block text-xs text-gray-400 mb-2">Document Type</label>
        <select class="w-full bg-gray-800 border-gray-600 rounded-lg px-3 py-2 text-white text-sm">
          <option>Plain Text</option>
          <option>Song Lyrics</option>
          <option>Script/Dialogue</option>
          <option>Article/Blog</option>
          <option>Book Chapter</option>
        </select>
      </div>

      <!-- Formatting Toolbar -->
      <div class="flex space-x-2 mb-4 p-2 bg-gray-800 rounded-lg">
        <button class="p-2 text-gray-400 hover:text-white rounded">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 4h8a4 4 0 014 4 4 4 0 01-4 4H6z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 12h9" />
          </svg>
        </button>
        <button class="p-2 text-gray-400 hover:text-white rounded">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H5a2 2 0 00-2 2v9a2 2 0 002 2h14a2 2 0 002-2V8a2 2 0 00-2-2h-5m-4 0V4a2 2 0 114 0v2m-4 0a2 2 0 104 0m-5 8a2 2 0 100-4 2 2 0 000 4zm0 0c1.306 0 2.417.835 2.83 2M9 14a3.001 3.001 0 00-2.83 2M15 11h3m-3 4h2" />
          </svg>
        </button>
      </div>

      <!-- Text Editor -->
      <div class="flex-1">
        <textarea
          id="mobile-text-editor"
          phx-hook="MobileTextEditor"
          phx-blur="text_update"
          phx-keyup="text_update"
          phx-target={@myself}
          class="w-full h-full bg-gray-800 border-gray-600 rounded-lg p-3 text-white text-sm resize-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500"
          placeholder="Start writing your masterpiece..."
        ><%= @workspace_state.text.content %></textarea>
      </div>

      <!-- Word Count & Status -->
      <div class="mt-3 flex justify-between items-center text-xs text-gray-500">
        <span><%= String.length(@workspace_state.text.content) %> characters</span>
        <span>Auto-saved</span>
      </div>
    </div>
    """
  end

  defp render_mobile_recorder_modal(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-4">
      <!-- Recording Status -->
      <div class="text-center mb-6">
        <%= if Map.get(assigns, :recording_track) do %>
          <div class="mb-4">
            <div class="w-20 h-20 mx-auto bg-red-600 rounded-full flex items-center justify-center animate-pulse">
              <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 24 24">
                <circle cx="12" cy="12" r="8" />
              </svg>
            </div>
            <p class="text-red-400 font-medium mt-2">Recording...</p>
            <p class="text-gray-400 text-sm">Track <%= Map.get(assigns, :recording_track) %></p>
          </div>
        <% else %>
          <div class="mb-4">
            <div class="w-20 h-20 mx-auto bg-gray-700 rounded-full flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
              </svg>
            </div>
            <p class="text-gray-400 font-medium mt-2">Ready to Record</p>
          </div>
        <% end %>
      </div>

      <!-- Input Level Meter -->
      <div class="mb-6">
        <label class="block text-sm text-gray-400 mb-2">Input Level</label>
        <div class="w-full h-4 bg-gray-800 rounded-full overflow-hidden">
          <div class="h-full bg-gradient-to-r from-green-500 via-yellow-500 to-red-500 rounded-full transition-all duration-150" style="width: 45%"></div>
        </div>
        <div class="flex justify-between text-xs text-gray-500 mt-1">
          <span>Low</span>
          <span>Good</span>
          <span>Clip</span>
        </div>
      </div>

      <!-- Recording Controls -->
      <div class="space-y-4">
        <button
          phx-click={if Map.get(assigns, :recording_track), do: "mobile_stop_recording", else: "mobile_start_recording"}
          phx-value-track-index="0"
          phx-target={@myself}
          class={[
            "w-full py-4 rounded-xl font-semibold text-lg transition-colors",
            Map.get(assigns, :recording_track) && "bg-red-600 hover:bg-red-700 text-white" || "bg-indigo-600 hover:bg-indigo-700 text-white"
          ]}
        >
          <%= if Map.get(assigns, :recording_track) do %>
            Stop Recording
          <% else %>
            Start Recording
          <% end %>
        </button>

        <!-- Quick Actions -->
        <div class="grid grid-cols-2 gap-3">
          <button class="bg-gray-700 hover:bg-gray-600 text-white py-2 rounded-lg text-sm">
            Playback
          </button>
          <button class="bg-gray-700 hover:bg-gray-600 text-white py-2 rounded-lg text-sm">
            Settings
          </button>
        </div>
      </div>

      <!-- Recording Tips -->
      <div class="mt-6 p-3 bg-gray-800 rounded-lg">
        <h4 class="text-white text-sm font-medium mb-2">💡 Recording Tips</h4>
        <ul class="text-xs text-gray-400 space-y-1">
          <li>• Keep device close for best quality</li>
          <li>• Find a quiet environment</li>
          <li>• Watch the input level meter</li>
        </ul>
      </div>
    </div>
    """
  end

  defp render_mobile_mixer_modal(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-4">
      <!-- Master Controls -->
      <div class="mb-6 p-4 bg-gray-800 rounded-lg">
        <h3 class="text-white font-medium mb-3">Master Mix</h3>
        <div class="space-y-3">
          <div>
            <label class="block text-xs text-gray-400 mb-1">Master Volume</label>
            <input type="range" min="0" max="1" step="0.01" value="0.8" class="w-full"
              phx-change="mobile_master_volume_change" phx-target={@myself} />
          </div>
          <div class="flex space-x-2">
            <button
              phx-click="mobile_mute_all_tracks"
              phx-target={@myself}
              class="flex-1 bg-red-600 hover:bg-red-700 text-white py-2 rounded text-sm">
              Mute All
            </button>
            <button class="flex-1 bg-yellow-600 hover:bg-yellow-700 text-white py-2 rounded text-sm">
              Solo Clear
            </button>
          </div>
        </div>
      </div>

      <!-- Individual Tracks -->
      <%= if length(@workspace_state.audio.tracks) == 0 do %>
        <div class="text-center py-8">
          <svg class="w-12 h-12 mx-auto mb-3 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
          </svg>
          <p class="text-gray-500">No tracks to mix</p>
          <p class="text-xs text-gray-600 mt-1">Add some tracks to get started!</p>
        </div>
      <% else %>
        <div class="space-y-4">
          <%= for {track, index} <- Enum.with_index(@workspace_state.audio.tracks) do %>
            <div class="bg-gray-800 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <h4 class="text-white font-medium"><%= track.name %></h4>
                <span class="text-xs text-gray-400">Track <%= index + 1 %></span>
              </div>

              <!-- Volume Fader -->
              <div class="mb-3">
                <div class="flex justify-between items-center mb-1">
                  <label class="text-xs text-gray-400">Volume</label>
                  <span class="text-xs text-gray-300"><%= round(track.volume * 100) %>%</span>
                </div>
                <input
                  type="range"
                  min="0"
                  max="1"
                  step="0.01"
                  value={track.volume}
                  phx-change="mobile_track_volume_change"
                  phx-value-track-index={index}
                  phx-target={@myself}
                  class="w-full"
                />
              </div>

              <!-- Mute/Solo Buttons -->
              <div class="flex space-x-2">
                <button
                  phx-click="mobile_toggle_track_mute"
                  phx-value-track-index={index}
                  phx-target={@myself}
                  class={[
                    "flex-1 py-2 rounded text-xs font-medium transition-colors",
                    track.muted && "bg-red-600 text-white" || "bg-gray-700 text-gray-300"
                  ]}
                >
                  <%= if track.muted, do: "Unmute", else: "Mute" %>
                </button>

                <button
                  phx-click="mobile_solo_track"
                  phx-value-track-index={index}
                  phx-target={@myself}
                  class={[
                    "flex-1 py-2 rounded text-xs font-medium transition-colors",
                    track.solo && "bg-yellow-600 text-white" || "bg-gray-700 text-gray-300"
                  ]}
                >
                  <%= if track.solo, do: "Unsolo", else: "Solo" %>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_mobile_effects_modal(assigns) do
    ~H"""
    <div class="h-full overflow-y-auto p-4">
      <!-- Track Selector -->
      <div class="mb-4">
        <label class="block text-xs text-gray-400 mb-2">Apply Effects To</label>
        <select class="w-full bg-gray-800 border-gray-600 rounded-lg px-3 py-2 text-white text-sm">
          <option>Master Bus</option>
          <%= for track <- @workspace_state.audio.tracks do %>
            <option value={track.id}><%= track.name %></option>
          <% end %>
        </select>
      </div>

      <!-- Quick Effect Buttons -->
      <div class="grid grid-cols-2 gap-3 mb-6">
        <button
          phx-click="mobile_toggle_effect"
          phx-value-track-index="0"
          phx-value-effect-type="reverb"
          phx-target={@myself}
          class="bg-purple-600 hover:bg-purple-700 text-white py-3 rounded-lg text-sm font-medium"
        >
          🎵 Add Reverb
        </button>
        <button
          phx-click="mobile_toggle_effect"
          phx-value-track-index="0"
          phx-value-effect-type="delay"
          phx-target={@myself}
          class="bg-blue-600 hover:bg-blue-700 text-white py-3 rounded-lg text-sm font-medium"
        >
          🔄 Add Delay
        </button>
        <button
          phx-click="mobile_toggle_effect"
          phx-value-track-index="0"
          phx-value-effect-type="distortion"
          phx-target={@myself}
          class="bg-red-600 hover:bg-red-700 text-white py-3 rounded-lg text-sm font-medium"
        >
          🔥 Distortion
        </button>
        <button class="bg-gray-700 hover:bg-gray-600 text-white py-3 rounded-lg text-sm font-medium">
          🧹 Clear All
        </button>
      </div>

      <!-- EQ Section -->
      <div class="bg-gray-800 rounded-lg p-4 mb-4">
        <h3 class="text-white font-medium mb-3">EQ</h3>
        <div class="space-y-3">
          <div>
            <label class="block text-xs text-gray-400 mb-1">Low</label>
            <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
          </div>
          <div>
            <label class="block text-xs text-gray-400 mb-1">Mid</label>
            <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
          </div>
          <div>
            <label class="block text-xs text-gray-400 mb-1">High</label>
            <input type="range" min="-12" max="12" step="0.1" value="0" class="w-full" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Missing event handlers that are referenced in templates
  @impl true
  def handle_event("send_session_message", %{"message" => message}, socket) do
    send(self(), {:mobile_send_message, message})
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_message_input", %{"value" => value}, socket) do
    send(self(), {:mobile_update_message_input, value})
    {:noreply, socket}
  end

  @impl true
  def handle_event("typing_start", _params, socket) do
    send(self(), {:mobile_typing_start})
    {:noreply, socket}
  end

  @impl true
  def handle_event("typing_stop", _params, socket) do
    send(self(), {:mobile_typing_stop})
    {:noreply, socket}
  end

  @impl true
  def handle_event("text_update", params, socket) do
    send(self(), {:mobile_text_update, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("mobile_toggle_track_mute", %{"track_index" => index}, socket) do
    send(self(), {:mobile_toggle_track_mute, String.to_integer(index)})
    {:noreply, socket}
  end

  @impl true
  def handle_event("mobile_master_volume_change", %{"value" => volume}, socket) do
    send(self(), {:mobile_master_volume_change, String.to_float(volume)})
    {:noreply, socket}
  end

end
