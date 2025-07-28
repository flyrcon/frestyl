# lib/frestyl_web/components/simple_nav.ex

defmodule FrestylWeb.Components.SimpleNav do
  @moduledoc """
  Simple navigation component for the portfolio editor
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents

  def nav(assigns) do
    ~H"""
    <nav class="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Logo/Brand -->
          <div class="flex items-center">
            <.link navigate="/" class="flex items-center">
              <div class="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center mr-3">
                <span class="text-white font-bold text-sm">F</span>
              </div>
              <span class="text-xl font-bold text-gray-900">Frestyl</span>
            </.link>
          </div>

          <!-- Navigation Links -->
          <div class="hidden md:flex items-center space-x-8">
            <.link navigate="/portfolios"
                   class={[
                     "text-sm font-medium transition-colors",
                     if(Map.get(assigns, :active_tab) == :portfolio_editor,
                       do: "text-blue-600",
                       else: "text-gray-700 hover:text-gray-900")
                   ]}>
              Portfolios
            </.link>

            <.link navigate="/dashboard"
                   class="text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors">
              Dashboard
            </.link>
          </div>

          <!-- User Menu -->
          <div class="flex items-center space-x-4">
            <%= if assigns[:current_user] do %>
              <div class="flex items-center space-x-3">
                <span class="text-sm text-gray-700">
                  <%= Map.get(@current_user, :name, "User") %>
                </span>
                <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
                  <span class="text-xs font-medium text-gray-600">
                    <%= String.first(Map.get(@current_user, :name, "U")) %>
                  </span>
                </div>
              </div>
            <% else %>
              <.link navigate="/login"
                     class="text-sm font-medium text-gray-700 hover:text-gray-900 transition-colors">
                Sign In
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end
end
