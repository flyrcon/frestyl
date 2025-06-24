# lib/frestyl_web/live/studio_live/workspace_layout_component.ex
defmodule FrestylWeb.StudioLive.WorkspaceLayoutComponent do
  use FrestylWeb, :live_component

  alias FrestylWeb.StudioLive.{
    HeaderComponent,
    ToolSidebarComponent,
    DockPanelComponent,
    WorkspaceContentComponent,
    MobileInterfaceComponent,
    NotificationComponent,
    ModalComponent
  }

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-gradient-to-br from-gray-900 to-indigo-900">
      <!-- Header with session info and controls -->
      <.live_component
        module={HeaderComponent}
        id="studio-header"
        current_user={@current_user}
        channel={@channel}
        session={@session}
        permissions={@permissions}
        collaborators={@collaborators}
        connection_status={@connection_status}
        pending_operations={@pending_operations}
        operation_conflicts={@operation_conflicts}
        show_invite_modal={@show_invite_modal}
        show_settings_modal={@show_settings_modal}
        show_end_session_modal={@show_end_session_modal}
      />

      <!-- Main content area with dockable panels -->
      <div class="flex flex-1 overflow-hidden" id="main-content" phx-hook="ToolDragDrop">
        <!-- Desktop Layout -->
        <div class="hidden lg:flex flex-1">
          <!-- Tool Sidebar -->
          <.live_component
            module={ToolSidebarComponent}
            id="tool-sidebar"
            available_tools={@available_tools}
            active_tool={@active_tool}
            collaboration_mode={@collaboration_mode}
          />

          <!-- Left Dock Panel -->
          <%= if length(@tool_layout.left_dock) > 0 and Map.get(@dock_visibility, :left, true) do %>
            <.live_component
              module={DockPanelComponent}
              id="left-dock"
              dock_position="left"
              tools={@tool_layout.left_dock}
              workspace_state={@workspace_state}
              current_user={@current_user}
              session={@session}
              permissions={@permissions}
              dock_visibility={@dock_visibility}
            />
          <% end %>

          <!-- Main Workspace Content -->
          <div class="flex-1 flex flex-col overflow-hidden">
            <.live_component
              module={WorkspaceContentComponent}
              id="workspace-content"
              active_tool={@active_tool}
              workspace_state={@workspace_state}
              current_user={@current_user}
              session={@session}
              permissions={@permissions}
              is_mobile={@is_mobile}
              collaboration_mode={@collaboration_mode}
              myself={@myself}
            />

            <!-- Bottom Dock Panel -->
            <%= if length(@tool_layout.bottom_dock) > 0 and Map.get(@dock_visibility, :bottom, true) do %>
              <.live_component
                module={DockPanelComponent}
                id="bottom-dock"
                dock_position="bottom"
                tools={@tool_layout.bottom_dock}
                workspace_state={@workspace_state}
                current_user={@current_user}
                session={@session}
                permissions={@permissions}
                dock_visibility={@dock_visibility}
              />
            <% end %>
          </div>

          <!-- Right Dock Panel -->
          <%= if Map.get(@dock_visibility, :right, true) do %>
            <.live_component
              module={DockPanelComponent}
              id="right-dock"
              dock_position="right"
              tools={@tool_layout.right_dock}
              workspace_state={@workspace_state}
              current_user={@current_user}
              session={@session}
              permissions={@permissions}
              dock_visibility={@dock_visibility}
              chat_messages={@chat_messages}
              message_input={@message_input}
              typing_users={@typing_users}
            />
          <% end %>
        </div>

        <!-- Expand buttons for collapsed docks -->
        <div class="absolute inset-0 pointer-events-none">
          <!-- Left dock expand button -->
          <%= if length(@tool_layout.left_dock) > 0 and not Map.get(@dock_visibility, :left, true) do %>
            <button
              phx-click="toggle_dock_visibility"
              phx-value-dock="left"
              class="absolute left-0 top-1/2 -translate-y-1/2 w-6 h-12 bg-gray-800 hover:bg-gray-700 border-r border-gray-600 rounded-r-md flex items-center justify-center text-gray-400 hover:text-white transition-colors pointer-events-auto z-20"
              title="Expand left panel"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          <% end %>

          <!-- Right dock expand button -->
          <%= if Map.get(@tool_layout, :right_dock) && length(@tool_layout.right_dock) > 0 and not Map.get(@dock_visibility, :right, true) do %>
            <button
              phx-click="toggle_dock_visibility"
              phx-value-dock="right"
              class="absolute right-0 top-1/2 -translate-y-1/2 w-6 h-12 bg-gray-800 hover:bg-gray-700 border-l border-gray-600 rounded-l-md flex items-center justify-center text-gray-400 hover:text-white transition-colors pointer-events-auto z-20"
              title="Expand right panel"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" />
              </svg>
            </button>
          <% end %>

          <!-- Bottom dock expand button -->
          <%= if length(@tool_layout.bottom_dock) > 0 and not Map.get(@dock_visibility, :bottom, true) do %>
            <button
              phx-click="toggle_dock_visibility"
              phx-value-dock="bottom"
              class="absolute bottom-0 left-1/2 -translate-x-1/2 h-6 w-12 bg-gray-800 hover:bg-gray-700 border-t border-gray-600 rounded-t-md flex items-center justify-center text-gray-400 hover:text-white transition-colors pointer-events-auto z-20"
              title="Expand bottom panel"
            >
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
              </svg>
            </button>
          <% end %>
        </div>

        <!-- Mobile Layout -->
        <div class="lg:hidden flex-1">
          <.live_component
            module={FrestylWeb.StudioLive.Components.MobileInterfaceComponent}
            id="mobile-interface"
            active_tool={@active_tool}
            workspace_state={@workspace_state}
            current_user={@current_user}
            session={@session}
            permissions={@permissions}
            available_tools={@available_tools}
            mobile_layout={@mobile_layout}
            mobile_tool_drawer_open={@mobile_tool_drawer_open}
            show_mobile_tool_modal={@show_mobile_tool_modal}
            mobile_modal_tool={@mobile_modal_tool}
            collaboration_mode={@collaboration_mode}
            chat_messages={@chat_messages}
            message_input={@message_input}
            typing_users={@typing_users}
            mobile_active_tool={@mobile_active_tool || @active_tool}
            recording_track={@recording_track}
          />
        </div>
      </div>

      <!-- Notification System -->
      <FrestylWeb.StudioLive.NotificationComponent.notification_container
        notifications={@notifications}
      />

      <!-- Modal System -->
      <.live_component
        module={ModalComponent}
        id="modal-system"
        show_invite_modal={@show_invite_modal}
        show_settings_modal={@show_settings_modal}
        show_end_session_modal={@show_end_session_modal}
        current_user={@current_user}
        session={@session}
        permissions={@permissions}
      />
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    # Remove reserved LiveView keys before assigning
    clean_assigns = Map.drop(assigns, [:socket, :myself, :flash])
    {:ok, assign(socket, clean_assigns)}
  end
end
