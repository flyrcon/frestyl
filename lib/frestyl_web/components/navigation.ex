# lib/frestyl_web/components/navigation.ex
defmodule FrestylWeb.Navigation do
  use Phoenix.Component
  use FrestylWeb, :verified_routes
  alias Phoenix.LiveView.JS

  # Add this to your CoreComponents or create a separate NavigationComponents module

  @doc """
  Renders the main navigation bar with user menu.

  ## Examples

      <.nav current_user={@current_user} active_tab={:channels} />
      <.nav current_user={@current_user} active_tab={:dashboard} />
  """
  attr :current_user, :map, required: true
  attr :active_tab, :atom, default: :dashboard

  def nav(assigns) do
    ~H"""
    <!-- Navigation -->
    <nav class="fixed top-0 left-0 right-0 z-50 bg-white bg-opacity-95 backdrop-blur border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex items-center justify-between h-16">
          <!-- Logo -->
          <div class="flex items-center">
            <.link navigate={~p"/dashboard"}>
              <img src={~p"/images/logo.svg"} alt="Frestyl" class="w-24 h-24" />
            </.link>
          </div>

          <!-- Navigation Links -->
          <div class="hidden md:flex items-center space-x-8">
            <.link navigate={~p"/dashboard"} class={"font-semibold relative pb-1 group #{if @active_tab == :dashboard, do: "font-bold text-gray-900", else: "text-gray-600 hover:text-gray-900"}"}>
              Dashboard
              <%= if @active_tab == :dashboard do %>
                <span class="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-pink-500 to-purple-500"></span>
              <% else %>
                <span class="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-pink-500 to-purple-500 group-hover:w-full transition-all duration-300"></span>
              <% end %>
            </.link>

            <.link navigate={~p"/channels"} class={"font-semibold relative pb-1 group #{if @active_tab == :channels, do: "font-bold text-gray-900", else: "text-gray-600 hover:text-gray-900"}"}>
              Channels
              <%= if @active_tab == :channels do %>
                <span class="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-pink-500 to-purple-500"></span>
              <% else %>
                <span class="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-pink-500 to-purple-500 group-hover:w-full transition-all duration-300"></span>
              <% end %>
            </.link>

            <.link navigate={~p"/chat"} class={"font-semibold relative pb-1 group #{if @active_tab == :chat, do: "font-bold text-gray-900", else: "text-gray-600 hover:text-gray-900"}"}>
              Chat
              <%= if @active_tab == :chat do %>
                <span class="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-pink-500 to-purple-500"></span>
              <% else %>
                <span class="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-pink-500 to-purple-500 group-hover:w-full transition-all duration-300"></span>
              <% end %>
            </.link>

            <.link navigate={~p"/media"} class={"font-semibold relative pb-1 group #{if @active_tab == :media, do: "font-bold text-gray-900", else: "text-gray-600 hover:text-gray-900"}"}>
              Media
              <%= if @active_tab == :media do %>
                <span class="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-pink-500 to-purple-500"></span>
              <% else %>
                <span class="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-pink-500 to-purple-500 group-hover:w-full transition-all duration-300"></span>
              <% end %>
            </.link>

            <.link navigate={~p"/events"} class={"font-semibold relative pb-1 group #{if @active_tab == :events, do: "font-bold text-gray-900", else: "text-gray-600 hover:text-gray-900"}"}>
              Events
              <%= if @active_tab == :events do %>
                <span class="absolute bottom-0 left-0 w-full h-0.5 bg-gradient-to-r from-pink-500 to-purple-500"></span>
              <% else %>
                <span class="absolute bottom-0 left-0 w-0 h-0.5 bg-gradient-to-r from-pink-500 to-purple-500 group-hover:w-full transition-all duration-300"></span>
              <% end %>
            </.link>

            <.link navigate="/streaming"
                  class="flex items-center px-4 py-2 text-gray-700 hover:bg-gray-100 rounded-lg">
              <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                      d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
              Live Streaming
            </.link>
          </div>

          <!-- Search & Actions -->
          <div class="flex items-center space-x-4">
            <!-- Search -->
            <div class="relative hidden sm:block">
              <div id="search-container" class="flex items-center">
                <button id="search-toggle" class="p-2 text-gray-600 hover:text-blue-500">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
                  </svg>
                </button>
                <input
                  id="search-input"
                  type="search"
                  placeholder="Search channels, media, people..."
                  class="hidden w-48 lg:w-64 h-10 ml-2 pl-4 pr-4 bg-gray-50 border border-gray-200 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500 focus:bg-white"
                />
              </div>
            </div>

            <!-- Notifications -->
            <button class="relative p-2 text-gray-600 hover:text-blue-500">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"></path>
              </svg>
              <span class="absolute top-1 right-1 w-2 h-2 bg-pink-500 rounded-full"></span>
            </button>

            <!-- Profile -->
            <div class="relative" phx-click-away={JS.hide(to: "#user-menu")}>
              <button
                phx-click={JS.toggle(to: "#user-menu")}
                class="w-8 h-8 bg-gradient-to-r from-orange-500 to-pink-500 rounded-xl flex items-center justify-center text-white font-bold text-sm"
              >
                <%= String.first(@current_user.full_name || @current_user.email || "U") %>
              </button>
              <div id="user-menu" class="hidden absolute right-0 mt-2 w-48 bg-white rounded-xl shadow-lg z-50 border border-gray-100">
                <div class="py-2">
                  <!-- User Info Header -->
                  <div class="px-4 py-3 border-b border-gray-100">
                    <p class="text-sm font-bold text-gray-900 truncate">
                      <%= @current_user.full_name || "User" %>
                    </p>
                    <p class="text-xs text-gray-500 truncate">
                      <%= @current_user.email %>
                    </p>
                  </div>

                  <!-- Menu Items -->
                  <.link navigate={~p"/profile"} class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 font-semibold">
                    Account
                  </.link>
                  <.link navigate={~p"/portfolios"} class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 font-semibold">
                    Portfolio
                  </.link>
                  <.link navigate={~p"/settings"} class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 font-semibold">
                    Settings
                  </.link>
                  <div class="border-t border-gray-100"></div>
                  <.link href={~p"/logout"} method="delete" class="block px-4 py-2 text-sm text-red-600 hover:bg-red-50 font-semibold">
                    Logout
                  </.link>
                </div>
              </div>
            </div>

            <!-- Mobile menu button -->
            <button
              phx-click={JS.toggle(to: "#mobile-sidebar") |> JS.toggle(to: "#mobile-overlay")}
              class="md:hidden p-2 text-gray-600 hover:text-blue-500"
            >
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </nav>

    <!-- Mobile Sidebar -->
    <div id="mobile-sidebar" class="fixed top-16 left-0 bottom-0 w-80 bg-white z-40 lg:hidden shadow-lg transform -translate-x-full transition-transform duration-300">
      <div class="p-6 space-y-6">
        <!-- Mobile search -->
        <div class="relative">
          <input
            type="search"
            placeholder="Search channels..."
            class="w-full h-10 pl-10 pr-4 bg-gray-50 border-0 rounded-xl focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <svg class="absolute left-3 top-3 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"></path>
          </svg>
        </div>

        <!-- Mobile Navigation Links -->
        <div class="space-y-3">
          <h3 class="font-bold text-gray-900 text-sm uppercase tracking-wide">Navigation</h3>

          <.link navigate={~p"/dashboard"} class="w-full flex items-center space-x-3 p-3 bg-gray-50 hover:bg-gray-100 rounded-xl">
            <div class="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-500 rounded-lg flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
              </svg>
            </div>
            <span class="font-semibold text-gray-900 text-sm">Dashboard</span>
          </.link>

          <.link navigate={~p"/channels"} class="w-full flex items-center space-x-3 p-3 bg-gray-50 hover:bg-gray-100 rounded-xl">
            <div class="w-8 h-8 bg-gradient-to-r from-purple-500 to-pink-500 rounded-lg flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            <span class="font-semibold text-gray-900 text-sm">Channels</span>
          </.link>
        </div>

        <!-- Quick Actions -->
        <div class="space-y-3">
          <h3 class="font-bold text-gray-900 text-sm uppercase tracking-wide">Quick Actions</h3>
          <.link navigate={~p"/channels/new"} class="w-full flex items-center space-x-3 p-3 bg-gray-50 hover:bg-gray-100 rounded-xl">
            <div class="w-8 h-8 bg-gradient-to-r from-blue-500 to-pink-500 rounded-lg flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"></path>
              </svg>
            </div>
            <span class="font-semibold text-gray-900 text-sm">New Channel</span>
          </.link>
        </div>
      </div>
    </div>

    <!-- Overlay -->
    <div
      id="mobile-overlay"
      class="hidden fixed inset-0 bg-black bg-opacity-50 z-30 lg:hidden"
      phx-click={JS.hide(to: "#mobile-sidebar") |> JS.hide(to: "#mobile-overlay")}
    ></div>
    """
  end
end
