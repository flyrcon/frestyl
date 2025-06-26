# lib/frestyl_web/live/portfolio_hub_live.ex - CHANNELS & LAB INTEGRATION

defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Accounts
  alias Frestyl.Analytics
  alias Frestyl.Channels
  alias Frestyl.Studio
  alias Frestyl.Lab

  # Import helper modules
  alias FrestylWeb.PortfolioHubLive.Components

  @impl true
  def mount(params, _session, socket) do
    user = socket.assigns.current_user
    portfolios = Portfolios.list_user_portfolios(user.id)
    limits = Portfolios.get_portfolio_limits(user)

    # Enhanced onboarding completion check
    is_first_visit = check_first_visit(user, params)
    just_completed_onboarding = Map.get(params, "welcome") == "true"
    recently_created_portfolio = get_recently_created_portfolio(portfolios)

    # Get user overview and activity with better error handling
    overview = safe_get_user_overview(user.id)
    recent_activity = get_enhanced_activity_feed(user.id)
    collaboration_requests = get_collaboration_requests(user.id)

    # Enhanced portfolio stats with better error handling
    portfolio_stats = build_portfolio_stats(portfolios, user.id)

    # CHANNELS INTEGRATION
    user_channels = get_user_channels(user)
    channel_recommendations = get_channel_recommendations(user)
    trending_channels = get_trending_channels(user)

    # LAB INTEGRATION
    lab_features = get_lab_features_for_user(user, limits)
    active_experiments = get_active_experiments(user.id)
    lab_recommendations = get_lab_recommendations(user, portfolios)

    # DISCOVERY & COMMUNITY
    featured_creators = get_featured_creators(user)
    collaboration_opportunities = get_collaboration_opportunities(user)

    socket =
      socket
      |> assign(:page_title, "Portfolio Hub")
      |> assign(:portfolios, portfolios)
      |> assign(:limits, limits)
      |> assign(:overview, overview)
      |> assign(:portfolio_stats, portfolio_stats)
      |> assign(:recent_activity, recent_activity)
      |> assign(:collaboration_requests, collaboration_requests)
      |> assign(:view_mode, "grid")
      |> assign(:filter_status, "all")
      |> assign(:show_create_modal, false)
      |> assign(:show_collaboration_panel, false)
      # Enhanced onboarding integration
      |> assign(:is_first_visit, is_first_visit)
      |> assign(:just_completed_onboarding, just_completed_onboarding)
      |> assign(:recently_created_portfolio, recently_created_portfolio)
      |> assign(:show_welcome_celebration, just_completed_onboarding)
      |> assign(:onboarding_state, get_onboarding_state(user, portfolios, limits))
      # CHANNELS INTEGRATION
      |> assign(:user_channels, user_channels)
      |> assign(:channel_recommendations, channel_recommendations)
      |> assign(:trending_channels, trending_channels)
      |> assign(:show_channels_modal, false)
      |> assign(:selected_channel, nil)
      |> assign(:show_channel_create_modal, false)
      # LAB INTEGRATION
      |> assign(:lab_features, lab_features)
      |> assign(:active_experiments, active_experiments)
      |> assign(:lab_recommendations, lab_recommendations)
      |> assign(:show_lab_modal, false)
      |> assign(:selected_lab_feature, nil)
      |> assign(:lab_active_tab, "featured")
      # DISCOVERY
      |> assign(:featured_creators, featured_creators)
      |> assign(:collaboration_opportunities, collaboration_opportunities)
      |> assign(:show_discovery_panel, false)
      |> assign(:discovery_active_tab, "channels")
      # Mobile state management
      |> assign_mobile_state()

    {:ok, socket}
  end

  # ============================================================================
  # CHANNELS INTEGRATION EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("show_channels_modal", _params, socket) do
    {:noreply, assign(socket, :show_channels_modal, true)}
  end

  @impl true
  def handle_event("hide_channels_modal", _params, socket) do
    {:noreply, assign(socket, :show_channels_modal, false)}
  end

  @impl true
  def handle_event("join_channel", %{"channel_id" => channel_id}, socket) do
    user = socket.assigns.current_user

    case Channels.join_channel(channel_id, user.id) do
      {:ok, _membership} ->
        channel = Channels.get_channel!(channel_id)
        updated_channels = [channel | socket.assigns.user_channels]

        {:noreply,
         socket
         |> assign(:user_channels, updated_channels)
         |> put_flash(:info, "Joined #{channel.name}!")
         |> push_navigate(to: "/channels/#{channel.slug}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to join channel: #{reason}")}
    end
  end

  @impl true
  def handle_event("create_channel_from_portfolio", %{"portfolio_id" => portfolio_id}, socket) do
    user = socket.assigns.current_user
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case create_portfolio_collaboration_channel(user, portfolio) do
      {:ok, channel} ->
        # Add to user channels
        updated_channels = [channel | socket.assigns.user_channels]

        {:noreply,
         socket
         |> assign(:user_channels, updated_channels)
         |> assign(:show_channels_modal, false)
         |> put_flash(:info, "Collaboration channel created for #{portfolio.title}!")
         |> push_navigate(to: "/channels/#{channel.slug}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create channel: #{reason}")}
    end
  end

  @impl true
  def handle_event("show_channel_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_channel_create_modal, true)}
  end

  @impl true
  def handle_event("hide_channel_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_channel_create_modal, false)}
  end

  # ============================================================================
  # LAB INTEGRATION EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("show_lab_modal", _params, socket) do
    {:noreply, assign(socket, :show_lab_modal, true)}
  end

  @impl true
  def handle_event("hide_lab_modal", _params, socket) do
    {:noreply, assign(socket, :show_lab_modal, false)}
  end

  @impl true
  def handle_event("set_lab_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :lab_active_tab, tab)}
  end

  @impl true
  def handle_event("start_experiment", %{"feature_id" => feature_id, "portfolio_id" => portfolio_id}, socket) do
    user = socket.assigns.current_user
    portfolio = portfolio_id && Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case Lab.start_experiment(user, feature_id, portfolio) do
      {:ok, experiment} ->
        updated_experiments = [experiment | socket.assigns.active_experiments]

        {:noreply,
         socket
         |> assign(:active_experiments, updated_experiments)
         |> assign(:show_lab_modal, false)
         |> put_flash(:info, "Lab experiment started!")
         |> redirect_to_experiment(experiment)}

      {:error, :subscription_required} ->
        {:noreply,
         socket
         |> put_flash(:error, "This Lab feature requires a premium subscription.")
         |> push_navigate(to: "/account/subscription")}

      {:error, :time_limit_exceeded} ->
        {:noreply,
         socket
         |> put_flash(:error, "You've reached your Lab time limit for this billing period.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start experiment: #{reason}")}
    end
  end

  @impl true
  def handle_event("end_experiment", %{"experiment_id" => experiment_id}, socket) do
    user = socket.assigns.current_user

    case Lab.end_experiment(experiment_id, user.id) do
      {:ok, _} ->
        updated_experiments = Enum.reject(socket.assigns.active_experiments,
          &(&1.id == String.to_integer(experiment_id)))

        {:noreply,
         socket
         |> assign(:active_experiments, updated_experiments)
         |> put_flash(:info, "Experiment ended and data saved.")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to end experiment: #{reason}")}
    end
  end

  # ============================================================================
  # DISCOVERY INTEGRATION EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("show_discovery_panel", _params, socket) do
    {:noreply, assign(socket, :show_discovery_panel, true)}
  end

  @impl true
  def handle_event("hide_discovery_panel", _params, socket) do
    {:noreply, assign(socket, :show_discovery_panel, false)}
  end

  @impl true
  def handle_event("set_discovery_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :discovery_active_tab, tab)}
  end

  @impl true
  def handle_event("follow_creator", %{"user_id" => user_id}, socket) do
    current_user = socket.assigns.current_user

    case Accounts.follow_user(current_user.id, user_id) do
      {:ok, _follow} ->
        # Update featured creators to show following status
        updated_creators = update_creator_follow_status(socket.assigns.featured_creators, user_id, true)

        {:noreply,
         socket
         |> assign(:featured_creators, updated_creators)
         |> put_flash(:info, "Following creator!")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to follow: #{reason}")}
    end
  end

  @impl true
  def handle_event("start_collaboration", %{"opportunity_id" => opportunity_id}, socket) do
    user = socket.assigns.current_user

    case create_collaboration_from_opportunity(user, opportunity_id) do
      {:ok, channel} ->
        {:noreply,
         socket
         |> assign(:show_discovery_panel, false)
         |> put_flash(:info, "Collaboration started!")
         |> push_navigate(to: "/channels/#{channel.slug}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start collaboration: #{reason}")}
    end
  end

  # ============================================================================
  # ENHANCED EXISTING EVENT HANDLERS
  # ============================================================================

  # Enhanced Studio integration to work with Channels
  @impl true
  def handle_event("start_portfolio_enhancement", %{"portfolio_id" => portfolio_id, "type" => enhancement_type}, socket) do
    user = socket.assigns.current_user
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case create_enhancement_channel_session(user, portfolio, enhancement_type) do
      {:ok, channel, session} ->
        # Track the enhancement creation
        track_enhancement_created(user.id, portfolio.id, enhancement_type)

        {:noreply,
         socket
         |> put_flash(:info, "Enhancement workspace created!")
         |> push_navigate(to: "/channels/#{channel.slug}/studio/#{session.id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create enhancement workspace: #{reason}")}
    end
  end

  # Keep all existing event handlers unchanged...
  @impl true
  def handle_event("show_create_modal", _params, socket) do
    # Enhanced to suggest Lab templates
    lab_templates = get_lab_portfolio_templates(socket.assigns.limits)

    socket =
      socket
      |> assign(:show_create_modal, true)
      |> assign(:selected_template, nil)
      |> assign(:portfolio_title, "")
      |> assign(:lab_templates, lab_templates)

    {:noreply, socket}
  end

  # ... [Keep all other existing event handlers unchanged] ...

  # ============================================================================
  # CHANNELS & LAB HELPER FUNCTIONS
  # ============================================================================

  defp get_user_channels(user) do
    Channels.list_user_channels(user.id)
    |> Enum.map(&enhance_channel_data/1)
  end

  defp get_channel_recommendations(user) do
    try do
      alias Frestyl.Channels.Channel
      alias Frestyl.Repo
      import Ecto.Query

      # Get some public channels as recommendations
      query = from c in Channel,
        where: c.visibility == "public" and c.archived == false,
        order_by: [desc: c.inserted_at],
        limit: 5

      channels = Repo.all(query)

      # Transform to the expected format with enhancement
      channels
      |> Enum.map(&enhance_channel_data/1)
      |> Enum.take(3)  # Limit to 3 recommendations
    rescue
      _ -> []
    end
  end

  defp get_trending_channels(user) do
    try do
      alias Frestyl.Channels.Channel
      alias Frestyl.Repo
      import Ecto.Query

      # Get some public channels as "trending" channels
      query = from c in Channel,
        where: c.visibility == "public" and c.archived == false,
        order_by: [desc: c.updated_at],  # Order by most recently updated
        limit: 6

      channels = Repo.all(query)

      # Transform to the expected format with enhancement
      channels
      |> Enum.map(&enhance_channel_data/1)
      |> Enum.take(5)  # Limit to 5 trending channels
    rescue
      _ -> []
    end
  end

  defp get_lab_features_for_user(user, limits) do
    base_features = [
      %{
        id: "bio_generator",
        name: "AI Bio Generator",
        description: "Generate compelling creator bios",
        icon: "✨",
        category: "content",
        tier_required: "free",
        time_limit: get_lab_time_limit(limits, "bio_generator"),
        estimated_time: "5 min"
      },
      %{
        id: "portfolio_layouts",
        name: "Experimental Layouts",
        description: "Try cutting-edge portfolio designs",
        icon: "🎨",
        category: "design",
        tier_required: "pro",
        time_limit: get_lab_time_limit(limits, "portfolio_layouts"),
        estimated_time: "15 min"
      },
      %{
        id: "collaboration_cipher",
        name: "Cipher Collaboration",
        description: "Anonymous creative partnership",
        icon: "🔐",
        category: "collaboration",
        tier_required: "premium",
        time_limit: get_lab_time_limit(limits, "collaboration_cipher"),
        estimated_time: "30 min"
      },
      %{
        id: "ab_testing",
        name: "Portfolio A/B Testing",
        description: "Test different versions with real users",
        icon: "📊",
        category: "analytics",
        tier_required: "premium",
        time_limit: get_lab_time_limit(limits, "ab_testing"),
        estimated_time: "Ongoing"
      },
      %{
        id: "brainstorm_room",
        name: "Brainstorm Room",
        description: "Structured creative ideation sessions",
        icon: "💡",
        category: "collaboration",
        tier_required: "pro",
        time_limit: get_lab_time_limit(limits, "brainstorm_room"),
        estimated_time: "45 min"
      },
      %{
        id: "stranger_collab",
        name: "Stranger Collaboration",
        description: "Get matched with creators worldwide",
        icon: "🌍",
        category: "collaboration",
        tier_required: "pro",
        time_limit: get_lab_time_limit(limits, "stranger_collab"),
        estimated_time: "60 min"
      }
    ]

    # Filter by tier and add availability status
    base_features
    |> Enum.filter(&(tier_available?(user, &1.tier_required)))
    |> Enum.map(&add_availability_status(&1, user))
  end

  defp get_active_experiments(user_id) do
    Lab.list_active_experiments(user_id)
  end

  defp get_lab_recommendations(user, portfolios) do
    [
      %{
        id: "bio_for_portfolio",
        feature_id: "bio_generator",
        title: "Generate Creator Bio",
        description: "Add a compelling bio to your latest portfolio",
        portfolio: List.first(portfolios),
        urgency: "high"
      },
      %{
        id: "layout_experiment",
        feature_id: "portfolio_layouts",
        title: "Try New Layout",
        description: "Experiment with gallery-style portfolio layout",
        portfolio: get_most_viewed_portfolio(portfolios),
        urgency: "medium"
      }
    ]
    |> Enum.filter(& &1.portfolio != nil)
  end

  defp get_featured_creators(user) do
    # Get creators in similar industries with great portfolios
    Accounts.get_featured_creators_for_user(user.id)
    |> Enum.map(&enhance_creator_data/1)
  end

  defp get_collaboration_opportunities(user) do
    # Get open collaboration requests from channels and direct invitations
    [
      %{
        id: "collab_1",
        type: "portfolio_feedback",
        title: "Looking for UX feedback",
        creator: "Sarah Chen",
        skills_needed: ["UX Design", "User Research"],
        estimated_time: "2 hours",
        compensation: "Credit in project",
        urgency: "medium"
      },
      %{
        id: "collab_2",
        type: "joint_project",
        title: "Music video collaboration",
        creator: "Alex Rivera",
        skills_needed: ["Video Production", "Motion Graphics"],
        estimated_time: "1 week",
        compensation: "Revenue share",
        urgency: "high"
      }
    ]
  end

  defp create_portfolio_collaboration_channel(user, portfolio) do
    channel_attrs = %{
      name: "#{portfolio.title} - Collaboration",
      description: "Collaborative workspace for enhancing #{portfolio.title}",
      visibility: "private",
      channel_type: "portfolio_collaboration",
      color_scheme: %{
        "primary" => "#8B5CF6",
        "secondary" => "#EC4899",
        "accent" => "#F59E0B"
      },
      tagline: "Enhancing #{portfolio.title}",
      social_links: %{
        "portfolio_url" => "/p/#{portfolio.slug}"
      },
      featured_content: [
        %{"type" => "portfolio", "id" => portfolio.id}
      ]
    }

    Channels.create_channel(channel_attrs, user)
  end

  defp create_enhancement_channel_session(user, portfolio, enhancement_type) do
    # Create channel first
    case create_portfolio_collaboration_channel(user, portfolio) do
      {:ok, channel} ->
        # Create Studio session in the channel
        session_attrs = %{
          title: "#{format_enhancement_type(enhancement_type)} Session",
          description: "Working on #{enhancement_type} for #{portfolio.title}",
          session_type: map_enhancement_to_session_type(enhancement_type),
          channel_id: channel.id,
          creator_id: user.id,
          is_public: false
        }

        case Studio.create_session(session_attrs) do
          {:ok, session} ->
            {:ok, channel, session}
          {:error, reason} ->
            # Clean up channel if session creation fails
            Channels.delete_channel(channel.id)
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_collaboration_from_opportunity(user, opportunity_id) do
    # Find the opportunity and create appropriate collaboration space
    # This would create a channel or join an existing collaboration

    # Placeholder implementation
    channel_attrs = %{
      name: "Collaboration Project",
      description: "New collaboration workspace",
      visibility: "private",
      channel_type: "collaboration"
    }

    Channels.create_channel(channel_attrs, user)
  end

  defp redirect_to_experiment(socket, experiment) do
    case experiment.feature_id do
      "bio_generator" ->
        push_navigate(socket, to: "/lab/bio-generator/#{experiment.id}")
      "portfolio_layouts" ->
        push_navigate(socket, to: "/lab/layouts/#{experiment.id}")
      "collaboration_cipher" ->
        push_navigate(socket, to: "/lab/cipher/#{experiment.id}")
      "ab_testing" ->
        push_navigate(socket, to: "/lab/ab-test/#{experiment.id}")
      "brainstorm_room" ->
        push_navigate(socket, to: "/lab/brainstorm/#{experiment.id}")
      "stranger_collab" ->
        push_navigate(socket, to: "/lab/stranger-collab/#{experiment.id}")
      _ ->
        push_navigate(socket, to: "/lab")
    end
  end

  defp get_lab_portfolio_templates(limits) do
    base_templates = [
      %{id: "gallery", name: "Gallery", type: "stable"},
      %{id: "minimal", name: "Minimal", type: "stable"},
      %{id: "dashboard", name: "Dashboard", type: "stable"}
    ]

    lab_templates = if tier_available?(%{subscription_tier: limits.subscription_tier}, "pro") do
      [
        %{id: "holographic", name: "Holographic", type: "lab", tier: "pro"},
        %{id: "kinetic", name: "Kinetic", type: "lab", tier: "pro"},
        %{id: "immersive", name: "Immersive", type: "lab", tier: "premium"}
      ]
    else
      []
    end

    base_templates ++ lab_templates
  end

  # Helper functions for tier and time management
  defp tier_available?(user, required_tier) do
    current_tier = user.subscription_tier || "free"
    tier_hierarchy = %{"free" => 0, "pro" => 1, "premium" => 2}

    Map.get(tier_hierarchy, current_tier, 0) >= Map.get(tier_hierarchy, required_tier, 0)
  end

defp get_lab_time_limit(user, limits) do
  # Get subscription tier from user, not from limits
  subscription_tier = Map.get(user, :subscription_tier, "free")

  case subscription_tier do
    "pro" -> 60  # 60 minutes for pro users
    "premium" -> 120  # 120 minutes for premium users
    _ -> 30  # 30 minutes for free users
  end
rescue
  _ -> 30  # Default fallback
end

#  Also fix get_lab_features_for_user/2 if it has similar issues
  defp get_lab_features_for_user(user, limits) do
    # Get subscription tier from user
    subscription_tier = Map.get(user, :subscription_tier, "free")

    base_features = %{
      time_limit_minutes: get_lab_time_limit(user, limits),
      can_export_sessions: subscription_tier != "free",
      can_invite_collaborators: subscription_tier in ["pro", "premium"],
      max_concurrent_sessions: case subscription_tier do
        "premium" -> 5
        "pro" -> 3
        _ -> 1
      end,
      advanced_tools: subscription_tier == "premium",
      priority_support: subscription_tier in ["pro", "premium"]
    }

    # Merge with any additional features from limits if needed
    Map.merge(base_features, %{
      collaboration_features: Map.get(limits, :collaboration_features, true),
      video_recording: Map.get(limits, :video_recording, true)
    })
  rescue
    _ ->
      # Fallback features for free tier
      %{
        time_limit_minutes: 30,
        can_export_sessions: false,
        can_invite_collaborators: false,
        max_concurrent_sessions: 1,
        advanced_tools: false,
        priority_support: false,
        collaboration_features: true,
        video_recording: true
      }
  end

  defp add_availability_status(feature, user) do
    time_used = Lab.get_time_used_this_month(user.id, feature.id)
    time_remaining = max(0, feature.time_limit - time_used)

    Map.merge(feature, %{
      time_used: time_used,
      time_remaining: time_remaining,
      available: time_remaining > 0 || feature.time_limit == 999
    })
  end

  defp enhance_channel_data({channel, _index}) when is_struct(channel) do
    # Handle tuple format where the second element might be an index or count
    enhance_channel_data(channel)
  end

  defp enhance_channel_data(channel) when is_struct(channel) do
    %{
      id: channel.id,
      name: channel.name,
      description: channel.description,
      slug: channel.slug,
      visibility: channel.visibility,
      channel_type: channel.channel_type || "general",
      color_scheme: channel.color_scheme || %{
        "primary" => "#8B5CF6",
        "secondary" => "#00D4FF",
        "accent" => "#FF0080"
      },
      tagline: channel.tagline,
      hero_image_url: channel.hero_image_url,
      member_count: 0,  # Simplified - replace with actual count if needed
      activity_score: 0, # Simplified - replace with actual calculation if needed
      inserted_at: channel.inserted_at,
      updated_at: channel.updated_at
    }
  end

  defp enhance_channel_data(data) do
    # Fallback for unexpected data format
    IO.warn("Unexpected data format in enhance_channel_data: #{inspect(data)}")
    %{
      id: nil,
      name: "Unknown Channel",
      description: nil,
      slug: "unknown",
      visibility: "private",
      channel_type: "general",
      color_scheme: %{"primary" => "#8B5CF6", "secondary" => "#00D4FF", "accent" => "#FF0080"},
      tagline: nil,
      hero_image_url: nil,
      member_count: 0,
      activity_score: 0,
      inserted_at: nil,
      updated_at: nil
    }
  end

  defp enhance_channel_recommendation(channel) do
    Map.merge(channel, %{
      member_count: Channels.get_member_count(channel.id),
      activity_level: Channels.calculate_activity_level(channel.id),
      recommendation_reason: Channels.get_recommendation_reason(channel.id)
    })
  end

  defp enhance_creator_data(creator) do
    Map.merge(creator, %{
      portfolio_count: Portfolios.count_user_portfolios(creator.id),
      follower_count: Accounts.get_follower_count(creator.id),
      featured_work: Portfolios.get_featured_portfolio(creator.id),
      is_following: false # This would be checked against current user
    })
  end

  defp update_creator_follow_status(creators, user_id, following_status) do
    Enum.map(creators, fn creator ->
      if creator.id == String.to_integer(user_id) do
        Map.put(creator, :is_following, following_status)
      else
        creator
      end
    end)
  end

  defp get_most_viewed_portfolio(portfolios) do
    portfolios
    |> Enum.max_by(&(&1.view_count || 0), fn -> nil end)
  end

  defp map_enhancement_to_session_type(enhancement_type) do
    case enhancement_type do
      "voice_intro" -> "voice_recording"
      "enhance_writing" -> "collaborative_writing"
      "background_music" -> "music_creation"
      "design_feedback" -> "design_review"
      _ -> "general_collaboration"
    end
  end

  defp format_enhancement_type(enhancement_type) do
    case enhancement_type do
      "voice_intro" -> "Voice Introduction"
      "enhance_writing" -> "Writing Enhancement"
      "background_music" -> "Background Music"
      "design_feedback" -> "Design Feedback"
      _ -> String.capitalize(String.replace(enhancement_type, "_", " "))
    end
  end

  # Keep all existing helper functions unchanged...
  defp check_first_visit(user, params) do
    Map.get(params, "first") == "true" or
    not user.onboarding_completed or
    Portfolios.count_user_portfolios(user.id) == 1
  end

  defp get_recently_created_portfolio(portfolios) do
    portfolios
    |> Enum.filter(&created_recently?/1)
    |> List.first()
  end

  defp created_recently?(portfolio) do
    now = DateTime.utc_now()

    # Convert the portfolio's inserted_at to DateTime if it's NaiveDateTime
    case portfolio.inserted_at do
      %DateTime{} = dt ->
        # Check if created within last 24 hours (86400 seconds)
        DateTime.diff(now, dt, :second) < 86400
      %NaiveDateTime{} = ndt ->
        # Convert NaiveDateTime to DateTime assuming UTC
        portfolio_time = DateTime.from_naive!(ndt, "Etc/UTC")
        DateTime.diff(now, portfolio_time, :second) < 86400
      _ ->
        # Fallback if it's neither type
        false
    end
  rescue
    # If any error occurs in date conversion, assume not recent
    _ -> false
  end

  defp safe_get_user_overview(user_id) do
    try do
      Portfolios.get_user_portfolio_overview(user_id)
    rescue
      _ -> %{total_views: 0, total_portfolios: 0, total_collaborations: 0}
    end
  end

  defp build_portfolio_stats(portfolios, user_id) do
    Enum.map(portfolios, fn portfolio ->
      stats = safe_get_portfolio_analytics(portfolio.id, user_id)
      collaborations = get_portfolio_collaborations(portfolio.id)
      comments = get_portfolio_comments(portfolio.id)

      {portfolio.id, %{
        stats: stats,
        collaborations: collaborations,
        comments: comments,
        needs_feedback: length(comments) == 0 && created_recently?(portfolio)
      }}
    end) |> Enum.into(%{})
  end

  defp safe_get_portfolio_analytics(portfolio_id, user_id) do
    try do
      Portfolios.get_portfolio_analytics(portfolio_id, user_id)
    rescue
      _ -> %{total_visits: 0, unique_visitors: 0, shares: 0, comments: 0}
    end
  end

  defp get_enhanced_activity_feed(user_id) do
    portfolio_activity = get_portfolio_activity(user_id)
    channel_activity = get_channel_activity(user_id)
    lab_activity = get_lab_activity(user_id)

    (portfolio_activity ++ channel_activity ++ lab_activity)
    |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
    |> Enum.take(10)
  end

  defp get_channel_activity(user_id) do
    [
      %{
        id: "channel_1",
        type: :channel_joined,
        user: "You",
        channel: "UX Design Community",
        time: "1 hour ago",
        timestamp: DateTime.utc_now() |> DateTime.add(-1, :hour),
        description: "joined channel",
        icon: "🏠"
      },
      %{
        id: "channel_2",
        type: :collaboration_started,
        user: "Maria Garcia",
        channel: "Portfolio Feedback",
        time: "3 hours ago",
        timestamp: DateTime.utc_now() |> DateTime.add(-3, :hour),
        description: "started a collaboration session",
        icon: "🤝"
      }
    ]
  end

  defp get_lab_activity(user_id) do
    [
      %{
        id: "lab_1",
        type: :experiment_completed,
        user: "You",
        experiment: "Bio Generator",
        time: "30 minutes ago",
        timestamp: DateTime.utc_now() |> DateTime.add(-30, :minute),
        description: "completed bio generation experiment",
        icon: "⚗️"
      },
      %{
        id: "lab_2",
        type: :layout_experiment_started,
        user: "You",
        experiment: "Holographic Layout",
        time: "2 days ago",
        timestamp: DateTime.utc_now() |> DateTime.add(-2, :day),
        description: "started testing new portfolio layout",
        icon: "🎨"
      }
    ]
  end

  defp get_portfolio_activity(user_id) do
    [
      %{
        id: "portfolio_1",
        type: :portfolio_view,
        user: "Anonymous",
        portfolio: "My Creative Portfolio",
        time: "5 minutes ago",
        timestamp: DateTime.utc_now() |> DateTime.add(-5, :minute),
        description: "viewed your portfolio",
        count: 3,
        icon: "👁️"
      }
    ]
  end

  defp get_collaboration_requests(user_id) do
    [
      %{
        id: 1,
        user: "Alex Chen",
        type: "feedback",
        portfolio: "UX Case Study",
        message: "Would love feedback on my latest case study",
        time: "2 hours ago"
      },
      %{
        id: 2,
        user: "Sarah Miller",
        type: "collaboration",
        portfolio: "Music Video Project",
        message: "Looking for motion graphics collaboration",
        time: "1 day ago"
      }
    ]
  end

  defp get_portfolio_collaborations(portfolio_id) do
    [
      %{user: "Maria", role: "Feedback Provider"},
      %{user: "John", role: "Co-creator"}
    ]
  end

  defp get_portfolio_comments(portfolio_id) do
    []
  end

  defp track_enhancement_created(user_id, portfolio_id, enhancement_type) do
    Analytics.track_event("enhancement_created", %{
      user_id: user_id,
      portfolio_id: portfolio_id,
      enhancement_type: enhancement_type,
      source: "portfolio_hub_channels"
    })
  end

  defp get_onboarding_state(user, portfolios, limits) do
    %{
      completed_steps: [],
      next_steps: ["create_portfolio", "join_channel", "try_lab_feature"],
      progress: 30
    }
  end

  defp assign_mobile_state(socket) do
    socket
    |> assign(:show_mobile_menu, false)
    |> assign(:show_mobile_filters, false)
    |> assign(:show_mobile_sidebar, false)
    |> assign(:show_mobile_actions, false)
    |> assign(:mobile_view_mode, "cards")
    |> assign(:mobile_filter_active, false)
    |> assign(:mobile_gesture_enabled, true)
    |> assign(:active_tab, "overview")
    |> assign(:selected_template, nil)
    |> assign(:portfolio_title, "")
  end

  # Add these functions to your FrestylWeb.PortfolioHubLive module

  defp relative_date(datetime) when is_nil(datetime), do: "Never"
  defp relative_date(datetime) do
    current_time = DateTime.utc_now()

    datetime_utc = case datetime do
      %DateTime{} -> datetime
      %NaiveDateTime{} ->
        DateTime.from_naive!(datetime, "Etc/UTC")
      _ -> current_time
    end

    case DateTime.diff(current_time, datetime_utc, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)} minutes ago"
      diff when diff < 86400 -> "#{div(diff, 3600)} hours ago"
      diff when diff < 604800 -> "#{div(diff, 86400)} days ago"
      _ -> Calendar.strftime(datetime_utc, "%b %d, %Y")
    end
  rescue
    _ -> "Unknown time"
  end

  # Function 2: get_filtered_portfolios/2 - filters portfolios by status
  defp get_filtered_portfolios(portfolios, filter_status) when is_list(portfolios) do
    case filter_status do
      "all" -> portfolios
      "public" -> Enum.filter(portfolios, &(&1.visibility == :public))
      "private" -> Enum.filter(portfolios, &(&1.visibility == :private))
      "link_only" -> Enum.filter(portfolios, &(&1.visibility == :link_only))
      "draft" -> Enum.filter(portfolios, &(Map.get(&1, :status) == :draft))
      _ -> portfolios
    end
  end
  defp get_filtered_portfolios(_, _), do: []
end
