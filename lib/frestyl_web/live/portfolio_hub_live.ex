# lib/frestyl_web/live/portfolio_hub_live.ex - CHANNELS & LAB INTEGRATION

defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  alias Frestyl.{Accounts, Portfolios, Channels, Billing, Lab, Features, Analytics, Studio}
  alias FrestylWeb.PortfolioHubLive.{Helpers, EnhancementEngine}


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
    recent_activities = get_recent_activities(user.id)
    collaboration_requests = Helpers.get_collaboration_requests(user.id)

    # Enhanced portfolio stats with better error handling
    portfolio_stats = calculate_portfolio_stats(portfolios)
    enhancement_suggestions = generate_enhancement_suggestions(portfolios, user)

    # CHANNELS INTEGRATION
    user_channels = get_user_channels(user)
    channel_recommendations = get_channel_recommendations(user)
    trending_channels = get_trending_channels(user)

    # LAB INTEGRATION - Temporarily disabled to fix cast error
    lab_features = []  # get_lab_features_for_user(user, limits)
    active_experiments = []  # get_active_experiments(user.id)
    lab_recommendations = []  # get_lab_recommendations(user, portfolios)

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
      |> assign(:collaboration_mode, false)
      |> assign(:enhancement_suggestions, [])
      |> assign(:show_enhancement_modal, false)
      |> assign(:quarterly_reminders, [])
      |> assign(:show_studio_welcome_modal, false)
      |> assign(:show_studio_modal, false)          # Main studio modal
      |> assign(:selected_enhancement, nil)         # Selected enhancement type
      |> assign(:studio_mode, nil)                  # e.g., "enhancement", "creation"
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

  @impl true
  def handle_event("show_studio_modal", params, socket) do
    mode = Map.get(params, "mode", "general")
    enhancement_type = Map.get(params, "enhancement_type")

    {:noreply,
    socket
    |> assign(:show_studio_modal, true)
    |> assign(:studio_mode, mode)
    |> assign(:selected_enhancement, enhancement_type)}
  end

  @impl true
  def handle_event("hide_studio_modal", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_studio_modal, false)
    |> assign(:studio_mode, nil)
    |> assign(:selected_enhancement, nil)}
  end

  @impl true
  def handle_event("show_studio_welcome", _params, socket) do
    {:noreply, assign(socket, :show_studio_welcome_modal, true)}
  end

  @impl true
  def handle_event("hide_studio_welcome", _params, socket) do
    {:noreply, assign(socket, :show_studio_welcome_modal, false)}
  end

  @impl true
  def handle_event("select_enhancement", %{"type" => enhancement_type, "portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    {:noreply,
    socket
    |> assign(:show_studio_modal, true)
    |> assign(:studio_mode, "enhancement")
    |> assign(:selected_enhancement, enhancement_type)
    |> assign(:selected_portfolio, portfolio)}
  end

  @impl true
  def handle_event("create_studio_channel", %{"enhancement_type" => type, "portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    # Create a new channel for this enhancement
    case create_enhancement_channel(socket.assigns.current_user, portfolio, type) do
      {:ok, channel} ->
        {:noreply,
        socket
        |> assign(:show_studio_modal, false)
        |> put_flash(:info, "Studio workspace created!")
        |> push_navigate(to: "/channel/#{channel.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create studio workspace")}
    end
  end

  defp create_enhancement_channel(user, portfolio, enhancement_type) do
    channel_name = "#{portfolio.title} - #{format_enhancement_name(enhancement_type)}"

    channel_attrs = %{
      name: channel_name,
      description: "Studio workspace for enhancing #{portfolio.title}",
      channel_type: "portfolio_#{enhancement_type}",
      visibility: "private",
      featured_content: [%{"type" => "portfolio", "id" => portfolio.id}],
      user_id: user.id
    }

    # Create the channel using your Channels context
    Frestyl.Channels.create_channel(channel_attrs)
  end

  defp format_enhancement_name(type) do
    case type do
      "video_introduction" -> "Video Introduction"
      "content_writing" -> "Content Writing"
      "music_background" -> "Background Music"
      "design_review" -> "Design Review"
      _ -> String.capitalize(type)
    end
  end

  def handle_event("start_enhancement", %{"suggestion_id" => suggestion_id}, socket) do
    suggestion = Enum.find(socket.assigns.enhancement_suggestions, &(&1.id == suggestion_id))

    if suggestion && suggestion.can_collaborate do
      socket = socket
      |> assign(:selected_enhancement, suggestion)
      |> assign(:show_enhancement_modal, true)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Upgrade your plan to access collaborative enhancements")}
    end
  end

  def handle_event("close_enhancement_modal", _params, socket) do
    socket = socket
    |> assign(:show_enhancement_modal, false)
    |> assign(:selected_enhancement, nil)

    {:noreply, socket}
  end

  def handle_event("create_enhancement_channel", %{"suggestion_id" => suggestion_id, "invite_collaborators" => invite_collaborators}, socket) do
    suggestion = socket.assigns.selected_enhancement
    user = socket.assigns.current_user

    # Create portfolio-specific collaboration channel
    channel_attrs = %{
      name: "#{suggestion.portfolio_title} - #{suggestion.title}",
      description: suggestion.description,
      channel_type: suggestion.type,
      visibility: "private",
      user_id: user.id,
      featured_content: [%{
        "type" => "portfolio",
        "id" => suggestion.portfolio_id
      }]
    }

    case Channels.create_channel(channel_attrs) do
      {:ok, channel} ->
        # Track collaboration usage
        Billing.UsageTracker.track_usage(user.account, :collaboration_creation, 1, %{
          enhancement_type: suggestion.type,
          portfolio_id: suggestion.portfolio_id
        })

        # Handle collaborator invitations if specified
        if invite_collaborators do
          send_enhancement_invitations(channel, suggestion.type, user)
        end

        # Update enhancement tracking
        track_enhancement_start(suggestion.portfolio_id, suggestion.type)

        {:noreply,
         socket
         |> put_flash(:info, "Enhancement collaboration started! Redirecting to Studio...")
         |> push_navigate(to: "/studio/#{channel.slug}")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create enhancement channel")}
    end
  end

    def handle_event("accept_collaboration", %{"request_id" => request_id}, socket) do
    # Handle collaboration request acceptance
    case accept_collaboration_request(request_id, socket.assigns.current_user.id) do
      {:ok, collaboration} ->
        # Update collaboration requests list
        updated_requests = Enum.reject(socket.assigns.collaboration_requests, &(&1.id == String.to_integer(request_id)))

        {:noreply,
        socket
        |> assign(:collaboration_requests, updated_requests)
        |> put_flash(:info, "Collaboration request accepted!")
        |> push_navigate(to: "/studio/#{collaboration.channel_slug}")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to accept collaboration: #{reason}")}
    end
  end

  def handle_event("decline_collaboration", %{"request_id" => request_id}, socket) do
    case decline_collaboration_request(request_id, socket.assigns.current_user.id) do
      {:ok, _} ->
        updated_requests = Enum.reject(socket.assigns.collaboration_requests, &(&1.id == String.to_integer(request_id)))

        {:noreply,
        socket
        |> assign(:collaboration_requests, updated_requests)
        |> put_flash(:info, "Collaboration request declined")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to decline collaboration: #{reason}")}
    end
  end

  def handle_event("view_all_requests", _params, socket) do
    {:noreply, push_navigate(socket, to: "/collaboration/requests")}
  end

  def handle_event("show_upgrade_modal", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/subscription")}
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

  defp get_featured_creators(_user) do
    []  # Return empty list to disable featured creators
  end

  defp generate_enhancement_suggestions(portfolios) do
    Enum.map(portfolios, fn portfolio ->
      %{
        id: "suggestion_#{portfolio.id}",
        portfolio_id: portfolio.id,
        type: "video_introduction",
        title: "Add Video Introduction",
        description: "Make your portfolio more engaging with a personal video",
        priority: 3,
        estimated_time: "15-30 minutes"
      }
    end)
    |> Enum.take(3)  # Limit to top 3 suggestions
  end

  defp generate_enhancement_suggestions(portfolios, user) do
    suggestions = []

    Enum.reduce(portfolios, suggestions, fn portfolio, acc ->
      quality_score = calculate_portfolio_quality_score(portfolio)
      completion_data = get_portfolio_completion_data(portfolio)

      portfolio_suggestions = []

      # Voice-over enhancement trigger
      if needs_voice_enhancement?(portfolio, quality_score) do
        voice_suggestion = %{
          id: "voice_#{portfolio.id}",
          type: "portfolio_voice_over",
          priority: get_enhancement_priority(quality_score, :voice),
          portfolio_id: portfolio.id,
          portfolio_title: portfolio.title,
          title: "Add Professional Voice Introduction",
          description: "Create a compelling voice introduction to make your portfolio stand out",
          estimated_time: "30-45 minutes",
          collaboration_type: "voice_recording",
          benefits: ["Increase engagement by 40%", "Personal connection with viewers", "Professional presentation"],
          can_collaborate: can_access_collaboration?(user, :portfolio_voice_over),
          completion_percentage: completion_data.voice_completion || 0
        }
        portfolio_suggestions = [voice_suggestion | portfolio_suggestions]
      end

      # Writing enhancement trigger
      if needs_writing_enhancement?(portfolio, quality_score) do
        writing_suggestion = %{
          id: "writing_#{portfolio.id}",
          type: "portfolio_writing",
          priority: get_enhancement_priority(quality_score, :writing),
          portfolio_id: portfolio.id,
          portfolio_title: portfolio.title,
          title: "Enhance Content & Descriptions",
          description: "Collaborate with professional writers to polish your portfolio content",
          estimated_time: "2-3 hours",
          collaboration_type: "content_writing",
          benefits: ["Clear, compelling descriptions", "Better SEO optimization", "Professional tone"],
          can_collaborate: can_access_collaboration?(user, :portfolio_writing),
          completion_percentage: completion_data.writing_completion || 0
        }
        portfolio_suggestions = [writing_suggestion | portfolio_suggestions]
      end

      # Design enhancement trigger
      if needs_design_enhancement?(portfolio, quality_score) do
        design_suggestion = %{
          id: "design_#{portfolio.id}",
          type: "portfolio_design",
          priority: get_enhancement_priority(quality_score, :design),
          portfolio_id: portfolio.id,
          portfolio_title: portfolio.title,
          title: "Visual Design Improvements",
          description: "Work with designers to create stunning visual elements",
          estimated_time: "1-2 hours",
          collaboration_type: "design_review",
          benefits: ["Modern, professional appearance", "Better visual hierarchy", "Increased credibility"],
          can_collaborate: can_access_collaboration?(user, :portfolio_design),
          completion_percentage: completion_data.design_completion || 0
        }
        portfolio_suggestions = [design_suggestion | portfolio_suggestions]
      end

      # Music enhancement trigger
      if needs_music_enhancement?(portfolio, quality_score) do
        music_suggestion = %{
          id: "music_#{portfolio.id}",
          type: "portfolio_music",
          priority: get_enhancement_priority(quality_score, :music),
          portfolio_id: portfolio.id,
          portfolio_title: portfolio.title,
          title: "Custom Background Music",
          description: "Add custom background music to create the perfect mood",
          estimated_time: "45-60 minutes",
          collaboration_type: "music_creation",
          benefits: ["Emotional engagement", "Memorable experience", "Professional polish"],
          can_collaborate: can_access_collaboration?(user, :portfolio_music),
          completion_percentage: completion_data.music_completion || 0
        }
        portfolio_suggestions = [music_suggestion | portfolio_suggestions]
      end

      acc ++ portfolio_suggestions
    end)
    |> Enum.sort_by(& &1.priority, :desc)
    |> Enum.take(6) # Limit to top 6 suggestions
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

  defp get_portfolio_title(portfolio_id, portfolios) when is_binary(portfolio_id) do
    get_portfolio_title(String.to_integer(portfolio_id), portfolios)
  rescue
    ArgumentError -> "Unknown Portfolio"
  end

  defp get_portfolio_title(portfolio_id, portfolios) when is_integer(portfolio_id) do
    case Enum.find(portfolios, &(&1.id == portfolio_id)) do
      %{title: title} -> title
      nil -> "Unknown Portfolio"
    end
  end

  defp get_portfolio_title(_, _), do: "Unknown Portfolio"

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

  defp generate_quarterly_reminders(user, portfolios) do
    now = DateTime.utc_now()

    [
      %{
        id: "reminder_1",
        type: "portfolio_update",
        title: "Update Your Portfolio",
        description: "It's been a while since your last portfolio update. Add your recent work!",
        due_date: DateTime.add(now, 7, :day),
        priority: "medium",
        portfolio_id: List.first(portfolios) && List.first(portfolios).id
      },
      %{
        id: "reminder_2",
        type: "skills_review",
        title: "Review Your Skills",
        description: "Review and update your skills section with new technologies you've learned",
        due_date: DateTime.add(now, 14, :day),
        priority: "low",
        portfolio_id: nil
      }
    ]
    |> Enum.filter(fn reminder ->
      # Only show relevant reminders
      case reminder.type do
        "portfolio_update" -> length(portfolios) > 0
        _ -> true
      end
    end)
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
      _ -> %{total_visits: 0, total_portfolios: 0, total_collaborations: 0}
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

    @doc """
  Track enhancement start for billing/analytics
  """
  defp track_enhancement_start(portfolio_id, enhancement_type) do
    case Portfolios.get_portfolio(portfolio_id) do
      nil -> :ok
      portfolio ->
        case get_portfolio_user_account(portfolio) do
          nil -> :ok
          account ->
            Billing.UsageTracker.track_usage(
              account,
              :enhancement_session_start,
              1,
              %{
                portfolio_id: portfolio_id,
                enhancement_type: enhancement_type,
                started_at: DateTime.utc_now()
              }
            )
        end
    end
  end

  @doc """
  Track enhancement creation
  """
  defp track_enhancement_created(user_id, portfolio_id, enhancement_type) do
    user = Accounts.get_user(user_id)
    account = user.account || %{subscription_tier: "personal"}

    Billing.UsageTracker.track_usage(
      account,
      :enhancement_created,
      1,
      %{
        user_id: user_id,
        portfolio_id: portfolio_id,
        enhancement_type: enhancement_type,
        created_at: DateTime.utc_now()
      }
    )
  end

  @doc """
  Get portfolio completion data
  """
  defp get_portfolio_completion_data(portfolio) do
    # Use the CompletionTracker if available, otherwise mock data
    try do
      Frestyl.Portfolios.CompletionTracker.get_portfolio_completion_data(portfolio.id)
    rescue
      _ ->
        # Fallback mock data
        %{
          voice_completion: 0,
          writing_completion: 0,
          design_completion: 0,
          music_completion: 0,
          overall_completion: 0,
          last_enhancement: nil,
          total_enhancements: 0,
          enhancement_streak: 0,
          quality_trajectory: %{trend: :new, improvement_points: 0},
          collaboration_score: 0
        }
    end
  end

  # ============================================================================
  # QUALITY SCORING FUNCTIONS
  # ============================================================================

  defp calculate_portfolio_quality_score(portfolio) do
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
    content_sections = Enum.filter(sections, &(&1.type in ["about", "experience", "projects"]))

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

  defp assess_visual_consistency(portfolio) do
    portfolio.theme != nil && portfolio.customization != nil
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

  # ============================================================================
  # HELPER CHECK FUNCTIONS
  # ============================================================================

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
    false # Mock - implement based on your schema
  end

  defp has_interactive_elements?(portfolio) do
    false # Mock - implement based on your schema
  end

  defp has_social_links?(portfolio) do
    social_links = portfolio.social_links || %{}
    map_size(social_links) > 0
  end

  defp has_cta?(portfolio) do
    portfolio.contact_info != nil
  end

  defp has_custom_domain?(portfolio) do
    false # Mock - implement based on your schema
  end

  defp has_professional_contact?(portfolio) do
    contact_info = portfolio.contact_info || %{}
    map_size(contact_info) > 0
  end

  defp has_complete_contact?(portfolio) do
    contact = portfolio.contact_info || %{}
    Map.has_key?(contact, "email") && Map.has_key?(contact, "phone")
  end

  defp has_seo_optimization?(portfolio) do
    portfolio.meta_description != nil
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

  # ============================================================================
  # STATISTICS FUNCTIONS
  # ============================================================================

  defp calculate_portfolio_stats(portfolios) do
    total_portfolios = length(portfolios)
    total_views = Enum.sum(Enum.map(portfolios, &get_portfolio_views/1))

    avg_quality = if total_portfolios > 0 do
      total_quality = Enum.sum(Enum.map(portfolios, fn portfolio ->
        calculate_portfolio_quality_score(portfolio).total
      end))
      Float.round(total_quality / total_portfolios, 1)
    else
      0
    end

    enhancement_breakdown = calculate_enhancement_breakdown(portfolios)
    enhancement_completion_rate = calculate_overall_enhancement_completion(portfolios)

    %{
      total_views: total_views,
      avg_quality_score: avg_quality,
      enhancement_completion_rate: enhancement_completion_rate,
      enhancement_breakdown: enhancement_breakdown
    }
  end

  defp get_portfolio_views(portfolio) do
    # Mock - replace with actual view counting
    :rand.uniform(100)
  end

  defp calculate_enhancement_breakdown(portfolios) do
    enhancement_types = ["voice_over", "writing", "design", "music"]

    Enum.map(enhancement_types, fn type ->
      completed_count = Enum.count(portfolios, &has_completed_enhancement?(&1, type))
      total_count = length(portfolios)
      percentage = if total_count > 0, do: Float.round(completed_count / total_count * 100, 1), else: 0

      {type, percentage}
    end)
  end

  defp calculate_overall_enhancement_completion(portfolios) do
    if length(portfolios) > 0 do
      total_possible = length(portfolios) * 4 # 4 enhancement types
      total_completed = Enum.reduce(portfolios, 0, fn portfolio, acc ->
        acc + count_completed_enhancements_for_portfolio(portfolio)
      end)

      if total_possible > 0 do
        Float.round(total_completed / total_possible * 100, 1)
      else
        0
      end
    else
      0
    end
  end

  defp has_completed_enhancement?(portfolio, enhancement_type) do
    # Mock - check if portfolio has completed this enhancement type
    :rand.uniform() > 0.6
  end

  defp count_completed_enhancements_for_portfolio(portfolio) do
    # Mock - count completed enhancements for a single portfolio
    :rand.uniform(4)
  end

  # ============================================================================
  # COLLABORATION FUNCTIONS
  # ============================================================================

  defp accept_collaboration_request(request_id, user_id) do
    case get_collaboration_request(request_id) do
      nil -> {:error, "Request not found"}
      request ->
        channel_attrs = %{
          name: "Collaboration: #{request.portfolio}",
          description: "Collaborative work on #{request.portfolio}",
          channel_type: "portfolio_#{request.type}",
          visibility: "private",
          user_id: request.requester_id
        }

        case Channels.create_channel(channel_attrs) do
          {:ok, channel} ->
            add_user_to_channel(channel.id, request.requester_id, "owner")
            add_user_to_channel(channel.id, user_id, "collaborator")
            update_collaboration_request(request_id, %{status: "accepted"})
            {:ok, %{channel_slug: channel.slug}}
          error -> error
        end
    end
  end

  defp decline_collaboration_request(request_id, user_id) do
    case get_collaboration_request(request_id) do
      nil -> {:error, "Request not found"}
      request ->
        update_collaboration_request(request_id, %{
          status: "declined",
          declined_by: user_id,
          declined_at: DateTime.utc_now()
        })
    end
  end

  defp get_collaboration_request(request_id) do
    # Mock - replace with actual database query
    %{
      id: request_id,
      requester_id: 1,
      portfolio: "Sample Portfolio",
      type: "writing",
      status: "pending"
    }
  end

  defp update_collaboration_request(request_id, updates) do
    # Mock - replace with actual database update
    IO.puts("Updating collaboration request #{request_id} with #{inspect(updates)}")
    {:ok, updates}
  end

  defp add_user_to_channel(channel_id, user_id, role) do
    # Mock - replace with actual channel membership creation
    IO.puts("Adding user #{user_id} to channel #{channel_id} as #{role}")
    :ok
  end

  # ============================================================================
  # SERVICE PROVIDER FUNCTIONS
  # ============================================================================

  defp send_enhancement_invitations(channel, enhancement_type, user) do
    if Features.FeatureGate.can_access_feature?(user.account, :service_provider_access) do
      providers = find_enhancement_service_providers(enhancement_type, user.location)

      Enum.each(providers, fn provider ->
        create_service_provider_invitation(channel, provider, enhancement_type)
      end)
    else
      suggest_service_provider_upgrade(user, enhancement_type)
    end
  end

  defp find_enhancement_service_providers(enhancement_type, user_location) do
    # Mock - replace with actual service provider query
    []
  end

  defp create_service_provider_invitation(channel, provider, enhancement_type) do
    # Mock - replace with actual invitation creation
    IO.puts("Creating service provider invitation for channel #{channel.id}")
    :ok
  end

  defp suggest_service_provider_upgrade(user, enhancement_type) do
    # Mock - suggest upgrade to access service providers
    IO.puts("Suggesting upgrade for user #{user.id} to access #{enhancement_type} providers")
    :ok
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp get_portfolio_user_account(portfolio) do
    cond do
      portfolio.user && portfolio.user.account ->
        portfolio.user.account

      portfolio.user_id ->
        case Accounts.get_user(portfolio.user_id) do
          nil -> nil
          user -> user.account
        end

      true ->
        nil
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

  defp calculate_quick_stats(portfolios, overview) do
    total_portfolios = length(portfolios)
    # FIX: Use :total_visits instead of :total_visits
    total_visits = Map.get(overview, :total_visits, 0)  # Changed from :total_visits
    public_portfolios = Enum.count(portfolios, &(&1.visibility == :public))

    %{
      total_portfolios: total_portfolios,
      total_visits: total_visits,  # This is what the template expects
      public_portfolios: public_portfolios,
      completion_rate: calculate_average_completion(portfolios)
    }
  end

  defp calculate_average_completion(portfolios) do
    if length(portfolios) == 0 do
      0
    else
      total_completion = portfolios
      |> Enum.map(&calculate_portfolio_completion/1)
      |> Enum.sum()

      round(total_completion / length(portfolios))
    end
  end

  defp calculate_portfolio_completion(portfolio) do
    try do
      sections = Portfolios.list_portfolio_sections(portfolio.id)

      case length(sections) do
        0 -> 25  # Base score for having a portfolio
        section_count ->
          base_score = 25
          section_score = min(50, section_count * 10)  # 10 points per section, max 50
          content_score = 25  # Simplified for now
          base_score + section_score + content_score
      end
    rescue
      _ -> 25  # Fallback score
    end
  end

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

  # Add these at the bottom of your PortfolioHubLive module
  defp get_lab_features_for_user(_user, _limits), do: []
  defp get_active_experiments(_user_id), do: []
  defp get_lab_recommendations(_user, _portfolios), do: []

  # Fix the problematic add_availability_status function
  defp add_availability_status(feature, _user) do
    Map.merge(feature, %{
      time_used: 0,
      time_remaining: 30,
      available: true
    })
  end

    defp calculate_portfolio_quality_score(portfolio) do
    sections = Portfolios.list_portfolio_sections(portfolio.id)

    # Base scoring components
    base_score = 0
    max_score = 100

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
      total: min(total_score, max_score),
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

    defp can_access_collaboration?(user, collaboration_type) do
    account = user.account || %{subscription_tier: "personal"}

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

  # Service provider booking integration
  defp send_enhancement_invitations(channel, enhancement_type, user) do
    # Check if user wants to invite service providers
    if Features.FeatureGate.can_access_feature?(user.account, :service_provider_access) do
      # Match with appropriate service providers
      providers = find_enhancement_service_providers(enhancement_type, user.location)

      Enum.each(providers, fn provider ->
        create_service_provider_invitation(channel, provider, enhancement_type)
      end)
    else
      # Suggest upgrade to access service providers
      suggest_service_provider_upgrade(user, enhancement_type)
    end
  end

  defp activity_color(activity_type) do
    case activity_type do
      :portfolio_view -> "bg-blue-400"
      :comment_received -> "bg-green-400"
      :collaboration_invite -> "bg-purple-400"
      :feedback_received -> "bg-yellow-400"
      :share_created -> "bg-indigo-400"
      :edit_session -> "bg-pink-400"
      _ -> "bg-gray-400"
    end
  end

  defp enhancement_color(enhancement_type) do
    case enhancement_type do
      "voice_over" -> "bg-blue-500"
      "writing" -> "bg-green-500"
      "design" -> "bg-purple-500"
      "music" -> "bg-pink-500"
      "quarterly_update" -> "bg-yellow-500"
      "feedback" -> "bg-indigo-500"
      _ -> "bg-gray-500"
    end
  end

  # ============================================================================
  # Supporting Functions for Event Handlers
  # ============================================================================

  defp accept_collaboration_request(request_id, user_id) do
    # Implementation to accept collaboration request
    # This would involve creating a channel, setting up permissions, etc.

    # Placeholder implementation
    case get_collaboration_request(request_id) do
      nil -> {:error, "Request not found"}
      request ->
        # Create collaboration channel
        channel_attrs = %{
          name: "Collaboration: #{request.portfolio}",
          description: "Collaborative work on #{request.portfolio}",
          channel_type: "portfolio_#{request.type}",
          visibility: "private",
          user_id: request.requester_id
        }

        case Channels.create_channel(channel_attrs) do
          {:ok, channel} ->
            # Add both users to channel
            add_user_to_channel(channel.id, request.requester_id, "owner")
            add_user_to_channel(channel.id, user_id, "collaborator")

            # Mark request as accepted
            update_collaboration_request(request_id, %{status: "accepted"})

            {:ok, %{channel_slug: channel.slug}}

          error -> error
        end
    end
  end

  defp decline_collaboration_request(request_id, user_id) do
    # Implementation to decline collaboration request
    case get_collaboration_request(request_id) do
      nil -> {:error, "Request not found"}
      request ->
        update_collaboration_request(request_id, %{
          status: "declined",
          declined_by: user_id,
          declined_at: DateTime.utc_now()
        })
    end
  end

  defp calculate_portfolio_stats(portfolios) do
    total_views = Enum.sum(Enum.map(portfolios, &get_portfolio_views/1))
    avg_quality_score = if length(portfolios) > 0 do
      total_quality = Enum.sum(Enum.map(portfolios, &calculate_portfolio_quality_score/1))
      Float.round(total_quality / length(portfolios), 1)
    else
      0
    end

    enhancement_breakdown = calculate_enhancement_breakdown(portfolios)
    enhancement_completion_rate = calculate_overall_enhancement_completion(portfolios)

    %{
      total_views: total_views,
      avg_quality_score: avg_quality_score,
      enhancement_completion_rate: enhancement_completion_rate,
      enhancement_breakdown: enhancement_breakdown
    }
  end

  defp calculate_enhancement_breakdown(portfolios) do
    enhancement_types = ["voice_over", "writing", "design", "music"]

    Enum.map(enhancement_types, fn type ->
      completed_count = Enum.count(portfolios, &has_completed_enhancement?(&1, type))
      total_count = length(portfolios)
      percentage = if total_count > 0, do: Float.round(completed_count / total_count * 100, 1), else: 0

      {type, percentage}
    end)
  end

  defp get_recent_activities(user_id) do
    # Mock activity data - replace with real queries
    [
      %{
        type: :portfolio_view,
        portfolio: "UX Designer Portfolio",
        message: "3 new views on",
        relative_time: "2 hours ago"
      },
      %{
        type: :collaboration_invite,
        portfolio: "Developer Showcase",
        message: "Collaboration started on",
        relative_time: "1 day ago"
      },
      %{
        type: :feedback_received,
        portfolio: "Creative Director",
        message: "New feedback received on",
        relative_time: "2 days ago"
      }
    ]
  end
end
