# lib/frestyl_web/live/portfolio_hub_live/helpers.ex - ENHANCED FOR CREATOR COMMAND CENTER

defmodule FrestylWeb.PortfolioHubLive.Helpers do
  @moduledoc """
  Enhanced helper functions for the comprehensive Portfolio Hub Live view.
  Supports all six feature sections with equal prominence and subscription-based access.
  """

  alias Frestyl.{Portfolios, Accounts, Features, Channels, Services, Revenue, Lab, Analytics}

  # ============================================================================
  # EXISTING HELPER FUNCTIONS (Maintained)
  # ============================================================================

  @doc """
  Formats a relative date string (e.g., "2 days ago")
  """
  def relative_date(datetime) when is_nil(datetime), do: "never"

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
      "enhanced" -> Enum.filter(portfolios, &has_enhancements?/1)
      "service_linked" -> Enum.filter(portfolios, &has_service_integration?/1)
      _ -> portfolios
    end
  end

  @doc """
  Checks if a portfolio has active collaborations
  """
  def has_collaborations?(portfolio) do
    # Check if portfolio has collaboration features enabled
    try do
      case Channels.get_portfolio_collaborations(portfolio.id) do
        collaborations when is_list(collaborations) -> length(collaborations) > 0
        _ -> false
      end
    rescue
      _ -> false
    end
  end

    @doc """
  Humanizes a snake_case section name for display in the UI.
  """
  def humanize_section_name(section) do
    case section do
      "portfolio_studio" -> "Portfolio Studio"
      "collaboration_hub" -> "Collaboration Hub"
      "community_channels" -> "Community Channels"
      "creator_lab" -> "Creator Lab"
      "service_dashboard" -> "Service Dashboard"
      "revenue_center" -> "Revenue Center"
      _ -> Phoenix.Naming.humanize(section)
    end
  end

  @doc """
  Generates Portfolio Hub onboarding flow based on user state
  """
  def get_onboarding_state(user, portfolios, limits) do
    %{
      completed_steps: [],
      total_steps: 5,
      current_step: 1,
      is_complete: length(portfolios) > 0
    }
  end

  # ============================================================================
  # COLLABORATION FUNCTIONS (Enhanced)
  # ============================================================================

  @doc """
  Gets collaboration requests for a user across all portfolios
  """
  def get_collaboration_requests(user_id) do
    # Mock data - replace with actual implementation
    []
  end

  defp format_collaboration_request(request) do
    %{
      id: request.id,
      user: request.requester_name || "Unknown User",
      type: format_collaboration_type(request.collaboration_type),
      portfolio: request.portfolio_title || "Unknown Portfolio",
      message: request.message,
      created_at: request.inserted_at,
      urgency: determine_request_urgency(request)
    }
  end

  defp format_collaboration_type(type) do
    case type do
      "peer_review" -> "provide feedback"
      "content_collaboration" -> "collaborate on content"
      "design_review" -> "review design"
      "expert_consultation" -> "provide expert consultation"
      _ -> "collaborate"
    end
  end

  defp determine_request_urgency(request) do
    days_old = DateTime.diff(DateTime.utc_now(), request.inserted_at, :day)
    cond do
      days_old > 7 -> "low"
      days_old > 3 -> "medium"
      true -> "high"
    end
  end

  @doc """
  Checks if user can access recommendation type based on subscription
  """
  defp can_access_recommendation_type?(current_account, recommendation_type) do
    account = current_account || %{subscription_tier: "personal"}

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

  # ============================================================================
  # SERVICE DASHBOARD FUNCTIONS (NEW)
  # ============================================================================

  @doc """
  Checks if user can access service features
  """
  def can_access_services?(user) do
    account = user.account || %{subscription_tier: "personal"}
    Features.FeatureGate.can_access_feature?(account, :service_dashboard)
  end

  @doc """
  Gets service booking statistics for user
  """
  def get_service_stats(user_id) do
    if_can_access_services(user_id, fn ->
      %{
        total_bookings: Services.count_user_bookings(user_id),
        active_bookings: Services.count_active_bookings(user_id),
        completed_bookings: Services.count_completed_bookings(user_id),
        total_revenue: Services.get_total_service_revenue(user_id),
        average_rating: Services.get_average_service_rating(user_id),
        repeat_client_rate: Services.get_repeat_client_rate(user_id)
      }
    end)
  end

  @doc """
  Gets upcoming service appointments for user
  """
  def get_upcoming_service_appointments(user_id, limit \\ 5) do
    if_can_access_services(user_id, fn ->
      Services.get_upcoming_appointments(user_id, limit: limit)
      |> Enum.map(&format_service_appointment/1)
    end)
  end

  defp format_service_appointment(appointment) do
    %{
      id: appointment.id,
      service_name: appointment.service.name,
      client_name: appointment.client.name,
      date: format_appointment_date(appointment.scheduled_at),
      time: format_appointment_time(appointment.scheduled_at),
      duration: appointment.service.duration,
      amount: appointment.service.price,
      status: appointment.status,
      meeting_link: appointment.meeting_link,
      notes: appointment.notes
    }
  end

  defp format_appointment_date(datetime) do
    case Date.diff(DateTime.to_date(datetime), Date.utc_today()) do
      0 -> "Today"
      1 -> "Tomorrow"
      days when days < 7 -> Calendar.strftime(datetime, "%A")
      _ -> Calendar.strftime(datetime, "%b %d")
    end
  end

  defp format_appointment_time(datetime) do
    Calendar.strftime(datetime, "%I:%M %p")
  end

  # ============================================================================
  # REVENUE CENTER FUNCTIONS (NEW)
  # ============================================================================

  @doc """
  Checks if user can access revenue center features
  """
  def can_access_revenue_center?(user) do
    account = user.account || %{subscription_tier: "personal"}
    Features.FeatureGate.can_access_feature?(account, :revenue_center)
  end

  @doc """
  Gets comprehensive revenue analytics for user
  """
  def get_revenue_analytics(user_id) do
    if_can_access_revenue(user_id, fn ->
      %{
        total_revenue: Revenue.get_total_revenue(user_id),
        monthly_revenue: Revenue.get_monthly_revenue(user_id),
        revenue_sources: Revenue.get_revenue_sources_breakdown(user_id),
        growth_rate: Revenue.calculate_growth_rate(user_id),
        top_performing_portfolios: Revenue.get_top_performing_portfolios(user_id),
        projected_revenue: Revenue.calculate_projected_revenue(user_id),
        platform_fees: Revenue.get_platform_fees_summary(user_id)
      }
    end)
  end

  @doc """
  Gets revenue trends data for charts
  """
  def get_revenue_trends(user_id, period \\ :last_12_months) do
    if_can_access_revenue(user_id, fn ->
      Revenue.get_revenue_trends(user_id, period)
      |> Enum.map(&format_revenue_trend_point/1)
    end)
  end

  defp format_revenue_trend_point(data_point) do
    %{
      date: data_point.date,
      revenue: data_point.total_revenue,
      portfolios: data_point.portfolio_revenue,
      services: data_point.service_revenue,
      other: data_point.other_revenue
    }
  end

  # ============================================================================
  # CREATOR LAB FUNCTIONS (NEW)
  # ============================================================================

  @doc """
  Checks if user can access creator lab features
  """
  def can_access_creator_lab?(user) do
    account = user.account || %{subscription_tier: "personal"}
    Features.FeatureGate.can_access_feature?(account, :creator_lab)
  end

  @doc """
  Gets available lab features for user
  """
  def get_available_lab_features(user) do
    if_can_access_lab(user, fn ->
      Lab.get_available_features(user)
      |> Enum.map(&format_lab_feature/1)
    end)
  end

  defp format_lab_feature(feature) do
    %{
      id: feature.id,
      name: feature.name,
      icon: feature.icon || "🧪",
      description: feature.description,
      status: feature.status, # "beta", "experimental", "stable"
      complexity: feature.complexity, # "beginner", "intermediate", "advanced"
      estimated_time: feature.estimated_completion_time,
      prerequisites: feature.prerequisites || []
    }
  end

  @doc """
  Gets AI insights and recommendations for user
  """
  def get_ai_insights(user_id) do
    if_can_access_lab_by_id(user_id, fn ->
      Lab.get_ai_insights(user_id)
      |> Enum.reduce(%{}, &format_ai_insight/2)
    end)
  end

  defp format_ai_insight({insight_type, insight_data}, acc) do
    formatted_insight = %{
      description: insight_data.description,
      confidence: insight_data.confidence_score,
      impact: insight_data.potential_impact,
      action_items: insight_data.recommended_actions || [],
      created_at: insight_data.generated_at
    }
    Map.put(acc, insight_type, formatted_insight)
  end

  # ============================================================================
  # COMMUNITY CHANNELS FUNCTIONS (Enhanced)
  # ============================================================================

  @doc """
  Gets trending channels based on user interests
  """
  def get_trending_channels(user, limit \\ 6) do
    try do
      Channels.get_trending_channels(user, limit: limit)
      |> Enum.map(&format_channel/1)
    rescue
      _ -> []
    end
  end

  def generate_enhancement_recommendations(portfolios, current_account) do
    portfolios
    |> Enum.flat_map(fn portfolio ->
      quality_score = calculate_portfolio_quality_score(portfolio)

      recommendations = []

      # Only suggest recommendations the user can access
      if can_access_recommendation_type?(current_account, "mentor_session") do
        recommendations = [%{
          type: "mentor_session",
          portfolio_id: portfolio.id,
          title: "Schedule Mentor Session",
          description: "Get expert feedback on your portfolio"
        } | recommendations]
      end

      if can_access_recommendation_type?(current_account, "expert_review") do
        recommendations = [%{
          type: "expert_review",
          portfolio_id: portfolio.id,
          title: "Expert Portfolio Review",
          description: "Professional review of your portfolio content"
        } | recommendations]
      end

      recommendations
    end)
    |> Enum.take(5)
  end

  @doc """
  Gets personalized channel recommendations
  """
  def get_channel_recommendations(user, limit \\ 6) do
    try do
      Channels.get_personalized_recommendations(user, limit: limit)
      |> Enum.map(&format_channel_recommendation/1)
    rescue
      _ -> []
    end
  end

  defp format_channel(channel) do
    %{
      id: channel.id,
      name: channel.name,
      description: channel.description,
      type: channel.channel_type,
      member_count: channel.member_count || 0,
      activity_level: determine_activity_level(channel),
      created_at: channel.inserted_at,
      is_trending: channel.is_trending || false
    }
  end

  defp format_channel_recommendation(channel) do
    %{
      id: channel.id,
      name: channel.name,
      description: channel.description,
      category: channel.category,
      member_count: channel.member_count || 0,
      match_score: channel.recommendation_score,
      match_reasons: channel.match_reasons || []
    }
  end

  defp determine_activity_level(channel) do
    recent_activity = channel.recent_message_count || 0
    cond do
      recent_activity > 50 -> "high"
      recent_activity > 20 -> "medium"
      recent_activity > 5 -> "low"
      true -> "minimal"
    end
  end

  # ============================================================================
  # PORTFOLIO QUALITY & ENHANCEMENT FUNCTIONS (Enhanced)
  # ============================================================================

  @doc """
  Calculates comprehensive portfolio quality score
  """
  def calculate_portfolio_quality_score(portfolio) do
    sections = safe_get_portfolio_sections(portfolio.id)

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
        seo_optimized: has_seo_optimization?(portfolio),
        social_integration: has_social_integration?(portfolio),
        call_to_action: has_call_to_action?(portfolio)
      }
    }
  end

  defp safe_get_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  @doc """
  Gets portfolio title safely from portfolio list
  """
  def get_portfolio_title(portfolio_id, portfolios) when is_binary(portfolio_id) do
    case Integer.parse(portfolio_id) do
      {id, ""} -> get_portfolio_title(id, portfolios)
      _ -> "Unknown Portfolio"
    end
  end

  def get_portfolio_title(portfolio_id, portfolios) do
    case Enum.find(portfolios, &(&1.id == portfolio_id)) do
      nil -> "Unknown Portfolio"
      portfolio -> portfolio.title
    end
  end

  def get_portfolio_title(_, _), do: "Unknown Portfolio"

  # ============================================================================
  # ANALYTICS & METRICS FUNCTIONS (NEW)
  # ============================================================================

  @doc """
  Gets comprehensive user analytics across all features
  """
  def get_user_analytics_summary(user_id) do
    %{
      portfolio_metrics: get_portfolio_metrics_summary(user_id),
      collaboration_metrics: get_collaboration_metrics_summary(user_id),
      service_metrics: get_service_metrics_summary(user_id),
      revenue_metrics: get_revenue_metrics_summary(user_id),
      engagement_metrics: get_engagement_metrics_summary(user_id)
    }
  end

  defp get_portfolio_metrics_summary(user_id) do
    try do
      Analytics.get_portfolio_metrics_summary(user_id)
    rescue
      _ -> %{total_views: 0, total_shares: 0, average_quality: 0}
    end
  end

  defp get_collaboration_metrics_summary(user_id) do
    try do
      Analytics.get_collaboration_metrics_summary(user_id)
    rescue
      _ -> %{active_collaborations: 0, feedback_given: 0, feedback_received: 0}
    end
  end

  defp get_service_metrics_summary(user_id) do
    if_can_access_services(user_id, fn ->
      Analytics.get_service_metrics_summary(user_id)
    end) || %{total_bookings: 0, revenue: 0, rating: 0}
  end

  defp get_revenue_metrics_summary(user_id) do
    if_can_access_revenue(user_id, fn ->
      Analytics.get_revenue_metrics_summary(user_id)
    end) || %{total_revenue: 0, growth_rate: 0}
  end

  defp get_engagement_metrics_summary(user_id) do
    try do
      Analytics.get_engagement_metrics_summary(user_id)
    rescue
      _ -> %{community_engagement: 0, channel_participation: 0}
    end
  end

  # ============================================================================
  # UTILITY & FORMATTING FUNCTIONS
  # ============================================================================

  @doc """
  Formats currency amounts with proper symbols
  """
  def format_currency(amount, currency \\ "USD") when is_number(amount) do
    case currency do
      "USD" -> "$#{:erlang.float_to_binary(amount / 1, decimals: 2)}"
      "EUR" -> "€#{:erlang.float_to_binary(amount / 1, decimals: 2)}"
      "GBP" -> "£#{:erlang.float_to_binary(amount / 1, decimals: 2)}"
      _ -> "#{currency} #{:erlang.float_to_binary(amount / 1, decimals: 2)}"
    end
  end

  def format_currency(_, _), do: "$0.00"

  @doc """
  Formats large numbers with appropriate suffixes
  """
  def format_number(number) when is_number(number) do
    cond do
      number >= 1_000_000 -> "#{Float.round(number / 1_000_000, 1)}M"
      number >= 1_000 -> "#{Float.round(number / 1_000, 1)}K"
      true -> "#{number}"
    end
  end

  def format_number(_), do: "0"

  @doc """
  Calculates growth percentage between two values
  """
  def calculate_growth_percentage(current, previous) when is_number(current) and is_number(previous) and previous > 0 do
    growth = ((current - previous) / previous) * 100
    Float.round(growth, 1)
  end

  def calculate_growth_percentage(_, _), do: 0

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  # Access control helpers
  defp if_can_access_services(user_id, fun) do
    user = Accounts.get_user!(user_id)
    if can_access_services?(user), do: fun.(), else: nil
  end

  defp if_can_access_revenue(user_id, fun) do
    user = Accounts.get_user!(user_id)
    if can_access_revenue_center?(user), do: fun.(), else: nil
  end

  defp if_can_access_lab(user, fun) do
    if can_access_creator_lab?(user), do: fun.(), else: nil
  end

  defp if_can_access_lab_by_id(user_id, fun) do
    user = Accounts.get_user!(user_id)
    if_can_access_lab(user, fun)
  end

  # Portfolio quality assessment helpers
  defp calculate_content_completeness(sections) do
    required_sections = ["about", "experience", "projects", "skills"]
    present_sections = Enum.map(sections, & &1.section_type)
    completion_rate = length(Enum.uniq(present_sections)) / length(required_sections)
    (completion_rate * 40) |> min(40) |> round()
  end

  defp calculate_visual_quality(portfolio, sections) do
    score = 0
    score = if portfolio.hero_image_url, do: score + 8, else: score
    score = if has_consistent_theme?(portfolio), do: score + 7, else: score
    media_score = count_section_media(sections) |> min(10)
    score + media_score
  end

  defp calculate_engagement_elements(portfolio) do
    score = 0
    score = if has_voice_intro?(portfolio), do: score + 8, else: score
    score = if has_interactive_elements?(portfolio), do: score + 6, else: score
    score = if has_social_links?(portfolio), do: score + 3, else: score
    score = if has_cta?(portfolio), do: score + 3, else: score
    score
  end

  defp calculate_professional_polish(portfolio) do
    score = 0
    score = if has_custom_domain?(portfolio), do: score + 5, else: score
    score = if has_professional_contact?(portfolio), do: score + 3, else: score
    score = if has_complete_contact?(portfolio), do: score + 4, else: score
    score = if has_seo_optimization?(portfolio), do: score + 3, else: score
    score
  end

  # Feature detection helpers
  defp has_enhancements?(portfolio), do: false # Implement based on your enhancement system
  defp has_service_integration?(portfolio), do: false # Implement based on your service system
  defp has_resume_uploaded?(user), do: false # Implement based on your file system
  defp has_collaboration_setup?(portfolios), do: Enum.any?(portfolios, &has_collaborations?/1)
  defp has_service_setup?(user), do: false # Implement based on your service system
  defp has_voice_introduction?(sections), do: Enum.any?(sections, &(&1.section_type == "voice_intro"))
  defp has_consistent_theme?(portfolio), do: portfolio.theme != nil && portfolio.customization != nil
  defp has_voice_intro?(portfolio), do: false # Implement based on your voice system
  defp has_interactive_elements?(portfolio), do: false # Implement based on your interactive system
  defp has_social_links?(portfolio), do: portfolio.social_links && map_size(portfolio.social_links) > 0
  defp has_cta?(portfolio), do: portfolio.contact_info != nil
  defp has_custom_domain?(portfolio), do: false # Implement based on your domain system
  defp has_professional_contact?(portfolio), do: portfolio.contact_info != nil && portfolio.contact_info != %{}
  defp has_complete_contact?(portfolio) do
    contact = portfolio.contact_info || %{}
    Map.has_key?(contact, "email") && Map.has_key?(contact, "phone")
  end
  defp has_seo_optimization?(portfolio), do: portfolio.meta_description != nil
  defp has_social_integration?(portfolio), do: has_social_links?(portfolio)
  defp has_call_to_action?(portfolio), do: has_cta?(portfolio)

  defp assess_content_quality(sections) do
    content_sections = Enum.filter(sections, &(&1.section_type in ["about", "experience", "projects"]))
    if length(content_sections) > 0 do
      avg_length = Enum.reduce(content_sections, 0, fn section, acc ->
        content_length = get_content_length(section)
        acc + content_length
      end) / length(content_sections)
      min(avg_length / 10, 100) |> round()
    else
      0
    end
  end

  defp assess_visual_consistency(portfolio), do: has_consistent_theme?(portfolio)

  defp has_professional_media?(sections) do
    Enum.any?(sections, fn section ->
      section.content &&
      (Map.has_key?(section.content, "images") || Map.has_key?(section.content, "media"))
    end)
  end

  defp count_section_media(sections) do
    Enum.count(sections, fn section ->
      section.content &&
      (Map.has_key?(section.content, "images") ||
       Map.has_key?(section.content, "media") ||
       Map.has_key?(section.content, "hero_image"))
    end)
  end

  defp get_content_length(section) do
    case section.content do
      nil -> 0
      content when is_map(content) ->
        content
        |> Map.values()
        |> Enum.reduce(0, fn value, acc ->
          if is_binary(value), do: acc + String.length(value), else: acc
        end)
      _ -> 0
    end
  end

  defp count_completed_enhancements(portfolios) do
    # Mock implementation - count completed enhancements across portfolios
    Enum.reduce(portfolios, 0, fn portfolio, acc ->
      completed_count = :rand.uniform(4) # Mock: 0-4 completed enhancements per portfolio
      acc + completed_count
    end)
  end
end
