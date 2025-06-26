# lib/frestyl_web/live/portfolio_hub_live/components.ex
# Mobile-First Components for Portfolio Hub

defmodule FrestylWeb.PortfolioHubLive.Components do
  @moduledoc """
  Mobile-first components for the Portfolio Hub that enhance the existing GitHub × Behance design.
  Built on your existing Tailwind CSS patterns and touch interactions.
  """

  use FrestylWeb, :live_component
  import Phoenix.HTML

  # ============================================================================
  # MOBILE NAVIGATION COMPONENT
  # ============================================================================

  def mobile_header(assigns) do
    ~H"""
    <!-- Enhanced Mobile Header - Slide Down -->
    <div class="lg:hidden">
      <!-- Mobile Top Bar -->
      <div class="border-b border-gray-200 bg-white/95 backdrop-blur-sm sticky top-0 z-50">
        <div class="px-4 py-3">
          <div class="flex items-center justify-between">
            <!-- Logo & Hub Title -->
            <div class="flex items-center space-x-3">
              <img src="/images/logo.svg" alt="Frestyl" class="w-7 h-7" />
              <h1 class="text-lg font-bold text-gray-900">Portfolio Hub</h1>
            </div>

            <!-- Mobile Actions -->
            <div class="flex items-center space-x-2">
              <!-- Collaboration Bell -->
              <button
                phx-click="toggle_collaboration_panel"
                class="relative p-2 text-gray-600 hover:text-blue-600 rounded-lg transition-colors"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"/>
                </svg>
                <%= if length(@collaboration_requests) > 0 do %>
                  <span class="absolute -top-1 -right-1 h-4 w-4 bg-red-500 text-white text-xs rounded-full flex items-center justify-center animate-pulse">
                    <%= length(@collaboration_requests) %>
                  </span>
                <% end %>
              </button>

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

          <!-- Mobile Tab Navigation (slide down when menu open) -->
          <%= if @show_mobile_menu do %>
            <div class="mt-4 pb-3 border-t border-gray-100 pt-3 animate-slide-down">
              <nav class="flex flex-col space-y-1">
                <button
                  phx-click="set_active_tab"
                  phx-value-tab="overview"
                  class={[
                    "px-3 py-2 text-sm font-medium rounded-lg transition-colors text-left",
                    if(@active_tab == "overview", do: "bg-blue-50 text-blue-600 border-l-4 border-blue-500", else: "text-gray-600 hover:text-gray-900 hover:bg-gray-50")
                  ]}
                >
                  📊 Overview
                </button>
                <.link
                  navigate="/portfolios/dashboard"
                  phx-click="toggle_mobile_menu"
                  class="px-3 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 hover:bg-gray-50 rounded-lg transition-colors"
                >
                  📈 Dashboard
                </.link>
                <.link
                  navigate="/studio"
                  phx-click="toggle_mobile_menu"
                  class="px-3 py-2 text-sm font-medium text-gray-600 hover:text-gray-900 hover:bg-gray-50 rounded-lg transition-colors"
                >
                  🎵 Studio
                </.link>
              </nav>

              <!-- Mobile Create Button -->
              <div class="mt-4 pt-3 border-t border-gray-100">
                <button
                  phx-click="show_create_modal"
                  class="w-full flex items-center justify-center px-4 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
                >
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  New Portfolio
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MOBILE PORTFOLIO GRID COMPONENT
  # ============================================================================

  def mobile_portfolio_grid(assigns) do
    ~H"""
    <!-- Mobile-Optimized Portfolio Grid -->
    <div class="lg:hidden">
      <!-- Mobile Filter Bar -->
      <div class="bg-white border-b border-gray-200 px-4 py-3 sticky top-[73px] z-40">
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <h3 class="text-base font-semibold text-gray-900">Your Portfolios</h3>
            <span class="px-2 py-1 bg-gray-100 text-gray-600 rounded-full text-xs font-medium">
              <%= length(@portfolios) %>
            </span>
          </div>

          <!-- Mobile Filter Toggle -->
          <button
            phx-click="toggle_mobile_filters"
            class="flex items-center space-x-1 px-3 py-2 bg-gray-100 rounded-lg text-sm font-medium text-gray-700 hover:bg-gray-200 transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.293A1 1 0 013 6.586V4z"/>
            </svg>
            <span>Filter</span>
          </button>
        </div>

        <!-- Mobile Filter Panel -->
        <%= if @show_mobile_filters do %>
          <div class="mt-3 p-3 bg-gray-50 rounded-lg animate-slide-down">
            <div class="flex flex-wrap gap-2">
              <button
                phx-click="filter_portfolios"
                phx-value-status="all"
                class={[
                  "px-3 py-2 text-xs font-medium rounded-full transition-colors",
                  if(@filter_status == "all", do: "bg-blue-500 text-white", else: "bg-white text-gray-700 hover:bg-gray-100")
                ]}
              >
                All
              </button>
              <button
                phx-click="filter_portfolios"
                phx-value-status="published"
                class={[
                  "px-3 py-2 text-xs font-medium rounded-full transition-colors",
                  if(@filter_status == "published", do: "bg-green-500 text-white", else: "bg-white text-gray-700 hover:bg-gray-100")
                ]}
              >
                Published
              </button>
              <button
                phx-click="filter_portfolios"
                phx-value-status="collaborative"
                class={[
                  "px-3 py-2 text-xs font-medium rounded-full transition-colors",
                  if(@filter_status == "collaborative", do: "bg-purple-500 text-white", else: "bg-white text-gray-700 hover:bg-gray-100")
                ]}
              >
                Collaborative
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Mobile Portfolio Cards -->
      <div class="p-4">
        <%= if length(@portfolios) == 0 do %>
          <!-- Mobile Empty State -->
          <div class="text-center py-12">
            <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 rounded-full flex items-center justify-center">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Create your first portfolio</h3>
            <p class="text-gray-600 mb-6 text-sm px-4">Showcase your work and connect with opportunities</p>
            <button
              phx-click="show_create_modal"
              class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
            >
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Create Portfolio
            </button>
          </div>
        <% else %>
          <!-- Mobile Portfolio Cards -->
          <div class="space-y-4">
            <%= for portfolio <- get_filtered_portfolios(@portfolios, @filter_status) do %>
              <div class="bg-white border border-gray-200 rounded-xl shadow-sm overflow-hidden">
                <!-- Portfolio Preview -->
                <div class={[
                  "h-24 flex items-center justify-center relative",
                  case portfolio.theme do
                    "executive" -> "bg-gradient-to-br from-blue-500 to-indigo-600"
                    "creative" -> "bg-gradient-to-br from-purple-500 to-pink-600"
                    "developer" -> "bg-gradient-to-br from-green-500 to-teal-600"
                    _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
                  end
                ]}>
                  <div class="text-center text-white">
                    <h4 class="font-bold text-base"><%= portfolio.title %></h4>
                    <p class="text-xs opacity-90">/<%= portfolio.slug %></p>
                  </div>

                  <!-- Collaboration Indicators - Mobile Positioned -->
                  <%= if stats = Map.get(@portfolio_stats, portfolio.id) do %>
                    <div class="absolute top-2 right-2 flex items-center space-x-1">
                      <%= if length(Map.get(stats, :collaborations, [])) > 0 do %>
                        <div class="flex -space-x-1">
                          <%= for collab <- Enum.take(stats.collaborations, 2) do %>
                            <div class="w-6 h-6 bg-white bg-opacity-30 rounded-full border border-white flex items-center justify-center text-xs text-white font-bold">
                              <%= String.first(collab.user) %>
                            </div>
                          <% end %>
                          <%= if length(stats.collaborations) > 2 do %>
                            <div class="w-6 h-6 bg-white bg-opacity-30 rounded-full border border-white flex items-center justify-center text-xs text-white">
                              +<%= length(stats.collaborations) - 2 %>
                            </div>
                          <% end %>
                        </div>
                      <% end %>
                    </div>
                  <% end %>
                </div>

                <!-- Portfolio Info -->
                <div class="p-4">
                  <div class="mb-3">
                    <h3 class="font-semibold text-gray-900 text-base mb-1 line-clamp-1">
                      <%= portfolio.title %>
                    </h3>
                    <p class="text-sm text-gray-600 line-clamp-2"><%= portfolio.description %></p>
                  </div>

                  <!-- Mobile Stats Row -->
                  <div class="flex items-center justify-between text-sm text-gray-500 mb-4">
                    <div class="flex items-center space-x-4">
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                        <%= Map.get(@portfolio_stats, portfolio.id, %{}) |> Map.get(:stats, %{}) |> Map.get(:total_visits, 0) %>
                      </span>
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V5a2 2 0 00-2-2H9a2 2 0 00-2 2v3m10 0v3a2 2 0 01-2 2H9a2 2 0 01-2-2v-3"/>
                        </svg>
                        <%= Map.get(@portfolio_stats, portfolio.id, %{}) |> Map.get(:comments, 0) %>
                      </span>
                    </div>
                    <span class="text-xs">
                      <%= relative_date(portfolio.updated_at) %>
                    </span>
                  </div>

                  <!-- Mobile Action Buttons -->
                  <div class="flex space-x-2">
                    <.link
                      href={"/portfolios/#{portfolio.id}/edit"}
                      class="flex-1 flex items-center justify-center px-3 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors text-sm font-medium"
                    >
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                      Edit
                    </.link>

                    <.link
                      href={"/p/#{portfolio.slug}"}
                      target="_blank"
                      class="flex-1 flex items-center justify-center px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium"
                    >
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                      </svg>
                      View
                    </.link>
                  </div>

                  <!-- Mobile Collaboration Actions -->
                  <div class="flex space-x-2 mt-2">
                    <button
                      phx-click="request_feedback"
                      phx-value-portfolio_id={portfolio.id}
                      class="flex-1 flex items-center justify-center px-3 py-2 border border-orange-300 text-orange-600 rounded-lg hover:bg-orange-50 transition-colors text-sm font-medium"
                    >
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V5a2 2 0 00-2-2H9a2 2 0 00-2 2v3m10 0v3a2 2 0 01-2 2H9a2 2 0 01-2-2v-3"/>
                      </svg>
                      Feedback
                    </button>

                    <button
                      phx-click="start_collaboration"
                      phx-value-portfolio_id={portfolio.id}
                      class="flex-1 flex items-center justify-center px-3 py-2 border border-purple-300 text-purple-600 rounded-lg hover:bg-purple-50 transition-colors text-sm font-medium"
                    >
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                      </svg>
                      Collaborate
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MOBILE SIDEBAR COMPONENT
  # ============================================================================

  def mobile_sidebar(assigns) do
    ~H"""
    <!-- Mobile Sidebar - Slide from Right -->
    <div class="lg:hidden">
      <!-- Mobile Floating Action Button -->
      <div class="fixed bottom-6 right-6 z-40">
        <button
          phx-click="toggle_mobile_sidebar"
          class="w-14 h-14 bg-gradient-to-r from-purple-600 to-blue-600 rounded-full shadow-lg flex items-center justify-center text-white hover:shadow-xl transition-all transform hover:scale-110"
          aria-label="Quick actions"
        >
          <%= if @show_mobile_sidebar do %>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          <% else %>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
          <% end %>
        </button>
      </div>

      <!-- Mobile Sidebar Panel -->
      <%= if @show_mobile_sidebar do %>
        <div class="fixed inset-0 z-50">
          <!-- Backdrop -->
          <div
            class="absolute inset-0 bg-black bg-opacity-50 backdrop-blur-sm transition-opacity"
            phx-click="toggle_mobile_sidebar"
          ></div>

          <!-- Sidebar Content -->
          <div class="absolute right-0 top-0 h-full w-80 max-w-[85vw] bg-white shadow-2xl transform transition-transform duration-300 overflow-y-auto">
            <!-- Sidebar Header -->
            <div class="p-6 border-b border-gray-200 bg-gradient-to-r from-purple-50 to-blue-50">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-lg font-bold text-gray-900">Quick Actions</h3>
                <button
                  phx-click="toggle_mobile_sidebar"
                  class="p-2 rounded-lg hover:bg-gray-100"
                >
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <!-- User Info -->
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-gradient-to-r from-purple-600 to-blue-600 rounded-full flex items-center justify-center text-white text-sm font-bold">
                  <%= String.first(@current_user.email) |> String.upcase() %>
                </div>
                <div>
                  <p class="font-medium text-gray-900">
                    <%= String.split(@current_user.email, "@") |> List.first() |> String.capitalize() %>
                  </p>
                  <p class="text-sm text-gray-600">
                    <%= String.capitalize(@current_user.subscription_tier || "free") %> Plan
                  </p>
                </div>
              </div>
            </div>

            <!-- Sidebar Content -->
            <div class="p-6 space-y-6">

              <!-- Quick Actions -->
              <div>
                <h4 class="text-sm font-semibold text-gray-900 mb-3 uppercase tracking-wide">Create & Manage</h4>
                <div class="space-y-3">
                  <button
                    phx-click="show_create_modal"
                    class="w-full flex items-center space-x-3 p-3 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg font-medium hover:from-purple-700 hover:to-blue-700 transition-all"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                    </svg>
                    <span>New Portfolio</span>
                  </button>

                  <.link
                    navigate="/studio"
                    phx-click="toggle_mobile_sidebar"
                    class="w-full flex items-center space-x-3 p-3 bg-gray-100 text-gray-700 rounded-lg font-medium hover:bg-gray-200 transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
                    </svg>
                    <span>Open Studio</span>
                  </.link>

                  <.link
                    navigate="/portfolios/dashboard"
                    phx-click="toggle_mobile_sidebar"
                    class="w-full flex items-center space-x-3 p-3 bg-gray-100 text-gray-700 rounded-lg font-medium hover:bg-gray-200 transition-colors"
                  >
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                    </svg>
                    <span>View Dashboard</span>
                  </.link>
                </div>
              </div>

              <!-- Collaboration Section -->
              <div>
                <h4 class="text-sm font-semibold text-gray-900 mb-3 uppercase tracking-wide">Collaborations</h4>

                <%= if length(@collaboration_requests) > 0 do %>
                  <div class="space-y-3">
                    <%= for request <- Enum.take(@collaboration_requests, 3) do %>
                      <div class="p-3 bg-purple-50 border border-purple-200 rounded-lg">
                        <div class="flex items-start justify-between">
                          <div class="flex-1">
                            <p class="text-sm font-medium text-purple-900"><%= request.user %></p>
                            <p class="text-xs text-purple-700">wants to <%= request.type %></p>
                            <p class="text-xs text-purple-600 mt-1 line-clamp-1">"<%= request.portfolio %>"</p>
                          </div>
                          <div class="flex space-x-1 ml-2">
                            <button
                              phx-click="accept_collaboration"
                              phx-value-request_id={request.id}
                              class="p-1 text-green-600 hover:bg-green-100 rounded transition-colors"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                              </svg>
                            </button>
                            <button
                              phx-click="decline_collaboration"
                              phx-value-request_id={request.id}
                              class="p-1 text-red-600 hover:bg-red-100 rounded transition-colors"
                            >
                              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                              </svg>
                            </button>
                          </div>
                        </div>
                      </div>
                    <% end %>

                    <%= if length(@collaboration_requests) > 3 do %>
                      <button
                        phx-click="view_all_collaborations"
                        class="w-full text-sm text-purple-600 hover:text-purple-700 font-medium py-2"
                      >
                        View <%= length(@collaboration_requests) - 3 %> more →
                      </button>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center py-6">
                    <div class="w-12 h-12 mx-auto mb-3 bg-purple-100 rounded-full flex items-center justify-center">
                      <svg class="w-6 h-6 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                      </svg>
                    </div>
                    <p class="text-sm text-gray-600 mb-3">No active collaborations</p>
                    <button
                      phx-click="invite_collaborators"
                      class="text-xs text-purple-600 hover:text-purple-700 font-medium"
                    >
                      Invite collaborators →
                    </button>
                  </div>
                <% end %>
              </div>

              <!-- Recent Activity -->
              <div>
                <h4 class="text-sm font-semibold text-gray-900 mb-3 uppercase tracking-wide">Recent Activity</h4>

                <div class="space-y-3">
                  <%= for activity <- Enum.take(@recent_activity, 4) do %>
                    <div class="flex items-start space-x-3 p-2 hover:bg-gray-50 rounded-lg transition-colors">
                      <div class={[
                        "w-8 h-8 rounded-full flex items-center justify-center text-xs font-bold text-white flex-shrink-0",
                        case activity.type do
                          :portfolio_view -> "bg-blue-500"
                          :comment_received -> "bg-green-500"
                          :collaboration_invite -> "bg-purple-500"
                          :feedback_received -> "bg-orange-500"
                          _ -> "bg-gray-500"
                        end
                      ]}>
                        <%= case activity.type do
                          :portfolio_view -> "👁"
                          :comment_received -> "💬"
                          :collaboration_invite -> "🤝"
                          :feedback_received -> "⭐"
                          _ -> "📝"
                        end %>
                      </div>

                      <div class="flex-1 min-w-0">
                        <p class="text-sm text-gray-900 line-clamp-1">
                          <%= case activity.type do
                            :portfolio_view -> "#{activity.count} new views"
                            :comment_received -> "#{activity.user} commented"
                            :collaboration_invite -> "#{activity.user} invited you"
                            :feedback_received -> "#{activity.rating}⭐ feedback"
                            _ -> "Activity"
                          end %>
                        </p>
                        <p class="text-xs text-gray-600 line-clamp-1">"<%= activity.portfolio %>"</p>
                        <p class="text-xs text-gray-500"><%= activity.time %></p>
                      </div>
                    </div>
                  <% end %>
                </div>

                <button
                  phx-click="view_all_activity"
                  class="w-full mt-4 text-sm text-blue-600 hover:text-blue-700 font-medium py-2"
                >
                  View all activity →
                </button>
              </div>

              <!-- Subscription Status -->
              <div class="bg-gradient-to-r from-purple-500 to-pink-600 rounded-xl p-4 text-white">
                <div class="flex items-center justify-between mb-3">
                  <h4 class="font-semibold">Frestyl Pro</h4>
                  <div class="text-xs bg-white/20 px-2 py-1 rounded-full">
                    <%= String.capitalize(@current_user.subscription_tier || "free") %>
                  </div>
                </div>

                <p class="text-sm text-purple-100 mb-4">
                  <%= if @current_user.subscription_tier == "free" do %>
                    Upgrade to unlock unlimited portfolios and advanced collaboration features.
                  <% else %>
                    You have access to all premium features including unlimited collaborations.
                  <% end %>
                </p>

                <%= if @current_user.subscription_tier == "free" do %>
                  <.link
                    navigate="/account/subscription"
                    phx-click="toggle_mobile_sidebar"
                    class="inline-flex items-center px-4 py-2 bg-white text-purple-600 rounded-lg hover:bg-purple-50 transition-colors text-sm font-medium"
                  >
                    Upgrade Now
                  </.link>
                <% else %>
                  <.link
                    navigate="/account/subscription"
                    phx-click="toggle_mobile_sidebar"
                    class="inline-flex items-center text-sm text-purple-100 hover:text-white"
                  >
                    Manage subscription →
                  </.link>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # MOBILE WELCOME HERO COMPONENT
  # ============================================================================

  def mobile_welcome_hero(assigns) do
    ~H"""
    <!-- Mobile Welcome Hero - Compact Version -->
    <div class="lg:hidden p-4 mb-6">
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-4 relative overflow-hidden">
        <!-- Background pattern -->
        <div class="absolute inset-0 bg-gradient-to-br from-purple-50 to-blue-50 opacity-50"></div>

        <div class="relative z-10">
          <div class="flex items-center space-x-3 mb-4">
            <div class="w-10 h-10 bg-gradient-to-r from-purple-600 to-blue-600 rounded-full flex items-center justify-center text-white text-sm font-bold">
              <%= String.first(@current_user.email) |> String.upcase() %>
            </div>
            <div class="flex-1">
              <h2 class="text-lg font-bold text-gray-900">
                Welcome back, <%= String.split(@current_user.email, "@") |> List.first() |> String.capitalize() %>
              </h2>
              <p class="text-sm text-gray-600">Your creative portfolio workspace</p>
            </div>
          </div>

          <!-- Mobile Activity Graph -->
          <div class="mb-4">
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-medium text-gray-700">Portfolio Activity</span>
              <span class="text-xs text-gray-500">Last 30 days</span>
            </div>
            <div class="grid grid-cols-15 gap-0.5">
              <%= for day <- 1..15 do %>
                <div class={[
                  "w-2 h-2 rounded-sm",
                  case rem(day, 4) do
                    0 -> "bg-green-200"
                    1 -> "bg-green-300"
                    2 -> "bg-green-400"
                    _ -> "bg-gray-100"
                  end
                ]} title={"Day #{day}"}></div>
              <% end %>
            </div>
          </div>

          <!-- Mobile Quick Stats -->
          <div class="grid grid-cols-3 gap-3">
            <div class="text-center p-2 bg-white bg-opacity-70 rounded-lg">
              <div class="text-lg font-bold text-blue-600"><%= length(@portfolios) %></div>
              <div class="text-xs text-gray-600">Portfolios</div>
            </div>
            <div class="text-center p-2 bg-white bg-opacity-70 rounded-lg">
              <div class="text-lg font-bold text-green-600"><%= @overview.total_views || 0 %></div>
              <div class="text-xs text-gray-600">Total Views</div>
            </div>
            <div class="text-center p-2 bg-white bg-opacity-70 rounded-lg">
              <div class="text-lg font-bold text-purple-600"><%= length(@collaboration_requests) %></div>
              <div class="text-xs text-gray-600">Collaborations</div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MOBILE TOUCH GESTURES COMPONENT
  # ============================================================================

  def mobile_touch_gestures(assigns) do
    ~H"""
    <!-- Mobile Touch Gestures Handler -->
    <div
      class="lg:hidden fixed inset-0 pointer-events-none z-0"
      phx-hook="MobilePortfolioGestures"
      id="mobile-gesture-area"
    >
      <!-- Swipe indicators - only show during gesture -->
      <div
        id="swipe-indicator"
        class="hidden fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 bg-black bg-opacity-75 text-white px-4 py-2 rounded-lg text-sm font-medium z-50"
      >
        <span id="swipe-text">Swipe detected</span>
      </div>
    </div>

    <!-- Mobile Pull-to-Refresh -->
    <div class="lg:hidden">
      <div
        id="pull-to-refresh"
        class="hidden text-center py-4 text-gray-500 text-sm"
      >
        <svg class="w-5 h-5 mx-auto mb-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
        </svg>
        Pull to refresh
      </div>
    </div>

    <script>
      // Mobile Portfolio Gestures Hook
      window.MobilePortfolioGestures = {
        mounted() {
          this.setupTouchGestures();
          this.setupPullToRefresh();
        },

        setupTouchGestures() {
          let startX, startY, currentX, currentY;
          let isGesturing = false;
          const threshold = 50; // Minimum swipe distance
          const restraint = 100; // Maximum perpendicular distance

          this.el.addEventListener('touchstart', (e) => {
            const touch = e.touches[0];
            startX = touch.clientX;
            startY = touch.clientY;
            isGesturing = true;
          }, { passive: true });

          this.el.addEventListener('touchmove', (e) => {
            if (!isGesturing) return;

            const touch = e.touches[0];
            currentX = touch.clientX;
            currentY = touch.clientY;

            // Show swipe indicator during gesture
            const deltaX = currentX - startX;
            const deltaY = currentY - startY;

            if (Math.abs(deltaX) > 30 || Math.abs(deltaY) > 30) {
              this.showSwipeIndicator(deltaX, deltaY);
            }
          }, { passive: true });

          this.el.addEventListener('touchend', (e) => {
            if (!isGesturing) return;

            const deltaX = currentX - startX;
            const deltaY = currentY - startY;

            this.hideSwipeIndicator();

            // Determine swipe direction
            if (Math.abs(deltaX) >= threshold && Math.abs(deltaY) <= restraint) {
              if (deltaX > 0) {
                this.handleSwipe('right');
              } else {
                this.handleSwipe('left');
              }
            } else if (Math.abs(deltaY) >= threshold && Math.abs(deltaX) <= restraint) {
              if (deltaY > 0) {
                this.handleSwipe('down');
              } else {
                this.handleSwipe('up');
              }
            }

            isGesturing = false;
          }, { passive: true });
        },

        setupPullToRefresh() {
          let startY = 0;
          let currentY = 0;
          let isPulling = false;
          const pullThreshold = 80;

          document.addEventListener('touchstart', (e) => {
            if (window.scrollY <= 0) {
              startY = e.touches[0].clientY;
              isPulling = true;
            }
          }, { passive: true });

          document.addEventListener('touchmove', (e) => {
            if (!isPulling || window.scrollY > 0) return;

            currentY = e.touches[0].clientY;
            const pullDistance = currentY - startY;

            if (pullDistance > 20) {
              const pullIndicator = document.getElementById('pull-to-refresh');
              if (pullIndicator) {
                pullIndicator.classList.remove('hidden');

                if (pullDistance > pullThreshold) {
                  pullIndicator.style.transform = `translateY(${Math.min(pullDistance - 20, 60)}px)`;
                  pullIndicator.innerHTML = '<svg class="w-5 h-5 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/></svg>Release to refresh';
                }
              }
            }
          }, { passive: true });

          document.addEventListener('touchend', (e) => {
            if (!isPulling) return;

            const pullDistance = currentY - startY;
            const pullIndicator = document.getElementById('pull-to-refresh');

            if (pullDistance > pullThreshold) {
              // Trigger refresh
              this.pushEvent('refresh_portfolios', {});
            }

            if (pullIndicator) {
              pullIndicator.classList.add('hidden');
              pullIndicator.style.transform = '';
            }

            isPulling = false;
          }, { passive: true });
        },

        showSwipeIndicator(deltaX, deltaY) {
          const indicator = document.getElementById('swipe-indicator');
          const text = document.getElementById('swipe-text');

          if (indicator && text) {
            let direction = '';
            if (Math.abs(deltaX) > Math.abs(deltaY)) {
              direction = deltaX > 0 ? 'Swipe right to navigate' : 'Swipe left to filter';
            } else {
              direction = deltaY > 0 ? 'Swipe down to refresh' : 'Swipe up for actions';
            }

            text.textContent = direction;
            indicator.classList.remove('hidden');
          }
        },

        hideSwipeIndicator() {
          const indicator = document.getElementById('swipe-indicator');
          if (indicator) {
            indicator.classList.add('hidden');
          }
        },

        handleSwipe(direction) {
          switch (direction) {
            case 'right':
              // Navigate to previous portfolio or open sidebar
              this.pushEvent('mobile_swipe_right', {});
              break;
            case 'left':
              // Navigate to next portfolio or close sidebar
              this.pushEvent('mobile_swipe_left', {});
              break;
            case 'up':
              // Open mobile actions
              this.pushEvent('mobile_swipe_up', {});
              break;
            case 'down':
              // Refresh or close modal
              this.pushEvent('mobile_swipe_down', {});
              break;
          }
        }
      };
    </script>
    """
  end

  # ============================================================================
  # MOBILE CREATE PORTFOLIO MODAL
  # ============================================================================

  def mobile_create_modal(assigns) do
    ~H"""
    <!-- Mobile-Optimized Create Portfolio Modal -->
    <%= if @show_create_modal do %>
      <div class="lg:hidden fixed inset-0 z-50 overflow-y-auto">
        <!-- Mobile Modal Backdrop -->
        <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm transition-opacity"
             phx-click="hide_create_modal"></div>

        <!-- Mobile Modal Content - Full Screen on Small Devices -->
        <div class="flex min-h-full items-end sm:items-center justify-center p-0 sm:p-4">
          <div class="relative bg-white w-full h-full sm:h-auto sm:max-h-[90vh] sm:rounded-2xl shadow-2xl sm:max-w-lg overflow-hidden">

            <!-- Mobile Modal Header -->
            <div class="bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-4 sm:rounded-t-2xl">
              <div class="flex items-center justify-between">
                <div>
                  <h2 class="text-xl font-bold text-white">Create Portfolio</h2>
                  <p class="text-purple-100 text-sm mt-1">Choose a template to get started</p>
                </div>
                <button
                  phx-click="hide_create_modal"
                  class="text-white hover:text-gray-200 transition-colors p-2 rounded-lg hover:bg-white/10"
                >
                  <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            </div>

            <!-- Mobile Modal Body -->
            <div class="p-6 overflow-y-auto max-h-[calc(100vh-200px)] sm:max-h-[60vh]">

              <!-- Portfolio Title Input -->
              <div class="mb-6">
                <label class="block text-sm font-semibold text-gray-900 mb-2">Portfolio Title</label>
                <input
                  type="text"
                  id="mobile-portfolio-title"
                  placeholder="e.g. My Creative Portfolio"
                  class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent text-base"
                  phx-debounce="300"
                  phx-change="update_portfolio_title"
                />
              </div>

              <!-- Quick Template Selection -->
              <div class="mb-6">
                <label class="block text-sm font-semibold text-gray-900 mb-3">Choose Template</label>
                <div class="space-y-3">

                  <!-- Creative Template -->
                  <button
                    phx-click="select_template"
                    phx-value-template="creative"
                    class={[
                      "w-full p-4 border-2 rounded-xl transition-all text-left",
                      if(@selected_template == "creative", do: "border-purple-500 bg-purple-50", else: "border-gray-200 hover:border-purple-300")
                    ]}
                  >
                    <div class="flex items-center space-x-3">
                      <div class="w-12 h-12 bg-gradient-to-br from-purple-500 to-pink-600 rounded-lg flex items-center justify-center">
                        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17v4a2 2 0 002 2h4M13 13h4a2 2 0 012 2v4a2 2 0 01-2 2h-4m-6-4a2 2 0 01-2-2V7a2 2 0 012-2h2m0 0V3a2 2 0 012-2h4a2 2 0 012 2v2m-6 4h2.343"/>
                        </svg>
                      </div>
                      <div class="flex-1">
                        <h3 class="font-bold text-gray-900">Creative Portfolio</h3>
                        <p class="text-sm text-gray-600">Perfect for artists, designers, and creative professionals</p>
                        <div class="flex items-center mt-1">
                          <span class="text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded-full">Most Popular</span>
                        </div>
                      </div>
                    </div>
                  </button>

                  <!-- Executive Template -->
                  <button
                    phx-click="select_template"
                    phx-value-template="executive"
                    class={[
                      "w-full p-4 border-2 rounded-xl transition-all text-left",
                      if(@selected_template == "executive", do: "border-blue-500 bg-blue-50", else: "border-gray-200 hover:border-blue-300")
                    ]}
                  >
                    <div class="flex items-center space-x-3">
                      <div class="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center">
                        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                        </svg>
                      </div>
                      <div class="flex-1">
                        <h3 class="font-bold text-gray-900">Executive Portfolio</h3>
                        <p class="text-sm text-gray-600">Professional layout for business leaders and executives</p>
                        <div class="flex items-center mt-1">
                          <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Professional</span>
                        </div>
                      </div>
                    </div>
                  </button>

                  <!-- Developer Template -->
                  <button
                    phx-click="select_template"
                    phx-value-template="developer"
                    class={[
                      "w-full p-4 border-2 rounded-xl transition-all text-left",
                      if(@selected_template == "developer", do: "border-green-500 bg-green-50", else: "border-gray-200 hover:border-green-300")
                    ]}
                  >
                    <div class="flex items-center space-x-3">
                      <div class="w-12 h-12 bg-gradient-to-br from-green-500 to-teal-600 rounded-lg flex items-center justify-center">
                        <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
                        </svg>
                      </div>
                      <div class="flex-1">
                        <h3 class="font-bold text-gray-900">Developer Portfolio</h3>
                        <p class="text-sm text-gray-600">Tech-focused design for developers and engineers</p>
                        <div class="flex items-center mt-1">
                          <span class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full">Tech</span>
                        </div>
                      </div>
                    </div>
                  </button>
                </div>
              </div>

              <!-- Template Preview -->
              <%= if @selected_template do %>
                <div class="mb-6">
                  <h4 class="text-sm font-semibold text-gray-900 mb-2">Template Preview</h4>
                  <div class="bg-gray-100 rounded-lg p-4 aspect-[4/3]">
                    <div class={[
                      "w-full h-full rounded-lg flex items-center justify-center text-white text-sm font-medium",
                      case @selected_template do
                        "creative" -> "bg-gradient-to-br from-purple-500 to-pink-600"
                        "executive" -> "bg-gradient-to-br from-blue-500 to-indigo-600"
                        "developer" -> "bg-gradient-to-br from-green-500 to-teal-600"
                        _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
                      end
                    ]}>
                      <%= String.capitalize(@selected_template) %> Template Preview
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Mobile Modal Footer -->
            <div class="bg-gray-50 px-6 py-4 sm:rounded-b-2xl">
              <div class="flex flex-col sm:flex-row items-center space-y-3 sm:space-y-0 sm:space-x-3">
                <button
                  phx-click="hide_create_modal"
                  class="w-full sm:w-auto px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium"
                >
                  Cancel
                </button>
                <button
                  phx-click="create_portfolio_with_template"
                  disabled={!@selected_template}
                  class={[
                    "w-full sm:w-auto px-6 py-3 rounded-lg font-medium transition-colors",
                    if(@selected_template,
                      do: "bg-gradient-to-r from-purple-600 to-blue-600 text-white hover:from-purple-700 hover:to-blue-700",
                      else: "bg-gray-300 text-gray-500 cursor-not-allowed"
                    )
                  ]}
                >
                  Create Portfolio
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_filtered_portfolios(portfolios, "all"), do: portfolios
  defp get_filtered_portfolios(portfolios, "published") do
    Enum.filter(portfolios, & &1.published)
  end
  defp get_filtered_portfolios(portfolios, "collaborative") do
    Enum.filter(portfolios, fn portfolio ->
      # Check if portfolio has active collaborations
      case Map.get(portfolio, :collaborations, []) do
        [] -> false
        collaborations -> length(collaborations) > 0
      end
    end)
  end
  defp get_filtered_portfolios(portfolios, _), do: portfolios

  defp relative_date(date_string) when is_binary(date_string) do
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _} -> relative_date(datetime)
      _ -> "recently"
    end
  end

  defp relative_date(%DateTime{} = datetime) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, datetime, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      diff_seconds < 2629746 -> "#{div(diff_seconds, 604800)}w ago"
      true -> "#{div(diff_seconds, 2629746)}mo ago"
    end
  end

  defp relative_date(_), do: "recently"

end
