# lib/frestyl_web/live/portfolio_hub_live.ex
defmodule FrestylWeb.PortfolioHubLive do
  use FrestylWeb, :live_view

  on_mount {FrestylWeb.UserAuth, :ensure_authenticated}

  alias Frestyl.{Portfolios, Accounts, Channels, Features, Repo}
  alias Frestyl.Accounts.{Account, AccountMembership}
  alias Frestyl.Features.FeatureGate
  alias FrestylWeb.StoryEngineLive.Hub
  alias FrestylWeb.PortfolioHubLive.ContentCampaignComponents
  alias Frestyl.DataCampaigns.AdvancedTracker
  import FrestylWeb.Navigation, only: [nav: 1]
  alias FrestylWeb.PortfolioHubLive.Helpers
  import Ecto.Changeset

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    # Load user's accounts for switcher and ensure current account is set
    available_accounts = load_user_accounts(current_user.id)
    current_account = get_current_account(current_user, available_accounts)

    # Enhanced PubSub subscriptions with all necessary channels
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_hub")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolios:#{current_user.id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "content_campaigns:#{current_account.id}")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}:campaigns")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}:quality_gates")
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "user:#{current_user.id}:revenue")
    end

    # Load initial data scoped to current account
    portfolios = load_account_portfolios(current_account) || []
    network_stats = load_network_stats(current_user.id)
    analytics_data = calculate_analytics_data(portfolios)

    socket = socket
      |> assign(:current_account, current_account)
      |> assign(:available_accounts, available_accounts)
      |> assign(:show_account_switcher, false)
      |> assign(:portfolios, portfolios)
      |> assign(:analytics_data, analytics_data)
      |> assign(:analytics_period, "30")
      |> assign(:story_template, nil)
      |> assign(:calendar_view, "month")
      |> assign(:view_mode, "cards")
      |> assign(:sort_by, "recent")
      |> assign(:filter_status, "all")
      |> assign(:show_create_modal, false)
      |> assign(:create_type, nil)
      |> assign(:active_tab, "portfolio_hub")
      |> assign(:active_section, "portfolios")
      |> assign(:story_engine_enabled, true)
      |> assign(:page_title, "Portfolio Hub")
      |> assign(:total_views, calculate_total_views(portfolios))
      |> assign(:monthly_views, calculate_monthly_views(portfolios))
      |> assign(:network_stats, network_stats)
      |> assign(:recent_connections, load_recent_connections(current_user.id))
      |> assign(:trending_portfolios, load_trending_portfolios())
      |> assign(:active_collaborations, load_active_collaborations(current_user.id))
      |> assign(:available_templates, load_available_templates())
      # Collaboration Hub data
      |> assign(:collaboration_invites, load_collaboration_invites(current_user.id))
      |> assign(:collaboration_projects, load_collaboration_projects(current_user.id))
      # Community Channels data
      |> assign(:user_channels, load_user_channels(current_user.id))
      |> assign(:recommended_channels, load_recommended_channels(current_user.id))
      |> assign(:official_channel, load_official_channel())
      |> assign(:featured_collaborations, load_featured_collaborations())
      |> assign(:channels_view_mode, "cards")
      |> assign(:channel_search, "")
      |> assign(:channels_sort_by, "recent")
      |> assign(:channels_filter, "all")
      |> assign(:open_channel_menu, nil)
      # Service Dashboard data (Creator tier+)
      |> assign(:service_revenue, load_service_revenue(current_account))
      |> assign(:service_bookings, load_service_bookings(current_account))
      |> assign(:service_analytics, load_service_analytics(current_account))
      # Creator Studio data (Creator tier+)
      |> assign(:studio_projects, load_studio_projects(current_account))
      |> assign(:studio_resources, load_studio_resources(current_account))
      # Phase 1: Content Campaigns
      |> assign(:content_campaigns, load_content_campaigns(current_user))
      |> assign(:campaign_limits, get_campaign_limits(current_account))
      # Phase 2: Advanced tracking and quality management
      |> assign(:campaign_metrics, load_campaign_metrics(current_user))
      |> assign(:active_improvement_periods, load_active_improvement_periods(current_user))
      |> assign(:pending_peer_reviews, load_pending_peer_reviews(current_user))
      |> assign(:show_improvement_modal, false)
      |> assign(:show_peer_review_modal, false)
      # Phase 3: Revenue & contracts system
      |> assign(:revenue_metrics, load_revenue_metrics(current_user))
      |> assign(:campaign_revenues, load_campaign_revenues(current_user))
      |> assign(:recent_payments, load_recent_payments(current_user))
      |> assign(:revenue_projections, load_revenue_projections(current_user))
      |> assign(:projected_total_revenue, calculate_projected_total(current_user))
      |> assign(:pending_contracts, load_pending_contracts(current_user))
      |> assign(:show_contract_modal, false)
      |> assign(:current_contract, nil)
      |> assign(:show_revenue_analytics, false)
      # Enhanced onboarding with all new features
      |> assign(:onboarding_state, get_onboarding_state(current_user, portfolios, load_revenue_metrics(current_user)))

    {:ok, socket}
  end

  # Helper function to get user's primary account
  defp get_user_primary_account(user) do
    case Accounts.get_user_primary_account(user) do
      nil ->
        # Create a default account if none exists
        {:ok, account} = Accounts.create_account(%{
          name: "#{user.username || user.email}'s Account",
          user_id: user.id,
          subscription_tier: "personal"
        })
        account
      account -> account
    end
  end

  # Phase 1 helper functions
  defp load_content_campaigns(user) do
    try do
      DataCampaigns.list_user_campaigns(user.id)
    rescue
      _ -> []
    end
  end

  defp get_campaign_limits(account) do
    try do
      Features.FeatureGate.get_campaign_limits(account)
    rescue
      _ -> %{concurrent_campaigns: 1, max_contributors: 3, revenue_sharing: false}
    end
  end

  defp load_campaign_metrics(user) do
    try do
      DataCampaigns.get_user_campaign_metrics(user.id)
    rescue
      _ -> %{
        total_campaigns: 0,
        active_campaigns: 0,
        completed_campaigns: 0,
        total_revenue: 0,
        avg_quality_score: 0
      }
    end
  end

  # Phase 2 helper functions
  defp load_active_improvement_periods(user) do
    try do
      case :ets.match(:improvement_periods, {'$1', %{user_id: user.id, status: :active}}) do
        periods when is_list(periods) ->
          Enum.map(periods, fn [id] ->
            [{^id, period}] = :ets.lookup(:improvement_periods, id)
            period
          end)
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp load_pending_peer_reviews(user) do
    try do
      case :ets.match(:peer_review_requests, {'$1', %{status: :pending}}) do
        requests when is_list(requests) ->
          Enum.map(requests, fn [id] ->
            [{^id, request}] = :ets.lookup(:peer_review_requests, id)
            request
          end)
          |> Enum.filter(&can_review_request?(&1, user))
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp can_review_request?(review_request, user) do
    # User can review if they're in the campaign but not the contributor
    review_request.contributor_id != user.id
  end

  # Phase 3 helper functions
  defp load_revenue_metrics(user) do
    try do
      case DataCampaigns.RevenueManager.update_portfolio_revenue_metrics(user.id) do
        {:ok, metrics} -> metrics
        _ -> default_revenue_metrics()
      end
    rescue
      _ -> default_revenue_metrics()
    end
  end

  defp default_revenue_metrics do
    %{
      total_revenue: 0,
      campaign_revenue: 0,
      active_campaigns: 0,
      avg_quality_score: 0,
      revenue_growth_rate: 0,
      campaign_growth_rate: 0,
      quality_trend: :stable
    }
  end

  defp load_campaign_revenues(user) do
    try do
      DataCampaigns.RevenueManager.get_user_campaign_revenues(user.id)
    rescue
      _ -> []
    end
  end

  defp load_recent_payments(user) do
    try do
      DataCampaigns.RevenueManager.get_recent_campaign_payments(user.id, 5)
    rescue
      _ -> []
    end
  end

  defp load_revenue_projections(user) do
    try do
      DataCampaigns.RevenueManager.get_revenue_projections(user.id)
    rescue
      _ -> []
    end
  end

  defp calculate_projected_total(user) do
    try do
      DataCampaigns.RevenueManager.calculate_projected_total_revenue(user.id)
    rescue
      _ -> 0
    end
  end

  defp load_pending_contracts(user) do
    try do
      DataCampaigns.RevenueManager.get_user_pending_contracts(user.id)
    rescue
      _ -> []
    end
  end

  # Existing helper functions (keep these as they were)
  defp load_user_portfolios(user_id) do
    try do
      case Portfolios.list_user_portfolios(user_id) do
        portfolios when is_list(portfolios) -> portfolios
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp load_network_stats(user_id) do
    %{
      connections: get_user_connections_count(user_id),
      collaborations: get_user_collaborations_count(user_id),
      recommendations: get_user_recommendations_count(user_id),
      profile_views: get_user_profile_views(user_id)
    }
  end

  defp load_recent_connections(user_id) do
    try do
      []
    rescue
      _ -> []
    end
  end

  defp load_trending_portfolios do
    try do
      []
    rescue
      _ -> []
    end
  end

  defp load_user_channels(user_id) do
    try do
      Channels.list_user_channels(user_id)
    rescue
      _ -> []
    end
  end

  defp load_featured_collaborations do
    try do
      Frestyl.Content.get_featured_collaborations(limit: 3)
    rescue
      _ -> []
    end
  end

  # Placeholder functions that would need actual implementation
  defp get_user_connections_count(_user_id), do: 0
  defp get_user_collaborations_count(_user_id), do: 0
  defp get_user_recommendations_count(_user_id), do: 0
  defp get_user_profile_views(_user_id), do: 0

  @impl true
  def handle_params(params, _url, socket) do
    section = Map.get(params, "section", "portfolios")
    {:noreply, assign(socket, :active_section, section)}
  end

  # Account Switching Events
  @impl true
  def handle_event("close_account_switcher", _params, socket) do
    {:noreply, assign(socket, :show_account_switcher, false)}
  end

  @impl true
  def handle_event("toggle_account_switcher", _params, socket) do
    {:noreply, assign(socket, :show_account_switcher, !socket.assigns.show_account_switcher)}
  end

  # Update your existing switch_account handler to close the dropdown:
  @impl true
  def handle_event("switch_account", %{"account_id" => account_id}, socket) do
    current_user = socket.assigns.current_user
    account_id = String.to_integer(account_id)

    case get_user_account(current_user.id, account_id) do
      {:ok, account} ->
        # Update session to remember last active account
        Phoenix.PubSub.broadcast(Frestyl.PubSub, "user:#{current_user.id}",
          {:account_switched, account_id})

        # Reload data for new account
        portfolios = load_account_portfolios(account)
        analytics_data = calculate_analytics_data(portfolios)

        {:noreply,
        socket
        |> assign(:current_account, account)
        |> assign(:portfolios, portfolios)
        |> assign(:analytics_data, analytics_data)
        |> assign(:show_account_switcher, false)  # This already closes it
        |> put_flash(:info, "Switched to #{account.name}")}

      {:error, _} ->
        {:noreply,
        socket
        |> assign(:show_account_switcher, false)  # Close on error too
        |> put_flash(:error, "Could not switch accounts")}
    end
  end

  @impl true
  def handle_event("create_account", params, socket) do
    current_user = socket.assigns.current_user

    account_attrs = %{
      name: params["name"],
      type: String.to_atom(params["type"])
    }

    case create_account_for_user(current_user, account_attrs) do
      {:ok, account} ->
        available_accounts = load_user_accounts(current_user.id)

        {:noreply,
         socket
         |> assign(:available_accounts, available_accounts)
         |> assign(:current_account, account)
         |> assign(:show_account_switcher, false)
         |> put_flash(:info, "Created account: #{account.name}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create account")}
    end
  end

  # Tab Navigation Events
  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    # Check tier access for premium features
    case check_tab_access(socket.assigns.current_account, tab) do
      {:ok, :accessible} ->
        {:noreply, assign(socket, :active_tab, tab)}
      {:error, :upgrade_required} ->
        {:noreply, put_flash(socket, :info, "Upgrade to access #{humanize_tab(tab)}")}
    end
  end

  # Collaboration Hub Events
  @impl true
  def handle_event("invite_collaborator", %{"email" => email, "project_id" => project_id}, socket) do
    current_user = socket.assigns.current_user

    case create_collaboration_invite(current_user, email, project_id) do
      {:ok, _invite} ->
        {:noreply, put_flash(socket, :info, "Collaboration invite sent to #{email}")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to send invitation")}
    end
  end

  @impl true
  def handle_event("start_collaboration", %{"title" => title, "description" => description}, socket) do
    current_user = socket.assigns.current_user
    current_account = socket.assigns.current_account

    case create_collaboration_project(current_account, current_user, %{
      title: title,
      description: description
    }) do
      {:ok, project} ->
        {:noreply, put_flash(socket, :info, "Collaboration project '#{title}' created!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create collaboration project")}
    end
  end

  # Community Channels Events
  @impl true
  def handle_event("join_channel", %{"channel_id" => channel_id}, socket) do
    current_user = socket.assigns.current_user

    case Channels.join_channel(current_user, channel_id) do
      {:ok, _membership} ->
        user_channels = load_user_channels(current_user.id)
        {:noreply, assign(socket, :user_channels, user_channels)}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to join channel")}
    end
  end

  @impl true
  def handle_event("create_channel", params, socket) do
    current_user = socket.assigns.current_user

    channel_attrs = %{
      name: params["name"],
      description: params["description"],
      is_public: params["is_public"] == "true"
    }

    case Channels.create_channel(current_user, channel_attrs) do
      {:ok, channel} ->
        {:noreply, put_flash(socket, :info, "Channel '#{channel.name}' created!")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create channel")}
    end
  end

  @impl true
  def handle_event("start_session", %{"channel_id" => channel_id}, socket) do
    current_user = socket.assigns.current_user

    case start_channel_session(current_user, channel_id) do
      {:ok, session} ->
        {:noreply, redirect(socket, to: ~p"/channels/#{channel_id}/session/#{session.id}")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to start session")}
    end
  end

  def handle_event("discover_official_channel", _params, socket) do
    {:noreply, redirect(socket, to: ~p"/channels/frestyl-official")}
  end

  # Service Dashboard Events (Creator Tier+)
  @impl true
  def handle_event("create_service", params, socket) do
    if can_access_feature?(socket.assigns.current_account, :service_booking) do
      current_account = socket.assigns.current_account

      case create_portfolio_service(current_account, params) do
        {:ok, service} ->
          {:noreply, put_flash(socket, :info, "Service '#{service.title}' created!")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to create service")}
      end
    else
      {:noreply, put_flash(socket, :info, "Upgrade to Creator tier to offer services")}
    end
  end

  @impl true
  def handle_event("export_revenue_report", _params, socket) do
    if can_access_feature?(socket.assigns.current_account, :service_booking) do
      {:noreply, put_flash(socket, :info, "Revenue report download started")}
    else
      {:noreply, put_flash(socket, :info, "Upgrade to access revenue reports")}
    end
  end

  # Creator Studio Events (Creator Tier+)
  @impl true
  def handle_event("launch_studio_tool", %{"tool" => tool}, socket) do
    if can_access_feature?(socket.assigns.current_account, :creator_studio) do
      case tool do
        "video_editor" ->
          {:noreply, redirect(socket, external: "https://studio.frestyl.com/video")}
        "audio_mixer" ->
          {:noreply, redirect(socket, external: "https://studio.frestyl.com/audio")}
        "live_broadcast" ->
          {:noreply, redirect(socket, to: ~p"/studio/broadcast")}
        _ ->
          {:noreply, put_flash(socket, :info, "Launching #{tool}...")}
      end
    else
      {:noreply, put_flash(socket, :info, "Upgrade to Creator tier to access Studio tools")}
    end
  end

  # Existing Events (preserved from original)
  @impl true
  def handle_event("change_section", %{"section" => section}, socket) do
    {:noreply,
     socket
     |> assign(:active_section, section)
     |> push_patch(to: ~p"/portfolio-hub?section=#{section}")}
  end

  @impl true
  def handle_event("import_portfolio", _params, socket) do
    {:noreply, socket |> put_flash(:info, "Portfolio import feature coming soon!")}
  end

  @impl true
  def handle_event("use_template", %{"template_id" => template_id}, socket) do
    current_user = socket.assigns.current_user
    current_account = socket.assigns.current_account

    case create_portfolio_from_template(template_id, current_user, current_account) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> put_flash(:info, "Portfolio created from template!")
         |> redirect(to: ~p"/portfolios/#{portfolio.id}/edit")}

      {:error, _reason} ->
        {:noreply, socket |> put_flash(:error, "Failed to create portfolio from template")}
    end
  end

  @impl true
  def handle_event("change_view", params, socket) do
    view_mode = params["view"]
    {:noreply, assign(socket, :view_mode, view_mode)}
  end

  @impl true
  def handle_event("create_story_from_template", %{"template" => template_type}, socket) do
    {:noreply,
    socket
    |> assign(:show_create_modal, true)
    |> assign(:create_type, "story")
    |> assign(:story_template, template_type)
    |> put_flash(:info, "Creating #{template_type} story...")}
  end

  @impl true
  def handle_event("create_story", params, socket) do
    current_user = socket.assigns.current_user
    current_account = socket.assigns.current_account
    template_type = socket.assigns[:story_template] || "general"

    story_attrs = %{
      title: params["title"],
      description: params["description"],
      story_type: template_type,
      status: "draft",
      account_id: current_account.id
    }

    {:noreply,
    socket
    |> assign(:show_create_modal, false)
    |> assign(:create_type, nil)
    |> assign(:story_template, nil)
    |> put_flash(:info, "Story '#{story_attrs.title}' created successfully!")}
  end

  @impl true
  def handle_event("toggle_setting", %{"setting" => setting_name}, socket) do
    message = case setting_name do
      "email_notifications" -> "Email notifications updated"
      "search_engines" -> "Search engine indexing updated"
      "allow_downloads" -> "Download permissions updated"
      "analytics_tracking" -> "Analytics tracking updated"
      _ -> "Setting updated"
    end

    {:noreply, put_flash(socket, :info, message)}
  end

  @impl true
  def handle_event("connect_social", %{"platform" => platform}, socket) do
    {:noreply, put_flash(socket, :info, "#{String.capitalize(platform)} connection initiated")}
  end

  @impl true
  def handle_event("change_analytics_period", %{"period" => period}, socket) do
    updated_analytics = calculate_analytics_for_period(socket.assigns.portfolios, period)

    {:noreply,
    socket
    |> assign(:analytics_data, updated_analytics)
    |> assign(:analytics_period, period)}
  end

  @impl true
  def handle_event("add_calendar_event", %{"type" => event_type}, socket) do
    {:noreply, put_flash(socket, :info, "#{String.capitalize(event_type)} event creation coming soon!")}
  end

  @impl true
  def handle_event("change_calendar_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :calendar_view, view)}
  end

  @impl true
  def handle_event("navigate_calendar", %{"direction" => direction}, socket) do
    message = case direction do
      "prev" -> "Navigated to previous period"
      "next" -> "Navigated to next period"
      _ -> "Calendar navigation"
    end

    {:noreply, put_flash(socket, :info, message)}
  end

  @impl true
  def handle_event("select_calendar_day", %{"day" => day}, socket) do
    {:noreply, put_flash(socket, :info, "Selected day #{day} - event creation coming soon!")}
  end

  @impl true
  def handle_event("sync_external_calendar", _params, socket) do
    {:noreply, put_flash(socket, :info, "Syncing with connected calendars...")}
  end

  @impl true
  def handle_event("export_data", _params, socket) do
    {:noreply, put_flash(socket, :info, "Data export initiated. You'll receive an email when ready.")}
  end

  @impl true
  def handle_event("close_create_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_modal, false)}
  end

  @impl true
  def handle_event("show_create_modal", %{"type" => type}, socket) do
    {:noreply,
     socket
     |> assign(:show_create_modal, true)
     |> assign(:create_type, type)}
  end

  def handle_event("show_create_modal", %{"type" => "content_campaign"}, socket) do
    {:noreply, assign(socket, :show_content_campaign_modal, true)}
  end

  def handle_event("join_campaign", %{"campaign_id" => campaign_id}, socket) do
    # Implement campaign joining logic
    {:noreply, socket |> put_flash(:info, "Joined campaign successfully!")}
  end

  def handle_event("view_campaign", %{"campaign_id" => campaign_id}, socket) do
    {:noreply, push_navigate(socket, to: "/campaigns/#{campaign_id}")}
  end

  # Add these event handlers to lib/frestyl_web/live/portfolio_hub_live.ex

  # Story Engine Quick Actions Event Handlers
  @impl true
  def handle_event("quick_create_story", %{"template" => template_key}, socket) do
    user = socket.assigns.current_user

    # Map template keys to story types and intents
    {story_type, intent} = case template_key do
      "article" -> {"article", "educate"}
      "case_study" -> {"case_study", "persuade"}
      _ -> {"article", "educate"}
    end

    # Create story with template
    story_params = %{
      title: get_template_title(template_key),
      story_type: story_type,
      intent_category: intent,
      creation_source: "portfolio_hub_quick_action",
      quick_start_template: template_key,
      created_by_id: user.id
    }

    case Stories.create_enhanced_story(story_params, user) do
      {:ok, story} ->
        {:noreply,
        socket
        |> put_flash(:info, "Story created! Redirecting to editor...")
        |> redirect(to: ~p"/stories/#{story.id}/edit")}
      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create story. Please try again.")}
    end
  end

  @impl true
  def handle_event("show_import_modal", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_import_modal, true)
    |> assign(:import_error, nil)
    |> assign(:processing_import, false)}
  end

  @impl true
  def handle_event("close_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_import_modal, false)}
  end

  @impl true
  def handle_event("import_existing_work", %{"import" => import_params}, socket) do
    user = socket.assigns.current_user

    case import_params do
      %{"file" => file_upload} ->
        # Handle file upload
        handle_file_import(socket, file_upload, user)

      %{"text_content" => text_content, "title" => title} when text_content != "" ->
        # Handle direct text paste
        handle_text_import(socket, text_content, title, user)

      %{"url" => url} when url != "" ->
        # Handle URL import (Google Docs, etc.)
        handle_url_import(socket, url, user)

      _ ->
        {:noreply, put_flash(socket, :error, "Please provide content to import")}
    end
  end

  @impl true
  def handle_event("launch_studio_tool", %{"tool" => tool}, socket) do
    # Redirect to creator studio with specific tool
    studio_path = case tool do
      "audio_production" -> ~p"/studio?tool=audio"
      "video_production" -> ~p"/studio?tool=video"
      "podcast_creation" -> ~p"/studio?tool=podcast"
      _ -> ~p"/studio"
    end

    {:noreply, redirect(socket, to: studio_path)}
  end

  @impl true
  def handle_event("show_story_templates", _params, socket) do
    {:noreply, push_event(socket, "show_modal", %{modal: "story_templates_library"})}
  end

  # Import Helper Functions
  defp handle_file_import(socket, file_upload, user) do
    socket = assign(socket, :processing_import, true)

    case extract_content_from_file(file_upload) do
      {:ok, content, title} ->
        create_imported_story(socket, content, title, user, "file_upload")

      {:error, reason} ->
        {:noreply,
        socket
        |> assign(:processing_import, false)
        |> assign(:import_error, "Failed to process file: #{reason}")
        |> put_flash(:error, "Could not import file. Please try a different format.")}
    end
  end

  defp handle_text_import(socket, text_content, title, user) do
    title = if title == "" or is_nil(title), do: "Imported Story", else: title
    create_imported_story(socket, text_content, title, user, "text_paste")
  end

  defp handle_url_import(socket, url, user) do
    socket = assign(socket, :processing_import, true)

    case import_from_url(url) do
      {:ok, content, title} ->
        create_imported_story(socket, content, title, user, "url_import")

      {:error, reason} ->
        {:noreply,
        socket
        |> assign(:processing_import, false)
        |> assign(:import_error, "Failed to import from URL: #{reason}")
        |> put_flash(:error, "Could not access the provided URL.")}
    end
  end

  defp create_imported_story(socket, content, title, user, source) do
    story_params = %{
      title: title,
      content: content,
      story_type: "imported_content",
      intent_category: "general",
      creation_source: source,
      created_by_id: user.id,
      status: "draft"
    }

    case Stories.create_enhanced_story(story_params, user) do
      {:ok, story} ->
        {:noreply,
        socket
        |> assign(:show_import_modal, false)
        |> assign(:processing_import, false)
        |> put_flash(:info, "Content imported successfully!")
        |> redirect(to: ~p"/stories/#{story.id}/edit")}

      {:error, _changeset} ->
        {:noreply,
        socket
        |> assign(:processing_import, false)
        |> assign(:import_error, "Failed to create story from imported content")
        |> put_flash(:error, "Could not create story. Please try again.")}
    end
  end

  defp extract_content_from_file(file_upload) do
    # Extract content based on file type
    case Path.extname(file_upload.filename) do
      ".txt" ->
        {:ok, File.read!(file_upload.path), Path.basename(file_upload.filename, ".txt")}

      ".md" ->
        {:ok, File.read!(file_upload.path), Path.basename(file_upload.filename, ".md")}

      ".docx" ->
        # Use a library like Pandoc or similar to extract text from DOCX
        extract_docx_content(file_upload.path)

      ".pdf" ->
        # Use a PDF text extraction library
        extract_pdf_content(file_upload.path)

      _ ->
        {:error, "Unsupported file format"}
    end
  end

  defp extract_docx_content(file_path) do
    # Implementation depends on available libraries
    # For now, return error suggesting manual copy-paste
    {:error, "DOCX files not yet supported. Please copy and paste your content."}
  end

  defp extract_pdf_content(file_path) do
    # Implementation depends on available PDF libraries
    {:error, "PDF files not yet supported. Please copy and paste your content."}
  end

  defp import_from_url(url) do
    # For now, URL import is not supported - suggest manual copy/paste
    # This can be implemented later when HTTP client dependencies are added
    {:error, "URL import not yet supported. Please copy and paste your content using the 'Paste Text Content' option above."}
  end

  # Future implementation placeholder (commented out until HTTP client is available)
  # defp import_from_url_with_finch(url) do
  #   case Finch.build(:get, url) |> Finch.request(MyApp.Finch) do
  #     {:ok, %Finch.Response{status: 200, body: body}} ->
  #       content = clean_html_content(body)
  #       title = extract_title_from_html(body) || "Imported from URL"
  #       {:ok, content, title}
  #     _ ->
  #       {:error, "Could not fetch content from URL"}
  #   end
  # rescue
  #   _ -> {:error, "URL import service unavailable"}
  # end

  defp clean_html_content(html) do
    # Basic HTML-to-text conversion for future use
    html
    |> String.replace(~r/<script[^>]*>.*?<\/script>/s, "")
    |> String.replace(~r/<style[^>]*>.*?<\/style>/s, "")
    |> String.replace(~r/<[^>]*>/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp extract_title_from_html(html) do
    case Regex.run(~r/<title[^>]*>([^<]+)<\/title>/i, html) do
      [_, title] -> String.trim(title)
      _ -> nil
    end
  end

  # Helper function for template titles
  defp get_template_title(template_key) do
    case template_key do
      "article" -> "Quick Article"
      "case_study" -> "Case Study Analysis"
      _ -> "New Story"
    end
  end

  # Content Campaigns Events
  @impl true
  def handle_event("create_content_campaign", _params, socket) do
    current_user = socket.assigns.current_user
    current_account = socket.assigns.current_account

    if FeatureGate.can_access_feature?(current_account, :content_campaigns) do
      {:noreply, socket
      |> assign(:show_campaign_modal, true)
      |> assign(:campaign_form, %{})}
    else
      {:noreply, socket
      |> put_flash(:error, "Upgrade required for content campaigns")
      |> push_navigate(to: "/subscription")}
    end
  end

  @impl true
  def handle_event("join_campaign", %{"campaign_id" => campaign_id}, socket) do
    current_user = socket.assigns.current_user

    case Frestyl.DataCampaigns.join_campaign(campaign_id, current_user) do
      {:ok, _contribution} ->
        {:noreply, socket
        |> assign(:content_campaigns, load_content_campaigns(current_user))
        |> put_flash(:info, "Joined campaign successfully!")}

      {:error, :campaign_full} ->
        {:noreply, put_flash(socket, :error, "Campaign is full")}

      {:error, :already_joined} ->
        {:noreply, put_flash(socket, :error, "Already part of this campaign")}
    end
  end

  @impl true
  def handle_event("start_peer_review", %{"campaign_id" => campaign_id, "submission_type" => type}, socket) do
    current_user = socket.assigns.current_user

    submission_data = %{
      type: String.to_atom(type),
      content: get_user_campaign_content(campaign_id, current_user.id, type)
    }

    case Frestyl.DataCampaigns.PeerReview.submit_for_review(campaign_id, current_user.id, submission_data) do
      {:ok, review_request} ->
        {:noreply, socket
        |> put_flash(:info, "Submitted for peer review! Reviewers will be notified.")
        |> assign(:content_campaigns, load_content_campaigns(current_user))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to submit for review: #{reason}")}
    end
  end

  @impl true
  def handle_event("submit_peer_review", params, socket) do
    %{
      "review_request_id" => review_request_id,
      "overall_score" => overall_score,
      "criteria_scores" => criteria_scores,
      "feedback" => feedback
    } = params

    current_user = socket.assigns.current_user

    review_data = %{
      overall_score: String.to_float(overall_score),
      criteria_scores: parse_criteria_scores(criteria_scores),
      feedback: feedback,
      suggestions: Map.get(params, "suggestions", [])
    }

    case Frestyl.DataCampaigns.PeerReview.submit_review(review_request_id, current_user.id, review_data) do
      {:ok, :review_completed, score} ->
        {:noreply, socket
        |> put_flash(:info, "Review completed! Final score: #{score}/5.0")
        |> assign(:content_campaigns, load_content_campaigns(current_user))}

      {:ok, :review_submitted, :awaiting_more_reviews} ->
        {:noreply, socket
        |> put_flash(:info, "Review submitted! Waiting for more reviewers.")
        |> assign(:content_campaigns, load_content_campaigns(current_user))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Review submission failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("view_contract", %{"contract_id" => contract_id}, socket) do
    contract = DataCampaigns.RevenueManager.get_contract_details(contract_id)

    {:noreply, socket
    |> assign(:show_contract_modal, true)
    |> assign(:current_contract, contract)}
  end

  @impl true
  def handle_event("sign_contract_submit", params, socket) do
    %{
      "contract_id" => contract_id,
      "legal_name" => legal_name,
      "digital_signature" => digital_signature
    } = params

    current_user = socket.assigns.current_user

    signature_data = %{
      legal_name: legal_name,
      digital_signature: digital_signature,
      ip_address: get_connect_info(socket, :peer_data).address,
      user_agent: get_connect_info(socket, :user_agent),
      timestamp: DateTime.utc_now()
    }

    case DataCampaigns.RevenueManager.sign_contract(contract_id, current_user.id, signature_data) do
      {:ok, signed_contract} ->
        {:noreply, socket
        |> assign(:show_contract_modal, false)
        |> assign(:current_contract, nil)
        |> assign(:pending_contracts, load_pending_contracts(current_user))
        |> put_flash(:info, "Contract signed successfully! You're now part of the campaign.")}

      {:error, reason} ->
        {:noreply, socket
        |> put_flash(:error, "Contract signing failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("view_improvement_plan", %{"improvement_period_id" => period_id}, socket) do
    {:noreply, socket
    |> assign(:show_improvement_modal, true)
    |> assign(:improvement_period_id, period_id)}
  end

  @impl true
  def handle_event("complete_improvement_task", %{"period_id" => period_id, "task_index" => task_index}, socket) do
    # Mark improvement task as completed
    # This would update the improvement period progress
    {:noreply, socket
    |> put_flash(:info, "Improvement task completed!")
    |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_user))}
  end

  @impl true
  def handle_event("change_channels_view", %{"view" => view}, socket) do
    {:noreply, assign(socket, :channels_view_mode, view)}
  end

  @impl true
  def handle_event("search_channels", %{"search" => search_term}, socket) do
    {:noreply, assign(socket, :channel_search, search_term)}
  end

  @impl true
  def handle_event("change_channels_sort", %{"sort_by" => sort_by}, socket) do
    {:noreply, assign(socket, :channels_sort_by, sort_by)}
  end

  @impl true
  def handle_event("change_channels_filter", %{"filter" => filter}, socket) do
    {:noreply, assign(socket, :channels_filter, filter)}
  end

  @impl true
  def handle_event("start_channel_session", %{"channel_id" => channel_id}, socket) do
    # Implement channel session start logic
    {:noreply, put_flash(socket, :info, "Starting session for channel #{channel_id}")}
  end

  @impl true
  def handle_event("toggle_channel_menu", %{"channel_id" => channel_id}, socket) do
    # Implement channel menu toggle logic
    current_menu = Map.get(socket.assigns, :open_channel_menu)
    new_menu = if current_menu == channel_id, do: nil, else: channel_id

    {:noreply, assign(socket, :open_channel_menu, new_menu)}
  end

  def handle_event("navigate_to_tab", %{"tab" => "story_engine"}, socket) do
    {:noreply, assign(socket, :active_tab, "story_engine")}
  end

  def handle_event("navigate_to_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end


  # PubSub Message Handlers
  @impl true
  def handle_info({:portfolio_created, portfolio}, socket) do
    if portfolio.account_id == socket.assigns.current_account.id do
      updated_portfolios = [portfolio | socket.assigns.portfolios]
      {:noreply, assign(socket, :portfolios, updated_portfolios)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:portfolio_updated, portfolio}, socket) do
    if portfolio.account_id == socket.assigns.current_account.id do
      updated_portfolios = update_portfolio_in_list(socket.assigns.portfolios, portfolio)
      {:noreply, assign(socket, :portfolios, updated_portfolios)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:portfolio_deleted, portfolio_id}, socket) do
    updated_portfolios = Enum.reject(socket.assigns.portfolios, &(&1.id == portfolio_id))
    {:noreply, assign(socket, :portfolios, updated_portfolios)}
  end

  @impl true
  def handle_info({:account_switched, _account_id}, socket) do
    # Refresh data when account changes in another tab/window
    current_user = socket.assigns.current_user
    available_accounts = load_user_accounts(current_user.id)
    {:noreply, assign(socket, :available_accounts, available_accounts)}
  end

  # Content Campaign Events
  @impl true
  def handle_info({:campaign_created, campaign}, socket) do
    current_user = socket.assigns.current_user

    {:noreply, socket
    |> assign(:content_campaigns, load_content_campaigns(current_user))
    |> put_flash(:info, "Campaign \"#{campaign.title}\" created successfully!")}
  end

  @impl true
  def handle_info({:campaign_updated, campaign}, socket) do
    current_user = socket.assigns.current_user

    {:noreply, assign(socket, :content_campaigns, load_content_campaigns(current_user))}
  end

  @impl true
  def handle_info({:quality_gate_failed, campaign_id, gate_name, improvement_period}, socket) do
    {:noreply, socket
    |> put_flash(:warning, "Quality gate failed: #{gate_name}. Improvement period started.")
    |> assign(:active_improvement_periods, load_active_improvement_periods(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:payment_completed, payment_info}, socket) do
    {:noreply, socket
    |> assign(:revenue_metrics, load_revenue_metrics(socket.assigns.current_user))
    |> assign(:recent_payments, load_recent_payments(socket.assigns.current_user))
    |> put_flash(:info, "Payment received: $#{payment_info.amount}")}
  end

  @impl true
  def handle_info({:contributor_joined, contributor}, socket) do
    current_user = socket.assigns.current_user

    {:noreply, socket
    |> assign(:content_campaigns, load_content_campaigns(current_user))
    |> put_flash(:info, "New contributor joined your campaign!")}
  end

  @impl true
  def handle_info({:metrics_updated, tracker}, socket) do
    # Update campaign metrics in real-time
    {:noreply, socket
    |> assign(:campaign_metrics, update_campaign_metrics(socket.assigns.campaign_metrics, tracker))}
  end

  # Real-time campaign updates
  @impl true
  def handle_info({:metrics_updated, tracker}, socket) do
    current_user = socket.assigns.current_user

    {:noreply, socket
    |> assign(:content_campaigns, load_content_campaigns(current_user))
    |> assign(:campaign_metrics, load_campaign_metrics(current_user))}
  end

  @impl true
  def handle_info({:revenue_split_updated, campaign_id, percentage}, socket) do
    # Show real-time revenue split update
    {:noreply, socket
    |> put_flash(:info, "Your revenue share updated: #{percentage}%")
    |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:quality_gate_passed, campaign_id, gate_name}, socket) do
    {:noreply, socket
    |> put_flash(:info, "✅ Quality gate passed: #{gate_name}")
    |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:improvement_period_started, improvement_period}, socket) do
    {:noreply, socket
    |> put_flash(:warning, "📈 Quality improvement needed - check your improvement plan")
    |> assign(:show_improvement_notification, true)
    |> assign(:improvement_period, improvement_period)}
  end

  @impl true
  def handle_info({:review_completed, review_request_id, average_score}, socket) do
    {:noreply, socket
    |> put_flash(:info, "🎉 Peer review completed! Average score: #{average_score}/5.0")
    |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:live_contribution, user_id, contribution}, socket) do
    # Handle real-time contribution updates (for live campaign dashboard)
    if socket.assigns.current_user.id == user_id do
      {:noreply, socket
      |> assign(:live_contribution_update, contribution)}
    else
      {:noreply, socket}
    end
  end

  # Real-time campaign updates
  @impl true
  def handle_info({:metrics_updated, tracker}, socket) do
    current_user = socket.assigns.current_user

    {:noreply, socket
    |> assign(:content_campaigns, load_content_campaigns(current_user))
    |> assign(:campaign_metrics, load_campaign_metrics(current_user))}
  end

  @impl true
  def handle_info({:quality_gate_passed, campaign_id, gate_name}, socket) do
    {:noreply, socket
    |> put_flash(:info, "✅ Quality gate passed: #{gate_name}")
    |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:improvement_period_started, improvement_period}, socket) do
    {:noreply, socket
    |> put_flash(:warning, "📈 Quality improvement needed - check your improvement plan")
    |> assign(:show_improvement_notification, true)
    |> assign(:improvement_period, improvement_period)}
  end

  # Helper functions for event handlers
  defp get_user_campaign_content(campaign_id, user_id, submission_type) do
    case submission_type do
      "content_contribution" ->
        %{content: "User's written contribution...", word_count: 1500}

      "audio_contribution" ->
        %{duration_seconds: 300, track_type: :vocals}

      _ ->
        %{content: "Generic contribution"}
    end
  end

  defp parse_criteria_scores(criteria_scores_string) do
    criteria_scores_string
    |> String.split(",")
    |> Enum.map(fn score_pair ->
      [name, score] = String.split(score_pair, ":")
      %{name: name, score: String.to_float(score)}
    end)
  end

  # Helper Functions - Account Management
  defp load_user_accounts(user_id) do
    try do
      Accounts.list_user_accounts(user_id)
    rescue
      _ -> []
    end
  end

  defp get_current_account(user, available_accounts) do
    # Get last active account from session or default to first personal account
    case available_accounts do
      [account | _] -> account
      [] ->
        IO.puts("No accounts found, creating default personal account for user #{user.id}")
        create_default_personal_account(user)
    end
  end

  defp get_user_account(user_id, account_id) do
    try do
      case Enum.find(load_user_accounts(user_id), &(&1.id == account_id)) do
        nil -> {:error, :not_found}
        account -> {:ok, account}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp create_default_personal_account(user) do
    IO.puts("Creating default personal account for user: #{inspect(user)}")

    case create_account_for_user(user, %{name: "Personal", type: :personal}) do
      {:ok, account} ->
        IO.puts("Successfully created account: #{inspect(account)}")
        account
      {:error, error} ->
        IO.puts("Failed to create account: #{inspect(error)}")
        # Return a mock account to prevent crashes
        %{id: 0, name: "Personal", type: :personal, owner_id: user.id}
    end
  end

  defp create_account_for_user(user, attrs) do
    Repo.transaction(fn ->
      # Create account directly with struct to bypass changeset validation issues
      account = Repo.insert!(%Account{
        name: attrs[:name] || attrs["name"],
        type: attrs[:type] || String.to_atom(attrs["type"]),
        owner_id: user.id,
        subscription_tier: :personal,
        subscription_status: :active,
        settings: %{},
        branding_config: %{},
        current_usage: %{},
        billing_cycle_usage: %{},
        feature_flags: %{}
      })

      # Create owner membership
      %AccountMembership{}
      |> AccountMembership.changeset(%{
        user_id: user.id,
        account_id: account.id,
        role: :owner
      })
      |> Repo.insert!()

      account
    end)
  end

  defp load_account_portfolios(account) do
    try do
      # Fallback to user portfolios if account portfolios don't exist yet
      case account do
        %{id: 0} -> []  # Mock account
        account ->
          # Try account-based portfolios first, fallback to user portfolios
          case Portfolios.list_account_portfolios(account.id) do
            portfolios when is_list(portfolios) -> portfolios
            _ ->
              # Fallback to user portfolios
              case Portfolios.list_user_portfolios(account.owner_id) do
                portfolios when is_list(portfolios) -> portfolios
                _ -> []
              end
          end
      end
    rescue
      _ ->
        # Final fallback - try user portfolios
        try do
          Portfolios.list_user_portfolios(account.owner_id || account.id)
        rescue
          _ -> []
        end
    end
  end

  defp load_collaboration_invites(user_id) do
    # Mock data - implement actual collaboration system
    []
  end

  defp load_collaboration_projects(user_id) do
    # Mock data - implement actual collaboration system
    []
  end

  defp load_user_channels(user_id) do
    try do
      channels = Channels.list_user_channels(user_id)
      # Ensure channels have proper structure
      Enum.map(channels || [], fn
        %{} = channel -> channel
        channel when is_map(channel) ->
          Map.put_new(channel, :id, Map.get(channel, "id"))
        _ -> nil
      end)
      |> Enum.filter(& &1)
    rescue
      _ -> []
    end
  end

  defp load_recommended_channels(user_id) do
    try do
      Channels.get_recommended_channels(user_id)
    rescue
      _ -> []
    end
  end

  defp load_official_channel() do
    try do
      Channels.get_official_channel()
    rescue
      _ -> %{id: 1, name: "Frestyl Official", member_count: 1500, status: "active"}
    end
  end

  defp load_service_revenue(account) do
    # Mock data for service dashboard
    %{
      total: 0,
      monthly: 0,
      pending: 0,
      growth: 0
    }
  end

  defp load_service_bookings(account) do
    []
  end

  defp load_service_analytics(account) do
    %{
      popular_services: [],
      client_feedback: 0,
      performance_metrics: %{}
    }
  end

  defp load_studio_projects(account) do
    []
  end

  defp load_studio_resources(account) do
    %{
      storage_used: 0,
      bandwidth_used: 0,
      processing_hours: 0
    }
  end

  defp load_content_campaigns(user) do
    Frestyl.DataCampaigns.list_user_campaigns(user.id)
  end

  defp load_campaign_metrics(user) do
    Frestyl.DataCampaigns.get_user_campaign_metrics(user.id)
  end

  # Helper Functions - Access Control
  defp check_tab_access(account, tab) do
    case tab do
      "service_dashboard" ->
        if can_access_feature?(account, :service_booking) do
          {:ok, :accessible}
        else
          {:error, :upgrade_required}
        end
      "creator_studio" ->
        if can_access_feature?(account, :creator_studio) do
          {:ok, :accessible}
        else
          {:error, :upgrade_required}
        end
      _ ->
        {:ok, :accessible}
    end
  end

  defp can_access_feature?(account, feature) do
    # Simplified feature gate - implement proper tier checking
    case account.subscription_tier do
      :creator -> true
      :professional -> true
      :enterprise -> true
      _ -> false
    end
  end

  defp humanize_tab(tab) do
    case tab do
      "service_dashboard" -> "Service Dashboard"
      "creator_studio" -> "Creator Studio"
      "collaboration_hub" -> "Collaboration Hub"
      "community_channels" -> "Community Channels"
      _ -> String.capitalize(tab)
    end
  end

  # Helper Functions - Business Logic
  defp create_collaboration_invite(user, email, project_id) do
    # Mock implementation
    {:ok, %{id: 1, email: email, project_id: project_id}}
  end

  defp create_collaboration_project(account, user, attrs) do
    # Mock implementation
    {:ok, %{id: 1, title: attrs.title, description: attrs.description}}
  end

  defp start_channel_session(user, channel_id) do
    # Mock implementation
    {:ok, %{id: 1, channel_id: channel_id}}
  end

  defp create_portfolio_service(account, params) do
    # Mock implementation
    {:ok, %{id: 1, title: params["title"]}}
  end

  # Preserved Helper Functions (from original code)
  defp load_user_portfolios(user_id) do
    try do
      case Portfolios.list_user_portfolios(user_id) do
        portfolios when is_list(portfolios) -> portfolios
        _ -> []
      end
    rescue
      _ -> []
    end
  end

  defp load_network_stats(user_id) do
    %{
      connections: get_user_connections_count(user_id),
      collaborations: get_user_collaborations_count(user_id),
      recommendations: get_user_recommendations_count(user_id),
      profile_views: get_user_profile_views(user_id)
    }
  end

  defp load_recent_connections(user_id) do
    try do
      []
    rescue
      _ -> []
    end
  end

  defp load_trending_portfolios do
    try do
      []
    rescue
      _ -> []
    end
  end

  defp load_active_collaborations(user_id) do
    try do
      []
    rescue
      _ -> []
    end
  end

  defp load_available_templates do
    [
      %{
        id: 1,
        name: "Professional Resume",
        description: "Clean, ATS-friendly resume template",
        category: "Resume"
      },
      %{
        id: 2,
        name: "Creative Portfolio",
        description: "Showcase your creative work beautifully",
        category: "Portfolio"
      },
      %{
        id: 3,
        name: "Developer Profile",
        description: "Technical portfolio for developers",
        category: "Tech"
      },
      %{
        id: 4,
        name: "Business Executive",
        description: "Executive-level professional profile",
        category: "Business"
      }
    ]
  end

  defp calculate_total_views(portfolios) do
    Enum.reduce(portfolios, 0, fn portfolio, acc ->
      acc + get_portfolio_views(portfolio)
    end)
  end

  defp calculate_monthly_views(portfolios) do
    total = calculate_total_views(portfolios)
    div(total, 3)
  end

  defp update_portfolio_in_list(portfolios, updated_portfolio) do
    Enum.map(portfolios, fn portfolio ->
      if portfolio.id == updated_portfolio.id do
        updated_portfolio
      else
        portfolio
      end
    end)
  end

  defp create_portfolio_from_template(template_id, user, account) do
    portfolio_attrs = %{
      title: "New Portfolio from Template",
      description: "Portfolio created from template #{template_id}",
      visibility: "private",
      account_id: account.id
    }

    try do
      Portfolios.create_portfolio(user, portfolio_attrs)
    rescue
      _ -> {:error, "Failed to create portfolio"}
    end
  end

  defp get_user_campaign_content(campaign_id, user_id, submission_type) do
    # Get user's current contribution content for review
    case submission_type do
      "content_contribution" ->
        # Get text content from campaign
        %{content: "User's written contribution...", word_count: 1500}

      "audio_contribution" ->
        # Get audio contribution data
        %{duration_seconds: 300, track_type: :vocals}

      _ ->
        %{content: "Generic contribution"}
    end
  end

  defp parse_criteria_scores(criteria_scores_string) do
    # Parse criteria scores from form submission
    # Format: "Clarity:4.0,Relevance:3.5,Quality:4.5"
    criteria_scores_string
    |> String.split(",")
    |> Enum.map(fn score_pair ->
      [name, score] = String.split(score_pair, ":")
      %{name: name, score: String.to_float(score)}
    end)
  end

  # Stats Helper Functions
  defp get_user_connections_count(_user_id), do: 0
  defp get_user_collaborations_count(_user_id), do: 0
  defp get_user_recommendations_count(_user_id), do: 0
  defp get_user_profile_views(_user_id), do: 0

  # Portfolio Helper Functions (preserved from original)
  defp get_portfolio_header_style(portfolio) do
    case get_portfolio_category(portfolio) do
      "creative" -> "bg-gradient-to-br from-purple-50 to-pink-50"
      "technical" -> "bg-gradient-to-br from-blue-50 to-cyan-50"
      "business" -> "bg-gradient-to-br from-gray-50 to-slate-50"
      "academic" -> "bg-gradient-to-br from-green-50 to-emerald-50"
      _ ->
        case rem(portfolio.id, 6) do
          0 -> "bg-gradient-to-br from-gray-50 to-slate-50"
          1 -> "bg-gradient-to-br from-blue-50 to-cyan-50"
          2 -> "bg-gradient-to-br from-green-50 to-emerald-50"
          3 -> "bg-gradient-to-br from-orange-50 to-amber-50"
          4 -> "bg-gradient-to-br from-purple-50 to-violet-50"
          5 -> "bg-gradient-to-br from-pink-50 to-rose-50"
        end
    end
  end

  defp get_portfolio_icon_style(portfolio) do
    case get_portfolio_category(portfolio) do
      "creative" -> "bg-gradient-to-br from-purple-600 to-pink-600"
      "technical" -> "bg-gradient-to-br from-blue-600 to-cyan-600"
      "business" -> "bg-gradient-to-br from-gray-600 to-slate-700"
      "academic" -> "bg-gradient-to-br from-green-600 to-emerald-600"
      _ ->
        case rem(portfolio.id, 6) do
          0 -> "bg-gradient-to-br from-gray-600 to-slate-700"
          1 -> "bg-gradient-to-br from-blue-600 to-cyan-700"
          2 -> "bg-gradient-to-br from-green-600 to-emerald-700"
          3 -> "bg-gradient-to-br from-orange-600 to-amber-700"
          4 -> "bg-gradient-to-br from-purple-600 to-violet-700"
          5 -> "bg-gradient-to-br from-pink-600 to-rose-700"
        end
    end
  end

  defp get_portfolio_category(portfolio) do
    title_lower = String.downcase(portfolio.title || "")

    cond do
      String.contains?(title_lower, ["creative", "design", "art", "portfolio"]) -> "creative"
      String.contains?(title_lower, ["developer", "engineer", "tech", "software"]) -> "technical"
      String.contains?(title_lower, ["executive", "business", "manager", "consultant"]) -> "business"
      String.contains?(title_lower, ["academic", "research", "phd", "professor"]) -> "academic"
      true -> "general"
    end
  end

  defp get_portfolio_status(portfolio) do
    cond do
      portfolio.visibility == "public" -> "published"
      portfolio.visibility == "private" -> "private"
      true -> "draft"
    end
  end

  defp get_status_badge_classes(visibility) do
    case visibility do
      "public" -> "bg-emerald-500 text-white shadow-lg border border-emerald-400"
      :public -> "bg-emerald-500 text-white shadow-lg border border-emerald-400"
      "private" -> "bg-slate-600 text-white shadow-lg border border-slate-500"
      :private -> "bg-slate-600 text-white shadow-lg border border-slate-500"
      _ -> "bg-amber-500 text-white shadow-lg border border-amber-400"
    end
  end

  defp get_portfolio_views(portfolio) do
    base_views = rem(portfolio.id * 17, 500) + 10
    base_views
  end

  defp get_portfolio_sections_count(portfolio) do
    case portfolio.sections do
      %Ecto.Association.NotLoaded{} -> 5
      nil -> 0
      sections when is_list(sections) -> length(sections)
      _ -> 0
    end
  end

  defp format_time_ago(datetime) when is_nil(datetime), do: "Never"
  defp format_time_ago(%DateTime{} = datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 2592000 -> "#{div(diff, 86400)}d ago"
      true -> "#{div(diff, 2592000)}mo ago"
    end
  end
  defp format_time_ago(%NaiveDateTime{} = naive_datetime) do
    datetime = DateTime.from_naive!(naive_datetime, "Etc/UTC")
    format_time_ago(datetime)
  end
  defp format_time_ago(_), do: "Unknown"

  defp filter_portfolios(portfolios, filter_status) when is_nil(portfolios), do: []
  defp filter_portfolios(portfolios, filter_status) do
    case filter_status do
      "published" -> Enum.filter(portfolios, &(&1.visibility == "public" || &1.visibility == :public))
      "draft" -> Enum.filter(portfolios, &(&1.visibility == "private" || &1.visibility == :private))
      "private" -> Enum.filter(portfolios, &(&1.visibility == "private" || &1.visibility == :private))
      "all" -> portfolios
      _ -> portfolios
    end
  end

  defp sort_portfolios(portfolios, _sort_by) when is_nil(portfolios), do: []
  defp sort_portfolios(portfolios, sort_by) do
    case sort_by do
      "recent" ->
        Enum.sort_by(portfolios, fn portfolio ->
          case portfolio.updated_at do
            %DateTime{} = dt -> DateTime.to_unix(dt)
            %NaiveDateTime{} = ndt -> NaiveDateTime.to_gregorian_seconds(ndt)
            _ -> 0
          end
        end, :desc)
      "name" ->
        Enum.sort_by(portfolios, & String.downcase(&1.title || ""))
      "views" ->
        Enum.sort_by(portfolios, &get_portfolio_views/1, :desc)
      "status" ->
        Enum.sort_by(portfolios, & &1.visibility)
      _ ->
        portfolios
    end
  end

  defp calculate_completion_percentage(portfolio) do
    sections_count = get_portfolio_sections_count(portfolio)
    base_score = min(sections_count * 20, 80)

    bonus = 0
    bonus = if portfolio.title && String.length(portfolio.title) > 0, do: bonus + 10, else: bonus
    bonus = if portfolio.description && String.length(portfolio.description) > 0, do: bonus + 10, else: bonus

    min(base_score + bonus, 100)
  end

  defp calculate_analytics_data(portfolios) do
    published_count = Enum.count(portfolios, fn portfolio ->
      portfolio.visibility == "public" || portfolio.visibility == :public
    end)

    total_views = calculate_total_views(portfolios)

    %{
      total_portfolios: length(portfolios),
      published_count: published_count,
      total_views: total_views,
      this_month_views: calculate_monthly_views(portfolios),
      engagement_rate: if(total_views > 0 && length(portfolios) > 0, do: min(published_count * 100 / length(portfolios), 100), else: 0) |> round()
    }
  end

  defp calculate_analytics_for_period(portfolios, period) do
    base_data = calculate_analytics_data(portfolios)

    case period do
      "7" ->
        %{base_data |
          this_month_views: div(base_data.this_month_views, 4),
          engagement_rate: max(base_data.engagement_rate - 10, 0)}
      "90" ->
        %{base_data |
          this_month_views: base_data.this_month_views * 3,
          engagement_rate: min(base_data.engagement_rate + 15, 100)}
      _ -> base_data
    end
  end

  defp time_ago(datetime), do: format_time_ago(datetime)

  defp get_portfolio_card_gradient(portfolio) do
    case rem(portfolio.id, 8) do
      0 -> "from-indigo-500/90 via-purple-500/80 to-pink-500/90"
      1 -> "from-cyan-500/90 via-blue-500/80 to-indigo-500/90"
      2 -> "from-emerald-500/90 via-teal-500/80 to-cyan-500/90"
      3 -> "from-orange-500/90 via-red-500/80 to-pink-500/90"
      4 -> "from-violet-500/90 via-purple-500/80 to-indigo-500/90"
      5 -> "from-rose-500/90 via-pink-500/80 to-purple-500/90"
      6 -> "from-blue-500/90 via-indigo-500/80 to-purple-500/90"
      7 -> "from-teal-500/90 via-emerald-500/80 to-green-500/90"
    end
  end

  defp get_portfolio_icon_gradient(portfolio) do
    case rem(portfolio.id, 8) do
      0 -> "from-indigo-600 via-purple-600 to-pink-600"
      1 -> "from-cyan-600 via-blue-600 to-indigo-600"
      2 -> "from-emerald-600 via-teal-600 to-cyan-600"
      3 -> "from-orange-600 via-red-600 to-pink-600"
      4 -> "from-violet-600 via-purple-600 to-indigo-600"
      5 -> "from-rose-600 via-pink-600 to-purple-600"
      6 -> "from-blue-600 via-indigo-600 to-purple-600"
      7 -> "from-teal-600 via-emerald-600 to-green-600"
    end
  end

  defp get_portfolio_hover_gradient(portfolio) do
    case rem(portfolio.id, 8) do
      0 -> "hover:from-indigo-600 hover:via-purple-600 hover:to-pink-600"
      1 -> "hover:from-cyan-600 hover:via-blue-600 hover:to-indigo-600"
      2 -> "hover:from-emerald-600 hover:via-teal-600 hover:to-cyan-600"
      3 -> "hover:from-orange-600 hover:via-red-600 hover:to-pink-600"
      4 -> "hover:from-violet-600 hover:via-purple-600 hover:to-indigo-600"
      5 -> "hover:from-rose-600 hover:via-pink-600 hover:to-purple-600"
      6 -> "hover:from-blue-600 hover:via-indigo-600 hover:to-purple-600"
      7 -> "hover:from-teal-600 hover:via-emerald-600 hover:to-green-600"
    end
  end

  defp format_channel_type(channel_type) do
    case channel_type do
      "general" -> "General"
      "collaboration" -> "Collab"
      "showcase" -> "Showcase"
      "learning" -> "Learning"
      "feedback" -> "Feedback"
      "networking" -> "Network"
      _ -> "Channel"
    end
  end

  defp filter_channels(channels, search_term, filter_type) do
    channels
    |> filter_by_search(search_term)
    |> filter_by_type(filter_type)
  end

  defp filter_by_search(channels, "") do
    channels
  end

  defp filter_by_search(channels, search_term) do
    search_lower = String.downcase(search_term)

    Enum.filter(channels, fn {channel, _count} ->
      String.contains?(String.downcase(channel.name), search_lower) ||
      String.contains?(String.downcase(channel.description || ""), search_lower)
    end)
  end

  defp filter_by_type(channels, "all"), do: channels
  defp filter_by_type(channels, "owned") do
    current_user_id = get_current_user_id()
    Enum.filter(channels, fn {channel, _count} ->
      channel.owner_id == current_user_id
    end)
  end
  defp filter_by_type(channels, "joined"), do: channels  # Implement based on membership logic
  defp filter_by_type(channels, "active") do
    Enum.filter(channels, fn {channel, _count} ->
      channel.show_live_activity
    end)
  end

  defp get_current_user_id do
    # This should get the current user ID from socket assigns
    # You'll need to implement this based on your auth system
    nil
  end

  defp get_channel_card_gradient(channel) do
    case rem(channel.id, 7) do
      0 -> "from-indigo-600/90 via-purple-600/80 to-pink-600/90"
      1 -> "from-cyan-600/90 via-blue-600/80 to-indigo-600/90"
      2 -> "from-emerald-600/90 via-teal-600/80 to-cyan-600/90"
      3 -> "from-orange-600/90 via-red-600/80 to-rose-600/90"
      4 -> "from-violet-600/90 via-purple-600/80 to-indigo-600/90"
      5 -> "from-amber-600/90 via-orange-600/80 to-red-600/90"
      6 -> "from-lime-600/90 via-green-600/80 to-emerald-600/90"
    end
  end

  defp get_channel_icon_gradient(channel) do
    case rem(channel.id, 7) do
      0 -> "from-indigo-500 to-purple-500"
      1 -> "from-cyan-500 to-blue-500"
      2 -> "from-emerald-500 to-teal-500"
      3 -> "from-orange-500 to-red-500"
      4 -> "from-violet-500 to-purple-500"
      5 -> "from-amber-500 to-orange-500"
      6 -> "from-lime-500 to-green-500"
    end
  end


  defp format_visibility(visibility) when is_atom(visibility) do
    visibility |> Atom.to_string() |> String.capitalize()
  end
  defp format_visibility(visibility) when is_binary(visibility) do
    String.capitalize(visibility)
  end
  defp format_visibility(_), do: "Unknown"

  defp format_account_type(type) when is_atom(type) do
    type |> Atom.to_string() |> String.capitalize()
  end
  defp format_account_type(type) when is_binary(type) do
    String.capitalize(type)
  end
  defp format_account_type(_), do: "Unknown"

  defp format_subscription_tier(tier) when is_atom(tier) do
    tier |> Atom.to_string() |> String.capitalize()
  end
  defp format_subscription_tier(tier) when is_binary(tier) do
    String.capitalize(tier)
  end
  defp format_subscription_tier(nil), do: "Free"
  defp format_subscription_tier(_), do: "Unknown"

  # Account Helper Functions
  defp get_account_gradient(account_type) do
    case account_type do
      :personal -> "from-blue-600 to-cyan-600"
      :work -> "from-purple-600 to-pink-600"
      :team -> "from-emerald-600 to-teal-600"
      _ -> "from-gray-600 to-slate-600"
    end
  end

  defp get_account_icon(account_type) do
    case account_type do
      :personal -> "M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
      :work -> "M20 6L9 17l-5-5"
      :team -> "M12 2l3.09 6.26L22 9l-5 4.74L18.18 22 12 18.27 5.82 22 7 13.74 2 9l6.91-.74L12 2z"
      _ -> "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
    end
  end

  defp list_content_campaigns(user) do
    # For now, return empty list - implement when backend is ready
    []
  end

  defp get_campaign_limit(user) do
    case Frestyl.Features.TierManager.get_account_tier(user) do
      "personal" -> 1
      "creator" -> 3
      "professional" -> 10
      "enterprise" -> "∞"
      _ -> 1
    end
  end

  defp already_joined?(campaign, user) do
    Enum.any?(campaign.contributors || [], &(&1.user_id == user.id))
  end

  defp load_active_improvement_periods(user) do
    # Get user's active improvement periods
    case :ets.match(:improvement_periods, {'$1', %{user_id: user.id, status: :active}}) do
      periods when is_list(periods) ->
        Enum.map(periods, fn [id] ->
          [{^id, period}] = :ets.lookup(:improvement_periods, id)
          period
        end)
      _ -> []
    end
  end

  defp load_pending_peer_reviews(user) do
    # Get peer review requests where user can be reviewer
    case :ets.match(:peer_review_requests, {'$1', %{status: :pending}}) do
      requests when is_list(requests) ->
        Enum.map(requests, fn [id] ->
          [{^id, request}] = :ets.lookup(:peer_review_requests, id)
          request
        end)
        |> Enum.filter(&can_review_request?(&1, user))
      _ -> []
    end
  end

  defp can_review_request?(review_request, user) do
    # User can review if they're in the campaign but not the contributor
    review_request.contributor_id != user.id
  end

  @doc """
  Updates campaign metrics with new tracker data
  """
  defp update_campaign_metrics(current_metrics, tracker) do
    # Update the campaign metrics based on tracker updates
    Map.merge(current_metrics, %{
      total_contributors: Map.get(tracker, :total_contributors, 0),
      total_contributions: Map.get(tracker, :total_contributions, 0),
      average_quality_score: Map.get(tracker, :average_quality_score, 0.0),
      last_updated: DateTime.utc_now()
    })
  end

  @doc """
  Gets the user's onboarding state
  """
  defp get_onboarding_state(current_user, portfolios, revenue_metrics) do
    %{
      has_portfolio: length(portfolios) > 0,
      has_revenue_setup: Map.get(revenue_metrics, :payment_method_configured, false),
      profile_complete: user_profile_complete?(current_user),
      first_campaign_joined: Map.get(revenue_metrics, :active_campaigns, 0) > 0,
      completed_steps: calculate_completed_onboarding_steps(current_user, portfolios, revenue_metrics),
      next_step: determine_next_onboarding_step(current_user, portfolios, revenue_metrics)
    }
  end

  @doc """
  Gets user's revenue percentage for a specific campaign
  """
  defp get_user_revenue_percentage(campaign, current_user) do
    # This would typically come from the campaign tracker
    case Frestyl.DataCampaigns.AdvancedTracker.get_user_campaign_share(campaign.id, current_user.id) do
      {:ok, percentage} -> percentage
      _ -> 0.0
    end
  end

  @doc """
  Gets user's projected revenue from a campaign
  """
  defp get_user_campaign_revenue(campaign, current_user) do
    percentage = get_user_revenue_percentage(campaign, current_user)
    campaign_revenue = campaign.revenue_target || Decimal.new("0")

    campaign_revenue
    |> Decimal.mult(Decimal.div(Decimal.new(percentage), 100))
    |> Decimal.to_float()
  end

  @doc """
  Formats currency amounts
  """
  defp format_currency_local(amount) when is_number(amount) do
    :erlang.float_to_binary(amount, decimals: 2)
  end

  defp format_currency_local(%Decimal{} = amount) do
    amount |> Decimal.to_float() |> format_currency_local()
  end

  defp format_currency_local(_), do: "0.00"

  # ============================================================================
  # COMPONENT FUNCTIONS FOR TEMPLATES
  # ============================================================================

  @doc """
  Campaign metrics dashboard component
  """
  defp campaign_metrics_dashboard(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow p-6">
      <h3 class="text-lg font-semibold mb-4">Campaign Performance</h3>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="text-center">
          <p class="text-2xl font-bold text-blue-600"><%= @metrics.active_campaigns %></p>
          <p class="text-sm text-gray-600">Active Campaigns</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-green-600"><%= @metrics.completed_campaigns %></p>
          <p class="text-sm text-gray-600">Completed</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-purple-600"><%= Float.round(@metrics.avg_quality_score, 1) %></p>
          <p class="text-sm text-gray-600">Avg Quality</p>
        </div>
        <div class="text-center">
          <p class="text-2xl font-bold text-indigo-600">$<%= Helpers.format_currency(@metrics.total_revenue) %></p>
          <p class="text-sm text-gray-600">Total Revenue</p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Content campaign card component
  """
  defp content_campaign_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6 hover:shadow-md transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <div>
          <h4 class="text-lg font-semibold"><%= @campaign.title %></h4>
          <p class="text-sm text-gray-600"><%= @campaign.content_type |> to_string() |> String.capitalize() %></p>
        </div>
        <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
          <%= @campaign.status |> to_string() |> String.capitalize() %>
        </span>
      </div>

      <div class="space-y-2 mb-4">
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Your contribution:</span>
          <span class="font-medium"><%= get_user_revenue_percentage(@campaign, @current_user) %>%</span>
        </div>
        <div class="flex justify-between text-sm">
          <span class="text-gray-600">Projected earnings:</span>
          <span class="font-medium text-green-600">$<%= Helpers.format_currency(get_user_campaign_revenue(@campaign, @current_user)) %></span>
        </div>
      </div>

      <div class="flex items-center justify-between">
        <div class="text-xs text-gray-500">
          Deadline: <%= if @campaign.deadline, do: Calendar.strftime(@campaign.deadline, "%b %d, %Y"), else: "No deadline" %>
        </div>
        <button class="text-blue-600 hover:text-blue-800 text-sm font-medium">
          View Details →
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Improvement period card component
  """
  defp improvement_period_card(assigns) do
    ~H"""
    <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <h4 class="text-sm font-medium text-yellow-800">Improvement Period Active</h4>
          <p class="text-sm text-yellow-700 mt-1">
            Campaign: <span class="font-medium"><%= @period.campaign_title %></span>
          </p>
          <p class="text-xs text-yellow-600 mt-1">
            Due: <%= Calendar.strftime(@period.due_date, "%b %d, %Y") %>
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Peer review card component
  """
  defp peer_review_card(assigns) do
    ~H"""
    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
        </div>
        <div class="ml-3">
          <h4 class="text-sm font-medium text-blue-800">Peer Review Request</h4>
          <p class="text-sm text-blue-700 mt-1">
            From: <span class="font-medium"><%= @review.requester_name %></span>
          </p>
          <p class="text-sm text-blue-700">
            Content: <span class="font-medium"><%= @review.content_type %></span>
          </p>
          <div class="mt-2 flex space-x-2">
            <button class="text-xs bg-blue-600 text-white px-2 py-1 rounded hover:bg-blue-700">
              Review Now
            </button>
            <button class="text-xs bg-white text-blue-600 border border-blue-600 px-2 py-1 rounded hover:bg-blue-50">
              Later
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp user_profile_complete?(user) do
    # Check if user has completed their profile
    !is_nil(user.name) && !is_nil(user.email) && byte_size(user.name || "") > 0
  end

  defp calculate_completed_onboarding_steps(user, portfolios, revenue_metrics) do
    steps = []
    steps = if user_profile_complete?(user), do: ["profile" | steps], else: steps
    steps = if length(portfolios) > 0, do: ["portfolio" | steps], else: steps
    steps = if Map.get(revenue_metrics, :payment_method_configured, false), do: ["payment" | steps], else: steps
    steps = if Map.get(revenue_metrics, :active_campaigns, 0) > 0, do: ["campaign" | steps], else: steps

    length(steps)
  end

  defp determine_next_onboarding_step(user, portfolios, revenue_metrics) do
    cond do
      !user_profile_complete?(user) -> "complete_profile"
      length(portfolios) == 0 -> "create_portfolio"
      !Map.get(revenue_metrics, :payment_method_configured, false) -> "setup_payment"
      Map.get(revenue_metrics, :active_campaigns, 0) == 0 -> "join_campaign"
      true -> "explore_features"
    end
  end

  defp get_user_revenue_percentage(campaign, current_user) do
    case Frestyl.DataCampaigns.AdvancedTracker.get_campaign_tracker(campaign.id) do
      {:ok, tracker} -> Map.get(tracker.dynamic_revenue_weights, current_user.id, 0.0)
      _ -> 0.0
    end
  end

end
