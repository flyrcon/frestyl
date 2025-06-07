# lib/frestyl_web/live/studio_live/header_component.ex
defmodule FrestylWeb.StudioLive.HeaderComponent do
  use FrestylWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <header class="flex items-center justify-between px-4 py-2 bg-gray-900 bg-opacity-70 border-b border-gray-800">
      <div class="flex items-center">
        <div class="mr-4">
          <.link navigate={~p"/channels/#{@channel.slug}"} class="text-white hover:text-indigo-300">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </.link>
        </div>

        <div class="flex items-center space-x-2">
          <div class="text-sm text-gray-400 uppercase tracking-wider">
            <%= @channel.name %>
          </div>
          <span class="text-gray-600">/</span>
          <div class="text-white font-medium">
            <%= @session.title || "Untitled Session" %>
          </div>
        </div>
      </div>

      <div class="flex items-center space-x-3">
        <!-- Connection status -->
        <span class={[
          "h-2 w-2 rounded-full",
          case @connection_status do
            "connected" -> "bg-green-500"
            "connecting" -> "bg-yellow-500"
            _ -> "bg-red-500"
          end
        ]} title={String.capitalize(@connection_status)}></span>

        <!-- Members indicator -->
        <div class="relative">
          <div class="flex items-center text-gray-400 hover:text-white">
            <span class="text-sm"><%= length(@collaborators) %></span>
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v1h8v-1zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-1a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v1h-3zM4.75 12.094A5.973 5.973 0 004 15v1H1v-1a3 3 0 013.75-2.906z" />
            </svg>
          </div>
        </div>

        <!-- Settings button -->
        <button
          type="button"
          phx-click="toggle_settings_modal"
          class="text-gray-400 hover:text-white"
          aria-label="Settings"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
          </svg>
        </button>

        <!-- End Session button -->
        <%= if @current_user.id == @session.creator_id || @current_user.id == @session.host_id do %>
          <button
            type="button"
            phx-click="end_session"
            class="bg-red-500 hover:bg-red-600 text-white rounded-md px-3 py-1"
          >
            End
          </button>
        <% end %>
      </div>
    </header>
    """
  end
end
