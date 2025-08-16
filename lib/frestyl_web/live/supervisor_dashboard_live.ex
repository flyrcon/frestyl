# lib/frestyl_web/live/supervisor_dashboard_live.ex
defmodule FrestylWeb.SupervisorDashboardLive do
  use FrestylWeb, :live_view
  alias Frestyl.Teams

  @impl true
  def mount(_params, _session, socket) do
    # Set a default user for demo purposes if none exists
    current_user = case socket.assigns[:current_user] do
      nil -> %{id: 1, first_name: "Demo", last_name: "Supervisor", email: "supervisor@example.com"}
      user -> user
    end

    # Get rating dimensions safely
    rating_dimensions = get_rating_dimensions_safely()

    socket =
      socket
      |> assign(:current_user, current_user)
      |> assign(:dashboard_data, get_dashboard_data_safely(current_user.id))
      |> assign(:view_mode, "cards")
      |> assign(:filter_status, "all")
      |> assign(:sort_by, "recent_activity")
      |> assign(:selected_team, nil)
      |> assign(:show_team_detail, false)
      |> assign(:show_create_team_modal, false)
      |> assign(:show_rating_config_modal, false)
      |> assign(:rating_dimensions, rating_dimensions)

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
    case get_team_detail_safely(team_id) do
      {:ok, team_detail} ->
        socket
        |> assign(:page_title, "Team: #{team_detail.team.name}")
        |> assign(:team_detail, team_detail)
        |> assign(:selected_team, team_detail.team)
        |> assign(:show_team_detail, true)

      {:error, _reason} ->
        socket
        |> put_flash(:error, "Team not found")
        |> push_patch(to: ~p"/supervisor/teams")
    end
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
         |> assign(:dashboard_data, get_dashboard_data_safely(socket.assigns.current_user.id))
         |> put_flash(:info, "Team created successfully!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create team. Please check your input.")}
    end
  end

  # Safe helper functions to handle missing modules/functions

  defp get_rating_dimensions_safely do
    try do
      if Code.ensure_loaded?(Frestyl.Teams.RatingDimensionConfig) do
        Frestyl.Teams.RatingDimensionConfig.get_all_categories()
      else
        get_default_rating_dimensions()
      end
    rescue
      _error -> get_default_rating_dimensions()
    end
  end

  defp get_dashboard_data_safely(user_id) do
    try do
      Teams.get_supervisor_dashboard(user_id)
    rescue
      _error ->
        # Return default dashboard data if function fails
        %{
          total_teams: 0,
          active_teams: 0,
          needs_attention: 0,
          high_performance: 0,
          team_cards: [],
          recent_activity: []
        }
    end
  end

  defp get_team_detail_safely(team_id) do
    try do
      team_detail = Teams.get_team_detail_view(team_id)
      {:ok, team_detail}
    rescue
      _error -> {:error, :not_found}
    end
  end

  defp get_default_rating_dimensions do
    %{
      primary_dimensions: [
        %{key: "quality", name: "Quality", description: "Overall quality of work"}
      ],
      secondary_dimensions: [
        %{key: "collaboration_effectiveness", name: "Collaboration", description: "How well they work with others"}
      ],
      organization_types: [
        %{key: "academic", name: "Academic", default_secondary: "collaboration_effectiveness"}
      ]
    }
  end

  # Add these helper functions for the template to work
  def filter_teams(team_cards, filter_status) do
    case filter_status do
      "all" -> team_cards
      "needs_attention" -> Enum.filter(team_cards, fn card -> length(Map.get(card, :needs_attention, [])) > 0 end)
      "high_performance" -> Enum.filter(team_cards, fn card -> Map.get(card, :team_sentiment_score, 0) > 80 end)
      _ -> team_cards
    end
  end

  def sort_teams(team_cards, sort_by) do
    case sort_by do
      "name" -> Enum.sort_by(team_cards, fn card -> Map.get(card, :name, "") end)
      "completion_rate" -> Enum.sort_by(team_cards, fn card -> Map.get(card, :completion_percentage, 0) end, :desc)
      "team_sentiment" -> Enum.sort_by(team_cards, fn card -> Map.get(card, :team_sentiment_score, 0) end, :desc)
      _ -> team_cards # recent_activity or default
    end
  end

  # Helper functions for the template

  def render_performance_badge(team_card) do
    class = cond do
      length(Map.get(team_card, :needs_attention, [])) > 0 ->
        "inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-red-100 text-red-800"
      Map.get(team_card, :team_sentiment_score, 0) > 80 ->
        "inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-green-100 text-green-800"
      Map.get(team_card, :team_sentiment_score, 0) > 60 ->
        "inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-yellow-100 text-yellow-800"
      true ->
        "inline-flex items-center px-2.5 py-1 text-xs font-semibold rounded-full bg-gray-100 text-gray-800"
    end

    text = cond do
      length(Map.get(team_card, :needs_attention, [])) > 0 -> "Needs Attention"
      Map.get(team_card, :team_sentiment_score, 0) > 80 -> "High Performance"
      Map.get(team_card, :team_sentiment_score, 0) > 60 -> "Good"
      true -> "Developing"
    end

    Phoenix.HTML.raw("<span class=\"#{class}\">#{text}</span>")
  end

  def render_vibe_trend_icon(trend) do
    case trend do
      :improving ->
        Phoenix.HTML.raw("""
        <div class="text-green-400" title="Improving sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M3.293 9.707a1 1 0 010-1.414l6-6a1 1 0 011.414 0l6 6a1 1 0 01-1.414 1.414L11 5.414V17a1 1 0 11-2 0V5.414L4.707 9.707a1 1 0 01-1.414 0z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)

      :declining ->
        Phoenix.HTML.raw("""
        <div class="text-red-400" title="Declining sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M16.707 10.293a1 1 0 010 1.414l-6 6a1 1 0 01-1.414 0l-6-6a1 1 0 111.414-1.414L9 14.586V3a1 1 0 012 0v11.586l4.293-4.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="text-gray-400" title="Stable sentiment">
          <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M3 10a1 1 0 011-1h12a1 1 0 110 2H4a1 1 0 01-1-1z" clip-rule="evenodd"/>
          </svg>
        </div>
        """)
    end
  end

  def render_attention_alerts(needs_attention) when is_list(needs_attention) do
    if length(needs_attention) > 0 do
      Phoenix.HTML.raw("""
      <div class="space-y-1">
        #{Enum.map_join(needs_attention, "", fn alert ->
          "<div class=\"flex items-center text-xs text-red-600\">
            <svg class=\"w-3 h-3 mr-1\" fill=\"currentColor\" viewBox=\"0 0 20 20\">
              <path fill-rule=\"evenodd\" d=\"M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z\" clip-rule=\"evenodd\"/>
            </svg>
            #{alert}
          </div>"
        end)}
      </div>
      """)
    else
      Phoenix.HTML.raw("")
    end
  end

  def render_attention_alerts(_), do: Phoenix.HTML.raw("")

  def time_ago(time_string) when is_binary(time_string) do
    time_string
  end

  def time_ago(datetime) when is_struct(datetime) do
    diff_seconds = DateTime.diff(DateTime.utc_now(), datetime, :second)

    cond do
      diff_seconds < 60 -> "Just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      diff_seconds < 604800 -> "#{div(diff_seconds, 86400)}d ago"
      true -> "Over a week ago"
    end
  end

  def time_ago(_), do: "Unknown"

  def lighten_color(hex_color) do
    # Simple color lightening - in a real app you might want a more sophisticated approach
    case hex_color do
      "#" <> rest when byte_size(rest) == 6 ->
        # Parse RGB values and lighten them
        {r, _} = Integer.parse(String.slice(rest, 0, 2), 16)
        {g, _} = Integer.parse(String.slice(rest, 2, 2), 16)
        {b, _} = Integer.parse(String.slice(rest, 4, 2), 16)

        # Lighten by adding 30 to each component (max 255)
        r_light = min(255, r + 30)
        g_light = min(255, g + 30)
        b_light = min(255, b + 30)

        # Convert back to hex
        "#" <>
        String.pad_leading(Integer.to_string(r_light, 16), 2, "0") <>
        String.pad_leading(Integer.to_string(g_light, 16), 2, "0") <>
        String.pad_leading(Integer.to_string(b_light, 16), 2, "0")

      _ -> "#e5e7eb" # Default light gray
    end
  end
end
