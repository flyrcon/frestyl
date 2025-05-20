# lib/frestyl_web/components/navigation.ex
defmodule FrestylWeb.Navigation do
  use Phoenix.Component
  use FrestylWeb, :verified_routes
  alias Phoenix.LiveView.JS

  attr :active_tab, :atom, required: true
  attr :current_user, :map, required: true

  def nav(assigns) do
    ~H"""
    <nav class="bg-white shadow-sm sticky top-0 z-30">
      <div class="container mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-14">
          <div class="flex items-center">
            <!-- Frestyl brand commented out as requested -->
            <!-- <div class="flex-shrink-0 flex items-center">
              <.link navigate={~p"/"} class="flex items-center">
                <span class="bg-clip-text text-transparent bg-gradient-to-r from-purple-700 to-indigo-600 text-xl font-extrabold tracking-tight">Frestyl</span>
              </.link>
            </div> -->
            <div class="flex sm:space-x-6">
              <!-- Primary Navigation Menu -->
              <.link
                navigate={~p"/dashboard"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :dashboard,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
                </svg>
                Dashboard
              </.link>

              <.link
                navigate={~p"/channels"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :channels,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                Channels
              </.link>

              <.link
                navigate={~p"/chat"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :chat,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                </svg>
                Chat
              </.link>

              <.link
                navigate={~p"/media"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :media,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
                </svg>
                Media
              </.link>

              <.link
                navigate={~p"/events"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :events,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
                </svg>
                Events
              </.link>

              <!-- Analytics navigation item commented out as requested -->
              <!--
              <.link
                navigate={~p"/analytics"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium transition-colors duration-150",
                  if(@active_tab == :analytics,
                    do: "border-purple-700 text-gray-900 font-semibold",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-1.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z" />
                </svg>
                Analytics
              </.link>
              -->
            </div>
          </div>

          <div class="hidden sm:ml-6 sm:flex sm:items-center">
            <!-- Notification bell -->
            <div class="relative ml-3">
              <button
                id="notification-button"
                type="button"
                class="relative p-1 rounded-full text-gray-500 hover:text-gray-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
                phx-click={JS.toggle(to: "#notification-menu", in: "transition ease-out duration-100", out: "transition ease-in duration-75", display: "block")}
              >
                <span class="sr-only">View notifications</span>
                <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                </svg>
                <!-- Notification badge (conditionally rendered based on unread notifications) -->
                <span class="absolute top-0 right-0 block h-2 w-2 rounded-full bg-red-500 ring-2 ring-white"></span>
              </button>

              <div
                id="notification-menu"
                style="display: none;"
                class="origin-top-right absolute right-0 mt-2 w-80 rounded-md shadow-lg py-1 bg-white ring-1 ring-black ring-opacity-5 focus:outline-none z-50"
                role="menu"
                aria-orientation="vertical"
                aria-labelledby="notification-button"
              >
                <div class="px-4 py-2 border-b border-gray-100">
                  <h3 class="text-sm font-semibold text-gray-900">Notifications</h3>
                </div>
                <div class="max-h-60 overflow-y-auto">
                  <div class="p-2 text-center text-sm text-gray-500">
                    No new notifications
                  </div>
                  <!-- Notifications would be rendered here -->
                </div>
                <div class="border-t border-gray-100 px-4 py-2 text-center">
                  <button class="text-xs font-medium text-purple-600 hover:text-purple-800">
                    Mark all as read
                  </button>
                </div>
              </div>
            </div>

            <!-- Profile dropdown -->
            <div class="ml-3 relative">
              <div>
                <button
                  id="user-menu-button"
                  type="button"
                  class="bg-white flex text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
                  aria-expanded="false"
                  aria-haspopup="true"
                  phx-click={JS.toggle(to: "#user-menu", in: "transition ease-out duration-100", out: "transition ease-in duration-75", display: "block")}
                >
                  <span class="sr-only">Open user menu</span>
                  <div class="h-8 w-8 rounded-full bg-gradient-to-r from-purple-700 to-indigo-600 flex items-center justify-center text-white font-bold">
                    <%= if @current_user, do: String.at(@current_user.email || "", 0) |> String.upcase(), else: "?" %>
                  </div>
                </button>
              </div>

              <div
                id="user-menu"
                style="display: none;"
                class="origin-top-right absolute right-0 mt-2 w-48 rounded-md shadow-lg py-1 bg-white ring-1 ring-black ring-opacity-5 z-50"
                role="menu"
                aria-orientation="vertical"
                aria-labelledby="user-menu-button"
              >
                <.link
                  navigate={~p"/profile"}
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  role="menuitem"
                >
                  Your Profile
                </.link>

                <.link
                  navigate={~p"/settings"}
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  role="menuitem"
                >
                  Settings
                </.link>

                <.link
                  href={~p"/logout"}
                  method="delete"
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50 transition-colors"
                  role="menuitem"
                >
                  Sign out
                </.link>
              </div>
            </div>
          </div>

          <!-- Mobile menu button -->
          <div class="-mr-2 flex items-center sm:hidden">
            <button
              type="button"
              class="inline-flex items-center justify-center p-2 rounded-md text-gray-500 hover:text-gray-700 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-purple-500"
              aria-expanded="false"
              phx-click={JS.toggle(to: "#mobile-menu", in: "transition ease-out duration-100", out: "transition ease-in duration-75", display: "block")}
            >
              <span class="sr-only">Open main menu</span>
              <svg class="block h-6 w-6" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Mobile menu -->
      <div id="mobile-menu" style="display: none;" class="sm:hidden">
        <div class="pt-2 pb-3 space-y-1">
          <.link
            navigate={~p"/dashboard"}
            class={[
              "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :dashboard,
                do: "border-purple-700 text-purple-700 bg-purple-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
            </svg>
            Dashboard
          </.link>

          <.link
            navigate={~p"/channels"}
            class={[
              "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :channels,
                do: "border-purple-700 text-purple-700 bg-purple-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" />
            </svg>
            Channels
          </.link>

          <.link
            navigate={~p"/chat"}
            class={[
              "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :chat,
                do: "border-purple-700 text-purple-700 bg-purple-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            Chat
          </.link>

          <.link
            navigate={~p"/media"}
            class={[
              "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :media,
                do: "border-purple-700 text-purple-700 bg-purple-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z" />
            </svg>
            Media
          </.link>

          <.link
            navigate={~p"/events"}
            class={[
              "flex items-center pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :events,
                do: "border-purple-700 text-purple-700 bg-purple-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
            </svg>
            Events
          </.link>

          <!-- Analytics link removed from mobile menu as well -->
        </div>

        <div class="pt-4 pb-3 border-t border-gray-200">
          <div class="flex items-center px-4">
            <div class="flex-shrink-0">
              <div class="h-10 w-10 rounded-full bg-gradient-to-r from-purple-700 to-indigo-600 flex items-center justify-center text-white font-bold">
                <%= if @current_user, do: String.at(@current_user.email || "", 0) |> String.upcase(), else: "?" %>
              </div>
            </div>
            <div class="ml-3">
              <div class="text-base font-medium text-gray-800">
                <%= if @current_user, do: @current_user.name || @current_user.email, else: "Guest" %>
              </div>
              <div class="text-sm font-medium text-gray-500">
                <%= if @current_user, do: @current_user.email, else: "" %>
              </div>
            </div>
          </div>
          <div class="mt-3 space-y-1">
            <.link
              navigate={~p"/profile"}
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-50"
            >
              Your Profile
            </.link>

            <.link
              navigate={~p"/settings"}
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-50"
            >
              Settings
            </.link>

            <.link
              href={~p"/logout"}
              method="delete"
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-50"
            >
              Sign out
            </.link>
          </div>
        </div>
      </div>
    </nav>
    """
  end
end
