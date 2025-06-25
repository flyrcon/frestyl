# lib/frestyl_web/live/portfolio_hub_live/helpers.ex
defmodule FrestylWeb.PortfolioHubLive.Helpers do
  @moduledoc """
  Helper functions for the Portfolio Hub Live view
  """

  @doc """
  Formats a relative date string (e.g., "2 days ago")
  """
  def relative_date(datetime) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff < 604800 -> "#{div(diff, 86400)} days ago"
      diff < 2629746 -> "#{div(diff, 604800)} weeks ago"
      true -> "#{div(diff, 2629746)} months ago"
    end
  end

  @doc """
  Filters portfolios based on status
  """
  def get_filtered_portfolios(portfolios, filter_status) do
    case filter_status do
      "published" -> Enum.filter(portfolios, &(&1.visibility == :public))
      "draft" -> Enum.filter(portfolios, &(&1.visibility == :private))
      "collaborative" -> Enum.filter(portfolios, &has_collaborations?/1)
      _ -> portfolios
    end
  end

  @doc """
  Checks if a portfolio has active collaborations
  """
  def has_collaborations?(portfolio) do
    # This would integrate with your actual collaboration system
    # For now, randomly assign some portfolios as collaborative for demo
    case rem(portfolio.id, 3) do
      0 -> true
      _ -> false
    end
  end

  @doc """
  Gets collaboration indicators for a portfolio
  """
  def get_collaboration_indicators(portfolio_stats) do
    %{
      collaborator_count: length(Map.get(portfolio_stats, :collaborations, [])),
      has_pending_feedback: Map.get(portfolio_stats, :needs_feedback, false),
      comment_count: Map.get(portfolio_stats, :comments, 0),
      recent_activity: Map.get(portfolio_stats, :recent_activity, false)
    }
  end

  @doc """
  Generates GitHub-style activity data for the contribution graph
  """
  def generate_activity_data(user_id, days \\ 30) do
    # This would fetch real activity data from your database
    # For now, generate mock data
    today = Date.utc_today()

    for day_offset <- (days - 1)..0 do
      date = Date.add(today, -day_offset)
      activity_level = :rand.uniform(4) - 1  # 0-3 activity levels

      %{
        date: date,
        activity_level: activity_level,
        contributions: activity_level * :rand.uniform(5)
      }
    end
  end

  @doc """
  Gets the CSS class for activity level in contribution graph
  """
  def activity_level_class(level) do
    case level do
      0 -> "bg-gray-100"
      1 -> "bg-green-200"
      2 -> "bg-green-300"
      3 -> "bg-green-400"
      _ -> "bg-green-500"
    end
  end

  @doc """
  Formats portfolio statistics for display
  """
  def format_portfolio_stats(stats) when is_map(stats) do
    %{
      views: format_number(Map.get(stats, :total_visits, 0)),
      unique_visitors: format_number(Map.get(stats, :unique_visitors, 0)),
      shares: format_number(Map.get(stats, :shares, 0)),
      comments: format_number(Map.get(stats, :comments, 0))
    }
  end
  def format_portfolio_stats(_), do: %{views: "0", unique_visitors: "0", shares: "0", comments: "0"}

  @doc """
  Formats numbers with appropriate suffixes (1K, 1M, etc.)
  """
  def format_number(num) when is_integer(num) do
    cond do
      num >= 1_000_000 -> "#{Float.round(num / 1_000_000, 1)}M"
      num >= 1_000 -> "#{Float.round(num / 1_000, 1)}K"
      true -> Integer.to_string(num)
    end
  end
  def format_number(_), do: "0"

  @doc """
  Gets theme-specific gradient classes for portfolio cards
  """
  def theme_gradient_class(theme) do
    case theme do
      "executive" -> "bg-gradient-to-br from-blue-500 to-indigo-600"
      "creative" -> "bg-gradient-to-br from-purple-500 to-pink-600"
      "developer" -> "bg-gradient-to-br from-green-500 to-teal-600"
      "minimalist" -> "bg-gradient-to-br from-gray-500 to-gray-600"
      "corporate" -> "bg-gradient-to-br from-blue-600 to-blue-800"
      "academic" -> "bg-gradient-to-br from-indigo-500 to-purple-600"
      _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
    end
  end

  @doc """
  Determines if a portfolio was created recently (within last 7 days)
  """
  def created_recently?(portfolio) do
    case DateTime.compare(portfolio.inserted_at, DateTime.add(DateTime.utc_now(), -7, :day)) do
      :gt -> true
      _ -> false
    end
  end

  @doc """
  Gets collaboration status emoji/icon
  """
  def collaboration_status_icon(type) do
    case type do
      :portfolio_view -> "👁️"
      :comment_received -> "💬"
      :collaboration_invite -> "🤝"
      :feedback_received -> "⭐"
      :share_created -> "🔗"
      :edit_session -> "✏️"
      _ -> "📝"
    end
  end

  @doc """
  Generates mock recent activity data
  This would be replaced with real database queries
  """
  def get_recent_activity(user_id, limit \\ 5) do
    activities = [
      %{type: :portfolio_view, portfolio: "UX Designer Portfolio", count: 12, time: "2 hours ago"},
      %{type: :comment_received, portfolio: "Developer Showcase", user: "Sarah Chen", time: "5 hours ago"},
      %{type: :collaboration_invite, portfolio: "Creative Director", user: "Alex Rivera", time: "1 day ago"},
      %{type: :feedback_received, portfolio: "Product Manager", rating: 4.8, time: "2 days ago"},
      %{type: :share_created, portfolio: "UX Designer Portfolio", count: 3, time: "3 days ago"},
      %{type: :edit_session, portfolio: "Developer Showcase", duration: "45 min", time: "1 week ago"}
    ]

    activities
    |> Enum.take(limit)
    |> Enum.map(&format_activity_message/1)
  end

  defp format_activity_message(activity) do
    message = case activity.type do
      :portfolio_view -> "#{activity.count} new views on"
      :comment_received -> "#{activity.user} commented on"
      :collaboration_invite -> "#{activity.user} invited you to collaborate on"
      :feedback_received -> "Received #{activity.rating}⭐ feedback on"
      :share_created -> "#{activity.count} new shares of"
      :edit_session -> "#{activity.duration} editing session on"
      _ -> "Activity on"
    end

    Map.put(activity, :message, message)
  end

  @doc """
  Gets mock collaboration requests
  This would be replaced with real database queries
  """
  def get_collaboration_requests(user_id, limit \\ 10) do
    requests = [
      %{
        id: 1,
        user: "Sarah Chen",
        user_avatar: "SC",
        portfolio: "UX Designer Portfolio",
        type: "review",
        status: "pending",
        message: "Would love to get feedback on the case study section",
        requested_at: DateTime.add(DateTime.utc_now(), -2, :hour)
      },
      %{
        id: 2,
        user: "Alex Rivera",
        user_avatar: "AR",
        portfolio: "Developer Showcase",
        type: "collaborate",
        status: "pending",
        message: "Let's work together on the technical documentation",
        requested_at: DateTime.add(DateTime.utc_now(), -1, :day)
      },
      %{
        id: 3,
        user: "Maya Patel",
        user_avatar: "MP",
        portfolio: "Creative Director",
        type: "feedback",
        status: "pending",
        message: "Looking for design feedback on the visual hierarchy",
        requested_at: DateTime.add(DateTime.utc_now(), -3, :day)
      }
    ]

    requests
    |> Enum.take(limit)
    |> Enum.map(fn req ->
      Map.put(req, :relative_time, relative_date(req.requested_at))
    end)
  end

  @doc """
  Gets portfolio collaboration data
  This would integrate with your actual collaboration system
  """
  def get_portfolio_collaborations(portfolio_id) do
    # Mock collaboration data
    collaborator_count = :rand.uniform(5)

    collaborators = for i <- 1..collaborator_count do
      names = ["Sarah Chen", "Alex Rivera", "Maya Patel", "Jordan Kim", "Taylor Swift"]
      roles = ["reviewer", "editor", "commenter", "viewer"]

      %{
        user: Enum.at(names, rem(i, length(names))),
        role: Enum.at(roles, rem(i, length(roles))),
        status: if(:rand.uniform(10) > 2, do: "active", else: "pending"),
        avatar: String.first(Enum.at(names, rem(i, length(names))))
      }
    end

    collaborators
  end

  @doc """
  Gets portfolio comment count (mock data)
  """
  def get_portfolio_comments(portfolio_id) do
    # Mock comment count
    :rand.uniform(15)
  end

  @doc """
  Checks if portfolio needs feedback based on various criteria
  """
  def needs_feedback?(portfolio, stats) do
    recently_created = created_recently?(portfolio)
    low_engagement = Map.get(stats, :comments, 0) < 2
    no_recent_activity = Map.get(stats, :recent_activity, false) == false

    recently_created and (low_engagement or no_recent_activity)
  end

  @doc """
  Generates Portfolio Hub onboarding flow based on user state
  """
  def get_onboarding_state(user, portfolios, limits) do
    cond do
      length(portfolios) == 0 ->
        %{step: :create_first_portfolio, message: "Create your first portfolio to get started"}

      Enum.all?(portfolios, &(&1.visibility == :private)) ->
        %{step: :publish_portfolio, message: "Publish a portfolio to start getting views"}

      !has_resume_uploaded?(user) ->
        %{step: :upload_resume, message: "Upload your resume to auto-populate portfolio sections"}

      !has_collaboration_setup?(portfolios) ->
        %{step: :setup_collaboration, message: "Enable collaboration to get feedback from peers"}

      true ->
        %{step: :completed, message: "You're all set! Keep creating amazing portfolios"}
    end
  end

  defp has_resume_uploaded?(user) do
    # Check if user has uploaded a resume
    # This would check your actual resume/file upload system
    false
  end

  defp has_collaboration_setup?(portfolios) do
    # Check if any portfolio has collaboration enabled
    # This would check your actual collaboration system
    Enum.any?(portfolios, &has_collaborations?/1)
  end
end

# lib/frestyl_web/live/portfolio_hub_live/components.ex
defmodule FrestylWeb.PortfolioHubLive.Components do
  @moduledoc """
  Reusable components for Portfolio Hub
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  alias FrestylWeb.PortfolioHubLive.Helpers

  @doc """
  Renders a portfolio card with collaboration indicators
  """
  def portfolio_card(assigns) do
    ~H"""
    <div class="group bg-white border border-gray-200 rounded-lg hover:shadow-md transition-all duration-200 overflow-hidden">
      <!-- Portfolio Preview -->
      <div class="aspect-w-16 aspect-h-9 bg-gradient-to-br from-gray-100 to-gray-200">
        <div class={[
          "w-full h-32 flex items-center justify-center",
          Helpers.theme_gradient_class(@portfolio.theme)
        ]}>
          <div class="text-center text-white">
            <h4 class="font-bold text-lg"><%= @portfolio.title %></h4>
            <p class="text-sm opacity-90">/<%= @portfolio.slug %></p>
          </div>
        </div>
      </div>

      <!-- Portfolio Info -->
      <div class="p-4">
        <div class="flex items-start justify-between mb-3">
          <div class="flex-1">
            <h3 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors">
              <%= @portfolio.title %>
            </h3>
            <p class="text-sm text-gray-600 mt-1"><%= @portfolio.description %></p>
          </div>

          <!-- Collaboration Indicators -->
          <.collaboration_indicators stats={@stats} />
        </div>

        <!-- Stats & Actions -->
        <.portfolio_stats_row portfolio={@portfolio} stats={@stats} />
        <.portfolio_actions portfolio={@portfolio} />
      </div>
    </div>
    """
  end

  @doc """
  Renders collaboration indicators (avatars, feedback needs, etc.)
  """
  def collaboration_indicators(assigns) do
    ~H"""
    <div class="flex items-center space-x-1 ml-2">
      <%= if length(@stats.collaborations) > 0 do %>
        <div class="flex -space-x-1">
          <%= for collab <- Enum.take(@stats.collaborations, 3) do %>
            <div class="w-6 h-6 bg-purple-500 rounded-full border-2 border-white flex items-center justify-center text-xs text-white font-bold">
              <%= String.first(collab.user) %>
            </div>
          <% end %>
          <%= if length(@stats.collaborations) > 3 do %>
            <div class="w-6 h-6 bg-gray-400 rounded-full border-2 border-white flex items-center justify-center text-xs text-white">
              +<%= length(@stats.collaborations) - 3 %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @stats.needs_feedback do %>
        <div class="w-2 h-2 bg-orange-400 rounded-full" title="Seeking feedback"></div>
      <% end %>

      <%= if @stats.comments > 5 do %>
        <div class="w-2 h-2 bg-green-400 rounded-full" title="Active discussions"></div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders portfolio stats row (views, comments, etc.)
  """
  def portfolio_stats_row(assigns) do
    formatted_stats = Helpers.format_portfolio_stats(@stats.stats)

    assigns = assign(assigns, :formatted_stats, formatted_stats)

    ~H"""
    <div class="flex items-center justify-between text-sm text-gray-500 mb-3">
      <div class="flex items-center space-x-4">
        <span class="flex items-center">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
          </svg>
          <%= @formatted_stats.views %>
        </span>
        <span class="flex items-center">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V5a2 2 0 00-2-2H9a2 2 0 00-2 2v3m10 0v3a2 2 0 01-2 2H9a2 2 0 01-2-2v-3"/>
          </svg>
          <%= @formatted_stats.comments %>
        </span>
      </div>
      <span class="text-xs">
        Updated <%= Helpers.relative_date(@portfolio.updated_at) %>
      </span>
    </div>
    """
  end

  @doc """
  Renders portfolio action buttons
  """
  def portfolio_actions(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-2">
        <.link href={"/portfolios/#{@portfolio.id}/edit"}
              class="inline-flex items-center px-2 py-1 text-xs font-medium text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
          </svg>
          Edit
        </.link>

        <.link href={"/p/#{@portfolio.slug}"} target="_blank"
              class="inline-flex items-center px-2 py-1 text-xs font-medium text-gray-600 hover:text-green-600 hover:bg-green-50 rounded transition-colors">
          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
          </svg>
          View
        </.link>
      </div>

      <!-- Collaboration Actions -->
      <div class="flex items-center space-x-1">
        <button phx-click="request_feedback" phx-value-portfolio_id={@portfolio.id}
                class="inline-flex items-center px-2 py-1 text-xs font-medium text-orange-600 hover:text-orange-700 hover:bg-orange-50 rounded transition-colors"
                title="Request feedback">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10m0 0V5a2 2 0 00-2-2H9a2 2 0 00-2 2v3m10 0v3a2 2 0 01-2 2H9a2 2 0 01-2-2v-3"/>
          </svg>
        </button>

        <button phx-click="start_collaboration" phx-value-portfolio_id={@portfolio.id}
                class="inline-flex items-center px-2 py-1 text-xs font-medium text-purple-600 hover:text-purple-700 hover:bg-purple-50 rounded transition-colors"
                title="Start collaboration">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders the GitHub-style contribution graph
  """
  def contribution_graph(assigns) do
    activity_data = Helpers.generate_activity_data(assigns.user_id, 30)
    assigns = assign(assigns, :activity_data, activity_data)

    ~H"""
    <div class="mb-6">
      <div class="flex items-center justify-between mb-2">
        <span class="text-sm font-medium text-gray-700">Portfolio Activity</span>
        <span class="text-xs text-gray-500">Last 30 days</span>
      </div>
      <div class="grid grid-cols-30 gap-1">
        <%= for day <- @activity_data do %>
          <div class={[
            "w-3 h-3 rounded-sm",
            Helpers.activity_level_class(day.activity_level)
          ]} title={"#{day.date}: #{day.contributions} contributions"}></div>
        <% end %>
      </div>
    </div>
    """
  end
end
