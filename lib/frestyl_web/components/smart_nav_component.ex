# Create this file: lib/frestyl_web/components/smart_nav_component.ex

defmodule FrestylWeb.Components.SmartNavComponent do
  use FrestylWeb, :live_component
  import FrestylWeb.CoreComponents

  # Define the expected attributes
  attr :id, :string, required: true
  attr :current_user, :map, required: true
  attr :current_context, :string, default: "hub"
  attr :portfolios, :list, default: []
  attr :lab_data, :map, default: %{}
  attr :studio_data, :map, default: %{}

  def render(assigns) do
    ~H"""
    <nav class="bg-white shadow-sm border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between h-16">
          <!-- Logo and Main Nav -->
          <div class="flex items-center">
            <.link navigate={~p"/dashboard"} class="flex items-center">
              <img src={~p"/images/logo.svg"} alt="Frestyl" class="h-8 w-auto" />
            </.link>

            <div class="hidden md:ml-8 md:flex md:space-x-8">
              <.nav_link
                to={~p"/portfolios"}
                active={@current_context == "hub"}
                label="Portfolio Hub"
                count={length(@portfolios)} />

              <.nav_link
                to={~p"/lab"}
                active={@current_context == "lab"}
                label="Creator Lab"
                count={map_size(@lab_data)} />

              <.nav_link
                to={~p"/studio"}
                active={@current_context == "studio"}
                label="Studio"
                count={Map.get(@studio_data, :total_portfolios, 0)} />
            </div>
          </div>

          <!-- User Menu -->
          <div class="flex items-center space-x-4">
            <!-- Notifications -->
            <button class="p-2 text-gray-400 hover:text-gray-500">
              <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-3.5-3.5a7 7 0 111.5-4.5M15 17H9.236c.654.654 1.539 1 2.414 1H15z"/>
              </svg>
            </button>

            <!-- User Avatar -->
            <div class="flex items-center space-x-3">
              <img
                src={@current_user.avatar_url || ~p"/images/default-avatar.png"}
                alt={@current_user.name || @current_user.email}
                class="h-8 w-8 rounded-full" />

              <span class="hidden md:block text-sm font-medium text-gray-700">
                <%= @current_user.name || @current_user.email %>
              </span>
            </div>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  # Helper component for navigation links
  defp nav_link(assigns) do
    ~H"""
    <.link
      navigate={@to}
      class={[
        "flex items-center px-3 py-2 text-sm font-medium rounded-md transition-colors",
        if(@active,
          do: "text-indigo-600 bg-indigo-50 border-b-2 border-indigo-600",
          else: "text-gray-500 hover:text-gray-700 hover:bg-gray-50")
      ]}>
      <%= @label %>
      <%= if @count > 0 do %>
        <span class="ml-2 bg-gray-100 text-gray-600 text-xs px-2 py-1 rounded-full">
          <%= @count %>
        </span>
      <% end %>
    </.link>
    """
  end
end
