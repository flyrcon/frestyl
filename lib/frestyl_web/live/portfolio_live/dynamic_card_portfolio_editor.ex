# lib/frestyl_web/live/portfolio_live/dynamic_card_portfolio_editor.ex
defmodule FrestylWeb.PortfolioLive.DynamicCardPortfolioEditor do
  @moduledoc """
  Extended Portfolio Editor specifically for Dynamic Card Layouts.
  Integrates with the existing PortfolioEditor framework while adding
  dynamic card layout capabilities with brand control and monetization.
  """

  use FrestylWeb, :live_view

  # Import the base PortfolioEditor framework
  alias FrestylWeb.PortfolioLive.PortfolioEditor
  alias FrestylWeb.PortfolioLive.DynamicCardLayoutManager
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Accounts.BrandSettings

  # ============================================================================
  # MOUNT - Extended from PortfolioEditor
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, session, socket) do
    # Delegate to base PortfolioEditor for core initialization
    case PortfolioEditor.mount(%{"id" => portfolio_id}, session, socket) do
      {:ok, base_socket} ->
        # Extend with dynamic card layout capabilities
        account = base_socket.assigns.account
        portfolio = base_socket.assigns.portfolio

        # Load brand settings
        brand_settings = get_or_create_brand_settings(account)

        # Determine if this is a dynamic card layout portfolio
        is_dynamic_layout = is_dynamic_card_layout?(portfolio)

        # Get available dynamic card blocks based on subscription
        available_dynamic_blocks = DynamicCardBlocks.get_blocks_by_monetization_tier(account.subscription_tier)

        # Load dynamic layout zones if applicable
        layout_zones = if is_dynamic_layout do
          load_dynamic_layout_zones(portfolio.id)
        else
          %{}
        end

        # Calculate layout metrics
        layout_metrics = calculate_layout_performance_metrics(portfolio.id)

        enhanced_socket = base_socket
        |> assign(:is_dynamic_layout, is_dynamic_layout)
        |> assign(:brand_settings, brand_settings)
        |> assign(:available_dynamic_blocks, available_dynamic_blocks)
        |> assign(:layout_zones, layout_zones)
        |> assign(:layout_metrics, layout_metrics)
        |> assign(:active_layout_zone, nil)
        |> assign(:show_dynamic_layout_manager, false)
        |> assign(:show_brand_settings_editor, false)
        |> assign(:layout_preview_mode, false)

        {:ok, enhanced_socket}

      error -> error
    end
  end

  # ============================================================================
  # DYNAMIC CARD LAYOUT ENHANCEMENT
  # ============================================================================

  defp enhance_with_dynamic_card_capabilities(socket, account, portfolio) do
    # Load brand settings
    brand_settings = get_or_create_brand_settings(account)

    # Determine if this is a dynamic card layout portfolio
    is_dynamic_layout = is_dynamic_card_layout?(portfolio)

    # Get available dynamic card blocks based on subscription
    available_dynamic_blocks = DynamicCardBlocks.get_blocks_by_monetization_tier(account.subscription_tier)

    # Load dynamic layout zones if applicable
    layout_zones = if is_dynamic_layout do
      load_dynamic_layout_zones(portfolio.id)
    else
      %{}
    end

    # Calculate layout metrics
    layout_metrics = calculate_layout_performance_metrics(portfolio.id)

    socket
    |> assign(:is_dynamic_layout, is_dynamic_layout)
    |> assign(:brand_settings, brand_settings)
    |> assign(:available_dynamic_blocks, available_dynamic_blocks)
    |> assign(:layout_zones, layout_zones)
    |> assign(:layout_metrics, layout_metrics)
    |> assign(:active_layout_zone, nil)
    |> assign(:show_dynamic_layout_manager, false)
    |> assign(:show_brand_settings_editor, false)
    |> assign(:layout_preview_mode, false)
  end

  # ============================================================================
  # RENDER - Enhanced Template Editor Interface
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-portfolio-editor h-screen flex flex-col bg-gray-50">
      <!-- Enhanced Header with Dynamic Layout Controls -->
      <%= render_enhanced_header(assigns) %>

      <!-- Main Editor Layout -->
      <div class="flex-1 flex overflow-hidden">
        <!-- Left Sidebar: Enhanced with Dynamic Blocks -->
        <div class="w-80 bg-white border-r border-gray-200 flex flex-col">
          <%= render_enhanced_sidebar(assigns) %>
        </div>

        <!-- Center: Main Editor Canvas -->
        <div class="flex-1 flex flex-col">
          <%= if @is_dynamic_layout && @show_dynamic_layout_manager do %>
            <!-- Dynamic Card Layout Manager -->
            <.live_component
              module={DynamicCardLayoutManager}
              id="dynamic-layout-manager"
              portfolio={@portfolio}
              account={@account}
              features={@features}
              brand_settings={@brand_settings}
              content_blocks={@content_blocks}
              layout_zones={@layout_zones} />
          <% else %>
            <!-- Traditional Portfolio Editor -->
            <%= render_traditional_editor_canvas(assigns) %>
          <% end %>
        </div>

        <!-- Right Sidebar: Properties and Brand Control -->
        <div class="w-80 bg-white border-l border-gray-200 flex flex-col">
          <%= render_properties_sidebar(assigns) %>
        </div>
      </div>

      <!-- Modals and Overlays -->
      <%= render_modals_and_overlays(assigns) %>
    </div>
    """
  end

  # ============================================================================
  # ENHANCED HEADER RENDERING
  # ============================================================================

  defp render_enhanced_header(assigns) do
    ~H"""
    <div class="bg-white border-b border-gray-200 px-6 py-4">
      <div class="flex items-center justify-between">
        <!-- Portfolio Info with Layout Type Badge -->
        <div class="flex items-center space-x-4">
          <.link navigate="/portfolios" class="text-gray-500 hover:text-gray-700">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
          </.link>

          <div>
            <h1 class="text-xl font-semibold text-gray-900 flex items-center">
              <%= @portfolio.title %>
              <%= if @is_dynamic_layout do %>
                <span class="ml-2 px-2 py-1 bg-purple-100 text-purple-700 text-xs font-medium rounded-full">
                  Dynamic Layout
                </span>
              <% end %>
            </h1>
            <p class="text-sm text-gray-500">
              <%= get_layout_type_description(@portfolio.layout, @is_dynamic_layout) %>
            </p>
          </div>
        </div>

        <!-- Enhanced Action Bar -->
        <div class="flex items-center space-x-3">
          <!-- Layout Mode Toggle -->
          <%= if @is_dynamic_layout do %>
            <div class="flex bg-gray-100 rounded-lg p-1">
              <button
                phx-click="toggle_layout_mode"
                phx-value-mode="traditional"
                class={[
                  "px-3 py-1 rounded text-sm font-medium transition-colors",
                  if(@show_dynamic_layout_manager,
                    do: "text-gray-600 hover:text-gray-900",
                    else: "bg-white text-gray-900 shadow-sm")
                ]}>
                Traditional
              </button>
              <button
                phx-click="toggle_layout_mode"
                phx-value-mode="dynamic"
                class={[
                  "px-3 py-1 rounded text-sm font-medium transition-colors",
                  if(@show_dynamic_layout_manager,
                    do: "bg-white text-gray-900 shadow-sm",
                    else: "text-gray-600 hover:text-gray-900")
                ]}>
                Dynamic Cards
              </button>
            </div>
          <% end %>

          <!-- Brand Settings -->
          <%= if @can_customize_brand do %>
            <button
              phx-click="toggle_brand_settings"
              class={[
                "px-3 py-2 rounded-lg text-sm font-medium transition-colors flex items-center",
                if(@show_brand_settings_editor,
                  do: "bg-blue-600 text-white",
                  else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
              ]}>
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"/>
              </svg>
              Brand
            </button>
          <% end %>

          <!-- Preview Mode -->
          <button
            phx-click="toggle_preview_mode"
            class={[
              "px-3 py-2 rounded-lg text-sm font-medium transition-colors flex items-center",
              if(@layout_preview_mode,
                do: "bg-green-600 text-white",
                else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
            ]}>
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>
            Preview
          </button>

          <!-- Save Status -->
          <%= if @unsaved_changes do %>
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 bg-amber-500 rounded-full animate-pulse"></div>
              <span class="text-sm text-amber-600 font-medium">Unsaved changes</span>
            </div>
          <% else %>
            <div class="flex items-center space-x-2">
              <div class="w-2 h-2 bg-green-500 rounded-full"></div>
              <span class="text-sm text-green-600 font-medium">All changes saved</span>
            </div>
          <% end %>

          <!-- Publish Button -->
          <button
            phx-click="publish_portfolio"
            class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors font-medium">
            Publish
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # ENHANCED SIDEBAR RENDERING
  # ============================================================================

  defp render_enhanced_sidebar(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col">
      <!-- Sidebar Header -->
      <div class="p-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Portfolio Builder</h3>

        <!-- Quick Stats -->
        <div class="mt-3 grid grid-cols-2 gap-3">
          <div class="text-center p-2 bg-gray-50 rounded">
            <div class="text-lg font-bold text-purple-600"><%= @section_count %></div>
            <div class="text-xs text-gray-500">Sections</div>
          </div>
          <div class="text-center p-2 bg-gray-50 rounded">
            <div class="text-lg font-bold text-green-600"><%= @content_block_count %></div>
            <div class="text-xs text-gray-500">Blocks</div>
          </div>
        </div>
      </div>

      <!-- Content Tabs -->
      <div class="border-b border-gray-200">
        <nav class="flex -mb-px">
          <button
            phx-click="switch_sidebar_tab"
            phx-value-tab="sections"
            class={[
              "flex-1 py-2 px-1 border-b-2 font-medium text-sm",
              if(@active_tab == :sections,
                do: "border-purple-500 text-purple-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
            ]}>
            Sections
          </button>

          <%= if @is_dynamic_layout do %>
            <button
              phx-click="switch_sidebar_tab"
              phx-value-tab="dynamic_blocks"
              class={[
                "flex-1 py-2 px-1 border-b-2 font-medium text-sm",
                if(@active_tab == :dynamic_blocks,
                  do: "border-purple-500 text-purple-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
              ]}>
              Dynamic Blocks
            </button>
          <% end %>

          <button
            phx-click="switch_sidebar_tab"
            phx-value-tab="media"
            class={[
              "flex-1 py-2 px-1 border-b-2 font-medium text-sm",
              if(@active_tab == :media,
                do: "border-purple-500 text-purple-600",
                else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
            ]}>
            Media
          </button>
        </nav>
      </div>

      <!-- Tab Content -->
      <div class="flex-1 overflow-y-auto p-4">
        <%= case @active_tab do %>
          <% :sections -> %>
            <%= render_sections_tab(assigns) %>
          <% :dynamic_blocks -> %>
            <%= render_dynamic_blocks_tab(assigns) %>
          <% :media -> %>
            <%= render_media_tab(assigns) %>
          <% _ -> %>
            <%= render_sections_tab(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_dynamic_blocks_tab(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex items-center justify-between">
        <h4 class="text-sm font-semibold text-gray-900">Dynamic Card Blocks</h4>
        <span class="text-xs px-2 py-1 bg-purple-100 text-purple-700 rounded-full">
          <%= length(@available_dynamic_blocks) %> Available
        </span>
      </div>

      <!-- Block Categories -->
      <%= for category <- get_unique_block_categories(@available_dynamic_blocks) do %>
        <div class="space-y-2">
          <h5 class="text-xs font-medium text-gray-700 uppercase tracking-wide">
            <%= String.replace(to_string(category), "_", " ") %>
          </h5>

          <%= for block <- get_blocks_by_category(@available_dynamic_blocks, category) do %>
            <div class="block-item group cursor-grab"
                 data-block-type={block.type}
                 draggable="true">
              <div class={[
                "p-3 border-2 border-dashed rounded-lg transition-all",
                "group-hover:border-purple-400 group-hover:bg-purple-50",
                if(block.monetization_tier != :personal, do: "border-amber-300 bg-amber-50", else: "border-gray-300 bg-white")
              ]}>
                <div class="flex items-start justify-between mb-2">
                  <h6 class="text-sm font-medium text-gray-900"><%= block.name %></h6>
                  <%= if block.monetization_tier != :personal do %>
                    <span class="text-xs px-1 py-0.5 bg-amber-100 text-amber-700 rounded">
                      <%= String.capitalize(to_string(block.monetization_tier)) %>+
                    </span>
                  <% end %>
                </div>

                <p class="text-xs text-gray-600 mb-2"><%= block.description %></p>

                <%= if block.monetization_tier in [:creator, :professional] and @can_monetize do %>
                  <div class="flex items-center text-xs text-green-600">
                    <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M8.433 7.418c.155-.103.346-.196.567-.267v1.698a2.305 2.305 0 01-.567-.267C8.07 8.34 8 8.114 8 8c0-.114.07-.34.433-.582z"/>
                    </svg>
                    Monetization Ready
                  </div>
                <% end %>

                <button
                  phx-click="add_dynamic_block"
                  phx-value-block-type={block.type}
                  class="w-full mt-2 py-1 text-xs bg-purple-600 text-white rounded hover:bg-purple-700 transition-colors">
                  Add to Layout
                </button>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Monetization Upsell -->
      <%= if has_locked_blocks?(@available_dynamic_blocks, @account.subscription_tier) do %>
        <div class="mt-6 p-4 bg-gradient-to-br from-amber-50 to-orange-50 border border-amber-200 rounded-lg">
          <h5 class="text-sm font-semibold text-amber-900 mb-2">
            Unlock Advanced Monetization Blocks
          </h5>
          <p class="text-xs text-amber-700 mb-3">
            Upgrade to access premium blocks like subscription tiers, advanced analytics, and enterprise features.
          </p>
          <button
            phx-click="show_upgrade_modal"
            class="w-full px-3 py-2 bg-amber-600 text-white text-xs font-medium rounded hover:bg-amber-700 transition-colors">
            Upgrade Account
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS - Extended from PortfolioEditor
  # ============================================================================

  @impl true
  def handle_event("toggle_layout_mode", %{"mode" => mode}, socket) do
    show_dynamic = mode == "dynamic"

    {:noreply, socket
      |> assign(:show_dynamic_layout_manager, show_dynamic)
      |> push_event("layout_mode_changed", %{mode: mode})
    }
  end

  @impl true
  def handle_event("toggle_brand_settings", _params, socket) do
    new_state = !socket.assigns.show_brand_settings_editor

    {:noreply, assign(socket, :show_brand_settings_editor, new_state)}
  end

  @impl true
  def handle_event("toggle_preview_mode", _params, socket) do
    new_mode = !socket.assigns.layout_preview_mode

    {:noreply, socket
      |> assign(:layout_preview_mode, new_mode)
      |> push_event("preview_mode_toggled", %{enabled: new_mode})
    }
  end

  @impl true
  def handle_event("add_dynamic_block", %{"block_type" => block_type}, socket) do
    # Following PortfolioEditor pattern for block creation
    case create_dynamic_card_block(block_type, socket) do
      {:ok, new_block} ->
        updated_blocks = add_block_to_content_cache(socket.assigns.content_blocks, new_block)

        {:noreply, socket
          |> assign(:content_blocks, updated_blocks)
          |> assign(:content_block_count, socket.assigns.content_block_count + 1)
          |> assign(:unsaved_changes, true)
          |> put_flash(:info, "Dynamic block added successfully")
        }

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{reason}")}
    end
  end

  @impl true
  def handle_event("switch_sidebar_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_atom(tab)
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  # Delegate other events to base PortfolioEditor
  @impl true
  def handle_event(event_name, params, socket) do
    # Try to handle with PortfolioEditor first
    case apply(PortfolioEditor, :handle_event, [event_name, params, socket]) do
      {:noreply, updated_socket} -> {:noreply, updated_socket}
      other -> other
    end
  rescue
    # If PortfolioEditor doesn't handle it, handle here or show error
    FunctionClauseError ->
      {:noreply, put_flash(socket, :error, "Unknown action: #{event_name}")}
  end

  # ============================================================================
  # HELPER FUNCTIONS - Include missing functions from PortfolioEditor
  # ============================================================================

  defp load_portfolio_with_account_and_blocks(portfolio_id, user) do
    case Portfolios.get_portfolio_with_account(portfolio_id) do
      nil ->
        {:error, :not_found}

      %{portfolio: portfolio, account: account} ->
        if can_edit_portfolio?(portfolio, account, user) do
          # Load content blocks organized by section
          content_blocks = load_content_blocks_by_section(portfolio_id)
          {:ok, portfolio, account, content_blocks}
        else
          {:error, :unauthorized}
        end
    end
  end

  defp load_content_blocks_by_section(portfolio_id) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)

    Enum.reduce(sections, %{}, fn section, acc ->
      blocks = Portfolios.list_content_blocks_for_section(section.id)
      Map.put(acc, section.id, blocks)
    end)
  end

  defp can_edit_portfolio?(portfolio, account, user) do
    # Owner check
    portfolio.account_id == account.id and account.user_id == user.id
    # TODO: Add collaboration permissions here
  end

  defp get_account_features(account) do
    case account.subscription_tier do
      "personal" -> %{
        monetization_enabled: false,
        streaming_enabled: false,
        scheduling_enabled: false,
        advanced_analytics: false,
        custom_branding: false,
        api_access: false
      }

      "creator" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: false,
        custom_branding: false,
        api_access: false
      }

      "professional" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: true,
        custom_branding: true,
        api_access: false
      }

      "enterprise" -> %{
        monetization_enabled: true,
        streaming_enabled: true,
        scheduling_enabled: true,
        advanced_analytics: true,
        custom_branding: true,
        api_access: true
      }
    end
  end

  defp get_account_limits(account) do
    case account.subscription_tier do
      "personal" -> %{
        max_portfolios: 2,
        max_sections: 10,
        max_media_size_mb: 50,
        max_video_length: 60,
        max_streaming_hours: 0
      }

      "creator" -> %{
        max_portfolios: 5,
        max_sections: 25,
        max_media_size_mb: 200,
        max_video_length: 300,
        max_streaming_hours: 10
      }

      "professional" -> %{
        max_portfolios: 15,
        max_sections: 50,
        max_media_size_mb: 500,
        max_video_length: 600,
        max_streaming_hours: 50
      }

      "enterprise" -> %{
        max_portfolios: -1,
        max_sections: -1,
        max_media_size_mb: 1000,
        max_video_length: -1,
        max_streaming_hours: -1
      }
    end
  end

  defp assign_core_data(socket, portfolio, account, user) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:account, account)
    |> assign(:user, user)
    |> assign(:page_title, "Edit #{portfolio.title}")
  end

  defp assign_features_and_limits(socket, features, limits) do
    socket
    |> assign(:features, features)
    |> assign(:limits, limits)
    |> assign(:can_monetize, features.monetization_enabled)
    |> assign(:can_stream, features.streaming_enabled)
    |> assign(:can_schedule, features.scheduling_enabled)
    |> assign(:can_customize_brand, features.custom_branding)
    |> assign(:max_sections, limits.max_sections)
    |> assign(:max_media_size, limits.max_media_size_mb)
  end

  defp assign_content_data(socket, sections, media_library, content_blocks) do
    socket
      |> assign(:sections, sections)
      |> assign(:media_library, media_library)
      |> assign(:content_blocks, content_blocks)
      |> assign(:section_count, length(sections))
      |> assign(:content_block_count, count_total_blocks(content_blocks))
      |> assign(:editing_section, nil)
      |> assign(:editing_block, nil)
      |> assign(:editing_mode, :overview)
      |> assign(:block_builder_open, false)
  end

  defp assign_monetization_data(socket, monetization_data, streaming_config) do
    socket
    |> assign(:monetization_data, monetization_data)
    |> assign(:streaming_config, streaming_config)
    |> assign(:revenue_analytics, monetization_data.analytics)
    |> assign(:booking_calendar, monetization_data.calendar)
  end

  defp assign_design_system(socket, available_layouts, brand_constraints) do
    socket
    |> assign(:available_layouts, available_layouts)
    |> assign(:brand_constraints, brand_constraints)
    |> assign(:current_layout, socket.assigns.portfolio.layout || "professional_service")
    |> assign(:design_tokens, generate_design_tokens(socket.assigns.portfolio, brand_constraints))
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, :content)
    |> assign(:show_video_recorder, false)
    |> assign(:show_media_library, false)
    |> assign(:unsaved_changes, false)
    |> assign(:auto_save_enabled, true)
  end

  defp load_portfolio_sections(portfolio_id), do: Portfolios.list_portfolio_sections(portfolio_id)
  defp load_portfolio_media(portfolio_id), do: Portfolios.list_portfolio_media(portfolio_id)

  defp load_monetization_data(portfolio, account) do
    %{
      services: [],
      pricing: %{},
      calendar: %{},
      analytics: %{},
      payment_config: %{}
    }
  end

  defp load_streaming_config(portfolio, account) do
    %{
      streaming_key: nil,
      scheduled_streams: [],
      stream_analytics: %{},
      rtmp_config: %{}
    }
  end

  defp get_available_layouts(account), do: ["professional_service", "creative_showcase", "corporate_executive"]

  defp get_brand_constraints(account) do
    %{
      primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626"],
      secondary_colors: ["#64748b", "#6b7280", "#9ca3af"],
      accent_colors: ["#f59e0b", "#ef4444", "#8b5cf6", "#06b6d4"],
      allowed_fonts: ["Inter", "Merriweather", "JetBrains Mono"],
      font_size_scale: %{min: 0.875, max: 2.25},
      max_sections: 20,
      spacing_scale: [0.5, 1, 1.5, 2, 3, 4],
      enforce_brand: false,
      brand_locked_elements: []
    }
  end

  defp generate_design_tokens(portfolio, brand_constraints) do
    customization = portfolio.customization || %{}

    %{
      primary: get_constrained_color(customization["primary_color"], brand_constraints.primary_colors),
      secondary: get_constrained_color(customization["secondary_color"], brand_constraints.secondary_colors),
      accent: get_constrained_color(customization["accent_color"], brand_constraints.accent_colors),
      font_family: get_constrained_font(customization["font_family"], brand_constraints.allowed_fonts),
      font_scale: brand_constraints.font_size_scale,
      spacing_scale: brand_constraints.spacing_scale,
      max_width: "1200px",
      border_radius: "0.5rem",
      shadow_scale: ["sm", "md", "lg", "xl"]
    }
  end

  defp get_constrained_color(user_color, allowed_colors) do
    if user_color in allowed_colors do
      user_color
    else
      List.first(allowed_colors)
    end
  end

  defp get_constrained_font(user_font, allowed_fonts) do
    if user_font in allowed_fonts do
      user_font
    else
      List.first(allowed_fonts)
    end
  end

  defp count_total_blocks(content_blocks) do
    content_blocks
    |> Map.values()
    |> List.flatten()
    |> length()
  end

  defp is_dynamic_card_layout?(portfolio) do
    dynamic_layouts = [
      "professional_service_provider",
      "creative_portfolio_showcase",
      "technical_expert_dashboard",
      "content_creator_hub",
      "corporate_executive_profile"
    ]

    portfolio.layout in dynamic_layouts
  end

  defp get_layout_type_description(layout, is_dynamic) do
    if is_dynamic do
      case layout do
        "professional_service_provider" -> "Service-focused with booking and pricing showcase"
        "creative_portfolio_showcase" -> "Visual portfolio with commission opportunities"
        "technical_expert_dashboard" -> "Skill-based with consultation booking"
        "content_creator_hub" -> "Content metrics with subscription options"
        "corporate_executive_profile" -> "Achievement-focused executive presence"
        _ -> "Dynamic card layout with monetization features"
      end
    else
      "Traditional portfolio layout"
    end
  end

  defp get_or_create_brand_settings(account) do
    case Frestyl.Accounts.get_brand_settings_by_account(account.id) do
      nil ->
        {:ok, brand_settings} = Frestyl.Accounts.create_brand_settings(%{
          account_id: account.id
        })
        brand_settings

      existing_settings -> existing_settings
    end
  end

  defp load_dynamic_layout_zones(portfolio_id) do
    # Load layout zone configuration from database
    # This would store how content blocks are organized into zones
    %{
      "hero" => [],
      "services" => [],
      "testimonials" => [],
      "pricing" => [],
      "cta" => []
    }
  end

  defp calculate_layout_performance_metrics(portfolio_id) do
    # Calculate metrics like conversion rates, engagement, etc.
    %{
      total_views: 0,
      conversion_rate: 0.0,
      avg_time_on_page: 0,
      bounce_rate: 0.0
    }
  end

  defp get_unique_block_categories(blocks) do
    blocks
    |> Enum.map(& &1.category)
    |> Enum.uniq()
  end

  defp get_blocks_by_category(blocks, category) do
    Enum.filter(blocks, & &1.category == category)
  end

  defp has_locked_blocks?(available_blocks, subscription_tier) do
    all_blocks = DynamicCardBlocks.get_all_dynamic_card_blocks()
    length(all_blocks) > length(available_blocks)
  end

  defp create_dynamic_card_block(block_type, socket) do
    # Implementation following PortfolioEditor pattern
    block_config = DynamicCardBlocks.get_block_config(String.to_atom(block_type))

    if block_config do
      # Create the block with default content
      {:ok, %{
        id: System.unique_integer([:positive]),
        block_type: String.to_atom(block_type),
        content_data: block_config.default_content,
        position: get_next_block_position(socket),
        created_at: DateTime.utc_now()
      }}
    else
      {:error, "Unknown block type: #{block_type}"}
    end
  end

  defp add_block_to_content_cache(content_blocks, new_block) do
    # Add to the general content blocks cache
    # In a real implementation, this would be organized by section
    Map.update(content_blocks, :general, [new_block], fn existing ->
      [new_block | existing]
    end)
  end

  defp get_next_block_position(socket) do
    socket.assigns.content_block_count
  end

  # Placeholder render functions - would be implemented based on existing patterns
  defp render_sections_tab(assigns), do: ~H"<div>Sections tab content</div>"
  defp render_media_tab(assigns), do: ~H"<div>Media tab content</div>"
  defp render_traditional_editor_canvas(assigns), do: ~H"<div>Traditional editor canvas</div>"
  defp render_properties_sidebar(assigns), do: ~H"<div>Properties sidebar</div>"
  defp render_modals_and_overlays(assigns), do: ~H"<div>Modals and overlays</div>"
end
