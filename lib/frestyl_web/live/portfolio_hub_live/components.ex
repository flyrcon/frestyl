# lib/frestyl_web/live/portfolio_hub_live/components.ex - ENHANCED MOBILE-FIRST COMPONENTS

defmodule FrestylWeb.PortfolioHubLive.Components do
  @moduledoc """
  Enhanced mobile-first components for the comprehensive Portfolio Hub.
  Supports all six feature sections with equal prominence and subscription-based UI.
  """

  use FrestylWeb, :live_component
  import Phoenix.HTML
  alias FrestylWeb.PortfolioHubLive.Helpers

  # ============================================================================
  # ENHANCED MOBILE HEADER COMPONENT
  # ============================================================================

  def mobile_header(assigns) do
    ~H"""
    <!-- Enhanced Mobile Header for Creator Hub -->
    <div class="lg:hidden">
      <!-- Mobile Top Bar with Hub Features -->
      <div class="border-b border-gray-200 bg-white/95 backdrop-blur-sm sticky top-0 z-50">
        <div class="px-4 py-3">
          <div class="flex items-center justify-between">
            <!-- Logo & Dynamic Title -->
            <div class="flex items-center space-x-3">
              <img src="/images/logo.svg" alt="Frestyl" class="w-7 h-7" />
              <div>
                <h1 class="text-lg font-bold text-gray-900">Creator Hub</h1>
                <p class="text-xs text-gray-500"><%= get_active_section_title(@active_section) %></p>
              </div>
            </div>

            <!-- Mobile Actions with Subscription Awareness -->
            <div class="flex items-center space-x-2">
              <!-- Quick Action Button -->
              <%= if @quick_actions && length(@quick_actions) > 0 do %>
                <button
                  phx-click={List.first(@quick_actions).action}
                  class="p-2 bg-purple-100 text-purple-600 rounded-lg transition-colors hover:bg-purple-200"
                  title={List.first(@quick_actions).description}
                >
                  <span class="text-sm"><%= List.first(@quick_actions).icon %></span>
                </button>
              <% end %>

              <!-- Collaboration Bell with Smart Badges -->
              <button
                phx-click="toggle_collaboration_panel"
                class="relative p-2 text-gray-600 hover:text-blue-600 rounded-lg transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                </svg>
                <%= if @collaboration_requests && length(@collaboration_requests) > 0 do %>
                  <span class="absolute -top-1 -right-1 h-4 w-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center animate-pulse">
                    <%= length(@collaboration_requests) %>
                  </span>
                <% end %>
              </button>

              <!-- Revenue Indicator (Professional+ only) -->
              <%= if @account.subscription_tier in ["professional", "enterprise"] do %>
                <button
                  phx-click="switch_section" phx-value-section="revenue_center"
                  class="p-2 text-gray-600 hover:text-green-600 rounded-lg transition-colors"
                  title="Revenue Center"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
                  </svg>
                </button>
              <% end %>

              <!-- Mobile Menu Toggle -->
              <button
                phx-click="toggle_mobile_menu"
                class="p-2 text-gray-600 hover:text-gray-900 rounded-lg transition-colors"
                aria-label="Toggle menu"
              >
                <%= if @show_mobile_menu do %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                <% else %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
                  </svg>
                <% end %>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile Section Navigation Drawer -->
      <%= if @show_mobile_menu do %>
        <div class="bg-white border-b border-gray-200 shadow-lg">
          <div class="px-4 py-3 space-y-1">
            <%= for section <- @hub_config.primary_sections do %>
              <button
                phx-click="switch_section"
                phx-value-section={section}
                class={[
                  "w-full flex items-center px-3 py-2 rounded-lg text-left transition-colors",
                  if(@active_section == section,
                    do: "bg-purple-100 text-purple-700",
                    else: "text-gray-700 hover:bg-gray-100")
                ]}
              >
                <span class="mr-3"><%= get_section_icon(section) %></span>
                <%= Helpers.humanize_section_name(section) %>
                <%= if section in @hub_config.upgrade_prompts do %>
                  <span class="ml-auto px-2 py-0.5 bg-yellow-100 text-yellow-700 text-xs rounded-full">Pro</span>
                <% end %>
              </button>
            <% end %>

            <!-- Secondary sections -->
            <%= if length(@hub_config.secondary_sections) > 0 do %>
              <div class="border-t border-gray-200 mt-3 pt-3">
                <%= for section <- @hub_config.secondary_sections do %>
                  <button
                    phx-click="switch_section"
                    phx-value-section={section}
                    class={[
                      "w-full flex items-center px-3 py-2 rounded-lg text-left transition-colors text-sm",
                      if(@active_section == section,
                        do: "bg-purple-50 text-purple-600",
                        else: "text-gray-600 hover:bg-gray-50")
                    ]}
                  >
                    <span class="mr-3"><%= get_section_icon(section) %></span>
                    <%= Helpers.humanize_section_name(section) %>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: SUBSCRIPTION TIER BADGE COMPONENT
  # ============================================================================

  def subscription_badge(assigns) do
    ~H"""
    <div class={[
      "inline-flex items-center px-3 py-1 rounded-full text-xs font-medium",
      case @tier do
        "personal" -> "bg-gray-100 text-gray-700"
        "creator" -> "bg-blue-100 text-blue-700"
        "professional" -> "bg-purple-100 text-purple-700"
        "enterprise" -> "bg-indigo-100 text-indigo-700"
        _ -> "bg-gray-100 text-gray-700"
      end
    ]}>
      <span class="mr-1"><%= get_tier_icon(@tier) %></span>
      <%= String.capitalize(@tier) %>
    </div>
    """
  end

  # ============================================================================
  # NEW: FEATURE SECTION CARD COMPONENT
  # ============================================================================

  def feature_section_card(assigns) do
    ~H"""
    <div class={[
      "group relative bg-white rounded-xl border transition-all duration-300 overflow-hidden",
      if(@is_active, do: "border-purple-300 shadow-lg", else: "border-gray-200 hover:border-gray-300 hover:shadow-md"),
      if(@is_locked, do: "opacity-75", else: "")
    ]}>
      <!-- Card Header -->
      <div class={[
        "px-6 py-4 border-b border-gray-100",
        if(@is_active, do: "bg-purple-50", else: "bg-gray-50")
      ]}>
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <span class="text-2xl mr-3"><%= @icon %></span>
            <div>
              <h3 class="font-semibold text-gray-900"><%= @title %></h3>
              <p class="text-sm text-gray-600"><%= @description %></p>
            </div>
          </div>

          <%= if @is_locked do %>
            <div class="flex items-center space-x-2">
              <span class="px-2 py-1 bg-yellow-100 text-yellow-700 text-xs rounded-full font-medium">
                <%= @required_tier %>+
              </span>
              <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Card Content -->
      <div class="p-6">
        <%= if @is_locked do %>
          <!-- Locked State -->
          <div class="text-center py-8">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>
            <h4 class="font-medium text-gray-900 mb-2">Unlock <%= @title %></h4>
            <p class="text-sm text-gray-600 mb-4"><%= @upgrade_message %></p>
            <button
              phx-click={@upgrade_action}
              class="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
              Upgrade Now
            </button>
          </div>
        <% else %>
          <!-- Active State Content -->
          <%= render_slot(@inner_block) %>
        <% end %>
      </div>

      <!-- Click Area for Section Navigation -->
      <%= unless @is_locked do %>
        <button
          phx-click="switch_section"
          phx-value-section={@section_key}
          class="absolute inset-0 w-full h-full bg-transparent"
          aria-label={"Navigate to #{@title}"}
        >
        </button>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: METRIC CARD COMPONENT
  # ============================================================================

  def metric_card(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
      <div class="flex items-center">
        <div class={[
          "p-3 rounded-lg",
          case @color do
            "purple" -> "bg-purple-100"
            "blue" -> "bg-blue-100"
            "green" -> "bg-green-100"
            "yellow" -> "bg-yellow-100"
            "red" -> "bg-red-100"
            "indigo" -> "bg-indigo-100"
            "pink" -> "bg-pink-100"
            _ -> "bg-gray-100"
          end
        ]}>
          <svg class={[
            "w-6 h-6",
            case @color do
              "purple" -> "text-purple-600"
              "blue" -> "text-blue-600"
              "green" -> "text-green-600"
              "yellow" -> "text-yellow-600"
              "red" -> "text-red-600"
              "indigo" -> "text-indigo-600"
              "pink" -> "text-pink-600"
              _ -> "text-gray-600"
            end
          ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <%= raw(@icon_path) %>
          </svg>
        </div>
        <div class="ml-4 flex-1">
          <p class="text-sm font-medium text-gray-600"><%= @label %></p>
          <div class="flex items-baseline">
            <p class="text-2xl font-bold text-gray-900"><%= @value %></p>
            <%= if @growth do %>
              <span class={[
                "ml-2 text-sm font-medium",
                if(@growth >= 0, do: "text-green-600", else: "text-red-600")
              ]}>
                <%= if @growth >= 0, do: "+#{@growth}%", else: "#{@growth}%" %>
              </span>
            <% end %>
          </div>
          <%= if @subtitle do %>
            <p class="text-xs text-gray-500 mt-1"><%= @subtitle %></p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NEW: COLLABORATION REQUEST CARD COMPONENT
  # ============================================================================

  def collaboration_request_card(assigns) do
    ~H"""
    <div class="group flex items-center justify-between p-4 border border-purple-200 rounded-lg hover:shadow-md transition-all">
      <div class="flex items-center">
        <div class={[
          "w-10 h-10 rounded-full flex items-center justify-center text-white font-bold",
          get_urgency_color(@request.urgency)
        ]}>
          <%= String.first(@request.user) %>
        </div>
        <div class="ml-4">
          <p class="font-medium text-gray-900"><%= @request.user %></p>
          <p class="text-sm text-gray-600">wants to <%= @request.type %> on "<%= @request.portfolio %>"</p>
          <p class="text-xs text-gray-500"><%= Helpers.relative_date(@request.created_at) %></p>
        </div>
      </div>
      <div class="flex items-center space-x-2">
        <button
          phx-click="accept_collaboration"
          phx-value-request_id={@request.id}
          class="px-3 py-1 bg-green-600 text-white rounded-lg text-sm hover:bg-green-700 transition-colors"
        >
          Accept
        </button>
        <button
          phx-click="decline_collaboration"
          phx-value-request_id={@request.id}
          class="px-3 py-1 bg-gray-300 text-gray-700 rounded-lg text-sm hover:bg-gray-400 transition-colors"
        >
          Decline
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NEW: ENHANCEMENT SUGGESTION CARD COMPONENT
  # ============================================================================

  def enhancement_suggestion_card(assigns) do
    ~H"""
    <div class="group relative bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg p-4 border border-purple-200 hover:border-purple-300 hover:shadow-md transition-all cursor-pointer"
         phx-click="enhance_portfolio"
         phx-value-type={@suggestion.type}
         phx-value-portfolio_id={@suggestion.portfolio_id}>

      <div class="flex items-center mb-3">
        <span class="text-2xl mr-3"><%= @suggestion.icon %></span>
        <div class="flex-1">
          <h3 class="font-semibold text-gray-900 group-hover:text-purple-700 transition-colors">
            <%= @suggestion.title %>
          </h3>
          <%= if @suggestion.urgency do %>
            <span class={[
              "inline-block px-2 py-0.5 text-xs rounded-full mt-1",
              case @suggestion.urgency do
                "high" -> "bg-red-100 text-red-700"
                "medium" -> "bg-yellow-100 text-yellow-700"
                "low" -> "bg-green-100 text-green-700"
                _ -> "bg-gray-100 text-gray-700"
              end
            ]}>
              <%= String.capitalize(@suggestion.urgency) %> Priority
            </span>
          <% end %>
        </div>
        <svg class="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </div>

      <p class="text-sm text-gray-600 mb-3"><%= @suggestion.description %></p>

      <div class="flex items-center justify-between text-xs text-gray-500">
        <span>For: <%= Helpers.get_portfolio_title(@suggestion.portfolio_id, @portfolios) %></span>
        <%= if @suggestion.estimated_time do %>
          <span><%= @suggestion.estimated_time %> min</span>
        <% end %>
      </div>

      <!-- Progress bar if enhancement is in progress -->
      <%= if @suggestion.progress && @suggestion.progress > 0 do %>
        <div class="mt-3">
          <div class="flex justify-between items-center mb-1">
            <span class="text-xs text-gray-600">Progress</span>
            <span class="text-xs text-purple-600"><%= @suggestion.progress %>%</span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-1.5">
            <div class="bg-purple-600 h-1.5 rounded-full transition-all duration-300" style={"width: #{@suggestion.progress}%"}></div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: SERVICE BOOKING CARD COMPONENT
  # ============================================================================

  def service_booking_card(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-md transition-all">
      <div class="flex items-center">
        <div class={[
          "w-10 h-10 rounded-full flex items-center justify-center text-white font-bold",
          case @booking.status do
            "confirmed" -> "bg-green-500"
            "pending" -> "bg-yellow-500"
            "completed" -> "bg-blue-500"
            "cancelled" -> "bg-red-500"
            _ -> "bg-gray-500"
          end
        ]}>
          <%= String.first(@booking.client_name) %>
        </div>
        <div class="ml-4">
          <p class="font-medium text-gray-900"><%= @booking.service_name %></p>
          <p class="text-sm text-gray-600"><%= @booking.client_name %> • <%= @booking.date %> at <%= @booking.time %></p>
          <div class="flex items-center mt-1">
            <span class={[
              "px-2 py-0.5 text-xs rounded-full font-medium",
              case @booking.status do
                "confirmed" -> "bg-green-100 text-green-700"
                "pending" -> "bg-yellow-100 text-yellow-700"
                "completed" -> "bg-blue-100 text-blue-700"
                "cancelled" -> "bg-red-100 text-red-700"
                _ -> "bg-gray-100 text-gray-700"
              end
            ]}>
              <%= String.capitalize(@booking.status) %>
            </span>
            <span class="ml-2 text-xs text-gray-500"><%= @booking.duration %> min</span>
          </div>
        </div>
      </div>
      <div class="flex items-center space-x-3">
        <span class="text-lg font-bold text-green-600">$<%= @booking.amount %></span>
        <button
          phx-click="view_booking_details"
          phx-value-id={@booking.id}
          class="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-xs hover:bg-blue-200 transition-colors"
        >
          Details
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NEW: REVENUE TREND CHART PLACEHOLDER COMPONENT
  # ============================================================================

  def revenue_chart_placeholder(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-bold text-gray-900">Revenue Trends</h2>
        <div class="flex space-x-2">
          <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors">
            7D
          </button>
          <button class="px-3 py-1 bg-purple-600 text-white rounded-lg text-sm">
            30D
          </button>
          <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors">
            90D
          </button>
        </div>
      </div>

      <!-- Chart Placeholder -->
      <div class="h-64 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg flex items-center justify-center border-2 border-dashed border-purple-200">
        <div class="text-center">
          <svg class="w-12 h-12 text-purple-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
          </svg>
          <p class="text-purple-600 font-medium">Revenue Analytics Chart</p>
          <p class="text-sm text-purple-500 mt-1">Integrate with your preferred charting library</p>
        </div>
      </div>

      <!-- Chart Legend -->
      <div class="flex items-center justify-center space-x-6 mt-4">
        <div class="flex items-center">
          <div class="w-3 h-3 bg-purple-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Portfolio Revenue</span>
        </div>
        <div class="flex items-center">
          <div class="w-3 h-3 bg-blue-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Service Revenue</span>
        </div>
        <div class="flex items-center">
          <div class="w-3 h-3 bg-green-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Other Revenue</span>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NEW: QUICK ACTION BUTTON COMPONENT
  # ============================================================================

  def quick_action_button(assigns) do
    ~H"""
    <button
      phx-click={@action.action}
      class={[
        "group inline-flex items-center px-4 py-2 rounded-lg text-sm font-medium transition-all transform hover:scale-105",
        case @action.priority do
          1 -> "bg-purple-600 text-white hover:bg-purple-700 shadow-lg"
          2 -> "bg-blue-600 text-white hover:bg-blue-700"
          3 -> "bg-white border border-gray-300 text-gray-700 hover:bg-gray-50"
          _ -> "bg-gray-100 text-gray-700 hover:bg-gray-200"
        end
      ]}
      title={@action.description}
    >
      <span class="mr-2 group-hover:animate-pulse"><%= @action.icon %></span>
      <%= @action.title %>
      <%= if @action.badge do %>
        <span class="ml-2 px-2 py-0.5 bg-red-500 text-white text-xs rounded-full">
          <%= @action.badge %>
        </span>
      <% end %>
    </button>
    """
  end

  # ============================================================================
  # NEW: EMPTY STATE COMPONENT
  # ============================================================================

  def empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="text-6xl mb-4"><%= @icon %></div>
      <h3 class="text-lg font-medium text-gray-900 mb-2"><%= @title %></h3>
      <p class="text-gray-600 mb-6 max-w-md mx-auto"><%= @description %></p>
      <%= if @action do %>
        <button
          phx-click={@action.action}
          class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-all transform hover:scale-105"
        >
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          <%= @action.title %>
        </button>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp get_active_section_title(section) do
    case section do
      "portfolio_studio" -> "Create & Manage"
      "collaboration_hub" -> "Connect & Collaborate"
      "community_channels" -> "Discover & Engage"
      "creator_lab" -> "Experiment & Innovate"
      "service_dashboard" -> "Bookings & Clients"
      "revenue_center" -> "Analytics & Revenue"
      _ -> "Creator Hub"
    end
  end

  defp get_section_icon(section) do
    case section do
      "portfolio_studio" -> "🎨"
      "collaboration_hub" -> "🤝"
      "community_channels" -> "🌟"
      "creator_lab" -> "🧪"
      "service_dashboard" -> "💼"
      "revenue_center" -> "📊"
      _ -> "📋"
    end
  end

  defp get_urgency_color(urgency) do
    case urgency do
      "high" -> "bg-red-500"
      "medium" -> "bg-yellow-500"
      "low" -> "bg-green-500"
      _ -> "bg-gray-500"
    end
  end

  # ============================================================================
  # NEW: PORTFOLIO GRID COMPONENT
  # ============================================================================

  def portfolio_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <%= for portfolio <- @portfolios do %>
        <div class="group border border-gray-200 rounded-lg hover:shadow-lg transition-all duration-300 overflow-hidden">
          <!-- Portfolio Preview -->
          <div class={[
            "w-full h-32 flex items-center justify-center relative overflow-hidden",
            case portfolio.theme do
              "executive" -> "bg-gradient-to-br from-blue-500 to-indigo-600"
              "creative" -> "bg-gradient-to-br from-purple-500 to-pink-600"
              "developer" -> "bg-gradient-to-br from-green-500 to-teal-600"
              "designer" -> "bg-gradient-to-br from-orange-500 to-red-600"
              "academic" -> "bg-gradient-to-br from-indigo-500 to-purple-600"
              "consultant" -> "bg-gradient-to-br from-gray-600 to-gray-800"
              _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
            end
          ]}>
            <div class="text-center text-white z-10">
              <h4 class="font-bold text-lg drop-shadow-lg"><%= portfolio.title %></h4>
              <p class="text-sm opacity-90 drop-shadow">/<%= portfolio.slug %></p>
            </div>

            <!-- Hover overlay -->
            <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-10 transition-all duration-300"></div>

            <!-- Status indicator -->
            <div class="absolute top-2 right-2">
              <span class={[
                "px-2 py-1 text-xs rounded-full font-medium",
                if(portfolio.visibility == :public,
                  do: "bg-green-500 text-white",
                  else: "bg-yellow-500 text-white")
              ]}>
                <%= if portfolio.visibility == :public, do: "Live", else: "Draft" %>
              </span>
            </div>

            <!-- Collaboration indicators -->
            <%= if @show_collaboration_indicators && Map.get(@portfolio_stats, portfolio.id) do %>
              <% stats = Map.get(@portfolio_stats, portfolio.id) %>
              <%= if Map.get(stats, :collaborations) && length(stats.collaborations) > 0 do %>
                <div class="absolute top-2 left-2 flex -space-x-1">
                  <%= for collab <- Enum.take(stats.collaborations, 3) do %>
                    <div class="w-6 h-6 bg-white bg-opacity-90 rounded-full border border-white flex items-center justify-center text-xs text-gray-700 font-bold">
                      <%= String.first(collab.user) %>
                    </div>
                  <% end %>
                  <%= if length(stats.collaborations) > 3 do %>
                    <div class="w-6 h-6 bg-white bg-opacity-90 rounded-full border border-white flex items-center justify-center text-xs text-gray-700">
                      +<%= length(stats.collaborations) - 3 %>
                    </div>
                  <% end %>
                </div>
              <% end %>
            <% end %>
          </div>

          <!-- Portfolio Info -->
          <div class="p-4">
            <div class="flex items-start justify-between mb-3">
              <div class="flex-1">
                <h3 class="font-semibold text-gray-900 group-hover:text-purple-600 transition-colors line-clamp-1">
                  <%= portfolio.title %>
                </h3>
                <p class="text-sm text-gray-600 mt-1 line-clamp-2">
                  <%= portfolio.description || "No description available" %>
                </p>
              </div>
            </div>

            <!-- Portfolio Stats -->
            <%= if @show_stats && Map.get(@portfolio_stats, portfolio.id) do %>
              <% stats = Map.get(@portfolio_stats, portfolio.id) %>
              <div class="flex items-center justify-between text-sm text-gray-500 mb-4">
                <div class="flex items-center space-x-4">
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                    </svg>
                    <%= Map.get(stats, :total_visits, 0) %>
                  </span>
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"/>
                    </svg>
                    <%= Map.get(stats, :total_shares, 0) %>
                  </span>
                </div>
                <span class="text-xs">
                  Updated <%= Helpers.relative_date(portfolio.updated_at) %>
                </span>
              </div>
            <% end %>

            <!-- Action Buttons -->
            <div class="flex items-center justify-between">
              <div class="flex space-x-2">
                <.link href={"/portfolios/#{portfolio.id}/edit"}
                      class="text-xs px-3 py-1.5 bg-purple-100 text-purple-700 rounded-lg hover:bg-purple-200 transition-colors font-medium">
                  <svg class="w-3 h-3 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                  Edit
                </.link>
                <.link href={"/p/#{portfolio.slug}"} target="_blank"
                      class="text-xs px-3 py-1.5 bg-blue-100 text-blue-700 rounded-lg hover:bg-blue-200 transition-colors font-medium">
                  <svg class="w-3 h-3 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                  View
                </.link>
              </div>

              <!-- Portfolio Menu -->
              <div class="relative">
                <button
                  phx-click="toggle_portfolio_menu"
                  phx-value-portfolio_id={portfolio.id}
                  class="p-1 text-gray-400 hover:text-gray-600 rounded transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: CHANNEL DISCOVERY COMPONENT
  # ============================================================================

  def channel_discovery_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
      <%= for channel <- @channels do %>
        <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-all group">
          <div class="flex items-center mb-3">
            <div class={[
              "w-10 h-10 rounded-lg flex items-center justify-center text-white font-bold",
              case channel.type || channel.category do
                "portfolio" -> "bg-gradient-to-br from-purple-500 to-blue-500"
                "collaboration" -> "bg-gradient-to-br from-green-500 to-teal-500"
                "design" -> "bg-gradient-to-br from-pink-500 to-rose-500"
                "development" -> "bg-gradient-to-br from-blue-500 to-indigo-500"
                "creative" -> "bg-gradient-to-br from-orange-500 to-red-500"
                _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
              end
            ]}>
              <%= String.first(channel.name) %>
            </div>
            <div class="ml-3 flex-1">
              <h3 class="font-semibold text-gray-900 group-hover:text-purple-600 transition-colors">
                <%= channel.name %>
              </h3>
              <p class="text-sm text-gray-600">
                <%= channel.type || channel.category %>
                <%= if channel.is_trending do %>
                  <span class="ml-1 text-orange-500">🔥</span>
                <% end %>
              </p>
            </div>
            <%= if channel.activity_level do %>
              <div class={[
                "w-2 h-2 rounded-full",
                case channel.activity_level do
                  "high" -> "bg-green-500"
                  "medium" -> "bg-yellow-500"
                  "low" -> "bg-orange-500"
                  _ -> "bg-gray-300"
                end
              ]}></div>
            <% end %>
          </div>

          <p class="text-sm text-gray-600 mb-4 line-clamp-2"><%= channel.description %></p>

          <div class="flex items-center justify-between">
            <div class="flex items-center text-xs text-gray-500">
              <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
              </svg>
              <%= Helpers.format_number(channel.member_count || 0) %> members
            </div>

            <button
              phx-click="join_channel"
              phx-value-channel_id={channel.id}
              class={[
                "px-3 py-1 rounded-full text-xs font-medium transition-colors",
                if(@user_channel_ids && channel.id in @user_channel_ids,
                  do: "bg-green-100 text-green-700 cursor-default",
                  else: "bg-purple-600 text-white hover:bg-purple-700")
              ]}
            >
              <%= if @user_channel_ids && channel.id in @user_channel_ids do %>
                Joined
              <% else %>
                Join
              <% end %>
            </button>
          </div>

          <!-- Match reasons for recommendations -->
          <%= if channel.match_reasons && length(channel.match_reasons) > 0 do %>
            <div class="mt-3 pt-3 border-t border-gray-100">
              <p class="text-xs text-gray-500 mb-1">Recommended because:</p>
              <div class="flex flex-wrap gap-1">
                <%= for reason <- Enum.take(channel.match_reasons, 2) do %>
                  <span class="px-2 py-0.5 bg-blue-50 text-blue-700 text-xs rounded-full">
                    <%= reason %>
                  </span>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: LAB FEATURE CARD COMPONENT
  # ============================================================================

  def lab_feature_card(assigns) do
    ~H"""
    <div class="border border-purple-200 rounded-lg p-4 hover:shadow-md transition-all bg-gradient-to-br from-purple-50 to-pink-50 group">
      <div class="flex items-center mb-3">
        <span class="text-2xl mr-3"><%= @feature.icon %></span>
        <div class="flex-1">
          <div class="flex items-center">
            <h3 class="font-semibold text-gray-900 group-hover:text-purple-700 transition-colors">
              <%= @feature.name %>
            </h3>
            <span class={[
              "ml-2 px-2 py-0.5 text-xs rounded-full font-medium",
              case @feature.status do
                "beta" -> "bg-yellow-100 text-yellow-700"
                "experimental" -> "bg-red-100 text-red-700"
                "stable" -> "bg-green-100 text-green-700"
                _ -> "bg-gray-100 text-gray-700"
              end
            ]}>
              <%= String.capitalize(@feature.status) %>
            </span>
          </div>
          <%= if @feature.complexity do %>
            <div class="flex items-center mt-1">
              <%= for i <- 1..3 do %>
                <svg class={[
                  "w-3 h-3",
                  if(i <= complexity_level(@feature.complexity), do: "text-purple-500", else: "text-gray-300")
                ]} fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                </svg>
              <% end %>
              <span class="ml-1 text-xs text-gray-500"><%= String.capitalize(@feature.complexity) %></span>
            </div>
          <% end %>
        </div>
      </div>

      <p class="text-sm text-gray-600 mb-4"><%= @feature.description %></p>

      <div class="flex items-center justify-between">
        <%= if @feature.estimated_time do %>
          <div class="flex items-center text-xs text-gray-500">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            ~<%= @feature.estimated_time %> min
          </div>
        <% else %>
          <div></div>
        <% end %>

        <button
          phx-click="try_lab_feature"
          phx-value-feature_id={@feature.id}
          class="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm font-medium"
        >
          Try Feature
        </button>
      </div>

      <!-- Prerequisites if any -->
      <%= if @feature.prerequisites && length(@feature.prerequisites) > 0 do %>
        <div class="mt-3 pt-3 border-t border-purple-200">
          <p class="text-xs text-gray-500 mb-1">Prerequisites:</p>
          <div class="flex flex-wrap gap-1">
            <%= for prereq <- @feature.prerequisites do %>
              <span class="px-2 py-0.5 bg-purple-100 text-purple-700 text-xs rounded-full">
                <%= prereq %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: NOTIFICATION TOAST COMPONENT
  # ============================================================================

  def notification_toast(assigns) do
    ~H"""
    <div class={[
      "fixed top-4 right-4 z-50 max-w-sm w-full bg-white rounded-lg shadow-lg border-l-4 p-4 transform transition-all duration-300",
      case @type do
        "success" -> "border-green-500"
        "error" -> "border-red-500"
        "warning" -> "border-yellow-500"
        "info" -> "border-blue-500"
        _ -> "border-gray-300"
      end,
      if(@show, do: "translate-x-0 opacity-100", else: "translate-x-full opacity-0")
    ]}>
      <div class="flex items-start">
        <div class={[
          "flex-shrink-0 w-5 h-5 mr-3 mt-0.5",
          case @type do
            "success" -> "text-green-500"
            "error" -> "text-red-500"
            "warning" -> "text-yellow-500"
            "info" -> "text-blue-500"
            _ -> "text-gray-500"
          end
        ]}>
          <%= case @type do %>
            <% "success" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
              </svg>
            <% "error" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            <% "warning" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
              </svg>
            <% _ -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
          <% end %>
        </div>

        <div class="flex-1">
          <%= if @title do %>
            <p class="text-sm font-medium text-gray-900"><%= @title %></p>
          <% end %>
          <p class={[
            "text-sm",
            if(@title, do: "text-gray-600 mt-1", else: "text-gray-900")
          ]}>
            <%= @message %>
          </p>
        </div>

        <button
          phx-click="dismiss_notification"
          phx-value-id={@id}
          class="flex-shrink-0 ml-3 text-gray-400 hover:text-gray-600 transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # UTILITY FUNCTIONS (Additional)
  # ============================================================================

  defp complexity_level(complexity) do
    case complexity do
      "beginner" -> 1
      "intermediate" -> 2
      "advanced" -> 3
      _ -> 1
    end
  end

  # ============================================================================
  # NEW: LOADING SKELETON COMPONENTS
  # ============================================================================

  def skeleton_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-6 animate-pulse">
      <div class="flex items-center mb-4">
        <div class="w-10 h-10 bg-gray-300 rounded-lg"></div>
        <div class="ml-4 flex-1">
          <div class="h-4 bg-gray-300 rounded w-3/4 mb-2"></div>
          <div class="h-3 bg-gray-300 rounded w-1/2"></div>
        </div>
      </div>
      <div class="space-y-2">
        <div class="h-3 bg-gray-300 rounded"></div>
        <div class="h-3 bg-gray-300 rounded w-5/6"></div>
        <div class="h-3 bg-gray-300 rounded w-4/6"></div>
      </div>
      <div class="flex justify-between items-center mt-4">
        <div class="h-8 bg-gray-300 rounded w-20"></div>
        <div class="h-8 bg-gray-300 rounded w-16"></div>
      </div>
    </div>
    """
  end

  def skeleton_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <%= for _ <- 1..(@count || 6) do %>
        <.skeleton_card />
      <% end %>
    </div>
    """
  end

# ============================================================================
  # NEW: PROGRESS BAR COMPONENT
  # ============================================================================

  def progress_bar(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @label do %>
        <div class="flex justify-between items-center mb-2">
          <span class="text-sm font-medium text-gray-700"><%= @label %></span>
          <span class="text-sm text-gray-500"><%= @percentage %>%</span>
        </div>
      <% end %>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div
          class={[
            "h-2 rounded-full transition-all duration-300",
            case @color do
              "purple" -> "bg-purple-600"
              "blue" -> "bg-blue-600"
              "green" -> "bg-green-600"
              "yellow" -> "bg-yellow-600"
              "red" -> "bg-red-600"
              _ -> "bg-gray-600"
            end
          ]}
          style={"width: #{@percentage}%"}
        ></div>
      </div>
      <%= if @subtitle do %>
        <p class="text-xs text-gray-500 mt-1"><%= @subtitle %></p>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: AVATAR COMPONENT
  # ============================================================================

  def user_avatar(assigns) do
    ~H"""
    <div class={[
      "flex items-center justify-center rounded-full text-white font-bold",
      case @size do
        "xs" -> "w-6 h-6 text-xs"
        "sm" -> "w-8 h-8 text-sm"
        "md" -> "w-10 h-10 text-base"
        "lg" -> "w-12 h-12 text-lg"
        "xl" -> "w-16 h-16 text-xl"
        _ -> "w-10 h-10 text-base"
      end,
      case @color do
        "purple" -> "bg-purple-500"
        "blue" -> "bg-blue-500"
        "green" -> "bg-green-500"
        "yellow" -> "bg-yellow-500"
        "red" -> "bg-red-500"
        "indigo" -> "bg-indigo-500"
        "pink" -> "bg-pink-500"
        "orange" -> "bg-orange-500"
        _ -> "bg-gray-500"
      end
    ]}>
      <%= if @image_url do %>
        <img src={@image_url} alt={@name} class="w-full h-full rounded-full object-cover" />
      <% else %>
        <%= String.first(@name || "?") %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: STATS GRID COMPONENT
  # ============================================================================

  def stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <%= for stat <- @stats do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
          <div class="flex items-center">
            <div class={[
              "p-3 rounded-lg",
              case stat.color do
                "purple" -> "bg-purple-100"
                "blue" -> "bg-blue-100"
                "green" -> "bg-green-100"
                "yellow" -> "bg-yellow-100"
                "red" -> "bg-red-100"
                "indigo" -> "bg-indigo-100"
                "pink" -> "bg-pink-100"
                _ -> "bg-gray-100"
              end
            ]}>
              <%= if stat.icon do %>
                <span class="text-2xl"><%= stat.icon %></span>
              <% else %>
                <svg class={[
                  "w-6 h-6",
                  case stat.color do
                    "purple" -> "text-purple-600"
                    "blue" -> "text-blue-600"
                    "green" -> "text-green-600"
                    "yellow" -> "text-yellow-600"
                    "red" -> "text-red-600"
                    "indigo" -> "text-indigo-600"
                    "pink" -> "text-pink-600"
                    _ -> "text-gray-600"
                  end
                ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= raw(stat.svg_path) %>
                </svg>
              <% end %>
            </div>
            <div class="ml-4 flex-1">
              <p class="text-sm font-medium text-gray-600"><%= stat.label %></p>
              <div class="flex items-baseline">
                <p class="text-2xl font-bold text-gray-900"><%= stat.value %></p>
                <%= if stat.change do %>
                  <span class={[
                    "ml-2 text-sm font-medium",
                    if(stat.change >= 0, do: "text-green-600", else: "text-red-600")
                  ]}>
                    <%= if stat.change >= 0, do: "+#{stat.change}%", else: "#{stat.change}%" %>
                  </span>
                <% end %>
              </div>
              <%= if stat.subtitle do %>
                <p class="text-xs text-gray-500 mt-1"><%= stat.subtitle %></p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: ACTION BUTTON GRID COMPONENT
  # ============================================================================

  def action_button_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <%= for action <- @actions do %>
        <button
          phx-click={action.action}
          phx-value-id={action.id}
          class={[
            "group relative p-6 bg-white border border-gray-200 rounded-xl hover:shadow-lg transition-all duration-300 text-left",
            if(action.disabled, do: "opacity-50 cursor-not-allowed", else: "hover:border-purple-300")
          ]}
          disabled={action.disabled}
        >
          <div class="flex items-center mb-4">
            <div class={[
              "w-12 h-12 rounded-lg flex items-center justify-center",
              case action.color do
                "purple" -> "bg-purple-100 group-hover:bg-purple-200"
                "blue" -> "bg-blue-100 group-hover:bg-blue-200"
                "green" -> "bg-green-100 group-hover:bg-green-200"
                "yellow" -> "bg-yellow-100 group-hover:bg-yellow-200"
                "red" -> "bg-red-100 group-hover:bg-red-200"
                _ -> "bg-gray-100 group-hover:bg-gray-200"
              end
            ]}>
              <span class="text-2xl"><%= action.icon %></span>
            </div>
            <%= if action.badge do %>
              <span class="ml-auto px-2 py-1 bg-red-500 text-white text-xs rounded-full">
                <%= action.badge %>
              </span>
            <% end %>
          </div>

          <h3 class="font-semibold text-gray-900 mb-2 group-hover:text-purple-700 transition-colors">
            <%= action.title %>
          </h3>

          <p class="text-sm text-gray-600 mb-4"><%= action.description %></p>

          <%= if action.progress do %>
            <div class="mb-4">
              <div class="flex justify-between items-center mb-1">
                <span class="text-xs text-gray-500">Progress</span>
                <span class="text-xs text-purple-600"><%= action.progress %>%</span>
              </div>
              <div class="w-full bg-gray-200 rounded-full h-1.5">
                <div class="bg-purple-600 h-1.5 rounded-full transition-all duration-300" style={"width: #{action.progress}%"}></div>
              </div>
            </div>
          <% end %>

          <div class="flex items-center justify-between">
            <%= if action.time_estimate do %>
              <span class="text-xs text-gray-500">~<%= action.time_estimate %> min</span>
            <% else %>
              <div></div>
            <% end %>

            <svg class="w-4 h-4 text-gray-400 group-hover:text-purple-600 group-hover:translate-x-1 transition-all" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
            </svg>
          </div>

          <%= if action.disabled do %>
            <div class="absolute inset-0 bg-gray-50 bg-opacity-75 rounded-xl flex items-center justify-center">
              <span class="px-3 py-1 bg-yellow-100 text-yellow-700 text-xs rounded-full font-medium">
                <%= action.disabled_reason || "Coming Soon" %>
              </span>
            </div>
          <% end %>
        </button>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # NEW: TIMELINE COMPONENT
  # ============================================================================

  def activity_timeline(assigns) do
    ~H"""
    <div class="flow-root">
      <ul class="-mb-8">
        <%= for {activity, index} <- Enum.with_index(@activities) do %>
          <li>
            <div class="relative pb-8">
              <%= if index != length(@activities) - 1 do %>
                <span class="absolute top-4 left-4 -ml-px h-full w-0.5 bg-gray-200" aria-hidden="true"></span>
              <% end %>
              <div class="relative flex space-x-3">
                <div>
                  <span class={[
                    "h-8 w-8 rounded-full flex items-center justify-center ring-8 ring-white",
                    case activity.type do
                      "success" -> "bg-green-500"
                      "warning" -> "bg-yellow-500"
                      "error" -> "bg-red-500"
                      "info" -> "bg-blue-500"
                      _ -> "bg-gray-500"
                    end
                  ]}>
                    <%= case activity.type do %>
                      <% "success" -> %>
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                      <% "warning" -> %>
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
                        </svg>
                      <% "error" -> %>
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                      <% _ -> %>
                        <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                    <% end %>
                  </span>
                </div>
                <div class="min-w-0 flex-1 pt-1.5 flex justify-between space-x-4">
                  <div>
                    <p class="text-sm text-gray-900">
                      <%= activity.message %>
                      <%= if activity.target do %>
                        <span class="font-medium text-gray-900"><%= activity.target %></span>
                      <% end %>
                    </p>
                    <%= if activity.description do %>
                      <p class="text-sm text-gray-500"><%= activity.description %></p>
                    <% end %>
                  </div>
                  <div class="text-right text-sm whitespace-nowrap text-gray-500">
                    <%= Helpers.relative_date(activity.timestamp) %>
                  </div>
                </div>
              </div>
            </div>
          </li>
        <% end %>
      </ul>
    </div>
    """
  end

  # ============================================================================
  # NEW: FEATURE COMPARISON COMPONENT
  # ============================================================================

  def feature_comparison_table(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-200">
        <h3 class="text-lg font-semibold text-gray-900">Feature Comparison</h3>
      </div>

      <div class="overflow-x-auto">
        <table class="min-w-full divide-y divide-gray-200">
          <thead class="bg-gray-50">
            <tr>
              <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                Feature
              </th>
              <%= for tier <- @tiers do %>
                <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div class="flex flex-col items-center">
                    <span><%= tier.name %></span>
                    <span class="text-lg font-bold text-gray-900 mt-1">$<%= tier.price %></span>
                    <span class="text-xs text-gray-500">per month</span>
                  </div>
                </th>
              <% end %>
            </tr>
          </thead>
          <tbody class="bg-white divide-y divide-gray-200">
            <%= for feature <- @features do %>
              <tr>
                <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900">
                  <%= feature.name %>
                  <%= if feature.description do %>
                    <p class="text-xs text-gray-500 mt-1"><%= feature.description %></p>
                  <% end %>
                </td>
                <%= for tier <- @tiers do %>
                  <td class="px-6 py-4 whitespace-nowrap text-center">
                    <%= case Map.get(feature.availability, tier.key) do %>
                      <% true -> %>
                        <svg class="w-5 h-5 text-green-500 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                      <% false -> %>
                        <svg class="w-5 h-5 text-gray-300 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                      <% value when is_binary(value) -> %>
                        <span class="text-sm text-gray-900"><%= value %></span>
                      <% _ -> %>
                        <span class="text-sm text-gray-400">-</span>
                    <% end %>
                  </td>
                <% end %>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>

      <div class="px-6 py-4 bg-gray-50 border-t border-gray-200">
        <div class="flex justify-center space-x-4">
          <%= for tier <- @tiers do %>
            <button
              phx-click="select_tier"
              phx-value-tier={tier.key}
              class={[
                "px-6 py-2 rounded-lg text-sm font-medium transition-colors",
                if(tier.current,
                  do: "bg-gray-300 text-gray-500 cursor-default",
                  else: "bg-purple-600 text-white hover:bg-purple-700")
              ]}
              disabled={tier.current}
            >
              <%= if tier.current do %>
                Current Plan
              <% else %>
                Choose <%= tier.name %>
              <% end %>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # UTILITY FUNCTIONS (Additional)
  # ============================================================================

  defp get_tier_icon(tier) do
    case tier do
      "personal" -> "👤"
      "creator" -> "🎨"
      "professional" -> "💼"
      "enterprise" -> "🏢"
      _ -> "📋"
    end
  end

  defp complexity_level(complexity) do
    case complexity do
      "beginner" -> 1
      "intermediate" -> 2
      "advanced" -> 3
      _ -> 1
    end
  end

  defp get_urgency_color(urgency) do
    case urgency do
      "high" -> "bg-red-500"
      "medium" -> "bg-yellow-500"
      "low" -> "bg-green-500"
      _ -> "bg-gray-500"
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR TEMPLATE INTEGRATION
  # ============================================================================

  @doc """
  Renders a conditional wrapper around content
  """
  def conditional_wrapper(assigns) do
    ~H"""
    <%= if @condition do %>
      <div class={@wrapper_class}>
        <%= render_slot(@inner_block) %>
      </div>
    <% else %>
      <%= render_slot(@inner_block) %>
    <% end %>
    """
  end

  @doc """
  Renders a responsive container with proper spacing
  """
  def responsive_container(assigns) do
    ~H"""
    <div class={[
      "mx-auto px-4 sm:px-6 lg:px-8",
      case @size do
        "sm" -> "max-w-2xl"
        "md" -> "max-w-4xl"
        "lg" -> "max-w-6xl"
        "xl" -> "max-w-7xl"
        "full" -> "max-w-full"
        _ -> "max-w-7xl"
      end
    ]}>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a section with proper spacing and optional background
  """
  def content_section(assigns) do
    ~H"""
    <section class={[
      "py-8 lg:py-12",
      case @background do
        "gray" -> "bg-gray-50"
        "white" -> "bg-white"
        "purple" -> "bg-purple-50"
        "blue" -> "bg-blue-50"
        _ -> ""
      end
    ]}>
      <.responsive_container size={@container_size || "xl"}>
        <%= if @title do %>
          <div class="text-center mb-8 lg:mb-12">
            <h2 class="text-3xl font-bold text-gray-900 mb-4"><%= @title %></h2>
            <%= if @description do %>
              <p class="text-xl text-gray-600 max-w-3xl mx-auto"><%= @description %></p>
            <% end %>
          </div>
        <% end %>

        <%= render_slot(@inner_block) %>
      </.responsive_container>
    </section>
    """
  end

end
