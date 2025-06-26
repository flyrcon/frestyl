# lib/frestyl_web/live/components/subscription_gate_component.ex
defmodule FrestylWeb.SubscriptionGateComponent do
  use FrestylWeb, :live_component

  alias Frestyl.Portfolios

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"subscription-gate-#{@id}"}>
      <%= case Portfolios.check_upgrade_requirements(@user, @action, @params || %{}) do %>
        <% {:ok, :allowed} -> %>
          <%= render_slot(@inner_block) %>

        <% {:error, :upgrade_required, details} -> %>
          <div class="relative">
            <!-- Upgrade Required Overlay -->
            <div class="absolute inset-0 bg-gray-50 bg-opacity-95 backdrop-blur-sm rounded-lg z-10 flex items-center justify-center">
              <div class="text-center p-6 max-w-md">
                <div class="w-16 h-16 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center mx-auto mb-4">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                </div>

                <h3 class="text-xl font-bold text-gray-900 mb-2">
                  Upgrade to <%= String.capitalize(details.required_tier) %>
                </h3>

                <p class="text-gray-600 mb-4">
                  <%= details.message %>
                </p>

                <div class="space-y-2 mb-6">
                  <%= for benefit <- details.upgrade_benefits do %>
                    <div class="flex items-center text-sm text-gray-700">
                      <svg class="w-4 h-4 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <%= benefit %>
                    </div>
                  <% end %>
                </div>

                <div class="space-y-3">
                  <.link
                    navigate="/account/subscription"
                    class="w-full bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold py-3 px-6 rounded-xl transition-all duration-300 transform hover:scale-105 inline-flex items-center justify-center">
                    <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                    Upgrade Now
                  </.link>

                  <%= if Map.get(assigns, :allow_dismiss, true) do %>
                    <button
                      phx-click="dismiss_upgrade_gate"
                      phx-target={@myself}
                      class="w-full text-gray-600 hover:text-gray-700 font-medium py-2">
                      Maybe Later
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Blurred/Disabled Content -->
            <div class="filter blur-sm pointer-events-none opacity-50">
              <%= render_slot(@inner_block) %>
            </div>
          </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("dismiss_upgrade_gate", _params, socket) do
    # Track the dismissal for analytics
    Frestyl.Analytics.track_upgrade_prompt_dismissed(
      socket.assigns.user.id,
      socket.assigns.action,
      socket.assigns.user.subscription_tier
    )

    # You could add logic here to temporarily hide the gate
    # or redirect the user elsewhere

    {:noreply, socket}
  end
end
