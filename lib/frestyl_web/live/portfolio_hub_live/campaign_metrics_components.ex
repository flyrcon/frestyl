# File: lib/frestyl_web/live/portfolio_hub_live/campaign_metrics_components.ex

defmodule FrestylWeb.PortfolioHubLive.CampaignMetricsComponents do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  @doc """
  Real-time campaign metrics dashboard for active campaigns.
  """
  def campaign_metrics_dashboard(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 shadow-sm border">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Campaign Metrics</h3>
        <div class="flex items-center space-x-2">
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse"></div>
          <span class="text-xs text-gray-500">Live</span>
        </div>
      </div>

      <!-- Metrics Grid -->
      <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
        <.metric_card
          label="Active Campaigns"
          value={Map.get(@metrics, :active_campaigns, 0)}
          trend={Map.get(@metrics, :campaign_trend, 0)}
          icon="chart-bar" />

        <.metric_card
          label="Total Revenue"
          value={"$#{format_currency(Map.get(@metrics, :total_revenue, 0))}"}
          trend={Map.get(@metrics, :revenue_trend, 0)}
          icon="currency-dollar" />

        <.metric_card
          label="Avg Quality Score"
          value={Map.get(@metrics, :avg_quality_score, 0)}
          trend={Map.get(@metrics, :quality_trend, 0)}
          icon="star" />

        <.metric_card
          label="Active Reviews"
          value={Map.get(@metrics, :pending_reviews, 0)}
          trend={nil}
          icon="eye" />
      </div>

      <!-- Active Campaigns List -->
      <div class="space-y-3">
        <h4 class="font-medium text-gray-900">Active Campaigns</h4>
        <%= for campaign <- @active_campaigns do %>
          <.campaign_progress_bar campaign={campaign} />
        <% end %>
      </div>
    </div>
    """
  end

  defp metric_card(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-4">
      <div class="flex items-center justify-between">
        <div>
          <p class="text-sm text-gray-600"><%= @label %></p>
          <p class="text-xl font-semibold text-gray-900"><%= @value %></p>
        </div>
        <.icon name={@icon} class="w-6 h-6 text-gray-400" />
      </div>

      <%= if @trend do %>
        <div class={["flex items-center mt-2 text-xs",
          if(@trend >= 0, do: "text-green-600", else: "text-red-600")]}>
          <%= if @trend >= 0 do %>
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M3.293 9.707a1 1 0 010-1.414l6-6a1 1 0 011.414 0l6 6a1 1 0 01-1.414 1.414L10 4.414 4.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
            </svg>
            +<%= abs(@trend) %>%
          <% else %>
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 10.293a1 1 0 010 1.414l-6 6a1 1 0 01-1.414 0l-6-6a1 1 0 111.414-1.414L10 15.586l5.293-5.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            <%= @trend %>%
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp campaign_progress_bar(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-4">
      <div class="flex items-center justify-between mb-2">
        <h5 class="font-medium text-gray-900"><%= @campaign.title %></h5>
        <span class="text-sm text-gray-500">
          <%= get_progress_percentage(@campaign) %>% complete
        </span>
      </div>

      <!-- Progress Bar -->
      <div class="w-full bg-gray-200 rounded-full h-2 mb-3">
        <div class="bg-purple-600 h-2 rounded-full transition-all"
             style={"width: #{get_progress_percentage(@campaign)}%"}></div>
      </div>

      <!-- Campaign Stats -->
      <div class="grid grid-cols-3 gap-4 text-sm">
        <div>
          <span class="text-gray-600">Contributors:</span>
          <span class="font-medium"><%= length(@campaign.contributors || []) %></span>
        </div>
        <div>
          <span class="text-gray-600">Quality:</span>
          <span class="font-medium"><%= get_campaign_quality_score(@campaign) %>/5.0</span>
        </div>
        <div>
          <span class="text-gray-600">Revenue:</span>
          <span class="font-medium">$<%= format_currency(@campaign.projected_revenue || 0) %></span>
        </div>
      </div>

      <!-- Quality Gates Status -->
      <div class="mt-3">
        <.quality_gates_mini_display campaign={@campaign} />
      </div>
    </div>
    """
  end

  defp quality_gates_mini_display(assigns) do
    gates_status = get_campaign_quality_gates_status(assigns.campaign)

    ~H"""
    <div class="flex items-center justify-between">
      <span class="text-xs text-gray-600">Quality Gates:</span>
      <div class="flex space-x-1">
        <%= for gate <- gates_status.gates do %>
          <div class={[
            "w-3 h-3 rounded-full",
            case gate.status do
              :passed -> "bg-green-500"
              :failed -> "bg-red-500"
              :improvement -> "bg-yellow-500"
              _ -> "bg-gray-300"
            end
          ]} title={gate.name}></div>
        <% end %>
      </div>
    </div>
    """
  end

  # Helper functions
  defp get_progress_percentage(campaign) do
    case campaign.current_metrics do
      %{"progress_percentage" => percentage} -> round(percentage)
      _ -> 0
    end
  end

  defp get_campaign_quality_score(campaign) do
    case campaign.current_metrics do
      %{"quality_score" => score} -> Float.round(score, 1)
      _ -> 0.0
    end
  end

  defp get_campaign_quality_gates_status(campaign) do
    case campaign.current_metrics do
      %{"quality_gates_summary" => gates} when is_list(gates) ->
        %{gates: gates}
      _ ->
        %{gates: []}
    end
  end

  def format_currency(amount) when is_number(amount) do
    :erlang.float_to_binary(amount/1, [{:decimals, 0}])
  end
  def format_currency(_), do: "0"
end
