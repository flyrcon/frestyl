# lib/frestyl_web/live/subscription_live.ex
defmodule FrestylWeb.SubscriptionLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Portfolios

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    limits = Portfolios.get_portfolio_limits(user)
    usage_data = get_usage_data(user)

    {:ok,
     socket
     |> assign(:page_title, "Subscription")
     |> assign(:active_tab, "overview")
     |> assign(:limits, limits)
     |> assign(:usage_data, usage_data)
     |> assign(:show_upgrade_modal, false)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("show_upgrade_modal", _params, socket) do
    {:noreply, assign(socket, :show_upgrade_modal, true)}
  end

  @impl true
  def handle_event("close_upgrade_modal", _params, socket) do
    {:noreply, assign(socket, :show_upgrade_modal, false)}
  end

  @impl true
  def handle_event("upgrade_plan", %{"plan" => plan}, socket) do
    case upgrade_user_plan(socket.assigns.current_user, plan) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> assign(:show_upgrade_modal, false)
         |> put_flash(:info, "Successfully upgraded to #{String.capitalize(plan)} plan!")
         |> push_navigate(to: "/portfolios")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to upgrade plan. Please try again.")}
    end
  end

  @impl true
  def handle_event("manage_billing", _params, socket) do
    # Redirect to billing portal
    {:noreply, push_navigate(socket, to: "/account/billing")}
  end

  defp get_usage_data(user) do
    portfolios = Portfolios.list_user_portfolios(user.id)

    %{
      portfolios: %{used: length(portfolios), limit: get_portfolio_limit(user.subscription_tier)},
      storage: %{used: 2.3, limit: get_storage_limit(user.subscription_tier)},
      custom_domains: %{used: 1, limit: get_domain_limit(user.subscription_tier)},
      monthly_views: %{used: 1247, limit: get_view_limit(user.subscription_tier)},
      video_intros: %{used: 2, limit: get_video_limit(user.subscription_tier)},
      lab_access: has_lab_access?(user.subscription_tier)
    }
  end

  defp get_portfolio_limit("storyteller"), do: 2
  defp get_portfolio_limit(_), do: :unlimited

  defp get_storage_limit("storyteller"), do: 1
  defp get_storage_limit("professional"), do: 50
  defp get_storage_limit("business"), do: 500

  defp get_domain_limit("storyteller"), do: 0
  defp get_domain_limit("professional"), do: 3
  defp get_domain_limit("business"), do: :unlimited

  defp get_view_limit("storyteller"), do: 1000
  defp get_view_limit(_), do: :unlimited

  defp get_video_limit("storyteller"), do: 1
  defp get_video_limit(_), do: :unlimited

  defp has_lab_access?(_), do: true  # All plans have Lab access

  defp upgrade_user_plan(user, plan) do
    # Implement actual subscription upgrade logic
    # This would integrate with your payment processor
    Accounts.update_user(user, %{"subscription_tier" => plan})
  end

  defp get_plan_data do
    %{
      "storyteller" => %{
        name: "Storyteller",
        price: 0,
        color: "from-gray-600 to-gray-800",
        features: [
          "2 portfolios",
          "Basic templates",
          "Video introductions (not streaming)",
          "Public sharing",
          "Access to the Lab"
        ],
        limitations: ["Limited customization", "No analytics", "No custom domains"]
      },
      "professional" => %{
        name: "Professional",
        price: 12,
        color: "from-purple-600 to-indigo-600",
        features: [
          "Unlimited portfolios",
          "Premium templates",
          "Custom domains",
          "Analytics & insights",
          "ATS optimization",
          "Video introductions & streaming",
          "Full access to the Lab"
        ],
        limitations: ["No team features", "Standard support"]
      },
      "business" => %{
        name: "Business",
        price: 29,
        color: "from-blue-600 to-cyan-600",
        features: [
          "Everything in Professional",
          "Team collaboration",
          "Multi-account management",
          "Advanced analytics",
          "Priority support",
          "White-label options",
          "Unlimited Lab access"
        ],
        limitations: []
      }
    }
  end

  defp get_usage_color(used, limit) when limit == :unlimited, do: "bg-green-500"
  defp get_usage_color(used, limit) do
    percentage = (used / limit) * 100
    cond do
      percentage < 70 -> "bg-green-500"
      percentage < 90 -> "bg-yellow-500"
      true -> "bg-red-500"
    end
  end

  defp get_usage_percentage(used, limit) when limit == :unlimited do
    min(used / 10 * 100, 100)
  end
  defp get_usage_percentage(used, limit) do
    min(used / limit * 100, 100)
  end

  defp format_limit(:unlimited), do: "∞"
  defp format_limit(limit), do: to_string(limit)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50 pt-16">
      <!-- Navigation -->
      <.live_component
        module={FrestylWeb.Components.NavigationComponent}
        id="navigation"
        current_user={@current_user}
        active_tab={:subscription}
      />

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-black text-gray-900 mb-2">Subscription Management</h1>
          <p class="text-gray-600">Manage your plan and discover powerful features</p>
        </div>

        <!-- Current Plan Overview -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 overflow-hidden mb-8">
          <div class={"h-2 bg-gradient-to-r #{get_plan_data()[@current_user.subscription_tier].color}"}></div>

          <div class="p-8">
            <div class="flex items-center justify-between mb-6">
              <div class="flex items-center space-x-4">
                <div class={"w-16 h-16 bg-gradient-to-r #{get_plan_data()[@current_user.subscription_tier].color} rounded-2xl flex items-center justify-center"}>
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3l14 0 0 11c0 6-4 9-7 9s-7-3-7-9l0-11z"/>
                  </svg>
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-gray-900"><%= get_plan_data()[@current_user.subscription_tier].name %> Plan</h2>
                  <p class="text-gray-600">
                    $<%= get_plan_data()[@current_user.subscription_tier].price %>/month
                    <%= if get_plan_data()[@current_user.subscription_tier].price > 0, do: "• Billed monthly" %>
                  </p>
                </div>
              </div>

              <%= if @current_user.subscription_tier != "business" do %>
                <button
                  phx-click="show_upgrade_modal"
                  class="flex items-center space-x-2 px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl hover:shadow-lg transition-all"
                >
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11l5-5m0 0l5 5m-5-5v12"/>
                  </svg>
                  <span>Upgrade Plan</span>
                </button>
              <% end %>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div>
                <h3 class="font-bold text-gray-900 mb-4">What's Included</h3>
                <ul class="space-y-2">
                  <%= for feature <- get_plan_data()[@current_user.subscription_tier].features do %>
                    <li class="flex items-center space-x-2">
                      <svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <span class="text-gray-700"><%= feature %></span>
                    </li>
                  <% end %>
                </ul>
              </div>

              <%= if length(get_plan_data()[@current_user.subscription_tier].limitations) > 0 do %>
                <div>
                  <h3 class="font-bold text-gray-900 mb-4">Upgrade to Unlock</h3>
                  <ul class="space-y-2">
                    <%= for limitation <- get_plan_data()[@current_user.subscription_tier].limitations do %>
                      <li class="flex items-center space-x-2">
                        <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                        </svg>
                        <span class="text-gray-500"><%= limitation %></span>
                      </li>
                    <% end %>
                  </ul>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Navigation Tabs -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 mb-8">
          <div class="border-b border-gray-200">
            <nav class="flex space-x-8 px-8" aria-label="Tabs">
              <%= for {tab_id, tab_name} <- [
                {"overview", "Overview"},
                {"usage", "Usage & Limits"},
                {"features", "Feature Discovery"},
                {"billing", "Billing"}
              ] do %>
                <button
                  phx-click="change_tab"
                  phx-value-tab={tab_id}
                  class={"py-4 px-1 border-b-2 font-medium text-sm transition-colors #{
                    if @active_tab == tab_id,
                      do: "border-purple-500 text-purple-600",
                      else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
                  }"}
                >
                  <%= tab_name %>
                </button>
              <% end %>
            </nav>
          </div>
        </div>

        <!-- Tab Content -->
        <%= case @active_tab do %>
          <% "overview" -> %>
            <%= render_overview_tab(assigns) %>
          <% "usage" -> %>
            <%= render_usage_tab(assigns) %>
          <% "features" -> %>
            <%= render_features_tab(assigns) %>
          <% "billing" -> %>
            <%= render_billing_tab(assigns) %>
        <% end %>

        <!-- Upgrade Modal -->
        <%= if @show_upgrade_modal do %>
          <%= render_upgrade_modal(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_overview_tab(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
      <!-- Quick Actions -->
      <div class="lg:col-span-2 space-y-6">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center space-x-3 mb-4">
              <div class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </div>
              <h3 class="font-bold text-gray-900">Usage Analytics</h3>
            </div>
            <p class="text-sm text-gray-600 mb-4">Monitor your portfolio performance and usage</p>
            <button class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
              View Analytics
            </button>
          </div>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center space-x-3 mb-4">
              <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H6a3 3 0 00-3 3v8a3 3 0 003 3z"/>
                </svg>
              </div>
              <h3 class="font-bold text-gray-900">Billing History</h3>
            </div>
            <p class="text-sm text-gray-600 mb-4">Download invoices and manage payment methods</p>
            <button
              phx-click="manage_billing"
              class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
            >
              Manage Billing
            </button>
          </div>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center space-x-3 mb-4">
              <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <h3 class="font-bold text-gray-900">Get Support</h3>
            </div>
            <p class="text-sm text-gray-600 mb-4">Access help center and contact our team</p>
            <button class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
              Get Help
            </button>
          </div>
        </div>

        <!-- Lab Access Highlight -->
        <div class="bg-gradient-to-br from-purple-50 to-indigo-50 rounded-2xl border border-purple-200 p-8">
          <div class="flex items-center space-x-3 mb-6">
            <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
            </svg>
            <h3 class="text-xl font-bold text-purple-900">Lab Access Included</h3>
          </div>
          <p class="text-purple-700 mb-4">
            Experiment with cutting-edge features, AI tools, and beta functionality. All Frestyl plans include full access to our innovation lab.
          </p>
          <.link
            navigate={~p"/lab"}
            class="inline-flex items-center space-x-2 px-6 py-3 bg-purple-600 text-white rounded-xl hover:bg-purple-700 transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            <span>Explore the Lab</span>
          </.link>
        </div>
      </div>

      <!-- Feature Highlights -->
      <div class="space-y-6">
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
          <h3 class="font-bold text-gray-900 mb-4">Maximize Your Plan</h3>

          <div class="space-y-4">
            <%= for feature <- get_available_features(@current_user.subscription_tier) do %>
              <div class={"p-4 rounded-xl border-2 transition-all #{
                if feature.available,
                  do: "border-purple-200 bg-white hover:shadow-md",
                  else: "border-gray-200 bg-gray-50"
              }"}>
                <div class={"w-8 h-8 rounded-lg flex items-center justify-center mb-3 #{
                  if feature.available,
                    do: "bg-purple-100 text-purple-600",
                    else: "bg-gray-100 text-gray-400"
                }"}>
                  <%= raw(feature.icon) %>
                </div>
                <h4 class={"font-medium mb-1 #{if feature.available, do: "text-gray-900", else: "text-gray-500"}"}>
                  <%= feature.title %>
                </h4>
                <p class={"text-sm #{if feature.available, do: "text-gray-600", else: "text-gray-400"}"}>
                  <%= feature.description %>
                </p>
                <%= unless feature.available do %>
                  <button
                    phx-click="show_upgrade_modal"
                    class="mt-3 text-xs text-purple-600 hover:text-purple-700 font-medium"
                  >
                    Upgrade to unlock
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_usage_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Usage Overview -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for {key, data} <- [
          {:portfolios, %{label: "Portfolios", icon: "briefcase"}},
          {:storage, %{label: "Storage", icon: "database", unit: "GB"}},
          {:custom_domains, %{label: "Custom Domains", icon: "globe"}},
          {:monthly_views, %{label: "Monthly Views", icon: "eye"}},
          {:video_intros, %{label: "Video Intros", icon: "video"}}
        ] do %>
          <% usage = @usage_data[key] %>
          <% percentage = get_usage_percentage(usage.used, usage.limit) %>
          <% color = get_usage_color(usage.used, usage.limit) %>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                  <%= case data.icon do %>
                    <% "briefcase" -> %>
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2h8a2 2 0 012-2z"/>
                      </svg>
                    <% "database" -> %>
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"/>
                      </svg>
                    <% "globe" -> %>
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
                      </svg>
                    <% "eye" -> %>
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      </svg>
                    <% "video" -> %>
                      <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                      </svg>
                  <% end %>
                </div>
                <h3 class="font-bold text-gray-900"><%= data.label %></h3>
              </div>
              <%= if usage.limit != :unlimited and percentage > 80 do %>
                <svg class="w-5 h-5 text-orange-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
                </svg>
              <% end %>
            </div>

            <div class="space-y-3">
              <div class="flex justify-between items-end">
                <span class="text-2xl font-bold text-gray-900">
                  <%= usage.used %><%= Map.get(data, :unit, "") %>
                </span>
                <span class="text-sm text-gray-500">
                  / <%= format_limit(usage.limit) %><%= Map.get(data, :unit, "") %>
                </span>
              </div>

              <div class="w-full bg-gray-200 rounded-full h-2">
                <div
                  class={"h-2 rounded-full transition-all duration-300 #{color}"}
                  style={"width: #{percentage}%"}
                ></div>
              </div>

              <%= if usage.limit != :unlimited and percentage > 80 do %>
                <div class="text-xs text-orange-600 font-medium">
                  <%= if percentage > 95, do: "Limit nearly reached", else: "Approaching limit" %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Upgrade Prompt for Storyteller -->
      <%= if @current_user.subscription_tier == "storyteller" do %>
        <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl p-8 text-white">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-2xl font-bold mb-2">Ready to go unlimited?</h3>
              <p class="text-purple-100 mb-4">
                You're using <%= @usage_data.portfolios.used %> of <%= @usage_data.portfolios.limit %> portfolios.
                Upgrade to create unlimited portfolios and unlock premium features.
              </p>
            </div>
            <button
              phx-click="show_upgrade_modal"
              class="px-8 py-4 bg-white text-purple-600 rounded-xl font-bold hover:shadow-lg transition-all"
            >
              Upgrade Now
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_features_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Features Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for feature <- get_all_features() do %>
          <% available = is_feature_available?(feature.id, @current_user.subscription_tier) %>

          <div class={"rounded-2xl border-2 p-6 transition-all hover:shadow-lg #{
            if available,
              do: "border-gray-200 bg-white hover:border-purple-300",
              else: "border-gray-200 bg-gray-50"
          }"}>
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1">
                <div class="flex items-center space-x-2 mb-2">
                  <h3 class={"font-bold #{if available, do: "text-gray-900", else: "text-gray-500"}"}>
                    <%= feature.title %>
                  </h3>
                  <%= if feature.popular do %>
                    <span class="px-2 py-1 bg-purple-100 text-purple-700 rounded-lg text-xs font-medium">
                      Popular
                    </span>
                  <% end %>
                </div>
                <p class={"text-sm #{if available, do: "text-gray-600", else: "text-gray-400"}"}>
                  <%= feature.description %>
                </p>
              </div>

              <%= unless available do %>
                <svg class="w-5 h-5 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 3l14 0 0 11c0 6-4 9-7 9s-7-3-7-9l0-11z"/>
                </svg>
              <% end %>
            </div>

            <%= if available do %>
              <div class="space-y-3">
                <div class="flex items-center justify-between text-sm">
                  <span class="text-purple-600 font-medium"><%= feature.benefit %></span>
                  <span class="text-gray-500"><%= feature.tutorial %></span>
                </div>

                <div class="flex space-x-2">
                  <button class="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-sm">
                    Get Started
                  </button>
                  <button class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors text-sm">
                    Learn More
                  </button>
                </div>
              </div>
            <% else %>
              <div class="space-y-3">
                <div class="text-sm text-gray-500">
                  <%= feature.benefit %> • Available on <%= feature.required_plan %> plan
                </div>

                <button
                  phx-click="show_upgrade_modal"
                  class="w-full px-4 py-2 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-lg hover:shadow-lg transition-all text-sm"
                >
                  Upgrade to Unlock
                </button>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_billing_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Current Subscription -->
      <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-8">
        <h3 class="text-xl font-bold text-gray-900 mb-6">Current Subscription</h3>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
          <div>
            <div class="text-sm font-medium text-gray-500 mb-1">Plan</div>
            <div class="text-2xl font-bold text-gray-900">
              <%= get_plan_data()[@current_user.subscription_tier].name %>
            </div>
          </div>

          <div>
            <div class="text-sm font-medium text-gray-500 mb-1">Monthly Cost</div>
            <div class="text-2xl font-bold text-gray-900">
              $<%= get_plan_data()[@current_user.subscription_tier].price %>
            </div>
          </div>

          <div>
            <div class="text-sm font-medium text-gray-500 mb-1">Next Billing Date</div>
            <div class="text-2xl font-bold text-gray-900">
              <%= if @current_user.subscription_tier == "storyteller", do: "-", else: "Mar 15, 2024" %>
            </div>
          </div>
        </div>

        <%= if @current_user.subscription_tier != "storyteller" do %>
          <div class="mt-6 flex space-x-4">
            <button
              phx-click="show_upgrade_modal"
              class="px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl hover:shadow-lg transition-all"
            >
              Change Plan
            </button>
            <button class="px-6 py-3 border border-gray-300 text-gray-700 rounded-xl hover:bg-gray-50 transition-colors">
              Cancel Subscription
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_upgrade_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" phx-click="close_upgrade_modal">
      <div class="bg-white rounded-2xl shadow-xl max-w-4xl w-full max-h-[90vh] overflow-y-auto" phx-click={JS.stop_propagation()}>
        <!-- Header -->
        <div class="p-6 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-2xl font-bold text-gray-900">Upgrade Your Plan</h3>
              <p class="text-gray-600">Unlock powerful features to enhance your portfolio</p>
            </div>
            <button
              phx-click="close_upgrade_modal"
              class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center hover:bg-gray-200 transition-colors"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Plans -->
        <div class="p-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <%= for {plan_id, plan} <- get_upgrade_plans(@current_user.subscription_tier) do %>
              <div class={"relative p-8 border-2 rounded-2xl transition-all #{
                if plan.popular,
                  do: "border-purple-500 bg-purple-50",
                  else: "border-gray-200 hover:border-purple-300"
              }"}>
                <%= if plan.popular do %>
                  <div class="absolute -top-3 left-1/2 transform -translate-x-1/2">
                    <span class="bg-purple-600 text-white px-4 py-1 rounded-full text-sm font-bold">
                      Most Popular
                    </span>
                  </div>
                <% end %>

                <div class="text-center mb-6">
                  <h4 class="text-2xl font-bold text-gray-900 mb-2"><%= plan.name %></h4>
                  <div class="text-4xl font-black text-purple-600 mb-2">
                    $<%= plan.price %>
                    <span class="text-lg text-gray-500">/month</span>
                  </div>
                  <p class="text-gray-600"><%= plan.description %></p>
                </div>

                <ul class="space-y-3 mb-8">
                  <%= for feature <- plan.features do %>
                    <li class="flex items-center space-x-3">
                      <svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <span class="text-gray-700"><%= feature %></span>
                    </li>
                  <% end %>
                </ul>

                <button
                  phx-click="upgrade_plan"
                  phx-value-plan={plan_id}
                  class={"w-full py-4 rounded-xl font-bold transition-all #{
                    if plan.popular,
                      do: "bg-purple-600 text-white hover:bg-purple-700 hover:shadow-lg",
                      else: "border-2 border-purple-600 text-purple-600 hover:bg-purple-50"
                  }"}
                >
                  <%= if @current_user.subscription_tier == "storyteller", do: "Start Free Trial", else: "Upgrade to #{plan.name}" %>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp get_upgrade_plans("storyteller") do
    %{
      "professional" => %{
        name: "Professional",
        price: 12,
        description: "Perfect for individuals and freelancers",
        features: [
          "Unlimited portfolios",
          "Premium templates",
          "Custom domains",
          "Advanced analytics",
          "ATS optimization",
          "Video introductions & streaming",
          "Full access to the Lab"
        ],
        popular: true
      },
      "business" => %{
        name: "Business",
        price: 29,
        description: "Ideal for teams and agencies",
        features: [
          "Everything in Professional",
          "Team collaboration",
          "Multi-account management",
          "White-label options",
          "Priority support",
          "Advanced integrations",
          "Unlimited Lab access"
        ],
        popular: false
      }
    }
  end

  defp get_upgrade_plans("professional") do
    %{
      "business" => %{
        name: "Business",
        price: 29,
        description: "Ideal for teams and agencies",
        features: [
          "Everything in Professional",
          "Team collaboration",
          "Multi-account management",
          "White-label options",
          "Priority support",
          "Advanced integrations",
          "Unlimited Lab access"
        ],
        popular: true
      }
    }
  end

  defp get_upgrade_plans("business"), do: %{}

  defp get_available_features(tier) do
    [
      %{
        title: "Video Introductions",
        description: "Add a personal video introduction to make your portfolio stand out",
        available: true,  # Storyteller has basic video
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>)
      },
      %{
        title: "Lab Access",
        description: "Experiment with cutting-edge features and AI tools",
        available: true,  # All plans have Lab access
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/></svg>)
      },
      %{
        title: "Custom Domains",
        description: "Use your own domain for professional branding",
        available: tier != "storyteller",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>)
      },
      %{
        title: "Advanced Analytics",
        description: "Track detailed performance metrics and visitor insights",
        available: tier != "storyteller",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>)
      },
      %{
        title: "Team Collaboration",
        description: "Work with your team on portfolios and projects",
        available: tier == "business",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/></svg>)
      },
      %{
        title: "ATS Optimization",
        description: "Make your portfolio recruiter-friendly",
        available: tier != "storyteller",
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)
      }
    ]
  end

  defp get_all_features do
    [
      %{
        id: "video-intro",
        title: "Video Introductions",
        description: "Add a personal video introduction to make your portfolio stand out",
        popular: true,
        tutorial: "Watch 2-min tutorial",
        benefit: "Increase engagement by 40%",
        required_plan: "Professional"
      },
      %{
        id: "lab-access",
        title: "Lab Access",
        description: "Experiment with cutting-edge features, AI tools, and beta functionality",
        popular: true,
        tutorial: "Explore the Lab",
        benefit: "Access to latest innovations",
        required_plan: "All plans"
      },
      %{
        id: "ats-optimization",
        title: "ATS Optimization",
        description: "Make your portfolio searchable and recruiter-friendly",
        popular: false,
        tutorial: "Learn ATS best practices",
        benefit: "Improve discoverability",
        required_plan: "Professional"
      },
      %{
        id: "custom-domain",
        title: "Custom Domains",
        description: "Use your own domain for professional branding",
        popular: true,
        tutorial: "Setup guide",
        benefit: "Professional presence",
        required_plan: "Professional"
      },
      %{
        id: "team-collaboration",
        title: "Team Collaboration",
        description: "Work with your team on portfolios and projects",
        popular: false,
        tutorial: "Team setup guide",
        benefit: "Streamline workflows",
        required_plan: "Business"
      },
      %{
        id: "advanced-analytics",
        title: "Advanced Analytics",
        description: "Track detailed performance metrics and visitor insights",
        popular: true,
        tutorial: "Analytics overview",
        benefit: "Data-driven optimization",
        required_plan: "Professional"
      }
    ]
  end

  defp is_feature_available?("lab-access", _tier), do: true  # All plans have Lab access
  defp is_feature_available?("video-intro", "storyteller"), do: true  # Basic video for Storyteller
  defp is_feature_available?(_feature, "storyteller"), do: false
  defp is_feature_available?("team-collaboration", tier), do: tier == "business"
  defp is_feature_available?(_feature, tier) when tier in ["professional", "business"], do: true
  defp is_feature_available?(_feature, _tier), do: false

  defp get_available_features(tier) do
    # This function is called but truncated in your code
    # The implementation I provided is complete
  end

  defp get_all_features do
    # This function is also called but incomplete
    # The implementation should match what I provided
  end

  defp is_feature_available?(feature_id, tier) do
    # This function needs the complete implementation
  end
end
