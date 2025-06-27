# lib/frestyl_web/live/portfolio_hub_live/helpers.ex
defmodule FrestylWeb.PortfolioHubLive.Helpers do


  @moduledoc """
  Helper functions for the Portfolio Hub Live view
  """
  alias Frestyl.{Portfolios, Accounts, Features}

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
      %{type: :experiment_completed, experiment: "Bio Generator", user: "You", time: "30 minutes ago"}
    ]

    activities
    |> Enum.take(limit)
    |> Enum.map(&format_activity_message/1)
  end

    def get_enhancement_completion_rate(user_id) do
    portfolios = Portfolios.list_user_portfolios(user_id)

    total_possible_enhancements = length(portfolios) * 4 # voice, writing, design, music
    completed_enhancements = count_completed_enhancements(portfolios)

    if total_possible_enhancements > 0 do
      (completed_enhancements / total_possible_enhancements * 100) |> Float.round(1)
    else
      0
    end
  end

  def get_collaboration_recommendations(user_id, portfolio_id) do
    portfolio = Portfolios.get_portfolio(portfolio_id)
    quality_score = calculate_portfolio_quality_score(portfolio)
    user = Accounts.get_user(user_id)

    recommendations = []

    # Based on portfolio quality and user tier
    if quality_score.total < 60 do
      recommendations = recommendations ++ [
        %{type: "mentor_session", priority: "high", reason: "Portfolio needs fundamental improvements"},
        %{type: "peer_review", priority: "medium", reason: "Get feedback from fellow creators"}
      ]
    end

    if quality_score.total >= 70 do
      recommendations = recommendations ++ [
        %{type: "expert_review", priority: "high", reason: "Ready for professional feedback"},
        %{type: "community_showcase", priority: "medium", reason: "Share your work with the community"}
      ]
    end

    recommendations
    |> Enum.filter(&can_access_recommendation_type?(user, &1.type))
    |> Enum.sort_by(& &1.priority, :desc)
  end

    defp calculate_content_completeness(sections) do
    required_sections = ["about", "experience", "projects", "skills"]
    present_sections = Enum.map(sections, & &1.type)

    completion_rate = length(present_sections) / length(required_sections)
    (completion_rate * 40) |> min(40) |> round()
  end

  defp calculate_visual_quality(portfolio, sections) do
    score = 0

    # Check for hero image
    score = if portfolio.hero_image_url, do: score + 8, else: score

    # Check for consistent theming
    score = if has_consistent_theme?(portfolio), do: score + 7, else: score

    # Check for media in sections
    media_score = count_section_media(sections) |> min(10)
    score + media_score
  end

  defp calculate_engagement_elements(portfolio) do
    score = 0

    # Voice introduction
    score = if has_voice_intro?(portfolio), do: score + 8, else: score

    # Interactive elements
    score = if has_interactive_elements?(portfolio), do: score + 6, else: score

    # Social links
    score = if has_social_links?(portfolio), do: score + 3, else: score

    # Call-to-action
    score = if has_cta?(portfolio), do: score + 3, else: score

    score
  end

  defp calculate_professional_polish(portfolio) do
    score = 0

    # Custom domain
    score = if has_custom_domain?(portfolio), do: score + 5, else: score

    # Professional email
    score = if has_professional_contact?(portfolio), do: score + 3, else: score

    # Complete contact information
    score = if has_complete_contact?(portfolio), do: score + 4, else: score

    # SEO optimization
    score = if has_seo_optimization?(portfolio), do: score + 3, else: score

    score
  end

  defp format_activity_message(activity) do
    message = case activity.type do
      :portfolio_view -> "#{activity.count} new views on"
      :comment_received -> "#{activity.user} commented on"
      :collaboration_invite -> "#{activity.user} invited you to collaborate on"
      :feedback_received -> "Received #{activity.rating}⭐ feedback on"
      :experiment_completed -> "#{activity.user} completed"
      _ -> "Activity on"
    end

    Map.put(activity, :message, message)
  end

  @doc """
  Gets mock collaboration requests
  This would be replaced with real database queries
  """
  def get_collaboration_requests(user_id, limit \\ 10) do
    [
      %{
        id: 1,
        user: "Alex Chen",
        user_avatar: "AC",
        portfolio: "UX Case Study",
        type: "feedback",
        status: "pending",
        message: "Would love feedback on my latest case study",
        time: "2 hours ago"
      },
      %{
        id: 2,
        user: "Sarah Miller",
        user_avatar: "SM",
        portfolio: "Music Video Project",
        type: "collaboration",
        status: "pending",
        message: "Looking for motion graphics collaboration",
        time: "1 day ago"
      }
    ]
    |> Enum.take(limit)
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

    def get_portfolio_title(portfolio_id, portfolios) when is_binary(portfolio_id) do
    get_portfolio_title(String.to_integer(portfolio_id), portfolios)
  rescue
    ArgumentError -> "Unknown Portfolio"
  end

  def get_portfolio_title(portfolio_id, portfolios) when is_integer(portfolio_id) do
    case Enum.find(portfolios, &(&1.id == portfolio_id)) do
      %{title: title} -> title
      nil -> "Unknown Portfolio"
    end
  end

  def get_portfolio_title(_, _), do: "Unknown Portfolio"


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

    def calculate_portfolio_quality_score(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    # Content completeness (40 points)
    content_score = calculate_content_completeness(sections)

    # Visual quality (25 points)
    visual_score = calculate_visual_quality(portfolio, sections)

    # Engagement elements (20 points)
    engagement_score = calculate_engagement_elements(portfolio)

    # Professional polish (15 points)
    polish_score = calculate_professional_polish(portfolio)

    total_score = content_score + visual_score + engagement_score + polish_score

    %{
      total: min(total_score, 100),
      content: content_score,
      visual: visual_score,
      engagement: engagement_score,
      polish: polish_score,
      breakdown: %{
        has_voice_intro: has_voice_introduction?(sections),
        content_quality: assess_content_quality(sections),
        visual_consistency: assess_visual_consistency(portfolio),
        professional_media: has_professional_media?(sections),
        engagement_elements: count_engagement_elements(portfolio)
      }
    }
  end

  @doc """
  Get collaboration recommendations for a user and portfolio
  """
  def get_collaboration_recommendations(user_id, portfolio_id) do
    portfolio = Portfolios.get_portfolio(portfolio_id)
    quality_score = calculate_portfolio_quality_score(portfolio)
    user = Accounts.get_user(user_id)

    recommendations = []

    # Based on portfolio quality and user tier
    recommendations = if quality_score.total < 60 do
      recommendations ++ [
        %{type: "mentor_session", priority: "high", reason: "Portfolio needs fundamental improvements"},
        %{type: "peer_review", priority: "medium", reason: "Get feedback from fellow creators"}
      ]
    else
      recommendations
    end

    recommendations = if quality_score.total >= 70 do
      recommendations ++ [
        %{type: "expert_review", priority: "high", reason: "Ready for professional feedback"},
        %{type: "community_showcase", priority: "medium", reason: "Share your work with the community"}
      ]
    else
      recommendations
    end

    recommendations
    |> Enum.filter(&can_access_recommendation_type?(user, &1.type))
    |> Enum.sort_by(& &1.priority, :desc)
  end

  @doc """
  Get enhancement completion rate for a user
  """
  def get_enhancement_completion_rate(user_id) do
    portfolios = Portfolios.list_user_portfolios(user_id)

    total_possible_enhancements = length(portfolios) * 4 # voice, writing, design, music
    completed_enhancements = count_completed_enhancements(portfolios)

    if total_possible_enhancements > 0 do
      (completed_enhancements / total_possible_enhancements * 100) |> Float.round(1)
    else
      0
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR QUALITY ASSESSMENT
  # ============================================================================

  defp calculate_content_completeness(sections) do
    required_sections = ["about", "experience", "projects", "skills"]
    present_sections = Enum.map(sections, & &1.type)

    completion_rate = length(present_sections) / length(required_sections)
    (completion_rate * 40) |> min(40) |> round()
  end

  defp calculate_visual_quality(portfolio, sections) do
    score = 0

    # Check for hero image
    score = if portfolio.hero_image_url, do: score + 8, else: score

    # Check for consistent theming
    score = if has_consistent_theme?(portfolio), do: score + 7, else: score

    # Check for media in sections
    media_score = count_section_media(sections) |> min(10)
    score + media_score
  end

  defp calculate_engagement_elements(portfolio) do
    score = 0

    # Voice introduction
    score = if has_voice_intro?(portfolio), do: score + 8, else: score

    # Interactive elements
    score = if has_interactive_elements?(portfolio), do: score + 6, else: score

    # Social links
    score = if has_social_links?(portfolio), do: score + 3, else: score

    # Call-to-action
    score = if has_cta?(portfolio), do: score + 3, else: score

    score
  end

  defp calculate_professional_polish(portfolio) do
    score = 0

    # Custom domain
    score = if has_custom_domain?(portfolio), do: score + 5, else: score

    # Professional email
    score = if has_professional_contact?(portfolio), do: score + 3, else: score

    # Complete contact information
    score = if has_complete_contact?(portfolio), do: score + 4, else: score

    # SEO optimization
    score = if has_seo_optimization?(portfolio), do: score + 3, else: score

    score
  end

  # ============================================================================
  # PORTFOLIO CHECK FUNCTIONS
  # ============================================================================

  defp has_voice_introduction?(sections) do
    Enum.any?(sections, fn section ->
      section.type == "voice_intro" ||
      (section.content && Map.has_key?(section.content, "voice_file"))
    end)
  end

  defp assess_content_quality(sections) do
    # Calculate content quality based on section completeness and length
    content_sections = Enum.filter(sections, &(&1.type in ["about", "experience", "projects"]))

    if length(content_sections) > 0 do
      avg_length = Enum.reduce(content_sections, 0, fn section, acc ->
        content_length = get_content_length(section)
        acc + content_length
      end) / length(content_sections)

      # Scale to 0-100
      min(avg_length / 10, 100) |> round()
    else
      0
    end
  end

  defp assess_visual_consistency(portfolio) do
    # Mock assessment - in real implementation, check color scheme, fonts, etc.
    portfolio.theme != nil
  end

  defp has_professional_media?(sections) do
    Enum.any?(sections, fn section ->
      section.content &&
      (Map.has_key?(section.content, "images") || Map.has_key?(section.content, "media"))
    end)
  end

  defp count_engagement_elements(portfolio) do
    elements = 0
    elements = if has_voice_intro?(portfolio), do: elements + 1, else: elements
    elements = if has_social_links?(portfolio), do: elements + 1, else: elements
    elements = if has_cta?(portfolio), do: elements + 1, else: elements
    elements = if has_interactive_elements?(portfolio), do: elements + 1, else: elements
    elements
  end

  defp has_consistent_theme?(portfolio) do
    portfolio.theme != nil && portfolio.customization != nil
  end

  defp count_section_media(sections) do
    Enum.count(sections, fn section ->
      section.content &&
      (Map.has_key?(section.content, "images") ||
       Map.has_key?(section.content, "media") ||
       Map.has_key?(section.content, "hero_image"))
    end)
  end

  defp has_voice_intro?(portfolio) do
    # Check if portfolio has voice introduction
    false # Mock - implement based on your schema
  end

  defp has_interactive_elements?(portfolio) do
    # Check for interactive elements
    false # Mock - implement based on your schema
  end

  defp has_social_links?(portfolio) do
    portfolio.social_links && map_size(portfolio.social_links) > 0
  end

  defp has_cta?(portfolio) do
    # Check for call-to-action elements
    portfolio.contact_info != nil
  end

  defp has_custom_domain?(portfolio) do
    # Check if portfolio uses custom domain
    false # Mock - implement based on your schema
  end

  defp has_professional_contact?(portfolio) do
    portfolio.contact_info != nil && portfolio.contact_info != %{}
  end

  defp has_complete_contact?(portfolio) do
    contact = portfolio.contact_info || %{}
    Map.has_key?(contact, "email") && Map.has_key?(contact, "phone")
  end

  defp has_seo_optimization?(portfolio) do
    # Check for SEO elements like meta descriptions, titles, etc.
    portfolio.meta_description != nil
  end

  defp get_content_length(section) do
    case section.content do
      nil -> 0
      content when is_map(content) ->
        # Count text content in the section
        content
        |> Map.values()
        |> Enum.reduce(0, fn value, acc ->
          if is_binary(value) do
            acc + String.length(value)
          else
            acc
          end
        end)
      _ -> 0
    end
  end

  # ============================================================================
  # COLLABORATION FUNCTIONS
  # ============================================================================

  defp can_access_recommendation_type?(user, recommendation_type) do
    account = user.account || %{subscription_tier: "personal"}

    case recommendation_type do
      "mentor_session" ->
        Features.FeatureGate.can_access_feature?(account, :mentor_access)
      "expert_review" ->
        Features.FeatureGate.can_access_feature?(account, :expert_review)
      "community_showcase" ->
        Features.FeatureGate.can_access_feature?(account, :community_showcase)
      "peer_review" ->
        Features.FeatureGate.can_access_feature?(account, :real_time_collaboration)
      _ ->
        true # Default to accessible
    end
  end

  defp count_completed_enhancements(portfolios) do
    # Mock implementation - count completed enhancements across portfolios
    Enum.reduce(portfolios, 0, fn portfolio, acc ->
      # In real implementation, query enhancement_completions table
      completed_count = :rand.uniform(4) # Mock: 0-4 completed enhancements per portfolio
      acc + completed_count
    end)
  end
end
