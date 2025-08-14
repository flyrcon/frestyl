# lib/frestyl_web/live/storyboard_live/canvas_component.ex
defmodule FrestylWeb.StoryboardLive.CanvasComponent do
  @moduledoc """
  Interactive drawing canvas component with Fabric.js integration,
  responsive design, and real-time collaboration support.
  """

  use FrestylWeb, :live_component

  alias Frestyl.Storyboard.CanvasManager
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, socket
     |> assign(:canvas_ready, false)
     |> assign(:drawing_operations, [])
     |> assign(:collaborator_cursors, %{})
     |> assign(:pending_save, false)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if connected?(socket) and assigns.collaboration_enabled do
      setup_collaboration_subscriptions(assigns.story_id, assigns.panel.id)
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="canvas-container relative h-full"
         phx-hook="FabricCanvas"
         id={"canvas-container-#{@panel.id}"}
         data-panel-id={@panel.id}
         data-device-type={@device_type}
         data-selected-tool={@selected_tool}
         data-zoom-level={@zoom_level}
         data-collaboration-enabled={@collaboration_enabled}
         data-canvas-data={Jason.encode!(@panel.canvas_data)}>

      <!-- Main Canvas Element -->
      <canvas id={"fabric-canvas-#{@panel.id}"}
              class="fabric-canvas border border-gray-300 bg-white"
              style={get_canvas_style(@device_type, @panel.canvas_data)}>
      </canvas>

      <!-- Canvas Overlay Elements -->
      <div class="canvas-overlay absolute inset-0 pointer-events-none">
        <!-- Collaboration Cursors -->
        <%= if @collaboration_enabled do %>
          <%= for {user_id, cursor} <- @collaborator_cursors do %>
            <div class="collaborator-cursor absolute pointer-events-none"
                 style={"left: #{cursor.x}px; top: #{cursor.y}px;"}>
              <div class="cursor-pointer w-4 h-4 rounded-full border-2 border-white"
                   style={"background-color: #{cursor.color};"}></div>
              <div class="cursor-label mt-1 px-2 py-1 text-xs text-white rounded shadow-sm"
                   style={"background-color: #{cursor.color};"}>
                <%= cursor.username %>
              </div>
            </div>
          <% end %>
        <% end %>

        <!-- Loading Indicator -->
        <%= if not @canvas_ready do %>
          <div class="absolute inset-0 flex items-center justify-center bg-gray-50 bg-opacity-75">
            <div class="flex items-center space-x-2">
              <div class="w-4 h-4 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
              <span class="text-sm text-gray-600">Loading canvas...</span>
            </div>
          </div>
        <% end %>

        <!-- Save Indicator -->
        <%= if @pending_save do %>
          <div class="absolute top-2 right-2 bg-blue-500 text-white px-2 py-1 rounded text-xs">
            Saving...
          </div>
        <% end %>
      </div>

      <!-- Mobile Touch Helpers -->
      <%= if @device_type == "mobile" do %>
        <.render_mobile_helpers assigns={assigns} />
      <% end %>

      <!-- Canvas Context Menu (Desktop) -->
      <%= if @device_type != "mobile" do %>
        <div id={"context-menu-#{@panel.id}"}
             class="context-menu absolute bg-white border border-gray-200 rounded shadow-lg py-1 z-50 hidden">
          <button class="block w-full text-left px-4 py-2 text-sm hover:bg-gray-100"
                  phx-click="copy_object" phx-target={@myself}>
            Copy
          </button>
          <button class="block w-full text-left px-4 py-2 text-sm hover:bg-gray-100"
                  phx-click="delete_object" phx-target={@myself}>
            Delete
          </button>
          <hr class="my-1">
          <button class="block w-full text-left px-4 py-2 text-sm hover:bg-gray-100"
                  phx-click="bring_to_front" phx-target={@myself}>
            Bring to Front
          </button>
          <button class="block w-full text-left px-4 py-2 text-sm hover:bg-gray-100"
                  phx-click="send_to_back" phx-target={@myself}>
            Send to Back
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Mobile Helpers
  defp render_mobile_helpers(assigns) do
    ~H"""
    <!-- Mobile Gesture Hints -->
    <div class="mobile-hints absolute top-2 left-2 bg-black bg-opacity-50 text-white px-2 py-1 rounded text-xs">
      <%= case @selected_tool do %>
        <% "pen" -> %>
          Draw with finger
        <% "eraser" -> %>
          Tap to erase
        <% "text" -> %>
          Tap to add text
        <% "select" -> %>
          Tap to select objects
        <% _ -> %>
          <%= @selected_tool %>
      <% end %>
    </div>

    <!-- Mobile Zoom Controls -->
    <div class="mobile-zoom-controls absolute bottom-2 right-2 flex flex-col space-y-1">
      <button phx-click="mobile_zoom_in" phx-target={@myself}
              class="w-10 h-10 bg-white border border-gray-300 rounded-full flex items-center justify-center shadow-sm">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
      </button>

      <button phx-click="mobile_zoom_out" phx-target={@myself}
              class="w-10 h-10 bg-white border border-gray-300 rounded-full flex items-center justify-center shadow-sm">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"/>
        </svg>
      </button>
    </div>

    <!-- Mobile Palm Rejection Indicator -->
    <div id="palm-rejection-indicator" class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2
                                            bg-red-500 text-white px-3 py-1 rounded text-sm opacity-0 transition-opacity">
      Palm detected - drawing disabled
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("canvas_ready", _params, socket) do
    {:noreply, assign(socket, :canvas_ready, true)}
  end

  @impl true
  def handle_event("drawing_operation", %{"operation" => operation}, socket) do
    user_id = socket.assigns.current_user.id
    panel_id = socket.assigns.panel.id

    # Process the drawing operation
    case CanvasManager.process_drawing_operation(panel_id, operation, user_id) do
      {:ok, updated_canvas_data} ->
        # Update local state
        updated_panel = %{socket.assigns.panel | canvas_data: updated_canvas_data}

        {:noreply, socket
         |> assign(:panel, updated_panel)
         |> assign(:pending_save, true)
         |> then(&schedule_save_completion/1)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("canvas_resized", %{"dimensions" => dimensions}, socket) do
    user_id = socket.assigns.current_user.id
    panel_id = socket.assigns.panel.id

    case CanvasManager.resize_canvas(panel_id, dimensions, user_id) do
      {:ok, updated_panel} ->
        {:noreply, assign(socket, :panel, updated_panel)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cursor_moved", %{"x" => x, "y" => y}, socket) do
    if socket.assigns.collaboration_enabled do
      user_id = socket.assigns.current_user.id
      story_id = socket.assigns.story_id
      panel_id = socket.assigns.panel.id

      # Broadcast cursor position to collaborators
      PubSub.broadcast(
        Frestyl.PubSub,
        "storyboard:#{story_id}:#{panel_id}",
        {:cursor_moved, %{user_id: user_id, x: x, y: y}}
      )
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("mobile_zoom_in", _params, socket) do
    new_zoom = min(socket.assigns.zoom_level * 1.2, 3.0)
    {:noreply, socket
     |> assign(:zoom_level, new_zoom)
     |> push_event("update_zoom", %{zoom: new_zoom})}
  end

  @impl true
  def handle_event("mobile_zoom_out", _params, socket) do
    new_zoom = max(socket.assigns.zoom_level / 1.2, 0.1)
    {:noreply, socket
     |> assign(:zoom_level, new_zoom)
     |> push_event("update_zoom", %{zoom: new_zoom})}
  end

  @impl true
  def handle_event("copy_object", _params, socket) do
    {:noreply, push_event(socket, "copy_selected_object", %{})}
  end

  @impl true
  def handle_event("delete_object", _params, socket) do
    {:noreply, push_event(socket, "delete_selected_object", %{})}
  end

  @impl true
  def handle_event("bring_to_front", _params, socket) do
    {:noreply, push_event(socket, "bring_selected_to_front", %{})}
  end

  @impl true
  def handle_event("send_to_back", _params, socket) do
    {:noreply, push_event(socket, "send_selected_to_back", %{})}
  end

  # PubSub Message Handlers
  @impl true
  def handle_info({:drawing_operation, operation, user_id}, socket) do
    if user_id != socket.assigns.current_user.id do
      # Apply remote drawing operation
      {:noreply, push_event(socket, "apply_remote_operation", %{operation: operation})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:cursor_moved, %{user_id: user_id, x: x, y: y}}, socket) do
    if user_id != socket.assigns.current_user.id do
      # Update collaborator cursor position
      collaborator = get_collaborator_info(user_id)

      updated_cursors = Map.put(socket.assigns.collaborator_cursors, user_id, %{
        x: x,
        y: y,
        username: collaborator.username,
        color: collaborator.color
      })

      {:noreply, assign(socket, :collaborator_cursors, updated_cursors)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:save_completion}, socket) do
    {:noreply, assign(socket, :pending_save, false)}
  end

  # Helper Functions
  defp get_canvas_style(device_type, canvas_data) do
    base_width = canvas_data["width"] || 800
    base_height = canvas_data["height"] || 600

    case device_type do
      "mobile" ->
        # Full width on mobile, maintain aspect ratio
        "width: 100%; height: auto; max-height: 60vh;"

      "tablet" ->
        # Responsive size for tablet
        "width: min(#{base_width}px, 80vw); height: min(#{base_height}px, 60vh);"

      "preview" ->
        # Small preview size
        "width: 100%; height: 100%; max-width: 300px; max-height: 200px;"

      _ ->
        # Desktop - use actual dimensions with zoom
        "width: #{base_width}px; height: #{base_height}px;"
    end
  end

  defp setup_collaboration_subscriptions(story_id, panel_id) do
    PubSub.subscribe(Frestyl.PubSub, "storyboard:#{story_id}:#{panel_id}")
  end

  defp schedule_save_completion(socket) do
    Process.send_after(self(), {:save_completion}, 2000)
    socket
  end

  defp get_collaborator_info(user_id) do
    # Would fetch from user context in real implementation
    colors = ["#3B82F6", "#EF4444", "#10B981", "#F59E0B", "#8B5CF6", "#F97316"]
    color = Enum.at(colors, rem(String.to_integer(String.slice(user_id, 0, 8), 16), length(colors)))

    %{
      username: "User #{String.slice(user_id, 0, 8)}",
      color: color
    }
  end
end
