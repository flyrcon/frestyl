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
