# File: lib/frestyl_web/live/portfolio_hub_live/content_campaign_components.ex

defmodule FrestylWeb.PortfolioHubLive.ContentCampaignComponents do
  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.LiveView.Helpers

  @doc """
  Renders a content campaign card with metrics and actions.
  """
  def content_campaign_card(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded-xl p-6 hover:shadow-lg transition-all group">
      <!-- Campaign Header -->
      <div class="flex justify-between items-start mb-4">
        <div class="flex-1">
          <div class="flex items-center space-x-2 mb-2">
            <.content_type_icon type={@campaign.content_type} />
            <h3 class="font-bold text-lg text-gray-900 group-hover:text-purple-600 transition-colors">
              <%= @campaign.title %>
            </h3>
          </div>
          <p class="text-gray-600 text-sm line-clamp-2"><%= @campaign.description %></p>
        </div>

        <.campaign_status_badge status={@campaign.status} />
      </div>

      <!-- Progress Metrics -->
      <div class="space-y-3 mb-4">
        <.contribution_progress campaign={@campaign} />
        <.revenue_split_preview campaign={@campaign} current_user={@current_user} />
      </div>

      <!-- Contributors -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center space-x-2">
          <svg class="w-4 h-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
          </svg>
          <span class="text-sm text-gray-600">
            <%= length(@campaign.contributors || []) %>/<%= @campaign.max_contributors %> contributors
          </span>
        </div>

        <%= if @campaign.deadline do %>
          <.time_remaining deadline={@campaign.deadline} />
        <% end %>
      </div>

      <!-- Action Buttons -->
      <div class="flex space-x-2">
        <.link
          navigate={"/campaigns/#{@campaign.id}"}
          class="flex-1 bg-purple-600 text-white text-center px-4 py-2 rounded-lg hover:bg-purple-700 transition-colors text-sm font-medium"
        >
          View Details
        </.link>

        <%= if @campaign.status == :open and not user_joined?(@campaign, @current_user) do %>
          <button
            phx-click="join_campaign"
            phx-value-campaign_id={@campaign.id}
            class="px-4 py-2 border border-purple-600 text-purple-600 rounded-lg hover:bg-purple-50 transition-colors text-sm font-medium"
          >
            Join
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Supporting component functions
  defp content_type_icon(assigns) do
    icon = case assigns.type do
      :data_story -> "📊"
      :book -> "📚"
      :podcast -> "🎙️"
      :music_track -> "🎵"
      :blog_post -> "📝"
      :news_article -> "📰"
      :video_content -> "🎬"
      _ -> "📄"
    end

    ~H"""
    <span class="text-lg"><%= icon %></span>
    """
  end

  def quality_score_badge(assigns) do
    quality_score = get_campaign_quality_score(assigns.campaign)
    {color_class, grade} = get_quality_grade(quality_score)

    ~H"""
    <div class={"px-2 py-1 text-xs rounded-full font-medium #{color_class}"}>
      <%= grade %>
    </div>
    """
  end

  defp quality_gates_progress(assigns) do
    gates_status = get_user_quality_gates_status(assigns.campaign, assigns.current_user)

    ~H"""
    <div>
      <div class="flex justify-between text-xs text-gray-600 mb-1">
        <span>Quality Gates</span>
        <span><%= gates_status.passed %>/<%= gates_status.total %> passed</span>
      </div>
      <div class="flex space-x-1">
        <%= for gate <- gates_status.gates do %>
          <div class={[
            "flex-1 h-2 rounded-full",
            case gate.status do
              :passed -> "bg-green-500"
              :failed -> "bg-red-500"
              :improvement -> "bg-yellow-500"
              _ -> "bg-gray-200"
            end
          ]} title={gate.name}></div>
        <% end %>
      </div>

      <%= if gates_status.improvement_periods > 0 do %>
        <div class="text-xs text-yellow-600 mt-1">
          <%= gates_status.improvement_periods %> improvement period(s) active
        </div>
      <% end %>
    </div>
    """
  end

  def improvement_period_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg p-4 border border-yellow-200">
      <div class="flex justify-between items-start mb-3">
        <div>
          <h4 class="font-medium text-gray-900"><%= @period.improvement_plan.title %></h4>
          <p class="text-sm text-gray-600">Gate: <%= @period.gate_name %></p>
        </div>
        <div class="text-right">
          <span class="text-xs text-yellow-600">
            <%= days_remaining(@period.expires_at) %> days left
          </span>
        </div>
      </div>

      <!-- Progress Tasks -->
      <div class="space-y-2 mb-3">
        <%= for {task, index} <- Enum.with_index(@period.improvement_plan.tasks) do %>
          <div class="flex items-center space-x-2">
            <input type="checkbox"
                  phx-click="complete_improvement_task"
                  phx-value-period_id={@period.id}
                  phx-value-task_index={index}
                  class="rounded text-purple-600" />
            <span class="text-sm text-gray-700"><%= task %></span>
          </div>
        <% end %>
      </div>

      <div class="flex justify-between items-center">
        <span class="text-xs text-gray-500">
          Estimated: <%= @period.improvement_plan.estimated_time %>
        </span>
        <button phx-click="view_improvement_plan"
                phx-value-improvement_period_id={@period.id}
                class="text-xs text-purple-600 hover:text-purple-800">
          View Full Plan →
        </button>
      </div>
    </div>
    """
  end

  def peer_review_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg p-4 border border-blue-200">
      <div class="flex justify-between items-start mb-3">
        <div>
          <h4 class="font-medium text-gray-900">Review Request</h4>
          <p class="text-sm text-gray-600">
            <%= String.capitalize(to_string(@review.submission_type)) %> contribution
          </p>
        </div>
        <span class="text-xs text-blue-600">
          <%= @review.reviewers_needed - length(@review.reviews) %> reviewers needed
        </span>
      </div>

      <p class="text-sm text-gray-700 mb-3"><%= @review.content_preview %></p>

      <div class="flex justify-between items-center">
        <span class="text-xs text-gray-500">
          Requested: <%= time_ago(@review.requested_at) %>
        </span>
        <button phx-click="start_peer_review"
                phx-value-review_request_id={@review.id}
                class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700">
          Start Review
        </button>
      </div>
    </div>
    """
  end

  defp campaign_status_badge(assigns) do
    {color_class, text} = case assigns.status do
      :open -> {"bg-green-100 text-green-800", "Open"}
      :active -> {"bg-blue-100 text-blue-800", "Active"}
      :review -> {"bg-yellow-100 text-yellow-800", "Review"}
      :completed -> {"bg-gray-100 text-gray-800", "Completed"}
      :published -> {"bg-purple-100 text-purple-800", "Published"}
      :cancelled -> {"bg-red-100 text-red-800", "Cancelled"}
      _ -> {"bg-gray-100 text-gray-600", "Draft"}
    end

    ~H"""
    <span class={"px-2 py-1 text-xs rounded-full font-medium #{color_class}"}>
      <%= text %>
    </span>
    """
  end

  defp contribution_progress(assigns) do
    # Calculate progress based on content type
    progress = get_campaign_progress_percentage(assigns.campaign)

    ~H"""
    <div>
      <div class="flex justify-between text-xs text-gray-600 mb-1">
        <span>Progress</span>
        <span><%= progress %>%</span>
      </div>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div class="bg-purple-600 h-2 rounded-full transition-all" style={"width: #{progress}%"}></div>
      </div>
    </div>
    """
  end

  defp revenue_split_preview(assigns) do
    user_percentage = get_user_revenue_percentage(assigns.campaign, assigns.current_user)

    ~H"""
    <%= if user_percentage > 0 do %>
      <div class="text-xs text-gray-600">
        Your current share: <span class="font-medium text-purple-600"><%= user_percentage %>%</span>
      </div>
    <% end %>
    """
  end

  defp time_remaining(assigns) do
    days_left = DateTime.diff(assigns.deadline, DateTime.utc_now(), :day)

    ~H"""
    <div class="text-xs text-gray-500">
      <%= cond do %>
        <% days_left > 7 -> %>
          <%= days_left %> days left
        <% days_left > 0 -> %>
          <span class="text-orange-600 font-medium"><%= days_left %> days left</span>
        <% true -> %>
          <span class="text-red-600 font-medium">Overdue</span>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp user_joined?(campaign, user) do
    Enum.any?(campaign.contributors || [], &(&1.user_id == user.id))
  end

  defp get_campaign_progress_percentage(campaign) do
    # This would calculate based on actual content metrics
    case campaign.current_metrics do
      %{"progress_percentage" => percentage} -> round(percentage)
      _ -> 0
    end
  end

  defp get_user_revenue_percentage(campaign, user) do
    case campaign.revenue_splits do
      %{} = splits when map_size(splits) > 0 ->
        Map.get(splits, to_string(user.id), 0.0) |> round()
      _ -> 0.0
    end
  end

  defp get_campaign_quality_score(campaign) do
    case campaign.current_metrics do
      %{"quality_score" => score} -> score
      _ -> 0.0
    end
  end

  defp get_quality_grade(score) do
    cond do
      score >= 4.5 -> {"bg-green-100 text-green-800", "A+"}
      score >= 4.0 -> {"bg-green-100 text-green-700", "A"}
      score >= 3.5 -> {"bg-blue-100 text-blue-800", "B+"}
      score >= 3.0 -> {"bg-blue-100 text-blue-700", "B"}
      score >= 2.5 -> {"bg-yellow-100 text-yellow-800", "C+"}
      score >= 2.0 -> {"bg-yellow-100 text-yellow-700", "C"}
      score > 0 -> {"bg-red-100 text-red-800", "D"}
      true -> {"bg-gray-100 text-gray-600", "N/A"}
    end
  end

  defp get_user_quality_gates_status(campaign, user) do
    user_id = to_string(user.id)

    # Get quality gates status for user
    case campaign.current_metrics do
      %{"quality_gates" => quality_gates} when is_map(quality_gates) ->
        case Map.get(quality_gates, user_id) do
          gates when is_map(gates) ->
            gates_list = Enum.map(gates, fn {name, status} ->
              %{name: name, status: String.to_atom(status)}
            end)

            passed = Enum.count(gates_list, &(&1.status == :passed))
            improvement = Enum.count(gates_list, &(&1.status == :improvement))

            %{
              gates: gates_list,
              total: length(gates_list),
              passed: passed,
              improvement_periods: improvement
            }

          _ ->
            default_gates_status()
        end

      _ ->
        default_gates_status()
    end
  end

  defp default_gates_status do
    %{gates: [], total: 0, passed: 0, improvement_periods: 0}
  end

  defp days_remaining(expires_at) do
    DateTime.diff(expires_at, DateTime.utc_now(), :day)
  end

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)
    cond do
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      true -> "#{div(diff, 86400)} days ago"
    end
  end
end
