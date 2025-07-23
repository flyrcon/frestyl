# lib/frestyl_web/live/collaboration_live.ex
defmodule FrestylWeb.CollaborationLive do
  use FrestylWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to necessary topics for real-time updates
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "collaboration:updates")
    end

    {:ok, assign(socket,
      page_title: "Collaboration Hub",
      active_collaborations: [],
      invitations: [],
      mobile_menu_open: false,
      active_section: "overview",  # overview, content_creation, live_sessions
      content_campaigns: [],
      show_campaign_modal: false,
      campaign_limits: %{concurrent_campaigns: 3, max_platforms: 5, monthly_publishes: 50},
      story_templates: []
    )}
  end

  @impl true
  def handle_event("switch_section", %{"section" => section}, socket) do
    # Load section-specific data
    socket = case section do
      "content_creation" ->
        socket
        |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_account))
        |> assign(:story_templates, load_story_templates())
        |> assign(:campaign_limits, get_campaign_limits(socket.assigns.current_account))

      "live_sessions" ->
        socket
        |> assign(:active_collaborations, load_active_sessions(socket.assigns.current_user))

      _ ->
        socket
    end

    {:noreply, assign(socket, :active_section, section)}
  end

  @impl true
  def handle_event("show_create_campaign_modal", _params, socket) do
    {:noreply, assign(socket, :show_campaign_modal, true)}
  end

  @impl true
  def handle_event("close_campaign_modal", _params, socket) do
    {:noreply, assign(socket, :show_campaign_modal, false)}
  end

  @impl true
  def handle_event("create_content_campaign", params, socket) do
    account = socket.assigns.current_account
    user = socket.assigns.current_user

    # Check campaign limits
    current_campaigns = length(socket.assigns.content_campaigns)
    limit = socket.assigns.campaign_limits.concurrent_campaigns

    if current_campaigns >= limit do
      {:noreply, socket
      |> put_flash(:error, "Campaign limit reached. Upgrade your plan for more campaigns.")
      |> push_navigate(to: "/subscription")}
    else
      case create_campaign(params, account, user) do
        {:ok, campaign} ->
          # Track story lab usage if template was used
          if params["story_template"] do
            try do
              Frestyl.Stories.track_story_lab_usage(user.id, :story_created, %{
                context: "content_campaign",
                campaign_id: campaign.id,
                template_id: params["story_template"]
              })
            rescue
              _ -> :ok  # Continue even if tracking fails
            end
          end

          {:noreply, socket
          |> assign(:content_campaigns, load_content_campaigns(account))
          |> assign(:show_campaign_modal, false)
          |> put_flash(:info, "Content campaign created successfully! #{if params["story_template"], do: "Story structure applied.", else: ""}")}

        {:error, reason} ->
          {:noreply, socket |> put_flash(:error, format_error(reason))}
      end
    end
  end

  @impl true
  def handle_event("join_campaign", %{"campaign_id" => campaign_id}, socket) do
    user = socket.assigns.current_user

    case join_content_campaign(campaign_id, user) do
      {:ok, _} ->
        {:noreply, socket
        |> assign(:content_campaigns, load_content_campaigns(socket.assigns.current_account))
        |> put_flash(:info, "Successfully joined campaign!")}

      {:error, reason} ->
        {:noreply, socket |> put_flash(:error, format_error(reason))}
    end
  end


  @impl true
  def handle_event("toggle_mobile_menu", _, socket) do
    {:noreply, assign(socket, mobile_menu_open: !socket.assigns.mobile_menu_open)}
  end

  @impl true
  def handle_event("create_collaboration", %{"type" => type}, socket) do
    # Logic to create a new collaboration space
    # Would interact with a context module

    {:noreply, socket}
  end

  @impl true
  def handle_event("join_collaboration", %{"id" => id}, socket) do
    # Logic to join an existing collaboration

    {:noreply, socket}
  end

  def handle_params(_params, _uri, socket) do
    tabs = [
      # Existing tabs...
      %{id: "content", label: "Content Campaigns", icon: "document-text",
        component: FrestylWeb.CollaborationHubLive.ContentCampaigns}
    ]

    {:noreply, assign(socket, :tabs, tabs)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Mobile-First Header -->
      <div class="flex flex-col space-y-4 md:flex-row md:items-center md:justify-between md:space-y-0">
        <div class="flex-1 min-w-0">
          <h2 class="text-2xl font-bold leading-7 text-gray-900 sm:text-3xl sm:truncate">
            Collaboration Hub
          </h2>
          <p class="mt-1 text-sm text-gray-500">Create, collaborate, and publish content together</p>
        </div>

        <!-- Mobile Menu Toggle -->
        <div class="md:hidden">
          <button
            phx-click="toggle_mobile_menu"
            class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Section Navigation - Mobile Optimized -->
      <div class={[
        "mt-6 border-b border-gray-200",
        if(@mobile_menu_open, do: "block", else: "hidden md:block")
      ]}>
        <nav class="flex flex-col md:flex-row md:space-x-8 space-y-2 md:space-y-0">
          <%= for {section_id, section_name, icon} <- [
            {"overview", "Overview", "home"},
            {"content_creation", "Content Creation", "document-text"},
            {"live_sessions", "Live Sessions", "users"}
          ] do %>
            <button
              phx-click="switch_section"
              phx-value-section={section_id}
              class={[
                "flex items-center space-x-2 py-4 px-1 border-b-2 font-medium text-sm transition-colors w-full md:w-auto justify-center md:justify-start",
                if(@active_section == section_id,
                  do: "border-indigo-500 text-indigo-600",
                  else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
              ]}>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <%= case icon do %>
                  <% "home" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 7v10a2 2 0 002 2h14a2 2 0 002-2V9a2 2 0 00-2-2H5a2 2 0 00-2-2z"/>
                  <% "document-text" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  <% "users" -> %>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197m13.5-9a2.5 2.5 0 11-5 0 2.5 2.5 0 015 0z"/>
                <% end %>
              </svg>
              <span><%= section_name %></span>
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Section Content -->
      <div class="mt-8">
        <%= case @active_section do %>
          <% "content_creation" -> %>
            <.render_content_creation_section {assigns} />
          <% "live_sessions" -> %>
            <.render_live_sessions_section {assigns} />
          <% _ -> %>
            <.render_overview_section {assigns} />
        <% end %>
      </div>

      <!-- Campaign Creation Modal -->
      <%= if @show_campaign_modal do %>
        <.render_campaign_modal {assigns} />
      <% end %>
    </div>
    """
  end

  # Content Creation Section Component
  defp render_content_creation_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Section Header with Quick Actions -->
      <div class="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
        <div class="flex flex-col space-y-4 sm:flex-row sm:items-center sm:justify-between sm:space-y-0">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Content Creation Campaigns</h3>
            <p class="text-sm text-gray-600 mt-1">Collaborate on content and share revenue</p>
          </div>

          <button
            phx-click="show_create_campaign_modal"
            class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 transition-colors">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
            New Campaign
          </button>

          <!-- Story Lab Integration Button -->
          <.link
            navigate={~p"/portfolio_hub?tab=story_lab"}
            class="inline-flex items-center px-4 py-2 border border-purple-600 text-purple-600 rounded-md hover:bg-purple-50 transition-colors text-sm font-medium">
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>
            Story Lab
          </.link>
        </div>

        <!-- Campaign Limits Bar -->
        <div class="mt-4 bg-gray-50 rounded-lg p-4">
          <div class="flex items-center justify-between text-sm">
            <span class="text-gray-600">Active Campaigns</span>
            <span class="font-medium text-gray-900">
              <%= length(@content_campaigns) %>/<%= if @campaign_limits.concurrent_campaigns == :unlimited, do: "∞", else: @campaign_limits.concurrent_campaigns %>
            </span>
          </div>
          <%= unless @campaign_limits.concurrent_campaigns == :unlimited do %>
            <div class="mt-2 w-full bg-gray-200 rounded-full h-2">
              <div
                class="bg-indigo-600 h-2 rounded-full transition-all"
                style={"width: #{min(100, (length(@content_campaigns) / @campaign_limits.concurrent_campaigns) * 100)}%"}>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Campaigns Grid - Mobile Optimized -->
      <%= if length(@content_campaigns) > 0 do %>
        <div class="grid gap-4 sm:gap-6 lg:grid-cols-2 xl:grid-cols-3">
          <%= for campaign <- @content_campaigns do %>
            <.render_campaign_card campaign={campaign} current_user={@current_user} />
          <% end %>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-12">
          <div class="w-16 h-16 bg-indigo-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">No content campaigns yet</h3>
          <p class="text-gray-600 mb-6 max-w-sm mx-auto">
            Start collaborating on content creation. Write, create videos, or build tutorials together.
          </p>
          <button
            phx-click="show_create_campaign_modal"
            class="inline-flex items-center px-6 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-indigo-600 hover:bg-indigo-700">
            Create Your First Campaign
          </button>
        </div>
      <% end %>

      <!-- Quick Stats Row -->
      <div class="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <div class="text-2xl font-bold text-green-600"><%= Enum.count(@content_campaigns, &(&1.status == "completed")) %></div>
          <div class="text-sm text-gray-600">Completed</div>
        </div>
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <div class="text-2xl font-bold text-blue-600"><%= Enum.count(@content_campaigns, &(&1.status == "active")) %></div>
          <div class="text-sm text-gray-600">Active</div>
        </div>
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <div class="text-2xl font-bold text-purple-600"><%= get_total_collaborators(@content_campaigns) %></div>
          <div class="text-sm text-gray-600">Collaborators</div>
        </div>
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <div class="text-2xl font-bold text-yellow-600">5</div>
          <div class="text-sm text-gray-600">Platforms</div>
        </div>
      </div>
    </div>
    """
  end

  # Campaign Card Component
  defp render_campaign_card(assigns) do
    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
      <!-- Campaign Header -->
      <div class="p-4 border-b border-gray-100">
        <div class="flex justify-between items-start mb-2">
          <h4 class="text-sm font-semibold text-gray-900 line-clamp-2 flex-1"><%= @campaign.title %></h4>
          <span class={"ml-2 px-2 py-1 text-xs rounded-full #{status_class(@campaign.status)}"}>
            <%= String.capitalize(@campaign.status) %>
          </span>
        </div>

        <p class="text-gray-600 text-xs line-clamp-2 mb-3"><%= @campaign.description %></p>

        <!-- Story Lab Integration Badge -->
        <%= if @campaign[:story_structure_id] do %>
          <div class="mb-3">
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
              <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
              Story Structure
            </span>
          </div>
        <% end %>

        <!-- Campaign Meta -->
        <div class="flex items-center justify-between text-xs text-gray-500">
          <div class="flex items-center space-x-3">
            <span class="flex items-center">
              <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.196-2.121M9 4a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
              <%= length(@campaign.contributors) %>/<%= @campaign.max_contributors %>
            </span>

            <%= if @campaign.deadline do %>
              <span class="flex items-center">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <%= Calendar.strftime(@campaign.deadline, "%b %d") %>
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Campaign Content -->
      <div class="p-4">
        <!-- Target Platforms -->
        <%= if length(@campaign.target_platforms) > 0 do %>
          <div class="mb-3">
            <div class="flex flex-wrap gap-1">
              <%= for platform <- Enum.take(@campaign.target_platforms, 3) do %>
                <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                  <%= String.capitalize(platform) %>
                </span>
              <% end %>
              <%= if length(@campaign.target_platforms) > 3 do %>
                <span class="px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded-full">
                  +<%= length(@campaign.target_platforms) - 3 %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>

        <!-- Contributors Avatars -->
        <div class="flex items-center justify-between mb-3">
          <div class="flex -space-x-2">
            <%= for contributor <- Enum.take(@campaign.contributors, 4) do %>
              <img class="inline-block h-6 w-6 rounded-full ring-2 ring-white" src={contributor.avatar} alt={contributor.name}>
            <% end %>
            <%= if length(@campaign.contributors) > 4 do %>
              <div class="inline-flex items-center justify-center h-6 w-6 rounded-full ring-2 ring-white bg-gray-100 text-xs font-medium text-gray-500">
                +<%= length(@campaign.contributors) - 4 %>
              </div>
            <% end %>
          </div>

          <span class="text-xs text-gray-500">
            <%= String.capitalize(@campaign.type |> String.replace("_", " ")) %>
          </span>
        </div>

        <!-- Actions with Story Lab Integration -->
        <div class="space-y-2">
          <div class="flex space-x-2">
            <button class="flex-1 bg-indigo-600 text-white text-center px-3 py-2 rounded-md hover:bg-indigo-700 transition-colors text-xs font-medium">
              View Details
            </button>

            <%= if @campaign.status == "open" and not already_joined?(@campaign, @current_user) do %>
              <button
                phx-click="join_campaign"
                phx-value-campaign_id={@campaign.id}
                class="px-3 py-2 border border-indigo-600 text-indigo-600 rounded-md hover:bg-indigo-50 transition-colors text-xs font-medium">
                Join
              </button>
            <% end %>
          </div>

          <!-- Story Lab Quick Actions -->
          <%= if @campaign[:story_structure_id] do %>
            <div class="flex space-x-2 pt-2 border-t border-gray-100">
              <.link
                navigate={~p"/stories/#{@campaign.story_structure_id}/edit"}
                class="flex-1 text-center px-3 py-2 text-xs font-medium text-purple-600 hover:text-purple-700 border border-purple-200 rounded-md hover:bg-purple-50 transition-colors">
                <svg class="w-3 h-3 inline mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
                Edit Structure
              </.link>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_overview_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Quick Action Cards Grid -->
      <div class="grid gap-4 sm:gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <!-- Content Creation Card -->
        <div class="bg-gradient-to-br from-purple-50 to-indigo-50 rounded-lg p-6 border border-purple-200 hover:shadow-md transition-shadow">
          <div class="flex items-center mb-4">
            <div class="w-10 h-10 bg-purple-600 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
            </div>
            <h3 class="ml-3 text-lg font-semibold text-gray-900">Content Creation</h3>
          </div>
          <p class="text-gray-600 text-sm mb-4">Collaborate on blogs, videos, tutorials, and social content with revenue sharing.</p>
          <button
            phx-click="switch_section"
            phx-value-section="content_creation"
            class="w-full bg-purple-600 text-white px-4 py-2 rounded-md hover:bg-purple-700 transition-colors text-sm font-medium">
            Start Creating
          </button>
        </div>

        <!-- Live Sessions Card -->
        <div class="bg-gradient-to-br from-orange-50 to-red-50 rounded-lg p-6 border border-orange-200 hover:shadow-md transition-shadow">
          <div class="flex items-center mb-4">
            <div class="w-10 h-10 bg-orange-600 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
            </div>
            <h3 class="ml-3 text-lg font-semibold text-gray-900">Live Sessions</h3>
          </div>
          <p class="text-gray-600 text-sm mb-4">Real-time collaboration for music, visual arts, and creative projects.</p>
          <button
            phx-click="switch_section"
            phx-value-section="live_sessions"
            class="w-full bg-orange-600 text-white px-4 py-2 rounded-md hover:bg-orange-700 transition-colors text-sm font-medium">
            Join Session
          </button>
        </div>

        <!-- Coming Soon Card -->
        <div class="bg-gradient-to-br from-gray-50 to-blue-50 rounded-lg p-6 border border-gray-200 opacity-75">
          <div class="flex items-center mb-4">
            <div class="w-10 h-10 bg-gray-400 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
              </svg>
            </div>
            <h3 class="ml-3 text-lg font-semibold text-gray-900">Project Matching</h3>
          </div>
          <p class="text-gray-600 text-sm mb-4">AI-powered matching with creators who complement your skills.</p>
          <div class="w-full bg-gray-300 text-gray-500 px-4 py-2 rounded-md text-sm font-medium text-center">
            Coming Soon
          </div>
        </div>
      </div>

      <!-- Recent Activity Summary -->
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Recent Activity</h3>
        <div class="space-y-3">
          <div class="flex items-center space-x-3 p-3 bg-green-50 rounded-lg">
            <div class="w-8 h-8 bg-green-500 rounded-full flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900">Content campaign completed</p>
              <p class="text-xs text-gray-500">"AI in Creative Work" series published • 2 hours ago</p>
            </div>
          </div>

          <div class="flex items-center space-x-3 p-3 bg-blue-50 rounded-lg">
            <div class="w-8 h-8 bg-blue-500 rounded-full flex items-center justify-center">
              <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="text-sm font-medium text-gray-900">New collaborator joined</p>
              <p class="text-xs text-gray-500">Alex Kim joined "Video Tutorial Series" • 1 day ago</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Live Sessions Section Component
  defp render_live_sessions_section(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Section Header -->
      <div class="bg-white rounded-lg p-6 shadow-sm border border-gray-200">
        <div class="flex flex-col space-y-4 sm:flex-row sm:items-center sm:justify-between sm:space-y-0">
          <div>
            <h3 class="text-lg font-semibold text-gray-900">Live Collaboration Sessions</h3>
            <p class="text-sm text-gray-600 mt-1">Real-time creative collaboration spaces</p>
          </div>

          <div class="flex flex-col space-y-2 sm:flex-row sm:space-y-0 sm:space-x-3">
            <button
              phx-click="create_collaboration"
              phx-value-type="music"
              class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
              </svg>
              Music Session
            </button>
            <button
              phx-click="create_collaboration"
              phx-value-type="visual"
              class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-purple-600 hover:bg-purple-700">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h3a1 1 0 011 1v1a1 1 0 01-1 1v9a2 2 0 01-2 2H6a2 2 0 01-2-2V7a1 1 0 01-1-1V5a1 1 0 011-1h3z"/>
              </svg>
              Visual Session
            </button>
          </div>
        </div>
      </div>

      <!-- Active Sessions -->
      <%= if length(@active_collaborations) > 0 do %>
        <div class="grid gap-4 sm:gap-6 lg:grid-cols-2">
          <%= for session <- @active_collaborations do %>
            <div class="bg-white overflow-hidden shadow-sm rounded-lg border border-gray-200">
              <div class="px-4 py-5 sm:px-6">
                <div class="flex items-center justify-between">
                  <h3 class="text-lg leading-6 font-medium text-gray-900"><%= session.title %></h3>
                  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                    <span class="w-2 h-2 bg-green-400 rounded-full mr-1 animate-pulse"></span>
                    Live
                  </span>
                </div>
                <p class="mt-1 max-w-2xl text-sm text-gray-500">
                  Session started <%= format_time_ago(session.started_at) %>
                </p>
              </div>
              <div class="px-4 py-5 sm:p-6">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <div class="flex -space-x-2 overflow-hidden">
                      <%= for participant <- Enum.take(session.participants, 3) do %>
                        <img class="inline-block h-8 w-8 rounded-full ring-2 ring-white" src="https://via.placeholder.com/150" alt={participant.name}>
                      <% end %>
                      <%= if length(session.participants) > 3 do %>
                        <div class="inline-flex items-center justify-center h-8 w-8 rounded-full ring-2 ring-white bg-gray-100 text-xs font-medium text-gray-500">
                          +<%= length(session.participants) - 3 %>
                        </div>
                      <% end %>
                    </div>
                    <span class="ml-2 text-sm text-gray-500"><%= length(session.participants) %> participants</span>
                  </div>
                </div>
                <div class="mt-4">
                  <button
                    phx-click="join_collaboration"
                    phx-value-id={session.id}
                    class="text-sm font-medium text-indigo-600 hover:text-indigo-500">
                    Join session <span aria-hidden="true">→</span>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Empty State for Live Sessions -->
        <div class="text-center py-12">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">No active sessions</h3>
          <p class="text-gray-600 mb-6 max-w-sm mx-auto">
            Start a live collaboration session to work on music, visuals, or other creative projects in real-time.
          </p>
          <div class="flex flex-col space-y-3 sm:flex-row sm:space-y-0 sm:space-x-3 sm:justify-center">
            <button
              phx-click="create_collaboration"
              phx-value-type="music"
              class="inline-flex items-center px-6 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-indigo-600 hover:bg-indigo-700">
              Start Music Session
            </button>
            <button
              phx-click="create_collaboration"
              phx-value-type="visual"
              class="inline-flex items-center px-6 py-3 border border-transparent rounded-md shadow-sm text-base font-medium text-white bg-purple-600 hover:bg-purple-700">
              Start Visual Session
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Campaign Creation Modal Component
  defp render_campaign_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50" phx-click="close_campaign_modal">
      <div class="relative top-20 mx-auto p-5 border w-full max-w-lg shadow-lg rounded-md bg-white" phx-click-away="close_campaign_modal">
        <form phx-submit="create_content_campaign" class="space-y-6">
          <!-- Modal Header -->
          <div class="flex justify-between items-center">
            <h3 class="text-lg font-medium text-gray-900">Create Content Campaign</h3>
            <button
              type="button"
              phx-click="close_campaign_modal"
              class="text-gray-400 hover:text-gray-600">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>

          <!-- Campaign Details -->
          <div class="space-y-4">
            <div>
              <label for="campaign_title" class="block text-sm font-medium text-gray-700">Campaign Title</label>
              <input
                type="text"
                name="title"
                id="campaign_title"
                required
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                placeholder="e.g., Tech Blog Series: Future of AI">
            </div>

            <div>
              <label for="campaign_description" class="block text-sm font-medium text-gray-700">Description</label>
              <textarea
                name="description"
                id="campaign_description"
                rows="3"
                required
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm"
                placeholder="Describe your content campaign goals..."></textarea>
            </div>

            <div>
              <label for="campaign_type" class="block text-sm font-medium text-gray-700">Content Type</label>
              <select
                name="type"
                id="campaign_type"
                required
                class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                <option value="">Select content type...</option>
                <option value="blog_series">Blog Series</option>
                <option value="video_series">Video Series</option>
                <option value="social_campaign">Social Media Campaign</option>
                <option value="tutorial_guide">Tutorial Guide</option>
                <option value="podcast_series">Podcast Series</option>
                <option value="ebook">E-book/Guide</option>
              </select>
            </div>

            <!-- Story Lab Integration -->
            <div class="bg-gradient-to-br from-blue-50 to-purple-50 rounded-lg p-4 border border-blue-200">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center">
                  <svg class="w-5 h-5 text-purple-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                  </svg>
                  <h4 class="text-sm font-medium text-purple-900">Story Lab Integration</h4>
                </div>
                <.link
                  navigate={~p"/portfolio_hub?tab=story_lab"}
                  class="text-xs text-purple-600 hover:text-purple-700 font-medium">
                  Browse All Templates →
                </.link>
              </div>
              <p class="text-xs text-purple-700 mb-3">Use proven narrative structures to organize your content campaign effectively</p>

              <div class="space-y-2">
                <%= for template <- @story_templates do %>
                  <label class="flex items-center p-2 rounded-md hover:bg-white/50 transition-colors">
                    <input type="radio" name="story_template" value={template.id} class="mr-3 text-purple-600">
                    <div class="flex-1">
                      <div class="flex items-center justify-between">
                        <div class="text-xs font-medium text-gray-900"><%= template.name %></div>
                        <span class="text-xs px-2 py-1 bg-purple-100 text-purple-700 rounded-full">
                          <%= template.type |> String.replace("_", " ") |> String.capitalize() %>
                        </span>
                      </div>
                      <div class="text-xs text-gray-500 mt-1"><%= template.description %></div>
                    </div>
                  </label>
                <% end %>
              </div>

              <div class="mt-3 p-2 bg-white/50 rounded-md">
                <p class="text-xs text-gray-600">
                  💡 <strong>Tip:</strong> Selected templates will create a structured outline in Story Lab that all collaborators can follow for consistent, high-quality content.
                </p>
              </div>
            </div>

            <div>
              <label for="target_platforms" class="block text-sm font-medium text-gray-700">Target Platforms</label>
              <div class="mt-2 grid grid-cols-2 gap-2">
                <%= for platform <- ["LinkedIn", "Medium", "YouTube", "TikTok", "Instagram", "Twitter", "Company Blog", "Newsletter"] do %>
                  <label class="flex items-center">
                    <input type="checkbox" name="platforms[]" value={String.downcase(platform)} class="mr-2 text-indigo-600">
                    <span class="text-sm text-gray-700"><%= platform %></span>
                  </label>
                <% end %>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <label for="max_contributors" class="block text-sm font-medium text-gray-700">Max Contributors</label>
                <select
                  name="max_contributors"
                  id="max_contributors"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
                  <option value="2">2 people</option>
                  <option value="3" selected>3 people</option>
                  <option value="5">5 people</option>
                  <option value="10">10 people</option>
                </select>
              </div>

              <div>
                <label for="deadline" class="block text-sm font-medium text-gray-700">Deadline (Optional)</label>
                <input
                  type="date"
                  name="deadline"
                  id="deadline"
                  class="mt-1 block w-full border-gray-300 rounded-md shadow-sm focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm">
              </div>
            </div>
          </div>

          <!-- Modal Actions -->
          <div class="flex flex-col space-y-3 sm:flex-row sm:space-y-0 sm:space-x-3 sm:justify-end">
            <button
              type="button"
              phx-click="close_campaign_modal"
              class="w-full sm:w-auto px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
              Cancel
            </button>
            <button
              type="submit"
              class="w-full sm:w-auto px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700">
              Create Campaign
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end

  # Helper function for time formatting
  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "just now"
      diff < 60 -> "#{diff} minutes ago"
      diff < 1440 -> "#{div(diff, 60)} hours ago"
      true -> "#{div(diff, 1440)} days ago"
    end
  end

  defp load_content_campaigns(account) do
    # Mock data - replace with actual implementation
    [
      %{
        id: 1,
        title: "Tech Blog Series: AI in Creative Work",
        description: "Exploring how AI transforms creative workflows",
        status: "open",
        type: "blog_series",
        target_platforms: ["medium", "linkedin", "company_blog"],
        contributors: [
          %{user_id: 1, name: "Sarah Chen", role: "lead_writer", avatar: "https://via.placeholder.com/150"},
          %{user_id: 2, name: "Mike Rodriguez", role: "editor", avatar: "https://via.placeholder.com/150"}
        ],
        max_contributors: 5,
        deadline: ~D[2025-08-15],
        revenue_split: %{lead_writer: 40, contributors: 30, platform: 30},
        created_at: ~D[2025-07-10]
      },
      %{
        id: 2,
        title: "Video Tutorial: Portfolio Creation",
        description: "Step-by-step video series for new creators",
        status: "active",
        type: "video_series",
        target_platforms: ["youtube", "tiktok", "instagram"],
        contributors: [
          %{user_id: 3, name: "Alex Kim", role: "host", avatar: "https://via.placeholder.com/150"}
        ],
        max_contributors: 3,
        deadline: ~D[2025-07-30],
        revenue_split: %{host: 50, editor: 25, platform: 25},
        created_at: ~D[2025-07-01]
      }
    ]
  end

  defp load_story_templates do
    # Integration with existing story lab enhanced templates
    try do
      # Use the actual enhanced templates from the Stories module
      enhanced_templates = Frestyl.Stories.EnhancedTemplates.get_all_templates()

      # Filter templates suitable for content campaigns
      content_suitable_templates = [
        # Blog/Written Content Templates
        %{
          id: "professional_bio",
          name: "Professional Bio",
          type: "written_content",
          description: "Structured professional biography",
          story_type: :professional_narrative,
          narrative_structure: "professional_showcase",
          template_data: Map.get(enhanced_templates, :professional_narrative, %{})
        },
        %{
          id: "case_study",
          name: "Case Study",
          type: "written_content",
          description: "Problem-solution case study format",
          story_type: :case_study,
          narrative_structure: "problem_solution",
          template_data: Map.get(enhanced_templates, :case_study, %{})
        },
        %{
          id: "customer_journey",
          name: "Customer Journey",
          type: "written_content",
          description: "Customer experience story",
          story_type: :customer_story,
          narrative_structure: "journey_map",
          template_data: Map.get(enhanced_templates, :customer_story, %{})
        },

        # Video Content Templates
        %{
          id: "storyboard_sequence",
          name: "Video Storyboard",
          type: "video_content",
          description: "Visual storyboard for video content",
          story_type: :storyboard,
          narrative_structure: "film_sequence",
          template_data: Map.get(enhanced_templates, :storyboard, %{})
        },

        # Tutorial/Educational Templates
        %{
          id: "tutorial_guide",
          name: "Tutorial Guide",
          type: "educational",
          description: "Step-by-step instructional content",
          story_type: :tutorial,
          narrative_structure: "step_by_step",
          template_data: %{
            name: "Tutorial Guide",
            description: "Educational step-by-step content",
            chapters: [
              %{title: "Introduction", type: :overview, purpose: :context},
              %{title: "Prerequisites", type: :preparation, purpose: :setup},
              %{title: "Step-by-Step Guide", type: :instruction, purpose: :action},
              %{title: "Troubleshooting", type: :support, purpose: :problem_solving},
              %{title: "Next Steps", type: :conclusion, purpose: :advancement}
            ]
          }
        }
      ]

      content_suitable_templates
    rescue
      _ ->
        # Fallback templates if Stories module is not available
        [
          %{id: "blog_post", name: "Blog Post", type: "written_content", description: "Professional blog writing"},
          %{id: "video_script", name: "Video Script", type: "video_content", description: "Engaging video narratives"},
          %{id: "social_series", name: "Social Media Series", type: "social_content", description: "Multi-platform content"},
          %{id: "tutorial_guide", name: "Tutorial Guide", type: "educational", description: "Step-by-step tutorials"}
        ]
    end
  end

  defp get_campaign_limits(account) do
    # Mock limits based on subscription tier
    case account.subscription_tier do
      :enterprise -> %{concurrent_campaigns: :unlimited, max_platforms: :unlimited, monthly_publishes: :unlimited}
      :professional -> %{concurrent_campaigns: 10, max_platforms: 15, monthly_publishes: 200}
      :creator -> %{concurrent_campaigns: 5, max_platforms: 8, monthly_publishes: 100}
      _ -> %{concurrent_campaigns: 3, max_platforms: 5, monthly_publishes: 50}
    end
  end

  defp load_active_sessions(user) do
    # Mock active collaboration sessions
    [
      %{
        id: 1,
        title: "Beat Session with DJ Freso",
        type: "music",
        status: "live",
        participants: [
          %{name: "DJ Freso", avatar: "https://via.placeholder.com/150"},
          %{name: "Producer Mike", avatar: "https://via.placeholder.com/150"},
          %{name: "You", avatar: "https://via.placeholder.com/150"}
        ],
        started_at: DateTime.utc_now() |> DateTime.add(-1800, :second) # 30 min ago
      }
    ]
  end

  defp create_campaign(params, account, user) do
    # Extract story template if selected
    story_template_id = params["story_template"]

    campaign_attrs = %{
      title: params["title"],
      description: params["description"],
      type: params["type"],
      target_platforms: params["platforms"] || [],
      max_contributors: String.to_integer(params["max_contributors"] || "3"),
      deadline: parse_date(params["deadline"]),
      created_by: user.id,
      account_id: account.id,
      status: "open"
    }

    # If story template is selected, create associated story structure
    campaign_attrs = if story_template_id do
      case create_campaign_story_structure(story_template_id, campaign_attrs, user, account) do
        {:ok, story_structure} ->
          Map.put(campaign_attrs, :story_structure_id, story_structure.id)
        {:error, _} ->
          campaign_attrs
      end
    else
      campaign_attrs
    end

    # Mock implementation - replace with actual campaign creation
    {:ok, Map.merge(campaign_attrs, %{
      id: :rand.uniform(1000),
      contributors: [%{user_id: user.id, name: user.name || "You", role: "creator", avatar: "https://via.placeholder.com/150"}],
      revenue_split: %{creator: 50, contributors: 30, platform: 20},
      created_at: DateTime.utc_now()
    })}
  end

  defp create_campaign_story_structure(template_id, campaign_attrs, user, account) do
    try do
      # Load the selected template
      templates = load_story_templates()
      template = Enum.find(templates, &(&1.id == template_id))

      if template && template.template_data do
        # Create a story using the existing Stories module
        story_attrs = %{
          title: "#{campaign_attrs.title} - Content Structure",
          description: "Story structure for content campaign",
          story_type: template.story_type,
          narrative_structure: template.narrative_structure,
          user_id: user.id,
          account_id: account.id,
          visibility: :private,
          is_campaign_structure: true  # Flag to identify campaign-related stories
        }

        case Frestyl.Stories.create_story_from_template(user, account, template_id, story_attrs) do
          {:ok, story} ->
            {:ok, story}
          {:error, reason} ->
            {:error, reason}
        end
      else
        {:error, :template_not_found}
      end
    rescue
      _ -> {:error, :story_creation_failed}
    end
  end

  defp join_content_campaign(campaign_id, user) do
    # Mock implementation
    {:ok, %{campaign_id: campaign_id, user_id: user.id}}
  end

  defp format_error(:campaign_full), do: "Campaign is full"
  defp format_error(:already_joined), do: "Already part of this campaign"
  defp format_error(_), do: "Unable to process request"

  defp status_class("open"), do: "bg-green-100 text-green-800"
  defp status_class("active"), do: "bg-blue-100 text-blue-800"
  defp status_class("completed"), do: "bg-gray-100 text-gray-800"
  defp status_class("cancelled"), do: "bg-red-100 text-red-800"
  defp status_class(_), do: "bg-gray-100 text-gray-800"

  defp already_joined?(campaign, user) do
    Enum.any?(campaign.contributors, &(&1.user_id == user.id))
  end

  defp get_total_collaborators(campaigns) do
    campaigns
    |> Enum.map(&length(&1.contributors))
    |> Enum.sum()
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil
  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  # Helper function for time formatting
  defp format_time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "just now"
      diff < 60 -> "#{diff} minutes ago"
      diff < 1440 -> "#{div(diff, 60)} hours ago"
      true -> "#{div(diff, 1440)} days ago"
    end
  end
end
