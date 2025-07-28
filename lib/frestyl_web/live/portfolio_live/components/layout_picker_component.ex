# lib/frestyl_web/live/portfolio_live/components/layout_picker_component.ex

defmodule FrestylWeb.PortfolioLive.Components.LayoutPickerComponent do
  @moduledoc """
  Clean layout picker for the new 3-layout system:
  Sidebar, Single, and Workspace layouts with minimal customization options.
  """

  use FrestylWeb, :live_component
  import FrestylWeb.CoreComponents

  @impl true
  def update(assigns, socket) do
    current_layout = get_current_layout(assigns.portfolio)
    current_color_scheme = get_current_color_scheme(assigns.portfolio)
    current_typography = get_current_typography(assigns.portfolio)

    {:ok, socket
      |> assign(assigns)
      |> assign(:current_layout, current_layout)
      |> assign(:current_color_scheme, current_color_scheme)
      |> assign(:current_typography, current_typography)
      |> assign(:show_preview, false)
      |> assign(:preview_layout, nil)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="layout-picker space-y-6">
      <!-- Layout Selection -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM14 12a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1h-4a1 1 0 01-1-1v-7z"/>
          </svg>
          Portfolio Layout
        </h3>
        <p class="text-gray-600 mb-6">Choose how you want to organize your portfolio content</p>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for layout <- get_available_layouts() do %>
            <div class="layout-option">
              <input
                type="radio"
                name="layout_type"
                value={layout.id}
                id={"layout_#{layout.id}"}
                checked={@current_layout == layout.id}
                phx-click="select_layout"
                phx-value-layout={layout.id}
                phx-target={@myself}
                class="sr-only peer">

              <label
                for={"layout_#{layout.id}"}
                class="block cursor-pointer p-4 border-2 border-gray-200 rounded-lg hover:border-gray-300 peer-checked:border-purple-500 peer-checked:bg-purple-50 transition-all">

                <!-- Layout Preview -->
                <div class="mb-3">
                  <%= render_layout_preview(layout.id) %>
                </div>

                <!-- Layout Info -->
                <h4 class="font-semibold text-gray-900 mb-1"><%= layout.name %></h4>
                <p class="text-sm text-gray-600 mb-3"><%= layout.description %></p>

                <!-- Best For Tags -->
                <div class="flex flex-wrap gap-1">
                  <%= for tag <- layout.best_for do %>
                    <span class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded-full">
                      <%= tag %>
                    </span>
                  <% end %>
                </div>
              </label>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Color Scheme Selection -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v12a4 4 0 004 4h4a2 2 0 002-2V5z"/>
          </svg>
          Color Scheme
        </h3>
        <p class="text-gray-600 mb-6">Add a touch of personality with professional color palettes</p>

        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <%= for scheme <- get_color_schemes() do %>
            <div class="color-scheme-option">
              <input
                type="radio"
                name="color_scheme"
                value={scheme.id}
                id={"color_#{scheme.id}"}
                checked={@current_color_scheme == scheme.id}
                phx-click="select_color_scheme"
                phx-value-scheme={scheme.id}
                phx-target={@myself}
                class="sr-only peer">

              <label
                for={"color_#{scheme.id}"}
                class="block cursor-pointer p-3 border-2 border-gray-200 rounded-lg hover:border-gray-300 peer-checked:border-purple-500 peer-checked:bg-purple-50 transition-all">

                <!-- Color Preview -->
                <div class="flex mb-2">
                  <div class="w-6 h-6 rounded-l border border-gray-200" style={"background-color: #{scheme.primary}"}></div>
                  <div class="w-6 h-6 border-t border-b border-gray-200" style={"background-color: #{scheme.secondary}"}></div>
                  <div class="w-6 h-6 rounded-r border border-gray-200" style={"background-color: #{scheme.accent}"}></div>
                </div>

                <h4 class="font-medium text-gray-900 text-sm"><%= scheme.name %></h4>
                <p class="text-xs text-gray-500"><%= scheme.description %></p>
              </label>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Typography Selection -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
          </svg>
          Typography
        </h3>
        <p class="text-gray-600 mb-6">Choose the font style that best represents your personality</p>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <%= for font <- get_typography_options() do %>
            <div class="typography-option">
              <input
                type="radio"
                name="typography"
                value={font.id}
                id={"font_#{font.id}"}
                checked={@current_typography == font.id}
                phx-click="select_typography"
                phx-value-font={font.id}
                phx-target={@myself}
                class="sr-only peer">

              <label
                for={"font_#{font.id}"}
                class="block cursor-pointer p-4 border-2 border-gray-200 rounded-lg hover:border-gray-300 peer-checked:border-purple-500 peer-checked:bg-purple-50 transition-all">

                <h4 class="font-semibold text-gray-900 mb-2" style={"font-family: #{font.family}"}><%= font.name %></h4>
                <p class="text-sm text-gray-600 mb-2" style={"font-family: #{font.family}"}>Sample portfolio text in <%= font.name %></p>
                <p class="text-xs text-gray-500"><%= font.description %></p>
              </label>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Apply Changes -->
      <div class="bg-gray-50 rounded-xl p-6 border border-gray-200">
        <div class="flex items-center justify-between">
          <div>
            <h4 class="font-medium text-gray-900">Ready to apply changes?</h4>
            <p class="text-sm text-gray-600">Your portfolio will be updated with the new design</p>
          </div>
          <button
            phx-click="apply_design_changes"
            phx-target={@myself}
            class="px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors font-medium">
            Apply Design
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT DEFINITIONS
  # ============================================================================

  defp get_available_layouts do
    [
      %{
        id: "sidebar",
        name: "Sidebar",
        description: "Professional layout with navigation sidebar and main content area",
        best_for: ["Professional", "Business", "Corporate"]
      },
      %{
        id: "single",
        name: "Single",
        description: "Clean single-column layout perfect for storytelling",
        best_for: ["Personal", "Creative", "Minimal"]
      },
      %{
        id: "workspace",
        name: "Workspace",
        description: "Unique dashboard-style layout that showcases work dynamically",
        best_for: ["Portfolio", "Showcase", "Creative"]
      }
    ]
  end

  defp get_color_schemes do
    [
      %{
        id: "professional",
        name: "Professional",
        description: "Classic blue tones",
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa"
      },
      %{
        id: "creative",
        name: "Creative",
        description: "Bold purple vibes",
        primary: "#7c3aed",
        secondary: "#a855f7",
        accent: "#c084fc"
      },
      %{
        id: "tech",
        name: "Tech",
        description: "Modern green energy",
        primary: "#059669",
        secondary: "#10b981",
        accent: "#34d399"
      },
      %{
        id: "warm",
        name: "Warm",
        description: "Friendly orange warmth",
        primary: "#ea580c",
        secondary: "#f97316",
        accent: "#fb923c"
      }
    ]
  end

  defp get_typography_options do
    [
      %{
        id: "sans",
        name: "Sans Serif",
        family: "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif",
        description: "Clean and modern, perfect for digital reading"
      },
      %{
        id: "serif",
        name: "Serif",
        family: "'Crimson Text', 'Times New Roman', serif",
        description: "Classic and elegant, great for traditional portfolios"
      },
      %{
        id: "mono",
        name: "Monospace",
        family: "'JetBrains Mono', 'Fira Code', monospace",
        description: "Technical and precise, ideal for developers"
      }
    ]
  end

  # ============================================================================
  # LAYOUT PREVIEW RENDERING
  # ============================================================================

  defp render_layout_preview("sidebar") do
    assigns = %{}
    ~H"""
    <div class="w-full h-16 bg-gray-100 rounded border overflow-hidden">
      <div class="flex h-full">
        <div class="w-1/3 bg-gray-200 border-r"></div>
        <div class="flex-1 p-1">
          <div class="w-full h-2 bg-gray-300 rounded mb-1"></div>
          <div class="w-3/4 h-2 bg-gray-300 rounded mb-1"></div>
          <div class="w-1/2 h-2 bg-gray-300 rounded"></div>
        </div>
      </div>
    </div>
    """
  end

  defp render_layout_preview("single") do
    assigns = %{}
    ~H"""
    <div class="w-full h-16 bg-gray-100 rounded border overflow-hidden p-2">
      <div class="w-full h-3 bg-gray-300 rounded mb-1"></div>
      <div class="w-4/5 h-2 bg-gray-300 rounded mb-1"></div>
      <div class="w-3/5 h-2 bg-gray-300 rounded mb-1"></div>
      <div class="w-2/3 h-2 bg-gray-300 rounded"></div>
    </div>
    """
  end

  defp render_layout_preview("workspace") do
    assigns = %{}
    ~H"""
    <div class="w-full h-16 bg-gray-100 rounded border overflow-hidden p-1">
      <div class="grid grid-cols-3 gap-1 h-full">
        <div class="bg-gray-300 rounded"></div>
        <div class="bg-gray-300 rounded"></div>
        <div class="bg-gray-200 rounded"></div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("select_layout", %{"layout" => layout}, socket) do
    {:noreply, assign(socket, :current_layout, layout)}
  end

  @impl true
  def handle_event("select_color_scheme", %{"scheme" => scheme}, socket) do
    {:noreply, assign(socket, :current_color_scheme, scheme)}
  end

  @impl true
  def handle_event("select_typography", %{"font" => font}, socket) do
    {:noreply, assign(socket, :current_typography, font)}
  end

  @impl true
  def handle_event("apply_design_changes", _params, socket) do
    # Build the customization update
    layout_update = %{
      "layout_style" => socket.assigns.current_layout,
      "color_scheme" => socket.assigns.current_color_scheme,
      "typography" => socket.assigns.current_typography,
      "updated_at" => DateTime.utc_now() |> DateTime.to_iso8601()
    }

    # Send to parent
    send(self(), {:update_portfolio_design, layout_update})

    {:noreply, socket
      |> put_flash(:info, "Design updated successfully!")
    }
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_layout(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "layout_style", "single")
  end

  defp get_current_color_scheme(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "color_scheme", "professional")
  end

  defp get_current_typography(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "typography", "sans")
  end
end
