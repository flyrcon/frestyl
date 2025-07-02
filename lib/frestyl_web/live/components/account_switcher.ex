# lib/frestyl_web/live/components/account_switcher.ex
defmodule FrestylWeb.Components.AccountSwitcher do
  use FrestylWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_menu, false)
     |> assign(:search_query, "")
     |> assign(:show_advanced_switcher, false)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_event("toggle_account_menu", _params, socket) do
    {:noreply, assign(socket, :show_menu, !socket.assigns[:show_menu])}
  end

  @impl true
  def handle_event("show_advanced_switcher", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_menu, false)
     |> assign(:show_advanced_switcher, true)}
  end

  @impl true
  def handle_event("close_advanced_switcher", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_advanced_switcher, false)
     |> assign(:search_query, "")}
  end

  @impl true
  def handle_event("search_accounts", %{"value" => query}, socket) do
    {:noreply, assign(socket, :search_query, query)}
  end

  @impl true
  def handle_event("switch_account", %{"account_id" => account_id}, socket) do
    # Send event to parent LiveView
    send(self(), {:switch_account, String.to_integer(account_id)})
    {:noreply,
     socket
     |> assign(:show_menu, false)
     |> assign(:show_advanced_switcher, false)}
  end

  @impl true
  def handle_event("show_create_account", _params, socket) do
    send(self(), :show_create_account_modal)
    {:noreply,
     socket
     |> assign(:show_menu, false)
     |> assign(:show_advanced_switcher, false)}
  end

  defp filter_accounts(accounts, query) when query == "" or is_nil(query), do: accounts
  defp filter_accounts(accounts, query) do
    query_lower = String.downcase(query)

    Enum.filter(accounts, fn account ->
      String.contains?(String.downcase(account.name), query_lower) or
      String.contains?(String.downcase(account.subscription_tier), query_lower)
    end)
  end

  defp get_account_color(account) do
    case account.subscription_tier do
      "storyteller" -> "from-gray-600 to-gray-800"
      "professional" -> "from-purple-500 to-indigo-500"
      "business" -> "from-blue-500 to-cyan-500"
      _ -> "from-blue-500 to-purple-500"
    end
  end

  defp get_account_stats(account) do
    # Mock data - replace with actual stats
    case account.subscription_tier do
      "storyteller" -> %{portfolios: 2, storage: "1 GB"}
      "professional" -> %{portfolios: "∞", storage: "50 GB"}
      "business" -> %{portfolios: "∞", storage: "500 GB"}
      _ -> %{portfolios: 1, storage: "500 MB"}
    end
  end

  defp format_subscription_tier(tier) do
    case tier do
      "storyteller" -> "Storyteller"
      "professional" -> "Professional"
      "business" -> "Business"
      _ -> String.capitalize(tier)
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="relative">
      <!-- Main Account Switcher Button -->
      <button
        type="button"
        phx-click="toggle_account_menu"
        phx-target={@myself}
        class="flex items-center space-x-2 px-3 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
      >
        <div class={"w-8 h-8 bg-gradient-to-r #{get_account_color(@current_account)} rounded-lg flex items-center justify-center text-white font-bold text-sm"}>
          <%= String.first(Map.get(@current_account, :name, "P")) %>
        </div>
        <div class="text-left">
          <div class="text-sm font-medium text-gray-900"><%= Map.get(@current_account, :name, "Personal Account") %></div>
          <div class="text-xs text-gray-500"><%= format_subscription_tier(@current_account.subscription_tier) %></div>
        </div>
        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </button>

      <!-- Quick Account Menu -->
      <%= if @show_menu do %>
        <div class="absolute top-full left-0 mt-2 w-80 bg-white border border-gray-200 rounded-xl shadow-lg z-50">
          <!-- Current Account -->
          <div class="p-4 border-b border-gray-100">
            <div class="text-xs text-gray-500 uppercase tracking-wide mb-2">Current Account</div>
            <div class="flex items-center space-x-3">
              <div class={"w-10 h-10 bg-gradient-to-r #{get_account_color(@current_account)} rounded-lg flex items-center justify-center text-white font-bold"}>
                <%= String.first(@current_account.name) %>
              </div>
              <div class="flex-1">
                <div class="text-sm font-medium text-gray-900"><%= @current_account.name %></div>
                <div class="text-xs text-gray-500"><%= format_subscription_tier(@current_account.subscription_tier) %></div>
                <div class="text-xs text-gray-400 mt-1">
                  <% stats = get_account_stats(@current_account) %>
                  <%= stats.portfolios %> portfolios • <%= stats.storage %>
                </div>
              </div>
              <div class="w-2 h-2 bg-green-500 rounded-full"></div>
            </div>
          </div>

          <!-- Quick Switch (max 3 other accounts) -->
          <%= if length(@accounts) > 1 do %>
            <div class="p-3">
              <div class="text-xs text-gray-500 uppercase tracking-wide px-1 mb-2">Quick Switch</div>
              <%= for account <- Enum.take(Enum.reject(@accounts, &(&1.id == @current_account.id)), 3) do %>
                <button
                  type="button"
                  phx-click="switch_account"
                  phx-value-account_id={account.id}
                  phx-target={@myself}
                  class="w-full flex items-center space-x-3 px-3 py-2 rounded-lg hover:bg-gray-50 text-left transition-colors"
                >
                  <div class={"w-8 h-8 bg-gradient-to-r #{get_account_color(account)} rounded-lg flex items-center justify-center text-white font-bold text-sm"}>
                    <%= String.first(Map.get(account, :name, "P")) %>
                  </div>
                  <div class="flex-1">
                    <div class="text-sm font-medium text-gray-900"><%= Map.get(account, :name, "Personal Account") %></div>
                    <div class="text-xs text-gray-500"><%= format_subscription_tier(account.subscription_tier) %></div>
                  </div>
                  <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                  </svg>
                </button>
              <% end %>

              <!-- Show All Accounts link if more than 3 -->
              <%= if length(@accounts) > 4 do %>
                <button
                  type="button"
                  phx-click="show_advanced_switcher"
                  phx-target={@myself}
                  class="w-full flex items-center justify-center space-x-2 px-3 py-2 mt-2 text-purple-600 hover:bg-purple-50 rounded-lg text-sm font-medium transition-colors"
                >
                  <span>View All Accounts (<%= length(@accounts) - 1 %>)</span>
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                  </svg>
                </button>
              <% end %>
            </div>
          <% end %>

          <!-- Actions -->
          <div class="border-t border-gray-100 p-3 space-y-2">
            <%= if length(@accounts) > 4 do %>
              <button
                type="button"
                phx-click="show_advanced_switcher"
                phx-target={@myself}
                class="w-full flex items-center space-x-2 px-3 py-2 rounded-lg hover:bg-gray-50 text-left text-gray-700 transition-colors"
              >
                <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <span class="text-sm font-medium">Search All Accounts</span>
              </button>
            <% end %>

            <button
              type="button"
              phx-click="show_create_account"
              phx-target={@myself}
              class="w-full flex items-center space-x-2 px-3 py-2 rounded-lg hover:bg-gray-50 text-left text-purple-600 transition-colors"
            >
              <div class="w-4 h-4 border-2 border-dashed border-purple-300 rounded flex items-center justify-center">
                <svg class="w-2 h-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M12 4v16m8-8H4" />
                </svg>
              </div>
              <span class="text-sm font-medium">Create New Account</span>
            </button>
          </div>
        </div>
      <% end %>

      <!-- Advanced Account Switcher Modal -->
      <%= if @show_advanced_switcher do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" phx-click="close_advanced_switcher" phx-target={@myself}>
          <div class="bg-white rounded-2xl shadow-xl max-w-2xl w-full max-h-[80vh] overflow-hidden" phx-click={JS.stop_propagation()}>
            <!-- Header -->
            <div class="p-6 border-b border-gray-200">
              <div class="flex items-center justify-between mb-4">
                <h3 class="text-xl font-bold text-gray-900">Switch Account</h3>
                <button
                  phx-click="close_advanced_switcher"
                  phx-target={@myself}
                  class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center hover:bg-gray-200 transition-colors"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>

              <!-- Search -->
              <div class="relative">
                <svg class="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                </svg>
                <input
                  type="text"
                  placeholder="Search accounts..."
                  value={@search_query}
                  phx-keyup="search_accounts"
                  phx-target={@myself}
                  class="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-purple-500 focus:border-purple-500"
                />
              </div>
            </div>

            <!-- Account List -->
            <div class="p-6 space-y-3 max-h-96 overflow-y-auto">
              <%= for account <- filter_accounts(@accounts, @search_query) do %>
                <button
                  phx-click="switch_account"
                  phx-value-account_id={account.id}
                  phx-target={@myself}
                  class={"w-full p-4 rounded-xl border-2 transition-all hover:shadow-md #{
                    if account.id == @current_account.id,
                      do: "border-purple-500 bg-purple-50",
                      else: "border-gray-200 hover:border-purple-300"
                  }"}
                >
                  <div class="flex items-center space-x-4">
                    <div class={"w-12 h-12 bg-gradient-to-r #{get_account_color(account)} rounded-xl flex items-center justify-center text-white font-bold"}>
                      <%= String.first(account.name) %>
                    </div>

                    <div class="flex-1 text-left">
                      <div class="flex items-center space-x-2">
                        <h4 class="font-bold text-gray-900"><%= account.name %></h4>
                        <%= if account.id == @current_account.id do %>
                          <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                          </svg>
                        <% end %>
                      </div>
                      <p class="text-sm text-gray-600"><%= format_subscription_tier(account.subscription_tier) %></p>
                      <p class="text-xs text-gray-500">
                        <% stats = get_account_stats(account) %>
                        <%= stats.portfolios %> portfolios • <%= stats.storage %>
                      </p>
                    </div>

                    <div class="text-right">
                      <%= if account.id == @current_account.id do %>
                        <div class="text-xs text-purple-600 font-medium">Current</div>
                      <% else %>
                        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                        </svg>
                      <% end %>
                    </div>
                  </div>
                </button>
              <% end %>
            </div>

            <!-- Footer -->
            <div class="p-6 border-t border-gray-200">
              <button
                phx-click="show_create_account"
                phx-target={@myself}
                class="w-full flex items-center justify-center space-x-2 px-4 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl hover:shadow-lg transition-all"
              >
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                <span>Create New Account</span>
              </button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
