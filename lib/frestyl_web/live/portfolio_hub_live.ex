# lib/frestyl_web/live/portfolio_hub_live.ex - COMPREHENSIVE CREATOR COMMAND CENTER

defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  import Phoenix.LiveView.Helpers
  import Phoenix.Component

  alias Frestyl.{Accounts, Calendar, Portfolios, Channels, Billing, Lab, Features, Analytics, Studio, Services, Revenue, Sessions}
  alias Frestyl.Features.TierManager
  alias Frestyl.Studio.PortfolioCollaborationManager
  alias FrestylWeb.PortfolioHubLive.{Helpers, EnhancementEngine, Components}

 @impl true
  def mount(params, _session, socket) do
    IO.puts("=== PORTFOLIO HUB LIVEVIEW MOUNT CALLED ===")
    IO.inspect(params, label: "MOUNT PARAMS")
    user = socket.assigns.current_user
    IO.puts("=== USER LOADED ===")

    accounts = Accounts.list_user_accounts(user.id)
    current_account = List.first(accounts) || user  # Use user as fallback
    account = current_account
    user_tier = TierManager.get_user_tier(user)

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

    calendar_data = load_calendar_data(user, account)

    # Onboarding state (existing)
    is_first_visit = check_first_visit(user, params)
    just_completed_onboarding = Map.get(params, "welcome") == "true"
    recently_created_portfolio = get_recently_created_portfolio(portfolios)
    onboarding_state = Helpers.get_onboarding_state(user, portfolios, limits)

    # ============================================================================
    # FEATURE SECTION DATA LOADING (Equal Prominence)
    # ============================================================================

    studio_data = load_studio_data(user, portfolios, account)
    collaboration_data = load_collaboration_data(user, account)
    channels_data = load_channels_data(user, account)
    lab_access = Features.FeatureGate.can_access_feature?(account, :creator_lab)
    lab_data = load_lab_data(user, portfolios, account)
    service_data = load_service_data(user, account)

    revenue_data = load_revenue_data(user, account)

    broadcast_data = load_broadcast_data(user, account)

    hub_config = configure_hub_for_subscription_fixed(account.subscription_tier)
    default_section = determine_default_section(account.subscription_tier)
    quick_actions = generate_quick_actions(user, account, portfolios)

    mobile_state = assign_mobile_state()

    story_lab_data = load_story_lab_data(user, account)

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
      |> assign(:quick_actions, get_quick_actions(socket.assigns.current_user))
      |> assign(:user_tier, user_tier)

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
      |> assign(:lab_data, lab_data)
      |> assign(:lab_features, lab_data.features)
      |> assign(:active_experiments, lab_data.active_experiments)
      |> assign(:lab_recommendations, lab_data.recommendations)
      |> assign(:experiment_results, lab_data.results)
      |> assign(:story_lab_data, story_lab_data)

      # ======== EXPORT AND ANALYTICS STATE ========
      |> assign(:show_export_menu, false)                  # Export menu state
      |> assign(:analytics_data, %{})                      # Analytics data
      |> assign(:export_status, nil)                       # Export operation status


      # ======== HUB OPTIONS ========
      |> assign(:overview, safe_get_user_overview(user.id))
      |> assign(:view_mode, "grid")                    # "grid" or "list"
      |> assign(:active_hub_section, "portfolio_studio") # Tab management
      |> assign(:show_share_modal, false)              # Share modal state
      |> assign(:selected_portfolio_for_share, nil)    # Selected portfolio for sharing
      |> assign(:show_live_stream_modal, false)        # Live streaming modal
      |> assign(:show_clone_modal, false)              # Clone portfolio modal
      |> assign(:hub_sections, get_hub_sections_with_state(current_account, hub_config))

      # ======== SERVICE DASHBOARD SECTION (Creator+ only) ========
      |> assign(:service_data, service_data)
      |> assign(:active_bookings, service_data.active_bookings)
      |> assign(:service_performance, service_data.service_performance)
      |> assign(:upcoming_appointments, service_data.upcoming_appointments)
      |> assign(:service_revenue, service_data.revenue)

      # ======== REVENUE CENTER SECTION (Professional+ only) ========
      |> assign(:revenue_data, revenue_data)
      |> assign(:portfolio_performance, revenue_data.portfolio_performance)
      |> assign(:total_revenue, revenue_data.total_revenue)
      |> assign(:revenue_trends, revenue_data.trends)
      |> assign(:platform_fees, revenue_data.platform_fees)
      |> assign(:payout_schedule, revenue_data.payout_schedule)
      |> assign(:broadcast_data, broadcast_data)
      |> assign(:active_broadcasts, broadcast_data.active_broadcasts)
      |> assign(:scheduled_broadcasts, broadcast_data.scheduled_broadcasts)
      |> assign(:recent_broadcasts, broadcast_data.recent_broadcasts)
      |> assign(:broadcast_analytics, broadcast_data.broadcast_analytics)
      |> assign(:recording_library, broadcast_data.recording_library)

      # ======== USER JOURNEY & ONBOARDING ========
      |> assign(:recent_activity, recent_activity)
      |> assign(:onboarding_state, onboarding_state)
      |> assign(:is_first_visit, is_first_visit)
      |> assign(:just_completed_onboarding, just_completed_onboarding)
      |> assign(:recently_created_portfolio, recently_created_portfolio)
      |> assign(:show_broadcast_modal, false)
      |> assign(:show_broadcast_scheduler, false)
      |> assign(:selected_portfolio_for_broadcast, nil)
      |> assign(:broadcast_creation_step, :setup)

      # ======== STUDIO MODAL STATE MANAGEMENT (NEW) ========
      |> assign(:show_studio_modal, false)
      |> assign(:studio_step, :tool_selection)
      |> assign(:studio_enhancement_type, nil)
      |> assign(:available_studio_tools, get_studio_tools_for_account(account))
      |> assign(:selected_studio_tools, [])
      |> assign(:studio_layout_config, %{})
      |> assign(:show_welcome_celebration, is_first_visit || just_completed_onboarding)

      # ======== UI STATE MANAGEMENT ========
      |> assign(:active_section, "portfolio_studio")
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

      |> assign(:open_more_menu, nil)
      |> assign(:show_settings_modal, false)
      |> assign(:selected_portfolio_for_settings, nil)
      |> assign(:show_url_customization, false)
      |> assign(:selected_portfolio_for_overview, nil)
      |> assign(:url_preview, nil)
      |> assign(:settings_data, %{})

      |> assign(:show_ai_creation_modal, false)            # AI creation modal
      |> assign(:show_clone_modal, false)                  # Clone portfolio modal
      |> assign(:show_template_browser, false)             # Template browser modal
      |> assign(:show_resume_import_modal, false)

      |> assign(:show_enhancement_modal, false)            # Enhancement request modal
      |> assign(:show_upgrade_modal, false)                # Upgrade subscription modal
      |> assign(:requested_feature, nil)                   # Feature requiring upgrade

      # ======== MOBILE STATE ========
      |> Map.merge(mobile_state)
      |> assign(:show_mobile_menu, false)     # ADD THIS LINE
      |> assign(:show_mobile_nav, false)      # ADD THIS LINE
      |> assign(:mobile_section, "portfolio") # ADD THIS LINE
      |> assign(:mobile_sidebar_open, false)  # ADD THIS LINE (if needed)
      |> assign(:discovery_active_tab, "recommendations")
      |> assign(:calendar_data, calendar_data)
      |> assign(:active_section, determine_default_section(account.subscription_tier))

    {:ok, socket}
  end

  @impl true
  def handle_event("show_portfolio_overview", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      url_preview = %{
        current_url: "#{get_base_url()}/#{portfolio.slug}",
        custom_available: portfolio.slug != portfolio.id
      }

      {:noreply,
      socket
      |> assign(:selected_portfolio_for_overview, portfolio)
      |> assign(:url_preview, url_preview)
      |> assign(:show_url_customization, true)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("close_url_customization", _params, socket) do
    {:noreply, assign(socket, :show_url_customization, false)}
  end

  @impl true
  def handle_event("update_portfolio_url", %{"custom_slug" => custom_slug}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_overview

    case Portfolios.update_portfolio(portfolio, %{slug: String.downcase(custom_slug)}) do
      {:ok, updated_portfolio} ->
        updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
          if p.id == updated_portfolio.id, do: updated_portfolio, else: p
        end)

        url_preview = %{
          current_url: "#{get_base_url()}/#{updated_portfolio.slug}",
          custom_available: true
        }

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:selected_portfolio_for_overview, updated_portfolio)
        |> assign(:url_preview, url_preview)
        |> put_flash(:info, "Portfolio URL updated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update URL. Slug may already be taken.")}
    end
  end

  @impl true
  def handle_event("copy_portfolio_url", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      url = "#{get_base_url()}/#{portfolio.slug}"

      {:noreply,
      socket
      |> put_flash(:info, "Portfolio URL copied to clipboard!")
      |> push_event("copy-to-clipboard", %{text: url})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_portfolio_visibility", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      new_visibility = if portfolio.visibility == :public, do: :private, else: :public

      case Portfolios.update_portfolio(portfolio, %{visibility: new_visibility}) do
        {:ok, updated_portfolio} ->
          updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
            if p.id == updated_portfolio.id, do: updated_portfolio, else: p
          end)

          {:noreply,
          socket
          |> assign(:portfolios, updated_portfolios)
          |> assign(:selected_portfolio_for_overview, updated_portfolio)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update visibility")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_portfolio_overview", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      url_preview = %{
        current_url: "#{get_base_url()}/#{portfolio.slug}",
        custom_available: portfolio.slug != portfolio.id
      }

      {:noreply,
      socket
      |> assign(:selected_portfolio_for_overview, portfolio)
      |> assign(:url_preview, url_preview)
      |> assign(:show_url_customization, true)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("close_url_customization", _params, socket) do
    {:noreply, assign(socket, :show_url_customization, false)}
  end

  @impl true
  def handle_event("update_portfolio_url", %{"custom_slug" => custom_slug}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_overview

    case Portfolios.update_portfolio(portfolio, %{slug: String.downcase(custom_slug)}) do
      {:ok, updated_portfolio} ->
        updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
          if p.id == updated_portfolio.id, do: updated_portfolio, else: p
        end)

        url_preview = %{
          current_url: "#{get_base_url()}/#{updated_portfolio.slug}",
          custom_available: true
        }

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:selected_portfolio_for_overview, updated_portfolio)
        |> assign(:url_preview, url_preview)
        |> put_flash(:info, "Portfolio URL updated successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update URL. Slug may already be taken.")}
    end
  end

  @impl true
  def handle_event("show_portfolio_settings", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      settings_data = load_portfolio_settings(portfolio, socket.assigns.current_user)

      {:noreply,
      socket
      |> assign(:show_settings_modal, true)
      |> assign(:selected_portfolio_for_settings, portfolio)
      |> assign(:settings_data, settings_data)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("close_settings_modal", _params, socket) do
    {:noreply, assign(socket, :show_settings_modal, false)}
  end



  @impl true
  def handle_event("update_visibility_tier", %{"tier" => tier}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_settings
    tier_atom = String.to_atom(tier)

    case Portfolios.update_portfolio_visibility(portfolio, tier_atom) do
      {:ok, updated_portfolio} ->
        updated_portfolios = update_portfolio_in_list(socket.assigns.portfolios, updated_portfolio)
        settings_data = load_portfolio_settings(updated_portfolio, socket.assigns.current_user)

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:selected_portfolio_for_settings, updated_portfolio)
        |> assign(:settings_data, settings_data)
        |> put_flash(:info, "Visibility updated successfully!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility: #{reason}")}
    end
  end

  @impl true
  def handle_event("toggle_seo_indexing", _params, socket) do
    portfolio = socket.assigns.selected_portfolio_for_settings
    new_seo_value = not Map.get(portfolio, :seo_enabled, false)

    case Portfolios.update_portfolio(portfolio, %{seo_enabled: new_seo_value}) do
      {:ok, updated_portfolio} ->
        updated_portfolios = update_portfolio_in_list(socket.assigns.portfolios, updated_portfolio)

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:selected_portfolio_for_settings, updated_portfolio)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update SEO settings")}
    end
  end

  @impl true
  def handle_event("update_access_control", params, socket) do
    portfolio = socket.assigns.selected_portfolio_for_settings

    access_settings = %{
      password_protection: Map.get(params, "password_protection") == "true",
      password: Map.get(params, "password", ""),
      allowed_domains: String.split(Map.get(params, "allowed_domains", ""), ",") |> Enum.map(&String.trim/1),
      expiry_date: parse_date(Map.get(params, "expiry_date"))
    }

    case Portfolios.update_portfolio_access(portfolio, access_settings) do
      {:ok, updated_portfolio} ->
        updated_portfolios = update_portfolio_in_list(socket.assigns.portfolios, updated_portfolio)
        settings_data = load_portfolio_settings(updated_portfolio, socket.assigns.current_user)

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:selected_portfolio_for_settings, updated_portfolio)
        |> assign(:settings_data, settings_data)
        |> put_flash(:info, "Access controls updated!")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update access controls: #{reason}")}
    end
  end

  @impl true
  def handle_event("generate_share_link", %{"link_type" => link_type}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_settings

    case Portfolios.generate_share_link(portfolio, link_type) do
      {:ok, share_link} ->
        updated_settings = Map.put(socket.assigns.settings_data, :latest_share_link, share_link)

        {:noreply,
        socket
        |> assign(:settings_data, updated_settings)
        |> put_flash(:info, "Share link generated!")
        |> push_event("copy-to-clipboard", %{text: share_link.url})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to generate share link: #{reason}")}
    end
  end

    @impl true
  def handle_event("start_portfolio_collaboration", %{"portfolio_id" => portfolio_id}, socket) do
    user = socket.assigns.current_user

    case validate_collaboration_access(socket.assigns.current_account, portfolio_id) do
      {:ok, portfolio} ->
        # Setup collaboration session
        PortfolioCollaborationManager.setup_portfolio_subscriptions(portfolio_id, user.id)

        # Track presence
        device_info = get_device_info_from_socket(socket)
        permissions = get_user_portfolio_permissions(portfolio, user)

        PortfolioCollaborationManager.track_portfolio_presence(
          portfolio_id,
          user,
          permissions,
          device_info
        )

        # Navigate to collaborative editor
        {:noreply, push_navigate(socket, to: "/portfolios/#{portfolio_id}/edit?collaborate=true")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Cannot start collaboration: #{reason}")}
    end
  end

  @impl true
  def handle_event("invite_to_portfolio", %{"portfolio_id" => portfolio_id, "email" => email, "permissions" => permissions}, socket) do
    user = socket.assigns.current_user

    case PortfolioCollaborationManager.create_portfolio_invitation(portfolio_id, user, email, permissions) do
      {:ok, invitation} ->
        # Update collaboration data to show pending invitation
        updated_collaboration_data = update_collaboration_data_with_invitation(
          socket.assigns.collaboration_data,
          invitation
        )

        {:noreply,
         socket
         |> assign(:collaboration_data, updated_collaboration_data)
         |> put_flash(:info, "Collaboration invitation sent to #{email}")
         |> assign(:show_invite_modal, false)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation: #{reason}")}
    end
  end

  @impl true
  def handle_event("show_portfolio_collaborators", %{"portfolio_id" => portfolio_id}, socket) do
    # Get real-time collaborator list
    collaborators = PortfolioCollaborationManager.list_portfolio_collaborators(portfolio_id)
    analytics = PortfolioCollaborationManager.get_collaboration_analytics(portfolio_id)

    {:noreply,
     socket
     |> assign(:selected_portfolio_collaborators, collaborators)
     |> assign(:collaboration_analytics, analytics)
     |> assign(:show_collaborators_modal, true)}
  end

  @impl true
  def handle_event("toggle_collaboration_section", %{"section" => section}, socket) do
    current_section = Map.get(socket.assigns, :active_collaboration_section, "active")
    new_section = if current_section == section, do: nil, else: section

    {:noreply, assign(socket, :active_collaboration_section, new_section)}
  end

    @impl true
  def handle_params(%{"section" => section} = params, _url, socket) do
    # Handle calendar section navigation
    socket = case section do
      "calendar" ->
        calendar_data = load_calendar_data(socket.assigns.user, socket.assigns.account)
        assign(socket, :calendar_data, calendar_data)
      _ ->
        socket
    end

    {:noreply, assign(socket, :active_section, section)}
  end

  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

    # ============================================================================
  # CALENDAR EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("switch_to_calendar", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/hub?section=calendar")}
  end

  @impl true
  def handle_event("create_calendar_event", params, socket) do
    if socket.assigns.calendar_data.permissions.can_create do
      # Delegate to calendar creation logic
      send_update(CalendarSectionComponent,
        id: "calendar_section",
        action: :create_event,
        params: params
      )
      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Upgrade to Creator to create calendar events")}
    end
  end

  @impl true
  def handle_event("quick_calendar_action", %{"action" => action} = params, socket) do
    case action do
      "view_today" ->
        today_events = get_today_events(socket.assigns.user, socket.assigns.account)
        {:noreply, assign(socket, :today_events, today_events)}

      "sync_calendars" ->
        if socket.assigns.calendar_data.permissions.can_integrate do
          # Trigger calendar sync
          Calendar.sync_user_calendars(socket.assigns.user.id)
          {:noreply, put_flash(socket, :info, "Calendar sync initiated")}
        else
          {:noreply, put_flash(socket, :error, "Upgrade to Creator for calendar sync")}
        end

      _ ->
        {:noreply, socket}
    end
  end


  # ============================================================================
  # PORTFOLIO ENHANCEMENTS
  # ============================================================================

  # Tab visibility configuration
  defp should_show_tab?(hub_config, section) do
    is_section_available?(hub_config, section)
  end

  # Original tab styling functions
  defp get_original_tab_classes(hub_config, section, active_section) do
    cond do
      active_section == section ->
        "border-purple-500 text-purple-600"

      is_section_locked?(hub_config, section) ->
        "border-transparent text-gray-300 hover:text-gray-400 cursor-not-allowed"

      true ->
        "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end

  defp get_mobile_tab_classes(hub_config, section, active_section) do
    cond do
      active_section == section ->
        "bg-purple-50 text-purple-600 border-r-2 border-purple-500"

      is_section_locked?(hub_config, section) ->
        "text-gray-300 cursor-not-allowed"

      true ->
        "text-gray-700 hover:bg-gray-50"
    end
  end

  defp get_tab_tooltip(hub_config, section) do
    if is_section_locked?(hub_config, section) do
      upgrade_info = get_upgrade_prompt_for_section(hub_config, section)
      "Upgrade to #{String.capitalize(upgrade_info.tier)} required"
    else
      nil
    end
  end

  defp load_studio_data(user, portfolios, account) do
    %{
      total_portfolios: length(portfolios),
      published_count: Enum.count(portfolios, &(&1.visibility == :public)),
      draft_count: Enum.count(portfolios, &(&1.visibility == :private)),

      # Existing keys:
      quick_integrations: get_available_integrations(account),
      studio_ready_portfolios: filter_studio_ready_portfolios(portfolios),
      recent_edits: get_recent_portfolio_edits(user.id),
      studio_features: get_studio_features_for_account(account),
      analytics_summary: get_studio_analytics_summary(user.id),

      # Additional useful keys:
      templates_available: get_available_templates_count(account),
      enhancement_progress: get_enhancement_progress(portfolios),
      creation_limits: get_creation_limits(account),
      recent_creations: get_recent_portfolio_activity(user.id)
    }
  end

  defp filter_studio_ready_portfolios(portfolios) do
    Enum.filter(portfolios, fn portfolio ->
      # Safe check for loaded associations
      sections_loaded = case Ecto.assoc_loaded?(portfolio.sections) do
        true -> not is_nil(portfolio.sections) and length(portfolio.sections || []) > 0
        false -> false  # If not loaded, assume not ready
      end

      # ✅ FIX: Use portfolio.visibility instead of portfolio.status
      has_sufficient_content = sections_loaded
      visibility_is_set = portfolio.visibility in [:public, :link_only, :request_only, :private]

      has_sufficient_content && visibility_is_set
    end)
  end


  defp get_available_integrations(account) do
    # Return available integrations based on account tier/permissions
    base_integrations = [
      %{
        id: "linkedin",
        name: "LinkedIn",
        description: "Share portfolio directly to LinkedIn",
        icon: "linkedin",
        enabled: true,
        category: "social"
      },
      %{
        id: "github",
        name: "GitHub",
        description: "Connect GitHub repositories",
        icon: "github",
        enabled: true,
        category: "development"
      },
      %{
        id: "dribbble",
        name: "Dribbble",
        description: "Import projects from Dribbble",
        icon: "dribbble",
        enabled: account.subscription_tier != "personal",
        category: "design"
      },
      %{
        id: "behance",
        name: "Behance",
        description: "Import projects from Behance",
        icon: "behance",
        enabled: account.subscription_tier != "personal",
        category: "design"
      },
      %{
        id: "figma",
        name: "Figma",
        description: "Import Figma designs and prototypes",
        icon: "figma",
        enabled: account.subscription_tier in ["creator", "creator_plus"],
        category: "design"
      }
    ]

    # Filter based on account permissions
    Enum.filter(base_integrations, & &1.enabled)
  end

  defp text_heavy_without_audio?(portfolio) do
    # Safe handling of sections association
    sections = case Ecto.assoc_loaded?(portfolio.sections) do
      true -> portfolio.sections || []
      false -> []
    end

    # Count text-heavy sections
    text_sections = Enum.count(sections, fn section ->
      section.section_type in [:about, :experience, :education, :skills, :testimonials] and
      has_significant_text_content?(section)
    end)

    # Check if portfolio has audio content
    has_audio = Enum.any?(sections, fn section ->
      media_items = get_in(section, [:content, "media_items"]) || []

      Enum.any?(media_items, fn item ->
        case item do
          %{"type" => "audio"} -> true
          %{"file_type" => file_type} when is_binary(file_type) ->
            String.contains?(String.downcase(file_type), "audio")
          _ -> false
        end
      end)
    end)

    # Portfolio is text-heavy without audio if it has 3+ text sections and no audio
    text_sections >= 3 and not has_audio
  end

  defp missing_story_structure?(portfolio) do
    # Safe handling of sections association
    sections = case Ecto.assoc_loaded?(portfolio.sections) do
      true -> portfolio.sections || []
      false -> []
    end

    section_types = Enum.map(sections, & &1.section_type)

    # Check for basic story structure elements
    has_intro = :intro in section_types or :about in section_types
    has_journey = :experience in section_types or :projects in section_types
    has_skills_showcase = :skills in section_types
    has_conclusion = :contact in section_types or :call_to_action in section_types

    # Missing key story elements (need at least 3 of 4)
    story_elements = [has_intro, has_journey, has_skills_showcase, has_conclusion]
    present_elements = Enum.count(story_elements, & &1)

    present_elements < 3
  end

  defp get_smart_enhancement_suggestions(portfolios, user) do
    portfolios
    |> Enum.flat_map(&analyze_portfolio_for_enhancements(&1, user))
    |> Enum.take(3) # Top 3 suggestions
  end

  defp analyze_portfolio_for_enhancements(portfolio, user) do
    suggestions = []

    # Check for missing story structure
    suggestions = if missing_story_structure?(portfolio) do
      [%{
        type: :story_structure,
        title: "Improve Story Flow",
        description: "Add sections to create a compelling narrative arc",
        priority: :high,
        action: "Add missing sections",
        icon: "document-text"
      } | suggestions]
    else
      suggestions
    end

    # Check for text-heavy without audio
    suggestions = if text_heavy_without_audio?(portfolio) do
      [%{
        type: :audio_enhancement,
        title: "Add Voice Elements",
        description: "Consider adding audio introductions or voice notes",
        priority: :medium,
        action: "Record audio content",
        icon: "microphone"
      } | suggestions]
    else
      suggestions
    end

    # Additional enhancement checks
    suggestions = if needs_visual_polish?(portfolio) do
      [%{
        type: :visual_polish,
        title: "Enhance Visual Appeal",
        description: "Add more images, improve layout consistency",
        priority: :medium,
        action: "Upload media",
        icon: "photograph"
      } | suggestions]
    else
      suggestions
    end

    suggestions
  end

  # ============================================================================
  # DATA LOADING FUNCTIONS - Equal Feature Prominence
  # ============================================================================

  defp load_studio_data(user, portfolios, account) do
    %{
      total_portfolios: length(portfolios),
      # ✅ FIX: Use visibility enum instead of old field references
      published_count: Enum.count(portfolios, &(&1.visibility == :public)),
      draft_count: Enum.count(portfolios, &(&1.visibility == :private)),
      link_only_count: Enum.count(portfolios, &(&1.visibility == :link_only)),
      request_only_count: Enum.count(portfolios, &(&1.visibility == :request_only)),

      # Existing keys maintained:
      quick_integrations: get_available_integrations(account),
      studio_ready_portfolios: filter_studio_ready_portfolios(portfolios),
      recent_edits: get_recent_portfolio_edits(user.id),
      studio_features: get_studio_features_for_account(account),
      analytics_summary: get_studio_analytics_summary(user.id),
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

  defp load_story_lab_data(user, account) do
    tier = account.subscription_tier

    %{
      available_templates: get_story_lab_templates(tier),
      user_stories: safe_get_user_stories(user.id, tier),
      recording_limits: get_recording_limits(tier),
      audio_features: get_audio_features(tier),
      usage_stats: get_story_lab_usage_stats(user.id, tier),
      upgrade_prompt: tier == "personal",
      tier_limits: get_story_tier_limits(tier)
    }
  end

  defp get_recording_limits(tier) do
    case tier do
      "personal" ->
        %{
          max_minutes: 30,
          file_format: ["mp3"],
          quality: "standard",
          simultaneous_tracks: 1
        }
      "creator" ->
        %{
          max_minutes: -1,  # Unlimited
          file_format: ["mp3", "wav", "flac"],
          quality: "high",
          simultaneous_tracks: 4
        }
      tier when tier in ["professional", "enterprise"] ->
        %{
          max_minutes: -1,  # Unlimited
          file_format: ["mp3", "wav", "flac", "aiff"],
          quality: "studio",
          simultaneous_tracks: 8
        }
      _ ->
        get_recording_limits("personal")
    end
  end

  defp get_audio_features(tier) do
    case tier do
      "personal" ->
        %{
          beat_detection: false,
          auto_sync: false,
          noise_reduction: false,
          effects: [],
          mixing: false,
          teleprompter: false
        }
      "creator" ->
        %{
          beat_detection: true,
          auto_sync: true,
          noise_reduction: true,
          effects: ["reverb", "echo", "normalize"],
          mixing: true,
          teleprompter: true
        }
      tier when tier in ["professional", "enterprise"] ->
        %{
          beat_detection: true,
          auto_sync: true,
          noise_reduction: true,
          effects: ["reverb", "echo", "normalize", "compressor", "eq", "gate"],
          mixing: true,
          teleprompter: true,
          mastering: true,
          stem_separation: true
        }
      _ ->
        get_audio_features("personal")
    end
  end

  defp get_story_lab_templates(tier) do
    normalized_tier = TierManager.normalize_tier(tier)

    case normalized_tier do
      "personal" ->
        [
          %{
            id: "personal_journey",
            name: "Personal Journey",
            description: "Tell your life story with chapters and audio",
            icon: "📖",
            estimated_time: "30 minutes",
            features: ["Basic chapters", "Audio recording", "Simple timeline"]
          },
          %{
            id: "simple_portfolio",
            name: "Story Portfolio",
            description: "Portfolio with narrative structure",
            icon: "💼",
            estimated_time: "45 minutes",
            features: ["Project stories", "Work narrative", "Basic media"]
          },
          %{
            id: "basic_lyrics",
            name: "Lyrics & Audio",
            description: "Simple lyrics with audio sync",
            icon: "🎵",
            estimated_time: "20 minutes",
            features: ["Lyrics editor", "Audio sync", "Basic recording"]
          }
        ]

      tier when tier in ["creator", "professional", "enterprise"] ->
        get_story_lab_templates("personal") ++ [
          %{
            id: "hero_journey",
            name: "Hero's Journey",
            description: "Advanced narrative with multimedia",
            icon: "🚀",
            estimated_time: "2 hours",
            features: ["Advanced templates", "Beat detection", "Collaboration"],
            requires_tier: "creator"
          },
          %{
            id: "case_study",
            name: "Interactive Case Study",
            description: "Problem-solution with demos",
            icon: "🔬",
            estimated_time: "90 minutes",
            features: ["Interactive elements", "Video embedding", "Analytics"],
            requires_tier: "creator"
          },
          %{
            id: "audiobook",
            name: "Audiobook Production",
            description: "Professional audiobook with script sync",
            icon: "🎙️",
            estimated_time: "3+ hours",
            features: ["Teleprompter", "Advanced audio", "Chapter management"],
            requires_tier: "creator"
          }
        ]
    end
  end

  defp get_story_tier_limits(tier) do
    normalized_tier = TierManager.normalize_tier(tier)

    case normalized_tier do
      "personal" ->
        %{
          max_stories: 2,
          max_chapters_per_story: 5,
          recording_minutes_limit: 30,
          beat_detection_enabled: false,
          teleprompter_mode: false,
          collaboration_enabled: false,
          advanced_templates: false,
          ai_suggestions: false,
          unlimited_storage: false
        }

      tier when tier in ["creator", "professional", "enterprise"] ->
        %{
          max_stories: if(tier == "creator", do: 10, else: -1),
          max_chapters_per_story: 50,
          recording_minutes_limit: -1,  # Unlimited
          beat_detection_enabled: true,
          teleprompter_mode: true,
          collaboration_enabled: true,
          advanced_templates: true,
          ai_suggestions: true,
          unlimited_storage: true
        }
    end
  end

  defp safe_get_user_stories(user_id, tier) do
    try do
      normalized_tier = TierManager.normalize_tier(tier)

      limit = case normalized_tier do
        "personal" -> 2
        "creator" -> 10
        _ -> -1
      end

      # This would call your Stories context
      # Stories.list_user_stories(user_id, limit: limit)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp safe_get_lab_features(user, account) do
    try do
      # Lab.get_available_features(user, account)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp safe_get_active_experiments(user_id) do
    try do
      # Lab.get_active_experiments(user_id)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp safe_get_lab_recommendations(user, portfolios) do
    try do
      # Lab.get_recommendations(user, portfolios)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp safe_get_experiment_results(user_id) do
    try do
      # Lab.get_experiment_results(user_id)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp get_beta_features(account) do
    try do
      # Lab.get_beta_features(account)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  defp safe_get_ai_insights(user_id) do
    try do
      # Lab.get_ai_insights(user_id)
      %{}  # Placeholder for now
    rescue
      _ -> %{}
    end
  end

  defp safe_get_feature_requests(user_id) do
    try do
      # Lab.get_feature_requests(user_id)
      []  # Placeholder for now
    rescue
      _ -> []
    end
  end

  # Add all the remaining safe functions that are referenced in the existing codebase
  defp safe_get_active_service_bookings(user_id), do: []
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
  defp safe_get_peer_network(user_id), do: []
  defp safe_get_recent_feedback(user_id), do: []
  defp safe_get_trending_channels(user), do: []
  defp safe_get_channel_recommendations(user), do: []
  defp safe_get_featured_creators(user), do: []
  defp safe_get_community_activity(user_id), do: []
  defp safe_get_discovery_feed(user_id), do: []
  defp check_calendar_integration(user_id), do: false

  defp get_story_lab_usage_stats(user_id, tier) do
    %{
      stories_created: 0,  # Would pull from database
      recording_minutes_used: 0,
      chapters_created: 0,
      last_story_created: nil
    }
  end

  defp get_quick_actions(user) do
    [
      %{
        title: "Upload Media",
        icon: "📸",
        action: "show_media_upload",
        description: "Add images or videos"
      },
      %{
        title: "Analytics",
        icon: "📊",
        action: "switch_section",
        description: "View performance"
      }
    ]
  end

  defp has_sufficient_content?(portfolio) do
    # 🔥 SAFE CHECK: Handle NotLoaded associations
    sections = case Ecto.assoc_loaded?(portfolio.sections) do
      true -> portfolio.sections || []
      false -> []
    end

    content_sections = Enum.count(sections, fn section ->
      content = section.content || %{}

      # Check for meaningful text content
      text_content = [
        content["description"],
        content["summary"],
        content["content"],
        content["bio"]
      ]
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")
      |> String.trim()

      has_text = String.length(text_content) > 50

      # Check for media content
      media_items = content["media_items"] || []
      has_media = length(media_items) > 0

      has_text or has_media
    end)

    content_sections >= 2
  end

  # Helper function to check if section has significant text content
  defp has_significant_text_content?(section) do
    content = section.content || %{}

    text_fields = ["description", "summary", "content", "bio", "responsibilities", "achievements"]

    total_text =
      text_fields
      |> Enum.map(&(content[&1] || ""))
      |> Enum.filter(&is_binary/1)
      |> Enum.join(" ")
      |> String.trim()
      |> String.length()

    total_text > 200
  end

  defp safe_get_user_overview(user_id) do
    try do
      # Replace this with your actual overview loading logic
      %{
        total_visits: 0,
        total_portfolios: length(Portfolios.list_user_portfolios(user_id)),
        total_shares: 0
      }
    rescue
      _ ->
        %{total_visits: 0, total_portfolios: 0, total_shares: 0}
    end
  end


    defp load_collaboration_data(user, account) do
    # Get user's portfolios that support collaboration
    collaborative_portfolios = get_collaborative_portfolios(user.id, account)

    # Get active collaboration sessions
    active_collaborations = get_active_portfolio_collaborations(user.id)

    # Get collaboration invitations (sent and received)
    sent_invitations = get_sent_collaboration_invitations(user.id)
    received_invitations = get_received_collaboration_invitations(user.id)

    # Get collaboration opportunities
    opportunities = generate_collaboration_opportunities(user, account, collaborative_portfolios)

    # Get collaboration analytics
    collaboration_stats = get_user_collaboration_stats(user.id)

    %{
      # Existing fields
      active_collaborations: active_collaborations,
      opportunities: opportunities,

      # Enhanced fields
      collaborative_portfolios: collaborative_portfolios,
      sent_invitations: sent_invitations,
      received_invitations: received_invitations,
      collaboration_stats: collaboration_stats,
      real_time_sessions: get_real_time_collaboration_sessions(user.id),
      collaboration_history: get_recent_collaboration_history(user.id, 10)
    }
  end

  defp get_collaborative_portfolios(user_id, account) do
    # Get portfolios that can be used for collaboration
    user_portfolios = Portfolios.list_user_portfolios(user_id)

    Enum.map(user_portfolios, fn portfolio ->
      # Add collaboration metadata
      collaboration_enabled = Features.FeatureGate.can_access_feature?(account, :real_time_collaboration)
      active_sessions = get_portfolio_active_sessions(portfolio.id)

      %{
        portfolio: portfolio,
        collaboration_enabled: collaboration_enabled,
        active_sessions: length(active_sessions),
        collaborators: active_sessions,
        last_collaborative_edit: get_last_collaborative_edit(portfolio.id),
        collaboration_permissions: get_portfolio_collaboration_settings(portfolio.id)
      }
    end)
  end

  defp get_active_portfolio_collaborations(user_id) do
    # Get currently active collaboration sessions for this user
    case :ets.match(:portfolio_presence, {{:_, user_id}, :"$1"}) do
      sessions when is_list(sessions) ->
        Enum.map(sessions, fn [presence_data] ->
          %{
            portfolio_id: presence_data.portfolio_id,
            joined_at: presence_data.joined_at,
            active_section: presence_data.active_section,
            other_collaborators: get_other_collaborators(presence_data.portfolio_id, user_id),
            last_activity: presence_data.last_activity,
            device_type: presence_data.device_type
          }
        end)

      _ ->
        []
    end
  end

  defp get_sent_collaboration_invitations(user_id) do
    # Get invitations sent by this user
    case :ets.match(:portfolio_invitations, {:"$1", %{inviting_user_id: user_id, status: :pending}}) do
      invitations when is_list(invitations) ->
        Enum.map(invitations, fn [token] ->
          [{^token, invitation}] = :ets.lookup(:portfolio_invitations, token)

          %{
            token: token,
            portfolio_id: invitation.portfolio_id,
            invitee_email: invitation.invitee_email,
            permissions: invitation.permissions,
            created_at: invitation.created_at,
            expires_at: invitation.expires_at
          }
        end)

      _ ->
        []
    end
  end

  defp get_received_collaboration_invitations(user_id) do
    # Get invitations received by this user (by email)
    user = Accounts.get_user!(user_id)

    case :ets.match(:portfolio_invitations, {:"$1", %{invitee_email: user.email, status: :pending}}) do
      invitations when is_list(invitations) ->
        Enum.map(invitations, fn [token] ->
          [{^token, invitation}] = :ets.lookup(:portfolio_invitations, token)
          inviting_user = Accounts.get_user!(invitation.inviting_user_id)
          portfolio = Portfolios.get_portfolio!(invitation.portfolio_id)

          %{
            token: token,
            portfolio: portfolio,
            inviting_user: inviting_user,
            permissions: invitation.permissions,
            created_at: invitation.created_at,
            expires_at: invitation.expires_at
          }
        end)

      _ ->
        []
    end
  end

  defp generate_collaboration_opportunities(user, account, portfolios) do
    opportunities = []

    # Suggest collaboration based on portfolio content and user tier
    opportunities = if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
      content_based_opportunities = Enum.flat_map(portfolios, fn %{portfolio: portfolio} ->
        case suggest_collaboration_for_portfolio(portfolio, account) do
          [] -> []
          suggestions -> suggestions
        end
      end)

      opportunities ++ content_based_opportunities
    else
      opportunities
    end

    # Add upgrade opportunities for collaboration features
    opportunities = if account.subscription_tier in ["personal", "free"] do
      upgrade_opportunity = %{
        type: :upgrade,
        title: "Unlock Real-time Collaboration",
        description: "Collaborate with others in real-time on your portfolios",
        action: :upgrade_subscription,
        suggested_tier: :creator,
        benefits: ["Real-time editing", "10 collaborators", "Version history"]
      }

      [upgrade_opportunity | opportunities]
    else
      opportunities
    end

    opportunities
  end

  defp suggest_collaboration_for_portfolio(portfolio, account) do
    suggestions = []

    # Suggest based on portfolio completeness
    sections = portfolio.sections || []
    incomplete_sections = Enum.filter(sections, &section_needs_collaboration?/1)

    suggestions = if length(incomplete_sections) > 0 do
      collaboration_suggestion = %{
        type: :content_collaboration,
        portfolio_id: portfolio.id,
        title: "Get help completing your portfolio",
        description: "#{length(incomplete_sections)} sections could benefit from collaboration",
        action: :find_collaborators,
        priority: :medium,
        sections: Enum.map(incomplete_sections, & &1.id)
      }

      [collaboration_suggestion | suggestions]
    else
      suggestions
    end

    # Suggest review collaboration for completed portfolios
    suggestions = if portfolio.visibility == :public and length(sections) > 2 do
      review_suggestion = %{
        type: :review_collaboration,
        portfolio_id: portfolio.id,
        title: "Get expert feedback",
        description: "Your portfolio is ready for professional review",
        action: :request_review,
        priority: :low
      }

      [review_suggestion | suggestions]
    else
      suggestions
    end

    suggestions
  end

  defp section_needs_collaboration?(section) do
    content = section.content || %{}

    # Check if section has minimal content
    text_content = Map.get(content, "text", "")
    media_items = Map.get(content, "media_items", [])

    String.length(text_content) < 100 and length(media_items) == 0
  end

  defp get_user_collaboration_stats(user_id) do
    # Calculate collaboration statistics for the user
    case :ets.lookup(:user_collaboration_stats, user_id) do
      [{^user_id, stats}] ->
        stats

      [] ->
        %{
          total_collaborations: 0,
          portfolios_collaborated: 0,
          time_spent_collaborating: 0,
          invitations_sent: 0,
          invitations_received: 0,
          successful_collaborations: 0
        }
    end
  end

  defp get_real_time_collaboration_sessions(user_id) do
    # Get currently active real-time sessions
    case :ets.match(:portfolio_sessions, {{user_id, :"$1"}, :"$2"}) do
      sessions when is_list(sessions) ->
        Enum.map(sessions, fn [portfolio_id, session_data] ->
          portfolio = Portfolios.get_portfolio!(portfolio_id)

          %{
            portfolio: portfolio,
            session_start: session_data.started_at,
            active_section: session_data.active_section,
            collaborators: get_session_collaborators(portfolio_id),
            last_activity: session_data.last_activity
          }
        end)

      _ ->
        []
    end
  end

  defp get_recent_collaboration_history(user_id, limit \\ 10) do
    # Get recent collaboration activities
    case :ets.lookup(:collaboration_history, user_id) do
      [{^user_id, history}] ->
        history
        |> Enum.sort_by(& &1.timestamp, {:desc, DateTime})
        |> Enum.take(limit)

      [] ->
        []
    end
  end


  # ============================================================================
  # HUB CONFIGURATION BASED ON SUBSCRIPTION TIER
  # ============================================================================

  defp configure_hub_for_subscription_fixed(tier) when is_atom(tier) do
    configure_hub_for_subscription_fixed(to_string(tier))
  end

  defp configure_hub_for_subscription_fixed(tier) do
    # Always show all 9 sections in navigation
    all_sections = [
      "portfolio_studio",
      "story_lab",
      "analytics",
      "collaboration_hub",
      "community_channels",
      "creator_lab",
      "service_dashboard",
      "revenue_center",
      "calendar"
    ]

    # Define primary and secondary sections for navigation structure
    {primary_sections, secondary_sections} = case tier do
      "personal" ->
        {["portfolio_studio", "story_lab", "calendar"],
        ["analytics", "collaboration_hub", "community_channels", "creator_lab", "service_dashboard", "revenue_center"]}

      "creator" ->
        {["portfolio_studio", "story_lab", "calendar", "analytics", "collaboration_hub", "creator_lab"],
        ["community_channels", "service_dashboard", "revenue_center"]}

      "professional" ->
        {["portfolio_studio", "story_lab", "calendar", "analytics", "collaboration_hub", "service_dashboard", "revenue_center"],
        ["community_channels", "creator_lab"]}

      "enterprise" ->
        {all_sections, []}

      _ ->
        {["portfolio_studio", "story_lab", "calendar"],
        ["analytics", "collaboration_hub", "community_channels", "creator_lab", "service_dashboard", "revenue_center"]}
    end

    case tier do
      "personal" ->
        %{
          primary_sections: primary_sections,
          secondary_sections: secondary_sections,
          all_sections: all_sections,
          available_sections: ["portfolio_studio", "story_lab", "collaboration_hub", "community_channels", "calendar"],
          locked_sections: ["analytics", "creator_lab", "service_dashboard", "revenue_center"],
          upgrade_prompts: %{
            "analytics" => %{tier: "creator", message: "Upgrade to Creator to access detailed analytics"},
            "creator_lab" => %{tier: "creator", message: "Unlock the full Creator Lab with advanced storytelling, unlimited recording, and collaboration features"},
            "service_dashboard" => %{tier: "creator", message: "Manage bookings and services with Creator tier"},
            "revenue_center" => %{tier: "professional", message: "Track revenue and earnings with Professional tier"}
          },
          max_portfolios: 3,
          max_stories: 2,
          collaboration_limits: %{max_active: 2},
          story_lab_limits: %{
            max_stories: 2,
            max_chapters_per_story: 5,
            recording_minutes_limit: 30,
            templates_available: ["personal_journey", "simple_portfolio", "basic_lyrics"],
            advanced_features: false
          },
          feature_focus: "portfolio_creation"
        }

      "creator" ->
        %{
          primary_sections: primary_sections,
          secondary_sections: secondary_sections,
          all_sections: all_sections,
          available_sections: ["portfolio_studio", "story_lab", "analytics", "collaboration_hub", "community_channels", "calendar", "creator_lab", "service_dashboard"],
          locked_sections: ["revenue_center"],
          upgrade_prompts: %{
            "revenue_center" => %{tier: "professional", message: "Advanced revenue tracking requires Professional tier"}
          },
          max_portfolios: 10,
          max_stories: 10,
          collaboration_limits: %{max_active: 10},
          story_lab_limits: %{
            max_stories: 10,
            max_chapters_per_story: 50,
            recording_minutes_limit: -1,
            templates_available: "all",
            advanced_features: true
          },
          feature_focus: "service_offering"
        }

      "professional" ->
        %{
          primary_sections: primary_sections,
          secondary_sections: secondary_sections,
          all_sections: all_sections,
          available_sections: all_sections,
          locked_sections: [],
          upgrade_prompts: %{},
          max_portfolios: -1,
          max_stories: -1,
          collaboration_limits: %{max_active: -1},
          story_lab_limits: %{
            max_stories: -1,
            max_chapters_per_story: -1,
            recording_minutes_limit: -1,
            templates_available: "all",
            advanced_features: true
          },
          feature_focus: "revenue_optimization"
        }

      "enterprise" ->
        %{
          primary_sections: primary_sections,
          secondary_sections: secondary_sections,
          all_sections: all_sections,
          available_sections: all_sections,
          locked_sections: [],
          upgrade_prompts: %{},
          max_portfolios: -1,
          max_stories: -1,
          collaboration_limits: %{max_active: -1},
          story_lab_limits: %{
            max_stories: -1,
            max_chapters_per_story: -1,
            recording_minutes_limit: -1,
            templates_available: "all",
            advanced_features: true
          },
          feature_focus: "team_management",
          enterprise_features: ["white_label", "api_access", "custom_domains"]
        }

      _ ->
        configure_hub_for_subscription_fixed("personal")
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

    defp get_recent_portfolio_edits(user_id) do
    # Implementation to get recent portfolio edits
    []
  end

  defp get_studio_features_for_account(account) do
    # Implementation to get available studio features
    %{
      ai_assistant: true,
      collaboration: account.subscription_tier != "personal",
      analytics: account.subscription_tier in ["creator", "creator_plus"],
      custom_themes: account.subscription_tier == "creator_plus"
    }
  end

  defp get_studio_analytics_summary(user_id) do
    # Implementation to get analytics summary
    %{
      total_views: 0,
      engagement_rate: 0,
      conversion_rate: 0
    }
  end

  defp needs_visual_polish?(portfolio) do
    sections = portfolio.sections || []

    sections_with_media = Enum.count(sections, fn section ->
      media_items = get_in(section, [:content, "media_items"]) || []
      length(media_items) > 0
    end)

    # Needs visual polish if less than half the sections have media
    sections_with_media < (length(sections) / 2)
  end

  # ============================================================================
  # SAFE DATA LOADING FUNCTIONS (Error Handling)
  # ============================================================================

  defp safe_load_portfolios(user_id) do
    try do
      # Use the existing Portfolios context instead of writing your own query
      portfolios = Portfolios.list_user_portfolios(user_id)

      # Ensure sections are preloaded
      portfolios
      |> Enum.map(fn portfolio ->
        case Ecto.assoc_loaded?(portfolio.sections) do
          true -> portfolio
          false -> Frestyl.Repo.preload(portfolio, :sections)
        end
      end)
    rescue
      error ->
        require Logger
        Logger.error("Failed to load portfolios for user #{user_id}: #{inspect(error)}")
        []
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

  def is_section_available?(hub_config, section) do
    section in hub_config.available_sections
  end

  def is_section_locked?(hub_config, section) do
    section in hub_config.locked_sections
  end

  def get_upgrade_prompt_for_section(hub_config, section) do
    Map.get(hub_config.upgrade_prompts, section)
  end

  def get_section_upgrade_tier(hub_config, section) do
    case Map.get(hub_config.upgrade_prompts, section) do
      %{tier: tier} -> tier
      _ -> nil
    end
  end

  defp get_section_tab_classes(hub_config, section) do
    if is_section_locked?(hub_config, section) do
      "border-transparent text-gray-400 hover:text-gray-500 hover:border-gray-200 cursor-pointer"
    else
      "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300 cursor-pointer"
    end
  end

  defp get_mobile_section_classes(hub_config, section) do
    if is_section_locked?(hub_config, section) do
      "text-gray-400 hover:bg-gray-50"
    else
      "text-gray-700 hover:bg-gray-50"
    end
  end

  def get_section_icon(section) do
    case section do
      "portfolio_studio" -> "🎨"
      "story_lab" -> "📖"
      "analytics" -> "📊"
      "collaboration_hub" -> "🤝"
      "community_channels" -> "💬"
      "creator_lab" -> "🧪"
      "calendar" -> "📅"
      "service_dashboard" -> "⚡"
      "revenue_center" -> "💰"
      _ -> "📁"
    end
  end

  defp get_active_section_title(active_section) do
    # Implement your logic to return the title
    case active_section do
      "overview" -> "Overview"
      "projects" -> "My Projects"
      # ... other active sections
      _ -> "Unknown Section"
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
  defp get_beta_features(_account), do: []
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
        icon: "microphone",
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
        icon: "pencil",
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
        icon: "palette",
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
        icon: "musical-note",
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
    required_sections = [:about, :experience, :projects, :skills]
    present_sections = Enum.map(sections, & &1.section_type)

    matching_sections = Enum.count(present_sections, fn section_type ->
      section_type in required_sections
    end)

    completion_rate = matching_sections / length(required_sections)
    (completion_rate * 40) |> min(40) |> round()
  end

  defp calculate_visual_quality(portfolio, sections) do
    score = 0

    # Check for hero image
    score = if has_hero_image?(portfolio, sections), do: score + 8, else: score

    # Check for consistent theming
    score = if has_consistent_theme?(portfolio), do: score + 7, else: score

    # Check for media in sections
    media_score = count_section_media(sections) |> min(10)
    score + media_score
  end

  defp has_hero_image?(portfolio, sections) do
    # Check in customization first
    customization = portfolio.customization || %{}
    hero_from_customization = Map.get(customization, "hero_image_url") ||
                            Map.get(customization, "hero_image") ||
                            Map.get(customization, "background_image")

    # Check in sections for hero/intro sections
    hero_from_sections = Enum.any?(sections, fn section ->
      section.section_type in [:intro, :hero] &&
      section.content &&
      (Map.has_key?(section.content, "hero_image") ||
      Map.has_key?(section.content, "background_image") ||
      Map.has_key?(section.content, "header_image"))
    end)

    # Return true if hero image found in either location
    (hero_from_customization && hero_from_customization != "") || hero_from_sections
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

  defp can_create_portfolio?(user) do
    limits = Portfolios.get_portfolio_limits(user)
    current_count = Portfolios.count_user_portfolios(user.id)

    limits.max_portfolios == -1 || current_count < limits.max_portfolios
  end

  @impl true
  def handle_event("show_create_modal", _params, socket) do
    IO.puts("=== CREATE MODAL CLICKED ===")
    {:noreply, assign(socket, :show_create_modal, true)}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  def handle_event("close_upgrade_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_upgrade_modal, false)
    |> assign(:upgrade_context, nil)}
  end

  def handle_event("proceed_to_upgrade", _params, socket) do
    context = socket.assigns[:upgrade_context] || %{}

    {:noreply, socket
    |> push_navigate(to: ~p"/upgrade?from=story_lab&context=#{Jason.encode!(context)}")}
  end

  @impl true
  def handle_event("create_from_template", _params, socket) do
    {:noreply, push_navigate(socket, to: "/portfolios/new?method=template")}
  end

  @impl true
  def handle_event("create_from_resume", _params, socket) do
    {:noreply, push_navigate(socket, to: "/onboarding/resume-upload")}
  end

  @impl true
  def handle_event("create_blank", _params, socket) do
    {:noreply, push_navigate(socket, to: "/portfolios/new?method=blank")}
  end

    @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    current_state = Map.get(socket.assigns, :show_mobile_menu, false)
    {:noreply, assign(socket, :show_mobile_menu, !current_state)}
  end

  @impl true
  def handle_event("toggle_collaboration_panel", _params, socket) do
    current_state = Map.get(socket.assigns, :show_collaboration_panel, false)
    {:noreply, assign(socket, :show_collaboration_panel, !current_state)}
  end

  @impl true
  def handle_event("show_community_channels", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_channels_modal, true)
     |> assign(:discovery_active_tab, "channels")}
  end

  @impl true
  def handle_event("navigate_to_channels", _params, socket) do
    {:noreply, push_navigate(socket, to: "/channels")}
  end

  @impl true
  def handle_event("create_portfolio", %{"title" => title} = params, socket) when title != "" do
    user = socket.assigns.current_user
    template = Map.get(params, "template", "professional")

    portfolio_attrs = %{
      title: String.trim(title),
      template: template,
      user_id: user.id,
      status: "draft",
      visibility: :private,
      slug: Portfolios.generate_slug(title)
    }

    case Portfolios.create_portfolio(portfolio_attrs, user) do
      {:ok, portfolio} ->
        {:noreply,
        socket
        |> assign(:show_create_modal, false)
        |> put_flash(:info, "Portfolio '#{portfolio.title}' created successfully!")
        |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create portfolio. Please try again.")}
    end
  end

  @impl true
  def handle_event("create_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please enter a portfolio title")}
  end

  # Upgrade event handlers
  @impl true
  def handle_event("upgrade_to_creator", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/subscription?plan=creator")}
  end

  @impl true
  def handle_event("upgrade_to_professional", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/subscription?plan=professional")}
  end

  @impl true
  def handle_event("upgrade_to_enterprise", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/subscription?plan=enterprise")}
  end

  @impl true
  def handle_event("upgrade_for_lab", _params, socket) do
    {:noreply, push_navigate(socket, to: "/account/subscription?feature=creator_lab")}
  end

  @impl true
  def handle_event("create_service", _params, socket) do
    {:noreply, push_navigate(socket, to: "/services/new")}
  end

  def handle_event("upgrade_to_creator_lab", _params, socket) do
    {:noreply, socket
    |> push_navigate(to: ~p"/upgrade?from=story_lab&target=creator")}
  end

  def handle_event("show_creator_lab_comparison", _params, socket) do
    {:noreply, socket
    |> assign(:show_comparison_modal, true)}
  end

  def handle_event("create_story_from_template", %{"template" => template_id}, socket) do
    user = socket.assigns.current_user
    account = socket.assigns.current_account

    # Check if user has reached story limit
    current_story_count = socket.assigns.story_lab_data.usage_stats.stories_created
    max_stories = socket.assigns.story_lab_data.tier_limits.max_stories

    if current_story_count >= max_stories do
      {:noreply, socket
      |> put_flash(:error, "You've reached your story limit of #{max_stories}. Upgrade to Creator for more stories.")
      |> assign(:show_upgrade_modal, true)}
    else
      # Navigate to story creation (this would be implemented in your Stories context)
      {:noreply, socket
      |> push_navigate(to: ~p"/stories/new?template=#{template_id}")}
    end
  end

  def handle_event("show_upgrade_modal", %{"template" => template_id}, socket) do
    {:noreply, socket
    |> assign(:show_upgrade_modal, true)
    |> assign(:upgrade_context, %{from: "story_lab", template: template_id})}
  end

  def handle_event("create_new_story", _params, socket) do
    user = socket.assigns.current_user
    current_story_count = socket.assigns.story_lab_data.usage_stats.stories_created
    max_stories = socket.assigns.story_lab_data.tier_limits.max_stories

    if current_story_count >= max_stories do
      {:noreply, socket
      |> put_flash(:error, "You've reached your story limit. Upgrade to Creator for unlimited stories.")
      |> assign(:show_upgrade_modal, true)}
    else
      {:noreply, socket
      |> push_navigate(to: ~p"/stories/new")}
    end
  end

  def handle_event("edit_story", %{"story_id" => story_id}, socket) do
    {:noreply, socket
    |> push_navigate(to: ~p"/stories/#{story_id}/edit")}
  end

  def handle_event("create_first_story", _params, socket) do
    handle_event("create_new_story", %{}, socket)
  end

  @impl true
  def handle_info({:collaboration_joined, portfolio_id, joining_user}, socket) do
    # Update collaboration data when someone joins
    updated_data = update_collaboration_data_with_new_collaborator(
      socket.assigns.collaboration_data,
      portfolio_id,
      joining_user
    )

    {:noreply,
     socket
     |> assign(:collaboration_data, updated_data)
     |> put_flash(:info, "#{joining_user.username} joined your portfolio collaboration")}
  end

  @impl true
  def handle_info({:collaboration_invitation_accepted, invitation, accepting_user}, socket) do
    # Update UI when invitation is accepted
    updated_data = remove_pending_invitation(socket.assigns.collaboration_data, invitation.token)

    {:noreply,
     socket
     |> assign(:collaboration_data, updated_data)
     |> put_flash(:info, "#{accepting_user.username} accepted your collaboration invitation")}
  end

  @impl true
  def handle_info({:real_time_edit, portfolio_id, section_id, operation, editor_user}, socket) do
    # Show real-time editing indicators in hub
    if Map.get(socket.assigns, :show_collaboration_panel, false) do
      updated_data = add_real_time_activity(
        socket.assigns.collaboration_data,
        portfolio_id,
        section_id,
        operation,
        editor_user
      )

      {:noreply, assign(socket, :collaboration_data, updated_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("switch_section", %{"section" => section}, socket) do
    hub_config = socket.assigns.hub_config

    cond do
      # If section is available, switch to it
      is_section_available?(hub_config, section) ->
        {:noreply, assign(socket, :active_section, section)}

      # If section is locked, show upgrade prompt and don't switch
      is_section_locked?(hub_config, section) ->
        upgrade_info = get_upgrade_prompt_for_section(hub_config, section)
        upgrade_tier = upgrade_info.tier
        upgrade_message = upgrade_info.message

        {:noreply,
        socket
        |> put_flash(:info, "#{humanize_section_name(section)} requires #{String.capitalize(upgrade_tier)} subscription")
        |> assign(:show_upgrade_modal, true)
        |> assign(:requested_feature, section)
        |> assign(:upgrade_tier_needed, upgrade_tier)}

      # Default case
      true ->
        {:noreply, put_flash(socket, :error, "Unable to access #{humanize_section_name(section)}")}
    end
  end

  def handle_event("switch_section", %{"section" => "calendar"}, socket) do
    # Refresh calendar data when switching to calendar tab
    calendar_data = load_calendar_data(socket.assigns.user, socket.assigns.account)

    {:noreply,
    socket
    |> assign(:active_section, "calendar")
    |> assign(:calendar_data, calendar_data)}
  end

  # Mobile Menu Toggle
  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    current_state = Map.get(socket.assigns, :show_mobile_menu, false)
    {:noreply, assign(socket, :show_mobile_menu, !current_state)}
  end

  @impl true
  def handle_event("toggle_mobile_nav", _params, socket) do
    current_state = Map.get(socket.assigns, :show_mobile_nav, false)
    {:noreply, assign(socket, :show_mobile_nav, !current_state)}
  end

  @impl true
  def handle_event("close_mobile_nav", _params, socket) do
    {:noreply, assign(socket, :show_mobile_nav, false)}
  end

  # Collaboration Panel Toggle
  @impl true
  def handle_event("toggle_collaboration_panel", _params, socket) do
    current_state = Map.get(socket.assigns, :show_collaboration_panel, false)
    {:noreply, assign(socket, :show_collaboration_panel, !current_state)}
  end


  @impl true
  def handle_event("start_mobile_collaboration", %{"portfolio_id" => portfolio_id}, socket) do
    user = socket.assigns.current_user

    case validate_mobile_collaboration_access(socket.assigns.current_account, portfolio_id) do
      {:ok, portfolio} ->
        # Setup mobile-optimized collaboration
        device_info = %{device_type: "mobile", is_mobile: true, supports_real_time: true}
        permissions = get_mobile_collaboration_permissions(portfolio, user)

        PortfolioCollaborationManager.track_portfolio_presence(
          portfolio_id,
          user,
          permissions,
          device_info
        )

        # Navigate to mobile collaboration view
        {:noreply, push_navigate(socket, to: "/portfolios/#{portfolio_id}/mobile-edit?collaborate=true")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Mobile collaboration unavailable: #{reason}")}
    end
  end

  @impl true
  def handle_event("show_mobile_collaboration_options", %{"portfolio_id" => portfolio_id}, socket) do
    mobile_options = get_mobile_collaboration_options(portfolio_id, socket.assigns.current_account)

    {:noreply,
     socket
     |> assign(:mobile_collaboration_options, mobile_options)
     |> assign(:show_mobile_collab_modal, true)}
  end

  # Template Selection Handlers

    @impl true
  def handle_event("select_portfolio_for_studio", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))
    tools_for_enhancement = get_tools_for_enhancement(socket.assigns.selected_enhancement.type)

    {:noreply,
     socket
     |> assign(:selected_portfolio, portfolio)
     |> assign(:studio_step, :tool_configuration)
     |> assign(:tools_for_enhancement, tools_for_enhancement)}
  end

    @impl true
  def handle_event("create_studio_session", %{"configuration" => config}, socket) do
    user = socket.assigns.user
    enhancement = socket.assigns.selected_enhancement
    portfolio = socket.assigns.selected_portfolio

    # Create studio session with enhanced configuration
    session_attrs = %{
      "title" => "#{enhancement.title} - #{portfolio.title}",
      "description" => "Enhancing #{portfolio.title} with #{enhancement.title}",
      "session_type" => "portfolio_enhancement",
      "creator_id" => user.id,
      "host_id" => user.id,
      "context" => %{
        enhancement_type: enhancement.type,
        portfolio_id: portfolio.id,
        tools: Map.get(config, "tools", []),
        collaboration_mode: Map.get(config, "collaboration_mode", "solo")
      }
    }

    case create_enhancement_session(session_attrs, user) do
      {:ok, session} ->
        # Track studio usage
        Features.FeatureGate.track_feature_usage(socket.assigns.account, :studio_session, 1)

        {:noreply,
         socket
         |> assign(:show_studio_modal, false)
         |> put_flash(:info, "Studio session created! Redirecting...")
         |> push_navigate(to: ~p"/studio/#{session.id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create studio session: #{reason}")}
    end
  end

  @impl true
  def handle_event("back_to_enhancement_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:studio_step, :enhancement_selection)
     |> assign(:selected_enhancement, nil)
     |> assign(:selected_portfolio, nil)}
  end

  @impl true
  def handle_event("back_to_portfolio_selection", _params, socket) do
    {:noreply,
     socket
     |> assign(:studio_step, :portfolio_selection)
     |> assign(:selected_portfolio, nil)}
  end

  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    {:noreply, assign(socket, :selected_template, template)}
  end

  @impl true
  def handle_event("navigate_to_studio", _params, socket) do
    {:noreply, push_navigate(socket, to: "/studio")}
  end

  @impl true
  def handle_event("browse_templates", _params, socket) do
    {:noreply, push_navigate(socket, to: "/portfolios/templates")}
  end

  @impl true
  def handle_event("access_story_lab", _params, socket) do
    account = socket.assigns.current_account || %{subscription_tier: "personal"}
    # For now, let's just navigate directly to lab features
    {:noreply, push_navigate(socket, to: "/lab")}
  end

  @impl true
  def handle_event("show_studio_modal", _params, socket) do
    available_enhancements = get_available_enhancements(socket.assigns.account)
    available_tools = get_available_studio_tools(socket.assigns.account)

    {:noreply,
     socket
     |> assign(:show_studio_modal, true)
     |> assign(:studio_step, :enhancement_selection)
     |> assign(:available_enhancements, available_enhancements)
     |> assign(:available_tools, available_tools)
     |> assign(:selected_enhancement, nil)
     |> assign(:selected_portfolio, nil)}
  end

  @impl true
  def handle_event("hide_studio_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_studio_modal, false)
     |> assign(:studio_step, :enhancement_selection)
     |> assign(:selected_enhancement, nil)
     |> assign(:selected_portfolio, nil)}
  end

  @impl true
  def handle_event("show_studio_welcome", _params, socket) do
    {:noreply, assign(socket, :show_studio_welcome_modal, true)}
  end

  @impl true
  def handle_event("hide_studio_welcome", _params, socket) do
    {:noreply, assign(socket, :show_studio_welcome_modal, false)}
  end

  def handle_event("create_studio_session", %{"type" => session_type}, socket) do
    # For now, just navigate to the studio route or close modal with message
    {:noreply,
    socket
    |> assign(:show_studio_modal, false)
    |> put_flash(:info, "Studio sessions coming soon! #{String.capitalize(String.replace(session_type, "_", " "))} will be available in the next update.")
    |> push_navigate(to: "/studio")}
  end


# ==============================================================================
# PHASE 2: STUDIO MODAL SYSTEM IMPLEMENTATION PATCHES
# ==============================================================================

# PATCH 1: UPDATE EXISTING STUDIO EVENT HANDLERS
# ==============================================================================
# FIND in portfolio_hub_live.ex around line 600-700:

  @impl true
  def handle_event("navigate_to_studio", _params, socket) do
    # Now opens studio modal instead of navigating
    {:noreply, assign(socket, :show_studio_modal, true)}
  end

  @impl true
  def handle_event("access_story_lab", _params, socket) do
    account = socket.assigns.current_account || %{subscription_tier: "personal"}

    if Features.FeatureGate.can_access_feature?(account, :creator_lab) do
      {:noreply,
       socket
       |> assign(:show_studio_modal, true)
       |> assign(:studio_enhancement_type, :creator_lab)}
    else
      {:noreply,
       socket
       |> put_flash(:warning, "Creator Lab requires Creator+ subscription")
       |> assign(:show_upgrade_modal, true)}
    end
  end

  @impl true
  def handle_event("create_studio_session", %{"type" => session_type}, socket) do
    user = socket.assigns.user
    account = socket.assigns.account

    case create_contextual_studio_session(user, account, session_type, socket) do
      {:ok, session_url} ->
        {:noreply,
         socket
         |> assign(:show_studio_modal, false)
         |> put_flash(:info, "Studio session created!")
         |> push_navigate(to: session_url)}

      {:error, :upgrade_required} ->
        {:noreply,
         socket
         |> assign(:show_upgrade_modal, true)
         |> put_flash(:warning, "This studio feature requires a higher subscription tier")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create studio session: #{reason}")}
    end
  end

    @impl true
  def handle_event("show_studio_launcher", _params, socket) do
    available_tools = get_studio_tools_for_account(socket.assigns.account)

    {:noreply,
     socket
     |> assign(:show_studio_modal, true)
     |> assign(:studio_step, :tool_selection)
     |> assign(:available_studio_tools, available_tools)
     |> assign(:selected_studio_tools, [])
     |> assign(:studio_enhancement_type, nil)}
  end

  @impl true
  def handle_event("select_enhancement", %{"type" => enhancement_type}, socket) do
    enhancement = Enum.find(socket.assigns.available_enhancements, &(&1.type == enhancement_type))
    portfolios_for_enhancement = get_portfolios_for_enhancement(socket.assigns.portfolios, enhancement_type)

    {:noreply,
     socket
     |> assign(:selected_enhancement, enhancement)
     |> assign(:studio_step, :portfolio_selection)
     |> assign(:portfolios_for_enhancement, portfolios_for_enhancement)}
  end

  @impl true
  def handle_event("launch_studio_with_config", %{"config" => config}, socket) do
    user = socket.assigns.user
    account = socket.assigns.account
    enhancement_type = socket.assigns.studio_enhancement_type

    session_attrs = %{
      "title" => config["session_title"] || "Studio Session",
      "session_type" => "portfolio_enhancement",
      "enhancement_context" => %{
        type: enhancement_type,
        tools: socket.assigns.selected_studio_tools,
        layout: socket.assigns.studio_layout_config,
        portfolio_id: config["portfolio_id"]
      },
      "creator_id" => user.id,
      "host_id" => user.id,
      "is_public" => false
    }

    case Sessions.create_studio_session(session_attrs) do
      {:ok, session} ->
        {:noreply,
         socket
         |> assign(:show_studio_modal, false)
         |> put_flash(:info, "Studio session launched!")
         |> push_navigate(to: ~p"/studio/#{session.id}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create studio session")}
    end
  end

  @impl true
  def handle_event("quick_studio_launch", %{"enhancement" => enhancement_type}, socket) do
    # Quick launch with default settings for common enhancements
    account = socket.assigns.account

    case enhancement_type do
      "voice_intro" ->
        if Features.FeatureGate.can_access_feature?(account, :voice_recording) do
          launch_quick_studio_session(socket, :voice_intro, ["audio_recorder", "script_editor"])
        else
          {:noreply, show_upgrade_prompt(socket, "voice recording")}
        end

      "writing_enhancement" ->
        if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
          launch_quick_studio_session(socket, :writing_enhancement, ["text_editor", "ai_assistant"])
        else
          {:noreply, show_upgrade_prompt(socket, "writing collaboration")}
        end

      "background_music" ->
        if Features.FeatureGate.can_access_feature?(account, :audio_creation) do
          launch_quick_studio_session(socket, :background_music, ["beat_machine", "audio_mixer"])
        else
          {:noreply, show_upgrade_prompt(socket, "music creation")}
        end

      _ ->
        {:noreply, put_flash(socket, :error, "Unknown enhancement type")}
    end
  end

  @impl true
  def handle_event("navigate_to_studio", _params, socket) do
    # Now opens studio modal instead of navigating
    {:noreply, assign(socket, :show_studio_modal, true)}
  end

  @impl true
  def handle_event("prevent_close", _params, socket) do
    # Prevents modal from closing when clicking inside modal content
    {:noreply, socket}
  end

  # Enhanced Welcome Flow
  @impl true
  def handle_event("dismiss_welcome", _params, socket) do
    {:noreply, assign(socket, :show_welcome_celebration, false)}
  end

  @impl true
  def handle_event("complete_onboarding_step", %{"step" => step}, socket) do
    user = socket.assigns.current_user

    # Track onboarding completion
    case step do
      "upload_resume" ->
        {:noreply, push_navigate(socket, to: "/onboarding/upload")}
      "share_promote" ->
        {:noreply, push_navigate(socket, to: "/portfolios/share")}
      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("preview_video_intro", %{"portfolio-id" => portfolio_id} = params, socket) do
    # Handle hyphenated parameter name from template
    handle_event("preview_video_intro", Map.put(params, "portfolio_id", portfolio_id), socket)
  end

  @impl true
  def handle_event("preview_video_intro", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      # Navigate to portfolio view to see the video
      {:noreply, push_navigate(socket, to: "/#{Map.get(portfolio, :slug, portfolio_id)}")}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("record_video_intro", %{"portfolio-id" => portfolio_id} = params, socket) do
    # Handle hyphenated parameter name from template
    handle_event("record_video_intro", Map.put(params, "portfolio_id", portfolio_id), socket)
  end

  @impl true
  def handle_event("record_video_intro", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      {:noreply,
      socket
      |> assign(:show_video_intro_modal, true)
      |> assign(:current_portfolio_for_video, portfolio)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  # ============================================================================
  # MORE MENU WITH EXPORT OPTIONS
  # ============================================================================

  # Add to your existing event handlers:

  @impl true
  def handle_event("toggle_more_menu", %{"portfolio-id" => portfolio_id}, socket) do
    current_open = socket.assigns[:open_more_menu]
    new_open = if current_open == portfolio_id, do: nil, else: portfolio_id

    {:noreply, assign(socket, :open_more_menu, new_open)}
  end

  @impl true
  def handle_event("close_more_menu", _params, socket) do
    {:noreply, assign(socket, :open_more_menu, nil)}
  end

  @impl true
  def handle_event("export_portfolio", %{"portfolio-id" => portfolio_id, "format" => format}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case format do
      "pdf" ->
        case export_portfolio_to_pdf(portfolio, socket.assigns.current_user) do
          {:ok, pdf_url} ->
            {:noreply,
            socket
            |> assign(:open_more_menu, nil)
            |> push_event("download_file", %{url: pdf_url, filename: "#{portfolio.slug}-portfolio.pdf"})
            |> put_flash(:info, "PDF export ready for download")}

          {:error, reason} ->
            {:noreply,
            socket
            |> assign(:open_more_menu, nil)
            |> put_flash(:error, "PDF export failed: #{reason}")}
        end

      "json" ->
        case export_portfolio_to_json(portfolio) do
          {:ok, json_data} ->
            {:noreply,
            socket
            |> assign(:open_more_menu, nil)
            |> push_event("download_json", %{data: json_data, filename: "#{portfolio.slug}-portfolio.json"})
            |> put_flash(:info, "Portfolio data exported")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
        end

      "analytics" ->
        case export_portfolio_analytics(portfolio, socket.assigns.current_user) do
          {:ok, analytics_data} ->
            {:noreply,
            socket
            |> assign(:open_more_menu, nil)
            |> push_event("download_csv", %{data: analytics_data, filename: "#{portfolio.slug}-analytics.csv"})
            |> put_flash(:info, "Analytics exported")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Analytics export failed: #{reason}")}
        end
    end
  end

  @impl true
  def handle_event("duplicate_portfolio", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case duplicate_portfolio(portfolio, socket.assigns.current_user) do
      {:ok, new_portfolio} ->
        updated_portfolios = [new_portfolio | socket.assigns.portfolios]

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:open_more_menu, nil)
        |> put_flash(:info, "Portfolio duplicated successfully")
        |> push_navigate(to: "/portfolios/#{new_portfolio.id}/edit")}

      {:error, reason} ->
        {:noreply,
        socket
        |> assign(:open_more_menu, nil)
        |> put_flash(:error, "Failed to duplicate portfolio: #{reason}")}
    end
  end

  @impl true
  def handle_event("archive_portfolio", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    case archive_portfolio(portfolio, socket.assigns.current_user) do
      {:ok, archived_portfolio} ->
        updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
          if p.id == archived_portfolio.id, do: archived_portfolio, else: p
        end)

        {:noreply,
        socket
        |> assign(:portfolios, updated_portfolios)
        |> assign(:open_more_menu, nil)
        |> put_flash(:info, "Portfolio archived")}

      {:error, reason} ->
        {:noreply,
        socket
        |> assign(:open_more_menu, nil)
        |> put_flash(:error, "Failed to archive portfolio: #{reason}")}
    end
  end

  @impl true
  def handle_event("show_settings_modal", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    {:noreply,
    socket
    |> assign(:show_settings_modal, true)
    |> assign(:selected_portfolio_for_settings, portfolio)
    |> assign(:open_more_menu, nil)}
  end

  @impl true
  def handle_event("navigate_to_portfolio", %{"id" => id, "value" => _value}, socket) do
    handle_event("navigate_to_portfolio", %{"id" => id}, socket)
  end

  @impl true
  def handle_event("navigate_to_portfolio", %{"id" => id}, socket) do
    portfolio_id = String.to_integer(id)
    {:noreply, push_navigate(socket, to: "/portfolios/#{portfolio_id}/edit")}
  end


  # Portfolio Overview Events
  @impl true
  def handle_event("show_portfolio_overview", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

      if portfolio do
        url_preview = %{
          current_url: "#{get_base_url()}/#{Map.get(portfolio, :slug, portfolio_id)}",
          custom_available: true
        }

        {:noreply,
        socket
        |> assign(:selected_portfolio_for_overview, portfolio)
        |> assign(:url_preview, url_preview)
        |> assign(:show_url_customization, true)}
      else
        {:noreply, put_flash(socket, :error, "Portfolio not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
    end
  end

  # Portfolio Settings Events
  @impl true
  def handle_event("show_portfolio_settings", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

      if portfolio do
        settings_data = load_portfolio_settings(portfolio, socket.assigns.current_user)

        {:noreply,
        socket
        |> assign(:show_settings_modal, true)
        |> assign(:selected_portfolio_for_settings, portfolio)
        |> assign(:settings_data, settings_data)}
      else
        {:noreply, put_flash(socket, :error, "Portfolio not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
    end
  end

  # Video Intro Events
  @impl true
  def handle_event("preview_video_intro", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

      if portfolio do
        {:noreply, push_navigate(socket, to: "/#{Map.get(portfolio, :slug, portfolio_id)}")}
      else
        {:noreply, put_flash(socket, :error, "Portfolio not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
    end
  end

  @impl true
  def handle_event("record_video_intro", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

      if portfolio do
        {:noreply,
        socket
        |> assign(:show_video_intro_modal, true)
        |> assign(:current_portfolio_for_video, portfolio)}
      else
        {:noreply, put_flash(socket, :error, "Portfolio not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
    end
  end

  # Portfolio Navigation
  @impl true
  def handle_event("navigate_to_portfolio", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      {:noreply, push_navigate(socket, to: "/portfolios/#{portfolio_id}/edit")}
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
    end
  end

  # Copy Portfolio URL
  @impl true
  def handle_event("copy_portfolio_url", params, socket) do
    portfolio_id = extract_portfolio_id(params)

    if portfolio_id do
      portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

      if portfolio do
        url = "#{get_base_url()}/#{Map.get(portfolio, :slug, portfolio_id)}"

        {:noreply,
        socket
        |> put_flash(:info, "Portfolio URL copied to clipboard!")
        |> push_event("copy-to-clipboard", %{text: url})}
      else
        {:noreply, put_flash(socket, :error, "Portfolio not found")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio ID required")}
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
    # 🔥 FIX: Use NaiveDateTime.compare instead of DateTime.compare
    # since inserted_at is a NaiveDateTime struct, not DateTime
    |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
    |> List.first()
  end

  # Alternative fix if you want to handle both DateTime and NaiveDateTime:
  defp get_recently_created_portfolio_safe(portfolios) do
    portfolios
    |> Enum.sort_by(fn portfolio ->
      case portfolio.inserted_at do
        %DateTime{} = dt -> dt
        %NaiveDateTime{} = ndt ->
          # Convert NaiveDateTime to DateTime (assuming UTC)
          DateTime.from_naive!(ndt, "Etc/UTC")
        _ ->
          # Fallback to current time if neither
          DateTime.utc_now()
      end
    end, {:desc, DateTime})
    |> List.first()
  end

  # Or the simplest fix - use the raw comparison:
  defp get_recently_created_portfolio_simple(portfolios) do
    case portfolios do
      [] -> nil
      [portfolio] -> portfolio
      portfolios ->
        Enum.max_by(portfolios, & &1.inserted_at, NaiveDateTime)
    end
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
      section.content && Map.has_key?(section.content, :voice_intro)
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
    customization = portfolio.customization || %{}
    social_links = Map.get(customization, "social_links") || %{}
    map_size(social_links) > 0
  end

  defp has_cta?(portfolio) do
    # Check if there's contact info in customization or basic description
    customization = portfolio.customization || %{}
    contact_info = Map.get(customization, "contact_info") || %{}

    # Also check if portfolio has description (basic CTA)
    has_contact = map_size(contact_info) > 0
    has_description = portfolio.description && String.trim(portfolio.description) != ""

    has_contact || has_description
  end

  defp has_custom_domain?(portfolio) do
    # Check if portfolio uses custom domain
    false # Mock - implement based on your schema
  end

  defp has_professional_contact?(portfolio) do
    customization = portfolio.customization || %{}
    contact_info = Map.get(customization, "contact_info") || %{}
    map_size(contact_info) > 0
  end

  defp has_complete_contact?(portfolio) do
    customization = portfolio.customization || %{}
    contact = Map.get(customization, "contact_info") || %{}
    Map.has_key?(contact, "email") && Map.has_key?(contact, "phone")
  end


  defp has_seo_optimization?(portfolio) do
    portfolio.description != nil && String.trim(portfolio.description) != ""
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

  @impl true
  def handle_event("view_calendar", _params, socket) do
    {:noreply, push_navigate(socket, to: "/calendar")}
  end

  defp get_enhancement_progress(portfolios) do
    if length(portfolios) == 0 do
      %{completed: 0, total: 0, percentage: 0}
    else
      total_enhancements = length(portfolios) * 5  # 5 potential enhancements per portfolio
      completed = Enum.reduce(portfolios, 0, fn portfolio, acc ->
        enhancements_count = count_portfolio_enhancements(portfolio)
        acc + enhancements_count
      end)

      percentage = if total_enhancements > 0, do: round(completed / total_enhancements * 100), else: 0

      %{
        completed: completed,
        total: total_enhancements,
        percentage: percentage
      }
    end
  end

  defp get_available_templates_count(account) do
    case account.subscription_tier do
      "personal" -> 3
      "creator" -> 8
      "creator_plus" -> 15
      _ -> 3
    end
  end

  defp count_portfolio_enhancements(portfolio) do
    enhancements = 0

    # Check for various enhancements
    enhancements = if portfolio.theme && portfolio.theme != "default", do: enhancements + 1, else: enhancements
    enhancements = if map_size(portfolio.customization || %{}) > 0, do: enhancements + 1, else: enhancements
    enhancements = if length(portfolio.sections || []) > 3, do: enhancements + 1, else: enhancements
    enhancements = if portfolio.custom_css && String.length(portfolio.custom_css) > 0, do: enhancements + 1, else: enhancements
    enhancements = if portfolio.visibility == :public, do: enhancements + 1, else: enhancements

    enhancements
  end

  defp get_creation_limits(account) do
    case account.subscription_tier do
      "personal" -> %{max_portfolios: 2, max_sections_per_portfolio: 8, max_media_per_section: 5}
      "creator" -> %{max_portfolios: 10, max_sections_per_portfolio: 15, max_media_per_section: 15}
      "creator_plus" -> %{max_portfolios: 50, max_sections_per_portfolio: 25, max_media_per_section: 25}
      _ -> %{max_portfolios: 2, max_sections_per_portfolio: 8, max_media_per_section: 5}
    end
  end

  # Feature availability helpers
  defp get_recent_portfolio_activity(user_id), do: []
  defp get_channel_limits(account), do: %{}
  defp get_beta_features(account), do: []
  defp check_calendar_integration(user_id), do: false
  defp check_billing_integration(user_id), do: false
  defp portfolio_needs_work?(portfolio), do: false

  defp extract_portfolio_id(params) do
    cond do
      Map.has_key?(params, "portfolio_id") -> Map.get(params, "portfolio_id")
      Map.has_key?(params, "portfolio-id") -> Map.get(params, "portfolio-id")
      Map.has_key?(params, "id") -> Map.get(params, "id")
      true -> nil
    end
  end

  defp show_as_upgrade_prompt?(hub_config, section) do
    # Show upgrade prompts for sections that are one tier away
    upgrade_info = get_upgrade_prompt_for_section(hub_config, section)
    current_tier = get_current_tier_level(hub_config)
    required_tier = get_tier_level(upgrade_info.tier)

    # Show if the required tier is only 1 level higher
    required_tier - current_tier <= 1
  end

  defp get_current_tier_level(hub_config) do
    cond do
      length(hub_config.locked_sections) == 0 -> 4  # enterprise
      "revenue_center" not in hub_config.locked_sections -> 3  # professional
      "service_dashboard" not in hub_config.locked_sections -> 2  # creator
      true -> 1  # personal
    end
  end

  defp get_tier_level(tier) do
    case tier do
      "personal" -> 1
      "creator" -> 2
      "professional" -> 3
      "enterprise" -> 4
      _ -> 1
    end
  end

  defp get_original_tab_classes(hub_config, section, active_section) do
    cond do
      active_section == section ->
        "border-purple-500 text-purple-600"

      is_section_locked?(hub_config, section) ->
        "border-transparent text-gray-300 hover:text-gray-400 cursor-not-allowed"

      true ->
        "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300"
    end
  end

  defp get_mobile_tab_classes(hub_config, section, active_section) do
    cond do
      active_section == section ->
        "bg-purple-50 text-purple-600 border-r-2 border-purple-500"

      is_section_locked?(hub_config, section) ->
        "text-gray-300 cursor-not-allowed"

      true ->
        "text-gray-700 hover:bg-gray-50"
    end
  end

  # Update the existing get_section_badge function to be simpler
  defp get_section_badge(hub_config, section) do
    cond do
      section == "creator_lab" -> "BETA"
      section == "revenue_center" -> "NEW"
      true -> nil
    end
  end


  # ============================================================================
  # MAIN SECTION FUNCTIONS (called directly from template)
  # ============================================================================

  defp enhanced_portfolio_grid_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Enhanced Header (same as before) -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Your Portfolios</h2>
          <p class="text-gray-600 mt-1">
            <%= length(@portfolios) %> portfolios •
            <%= Enum.count(@portfolios, &(Map.get(&1, :visibility) == :public)) %> published
          </p>
        </div>

        <div class="flex items-center space-x-4">
          <!-- Action Buttons -->
          <div class="flex items-center space-x-3">
            <!-- Creative Studio Button (NEW) -->
            <button phx-click="show_studio_modal"
                    class="flex items-center px-4 py-2.5 bg-gradient-to-r from-green-500 to-teal-600 text-white rounded-xl hover:from-green-600 hover:to-teal-700 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"/>
              </svg>
              Creative Studio
            </button>

            <!-- Go Live Button (NEW) -->
            <%= if @broadcast_data.can_go_live do %>
              <button phx-click="show_broadcast_modal"
                      class="flex items-center px-4 py-2.5 bg-gradient-to-r from-red-500 to-pink-600 text-white rounded-xl hover:from-red-600 hover:to-pink-700 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
                <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"/>
                </svg>
                Go Live
                <%= if length(@broadcast_data.active_broadcasts) > 0 do %>
                  <span class="ml-2 w-2 h-2 bg-green-400 rounded-full animate-pulse"></span>
                <% end %>
              </button>
            <% else %>
              <!-- Upgrade prompt for non-Creator users -->
              <button phx-click="show_upgrade_modal"
                      class="flex items-center px-4 py-2.5 bg-gray-500 text-white rounded-xl opacity-75 cursor-not-allowed">
                <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M2 6a2 2 0 012-2h6a2 2 0 012 2v8a2 2 0 01-2 2H4a2 2 0 01-2-2V6zM14.553 7.106A1 1 0 0014 8v4a1 1 0 00.553.894l2 1A1 1 0 0018 13V7a1 1 0 00-1.447-.894l-2 1z"/>
                </svg>
                Go Live
                <svg class="w-3 h-3 ml-1" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"/>
                </svg>
              </button>
            <% end %>

            <!-- Create New Button (existing) -->
            <button phx-click="show_create_modal"
                    class="flex items-center px-4 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 text-white rounded-xl hover:from-blue-700 hover:to-indigo-700 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
              Create New
            </button>
          </div>
          <!-- View Toggle (FIXED) -->
          <div class="flex bg-gray-100 rounded-lg p-1">
            <button phx-click="set_view_mode" phx-value-mode="grid"
                    class={[
                      "px-3 py-1.5 rounded text-sm font-medium transition-colors",
                      if(@view_mode == "grid",
                        do: "bg-white text-gray-900 shadow-sm",
                        else: "text-gray-600 hover:text-gray-900")
                    ]}>
              <svg class="w-4 h-4 mr-1.5 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
              </svg>
              Grid
            </button>
            <button phx-click="set_view_mode" phx-value-mode="list"
                    class={[
                      "px-3 py-1.5 rounded text-sm font-medium transition-colors",
                      if(@view_mode == "list",
                        do: "bg-white text-gray-900 shadow-sm",
                        else: "text-gray-600 hover:text-gray-900")
                    ]}>
              <svg class="w-4 h-4 mr-1.5 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
              </svg>
              List
            </button>
          </div>
        </div>
      </div>

      <!-- Dynamic Portfolio Display based on view_mode -->
      <%= case @view_mode do %>
        <% "list" -> %>
          <%= render_portfolio_list_view(assigns) %>
        <% _ -> %>
          <%= render_portfolio_grid_view(assigns) %>
      <% end %>
    </div>
    """
  end

  # Separate the grid view into its own function
  defp render_portfolio_grid_view(assigns) do
    ~H"""
    <!-- Enhanced Portfolio Cards Grid -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
      <%= for portfolio <- @portfolios do %>
        <div class="group bg-white rounded-xl shadow-md hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1 overflow-hidden border border-gray-100">
          <!-- Theme Color Header -->
          <div class={[
            "h-1 bg-gradient-to-r rounded-t-xl",
            case Map.get(portfolio, :theme, "default") do
              "minimalist" -> "from-gray-600 to-gray-800"
              "creative" -> "from-purple-600 to-pink-600"
              "corporate" -> "from-blue-600 to-indigo-600"
              "developer" -> "from-green-600 to-teal-600"
              _ -> "from-cyan-600 to-blue-600"
            end
          ]}></div>

          <!-- Portfolio Preview -->
          <div class={[
            "h-32 flex items-center justify-center relative overflow-hidden bg-gradient-to-r",
            case Map.get(portfolio, :theme, "default") do
              "minimalist" -> "from-gray-600 to-gray-800"
              "creative" -> "from-purple-600 to-pink-600"
              "corporate" -> "from-blue-600 to-indigo-600"
              "developer" -> "from-green-600 to-teal-600"
              _ -> "from-cyan-600 to-blue-600"
            end
          ]}>
            <div class="absolute inset-0 bg-black bg-opacity-10"></div>

            <!-- Video Introduction Indicator -->
            <%= if has_intro_video?(portfolio) do %>
              <div class="absolute top-3 left-3 bg-green-500 text-white px-2 py-1 rounded-full text-xs font-bold flex items-center space-x-1">
                <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                </svg>
                <span>Video</span>
              </div>
            <% end %>

            <!-- Portfolio Title -->
            <div class="relative z-10 text-center text-white">
              <h3 class="text-lg font-bold"><%= portfolio.title %></h3>
              <div class="flex items-center justify-center space-x-1 mt-1">
                <span class="text-sm opacity-90">/<%= Map.get(portfolio, :slug, "portfolio") %></span>
              </div>
            </div>
          </div>

          <!-- Card Content with Icon Buttons -->
          <%= render_portfolio_card_content(assigns, portfolio) %>
        </div>
      <% end %>

      <!-- Enhanced Create New Portfolio Card -->
      <%= render_create_new_portfolio_card(assigns) %>
    </div>
    """
  end

  defp story_lab_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Story Lab Header -->
      <div class="flex items-center justify-between">
        <div>
          <div class="flex items-center space-x-3">
            <h2 class="text-2xl font-bold text-gray-900 flex items-center">
              <span class="mr-3">📖</span>
              Story Lab
            </h2>
            <%= if @story_lab_data.upgrade_prompt do %>
              <span class="px-3 py-1 bg-purple-100 text-purple-700 text-sm rounded-full font-medium">
                Personal Tier
              </span>
            <% end %>
          </div>
          <p class="text-gray-600 mt-1">
            Create engaging stories with audio, video, and interactive elements
          </p>
        </div>

        <%= if @story_lab_data.upgrade_prompt do %>
          <button phx-click="upgrade_to_creator_lab"
                  class="px-6 py-3 bg-gradient-to-r from-purple-600 to-indigo-600 text-white rounded-lg hover:from-purple-700 hover:to-indigo-700 font-medium transition-all transform hover:scale-105 shadow-lg">
            <svg class="w-5 h-5 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Unlock Full Creator Lab
          </button>
        <% end %>
      </div>

      <!-- Usage Stats & Limits (Personal tier) -->
      <%= if @story_lab_data.upgrade_prompt do %>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div class="bg-gradient-to-br from-purple-50 to-pink-50 rounded-xl p-6 border border-purple-200">
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-semibold text-gray-900">Stories Created</h3>
              <span class="text-2xl">📚</span>
            </div>
            <div class="flex items-end space-x-2">
              <span class="text-3xl font-bold text-purple-600"><%= @story_lab_data.usage_stats.stories_created %></span>
              <span class="text-gray-500 mb-1">of <%= @story_lab_data.tier_limits.max_stories %></span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div class="bg-purple-600 h-2 rounded-full" style={"width: #{(@story_lab_data.usage_stats.stories_created / @story_lab_data.tier_limits.max_stories * 100)}%"}></div>
            </div>
          </div>

          <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-xl p-6 border border-blue-200">
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-semibold text-gray-900">Recording Time</h3>
              <span class="text-2xl">🎙️</span>
            </div>
            <div class="flex items-end space-x-2">
              <span class="text-3xl font-bold text-blue-600"><%= @story_lab_data.usage_stats.recording_minutes_used %></span>
              <span class="text-gray-500 mb-1">of <%= @story_lab_data.tier_limits.recording_minutes_limit %> min</span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2 mt-3">
              <div class="bg-blue-600 h-2 rounded-full" style={"width: #{(@story_lab_data.usage_stats.recording_minutes_used / @story_lab_data.tier_limits.recording_minutes_limit * 100)}%"}></div>
            </div>
          </div>

          <div class="bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl p-6 border border-green-200">
            <div class="flex items-center justify-between mb-4">
              <h3 class="font-semibold text-gray-900">Chapters Written</h3>
              <span class="text-2xl">📄</span>
            </div>
            <div class="flex items-end space-x-2">
              <span class="text-3xl font-bold text-green-600"><%= @story_lab_data.usage_stats.chapters_created %></span>
              <span class="text-gray-500 mb-1">total</span>
            </div>
            <p class="text-sm text-gray-600 mt-2">
              Up to <%= @story_lab_data.tier_limits.max_chapters_per_story %> per story
            </p>
          </div>
        </div>

        <!-- Upgrade Prompt Banner -->
        <div class="bg-gradient-to-r from-amber-50 to-orange-50 border border-amber-200 rounded-xl p-6">
          <div class="flex items-start space-x-4">
            <div class="flex-shrink-0">
              <svg class="w-8 h-8 text-amber-600" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd"/>
              </svg>
            </div>
            <div class="flex-1">
              <h4 class="font-semibold text-amber-900 mb-2">Personal Tier Limitations</h4>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <ul class="text-sm text-amber-800 space-y-2">
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    Limited to 2 stories maximum
                  </li>
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    5 chapters per story limit
                  </li>
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    30 minutes audio recording
                  </li>
                </ul>
                <ul class="text-sm text-amber-800 space-y-2">
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    Basic templates only
                  </li>
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    No collaboration features
                  </li>
                  <li class="flex items-center">
                    <svg class="w-4 h-4 mr-2 text-amber-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                    No advanced audio features
                  </li>
                </ul>
              </div>
              <div class="mt-4 flex space-x-3">
                <button phx-click="show_creator_lab_comparison"
                        class="text-amber-800 font-medium text-sm hover:text-amber-900 underline">
                  See what Creator Lab unlocks →
                </button>
                <button phx-click="upgrade_to_creator_lab"
                        class="px-4 py-2 bg-amber-600 text-white rounded-lg text-sm font-medium hover:bg-amber-700 transition-colors">
                  Upgrade to Creator
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Story Templates -->
      <div>
        <div class="flex items-center justify-between mb-6">
          <h3 class="text-xl font-semibold text-gray-900">Quick Start Templates</h3>
          <%= if !@story_lab_data.upgrade_prompt do %>
            <button phx-click="browse_all_templates"
                    class="text-indigo-600 hover:text-indigo-700 text-sm font-medium">
              Browse All Templates →
            </button>
          <% end %>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <%= for template <- @story_lab_data.available_templates do %>
            <div class={[
              "border rounded-xl p-6 transition-all duration-200 hover:shadow-lg",
              Map.get(template, :requires_tier) && @story_lab_data.upgrade_prompt && "border-gray-300 opacity-75" || "border-gray-200 hover:border-indigo-300"
            ]}>
              <div class="flex items-start justify-between mb-4">
                <div class="text-3xl"><%= template.icon %></div>
                <%= if Map.get(template, :requires_tier) && @story_lab_data.upgrade_prompt do %>
                  <span class="px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded-full font-medium">
                    Creator
                  </span>
                <% end %>
              </div>

              <h4 class="font-semibold text-gray-900 mb-2"><%= template.name %></h4>
              <p class="text-sm text-gray-600 mb-4"><%= template.description %></p>

              <div class="mb-4">
                <div class="flex items-center text-xs text-gray-500 mb-2">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  <%= template.estimated_time %>
                </div>
                <div class="flex flex-wrap gap-1">
                  <%= for feature <- template.features do %>
                    <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                      <%= feature %>
                    </span>
                  <% end %>
                </div>
              </div>

              <%= if Map.get(template, :requires_tier) && @story_lab_data.upgrade_prompt do %>
                <button phx-click="show_upgrade_modal"
                        phx-value-template={template.id}
                        class="w-full px-4 py-2 bg-gray-200 text-gray-500 rounded-lg cursor-not-allowed">
                  Requires Creator Tier
                </button>
              <% else %>
                <button phx-click="create_story_from_template"
                        phx-value-template={template.id}
                        class="w-full px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 font-medium transition-colors">
                  Start Story
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Existing Stories -->
      <%= if length(@story_lab_data.user_stories) > 0 do %>
        <div>
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-xl font-semibold text-gray-900">Your Stories</h3>
            <div class="flex items-center space-x-3">
              <select class="text-sm border-gray-300 rounded-lg">
                <option>All Stories</option>
                <option>Recent</option>
                <option>Published</option>
              </select>
              <button phx-click="create_new_story"
                      class="px-4 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 text-sm font-medium">
                New Story
              </button>
            </div>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for story <- @story_lab_data.user_stories do %>
              <div class="border border-gray-200 rounded-xl p-6 hover:shadow-lg transition-all">
                <div class="flex items-start justify-between mb-4">
                  <h4 class="font-semibold text-gray-900 line-clamp-2"><%= Map.get(story, :title, "Untitled Story") %></h4>
                  <div class="flex items-center space-x-1">
                    <button class="text-gray-400 hover:text-gray-600">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
                      </svg>
                    </button>
                  </div>
                </div>

                <div class="flex items-center space-x-4 text-sm text-gray-500 mb-4">
                  <span><%= Map.get(story, :chapter_count, 0) %> chapters</span>
                  <span>•</span>
                  <span>Updated <%= Map.get(story, :updated_at, "recently") %></span>
                </div>

                <div class="flex items-center justify-between">
                  <span class={[
                    "px-2 py-1 rounded-full text-xs font-medium",
                    case Map.get(story, :status) do
                      "published" -> "bg-green-100 text-green-700"
                      "draft" -> "bg-gray-100 text-gray-700"
                      _ -> "bg-blue-100 text-blue-700"
                    end
                  ]}>
                    <%= String.capitalize(Map.get(story, :status, "draft")) %>
                  </span>

                  <button phx-click="edit_story"
                          phx-value-story_id={Map.get(story, :id)}
                          class="text-indigo-600 hover:text-indigo-700 text-sm font-medium">
                    Continue →
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-12 bg-gray-50 rounded-xl">
          <div class="text-6xl mb-4">📝</div>
          <h3 class="text-xl font-semibold text-gray-900 mb-2">Ready to tell your story?</h3>
          <p class="text-gray-600 mb-6 max-w-md mx-auto">
            Choose a template above to create your first interactive story with audio, chapters, and multimedia elements.
          </p>
          <button phx-click="create_first_story"
                  class="px-6 py-3 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 font-medium">
            Create Your First Story
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Add the list view rendering function
  defp render_portfolio_list_view(assigns) do
    ~H"""
    <div class="bg-white rounded-xl shadow-md border border-gray-100 overflow-hidden">
      <%= if length(@portfolios) > 0 do %>
        <div class="divide-y divide-gray-100">
          <%= for portfolio <- @portfolios do %>
            <div class="p-6 hover:bg-gray-50 transition-colors">
              <div class="flex items-center justify-between">
                <!-- Portfolio Info -->
                <div class="flex items-center flex-1">
                  <!-- Theme Color Indicator -->
                  <div class={[
                    "w-4 h-4 rounded-full mr-4 flex-shrink-0",
                    case Map.get(portfolio, :theme, "default") do
                      "minimalist" -> "bg-gray-600"
                      "creative" -> "bg-purple-600"
                      "corporate" -> "bg-blue-600"
                      "developer" -> "bg-green-600"
                      _ -> "bg-cyan-600"
                    end
                  ]}></div>

                  <!-- Portfolio Details -->
                  <div class="flex-1 min-w-0">
                    <div class="flex items-center space-x-3 mb-1">
                      <h3 class="text-lg font-semibold text-gray-900 truncate"><%= portfolio.title %></h3>

                      <!-- Video Indicator -->
                      <%= if has_intro_video?(portfolio) do %>
                        <div class="flex items-center text-green-600">
                          <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                          </svg>
                          <span class="text-xs font-medium">Video</span>
                        </div>
                      <% end %>

                      <!-- Status Badge -->
                      <% {badge_class, badge_text} = portfolio_status_badge(portfolio) %>
                      <span class={"px-2 py-1 rounded-full text-xs font-medium #{badge_class}"}>
                        <%= badge_text %>
                      </span>
                    </div>

                    <div class="flex items-center text-sm text-gray-500 space-x-4">
                      <span>/<%= Map.get(portfolio, :slug, "portfolio") %></span>
                      <span><%= get_portfolio_view_count(portfolio) %> views</span>
                      <span><%= get_portfolio_section_count(portfolio) %> sections</span>
                      <span>Updated <%= time_ago(Map.get(portfolio, :updated_at)) %></span>
                    </div>

                    <%= if Map.get(portfolio, :description) do %>
                      <p class="text-sm text-gray-600 mt-2 line-clamp-1">
                        <%= Map.get(portfolio, :description) %>
                      </p>
                    <% end %>
                  </div>
                </div>

                <!-- Action Icons (Same as Grid View) -->
                <div class="flex items-center space-x-1 ml-4">
                  <!-- Video Intro Button -->
                  <%= if has_intro_video?(portfolio) do %>
                    <button phx-click="show_video_intro" phx-value-portfolio_id={portfolio.id}
                            class="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                            title="Edit Video Introduction">
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                    </button>
                  <% else %>
                    <button phx-click="show_video_intro" phx-value-portfolio_id={portfolio.id}
                            class="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                            title="Add Video Introduction">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                      </svg>
                    </button>
                  <% end %>

                  <!-- Visibility Toggle Button -->
                  <button phx-click="toggle_discovery" phx-value-portfolio_id={portfolio.id}
                          class={[
                            "p-2 rounded-lg transition-colors",
                            if(Map.get(portfolio, :visibility) == :public,
                              do: "text-green-600 hover:bg-green-50",
                              else: "text-gray-600 hover:bg-gray-50")
                          ]}
                          title={
                            if(Map.get(portfolio, :visibility) == :public,
                              do: "Portfolio is Public",
                              else: "Portfolio is Private")
                          }>
                    <%= if Map.get(portfolio, :visibility) == :public do %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                      </svg>
                    <% end %>
                  </button>

                  <!-- Copy Link Button -->
                  <button phx-click="copy_portfolio_url" phx-value-portfolio_id={portfolio.id}
                          class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                          title="Copy Portfolio Link">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                    </svg>
                  </button>

                  <!-- Feedback Button -->
                  <button phx-click="request_feedback" phx-value-portfolio_id={portfolio.id}
                          class="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                          title="Request Feedback">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
                    </svg>
                  </button>

                  <!-- Settings Button -->
                  <button phx-click="show_portfolio_settings" phx-value-portfolio_id={portfolio.id}
                          class="p-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors"
                          title="Portfolio Settings">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    </svg>
                  </button>

                  <!-- Delete Button -->
                  <button phx-click="delete_portfolio" phx-value-id={portfolio.id}
                          data-confirm="Are you sure you want to delete this portfolio? This action cannot be undone."
                          class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                          title="Delete Portfolio">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>

                  <!-- Edit Button -->
                  <button phx-click="navigate_to_portfolio" phx-value-id={portfolio.id}
                          class="p-2 bg-blue-600 text-white hover:bg-blue-700 rounded-lg transition-colors"
                          title="Edit Portfolio">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-12">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No portfolios yet</h3>
          <p class="text-gray-600 mb-4">Create your first portfolio to get started</p>
          <button phx-click="show_create_modal"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Create Portfolio
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_portfolio_card_content(assigns, portfolio) do
    assigns = assign(assigns, :portfolio, portfolio)

    ~H"""
    <!-- Card Content -->
    <div class="p-6">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h3 class="text-xl font-bold text-gray-900 mb-2"><%= @portfolio.title %></h3>
          <div class="flex items-center space-x-2 mb-3">
            <% {badge_class, badge_text} = portfolio_status_badge(@portfolio) %>
            <span class={"px-2 py-1 rounded-full text-xs font-medium #{badge_class}"}>
              <%= badge_text %>
            </span>
          </div>
        </div>

        <!-- Action Menu Icons -->
        <div class="flex items-center space-x-1">
          <!-- Video Intro Button -->
          <%= if has_intro_video?(@portfolio) do %>
            <button phx-click="show_video_intro" phx-value-portfolio_id={@portfolio.id}
                    class="p-2 text-green-600 hover:bg-green-50 rounded-lg transition-colors"
                    title="Edit Video Introduction">
              <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </button>
          <% else %>
            <button phx-click="show_video_intro" phx-value-portfolio_id={@portfolio.id}
                    class="p-2 text-orange-600 hover:bg-orange-50 rounded-lg transition-colors"
                    title="Add Video Introduction">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
            </button>
          <% end %>

          <!-- Visibility Toggle Button -->
          <button phx-click="toggle_discovery" phx-value-portfolio_id={@portfolio.id}
                  class={[
                    "p-2 rounded-lg transition-colors",
                    if(Map.get(@portfolio, :visibility) == :public,
                      do: "text-green-600 hover:bg-green-50",
                      else: "text-gray-600 hover:bg-gray-50")
                  ]}
                  title={
                    if(Map.get(@portfolio, :visibility) == :public,
                      do: "Portfolio is Public",
                      else: "Portfolio is Private")
                  }>
            <%= if Map.get(@portfolio, :visibility) == :public do %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            <% else %>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
              </svg>
            <% end %>
          </button>

          <!-- Copy Link Button -->
          <button phx-click="copy_portfolio_url" phx-value-portfolio_id={@portfolio.id}
                  class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                  title="Copy Portfolio Link">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </button>

          <!-- Feedback Button -->
          <button phx-click="request_feedback" phx-value-portfolio_id={@portfolio.id}
                  class="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors"
                  title="Request Feedback">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
            </svg>
          </button>

          <!-- Settings Button -->
          <button phx-click="show_portfolio_settings" phx-value-portfolio_id={@portfolio.id}
                  class="p-2 text-gray-600 hover:bg-gray-50 rounded-lg transition-colors"
                  title="Portfolio Settings">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
          </button>

          <!-- Delete Button -->
          <button phx-click="delete_portfolio" phx-value-id={@portfolio.id}
                  data-confirm="Are you sure you want to delete this portfolio? This action cannot be undone."
                  class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                  title="Delete Portfolio">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
            </svg>
          </button>
        </div>
      </div>

      <%= if Map.get(@portfolio, :description) do %>
        <p class="text-sm text-gray-600 line-clamp-2 mb-4">
          <%= Map.get(@portfolio, :description) %>
        </p>
      <% end %>

      <!-- Portfolio Stats -->
      <div class="flex items-center justify-between text-sm text-gray-500 mb-6">
        <div class="flex items-center space-x-4">
          <span class="flex items-center">
            <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>
            <%= get_portfolio_view_count(@portfolio) %>
          </span>

          <span class="flex items-center">
            <svg class="w-4 h-4 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
            <%= get_portfolio_section_count(@portfolio) %> sections
          </span>
        </div>

        <span class="text-xs text-gray-400">
          Updated <%= time_ago(Map.get(@portfolio, :updated_at)) %>
        </span>
      </div>

      <!-- Action Buttons -->
      <div class="flex space-x-3">
        <button phx-click="navigate_to_portfolio" phx-value-id={@portfolio.id}
                class="flex-1 bg-gradient-to-r from-blue-600 to-indigo-600 text-white py-3 px-4 rounded-xl hover:from-blue-700 hover:to-indigo-700 transition-all duration-200 text-sm font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
          Edit
        </button>

        <%= if Map.get(@portfolio, :visibility) == :public do %>
          <a href={"#{get_base_url()}/#{Map.get(@portfolio, :slug, @portfolio.id)}"} target="_blank"
            class="bg-green-600 text-white py-3 px-4 rounded-xl hover:bg-green-700 transition-all duration-200 text-sm font-semibold shadow-lg hover:shadow-xl transform hover:-translate-y-0.5">
            View Live
          </a>
        <% else %>
          <button phx-click="show_portfolio_overview" phx-value-portfolio_id={@portfolio.id}
                  class="bg-gray-100 text-gray-700 py-3 px-4 rounded-xl hover:bg-gray-200 transition-all duration-200 text-sm font-semibold shadow-sm hover:shadow-md">
            Share
          </button>
        <% end %>
      </div>
    </div>
    """
  end

  # Extract the create new portfolio card into its own function
  defp render_create_new_portfolio_card(assigns) do
    ~H"""
    <div class="group bg-gradient-to-br from-gray-50 to-white rounded-xl border-2 border-dashed border-gray-300 hover:border-blue-400 hover:from-blue-50 hover:to-indigo-50 transition-all duration-300 cursor-pointer transform hover:-translate-y-2"
        phx-click="show_create_modal">
      <div class="aspect-video flex items-center justify-center">
        <div class="text-center">
          <div class="w-20 h-20 bg-gradient-to-br from-blue-100 to-indigo-200 group-hover:from-blue-200 group-hover:to-indigo-300 rounded-2xl flex items-center justify-center mx-auto mb-4 transition-all duration-300 transform group-hover:scale-110">
            <svg class="w-10 h-10 text-blue-600 group-hover:text-blue-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
          </div>
          <p class="text-blue-600 group-hover:text-blue-700 font-semibold text-lg">Create New Portfolio</p>
          <p class="text-gray-500 text-sm mt-1">Start with a template or build from scratch</p>
        </div>
      </div>

      <div class="p-6">
        <h3 class="font-bold text-lg text-gray-900 mb-2">Start Fresh</h3>
        <p class="text-sm text-gray-600 leading-relaxed">Create a professional portfolio that showcases your unique skills and experience with our advanced templates and tools.</p>

        <div class="mt-4 flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <span class="w-2 h-2 bg-green-400 rounded-full"></span>
            <span class="text-xs text-gray-500">Templates available</span>
          </div>
          <svg class="w-4 h-4 text-gray-400 group-hover:text-blue-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7l5 5m0 0l-5 5m5-5H6"/>
          </svg>
        </div>
      </div>
    </div>
    """
  end

  defp render_locked_section_content(assigns, section) do
    upgrade_info = get_upgrade_prompt_for_section(assigns.hub_config, section)
    section_config = get_section_config(section)

    assigns = assign(assigns, :upgrade_info, upgrade_info)
    assigns = assign(assigns, :section_config, section_config)
    assigns = assign(assigns, :current_section, section)

    ~H"""
    <div class="max-w-4xl mx-auto">
      <!-- Locked Section Header -->
      <div class="text-center mb-8">
        <div class="inline-flex items-center justify-center w-20 h-20 bg-gradient-to-br from-yellow-100 to-orange-100 rounded-2xl mb-6">
          <div class="text-4xl"><%= get_section_icon(@current_section) %></div>
        </div>
        <h1 class="text-3xl font-bold text-gray-900 mb-4">
          <%= humanize_section_name(@current_section) %>
        </h1>
        <p class="text-xl text-gray-600 mb-6"><%= @section_config.description %></p>

        <!-- Upgrade Badge -->
        <div class="inline-flex items-center space-x-2 bg-yellow-50 border border-yellow-200 rounded-full px-4 py-2">
          <svg class="w-4 h-4 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
          </svg>
          <span class="text-sm font-medium text-yellow-800">
            Requires <%= String.capitalize(@upgrade_info.tier) %> Subscription
          </span>
        </div>
      </div>

      <!-- Feature Preview Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        <%= for feature <- @section_config.key_features do %>
          <div class="relative bg-white rounded-xl p-6 border border-gray-200 shadow-sm">
            <!-- Overlay for locked state -->
            <div class="absolute inset-0 bg-white bg-opacity-75 rounded-xl flex items-center justify-center z-10">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
              </svg>
            </div>

            <!-- Feature Content -->
            <div class="text-center">
              <div class="text-3xl mb-3"><%= feature.icon %></div>
              <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= feature.title %></h3>
              <p class="text-sm text-gray-600"><%= feature.description %></p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Benefits List -->
      <div class="bg-gradient-to-br from-purple-50 to-blue-50 rounded-2xl p-8 mb-8 border border-purple-200">
        <h2 class="text-2xl font-bold text-gray-900 mb-6 text-center">
          What You'll Get with <%= String.capitalize(@upgrade_info.tier) %>
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for benefit <- @section_config.benefits do %>
            <div class="flex items-start space-x-3">
              <div class="flex-shrink-0 w-6 h-6 bg-green-500 rounded-full flex items-center justify-center mt-0.5">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900"><%= benefit.title %></h4>
                <p class="text-sm text-gray-600 mt-1"><%= benefit.description %></p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Upgrade CTA -->
      <div class="text-center">
        <button phx-click={"upgrade_to_#{@upgrade_info.tier}"}
                class="inline-flex items-center px-8 py-4 bg-gradient-to-r from-purple-600 to-indigo-600 text-white font-semibold rounded-xl hover:from-purple-700 hover:to-indigo-700 transition-all transform hover:scale-105 shadow-lg hover:shadow-xl">
          <svg class="w-5 h-5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
          </svg>
          Upgrade to <%= String.capitalize(@upgrade_info.tier) %>
        </button>

        <p class="text-sm text-gray-500 mt-4">
          Start your free trial • Cancel anytime • Immediate access
        </p>
      </div>
    </div>
    """
  end

  defp get_section_config(section) do
    case section do
      "analytics" ->
        %{
          description: "Track portfolio performance with detailed visitor analytics and engagement metrics",
          key_features: [
            %{icon: "📈", title: "Real-time Analytics", description: "See who's viewing your portfolio as it happens"},
            %{icon: "🎯", title: "Visitor Insights", description: "Understand your audience demographics and behavior"},
            %{icon: "📊", title: "Performance Metrics", description: "Track views, engagement, and conversion rates"},
            %{icon: "🔍", title: "SEO Analytics", description: "Monitor search rankings and organic traffic"},
            %{icon: "📱", title: "Device Breakdown", description: "See how visitors access your portfolio"},
            %{icon: "🌍", title: "Geographic Data", description: "Discover where your viewers are located"}
          ],
          benefits: [
            %{title: "Detailed visitor tracking", description: "Know exactly who visits your portfolio and when"},
            %{title: "Engagement heatmaps", description: "See which sections get the most attention"},
            %{title: "Conversion tracking", description: "Measure how many visitors take action"},
            %{title: "Performance insights", description: "Optimize your portfolio based on data"},
            %{title: "SEO optimization", description: "Improve your search engine visibility"},
            %{title: "Export analytics data", description: "Download reports for presentations"}
          ]
        }

      "collaboration_hub" ->
        %{
          description: "Work together with other creators, get feedback, and manage collaborative projects",
          key_features: [
            %{icon: "👥", title: "Real-time Collaboration", description: "Edit portfolios together in real-time"},
            %{icon: "💬", title: "Feedback System", description: "Request and provide structured feedback"},
            %{icon: "🔄", title: "Version Control", description: "Track changes and revert when needed"},
            %{icon: "📝", title: "Comment System", description: "Leave contextual comments on sections"},
            %{icon: "🎯", title: "Project Management", description: "Organize collaborative projects"},
            %{icon: "📊", title: "Collaboration Analytics", description: "Track team productivity and engagement"}
          ],
          benefits: [
            %{title: "Invite unlimited collaborators", description: "Work with teammates, clients, and mentors"},
            %{title: "Real-time editing", description: "See changes as they happen"},
            %{title: "Professional feedback tools", description: "Get structured, actionable feedback"},
            %{title: "Project organization", description: "Manage multiple collaborative projects"},
            %{title: "Revision history", description: "Never lose work with automatic versioning"},
            %{title: "Team communication", description: "Built-in chat and discussion tools"}
          ]
        }

      "community_channels" ->
        %{
          description: "Connect with other creators, join specialized communities, and discover new opportunities",
          key_features: [
            %{icon: "🌟", title: "Creator Communities", description: "Join communities based on your expertise"},
            %{icon: "💼", title: "Professional Networking", description: "Connect with industry professionals"},
            %{icon: "🎓", title: "Learning Groups", description: "Participate in skill-building communities"},
            %{icon: "🚀", title: "Project Showcases", description: "Share work and get community feedback"},
            %{icon: "💡", title: "Opportunity Board", description: "Discover jobs, gigs, and collaborations"},
            %{icon: "🏆", title: "Community Challenges", description: "Participate in creative challenges"}
          ],
          benefits: [
            %{title: "Access to all communities", description: "Join unlimited specialized communities"},
            %{title: "Direct messaging", description: "Connect privately with other creators"},
            %{title: "Community moderation tools", description: "Create and manage your own communities"},
            %{title: "Priority support", description: "Get help from community moderators"},
            %{title: "Event notifications", description: "Stay updated on workshops and meetups"},
            %{title: "Networking tools", description: "Advanced search and connection features"}
          ]
        }

      "creator_lab" ->
        %{
          description: "Experiment with cutting-edge tools, AI features, and beta functionality before anyone else",
          key_features: [
            %{icon: "🤖", title: "AI Content Generation", description: "Generate portfolio content with AI assistance"},
            %{icon: "🎨", title: "Design Experiments", description: "Try new layouts and visual styles"},
            %{icon: "🔬", title: "Beta Features", description: "Early access to upcoming functionality"},
            %{icon: "⚡", title: "Automation Tools", description: "Automate repetitive portfolio tasks"},
            %{icon: "📱", title: "Mobile Experiments", description: "Test mobile-first features"},
            %{icon: "🌐", title: "Integration Testing", description: "Connect with new platforms and tools"}
          ],
          benefits: [
            %{title: "Early access to new features", description: "Try new tools weeks before public release"},
            %{title: "AI-powered assistance", description: "Get help writing, designing, and optimizing"},
            %{title: "Experimental workflows", description: "Test new ways to create and manage portfolios"},
            %{title: "Direct feedback channel", description: "Influence product development"},
            %{title: "Advanced automation", description: "Save time with smart automation tools"},
            %{title: "Priority feature requests", description: "Get your feature ideas implemented faster"}
          ]
        }

      "service_dashboard" ->
        %{
          description: "Manage your freelance business with booking, client management, and service offerings",
          key_features: [
            %{icon: "📅", title: "Booking Management", description: "Automated scheduling and calendar sync"},
            %{icon: "👥", title: "Client Management", description: "Track client relationships and history"},
            %{icon: "💰", title: "Invoice & Payments", description: "Generate invoices and process payments"},
            %{icon: "📊", title: "Business Analytics", description: "Track revenue and business metrics"},
            %{icon: "⚙️", title: "Service Packages", description: "Create and manage service offerings"},
            %{icon: "🔔", title: "Automated Workflows", description: "Streamline client communication"}
          ],
          benefits: [
            %{title: "Unlimited service offerings", description: "Create packages for all your services"},
            %{title: "Automated booking system", description: "Let clients book directly from your portfolio"},
            %{title: "Payment processing", description: "Accept payments through multiple methods"},
            %{title: "Client communication tools", description: "Built-in messaging and project updates"},
            %{title: "Revenue tracking", description: "Monitor your business performance"},
            %{title: "Contract management", description: "Digital contracts and agreements"}
          ]
        }

      "revenue_center" ->
        %{
          description: "Advanced revenue tracking, financial analytics, and monetization optimization tools",
          key_features: [
            %{icon: "💎", title: "Revenue Analytics", description: "Comprehensive financial reporting and insights"},
            %{icon: "📈", title: "Growth Tracking", description: "Monitor revenue trends and projections"},
            %{icon: "🎯", title: "Conversion Optimization", description: "Optimize portfolios for maximum revenue"},
            %{icon: "💳", title: "Payment Analytics", description: "Track payment methods and success rates"},
            %{icon: "🧾", title: "Tax Documentation", description: "Automated tax reporting and documents"},
            %{icon: "🔮", title: "Predictive Analytics", description: "AI-powered revenue forecasting"}
          ],
          benefits: [
            %{title: "Complete financial dashboard", description: "See all revenue streams in one place"},
            %{title: "Advanced tax features", description: "Automated tax calculations and reporting"},
            %{title: "Revenue optimization", description: "AI recommendations to increase earnings"},
            %{title: "Multiple income streams", description: "Track various monetization methods"},
            %{title: "Payout management", description: "Flexible payout schedules and methods"},
            %{title: "Financial forecasting", description: "Predict future earnings and plan ahead"}
          ]
        }

      _ ->
        %{
          description: "Advanced portfolio features and professional tools",
          key_features: [
            %{icon: "⭐", title: "Premium Features", description: "Access to advanced functionality"},
            %{icon: "🔧", title: "Professional Tools", description: "Tools designed for professionals"},
            %{icon: "📊", title: "Analytics", description: "Detailed insights and reporting"}
          ],
          benefits: [
            %{title: "Enhanced capabilities", description: "More powerful features for professionals"},
            %{title: "Priority support", description: "Get help when you need it most"}
          ]
        }
    end
  end

  defp portfolio_status_badge(portfolio) do
    case Map.get(portfolio, :visibility, :private) do
      :public ->
        {"bg-green-100 text-green-700", "Published"}
      :link_only ->
        {"bg-blue-100 text-blue-700", "Link Only"}
      :request_only ->
        {"bg-yellow-100 text-yellow-700", "Request Access"}
      :private ->
        {"bg-gray-100 text-gray-700", "Draft"}
      _ ->
        {"bg-gray-100 text-gray-700", "Draft"}
    end
  end

  defp has_intro_video?(portfolio) do
    case Ecto.assoc_loaded?(portfolio.sections) do
      true ->
        sections = portfolio.sections || []
        Enum.any?(sections, fn section ->
          section.section_type in [:media_showcase, "media_showcase", :video_intro, "video_intro"] &&
          has_video_content_in_section?(section)
        end)
      false ->
        # Try to load sections if not preloaded
        try do
          portfolio = Frestyl.Repo.preload(portfolio, :sections)
          has_intro_video?(portfolio)
        rescue
          _ -> false
        end
    end
  end

  defp has_video_content_in_section?(section) do
    content = section.content || %{}

    # Check various video content patterns
    cond do
      Map.has_key?(content, "video_url") and content["video_url"] != nil -> true
      Map.has_key?(content, "video_type") and content["video_type"] == "introduction" -> true
      Map.has_key?(content, "media_items") ->
        media_items = content["media_items"] || []
        Enum.any?(media_items, fn item ->
          case item do
            %{"type" => "video"} -> true
            %{"media_type" => "video"} -> true
            %{"file_type" => file_type} when is_binary(file_type) ->
              String.contains?(String.downcase(file_type), "video")
            _ -> false
          end
        end)
      true -> false
    end
  end

  # ============================================================================
  # ADDITIONAL EVENT HANDLERS FROM INDEX.EX
  # ============================================================================

  @impl true
  def handle_event("show_video_intro", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      {:noreply,
       socket
       |> assign(:show_video_intro_modal, true)
       |> assign(:current_portfolio_for_video, portfolio)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("toggle_discovery", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      new_visibility = case Map.get(portfolio, :visibility, :private) do
        :public -> :private
        _ -> :public
      end

      case Portfolios.update_portfolio(portfolio, %{visibility: new_visibility}) do
        {:ok, updated_portfolio} ->
          updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
            if p.id == updated_portfolio.id, do: updated_portfolio, else: p
          end)

          flash_message = if new_visibility == :public do
            "Portfolio is now discoverable on Frestyl"
          else
            "Portfolio is now private (link-only access)"
          end

          {:noreply,
           socket
           |> assign(:portfolios, updated_portfolios)
           |> put_flash(:info, flash_message)}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update visibility.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("delete_portfolio", %{"id" => id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(id)))

    if portfolio && portfolio.user_id == socket.assigns.current_user.id do
      case Portfolios.delete_portfolio(portfolio) do
        {:ok, _} ->
          # Refresh portfolios list after deletion
          updated_portfolios = Enum.reject(socket.assigns.portfolios, &(&1.id == portfolio.id))

          {:noreply,
           socket
           |> assign(:portfolios, updated_portfolios)
           |> put_flash(:info, "Portfolio deleted successfully.")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Unauthorized action.")}
    end
  end

  defp get_base_url do
    Application.get_env(:frestyl, :portfolio_base_url, "https://frestyl.app")
  end

  defp load_portfolio_settings(portfolio, user) do
    # Get account from socket assigns instead of user.account
    account = %{subscription_tier: Map.get(user, :subscription_tier, "free")}

    %{
      current_visibility: Map.get(portfolio, :visibility, :private),
      seo_enabled: Map.get(portfolio, :seo_enabled, false),
      password_protection: Map.get(portfolio, :password_protection, false),
      access_controls: get_portfolio_access_controls(portfolio),
      share_links: get_portfolio_share_links(portfolio),
      analytics_enabled: can_access_analytics?(user),
      social_integrations: get_available_social_integrations(user),
      privacy_settings: get_privacy_settings(portfolio),
      visibility_tiers: get_visibility_tier_options(user)
    }
  end

  defp get_visibility_tier_options(user) do
    base_tiers = [
      %{
        key: :private,
        name: "Private",
        description: "Only you can see this portfolio",
        icon: "🔒",
        features: ["Personal access only", "Hidden from search engines"],
        available: true
      },
      %{
        key: :unlisted,
        name: "Unlisted",
        description: "Only people with the link can view",
        icon: "🔗",
        features: ["Link sharing", "Not indexed by search engines"],
        available: true
      },
      %{
        key: :public,
        name: "Public",
        description: "Anyone can find and view your portfolio",
        icon: "🌍",
        features: ["Public visibility", "Search engine indexing", "Social media sharing"],
        available: true
      }
    ]

    if can_access_premium_features?(user) do
      premium_tier = %{
        key: :premium_public,
        name: "Premium Public",
        description: "Enhanced public visibility with advanced features",
        icon: "⭐",
        features: ["Priority search ranking", "Advanced analytics", "Custom domain support"],
        available: true
      }
      base_tiers ++ [premium_tier]
    else
      base_tiers
    end
  end

  defp get_portfolio_access_controls(portfolio) do
    %{
      password_protection: Map.get(portfolio, :password_protection, false),
      allowed_domains: Map.get(portfolio, :allowed_domains, []),
      expiry_date: Map.get(portfolio, :expiry_date),
      view_limit: Map.get(portfolio, :view_limit),
      ip_restrictions: Map.get(portfolio, :ip_restrictions, [])
    }
  end

  defp get_portfolio_share_links(_portfolio), do: []

  defp can_access_analytics?(user) do
    user.account.subscription_tier in ["professional", "creator", "creator_plus"]
  end

  defp get_available_social_integrations(user) do
    base_integrations = [
      %{id: "linkedin", name: "LinkedIn", enabled: true},
      %{id: "twitter", name: "Twitter/X", enabled: true}
    ]

    if can_access_premium_features?(user) do
      base_integrations ++ [
        %{id: "instagram", name: "Instagram", enabled: true},
        %{id: "tiktok", name: "TikTok", enabled: true}
      ]
    else
      base_integrations
    end
  end

  defp get_privacy_settings(portfolio) do
    %{
      hide_contact_info: Map.get(portfolio, :hide_contact_info, false),
      watermark_images: Map.get(portfolio, :watermark_images, false),
      disable_right_click: Map.get(portfolio, :disable_right_click, false),
      track_visitors: Map.get(portfolio, :track_visitors, true)
    }
  end

    @impl true
  def handle_event("create_story_portfolio", _params, socket) do
    # This will navigate to a story-focused creation flow
    # You can customize the route and parameters as needed
    {:noreply,
     socket
     |> assign(:show_create_modal, false)
     |> push_navigate(to: "/portfolios/new?method=story&flow=guided")}
  end

    @impl true
  def handle_event("toggle_export_menu", _params, socket) do
    current_state = Map.get(socket.assigns, :show_export_menu, false)
    {:noreply, assign(socket, :show_export_menu, !current_state)}
  end

  # Close export menu handler
  @impl true
  def handle_event("close_export_menu", _params, socket) do
    {:noreply, assign(socket, :show_export_menu, false)}
  end

  # Export analytics handlers (from the analytics section)
  @impl true
  def handle_event("export_analytics", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        {:noreply, put_flash(socket, :info, "Generating PDF analytics report...")}
      "csv" ->
        {:noreply, put_flash(socket, :info, "Exporting analytics to CSV...")}
      "excel" ->
        {:noreply, put_flash(socket, :info, "Exporting analytics to Excel...")}
      _ ->
        {:noreply, put_flash(socket, :error, "Unsupported export format")}
    end
  end

  # Media upload handler (referenced in quick_actions)
  @impl true
  def handle_event("show_media_upload", _params, socket) do
    {:noreply, put_flash(socket, :info, "Media upload feature coming soon!")}
  end

  # Switch section handler (referenced in quick_actions)
  @impl true
  def handle_event("switch_section", _params, socket) do
    {:noreply, assign(socket, :active_hub_section, "analytics")}
  end

  # Mobile menu toggle
  @impl true
  def handle_event("toggle_mobile_menu", _params, socket) do
    current_state = Map.get(socket.assigns, :show_mobile_menu, false)
    {:noreply, assign(socket, :show_mobile_menu, !current_state)}
  end

  # Navigation handlers
  @impl true
  def handle_event("navigate_to_studio", _params, socket) do
    {:noreply, push_navigate(socket, to: "/studio")}
  end

  @impl true
  def handle_event("browse_templates", _params, socket) do
    {:noreply, push_navigate(socket, to: "/portfolios/templates")}
  end

  @impl true
  def handle_event("access_story_lab", _params, socket) do
    {:noreply, push_navigate(socket, to: "/lab")}
  end


  defp can_access_premium_features?(user) do
    user.account.subscription_tier in ["creator", "creator_plus"]
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp update_portfolio_in_list(portfolios, updated_portfolio) do
    Enum.map(portfolios, fn p ->
      if p.id == updated_portfolio.id, do: updated_portfolio, else: p
    end)
  end

  defp visibility_badge_class(visibility) do
    case visibility do
      :private -> "bg-gray-100 text-gray-600"
      :unlisted -> "bg-yellow-100 text-yellow-600"
      :public -> "bg-green-100 text-green-600"
      :premium_public -> "bg-purple-100 text-purple-600"
      _ -> "bg-gray-100 text-gray-600"
    end
  end

  defp format_visibility(visibility) do
    case visibility do
      :private -> "Private"
      :unlisted -> "Unlisted"
      :public -> "Public"
      :premium_public -> "Premium"
      _ -> "Unknown"
    end
  end

  defp render_create_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 p-4"
         phx-click="close_create_modal">
      <div class="bg-white rounded-2xl max-w-2xl w-full shadow-2xl"
           phx-click-away="close_create_modal">

        <!-- Enhanced Modal Header -->
        <div class="bg-gradient-to-r from-purple-600 via-blue-600 to-indigo-600 px-8 py-6 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-2xl font-bold text-white">Create Your Portfolio</h2>
              <p class="text-purple-100 mt-1">Choose how you'd like to tell your professional story</p>
            </div>
            <button phx-click="close_create_modal"
                    class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Enhanced Modal Content -->
        <div class="p-8">
          <div class="grid grid-cols-1 gap-6">

            <!-- Story Creation Option (Primary) -->
            <button phx-click="create_story_portfolio"
                    class="group text-left p-6 border-2 border-purple-200 rounded-2xl hover:border-purple-400 hover:bg-gradient-to-br hover:from-purple-50 hover:to-blue-50 transition-all duration-300 transform hover:scale-105 hover:shadow-lg">
              <div class="flex items-start">
                <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-2xl flex items-center justify-center mr-6 group-hover:scale-110 transition-transform">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C20.168 18.477 18.582 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-purple-700 transition-colors">Tell Your Story</h3>
                  <p class="text-gray-600 mb-3 leading-relaxed">Create a narrative-driven portfolio that guides visitors through your professional journey with engaging storytelling elements.</p>
                  <div class="flex flex-wrap gap-2">
                    <span class="px-3 py-1 bg-purple-100 text-purple-700 text-xs font-medium rounded-full">Story Flow</span>
                    <span class="px-3 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full">Guided Experience</span>
                    <span class="px-3 py-1 bg-green-100 text-green-700 text-xs font-medium rounded-full">Engaging</span>
                  </div>
                </div>
              </div>
            </button>

            <!-- Professional Template Option -->
            <button phx-click="create_from_template"
                    class="group text-left p-6 border-2 border-blue-200 rounded-2xl hover:border-blue-400 hover:bg-gradient-to-br hover:from-blue-50 hover:to-indigo-50 transition-all duration-300 transform hover:scale-105 hover:shadow-lg">
              <div class="flex items-start">
                <div class="w-16 h-16 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-2xl flex items-center justify-center mr-6 group-hover:scale-110 transition-transform">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-blue-700 transition-colors">Professional Template</h3>
                  <p class="text-gray-600 mb-3 leading-relaxed">Start with a professionally designed template optimized for your industry and customize it to match your personal brand.</p>
                  <div class="flex flex-wrap gap-2">
                    <span class="px-3 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full">Quick Start</span>
                    <span class="px-3 py-1 bg-indigo-100 text-indigo-700 text-xs font-medium rounded-full">Professional</span>
                    <span class="px-3 py-1 bg-cyan-100 text-cyan-700 text-xs font-medium rounded-full">Industry-Focused</span>
                  </div>
                </div>
              </div>
            </button>

            <!-- Resume Upload Option -->
            <button phx-click="create_from_resume"
                    class="group text-left p-6 border-2 border-green-200 rounded-2xl hover:border-green-400 hover:bg-gradient-to-br hover:from-green-50 hover:to-emerald-50 transition-all duration-300 transform hover:scale-105 hover:shadow-lg">
              <div class="flex items-start">
                <div class="w-16 h-16 bg-gradient-to-br from-green-500 to-emerald-600 rounded-2xl flex items-center justify-center mr-6 group-hover:scale-110 transition-transform">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-green-700 transition-colors">Import from Resume</h3>
                  <p class="text-gray-600 mb-3 leading-relaxed">Upload your existing resume and let our AI transform it into an interactive portfolio with smart content organization.</p>
                  <div class="flex flex-wrap gap-2">
                    <span class="px-3 py-1 bg-green-100 text-green-700 text-xs font-medium rounded-full">AI-Powered</span>
                    <span class="px-3 py-1 bg-emerald-100 text-emerald-700 text-xs font-medium rounded-full">Auto-Import</span>
                    <span class="px-3 py-1 bg-teal-100 text-teal-700 text-xs font-medium rounded-full">Time-Saving</span>
                  </div>
                </div>
              </div>
            </button>

            <!-- Blank Canvas Option -->
            <button phx-click="create_blank"
                    class="group text-left p-6 border-2 border-gray-200 rounded-2xl hover:border-gray-400 hover:bg-gradient-to-br hover:from-gray-50 hover:to-slate-50 transition-all duration-300 transform hover:scale-105 hover:shadow-lg">
              <div class="flex items-start">
                <div class="w-16 h-16 bg-gradient-to-br from-gray-500 to-slate-600 rounded-2xl flex items-center justify-center mr-6 group-hover:scale-110 transition-transform">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                </div>
                <div class="flex-1">
                  <h3 class="text-xl font-bold text-gray-900 mb-2 group-hover:text-gray-700 transition-colors">Start from Scratch</h3>
                  <p class="text-gray-600 mb-3 leading-relaxed">Build a completely custom portfolio from the ground up with full creative control over every element and design choice.</p>
                  <div class="flex flex-wrap gap-2">
                    <span class="px-3 py-1 bg-gray-100 text-gray-700 text-xs font-medium rounded-full">Full Control</span>
                    <span class="px-3 py-1 bg-slate-100 text-slate-700 text-xs font-medium rounded-full">Custom Design</span>
                    <span class="px-3 py-1 bg-zinc-100 text-zinc-700 text-xs font-medium rounded-full">Advanced</span>
                  </div>
                </div>
              </div>
            </button>
          </div>

          <!-- Bottom Helper Text -->
          <div class="mt-8 text-center">
            <p class="text-sm text-gray-500">
              Don't worry, you can always change your approach later. Start with what feels right for you today.
            </p>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_video_intro_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div class="bg-white rounded-2xl max-w-2xl w-full shadow-2xl">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-green-600 to-emerald-600 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-bold text-white">Video Introduction</h2>
            <button phx-click="close_video_intro_modal"
                    class="text-white hover:text-gray-200 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6">
          <div class="text-center">
            <div class="w-16 h-16 bg-green-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">Video Introduction Setup</h3>
            <p class="text-gray-600 mb-6">Add a personal video introduction to make your portfolio more engaging</p>

            <div class="space-y-4">
              <button class="w-full bg-green-600 text-white py-3 px-4 rounded-lg hover:bg-green-700 transition-colors">
                Record New Video
              </button>
              <button class="w-full bg-gray-100 text-gray-700 py-3 px-4 rounded-lg hover:bg-gray-200 transition-colors">
                Upload Video File
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_share_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div class="bg-white rounded-2xl max-w-lg w-full shadow-2xl">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-blue-600 to-indigo-600 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-bold text-white">Share Portfolio</h2>
            <button phx-click="close_share_modal"
                    class="text-white hover:text-gray-200 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6">
          <%= if @selected_portfolio_for_share do %>
            <div class="space-y-4">
              <!-- Portfolio URL -->
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio URL</label>
                <div class="flex">
                  <input type="text"
                         value={"#{get_base_url()}/#{Map.get(@selected_portfolio_for_share, :slug, @selected_portfolio_for_share.id)}"}
                         readonly
                         class="flex-1 px-3 py-2 border border-gray-300 rounded-l-lg bg-gray-50 text-gray-700 text-sm">
                  <button phx-click="copy_portfolio_url" phx-value-portfolio_id={@selected_portfolio_for_share.id}
                          class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-r-lg hover:bg-blue-700 transition-colors">
                    Copy
                  </button>
                </div>
              </div>

              <!-- Social Sharing -->
              <div class="grid grid-cols-2 gap-3">
                <button phx-click="share_to_social" phx-value-platform="linkedin"
                        class="flex items-center justify-center px-4 py-2 bg-blue-700 text-white rounded-lg hover:bg-blue-800 transition-colors">
                  LinkedIn
                </button>
                <button phx-click="share_to_social" phx-value-platform="twitter"
                        class="flex items-center justify-center px-4 py-2 bg-black text-white rounded-lg hover:bg-gray-800 transition-colors">
                  Twitter
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_url_customization_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div class="bg-white rounded-2xl max-w-lg w-full shadow-2xl">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-purple-600 to-pink-600 px-6 py-4 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <h2 class="text-xl font-bold text-white">Customize URL</h2>
            <button phx-click="close_url_customization"
                    class="text-white hover:text-gray-200 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-6">
          <%= if @selected_portfolio_for_overview do %>
            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Custom URL</label>
                <div class="flex items-center">
                  <span class="text-sm text-gray-500 mr-2"><%= get_base_url() %>/</span>
                  <input type="text"
                         value={Map.get(@selected_portfolio_for_overview, :slug, "")}
                         phx-keyup="update_portfolio_url"
                         phx-value-custom_slug={Map.get(@selected_portfolio_for_overview, :slug, "")}
                         class="flex-1 px-3 py-2 border border-gray-300 rounded-lg text-sm">
                </div>
              </div>

              <div class="flex space-x-3">
                <button phx-click="close_url_customization"
                        class="flex-1 px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
                  Cancel
                </button>
                <button phx-click="update_portfolio_url"
                        class="flex-1 px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
                  Save
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_special_cards(assigns) do
    ~H"""
    <!-- Create New Card -->
    <div class="group bg-gradient-to-br from-gray-100 to-gray-200 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-2xl transform hover:-translate-y-1 border-2 border-dashed border-gray-300 hover:border-purple-300 cursor-pointer"
        phx-click="show_create_modal">
      <div class="p-8 text-center h-full flex flex-col justify-center">
        <div class="w-16 h-16 bg-gradient-to-br from-purple-100 to-indigo-100 rounded-2xl flex items-center justify-center mb-4 mx-auto group-hover:from-purple-200 group-hover:to-indigo-200 transition-all duration-300">
          <svg class="w-8 h-8 text-gray-500 group-hover:text-purple-600 transition-colors transform group-hover:scale-110 duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-gray-700 group-hover:text-purple-700 transition-colors mb-2">
          Create New Portfolio
        </h3>
        <p class="text-sm text-gray-500 group-hover:text-gray-600 transition-colors">
          Start fresh or use a template
        </p>
      </div>
    </div>
    """
  end

  defp render_empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="w-20 h-20 bg-gradient-to-br from-purple-100 to-indigo-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
        <svg class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
      </div>
      <h3 class="text-2xl font-bold text-gray-900 mb-4">Ready to create your first portfolio?</h3>
      <p class="text-gray-600 mb-8 max-w-md mx-auto">
        Build a professional portfolio that showcases your work and opens new opportunities.
      </p>
      <button phx-click="show_create_modal"
              class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Create Your First Portfolio
      </button>
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

  # ============================================================================
  # SETTINGS MODAL COMPONENT
  # ============================================================================

  defp render_settings_modal(assigns) do
    ~H"""
    <%= if @show_settings_modal && @selected_portfolio_for_settings do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 backdrop-blur-sm flex items-center justify-center z-50 p-4"
          phx-click="close_settings_modal">
        <div class="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden shadow-2xl"
            phx-click-away="close_settings_modal">

          <!-- Modal Header -->
          <div class="bg-gradient-to-r from-indigo-600 to-purple-600 px-8 py-6">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                </div>
                <div>
                  <h2 class="text-2xl font-bold text-white">Portfolio Settings</h2>
                  <p class="text-indigo-100"><%= @selected_portfolio_for_settings.title %></p>
                </div>
              </div>
              <button phx-click="close_settings_modal"
                      class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Modal Content -->
          <div class="p-8 overflow-y-auto max-h-[calc(90vh-120px)]">
            <.form for={%{}} phx-submit="save_portfolio_settings" class="space-y-8">

              <!-- Visibility & Privacy Settings -->
              <div class="bg-gray-50 rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-6 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                  Visibility & Privacy
                </h3>

                <!-- Visibility Setting -->
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-3">Portfolio Visibility</label>
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <%= for {visibility_key, visibility_info} <- get_visibility_options() do %>
                      <label class="relative">
                        <input type="radio"
                              name="visibility"
                              value={visibility_key}
                              checked={@selected_portfolio_for_settings.visibility == visibility_key}
                              class="sr-only peer">
                        <div class="border-2 border-gray-200 rounded-lg p-4 cursor-pointer peer-checked:border-indigo-500 peer-checked:bg-indigo-50 hover:border-gray-300 transition-all">
                          <div class="flex items-start">
                            <div class={["w-8 h-8 rounded-lg flex items-center justify-center mr-3", visibility_info.color]}>
                              <%= visibility_info.icon %>
                            </div>
                            <div class="flex-1">
                              <div class="font-medium text-gray-900"><%= visibility_info.title %></div>
                              <div class="text-sm text-gray-600 mt-1"><%= visibility_info.description %></div>
                            </div>
                          </div>
                        </div>
                      </label>
                    <% end %>
                  </div>
                </div>

                <!-- Privacy Controls -->
                <div class="space-y-4">
                  <h4 class="font-medium text-gray-900">Privacy Controls</h4>

                  <%= for {setting_key, setting_info} <- get_privacy_settings() do %>
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="font-medium text-gray-900"><%= setting_info.title %></div>
                        <div class="text-sm text-gray-600"><%= setting_info.description %></div>
                      </div>
                      <label class="relative inline-flex items-center cursor-pointer ml-4">
                        <input type="checkbox"
                              name={"privacy_settings[#{setting_key}]"}
                              checked={get_privacy_setting(@selected_portfolio_for_settings, setting_key)}
                              class="sr-only peer">
                        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-indigo-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
                      </label>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Sharing Settings -->
              <div class="bg-blue-50 rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-6 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
                  </svg>
                  Sharing & Social
                </h3>

                <!-- Portfolio URL -->
                <div class="mb-6">
                  <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio URL</label>
                  <div class="flex items-center space-x-3">
                    <input type="text"
                          readonly
                          value={"#{FrestylWeb.Endpoint.url()}/p/#{@selected_portfolio_for_settings.slug}"}
                          class="flex-1 bg-white border border-gray-300 rounded-lg px-3 py-2 text-sm">
                    <button type="button"
                            onclick="copyToClipboard('portfolio-settings-url')"
                            class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                      Copy
                    </button>
                  </div>
                </div>

                <!-- Social Media Integration -->
                <div class="space-y-4">
                  <h4 class="font-medium text-gray-900">Social Media Integration</h4>

                  <%= for {platform, platform_info} <- get_social_platforms() do %>
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <div class={["w-8 h-8 rounded-lg flex items-center justify-center mr-3", platform_info.color]}>
                          <%= platform_info.icon %>
                        </div>
                        <div>
                          <div class="font-medium text-gray-900"><%= platform_info.name %></div>
                          <div class="text-sm text-gray-600">Auto-share portfolio updates</div>
                        </div>
                      </div>
                      <label class="relative inline-flex items-center cursor-pointer">
                        <input type="checkbox"
                              name={"social_integration[#{platform}]"}
                              checked={get_social_integration(@selected_portfolio_for_settings, platform)}
                              class="sr-only peer">
                        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                      </label>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Access Control -->
              <div class="bg-yellow-50 rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-6 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                  </svg>
                  Access Control
                </h3>

                <!-- Password Protection -->
                <div class="mb-6">
                  <div class="flex items-center justify-between mb-3">
                    <div>
                      <div class="font-medium text-gray-900">Password Protection</div>
                      <div class="text-sm text-gray-600">Require a password to view this portfolio</div>
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input type="checkbox"
                            name="password_protected"
                            checked={has_password_protection?(@selected_portfolio_for_settings)}
                            class="sr-only peer"
                            phx-click="toggle_password_protection">
                      <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-yellow-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-yellow-600"></div>
                    </label>
                  </div>

                  <%= if has_password_protection?(@selected_portfolio_for_settings) do %>
                    <input type="password"
                          name="portfolio_password"
                          placeholder="Enter portfolio password"
                          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm">
                  <% end %>
                </div>

                <!-- Expiration Date -->
                <div class="mb-6">
                  <div class="flex items-center justify-between mb-3">
                    <div>
                      <div class="font-medium text-gray-900">Auto-Expiration</div>
                      <div class="text-sm text-gray-600">Automatically make portfolio private after a date</div>
                    </div>
                    <label class="relative inline-flex items-center cursor-pointer">
                      <input type="checkbox"
                            name="has_expiration"
                            checked={@selected_portfolio_for_settings.expires_at != nil}
                            class="sr-only peer"
                            phx-click="toggle_expiration">
                      <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-yellow-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-yellow-600"></div>
                    </label>
                  </div>

                  <%= if @selected_portfolio_for_settings.expires_at do %>
                    <input type="datetime-local"
                          name="expires_at"
                          value={format_datetime_for_input(@selected_portfolio_for_settings.expires_at)}
                          class="w-full border border-gray-300 rounded-lg px-3 py-2 text-sm">
                  <% end %>
                </div>
              </div>

              <!-- Analytics & Tracking -->
              <div class="bg-green-50 rounded-xl p-6">
                <h3 class="text-lg font-semibold text-gray-900 mb-6 flex items-center">
                  <svg class="w-5 h-5 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                  </svg>
                  Analytics & Tracking
                </h3>

                <div class="space-y-4">
                  <%= for {setting_key, setting_info} <- get_analytics_settings() do %>
                    <div class="flex items-center justify-between">
                      <div class="flex-1">
                        <div class="font-medium text-gray-900"><%= setting_info.title %></div>
                        <div class="text-sm text-gray-600"><%= setting_info.description %></div>
                      </div>
                      <label class="relative inline-flex items-center cursor-pointer ml-4">
                        <input type="checkbox"
                              name={"analytics_settings[#{setting_key}]"}
                              checked={get_analytics_setting(@selected_portfolio_for_settings, setting_key)}
                              class="sr-only peer">
                        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-green-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-600"></div>
                      </label>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Action Buttons -->
              <div class="flex items-center justify-end space-x-4 pt-6 border-t border-gray-200">
                <button type="button"
                        phx-click="close_settings_modal"
                        class="px-6 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                  Cancel
                </button>
                <button type="submit"
                        class="px-6 py-2 bg-indigo-600 text-white rounded-lg hover:bg-indigo-700 transition-colors">
                  Save Settings
                </button>
              </div>

            </.form>
          </div>
        </div>
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
  # NEW: NOTIFICATION TOAST COMPONENT
  # ============================================================================

  def notification_toast(assigns) do
    ~H"""
    <div class={[
      "fixed top-4 right-4 z-50 max-w-sm w-full bg-white rounded-lg shadow-lg border-l-4 p-4 transform transition-all duration-300",
      case @type do
        "success" -> "border-green-500"
        "error" -> "border-red-500"
        "warning" -> "border-yellow-500"
        "info" -> "border-blue-500"
        _ -> "border-gray-300"
      end,
      if(@show, do: "translate-x-0 opacity-100", else: "translate-x-full opacity-0")
    ]}>
      <div class="flex items-start">
        <div class={[
          "flex-shrink-0 w-5 h-5 mr-3 mt-0.5",
          case @type do
            "success" -> "text-green-500"
            "error" -> "text-red-500"
            "warning" -> "text-yellow-500"
            "info" -> "text-blue-500"
            _ -> "text-gray-500"
          end
        ]}>
          <%= case @type do %>
            <% "success" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
              </svg>
            <% "error" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            <% "warning" -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
              </svg>
            <% _ -> %>
              <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
          <% end %>
        </div>

        <div class="flex-1">
          <%= if @title do %>
            <p class="text-sm font-medium text-gray-900"><%= @title %></p>
          <% end %>
          <p class={[
            "text-sm",
            if(@title, do: "text-gray-600 mt-1", else: "text-gray-900")
          ]}>
            <%= @message %>
          </p>
        </div>

        <button
          phx-click="dismiss_notification"
          phx-value-id={@id}
          class="flex-shrink-0 ml-3 text-gray-400 hover:text-gray-600 transition-colors"
        >
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # NEW: PROGRESS BAR COMPONENT
  # ============================================================================

  def progress_bar(assigns) do
    ~H"""
    <div class="w-full">
      <%= if @label do %>
        <div class="flex justify-between items-center mb-2">
          <span class="text-sm font-medium text-gray-700"><%= @label %></span>
          <span class="text-sm text-gray-500"><%= @percentage %>%</span>
        </div>
      <% end %>
      <div class="w-full bg-gray-200 rounded-full h-2">
        <div
          class={[
            "h-2 rounded-full transition-all duration-300",
            case @color do
              "purple" -> "bg-purple-600"
              "blue" -> "bg-blue-600"
              "green" -> "bg-green-600"
              "yellow" -> "bg-yellow-600"
              "red" -> "bg-red-600"
              _ -> "bg-gray-600"
            end
          ]}
          style={"width: #{@percentage}%"}
        ></div>
      </div>
      <%= if @subtitle do %>
        <p class="text-xs text-gray-500 mt-1"><%= @subtitle %></p>
      <% end %>
    </div>
    """
  end

    # ============================================================================
  # NEW: STATS GRID COMPONENT
  # ============================================================================

  def stats_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      <%= for stat <- @stats do %>
        <div class="bg-white rounded-xl p-6 border border-gray-200 hover:shadow-lg transition-all duration-300">
          <div class="flex items-center">
            <div class={[
              "p-3 rounded-lg",
              case stat.color do
                "purple" -> "bg-purple-100"
                "blue" -> "bg-blue-100"
                "green" -> "bg-green-100"
                "yellow" -> "bg-yellow-100"
                "red" -> "bg-red-100"
                "indigo" -> "bg-indigo-100"
                "pink" -> "bg-pink-100"
                _ -> "bg-gray-100"
              end
            ]}>
              <%= if stat.icon do %>
                <span class="text-2xl"><%= stat.icon %></span>
              <% else %>
                <svg class={[
                  "w-6 h-6",
                  case stat.color do
                    "purple" -> "text-purple-600"
                    "blue" -> "text-blue-600"
                    "green" -> "text-green-600"
                    "yellow" -> "text-yellow-600"
                    "red" -> "text-red-600"
                    "indigo" -> "text-indigo-600"
                    "pink" -> "text-pink-600"
                    _ -> "text-gray-600"
                  end
                ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= raw(stat.svg_path) %>
                </svg>
              <% end %>
            </div>
            <div class="ml-4 flex-1">
              <p class="text-sm font-medium text-gray-600"><%= stat.label %></p>
              <div class="flex items-baseline">
                <p class="text-2xl font-bold text-gray-900"><%= stat.value %></p>
                <%= if stat.change do %>
                  <span class={[
                    "ml-2 text-sm font-medium",
                    if(stat.change >= 0, do: "text-green-600", else: "text-red-600")
                  ]}>
                    <%= if stat.change >= 0, do: "+#{stat.change}%", else: "#{stat.change}%" %>
                  </span>
                <% end %>
              </div>
              <%= if stat.subtitle do %>
                <p class="text-xs text-gray-500 mt-1"><%= stat.subtitle %></p>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def handle_event("switch_hub_section", %{"section" => section}, socket) do
    {:noreply, assign(socket, :active_hub_section, section)}
  end

  @impl true
  def handle_event("show_share_modal", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    {:noreply,
    socket
    |> assign(:show_share_modal, true)
    |> assign(:selected_portfolio_for_share, portfolio)}
  end

  @impl true
  def handle_event("close_share_modal", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_share_modal, false)
    |> assign(:selected_portfolio_for_share, nil)}
  end

  @impl true
  def handle_event("share_to_social", %{"platform" => platform}, socket) do
    portfolio = socket.assigns.selected_portfolio_for_share
    portfolio_url = "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"

    share_url = case platform do
      "linkedin" ->
        "https://www.linkedin.com/sharing/share-offsite/?url=#{URI.encode(portfolio_url)}"
      "twitter" ->
        text = "Check out my portfolio: #{portfolio.title}"
        "https://twitter.com/intent/tweet?url=#{URI.encode(portfolio_url)}&text=#{URI.encode(text)}"
      "facebook" ->
        "https://www.facebook.com/sharer/sharer.php?u=#{URI.encode(portfolio_url)}"
      "email" ->
        subject = "Check out my portfolio: #{portfolio.title}"
        body = "I'd like to share my portfolio with you: #{portfolio_url}"
        "mailto:?subject=#{URI.encode(subject)}&body=#{URI.encode(body)}"
      _ ->
        portfolio_url
    end

    {:noreply,
    socket
    |> push_event("open_url", %{url: share_url})
    |> put_flash(:info, "Opening #{String.capitalize(platform)} share dialog...")}
  end

  @impl true
  def handle_event("generate_embed_code", _params, socket) do
    portfolio = socket.assigns.selected_portfolio_for_share
    embed_code = """
    <iframe src="#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}?embed=true"
            width="100%" height="600" frameborder="0">
    </iframe>
    """

    {:noreply,
    socket
    |> assign(:embed_code, embed_code)
    |> put_flash(:info, "Embed code generated!")}
  end

  @impl true
  def handle_event("generate_qr_code", _params, socket) do
    portfolio = socket.assigns.selected_portfolio_for_share
    portfolio_url = "#{FrestylWeb.Endpoint.url()}/p/#{portfolio.slug}"

    # In a real implementation, you'd generate a QR code image
    # For now, we'll just show a success message
    {:noreply,
    socket
    |> put_flash(:info, "QR code generated! (Feature coming soon)")
    |> assign(:qr_code_url, portfolio_url)}
  end

  @impl true
  def handle_event("close_live_stream_modal", _params, socket) do
    {:noreply, assign(socket, :show_live_stream_modal, false)}
  end

  @impl true
  def handle_event("start_portfolio_presentation", _params, socket) do
    # Implementation for starting portfolio presentation stream
    {:noreply,
    socket
    |> assign(:stream_type, "presentation")
    |> put_flash(:info, "Starting portfolio presentation stream...")
    |> assign(:show_live_stream_modal, false)}
  end

  @impl true
  def handle_event("start_interview_stream", _params, socket) do
    # Implementation for starting interview stream
    {:noreply,
    socket
    |> assign(:stream_type, "interview")
    |> put_flash(:info, "Starting live interview stream...")
    |> assign(:show_live_stream_modal, false)}
  end

  @impl true
  def handle_event("create_blank_portfolio", _params, socket) do
    user = socket.assigns.current_user

    # Check portfolio creation limits
    limits = socket.assigns.limits
    current_count = length(socket.assigns.portfolios)

    case check_portfolio_creation_limit(limits, current_count) do
      :allowed ->
        # Create blank portfolio with default title
        portfolio_attrs = %{
          title: "New Portfolio #{current_count + 1}",
          description: "A new professional portfolio",
          theme: "minimalist",
          visibility: :link_only
        }

        case Frestyl.Portfolios.create_portfolio(user.id, portfolio_attrs) do
          {:ok, portfolio} ->
            {:noreply,
            socket
            |> assign(:show_create_modal, false)
            |> put_flash(:info, "Blank portfolio created successfully!")
            |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create portfolio")}
        end

      {:limit_reached, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def handle_event("start_ai_creation", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_create_modal, false)
    |> assign(:show_ai_creation_modal, true)}
  end

  @impl true
  def handle_event("clone_portfolio", _params, socket) do
    if length(socket.assigns.portfolios) > 0 do
      {:noreply,
      socket
      |> assign(:show_create_modal, false)
      |> assign(:show_clone_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "No portfolios available to clone")}
    end
  end

  @impl true
  def handle_event("import_from_linkedin", _params, socket) do
    # Check if user has LinkedIn connected
    # For now, show coming soon message
    {:noreply,
    socket
    |> assign(:show_create_modal, false)
    |> put_flash(:info, "LinkedIn import coming soon! Use resume import for now.")}
  end

  @impl true
  def handle_info({:portfolio_created, portfolio, message}, socket) do
    socket =
      socket
      |> assign(:show_create_modal, false)
      |> put_flash(:info, message)
      |> push_navigate(to: "/portfolios/#{portfolio.id}/edit")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:portfolio_creation_failed, error_message}, socket) do
    socket =
      socket
      |> put_flash(:error, "Failed to create portfolio: #{error_message}")

    {:noreply, socket}
  end

  # ============================================================================
  # ANALYTICS SECTION HANDLERS
  # ============================================================================

  @impl true
  def handle_event("export_analytics", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        {:noreply, put_flash(socket, :info, "Generating PDF analytics report...")}
      "csv" ->
        {:noreply, put_flash(socket, :info, "Exporting analytics to CSV...")}
      "excel" ->
        {:noreply, put_flash(socket, :info, "Exporting analytics to Excel...")}
      _ ->
        {:noreply, put_flash(socket, :error, "Unsupported export format")}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR ENHANCED FEATURES
  # ============================================================================

  defp check_portfolio_creation_limit(limits, current_count) do
    max_portfolios = case limits.max_portfolios do
      :unlimited -> :unlimited
      max when is_integer(max) -> max
    end

    case max_portfolios do
      :unlimited -> :allowed
      max when current_count >= max ->
        {:limit_reached, "You've reached your portfolio limit (#{max}). Upgrade to create more."}
      _ -> :allowed
    end
  end

  # ============================================================================
  # RENDER FUNCTIONS FOR NEW SECTIONS
  # ============================================================================

  defp render_analytics_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Analytics Header -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Portfolio Analytics</h2>
          <p class="text-gray-600 mt-1">Track performance and engagement across all your portfolios</p>
        </div>

        <div class="flex items-center space-x-3">
          <!-- Date Range Selector -->
          <select class="border border-gray-300 rounded-lg px-3 py-2 text-sm focus:ring-2 focus:ring-purple-500 focus:border-purple-500">
            <option>Last 7 days</option>
            <option>Last 30 days</option>
            <option>Last 3 months</option>
            <option>Last year</option>
          </select>

          <!-- Export Button -->
          <div class="relative" phx-click-away="close_export_menu">
            <button phx-click="toggle_export_menu"
                    class="inline-flex items-center px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-4-4m4 4l4-4m-4-4v4m0 0V4a2 2 0 00-2-2H8a2 2 0 00-2 2v2"/>
              </svg>
              Export
            </button>

            <%= if @show_export_menu do %>
              <div class="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg border border-gray-200 z-10">
                <div class="py-1">
                  <button phx-click="export_analytics" phx-value-format="pdf"
                          class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    Export as PDF
                  </button>
                  <button phx-click="export_analytics" phx-value-format="csv"
                          class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    Export as CSV
                  </button>
                  <button phx-click="export_analytics" phx-value-format="excel"
                          class="w-full text-left px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">
                    Export as Excel
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Key Metrics Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Views</p>
              <p class="text-3xl font-bold text-gray-900 mt-1"><%= @overview.total_visits %></p>
              <p class="text-sm text-green-600 mt-1">+12% from last month</p>
            </div>
            <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Shares</p>
              <p class="text-3xl font-bold text-gray-900 mt-1"><%= @overview.total_shares %></p>
              <p class="text-sm text-green-600 mt-1">+8% from last month</p>
            </div>
            <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Avg. Time on Page</p>
              <p class="text-3xl font-bold text-gray-900 mt-1">2m 34s</p>
              <p class="text-sm text-red-600 mt-1">-5% from last month</p>
            </div>
            <div class="w-12 h-12 bg-yellow-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="bg-white rounded-xl p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Conversion Rate</p>
              <p class="text-3xl font-bold text-gray-900 mt-1">4.2%</p>
              <p class="text-sm text-green-600 mt-1">+15% from last month</p>
            </div>
            <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
              </svg>
            </div>
          </div>
        </div>
      </div>

      <!-- Portfolio Performance Table -->
      <div class="bg-white rounded-xl border border-gray-200 overflow-hidden">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Portfolio Performance</h3>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Portfolio</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Views</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Shares</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Avg. Time</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Conversion</th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= for portfolio <- @portfolios do %>
                <% stats = Map.get(@portfolio_stats, portfolio.id, %{}) %>
                <tr class="hover:bg-gray-50">
                  <td class="px-6 py-4 whitespace-nowrap">
                    <div class="flex items-center">
                      <div class={[
                        "w-10 h-10 rounded-lg flex items-center justify-center mr-3",
                        case portfolio.theme do
                          "minimalist" -> "bg-gray-100 text-gray-600"
                          "creative" -> "bg-purple-100 text-purple-600"
                          "corporate" -> "bg-blue-100 text-blue-600"
                          "developer" -> "bg-green-100 text-green-600"
                          _ -> "bg-cyan-100 text-cyan-600"
                        end
                      ]}>
                        <%= String.first(portfolio.title) %>
                      </div>
                      <div>
                        <div class="text-sm font-medium text-gray-900"><%= portfolio.title %></div>
                        <div class="text-sm text-gray-500">/<%= portfolio.slug %></div>
                      </div>
                    </div>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Map.get(stats, :total_visits, 0) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Map.get(stats, :total_shares, 0) %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Map.get(stats, :avg_time, "0m 0s") %>
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                    <%= Map.get(stats, :conversion_rate, 0) %>%
                  </td>
                  <td class="px-6 py-4 whitespace-nowrap text-sm font-medium">
                    <.link href={"/portfolios/#{portfolio.id}/analytics"} class="text-purple-600 hover:text-purple-900">
                      View Details
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp render_collaboration_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Collaboration Header -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Collaboration Hub</h2>
          <p class="text-gray-600 mt-1">Work together on portfolios and manage feedback</p>
        </div>

        <button phx-click="invite_collaborator"
                class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
          Invite Collaborator
        </button>
      </div>

      <!-- Active Collaborations -->
      <div class="bg-white rounded-xl border border-gray-200 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Active Collaborations</h3>

        <%= if length(@active_collaborations) > 0 do %>
          <div class="space-y-4">
            <%= for collab <- @active_collaborations do %>
              <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                <div class="flex items-center space-x-3">
                  <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
                    <span class="text-sm font-medium text-blue-600">
                      <%= String.first(collab.collaborator_name) %>
                    </span>
                  </div>
                  <div>
                    <h4 class="font-medium text-gray-900"><%= collab.collaborator_name %></h4>
                    <p class="text-sm text-gray-600">Working on: <%= collab.portfolio_title %></p>
                  </div>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">
                    <%= collab.permission_level %>
                  </span>
                  <button class="text-gray-400 hover:text-gray-600">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-8">
            <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
            <h4 class="text-lg font-medium text-gray-900 mb-2">No active collaborations</h4>
            <p class="text-gray-600">Start collaborating by inviting others to work on your portfolios</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_live_streaming_section(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Live Streaming Header -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Live Streaming</h2>
          <p class="text-gray-600 mt-1">Stream your portfolio presentations in real-time</p>
        </div>

        <button phx-click="start_live_stream"
                class="inline-flex items-center px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors">
          <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
            <path d="M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z"/>
          </svg>
          Go Live
        </button>
      </div>

      <!-- Streaming Options -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Stream</h3>
          <p class="text-gray-600 mb-4">Start streaming immediately with default settings</p>
          <button phx-click="quick_stream"
                  class="w-full bg-red-600 text-white py-2 rounded-lg hover:bg-red-700 transition-colors">
            Start Quick Stream
          </button>
        </div>

        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Scheduled Stream</h3>
          <p class="text-gray-600 mb-4">Schedule a stream for later and send invitations</p>
          <button phx-click="schedule_stream"
                  class="w-full bg-blue-600 text-white py-2 rounded-lg hover:bg-blue-700 transition-colors">
            Schedule Stream
          </button>
        </div>
      </div>

      <!-- Recent Streams -->
      <div class="bg-white rounded-xl border border-gray-200 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Recent Streams</h3>
        <div class="text-center py-8">
          <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="currentColor" viewBox="0 0 24 24">
            <path d="M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z"/>
          </svg>
          <h4 class="text-lg font-medium text-gray-900 mb-2">No streams yet</h4>
          <p class="text-gray-600">Your streaming history will appear here</p>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # PORTFOLIO URL HELPER
  # ============================================================================

  defp portfolio_url(slug) do
    "#{FrestylWeb.Endpoint.url()}/p/#{slug}"
  end

  # ============================================================================
  # RENDER FUNCTIONS - Add these to the LiveView module
  # ============================================================================

  def humanize_section_name(section) do
    case section do
      "portfolio_studio" -> "Portfolio Studio"
      "analytics" -> "Analytics"
      "collaboration_hub" -> "Collaboration Hub"
      "community_channels" -> "Community Channels"
      "creator_lab" -> "Creator Lab"
      "calendar" -> "Calendar"
      "service_dashboard" -> "Service Dashboard"
      "revenue_center" -> "Revenue Center"
      _ -> String.replace(section, "_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
    end
  end

  # ============================================================================
  # ENHANCED PORTFOLIO CARD WITH ALL NEW FEATURES
  # ============================================================================

  defp render_enhanced_portfolio_card(assigns, portfolio) do
    stats = Map.get(assigns.portfolio_stats, portfolio.id, %{})

    assigns = assign(assigns, :portfolio, portfolio)
    assigns = assign(assigns, :stats, stats)

    ~H"""
    <!-- Portfolio Preview Header -->
    <div class="relative">
      <!-- Theme Color Stripe -->
      <div class={[
        "h-1",
        case @portfolio.theme do
          "minimalist" -> "bg-gradient-to-r from-gray-600 to-gray-800"
          "creative" -> "bg-gradient-to-r from-purple-600 to-pink-600"
          "corporate" -> "bg-gradient-to-r from-blue-600 to-indigo-600"
          "developer" -> "bg-gradient-to-r from-green-600 to-teal-600"
          _ -> "bg-gradient-to-r from-cyan-600 to-blue-600"
        end
      ]}></div>

      <!-- Portfolio Preview -->
      <div class={[
        "h-40 flex items-center justify-center relative overflow-hidden",
        case @portfolio.theme do
          "minimalist" -> "bg-gradient-to-br from-gray-100 to-gray-200"
          "creative" -> "bg-gradient-to-br from-purple-50 to-pink-50"
          "corporate" -> "bg-gradient-to-br from-blue-50 to-indigo-50"
          "developer" -> "bg-gradient-to-br from-green-50 to-teal-50"
          _ -> "bg-gradient-to-br from-cyan-50 to-blue-50"
        end
      ]}>

        <!-- Video Indicator (NEW) -->
        <%= if has_intro_video?(@portfolio) do %>
          <div class="absolute top-3 left-3 z-10">
            <div class="bg-white bg-opacity-90 backdrop-blur-sm rounded-full p-2 shadow-lg">
              <svg class="w-4 h-4 text-red-500" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </div>
          </div>
        <% end %>

        <!-- Visibility Status (NEW) -->
        <div class="absolute top-3 right-3 z-10">
          <div class={[
            "bg-white bg-opacity-90 backdrop-blur-sm rounded-full p-2 shadow-lg transition-colors",
            get_visibility_color(@portfolio.visibility)
          ]}>
            <%= get_visibility_icon(@portfolio.visibility) %>
          </div>
        </div>

        <!-- Portfolio Title Preview -->
        <div class="text-center px-4">
          <h3 class={[
            "text-xl font-bold mb-2",
            case @portfolio.theme do
              "minimalist" -> "text-gray-800"
              "creative" -> "text-purple-800"
              "corporate" -> "text-blue-800"
              "developer" -> "text-green-800"
              _ -> "text-cyan-800"
            end
          ]}>
            <%= @portfolio.title %>
          </h3>
          <p class="text-sm text-gray-600">/<%= @portfolio.slug %></p>
        </div>

        <!-- Quick Actions Overlay (appears on hover) -->
        <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-40 transition-all duration-300 flex items-center justify-center opacity-0 group-hover:opacity-100">
          <div class="flex space-x-2">
            <.link href={"/p/#{@portfolio.slug}"} target="_blank"
                  class="bg-white bg-opacity-90 backdrop-blur-sm rounded-full p-3 hover:bg-opacity-100 transition-all transform hover:scale-110">
              <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
            </.link>
            <.link href={"/portfolios/#{@portfolio.id}/edit"}
                  class="bg-white bg-opacity-90 backdrop-blur-sm rounded-full p-3 hover:bg-opacity-100 transition-all transform hover:scale-110">
              <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </.link>
          </div>
        </div>
      </div>
    </div>

    <!-- Portfolio Info -->
    <div class="p-5">
      <!-- Title and Description -->
      <div class="mb-4">
        <div class="flex items-start justify-between mb-2">
          <h3 class="font-semibold text-gray-900 group-hover:text-purple-600 transition-colors line-clamp-1">
            <%= @portfolio.title %>
          </h3>

          <!-- Visibility Toggle (NEW) -->
          <button phx-click="toggle_portfolio_visibility" phx-value-portfolio-id={@portfolio.id}
                  class="ml-2 p-1 rounded-full hover:bg-gray-100 transition-colors"
                  title={get_visibility_tooltip(@portfolio.visibility)}>
            <%= get_visibility_icon(@portfolio.visibility) %>
          </button>
        </div>

        <%= if @portfolio.description do %>
          <p class="text-sm text-gray-600 line-clamp-2"><%= @portfolio.description %></p>
        <% end %>
      </div>

      <!-- Enhanced Stats Row (NEW) -->
      <div class="grid grid-cols-3 gap-3 mb-4 p-3 bg-gray-50 rounded-lg">
        <div class="text-center">
          <div class="text-lg font-bold text-gray-900">
            <%= Map.get(@stats, :total_visits, 0) %>
          </div>
          <div class="text-xs text-gray-500">Views</div>
        </div>
        <div class="text-center">
          <div class="text-lg font-bold text-gray-900">
            <%= Map.get(@stats, :total_shares, 0) %>
          </div>
          <div class="text-xs text-gray-500">Shares</div>
        </div>
        <div class="text-center">
          <div class="text-lg font-bold text-gray-900">
            <%= Map.get(@stats, :engagement_rate, 0) %>%
          </div>
          <div class="text-xs text-gray-500">Engagement</div>
        </div>
      </div>

      <!-- Action Buttons Row (NEW) -->
      <div class="flex items-center justify-between">
        <div class="flex space-x-2">
          <!-- Share Button (NEW) -->
          <button phx-click="show_share_modal" phx-value-portfolio-id={@portfolio.id}
                  class="flex items-center px-3 py-1.5 text-xs font-medium bg-blue-100 text-blue-700 rounded-full hover:bg-blue-200 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
            </svg>
            Share
          </button>

          <!-- Feedback Button (NEW) -->
          <button phx-click="request_feedback" phx-value-portfolio-id={@portfolio.id}
                  class="flex items-center px-3 py-1.5 text-xs font-medium bg-green-100 text-green-700 rounded-full hover:bg-green-200 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
            </svg>
            Feedback
          </button>
        </div>

        <!-- Last Updated -->
        <div class="text-xs text-gray-500">
          Updated <%= time_ago(@portfolio.updated_at) %>
        </div>

        <!-- MORE MENU BUTTON -->
        <div class="relative">
          <button phx-click="toggle_more_menu" phx-value-portfolio-id={@portfolio.id}
                  class="p-2 text-gray-400 hover:text-gray-600 transition-colors rounded-lg hover:bg-gray-100">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
            </svg>
          </button>

          <!-- More Menu Dropdown -->
          <%= if assigns[:open_more_menu] == to_string(@portfolio.id) do %>
            <div class="absolute right-0 top-full mt-2 w-64 bg-white rounded-xl shadow-2xl border border-gray-100 z-50"
                phx-click-away="close_more_menu">

              <!-- Export Section -->
              <div class="p-2">
                <div class="px-3 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">Export</div>

                <!-- PDF Export -->
                <button phx-click="export_portfolio" phx-value-portfolio-id={@portfolio.id} phx-value-format="pdf"
                        class={[
                          "w-full flex items-center px-3 py-2 text-sm rounded-lg transition-colors",
                          if(can_export_pdf?(@current_user, @portfolio),
                            do: "text-gray-700 hover:bg-gray-50",
                            else: "text-gray-400 cursor-not-allowed")
                        ]}
                        disabled={not can_export_pdf?(@current_user, @portfolio)}>
                  <svg class="w-4 h-4 mr-3 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z"/>
                  </svg>
                  <div class="flex-1 text-left">
                    <div class="font-medium">Export as PDF</div>
                    <div class="text-xs text-gray-500">
                      <%= if can_export_pdf?(@current_user, @portfolio), do: "Professional print-ready format", else: "Requires premium subscription" %>
                    </div>
                  </div>
                  <%= if not can_export_pdf?(@current_user, @portfolio) do %>
                    <svg class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
                    </svg>
                  <% end %>
                </button>

                <!-- JSON Export -->
                <button phx-click="export_portfolio" phx-value-portfolio-id={@portfolio.id} phx-value-format="json"
                        class="w-full flex items-center px-3 py-2 text-sm text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                  <svg class="w-4 h-4 mr-3 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  <div class="flex-1 text-left">
                    <div class="font-medium">Export Data</div>
                    <div class="text-xs text-gray-500">JSON format for backup/import</div>
                  </div>
                </button>

                <!-- Analytics Export -->
                <%= if can_access_analytics?(@current_user, @portfolio) do %>
                  <button phx-click="export_portfolio" phx-value-portfolio-id={@portfolio.id} phx-value-format="analytics"
                          class="w-full flex items-center px-3 py-2 text-sm text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                    <svg class="w-4 h-4 mr-3 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                    </svg>
                    <div class="flex-1 text-left">
                      <div class="font-medium">Export Analytics</div>
                      <div class="text-xs text-gray-500">CSV format with visitor data</div>
                    </div>
                  </button>
                <% end %>
              </div>

              <!-- Divider -->
              <div class="border-t border-gray-100 my-2"></div>

              <!-- Actions Section -->
              <div class="p-2">
                <div class="px-3 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</div>

                <!-- Duplicate Portfolio -->
                <button phx-click="duplicate_portfolio" phx-value-portfolio-id={@portfolio.id}
                        class={[
                          "w-full flex items-center px-3 py-2 text-sm rounded-lg transition-colors",
                          if(can_duplicate_portfolio?(@current_user),
                            do: "text-gray-700 hover:bg-gray-50",
                            else: "text-gray-400 cursor-not-allowed")
                        ]}
                        disabled={not can_duplicate_portfolio?(@current_user)}>
                  <svg class="w-4 h-4 mr-3 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                  <div class="flex-1 text-left">
                    <div class="font-medium">Duplicate Portfolio</div>
                    <div class="text-xs text-gray-500">
                      <%= if can_duplicate_portfolio?(@current_user), do: "Create a copy to customize", else: "Requires premium or under limit" %>
                    </div>
                  </div>
                </button>

                <!-- Portfolio Settings -->
                <button phx-click="show_settings_modal" phx-value-portfolio-id={@portfolio.id}
                        class="w-full flex items-center px-3 py-2 text-sm text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
                  <svg class="w-4 h-4 mr-3 text-indigo-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                  <div class="flex-1 text-left">
                    <div class="font-medium">Portfolio Settings</div>
                    <div class="text-xs text-gray-500">Privacy, sharing, and advanced options</div>
                  </div>
                </button>
              </div>

              <!-- Divider -->
              <div class="border-t border-gray-100 my-2"></div>

              <!-- Danger Zone -->
              <div class="p-2">
                <div class="px-3 py-2 text-xs font-semibold text-red-500 uppercase tracking-wider">Danger Zone</div>

                <!-- Archive Portfolio -->
                <button phx-click="archive_portfolio" phx-value-portfolio-id={@portfolio.id}
                        class="w-full flex items-center px-3 py-2 text-sm text-red-600 rounded-lg hover:bg-red-50 transition-colors">
                  <svg class="w-4 h-4 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8l4 4m0 0l4-4m-4 4v11"/>
                  </svg>
                  <div class="flex-1 text-left">
                    <div class="font-medium">Archive Portfolio</div>
                    <div class="text-xs text-red-400">Hide from public view</div>
                  </div>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SPECIAL CARDS: LIVE STREAMING & CREATE NEW
  # ============================================================================

  defp render_live_streaming_card(assigns) do
    ~H"""
    <div class="group bg-gradient-to-br from-red-500 to-pink-600 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-2xl transform hover:-translate-y-1 text-white">
      <!-- Live Indicator -->
      <div class="p-5 relative">
        <div class="absolute top-3 right-3">
          <div class="bg-white bg-opacity-20 backdrop-blur-sm rounded-full px-2 py-1 flex items-center space-x-1">
            <div class="w-2 h-2 bg-red-300 rounded-full animate-pulse"></div>
            <span class="text-xs font-medium">LIVE</span>
          </div>
        </div>

        <!-- Icon -->
        <div class="w-16 h-16 bg-white bg-opacity-20 backdrop-blur-sm rounded-2xl flex items-center justify-center mb-4">
          <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 24 24">
            <path d="M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z"/>
          </svg>
        </div>

        <!-- Content -->
        <h3 class="text-xl font-bold mb-2">Live Streaming</h3>
        <p class="text-red-100 text-sm mb-4 opacity-90">
          Stream your portfolio presentation live to potential employers or clients
        </p>

        <!-- Action Button -->
        <button phx-click="start_live_stream"
                class="w-full bg-white bg-opacity-20 backdrop-blur-sm border border-white border-opacity-30 rounded-lg px-4 py-3 text-sm font-medium hover:bg-opacity-30 transition-all duration-200">
          Start Live Stream
        </button>

        <!-- Feature List -->
        <div class="mt-4 space-y-1">
          <div class="flex items-center text-xs text-red-100 opacity-90">
            <svg class="w-3 h-3 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            HD video quality
          </div>
          <div class="flex items-center text-xs text-red-100 opacity-90">
            <svg class="w-3 h-3 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            Real-time chat
          </div>
          <div class="flex items-center text-xs text-red-100 opacity-90">
            <svg class="w-3 h-3 mr-2" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            Screen sharing
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_create_new_card(assigns) do
    ~H"""
    <div class="group bg-gradient-to-br from-gray-100 to-gray-200 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-2xl transform hover:-translate-y-1 border-2 border-dashed border-gray-300 hover:border-purple-300 cursor-pointer"
         phx-click="show_create_modal">

      <div class="p-8 text-center h-full flex flex-col justify-center">
        <!-- Animated Plus Icon -->
        <div class="w-16 h-16 bg-gradient-to-br from-purple-100 to-indigo-100 rounded-2xl flex items-center justify-center mb-4 mx-auto group-hover:from-purple-200 group-hover:to-indigo-200 transition-all duration-300">
          <svg class="w-8 h-8 text-gray-500 group-hover:text-purple-600 transition-colors transform group-hover:scale-110 duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
          </svg>
        </div>

        <!-- Content -->
        <h3 class="text-lg font-semibold text-gray-700 group-hover:text-purple-700 transition-colors mb-2">
          Create New Portfolio
        </h3>
        <p class="text-sm text-gray-500 group-hover:text-gray-600 transition-colors mb-4">
          Start fresh or use a template to build your next portfolio
        </p>

        <!-- Quick Options -->
        <div class="space-y-2 text-xs">
          <div class="flex items-center justify-center text-gray-400 group-hover:text-gray-500 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            Professional templates
          </div>
          <div class="flex items-center justify-center text-gray-400 group-hover:text-gray-500 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            AI-powered assistance
          </div>
          <div class="flex items-center justify-center text-gray-400 group-hover:text-gray-500 transition-colors">
            <svg class="w-3 h-3 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
            </svg>
            Ready in minutes
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EMPTY STATE WITH SPECIAL CARDS
  # ============================================================================

  defp render_empty_state_with_cards(assigns) do
    ~H"""
    <div class="text-center py-12">
      <!-- Main Empty State -->
      <div class="mb-12">
        <div class="w-20 h-20 bg-gradient-to-br from-purple-100 to-indigo-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <svg class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
        </div>
        <h3 class="text-2xl font-bold text-gray-900 mb-4">Ready to create your first portfolio?</h3>
        <p class="text-gray-600 mb-8 max-w-md mx-auto">
          Build a professional portfolio that showcases your work, tells your story, and opens new opportunities.
        </p>
      </div>

      <!-- Action Cards -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 max-w-4xl mx-auto">
        <!-- Create New Card -->
        <%= render_create_new_card(assigns) %>

        <!-- Import Resume Card -->
        <div class="group bg-gradient-to-br from-green-50 to-emerald-50 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-xl transform hover:-translate-y-1 border border-green-200 cursor-pointer"
             phx-click="show_resume_import">
          <div class="p-6 text-center">
            <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center mb-4 mx-auto">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800 mb-2">Import Resume</h3>
            <p class="text-sm text-gray-600">Upload your resume to get started quickly</p>
          </div>
        </div>

        <!-- Browse Templates Card -->
        <div class="group bg-gradient-to-br from-blue-50 to-cyan-50 rounded-xl overflow-hidden transition-all duration-300 hover:shadow-xl transform hover:-translate-y-1 border border-blue-200 cursor-pointer"
             phx-click="browse_templates">
          <div class="p-6 text-center">
            <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center mb-4 mx-auto">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"/>
              </svg>
            </div>
            <h3 class="font-semibold text-gray-800 mb-2">Browse Templates</h3>
            <p class="text-sm text-gray-600">Choose from professional designs</p>
          </div>
        </div>
      </div>
    </div>
    """
  end



  # ============================================================================
  # HELPER FUNCTIONS FOR NEW FEATURES
  # ============================================================================

  defp has_intro_video?(portfolio) do
    # Check if portfolio has an intro video section
    case portfolio.sections do
      %Ecto.Association.NotLoaded{} ->
        # Load sections if not preloaded
        portfolio = Frestyl.Repo.preload(portfolio, :sections)
        Enum.any?(portfolio.sections, &(&1.section_type == "video_intro"))
      sections when is_list(sections) ->
        Enum.any?(sections, &(&1.section_type == "video_intro"))
      _ ->
        false
    end
  end

  defp get_video_intro_status(portfolio) do
    case Ecto.assoc_loaded?(portfolio.sections) do
      true ->
        sections = portfolio.sections || []
        video_section = Enum.find(sections, fn section ->
          section.section_type in [:video_intro, "video_intro", :media_showcase, "media_showcase"] and
          has_video_content?(section)
        end)

        if video_section, do: :has_video, else: :no_video
      false ->
        # Need to load sections to check
        :unknown
    end
  end

  defp has_video_content?(section) do
    content = section.content || %{}

    # Check various video content patterns
    cond do
      Map.has_key?(content, "video_url") and content["video_url"] != nil -> true
      Map.has_key?(content, "video_type") and content["video_type"] == "introduction" -> true
      Map.has_key?(content, "media_items") ->
        media_items = content["media_items"] || []
        Enum.any?(media_items, fn item ->
          case item do
            %{"type" => "video"} -> true
            %{"media_type" => "video"} -> true
            %{"file_type" => file_type} when is_binary(file_type) ->
              String.contains?(String.downcase(file_type), "video")
            _ -> false
          end
        end)
      true -> false
    end
  end

  defp get_portfolio_view_count(portfolio) do
    # Replace with actual view count logic
    Map.get(portfolio, :view_count, 0)
  end

  defp get_portfolio_section_count(portfolio) do
    case Ecto.assoc_loaded?(portfolio.sections) do
      true -> length(portfolio.sections || [])
      false -> 0
    end
  end

  defp get_visibility_color(visibility) do
    case visibility do
      :public -> "text-green-600"
      :link_only -> "text-blue-600"
      :request_only -> "text-yellow-600"
      :private -> "text-red-600"
    end
  end

  defp get_visibility_icon(visibility) do
    case visibility do
      :public ->
        assigns = %{}
        ~H"""
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3.055 11H5a2 2 0 012 2v1a2 2 0 002 2 2 2 0 012 2v2.945M8 3.935V5.5A2.5 2.5 0 0010.5 8h.5a2 2 0 012 2 2 2 0 104 0 2 2 0 012-2h1.064M15 20.488V18a2 2 0 012-2h3.064M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        """
      :link_only ->
        assigns = %{}
        ~H"""
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """
      :request_only ->
        assigns = %{}
        ~H"""
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
        </svg>
        """
      :private ->
        assigns = %{}
        ~H"""
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
        </svg>
        """
    end
  end

  defp get_visibility_tooltip(visibility) do
    case visibility do
      :public -> "Public - Discoverable by everyone"
      :link_only -> "Link only - Accessible via direct URL"
      :request_only -> "Request access - Requires approval"
      :private -> "Private - Only you can see this"
    end
  end

  defp can_use_live_streaming?(user, account) do
    # Check if user's account tier supports live streaming
    case account.subscription_tier do
      tier when tier in [:professional, :enterprise] -> true
      _ -> false
    end
  end

  defp time_ago(datetime) when is_nil(datetime), do: "unknown"

  defp time_ago(%NaiveDateTime{} = naive_datetime) do
    # Convert NaiveDateTime to DateTime (assume UTC)
    case DateTime.from_naive(naive_datetime, "Etc/UTC") do
      {:ok, utc_datetime} -> time_ago(utc_datetime)
      {:error, _} -> "unknown"
    end
  end

  defp time_ago(%DateTime{} = datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :day) do
      0 -> "today"
      1 -> "1 day ago"
      days when days < 7 -> "#{days} days ago"
      days when days < 30 -> "#{div(days, 7)} weeks ago"
      days -> "#{div(days, 30)} months ago"
    end
  rescue
    _ -> "unknown"
  end

  defp time_ago(_), do: "unknown"



  # ============================================================================
  # EVENT HANDLERS FOR NEW FEATURES
  # ============================================================================

  @impl true
  def handle_event("set_view_mode", %{"mode" => mode}, socket) when mode in ["grid", "list"] do
    {:noreply, assign(socket, :view_mode, mode)}
  end

  @impl true
  def handle_event("toggle_portfolio_visibility", %{"portfolio-id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    new_visibility = case portfolio.visibility do
      :private -> :link_only
      :link_only -> :public
      :public -> :request_only
      :request_only -> :private
    end

    case Frestyl.Portfolios.update_portfolio_visibility(portfolio.id, new_visibility, socket.assigns.current_user.id) do
      {:ok, updated_portfolio} ->
        updated_portfolios = Enum.map(socket.assigns.portfolios, fn p ->
          if p.id == updated_portfolio.id, do: updated_portfolio, else: p
        end)

        {:noreply,
         socket
         |> assign(:portfolios, updated_portfolios)
         |> put_flash(:info, "Portfolio visibility updated to #{humanize_visibility(new_visibility)}")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update portfolio visibility")}
    end
  end

  @impl true
  def handle_event("request_feedback", %{"portfolio-id" => portfolio_id}, socket) do
    # Implementation for requesting feedback
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    # Create feedback request logic here
    # For now, just show a success message
    {:noreply,
     socket
     |> put_flash(:info, "Feedback request sent for '#{portfolio.title}'")}
  end

  @impl true
  def handle_event("start_live_stream", _params, socket) do
    # Implementation for starting live stream
    {:noreply,
     socket
     |> assign(:show_live_stream_modal, true)}
  end

  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_resume_import_modal, true)}
  end

  @impl true
  def handle_event("browse_templates", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_template_browser, true)}
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp humanize_visibility(visibility) do
    case visibility do
      :public -> "Public"
      :link_only -> "Link Only"
      :request_only -> "Request Access"
      :private -> "Private"
    end
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
              <span>For: <span>For: <%= FrestylWeb.PortfolioHubLive.Helpers.get_portfolio_title(suggestion.portfolio_id, @portfolios) %></span></span>
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
  # BROADCAST EVENT HANDLERS (NEW)
  # ============================================================================

  @impl true
  def handle_event("show_broadcast_modal", _params, socket) do
    if can_user_go_live?(socket.assigns.user, socket.assigns.account) do
      {:noreply,
       socket
       |> assign(:show_broadcast_modal, true)
       |> assign(:broadcast_creation_step, :setup)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Broadcast limit reached or feature not available")}
    end
  end

  @impl true
  def handle_event("close_broadcast_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_broadcast_modal, false)
     |> assign(:selected_portfolio_for_broadcast, nil)}
  end

  @impl true
  def handle_event("create_portfolio_showcase", %{"portfolio_id" => portfolio_id}, socket) do
    portfolio = Enum.find(socket.assigns.portfolios, &(&1.id == String.to_integer(portfolio_id)))

    if portfolio do
      {:noreply,
       socket
       |> assign(:selected_portfolio_for_broadcast, portfolio)
       |> assign(:show_broadcast_modal, true)}
    else
      {:noreply, put_flash(socket, :error, "Portfolio not found")}
    end
  end

  @impl true
  def handle_event("create_broadcast", %{"broadcast" => broadcast_params}, socket) do
    user = socket.assigns.user
    portfolio = socket.assigns.selected_portfolio_for_broadcast

    broadcast_attrs = broadcast_params
    |> Map.put("creator_id", user.id)
    |> Map.put("host_id", user.id)
    |> Map.put("session_type", "portfolio_broadcast")
    |> Map.put("context", %{
      portfolio_id: portfolio && portfolio.id,
      broadcast_mode: if(portfolio, do: "portfolio_showcase", else: "general"),
      allow_portfolio_sharing: portfolio != nil
    })
    |> add_broadcast_settings(socket.assigns.account)

    case Sessions.create_broadcast(broadcast_attrs) do
      {:ok, broadcast} ->
        Features.FeatureGate.track_feature_usage(socket.assigns.account, :live_broadcast, 1)
        updated_broadcast_data = load_broadcast_data(user, socket.assigns.account)

        {:noreply,
         socket
         |> assign(:broadcast_data, updated_broadcast_data)
         |> assign(:show_broadcast_modal, false)
         |> put_flash(:info, "Broadcast created successfully!")
         |> push_navigate(to: ~p"/channels/broadcasts/#{broadcast.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create broadcast")}
    end
  end

  @impl true
  def handle_event("join_live_broadcast", %{"broadcast_id" => broadcast_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/channels/broadcasts/#{broadcast_id}/live")}
  end

  @impl true
  def handle_event("manage_broadcast", %{"broadcast_id" => broadcast_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/channels/broadcasts/#{broadcast_id}/manage")}
  end

  @impl true
  def handle_event("view_recording", %{"recording_id" => recording_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/recordings/#{recording_id}")}
  end

  defp add_broadcast_settings(broadcast_attrs, account) do
    limits = get_broadcast_limits(account)

    broadcast_attrs
    |> Map.put("max_viewers", limits.max_viewers_per_broadcast)
    |> Map.put("max_duration_minutes", limits.max_duration_minutes)
    |> Map.put("recording_enabled", limits.recording_enabled)
  end


    # ============================================================================
  # CALENDAR DATA LOADING
  # ============================================================================

  defp load_calendar_data(user, account) do
    tier = TierManager.get_user_tier(user)
    permissions = get_calendar_permissions(tier)

    # Get upcoming events (next 7 days)
    {start_date, end_date} = {Date.utc_today(), Date.add(Date.utc_today(), 7)}
    upcoming_events = Calendar.get_user_visible_events(user, account,
      start_date: start_date,
      end_date: end_date
    )

    # Get today's events
    today_events = Calendar.get_user_visible_events(user, account,
      start_date: Date.utc_today(),
      end_date: Date.utc_today()
    )

    # Get calendar integrations
    integrations = Calendar.get_user_integrations(user.id)

    # Get quick stats
    stats = get_calendar_stats(upcoming_events, permissions)

    %{
      permissions: permissions,
      upcoming_events: upcoming_events,
      today_events: today_events,
      integrations: integrations,
      stats: stats,
      sync_status: get_sync_status(integrations)
    }
  end

  defp get_calendar_permissions(tier) do
    case tier do
      "personal" ->
        %{
          can_create: false,
          can_integrate: false,
          can_see_analytics: false,
          tier_name: "Personal",
          upgrade_message: "Upgrade to Creator to create and manage calendar events"
        }

      "creator" ->
        %{
          can_create: true,
          can_integrate: true,
          can_see_analytics: true,
          tier_name: "Creator",
          upgrade_message: nil
        }

      tier when tier in ["professional", "enterprise"] ->
        %{
          can_create: true,
          can_integrate: true,
          can_see_analytics: true,
          tier_name: String.capitalize(tier),
          upgrade_message: nil
        }
    end
  end

  defp get_calendar_stats(events, permissions) do
    if permissions.can_see_analytics do
      %{
        total_upcoming: length(events),
        bookings_count: Enum.count(events, &(&1.event_type == "service_booking")),
        broadcasts_count: Enum.count(events, &(&1.event_type == "broadcast")),
        channel_events_count: Enum.count(events, &(&1.event_type == "channel_event"))
      }
    else
      %{
        total_upcoming: length(events),
        visible_note: "Limited to channel events you belong to"
      }
    end
  end

  defp get_sync_status(integrations) do
    if length(integrations) == 0 do
      %{status: :no_integrations, message: "No calendar integrations"}
    else
      synced_count = Enum.count(integrations, &(&1.sync_enabled))
      failed_count = Enum.count(integrations, fn i ->
        length(i.sync_errors || []) > 0
      end)

      cond do
        failed_count > 0 ->
          %{status: :partial_sync, message: "#{failed_count} integration(s) need attention"}
        synced_count == length(integrations) ->
          %{status: :synced, message: "All calendars synced"}
        true ->
          %{status: :partial_sync, message: "#{synced_count}/#{length(integrations)} calendars synced"}
      end
    end
  end

  defp get_today_events(user, account) do
    Calendar.get_user_visible_events(user, account,
      start_date: Date.utc_today(),
      end_date: Date.utc_today()
    )
  end

  # ============================================================================
  # SAFE DATA LOADING FUNCTIONS FOR BROADCASTS (NEW)
  # ============================================================================

  defp safe_get_active_broadcasts(user_id) do
    try do
      Sessions.list_user_active_broadcasts(user_id)
    rescue
      _ -> []
    end
  end

  defp safe_get_scheduled_broadcasts(user_id) do
    try do
      Sessions.list_user_scheduled_broadcasts(user_id, days_ahead: 30)
    rescue
      _ -> []
    end
  end

  defp safe_get_recent_broadcasts(user_id) do
    try do
      Sessions.list_user_recent_broadcasts(user_id, days_back: 7)
    rescue
      _ -> []
    end
  end

  defp safe_get_broadcast_analytics(user_id) do
    try do
      Analytics.get_user_broadcast_analytics(user_id)
    rescue
      _ -> %{
        total_broadcasts: 0,
        total_viewers: 0,
        total_watch_time_hours: 0,
        average_duration_minutes: 0,
        engagement_rate: 0,
        recorded_broadcasts_count: 0
      }
    end
  end

  defp safe_get_channel_broadcast_activity(user_id) do
    try do
      Analytics.get_channel_broadcast_activity(user_id)
    rescue
      _ -> %{total_channel_broadcasts: 0, avg_channel_viewers: 0}
    end
  end

  defp safe_get_portfolio_broadcast_activity(user_id) do
    try do
      Analytics.get_portfolio_broadcast_activity(user_id)
    rescue
      _ -> %{total_portfolio_showcases: 0, avg_showcase_engagement: 0}
    end
  end

  defp safe_get_monetization_insights(user_id) do
    try do
      Revenue.get_broadcast_monetization_insights(user_id)
    rescue
      _ -> %{potential_revenue: 0, recorded_content_value: 0}
    end
  end

  defp safe_get_recording_library(user_id) do
    try do
      Sessions.list_user_broadcast_recordings(user_id)
    rescue
      _ -> []
    end
  end

  defp get_broadcast_usage(user_id) do
    try do
      Sessions.get_user_broadcast_usage(user_id)
    rescue
      _ -> %{concurrent_broadcasts: 0, monthly_broadcasts: 0}
    end
  end

  # ============================================================================
  # BROADCAST DATA LOADING (NEW)
  # ============================================================================

  defp load_broadcast_data(user, account) do
    if Features.FeatureGate.can_access_feature?(account, :live_broadcast) do
      %{
        active_broadcasts: safe_get_active_broadcasts(user.id),
        scheduled_broadcasts: safe_get_scheduled_broadcasts(user.id),
        recent_broadcasts: safe_get_recent_broadcasts(user.id),
        broadcast_analytics: safe_get_broadcast_analytics(user.id),
        channel_activity: safe_get_channel_broadcast_activity(user.id),
        portfolio_activity: safe_get_portfolio_broadcast_activity(user.id),
        monetization_potential: safe_get_monetization_insights(user.id),
        recording_library: safe_get_recording_library(user.id),
        broadcast_limits: get_broadcast_limits(account),
        current_usage: get_broadcast_usage(user.id),
        can_go_live: can_user_go_live?(user, account),
        live_quota_remaining: get_live_quota_remaining(user.id, account)
      }
    else
      %{
        active_broadcasts: [],
        scheduled_broadcasts: [],
        recent_broadcasts: [],
        broadcast_analytics: %{},
        channel_activity: %{},
        portfolio_activity: %{},
        monetization_potential: %{},
        recording_library: [],
        broadcast_limits: %{},
        current_usage: %{},
        can_go_live: false,
        live_quota_remaining: 0,
        upgrade_prompt: true,
        tier_required: "creator"
      }
    end
  end

  defp get_broadcast_limits(account) do
    case account.subscription_tier do
      "creator" ->
        %{
          max_concurrent_broadcasts: 1,
          max_viewers_per_broadcast: 25,
          max_duration_minutes: 60,
          recording_enabled: true,
          recording_auto_archive: true,
          analytics_retention_days: 30,
          monetization_enabled: false
        }
      "professional" ->
        %{
          max_concurrent_broadcasts: 1,
          max_viewers_per_broadcast: 100,
          max_duration_minutes: 180,
          recording_enabled: true,
          recording_auto_archive: true,
          analytics_retention_days: 90,
          monetization_enabled: true
        }
      "enterprise" ->
        %{
          max_concurrent_broadcasts: 3,
          max_viewers_per_broadcast: -1,
          max_duration_minutes: -1,
          recording_enabled: true,
          recording_auto_archive: true,
          analytics_retention_days: 365,
          monetization_enabled: true
        }
      _ ->
        %{
          max_concurrent_broadcasts: 0,
          max_viewers_per_broadcast: 0,
          max_duration_minutes: 0,
          recording_enabled: false,
          recording_auto_archive: false,
          analytics_retention_days: 0,
          monetization_enabled: false
        }
    end
  end

  defp can_user_go_live?(user, account) do
    limits = get_broadcast_limits(account)
    usage = get_broadcast_usage(user.id)

    Features.FeatureGate.can_access_feature?(account, :live_broadcast) &&
    usage.concurrent_broadcasts < limits.max_concurrent_broadcasts
  end

  defp get_live_quota_remaining(user_id, account) do
    limits = get_broadcast_limits(account)
    usage = get_broadcast_usage(user_id)

    case limits.max_concurrent_broadcasts do
      -1 -> :unlimited
      max -> max - usage.concurrent_broadcasts
    end
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

  defp get_hub_sections(account) do
    base_sections = %{
      "portfolio_studio" => %{
        title: "Portfolio Studio",
        icon: portfolio_icon(),
        badge: nil
      },
      "analytics" => %{
        title: "Analytics",
        icon: analytics_icon(),
        badge: nil
      }
    }

    # Add advanced sections based on subscription tier
    advanced_sections = case account.subscription_tier do
      tier when tier in [:professional, :enterprise] ->
        %{
          "collaboration" => %{
            title: "Collaboration",
            icon: collaboration_icon(),
            badge: "3"
          },
          "live_streaming" => %{
            title: "Live Streaming",
            icon: streaming_icon(),
            badge: "NEW"
          }
        }
      _ -> %{}
    end

    Map.merge(base_sections, advanced_sections)
  end

  defp get_hub_sections_with_state(account, hub_config) do
    hub_config.all_sections
    |> Enum.map(fn section ->
      {section, %{
        title: humanize_section_name(section),
        icon: get_section_icon(section),
        badge: get_section_badge(hub_config, section),
        locked: is_section_locked?(hub_config, section),
        upgrade_tier: get_section_upgrade_tier(hub_config, section)
      }}
    end)
    |> Enum.into(%{})
  end

  defp get_section_badge(hub_config, section) do
    cond do
      is_section_locked?(hub_config, section) ->
        upgrade_info = get_upgrade_prompt_for_section(hub_config, section)
        String.capitalize(upgrade_info.tier)
      section == "creator_lab" -> "BETA"
      section == "revenue_center" -> "NEW"
      true -> nil
    end
  end

    defp validate_collaboration_access(account, portfolio_id) do
    portfolio = Portfolios.get_portfolio!(portfolio_id)

    cond do
      not Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) ->
        {:error, "Real-time collaboration requires Creator tier or higher"}

      not collaboration_enabled_for_portfolio?(portfolio) ->
        {:error, "Collaboration is not enabled for this portfolio"}

      reached_collaboration_limit?(account, portfolio_id) ->
        {:error, "Collaboration limit reached for your subscription tier"}

      true ->
        {:ok, portfolio}
    end
  end

  defp validate_mobile_collaboration_access(account, portfolio_id) do
    case validate_collaboration_access(account, portfolio_id) do
      {:ok, portfolio} ->
        if Features.FeatureGate.can_access_feature?(account, :mobile_collaboration) do
          {:ok, portfolio}
        else
          {:error, "Mobile collaboration requires Professional tier or higher"}
        end

      error ->
        error
    end
  end

  defp get_device_info_from_socket(socket) do
    user_agent = get_connect_info(socket, :user_agent) || ""

    %{
      device_type: if(String.contains?(user_agent, "Mobile"), do: "mobile", else: "desktop"),
      is_mobile: String.contains?(user_agent, "Mobile"),
      supports_real_time: true,
      screen_size: "unknown"
    }
  end

  defp get_user_portfolio_permissions(portfolio_id, user_id) do
    # Look up user permissions for this portfolio
    case :ets.lookup(:portfolio_permissions, {portfolio_id, user_id}) do
      [{_key, permissions}] ->
        {:ok, permissions}

      [] ->
        {:error, :no_permissions}
    end
  end

  defp get_mobile_collaboration_permissions(portfolio, user) do
    base_permissions = get_user_portfolio_permissions(portfolio, user)

    # Mobile collaboration might have restricted permissions
    %{base_permissions |
      can_edit_all: base_permissions.can_edit_all && portfolio.mobile_editing_enabled,
      mobile_optimized: true,
      supports_voice_input: true,
      supports_camera: true
    }
  end

  defp get_mobile_collaboration_options(portfolio_id, account) do
    %{
      voice_editing: Features.FeatureGate.can_access_feature?(account, :voice_editing),
      camera_integration: Features.FeatureGate.can_access_feature?(account, :camera_integration),
      offline_sync: Features.FeatureGate.can_access_feature?(account, :offline_collaboration),
      touch_optimized_ui: true,
      gesture_controls: account.subscription_tier in ["professional", "enterprise"]
    }
  end

  defp update_collaboration_data_with_invitation(collaboration_data, invitation) do
    updated_sent = [invitation | collaboration_data.sent_invitations]
    %{collaboration_data | sent_invitations: updated_sent}
  end

  defp update_collaboration_data_with_new_collaborator(collaboration_data, portfolio_id, user) do
    # Find the collaboration session and add the new collaborator
    updated_active = Enum.map(collaboration_data.active_collaborations, fn collab ->
      if collab.portfolio_id == portfolio_id do
        updated_collaborators = [user | collab.other_collaborators]
        %{collab | other_collaborators: updated_collaborators}
      else
        collab
      end
    end)

    %{collaboration_data | active_collaborations: updated_active}
  end

  defp remove_pending_invitation(collaboration_data, token) do
    updated_sent = Enum.reject(collaboration_data.sent_invitations, &(&1.token == token))
    %{collaboration_data | sent_invitations: updated_sent}
  end

  defp add_real_time_activity(collaboration_data, portfolio_id, section_id, operation, editor_user) do
    # Add real-time activity indicator
    activity = %{
      portfolio_id: portfolio_id,
      section_id: section_id,
      operation_type: operation.type,
      editor: editor_user,
      timestamp: DateTime.utc_now()
    }

    recent_activities = [activity | Map.get(collaboration_data, :recent_activities, [])]
    |> Enum.take(10) # Keep only latest 10 activities

    %{collaboration_data | recent_activities: recent_activities}
  end

  defp collaboration_enabled_for_portfolio?(portfolio) do
    # Check if collaboration is enabled for this specific portfolio
    Map.get(portfolio.settings || %{}, "collaboration_enabled", true)
  end

  defp reached_collaboration_limit?(account, portfolio_id) do
    # Check if user has reached their collaboration limit
    current_sessions = get_user_active_collaboration_count(account.user_id)
    max_sessions = Features.FeatureGate.get_limit(account, :max_collaboration_sessions)

    current_sessions >= max_sessions
  end

  defp get_user_active_collaboration_count(user_id) do
    case :ets.match(:portfolio_sessions, {{user_id, :"$1"}, :"$2"}) do
      sessions when is_list(sessions) -> length(sessions)
      _ -> 0
    end
  end

  defp get_portfolio_active_sessions(portfolio_id) do
    case :ets.match(:portfolio_presence, {{portfolio_id, :"$1"}, :"$2"}) do
      sessions when is_list(sessions) ->
        Enum.map(sessions, fn [user_id, presence_data] ->
          %{
            user_id: user_id,
            username: presence_data.username,
            joined_at: presence_data.joined_at,
            active_section: presence_data.active_section,
            device_type: presence_data.device_type
          }
        end)

      _ ->
        []
    end
  end

  defp get_last_collaborative_edit(portfolio_id) do
    case :ets.lookup(:portfolio_analytics, portfolio_id) do
      [{^portfolio_id, analytics}] ->
        analytics.last_activity

      [] ->
        nil
    end
  end

  defp get_portfolio_collaboration_settings(portfolio_id) do
    # Get collaboration settings for portfolio
    %{
      collaboration_enabled: true,
      auto_save: true,
      conflict_resolution: :operational_transform,
      max_collaborators: 10,
      section_locking: true,
      mobile_collaboration: true
    }
  end

  defp get_other_collaborators(portfolio_id, exclude_user_id) do
    case :ets.match(:portfolio_presence, {{portfolio_id, :"$1"}, :"$2"}) do
      sessions when is_list(sessions) ->
        sessions
        |> Enum.reject(fn [user_id, _] -> user_id == exclude_user_id end)
        |> Enum.map(fn [user_id, presence_data] ->
          %{
            user_id: user_id,
            username: presence_data.username,
            avatar_url: presence_data.avatar_url,
            active_section: presence_data.active_section,
            last_activity: presence_data.last_activity
          }
        end)

      _ ->
        []
    end
  end

  defp get_session_collaborators(portfolio_id) do
    get_other_collaborators(portfolio_id, nil)
  end

  # ============================================================================
  # ETS TABLE INITIALIZATION (Add to mount/3 or init)
  # ============================================================================

  defp ensure_collaboration_ets_tables do
    # Initialize ETS tables for collaboration if they don't exist
    tables = [
      :portfolio_invitations,
      :portfolio_permissions,
      :portfolio_presence,
      :portfolio_sessions,
      :portfolio_analytics,
      :portfolio_sections,
      :user_collaboration_stats,
      :collaboration_history
    ]

    Enum.each(tables, fn table_name ->
      case :ets.whereis(table_name) do
        :undefined ->
          :ets.new(table_name, [:set, :public, :named_table])
        _ ->
          :ok
      end
    end)
  end

  # Add this to the mount function
  defp initialize_collaboration_system do
    ensure_collaboration_ets_tables()

    # Subscribe to collaboration events
    PubSub.subscribe(Frestyl.PubSub, "collaboration:global")
  end

  # ============================================================================
  # EXPORT HELPER FUNCTIONS
  # ============================================================================

  defp export_portfolio_to_pdf(portfolio, user) do
    # Check user permissions for PDF export
    if can_export_pdf?(user, portfolio) do
      try do
        # Generate PDF export
        case Frestyl.Services.PortfolioExporter.export_to_pdf(portfolio) do
          {:ok, pdf_path} ->
            # Upload to storage and return URL
            case upload_export_file(pdf_path, "pdf") do
              {:ok, url} -> {:ok, url}
              error -> error
            end
          error -> error
        end
      rescue
        e -> {:error, "PDF generation failed: #{Exception.message(e)}"}
      end
    else
      {:error, "PDF export requires premium subscription"}
    end
  end

  defp export_portfolio_to_json(portfolio) do
    try do
      # Preload all necessary associations
      portfolio = Frestyl.Repo.preload(portfolio, [:sections, :user])

      export_data = %{
        portfolio: %{
          title: portfolio.title,
          description: portfolio.description,
          theme: portfolio.theme,
          customization: portfolio.customization,
          visibility: portfolio.visibility,
          created_at: portfolio.inserted_at,
          updated_at: portfolio.updated_at
        },
        sections: Enum.map(portfolio.sections, fn section ->
          %{
            title: section.title,
            section_type: section.section_type,
            content: section.content,
            position: section.position,
            visible: section.visible
          }
        end),
        export_info: %{
          exported_at: DateTime.utc_now(),
          format_version: "1.0",
          exported_by: portfolio.user.email
        }
      }

      {:ok, Jason.encode!(export_data, pretty: true)}
    rescue
      e -> {:error, "JSON export failed: #{Exception.message(e)}"}
    end
  end

  defp export_portfolio_analytics(portfolio, user) do
    if can_access_analytics?(user, portfolio) do
      try do
        # Get analytics data
        analytics = Frestyl.Analytics.get_portfolio_analytics(portfolio.id)

        csv_data = [
          ["Date", "Views", "Unique Visitors", "Shares", "Time on Page", "Bounce Rate"],
          # Add analytics rows here
        ]
        |> Enum.map(&Enum.join(&1, ","))
        |> Enum.join("\n")

        {:ok, csv_data}
      rescue
        e -> {:error, "Analytics export failed: #{Exception.message(e)}"}
      end
    else
      {:error, "Analytics access requires premium subscription"}
    end
  end

  defp duplicate_portfolio(portfolio, user) do
    if can_duplicate_portfolio?(user) do
      try do
        # Create duplicate with new title and slug
        duplicate_attrs = %{
          title: "#{portfolio.title} (Copy)",
          slug: generate_unique_slug("#{portfolio.slug}-copy"),
          description: portfolio.description,
          theme: portfolio.theme,
          customization: portfolio.customization,
          visibility: :private  # Always start as private
        }

        case Frestyl.Portfolios.create_portfolio(user.id, duplicate_attrs) do
          {:ok, new_portfolio} ->
            # Copy sections
            copy_portfolio_sections(portfolio, new_portfolio)
            {:ok, new_portfolio}
          error -> error
        end
      rescue
        e -> {:error, "Duplication failed: #{Exception.message(e)}"}
      end
    else
      {:error, "Portfolio duplication requires premium subscription"}
    end
  end

  defp archive_portfolio(portfolio, user) do
    if portfolio.user_id == user.id do
      # Update portfolio to archived status
      case Frestyl.Portfolios.update_portfolio(portfolio, %{visibility: :private, archived: true}) do
        {:ok, updated_portfolio} -> {:ok, updated_portfolio}
        error -> error
      end
    else
      {:error, "Unauthorized"}
    end
  end

  # Permission checks
  defp can_export_pdf?(user, _portfolio) do
    user.subscription_tier in ["creator", "professional", "enterprise"]
  end

  defp can_access_analytics?(user, _portfolio) do
    user.subscription_tier in ["creator", "professional", "enterprise"]
  end

  defp can_duplicate_portfolio?(user) do
    user.subscription_tier in ["creator", "professional", "enterprise"] or
    length(Frestyl.Portfolios.list_user_portfolios(user.id)) < 3
  end

  # Utility functions
  defp upload_export_file(file_path, type) do
    # Implementation depends on your file storage system
    # This is a placeholder
    {:ok, "/exports/#{Path.basename(file_path)}"}
  end

  defp generate_unique_slug(base_slug) do
    # Generate unique slug by appending number if needed
    base_slug
  end

  defp copy_portfolio_sections(source_portfolio, target_portfolio) do
    # Copy all sections from source to target
    # Implementation depends on your section copying logic
    :ok
  end

    defp humanize_collaboration_mode(mode) do
    case mode do
      "solo" -> "Solo Work"
      "peer_review" -> "Peer Review"
      "expert_review" -> "Expert Review"
      "with_coach" -> "With Coach"
      "designer_collaboration" -> "Designer Help"
      "musician_collaboration" -> "Musician Help"
      "developer_collaboration" -> "Developer Help"
      _ -> String.capitalize(String.replace(mode, "_", " "))
    end
  end

  defp get_collaboration_mode_description(mode) do
    case mode do
      "solo" -> "Work independently at your own pace"
      "peer_review" -> "Get feedback from fellow creators"
      "expert_review" -> "Professional review and guidance"
      "with_coach" -> "One-on-one coaching session"
      "designer_collaboration" -> "Work with a visual designer"
      "musician_collaboration" -> "Collaborate with a musician"
      "developer_collaboration" -> "Technical implementation help"
      _ -> "Collaborative workspace"
    end
  end

  defp humanize_tool_name(tool) do
    case tool do
      "text_editor" -> "Text Editor"
      "audio_recorder" -> "Audio Recorder"
      "script_editor" -> "Script Editor"
      "collaboration_tools" -> "Collaboration"
      "chat" -> "Chat"
      "beat_machine" -> "Beat Machine"
      "audio_mixer" -> "Audio Mixer"
      "media_editor" -> "Media Editor"
      "ai_assistant" -> "AI Assistant"
      "teleprompter" -> "Teleprompter"
      _ -> String.capitalize(String.replace(tool, "_", " "))
    end
  end


  # Helper functions for icons (you can replace with your preferred icons)
  defp portfolio_icon do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
    </svg>
    """
  end

  defp analytics_icon do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
    </svg>
    """
  end

  defp collaboration_icon do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
    </svg>
    """
  end

  defp streaming_icon do
    assigns = %{}
    ~H"""
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
      <path d="M17 10.5V7a1 1 0 00-1-1H4a1 1 0 00-1 1v10a1 1 0 001 1h12a1 1 0 001-1v-3.5l4 4v-11l-4 4z"/>
    </svg>
    """
  end

  defp get_visibility_options do
    %{
      :public => %{
        title: "Public",
        description: "Visible to everyone and discoverable in search",
        icon: "🌍",
        color: "bg-green-500"
      },
      :link_only => %{
        title: "Link Only",
        description: "Only accessible via direct link",
        icon: "🔗",
        color: "bg-blue-500"
      },
      :request_only => %{
        title: "Request Access",
        description: "Viewers must request permission to view",
        icon: "🔒",
        color: "bg-yellow-500"
      },
      :private => %{
        title: "Private",
        description: "Only visible to you",
        icon: "👁",
        color: "bg-red-500"
      }
    }
  end

  defp get_social_platforms do
    %{
      "linkedin" => %{
        name: "LinkedIn",
        icon: "in",
        color: "bg-blue-600"
      },
      "twitter" => %{
        name: "Twitter/X",
        icon: "X",
        color: "bg-black"
      },
      "instagram" => %{
        name: "Instagram",
        icon: "IG",
        color: "bg-pink-500"
      },
      "facebook" => %{
        name: "Facebook",
        icon: "f",
        color: "bg-blue-700"
      }
    }
  end

  defp get_privacy_settings do
    %{
      "allow_search_engines" => %{
        title: "Search Engine Indexing",
        description: "Allow search engines to index this portfolio"
      },
      "show_in_discovery" => %{
        title: "Show in Discovery",
        description: "Include in platform's portfolio discovery feeds"
      },
      "require_login_to_view" => %{
        title: "Require Login",
        description: "Viewers must be logged in to access portfolio"
      },
      "watermark_images" => %{
        title: "Watermark Images",
        description: "Add watermarks to protect your images"
      },
      "disable_right_click" => %{
        title: "Disable Right Click",
        description: "Prevent right-click context menu (basic protection)"
      },
      "allow_downloads" => %{
        title: "Allow Downloads",
        description: "Enable download buttons for your files"
      }
    }
  end

  defp get_analytics_settings do
    %{
      "track_visitor_analytics" => %{
        title: "Visitor Analytics",
        description: "Track page views, visitor locations, and behavior"
      },
      "detailed_referrer_tracking" => %{
        title: "Referrer Tracking",
        description: "Track where visitors are coming from"
      },
      "conversion_tracking" => %{
        title: "Conversion Tracking",
        description: "Track contact form submissions and downloads"
      },
      "heatmap_tracking" => %{
        title: "Heatmap Tracking",
        description: "Visual heatmaps of where visitors click and scroll"
      }
    }
  end

  # Helper functions for getting current settings
  defp get_privacy_setting(portfolio, setting_key) do
    portfolio.privacy_settings
    |> Map.get(setting_key, false)
  end

  defp get_social_integration(portfolio, platform) do
    portfolio.social_integration
    |> Map.get("enabled_platforms", [])
    |> Enum.member?(platform)
  end

  defp get_analytics_setting(portfolio, setting_key) do
    portfolio.privacy_settings
    |> Map.get(setting_key, false)
  end

  defp has_password_protection?(portfolio) do
    Map.get(portfolio, :password_hash) != nil
  end

  defp format_datetime_for_input(datetime) when is_nil(datetime), do: ""
  defp format_datetime_for_input(datetime) do
    datetime
    |> DateTime.to_naive()
    |> NaiveDateTime.to_iso8601()
    |> String.slice(0, 16)  # Remove seconds for datetime-local input
  end

    defp get_studio_tools_for_account(account) do
    base_tools = [
      %{id: "text_editor", name: "Text Editor", icon: "📝", category: "writing"},
      %{id: "audio_recorder", name: "Audio Recorder", icon: "🎙️", category: "audio"}
    ]

    creator_tools = if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
      [
        %{id: "collaboration_editor", name: "Collaborative Editor", icon: "👥", category: "collaboration"},
        %{id: "script_editor", name: "Script Editor", icon: "📋", category: "writing"},
        %{id: "voice_recorder", name: "Voice Recorder", icon: "🎤", category: "audio"}
      ]
    else
      []
    end

    professional_tools = if Features.FeatureGate.can_access_feature?(account, :audio_creation) do
      [
        %{id: "beat_machine", name: "Beat Machine", icon: "🥁", category: "music"},
        %{id: "audio_mixer", name: "Audio Mixer", icon: "🎛️", category: "audio"},
        %{id: "ai_assistant", name: "AI Assistant", icon: "🤖", category: "ai"}
      ]
    else
      []
    end

    base_tools ++ creator_tools ++ professional_tools
  end

  defp get_tools_for_enhancement(enhancement_type, account) do
    case enhancement_type do
      :voice_intro ->
        tools = ["audio_recorder", "script_editor"]
        if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
          tools ++ ["collaboration_editor"]
        else
          tools
        end

      :writing_enhancement ->
        tools = ["text_editor"]
        if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
          tools ++ ["collaboration_editor", "ai_assistant"]
        else
          tools
        end

      :background_music ->
        if Features.FeatureGate.can_access_feature?(account, :audio_creation) do
          ["beat_machine", "audio_mixer", "audio_recorder"]
        else
          ["audio_recorder"]
        end

      :creator_lab ->
        if Features.FeatureGate.can_access_feature?(account, :creator_lab) do
          ["text_editor", "audio_recorder", "ai_assistant", "collaboration_editor"]
        else
          []
        end

      _ ->
        ["text_editor", "audio_recorder"]
    end
  end

  defp get_layout_for_enhancement(enhancement_type) do
    case enhancement_type do
      :voice_intro ->
        %{
          collaboration_mode: "audio_with_script",
          primary_tools: ["script_editor", "audio_recorder"],
          layout: %{
            left_dock: ["script_editor"],
            right_dock: ["chat"],
            bottom_dock: ["audio_recorder"]
          }
        }

      :writing_enhancement ->
        %{
          collaboration_mode: "collaborative_writing",
          primary_tools: ["text_editor", "collaboration_editor"],
          layout: %{
            left_dock: ["text_editor"],
            right_dock: ["chat"],
            bottom_dock: []
          }
        }

      :background_music ->
        %{
          collaboration_mode: "audio_production",
          primary_tools: ["beat_machine", "audio_mixer"],
          layout: %{
            left_dock: ["beat_machine"],
            right_dock: ["chat"],
            bottom_dock: ["audio_mixer"]
          }
        }

      :creator_lab ->
        %{
          collaboration_mode: "multimedia_creation",
          primary_tools: ["text_editor", "audio_recorder", "ai_assistant"],
          layout: %{
            left_dock: ["text_editor"],
            right_dock: ["chat"],
            bottom_dock: ["audio_recorder"]
          }
        }

      _ ->
        %{
          collaboration_mode: "general",
          primary_tools: ["text_editor"],
          layout: %{
            left_dock: ["text_editor"],
            right_dock: ["chat"],
            bottom_dock: []
          }
        }
    end
  end

  defp create_contextual_studio_session(user, account, session_type, socket) do
    # Validate feature access
    case session_type do
      "voice_intro" ->
        if Features.FeatureGate.can_access_feature?(account, :voice_recording) do
          create_studio_session_with_context(user, :voice_intro)
        else
          {:error, :upgrade_required}
        end

      "writing_lab" ->
        if Features.FeatureGate.can_access_feature?(account, :real_time_collaboration) do
          create_studio_session_with_context(user, :writing_enhancement)
        else
          {:error, :upgrade_required}
        end

      "audio_studio" ->
        if Features.FeatureGate.can_access_feature?(account, :audio_creation) do
          create_studio_session_with_context(user, :background_music)
        else
          {:error, :upgrade_required}
        end

      _ ->
        create_studio_session_with_context(user, :general)
    end
  end

  defp create_studio_session_with_context(user, enhancement_type) do
    session_attrs = %{
      "title" => "#{String.capitalize(to_string(enhancement_type))} Studio",
      "session_type" => "portfolio_enhancement",
      "enhancement_context" => %{type: enhancement_type},
      "creator_id" => user.id,
      "host_id" => user.id,
      "is_public" => false
    }

    case Sessions.create_studio_session(session_attrs) do
      {:ok, session} ->
        {:ok, ~p"/studio/#{session.id}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp launch_quick_studio_session(socket, enhancement_type, tools) do
    user = socket.assigns.user
    layout_config = get_layout_for_enhancement(enhancement_type)

    session_attrs = %{
      "title" => "Quick #{String.capitalize(to_string(enhancement_type))} Session",
      "session_type" => "portfolio_enhancement",
      "enhancement_context" => %{
        type: enhancement_type,
        tools: tools,
        layout: layout_config
      },
      "creator_id" => user.id,
      "host_id" => user.id,
      "is_public" => false
    }

    case Sessions.create_studio_session(session_attrs) do
      {:ok, session} ->
        {:noreply,
         socket
         |> put_flash(:info, "Studio session launched!")
         |> push_navigate(to: ~p"/studio/#{session.id}")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to create studio session")}
    end
  end

  defp show_upgrade_prompt(socket, feature_name) do
    socket
    |> assign(:show_upgrade_modal, true)
    |> put_flash(:warning, "#{String.capitalize(feature_name)} requires a higher subscription tier")
  end

    defp get_available_enhancements(account) do
    base_enhancements = [
      %{
        type: "voice_intro",
        title: "Voice Introduction",
        description: "Record a compelling personal introduction",
        icon: "🎙️",
        tools: ["audio_recorder", "script_editor", "teleprompter"],
        estimated_time: "15-30 minutes",
        collaboration_modes: ["solo", "with_coach"],
        tier_required: "personal"
      },
      %{
        type: "writing_enhancement",
        title: "Writing Enhancement",
        description: "Improve your portfolio content with expert feedback",
        icon: "✍️",
        tools: ["text_editor", "collaboration_tools", "ai_assistant"],
        estimated_time: "30-60 minutes",
        collaboration_modes: ["solo", "peer_review", "expert_review"],
        tier_required: "personal"
      },
      %{
        type: "visual_polish",
        title: "Visual Polish",
        description: "Enhance your portfolio's visual appeal",
        icon: "🎨",
        tools: ["media_editor", "layout_designer", "collaboration_tools"],
        estimated_time: "45-90 minutes",
        collaboration_modes: ["solo", "designer_collaboration"],
        tier_required: "creator"
      }
    ]

    premium_enhancements = [
      %{
        type: "background_music",
        title: "Background Music",
        description: "Create custom background music for your portfolio",
        icon: "🎵",
        tools: ["beat_machine", "audio_mixer", "collaboration_tools"],
        estimated_time: "60-120 minutes",
        collaboration_modes: ["solo", "musician_collaboration"],
        tier_required: "creator"
      },
      %{
        type: "interactive_elements",
        title: "Interactive Elements",
        description: "Add interactive features to engage visitors",
        icon: "⚡",
        tools: ["interaction_builder", "animation_tools", "collaboration_tools"],
        estimated_time: "90-180 minutes",
        collaboration_modes: ["solo", "developer_collaboration"],
        tier_required: "professional"
      }
    ]

    # Filter by subscription tier
    all_enhancements = base_enhancements ++ premium_enhancements
    tier_priority = tier_to_priority(account.subscription_tier)

    Enum.filter(all_enhancements, fn enhancement ->
      enhancement_priority = tier_to_priority(enhancement.tier_required)
      tier_priority >= enhancement_priority
    end)
  end

  defp get_available_studio_tools(account) do
    base_tools = [
      %{id: "text_editor", name: "Text Editor", category: "writing"},
      %{id: "audio_recorder", name: "Audio Recorder", category: "audio"},
      %{id: "script_editor", name: "Script Editor", category: "writing"},
      %{id: "collaboration_tools", name: "Collaboration", category: "collaboration"},
      %{id: "chat", name: "Chat", category: "collaboration"}
    ]

    premium_tools = [
      %{id: "beat_machine", name: "Beat Machine", category: "audio"},
      %{id: "audio_mixer", name: "Audio Mixer", category: "audio"},
      %{id: "media_editor", name: "Media Editor", category: "visual"},
      %{id: "ai_assistant", name: "AI Assistant", category: "ai"},
      %{id: "teleprompter", name: "Teleprompter", category: "presentation"}
    ]

    case account.subscription_tier do
      tier when tier in ["creator", "professional", "enterprise"] ->
        base_tools ++ premium_tools
      _ ->
        base_tools
    end
  end

  defp get_portfolios_for_enhancement(portfolios, enhancement_type) do
    case enhancement_type do
      "voice_intro" ->
        # Portfolios that don't have voice introductions yet
        Enum.filter(portfolios, fn p -> !has_voice_intro?(p) end)
      "writing_enhancement" ->
        # Portfolios with content that could be improved
        Enum.filter(portfolios, fn p -> has_content_to_enhance?(p) end)
      "visual_polish" ->
        # Portfolios that could benefit from visual improvements
        Enum.filter(portfolios, fn p -> needs_visual_improvement?(p) end)
      "background_music" ->
        # Portfolios that don't have background music
        Enum.filter(portfolios, fn p -> !has_background_music?(p) end)
      _ ->
        portfolios
    end
  end

  defp get_tools_for_enhancement(enhancement_type) do
    case enhancement_type do
      "voice_intro" ->
        ["script_editor", "audio_recorder", "teleprompter", "collaboration_tools"]
      "writing_enhancement" ->
        ["text_editor", "ai_assistant", "collaboration_tools", "chat"]
      "visual_polish" ->
        ["media_editor", "layout_designer", "collaboration_tools", "chat"]
      "background_music" ->
        ["beat_machine", "audio_mixer", "audio_recorder", "collaboration_tools"]
      "interactive_elements" ->
        ["interaction_builder", "animation_tools", "collaboration_tools", "chat"]
      _ ->
        ["text_editor", "collaboration_tools", "chat"]
    end
  end

  defp tier_to_priority(tier) do
    case tier do
      "personal" -> 1
      "creator" -> 2
      "professional" -> 3
      "enterprise" -> 4
      _ -> 0
    end
  end

  defp create_enhancement_session(session_attrs, user) do
    # Use existing Sessions context to create studio session
    try do
      Sessions.create_session(session_attrs)
    rescue
      _ -> {:error, "Failed to create session"}
    end
  end

  # Portfolio analysis helpers
  defp has_voice_intro?(portfolio) do
    # Check if portfolio has voice introduction section
    case Ecto.assoc_loaded?(portfolio.sections) do
      true ->
        sections = portfolio.sections || []
        Enum.any?(sections, &(&1.section_type == "voice_intro"))
      false ->
        false
    end
  end

  defp has_content_to_enhance?(portfolio) do
    case Ecto.assoc_loaded?(portfolio.sections) do
      true ->
        sections = portfolio.sections || []
        Enum.any?(sections, fn section ->
          content = section.content || %{}
          text_content = get_text_content_length(content)
          text_content > 50 && text_content < 500 # Has content but could be enhanced
        end)
      false ->
        false
    end
  end

  defp needs_visual_improvement?(portfolio) do
    case Ecto.assoc_loaded?(portfolio.sections) do
      true ->
        sections = portfolio.sections || []
        media_count = Enum.count(sections, fn section ->
          content = section.content || %{}
          has_media = Map.has_key?(content, "images") || Map.has_key?(content, "media_items")
          has_media
        end)
        media_count < 3 # Has fewer than 3 sections with media
      false ->
        true
    end
  end

  defp has_background_music?(portfolio) do
    # Check if portfolio has background music
    customization = portfolio.customization || %{}
    Map.has_key?(customization, "background_music_url")
  end

  defp get_text_content_length(content) do
    text_fields = ["description", "summary", "content", "bio"]

    text_fields
    |> Enum.map(&(content[&1] || ""))
    |> Enum.filter(&is_binary/1)
    |> Enum.join(" ")
    |> String.trim()
    |> String.length()
  end
end
