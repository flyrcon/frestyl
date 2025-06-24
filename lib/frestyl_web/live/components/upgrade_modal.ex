# lib/frestyl_web/live/components/upgrade_modal.ex
defmodule FrestylWeb.Components.UpgradeModal do
  use FrestylWeb, :live_component

  def render(assigns) do
    ~H"""
    <%= if @show do %>
      <div class="fixed inset-0 z-50 overflow-y-auto">
        <div class="flex items-center justify-center min-h-screen px-4 pt-4 pb-20 text-center sm:block sm:p-0">
          <!-- Background overlay -->
          <div class="fixed inset-0 transition-opacity bg-gray-500 bg-opacity-75" phx-click="close_upgrade_modal" phx-target={@myself}></div>

          <!-- Modal panel -->
          <div class="inline-block w-full max-w-lg p-6 my-8 overflow-hidden text-left align-middle transition-all transform bg-white shadow-xl rounded-2xl">

            <!-- Header -->
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center space-x-3">
                <div class="w-12 h-12 bg-gradient-to-r from-purple-500 to-pink-500 rounded-xl flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z" />
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-semibold text-gray-900"><%= @suggestion.title %></h3>
                  <p class="text-sm text-gray-600"><%= @suggestion.reason %></p>
                </div>
              </div>
              <button
                type="button"
                phx-click="close_upgrade_modal"
                phx-target={@myself}
                class="text-gray-400 hover:text-gray-600"
              >
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>

            <!-- Benefits -->
            <div class="mb-6">
              <h4 class="text-sm font-medium text-gray-900 mb-3">What you'll get:</h4>
              <div class="space-y-2">
                <%= for benefit <- @suggestion.benefits do %>
                  <div class="flex items-center space-x-2">
                    <svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    <span class="text-sm text-gray-700"><%= benefit %></span>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Pricing -->
            <div class="bg-gradient-to-r from-purple-50 to-pink-50 rounded-xl p-4 mb-6">
              <div class="text-center">
                <div class="text-2xl font-bold text-gray-900"><%= @suggestion.price %></div>
                <div class="text-sm text-gray-600">Billed monthly • Cancel anytime</div>
              </div>
            </div>

            <!-- Actions -->
            <div class="flex space-x-3">
              <button
                type="button"
                phx-click="close_upgrade_modal"
                phx-target={@myself}
                class="flex-1 px-4 py-2 text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 font-medium"
              >
                Maybe Later
              </button>
              <button
                type="button"
                phx-click="start_upgrade"
                phx-value-tier={@suggestion.suggested_tier}
                phx-target={@myself}
                class="flex-1 px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 text-white rounded-lg hover:from-purple-700 hover:to-pink-700 font-medium"
              >
                <%= @suggestion.cta %>
              </button>
            </div>

            <!-- Trust signals -->
            <div class="mt-4 text-center">
              <p class="text-xs text-gray-500">
                ✓ 14-day free trial • ✓ No setup fees • ✓ Cancel anytime
              </p>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  def handle_event("close_upgrade_modal", _params, socket) do
    send(self(), :close_upgrade_modal)
    {:noreply, socket}
  end

  def handle_event("start_upgrade", %{"tier" => tier}, socket) do
    send(self(), {:start_upgrade, tier})
    {:noreply, socket}
  end
end
