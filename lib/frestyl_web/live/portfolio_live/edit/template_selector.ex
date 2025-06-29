
defmodule FrestylWeb.PortfolioLive.Edit.TemplateSelector do
  use Phoenix.LiveComponent

  alias Frestyl.Templates.UnifiedRegistry
  alias Frestyl.Features.FeatureGate

  def render(assigns) do
    ~H"""
    <div class="template-selector-container">
      <div class="mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Choose Your Template</h3>
        <p class="text-sm text-gray-600 mt-1">Select a design that matches your style and subscription tier</p>
      </div>

      <!-- Template Categories -->
      <div class="space-y-8">
        <%= for {category, category_data} <- @template_categories do %>
          <div class="template-category">
            <!-- Category Header -->
            <div class="flex items-center justify-between mb-4">
              <div>
                <h4 class="text-md font-medium text-gray-800 capitalize">
                  <%= String.replace(category, "_", " ") %>
                </h4>
                <p class="text-sm text-gray-500">
                  <%= category_data.accessible_count %> available,
                  <%= category_data.locked_count %> locked
                </p>
              </div>

              <!-- Category Upgrade Badge -->
              <%= if category_data.upgrade_required do %>
                <div class="flex items-center text-sm">
                  <span class="bg-amber-100 text-amber-800 px-2 py-1 rounded-md">
                    Upgrade to <%= category_data.upgrade_required.required_tier |> Atom.to_string() |> String.capitalize() %>
                  </span>
                </div>
              <% end %>
            </div>

            <!-- Templates Grid -->
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
              <%= for {template_key, template_config} <- category_data.templates do %>
                <div class={[
                  "template-card relative border-2 rounded-xl p-4 transition-all duration-200",
                  if(template_config.access_status == :accessible,
                    do: "border-gray-200 hover:border-blue-300 hover:shadow-lg cursor-pointer",
                    else: "border-gray-100 bg-gray-50 opacity-75"
                  ),
                  if(@selected_template == template_key,
                    do: "border-blue-500 bg-blue-50 ring-2 ring-blue-200",
                    else: ""
                  )
                ]}>

                  <!-- Lock Icon for Locked Templates -->
                  <%= if template_config.access_status == :locked do %>
                    <div class="absolute top-2 right-2 z-10">
                      <div class="bg-gray-600 text-white p-1 rounded-full">
                        <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                          <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                        </svg>
                      </div>
                    </div>
                  <% end %>

                  <!-- Template Preview -->
                  <div class="template-preview h-24 bg-gradient-to-br rounded-lg mb-3 overflow-hidden"
                       style={"background: #{get_template_gradient(template_config)}"}>
                    <%= render_template_preview(template_key, template_config) %>
                  </div>

                  <!-- Template Info -->
                  <div class="template-info">
                    <h5 class="font-semibold text-gray-900 text-sm mb-1">
                      <%= template_config.name %>
                    </h5>
                    <p class="text-xs text-gray-600 mb-3 line-clamp-2">
                      <%= template_config.description %>
                    </p>

                    <!-- Features List -->
                    <%= if template_config.features && length(template_config.features) > 0 do %>
                      <div class="mb-3">
                        <div class="flex flex-wrap gap-1">
                          <%= for feature <- Enum.take(template_config.features, 2) do %>
                            <span class="text-xs bg-gray-100 text-gray-700 px-2 py-1 rounded">
                              <%= feature |> String.replace("_", " ") |> String.capitalize() %>
                            </span>
                          <% end %>
                        </div>
                      </div>
                    <% end %>

                    <!-- Action Button -->
                    <%= if template_config.access_status == :accessible do %>
                      <button phx-click="select_template"
                              phx-value-template={template_key}
                              phx-target={@myself}
                              class="w-full bg-blue-600 text-white text-sm py-2 px-3 rounded-lg hover:bg-blue-700 transition-colors">
                        <%= if @selected_template == template_key,
                            do: "Selected",
                            else: "Select" %>
                      </button>
                    <% else %>
                      <!-- Locked Template - Show Upgrade Prompt -->
                      <button phx-click="show_upgrade_modal"
                              phx-value-template={template_key}
                              phx-target={@myself}
                              class="w-full bg-amber-100 text-amber-800 text-sm py-2 px-3 rounded-lg hover:bg-amber-200 transition-colors border border-amber-300">
                        🔒 Upgrade Required
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Upgrade Modal -->
      <%= if @show_upgrade_modal do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm">
          <div class="bg-white rounded-xl shadow-2xl max-w-md w-full mx-4 overflow-hidden">
            <!-- Modal Header -->
            <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold text-white">
                  <%= @upgrade_info.title %>
                </h3>
                <button phx-click="hide_upgrade_modal"
                        phx-target={@myself}
                        class="text-white hover:text-gray-200">
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Modal Content -->
            <div class="px-6 py-6">
              <!-- Template Preview -->
              <div class="text-center mb-4">
                <div class="w-20 h-12 bg-gradient-to-br rounded-lg mx-auto mb-2"
                     style={"background: #{get_template_gradient(@locked_template_config)}"}>
                </div>
                <h4 class="font-semibold text-gray-900">
                  <%= @locked_template_config.name %>
                </h4>
              </div>

              <!-- Upgrade Reason -->
              <div class="text-center mb-6">
                <p class="text-gray-600 text-sm">
                  <%= @upgrade_info.reason %>
                </p>
              </div>

              <!-- Benefits List -->
              <div class="mb-6">
                <h5 class="font-medium text-gray-900 mb-3">What you'll get:</h5>
                <ul class="space-y-2">
                  <%= for benefit <- @upgrade_info.benefits do %>
                    <li class="flex items-center text-sm text-gray-700">
                      <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <%= benefit %>
                    </li>
                  <% end %>
                </ul>
              </div>

              <!-- Pricing -->
              <div class="bg-gray-50 rounded-lg p-4 mb-6 text-center">
                <div class="text-2xl font-bold text-gray-900">
                  <%= @upgrade_info.price %>
                </div>
                <div class="text-sm text-gray-600">
                  Billed monthly, cancel anytime
                </div>
              </div>

              <!-- Action Buttons -->
              <div class="flex space-x-3">
                <button phx-click="hide_upgrade_modal"
                        phx-target={@myself}
                        class="flex-1 bg-gray-200 text-gray-800 py-3 px-4 rounded-lg hover:bg-gray-300 transition-colors">
                  Maybe Later
                </button>
                <button phx-click="redirect_to_upgrade"
                        phx-value-tier={@upgrade_info.suggested_tier}
                        phx-target={@myself}
                        class="flex-1 bg-gradient-to-r from-blue-600 to-purple-600 text-white py-3 px-4 rounded-lg hover:from-blue-700 hover:to-purple-700 transition-all">
                  <%= @upgrade_info.cta %>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Event Handlers
  def handle_event("select_template", %{"template" => template_key}, socket) do
    # Check access one more time
    if UnifiedRegistry.can_access_template?(socket.assigns.current_user, template_key) do
      send(self(), {:template_selected, template_key})
      {:noreply, assign(socket, selected_template: template_key)}
    else
      {:noreply, put_flash(socket, :error, "You don't have access to this template")}
    end
  end

  def handle_event("show_upgrade_modal", %{"template" => template_key}, socket) do
    template_config = get_template_config_safe(template_key)
    upgrade_info = FeatureGate.get_template_upgrade_suggestion(
      socket.assigns.current_user,
      template_key
    )

    if upgrade_info do
      {:noreply, socket
       |> assign(show_upgrade_modal: true)
       |> assign(locked_template_key: template_key)
       |> assign(locked_template_config: template_config)
       |> assign(upgrade_info: upgrade_info)}
    else
      {:noreply, put_flash(socket, :info, "This template is already available to you!")}
    end
  end

  def handle_event("hide_upgrade_modal", _params, socket) do
    {:noreply, socket
     |> assign(show_upgrade_modal: false)
     |> assign(locked_template_key: nil)
     |> assign(locked_template_config: nil)
     |> assign(upgrade_info: nil)}
  end

  def handle_event("redirect_to_upgrade", %{"tier" => tier}, socket) do
    # Send upgrade event to parent LiveView
    send(self(), {:redirect_to_upgrade, tier})
    {:noreply, socket}
  end

  # Helper Functions
  defp get_template_gradient(template_config) do
    case Map.get(template_config, :preview_color) do
      "from-" <> _ = gradient ->
        "linear-gradient(135deg, var(--tw-gradient-stops)) #{gradient}"
      color when is_binary(color) ->
        color
      _ ->
        "linear-gradient(135deg, #e2e8f0 0%, #cbd5e1 100%)"
    end
  end

  defp render_template_preview(template_key, template_config) do
    case template_config.category do
      "minimalist" -> render_minimalist_preview()
      "professional" -> render_professional_preview()
      "creative" -> render_creative_preview()
      "technical" -> render_technical_preview()
      "audio" -> render_audio_preview()
      "gallery" -> render_gallery_preview()
      _ -> render_default_preview()
    end
  end

  defp render_minimalist_preview do
    Phoenix.HTML.raw("""
    <div class="p-3 h-full space-y-2">
      <div class="bg-white/80 rounded h-1 w-3/4"></div>
      <div class="bg-white/60 rounded h-1 w-1/2"></div>
      <div class="bg-white/80 rounded h-1 w-2/3"></div>
    </div>
    """)
  end

  defp render_professional_preview do
    Phoenix.HTML.raw("""
    <div class="p-2 h-full grid grid-cols-4 gap-1">
      <div class="bg-white/80 rounded col-span-3"></div>
      <div class="bg-white/60 rounded"></div>
      <div class="bg-white/60 rounded col-span-2"></div>
      <div class="bg-white/80 rounded col-span-2"></div>
    </div>
    """)
  end

  defp render_creative_preview do
    Phoenix.HTML.raw("""
    <div class="p-2 h-full flex space-x-1">
      <div class="flex-1 space-y-1">
        <div class="bg-white/80 rounded h-6"></div>
        <div class="bg-white/60 rounded h-4"></div>
      </div>
      <div class="flex-1 space-y-1">
        <div class="bg-white/60 rounded h-4"></div>
        <div class="bg-white/80 rounded h-6"></div>
      </div>
    </div>
    """)
  end

  defp render_technical_preview do
    Phoenix.HTML.raw("""
    <div class="p-2 h-full font-mono text-xs">
      <div class="bg-green-400/80 rounded w-2 h-2 mb-1"></div>
      <div class="space-y-1">
        <div class="bg-white/80 rounded h-1 w-full"></div>
        <div class="bg-white/60 rounded h-1 w-3/4"></div>
        <div class="bg-white/80 rounded h-1 w-5/6"></div>
      </div>
    </div>
    """)
  end

  defp render_audio_preview do
    Phoenix.HTML.raw("""
    <div class="p-2 h-full flex items-center">
      <div class="flex space-x-1 items-end">
        <div class="bg-white/60 w-1 h-4"></div>
        <div class="bg-white/80 w-1 h-6"></div>
        <div class="bg-white/90 w-1 h-8"></div>
        <div class="bg-white/70 w-1 h-5"></div>
        <div class="bg-white/60 w-1 h-3"></div>
      </div>
    </div>
    """)
  end

  defp render_gallery_preview do
    Phoenix.HTML.raw("""
    <div class="p-1 h-full grid grid-cols-3 gap-1">
      <div class="bg-white/80 rounded"></div>
      <div class="bg-white/60 rounded"></div>
      <div class="bg-white/80 rounded"></div>
      <div class="bg-white/60 rounded col-span-2"></div>
      <div class="bg-white/80 rounded"></div>
    </div>
    """)
  end

  defp render_default_preview do
    Phoenix.HTML.raw("""
    <div class="p-2 h-full flex items-center justify-center">
      <div class="bg-white/70 rounded-full w-8 h-8"></div>
    </div>
    """)
  end

  defp get_template_config_safe(template_key) do
    try do
      UnifiedRegistry.get_unified_template_config(template_key)
    rescue
      _ -> %{name: "Template", description: "Design template"}
    end
  end
end
