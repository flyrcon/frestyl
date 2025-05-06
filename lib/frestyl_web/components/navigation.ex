# lib/frestyl_web/components/navigation.ex
defmodule FrestylWeb.Navigation do
  use Phoenix.Component
  use FrestylWeb, :verified_routes

  attr :active_tab, :atom, required: true
  attr :current_user, :map, required: true

  def nav(assigns) do
    ~H"""
    <nav class="bg-white shadow">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <div class="flex">
            <div class="flex-shrink-0 flex items-center">
              <.link navigate={~p"/"} class="flex items-center">
                <span class="text-[#DD1155] text-xl font-bold">Frestyl</span>
              </.link>
            </div>
            <div class="hidden sm:ml-6 sm:flex sm:space-x-8">
              <!-- Primary Navigation Menu -->
              <.link
                navigate={~p"/dashboard"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :dashboard,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Dashboard
              </.link>

              <.link
                navigate={~p"/channels"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :channels,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Channels
              </.link>

              <.link
                navigate={~p"/chat"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :chat,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Chat
              </.link>

              <.link
                navigate={~p"/media"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :media,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Media
              </.link>

              <.link
                navigate={~p"/events"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :events,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Events
              </.link>

              <.link
                navigate={~p"/analytics"}
                class={[
                  "inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium",
                  if(@active_tab == :analytics,
                    do: "border-[#DD1155] text-gray-900",
                    else: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700"
                  )
                ]}
              >
                Analytics
              </.link>
            </div>
          </div>

          <div class="hidden sm:ml-6 sm:flex sm:items-center">
            <!-- Profile dropdown -->
            <div class="ml-3 relative">
              <div>
                <button
                  id="user-menu-button"
                  type="button"
                  class="bg-white flex text-sm rounded-full focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-[#DD1155]"
                  aria-haspopup="true"
                  phx-click={JS.toggle(to: "#user-menu", in: "transition ease-out duration-100", out: "transition ease-in duration-75", display: "block")}
                >
                  <span class="sr-only">Open user menu</span>
                  <div class="h-8 w-8 rounded-full bg-[#DD1155] flex items-center justify-center text-white font-bold">
                    <%= if @current_user, do: String.at(@current_user.email, 0) |> String.upcase(), else: "?" %>
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
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                  role="menuitem"
                >
                  Your Profile
                </.link>

                <.link
                  href={~p"/logout"}
                  method="delete"
                  class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
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
              class="inline-flex items-center justify-center p-2 rounded-md text-gray-400 hover:text-gray-500 hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-inset focus:ring-[#DD1155]"
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
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :dashboard,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Dashboard
          </.link>

          <.link
            navigate={~p"/channels"}
            class={[
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :channels,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Channels
          </.link>

          <.link
            navigate={~p"/chat"}
            class={[
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :chat,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Chat
          </.link>

          <.link
            navigate={~p"/media"}
            class={[
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :media,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Media
          </.link>

          <.link
            navigate={~p"/events"}
            class={[
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :events,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Events
          </.link>

          <.link
            navigate={~p"/analytics"}
            class={[
              "block pl-3 pr-4 py-2 border-l-4 text-base font-medium",
              if(@active_tab == :analytics,
                do: "border-[#DD1155] text-[#DD1155] bg-red-50",
                else: "border-transparent text-gray-500 hover:bg-gray-50 hover:border-gray-300 hover:text-gray-700"
              )
            ]}
          >
            Analytics
          </.link>
        </div>

        <div class="pt-4 pb-3 border-t border-gray-200">
          <div class="flex items-center px-4">
            <div class="flex-shrink-0">
              <div class="h-10 w-10 rounded-full bg-[#DD1155] flex items-center justify-center text-white font-bold">
                <%= if @current_user, do: String.at(@current_user.email, 0) |> String.upcase(), else: "?" %>
              </div>
            </div>
            <div class="ml-3">
              <div class="text-base font-medium text-gray-800">
                <%= if @current_user, do: @current_user.email, else: "Guest" %>
              </div>
            </div>
          </div>
          <div class="mt-3 space-y-1">
            <.link
              navigate={~p"/profile"}
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-100"
            >
              Your Profile
            </.link>

            <.link
              href={~p"/logout"}
              method="delete"
              class="block px-4 py-2 text-base font-medium text-gray-500 hover:text-gray-800 hover:bg-gray-100"
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
