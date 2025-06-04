# lib/frestyl_web/live/studio_live/mobile_layout_component.ex

defmodule FrestylWeb.StudioLive.MobileLayoutComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket, mobile_tab: "audio", mobile_menu_open: false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col h-full bg-gradient-to-br from-gray-900 via-purple-900 to-indigo-900">
      <!-- Mobile Tab Navigation -->
      <nav class="bg-black/30 backdrop-blur-sm border-b border-white/10 px-4 py-2">
        <div class="flex space-x-1 overflow-x-auto">
          <%= for tab <- mobile_tabs(@tools) do %>
            <button
              phx-click="switch_mobile_tab"
              phx-value-tab={tab.id}
              phx-target={@myself}
              class={[
                "flex-shrink-0 px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 flex items-center gap-2",
                if @mobile_tab == tab.id do
                  "bg-gradient-to-r from-pink-500 to-purple-600 text-white shadow-lg"
                else
                  "text-white/70 hover:text-white hover:bg-white/10"
                end
              ]}
              disabled={!tab.enabled}
            >
              <div class={[
                "w-4 h-4 flex items-center justify-center",
                !tab.enabled && "opacity-50"
              ]}>
                <%= render_tab_icon(tab.icon) %>
              </div>
              <span class="whitespace-nowrap"><%= tab.name %></span>
            </button>
          <% end %>
        </div>
      </nav>

      <!-- Mobile Content Area -->
      <div class="flex-1 overflow-hidden">
        <%= case @mobile_tab do %>
          <% "audio" -> %>
            <.live_component
              module={FrestylWeb.StudioLive.MobileAudioComponent}
              id="mobile-audio"
              workspace_state={@workspace_state}
              current_user={@current_user}
              permissions={@permissions}
              session={@session}
              device_info={@device_info}
              audio_config={@audio_config}
              is_recording={@is_recording}
              current_mobile_track={@current_mobile_track}
            />

          <% "chat" -> %>
            <.live_component
              module={FrestylWeb.StudioLive.MobileChatComponent}
              id="mobile-chat"
              chat_messages={@chat_messages}
              current_user={@current_user}
              collaborators={@collaborators}
              typing_users={@typing_users}
              message_input={@message_input}
              session={@session}
            />

          <% "text" -> %>
            <.live_component
              module={FrestylWeb.StudioLive.MobileTextComponent}
              id="mobile-text"
              workspace_state={@workspace_state}
              current_user={@current_user}
              permissions={@permissions}
              collaborators={@collaborators}
            />

          <% _ -> %>
            <div class="flex-1 flex items-center justify-center p-8">
              <div class="text-center text-white/70">
                <div class="w-16 h-16 mx-auto mb-4 bg-white/10 rounded-2xl flex items-center justify-center">
                  <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                  </svg>
                </div>
                <h3 class="text-lg font-semibold mb-2">Coming Soon</h3>
                <p class="text-sm">This tool will be available in a future update.</p>
              </div>
            </div>
        <% end %>
      </div>

      <!-- Mobile Quick Actions Bar -->
      <div class="bg-black/40 backdrop-blur-xl border-t border-white/10 px-4 py-3">
        <div class="flex items-center justify-between">
          <!-- Transport Controls -->
          <%= if @mobile_tab == "audio" do %>
            <div class="flex items-center space-x-3">
              <!-- Play/Stop Button -->
              <button
                phx-click="mobile_toggle_playback"
                phx-target={@myself}
                class="w-12 h-12 rounded-full bg-gradient-to-r from-green-500 to-emerald-600 hover:from-green-600 hover:to-emerald-700 flex items-center justify-center text-white shadow-lg transition-all duration-200 transform active:scale-95"
                aria-label="Play/Stop"
              >
                <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                  <%= if @workspace_state.audio.playing do %>
                    <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
                  <% else %>
                    <path d="M8 5v14l11-7z"/>
                  <% end %>
                </svg>
              </button>

              <!-- Record Button (if has permission) -->
              <%= if can_record_audio?(@permissions) do %>
                <button
                  phx-click="mobile_toggle_recording"
                  phx-target={@myself}
                  class={[
                    "w-12 h-12 rounded-full flex items-center justify-center text-white shadow-lg transition-all duration-200 transform active:scale-95",
                    if @is_recording do
                      "bg-gradient-to-r from-red-500 to-red-600 animate-pulse"
                    else
                      "bg-gradient-to-r from-red-500 to-red-600 hover:from-red-600 hover:to-red-700"
                    end
                  ]}
                  aria-label="Record"
                >
                  <%= if @is_recording do %>
                    <div class="w-4 h-4 bg-white rounded-sm"></div>
                  <% else %>
                    <div class="w-4 h-4 bg-white rounded-full"></div>
                  <% end %>
                </button>
              <% end %>
            </div>
          <% end %>

          <!-- Volume/Level Indicator -->
          <%= if @mobile_tab == "audio" do %>
            <div class="flex-1 mx-4">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-white/70" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/>
                </svg>
                <div class="flex-1 h-2 bg-white/20 rounded-full overflow-hidden">
                  <div
                    id="mobile-master-level"
                    class="h-full bg-gradient-to-r from-green-400 to-yellow-400 transition-all duration-100"
                    style="width: 60%"
                  ></div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Action Menu -->
          <div class="flex items-center space-x-2">
            <%= if @mobile_tab == "audio" && can_edit_audio?(@permissions) do %>
              <button
                phx-click="mobile_add_track"
                phx-target={@myself}
                class="w-10 h-10 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center text-white transition-colors"
                aria-label="Add track"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("switch_mobile_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, mobile_tab: tab)}
  end

  def handle_event("mobile_toggle_playback", _, socket) do
    send(self(), :mobile_toggle_playback)
    {:noreply, socket}
  end

  def handle_event("mobile_toggle_recording", _, socket) do
    send(self(), :mobile_toggle_recording)
    {:noreply, socket}
  end

  def handle_event("mobile_add_track", _, socket) do
    send(self(), :mobile_add_track)
    {:noreply, socket}
  end

  # Helper functions
  defp mobile_tabs(tools) do
    base_tabs = [
      %{id: "audio", name: "Audio", icon: "microphone", enabled: true},
      %{id: "chat", name: "Chat", icon: "chat", enabled: true}
    ]

    # Add enabled tools
    tool_tabs = Enum.map(tools, fn tool ->
      %{id: tool.id, name: tool.name, icon: tool.icon, enabled: tool.enabled}
    end)

    base_tabs ++ Enum.filter(tool_tabs, & &1.enabled && &1.id not in ["audio"])
  end

  defp render_tab_icon("microphone") do
    Phoenix.HTML.raw("""
    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z" />
    </svg>
    """)
  end

  defp render_tab_icon("chat") do
    Phoenix.HTML.raw("""
    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
    </svg>
    """)
  end

  defp render_tab_icon("document-text") do
    Phoenix.HTML.raw("""
    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>
    """)
  end

  defp render_tab_icon("music-note") do
    Phoenix.HTML.raw("""
    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3" />
    </svg>
    """)
  end

  defp render_tab_icon("pencil") do
    Phoenix.HTML.raw("""
    <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" class="w-full h-full">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
    </svg>
    """)
  end

  defp render_tab_icon(_), do: Phoenix.HTML.raw("")

  defp can_record_audio?(permissions), do: :record_audio in permissions
  defp can_edit_audio?(permissions), do: :edit_audio in permissions
end
