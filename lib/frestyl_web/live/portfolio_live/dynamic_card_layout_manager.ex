# lib/frestyl_web/live/portfolio_live/dynamic_card_layout_manager.ex
defmodule FrestylWeb.PortfolioLive.DynamicCardLayoutManager do
  @moduledoc """
  Dynamic Card Layout Manager - Arranges content blocks into brand-controllable
  layouts that work across all portfolio templates with monetization focus.

  Follows the PortfolioEditor framework for unified state management.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Accounts.BrandSettings

  # ============================================================================
  # COMPONENT LIFECYCLE
  # ============================================================================

  @impl true
  def mount(socket) do
    {:ok, socket
      |> assign(:layout_mode, :edit)
      |> assign(:active_category, :service_provider)
      |> assign(:preview_device, :desktop)
      |> assign(:brand_preview_mode, false)
      |> assign(:block_drag_active, false)
      |> assign(:layout_dirty, false)
    }
  end

  @impl true
  def update(assigns, socket) do
    # Following PortfolioEditor pattern for account-aware features
    account = assigns.account
    features = assigns.features || %{}
    brand_settings = assigns.brand_settings

    # Get available blocks based on subscription tier
    available_blocks = DynamicCardBlocks.get_blocks_by_monetization_tier(account.subscription_tier)

    # Get current layout configuration
    layout_config = get_current_layout_config(assigns.portfolio, brand_settings)

    # Organize content blocks by layout zones
    layout_zones = organize_blocks_into_zones(assigns.content_blocks, layout_config)

    {:ok, socket
      |> assign(assigns)
      |> assign(:available_blocks, available_blocks)
      |> assign(:layout_config, layout_config)
      |> assign(:layout_zones, layout_zones)
      |> assign(:can_monetize, features.monetization_enabled || false)
      |> assign(:can_customize_brand, features.custom_branding || false)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-layout-manager"
         id={"layout-manager-#{@portfolio.id}"}
         phx-hook="DynamicCardLayout">

      <!-- Layout Control Header -->
      <div class="layout-header bg-white border-b border-gray-200 p-4">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <h3 class="text-lg font-semibold text-gray-900">Dynamic Card Layout</h3>

            <!-- Category Selector -->
            <div class="flex space-x-2">
              <%= for category <- get_available_categories(@account.subscription_tier) do %>
                <button
                  phx-click="switch_category"
                  phx-value-category={category.key}
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 rounded-full text-sm font-medium transition-colors",
                    if(@active_category == category.key,
                      do: "bg-purple-600 text-white",
                      else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                  ]}>
                  <%= category.name %>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Layout Actions -->
          <div class="flex items-center space-x-3">
            <%= if @can_customize_brand do %>
              <button
                phx-click="toggle_brand_preview"
                phx-target={@myself}
                class={[
                  "px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                  if(@brand_preview_mode,
                    do: "bg-blue-600 text-white",
                    else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                ]}>
                <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"/>
                </svg>
                Brand Preview
              </button>
            <% end %>

            <!-- Device Preview Toggle -->
            <div class="flex bg-gray-100 rounded-lg p-1">
              <%= for device <- [:desktop, :tablet, :mobile] do %>
                <button
                  phx-click="switch_device_preview"
                  phx-value-device={device}
                  phx-target={@myself}
                  class={[
                    "px-3 py-1 rounded text-sm font-medium transition-colors",
                    if(@preview_device == device,
                      do: "bg-white text-gray-900 shadow-sm",
                      else: "text-gray-600 hover:text-gray-900")
                  ]}>
                  <%= String.capitalize(to_string(device)) %>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Main Layout Area -->
      <div class="layout-workspace flex h-full">

        <!-- Block Palette (Left Sidebar) -->
        <div class="block-palette w-80 bg-gray-50 border-r border-gray-200 p-4 overflow-y-auto">
          <h4 class="text-sm font-semibold text-gray-900 mb-4">Available Blocks</h4>

          <div class="space-y-3">
            <%= for block <- get_blocks_for_category(@available_blocks, @active_category) do %>
              <div class="block-template"
                   data-block-type={block.type}
                   draggable="true">
                <div class={[
                  "p-4 bg-white rounded-lg border-2 border-dashed border-gray-300",
                  "hover:border-purple-400 hover:bg-purple-50 transition-all cursor-grab",
                  if(block.monetization_tier != :personal, do: "border-amber-300 bg-amber-50")
                ]}>
                  <div class="flex items-start justify-between mb-2">
                    <h5 class="text-sm font-medium text-gray-900"><%= block.name %></h5>
                    <%= if block.monetization_tier != :personal do %>
                      <span class="text-xs px-2 py-1 bg-amber-100 text-amber-700 rounded-full">
                        <%= String.capitalize(to_string(block.monetization_tier)) %>+
                      </span>
                    <% end %>
                  </div>
                  <p class="text-xs text-gray-600 mb-3"><%= block.description %></p>

                  <%= if block.monetization_tier in [:creator, :professional] and @can_monetize do %>
                    <div class="flex items-center text-xs text-green-600">
                      <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582zM11 12.849v-1.698c.22.071.412.164.567.267.364.243.433.468.433.582 0 .114-.07.34-.433.582a2.305 2.305 0 01-.567.267z"/>
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm1-13a1 1 0 10-2 0v.092a4.535 4.535 0 00-1.676.662C6.602 6.234 6 7.009 6 8c0 .99.602 1.765 1.324 2.246.48.32 1.054.545 1.676.662v1.941c-.391-.127-.68-.317-.843-.504a1 1 0 10-1.51 1.31c.562.649 1.413 1.076 2.353 1.253V15a1 1 0 102 0v-.092a4.535 4.535 0 001.676-.662C13.398 13.766 14 12.991 14 12c0-.99-.602-1.765-1.324-2.246A4.535 4.535 0 0011 9.092V7.151c.391.127.68.317.843.504a1 1 0 101.511-1.31c-.563-.649-1.413-1.076-2.354-1.253V5z" clip-rule="evenodd"/>
                      </svg>
                      Monetization Ready
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Upgrade Prompt for Locked Blocks -->
          <%= if has_locked_blocks?(@available_blocks, @account.subscription_tier) do %>
            <div class="mt-6 p-4 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg border border-purple-200">
              <h5 class="text-sm font-semibold text-purple-900 mb-2">Unlock More Blocks</h5>
              <p class="text-xs text-purple-700 mb-3">Upgrade to access advanced monetization blocks and premium layouts.</p>
              <button
                phx-click="show_upgrade_modal"
                phx-target={@myself}
                class="w-full px-3 py-2 bg-purple-600 text-white text-xs font-medium rounded-lg hover:bg-purple-700 transition-colors">
                Upgrade Account
              </button>
            </div>
          <% end %>
        </div>

        <!-- Layout Canvas (Center) -->
        <div class="layout-canvas flex-1 p-6 overflow-y-auto">
          <div class={[
            "layout-preview bg-white rounded-lg shadow-sm border border-gray-200 min-h-screen",
            get_device_preview_classes(@preview_device),
            if(@brand_preview_mode, do: "brand-preview-mode")
          ]}>

            <!-- Dynamic Layout Zones -->
            <%= render_layout_zones(assigns) %>

          </div>
        </div>

        <!-- Properties Panel (Right Sidebar) -->
        <%= if @layout_mode == :edit do %>
          <div class="properties-panel w-80 bg-gray-50 border-l border-gray-200 p-4 overflow-y-auto">
            <%= render_properties_panel(assigns) %>
          </div>
        <% end %>
      </div>

      <!-- Layout Template Modal -->
      <%= if assigns[:show_layout_templates] do %>
        <%= render_layout_template_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS (Following PortfolioEditor Pattern)
  # ============================================================================

  @impl true
  def handle_event("switch_category", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)

    {:noreply, socket
      |> assign(:active_category, category_atom)
      |> assign(:layout_dirty, false)
    }
  end

  @impl true
  def handle_event("toggle_brand_preview", _params, socket) do
    new_mode = !socket.assigns.brand_preview_mode

    {:noreply, socket
      |> assign(:brand_preview_mode, new_mode)
      |> push_event("brand_preview_toggled", %{enabled: new_mode})
    }
  end

  @impl true
  def handle_event("switch_device_preview", %{"device" => device}, socket) do
    device_atom = String.to_atom(device)

    {:noreply, socket
      |> assign(:preview_device, device_atom)
      |> push_event("device_preview_changed", %{device: device})
    }
  end

  @impl true
  def handle_event("add_block_to_zone", %{"block_type" => block_type, "zone" => zone, "position" => position}, socket) do
    # Following PortfolioEditor's create_content_block pattern
    case create_dynamic_card_block(block_type, zone, position, socket) do
      {:ok, new_block} ->
        updated_zones = add_block_to_layout_zone(socket.assigns.layout_zones, zone, new_block, position)

        {:noreply, socket
          |> assign(:layout_zones, updated_zones)
          |> assign(:layout_dirty, true)
          |> put_flash(:info, "Block added successfully")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{reason}")}
    end
  end

  @impl true
  def handle_event("remove_block_from_zone", %{"block_id" => block_id, "zone" => zone}, socket) do
    case remove_block_from_layout(block_id, zone, socket) do
      {:ok, updated_zones} ->
        {:noreply, socket
          |> assign(:layout_zones, updated_zones)
          |> assign(:layout_dirty, true)
          |> put_flash(:info, "Block removed")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to remove block: #{reason}")}
    end
  end

  @impl true
  def handle_event("reorder_blocks_in_zone", %{"zone" => zone, "block_order" => order}, socket) do
    updated_zones = reorder_zone_blocks(socket.assigns.layout_zones, zone, order)

    {:noreply, socket
      |> assign(:layout_zones, updated_zones)
      |> assign(:layout_dirty, true)
    }
  end

  @impl true
  def handle_event("save_layout", _params, socket) do
    case save_dynamic_card_layout(socket.assigns.layout_zones, socket.assigns.portfolio) do
      {:ok, _portfolio} ->
        {:noreply, socket
          |> assign(:layout_dirty, false)
          |> put_flash(:info, "Layout saved successfully")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout: #{reason}")}
    end
  end

  @impl true
  def handle_event("apply_layout_template", %{"template_key" => template_key}, socket) do
    case apply_predefined_layout_template(template_key, socket) do
      {:ok, new_layout_zones} ->
        {:noreply, socket
          |> assign(:layout_zones, new_layout_zones)
          |> assign(:layout_dirty, true)
          |> assign(:show_layout_templates, false)
          |> put_flash(:info, "Layout template applied")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to apply template: #{reason}")}
    end
  end

  # ============================================================================
  # LAYOUT ZONE RENDERING
  # ============================================================================

  defp render_layout_zones(assigns) do
    ~H"""
    <div class="dynamic-layout-zones p-6">
      <%= case @active_category do %>
        <% :service_provider -> %>
          <%= render_service_provider_layout(assigns) %>
        <% :creative_showcase -> %>
          <%= render_creative_showcase_layout(assigns) %>
        <% :technical_expert -> %>
          <%= render_technical_expert_layout(assigns) %>
        <% :content_creator -> %>
          <%= render_content_creator_layout(assigns) %>
        <% :corporate_executive -> %>
          <%= render_corporate_executive_layout(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_service_provider_layout(assigns) do
    ~H"""
    <!-- Service Provider: Emphasizes booking/pricing -->
    <div class="service-provider-layout grid gap-6">
      <!-- Hero Zone: Main service showcase -->
      <div class="hero-zone col-span-full">
        <%= render_layout_zone("hero", @layout_zones["hero"] || [], assigns) %>
      </div>

      <!-- Services Grid: 2-column on desktop -->
      <div class="services-zone grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <%= render_layout_zone("services", @layout_zones["services"] || [], assigns) %>
      </div>

      <!-- Trust Building Section: Testimonials & Pricing -->
      <div class="trust-zone grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2">
          <%= render_layout_zone("testimonials", @layout_zones["testimonials"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1">
          <%= render_layout_zone("pricing", @layout_zones["pricing"] || [], assigns) %>
        </div>
      </div>

      <!-- Call-to-Action Zone -->
      <div class="cta-zone col-span-full">
        <%= render_layout_zone("cta", @layout_zones["cta"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_creative_showcase_layout(assigns) do
    ~H"""
    <!-- Creative Showcase: Portfolio-focused with commission options -->
    <div class="creative-showcase-layout grid gap-6">
      <!-- Portfolio Header -->
      <div class="portfolio-header-zone col-span-full">
        <%= render_layout_zone("portfolio_header", @layout_zones["portfolio_header"] || [], assigns) %>
      </div>

      <!-- Main Portfolio Gallery: Masonry-style -->
      <div class="portfolio-gallery-zone col-span-full">
        <%= render_layout_zone("portfolio_gallery", @layout_zones["portfolio_gallery"] || [], assigns) %>
      </div>

      <!-- Process & Collaboration: Side-by-side -->
      <div class="showcase-details grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="process-zone">
          <%= render_layout_zone("process", @layout_zones["process"] || [], assigns) %>
        </div>
        <div class="collaboration-zone">
          <%= render_layout_zone("collaborations", @layout_zones["collaborations"] || [], assigns) %>
        </div>
      </div>

      <!-- Commission Inquiry Zone -->
      <div class="commission-zone col-span-full">
        <%= render_layout_zone("commission_inquiry", @layout_zones["commission_inquiry"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_technical_expert_layout(assigns) do
    ~H"""
    <!-- Technical Expert: Skill-based with project pricing -->
    <div class="technical-expert-layout grid gap-6">
      <!-- Technical Profile Header -->
      <div class="tech-header-zone col-span-full">
        <%= render_layout_zone("tech_header", @layout_zones["tech_header"] || [], assigns) %>
      </div>

      <!-- Skills Matrix: Interactive grid -->
      <div class="skills-zone col-span-full">
        <%= render_layout_zone("skills_matrix", @layout_zones["skills_matrix"] || [], assigns) %>
      </div>

      <!-- Projects & Consultation: Structured layout -->
      <div class="expertise-showcase grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2 projects-zone">
          <%= render_layout_zone("projects", @layout_zones["projects"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1 consultation-zone">
          <%= render_layout_zone("consultation", @layout_zones["consultation"] || [], assigns) %>
        </div>
      </div>

      <!-- Technical Blog/Insights Zone -->
      <div class="insights-zone col-span-full">
        <%= render_layout_zone("insights", @layout_zones["insights"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_content_creator_layout(assigns) do
    ~H"""
    <!-- Content Creator: Streaming-focused with subscription options -->
    <div class="content-creator-layout grid gap-6">
      <!-- Creator Brand Header -->
      <div class="creator-header-zone col-span-full">
        <%= render_layout_zone("creator_header", @layout_zones["creator_header"] || [], assigns) %>
      </div>

      <!-- Content Metrics Dashboard -->
      <div class="metrics-zone col-span-full">
        <%= render_layout_zone("content_metrics", @layout_zones["content_metrics"] || [], assigns) %>
      </div>

      <!-- Partnerships & Subscriptions: Feature layout -->
      <div class="monetization-showcase grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="partnerships-zone">
          <%= render_layout_zone("brand_partnerships", @layout_zones["brand_partnerships"] || [], assigns) %>
        </div>
        <div class="subscriptions-zone">
          <%= render_layout_zone("subscription_tiers", @layout_zones["subscription_tiers"] || [], assigns) %>
        </div>
      </div>

      <!-- Content Calendar/Schedule -->
      <div class="schedule-zone col-span-full">
        <%= render_layout_zone("content_schedule", @layout_zones["content_schedule"] || [], assigns) %>
      </div>

      <!-- Community Engagement Zone -->
      <div class="community-zone col-span-full">
        <%= render_layout_zone("community", @layout_zones["community"] || [], assigns) %>
      </div>
    </div>
    """
  end

  defp render_corporate_executive_layout(assigns) do
    ~H"""
    <!-- Corporate Executive: Achievement-focused with consultation booking -->
    <div class="corporate-executive-layout grid gap-6">
      <!-- Executive Profile Header -->
      <div class="executive-header-zone col-span-full">
        <%= render_layout_zone("executive_header", @layout_zones["executive_header"] || [], assigns) %>
      </div>

      <!-- Achievements & Metrics Dashboard -->
      <div class="achievements-zone grid grid-cols-1 lg:grid-cols-3 gap-6 col-span-full">
        <div class="lg:col-span-2">
          <%= render_layout_zone("achievements", @layout_zones["achievements"] || [], assigns) %>
        </div>
        <div class="lg:col-span-1">
          <%= render_layout_zone("key_metrics", @layout_zones["key_metrics"] || [], assigns) %>
        </div>
      </div>

      <!-- Leadership & Collaboration Experience -->
      <div class="leadership-zone col-span-full">
        <%= render_layout_zone("leadership", @layout_zones["leadership"] || [], assigns) %>
      </div>

      <!-- Thought Leadership & Consultation -->
      <div class="thought-leadership grid grid-cols-1 lg:grid-cols-2 gap-6 col-span-full">
        <div class="content-zone">
          <%= render_layout_zone("thought_leadership", @layout_zones["thought_leadership"] || [], assigns) %>
        </div>
        <div class="consultation-booking-zone">
          <%= render_layout_zone("executive_consultation", @layout_zones["executive_consultation"] || [], assigns) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # INDIVIDUAL ZONE RENDERING
  # ============================================================================

  defp render_layout_zone(zone_name, blocks, assigns) do
    assigns = assign(assigns, :zone_name, zone_name) |> assign(:zone_blocks, blocks)

    ~H"""
    <div class={"layout-zone zone-#{@zone_name}"}
      id={"layout-zone-#{@zone_name}"}
      data-zone={@zone_name}
      phx-hook="LayoutZone">

      <%= if @layout_mode == :edit do %>
        <!-- Zone Header (Edit Mode) -->
        <div class="zone-header flex items-center justify-between p-2 border-2 border-dashed border-gray-300 rounded-lg mb-4 bg-gray-50">
          <span class="text-sm font-medium text-gray-600 capitalize">
            <%= String.replace(@zone_name, "_", " ") %> Zone
          </span>
          <button
            phx-click="add_block_to_zone"
            phx-value-zone={@zone_name}
            phx-target={@myself}
            class="text-xs px-2 py-1 bg-purple-600 text-white rounded hover:bg-purple-700 transition-colors">
            + Add Block
          </button>
        </div>
      <% end %>

      <!-- Zone Content -->
      <div class="zone-content space-y-4">
        <%= if Enum.empty?(@zone_blocks) do %>
          <%= if @layout_mode == :edit do %>
            <!-- Empty Zone Placeholder -->
            <div class="empty-zone-placeholder h-32 border-2 border-dashed border-gray-300 rounded-lg flex items-center justify-center text-gray-500">
              <div class="text-center">
                <svg class="w-8 h-8 mx-auto mb-2 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                </svg>
                <p class="text-sm">Drop blocks here</p>
              </div>
            </div>
          <% end %>
        <% else %>
          <!-- Render Zone Blocks -->
          <%= for {block, index} <- Enum.with_index(@zone_blocks) do %>
            <div class="zone-block" data-block-id={block.id} data-position={index}>
              <%= render_dynamic_card_block(block, assigns) %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DYNAMIC CARD BLOCK RENDERING
  # ============================================================================

  defp render_dynamic_card_block(block, assigns) do
    block_config = DynamicCardBlocks.get_block_config(block.block_type)
    brand_settings = assigns.brand_settings

    assigns = assigns
    |> assign(:block, block)
    |> assign(:block_config, block_config)
    |> assign(:block_css, DynamicCardBlocks.generate_block_css(block.block_type, block.content_data, brand_settings))

    ~H"""
    <div class="dynamic-card-block relative group">
      <%= if @layout_mode == :edit do %>
        <!-- Block Edit Controls -->
        <div class="block-controls absolute top-2 right-2 opacity-0 group-hover:opacity-100 transition-opacity z-10">
          <div class="flex space-x-1">
            <button
              phx-click="edit_block_content"
              phx-value-block-id={@block.id}
              phx-target={@myself}
              class="p-1 bg-blue-600 text-white rounded-sm hover:bg-blue-700 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>
            <button
              phx-click="remove_block_from_zone"
              phx-value-block-id={@block.id}
              phx-value-zone={@zone_name}
              phx-target={@myself}
              class="p-1 bg-red-600 text-white rounded-sm hover:bg-red-700 transition-colors">
              <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Block CSS -->
      <style><%= raw(@block_css) %></style>

      <!-- Block Content -->
      <%= case @block.block_type do %>
        <% :service_showcase -> %>
          <%= render_service_showcase_block(@block, assigns) %>
        <% :testimonial_carousel -> %>
          <%= render_testimonial_carousel_block(@block, assigns) %>
        <% :pricing_display -> %>
          <%= render_pricing_display_block(@block, assigns) %>
        <% :portfolio_gallery -> %>
          <%= render_portfolio_gallery_block(@block, assigns) %>
        <% :process_showcase -> %>
          <%= render_process_showcase_block(@block, assigns) %>
        <% :collaboration_display -> %>
          <%= render_collaboration_display_block(@block, assigns) %>
        <% :skill_matrix -> %>
          <%= render_skill_matrix_block(@block, assigns) %>
        <% :project_deep_dive -> %>
          <%= render_project_deep_dive_block(@block, assigns) %>
        <% :consultation_booking -> %>
          <%= render_consultation_booking_block(@block, assigns) %>
        <% :content_metrics -> %>
          <%= render_content_metrics_block(@block, assigns) %>
        <% :brand_partnerships -> %>
          <%= render_brand_partnerships_block(@block, assigns) %>
        <% :subscription_tiers -> %>
          <%= render_subscription_tiers_block(@block, assigns) %>
        <% _ -> %>
          <!-- Fallback for unknown block types -->
          <div class="unknown-block p-4 bg-gray-100 border border-gray-300 rounded-lg">
            <p class="text-sm text-gray-600">Unknown block type: <%= @block.block_type %></p>
          </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SPECIFIC BLOCK RENDERERS
  # ============================================================================

  defp render_service_showcase_block(block, assigns) do
    content = block.content_data
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="service-showcase-card brand-typography">
      <div class="service-header mb-4">
        <h3 class="text-xl font-semibold brand-heading mb-2">
          <%= @content["service_title"] || "Service Title" %>
        </h3>
        <p class="text-gray-600 mb-4">
          <%= @content["service_description"] || "Service description goes here..." %>
        </p>
      </div>

      <%= if @content["starting_price"] do %>
        <div class="service-pricing mb-4">
          <span class="service-price">
            <%= @content["currency"] %><%= @content["starting_price"] %>
          </span>
          <span class="text-sm text-gray-500 ml-2">
            <%= @content["pricing_model"] %> rate
          </span>
        </div>
      <% end %>

      <%= if @content["includes"] && length(@content["includes"]) > 0 do %>
        <div class="service-includes mb-4">
          <h4 class="text-sm font-medium text-gray-900 mb-2">Includes:</h4>
          <ul class="text-sm text-gray-600 space-y-1">
            <%= for item <- @content["includes"] do %>
              <li class="flex items-center">
                <svg class="w-4 h-4 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                </svg>
                <%= item %>
              </li>
            <% end %>
          </ul>
        </div>
      <% end %>

      <%= if @content["booking_enabled"] do %>
        <button class="booking-button w-full">
          <%= @content["booking_button_text"] || "Book Now" %>
        </button>
      <% else %>
        <button class="booking-button w-full opacity-75">
          Get Quote
        </button>
      <% end %>
    </div>
    """
  end

  defp render_testimonial_carousel_block(block, assigns) do
    content = block.content_data
    testimonials = content["testimonials"] || []
    assigns = assign(assigns, :content, content) |> assign(:testimonials, testimonials)

    ~H"""
    <div class="testimonial-carousel brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Client Testimonials</h3>

      <%= if Enum.empty?(@testimonials) do %>
        <div class="empty-testimonials p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300 text-center">
          <p class="text-gray-500">No testimonials added yet</p>
          <%= if @layout_mode == :edit do %>
            <button class="mt-2 text-sm text-purple-600 hover:text-purple-700">
              Add Testimonial
            </button>
          <% end %>
        </div>
      <% else %>
        <div class="testimonials-grid space-y-4">
          <%= for testimonial <- Enum.take(@testimonials, 3) do %>
            <div class="testimonial-card p-4 bg-white border border-gray-200 rounded-lg">
              <div class="flex items-start space-x-3">
                <%= if testimonial["client_photo_url"] do %>
                  <img src={testimonial["client_photo_url"]}
                       alt={testimonial["client_name"]}
                       class="w-10 h-10 rounded-full object-cover">
                <% else %>
                  <div class="w-10 h-10 bg-gray-300 rounded-full flex items-center justify-center">
                    <span class="text-gray-600 text-sm font-medium">
                      <%= String.first(testimonial["client_name"] || "?") %>
                    </span>
                  </div>
                <% end %>

                <div class="flex-1">
                  <p class="text-gray-700 text-sm mb-2">
                    "<%= testimonial["testimonial_text"] %>"
                  </p>
                  <div class="text-xs text-gray-500">
                    <span class="font-medium"><%= testimonial["client_name"] %></span>
                    <%= if testimonial["client_company"] do %>
                      • <%= testimonial["client_company"] %>
                    <% end %>
                  </div>

                  <%= if @content["show_ratings"] && testimonial["rating"] do %>
                    <div class="flex mt-1">
                      <%= for i <- 1..5 do %>
                        <svg class={[
                          "w-3 h-3",
                          if(i <= testimonial["rating"], do: "text-yellow-400", else: "text-gray-300")
                        ]} fill="currentColor" viewBox="0 0 20 20">
                          <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                        </svg>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_pricing_display_block(block, assigns) do
    content = block.content_data
    pricing_tiers = content["pricing_tiers"] || []
    assigns = assign(assigns, :content, content) |> assign(:pricing_tiers, pricing_tiers)

    ~H"""
    <div class="pricing-display brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Pricing</h3>

      <%= if Enum.empty?(@pricing_tiers) do %>
        <div class="empty-pricing p-6 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300 text-center">
          <p class="text-gray-500">No pricing tiers configured</p>
          <%= if @layout_mode == :edit do %>
            <button class="mt-2 text-sm text-purple-600 hover:text-purple-700">
              Add Pricing Tier
            </button>
          <% end %>
        </div>
      <% else %>
        <div class={[
          "pricing-grid gap-4",
          case @content["display_format"] do
            "table" -> "space-y-2"
            _ -> "grid grid-cols-1 lg:grid-cols-#{min(length(@pricing_tiers), 3)}"
          end
        ]}>
          <%= for tier <- @pricing_tiers do %>
            <div class={[
              "pricing-tier",
              case @content["display_format"] do
                "minimal" -> "p-3 border-l-4 border-purple-600 bg-gray-50"
                "table" -> "flex items-center justify-between p-3 border border-gray-200 rounded"
                _ -> "p-4 bg-white border border-gray-200 rounded-lg hover:shadow-md transition-shadow"
              end,
              if(tier["is_popular"], do: "ring-2 ring-purple-600")
            ]}>

              <%= if tier["is_popular"] && @content["highlight_popular"] do %>
                <div class="popular-badge text-xs bg-purple-600 text-white px-2 py-1 rounded-full mb-2 inline-block">
                  Most Popular
                </div>
              <% end %>

              <h4 class="font-semibold text-gray-900 mb-1">
                <%= tier["tier_name"] %>
              </h4>

              <div class="pricing-amount mb-2">
                <span class="text-2xl font-bold text-gray-900">
                  <%= @content["currency"] %><%= tier["base_price"] %>
                </span>
                <span class="text-sm text-gray-500">
                  / <%= tier["billing_cycle"] %>
                </span>
              </div>

              <%= if tier["description"] do %>
                <p class="text-sm text-gray-600 mb-3">
                  <%= tier["description"] %>
                </p>
              <% end %>

              <%= if tier["features_included"] && length(tier["features_included"]) > 0 do %>
                <ul class="text-sm text-gray-600 space-y-1 mb-4">
                  <%= for feature <- Enum.take(tier["features_included"], 5) do %>
                    <li class="flex items-center">
                      <svg class="w-3 h-3 text-green-500 mr-2" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                      </svg>
                      <%= feature %>
                    </li>
                  <% end %>
                </ul>
              <% end %>

              <button class={[
                "w-full px-4 py-2 rounded-lg font-medium transition-colors",
                if(tier["is_popular"],
                  do: "bg-purple-600 text-white hover:bg-purple-700",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
              ]}>
                <%= tier["booking_button_text"] || "Get Started" %>
              </button>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # Additional block renderers would continue following the same pattern...
  # For brevity, I'll add placeholder renderers for the remaining blocks

  defp render_portfolio_gallery_block(block, assigns) do
    ~H"""
    <div class="portfolio-gallery brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Portfolio Gallery</h3>
      <div class="portfolio-gallery">
        <!-- Portfolio items would be rendered here -->
        <div class="text-center p-8 text-gray-500">
          Portfolio gallery content
        </div>
      </div>
    </div>
    """
  end

  defp render_process_showcase_block(block, assigns) do
    ~H"""
    <div class="process-showcase brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">My Process</h3>
      <div class="text-center p-8 text-gray-500">
        Process showcase content
      </div>
    </div>
    """
  end

  defp render_collaboration_display_block(block, assigns) do
    ~H"""
    <div class="collaboration-display brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Past Collaborations</h3>
      <div class="text-center p-8 text-gray-500">
        Collaboration display content
      </div>
    </div>
    """
  end

  defp render_skill_matrix_block(block, assigns) do
    ~H"""
    <div class="skill-matrix brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Technical Skills</h3>
      <div class="skill-matrix">
        <!-- Skills would be rendered here -->
        <div class="text-center p-8 text-gray-500">
          Skill matrix content
        </div>
      </div>
    </div>
    """
  end

  defp render_project_deep_dive_block(block, assigns) do
    ~H"""
    <div class="project-deep-dive brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Featured Project</h3>
      <div class="text-center p-8 text-gray-500">
        Project deep dive content
      </div>
    </div>
    """
  end

  defp render_consultation_booking_block(block, assigns) do
    ~H"""
    <div class="consultation-booking brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Book Consultation</h3>
      <div class="text-center p-8 text-gray-500">
        Consultation booking form
      </div>
    </div>
    """
  end

  defp render_content_metrics_block(block, assigns) do
    ~H"""
    <div class="content-metrics brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Content Performance</h3>
      <div class="text-center p-8 text-gray-500">
        Content metrics dashboard
      </div>
    </div>
    """
  end

  defp render_brand_partnerships_block(block, assigns) do
    ~H"""
    <div class="brand-partnerships brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Brand Partnerships</h3>
      <div class="text-center p-8 text-gray-500">
        Brand partnerships showcase
      </div>
    </div>
    """
  end

  defp render_subscription_tiers_block(block, assigns) do
    ~H"""
    <div class="subscription-tiers brand-typography">
      <h3 class="text-lg font-semibold brand-heading mb-4">Support My Work</h3>
      <div class="text-center p-8 text-gray-500">
        Subscription tiers content
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS CONTINUED
  # ============================================================================

  defp render_properties_panel(assigns) do
    ~H"""
    <div class="properties-panel">
      <h4 class="text-sm font-semibold text-gray-900 mb-4">Layout Properties</h4>

      <!-- Brand Settings -->
      <%= if @can_customize_brand do %>
        <div class="property-section mb-6">
          <h5 class="text-xs font-medium text-gray-700 mb-2">Brand Controls</h5>

          <!-- Color Override -->
          <div class="space-y-3">
            <div>
              <label class="block text-xs text-gray-600 mb-1">Primary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  value={@brand_settings.primary_color}
                  phx-change="update_brand_color"
                  phx-value-field="primary_color"
                  phx-target={@myself}
                  class="w-8 h-8 rounded border border-gray-300"
                  disabled={@brand_settings.enforce_brand_colors}>
                <span class="text-xs text-gray-500">
                  <%= @brand_settings.primary_color %>
                </span>
              </div>
              <%= if @brand_settings.enforce_brand_colors do %>
                <p class="text-xs text-amber-600 mt-1">Brand colors are locked</p>
              <% end %>
            </div>

            <div>
              <label class="block text-xs text-gray-600 mb-1">Accent Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  value={@brand_settings.accent_color}
                  phx-change="update_brand_color"
                  phx-value-field="accent_color"
                  phx-target={@myself}
                  class="w-8 h-8 rounded border border-gray-300"
                  disabled={@brand_settings.enforce_brand_colors}>
                <span class="text-xs text-gray-500">
                  <%= @brand_settings.accent_color %>
                </span>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Layout Settings -->
      <div class="property-section mb-6">
        <h5 class="text-xs font-medium text-gray-700 mb-2">Layout Settings</h5>

        <div class="space-y-3">
          <!-- Grid Density -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Grid Density</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="grid_density"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="compact">Compact</option>
              <option value="normal" selected>Normal</option>
              <option value="spacious">Spacious</option>
            </select>
          </div>

          <!-- Mobile Layout -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Mobile Layout</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="mobile_layout"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="stack">Stack Vertically</option>
              <option value="card" selected>Card Style</option>
              <option value="minimal">Minimal</option>
            </select>
          </div>

          <!-- Animation Level -->
          <div>
            <label class="block text-xs text-gray-600 mb-1">Animations</label>
            <select
              phx-change="update_layout_property"
              phx-value-property="animation_level"
              phx-target={@myself}
              class="w-full text-xs border border-gray-300 rounded px-2 py-1">
              <option value="none">None</option>
              <option value="subtle" selected>Subtle</option>
              <option value="enhanced">Enhanced</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Monetization Settings -->
      <%= if @can_monetize do %>
        <div class="property-section mb-6">
          <h5 class="text-xs font-medium text-gray-700 mb-2">Monetization</h5>

          <div class="space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-600">Show Pricing</span>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={@brand_settings.show_pricing_by_default}
                  phx-click="toggle_monetization_setting"
                  phx-value-setting="show_pricing_by_default"
                  phx-target={@myself}
                  class="sr-only peer">
                <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-purple-600"></div>
              </label>
            </div>

            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-600">Enable Booking</span>
              <label class="relative inline-flex items-center cursor-pointer">
                <input
                  type="checkbox"
                  checked={@brand_settings.show_booking_widgets_by_default}
                  phx-click="toggle_monetization_setting"
                  phx-value-setting="show_booking_widgets_by_default"
                  phx-target={@myself}
                  class="sr-only peer">
                <div class="w-9 h-5 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:rounded-full after:h-4 after:w-4 after:transition-all peer-checked:bg-purple-600"></div>
              </label>
            </div>

            <div>
              <label class="block text-xs text-gray-600 mb-1">Default Currency</label>
              <select
                phx-change="update_monetization_setting"
                phx-value-setting="default_currency"
                phx-target={@myself}
                class="w-full text-xs border border-gray-300 rounded px-2 py-1">
                <option value="USD" selected>USD ($)</option>
                <option value="EUR">EUR (€)</option>
                <option value="GBP">GBP (£)</option>
                <option value="CAD">CAD (C$)</option>
              </select>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Layout Templates -->
      <div class="property-section mb-6">
        <h5 class="text-xs font-medium text-gray-700 mb-2">Quick Templates</h5>

        <div class="space-y-2">
          <%= for template <- get_quick_templates(@active_category) do %>
            <button
              phx-click="apply_layout_template"
              phx-value-template={template.key}
              phx-target={@myself}
              class="w-full p-2 text-left border border-gray-200 rounded hover:bg-gray-50 transition-colors">
              <div class="text-xs font-medium text-gray-900">
                <%= template.name %>
              </div>
              <div class="text-xs text-gray-500">
                <%= template.description %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Save Actions -->
      <%= if @layout_dirty do %>
        <div class="property-section">
          <div class="space-y-2">
            <button
              phx-click="save_layout"
              phx-target={@myself}
              class="w-full px-3 py-2 bg-purple-600 text-white text-sm font-medium rounded-lg hover:bg-purple-700 transition-colors">
              Save Layout
            </button>
            <button
              phx-click="reset_layout"
              phx-target={@myself}
              class="w-full px-3 py-2 bg-gray-100 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-200 transition-colors">
              Reset Changes
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT TEMPLATE MODAL
  # ============================================================================

  defp render_layout_template_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
         phx-click="close_layout_templates"
         phx-target={@myself}>
      <div class="bg-white rounded-xl max-w-4xl w-full max-h-screen overflow-y-auto m-4"
           phx-click-away="close_layout_templates"
           phx-target={@myself}>

        <div class="p-6 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Choose Layout Template</h3>
          <p class="text-sm text-gray-600 mt-1">
            Select a pre-designed layout for your <%= String.replace(to_string(@active_category), "_", " ") %> portfolio
          </p>
        </div>

        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for template <- get_layout_templates(@active_category) do %>
              <div class="template-option group cursor-pointer"
                   phx-click="apply_layout_template"
                   phx-value-template={template.key}
                   phx-target={@myself}>

                <!-- Template Preview -->
                <div class="template-preview h-40 bg-gray-100 rounded-lg mb-3 overflow-hidden relative">
                  <%= render_template_preview(template.key, assigns) %>

                  <!-- Hover Overlay -->
                  <div class="absolute inset-0 bg-purple-600 bg-opacity-0 group-hover:bg-opacity-20 transition-all duration-200 flex items-center justify-center">
                    <div class="opacity-0 group-hover:opacity-100 transition-opacity">
                      <div class="bg-white text-purple-600 px-3 py-1 rounded-full text-sm font-medium">
                        Apply Template
                      </div>
                    </div>
                  </div>
                </div>

                <!-- Template Info -->
                <h4 class="font-medium text-gray-900 mb-1"><%= template.name %></h4>
                <p class="text-sm text-gray-600 mb-2"><%= template.description %></p>

                <!-- Featured Blocks -->
                <div class="flex flex-wrap gap-1">
                  <%= for block_type <- Enum.take(template.featured_blocks, 3) do %>
                    <span class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded">
                      <%= humanize_block_type(block_type) %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_current_layout_config(portfolio, brand_settings) do
    base_config = %{
      layout_style: portfolio.layout || "professional_service_provider",
      grid_density: "normal",
      mobile_layout: "card",
      animation_level: "subtle"
    }

    # Apply brand constraints
    if brand_settings.enforce_layout_constraints do
      Map.merge(base_config, brand_settings.layout_constraints || %{})
    else
      base_config
    end
  end

  defp organize_blocks_into_zones(content_blocks, layout_config) do
    # Group content blocks by their assigned zones
    # This would be implemented based on how blocks are stored with zone information
    %{
      "hero" => [],
      "services" => [],
      "testimonials" => [],
      "pricing" => [],
      "cta" => []
    }
  end

  defp get_available_categories(subscription_tier) do
    base_categories = [
      %{key: :service_provider, name: "Service Provider"},
      %{key: :creative_showcase, name: "Creative"}
    ]

    case subscription_tier do
      tier when tier in ["creator", "professional", "enterprise"] ->
        base_categories ++ [
          %{key: :technical_expert, name: "Technical"},
          %{key: :content_creator, name: "Creator"},
          %{key: :corporate_executive, name: "Executive"}
        ]
      _ -> base_categories
    end
  end

  defp get_blocks_for_category(available_blocks, category) do
    Enum.filter(available_blocks, &(&1.category == category))
  end

  defp get_device_preview_classes(device) do
    case device do
      :mobile -> "max-w-sm mx-auto"
      :tablet -> "max-w-3xl mx-auto"
      :desktop -> "w-full"
    end
  end

  defp has_locked_blocks?(available_blocks, subscription_tier) do
    all_blocks = DynamicCardBlocks.get_all_dynamic_card_blocks()
    length(all_blocks) > length(available_blocks)
  end

  defp get_quick_templates(category) do
    DynamicCardBlocks.get_available_layouts_for_category(category)
  end

  defp get_layout_templates(category) do
    DynamicCardBlocks.get_available_layouts_for_category(category)
  end

  defp render_template_preview(template_key, assigns) do
    assigns = assign(assigns, :template_key, template_key)

    ~H"""
    <!-- Simplified template preview -->
    <div class="h-full p-3 bg-gradient-to-br from-gray-50 to-gray-100">
      <%= case @template_key do %>
        <% "professional_service_provider" -> %>
          <div class="space-y-2">
            <div class="h-4 bg-blue-300 rounded"></div>
            <div class="grid grid-cols-2 gap-1">
              <div class="h-8 bg-blue-200 rounded"></div>
              <div class="h-8 bg-green-200 rounded"></div>
            </div>
            <div class="h-3 bg-purple-200 rounded"></div>
          </div>
        <% "creative_portfolio_showcase" -> %>
          <div class="space-y-2">
            <div class="h-3 bg-purple-300 rounded"></div>
            <div class="grid grid-cols-3 gap-1">
              <div class="h-6 bg-pink-200 rounded"></div>
              <div class="h-6 bg-purple-200 rounded"></div>
              <div class="h-6 bg-indigo-200 rounded"></div>
            </div>
            <div class="h-4 bg-gradient-to-r from-purple-200 to-pink-200 rounded"></div>
          </div>
        <% _ -> %>
          <div class="h-full bg-gray-200 rounded flex items-center justify-center">
            <span class="text-xs text-gray-500">Preview</span>
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

  # Placeholder implementations for functions that would be implemented later
  defp create_dynamic_card_block(block_type, zone, position, socket) do
    # Implementation would create a new content block following PortfolioEditor pattern
    {:ok, %{id: :rand.uniform(1000), block_type: String.to_atom(block_type), content_data: %{}}}
  end

  defp add_block_to_layout_zone(layout_zones, zone, new_block, position) do
    current_blocks = Map.get(layout_zones, zone, [])
    updated_blocks = List.insert_at(current_blocks, String.to_integer(position), new_block)
    Map.put(layout_zones, zone, updated_blocks)
  end

  defp remove_block_from_layout(block_id, zone, socket) do
    current_zones = socket.assigns.layout_zones
    current_blocks = Map.get(current_zones, zone, [])
    updated_blocks = Enum.reject(current_blocks, &(&1.id == String.to_integer(block_id)))
    updated_zones = Map.put(current_zones, zone, updated_blocks)
    {:ok, updated_zones}
  end

  defp reorder_zone_blocks(layout_zones, zone, new_order) do
    current_blocks = Map.get(layout_zones, zone, [])
    # Reorder based on new_order array (list of block IDs)
    # Implementation would sort blocks according to the new order
    Map.put(layout_zones, zone, current_blocks)
  end

  defp save_dynamic_card_layout(layout_zones, portfolio) do
    # Implementation would save the layout configuration to the database
    {:ok, portfolio}
  end

  defp apply_predefined_layout_template(template_key, socket) do
    # Implementation would apply a predefined template layout
    {:ok, socket.assigns.layout_zones}
  end
end
