# lib/frestyl_web/live/portfolio_hub_live/collaboration_components.ex
defmodule FrestylWeb.PortfolioHubLive.CollaborationComponents do
  @moduledoc """
  UI components for the enhanced collaboration hub with real-time indicators,
  invitation management, and mobile-optimized collaboration features.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents

  # ============================================================================
  # REAL-TIME COLLABORATION INDICATORS
  # ============================================================================

  @doc """
  Displays real-time collaboration status for portfolios in the hub.
  """
  def portfolio_collaboration_status(assigns) do
    ~H"""
    <div class="collaboration-status">
      <%= if @collaboration_enabled do %>
        <div class="flex items-center space-x-2">
          <!-- Active Collaborators -->
          <%= if @active_sessions > 0 do %>
            <div class="flex items-center space-x-1">
              <div class="flex -space-x-1">
                <%= for collaborator <- Enum.take(@collaborators, 3) do %>
                  <div class="relative">
                    <img
                      src={collaborator.avatar_url || "/images/default-avatar.png"}
                      alt={collaborator.username}
                      class="w-6 h-6 rounded-full border-2 border-white"
                      title={collaborator.username} />
                    <div class="absolute -bottom-0.5 -right-0.5 w-3 h-3 bg-green-400 border-2 border-white rounded-full animate-pulse"></div>
                  </div>
                <% end %>

                <%= if @active_sessions > 3 do %>
                  <div class="w-6 h-6 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center text-xs font-medium text-gray-600">
                    +<%= @active_sessions - 3 %>
                  </div>
                <% end %>
              </div>

              <span class="text-xs text-green-600 font-medium">
                <%= @active_sessions %> active
              </span>
            </div>
          <% else %>
            <div class="flex items-center space-x-1 text-gray-400">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
              <span class="text-xs">Ready for collaboration</span>
            </div>
          <% end %>

          <!-- Recent Activity Indicator -->
          <%= if @last_collaborative_edit do %>
            <div class="text-xs text-gray-500">
              Last edit: <%= time_ago(@last_collaborative_edit) %>
            </div>
          <% end %>
        </div>
      <% else %>
        <div class="flex items-center space-x-1 text-gray-400">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"/>
          </svg>
          <span class="text-xs">Upgrade for collaboration</span>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Enhanced collaboration panel with real-time activity feed.
  """
  def collaboration_panel(assigns) do
    ~H"""
    <div class="collaboration-panel bg-white rounded-lg shadow-lg border border-gray-200 p-6">
      <!-- Panel Header -->
      <div class="flex items-center justify-between mb-6">
        <div class="flex items-center space-x-2">
          <div class="p-2 bg-blue-100 rounded-lg">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900">Collaboration Hub</h3>
        </div>

        <button
          phx-click="close_collaboration_panel"
          class="text-gray-400 hover:text-gray-600 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>

      <!-- Collaboration Tabs -->
      <div class="flex space-x-1 mb-6 bg-gray-100 p-1 rounded-lg">
        <button
          phx-click="toggle_collaboration_section"
          phx-value-section="active"
          class={[
            "flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors",
            if(@active_collaboration_section == "active", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900")
          ]}>
          Active Sessions
          <%= if length(@collaboration_data.real_time_sessions) > 0 do %>
            <span class="ml-1 bg-blue-100 text-blue-800 text-xs px-1.5 py-0.5 rounded-full">
              <%= length(@collaboration_data.real_time_sessions) %>
            </span>
          <% end %>
        </button>

        <button
          phx-click="toggle_collaboration_section"
          phx-value-section="invitations"
          class={[
            "flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors",
            if(@active_collaboration_section == "invitations", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900")
          ]}>
          Invitations
          <%= if length(@collaboration_data.received_invitations) > 0 do %>
            <span class="ml-1 bg-green-100 text-green-800 text-xs px-1.5 py-0.5 rounded-full">
              <%= length(@collaboration_data.received_invitations) %>
            </span>
          <% end %>
        </button>

        <button
          phx-click="toggle_collaboration_section"
          phx-value-section="opportunities"
          class={[
            "flex-1 px-3 py-2 text-sm font-medium rounded-md transition-colors",
            if(@active_collaboration_section == "opportunities", do: "bg-white text-gray-900 shadow-sm", else: "text-gray-600 hover:text-gray-900")
          ]}>
          Discover
        </button>
      </div>

      <!-- Active Sessions Tab -->
      <%= if @active_collaboration_section == "active" do %>
        <div class="space-y-4">
          <%= if length(@collaboration_data.real_time_sessions) > 0 do %>
            <%= for session <- @collaboration_data.real_time_sessions do %>
              <.collaboration_session_card session={session} />
            <% end %>
          <% else %>
            <div class="text-center py-8">
              <svg class="mx-auto w-12 h-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
              </svg>
              <p class="text-gray-500 text-sm">No active collaboration sessions</p>
              <p class="text-gray-400 text-xs mt-1">Start collaborating by inviting others to your portfolios</p>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Invitations Tab -->
      <%= if @active_collaboration_section == "invitations" do %>
        <div class="space-y-4">
          <!-- Received Invitations -->
          <%= if length(@collaboration_data.received_invitations) > 0 do %>
            <div class="space-y-3">
              <h4 class="text-sm font-medium text-gray-900 flex items-center">
                <svg class="w-4 h-4 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
                Received Invitations
              </h4>

              <%= for invitation <- @collaboration_data.received_invitations do %>
                <.invitation_card invitation={invitation} type="received" />
              <% end %>
            </div>
          <% end %>

          <!-- Sent Invitations -->
          <%= if length(@collaboration_data.sent_invitations) > 0 do %>
            <div class="space-y-3">
              <h4 class="text-sm font-medium text-gray-900 flex items-center">
                <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
                </svg>
                Sent Invitations
              </h4>

              <%= for invitation <- @collaboration_data.sent_invitations do %>
                <.invitation_card invitation={invitation} type="sent" />
              <% end %>
            </div>
          <% end %>

          <%= if length(@collaboration_data.received_invitations) == 0 && length(@collaboration_data.sent_invitations) == 0 do %>
            <div class="text-center py-8">
              <svg class="mx-auto w-12 h-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              <p class="text-gray-500 text-sm">No collaboration invitations</p>
              <p class="text-gray-400 text-xs mt-1">Invite others to collaborate on your portfolios</p>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Opportunities Tab -->
      <%= if @active_collaboration_section == "opportunities" do %>
        <div class="space-y-4">
          <%= if length(@collaboration_data.opportunities) > 0 do %>
            <%= for opportunity <- @collaboration_data.opportunities do %>
              <.collaboration_opportunity opportunity={opportunity} />
            <% end %>
          <% else %>
            <div class="text-center py-8">
              <svg class="mx-auto w-12 h-12 text-gray-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
              </svg>
              <p class="text-gray-500 text-sm">No collaboration opportunities right now</p>
              <p class="text-gray-400 text-xs mt-1">Keep creating content and we'll suggest collaboration opportunities</p>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # INDIVIDUAL COMPONENT CARDS
  # ============================================================================

  defp collaboration_session_card(assigns) do
    ~H"""
    <div class="bg-gray-50 rounded-lg p-4 border border-gray-200 hover:border-blue-300 transition-colors">
      <div class="flex items-center justify-between mb-3">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center text-white font-semibold text-sm">
            <%= String.first(@session.portfolio.title) %>
          </div>

          <div>
            <h4 class="font-medium text-gray-900"><%= @session.portfolio.title %></h4>
            <div class="flex items-center space-x-2 text-xs text-gray-500">
              <span>Session: <%= duration_since(@session.session_start) %></span>
              <%= if @session.active_section do %>
                <span>•</span>
                <span>Editing: Section <%= @session.active_section %></span>
              <% end %>
            </div>
          </div>
        </div>

        <div class="flex items-center space-x-2">
          <!-- Live Activity Indicator -->
          <div class="w-2 h-2 bg-green-400 rounded-full animate-pulse" title="Live collaboration active"></div>

          <!-- Join Session Button -->
          <button
            phx-click="start_portfolio_collaboration"
            phx-value-portfolio_id={@session.portfolio.id}
            class="px-3 py-1 bg-blue-600 text-white text-xs font-medium rounded-md hover:bg-blue-700 transition-colors">
            Join
          </button>
        </div>
      </div>

      <!-- Collaborators -->
      <div class="flex items-center space-x-3">
        <div class="flex -space-x-1">
          <%= for collaborator <- Enum.take(@session.collaborators, 4) do %>
            <img
              src={collaborator.avatar_url || "/images/default-avatar.png"}
              alt={collaborator.username}
              class="w-6 h-6 rounded-full border-2 border-white"
              title={collaborator.username} />
          <% end %>

          <%= if length(@session.collaborators) > 4 do %>
            <div class="w-6 h-6 rounded-full bg-gray-200 border-2 border-white flex items-center justify-center text-xs font-medium text-gray-600">
              +<%= length(@session.collaborators) - 4 %>
            </div>
          <% end %>
        </div>

        <span class="text-xs text-gray-500">
          <%= length(@session.collaborators) %> <%= if length(@session.collaborators) == 1, do: "collaborator", else: "collaborators" %>
        </span>

        <!-- Last Activity -->
        <span class="text-xs text-gray-400">
          • Last activity: <%= time_ago(@session.last_activity) %>
        </span>
      </div>
    </div>
    """
  end

  defp invitation_card(assigns) do
    ~H"""
    <div class="bg-white border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors">
      <%= if @type == "received" do %>
        <!-- Received Invitation -->
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <img
              src={@invitation.inviting_user.avatar_url || "/images/default-avatar.png"}
              alt={@invitation.inviting_user.username}
              class="w-10 h-10 rounded-full border border-gray-200" />

            <div>
              <h4 class="font-medium text-gray-900"><%= @invitation.portfolio.title %></h4>
              <p class="text-sm text-gray-600">
                Invited by <span class="font-medium"><%= @invitation.inviting_user.username %></span>
              </p>
              <div class="flex items-center space-x-2 text-xs text-gray-500 mt-1">
                <span>Permissions: <%= format_permissions(@invitation.permissions) %></span>
                <span>•</span>
                <span>Expires: <%= expires_in(@invitation.expires_at) %></span>
              </div>
            </div>
          </div>

          <div class="flex space-x-2">
            <button
              phx-click="decline_invitation"
              phx-value-token={@invitation.token}
              class="px-3 py-1 text-gray-600 border border-gray-300 rounded-md text-sm hover:bg-gray-50 transition-colors">
              Decline
            </button>
            <button
              phx-click="accept_invitation"
              phx-value-token={@invitation.token}
              class="px-3 py-1 bg-green-600 text-white rounded-md text-sm font-medium hover:bg-green-700 transition-colors">
              Accept
            </button>
          </div>
        </div>
      <% else %>
        <!-- Sent Invitation -->
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </div>

            <div>
              <h4 class="font-medium text-gray-900">Portfolio: <%= get_portfolio_title(@invitation.portfolio_id) %></h4>
              <p class="text-sm text-gray-600">Sent to: <%= @invitation.invitee_email %></p>
              <div class="flex items-center space-x-2 text-xs text-gray-500 mt-1">
                <span>Sent: <%= time_ago(@invitation.created_at) %></span>
                <span>•</span>
                <span>Expires: <%= expires_in(@invitation.expires_at) %></span>
              </div>
            </div>
          </div>

          <div class="flex items-center space-x-2">
            <span class="px-2 py-1 bg-amber-100 text-amber-800 text-xs rounded-full">Pending</span>
            <button
              phx-click="cancel_invitation"
              phx-value-token={@invitation.token}
              class="text-gray-400 hover:text-gray-600 transition-colors">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp collaboration_opportunity(assigns) do
    ~H"""
    <div class="bg-gradient-to-r from-blue-50 to-purple-50 border border-blue-200 rounded-lg p-4">
      <div class="flex items-start justify-between">
        <div class="flex items-start space-x-3">
          <!-- Opportunity Icon -->
          <div class={[
            "w-10 h-10 rounded-lg flex items-center justify-center text-white",
            case @opportunity.type do
              :upgrade -> "bg-gradient-to-br from-purple-500 to-pink-600"
              :content_collaboration -> "bg-gradient-to-br from-blue-500 to-cyan-600"
              :review_collaboration -> "bg-gradient-to-br from-green-500 to-emerald-600"
              _ -> "bg-gradient-to-br from-gray-500 to-gray-600"
            end
          ]}>
            <%= case @opportunity.type do %>
              <% :upgrade -> %>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
              <% :content_collaboration -> %>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              <% :review_collaboration -> %>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              <% _ -> %>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
            <% end %>
          </div>

          <div class="flex-1">
            <h4 class="font-semibold text-gray-900 mb-1"><%= @opportunity.title %></h4>
            <p class="text-sm text-gray-600 mb-2"><%= @opportunity.description %></p>

            <!-- Benefits for upgrade opportunities -->
            <%= if @opportunity.type == :upgrade && Map.has_key?(@opportunity, :benefits) do %>
              <div class="flex flex-wrap gap-1 mb-3">
                <%= for benefit <- Enum.take(@opportunity.benefits, 3) do %>
                  <span class="px-2 py-1 bg-purple-100 text-purple-700 text-xs rounded-full">
                    <%= benefit %>
                  </span>
                <% end %>
              </div>
            <% end %>

            <!-- Priority indicator -->
            <%= if Map.has_key?(@opportunity, :priority) do %>
              <div class="flex items-center space-x-2 text-xs">
                <span class={[
                  "px-2 py-1 rounded-full font-medium",
                  case @opportunity.priority do
                    :high -> "bg-red-100 text-red-700"
                    :medium -> "bg-amber-100 text-amber-700"
                    :low -> "bg-green-100 text-green-700"
                    _ -> "bg-gray-100 text-gray-700"
                  end
                ]}>
                  <%= String.capitalize(to_string(@opportunity.priority)) %> Priority
                </span>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Action Button -->
        <div class="flex-shrink-0">
          <button
            phx-click={@opportunity.action}
            phx-value-portfolio_id={Map.get(@opportunity, :portfolio_id)}
            phx-value-type={@opportunity.type}
            class={[
              "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
              case @opportunity.type do
                :upgrade -> "bg-purple-600 text-white hover:bg-purple-700"
                :content_collaboration -> "bg-blue-600 text-white hover:bg-blue-700"
                :review_collaboration -> "bg-green-600 text-white hover:bg-green-700"
                _ -> "bg-gray-600 text-white hover:bg-gray-700"
              end
            ]}>
            <%= case @opportunity.action do %>
              <% :upgrade_subscription -> %>
                <%= if Map.has_key?(@opportunity, :suggested_tier) do %>
                  Upgrade to <%= String.capitalize(to_string(@opportunity.suggested_tier)) %>
                <% else %>
                  Upgrade Now
                <% end %>
              <% :find_collaborators -> %>
                Find Collaborators
              <% :request_review -> %>
                Request Review
              <% _ -> %>
                Take Action
            <% end %>
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MOBILE COLLABORATION COMPONENTS
  # ============================================================================

  @doc """
  Mobile-optimized collaboration interface with touch-friendly controls.
  """
  def mobile_collaboration_interface(assigns) do
    ~H"""
    <div class="mobile-collaboration-interface bg-white rounded-t-xl shadow-lg border-t border-gray-200 p-4">
      <!-- Mobile Collaboration Header -->
      <div class="flex items-center justify-between mb-4">
        <div class="flex items-center space-x-3">
          <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
            <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
            </svg>
          </div>
          <h3 class="font-semibold text-gray-900">Collaborate</h3>
        </div>

        <!-- Mobile Collaboration Mode Toggle -->
        <button
          phx-click="toggle_mobile_collaboration_mode"
          class="px-3 py-1 bg-gray-100 text-gray-700 text-sm rounded-lg">
          <%= String.capitalize(to_string(@mobile_collaboration_mode || :standard)) %>
        </button>
      </div>

      <!-- Active Mobile Collaborators -->
      <%= if length(@active_collaborators) > 0 do %>
        <div class="mb-4">
          <h4 class="text-sm font-medium text-gray-700 mb-2">Active Collaborators</h4>
          <div class="flex space-x-2 overflow-x-auto pb-2">
            <%= for collaborator <- @active_collaborators do %>
              <div class="flex-shrink-0 flex items-center space-x-2 bg-gray-50 rounded-lg px-3 py-2">
                <img
                  src={collaborator.avatar_url || "/images/default-avatar.png"}
                  alt={collaborator.username}
                  class="w-6 h-6 rounded-full" />
                <span class="text-sm text-gray-900"><%= collaborator.username %></span>
                <%= if collaborator.device_type == "mobile" do %>
                  <div class="w-2 h-2 bg-blue-400 rounded-full" title="Mobile user"></div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Mobile Collaboration Actions -->
      <div class="space-y-3">
        <!-- Voice Collaboration (Mobile) -->
        <%= if @mobile_collaboration_options.voice_editing do %>
          <button
            phx-click="start_voice_collaboration"
            class="w-full flex items-center justify-center space-x-3 bg-green-50 border border-green-200 rounded-lg p-3 text-green-700 hover:bg-green-100 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11a7 7 0 01-7 7m0 0a7 7 0 01-7-7m7 7v4m0 0H8m4 0h4m-4-8a3 3 0 01-3-3V5a3 3 0 116 0v6a3 3 0 01-3 3z"/>
            </svg>
            <span class="font-medium">Voice Editing</span>
          </button>
        <% end %>

        <!-- Camera Integration (Mobile) -->
        <%= if @mobile_collaboration_options.camera_integration do %>
          <button
            phx-click="start_camera_collaboration"
            class="w-full flex items-center justify-center space-x-3 bg-purple-50 border border-purple-200 rounded-lg p-3 text-purple-700 hover:bg-purple-100 transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 9a2 2 0 012-2h.93a2 2 0 001.664-.89l.812-1.22A2 2 0 0110.07 4h3.86a2 2 0 011.664.89l.812 1.22A2 2 0 0018.07 7H19a2 2 0 012 2v9a2 2 0 01-2 2H5a2 2 0 01-2-2V9z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 13a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
            <span class="font-medium">Camera Capture</span>
          </button>
        <% end %>

        <!-- Standard Mobile Collaboration -->
        <button
          phx-click="start_mobile_collaboration"
          phx-value-portfolio_id={@portfolio_id}
          class="w-full flex items-center justify-center space-x-3 bg-blue-50 border border-blue-200 rounded-lg p-3 text-blue-700 hover:bg-blue-100 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
          </svg>
          <span class="font-medium">Start Collaboration</span>
        </button>
      </div>

      <!-- Mobile Gesture Guide -->
      <%= if @mobile_collaboration_options.gesture_controls do %>
        <div class="mt-4 p-3 bg-amber-50 border border-amber-200 rounded-lg">
          <h5 class="text-sm font-medium text-amber-800 mb-2">Gesture Controls</h5>
          <div class="space-y-1 text-xs text-amber-700">
            <div class="flex justify-between">
              <span>Swipe right:</span>
              <span>Indent text</span>
            </div>
            <div class="flex justify-between">
              <span>Swipe left:</span>
              <span>Unindent text</span>
            </div>
            <div class="flex justify-between">
              <span>Double tap:</span>
              <span>Bold text</span>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 ->
        "#{seconds}s ago"

      seconds when seconds < 3600 ->
        minutes = div(seconds, 60)
        "#{minutes}m ago"

      seconds when seconds < 86400 ->
        hours = div(seconds, 3600)
        "#{hours}h ago"

      _ ->
        days = div(DateTime.diff(DateTime.utc_now(), datetime, :second), 86400)
        "#{days}d ago"
    end
  end

  defp duration_since(datetime) do
    seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      seconds < 3600 ->
        minutes = div(seconds, 60)
        "#{minutes} min"

      seconds < 86400 ->
        hours = div(seconds, 3600)
        minutes = div(rem(seconds, 3600), 60)
        "#{hours}h #{minutes}m"

      true ->
        days = div(seconds, 86400)
        hours = div(rem(seconds, 86400), 3600)
        "#{days}d #{hours}h"
    end
  end

  defp expires_in(expires_at) do
    case DateTime.diff(expires_at, DateTime.utc_now(), :second) do
      seconds when seconds <= 0 ->
        "Expired"

      seconds when seconds < 3600 ->
        minutes = div(seconds, 60)
        "#{minutes}m left"

      seconds when seconds < 86400 ->
        hours = div(seconds, 3600)
        "#{hours}h left"

      _ ->
        days = div(DateTime.diff(expires_at, DateTime.utc_now(), :second), 86400)
        "#{days}d left"
    end
  end

  defp format_permissions(permissions) when is_map(permissions) do
    perms = []

    perms = if Map.get(permissions, :can_edit_all), do: ["Edit" | perms], else: perms
    perms = if Map.get(permissions, :can_invite), do: ["Invite" | perms], else: perms
    perms = if Map.get(permissions, :can_manage), do: ["Manage" | perms], else: perms

    case perms do
      [] -> "View only"
      list -> Enum.join(list, ", ")
    end
  end

  defp format_permissions(_), do: "View only"

  defp get_portfolio_title(portfolio_id) do
    # This would typically fetch from assigns or make a database call
    # For now, return a placeholder
    "Portfolio ##{portfolio_id}"
  end
end
