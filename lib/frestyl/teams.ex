# Teams Context Module
# File: lib/frestyl/teams.ex

defmodule Frestyl.Teams do
  @moduledoc """
  The Teams context for managing team collaboration, ratings, and supervision.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo
  alias Frestyl.Teams.{ChannelTeam, TeamMembership, VibeRating, TeamActivitySession, RatingReminder}

  # ============================================================================
  # TEAM MANAGEMENT
  # ============================================================================

  @doc """
  Creates a team within a channel.
  """
  def create_team(channel_id, creator_id, attrs \\ %{}) do
    %ChannelTeam{}
    |> ChannelTeam.changeset(Map.merge(attrs, %{
      channel_id: channel_id,
      created_by_id: creator_id
    }))
    |> Repo.insert()
  end

  @doc """
  Gets a team by ID with preloaded associations.
  """
  def get_team!(id) do
    Repo.get!(ChannelTeam, id)
    |> Repo.preload([:supervisor, :created_by, :members, :team_memberships])
  end

  @doc """
  Lists all teams for a supervisor.
  """
  def list_supervisor_teams(supervisor_id) do
    from(t in ChannelTeam,
      where: t.supervisor_id == ^supervisor_id,
      preload: [:members, :team_memberships]
    )
    |> Repo.all()
  end

  @doc """
  Lists teams in a channel.
  """
  def list_channel_teams(channel_id) do
    from(t in ChannelTeam,
      where: t.channel_id == ^channel_id,
      preload: [:supervisor, :members, :team_memberships]
    )
    |> Repo.all()
  end

  @doc """
  Assigns a user to a team.
  """
  def assign_to_team(team_id, user_id, role \\ "member", assigned_by_id \\ nil) do
    %TeamMembership{}
    |> TeamMembership.changeset(%{
      team_id: team_id,
      user_id: user_id,
      role: role,
      assigned_by_id: assigned_by_id,
      joined_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  @doc """
  Removes a user from a team.
  """
  def remove_from_team(team_id, user_id) do
    from(m in TeamMembership,
      where: m.team_id == ^team_id and m.user_id == ^user_id
    )
    |> Repo.delete_all()
  end

  @doc """
  Updates team completion percentage.
  """
  def update_team_completion(team_id, percentage) do
    team = Repo.get!(ChannelTeam, team_id)

    team
    |> ChannelTeam.changeset(%{completion_percentage: percentage})
    |> Repo.update()
  end

  # ============================================================================
  # VIBE RATING SYSTEM
  # ============================================================================

  @doc """
  Submits a vibe rating for a team member.
  """
  def submit_vibe_rating(attrs) do
    %VibeRating{}
    |> VibeRating.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, rating} ->
        # Trigger reminder completion
        complete_rating_reminder(rating.team_id, rating.reviewer_id, rating.rating_type)
        {:ok, rating}
      error -> error
    end
  end

  @doc """
  Gets all vibe ratings for a team.
  """
  def list_team_ratings(team_id, opts \\ []) do
    query = from(r in VibeRating,
      where: r.team_id == ^team_id,
      preload: [:reviewer, :reviewee],
      order_by: [desc: r.inserted_at]
    )

    query =
      case Keyword.get(opts, :rating_type) do
        nil -> query
        type -> from(r in query, where: r.rating_type == ^type)
      end

    query =
      case Keyword.get(opts, :limit) do
        nil -> query
        limit -> from(r in query, limit: ^limit)
      end

    Repo.all(query)
  end

  @doc """
  Calculates team sentiment metrics.
  """
  def calculate_team_sentiment(team_id) do
    ratings = list_team_ratings(team_id, limit: 50)

    if length(ratings) == 0 do
      %{
        overall_vibe_color: "#64748b",
        sentiment_score: 50.0,
        quality_average: 2.5,
        collaboration_average: 2.5,
        rating_count: 0,
        trend: :insufficient_data
      }
    else
      primary_scores = Enum.map(ratings, & &1.primary_score)
      secondary_scores = Enum.map(ratings, & &1.secondary_score)

      avg_primary = Enum.sum(primary_scores) / length(primary_scores)
      avg_secondary = Enum.sum(secondary_scores) / length(secondary_scores)

      %{
        overall_vibe_color: hue_to_hex_color(avg_primary),
        sentiment_score: avg_primary,
        quality_average: avg_primary / 20.0, # Convert to 1-5 scale
        collaboration_average: avg_secondary / 20.0,
        rating_count: length(ratings),
        trend: calculate_sentiment_trend(team_id)
      }
    end
  end

  @doc """
  Gets individual member performance summary.
  """
  def get_member_performance(team_id, user_id) do
    ratings_received = from(r in VibeRating,
      where: r.team_id == ^team_id and r.reviewee_id == ^user_id,
      preload: [:reviewer]
    ) |> Repo.all()

    ratings_given = from(r in VibeRating,
      where: r.team_id == ^team_id and r.reviewer_id == ^user_id,
      preload: [:reviewee]
    ) |> Repo.all()

    if length(ratings_received) == 0 do
      %{
        avg_quality_score: 0.0,
        avg_collaboration_score: 0.0,
        ratings_received_count: 0,
        ratings_given_count: length(ratings_given),
        participation_rate: 0.0,
        peer_feedback: []
      }
    else
      avg_quality = ratings_received
                   |> Enum.map(& &1.primary_score)
                   |> Enum.sum()
                   |> Kernel./(length(ratings_received))

      avg_collaboration = ratings_received
                         |> Enum.map(& &1.secondary_score)
                         |> Enum.sum()
                         |> Kernel./(length(ratings_received))

      %{
        avg_quality_score: avg_quality / 20.0, # Convert to 1-5 scale
        avg_collaboration_score: avg_collaboration / 20.0,
        ratings_received_count: length(ratings_received),
        ratings_given_count: length(ratings_given),
        participation_rate: calculate_participation_rate(team_id, user_id),
        peer_feedback: format_peer_feedback(ratings_received)
      }
    end
  end

  # ============================================================================
  # SUPERVISOR DASHBOARD
  # ============================================================================

  @doc """
  Gets supervisor dashboard data with team summary cards.
  """
  def get_supervisor_dashboard(supervisor_id) do
    teams = list_supervisor_teams(supervisor_id)

    team_cards = Enum.map(teams, fn team ->
      sentiment = calculate_team_sentiment(team.id)
      activity = calculate_team_activity_metrics(team.id)

      %{
        team_id: team.id,
        team_name: team.name,
        project_title: team.project_assignment,
        member_count: length(team.members),
        active_members: count_active_members(team.id),

        # Vibe metrics
        overall_vibe: sentiment.overall_vibe_color,
        vibe_trend: sentiment.trend,
        team_sentiment_score: sentiment.sentiment_score,

        # Activity metrics
        completion_percentage: team.completion_percentage,
        total_hours: activity.total_hours,
        avg_daily_hours: activity.avg_daily_hours,
        last_activity: activity.last_activity,

        # Quality metrics
        peer_review_avg: sentiment.quality_average,
        collaboration_score: sentiment.collaboration_average,

        # Alert indicators
        needs_attention: identify_team_issues(team.id),
        performance_alerts: get_performance_alerts(team.id)
      }
    end)

    %{
      team_cards: team_cards,
      total_teams: length(teams),
      teams_needing_attention: Enum.count(team_cards, &(length(&1.needs_attention) > 0)),
      overall_completion_avg: calculate_overall_completion_average(team_cards)
    }
  end

  @doc """
  Gets detailed team view for supervisor.
  """
  def get_team_detail_view(team_id) do
    team = get_team!(team_id)

    %{
      team: team,
      member_performances: get_all_member_performances(team_id),
      activity_timeline: get_team_activity_timeline(team_id),
      vibe_distribution: get_vibe_rating_distribution(team_id),
      collaboration_network: get_peer_rating_network(team_id),
      milestone_progress: get_milestone_completion(team_id),
      quality_trends: get_quality_trend_data(team_id),
      intervention_history: get_intervention_history(team_id)
    }
  end

  # ============================================================================
  # RATING REMINDERS SYSTEM
  # ============================================================================

  @doc """
  Creates rating reminders for team members.
  """
  def create_rating_reminders(team_id, reminder_type, due_at) do
    team = get_team!(team_id)

    Enum.each(team.members, fn member ->
      %RatingReminder{}
      |> RatingReminder.changeset(%{
        team_id: team_id,
        user_id: member.id,
        reminder_type: reminder_type,
        due_at: due_at
      })
      |> Repo.insert()
    end)
  end

  @doc """
  Gets pending reminders for a user.
  """
  def get_pending_reminders(user_id) do
    from(r in RatingReminder,
      where: r.user_id == ^user_id and r.status == "pending" and r.due_at <= ^DateTime.utc_now(),
      preload: [:team],
      order_by: [asc: r.due_at]
    )
    |> Repo.all()
  end

  @doc """
  Escalates overdue reminders.
  """
  def escalate_overdue_reminders() do
    overdue_threshold = DateTime.add(DateTime.utc_now(), -24 * 60 * 60) # 24 hours ago

    from(r in RatingReminder,
      where: r.status == "pending" and r.due_at < ^overdue_threshold,
      update: [inc: [escalation_level: 1], set: [last_reminded_at: ^DateTime.utc_now()]]
    )
    |> Repo.update_all([])
  end

  @doc """
  Completes a rating reminder.
  """
  def complete_rating_reminder(team_id, user_id, reminder_type) do
    from(r in RatingReminder,
      where: r.team_id == ^team_id and r.user_id == ^user_id and
             r.reminder_type == ^reminder_type and r.status == "pending"
    )
    |> Repo.update_all(set: [status: "completed", completed_at: DateTime.utc_now()])
  end

  # ============================================================================
  # INTERVENTION SYSTEM
  # ============================================================================

  @doc """
  Checks for teams needing intervention.
  """
  def check_intervention_triggers() do
    teams = from(t in ChannelTeam, where: t.status == "active") |> Repo.all()

    Enum.flat_map(teams, fn team ->
      issues = identify_team_issues(team.id)
      Enum.map(issues, &create_intervention_alert(team.id, &1))
    end)
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp hue_to_hex_color(hue_value) do
    # Convert 0-100 hue to red-green gradient
    hue = (hue_value / 100.0) * 120 # 0 = red, 120 = green
    saturation = 75
    lightness = 50

    # Convert HSL to RGB to HEX
    hsl_to_hex(hue, saturation, lightness)
  end

  defp hsl_to_hex(h, s, l) do
    h = h / 360
    s = s / 100
    l = l / 100

    c = (1 - abs(2 * l - 1)) * s
    x = c * (1 - abs(rem(h * 6, 2) - 1))
    m = l - c / 2

    {r, g, b} = case trunc(h * 6) do
      0 -> {c, x, 0}
      1 -> {x, c, 0}
      2 -> {0, c, x}
      3 -> {0, x, c}
      4 -> {x, 0, c}
      5 -> {c, 0, x}
      _ -> {0, 0, 0}
    end

    r = trunc((r + m) * 255)
    g = trunc((g + m) * 255)
    b = trunc((b + m) * 255)

    r_hex = Integer.to_string(r, 16) |> String.pad_leading(2, "0")
    g_hex = Integer.to_string(g, 16) |> String.pad_leading(2, "0")
    b_hex = Integer.to_string(b, 16) |> String.pad_leading(2, "0")

    "#" <> r_hex <> g_hex <> b_hex
  end

  defp calculate_sentiment_trend(team_id) do
    recent_ratings = from(r in VibeRating,
      where: r.team_id == ^team_id,
      order_by: [desc: r.inserted_at],
      limit: 20
    ) |> Repo.all()

    if length(recent_ratings) < 10 do
      :insufficient_data
    else
      {recent, older} = Enum.split(recent_ratings, 10)

      recent_avg = recent |> Enum.map(& &1.primary_score) |> Enum.sum() |> Kernel./(10)
      older_avg = older |> Enum.map(& &1.primary_score) |> Enum.sum() |> Kernel./(10)

      cond do
        recent_avg > older_avg + 5 -> :improving
        recent_avg < older_avg - 5 -> :declining
        true -> :stable
      end
    end
  end

  defp calculate_team_activity_metrics(team_id) do
    thirty_days_ago = DateTime.add(DateTime.utc_now(), -30 * 24 * 60 * 60)

    sessions = from(s in TeamActivitySession,
      where: s.team_id == ^team_id and s.started_at > ^thirty_days_ago,
      order_by: [desc: s.started_at]
    ) |> Repo.all()

    total_minutes = sessions |> Enum.map(&(&1.duration_minutes || 0)) |> Enum.sum()

    %{
      total_hours: Float.round(total_minutes / 60.0, 1),
      avg_daily_hours: Float.round(total_minutes / 60.0 / 30, 1),
      last_activity: case sessions do
        [] -> nil
        [latest | _] -> latest.started_at
      end,
      session_count: length(sessions)
    }
  end

  defp identify_team_issues(team_id) do
    sentiment = calculate_team_sentiment(team_id)
    activity = calculate_team_activity_metrics(team_id)

    issues = []

    # Low sentiment
    issues = if sentiment.sentiment_score < 40 do
      ["low_team_sentiment" | issues]
    else
      issues
    end

    # Low activity
    issues = if activity.avg_daily_hours < 0.5 do
      ["low_activity" | issues]
    else
      issues
    end

    # High collaboration variance
    issues = if has_high_collaboration_variance?(team_id) do
      ["collaboration_variance" | issues]
    else
      issues
    end

    issues
  end

  defp has_high_collaboration_variance?(team_id) do
    ratings = list_team_ratings(team_id, limit: 30)

    if length(ratings) < 5 do
      false
    else
      collaboration_scores = ratings |> Enum.map(& &1.secondary_score)
      variance = calculate_variance(collaboration_scores)
      variance > 400 # High variance threshold
    end
  end

  defp calculate_variance(numbers) do
    mean = Enum.sum(numbers) / length(numbers)
    squared_diffs = Enum.map(numbers, &:math.pow(&1 - mean, 2))
    Enum.sum(squared_diffs) / length(squared_diffs)
  end

  defp count_active_members(team_id) do
    from(m in TeamMembership,
      where: m.team_id == ^team_id and m.status == "active"
    )
    |> Repo.aggregate(:count, :id)
  end

  defp calculate_participation_rate(team_id, user_id) do
    # Calculate based on activity sessions and rating participation
    total_team_sessions = from(s in TeamActivitySession,
      where: s.team_id == ^team_id
    ) |> Repo.aggregate(:count, :id)

    user_sessions = from(s in TeamActivitySession,
      where: s.team_id == ^team_id and s.user_id == ^user_id
    ) |> Repo.aggregate(:count, :id)

    if total_team_sessions == 0 do
      0.0
    else
      Float.round(user_sessions / total_team_sessions * 100, 1)
    end
  end

  defp format_peer_feedback(ratings) do
    ratings
    |> Enum.take(5)
    |> Enum.map(fn rating ->
      %{
        reviewer_name: rating.reviewer.first_name,
        quality_score: rating.primary_score / 20.0,
        collaboration_score: rating.secondary_score / 20.0,
        timestamp: rating.inserted_at
      }
    end)
  end

  defp get_all_member_performances(team_id) do
    team = get_team!(team_id)

    Enum.map(team.members, fn member ->
      performance = get_member_performance(team_id, member.id)
      Map.put(performance, :member, member)
    end)
  end

  defp get_performance_alerts(team_id) do
    # Implementation for specific performance alerts
    []
  end

  defp calculate_overall_completion_average(team_cards) do
    if length(team_cards) == 0 do
      0
    else
      team_cards
      |> Enum.map(& &1.completion_percentage)
      |> Enum.sum()
      |> Kernel./(length(team_cards))
      |> Float.round(1)
    end
  end

  # Placeholder implementations for complex features
  defp get_team_activity_timeline(_team_id), do: []
  defp get_vibe_rating_distribution(_team_id), do: %{}
  defp get_peer_rating_network(_team_id), do: %{}
  defp get_milestone_completion(_team_id), do: %{}
  defp get_quality_trend_data(_team_id), do: []
  defp get_intervention_history(_team_id), do: []
  defp create_intervention_alert(_team_id, _issue), do: :ok
end
