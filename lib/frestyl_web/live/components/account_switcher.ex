# lib/frestyl_web/live/components/account_switcher.ex
defmodule FrestylWeb.Components.AccountSwitcher do
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="relative">
      <button
        type="button"
        phx-click="toggle_account_menu"
        phx-target={@myself}
        class="flex items-center space-x-2 px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50"
      >
        <div class="w-8 h-8 bg-gradient-to-r from-blue-500 to-purple-500 rounded-lg flex items-center justify-center text-white font-bold text-sm">
          <%= String.first(@current_account.name) %>
        </div>
        <div class="text-left">
          <div class="text-sm font-medium text-gray-900"><%= @current_account.name %></div>
          <div class="text-xs text-gray-500 capitalize"><%= @current_account.subscription_tier %></div>
        </div>
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <%= if @show_menu do %>
        <div class="absolute top-full left-0 mt-2 w-64 bg-white border border-gray-200 rounded-lg shadow-lg z-50">
          <!-- Current Account -->
          <div class="p-3 border-b border-gray-100">
            <div class="text-xs text-gray-500 uppercase tracking-wide">Current Account</div>
            <div class="flex items-center space-x-2 mt-1">
              <div class="w-6 h-6 bg-gradient-to-r from-blue-500 to-purple-500 rounded-md flex items-center justify-center text-white font-bold text-xs">
                <%= String.first(@current_account.name) %>
              </div>
              <div>
                <div class="text-sm font-medium"><%= @current_account.name %></div>
                <div class="text-xs text-gray-500 capitalize"><%= @current_account.subscription_tier %></div>
              </div>
            </div>
          </div>

          <!-- Other Accounts -->
          <%= if length(@accounts) > 1 do %>
            <div class="p-2">
              <div class="text-xs text-gray-500 uppercase tracking-wide px-2 py-1">Switch Account</div>
              <%= for account <- @accounts do %>
                <%= if account.id != @current_account.id do %>
                  <button
                    type="button"
                    phx-click="switch_account"
                    phx-value-account_id={account.id}
                    phx-target={@myself}
                    class="w-full flex items-center space-x-2 px-2 py-2 rounded-md hover:bg-gray-50 text-left"
                  >
                    <div class="w-6 h-6 bg-gradient-to-r from-green-500 to-teal-500 rounded-md flex items-center justify-center text-white font-bold text-xs">
                      <%= String.first(account.name) %>
                    </div>
                    <div>
                      <div class="text-sm font-medium"><%= account.name %></div>
                      <div class="text-xs text-gray-500 capitalize"><%= account.subscription_tier %></div>
                    </div>
                  </button>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <!-- Create New Account -->
          <div class="border-t border-gray-100 p-2">
            <button
              type="button"
              phx-click="show_create_account"
              phx-target={@myself}
              class="w-full flex items-center space-x-2 px-2 py-2 rounded-md hover:bg-gray-50 text-left text-blue-600"
            >
              <div class="w-6 h-6 border-2 border-dashed border-blue-300 rounded-md flex items-center justify-center">
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <div class="text-sm font-medium">Create New Account</div>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def handle_event("toggle_account_menu", _params, socket) do
    {:noreply, assign(socket, :show_menu, !socket.assigns[:show_menu])}
  end

  def handle_event("switch_account", %{"account_id" => account_id}, socket) do
    # Send event to parent LiveView
    send(self(), {:switch_account, String.to_integer(account_id)})
    {:noreply, assign(socket, :show_menu, false)}
  end

  def handle_event("show_create_account", _params, socket) do
    send(self(), :show_create_account_modal)
    {:noreply, assign(socket, :show_menu, false)}
  end
end
