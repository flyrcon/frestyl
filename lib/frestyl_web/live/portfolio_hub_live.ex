# lib/frestyl_web/live/portfolio_hub_live.ex - COMPREHENSIVE CREATOR COMMAND CENTER

defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  alias Frestyl.{Accounts, Portfolios, Channels, Billing, Lab, Features, Analytics, Studio, Services, Revenue}
  alias FrestylWeb.PortfolioHubLive.{Helpers, EnhancementEngine, Components}

 @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user

    # REPLACE THIS LINE:
    # account = user.account || %{subscription_tier: "personal"}
    # WITH THESE LINES:
    accounts = Accounts.list_user_accounts(user.id)
    current_account = List.first(accounts) || %{subscription_tier: "personal"}
    account = current_account  # Keep existing variable for backward compatibility

    # ============================================================================
    # CORE DATA LOADING (Existing functionality maintained)
    # ============================================================================

    # Portfolio data (existing)
    portfolios = safe_load_portfolios(user.id)
    limits = safe_load_limits(user)
    portfolio_stats = calculate_portfolio_stats(portfolios)
    enhancement_suggestions = generate_enhancement_suggestions(portfolios, user)

    # User overview and activity (existing)
    overview = safe_get_user_overview(user.id)
    recent_activity = get_enhanced_activity_feed(user.id)
    collaboration_requests = Helpers.get_collaboration_requests(user.id)

    # Onboarding state (existing)
    is_first_visit = check_first_visit(user, params)
    just_completed_onboarding = Map.get(params, "welcome") == "true"
    recently_created_portfolio = get_recently_created_portfolio(portfolios)
    onboarding_state = Helpers.get_onboarding_state(user, portfolios, limits)

    # ============================================================================
    # FEATURE SECTION DATA LOADING (Equal Prominence)
    # ============================================================================

    # 1. PORTFOLIO STUDIO DATA (Enhanced existing)
    studio_data = load_studio_data(user, portfolios, account)

    # 2. COLLABORATION HUB DATA (Enhanced existing)
    collaboration_data = load_collaboration_data(user, account)

    # 3. COMMUNITY CHANNELS DATA (Enhanced existing)
    channels_data = load_channels_data(user, account)

    # 4. CREATOR LAB DATA (Re-enabled and enhanced)
    lab_data = load_lab_data(user, portfolios, account)

    # 5. SERVICE DASHBOARD DATA (NEW - Creator+ tiers only)
    service_data = load_service_data(user, account)

    # 6. REVENUE CENTER DATA (NEW - Professional+ tiers only)
    revenue_data = load_revenue_data(user, account)

    # ============================================================================
    # HUB CUSTOMIZATION BASED ON SUBSCRIPTION TIER
    # ============================================================================

    hub_config = configure_hub_for_subscription(account.subscription_tier)
    quick_actions = generate_quick_actions(user, account, portfolios)

    # ============================================================================
    # MOBILE STATE MANAGEMENT (Existing functionality maintained)
    # ============================================================================

    mobile_state = assign_mobile_state()

    # ============================================================================
    # SOCKET ASSIGNMENT - Comprehensive Creator Command Center
    # ============================================================================

    socket =
      socket
      |> assign(:page_title, "Creator Hub")

      # ======== CORE DATA ========
      |> assign(:user, user)
      |> assign(:account, account)
      |> assign(:current_account, current_account)
      |> assign(:accounts, accounts)
      |> assign(:limits, limits)
      |> assign(:hub_config, hub_config)
      |> assign(:quick_actions, quick_actions)

      # ======== PORTFOLIO STUDIO SECTION ========
      |> assign(:portfolios, portfolios)
      |> assign(:portfolio_stats, portfolio_stats)
      |> assign(:enhancement_suggestions, enhancement_suggestions)
      |> assign(:studio_data, studio_data)

      # ======== COLLABORATION HUB SECTION ========
      |> assign(:collaboration_requests, collaboration_requests)
      |> assign(:collaboration_data, collaboration_data)
      |> assign(:active_collaborations, collaboration_data.active_collaborations)
      |> assign(:collaboration_opportunities, collaboration_data.opportunities)

      # ======== COMMUNITY CHANNELS SECTION ========
      |> assign(:user_channels, channels_data.user_channels)
      |> assign(:trending_channels, channels_data.trending)
      |> assign(:channel_recommendations, channels_data.recommendations)
      |> assign(:featured_creators, channels_data.featured_creators)

      # ======== CREATOR LAB SECTION ========
      |> assign(:lab_features, lab_data.features)
      |> assign(:active_experiments, lab_data.active_experiments)
      |> assign(:lab_recommendations, lab_data.recommendations)
      |> assign(:experiment_results, lab_data.results)

      # ======== SERVICE DASHBOARD SECTION (Creator+ only) ========
      |> assign(:service_data, service_data)
      |> assign(:active_bookings, service_data.active_bookings)
      |> assign(:service_performance, service_data.performance)
      |> assign(:upcoming_appointments, service_data.upcoming_appointments)
      |> assign(:service_revenue, service_data.revenue)

      # ======== REVENUE CENTER SECTION (Professional+ only) ========
      |> assign(:revenue_data, revenue_data)
      |> assign(:portfolio_performance, revenue_data.portfolio_performance)
      |> assign(:total_revenue, revenue_data.total_revenue)
      |> assign(:revenue_trends, revenue_data.trends)
      |> assign(:platform_fees, revenue_data.platform_fees)
      |> assign(:payout_schedule, revenue_data.payout_schedule)

      # ======== USER JOURNEY & ONBOARDING ========
      |> assign(:recent_activity, recent_activity)
      |> assign(:onboarding_state, onboarding_state)
      |> assign(:is_first_visit, is_first_visit)
      |> assign(:just_completed_onboarding, just_completed_onboarding)
      |> assign(:recently_created_portfolio, recently_created_portfolio)
      |> assign(:show_welcome_celebration, just_completed_onboarding)

      # ======== UI STATE MANAGEMENT ========
      |> assign(:view_mode, "sections") # "sections", "grid", "list"
      |> assign(:active_section, determine_default_section(account.subscription_tier))
      |> assign(:filter_status, "all")
      |> assign(:show_create_modal, false)
      |> assign(:show_collaboration_panel, false)
      |> assign(:show_studio_modal, false)
      |> assign(:show_lab_modal, false)
      |> assign(:show_channels_modal, false)
      |> assign(:show_service_modal, false)
      |> assign(:show_revenue_modal, false)
      |> assign(:selected_enhancement, nil)
      |> assign(:studio_mode, nil)

      # ======== MOBILE STATE ========
      |> Map.merge(mobile_state)

    {:ok, socket}
  end

  # ============================================================================
  # DATA LOADING FUNCTIONS - Equal Feature Prominence
  # ============================================================================

  defp load_studio_data(user, portfolios, account) do
    %{
      total_portfolios: length(portfolios),
      published_count: Enum.count(portfolios, &(&1.visibility == :public)),
      draft_count: Enum.count(portfolios, &(&1.visibility == :private)),
      templates_available: get_available_templates_count(account),
      enhancement_progress: get_enhancement_progress(portfolios),
      creation_limits: get_creation_limits(account),
      recent_creations: get_recent_portfolio_activity(user.id)
    }
  end

  defp load_collaboration_data(user, account) do
    %{
      active_collaborations: safe_get_active_collaborations(user.id),
      pending_invites: safe_get_pending_invites(user.id),
      opportunities: safe_get_collaboration_opportunities(user, account),
      collaboration_stats: safe_get_collaboration_stats(user.id),
      mentor_access: Features.FeatureGate.can_access_feature?(account, :mentor_access),
      peer_network: safe_get_peer_network(user.id),
      feedback_received: safe_get_recent_feedback(user.id)
    }
  end

  defp load_channels_data(user, account) do
    %{
      user_channels: safe_get_user_channels(user),
      trending: safe_get_trending_channels(user),
      recommendations: safe_get_channel_recommendations(user),
      featured_creators: safe_get_featured_creators(user),
      community_activity: safe_get_community_activity(user.id),
      channel_limits: get_channel_limits(account),
      discovery_feed: safe_get_discovery_feed(user.id)
    }
  end

  defp load_lab_data(user, portfolios, account) do
    if Features.FeatureGate.can_access_feature?(account, :creator_lab) do
      %{
        features: safe_get_lab_features(user, account),
        active_experiments: safe_get_active_experiments(user.id),
        recommendations: safe_get_lab_recommendations(user, portfolios),
        results: safe_get_experiment_results(user.id),
        beta_access: get_beta_features(account),
        ai_insights: safe_get_ai_insights(user.id),
        feature_requests: safe_get_feature_requests(user.id)
      }
    else
      %{
        features: [],
        active_experiments: [],
        recommendations: [],
        results: [],
        beta_access: [],
        ai_insights: %{},
        feature_requests: [],
        upgrade_prompt: true
      }
    end
  end

  defp load_service_data(user, account) do
    if Features.FeatureGate.can_access_feature?(account, :service_dashboard) do
      %{
        active_bookings: safe_get_active_service_bookings(user.id),
        upcoming_appointments: safe_get_upcoming_appointments(user.id),
        service_performance: safe_get_service_performance(user.id),
        revenue: safe_get_service_revenue(user.id),
        client_management: safe_get_client_data(user.id),
        calendar_integration: check_calendar_integration(user.id),
        service_offerings: safe_get_user_services(user.id),
        booking_settings: safe_get_booking_settings(user.id)
      }
    else
      %{
        active_bookings: [],
        upcoming_appointments: [],
        service_performance: %{},
        revenue: %{total: 0, this_month: 0},
        client_management: %{},
        calendar_integration: false,
        service_offerings: [],
        booking_settings: %{},
        upgrade_prompt: true,
        tier_required: "creator"
      }
    end
  end

  defp load_revenue_data(user, account) do
    if Features.FeatureGate.can_access_feature?(account, :revenue_center) do
      %{
        total_revenue: safe_get_total_revenue(user.id),
        portfolio_performance: safe_get_portfolio_revenue_performance(user.id),
        trends: safe_get_revenue_trends(user.id),
        platform_fees: safe_get_platform_fees(user.id),
        payout_schedule: safe_get_payout_schedule(user.id),
        analytics: safe_get_revenue_analytics(user.id),
        tax_documents: safe_get_tax_documents(user.id),
        billing_integration: check_billing_integration(user.id)
      }
    else
      %{
        total_revenue: %{amount: 0, currency: "USD"},
        portfolio_performance: [],
        trends: [],
        platform_fees: %{},
        payout_schedule: %{},
        analytics: %{},
        tax_documents: [],
        billing_integration: false,
        upgrade_prompt: true,
        tier_required: "professional"
      }
    end
  end

  # ============================================================================
  # HUB CONFIGURATION BASED ON SUBSCRIPTION TIER
  # ============================================================================

  defp configure_hub_for_subscription(tier) do
    case tier do
      "personal" ->
        %{
          primary_sections: ["portfolio_studio", "collaboration_hub"],
          secondary_sections: ["community_channels"],
          hidden_sections: ["service_dashboard", "revenue_center"],
          upgrade_prompts: ["creator_lab", "service_dashboard", "revenue_center"],
          max_portfolios: 3,
          collaboration_limits: %{max_active: 2},
          feature_focus: "portfolio_creation"
        }

      "creator" ->
        %{
          primary_sections: ["portfolio_studio", "service_dashboard", "collaboration_hub"],
          secondary_sections: ["community_channels", "creator_lab"],
          hidden_sections: ["revenue_center"],
          upgrade_prompts: ["revenue_center"],
          max_portfolios: 10,
          collaboration_limits: %{max_active: 10},
          feature_focus: "service_offering"
        }

      "professional" ->
        %{
          primary_sections: ["revenue_center", "service_dashboard", "portfolio_studio"],
          secondary_sections: ["creator_lab", "collaboration_hub", "community_channels"],
          hidden_sections: [],
          upgrade_prompts: [],
          max_portfolios: -1,
          collaboration_limits: %{max_active: -1},
          feature_focus: "revenue_optimization"
        }

      "enterprise" ->
        %{
          primary_sections: ["revenue_center", "service_dashboard", "portfolio_studio", "creator_lab"],
          secondary_sections: ["collaboration_hub", "community_channels"],
          hidden_sections: [],
          upgrade_prompts: [],
          max_portfolios: -1,
          collaboration_limits: %{max_active: -1},
          feature_focus: "team_management",
          enterprise_features: ["white_label", "api_access", "custom_domains"]
        }

      _ -> configure_hub_for_subscription("personal")
    end
  end

  defp determine_default_section(tier) do
    case tier do
      "personal" -> "portfolio_studio"
      "creator" -> "service_dashboard"
      "professional" -> "revenue_center"
      "enterprise" -> "revenue_center"
      _ -> "portfolio_studio"
    end
  end

  defp generate_quick_actions(user, account, portfolios) do
    base_actions = [
      %{
        id: "create_portfolio",
        title: "Create Portfolio",
        icon: "🎨",
        description: "Start a new portfolio",
        action: "show_create_modal",
        priority: 1
      }
    ]

    tier_actions = case account.subscription_tier do
      "creator" ->
        [
          %{
            id: "setup_service",
            title: "Setup Service",
            icon: "💼",
            description: "Create service offering",
            action: "setup_service",
            priority: 2
          }
        ]

      "professional" ->
        [
          %{
            id: "view_analytics",
            title: "Revenue Analytics",
            icon: "📊",
            description: "View performance data",
            action: "show_revenue_modal",
            priority: 1
          }
        ]

      _ -> []
    end

    smart_actions = generate_smart_recommendations(user, portfolios, account)

    (base_actions ++ tier_actions ++ smart_actions)
    |> Enum.sort_by(& &1.priority)
    |> Enum.take(6)
  end

  defp generate_smart_recommendations(user, portfolios, account) do
    recommendations = []

    # Portfolio enhancement suggestions
    recommendations = if length(portfolios) > 0 do
      incomplete_portfolios = Enum.filter(portfolios, &portfolio_needs_work?/1)
      if length(incomplete_portfolios) > 0 do
        [%{
          id: "enhance_portfolio",
          title: "Enhance Portfolio",
          icon: "✨",
          description: "Improve portfolio quality",
          action: "enhance_portfolio",
          priority: 3
        } | recommendations]
      else
        recommendations
      end
    else
      recommendations
    end

    # Collaboration suggestions
    recommendations = if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
      [%{
        id: "find_collaborators",
        title: "Find Collaborators",
        icon: "🤝",
        description: "Connect with other creators",
        action: "show_collaboration_panel",
        priority: 4
      } | recommendations]
    else
      recommendations
    end

    recommendations
  end

  defp get_portfolio_user_account(portfolio) do
    cond do
      portfolio.user_id ->
        case Accounts.get_user(portfolio.user_id) do
          nil -> nil
          user ->
            accounts = Accounts.list_user_accounts(user.id)
            List.first(accounts)
        end

      true ->
        nil
    end
  end

  defp ensure_current_account(socket) do
    case socket.assigns[:current_account] do
      nil ->
        user = socket.assigns.current_user
        accounts = Accounts.list_user_accounts(user.id)
        current_account = List.first(accounts) || %{subscription_tier: "free"}
        assign(socket, :current_account, current_account)

      _account ->
        socket
    end
  end

  # ============================================================================
  # SAFE DATA LOADING FUNCTIONS (Error Handling)
  # ============================================================================

  defp safe_load_portfolios(user_id) do
    try do
      Portfolios.list_user_portfolios(user_id)
    rescue
      _ -> []
    end
  end

  defp safe_load_limits(user) do
    try do
      Portfolios.get_portfolio_limits(user)
    rescue
      _ -> %{max_portfolios: 3, max_media_size_mb: 50}
    end
  end

  defp safe_get_user_overview(user_id) do
    try do
      Portfolios.get_user_portfolio_overview(user_id)
    rescue
      _ -> %{total_visits: 0, total_portfolios: 0, total_shares: 0}
    end
  end

  defp safe_get_active_collaborations(user_id) do
    try do
      # Use existing collaboration infrastructure
      Channels.get_user_active_collaborations(user_id)
    rescue
      _ -> []
    end
  end

  defp safe_get_user_channels(user) do
    try do
      Channels.get_user_channels(user)
    rescue
      _ -> []
    end
  end

  defp safe_get_lab_features(user, account) do
    try do
      Lab.get_available_features(user, account)
    rescue
      _ -> []
    end
  end

  defp safe_get_active_service_bookings(user_id) do
    try do
      Services.get_active_bookings(user_id)
    rescue
      _ -> []
    end
  end

  defp safe_get_total_revenue(user_id) do
    try do
      Revenue.get_total_user_revenue(user_id)
    rescue
      _ -> %{amount: 0, currency: "USD"}
    end
  end

  # Add more safe_get functions for other data sources...
  defp safe_get_pending_invites(user_id), do: []
  defp safe_get_collaboration_opportunities(user, account), do: []
  defp safe_get_collaboration_stats(user_id), do: %{}
  defp safe_get_peer_network(user_id), do: []
  defp safe_get_recent_feedback(user_id), do: []
  defp safe_get_trending_channels(user), do: []
  defp safe_get_channel_recommendations(user), do: []
  defp safe_get_featured_creators(user), do: []
  defp safe_get_community_activity(user_id), do: []
  defp safe_get_discovery_feed(user_id), do: []
  defp safe_get_active_experiments(user_id), do: []
  defp safe_get_lab_recommendations(user, portfolios), do: []
  defp safe_get_experiment_results(user_id), do: []
  defp safe_get_ai_insights(user_id), do: %{}
  defp safe_get_feature_requests(user_id), do: []
  defp safe_get_upcoming_appointments(user_id), do: []
  defp safe_get_service_performance(user_id), do: %{}
  defp safe_get_service_revenue(user_id), do: %{total: 0, this_month: 0}
  defp safe_get_client_data(user_id), do: %{}
  defp safe_get_user_services(user_id), do: []
  defp safe_get_booking_settings(user_id), do: %{}
  defp safe_get_portfolio_revenue_performance(user_id), do: []
  defp safe_get_revenue_trends(user_id), do: []
  defp safe_get_platform_fees(user_id), do: %{}
  defp safe_get_payout_schedule(user_id), do: %{}
  defp safe_get_revenue_analytics(user_id), do: %{}
  defp safe_get_tax_documents(user_id), do: []

  # ============================================================================
  # HELPER FUNCTIONS (Maintained from existing)
  # ============================================================================

  defp calculate_portfolio_stats(portfolios) do
    Enum.map(portfolios, fn portfolio ->
      stats = try do
        Portfolios.get_portfolio_analytics(portfolio.id, portfolio.user_id)
      rescue
        _ -> %{total_visits: 0, unique_visitors: 0, last_visit: nil}
      end
      {portfolio.id, stats}
    end) |> Enum.into(%{})
  end

  defp generate_enhancement_suggestions(portfolios, user) do
    case portfolios do
      [] ->
        []

      portfolios ->
        portfolios
        |> Enum.take(3)
        |> Enum.flat_map(fn portfolio ->
          quality_score = calculate_portfolio_quality_score(portfolio)
          generate_portfolio_enhancement_suggestions(portfolio, quality_score, user)
        end)
        |> Enum.sort_by(& &1.priority, :desc)
        |> Enum.take(5)
    end
  end

  defp calculate_portfolio_quality_score(portfolio) do
    sections = try do
      Portfolios.list_portfolio_sections(portfolio.id)
    rescue
      _ -> []
    end

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

  defp generate_portfolio_enhancement_suggestions(portfolio, quality_score, user) do
    suggestions = []

    suggestions = if needs_voice_enhancement?(portfolio, quality_score) do
      [%{
        type: :voice_over,
        portfolio_id: portfolio.id,
        title: "Add Voice Introduction",
        description: "Record a professional voice introduction to make your portfolio more engaging",
        priority: get_enhancement_priority(quality_score, :voice),
        estimated_time: "15-30 minutes",
        can_access: can_access_enhancement?(user, :voice_over)
      } | suggestions]
    else
      suggestions
    end

    suggestions = if needs_writing_enhancement?(portfolio, quality_score) do
      [%{
        type: :writing,
        portfolio_id: portfolio.id,
        title: "Improve Content Quality",
        description: "Enhance your portfolio sections with professional writing assistance",
        priority: get_enhancement_priority(quality_score, :writing),
        estimated_time: "30-60 minutes",
        can_access: can_access_enhancement?(user, :writing)
      } | suggestions]
    else
      suggestions
    end

    suggestions = if needs_design_enhancement?(portfolio, quality_score) do
      [%{
        type: :design,
        portfolio_id: portfolio.id,
        title: "Visual Design Upgrade",
        description: "Improve the visual appeal and consistency of your portfolio",
        priority: get_enhancement_priority(quality_score, :design),
        estimated_time: "45-90 minutes",
        can_access: can_access_enhancement?(user, :design)
      } | suggestions]
    else
      suggestions
    end

    suggestions = if needs_music_enhancement?(portfolio, quality_score) do
      [%{
        type: :music,
        portfolio_id: portfolio.id,
        title: "Add Background Music",
        description: "Enhance your portfolio with subtle background music or sound design",
        priority: get_enhancement_priority(quality_score, :music),
        estimated_time: "20-40 minutes",
        can_access: can_access_enhancement?(user, :music)
      } | suggestions]
    else
      suggestions
    end

    suggestions
  end

  defp needs_voice_enhancement?(portfolio, quality_score) do
    !quality_score.breakdown.has_voice_intro &&
    quality_score.content >= 20 # Only suggest if portfolio has basic content
  end

  defp needs_writing_enhancement?(portfolio, quality_score) do
    quality_score.breakdown.content_quality < 15 &&
    quality_score.total < 60
  end

  defp needs_design_enhancement?(portfolio, quality_score) do
    quality_score.visual < 15 ||
    !quality_score.breakdown.visual_consistency
  end

  defp needs_music_enhancement?(portfolio, quality_score) do
    quality_score.total >= 50 && # Only for already decent portfolios
    quality_score.breakdown.engagement_elements < 2
  end

  defp get_enhancement_priority(quality_score, enhancement_type) do
    base_priority = case enhancement_type do
      :voice -> if quality_score.total >= 40, do: 90, else: 60
      :writing -> if quality_score.content < 20, do: 95, else: 70
      :design -> if quality_score.visual < 15, do: 85, else: 50
      :music -> if quality_score.total >= 60, do: 75, else: 30
    end

    # Boost priority based on portfolio completion
    completion_boost = if quality_score.total >= 70, do: 10, else: 0
    base_priority + completion_boost
  end

  # Helper functions for quality assessment:
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
    score = if has_voice_intro?(portfolio), do: score + 5, else: score
    score = if has_social_links?(portfolio), do: score + 3, else: score
    score = if has_cta?(portfolio), do: score + 4, else: score
    score = if has_interactive_elements?(portfolio), do: score + 8, else: score
    score
  end

  defp calculate_professional_polish(portfolio) do
    score = 0
    score = if has_custom_domain?(portfolio), do: score + 5, else: score
    score = if has_professional_contact?(portfolio), do: score + 3, else: score
    score = if has_complete_contact?(portfolio), do: score + 2, else: score
    score = if has_seo_optimization?(portfolio), do: score + 5, else: score
    score
  end


  defp can_access_enhancement?(current_account, enhancement_type) do
    case enhancement_type do
      :voice_over ->
        Features.FeatureGate.can_access_feature?(current_account, :voice_recording)
      :writing ->
        Features.FeatureGate.can_access_feature?(current_account, :content_assistance)
      :design ->
        Features.FeatureGate.can_access_feature?(current_account, :advanced_media)
      :music ->
        Features.FeatureGate.can_access_feature?(current_account, :audio_creation)
      _ ->
        true
    end
  end

  defp can_access_collaboration?(current_account, collaboration_type) do
    account = current_account || %{subscription_tier: "personal"}

    case collaboration_type do
      :portfolio_voice_over ->
        Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) &&
        Features.FeatureGate.can_access_feature?(account, :voice_recording)

      :portfolio_writing ->
        Features.FeatureGate.can_access_feature?(account, :real_time_collaboration)

      :portfolio_design ->
        Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) &&
        Features.FeatureGate.can_access_feature?(account, :advanced_media)

      :portfolio_music ->
        Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) &&
        Features.FeatureGate.can_access_feature?(account, :audio_creation)

      _ ->
        false
    end
  end



  defp send_enhancement_invitations(channel, enhancement_type, current_account) do
    # Check if user wants to invite service providers
    if Features.FeatureGate.can_access_feature?(current_account, :service_provider_access) do
      providers = find_enhancement_service_providers(enhancement_type, nil)

      Enum.each(providers, fn provider ->
        create_service_provider_invitation(channel, provider, enhancement_type)
      end)
    else
      suggest_service_provider_upgrade(current_account, enhancement_type)
    end
  end

  defp suggest_service_provider_upgrade(current_account, enhancement_type) do
    # Mock - suggest upgrade to access service providers
    IO.puts("Suggesting upgrade for account #{current_account.id || "unknown"} to access #{enhancement_type} providers")
    :ok
  end

  defp get_enhanced_activity_feed(user_id) do
    try do
      Analytics.get_user_activity_feed(user_id, limit: 10)
    rescue
      _ -> []
    end
  end

  defp check_first_visit(user, params) do
    # Implementation for first visit detection
    false
  end

  defp get_recently_created_portfolio(portfolios) do
    portfolios
    |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    |> List.first()
  end

  defp assign_mobile_state() do
    %{
      mobile_view_mode: false,
      show_mobile_menu: false,
      show_mobile_nav: false
    }
  end

  @impl true
  def handle_event("request_enhancement", %{"type" => enhancement_type, "portfolio_id" => portfolio_id}, socket) do
    current_account = socket.assigns.current_account

    case can_access_collaboration?(current_account, String.to_atom(enhancement_type)) do
      true ->
        # Create enhancement request
        portfolio = Portfolios.get_portfolio!(portfolio_id)

        # Create a collaboration channel for this enhancement
        channel_attrs = %{
          name: "#{portfolio.title} - #{String.capitalize(enhancement_type)} Enhancement",
          description: "Collaboration space for #{enhancement_type} enhancement",
          visibility: "private",
          user_id: socket.assigns.current_user.id
        }

        case Channels.create_channel(channel_attrs) do
          {:ok, channel} ->
            # Send invitations to relevant service providers
            send_enhancement_invitations(channel, enhancement_type, current_account)

            {:noreply,
            socket
            |> put_flash(:info, "Enhancement request created! Invitations sent to qualified providers.")
            |> assign(:show_enhancement_modal, false)}

          {:error, _} ->
            {:noreply,
            socket
            |> put_flash(:error, "Failed to create enhancement request.")
            |> assign(:show_enhancement_modal, false)}
        end

      false ->
        # Show upgrade modal
        {:noreply,
        socket
        |> assign(:show_enhancement_modal, false)
        |> assign(:show_upgrade_modal, true)
        |> assign(:requested_feature, enhancement_type)}
    end
  end

  defp has_voice_introduction?(sections) do
    Enum.any?(sections, fn section ->
      section.content && Map.has_key?(section.content, "voice_intro")
    end)
  end

  defp assess_content_quality(sections) do
    total_length = Enum.reduce(sections, 0, fn section, acc ->
      acc + get_content_length(section)
    end)

    cond do
      total_length > 1000 -> 20
      total_length > 500 -> 15
      total_length > 250 -> 10
      total_length > 100 -> 5
      true -> 0
    end
  end

  defp assess_visual_consistency(portfolio) do
    portfolio.customization != nil && portfolio.theme != nil
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

  defp can_access_enhancement?(user, enhancement_type) do
    # For now, return true to avoid feature gate issues
    true
  end

  # Mock service provider functions:
  defp find_enhancement_service_providers(enhancement_type, user_location) do
    # Mock - replace with actual service provider query
    []
  end

  defp create_service_provider_invitation(channel, provider, enhancement_type) do
    # Mock - replace with actual invitation creation
    IO.puts("Creating service provider invitation for channel #{channel.id}")
    :ok
  end

  # Feature availability helpers
  defp get_available_templates_count(account), do: 10
  defp get_enhancement_progress(portfolios), do: %{}
  defp get_creation_limits(account), do: %{}
  defp get_recent_portfolio_activity(user_id), do: []
  defp get_channel_limits(account), do: %{}
  defp get_beta_features(account), do: []
  defp check_calendar_integration(user_id), do: false
  defp check_billing_integration(user_id), do: false
  defp portfolio_needs_work?(portfolio), do: false

  # ============================================================================
  # EVENT HANDLERS (To be implemented in next iteration)
  # ============================================================================

  @impl true
  def handle_event("switch_section", %{"section" => section}, socket) do
    {:noreply, assign(socket, :active_section, section)}
  end

  @impl true
  def handle_event("toggle_view_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  # ============================================================================
  # MAIN SECTION FUNCTIONS (called directly from template)
  # ============================================================================

  defp portfolio_studio_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Studio Overview Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <!-- Total Portfolios -->
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-purple-100 rounded-lg">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Portfolios</p>
              <p class="text-2xl font-bold text-gray-900"><%= Map.get(@studio_data, :total_portfolios, length(@portfolios)) %></p>
            </div>
          </div>
        </div>

        <!-- Published Count -->
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-green-100 rounded-lg">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Published</p>
              <p class="text-2xl font-bold text-gray-900"><%= Map.get(@studio_data, :published_count, Enum.count(@portfolios, &(&1.visibility == :public))) %></p>
            </div>
          </div>
        </div>

        <!-- Drafts -->
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-yellow-100 rounded-lg">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Drafts</p>
              <p class="text-2xl font-bold text-gray-900"><%= Map.get(@studio_data, :draft_count, Enum.count(@portfolios, &(&1.visibility == :private))) %></p>
            </div>
          </div>
        </div>

        <!-- Templates Available -->
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-blue-100 rounded-lg">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Templates</p>
              <p class="text-2xl font-bold text-gray-900"><%= Map.get(@studio_data, :templates_available, 10) %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Portfolios Section -->
      <%= portfolio_grid_section(assigns) %>

      <!-- Enhancement Suggestions -->
      <%= if @enhancement_suggestions && length(@enhancement_suggestions) > 0 do %>
        <%= enhancement_suggestions_section(assigns) %>
      <% end %>
    </div>
    """
  end

  defp revenue_center_section(assigns) do
    ~H"""
    <%= if Map.get(@revenue_data, :upgrade_prompt, true) do %>
      <!-- Upgrade Prompt for Revenue Center -->
      <div class="bg-gradient-to-br from-green-50 to-emerald-100 rounded-xl p-8 border-2 border-green-200">
        <div class="text-center">
          <div class="text-6xl mb-4">📊</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Revenue Center</h2>
          <p class="text-gray-600 mb-6">Unlock comprehensive revenue analytics, performance tracking, and financial insights with Professional tier.</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="bg-white rounded-lg p-4 border border-green-200">
              <div class="text-2xl mb-2">💰</div>
              <h3 class="font-semibold text-gray-900">Revenue Analytics</h3>
              <p class="text-sm text-gray-600">Detailed earnings and performance metrics</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-green-200">
              <div class="text-2xl mb-2">📈</div>
              <h3 class="font-semibold text-gray-900">Growth Tracking</h3>
              <p class="text-sm text-gray-600">Monitor trends and forecast revenue</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-green-200">
              <div class="text-2xl mb-2">🧾</div>
              <h3 class="font-semibold text-gray-900">Tax & Billing</h3>
              <p class="text-sm text-gray-600">Automated tax documents and billing</p>
            </div>
          </div>
          <button phx-click="upgrade_to_professional"
                  class="inline-flex items-center px-6 py-3 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-all transform hover:scale-105">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Upgrade to Professional
          </button>
        </div>
      </div>
    <% else %>
      <!-- Full Revenue Center -->
      <%= revenue_center_content(assigns) %>
    <% end %>
    """
  end

  defp service_dashboard_section(assigns) do
    ~H"""
    <%= if Map.get(@service_data, :upgrade_prompt, true) do %>
      <!-- Upgrade Prompt for Service Dashboard -->
      <div class="bg-gradient-to-br from-blue-50 to-indigo-100 rounded-xl p-8 border-2 border-blue-200">
        <div class="text-center">
          <div class="text-6xl mb-4">💼</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Service Dashboard</h2>
          <p class="text-gray-600 mb-6">Manage bookings, track revenue, and grow your service business with Creator tier features.</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">📅</div>
              <h3 class="font-semibold text-gray-900">Booking Management</h3>
              <p class="text-sm text-gray-600">Calendar integration and client scheduling</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">💰</div>
              <h3 class="font-semibold text-gray-900">Revenue Tracking</h3>
              <p class="text-sm text-gray-600">Monitor earnings and payment processing</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">🎯</div>
              <h3 class="font-semibold text-gray-900">Performance Analytics</h3>
              <p class="text-sm text-gray-600">Track success metrics and growth</p>
            </div>
          </div>
          <button phx-click="upgrade_to_creator"
                  class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all transform hover:scale-105">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Upgrade to Creator Tier
          </button>
        </div>
      </div>
    <% else %>
      <!-- Full Service Dashboard -->
      <%= service_dashboard_content(assigns) %>
    <% end %>
    """
  end

  defp creator_lab_section(assigns) do
    ~H"""
    <%= if Map.get(@lab_data, :upgrade_prompt, true) do %>
      <!-- Upgrade Prompt for Creator Lab -->
      <div class="bg-gradient-to-br from-purple-50 to-pink-100 rounded-xl p-8 border-2 border-purple-200">
        <div class="text-center">
          <div class="text-6xl mb-4">🧪</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Creator Lab</h2>
          <p class="text-gray-600 mb-6">Experiment with cutting-edge features, AI tools, and beta functionality to stay ahead of the curve.</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">🤖</div>
              <h3 class="font-semibold text-gray-900">AI-Powered Tools</h3>
              <p class="text-sm text-gray-600">Smart content generation and optimization</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">🔬</div>
              <h3 class="font-semibold text-gray-900">Beta Features</h3>
              <p class="text-sm text-gray-600">Early access to experimental functionality</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">📊</div>
              <h3 class="font-semibold text-gray-900">Advanced Analytics</h3>
              <p class="text-sm text-gray-600">Deep insights and performance metrics</p>
            </div>
          </div>
          <button phx-click="upgrade_for_lab"
                  class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-all transform hover:scale-105">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Unlock Creator Lab
          </button>
        </div>
      </div>
    <% else %>
      <!-- Full Creator Lab -->
      <div class="space-y-6">
        <!-- Lab Overview -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-purple-100 rounded-lg">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Active Experiments</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(Map.get(@lab_data, :active_experiments, [])) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-pink-100 rounded-lg">
                <svg class="w-6 h-6 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Beta Features</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(Map.get(@lab_data, :beta_access, [])) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-blue-100 rounded-lg">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">AI Insights</p>
                <p class="text-2xl font-bold text-gray-900"><%= map_size(Map.get(@lab_data, :ai_insights, %{})) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-green-100 rounded-lg">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Completed Tests</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(Map.get(@lab_data, :results, [])) %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Available Lab Features -->
        <%= if @lab_data[:features] && length(@lab_data.features) > 0 do %>
          <%= lab_features_section(assigns) %>
        <% end %>

        <!-- Active Experiments -->
        <%= if @lab_data[:active_experiments] && length(@lab_data.active_experiments) > 0 do %>
          <%= active_experiments_section(assigns) %>
        <% end %>

        <!-- AI Insights -->
        <%= if @lab_data[:ai_insights] && map_size(@lab_data.ai_insights) > 0 do %>
          <%= ai_insights_section(assigns) %>
        <% end %>
      </div>
    <% end %>
    """
  end

  # ============================================================================
  # ADDITIONAL MISSING HELPER FUNCTIONS
  # ============================================================================

  defp revenue_center_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Revenue Overview Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-green-100 rounded-lg">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Total Revenue</p>
              <p class="text-2xl font-bold text-gray-900">$<%= Map.get(@revenue_data, :total_revenue, %{amount: 0}) |> Map.get(:amount, 0) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-blue-100 rounded-lg">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">This Month</p>
              <p class="text-2xl font-bold text-gray-900">$<%= get_current_month_revenue(Map.get(@revenue_data, :trends, [])) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-purple-100 rounded-lg">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Platform Fees</p>
              <p class="text-2xl font-bold text-gray-900">$<%= Map.get(@revenue_data, :platform_fees, %{}) |> Map.get(:total, 0) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-yellow-100 rounded-lg">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Next Payout</p>
              <p class="text-2xl font-bold text-gray-900"><%= Map.get(@revenue_data, :payout_schedule, %{}) |> Map.get(:next_date, "N/A") %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Revenue Trends Chart -->
      <%= revenue_trends_chart(assigns) %>

      <!-- Portfolio Performance -->
      <%= if @revenue_data[:portfolio_performance] && length(@revenue_data.portfolio_performance) > 0 do %>
        <%= portfolio_performance_section(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # RENDER FUNCTIONS - Add these to the LiveView module
  # ============================================================================

  # Helper function for humanizing section names
  defp humanize_section_name(section) do
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

  # ============================================================================
  # PORTFOLIO STUDIO SECTION RENDERS
  # ============================================================================

  defp portfolio_grid_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-bold text-gray-900">Your Portfolios</h2>
        <button phx-click="show_create_modal"
                class="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Create Portfolio
        </button>
      </div>

      <%= if length(@portfolios) > 0 do %>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <%= for portfolio <- @portfolios do %>
            <div class="group border border-gray-200 rounded-lg hover:shadow-md transition-all duration-200 overflow-hidden">
              <!-- Portfolio Preview -->
              <div class={[
                "w-full h-32 flex items-center justify-center",
                case portfolio.theme do
                  "executive" -> "bg-gradient-to-br from-blue-500 to-indigo-600"
                  "creative" -> "bg-gradient-to-br from-purple-500 to-pink-600"
                  "developer" -> "bg-gradient-to-br from-green-500 to-teal-600"
                  _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
                end
              ]}>
                <div class="text-center text-white">
                  <h4 class="font-bold text-lg"><%= portfolio.title %></h4>
                  <p class="text-sm opacity-90">/<%= portfolio.slug %></p>
                </div>
              </div>

              <!-- Portfolio Info -->
              <div class="p-4">
                <div class="flex items-start justify-between mb-3">
                  <div class="flex-1">
                    <h3 class="font-semibold text-gray-900 group-hover:text-purple-600 transition-colors">
                      <%= portfolio.title %>
                    </h3>
                    <p class="text-sm text-gray-600 mt-1 line-clamp-2"><%= portfolio.description %></p>
                  </div>
                </div>

                <!-- Portfolio Actions -->
                <div class="flex items-center justify-between">
                  <div class="flex space-x-2">
                    <.link href={"/portfolios/#{portfolio.id}/edit"}
                          class="text-xs px-3 py-1 bg-purple-100 text-purple-700 rounded-full hover:bg-purple-200 transition-colors">
                      Edit
                    </.link>
                    <.link href={"/p/#{portfolio.slug}"} target="_blank"
                          class="text-xs px-3 py-1 bg-blue-100 text-blue-700 rounded-full hover:bg-blue-200 transition-colors">
                      View
                    </.link>
                  </div>

                  <%= if stats = Map.get(@portfolio_stats, portfolio.id) do %>
                    <div class="text-xs text-gray-500">
                      <%= Map.get(stats, :total_visits, 0) %> views
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12">
          <div class="text-6xl mb-4">🎨</div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No portfolios yet</h3>
          <p class="text-gray-600 mb-6">Create your first portfolio to get started</p>
          <button phx-click="show_create_modal"
                  class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Create Your First Portfolio
          </button>
        </div>
      <% end %>
    </div>
    """
  end



  defp enhancement_suggestions_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">AI Enhancement Suggestions</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for suggestion <- Enum.take(@enhancement_suggestions, 6) do %>
          <div class="group relative bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg p-4 border border-purple-200 hover:border-purple-300 hover:shadow-md transition-all cursor-pointer"
              phx-click="enhance_portfolio"
              phx-value-type={suggestion.type}
              phx-value-portfolio_id={suggestion.portfolio_id}>

            <div class="flex items-center mb-3">
              <span class="text-2xl mr-3"><%= suggestion.icon %></span>
              <h3 class="font-semibold text-gray-900 group-hover:text-purple-700 transition-colors">
                <%= suggestion.title %>
              </h3>
            </div>

            <p class="text-sm text-gray-600 mb-3"><%= suggestion.description %></p>

            <div class="flex items-center justify-between text-xs text-gray-500">
              <span>For: <%= Helpers.get_portfolio_title(suggestion.portfolio_id, @portfolios) %></span>
              <svg class="w-4 h-4 opacity-0 group-hover:opacity-100 transition-opacity" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
              </svg>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # COLLABORATION HUB SECTION
  # ============================================================================

  defp collaboration_hub_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Collaboration Overview -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-blue-100 rounded-lg">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Active Collaborations</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@collaboration_data.active_collaborations) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-green-100 rounded-lg">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Feedback Received</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@collaboration_data.feedback_received) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-purple-100 rounded-lg">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Peer Network</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@collaboration_data.peer_network) %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Collaboration Requests -->
      <%= if length(@collaboration_requests) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <h2 class="text-xl font-bold text-gray-900 mb-6">Pending Collaboration Requests</h2>
          <div class="space-y-4">
            <%= for request <- @collaboration_requests do %>
              <div class="flex items-center justify-between p-4 border border-purple-200 rounded-lg">
                <div class="flex items-center">
                  <div class="w-10 h-10 bg-purple-500 rounded-full flex items-center justify-center text-white font-bold">
                    <%= String.first(request.user) %>
                  </div>
                  <div class="ml-4">
                    <p class="font-medium text-gray-900"><%= request.user %></p>
                    <p class="text-sm text-gray-600">wants to <%= request.type %> on "<%= request.portfolio %>"</p>
                  </div>
                </div>
                <div class="flex space-x-2">
                  <button phx-click="accept_collaboration" phx-value-request_id={request.id}
                          class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
                    Accept
                  </button>
                  <button phx-click="decline_collaboration" phx-value-request_id={request.id}
                          class="px-4 py-2 bg-gray-300 text-gray-700 rounded-lg hover:bg-gray-400 transition-colors">
                    Decline
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

          <!-- Collaboration Opportunities -->
      <div class="bg-white rounded-xl p-6 border border-gray-200">
        <h2 class="text-xl font-bold text-gray-900 mb-6">Find Collaborators</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for opportunity <- Enum.take(@collaboration_data.opportunities, 6) do %>
            <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-all">
              <div class="flex items-center mb-3">
                <div class="w-8 h-8 bg-gradient-to-br from-purple-500 to-blue-500 rounded-full flex items-center justify-center text-white text-sm font-bold">
                  <%= String.first(opportunity.creator_name) %>
                </div>
                <div class="ml-3">
                  <p class="font-medium text-gray-900"><%= opportunity.creator_name %></p>
                  <p class="text-sm text-gray-600"><%= opportunity.expertise %></p>
                </div>
              </div>
              <p class="text-sm text-gray-600 mb-4"><%= opportunity.description %></p>
              <button phx-click="request_collaboration" phx-value-creator_id={opportunity.creator_id}
                      class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                Connect
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # COMMUNITY CHANNELS SECTION
  # ============================================================================

  defp community_channels_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Channels Overview -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-indigo-100 rounded-lg">
              <svg class="w-6 h-6 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2m-9 0h10m-10 0a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V6a2 2 0 00-2-2M7 4h10"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Your Channels</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@user_channels) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-pink-100 rounded-lg">
              <svg class="w-6 h-6 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Trending</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@trending_channels) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center">
            <div class="p-3 bg-orange-100 rounded-lg">
              <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Recommendations</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@channel_recommendations) %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Your Channels -->
      <%= if length(@user_channels) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <h2 class="text-xl font-bold text-gray-900 mb-6">Your Active Channels</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for channel <- @user_channels do %>
              <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-all">
                <div class="flex items-center mb-3">
                  <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-500 rounded-lg flex items-center justify-center text-white font-bold">
                    <%= String.first(channel.name) %>
                  </div>
                  <div class="ml-3">
                    <h3 class="font-semibold text-gray-900"><%= channel.name %></h3>
                    <p class="text-sm text-gray-600"><%= channel.type %></p>
                  </div>
                </div>
                <p class="text-sm text-gray-600 mb-4"><%= channel.description %></p>
                <div class="flex items-center justify-between">
                  <span class="text-xs text-gray-500"><%= channel.member_count %> members</span>
                  <button phx-click="join_channel" phx-value-channel_id={channel.id}
                          class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-xs hover:bg-purple-200 transition-colors">
                    Open
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Channel Recommendations -->
      <%= if length(@channel_recommendations) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <h2 class="text-xl font-bold text-gray-900 mb-6">Recommended Channels</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for channel <- Enum.take(@channel_recommendations, 6) do %>
              <div class="border border-gray-200 rounded-lg p-4 hover:shadow-md transition-all">
                <div class="flex items-center mb-3">
                  <div class="w-10 h-10 bg-gradient-to-br from-indigo-500 to-purple-500 rounded-lg flex items-center justify-center text-white font-bold">
                    <%= String.first(channel.name) %>
                  </div>
                  <div class="ml-3">
                    <h3 class="font-semibold text-gray-900"><%= channel.name %></h3>
                    <p class="text-sm text-gray-600"><%= channel.category %></p>
                  </div>
                </div>
                <p class="text-sm text-gray-600 mb-4"><%= channel.description %></p>
                <div class="flex items-center justify-between">
                  <span class="text-xs text-gray-500"><%= channel.member_count %> members</span>
                  <button phx-click="join_channel" phx-value-channel_id={channel.id}
                          class="px-3 py-1 bg-indigo-600 text-white rounded-full text-xs hover:bg-indigo-700 transition-colors">
                    Join
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Featured Creators -->
      <%= if length(@featured_creators) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <h2 class="text-xl font-bold text-gray-900 mb-6">Featured Creators</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <%= for creator <- Enum.take(@featured_creators, 8) do %>
              <div class="text-center p-4 border border-gray-200 rounded-lg hover:shadow-md transition-all">
                <div class="w-16 h-16 bg-gradient-to-br from-pink-500 to-orange-500 rounded-full mx-auto mb-3 flex items-center justify-center text-white text-xl font-bold">
                  <%= String.first(creator.name) %>
                </div>
                <h3 class="font-semibold text-gray-900 mb-1"><%= creator.name %></h3>
                <p class="text-sm text-gray-600 mb-3"><%= creator.specialty %></p>
                <button phx-click="view_creator" phx-value-creator_id={creator.id}
                        class="w-full px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-xs hover:bg-gray-200 transition-colors">
                  View Profile
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # CREATOR LAB SECTION
  # ============================================================================

  defp creator_lab_section(assigns) do
    ~H"""
    <%= if @lab_data.upgrade_prompt do %>
      <!-- Upgrade Prompt for Creator Lab -->
      <div class="bg-gradient-to-br from-purple-50 to-pink-100 rounded-xl p-8 border-2 border-purple-200">
        <div class="text-center">
          <div class="text-6xl mb-4">🧪</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Creator Lab</h2>
          <p class="text-gray-600 mb-6">Experiment with cutting-edge features, AI tools, and beta functionality to stay ahead of the curve.</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">🤖</div>
              <h3 class="font-semibold text-gray-900">AI-Powered Tools</h3>
              <p class="text-sm text-gray-600">Smart content generation and optimization</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">🔬</div>
              <h3 class="font-semibold text-gray-900">Beta Features</h3>
              <p class="text-sm text-gray-600">Early access to experimental functionality</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-purple-200">
              <div class="text-2xl mb-2">📊</div>
              <h3 class="font-semibold text-gray-900">Advanced Analytics</h3>
              <p class="text-sm text-gray-600">Deep insights and performance metrics</p>
            </div>
          </div>
          <button phx-click="upgrade_for_lab"
                  class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-all transform hover:scale-105">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Unlock Creator Lab
          </button>
        </div>
      </div>
    <% else %>
      <!-- Full Creator Lab -->
      <div class="space-y-6">
        <!-- Lab Overview -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-purple-100 rounded-lg">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Active Experiments</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(@lab_data.active_experiments) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-pink-100 rounded-lg">
                <svg class="w-6 h-6 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Beta Features</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(@lab_data.beta_access) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-blue-100 rounded-lg">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">AI Insights</p>
                <p class="text-2xl font-bold text-gray-900"><%= map_size(@lab_data.ai_insights) %></p>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl p-6 border border-gray-200">
            <div class="flex items-center">
              <div class="p-3 bg-green-100 rounded-lg">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="text-sm font-medium text-gray-600">Completed Tests</p>
                <p class="text-2xl font-bold text-gray-900"><%= length(@lab_data.results) %></p>
              </div>
            </div>
          </div>
        </div>

        <!-- Available Lab Features -->
        <%= if length(@lab_data.features) > 0 do %>
          <%= lab_features_section(assigns) %>
        <% end %>

        <!-- Active Experiments -->
        <%= if length(@lab_data.active_experiments) > 0 do %>
          <%= active_experiments_section(assigns) %>
        <% end %>

        <!-- AI Insights -->
        <%= if map_size(@lab_data.ai_insights) > 0 do %>
          <%= ai_insights_section(assigns) %>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp lab_features_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Available Lab Features</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for feature <- @lab_data.features do %>
          <div class="border border-purple-200 rounded-lg p-4 hover:shadow-md transition-all bg-gradient-to-br from-purple-50 to-pink-50">
            <div class="flex items-center mb-3">
              <span class="text-2xl mr-3"><%= feature.icon %></span>
              <div>
                <h3 class="font-semibold text-gray-900"><%= feature.name %></h3>
                <span class={[
                  "text-xs px-2 py-1 rounded-full",
                  case feature.status do
                    "beta" -> "bg-yellow-100 text-yellow-700"
                    "experimental" -> "bg-red-100 text-red-700"
                    "stable" -> "bg-green-100 text-green-700"
                    _ -> "bg-gray-100 text-gray-700"
                  end
                ]}>
                  <%= String.capitalize(feature.status) %>
                </span>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4"><%= feature.description %></p>
            <button phx-click="try_lab_feature" phx-value-feature_id={feature.id}
                    class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
              Try Feature
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp active_experiments_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Your Active Experiments</h2>
      <div class="space-y-4">
        <%= for experiment <- @lab_data.active_experiments do %>
          <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-purple-500 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="font-medium text-gray-900"><%= experiment.name %></p>
                <p class="text-sm text-gray-600">Started <%= experiment.start_date %> • <%= experiment.duration %> days remaining</p>
              </div>
            </div>
            <div class="flex items-center space-x-3">
              <div class="text-sm">
                <span class="text-gray-600">Progress:</span>
                <span class="font-medium text-purple-600"><%= experiment.progress %>%</span>
              </div>
              <button phx-click="view_experiment" phx-value-id={experiment.id}
                      class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-xs hover:bg-purple-200 transition-colors">
                View Results
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp ai_insights_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">AI Insights</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for {insight_type, insight_data} <- @lab_data.ai_insights do %>
          <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg p-4 border border-blue-200">
            <h3 class="font-semibold text-gray-900 mb-2"><%= Phoenix.Naming.humanize(insight_type) %></h3>
            <p class="text-sm text-gray-600 mb-3"><%= insight_data.description %></p>
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">Confidence: <%= insight_data.confidence %>%</span>
              <button phx-click="apply_ai_insight" phx-value-type={insight_type}
                      class="px-3 py-1 bg-blue-600 text-white rounded-full text-xs hover:bg-blue-700 transition-colors">
                Apply
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SERVICE DASHBOARD SECTION
  # ============================================================================

  defp service_dashboard_section(assigns) do
    ~H"""
    <%= if @service_data.upgrade_prompt do %>
      <!-- Upgrade Prompt for Service Dashboard -->
      <div class="bg-gradient-to-br from-blue-50 to-indigo-100 rounded-xl p-8 border-2 border-blue-200">
        <div class="text-center">
          <div class="text-6xl mb-4">💼</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-4">Service Dashboard</h2>
          <p class="text-gray-600 mb-6">Manage bookings, track revenue, and grow your service business with Creator tier features.</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">📅</div>
              <h3 class="font-semibold text-gray-900">Booking Management</h3>
              <p class="text-sm text-gray-600">Calendar integration and client scheduling</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">💰</div>
              <h3 class="font-semibold text-gray-900">Revenue Tracking</h3>
              <p class="text-sm text-gray-600">Monitor earnings and payment processing</p>
            </div>
            <div class="bg-white rounded-lg p-4 border border-blue-200">
              <div class="text-2xl mb-2">🎯</div>
              <h3 class="font-semibold text-gray-900">Performance Analytics</h3>
              <p class="text-sm text-gray-600">Track success metrics and growth</p>
            </div>
          </div>
          <button phx-click="upgrade_to_creator"
                  class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all transform hover:scale-105">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Upgrade to Creator Tier
          </button>
        </div>
      </div>
    <% else %>
      <!-- Full Service Dashboard -->
      <%= service_dashboard_content(assigns) %>
    <% end %>
    """
  end

  # Add this function to portfolio_hub_live.ex

  defp service_dashboard_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Service Overview Cards -->
      <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-blue-100 rounded-lg">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Active Bookings</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@service_data.active_bookings) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-green-100 rounded-lg">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">This Month Revenue</p>
              <p class="text-2xl font-bold text-gray-900">$<%= @service_data.revenue.this_month %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-purple-100 rounded-lg">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Active Clients</p>
              <p class="text-2xl font-bold text-gray-900"><%= map_size(@service_data.client_management) %></p>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all">
          <div class="flex items-center">
            <div class="p-3 bg-yellow-100 rounded-lg">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
              </svg>
            </div>
            <div class="ml-4">
              <p class="text-sm font-medium text-gray-600">Services Offered</p>
              <p class="text-2xl font-bold text-gray-900"><%= length(@service_data.service_offerings) %></p>
            </div>
          </div>
        </div>
      </div>

      <!-- Quick Actions Bar -->
      <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl p-4 border border-blue-200">
        <div class="flex flex-col sm:flex-row items-center justify-between">
          <div class="flex items-center mb-4 sm:mb-0">
            <div class="w-10 h-10 bg-blue-500 rounded-lg flex items-center justify-center mr-3">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <div>
              <h3 class="font-semibold text-gray-900">Service Management</h3>
              <p class="text-sm text-gray-600">Manage your bookings, clients, and service offerings</p>
            </div>
          </div>
          <div class="flex space-x-3">
            <button phx-click="create_service" class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              Add Service
            </button>
            <button phx-click="view_calendar" class="px-4 py-2 bg-white border border-blue-300 text-blue-700 rounded-lg hover:bg-blue-50 transition-colors">
              View Calendar
            </button>
          </div>
        </div>
      </div>

      <!-- Upcoming Appointments -->
      <%= if length(@service_data.upcoming_appointments) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-xl font-bold text-gray-900">Upcoming Appointments</h2>
            <button phx-click="view_all_appointments" class="text-blue-600 hover:text-blue-700 text-sm font-medium">
              View All
            </button>
          </div>
          <div class="space-y-4">
            <%= for appointment <- Enum.take(@service_data.upcoming_appointments, 5) do %>
              <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-sm transition-all">
                <div class="flex items-center">
                  <div class={[
                    "w-10 h-10 rounded-full flex items-center justify-center text-white font-bold text-sm",
                    case appointment.status do
                      "confirmed" -> "bg-green-500"
                      "pending" -> "bg-yellow-500"
                      "completed" -> "bg-blue-500"
                      "cancelled" -> "bg-red-500"
                      _ -> "bg-gray-500"
                    end
                  ]}>
                    <%= String.first(appointment.client_name) %>
                  </div>
                  <div class="ml-4">
                    <div class="flex items-center">
                      <p class="font-medium text-gray-900 mr-2"><%= appointment.service_name %></p>
                      <span class={[
                        "px-2 py-0.5 text-xs rounded-full font-medium",
                        case appointment.status do
                          "confirmed" -> "bg-green-100 text-green-700"
                          "pending" -> "bg-yellow-100 text-yellow-700"
                          "completed" -> "bg-blue-100 text-blue-700"
                          "cancelled" -> "bg-red-100 text-red-700"
                          _ -> "bg-gray-100 text-gray-700"
                        end
                      ]}>
                        <%= String.capitalize(appointment.status) %>
                      </span>
                    </div>
                    <p class="text-sm text-gray-600"><%= appointment.client_name %> • <%= appointment.date %> at <%= appointment.time %></p>
                    <p class="text-xs text-gray-500"><%= appointment.duration %> minutes • $<%= appointment.amount %></p>
                  </div>
                </div>
                <div class="flex items-center space-x-2">
                  <%= if appointment.meeting_link do %>
                    <a href={appointment.meeting_link} target="_blank"
                      class="px-3 py-1 bg-green-100 text-green-700 rounded-full text-xs hover:bg-green-200 transition-colors">
                      Join Meeting
                    </a>
                  <% end %>
                  <button phx-click="view_appointment" phx-value-id={appointment.id}
                          class="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-xs hover:bg-blue-200 transition-colors">
                    Details
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="text-center py-8">
            <div class="text-4xl mb-4">📅</div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No upcoming appointments</h3>
            <p class="text-gray-600 mb-4">Your appointments will appear here once clients start booking</p>
            <button phx-click="create_service"
                    class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              Create Your First Service
            </button>
          </div>
        </div>
      <% end %>

      <!-- Service Offerings Management -->
      <div class="bg-white rounded-xl p-6 border border-gray-200">
        <div class="flex items-center justify-between mb-6">
          <h2 class="text-xl font-bold text-gray-900">Your Services</h2>
          <button phx-click="create_service"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Add Service
          </button>
        </div>

        <%= if length(@service_data.service_offerings) > 0 do %>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for service <- @service_data.service_offerings do %>
              <div class="group border border-gray-200 rounded-lg p-4 hover:shadow-md transition-all cursor-pointer"
                  phx-click="view_service_details" phx-value-id={service.id}>
                <div class="flex items-start justify-between mb-3">
                  <div>
                    <h3 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors">
                      <%= service.name %>
                    </h3>
                    <div class="flex items-center text-sm text-gray-600 mt-1">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                      </svg>
                      <%= service.duration %> min
                    </div>
                  </div>
                  <div class="text-right">
                    <span class="text-lg font-bold text-green-600">$<%= service.price %></span>
                    <%= if service.booking_count do %>
                      <p class="text-xs text-gray-500"><%= service.booking_count %> bookings</p>
                    <% end %>
                  </div>
                </div>

                <p class="text-sm text-gray-600 mb-4 line-clamp-2"><%= service.description %></p>

                <!-- Service Stats -->
                <%= if service.stats do %>
                  <div class="flex items-center justify-between text-xs text-gray-500 mb-3">
                    <span class="flex items-center">
                      <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                      </svg>
                      <%= service.stats.rating %>/5
                    </span>
                    <span><%= service.stats.total_bookings %> total bookings</span>
                  </div>
                <% end %>

                <div class="flex space-x-2">
                  <button phx-click="edit_service" phx-value-id={service.id}
                          class="flex-1 px-3 py-2 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors font-medium">
                    Edit
                  </button>
                  <button phx-click="view_service_bookings" phx-value-service_id={service.id}
                          class="flex-1 px-3 py-2 bg-blue-100 text-blue-700 rounded-lg text-sm hover:bg-blue-200 transition-colors font-medium">
                    Bookings
                  </button>
                  <button phx-click="toggle_service_status" phx-value-id={service.id}
                          class={[
                            "px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                            if(service.active,
                              do: "bg-green-100 text-green-700 hover:bg-green-200",
                              else: "bg-red-100 text-red-700 hover:bg-red-200")
                          ]}>
                    <%= if service.active, do: "Active", else: "Inactive" %>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-12">
            <div class="text-6xl mb-4">💼</div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No services yet</h3>
            <p class="text-gray-600 mb-6">Create your first service offering to start accepting bookings from clients</p>
            <button phx-click="create_service"
                    class="inline-flex items-center px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-all transform hover:scale-105">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Create Your First Service
            </button>
          </div>
        <% end %>
      </div>

      <!-- Client Management Overview -->
      <%= if map_size(@service_data.client_management) > 0 do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between mb-6">
            <h2 class="text-xl font-bold text-gray-900">Recent Clients</h2>
            <button phx-click="view_all_clients" class="text-blue-600 hover:text-blue-700 text-sm font-medium">
              View All Clients
            </button>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for {client_id, client_data} <- Enum.take(@service_data.client_management, 6) do %>
              <div class="border border-gray-200 rounded-lg p-4 hover:shadow-sm transition-all">
                <div class="flex items-center mb-3">
                  <div class="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                    <%= String.first(client_data.name) %>
                  </div>
                  <div class="ml-3">
                    <p class="font-medium text-gray-900"><%= client_data.name %></p>
                    <p class="text-sm text-gray-600"><%= client_data.email %></p>
                  </div>
                </div>
                <div class="text-sm text-gray-600">
                  <p>Total Bookings: <%= client_data.booking_count %></p>
                  <p>Last Session: <%= client_data.last_booking_date %></p>
                  <p class="text-green-600 font-medium">Revenue: $<%= client_data.total_revenue %></p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Performance Metrics -->
      <%= if @service_data.performance do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <h2 class="text-xl font-bold text-gray-900 mb-6">Performance Overview</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div class="text-center p-4 bg-blue-50 rounded-lg">
              <p class="text-2xl font-bold text-blue-600"><%= @service_data.performance.completion_rate %>%</p>
              <p class="text-sm text-gray-600">Completion Rate</p>
            </div>
            <div class="text-center p-4 bg-green-50 rounded-lg">
              <p class="text-2xl font-bold text-green-600"><%= @service_data.performance.average_rating %></p>
              <p class="text-sm text-gray-600">Average Rating</p>
            </div>
            <div class="text-center p-4 bg-purple-50 rounded-lg">
              <p class="text-2xl font-bold text-purple-600"><%= @service_data.performance.repeat_client_rate %>%</p>
              <p class="text-sm text-gray-600">Repeat Clients</p>
            </div>
            <div class="text-center p-4 bg-yellow-50 rounded-lg">
              <p class="text-2xl font-bold text-yellow-600"><%= @service_data.performance.response_time %></p>
              <p class="text-sm text-gray-600">Avg Response Time</p>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # REVENUE CENTER HELPER FUNCTIONS
  # ============================================================================

  defp get_current_month_revenue(trends) when is_list(trends) do
    case List.first(trends) do
      %{amount: amount} when is_number(amount) -> amount
      %{"amount" => amount} when is_number(amount) -> amount
      _ -> 0
    end
  end

  defp get_current_month_revenue(_), do: 0

  defp revenue_trends_chart(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-bold text-gray-900">Revenue Trends</h2>
        <div class="flex space-x-2">
          <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors">
            7D
          </button>
          <button class="px-3 py-1 bg-purple-600 text-white rounded-lg text-sm">
            30D
          </button>
          <button class="px-3 py-1 bg-gray-100 text-gray-700 rounded-lg text-sm hover:bg-gray-200 transition-colors">
            90D
          </button>
        </div>
      </div>

      <!-- Chart Placeholder -->
      <div class="h-64 bg-gradient-to-br from-purple-50 to-blue-50 rounded-lg flex items-center justify-center border-2 border-dashed border-purple-200">
        <div class="text-center">
          <svg class="w-12 h-12 text-purple-400 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
          </svg>
          <p class="text-purple-600 font-medium">Revenue Analytics Chart</p>
          <p class="text-sm text-purple-500 mt-1">Integrate with your preferred charting library</p>
        </div>
      </div>

      <!-- Chart Legend -->
      <div class="flex items-center justify-center space-x-6 mt-4">
        <div class="flex items-center">
          <div class="w-3 h-3 bg-purple-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Portfolio Revenue</span>
        </div>
        <div class="flex items-center">
          <div class="w-3 h-3 bg-blue-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Service Revenue</span>
        </div>
        <div class="flex items-center">
          <div class="w-3 h-3 bg-green-600 rounded-full mr-2"></div>
          <span class="text-sm text-gray-600">Other Revenue</span>
        </div>
      </div>
    </div>
    """
  end

  defp portfolio_performance_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-bold text-gray-900">Portfolio Performance</h2>
        <button phx-click="view_detailed_performance" class="text-green-600 hover:text-green-700 text-sm font-medium">
          View Details
        </button>
      </div>
      <div class="space-y-4">
        <%= for performance <- @revenue_data.portfolio_performance do %>
          <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-sm transition-all">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-purple-500 rounded-full flex items-center justify-center text-white font-bold">
                <%= String.first(safe_get_performance_name(performance)) %>
              </div>
              <div class="ml-4">
                <p class="font-medium text-gray-900"><%= safe_get_performance_name(performance) %></p>
                <div class="flex items-center text-sm text-gray-600 space-x-4">
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                    </svg>
                    <%= safe_get_performance_data(performance, :views, 0) %> views
                  </span>
                  <span class="flex items-center">
                    <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                    </svg>
                    <%= safe_get_performance_data(performance, :conversions, 0) %> conversions
                  </span>
                </div>
              </div>
            </div>
            <div class="text-right">
              <p class="text-lg font-bold text-green-600">$<%= safe_get_performance_data(performance, :revenue, 0) %></p>
              <div class="flex items-center text-sm">
                <%= if safe_get_performance_data(performance, :growth_rate, 0) >= 0 do %>
                  <svg class="w-3 h-3 mr-1 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                  </svg>
                  <span class="text-green-600">+<%= safe_get_performance_data(performance, :growth_rate, 0) %>%</span>
                <% else %>
                  <svg class="w-3 h-3 mr-1 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 17h8m0 0V9m0 8l-8-8-4 4-6-6"/>
                  </svg>
                  <span class="text-red-600"><%= safe_get_performance_data(performance, :growth_rate, 0) %>%</span>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # CREATOR LAB HELPER FUNCTIONS
  # ============================================================================

  defp lab_features_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Available Lab Features</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        <%= for feature <- @lab_data.features do %>
          <div class="border border-purple-200 rounded-lg p-4 hover:shadow-md transition-all bg-gradient-to-br from-purple-50 to-pink-50 group">
            <div class="flex items-center mb-3">
              <span class="text-2xl mr-3"><%= safe_get_feature_data(feature, :icon, "🧪") %></span>
              <div>
                <h3 class="font-semibold text-gray-900 group-hover:text-purple-700 transition-colors">
                  <%= safe_get_feature_data(feature, :name, "Lab Feature") %>
                </h3>
                <span class={[
                  "text-xs px-2 py-1 rounded-full",
                  case safe_get_feature_data(feature, :status, "beta") do
                    "beta" -> "bg-yellow-100 text-yellow-700"
                    "experimental" -> "bg-red-100 text-red-700"
                    "stable" -> "bg-green-100 text-green-700"
                    _ -> "bg-gray-100 text-gray-700"
                  end
                ]}>
                  <%= String.capitalize(safe_get_feature_data(feature, :status, "beta")) %>
                </span>
              </div>
            </div>
            <p class="text-sm text-gray-600 mb-4"><%= safe_get_feature_data(feature, :description, "No description available") %></p>
            <button phx-click="try_lab_feature" phx-value-feature_id={safe_get_feature_data(feature, :id, "")}
                    class="w-full px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
              Try Feature
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp active_experiments_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Your Active Experiments</h2>
      <div class="space-y-4">
        <%= for experiment <- @lab_data.active_experiments do %>
          <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:shadow-sm transition-all">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-purple-500 rounded-full flex items-center justify-center text-white">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
              </div>
              <div class="ml-4">
                <p class="font-medium text-gray-900"><%= safe_get_experiment_data(experiment, :name, "Experiment") %></p>
                <p class="text-sm text-gray-600">
                  Started <%= safe_get_experiment_data(experiment, :start_date, "recently") %> •
                  <%= safe_get_experiment_data(experiment, :duration, "30") %> days remaining
                </p>
              </div>
            </div>
            <div class="flex items-center space-x-3">
              <div class="text-sm text-right">
                <span class="text-gray-600">Progress:</span>
                <span class="font-medium text-purple-600"><%= safe_get_experiment_data(experiment, :progress, 0) %>%</span>
              </div>
              <button phx-click="view_experiment" phx-value-id={safe_get_experiment_data(experiment, :id, "")}
                      class="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-xs hover:bg-purple-200 transition-colors">
                View Results
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp ai_insights_section(assigns) do
    ~H"""
    <div class="bg-white rounded-xl p-6 border border-gray-200">
      <h2 class="text-xl font-bold text-gray-900 mb-6">AI Insights</h2>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for {insight_type, insight_data} <- @lab_data.ai_insights do %>
          <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-lg p-4 border border-blue-200">
            <h3 class="font-semibold text-gray-900 mb-2"><%= Phoenix.Naming.humanize(insight_type) %></h3>
            <p class="text-sm text-gray-600 mb-3"><%= safe_get_insight_data(insight_data, :description, "AI-generated insight") %></p>
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">Confidence: <%= safe_get_insight_data(insight_data, :confidence, 85) %>%</span>
              <button phx-click="apply_ai_insight" phx-value-type={insight_type}
                      class="px-3 py-1 bg-blue-600 text-white rounded-full text-xs hover:bg-blue-700 transition-colors">
                Apply
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SAFE DATA ACCESS HELPER FUNCTIONS
  # ============================================================================

  # Safe data access for performance data
  defp safe_get_performance_name(performance) when is_map(performance) do
    performance[:portfolio_name] || performance["portfolio_name"] || "Portfolio"
  end

  defp safe_get_performance_name(_), do: "Portfolio"

  defp safe_get_performance_data(performance, key, default) when is_map(performance) do
    performance[key] || performance[to_string(key)] || default
  end

  defp safe_get_performance_data(_, _, default), do: default

  # Safe data access for feature data
  defp safe_get_feature_data(feature, key, default) when is_map(feature) do
    feature[key] || feature[to_string(key)] || default
  end

  defp safe_get_feature_data(_, _, default), do: default

  # Safe data access for experiment data
  defp safe_get_experiment_data(experiment, key, default) when is_map(experiment) do
    experiment[key] || experiment[to_string(key)] || default
  end

  defp safe_get_experiment_data(_, _, default), do: default

  # Safe data access for insight data
  defp safe_get_insight_data(insight_data, key, default) when is_map(insight_data) do
    insight_data[key] || insight_data[to_string(key)] || default
  end

  defp safe_get_insight_data(_, _, default), do: default
end
