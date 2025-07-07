# lib/frestyl_web/live/portfolio_hub_live/dynamic_card_section.ex
defmodule FrestylWeb.PortfolioHubLive.DynamicCardSection do
  @moduledoc """
  Hub integration for Dynamic Card Layouts - extends PortfolioHubLive
  with new layout options and monetization-focused portfolio creation.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Accounts.BrandSettings
  alias Frestyl.Features.TierManager

  @impl true
  def update(assigns, socket) do
    account = assigns.account
    user = assigns.user

    # Get available card layout categories based on subscription
    available_categories = get_available_card_categories(account.subscription_tier)

    # Check for existing brand settings
    brand_settings = get_or_create_brand_settings(account)

    # Get layout usage analytics
    layout_analytics = get_layout_usage_analytics(user.id)

    # Get monetization readiness score
    monetization_score = calculate_monetization_readiness(user, account)

    {:ok, socket
      |> assign(assigns)
      |> assign(:available_categories, available_categories)
      |> assign(:brand_settings, brand_settings)
      |> assign(:layout_analytics, layout_analytics)
      |> assign(:monetization_score, monetization_score)
      |> assign(:show_card_layout_modal, false)
      |> assign(:selected_category, nil)
      |> assign(:preview_template, nil)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-section">
      <!-- Section Header -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-xl font-bold text-gray-900 flex items-center">
            <div class="w-8 h-8 bg-gradient-to-br from-purple-600 to-pink-600 rounded-lg flex items-center justify-center mr-3">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            Dynamic Card Layouts
            <span class="ml-2 text-sm px-2 py-1 bg-purple-100 text-purple-700 rounded-full font-medium">
              New
            </span>
          </h2>
          <p class="text-gray-600 mt-1">
            Brand-controllable design system with monetization showcase
          </p>
        </div>

        <button
          phx-click="show_card_layout_modal"
          phx-target={@myself}
          class="inline-flex items-center px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg hover:from-purple-700 hover:to-pink-700 transition-all duration-200 transform hover:scale-105">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Create Dynamic Layout
        </button>
      </div>

      <!-- Monetization Readiness Score -->
      <%= if @monetization_score do %>
        <div class="bg-gradient-to-r from-green-50 to-emerald-50 border border-green-200 rounded-xl p-4 mb-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-3">
                <svg class="w-5 h-5 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"/>
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd"/>
                </svg>
              </div>
              <div>
                <h3 class="font-semibold text-green-900">Monetization Readiness</h3>
                <p class="text-sm text-green-700">
                  Your portfolio is <%= @monetization_score.percentage %>% ready for monetization
                </p>
              </div>
            </div>

            <div class="text-right">
              <div class="text-2xl font-bold text-green-600"><%= @monetization_score.percentage %>%</div>
              <div class="w-24 h-2 bg-green-200 rounded-full mt-1">
                <div class="h-2 bg-green-600 rounded-full" style={"width: #{@monetization_score.percentage}%"}></div>
              </div>
            </div>
          </div>

          <%= if @monetization_score.next_steps && length(@monetization_score.next_steps) > 0 do %>
            <div class="mt-3 pt-3 border-t border-green-200">
              <p class="text-sm font-medium text-green-900 mb-2">Quick wins to improve:</p>
              <div class="flex flex-wrap gap-2">
                <%= for step <- Enum.take(@monetization_score.next_steps, 3) do %>
                  <span class="text-xs px-2 py-1 bg-green-100 text-green-700 rounded-full">
                    <%= step %>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Layout Categories Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <%= for category <- @available_categories do %>
          <div class="group cursor-pointer"
               phx-click="preview_category"
               phx-value-category={category.key}
               phx-target={@myself}>

            <div class={[
              "relative overflow-hidden rounded-xl border-2 transition-all duration-300",
              "group-hover:border-purple-300 group-hover:shadow-lg group-hover:scale-105",
              if(category.tier_required != :personal, do: "border-amber-300 bg-gradient-to-br from-amber-50 to-orange-50", else: "border-gray-200 bg-white")
            ]}>

              <!-- Category Header -->
              <div class="p-4 border-b border-gray-100">
                <div class="flex items-center justify-between mb-2">
                  <h3 class="font-semibold text-gray-900 flex items-center">
                    <span class="text-2xl mr-2"><%= category.icon %></span>
                    <%= category.name %>
                  </h3>

                  <%= if category.tier_required != :personal do %>
                    <span class="text-xs px-2 py-1 bg-amber-100 text-amber-700 rounded-full font-medium">
                      <%= String.capitalize(to_string(category.tier_required)) %>+
                    </span>
                  <% end %>
                </div>
                <p class="text-sm text-gray-600"><%= category.description %></p>
              </div>

              <!-- Category Preview -->
              <div class="p-4">
                <div class="space-y-2 mb-4">
                  <%= for feature <- Enum.take(category.key_features, 3) do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <%= feature %>
                    </div>
                  <% end %>
                </div>

                <!-- Monetization Level -->
                <div class="flex items-center justify-between">
                  <span class="text-xs text-gray-500">Monetization Focus:</span>
                  <div class="flex">
                    <%= for i <- 1..3 do %>
                      <svg class={[
                        "w-3 h-3",
                        if(i <= category.monetization_level, do: "text-green-500", else: "text-gray-300")
                      ]} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"/>
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd"/>
                      </svg>
                    <% end %>
                  </div>
                </div>
              </div>

              <!-- Hover Action -->
              <div class="absolute inset-0 bg-purple-600 bg-opacity-0 group-hover:bg-opacity-10 transition-all duration-200 flex items-center justify-center">
                <div class="opacity-0 group-hover:opacity-100 transition-opacity">
                  <div class="bg-white text-purple-600 px-4 py-2 rounded-full text-sm font-medium shadow-lg">
                    Preview Layout
                  </div>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Brand Control Preview -->
      <%= if @brand_settings do %>
        <div class="bg-white border border-gray-200 rounded-xl p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-semibold text-gray-900">Brand Control Framework</h3>
            <button
              phx-click="edit_brand_settings"
              phx-target={@myself}
              class="text-sm text-purple-600 hover:text-purple-700 font-medium">
              Customize
            </button>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <!-- Color System -->
            <div class="text-center">
              <div class="flex justify-center space-x-1 mb-2">
                <div class="w-6 h-6 rounded-full border border-gray-300"
                     style={"background-color: #{@brand_settings.primary_color}"}></div>
                <div class="w-6 h-6 rounded-full border border-gray-300"
                     style={"background-color: #{@brand_settings.secondary_color}"}></div>
                <div class="w-6 h-6 rounded-full border border-gray-300"
                     style={"background-color: #{@brand_settings.accent_color}"}></div>
              </div>
              <p class="text-sm font-medium text-gray-900">Brand Colors</p>
              <p class="text-xs text-gray-500">
                <%= if @brand_settings.enforce_brand_colors, do: "Locked", else: "Customizable" %>
              </p>
            </div>

            <!-- Typography System -->
            <div class="text-center">
              <div class="mb-2">
                <span class="text-lg font-semibold" style={"font-family: #{@brand_settings.primary_font};"}>
                  Aa
                </span>
              </div>
              <p class="text-sm font-medium text-gray-900">Typography</p>
              <p class="text-xs text-gray-500">
                <%= @brand_settings.primary_font %>
              </p>
            </div>

            <!-- Monetization Preferences -->
            <div class="text-center">
              <div class="flex justify-center space-x-1 mb-2">
                <%= if @brand_settings.show_pricing_by_default do %>
                  <div class="w-6 h-6 bg-green-100 rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"/>
                    </svg>
                  </div>
                <% end %>
                <%= if @brand_settings.show_booking_widgets_by_default do %>
                  <div class="w-6 h-6 bg-blue-100 rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                  </div>
                <% end %>
              </div>
              <p class="text-sm font-medium text-gray-900">Monetization</p>
              <p class="text-xs text-gray-500">
                <%= @brand_settings.default_currency %> • <%= @brand_settings.price_display_format %>
              </p>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Usage Analytics -->
      <%= if @layout_analytics && @layout_analytics.total_portfolios > 0 do %>
        <div class="bg-gray-50 border border-gray-200 rounded-xl p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Your Layout Analytics</h3>

          <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600"><%= @layout_analytics.total_portfolios %></div>
              <p class="text-sm text-gray-600">Dynamic Layouts</p>
            </div>

            <div class="text-center">
              <div class="text-2xl font-bold text-green-600">
                <%= @layout_analytics.avg_monetization_rate %>%
              </div>
              <p class="text-sm text-gray-600">Avg. Monetization Rate</p>
            </div>

            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">
                <%= @layout_analytics.most_popular_category %>
              </div>
              <p class="text-sm text-gray-600">Top Category</p>
            </div>

            <div class="text-center">
              <div class="text-2xl font-bold text-orange-600">
                <%= @layout_analytics.total_views %>
              </div>
              <p class="text-sm text-gray-600">Total Views</p>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Create Dynamic Layout Modal -->
      <%= if @show_card_layout_modal do %>
        <%= render_card_layout_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("show_card_layout_modal", _params, socket) do
    {:noreply, assign(socket, :show_card_layout_modal, true)}
  end

  @impl true
  def handle_event("close_card_layout_modal", _params, socket) do
    {:noreply, socket
      |> assign(:show_card_layout_modal, false)
      |> assign(:selected_category, nil)
      |> assign(:preview_template, nil)
    }
  end

  @impl true
  def handle_event("preview_category", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)
    preview_template = get_category_preview_template(category_atom)

    {:noreply, socket
      |> assign(:selected_category, category_atom)
      |> assign(:preview_template, preview_template)
      |> assign(:show_card_layout_modal, true)
    }
  end

  @impl true
  def handle_event("create_portfolio_with_layout", %{"category" => category, "template" => template}, socket) do
    # Send event to parent LiveView to handle portfolio creation
    send(self(), {:create_dynamic_card_portfolio, category, template, socket.assigns.account})

    {:noreply, socket
      |> assign(:show_card_layout_modal, false)
      |> put_flash(:info, "Creating your dynamic card layout portfolio...")
    }
  end

  @impl true
  def handle_event("edit_brand_settings", _params, socket) do
    # Send event to parent to show brand settings editor
    send(self(), {:show_brand_settings_editor, socket.assigns.brand_settings})
    {:noreply, socket}
  end

  # ============================================================================
  # MODAL RENDERING
  # ============================================================================

  defp render_card_layout_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-click="close_card_layout_modal"
         phx-target={@myself}>

      <div class="bg-white rounded-2xl max-w-6xl w-full max-h-screen overflow-y-auto"
           phx-click-away="close_card_layout_modal"
           phx-target={@myself}>

        <!-- Modal Header -->
        <div class="sticky top-0 bg-white border-b border-gray-200 p-6 z-10">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-2xl font-bold text-gray-900">Create Dynamic Card Layout</h2>
              <p class="text-gray-600 mt-1">
                Choose a category that best showcases your talents and monetization opportunities
              </p>
            </div>
            <button
              phx-click="close_card_layout_modal"
              phx-target={@myself}
              class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6">
          <%= if @selected_category do %>
            <!-- Category Preview Mode -->
            <%= render_category_preview_mode(assigns) %>
          <% else %>
            <!-- Category Selection Mode -->
            <%= render_category_selection_mode(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_category_selection_mode(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-8">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">
          Select Your Portfolio Category
        </h3>
        <p class="text-gray-600">
          Each category is optimized for different types of talent showcase and monetization
        </p>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for category <- @available_categories do %>
          <button
            phx-click="preview_category"
            phx-value-category={category.key}
            phx-target={@myself}
            class="group text-left p-6 border-2 border-gray-200 rounded-xl hover:border-purple-300 hover:shadow-lg transition-all duration-200">

            <div class="flex items-start space-x-4">
              <div class="text-4xl"><%= category.icon %></div>

              <div class="flex-1">
                <div class="flex items-center space-x-2 mb-2">
                  <h4 class="text-lg font-semibold text-gray-900">
                    <%= category.name %>
                  </h4>
                  <%= if category.tier_required != :personal do %>
                    <span class="text-xs px-2 py-1 bg-amber-100 text-amber-700 rounded-full">
                      <%= String.capitalize(to_string(category.tier_required)) %>+
                    </span>
                  <% end %>
                </div>

                <p class="text-gray-600 mb-3"><%= category.description %></p>

                <div class="space-y-1 mb-3">
                  <%= for feature <- Enum.take(category.key_features, 4) do %>
                    <div class="flex items-center text-sm text-gray-600">
                      <svg class="w-3 h-3 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <%= feature %>
                    </div>
                  <% end %>
                </div>

                <div class="flex items-center justify-between">
                  <span class="text-sm text-gray-500">Monetization Focus:</span>
                  <div class="flex">
                    <%= for i <- 1..3 do %>
                      <svg class={[
                        "w-4 h-4",
                        if(i <= category.monetization_level, do: "text-green-500", else: "text-gray-300")
                      ]} fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"/>
                      </svg>
                    <% end %>
                  </div>
                </div>
              </div>
            </div>

            <div class="mt-4 opacity-0 group-hover:opacity-100 transition-opacity">
              <div class="text-center py-2 bg-purple-50 text-purple-600 rounded-lg text-sm font-medium">
                Preview Templates →
              </div>
            </div>
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_category_preview_mode(assigns) do
    category_config = get_category_config(@selected_category)
    available_templates = get_category_templates(@selected_category)

    assigns = assigns
    |> assign(:category_config, category_config)
    |> assign(:available_templates, available_templates)

    ~H"""
    <div class="space-y-6">
      <!-- Category Header -->
      <div class="flex items-center space-x-4 pb-6 border-b border-gray-200">
        <button
          phx-click="preview_category"
          phx-value-category=""
          phx-target={@myself}
          class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
        </button>

        <div class="flex-1">
          <div class="flex items-center space-x-3">
            <span class="text-3xl"><%= @category_config.icon %></span>
            <div>
              <h3 class="text-xl font-bold text-gray-900">
                <%= @category_config.name %> Layout
              </h3>
              <p class="text-gray-600"><%= @category_config.description %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Template Selection -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Choose Your Template</h4>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <%= for template <- @available_templates do %>
            <div class="group cursor-pointer"
                 phx-click="create_portfolio_with_layout"
                 phx-value-category={@selected_category}
                 phx-value-template={template.key}
                 phx-target={@myself}>

              <div class="border-2 border-gray-200 rounded-xl overflow-hidden group-hover:border-purple-300 group-hover:shadow-lg transition-all duration-200">
                <!-- Template Preview -->
                <div class="h-40 bg-gradient-to-br from-gray-50 to-gray-100 p-4">
                  <%= render_template_preview(template.key, assigns) %>
                </div>

                <!-- Template Info -->
                <div class="p-4">
                  <h5 class="font-semibold text-gray-900 mb-2"><%= template.name %></h5>
                  <p class="text-sm text-gray-600 mb-3"><%= template.description %></p>

                  <!-- Featured Blocks -->
                  <div class="space-y-2">
                    <p class="text-xs font-medium text-gray-500">Includes:</p>
                    <div class="flex flex-wrap gap-1">
                      <%= for block_type <- Enum.take(template.featured_blocks, 4) do %>
                        <span class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded">
                          <%= humanize_block_type(block_type) %>
                        </span>
                      <% end %>
                    </div>
                  </div>

                  <!-- Monetization Emphasis -->
                  <div class="flex items-center justify-between mt-3 pt-3 border-t border-gray-100">
                    <span class="text-xs text-gray-500">Monetization Focus:</span>
                    <div class="flex">
                      <%= for i <- 1..3 do %>
                        <svg class={[
                          "w-3 h-3",
                          if(i <= template.monetization_emphasis_level, do: "text-green-500", else: "text-gray-300")
                        ]} fill="currentColor" viewBox="0 0 20 20">
                          <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582z"/>
                        </svg>
                      <% end %>
                    </div>
                  </div>
                </div>

                <!-- Hover Action -->
                <div class="absolute inset-0 bg-purple-600 bg-opacity-0 group-hover:bg-opacity-10 transition-all duration-200 flex items-center justify-center">
                  <div class="opacity-0 group-hover:opacity-100 transition-opacity">
                    <div class="bg-purple-600 text-white px-6 py-3 rounded-lg font-medium shadow-lg">
                      Create Portfolio
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_available_card_categories(subscription_tier) do
    normalized_tier = TierManager.normalize_tier(subscription_tier)

    base_categories = [
      %{
        key: :service_provider,
        name: "Professional Service Provider",
        description: "Emphasizes booking/pricing with trust-building elements",
        icon: "💼",
        tier_required: "personal",
        monetization_level: 3
      },
      %{
        key: :creative_showcase,
        name: "Creative Showcase",
        description: "Portfolio-focused with commission options",
        icon: "🎨",
        tier_required: "personal",
        monetization_level: 2
      }
    ]

    case normalized_tier do
      tier when tier in ["creator", "professional", "enterprise"] ->
        base_categories ++ [
          %{
            key: :technical_expert,
            name: "Technical Expert",
            description: "Skill-based with project pricing",
            icon: "⚡",
            tier_required: "creator",
            monetization_level: 3
          },
          %{
            key: :content_creator,
            name: "Content Creator/Performer",
            description: "Streaming-focused with subscription options",
            icon: "📱",
            tier_required: "creator",
            monetization_level: 3
          }
        ]
      _ ->
        base_categories
    end
  end

  defp get_or_create_brand_settings(account) do
    case Frestyl.Accounts.get_brand_settings_by_account(account.id) do
      nil ->
        # Create default brand settings
        {:ok, brand_settings} = Frestyl.Accounts.create_brand_settings(%{
          account_id: account.id
        })
        brand_settings

      existing_settings -> existing_settings
    end
  end

  defp get_layout_usage_analytics(user_id) do
    # Mock analytics - replace with actual implementation
    %{
      total_portfolios: 3,
      avg_monetization_rate: 67,
      most_popular_category: "Service Provider",
      total_views: 1247
    }
  end

  defp calculate_monetization_readiness(user, account) do
    # Analyze user's portfolios and account settings to determine monetization readiness
    score_factors = [
      has_payment_method: account.payment_method_configured || false,
      has_pricing_set: false, # Check if any portfolios have pricing
      has_testimonials: false, # Check for testimonials
      has_portfolio_content: true, # At least one portfolio exists
      subscription_supports_monetization: account.subscription_tier in ["creator", "professional", "enterprise"]
    ]

    total_factors = length(score_factors)
    completed_factors = Enum.count(score_factors, fn {_key, value} -> value end)
    percentage = round((completed_factors / total_factors) * 100)

    next_steps = determine_next_monetization_steps(score_factors)

    %{
      percentage: percentage,
      next_steps: next_steps,
      factors: score_factors
    }
  end

  defp determine_next_monetization_steps(score_factors) do
    steps = []

    steps = if !score_factors[:has_payment_method] do
      ["Set up payment method" | steps]
    else
      steps
    end

    steps = if !score_factors[:has_pricing_set] do
      ["Add pricing to services" | steps]
    else
      steps
    end

    steps = if !score_factors[:has_testimonials] do
      ["Collect client testimonials" | steps]
    else
      steps
    end

    Enum.reverse(steps)
  end

  defp get_category_preview_template(category) do
    case category do
      :service_provider -> "professional_service_provider"
      :creative_showcase -> "creative_portfolio_showcase"
      :technical_expert -> "technical_expert_dashboard"
      :content_creator -> "content_creator_hub"
      :corporate_executive -> "corporate_executive_profile"
      _ -> "professional_service_provider"
    end
  end

  defp get_category_config(category) do
    available_categories = get_available_card_categories("professional")
    Enum.find(available_categories, fn cat -> cat.key == category end)
  end

  defp get_category_templates(category) do
    DynamicCardBlocks.get_available_layouts_for_category(category)
  end

defp render_template_preview(template_key, assigns) do
    assigns = assign(assigns, :template_key, template_key)

    ~H"""
    <div class="h-full">
      <%= case @template_key do %>
        <% "professional_service_provider" -> %>
          <div class="space-y-3 h-full">
            <div class="h-6 bg-blue-300 rounded"></div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-12 bg-blue-200 rounded"></div>
              <div class="h-12 bg-green-200 rounded"></div>
            </div>
            <div class="h-4 bg-purple-200 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-8 bg-gray-200 rounded"></div>
              <div class="h-8 bg-gray-200 rounded"></div>
              <div class="h-8 bg-orange-200 rounded"></div>
            </div>
          </div>

        <% "creative_portfolio_showcase" -> %>
          <div class="space-y-2 h-full">
            <div class="h-4 bg-purple-300 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-16 bg-pink-200 rounded"></div>
              <div class="h-16 bg-purple-200 rounded"></div>
              <div class="h-16 bg-indigo-200 rounded"></div>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-6 bg-purple-200 rounded"></div>
              <div class="h-6 bg-pink-200 rounded"></div>
            </div>
          </div>

        <% "technical_expert_dashboard" -> %>
          <div class="space-y-2 h-full">
            <div class="h-3 bg-gray-400 rounded"></div>
            <div class="grid grid-cols-4 gap-1">
              <div class="h-6 bg-blue-300 rounded"></div>
              <div class="h-6 bg-green-300 rounded"></div>
              <div class="h-6 bg-yellow-300 rounded"></div>
              <div class="h-6 bg-red-300 rounded"></div>
            </div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-12 bg-gray-300 rounded"></div>
              <div class="h-12 bg-indigo-200 rounded"></div>
            </div>
            <div class="h-4 bg-blue-200 rounded"></div>
          </div>

        <% "content_creator_hub" -> %>
          <div class="space-y-2 h-full">
            <div class="h-4 bg-pink-400 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-6 bg-pink-200 rounded-full"></div>
              <div class="h-6 bg-purple-200 rounded-full"></div>
              <div class="h-6 bg-blue-200 rounded-full"></div>
            </div>
            <div class="h-8 bg-gradient-to-r from-pink-200 to-purple-200 rounded"></div>
            <div class="grid grid-cols-2 gap-1">
              <div class="h-6 bg-yellow-200 rounded"></div>
              <div class="h-6 bg-green-200 rounded"></div>
            </div>
          </div>

        <% "corporate_executive_profile" -> %>
          <div class="space-y-2 h-full">
            <div class="h-5 bg-slate-400 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-8 bg-blue-200 rounded"></div>
              <div class="h-8 bg-green-200 rounded"></div>
              <div class="h-8 bg-gray-200 rounded"></div>
            </div>
            <div class="h-6 bg-slate-300 rounded"></div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-4 bg-blue-200 rounded"></div>
              <div class="h-4 bg-gray-300 rounded"></div>
            </div>
          </div>

        <% _ -> %>
          <div class="h-full bg-gray-200 rounded flex items-center justify-center">
            <span class="text-xs text-gray-500">Template Preview</span>
          </div>
      <% end %>
    </div>
    """
  end

  defp humanize_block_type(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  # ============================================================================
  # ADDITIONAL HELPER FUNCTIONS
  # ============================================================================

  defp get_monetization_emphasis_level(template) do
    case template.monetization_emphasis do
      :very_high -> 3
      :high -> 3
      :medium -> 2
      :low -> 1
      _ -> 2
    end
  end

  defp format_category_name(category_key) do
    category_key
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp can_access_category?(category, subscription_tier) do
    user_tier = TierManager.normalize_tier(subscription_tier)
    required_tier = Map.get(category, :tier_required, "personal")

    TierManager.has_tier_access?(user_tier, required_tier)
  end

  defp get_subscription_upgrade_message(current_tier, required_tier) do
    current_normalized = TierManager.normalize_tier(current_tier)
    required_normalized = TierManager.normalize_tier(required_tier)

    case {current_normalized, required_normalized} do
      {"personal", "creator"} ->
        "Upgrade to Creator to unlock advanced monetization blocks and content metrics."
      {"personal", "professional"} ->
        "Upgrade to Professional to access enterprise features and brand partnerships."
      {"creator", "professional"} ->
        "Upgrade to Professional for advanced analytics and brand control."
      {_, "enterprise"} ->
        "Contact sales for enterprise features and custom brand control."
      _ ->
        "Upgrade your account to access more layout options."
    end
  end

  # Mock functions - these would be replaced with actual implementations
  defp mock_portfolio_count_by_category do
    %{
      service_provider: 2,
      creative_showcase: 1,
      technical_expert: 0,
      content_creator: 0,
      corporate_executive: 0
    }
  end

  defp mock_average_conversion_rate_by_category do
    %{
      service_provider: 12.5,
      creative_showcase: 8.3,
      technical_expert: 15.2,
      content_creator: 6.7,
      corporate_executive: 18.9
    }
  end

  defp format_percentage(value) when is_number(value) do
    :erlang.float_to_binary(value, [{:decimals, 1}])
  end
  defp format_percentage(_), do: "0.0"

  # ============================================================================
  # TEMPLATE CONFIGURATION HELPERS
  # ============================================================================

  defp get_template_monetization_features(template_key) do
    case template_key do
      "professional_service_provider" -> [
        "Direct booking integration",
        "Pricing display optimization",
        "Client testimonial showcase",
        "Service package comparison"
      ]
      "creative_portfolio_showcase" -> [
        "Commission inquiry forms",
        "Portfolio licensing options",
        "Collaboration showcase",
        "Creative process highlight"
      ]
      "technical_expert_dashboard" -> [
        "Consultation booking calendar",
        "Skill-based pricing",
        "Project case studies",
        "Technical blog integration"
      ]
      "content_creator_hub" -> [
        "Subscription tier display",
        "Brand partnership showcase",
        "Content metrics dashboard",
        "Community engagement tools"
      ]
      "corporate_executive_profile" -> [
        "Executive consultation booking",
        "Achievement metrics display",
        "Thought leadership content",
        "Speaking engagement calendar"
      ]
      _ -> []
    end
  end

  defp get_template_ideal_for(template_key) do
    case template_key do
      "professional_service_provider" ->
        "Consultants, coaches, freelancers, and service-based businesses"
      "creative_portfolio_showcase" ->
        "Designers, artists, photographers, and creative professionals"
      "technical_expert_dashboard" ->
        "Developers, engineers, technical consultants, and IT professionals"
      "content_creator_hub" ->
        "YouTubers, streamers, influencers, and content creators"
      "corporate_executive_profile" ->
        "C-level executives, business leaders, and thought leaders"
      _ ->
        "Professional portfolio showcase"
    end
  end

  defp get_estimated_setup_time(template_key) do
    case template_key do
      "professional_service_provider" -> "15-30 minutes"
      "creative_portfolio_showcase" -> "20-45 minutes"
      "technical_expert_dashboard" -> "25-40 minutes"
      "content_creator_hub" -> "30-60 minutes"
      "corporate_executive_profile" -> "20-35 minutes"
      _ -> "15-30 minutes"
    end
  end

  # ============================================================================
  # ANALYTICS AND INSIGHTS HELPERS
  # ============================================================================

  defp calculate_template_popularity_score(template_key) do
    # This would calculate based on actual usage data
    base_scores = %{
      "professional_service_provider" => 85,
      "creative_portfolio_showcase" => 78,
      "technical_expert_dashboard" => 71,
      "content_creator_hub" => 92,
      "corporate_executive_profile" => 66
    }

    Map.get(base_scores, template_key, 50)
  end

  defp get_template_success_metrics(template_key) do
    # Mock success metrics - would be real data in production
    case template_key do
      "professional_service_provider" -> %{
        avg_conversion_rate: 12.3,
        avg_monthly_bookings: 8.7,
        client_satisfaction: 4.6
      }
      "creative_portfolio_showcase" -> %{
        avg_inquiry_rate: 15.8,
        avg_project_value: 2450,
        portfolio_engagement: 4.2
      }
      "technical_expert_dashboard" -> %{
        avg_consultation_rate: 18.5,
        avg_hourly_rate: 125,
        technical_credibility: 4.8
      }
      "content_creator_hub" -> %{
        avg_subscriber_growth: 23.2,
        brand_partnership_rate: 6.4,
        content_engagement: 4.1
      }
      "corporate_executive_profile" -> %{
        thought_leadership_score: 78,
        speaking_bookings: 3.2,
        professional_network_growth: 15.6
      }
      _ -> %{}
    end
  end

  # ============================================================================
  # BRAND INTEGRATION HELPERS
  # ============================================================================

  defp apply_brand_styling_to_template_preview(template_key, brand_settings) do
    base_styles = get_template_base_styles(template_key)
    brand_overrides = generate_brand_css_overrides(brand_settings)

    """
    <style>
      #{base_styles}
      #{brand_overrides}
    </style>
    """
  end

  defp get_template_base_styles(template_key) do
    case template_key do
      "professional_service_provider" ->
        """
        .template-preview {
          background: linear-gradient(135deg, #dbeafe 0%, #bfdbfe 100%);
        }
        """
      "creative_portfolio_showcase" ->
        """
        .template-preview {
          background: linear-gradient(135deg, #fce7f3 0%, #f3e8ff 100%);
        }
        """
      _ -> ""
    end
  end

  defp generate_brand_css_overrides(brand_settings) do
    if brand_settings.enforce_brand_colors do
      """
      .template-preview {
        --brand-primary: #{brand_settings.primary_color};
        --brand-accent: #{brand_settings.accent_color};
        border-left: 4px solid var(--brand-primary);
      }
      """
    else
      ""
    end
  end

  # ============================================================================
  # ACCESSIBILITY AND USER EXPERIENCE HELPERS
  # ============================================================================

  defp get_template_accessibility_score(template_key) do
    # Based on color contrast, keyboard navigation, screen reader support
    case template_key do
      "professional_service_provider" -> 92
      "creative_portfolio_showcase" -> 88
      "technical_expert_dashboard" -> 94
      "content_creator_hub" -> 85
      "corporate_executive_profile" -> 91
      _ -> 85
    end
  end

  defp get_mobile_optimization_score(template_key) do
    # All templates should be mobile-first, but some may be more optimized
    case template_key do
      "professional_service_provider" -> 95
      "creative_portfolio_showcase" -> 91
      "technical_expert_dashboard" -> 88
      "content_creator_hub" -> 97
      "corporate_executive_profile" -> 89
      _ -> 90
    end
  end

  defp get_seo_optimization_features(template_key) do
    base_features = [
      "Semantic HTML structure",
      "Open Graph meta tags",
      "Schema.org markup",
      "Fast loading optimized"
    ]

    template_specific = case template_key do
      "professional_service_provider" -> ["Local business schema", "Service markup"]
      "creative_portfolio_showcase" -> ["Portfolio schema", "Creative work markup"]
      "technical_expert_dashboard" -> ["Professional profile schema", "Skill markup"]
      "content_creator_hub" -> ["Creator profile schema", "Content markup"]
      "corporate_executive_profile" -> ["Executive profile schema", "Organization markup"]
      _ -> []
    end

    base_features ++ template_specific
  end

  # ============================================================================
  # INTEGRATION TESTING HELPERS (for development)
  # ============================================================================

  defp validate_template_configuration(template_key) do
    required_fields = [:name, :description, :featured_blocks, :monetization_emphasis]
    template_config = get_category_templates(:service_provider)
                     |> Enum.find(&(&1.layout_key == template_key))

    if template_config do
      missing_fields = required_fields -- Map.keys(template_config)
      case missing_fields do
        [] -> {:ok, template_config}
        missing -> {:error, "Missing required fields: #{Enum.join(missing, ", ")}"}
      end
    else
      {:error, "Template configuration not found: #{template_key}"}
    end
  end

  defp log_template_selection(template_key, user_id, account_tier) do
    # In production, this would log to analytics
    IO.puts("Template selected: #{template_key} by user #{user_id} (#{account_tier})")
  end

  defp track_monetization_feature_usage(feature_name, user_id) do
    # Track which monetization features are being used
    IO.puts("Monetization feature used: #{feature_name} by user #{user_id}")
  end
end
