# lib/frestyl_web/live/studio_live/desktop_layout_component.ex

defmodule FrestylWeb.StudioLive.DesktopLayoutComponent do
  use FrestylWeb, :live_component
  alias FrestylWeb.AccessibilityComponents, as: A11y

  @impl true
  def mount(socket) do
    {:ok, assign(socket,
      sidebar_collapsed: false,
      chat_collapsed: false
    )}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-1 overflow-hidden">

      <!-- Left Sidebar - Tools -->
      <.live_component
        module={FrestylWeb.StudioLive.ToolSidebarComponent}
        id="tool-sidebar"
        tools={@tools}
        active_tool={@active_tool}
        collapsed={@sidebar_collapsed}
      />

      <!-- Main Workspace Area -->
      <div class="flex-1 overflow-hidden flex flex-col">

        <!-- Workspace Content -->
        <div class="flex-1 overflow-hidden">
          <%= case @active_tool do %>
            <% "audio" -> %>
              <.live_component
                module={FrestylWeb.StudioLive.AudioWorkspaceComponent}
                id="audio-workspace"
                workspace_state={@workspace_state}
                current_user={@current_user}
                permissions={@permissions}
                session={@session}
                recording_mode={@recording_mode}
                recording_track={@recording_track}
                audio_engine_state={@audio_engine_state}
                beat_machine_state={@beat_machine_state}
              />

            <% "text" -> %>
              <.live_component
                module={FrestylWeb.StudioLive.TextWorkspaceComponent}
                id="text-workspace"
                workspace_state={@workspace_state}
                current_user={@current_user}
                permissions={@permissions}
                collaborators={@collaborators}
              />

            <% "midi" -> %>
              <.live_component
                module={FrestylWeb.StudioLive.MidiWorkspaceComponent}
                id="midi-workspace"
                workspace_state={@workspace_state}
                current_user={@current_user}
                permissions={@permissions}
              />

            <% "visual" -> %>
              <.live_component
                module={FrestylWeb.StudioLive.VisualWorkspaceComponent}
                id="visual-workspace"
                workspace_state={@workspace_state}
                current_user={@current_user}
                permissions={@permissions}
              />

            <% _ -> %>
              <!-- Default workspace -->
              <div class="h-full flex items-center justify-center bg-gray-900 bg-opacity-50">
                <div class="text-center text-white">
                  <div class="w-20 h-20 mx-auto mb-6 bg-white/10 rounded-3xl flex items-center justify-center">
                    <svg class="w-10 h-10" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" />
                    </svg>
                  </div>
                  <h3 class="text-xl font-semibold mb-3">Select a Tool</h3>
                  <p class="text-white/70">Choose a tool from the sidebar to start creating.</p>
                </div>
              </div>
          <% end %>
        </div>
      </div>

      <!-- Right Sidebar - Chat -->
      <.live_component
        module={FrestylWeb.StudioLive.ChatSidebarComponent}
        id="chat-sidebar"
        chat_messages={@chat_messages}
        current_user={@current_user}
        collaborators={@collaborators}
        typing_users={@typing_users}
        message_input={@message_input}
        session={@session}
        collapsed={@chat_collapsed}
      />

    </div>
    """
  end

  @impl true
  def handle_event("toggle_sidebar", _, socket) do
    {:noreply, assign(socket, sidebar_collapsed: !socket.assigns.sidebar_collapsed)}
  end

  def handle_event("toggle_chat", _, socket) do
    {:noreply, assign(socket, chat_collapsed: !socket.assigns.chat_collapsed)}
  end
end
