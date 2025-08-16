# lib/frestyl_web/live/demo_team_management_live.ex
defmodule FrestylWeb.DemoTeamManagementLive do
  use FrestylWeb, :live_view
  alias Frestyl.Teams

  @impl true
  def mount(%{"team_id" => team_id}, _session, socket) do
    # Get team safely
    team = case Teams.get_team(team_id) do
      nil -> create_demo_team_if_missing(team_id)
      team -> team
    end

    current_user = socket.assigns[:current_user] || %{
      id: 1,
      first_name: "Demo",
      last_name: "Supervisor",
      email: "supervisor@example.com"
    }

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:team, team)
      |> assign(:team_members, get_team_members_safely(team))
      |> assign(:recent_ratings, get_recent_ratings_safely(team_id))
      |> assign(:team_stats, get_team_stats_safely(team_id))
      |> assign(:show_add_member_modal, false)
      |> assign(:show_rating_config_modal, false)

    {:ok, socket}
  end

  @impl true
  def mount(_params, _session, socket) do
    # Handle case where no team_id is provided - redirect to demo overview
    {:ok, push_redirect(socket, to: "/demo/supervisor")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="demo-team-management min-h-screen bg-gray-50">
      <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Header -->
        <div class="flex items-center justify-between mb-8">
          <div>
            <div class="flex items-center space-x-4 mb-2">
              <a href="/demo/supervisor"
                 class="text-blue-600 hover:text-blue-700 flex items-center">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
                </svg>
                Back to Dashboard
              </a>
            </div>
            <h1 class="text-3xl font-bold text-gray-900"><%= @team.name %></h1>
            <p class="text-gray-600 mt-1"><%= @team.project_assignment || "Demo team project" %></p>
          </div>

          <div class="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p class="text-sm text-blue-800">
              📊 <strong>Demo Mode:</strong> This shows team management features
            </p>
          </div>
        </div>

        <!-- Team Stats Grid -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-gray-600">Team Members</p>
                <p class="text-3xl font-bold text-blue-600"><%= length(@team_members) %></p>
              </div>
              <div class="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"/>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-gray-600">Completion</p>
                <p class="text-3xl font-bold text-green-600"><%= @team.completion_percentage || 0 %>%</p>
              </div>
              <div class="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-gray-600">Recent Ratings</p>
                <p class="text-3xl font-bold text-purple-600"><%= length(@recent_ratings) %></p>
              </div>
              <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                </svg>
              </div>
            </div>
          </div>

          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between">
              <div>
                <p class="text-sm text-gray-600">Avg Score</p>
                <p class="text-3xl font-bold text-orange-600"><%= Float.round(@team_stats.avg_score, 1) %></p>
              </div>
              <div class="w-12 h-12 bg-orange-100 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"/>
                </svg>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Team Members -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-6">
              <h3 class="text-lg font-semibold text-gray-900">Team Members</h3>
              <button phx-click="show_add_member_modal"
                      class="px-3 py-1 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm">
                Add Member
              </button>
            </div>

            <div class="space-y-4">
              <%= for member <- @team_members do %>
                <div class="flex items-center justify-between p-4 border border-gray-200 rounded-lg">
                  <div class="flex items-center space-x-3">
                    <div class="w-10 h-10 bg-gradient-to-br from-blue-500 to-purple-500 rounded-full flex items-center justify-center text-white font-semibold">
                      <%= String.first(member.first_name) %><%= String.first(member.last_name) %>
                    </div>
                    <div>
                      <p class="font-medium text-gray-900"><%= member.first_name %> <%= member.last_name %></p>
                      <p class="text-sm text-gray-600"><%= member.email %></p>
                    </div>
                  </div>

                  <div class="flex items-center space-x-2">
                    <span class="px-2 py-1 bg-gray-100 text-gray-800 rounded text-xs font-medium">
                      Member
                    </span>
                    <div class="text-sm text-gray-500">
                      Score: <%= get_member_avg_score(member, @recent_ratings) %>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if length(@team_members) == 0 do %>
                <div class="text-center py-8 text-gray-500">
                  <p>No team members assigned yet</p>
                  <button phx-click="show_add_member_modal"
                          class="mt-2 text-blue-600 hover:text-blue-700 text-sm">
                    Add the first member
                  </button>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Recent Ratings -->
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 p-6">
            <div class="flex items-center justify-between mb-6">
              <h3 class="text-lg font-semibold text-gray-900">Recent Ratings</h3>
              <a href="/demo/vibe-rating"
                 class="px-3 py-1 bg-green-600 text-white rounded-lg hover:bg-green-700 text-sm">
                Test Rating Widget
              </a>
            </div>

            <div class="space-y-4">
              <%= for rating <- Enum.take(@recent_ratings, 5) do %>
                <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
                  <div>
                    <p class="text-sm font-medium text-gray-900">
                      <%= get_user_name(rating.reviewer_id) %> → <%= get_user_name(rating.reviewee_id) %>
                    </p>
                    <p class="text-xs text-gray-600">
                      <%= format_rating_time(rating.inserted_at) %>
                    </p>
                  </div>

                  <div class="flex items-center space-x-2">
                    <div class="text-sm">
                      <span class="font-medium text-blue-600"><%= Float.round(rating.primary_score, 1) %></span>
                      <span class="text-gray-400">/</span>
                      <span class="font-medium text-purple-600"><%= Float.round(rating.secondary_score, 1) %></span>
                    </div>
                  </div>
                </div>
              <% end %>

              <%= if length(@recent_ratings) == 0 do %>
                <div class="text-center py-8 text-gray-500">
                  <p>No ratings submitted yet</p>
                  <a href="/demo/vibe-rating"
                     class="mt-2 text-green-600 hover:text-green-700 text-sm">
                    Try the rating widget
                  </a>
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Quick Actions -->
        <div class="mt-8 bg-white rounded-xl shadow-sm border border-gray-200 p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Quick Actions</h3>

          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <a href="/demo/vibe-rating"
               class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50">
              <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-4">
                <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">Test Rating Widget</p>
                <p class="text-sm text-gray-600">Try the vibe rating interface</p>
              </div>
            </a>

            <button phx-click="show_rating_config_modal"
                    class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50">
              <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center mr-4">
                <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">Configure Ratings</p>
                <p class="text-sm text-gray-600">Set up rating dimensions</p>
              </div>
            </button>

            <a href="/demo/supervisor"
               class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-gray-50">
              <div class="w-10 h-10 bg-purple-100 rounded-lg flex items-center justify-center mr-4">
                <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                </svg>
              </div>
              <div>
                <p class="font-medium text-gray-900">View Dashboard</p>
                <p class="text-sm text-gray-600">Back to supervisor overview</p>
              </div>
            </a>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions
  defp create_demo_team_if_missing(team_id) do
    # If team doesn't exist, create a basic demo team
    demo_data = Frestyl.Teams.Demo.setup!()
    demo_data.team
  end

  defp get_team_members_safely(team) do
    case team do
      %{members: members} when is_list(members) -> members
      _ -> []
    end
  end

  defp get_recent_ratings_safely(team_id) do
    try do
      Teams.list_team_ratings(team_id)
    rescue
      _error -> []
    end
  end

  defp get_team_stats_safely(team_id) do
    ratings = get_recent_ratings_safely(team_id)

    avg_score = case ratings do
      [] -> 0.0
      ratings ->
        ratings
        |> Enum.map(& &1.primary_score)
        |> Enum.sum()
        |> Kernel./(length(ratings))
    end

    %{
      avg_score: avg_score,
      total_ratings: length(ratings)
    }
  end

  defp get_member_avg_score(member, ratings) do
    member_ratings = Enum.filter(ratings, fn rating ->
      rating.reviewee_id == member.id
    end)

    case member_ratings do
      [] -> "N/A"
      ratings ->
        avg = ratings
              |> Enum.map(& &1.primary_score)
              |> Enum.sum()
              |> Kernel./(length(ratings))

        Float.round(avg, 1)
    end
  end

  defp get_user_name(user_id) do
    # Simple lookup - in real app you'd cache this
    case Frestyl.Accounts.get_user(user_id) do
      nil -> "Unknown User"
      user -> "#{user.first_name} #{String.first(user.last_name)}."
    end
  end

  defp format_rating_time(datetime) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> "#{div(diff_seconds, 86400)}d ago"
    end
  end
end
