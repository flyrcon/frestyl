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
      "content_campaigns" -> "Content Campaigns"  # <-- ADD THIS
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
  # CHANNEL INTEGRATION
  # ============================================================================

    def get_portfolio_channel_recommendations(user, portfolios, account) do
    # Extract portfolio intelligence for recommendations
    portfolio_skills = extract_skills_from_portfolios(portfolios)
    portfolio_topics = extract_topics_from_portfolios(portfolios)
    career_level = determine_career_level_from_portfolios(portfolios)
    industry_focus = extract_industry_focus(portfolios)

    # Smart recommendation logic
    skill_based_channels = find_channels_by_skills(portfolio_skills, user.id)
    topic_related_channels = find_channels_by_topics(portfolio_topics, user.id)
    engagement_driving_channels = find_high_engagement_channels_for_level(career_level)

    # Combine and rank recommendations
    recommendations = (skill_based_channels ++ topic_related_channels ++ engagement_driving_channels)
    |> Enum.uniq_by(& &1.id)
    |> Enum.map(&add_relevance_score(&1, portfolios, user))
    |> Enum.sort_by(& &1.relevance_score, :desc)
    |> Enum.take(8)

    recommendations
  end

  defp extract_skills_from_portfolios(portfolios) do
    portfolios
    |> Enum.flat_map(fn portfolio ->
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      extract_skills_from_sections(sections)
    end)
    |> Enum.uniq()
  end

  defp extract_skills_from_sections(sections) do
    sections
    |> Enum.flat_map(fn section ->
      case section.section_type do
        "skills" -> get_nested_value(section.content, ["skills"], [])
        "projects" ->
          projects = get_nested_value(section.content, ["projects"], [])
          Enum.flat_map(projects, &get_nested_value(&1, ["technologies"], []))
        "experience" ->
          experiences = get_nested_value(section.content, ["experiences"], [])
          Enum.flat_map(experiences, &get_nested_value(&1, ["technologies"], []))
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp find_channels_by_skills(skills, user_id) do
    Channels.list_channels_by_tags(skills)
    |> Enum.reject(&Channels.user_member?(%{id: user_id}, &1))
    |> Enum.filter(&(&1.visibility in ["public", "unlisted"]))
  end

  defp add_relevance_score(channel, portfolios, user) do
    skill_match_score = calculate_skill_match_score(channel, portfolios)
    activity_score = calculate_channel_activity_score(channel)
    career_alignment_score = calculate_career_alignment_score(channel, portfolios)

    relevance_score = (skill_match_score * 0.4) + (activity_score * 0.3) + (career_alignment_score * 0.3)

    Map.put(channel, :relevance_score, relevance_score)
    |> Map.put(:recommendation_reason, generate_recommendation_reason(channel, portfolios))
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

      def create_portfolio_channel_sharing(portfolio_id, channel_id, user_id, sharing_options \\ %{}) do
    sharing_data = %{
      activity_type: :portfolio_shared,
      portfolio_id: portfolio_id,
      channel_id: channel_id,
      user_id: user_id,
      activity_data: %{
        "shared_sections" => sharing_options["sections"] || ["all"],
        "sharing_context" => sharing_options["context"] || "showcase",
        "permissions" => %{
          "can_comment" => sharing_options["allow_comments"] || true,
          "can_suggest_edits" => sharing_options["allow_edit_suggestions"] || false
        },
        "message" => sharing_options["message"] || ""
      },
      tags: extract_portfolio_tags(portfolio_id),
      visibility: sharing_options["visibility"] || :public
    }

    case Channels.create_portfolio_activity(sharing_data) do
      {:ok, activity} ->
        # Broadcast to channel members
        broadcast_portfolio_shared(activity)
        # Update portfolio hub metrics
        update_portfolio_engagement_metrics(portfolio_id, :shared)
        {:ok, activity}
      error -> error
    end
  end

  def request_portfolio_feedback(portfolio_id, channel_id, user_id, feedback_request) do
    feedback_data = %{
      activity_type: :portfolio_feedback_requested,
      portfolio_id: portfolio_id,
      channel_id: channel_id,
      user_id: user_id,
      activity_data: %{
        "feedback_type" => feedback_request["type"], # "general", "design", "content", "technical"
        "specific_areas" => feedback_request["areas"] || [],
        "deadline" => feedback_request["deadline"],
        "feedback_format" => feedback_request["format"] || "comments", # "comments", "video", "written"
        "experience_level_sought" => feedback_request["experience_level"] || "any"
      },
      tags: ["feedback", "portfolio-review"] ++ (feedback_request["additional_tags"] || []),
      visibility: :public
    }

    case Channels.create_portfolio_activity(feedback_data) do
      {:ok, activity} ->
        # Create feedback tracking record
        create_feedback_tracking(activity.id, feedback_request)
        # Notify relevant channel members
        notify_potential_reviewers(activity)
        {:ok, activity}
      error -> error
    end
  end

  def create_portfolio_channel_sharing(portfolio_id, channel_id, user_id, sharing_options) do
    sharing_data = %{
      activity_type: :portfolio_shared,
      portfolio_id: portfolio_id,
      channel_id: channel_id,
      user_id: user_id,
      activity_data: %{
        "shared_sections" => sharing_options["sections"] || ["all"],
        "sharing_context" => sharing_options["context"] || "showcase",
        "permissions" => %{
          "can_comment" => sharing_options["allow_comments"] || true,
          "can_suggest_edits" => sharing_options["allow_edit_suggestions"] || false
        },
        "message" => sharing_options["message"] || ""
      },
      tags: extract_portfolio_tags(portfolio_id),
      visibility: sharing_options["visibility"] || :public
    }

    case Channels.create_portfolio_activity(sharing_data) do
      {:ok, activity} ->
        # Broadcast to channel members
        broadcast_portfolio_shared(activity)
        # Update portfolio hub metrics
        update_portfolio_engagement_metrics(portfolio_id, :shared)
        {:ok, activity}
      error -> error
    end
  end

  def request_portfolio_feedback(portfolio_id, channel_id, user_id, feedback_request) do
    feedback_data = %{
      activity_type: :portfolio_feedback_requested,
      portfolio_id: portfolio_id,
      channel_id: channel_id,
      user_id: user_id,
      activity_data: %{
        "feedback_type" => feedback_request["type"], # "general", "design", "content", "technical"
        "specific_areas" => feedback_request["areas"] || [],
        "deadline" => feedback_request["deadline"],
        "feedback_format" => feedback_request["format"] || "comments", # "comments", "video", "written"
        "experience_level_sought" => feedback_request["experience_level"] || "any"
      },
      tags: ["feedback", "portfolio-review"] ++ (feedback_request["additional_tags"] || []),
      visibility: :public
    }

    case Channels.create_portfolio_activity(feedback_data) do
      {:ok, activity} ->
        # Create feedback tracking record
        create_feedback_tracking(activity.id, feedback_request)
        # Notify relevant channel members
        notify_potential_reviewers(activity)
        {:ok, activity}
      error -> error
    end
  end

    def create_portfolio_showcase_event(channel_id, user_id, showcase_data) do
    event_data = %{
      activity_type: :portfolio_showcase_scheduled,
      channel_id: channel_id,
      user_id: user_id,
      activity_data: %{
        "showcase_date" => showcase_data["date"],
        "showcase_type" => showcase_data["type"], # "demo", "presentation", "walkthrough"
        "duration_minutes" => showcase_data["duration"] || 30,
        "max_participants" => showcase_data["max_participants"] || 20,
        "requires_registration" => showcase_data["requires_registration"] || false,
        "showcase_description" => showcase_data["description"],
        "featured_portfolios" => showcase_data["portfolio_ids"] || []
      },
      tags: ["showcase", "demo", "portfolio-presentation"],
      visibility: :public,
      is_featured: true
    }

    case Channels.create_portfolio_activity(event_data) do
      {:ok, activity} ->
        # Create calendar event
        create_showcase_calendar_event(activity)
        # Setup streaming integration if needed
        setup_showcase_streaming(activity, showcase_data)
        # Notify channel members
        broadcast_showcase_announcement(activity)
        {:ok, activity}
      error -> error
    end
  end

  defp setup_showcase_streaming(activity, showcase_data) do
    if showcase_data["enable_streaming"] do
      streaming_config = %{
        integration_type: :portfolio_tour,
        session_duration_minutes: showcase_data["duration"] || 30,
        max_participants: showcase_data["max_participants"] || 20,
        is_public_stream: true,
        requires_payment: false
      }

      Portfolios.create_streaming_integration(streaming_config)
    end
  end

  # ============================================================================
  # ENHANCED CHANNEL METRICS FOR HUB DISPLAY
  # ============================================================================

  @doc """
  Calculate comprehensive channel metrics for hub display
  """
  def get_enhanced_channel_metrics(channel) do
    base_metrics = calculate_basic_channel_metrics(channel)
    portfolio_metrics = calculate_portfolio_specific_metrics(channel)

    Map.merge(base_metrics, portfolio_metrics)
  end

  defp calculate_portfolio_specific_metrics(channel) do
    %{
      portfolio_shares_count: count_portfolio_activities(channel.id, :portfolio_shared),
      active_feedback_sessions: count_active_feedback_sessions(channel.id),
      portfolio_collaboration_count: count_portfolio_collaborations(channel.id),
      showcase_events_count: count_upcoming_showcases(channel.id),
      member_portfolio_quality_avg: calculate_avg_member_portfolio_quality(channel.id),
      portfolio_improvement_rate: calculate_portfolio_improvement_rate(channel.id)
    }
  end

  # ============================================================================
  # INTERACTIVE MEDIA WALLS INTEGRATION
  # ============================================================================

  @doc """
  Create portfolio-focused media wall integration
  """
  def create_portfolio_media_wall_item(channel_id, user_id, media_data) do
    wall_item = %{
      media_type: media_data["type"],
      title: media_data["title"],
      description: media_data["description"],
      media_url: media_data["url"],
      thumbnail_url: media_data["thumbnail"],
      tags: media_data["tags"] ++ ["portfolio", "inspiration"],
      category: media_data["category"] || "portfolio-inspiration",
      channel_id: channel_id,
      user_id: user_id,
      metadata: %{
        "portfolio_relevance" => media_data["relevance_score"] || 1,
        "skill_areas" => media_data["skill_areas"] || [],
        "difficulty_level" => media_data["difficulty"] || "intermediate"
      }
    }

    case Channels.create_media_wall_item(wall_item) do
      {:ok, item} ->
        # Broadcast to channel
        broadcast_media_wall_update(channel_id, item)
        {:ok, item}
      error -> error
    end
  end

  # ============================================================================
  # ENHANCED USER SOCKET FOR REAL-TIME PORTFOLIO FEATURES
  # ============================================================================

  @doc """
  Enhanced real-time features for portfolio-channel integration
  """
  def setup_portfolio_channel_subscriptions(user_id) do
    # Subscribe to portfolio-specific channel activities
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:portfolio_feedback")
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:collaboration_invites")
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{user_id}:showcase_notifications")

    # Subscribe to channels user is member of
    user_channels = Channels.list_user_channels(user_id)
    Enum.each(user_channels, fn channel ->
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "channel:#{channel.id}:portfolio_activity")
    end)
  end

  # ============================================================================
  # ADDITIONAL HELPER FUNCTIONS
  # ============================================================================

  defp get_nested_value(map, keys, default \\ nil) do
    Enum.reduce(keys, map, fn key, acc ->
      if is_map(acc), do: Map.get(acc, key), else: default
    end) || default
  end

  defp broadcast_portfolio_shared(activity) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{activity.channel_id}:portfolio_activity",
      {:portfolio_shared, activity}
    )
  end

  defp broadcast_media_wall_update(channel_id, item) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{channel_id}:media_wall",
      {:media_wall_updated, item}
    )
  end

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

    defp extract_topics_from_portfolios(portfolios) do
    portfolios
    |> Enum.flat_map(fn portfolio ->
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      extract_topics_from_sections(sections)
    end)
    |> Enum.uniq()
  end

  defp extract_topics_from_sections(sections) do
    sections
    |> Enum.flat_map(fn section ->
      case section.section_type do
        "about" -> extract_keywords_from_text(get_nested_value(section.content, ["description"], ""))
        "projects" ->
          projects = get_nested_value(section.content, ["projects"], [])
          Enum.flat_map(projects, fn project ->
            description = get_nested_value(project, ["description"], "")
            extract_keywords_from_text(description)
          end)
        _ -> []
      end
    end)
    |> Enum.uniq()
  end

  defp extract_keywords_from_text(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/[^\w]+/, trim: true)
    |> Enum.filter(&(String.length(&1) > 3))
    |> Enum.take(10) # Limit to prevent overwhelming
  end
  defp extract_keywords_from_text(_), do: []

  defp determine_career_level_from_portfolios(portfolios) do
    experience_indicators = portfolios
    |> Enum.flat_map(fn portfolio ->
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      extract_experience_indicators(sections)
    end)

    years_of_experience = calculate_total_experience_years(experience_indicators)
    project_complexity = calculate_project_complexity_score(experience_indicators)

    cond do
      years_of_experience < 2 -> "entry"
      years_of_experience < 5 -> "mid"
      years_of_experience < 10 -> "senior"
      project_complexity > 8 -> "lead"
      true -> "senior"
    end
  end

  defp extract_experience_indicators(sections) do
    sections
    |> Enum.flat_map(fn section ->
      case section.section_type do
        "experience" -> get_nested_value(section.content, ["experiences"], [])
        "projects" -> get_nested_value(section.content, ["projects"], [])
        _ -> []
      end
    end)
  end

  defp calculate_total_experience_years(indicators) do
    # Simple heuristic based on number of experiences/projects
    length(indicators) * 1.5 # Rough estimate
  end

  defp calculate_project_complexity_score(indicators) do
    indicators
    |> Enum.map(fn item ->
      tech_count = length(get_nested_value(item, ["technologies"], []))
      team_size = get_nested_value(item, ["team_size"], 1)
      tech_count + (team_size * 0.5)
    end)
    |> Enum.sum()
    |> div(max(length(indicators), 1))
  end

  defp extract_industry_focus(portfolios) do
    portfolios
    |> Enum.map(fn portfolio ->
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      extract_industry_from_projects(sections)
    end)
    |> List.flatten()
    |> Enum.frequencies()
    |> Enum.max_by(fn {_industry, count} -> count end, fn -> {"general", 1} end)
    |> elem(0)
  end

  defp extract_industry_from_projects(sections) do
    sections
    |> Enum.flat_map(fn section ->
      case section.section_type do
        "projects" ->
          projects = get_nested_value(section.content, ["projects"], [])
          Enum.map(projects, &classify_project_industry/1)
        _ -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp classify_project_industry(project) do
    description = get_nested_value(project, ["description"], "")
    title = get_nested_value(project, ["title"], "")
    text = "#{title} #{description}" |> String.downcase()

    cond do
      String.contains?(text, ["ecommerce", "retail", "shopping"]) -> "retail"
      String.contains?(text, ["fintech", "banking", "payment"]) -> "fintech"
      String.contains?(text, ["health", "medical", "healthcare"]) -> "healthcare"
      String.contains?(text, ["education", "learning", "course"]) -> "education"
      String.contains?(text, ["game", "gaming", "entertainment"]) -> "gaming"
      true -> "general"
    end
  end

  # Channel matching functions
  defp find_channels_by_topics(topics, user_id) do
    # This would need to be implemented in the Channels context
    try do
      Channels.find_channels_by_topics(topics)
      |> Enum.reject(&Channels.user_member?(%{id: user_id}, &1))
    rescue
      _ -> []
    end
  end

  defp find_high_engagement_channels_for_level(career_level) do
    try do
      Channels.get_high_engagement_channels_for_career_level(career_level)
    rescue
      _ -> []
    end
  end

  # Scoring functions
  defp calculate_skill_match_score(channel, portfolios) do
    channel_tags = channel.tags || []
    portfolio_skills = extract_skills_from_portfolios(portfolios)

    matching_skills = Enum.count(channel_tags, &(&1 in portfolio_skills))
    total_channel_tags = max(length(channel_tags), 1)

    (matching_skills / total_channel_tags) * 10
  end

  defp calculate_channel_activity_score(channel) do
    # Base score on recent activity
    recent_activity_count = try do
      Channels.count_recent_activity(channel.id, hours: 24)
    rescue
      _ -> 0
    end

    member_count = try do
      Channels.get_member_count(channel.id)
    rescue
      _ -> 0
    end

    activity_ratio = if member_count > 0, do: recent_activity_count / member_count, else: 0
    min(activity_ratio * 10, 10)
  end

  defp calculate_career_alignment_score(channel, portfolios) do
    career_level = determine_career_level_from_portfolios(portfolios)
    channel_level_focus = determine_channel_career_focus(channel)

    case {career_level, channel_level_focus} do
      {level, level} -> 10 # Perfect match
      {"entry", "beginner"} -> 9
      {"mid", "intermediate"} -> 9
      {"senior", "advanced"} -> 9
      {"lead", "advanced"} -> 8
      _ -> 5 # Default moderate alignment
    end
  end

  defp determine_channel_career_focus(channel) do
    description = channel.description || ""
    tags = channel.tags || []
    text = "#{description} #{Enum.join(tags, " ")}" |> String.downcase()

    cond do
      String.contains?(text, ["beginner", "entry", "junior", "learning"]) -> "beginner"
      String.contains?(text, ["senior", "lead", "expert", "advanced"]) -> "advanced"
      String.contains?(text, ["intermediate", "mid-level"]) -> "intermediate"
      true -> "general"
    end
  end

  defp generate_recommendation_reason(channel, portfolios) do
    portfolio_skills = extract_skills_from_portfolios(portfolios)
    channel_tags = channel.tags || []
    matching_skills = Enum.filter(channel_tags, &(&1 in portfolio_skills))

    cond do
      length(matching_skills) > 2 ->
        "Strong skill match: #{Enum.take(matching_skills, 3) |> Enum.join(", ")}"
      length(matching_skills) > 0 ->
        "Skill alignment: #{Enum.join(matching_skills, ", ")}"
      true ->
        "Active community for your career level"
    end
  end

  # Portfolio and engagement functions
  defp extract_portfolio_tags(portfolio_id) do
    try do
      portfolio = Portfolios.get_portfolio!(portfolio_id)
      sections = Portfolios.list_portfolio_sections(portfolio_id)
      skills = extract_skills_from_sections(sections)
      topics = extract_topics_from_sections(sections)

      (skills ++ topics)
      |> Enum.uniq()
      |> Enum.take(10)
    rescue
      _ -> ["portfolio", "showcase"]
    end
  end

  defp update_portfolio_engagement_metrics(portfolio_id, action) do
    try do
      # This would update engagement tracking
      Analytics.track_portfolio_engagement(portfolio_id, action)
    rescue
      _ -> :ok
    end
  end

  defp notify_potential_reviewers(activity) do
    try do
      # Send notifications to qualified reviewers
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "channel:#{activity.channel_id}:feedback_requests",
        {:new_feedback_request, activity}
      )
    rescue
      _ -> :ok
    end
  end

  # Showcase functions
  defp create_showcase_calendar_event(activity) do
    try do
      showcase_data = activity.activity_data

      # Create calendar event (would integrate with calendar system)
      Calendar.create_event(%{
        title: "Portfolio Showcase",
        start_time: showcase_data["showcase_date"],
        duration: showcase_data["duration_minutes"] || 30,
        description: showcase_data["showcase_description"],
        channel_id: activity.channel_id
      })
    rescue
      _ -> :ok
    end
  end

  defp broadcast_showcase_announcement(activity) do
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "channel:#{activity.channel_id}:announcements",
      {:showcase_scheduled, activity}
    )
  end

  # Metrics calculation functions
  defp calculate_basic_channel_metrics(channel) do
    %{
      member_count: get_channel_member_count(channel.id),
      activity_score: calculate_channel_activity_score(channel),
      engagement_rate: calculate_engagement_rate(channel.id)
    }
  end

  defp get_channel_member_count(channel_id) do
    try do
      Channels.get_member_count(channel_id)
    rescue
      _ -> 0
    end
  end

  defp calculate_engagement_rate(channel_id) do
    try do
      member_count = Channels.get_member_count(channel_id)
      active_members = Channels.count_active_members(channel_id, days: 7)
      if member_count > 0, do: active_members / member_count, else: 0
    rescue
      _ -> 0
    end
  end

  defp count_portfolio_activities(channel_id, activity_type) do
    try do
      Channels.count_activities_by_type(channel_id, activity_type)
    rescue
      _ -> 0
    end
  end

  defp count_active_feedback_sessions(channel_id) do
    try do
      Channels.count_active_feedback_sessions(channel_id)
    rescue
      _ -> 0
    end
  end

  defp count_portfolio_collaborations(channel_id) do
    try do
      Channels.count_portfolio_collaborations(channel_id)
    rescue
      _ -> 0
    end
  end

  defp count_upcoming_showcases(channel_id) do
    try do
      Channels.count_upcoming_showcases(channel_id)
    rescue
      _ -> 0
    end
  end

  defp calculate_avg_member_portfolio_quality(channel_id) do
    try do
      member_portfolios = Channels.get_member_portfolios(channel_id)

      if length(member_portfolios) > 0 do
        total_quality = member_portfolios
        |> Enum.map(&calculate_portfolio_quality_score/1)
        |> Enum.map(& &1[:total])
        |> Enum.sum()

        total_quality / length(member_portfolios)
      else
        0
      end
    rescue
      _ -> 0
    end
  end

  defp calculate_portfolio_improvement_rate(channel_id) do
    try do
      # Calculate how much member portfolios have improved over time
      member_ids = Channels.get_channel_member_ids(channel_id)

      improvements = member_ids
      |> Enum.map(&calculate_user_portfolio_improvement/1)
      |> Enum.reject(&is_nil/1)

      if length(improvements) > 0 do
        Enum.sum(improvements) / length(improvements)
      else
        0
      end
    rescue
      _ -> 0
    end
  end

  defp calculate_user_portfolio_improvement(user_id) do
    # This would track portfolio quality changes over time
    # Simplified implementation
    try do
      portfolios = Portfolios.list_user_portfolios(user_id)
      # Return improvement percentage (simplified)
      if length(portfolios) > 0, do: 5.0, else: 0.0
    rescue
      _ -> 0.0
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


@doc """
Gets content campaigns overview for dashboard.
"""
def get_campaigns_overview(user_id) do
  campaigns = Frestyl.DataCampaigns.list_user_campaigns(user_id)

  %{
    total_campaigns: length(campaigns),
    active_campaigns: Enum.count(campaigns, &(&1.status in [:active, :open])),
    completed_campaigns: Enum.count(campaigns, &(&1.status == :completed)),
    total_revenue: calculate_user_campaign_revenue(campaigns, user_id),
    recent_activity: get_recent_campaign_activity(user_id)
  }
end

@doc """
Gets campaign contribution summary for a user.
"""
def get_user_contribution_summary(campaign, user_id) do
  tracker = Frestyl.DataCampaigns.get_campaign_tracker(campaign.id)

  case tracker do
    {:ok, tracker_data} ->
      metrics = tracker_data.contribution_metrics

      %{
        word_count: get_in(metrics, [:word_count_by_user, user_id]) || 0,
        media_contributions: get_in(metrics, [:media_contributions, user_id]) || 0,
        peer_review_score: get_in(metrics, [:peer_review_scores, user_id]) || 0.0,
        revenue_percentage: get_in(tracker_data, [:dynamic_revenue_weights, user_id]) || 0.0,
        last_contribution: get_last_contribution_date(campaign.id, user_id)
      }

    _ ->
      %{word_count: 0, media_contributions: 0, peer_review_score: 0.0, revenue_percentage: 0.0}
  end
end

@doc"""
Check s if user can access content campaigns feature.
"""
def can_access_content_campaigns?(account) do
  Frestyl.Features.FeatureGate.can_access_feature?(account, :content_campaigns)
end

@doc """
Gets campaign limits based on account tier.
"""
def get_content_campaign_limits(account) do
  case account.subscription_tier do
    :creator -> %{concurrent_campaigns: 3, max_contributors: 10, revenue_sharing: true}
    :professional -> %{concurrent_campaigns: 10, max_contributors: 25, revenue_sharing: true}
    :enterprise -> %{concurrent_campaigns: :unlimited, max_contributors: 50, revenue_sharing: true}
    _ -> %{concurrent_campaigns: 1, max_contributors: 3, revenue_sharing: false}
  end
end

# Private helper functions
defp calculate_user_campaign_revenue(campaigns, user_id) do
  campaigns
  |> Enum.filter(&(&1.status == :completed))
  |> Enum.reduce(Decimal.new("0.0"), fn campaign, acc ->
    user_share = get_in(campaign.revenue_splits, [to_string(user_id)]) || 0.0
    campaign_revenue = campaign.revenue_target || Decimal.new("0.0")

    user_revenue = Decimal.mult(campaign_revenue, Decimal.from_float(user_share / 100))
    Decimal.add(acc, user_revenue)
  end)
end

defp get_recent_campaign_activity(user_id) do
  # Implementation would get recent activity from campaign metrics
  []
end

defp get_last_contribution_date(campaign_id, user_id) do
  # Implementation would get last contribution timestamp
  nil
end


  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================



  defp create_feedback_tracking(activity_id, feedback_request) do
    Channels.create_feedback_session(%{
      activity_id: activity_id,
      status: "open",
      deadline: feedback_request["deadline"],
      feedback_received_count: 0,
      target_feedback_count: feedback_request["target_reviewers"] || 3
    })
  end

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
