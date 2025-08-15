# Supervisor Dashboard LiveView
# File: lib/frestyl_web/live/supervisor_dashboard_live.ex

defmodule FrestylWeb.SupervisorDashboardLive do
  use FrestylWeb, :live_view
  alias Frestyl.Teams
  alias Frestyl.Teams.RatingDimensionConfig

  @impl true
  def mount(_params, _session, socket) do
    # Set a default user for demo purposes if none exists
    current_user = case socket.assigns[:current_user] do
      nil -> %{id: 1, first_name: "Demo", last_name: "Supervisor", email: "supervisor@example.com"}
      user -> user
    end

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:dashboard_data, Teams.get_supervisor_dashboard(current_user.id))
      |> assign(:view_mode, "cards")
      |> assign(:filter_status, "all")
      |> assign(:sort_by, "recent_activity")
      |> assign(:selected_team, nil)
      |> assign(:show_team_detail, false)
      |> assign(:show_create_team_modal, false)
      |> assign(:show_rating_config_modal, false)
      |> assign(:rating_dimensions, RatingDimensionConfig.get_all_categories())

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Team Dashboard")
    |> assign(:show_team_detail, false)
  end

  defp apply_action(socket, :team_detail, %{"team_id" => team_id}) do
    team_detail = Teams.get_team_detail_view(team_id)

    socket
    |> assign(:page_title, "Team: #{team_detail.team.name}")
    |> assign(:team_detail, team_detail)
    |> assign(:selected_team, team_detail.team)
    |> assign(:show_team_detail, true)
  end

  @impl true
  def handle_event("filter_teams", %{"value" => filter}, socket) do
    {:noreply, assign(socket, :filter_status, filter)}
  end

  def handle_event("sort_teams", %{"value" => sort}, socket) do
    {:noreply, assign(socket, :sort_by, sort)}
  end

  def handle_event("view_team_details", %{"team-id" => team_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/supervisor/teams/#{team_id}")}
  end

  def handle_event("show_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, true)}
  end

  def handle_event("hide_create_team_modal", _params, socket) do
    {:noreply, assign(socket, :show_create_team_modal, false)}
  end

  def handle_event("create_team", %{"team" => team_params}, socket) do
    case Teams.create_team(team_params["channel_id"], socket.assigns.current_user.id, team_params) do
      {:ok, _team} ->
        {:noreply,
         socket
         |> assign(:show_create_team_modal, false)
         |> assign(:dashboard_data, Teams.get_supervisor_dashboard(socket.assigns.current_user.id))
         |> put_flash(:info, "Team created successfully!")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create team")}
    end
  end

  def handle_event("show_rating_config", %{"team-id" => team_id}, socket) do
    team = Teams.get_team!(team_id)

    socket =
      socket
      |> assign(:selected_team, team)
      |> assign(:show_rating_config_modal, true)

    {:noreply, socket}
  end

  def handle_event("update_rating_config", %{"team_id" => team_id, "config" => config}, socket) do
    # Update team rating configuration
    {:noreply, assign(socket, :show_rating_config_modal, false)}
  end

  def handle_event("trigger_intervention", %{"team-id" => team_id, "type" => intervention_type}, socket) do
    # Implement intervention actions
    {:noreply, put_flash(socket, :info, "Intervention initiated for team")}
  end

  def handle_event("export_team_data", %{"team-id" => team_id, "format" => format}, socket) do
    # Implement data export
    {:noreply, put_flash(socket, :info, "Export started - you'll receive an email when ready")}
  end

  # Helper functions for template
  defp filter_teams(teams, "all"), do: teams
  defp filter_teams(teams, "needs_attention") do
    Enum.filter(teams, &(length(&1.needs_attention) > 0))
  end
  defp filter_teams(teams, "high_performance") do
    Enum.filter(teams, &(&1.team_sentiment_score > 80))
  end

  defp sort_teams(teams, "recent_activity") do
    Enum.sort_by(teams, &(&1.last_activity || DateTime.from_unix!(0)), {:desc, DateTime})
  end
  defp sort_teams(teams, "completion_rate") do
    Enum.sort_by(teams, &(&1.completion_percentage), :desc)
  end
  defp sort_teams(teams, "team_sentiment") do
    Enum.sort_by(teams, &(&1.team_sentiment_score), :desc)
  end
  defp sort_teams(teams, "name") do
    Enum.sort_by(teams, &(&1.team_name))
  end

  defp render_performance_badge(team_card) do
    cond do
      length(team_card.needs_attention) > 0 ->
        Phoenix.HTML.raw("""
        <span class="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800">
          Needs Attention
        </span>
        """)

      team_card.team_sentiment_score > 80 ->
        Phoenix.HTML.raw("""
        <span class="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800">
          High Performance
        </span>
        """)

      team_card.team_sentiment_score > 60 ->
        Phoenix.HTML.raw("""
        <span class="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800">
          Good
        </span>
        """)

      true ->
        Phoenix.HTML.raw("""
        <span class="inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800">
          Developing
        </span>
        """)
    end
  end

  defp render_vibe_trend_icon(trend) do
    case trend do
      :improving ->
        Phoenix.HTML.raw("""
        <div class="text-green-400" title="Improving sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M5.293 7.707a1 1 0 010-1.414l4-4a1 1 0 011.414 0l4 4a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L6.707 7.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)

      :declining ->
        Phoenix.HTML.raw("""
        <div class="text-red-400" title="Declining sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M14.707 12.293a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0l-4-4a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l2.293-2.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)

      :stable ->
        Phoenix.HTML.raw("""
        <div class="text-blue-400" title="Stable sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="text-gray-400" title="Insufficient data">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-8-3a1 1 0 00-.867.5 1 1 0 11-1.731-1A3 3 0 0113 8a3.001 3.001 0 01-2 2.83V11a1 1 0 11-2 0v-1a1 1 0 011-1 1 1 0 100-2zm0 8a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)
    end
  end

  defp render_attention_alerts(needs_attention) do
    alerts = %{
      "low_team_sentiment" => %{icon: "😞", text: "Low team morale", color: "red"},
      "low_activity" => %{icon: "💤", text: "Low activity", color: "yellow"},
      "collaboration_variance" => %{icon: "⚠️", text: "Collaboration issues", color: "orange"}
    }

    html_parts = needs_attention
    |> Enum.take(2)
    |> Enum.map(fn issue ->
      alert = Map.get(alerts, issue, %{icon: "⚠️", text: issue, color: "gray"})

      """
      <div class="flex items-center space-x-2 text-xs text-#{alert.color}-600">
        <span>#{alert.icon}</span>
        <span>#{alert.text}</span>
      </div>
      """
    end)
    |> Enum.join("\n")

    Phoenix.HTML.raw(html_parts)
  end

  defp lighten_color(hex_color) do
    # Simple color lightening for gradient effect
    hex_color <> "80" # Add alpha for transparency
  end

  defp time_ago(nil), do: "Never"
  defp time_ago(datetime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff -> "#{div(diff, 86400)}d ago"
    end
  end
end
