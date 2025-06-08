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

        <!-- Mobile Layout -->
        <div class="lg:hidden flex-1">
          <.live_component
            module={MobileInterfaceComponent}
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
          />
        </div>
      </div>

      <!-- Notification System -->
      <.live_component
        module={NotificationComponent}
        id="notification-system"
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
    {:ok, assign(socket, assigns)}
  end
end
