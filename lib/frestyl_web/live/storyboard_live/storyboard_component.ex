# lib/frestyl_web/live/storyboard_live/storyboard_component.ex
defmodule FrestylWeb.StoryboardLive.StoryboardComponent do
  @moduledoc """
  Main storyboard interface component with responsive design and collaboration.
  """

  use FrestylWeb, :live_component

  alias Frestyl.Storyboard.{CanvasManager, PanelManager, TemplateLibrary}
  alias Frestyl.Stories
  alias Phoenix.PubSub

  @impl true
  def mount(socket) do
    {:ok, socket
     |> assign(:loading, true)
     |> assign(:panels, [])
     |> assign(:active_panel, nil)
     |> assign(:selected_tool, "pen")
     |> assign(:drawing_mode, false)
     |> assign(:zoom_level, 1.0)
     |> assign(:canvas_dimensions, %{width: 800, height: 600})
     |> assign(:device_type, "desktop")
     |> assign(:collaboration_enabled, false)
     |> assign(:collaborators, [])
     |> assign(:show_template_modal, false)
     |> assign(:templates, [])
     |> assign(:mobile_panel_index, 0)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if connected?(socket) do
      setup_subscriptions(socket.assigns.story.id)
    end

    {:ok, socket
     |> load_storyboard_data()
     |> detect_device_type()
     |> load_templates()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="storyboard-container h-full"
         phx-hook="StoryboardManager"
         id={"storyboard-#{@story.id}"}
         data-story-id={@story.id}
         data-device-type={@device_type}
         data-collaboration-enabled={@collaboration_enabled}>

      <!-- Header with Tools and Controls -->
      <div class="storyboard-header bg-white border-b border-gray-200 p-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <h2 class="text-xl font-semibold text-gray-900">
              <%= @story.title %> - Storyboard
            </h2>

            <!-- Panel Counter -->
            <div class="text-sm text-gray-500">
              <%= length(@panels) %> panels
              <%= if @device_type == "mobile" and @active_panel do %>
                • Panel <%= @mobile_panel_index + 1 %>
              <% end %>
            </div>
          </div>

          <div class="flex items-center space-x-2">
            <!-- Collaboration Status -->
            <%= if @collaboration_enabled do %>
              <div class="flex items-center space-x-2">
                <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
                <span class="text-sm text-green-600">Collaborative</span>

                <!-- Collaborator Avatars -->
                <div class="flex -space-x-2">
                  <%= for collaborator <- @collaborators do %>
                    <div class="w-6 h-6 rounded-full bg-blue-500 border-2 border-white flex items-center justify-center"
                         title={collaborator.username}>
                      <span class="text-xs text-white font-medium">
                        <%= String.first(collaborator.username) %>
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Action Buttons -->
            <button phx-click="add_panel"
                    phx-target={@myself}
                    class="px-3 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 flex items-center space-x-1">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              <span class="hidden sm:inline">Add Panel</span>
            </button>

            <button phx-click="show_templates"
                    phx-target={@myself}
                    class="px-3 py-2 bg-gray-500 text-white rounded-lg hover:bg-gray-600">
              Templates
            </button>

            <%= if @device_type == "mobile" do %>
              <button phx-click="toggle_mobile_tools"
                      phx-target={@myself}
                      class="p-2 bg-gray-100 rounded-lg">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
                </svg>
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Main Content Area -->
      <div class="storyboard-content flex-1 flex overflow-hidden">
        <!-- Desktop/Tablet Layout -->
        <%= if @device_type != "mobile" do %>
          <.render_desktop_layout assigns={assigns} />
        <% else %>
          <.render_mobile_layout assigns={assigns} />
        <% end %>
      </div>

      <!-- Template Selection Modal -->
      <%= if @show_template_modal do %>
        <.render_template_modal assigns={assigns} />
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # Helper Functions (MOVED TO BEFORE RENDER FUNCTIONS)
  # ============================================================================

  defp get_mobile_tools do
    [
      %{id: "pen", icon: "✏️"},
      %{id: "eraser", icon: "🧽"},
      %{id: "text", icon: "📝"},
      %{id: "select", icon: "👆"}
    ]
  end

  defp time_ago(datetime) do
    # Simplified time ago calculation
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      _ -> "recently"
    end
  end

  # Desktop/Tablet Layout
  defp render_desktop_layout(assigns) do
    ~H"""
    <!-- Left Sidebar - Tools -->
    <div class="storyboard-sidebar w-64 bg-gray-50 border-r border-gray-200 flex flex-col">
      <.render_tool_palette assigns={assigns} />
      <.render_layer_panel assigns={assigns} />
    </div>

    <!-- Main Canvas Area -->
    <div class="storyboard-main flex-1 flex flex-col">
      <!-- Canvas Controls -->
      <div class="canvas-controls bg-gray-100 px-4 py-2 border-b border-gray-200">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <!-- Zoom Controls -->
            <div class="flex items-center space-x-2">
              <button phx-click="zoom_out" phx-target={@myself}
                      class="p-1 bg-white rounded border border-gray-300">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 12H4"/>
                </svg>
              </button>

              <span class="text-sm text-gray-600 min-w-[60px] text-center">
                <%= round(@zoom_level * 100) %>%
              </span>

              <button phx-click="zoom_in" phx-target={@myself}
                      class="p-1 bg-white rounded border border-gray-300">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                </svg>
              </button>
            </div>

            <!-- Canvas Size Info -->
            <div class="text-sm text-gray-500">
              <%= @canvas_dimensions.width %>×<%= @canvas_dimensions.height %>
            </div>
          </div>

          <!-- Canvas Actions -->
          <div class="flex items-center space-x-2">
            <button phx-click="export_storyboard" phx-target={@myself}
                    class="px-3 py-1 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50">
              Export
            </button>

            <button phx-click="clear_canvas" phx-target={@myself}
                    class="px-3 py-1 text-sm bg-white border border-gray-300 rounded hover:bg-gray-50">
              Clear
            </button>
          </div>
        </div>
      </div>

      <!-- Panels Grid/Timeline -->
      <div class="panels-container flex-1 overflow-auto p-4">
        <%= if @device_type == "desktop" do %>
          <.render_panels_grid assigns={assigns} />
        <% else %>
          <.render_panels_timeline assigns={assigns} />
        <% end %>
      </div>
    </div>

    <!-- Right Sidebar - Properties -->
    <div class="properties-sidebar w-64 bg-gray-50 border-l border-gray-200 flex flex-col">
      <.render_properties_panel assigns={assigns} />
      <.render_voice_notes_panel assigns={assigns} />
    </div>
    """
  end

  # Mobile Layout
  defp render_mobile_layout(assigns) do
    ~H"""
    <div class="mobile-storyboard w-full flex flex-col">
      <!-- Mobile Canvas -->
      <div class="mobile-canvas flex-1 relative">
        <%= if @active_panel do %>
          <.live_component
            module={FrestylWeb.StoryboardLive.CanvasComponent}
            id={"canvas-#{@active_panel.id}"}
            panel={@active_panel}
            device_type="mobile"
            selected_tool={@selected_tool}
            zoom_level={@zoom_level}
            collaboration_enabled={@collaboration_enabled}
            story_id={@story.id}
          />
        <% else %>
          <div class="flex items-center justify-center h-full text-gray-500">
            <div class="text-center">
              <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
              <p class="text-lg font-medium">No panels yet</p>
              <p class="text-sm">Tap "Add Panel" to start storyboarding</p>
            </div>
          </div>
        <% end %>

        <!-- Mobile Panel Navigation -->
        <%= if length(@panels) > 0 do %>
          <div class="absolute bottom-4 left-1/2 transform -translate-x-1/2">
            <div class="bg-black bg-opacity-75 rounded-full px-4 py-2 flex items-center space-x-2">
              <button phx-click="prev_panel" phx-target={@myself}
                      disabled={@mobile_panel_index == 0}
                      class="p-2 text-white disabled:opacity-50">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
                </svg>
              </button>

              <span class="text-white text-sm">
                <%= @mobile_panel_index + 1 %> / <%= length(@panels) %>
              </span>

              <button phx-click="next_panel" phx-target={@myself}
                      disabled={@mobile_panel_index >= length(@panels) - 1}
                      class="p-2 text-white disabled:opacity-50">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Mobile Bottom Toolbar -->
      <.render_mobile_toolbar assigns={assigns} />
    </div>
    """
  end

  # Tool Palette Component
  defp render_tool_palette(assigns) do
    ~H"""
    <div class="tool-palette p-4 border-b border-gray-200">
      <h3 class="text-sm font-medium text-gray-900 mb-3">Drawing Tools</h3>

      <div class="grid grid-cols-2 gap-2">
        <%= for tool <- get_available_tools(@device_type) do %>
          <button phx-click="select_tool"
                  phx-value-tool={tool.id}
                  phx-target={@myself}
                  class={["p-3 rounded-lg border text-center transition-colors",
                         if(tool.id == @selected_tool,
                            do: "bg-blue-500 text-white border-blue-500",
                            else: "bg-white border-gray-200 hover:border-blue-300")]}>
            <div class="text-lg mb-1"><%= tool.icon %></div>
            <div class="text-xs"><%= tool.name %></div>
          </button>
        <% end %>
      </div>

      <!-- Tool Properties -->
      <%= if @selected_tool in ["pen", "brush"] do %>
        <div class="mt-4 space-y-3">
          <div>
            <label class="text-xs font-medium text-gray-700">Brush Size</label>
            <input type="range" min="1" max="50" value="5"
                   phx-change="update_brush_size" phx-target={@myself}
                   class="w-full mt-1" />
          </div>

          <div>
            <label class="text-xs font-medium text-gray-700">Color</label>
            <input type="color" value="#000000"
                   phx-change="update_color" phx-target={@myself}
                   class="w-full mt-1 h-8 rounded" />
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Panels Grid (Desktop)
  defp render_panels_grid(assigns) do
    ~H"""
    <div class="panels-grid">
      <%= if length(@panels) == 0 do %>
        <div class="empty-state text-center py-12">
          <svg class="w-24 h-24 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">Start Your Storyboard</h3>
          <p class="text-gray-600 mb-4">Create visual panels to plan your story structure</p>
          <button phx-click="add_panel" phx-target={@myself}
                  class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600">
            Create First Panel
          </button>
        </div>
      <% else %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
          <%= for {panel, index} <- Enum.with_index(@panels) do %>
            <.render_panel_card panel={panel} index={index} assigns={assigns} />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Individual Panel Card
  defp render_panel_card(assigns) do
    ~H"""
    <div class="panel-card bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow"
         phx-click="select_panel"
         phx-value-panel-id={@panel.id}
         phx-target={@myself}>

      <!-- Panel Header -->
      <div class="panel-header p-3 border-b border-gray-100">
        <div class="flex items-center justify-between">
          <span class="text-sm font-medium text-gray-900">
            Panel <%= @index + 1 %>
          </span>

          <div class="flex items-center space-x-1">
            <%= if @panel.voice_note_id do %>
              <svg class="w-4 h-4 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
              </svg>
            <% end %>

            <button phx-click="delete_panel"
                    phx-value-panel-id={@panel.id}
                    phx-target={@myself}
                    class="p-1 text-gray-400 hover:text-red-500">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Panel Canvas Preview -->
      <div class="panel-preview aspect-video bg-gray-50 relative">
        <%= if @panel.thumbnail_url do %>
          <img src={@panel.thumbnail_url} alt="Panel #{@index + 1}"
               class="w-full h-full object-cover" />
        <% else %>
          <.live_component
            module={FrestylWeb.StoryboardLive.CanvasComponent}
            id={"preview-#{@panel.id}"}
            panel={@panel}
            device_type="preview"
            selected_tool={@selected_tool}
            zoom_level={0.5}
            collaboration_enabled={false}
            story_id={@story.id}
          />
        <% end %>

        <!-- Active Panel Indicator -->
        <%= if @active_panel && @active_panel.id == @panel.id do %>
          <div class="absolute inset-0 border-2 border-blue-500 bg-blue-500 bg-opacity-10 rounded"></div>
        <% end %>
      </div>

      <!-- Panel Footer -->
      <div class="panel-footer p-2 text-xs text-gray-500 text-center">
        Updated <%= time_ago(@panel.updated_at) %>
      </div>
    </div>
    """
  end

  # Mobile Toolbar
  defp render_mobile_toolbar(assigns) do
    ~H"""
    <div class="mobile-toolbar bg-white border-t border-gray-200 p-4">
      <div class="flex items-center justify-between">
        <!-- Tool Selection -->
        <div class="flex items-center space-x-2">
          <%= for tool <- get_mobile_tools() do %>
            <button phx-click="select_tool"
                    phx-value-tool={tool.id}
                    phx-target={@myself}
                    class={["p-3 rounded-lg border",
                           if(tool.id == @selected_tool,
                              do: "bg-blue-500 text-white border-blue-500",
                              else: "bg-gray-100 border-gray-200")]}>
              <div class="text-lg"><%= tool.icon %></div>
            </button>
          <% end %>
        </div>

        <!-- Quick Actions -->
        <div class="flex items-center space-x-2">
          <button phx-click="undo" phx-target={@myself}
                  class="p-2 bg-gray-100 rounded-lg">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6"/>
            </svg>
          </button>

          <button phx-click="record_voice_note"
                  phx-value-panel-id={@active_panel && @active_panel.id}
                  phx-target={@myself}
                  class="p-2 bg-red-100 text-red-600 rounded-lg">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Additional render functions for layer panel, properties panel, etc.
  defp render_layer_panel(assigns) do
    ~H"""
    <div class="layer-panel p-4">
      <h3 class="text-sm font-medium text-gray-900 mb-3">Layers</h3>
      <!-- Layer management UI -->
    </div>
    """
  end

  defp render_properties_panel(assigns) do
    ~H"""
    <div class="properties-panel p-4">
      <h3 class="text-sm font-medium text-gray-900 mb-3">Properties</h3>
      <!-- Properties UI -->
    </div>
    """
  end

  defp render_voice_notes_panel(assigns) do
    ~H"""
    <div class="voice-notes-panel p-4 border-t border-gray-200">
      <h3 class="text-sm font-medium text-gray-900 mb-3">Voice Notes</h3>
      <!-- Voice notes integration -->
    </div>
    """
  end

  defp render_template_modal(assigns) do
    ~H"""
    <div class="template-modal fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg w-full max-w-4xl max-h-[80vh] overflow-auto">
        <!-- Template selection UI -->
      </div>
    </div>
    """
  end

  # Event Handlers
  @impl true
  def handle_event("add_panel", _params, socket) do
    story_id = socket.assigns.story.id
    user_id = socket.assigns.current_user.id

    case CanvasManager.create_canvas(story_id, nil, user_id) do
      {:ok, panel} ->
        updated_panels = socket.assigns.panels ++ [panel]

        {:noreply, socket
         |> assign(:panels, updated_panels)
         |> assign(:active_panel, panel)
         |> assign(:mobile_panel_index, length(updated_panels) - 1)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to create panel")}
    end
  end

  @impl true
  def handle_event("select_panel", %{"panel-id" => panel_id}, socket) do
    panel = Enum.find(socket.assigns.panels, &(&1.id == panel_id))
    panel_index = Enum.find_index(socket.assigns.panels, &(&1.id == panel_id)) || 0

    {:noreply, socket
     |> assign(:active_panel, panel)
     |> assign(:mobile_panel_index, panel_index)}
  end

  @impl true
  def handle_event("select_tool", %{"tool" => tool}, socket) do
    {:noreply, assign(socket, :selected_tool, tool)}
  end

  @impl true
  def handle_event("prev_panel", _params, socket) do
    new_index = max(0, socket.assigns.mobile_panel_index - 1)
    new_panel = Enum.at(socket.assigns.panels, new_index)

    {:noreply, socket
     |> assign(:mobile_panel_index, new_index)
     |> assign(:active_panel, new_panel)}
  end

  @impl true
  def handle_event("next_panel", _params, socket) do
    max_index = length(socket.assigns.panels) - 1
    new_index = min(max_index, socket.assigns.mobile_panel_index + 1)
    new_panel = Enum.at(socket.assigns.panels, new_index)

    {:noreply, socket
     |> assign(:mobile_panel_index, new_index)
     |> assign(:active_panel, new_panel)}
  end

  # Helper Functions
  defp load_storyboard_data(socket) do
    story_id = socket.assigns.story.id
    panels = PanelManager.get_story_panels(story_id)
    active_panel = List.first(panels)

    socket
    |> assign(:panels, panels)
    |> assign(:active_panel, active_panel)
    |> assign(:loading, false)
  end

  defp detect_device_type(socket) do
    # Would detect from user agent in real implementation
    assign(socket, :device_type, "desktop")
  end

  defp load_templates(socket) do
    templates = TemplateLibrary.list_templates()
    assign(socket, :templates, templates)
  end

  defp setup_subscriptions(story_id) do
    PubSub.subscribe(Frestyl.PubSub, "storyboard:#{story_id}")
  end

  defp get_available_tools("mobile") do
    [
      %{id: "pen", name: "Pen", icon: "✏️"},
      %{id: "eraser", name: "Eraser", icon: "🧽"},
      %{id: "text", name: "Text", icon: "📝"},
      %{id: "select", name: "Select", icon: "👆"}
    ]
  end

  defp get_available_tools(_device) do
    [
      %{id: "pen", name: "Pen", icon: "✏️"},
      %{id: "brush", name: "Brush", icon: "🖌️"},
      %{id: "eraser", name: "Eraser", icon: "🧽"},
      %{id: "text", name: "Text", icon: "📝"},
      %{id: "rectangle", name: "Rectangle", icon: "⬜"},
      %{id: "circle", name: "Circle", icon: "⭕"},
      %{id: "line", name: "Line", icon: "📏"},
      %{id: "select", name: "Select", icon: "👆"}
    ]
  end

  # Panels Timeline (Tablet)
  defp render_panels_timeline(assigns) do
    ~H"""
    <div class="panels-timeline">
      <%= if length(@panels) == 0 do %>
        <div class="empty-state text-center py-8">
          <svg class="w-16 h-16 mx-auto mb-4 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">Start Your Storyboard</h3>
          <p class="text-gray-600 mb-4">Create visual panels to plan your story structure</p>
          <button phx-click="add_panel" phx-target={@myself}
                  class="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600">
            Create First Panel
          </button>
        </div>
      <% else %>
        <div class="flex overflow-x-auto space-x-4 p-4">
          <%= for {panel, index} <- Enum.with_index(@panels) do %>
            <div class="flex-shrink-0 w-64">
              <.render_panel_card panel={panel} index={index} assigns={assigns} />
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
