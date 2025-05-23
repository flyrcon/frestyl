# lib/frestyl_web/components/navigation.ex
defmodule FrestylWeb.Navigation do
  use Phoenix.Component
  use FrestylWeb, :verified_routes
  alias Phoenix.LiveView.JS

  attr :active_tab, :atom, required: true
  attr :current_user, :map, required: true

  def nav(assigns) do
    ~H"""
    <nav class="bg-white/95 backdrop-blur-xl border-b border-gray-100 sticky top-0 z-50 shadow-sm">
      <div class="px-4 sm:px-6 lg:px-8 xl:px-16">
        <div class="flex justify-between h-20">
          <!-- Left side with logo and main nav -->
          <div class="flex items-center space-x-8">
            <!-- Logo -->
            <div class="flex-shrink-0">
              <.link navigate={~p"/dashboard"} class="flex items-center group">
                <div class="relative">
                  <img src={~p"/images/logo.svg"} alt="Frestyl Logo" class="h-12 w-24 rounded-2xl shadow-lg" />
                </div>
              </.link>
            </div>

            <!-- Desktop Navigation -->
            <div class="hidden lg:flex lg:space-x-2">
              <.nav_item navigate={~p"/dashboard"} active={@active_tab == :dashboard} icon="home">
                Dashboard
              </.nav_item>

              <.nav_item navigate={~p"/channels"} active={@active_tab == :channels} icon="channels">
                Channels
              </.nav_item>

              <.nav_item navigate={~p"/chat"} active={@active_tab == :chat} icon="chat">
                Chat
              </.nav_item>

              <.nav_item navigate={~p"/media"} active={@active_tab == :media} icon="media">
                Media
              </.nav_item>

              <.nav_item navigate={~p"/events"} active={@active_tab == :events} icon="events">
                Events
              </.nav_item>
            </div>
          </div>

          <!-- Center Search (hidden on mobile) -->
          <div class="hidden md:flex flex-1 justify-center px-6 lg:px-8">
            <div class="w-full max-w-lg">
              <.form :let={f} for={%{}} action={~p"/search"} method="get" as="search" class="relative">
                <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                  <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                  </svg>
                </div>
                <input
                  type="text"
                  name="q"
                  placeholder="Search channels, media, people..."
                  class="block w-full pl-12 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl text-gray-900 placeholder-gray-500 focus:border-[#C2185B] focus:ring-2 focus:ring-[#C2185B]/20 focus:bg-white transition-all duration-200"
                />
              </.form>
            </div>
          </div>

          <!-- Right side with actions and profile -->
          <div class="flex items-center space-x-4">
            <!-- Quick Upload Button (desktop) -->
            <div class="hidden lg:block">
              <.link
                navigate={~p"/media/upload"}
                class="group relative overflow-hidden bg-gradient-to-r from-[#FF6B47] to-[#0891B2] hover:from-[#E55A3A] hover:to-[#0782A3] px-6 py-3 rounded-2xl text-white font-bold text-sm transition-all duration-300 transform hover:scale-105 shadow-lg shadow-[#FF6B47]/25"
              >
                <div class="absolute inset-0 bg-white/20 transform scale-x-0 group-hover:scale-x-100 transition-transform origin-left duration-300"></div>
                <div class="relative flex items-center">
                  <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                  </svg>
                  Upload
                </div>
              </.link>
            </div>

            <!-- Notifications -->
            <div class="relative">
              <button
                id="notification-button"
                type="button"
                class="relative p-3 rounded-2xl text-gray-600 hover:text-[#C2185B] hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-[#C2185B]/20 transition-all duration-200"
                phx-click={JS.toggle(to: "#notification-menu", in: "transition ease-out duration-200 transform", out: "transition ease-in duration-150 transform")}
              >
                <span class="sr-only">View notifications</span>
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <!-- Notification indicator -->
                <span class="absolute top-2 right-2 block h-2 w-2 rounded-full bg-[#C2185B]"></span>
              </button>

              <!-- Notification dropdown -->
              <div
                id="notification-menu"
                style="display: none;"
                class="origin-top-right absolute right-0 mt-2 w-80 bg-white/95 backdrop-blur-xl rounded-2xl border border-gray-100 shadow-2xl z-50"
                role="menu"
              >
                <div class="p-4 border-b border-gray-100">
                  <h3 class="text-lg font-bold text-gray-900">Notifications</h3>
                </div>
                <div class="max-h-80 overflow-y-auto">
                  <div class="p-6 text-center">
                    <div class="w-16 h-16 mx-auto mb-4 bg-gradient-to-br from-[#C2185B]/10 to-[#6A1B9A]/10 rounded-2xl flex items-center justify-center">
                      <svg class="h-8 w-8 text-[#C2185B]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                      </svg>
                    </div>
                    <p class="text-gray-500 text-sm">No new notifications</p>
                  </div>
                </div>
                <div class="border-t border-gray-100 p-3 text-center">
                  <button class="text-[#C2185B] hover:text-[#6A1B9A] text-sm font-bold transition-colors">
                    Mark all as read
                  </button>
                </div>
              </div>
            </div>

            <!-- Profile dropdown -->
            <div class="relative">
              <button
                id="user-menu-button"
                type="button"
                class="flex items-center space-x-3 p-2 rounded-2xl text-gray-900 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-[#C2185B]/20 transition-all duration-200"
                phx-click={JS.toggle(to: "#user-menu", in: "transition ease-out duration-200 transform", out: "transition ease-in duration-150 transform")}
              >
                <div class="w-10 h-10 rounded-2xl bg-gradient-to-br from-[#C2185B] to-[#6A1B9A] flex items-center justify-center text-white font-bold text-sm shadow-lg">
                  <%= if @current_user, do: String.at(@current_user.email || "", 0) |> String.upcase(), else: "?" %>
                </div>
                <div class="hidden md:block text-left">
                  <p class="text-sm font-bold text-gray-900">
                    <%= if @current_user, do: @current_user.name || @current_user.email, else: "Guest" %>
                  </p>
                  <p class="text-xs text-gray-500">Creative Member</p>
                </div>
                <svg class="h-4 w-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
                </svg>
              </button>

              <!-- Profile dropdown menu -->
              <div
                id="user-menu"
                style="display: none;"
                class="origin-top-right absolute right-0 mt-2 w-64 bg-white/95 backdrop-blur-xl rounded-2xl border border-gray-100 shadow-2xl z-50"
                role="menu"
              >
                <div class="p-4 border-b border-gray-100">
                  <div class="flex items-center space-x-3">
                    <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-[#C2185B] to-[#6A1B9A] flex items-center justify-center text-white font-bold shadow-lg">
                      <%= if @current_user, do: String.at(@current_user.email || "", 0) |> String.upcase(), else: "?" %>
                    </div>
                    <div>
                      <p class="text-sm font-bold text-gray-900">
                        <%= if @current_user, do: @current_user.name || @current_user.email, else: "Guest" %>
                      </p>
                      <p class="text-xs text-gray-500">
                        <%= if @current_user, do: @current_user.email, else: "" %>
                      </p>
                    </div>
                  </div>
                </div>

                <div class="py-2">
                  <.dropdown_item navigate={~p"/profile"} icon="profile">
                    Profile
                  </.dropdown_item>

                  <.dropdown_item navigate={~p"/portfolios"} icon="portfolio">
                    Live Portfolio
                  </.dropdown_item>

                  <.dropdown_item navigate={~p"/settings"} icon="settings">
                    Settings
                  </.dropdown_item>

                  <div class="border-t border-gray-100 my-2"></div>

                  <.dropdown_item href={~p"/logout"} method="delete" icon="logout" class="text-red-500 hover:text-red-600 hover:bg-red-50">
                    Sign out
                  </.dropdown_item>
                </div>
              </div>
            </div>

            <!-- Mobile menu button -->
            <div class="lg:hidden">
              <button
                type="button"
                class="p-3 rounded-2xl text-gray-600 hover:text-[#C2185B] hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-[#C2185B]/20 transition-all duration-200"
                phx-click={JS.toggle(to: "#mobile-menu", in: "transition ease-out duration-200", out: "transition ease-in duration-150")}
              >
                <span class="sr-only">Open main menu</span>
                <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Mobile menu -->
      <div id="mobile-menu" style="display: none;" class="lg:hidden border-t border-gray-100">
        <div class="px-4 py-6 space-y-2 bg-white/95 backdrop-blur-xl">
          <!-- Mobile search -->
          <div class="mb-6">
            <.form :let={f} for={%{}} action={~p"/search"} method="get" as="search" class="relative">
              <div class="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                <svg class="h-5 w-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                </svg>
              </div>
              <input
                type="text"
                name="q"
                placeholder="Search..."
                class="block w-full pl-12 pr-4 py-3 bg-gray-50 border border-gray-200 rounded-2xl text-gray-900 placeholder-gray-500 focus:border-[#C2185B] focus:ring-2 focus:ring-[#C2185B]/20"
              />
            </.form>
          </div>

          <!-- Mobile nav items -->
          <.mobile_nav_item navigate={~p"/dashboard"} active={@active_tab == :dashboard} icon="home">
            Dashboard
          </.mobile_nav_item>

          <.mobile_nav_item navigate={~p"/channels"} active={@active_tab == :channels} icon="channels">
            Channels
          </.mobile_nav_item>

          <.mobile_nav_item navigate={~p"/chat"} active={@active_tab == :chat} icon="chat">
            Chat
          </.mobile_nav_item>

          <.mobile_nav_item navigate={~p"/media"} active={@active_tab == :media} icon="media">
            Media
          </.mobile_nav_item>

          <.mobile_nav_item navigate={~p"/events"} active={@active_tab == :events} icon="events">
            Events
          </.mobile_nav_item>
        </div>
      </div>
    </nav>
    """
  end

  # Navigation item component for desktop
  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  slot :inner_block, required: true

  def nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "group relative px-4 py-3 rounded-2xl text-sm font-bold transition-all duration-300 flex items-center space-x-3 transform hover:scale-105",
        if(@active,
          do: "text-white bg-gradient-to-r from-[#C2185B] to-[#6A1B9A] shadow-lg shadow-[#C2185B]/25",
          else: "text-gray-600 hover:text-[#C2185B] hover:bg-gray-50"
        )
      ]}
    >
      <div class={[
        "p-1.5 rounded-xl transition-colors",
        if(@active,
          do: "bg-white/20",
          else: "bg-gray-100 group-hover:bg-[#C2185B]/10"
        )
      ]}>
        <.nav_icon name={@icon} class={[
          "h-4 w-4 transition-colors",
          if(@active, do: "text-white", else: "text-gray-500 group-hover:text-[#C2185B]")
        ]} />
      </div>
      <span>{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  # Mobile navigation item
  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  attr :icon, :string, required: true
  slot :inner_block, required: true

  def mobile_nav_item(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "flex items-center space-x-4 px-4 py-4 rounded-2xl text-base font-bold transition-all duration-200",
        if(@active,
          do: "text-white bg-gradient-to-r from-[#C2185B] to-[#6A1B9A] shadow-lg",
          else: "text-gray-600 hover:text-[#C2185B] hover:bg-gray-50"
        )
      ]}
    >
      <div class={[
        "p-2 rounded-xl transition-colors",
        if(@active,
          do: "bg-white/20",
          else: "bg-gray-100"
        )
      ]}>
        <.nav_icon name={@icon} class={[
          "h-5 w-5",
          if(@active, do: "text-white", else: "text-gray-500")
        ]} />
      </div>
      <span>{render_slot(@inner_block)}</span>
    </.link>
    """
  end

  # Dropdown item component
  attr :navigate, :string, default: nil
  attr :href, :string, default: nil
  attr :method, :string, default: "get"
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def dropdown_item(assigns) do
    ~H"""
    <%= if @navigate do %>
      <.link
        navigate={@navigate}
        class={[
          "flex items-center space-x-3 px-4 py-3 text-sm font-medium text-gray-700 hover:text-[#C2185B] hover:bg-gray-50 transition-all duration-200 rounded-xl mx-2",
          @class
        ]}
        role="menuitem"
      >
        <.nav_icon name={@icon} class="h-4 w-4" />
        <span>{render_slot(@inner_block)}</span>
      </.link>
    <% else %>
      <.link
        href={@href}
        method={@method}
        class={[
          "flex items-center space-x-3 px-4 py-3 text-sm font-medium text-gray-700 hover:text-[#C2185B] hover:bg-gray-50 transition-all duration-200 rounded-xl mx-2",
          @class
        ]}
        role="menuitem"
      >
        <.nav_icon name={@icon} class="h-4 w-4" />
        <span>{render_slot(@inner_block)}</span>
      </.link>
    <% end %>
    """
  end

  # Icon component for navigation (keeping all your existing icon functions)
  attr :name, :string, required: true
  attr :class, :string, default: ""

  def nav_icon(%{name: "home"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
    </svg>
    """
  end

  def nav_icon(%{name: "channels"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    </svg>
    """
  end

  def nav_icon(%{name: "chat"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
    </svg>
    """
  end

  def nav_icon(%{name: "media"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
    </svg>
    """
  end

  def nav_icon(%{name: "events"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
    </svg>
    """
  end

  def nav_icon(%{name: "profile"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
    </svg>
    """
  end

  def nav_icon(%{name: "portfolio"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10" />
    </svg>
    """
  end

  def nav_icon(%{name: "settings"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z" />
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
    </svg>
    """
  end

  def nav_icon(%{name: "logout"} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
    </svg>
    """
  end

  def nav_icon(assigns), do: ~H""
end
