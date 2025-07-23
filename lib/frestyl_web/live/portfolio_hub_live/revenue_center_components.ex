# File: lib/frestyl_web/live/portfolio_hub_live/revenue_center_components.ex

defmodule FrestylWeb.PortfolioHubLive.RevenueCenterComponents do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Enhanced Revenue Center with campaign revenue integration.
  """
  def enhanced_revenue_center(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Revenue Overview Dashboard -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <.revenue_metric_card
          title="Total Revenue"
          value={"$#{format_currency(@revenue_metrics.total_revenue)}"}
          trend={@revenue_metrics.revenue_growth_rate}
          icon="currency-dollar"
          color="green" />

        <.revenue_metric_card
          title="Campaign Revenue"
          value={"$#{format_currency(@revenue_metrics.campaign_revenue)}"}
          trend={@revenue_metrics.campaign_growth_rate}
          icon="users"
          color="purple" />

        <.revenue_metric_card
          title="Active Campaigns"
          value={@revenue_metrics.active_campaigns}
          trend={nil}
          icon="chart-bar"
          color="blue" />

        <.revenue_metric_card
          title="Avg Quality Score"
          value={@revenue_metrics.avg_quality_score}
          trend={format_quality_trend(@revenue_metrics.quality_trend)}
          icon="star"
          color="yellow" />
      </div>

      <!-- Campaign Revenue Breakdown -->
      <div class="bg-white rounded-xl p-6 shadow-sm border">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">Campaign Revenue Breakdown</h3>
          <button class="text-purple-600 hover:text-purple-800 text-sm font-medium">
            View All Campaigns →
          </button>
        </div>

        <%= if length(@campaign_revenues) > 0 do %>
          <div class="space-y-4">
            <%= for campaign_revenue <- @campaign_revenues do %>
              <.campaign_revenue_item campaign={campaign_revenue} />
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <svg class="w-12 h-12 text-gray-300 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
            </svg>
            <p class="text-gray-500">No campaign revenue yet</p>
            <.link navigate={"?tab=content_campaigns"} class="text-purple-600 hover:text-purple-700 font-medium">
              Start your first campaign
            </.link>
          </div>
        <% end %>
      </div>

      <!-- Payment History & Projections -->
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <!-- Recent Payments -->
        <div class="bg-white rounded-xl p-6 shadow-sm border">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Recent Payments</h3>

          <%= if length(@recent_payments) > 0 do %>
            <div class="space-y-3">
              <%= for payment <- @recent_payments do %>
                <.payment_history_item payment={payment} />
              <% end %>
            </div>
          <% else %>
            <div class="text-center py-6">
              <p class="text-gray-500 text-sm">No payments received yet</p>
            </div>
          <% end %>
        </div>

        <!-- Revenue Projections -->
        <div class="bg-white rounded-xl p-6 shadow-sm border">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Revenue Projections</h3>

          <div class="space-y-4">
            <%= for projection <- @revenue_projections do %>
              <.revenue_projection_item projection={projection} />
            <% end %>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-200">
            <div class="flex justify-between items-center">
              <span class="font-medium text-gray-900">Projected Total</span>
              <span class="font-bold text-lg text-green-600">
                $<%= format_currency(@projected_total_revenue) %>
              </span>
            </div>
          </div>
        </div>
      </div>

      <!-- Contract Management -->
      <div class="bg-white rounded-xl p-6 shadow-sm border">
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-lg font-semibold text-gray-900">Contract Management</h3>
          <span class="text-sm text-gray-500">
            <%= length(@pending_contracts) %> contracts pending signature
          </span>
        </div>

        <%= if length(@pending_contracts) > 0 do %>
          <div class="space-y-4">
            <%= for contract <- @pending_contracts do %>
              <.contract_item contract={contract} />
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-6">
            <p class="text-gray-500">All contracts are up to date</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Component helpers
  defp revenue_metric_card(assigns) do
    ~H"""
    <div class={"bg-gradient-to-r #{get_gradient_colors(@color)} rounded-xl p-6 text-white"}>
      <div class="flex items-center justify-between">
        <div>
          <p class="text-white/80 text-sm"><%= @title %></p>
          <p class="text-2xl font-bold"><%= @value %></p>
        </div>
        <.icon name={@icon} class="w-8 h-8 text-white/60" />
      </div>

      <%= if @trend do %>
        <div class="flex items-center mt-2 text-sm text-white/90">
          <%= if @trend >= 0 do %>
            <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3.293 9.707a1 1 0 010-1.414l6-6a1 1 0 011.414 0l6 6a1 1 0 01-1.414 1.414L10 4.414 4.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
            </svg>
            +<%= abs(@trend) %>%
          <% else %>
            <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 10.293a1 1 0 010 1.414l-6 6a1 1 0 01-1.414 0l-6-6a1 1 0 111.414-1.414L10 15.586l5.293-5.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            <%= @trend %>%
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp campaign_revenue_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
      <div class="flex items-center space-x-3">
        <div class={"w-3 h-3 rounded-full #{get_status_color(@campaign.status)}"}>
        </div>
        <div>
          <h4 class="font-medium text-gray-900"><%= @campaign.title %></h4>
          <div class="flex items-center space-x-2 text-sm text-gray-600">
            <span><%= format_content_type(@campaign.content_type) %></span>
            <span>•</span>
            <span><%= @campaign.contributor_count %> contributors</span>
          </div>
        </div>
      </div>

      <div class="text-right">
        <p class="font-semibold text-gray-900">
          $<%= format_currency(@campaign.user_revenue) %>
        </p>
        <p class="text-sm text-gray-500">
          <%= Float.round(@campaign.revenue_percentage, 1) %>% share
        </p>
      </div>
    </div>
    """
  end

  defp payment_history_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2">
      <div class="flex items-center space-x-3">
        <div class="w-2 h-2 bg-green-500 rounded-full"></div>
        <div>
          <p class="text-sm font-medium text-gray-900"><%= @payment.campaign_title %></p>
          <p class="text-xs text-gray-500"><%= format_date(@payment.processed_at) %></p>
        </div>
      </div>
      <span class="font-medium text-green-600">
        +$<%= format_currency(@payment.amount) %>
      </span>
    </div>
    """
  end

  defp revenue_projection_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between py-2">
      <div>
        <p class="text-sm font-medium text-gray-900"><%= @projection.campaign_title %></p>
        <p class="text-xs text-gray-500">
          Expected: <%= format_date(@projection.expected_date) %>
        </p>
      </div>
      <div class="text-right">
        <span class="font-medium text-gray-900">
          $<%= format_currency(@projection.amount) %>
        </span>
        <p class="text-xs text-gray-500">
          <%= Float.round(@projection.confidence, 0) %>% confidence
        </p>
      </div>
    </div>
    """
  end

  defp contract_item(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-4 border border-yellow-200 bg-yellow-50 rounded-lg">
      <div class="flex items-center space-x-3">
        <svg class="w-5 h-5 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        <div>
          <h4 class="font-medium text-gray-900"><%= @contract.campaign_title %></h4>
          <p class="text-sm text-gray-600">
            Revenue Share: <%= Float.round(@contract.revenue_percentage, 1) %>%
          </p>
        </div>
      </div>

      <div class="flex items-center space-x-2">
        <button
          phx-click="view_contract"
          phx-value-contract_id={@contract.id}
          class="px-3 py-1 text-sm text-blue-600 hover:text-blue-800">
          Review
        </button>
        <button
          phx-click="sign_contract"
          phx-value-contract_id={@contract.id}
          class="px-3 py-1 bg-green-600 text-white text-sm rounded hover:bg-green-700">
          Sign Contract
        </button>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_gradient_colors("green"), do: "from-green-500 to-emerald-600"
  defp get_gradient_colors("purple"), do: "from-purple-500 to-pink-600"
  defp get_gradient_colors("blue"), do: "from-blue-500 to-cyan-600"
  defp get_gradient_colors("yellow"), do: "from-yellow-500 to-orange-600"
  defp get_gradient_colors(_), do: "from-gray-500 to-gray-600"

  defp get_status_color("completed"), do: "bg-green-500"
  defp get_status_color("active"), do: "bg-blue-500"
  defp get_status_color("pending"), do: "bg-yellow-500"
  defp get_status_color(_), do: "bg-gray-400"

  defp format_content_type(:data_story), do: "Data Story"
  defp format_content_type(:book), do: "Book"
  defp format_content_type(:podcast), do: "Podcast"
  defp format_content_type(:music_track), do: "Music"
  defp format_content_type(:blog_post), do: "Blog Post"
  defp format_content_type(_), do: "Content"

  defp format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount, [{:decimals, 2}])
  end
  defp format_currency(%Decimal{} = amount) do
    Decimal.to_string(amount, :normal)
  end
  defp format_currency(_), do: "0.00"

  defp format_date(datetime) do
    case datetime do
      %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
      _ -> "TBD"
    end
  end

  defp format_quality_trend(:improving), do: "+0.3"
  defp format_quality_trend(:declining), do: "-0.2"
  defp format_quality_trend(_), do: nil
end
