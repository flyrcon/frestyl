# lib/frestyl_web/components/subscription_components.ex
defmodule FrestylWeb.Components.SubscriptionComponents do
  use FrestylWeb, :html

  alias Frestyl.Portfolios

  @doc """
  Renders an upgrade prompt modal for when users hit subscription limits.
  """
  def upgrade_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50"
         id="upgrade-modal">
      <div class="bg-white rounded-2xl shadow-2xl max-w-lg w-full mx-4 overflow-hidden"
           phx-click-away="hide_upgrade_modal">

        <!-- Header -->
        <div class="bg-gradient-to-r from-purple-600 to-pink-600 px-6 py-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-white bg-opacity-20 rounded-full flex items-center justify-center mr-3">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              </div>
              <h3 class="text-xl font-bold text-white">Upgrade Required</h3>
            </div>
            <button phx-click="hide_upgrade_modal" class="text-white hover:text-gray-200">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Content -->
        <div class="p-6">
          <div class="text-center mb-6">
            <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>

            <h4 class="text-xl font-bold text-gray-900 mb-2">
              <%= Map.get(assigns, :title, "Unlock Premium Features") %>
            </h4>

            <p class="text-gray-600">
              <%= Map.get(assigns, :message, "You've reached your current plan's limits. Upgrade to continue using this feature.") %>
            </p>
          </div>

          <!-- Feature Highlights -->
          <div class="grid grid-cols-1 gap-3 mb-6">
            <%= for feature <- Map.get(assigns, :features, get_default_upgrade_features()) do %>
              <div class="flex items-center p-3 bg-purple-50 rounded-lg">
                <svg class="w-5 h-5 text-purple-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
                <span class="text-gray-700 font-medium"><%= feature %></span>
              </div>
            <% end %>
          </div>

          <!-- Action Buttons -->
          <div class="space-y-3">
            <.link
              navigate="/account/subscription"
              class="w-full bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-bold py-3 px-6 rounded-xl transition-all duration-300 transform hover:scale-105 inline-flex items-center justify-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
              Upgrade Now
            </.link>

            <button
              phx-click="hide_upgrade_modal"
              class="w-full bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium py-3 px-6 rounded-xl transition-colors">
              Maybe Later
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a feature gate component that shows upgrade prompt for premium features.
  """
  def feature_gate(assigns) do
    user = Map.get(assigns, :user)
    feature = Map.get(assigns, :feature)
    limits = if user, do: Portfolios.get_portfolio_limits(user), else: %{}

    has_access = case feature do
      :ats_optimization -> Map.get(limits, :ats_optimization, false)
      :advanced_analytics -> Map.get(limits, :advanced_analytics, false)
      :custom_domains -> Map.get(limits, :custom_domains, false)
      :unlimited_portfolios -> Map.get(limits, :max_portfolios, 2) == -1
      :premium_templates -> Map.get(limits, :premium_templates, false)
      :team_collaboration -> Map.get(limits, :team_collaboration, false)
      _ -> false
    end

    assigns = assign(assigns, :has_access, has_access)

    ~H"""
    <%= if @has_access do %>
      <%= render_slot(@inner_block) %>
    <% else %>
      <div class="relative">
        <!-- Overlay for locked feature -->
        <div class="absolute inset-0 bg-gray-50 bg-opacity-95 backdrop-blur-sm rounded-lg z-10 flex items-center justify-center">
          <div class="text-center p-6">
            <div class="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-3">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>
            <h4 class="font-bold text-gray-900 mb-2">Premium Feature</h4>
            <p class="text-sm text-gray-600 mb-4">
              <%= get_feature_message(@feature) %>
            </p>
            <.link
              navigate="/account/subscription"
              class="inline-flex items-center px-4 py-2 bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white font-medium text-sm rounded-lg transition-all">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
              Upgrade Plan
            </.link>
          </div>
        </div>

        <!-- Blurred content -->
        <div class="filter blur-sm pointer-events-none">
          <%= render_slot(@inner_block) %>
        </div>
      </div>
    <% end %>
    """
  end

  @doc """
  Renders a subscription status badge.
  """
  def subscription_badge(assigns) do
    tier = Map.get(assigns, :tier, "storyteller")

    {badge_class, badge_text} = case tier do
      "storyteller" -> {"bg-gray-100 text-gray-800", "Free"}
      "professional" -> {"bg-purple-100 text-purple-800", "Pro"}
      "business" -> {"bg-blue-100 text-blue-800", "Business"}
      _ -> {"bg-gray-100 text-gray-800", "Free"}
    end

    assigns = assigns |> assign(:badge_class, badge_class) |> assign(:badge_text, badge_text)

    ~H"""
    <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{@badge_class}"}>
      <%= @badge_text %>
    </span>
    """
  end

  @doc """
  Renders a usage meter for subscription limits.
  """
  def usage_meter(assigns) do
    ~H"""
    <div class="bg-white rounded-lg p-4 border border-gray-200">
      <div class="flex items-center justify-between mb-2">
        <h4 class="text-sm font-medium text-gray-900"><%= @title %></h4>
        <span class="text-sm text-gray-500">
          <%= @current %> / <%= if @max == -1, do: "∞", else: @max %>
        </span>
      </div>

      <%= if @max != -1 do %>
        <div class="w-full bg-gray-200 rounded-full h-2 mb-2">
          <div
            class={"h-2 rounded-full transition-all duration-300 #{get_usage_color(@current, @max)}"}
            style={"width: #{min(100, (@current / @max) * 100)}%"}>
          </div>
        </div>

        <div class="flex justify-between text-xs text-gray-500">
          <span><%= Float.round((@current / @max) * 100, 1) %>% used</span>
          <%= if @current >= @max do %>
            <span class="text-red-600 font-medium">Limit reached</span>
          <% else %>
            <span><%= @max - @current %> remaining</span>
          <% end %>
        </div>
      <% else %>
        <div class="text-xs text-green-600 font-medium">Unlimited</div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a compact upgrade CTA for inline use.
  """
  def inline_upgrade_cta(assigns) do
    ~H"""
    <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-lg p-4">
      <div class="flex items-center justify-between">
        <div class="flex items-center">
          <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center mr-3">
            <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
          </div>
          <div>
            <h4 class="font-medium text-gray-900"><%= Map.get(assigns, :title, "Upgrade to unlock this feature") %></h4>
            <p class="text-sm text-gray-600"><%= Map.get(assigns, :message, "Get more with a premium plan") %></p>
          </div>
        </div>
        <.link
          navigate="/account/subscription"
          class="inline-flex items-center px-3 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm font-medium rounded-lg transition-colors">
          Upgrade
        </.link>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_default_upgrade_features do
    [
      "Unlimited portfolios",
      "Custom domains",
      "Advanced analytics",
      "ATS optimization",
      "Premium templates"
    ]
  end

  defp get_feature_message(feature) do
    case feature do
      :ats_optimization -> "ATS optimization is available on Professional and Business plans."
      :advanced_analytics -> "Advanced analytics require a Professional or Business plan."
      :custom_domains -> "Custom domains are available with Professional and Business plans."
      :unlimited_portfolios -> "Create unlimited portfolios with a Professional or Business plan."
      :premium_templates -> "Premium templates require a Professional or Business plan."
      :team_collaboration -> "Team collaboration is available on Business plans."
      _ -> "This feature requires a premium subscription."
    end
  end

  defp get_usage_color(current, max) do
    percentage = (current / max) * 100

    cond do
      percentage >= 90 -> "bg-red-500"
      percentage >= 75 -> "bg-yellow-500"
      true -> "bg-green-500"
    end
  end
end
