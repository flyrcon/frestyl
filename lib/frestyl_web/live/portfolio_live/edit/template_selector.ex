# lib/frestyl_web/live/portfolio_live/edit/template_selector.ex

defmodule FrestylWeb.PortfolioLive.Edit.TemplateSelector do
  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.PortfolioTemplates

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="text-center">
        <h2 class="text-2xl font-bold text-gray-900 mb-4">Choose Your Portfolio Template</h2>
        <p class="text-gray-600 max-w-2xl mx-auto">
          Select a template that best represents your professional style. Each template is fully customizable and mobile-optimized.
        </p>
      </div>

      <!-- Template Categories -->
      <%= for {category, templates} <- group_templates_by_category() do %>
        <div class="space-y-4">
          <h3 class="text-xl font-semibold text-gray-900 border-b border-gray-200 pb-2">
            <%= category %>
          </h3>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%= for {template_key, template_config} <- templates do %>
              <div class={[
                "relative group cursor-pointer rounded-xl border-2 p-6 transition-all duration-300 hover:shadow-lg",
                if(@selected_template == template_key, do: "border-blue-500 bg-blue-50 shadow-lg ring-2 ring-blue-200", else: "border-gray-200 hover:border-gray-300")
              ]}
              phx-click="select_template"
              phx-value-template={template_key}
              phx-target={@myself}>

                <!-- Template Preview -->
                <div class={[
                  "h-32 bg-gradient-to-br rounded-lg mb-4 relative overflow-hidden transition-all duration-300",
                  template_config.preview_color
                ]}>
                  <!-- Mock Layout Preview -->
                  <div class="p-4 text-white relative z-10">
                    <div class="flex items-center space-x-3 mb-3">
                      <div class="w-8 h-8 bg-white/30 rounded-full"></div>
                      <div>
                        <div class="w-20 h-2 bg-white/40 rounded mb-1"></div>
                        <div class="w-16 h-1.5 bg-white/30 rounded"></div>
                      </div>
                    </div>

                    <%= case template_config.category do %>
                      <% "Minimalist" -> %>
                        <div class="space-y-2">
                          <div class="w-full h-1 bg-white/20 rounded"></div>
                          <div class="w-3/4 h-1 bg-white/20 rounded"></div>
                        </div>
                      <% "Professional" -> %>
                        <div class="grid grid-cols-3 gap-1">
                          <div class="h-4 bg-white/20 rounded"></div>
                          <div class="h-4 bg-white/20 rounded"></div>
                          <div class="h-4 bg-white/20 rounded"></div>
                        </div>
                      <% "Creative" -> %>
                        <div class="space-y-1">
                          <div class="flex space-x-1">
                            <div class="w-8 h-4 bg-white/30 rounded-full"></div>
                            <div class="w-6 h-4 bg-white/20 rounded-full"></div>
                          </div>
                          <div class="w-full h-2 bg-white/20 rounded-full"></div>
                        </div>
                      <% "Technical" -> %>
                        <div class="font-mono text-xs space-y-1">
                          <div class="flex space-x-1">
                            <div class="w-2 h-2 bg-green-400 rounded"></div>
                            <div class="w-16 h-2 bg-white/30 rounded"></div>
                          </div>
                          <div class="w-full h-1 bg-white/20 rounded"></div>
                        </div>
                      <% _ -> %>
                        <div class="grid grid-cols-2 gap-1">
                          <div class="h-4 bg-white/20 rounded"></div>
                          <div class="h-4 bg-white/20 rounded"></div>
                        </div>
                    <% end %>
                  </div>

                  <!-- Selection Indicator -->
                  <%= if @selected_template == template_key do %>
                    <div class="absolute top-3 right-3 w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                    </div>
                  <% end %>
                </div>

                <!-- Template Info -->
                <div>
                  <div class="flex items-center justify-between mb-2">
                    <h4 class="text-lg font-semibold text-gray-900">
                      <%= template_config.name %>
                    </h4>
                    <span class="text-2xl"><%= template_config.icon %></span>
                  </div>

                  <p class="text-sm text-gray-600 mb-4">
                    <%= template_config.description %>
                  </p>

                  <!-- Features -->
                  <div class="space-y-2">
                    <%= for feature <- Enum.take(template_config.features, 3) do %>
                      <div class="flex items-center text-xs text-gray-500">
                        <svg class="w-3 h-3 mr-2 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                        <%= feature %>
                      </div>
                    <% end %>
                  </div>

                  <!-- Mobile Optimized Badge -->
                  <%= if template_config.mobile_optimized do %>
                    <div class="mt-3">
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                        </svg>
                        Mobile Optimized
                      </span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Selected Template Actions -->
      <%= if @selected_template do %>
        <div class="mt-8 p-6 bg-blue-50 rounded-xl border border-blue-200">
          <div class="flex items-center justify-between">
            <div>
              <h4 class="text-lg font-semibold text-blue-900 mb-2">
                Selected: <%= get_template_name(@selected_template) %>
              </h4>
              <p class="text-blue-700">
                Ready to customize your <%= get_template_category(@selected_template) |> String.downcase() %> portfolio template.
              </p>
            </div>
            <div class="flex space-x-3">
              <button
                phx-click="preview_template"
                phx-value-template={@selected_template}
                phx-target={@myself}
                class="px-4 py-2 bg-white text-blue-600 border border-blue-300 rounded-lg hover:bg-blue-50 transition-colors"
              >
                Preview
              </button>
              <button
                phx-click="apply_template"
                phx-value-template={@selected_template}
                phx-target={@myself}
                class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Apply Template
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:selected_template, assigns.portfolio.theme || "professional_executive")}
  end

  @impl true
  def handle_event("select_template", %{"template" => template_key}, socket) do
    {:noreply, assign(socket, :selected_template, template_key)}
  end

  @impl true
  def handle_event("preview_template", %{"template" => template_key}, socket) do
    # Send event to parent to open preview
    send(self(), {:preview_template, template_key})
    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_template", %{"template" => template_key}, socket) do
    # Send event to parent to apply template
    send(self(), {:apply_template, template_key})
    {:noreply, socket}
  end

  # Helper functions
  defp group_templates_by_category do
    PortfolioTemplates.available_templates()
    |> Enum.group_by(fn {_key, config} -> config.category end)
    |> Enum.map(fn {category, templates} ->
      {String.capitalize(category), templates}
    end)
    |> Enum.sort_by(fn {category, _} ->
      case category do
        "Minimalist" -> 1
        "Professional" -> 2
        "Creative" -> 3
        "Technical" -> 4
        _ -> 5
      end
    end)
  end

  defp get_template_name(template_key) do
    case PortfolioTemplates.available_templates() |> Enum.find(fn {key, _} -> key == template_key end) do
      {_, config} -> config.name
      _ -> "Unknown"
    end
  end

  defp get_template_category(template_key) do
    case PortfolioTemplates.available_templates() |> Enum.find(fn {key, _} -> key == template_key end) do
      {_, config} -> config.category
      _ -> "Unknown"
    end
  end
end
