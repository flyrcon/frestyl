# File: lib/frestyl_web/live/portfolio_live/components/layout_picker_component.ex

defmodule FrestylWeb.PortfolioLive.Components.LayoutPickerComponent do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # Ensure we have all required assigns with defaults
    socket = socket
    |> assign(:current_layout, assigns[:current_layout] || assigns[:customization] || %{})
    |> assign(:portfolio, assigns[:portfolio])
    |> assign(assigns)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_layout", %{"layout" => layout_key}, socket) do
    # Send the selected layout back to the parent component
    send(self(), {:layout_selected, layout_key})
    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="layout-picker-component">
      <div class="mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Choose Your Layout</h3>
        <p class="text-sm text-gray-600">Select how you want your portfolio to be presented</p>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
        <%= for layout <- get_available_layouts() do %>
          <button
            phx-click="select_layout"
            phx-value-layout={layout.key}
            phx-target={@myself}
            class={[
              "layout-option p-4 border-2 rounded-lg transition-all duration-200 text-left hover:shadow-md",
              if(get_current_layout_key(@current_layout) == layout.key,
                do: "border-blue-500 bg-blue-50",
                else: "border-gray-200 hover:border-gray-300")
            ]}>

            <!-- Layout Preview -->
            <div class="mb-4">
              <div class={layout.preview_class}>
                <%= raw(layout.preview_content) %>
              </div>
            </div>

            <!-- Layout Info -->
            <div class="space-y-2">
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-2">
                  <span class="text-lg"><%= layout.icon %></span>
                  <h4 class="font-medium text-gray-900"><%= layout.name %></h4>
                  <%= if Map.get(layout, :badge) do %>
                    <span class="px-2 py-0.5 bg-green-100 text-green-700 text-xs font-medium rounded-full">
                      <%= layout.badge %>
                    </span>
                  <% end %>
                  <%= if Map.get(layout, :experimental) do %>
                    <span class="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs font-medium rounded-full">
                      Beta
                    </span>
                  <% end %>
                </div>

                <!-- Selection Indicator -->
                <%= if get_current_layout_key(@current_layout) == layout.key do %>
                  <div class="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                    <svg class="w-3 h-3 text-white" fill="currentColor" viewBox="0 0 20 20">
                      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                    </svg>
                  </div>
                <% else %>
                  <div class="w-5 h-5 border-2 border-gray-300 rounded-full"></div>
                <% end %>
              </div>

              <!-- Description -->
              <p class="text-sm text-gray-600"><%= layout.description %></p>

              <!-- Best For -->
              <%= if Map.get(layout, :best_for) do %>
                <div class="text-xs text-gray-500">
                  <span class="font-medium">Best for:</span>
                  <%= Enum.join(layout.best_for, ", ") %>
                </div>
              <% end %>

              <!-- Special Info for Time Machine -->
              <%= if layout.key == "time_machine" do %>
                <div class="mt-3 p-3 bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-200 rounded-md">
                  <div class="flex items-start space-x-2">
                    <svg class="w-4 h-4 text-purple-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"/>
                    </svg>
                    <div class="text-purple-700">
                      <p class="font-medium text-xs">✨ Immersive Experience</p>
                      <p class="mt-1 text-xs leading-relaxed">Full-screen card navigation. Users flip through sections like documents in a stack.</p>
                    </div>
                  </div>
                </div>
              <% end %>

              <!-- Features -->
              <div class="flex items-center space-x-3 text-xs text-gray-500 mt-2">
                <%= if Map.get(layout, :mobile_optimized) do %>
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                    </svg>
                    Mobile
                  </span>
                <% end %>
                <%= if Map.get(layout, :immersive) do %>
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                    Immersive
                  </span>
                <% end %>
              </div>
            </div>
          </button>
        <% end %>
      </div>

      <!-- Layout Tips -->
      <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
        <div class="flex items-start space-x-2">
          <svg class="w-4 h-4 text-blue-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
          </svg>
          <div class="text-blue-800 text-xs">
            <p class="font-medium">Quick Guide:</p>
            <ul class="mt-1 space-y-0.5">
              <li>• <strong>Single:</strong> Best for reading and mobile experience</li>
              <li>• <strong>Sidebar:</strong> Professional navigation for content-heavy portfolios</li>
              <li>• <strong>Workspace:</strong> Dashboard style for business profiles</li>
              <li>• <strong>Grid:</strong> Visual showcase for creative portfolios</li>
              <li>• <strong>Time Machine:</strong> Interactive storytelling (works best with video intro)</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT DATA - Updated to include Time Machine
  # ============================================================================

  defp get_available_layouts do
    [
      %{
        key: "single",
        name: "Single Column",
        description: "Clean single-column layout with floating navigation",
        icon: "📄",
        preview_class: "flex flex-col gap-1 h-16 bg-gray-100 rounded p-2",
        preview_content: "<div class='bg-blue-200 rounded h-3'></div><div class='bg-gray-200 rounded flex-1'></div><div class='bg-gray-200 rounded h-2'></div>",
        mobile_optimized: true,
        best_for: ["Personal portfolios", "Clean presentations", "Mobile-first design"]
      },
      %{
        key: "sidebar",
        name: "Sidebar",
        description: "Navigation on the left, content on the right",
        icon: "📐",
        preview_class: "grid grid-cols-4 gap-1 h-16 bg-gray-100 rounded p-2",
        preview_content: "<div class='bg-blue-200 rounded'></div><div class='bg-gray-200 rounded col-span-3'></div>",
        mobile_optimized: true,
        best_for: ["Professional portfolios", "Content-heavy sites", "Traditional layouts"]
      },
      %{
        key: "workspace",
        name: "Workspace",
        description: "Dashboard-style layout with organized sections",
        icon: "🗂️",
        preview_class: "grid grid-cols-3 grid-rows-2 gap-1 h-16 bg-gray-100 rounded p-2",
        preview_content: "<div class='bg-blue-200 rounded col-span-2'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div>",
        mobile_optimized: true,
        best_for: ["Business portfolios", "Executive profiles", "Data-heavy presentations"]
      },
      %{
        key: "grid",
        name: "Uniform Grid",
        description: "Uniform card grid layout for all sections",
        icon: "⊞",
        preview_class: "grid grid-cols-2 grid-rows-2 gap-1 h-16 bg-gray-100 rounded p-2",
        preview_content: "<div class='bg-blue-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div><div class='bg-gray-200 rounded'></div>",
        mobile_optimized: true,
        best_for: ["Creative portfolios", "Visual showcases", "Project galleries"]
      },
      %{
        key: "time_machine",
        name: "Cards",
        description: "Immersive card-stack navigation experience",
        icon: "🎭",
        preview_class: "relative h-16 bg-gray-100 rounded p-2 overflow-hidden",
        preview_content: """
        <div class='absolute inset-2 bg-white rounded shadow-sm border border-gray-200 z-30'></div>
        <div class='absolute inset-2 bg-gray-50 rounded shadow-sm border border-gray-200 transform translate-x-1 translate-y-1 z-20'></div>
        <div class='absolute inset-2 bg-gray-100 rounded shadow-sm border border-gray-200 transform translate-x-2 translate-y-2 z-10'></div>
        """,
        badge: "New",
        experimental: true,
        mobile_optimized: true,
        immersive: true,
        best_for: ["Creative portfolios", "Storytelling", "Interactive presentations"],
        requirements: ["Works best with video intro", "Minimum 3 sections recommended"]
      }
    ]
  end

  # ============================================================================
  # HELPER FUNCTIONS - Fixed to handle missing assigns
  # ============================================================================

  defp get_current_layout_key(current_layout) when is_map(current_layout) do
    Map.get(current_layout, "layout_style") || Map.get(current_layout, :layout_style) || "single"
  end
  defp get_current_layout_key(_), do: "single"

  defp is_layout_selected?(layout_key, current_layout) do
    get_current_layout_key(current_layout) == layout_key
  end

  defp get_layout_features(layout) do
    features = []

    features = if Map.get(layout, :mobile_optimized), do: features ++ ["Mobile Optimized"], else: features
    features = if Map.get(layout, :immersive), do: features ++ ["Immersive Experience"], else: features
    features = if Map.get(layout, :experimental), do: features ++ ["Beta Feature"], else: features

    features
  end
end
