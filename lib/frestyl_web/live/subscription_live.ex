# lib/frestyl_web/live/subscription_live.ex - PART 1
defmodule FrestylWeb.SubscriptionLive do
  use FrestylWeb, :live_view

  alias Frestyl.Accounts
  alias Frestyl.Portfolios
  alias Frestyl.Billing
  alias Frestyl.Billing.StripeService

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    limits = Portfolios.get_portfolio_limits(user)
    usage_data = get_usage_data(user)

    # Enhanced subscription analytics
    current_subscription = safe_get_subscription(user.id)
    subscription_analytics = safe_get_analytics(user.id)
    upgrade_suggestions = safe_get_suggestions(user)
    pricing_tiers = get_pricing_tiers()

    {:ok,
    socket
    |> assign(:page_title, "Subscription")
    |> assign(:active_tab, "overview")
    |> assign(:limits, limits)
    |> assign(:usage_data, usage_data)
    |> assign(:show_upgrade_modal, false)
    |> assign(:current_subscription, current_subscription)
    |> assign(:subscription_analytics, subscription_analytics)
    |> assign(:upgrade_suggestions, upgrade_suggestions)
    |> assign(:pricing_tiers, pricing_tiers)
    |> assign(:loading_upgrade, false)
    |> assign(:show_cancel_modal, false)
    |> assign(:stripe_public_key, Application.get_env(:frestyl, :stripe)[:public_key] || "")}
  end

  # Add these helper functions at the bottom of your module
  defp safe_get_subscription(user_id) do
    try do
      Billing.get_user_subscription(user_id)
    rescue
      _ -> nil
    end
  end

  defp safe_get_analytics(user_id) do
    try do
      Portfolios.get_subscription_analytics(user_id)
    rescue
      _ -> %{}
    end
  end

  defp safe_get_suggestions(user) do
    try do
      Portfolios.get_upgrade_suggestions(user)
    rescue
      _ -> []
    end
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

  # Enhanced Stripe-based upgrade handler
  @impl true
  def handle_event("upgrade_plan", %{"plan" => plan}, socket) do
    user = socket.assigns.current_user
    socket = assign(socket, loading_upgrade: true)

    case StripeService.create_checkout_session(user, plan) do
      {:ok, session} ->
        {:noreply,
         socket
         |> assign(loading_upgrade: false)
         |> push_event("redirect_to_stripe", %{url: session.url})}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(loading_upgrade: false)
         |> put_flash(:error, "Failed to start upgrade process: #{reason}")}
    end
  rescue
    _ ->
      # Fallback to legacy upgrade
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

  # Subscription cancellation
  @impl true
  def handle_event("show_cancel_modal", _params, socket) do
    {:noreply, assign(socket, show_cancel_modal: true)}
  end

  @impl true
  def handle_event("hide_cancel_modal", _params, socket) do
    {:noreply, assign(socket, show_cancel_modal: false)}
  end

  @impl true
  def handle_event("cancel_subscription", _params, socket) do
    user = socket.assigns.current_user

    case Billing.cancel_subscription(user.id) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(show_cancel_modal: false)
         |> put_flash(:info, "Your subscription has been cancelled.")
         |> push_navigate(to: "/portfolios")}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(show_cancel_modal: false)
         |> put_flash(:error, "Failed to cancel subscription: #{reason}")}
    end
  rescue
    _ ->
      {:noreply,
       socket
       |> assign(show_cancel_modal: false)
       |> put_flash(:error, "Failed to cancel subscription. Please try again.")}
  end

  @impl true
  def handle_event("manage_billing", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/billing")}
  end

  defp get_pricing_tiers do
    %{
      "free" => %{
        name: "Free",
        price: "Free",
        price_cents: 0,
        billing_interval: nil,
        color: "from-gray-600 to-gray-800",
        features: [
          "2 portfolios maximum",
          "Video recording",
          "Collaboration features",
          "Stats visibility",
          "50MB file uploads",
          "Public sharing"
        ],
        limitations: [
          "No custom domains",
          "No advanced analytics",
          "No ATS optimization",
          "No custom themes"
        ]
      },
      "basic" => %{
        name: "Basic",
        price: "$9",
        price_cents: 900,
        billing_interval: "month",
        color: "from-blue-600 to-indigo-600",
        stripe_price_id: Application.get_env(:frestyl, :stripe)[:basic_price_id],
        features: [
          "5 portfolios",
          "Advanced analytics",
          "Custom themes",
          "Video recording",
          "Collaboration features",
          "200MB file uploads"
        ],
        limitations: [
          "No custom domains",
          "No ATS optimization"
        ]
      },
      "premium" => %{
        name: "Premium",
        price: "$19",
        price_cents: 1900,
        billing_interval: "month",
        color: "from-purple-600 to-pink-600",
        stripe_price_id: Application.get_env(:frestyl, :stripe)[:premium_price_id],
        features: [
          "15 portfolios",
          "Custom domains",
          "Advanced analytics",
          "Custom themes",
          "ATS optimization",
          "500MB file uploads",
          "Priority support"
        ],
        limitations: [],
        popular: true
      },
      "pro" => %{
        name: "Pro",
        price: "$39",
        price_cents: 3900,
        billing_interval: "month",
        color: "from-emerald-600 to-teal-600",
        stripe_price_id: Application.get_env(:frestyl, :stripe)[:pro_price_id],
        features: [
          "Unlimited portfolios",
          "Custom domains",
          "Advanced analytics",
          "Custom themes",
          "ATS optimization",
          "1GB file uploads",
          "Priority support",
          "White-label options"
        ],
        limitations: []
      }
    }
  end

  defp get_usage_data(user) do
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)

    %{
      portfolios: %{used: length(portfolios), limit: limits.max_portfolios},
      storage: %{used: 2.3, limit: get_storage_limit_from_limits(limits)},
      custom_domains: %{used: count_user_custom_domains(user.id), limit: get_domain_limit_from_limits(limits)},
      monthly_views: %{used: 1247, limit: :unlimited},
      video_recording: %{enabled: limits.video_recording},
      collaboration: %{enabled: limits.collaboration_features},
      analytics: %{enabled: limits.advanced_analytics},
      ats_optimization: %{enabled: limits.ats_optimization}
    }
  end

  # Helper functions to work with your limits structure
  defp get_storage_limit_from_limits(limits) do
    case limits.max_media_size_mb do
      50 -> 1    # Free tier gets 1GB total storage
      200 -> 5   # Basic tier gets 5GB total storage
      500 -> 15  # Premium tier gets 15GB total storage
      1000 -> 50 # Pro tier gets 50GB total storage
      _ -> 1
    end
  end

  defp get_domain_limit_from_limits(limits) do
    if limits.custom_domain do
      case limits.max_portfolios do
        15 -> 3      # Premium: 3 domains
        -1 -> :unlimited  # Pro: unlimited domains
        _ -> 1       # Fallback: 1 domain
      end
    else
      0
    end
  end

  defp count_user_custom_domains(user_id) do
    # Placeholder - implement with proper Ecto queries when custom domains are added
    0
  end

  defp upgrade_user_plan(user, plan) do
    Accounts.update_user(user, %{"subscription_tier" => plan})
  end

  defp get_plan_data do
    get_pricing_tiers()
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

  defp get_feature_comparison do
    [
      {"Portfolios", ["2", "5", "15", "Unlimited"]},
      {"Custom Domains", ["❌", "❌", "✅", "✅"]},
      {"Advanced Analytics", ["❌", "✅", "✅", "✅"]},
      {"Custom Themes", ["❌", "✅", "✅", "✅"]},
      {"ATS Optimization", ["❌", "❌", "✅", "✅"]},
      {"File Upload Size", ["50MB", "200MB", "500MB", "1GB"]},
      {"Video Recording", ["✅", "✅", "✅", "✅"]},
      {"Collaboration", ["✅", "✅", "✅", "✅"]},
      {"Priority Support", ["❌", "❌", "✅", "✅"]}
    ]
  end

  # Helper function to get available upgrade tiers based on current tier
  defp get_available_upgrade_tiers(current_tier) do
    all_tiers = get_pricing_tiers()

    case current_tier do
      "free" ->
        Map.take(all_tiers, ["basic", "premium", "pro"])
      "basic" ->
        Map.take(all_tiers, ["premium", "pro"])
      "premium" ->
        Map.take(all_tiers, ["pro"])
      "pro" ->
        %{}
      _ ->
        Map.take(all_tiers, ["basic", "premium", "pro"])
    end
  end

  defp get_available_features(tier) do
    [
      %{
        title: "Video Recording",
        description: "Record and add video introductions to your portfolios",
        available: true,
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>)
      },
      %{
        title: "Collaboration Features",
        description: "Work together with others on your portfolio projects",
        available: true,
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/></svg>)
      },
      %{
        title: "Advanced Analytics",
        description: "Track detailed performance metrics and visitor insights",
        available: tier in ["basic", "premium", "pro"],
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>)
      },
      %{
        title: "Custom Themes",
        description: "Customize your portfolio with premium themes and layouts",
        available: tier in ["basic", "premium", "pro"],
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"/></svg>)
      },
      %{
        title: "Custom Domains",
        description: "Use your own domain for professional branding",
        available: tier in ["premium", "pro"],
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>)
      },
      %{
        title: "ATS Optimization",
        description: "Make your portfolio searchable and recruiter-friendly",
        available: tier in ["premium", "pro"],
        icon: ~s(<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>)
      }
    ]
  end

  defp get_all_features do
    [
      %{
        id: "video-recording",
        title: "Video Recording",
        description: "Record and add video introductions to make your portfolio stand out",
        popular: true,
        tutorial: "Watch 2-min tutorial",
        benefit: "Increase engagement by 40%",
        required_plan: "All plans"
      },
      %{
        id: "collaboration",
        title: "Collaboration Features",
        description: "Work together with others on portfolio projects",
        popular: true,
        tutorial: "Collaboration guide",
        benefit: "Team productivity",
        required_plan: "All plans"
      },
      %{
        id: "advanced-analytics",
        title: "Advanced Analytics",
        description: "Track detailed performance metrics and visitor insights",
        popular: true,
        tutorial: "Analytics overview",
        benefit: "Data-driven optimization",
        required_plan: "Basic"
      },
      %{
        id: "custom-themes",
        title: "Custom Themes",
        description: "Customize your portfolio with premium themes and layouts",
        popular: false,
        tutorial: "Theme customization",
        benefit: "Professional appearance",
        required_plan: "Basic"
      },
      %{
        id: "custom-domain",
        title: "Custom Domains",
        description: "Use your own domain for professional branding",
        popular: true,
        tutorial: "Domain setup guide",
        benefit: "Professional presence",
        required_plan: "Premium"
      },
      %{
        id: "ats-optimization",
        title: "ATS Optimization",
        description: "Make your portfolio searchable and recruiter-friendly",
        popular: false,
        tutorial: "Learn ATS best practices",
        benefit: "Improve discoverability",
        required_plan: "Premium"
      }
    ]
  end

  defp is_feature_available?("video-recording", _tier), do: true
  defp is_feature_available?("collaboration", _tier), do: true
  defp is_feature_available?("advanced-analytics", tier), do: tier in ["basic", "premium", "pro"]
  defp is_feature_available?("custom-themes", tier), do: tier in ["basic", "premium", "pro"]
  defp is_feature_available?("custom-domain", tier), do: tier in ["premium", "pro"]
  defp is_feature_available?("ats-optimization", tier), do: tier in ["premium", "pro"]
  defp is_feature_available?(_feature, _tier), do: false

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

        <!-- Upgrade Suggestions Banner -->
        <%= if length(@upgrade_suggestions || []) > 0 do %>
          <div class="mb-8">
            <%= for suggestion <- @upgrade_suggestions do %>
              <div class="bg-gradient-to-r from-purple-50 to-pink-50 border border-purple-200 rounded-xl p-4 mb-4">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <div class="w-8 h-8 bg-purple-100 rounded-full flex items-center justify-center mr-3">
                      <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                      </svg>
                    </div>
                    <div>
                      <h4 class="font-medium text-gray-900"><%= suggestion.title %></h4>
                      <p class="text-sm text-gray-600"><%= suggestion.message %></p>
                    </div>
                  </div>
                  <button
                    phx-click="show_upgrade_modal"
                    class="px-4 py-2 bg-purple-600 hover:bg-purple-700 text-white text-sm font-medium rounded-lg transition-colors">
                    <%= suggestion.action %>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>

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
                    <%= get_plan_data()[@current_user.subscription_tier].price %>
                    <%= if get_plan_data()[@current_user.subscription_tier].billing_interval do %>
                      /<%= get_plan_data()[@current_user.subscription_tier].billing_interval %> • Billed monthly
                    <% end %>
                  </p>
                </div>
              </div>

              <div class="flex items-center space-x-3">
                <%= if @current_user.subscription_tier != "pro" do %>
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

                <%= if @current_user.subscription_tier != "free" do %>
                  <button
                    phx-click="show_cancel_modal"
                    class="text-red-600 hover:text-red-700 text-sm font-medium px-4 py-2 border border-red-200 rounded-lg hover:bg-red-50 transition-colors">
                    Cancel Subscription
                  </button>
                <% end %>
              </div>
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

        <!-- Enhanced Upgrade Modal -->
        <%= if @show_upgrade_modal do %>
          <%= render_enhanced_upgrade_modal(assigns) %>
        <% end %>

        <!-- Cancel Subscription Modal -->
        <%= if @show_cancel_modal do %>
          <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50">
            <div class="bg-white rounded-xl shadow-2xl max-w-md w-full mx-4">
              <div class="p-6">
                <div class="flex items-center mb-4">
                  <div class="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center mr-4">
                    <svg class="w-6 h-6 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z"/>
                    </svg>
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900">Cancel Subscription</h3>
                </div>

                <p class="text-gray-600 mb-6">
                  Are you sure you want to cancel your subscription? You'll lose access to premium features at the end of your billing cycle.
                </p>

                <div class="flex space-x-3">
                  <button
                    phx-click="hide_cancel_modal"
                    class="flex-1 bg-gray-200 hover:bg-gray-300 text-gray-700 font-medium py-2 px-4 rounded-lg transition-colors">
                    Keep Subscription
                  </button>
                  <button
                    phx-click="cancel_subscription"
                    class="flex-1 bg-red-600 hover:bg-red-700 text-white font-medium py-2 px-4 rounded-lg transition-colors">
                    Cancel Subscription
                  </button>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Stripe Redirect Script -->
      <script>
        window.addEventListener('phx:redirect_to_stripe', (e) => {
          window.location.href = e.detail.url;
        });
      </script>
    </div>
    """
  end

  # Enhanced upgrade modal with tier-specific logic
  defp render_enhanced_upgrade_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4" phx-click="close_upgrade_modal">
      <div class="bg-white rounded-2xl shadow-xl max-w-5xl w-full max-h-[90vh] overflow-y-auto" phx-click={JS.stop_propagation()}>
        <!-- Header -->
        <div class="p-6 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-2xl font-bold text-gray-900">Choose Your Plan</h3>
              <p class="text-gray-600">Unlock your creative potential with the right plan for your needs</p>
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

        <!-- Pricing Cards -->
        <div class="p-6">
          <%= if @current_user.subscription_tier == "pro" do %>
            <!-- Pro user - show congratulations message -->
            <div class="text-center p-8">
              <div class="w-20 h-20 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-6">
                <svg class="w-10 h-10 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
              </div>

              <h3 class="text-2xl font-bold text-gray-900 mb-2">All Features Unlocked!</h3>
              <p class="text-gray-600 mb-6">You have access to all Frestyl features</p>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 max-w-lg mx-auto">
                <div class="p-4 bg-green-50 rounded-lg border border-green-200">
                  <h4 class="font-semibold text-green-900 mb-2">✅ Unlimited Portfolios</h4>
                  <p class="text-sm text-green-700">Create as many portfolios as you need</p>
                </div>
                <div class="p-4 bg-green-50 rounded-lg border border-green-200">
                  <h4 class="font-semibold text-green-900 mb-2">✅ Custom Domains</h4>
                  <p class="text-sm text-green-700">Professional branded URLs</p>
                </div>
                <div class="p-4 bg-green-50 rounded-lg border border-green-200">
                  <h4 class="font-semibold text-green-900 mb-2">✅ Advanced Analytics</h4>
                  <p class="text-sm text-green-700">Detailed performance insights</p>
                </div>
                <div class="p-4 bg-green-50 rounded-lg border border-green-200">
                  <h4 class="font-semibold text-green-900 mb-2">✅ ATS Optimization</h4>
                  <p class="text-sm text-green-700">Recruiter-friendly portfolios</p>
                </div>
              </div>

              <div class="mt-6">
                <p class="text-gray-600 mb-4">Thank you for being a Pro subscriber!</p>
                <button
                  phx-click="close_upgrade_modal"
                  class="px-6 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
                  Continue Using Pro
                </button>
              </div>
            </div>
          <% else %>
            <!-- Show upgrade options for other users -->
            <div class={"grid grid-cols-1 md:grid-cols-#{case map_size(get_available_upgrade_tiers(@current_user.subscription_tier)) do
              1 -> "1"
              2 -> "2"
              _ -> "3"
            end} gap-6"}>
              <%= for {tier_key, tier} <- get_available_upgrade_tiers(@current_user.subscription_tier) do %>
                <div class={[
                  "relative bg-white rounded-2xl shadow-sm border-2 transition-all duration-300 hover:shadow-lg p-6",
                  if(Map.get(tier, :popular), do: "border-purple-500 ring-2 ring-purple-200", else: "border-gray-200 hover:border-purple-300")
                ]}>
                  <%= if Map.get(tier, :popular) do %>
                    <div class="absolute -top-4 left-1/2 transform -translate-x-1/2">
                      <span class="bg-gradient-to-r from-purple-600 to-pink-600 text-white px-4 py-1 rounded-full text-sm font-medium">
                        Most Popular
                      </span>
                    </div>
                  <% end %>

                  <!-- Plan Header -->
                  <div class="text-center mb-6">
                    <h3 class="text-2xl font-bold text-gray-900 mb-2"><%= tier.name %></h3>
                    <div class="flex items-baseline justify-center">
                      <span class="text-4xl font-black text-gray-900"><%= tier.price %></span>
                      <%= if tier.billing_interval do %>
                        <span class="text-gray-500 ml-1">/<%= tier.billing_interval %></span>
                      <% end %>
                    </div>
                  </div>

                  <!-- Features -->
                  <ul class="space-y-3 mb-8">
                    <%= for feature <- tier.features do %>
                      <li class="flex items-start">
                        <svg class="h-5 w-5 text-green-500 mt-0.5 mr-3 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                        <span class="text-gray-700"><%= feature %></span>
                      </li>
                    <% end %>
                  </ul>

                  <!-- Action Button -->
                  <div class="text-center">
                    <button
                      phx-click="upgrade_plan"
                      phx-value-plan={tier_key}
                      disabled={@loading_upgrade}
                      class={[
                        "w-full font-bold py-3 px-6 rounded-xl transition-all duration-300",
                        if(Map.get(tier, :popular),
                          do: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white transform hover:scale-105",
                          else: "bg-gray-900 hover:bg-gray-800 text-white")
                      ]}>
                      <%= if @loading_upgrade do %>
                        <div class="flex items-center justify-center">
                          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" fill="none" viewBox="0 0 24 24">
                            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                          </svg>
                          Processing...
                        </div>
                      <% else %>
                        Upgrade to <%= tier.name %>
                      <% end %>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Feature Comparison Table -->
          <%= unless @current_user.subscription_tier == "pro" do %>
            <div class="mt-8 bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
              <div class="px-6 py-4 border-b border-gray-200">
                <h3 class="text-lg font-semibold text-gray-900">Feature Comparison</h3>
              </div>

              <div class="overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                  <thead class="bg-gray-50">
                    <tr>
                      <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Feature</th>
                      <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Free</th>
                      <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Basic</th>
                      <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Premium</th>
                      <th class="px-6 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Pro</th>
                    </tr>
                  </thead>
                  <tbody class="bg-white divide-y divide-gray-200">
                    <%= for {feature, values} <- get_feature_comparison() do %>
                      <tr>
                        <td class="px-6 py-4 whitespace-nowrap text-sm font-medium text-gray-900"><%= feature %></td>
                        <%= for value <- values do %>
                          <td class="px-6 py-4 whitespace-nowrap text-center text-sm text-gray-900"><%= value %></td>
                        <% end %>
                      </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Render tab functions
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
            <button phx-click="change_tab" phx-value-tab="usage" class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
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
            <button phx-click="manage_billing" class="w-full px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
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

        <!-- Video Recording Highlight -->
        <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl border border-blue-200 p-8">
          <div class="flex items-center space-x-3 mb-6">
            <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <h3 class="text-xl font-bold text-blue-900">Video Recording Included</h3>
          </div>
          <p class="text-blue-700 mb-4">
            Create engaging video introductions for your portfolios. All Frestyl plans include video recording capabilities.
          </p>
          <.link navigate={~p"/portfolios"} class="inline-flex items-center space-x-2 px-6 py-3 bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            <span>Create Videos</span>
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
                  do: "border-blue-200 bg-white hover:shadow-md",
                  else: "border-gray-200 bg-gray-50"
              }"}>
                <div class={"w-8 h-8 rounded-lg flex items-center justify-center mb-3 #{
                  if feature.available,
                    do: "bg-blue-100 text-blue-600",
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
        <!-- Portfolios Usage -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
              <h3 class="font-bold text-gray-900">Portfolios</h3>
            </div>
          </div>

          <div class="space-y-3">
            <div class="flex justify-between items-end">
              <span class="text-2xl font-bold text-gray-900">
                <%= @usage_data.portfolios.used %>
              </span>
              <span class="text-sm text-gray-500">
                / <%= format_limit(@usage_data.portfolios.limit) %>
              </span>
            </div>

            <%= unless @usage_data.portfolios.limit == :unlimited do %>
              <div class="w-full bg-gray-200 rounded-full h-2">
                <div
                  class={"h-2 rounded-full transition-all duration-300 #{get_usage_color(@usage_data.portfolios.used, @usage_data.portfolios.limit)}"}
                  style={"width: #{get_usage_percentage(@usage_data.portfolios.used, @usage_data.portfolios.limit)}%"}
                ></div>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Storage Usage -->
        <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
          <div class="flex items-center justify-between mb-4">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4"/>
                </svg>
              </div>
              <h3 class="font-bold text-gray-900">Storage</h3>
            </div>
          </div>

          <div class="space-y-3">
            <div class="flex justify-between items-end">
              <span class="text-2xl font-bold text-gray-900">
                <%= @usage_data.storage.used %>GB
              </span>
              <span class="text-sm text-gray-500">
                / <%= @usage_data.storage.limit %>GB
              </span>
            </div>

            <div class="w-full bg-gray-200 rounded-full h-2">
              <div
                class={"h-2 rounded-full transition-all duration-300 #{get_usage_color(@usage_data.storage.used, @usage_data.storage.limit)}"}
                style={"width: #{get_usage_percentage(@usage_data.storage.used, @usage_data.storage.limit)}%"}
              ></div>
            </div>
          </div>
        </div>

        <!-- Feature Status Cards -->
        <%= for {feature_key, feature_data} <- [
          {:video_recording, %{title: "Video Recording", icon: "video"}},
          {:collaboration, %{title: "Collaboration", icon: "users"}},
          {:analytics, %{title: "Advanced Analytics", icon: "chart"}},
          {:ats_optimization, %{title: "ATS Optimization", icon: "search"}}
        ] do %>
          <% enabled = Map.get(@usage_data[feature_key] || %{}, :enabled, false) %>

          <div class="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center space-x-3">
                <div class={"w-10 h-10 rounded-lg flex items-center justify-center #{
                  if enabled, do: "bg-green-100", else: "bg-gray-100"
                }"}>
                  <%= case feature_data.icon do %>
                    <% "video" -> %>
                      <svg class={"w-5 h-5 #{if enabled, do: "text-green-600", else: "text-gray-400"}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                      </svg>
                    <% "users" -> %>
                      <svg class={"w-5 h-5 #{if enabled, do: "text-green-600", else: "text-gray-400"}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                      </svg>
                    <% "chart" -> %>
                      <svg class={"w-5 h-5 #{if enabled, do: "text-green-600", else: "text-gray-400"}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                      </svg>
                    <% "search" -> %>
                      <svg class={"w-5 h-5 #{if enabled, do: "text-green-600", else: "text-gray-400"}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
                      </svg>
                  <% end %>
                </div>
                <h3 class="font-bold text-gray-900"><%= feature_data.title %></h3>
              </div>

              <%= if enabled do %>
                <span class="text-green-600 text-sm font-medium">Enabled</span>
              <% else %>
                <span class="text-gray-400 text-sm font-medium">Disabled</span>
              <% end %>
            </div>

            <%= unless enabled do %>
              <button
                phx-click="show_upgrade_modal"
                class="w-full text-purple-600 hover:text-purple-700 text-sm font-medium">
                Upgrade to unlock
              </button>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Upgrade Prompt for Free and Basic tiers -->
      <%= if @current_user.subscription_tier in ["free", "basic"] do %>
        <div class="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl p-8 text-white">
          <div class="flex items-center justify-between">
            <div>
              <h3 class="text-2xl font-bold mb-2">
               <%= if @current_user.subscription_tier == "free", do: "Ready to upgrade?", else: "Unlock more features" %>
              </h3>
              <p class="text-purple-100 mb-4">
                <%= if @current_user.subscription_tier == "free" do %>
                  You're using <%= @usage_data.portfolios.used %> of <%= @usage_data.portfolios.limit %> portfolios.
                  Upgrade to get more portfolios and unlock premium features.
                <% else %>
                  Get custom domains, ATS optimization, and more with Premium or Pro.
                <% end %>
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
                  <%= if Map.get(feature, :popular) do %>
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
                  <span class="text-purple-600 font-medium"><%= Map.get(feature, :benefit, "Available") %></span>
                  <span class="text-gray-500"><%= Map.get(feature, :tutorial, "Learn more") %></span>
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
                  <%= Map.get(feature, :benefit, "Premium feature") %> • Available on <%= Map.get(feature, :required_plan, "Professional") %> plan
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
              <%= get_plan_data()[@current_user.subscription_tier].price %>
            </div>
          </div>

          <div>
            <div class="text-sm font-medium text-gray-500 mb-1">Next Billing Date</div>
            <div class="text-2xl font-bold text-gray-900">
              <%= if @current_user.subscription_tier == "free", do: "-", else: "Mar 15, 2024" %>
            </div>
          </div>
        </div>

        <%= if @current_user.subscription_tier != "free" do %>
          <div class="mt-6 flex space-x-4">
            <button
              phx-click="show_upgrade_modal"
              class="px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-xl hover:shadow-lg transition-all"
            >
              Change Plan
            </button>
            <button
              phx-click="show_cancel_modal"
              class="px-6 py-3 border border-gray-300 text-gray-700 rounded-xl hover:bg-gray-50 transition-colors">
              Cancel Subscription
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
