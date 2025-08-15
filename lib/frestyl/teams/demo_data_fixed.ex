# Fixed Demo Setup - Corrected Query Issues
# File: lib/frestyl/teams/demo_data_fixed.ex

defmodule Frestyl.Teams.DemoDataFixed do
  @moduledoc """
  Creates realistic demo data for testing the team collaboration system.
  Fixed version with proper Ecto query imports and syntax.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Teams
  alias Frestyl.Channels
  alias Frestyl.Accounts
  alias Frestyl.Repo

  @doc """
  Creates a complete demo scenario with teams, members, and ratings.
  """
  def create_demo_scenario do
    # Create demo channel first
    {:ok, channel} = create_demo_channel()

    # Create demo users
    demo_users = create_demo_users()

    # Add users to channel
    Enum.each(demo_users, fn user ->
      Channels.join_channel(channel.id, user.id)
    end)

    # Create demo teams
    supervisor = get_or_create_instructor()
    teams = create_demo_teams(channel.id, supervisor.id)

    # Assign members to teams
    assign_members_to_teams(teams, demo_users)

    # Generate realistic vibe ratings
    generate_demo_ratings(teams, demo_users)

    # Create activity sessions
    generate_activity_sessions(teams, demo_users)

    # Create some rating reminders
    generate_rating_reminders(teams, demo_users)

    %{
      channel: channel,
      users: demo_users,
      teams: teams,
      supervisor: supervisor,
      scenario_summary: build_scenario_summary(teams, demo_users)
    }
  end

  @doc """
  Quick setup for immediate testing.
  """
  def quick_setup do
    # Clean existing demo data first
    clean_demo_data()

    # Create minimal viable demo
    supervisor = get_or_create_instructor()
    {:ok, channel} = create_demo_channel()

    # Create just 3 students
    students = [
      get_or_create_user(%{first_name: "Sarah", last_name: "Chen", email: "sarah.chen@demo.edu"}),
      get_or_create_user(%{first_name: "Marcus", last_name: "Rodriguez", email: "marcus.r@demo.edu"}),
      get_or_create_user(%{first_name: "Aisha", last_name: "Patel", email: "aisha.patel@demo.edu"})
    ]

    # Add to channel
    Enum.each(students, fn user ->
      Channels.join_channel(channel.id, user.id)
    end)

    # Create one team
    {:ok, team} = Teams.create_team(channel.id, supervisor.id, %{
      name: "Demo Team Alpha",
      project_assignment: "Build a collaborative rating system demo",
      due_date: DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60),
      completion_percentage: 45,
      rating_config: %{
        "organization_type" => "academic",
        "primary_dimension" => "quality",
        "secondary_dimension" => "collaboration_effectiveness",
        "rating_frequency" => "milestone_based"
      }
    })

    # Assign all students to team
    Enum.each(students, fn student ->
      Teams.assign_to_team(team.id, student.id, "member", supervisor.id)
    end)

    # Generate sample ratings
    generate_sample_ratings(team.id, students)

    %{
      channel: channel,
      team: team,
      students: students,
      supervisor: supervisor
    }
  end

  # Private helper functions

  defp clean_demo_data do
    # Clean up in dependency order
    from(r in Teams.VibeRating, where: like(r.rating_prompt, "%demo%")) |> Repo.delete_all()
    from(s in Teams.TeamActivitySession) |> Repo.delete_all()
    from(r in Teams.RatingReminder) |> Repo.delete_all()
    from(m in Teams.TeamMembership) |> Repo.delete_all()
    from(t in Teams.ChannelTeam, where: like(t.name, "%Demo%")) |> Repo.delete_all()

    # Clean demo channels and users
    from(c in Frestyl.Channels.Channel, where: like(c.name, "%Demo%") or like(c.name, "%CS 485%")) |> Repo.delete_all()
    from(u in Frestyl.Accounts.User, where: like(u.email, "%demo.edu") or like(u.email, "%university.edu")) |> Repo.delete_all()
  end

  defp create_demo_channel do
    instructor = get_or_create_instructor()

    Frestyl.Channels.create_channel(%{
      name: "CS 485 - Software Engineering Demo",
      description: "Demo channel for testing team collaboration features",
      channel_type: "academic",
      visibility: "private"
    }, instructor)
  end

  defp create_demo_users do
    users_data = [
      %{first_name: "Sarah", last_name: "Chen", email: "sarah.chen@university.edu"},
      %{first_name: "Marcus", last_name: "Rodriguez", email: "marcus.r@university.edu"},
      %{first_name: "Aisha", last_name: "Patel", email: "aisha.patel@university.edu"},
      %{first_name: "David", last_name: "Kim", email: "david.kim@university.edu"},
      %{first_name: "Emma", last_name: "Thompson", email: "emma.t@university.edu"},
      %{first_name: "Alex", last_name: "Johnson", email: "alex.johnson@university.edu"}
    ]

    Enum.map(users_data, &get_or_create_user/1)
  end

  defp create_demo_teams(channel_id, supervisor_id) do
    teams_data = [
      %{
        name: "Phoenix Innovators",
        project_assignment: "Build a real-time collaborative note-taking application using Phoenix LiveView",
        completion_percentage: 65,
        organization_type: "technical"
      },
      %{
        name: "UX Pioneers",
        project_assignment: "Design and prototype a mobile app for campus sustainability tracking",
        completion_percentage: 42,
        organization_type: "creative"
      }
    ]

    Enum.map(teams_data, fn team_data ->
      due_date = DateTime.add(DateTime.utc_now(), 14 * 24 * 60 * 60)

      {:ok, team} = Teams.create_team(channel_id, supervisor_id, Map.merge(team_data, %{
        due_date: due_date,
        rating_config: %{
          "organization_type" => team_data.organization_type,
          "primary_dimension" => "quality",
          "secondary_dimension" => get_secondary_dimension(team_data.organization_type),
          "rating_frequency" => "milestone_based"
        }
      }))
      team
    end)
  end

  defp assign_members_to_teams(teams, users) do
    # Phoenix Innovators gets first 3 users
    phoenix_team = Enum.at(teams, 0)
    phoenix_members = Enum.take(users, 3)

    Enum.each(phoenix_members, fn member ->
      Teams.assign_to_team(phoenix_team.id, member.id, "member")
    end)

    # UX Pioneers gets next 2 users (leaving 1 unassigned)
    ux_team = Enum.at(teams, 1)
    ux_members = Enum.slice(users, 3, 2)

    Enum.each(ux_members, fn member ->
      Teams.assign_to_team(ux_team.id, member.id, "member")
    end)
  end

  defp generate_demo_ratings(teams, _users) do
    Enum.each(teams, fn team ->
      team_with_members = Teams.get_team!(team.id)

      case team.name do
        "Phoenix Innovators" -> generate_high_performing_ratings(team_with_members)
        "UX Pioneers" -> generate_mixed_performance_ratings(team_with_members)
        _ -> generate_average_ratings(team_with_members)
      end
    end)
  end

  defp generate_high_performing_ratings(team) do
    members = team.members

    # High quality work, excellent collaboration
    Enum.each(members, fn member ->
      other_members = Enum.reject(members, &(&1.id == member.id))

      Enum.each(other_members, fn reviewer ->
        quality = 80 + :rand.uniform(15)  # 80-95 range
        collaboration = 85 + :rand.uniform(10)  # 85-95 range

        create_demo_rating(team.id, reviewer.id, member.id, quality, collaboration)
      end)
    end)
  end

  defp generate_mixed_performance_ratings(team) do
    members = team.members

    # Mixed performance with some issues
    Enum.with_index(members)
    |> Enum.each(fn {member, index} ->
      other_members = Enum.reject(members, &(&1.id == member.id))

      {quality_base, collab_base} = case index do
        0 -> {85, 90}  # High performer
        1 -> {45, 60}  # Struggling member
        _ -> {70, 75}  # Average
      end

      Enum.each(other_members, fn reviewer ->
        quality = quality_base + :rand.uniform(10) - 5
        collaboration = collab_base + :rand.uniform(10) - 5

        create_demo_rating(team.id, reviewer.id, member.id, quality, collaboration)
      end)
    end)
  end

  defp generate_average_ratings(team) do
    members = team.members

    Enum.each(members, fn member ->
      other_members = Enum.reject(members, &(&1.id == member.id))

      Enum.each(other_members, fn reviewer ->
        quality = 65 + :rand.uniform(20)  # 65-85 range
        collaboration = 70 + :rand.uniform(15)  # 70-85 range

        create_demo_rating(team.id, reviewer.id, member.id, quality, collaboration)
      end)
    end)
  end

  defp generate_sample_ratings(team_id, students) do
    Enum.each(students, fn student ->
      other_students = Enum.reject(students, &(&1.id == student.id))

      Enum.each(other_students, fn reviewer ->
        quality = 60 + :rand.uniform(35)  # 60-95 range
        collaboration = 55 + :rand.uniform(35)  # 55-90 range

        create_demo_rating(team_id, reviewer.id, student.id, quality, collaboration)
      end)
    end)
  end

  defp create_demo_rating(team_id, reviewer_id, reviewee_id, quality_score, collaboration_score) do
    Teams.submit_vibe_rating(%{
      team_id: team_id,
      reviewer_id: reviewer_id,
      reviewee_id: reviewee_id,
      primary_score: Float.round(quality_score, 1),
      secondary_score: Float.round(collaboration_score, 1),
      rating_coordinates: %{x: quality_score, y: collaboration_score},
      rating_type: "milestone",
      dimension_context: "quality_collaboration",
      rating_session_duration: :rand.uniform(25000) + 10000,  # 10-35 seconds
      rating_prompt: "Demo rating for team collaboration assessment"
    })
  end

  defp generate_activity_sessions(teams, _users) do
    Enum.each(teams, fn team ->
      team_with_members = Teams.get_team!(team.id)

      # Generate 3-5 sessions per team
      session_count = 3 + :rand.uniform(3)

      1..session_count
      |> Enum.each(fn _ ->
        member = Enum.random(team_with_members.members)
        days_ago = :rand.uniform(7)
        started_at = DateTime.add(DateTime.utc_now(), -days_ago * 24 * 60 * 60)
        duration = 45 + :rand.uniform(90)  # 45-135 minutes

        create_activity_session(team.id, member.id, started_at, duration)
      end)
    end)
  end

  defp create_activity_session(team_id, user_id, started_at, duration_minutes) do
    ended_at = DateTime.add(started_at, duration_minutes * 60)

    attrs = %{
      team_id: team_id,
      user_id: user_id,
      session_type: "collaboration",
      started_at: started_at,
      ended_at: ended_at,
      duration_minutes: duration_minutes,
      activity_data: %{
        tools_used: ["editor", "chat"],
        contributions: :rand.uniform(8)
      }
    }

    %Teams.TeamActivitySession{}
    |> Teams.TeamActivitySession.changeset(attrs)
    |> Repo.insert()
  end

  defp generate_rating_reminders(teams, _users) do
    # Create a few pending reminders
    team = List.first(teams)
    team_with_members = Teams.get_team!(team.id)

    # One member has an overdue reminder
    if length(team_with_members.members) > 0 do
      member = List.first(team_with_members.members)
      due_at = DateTime.add(DateTime.utc_now(), -2 * 24 * 60 * 60)  # 2 days overdue

      attrs = %{
        team_id: team.id,
        user_id: member.id,
        reminder_type: "milestone_rating",
        due_at: due_at,
        escalation_level: 2,
        status: "pending"
      }

      %Teams.RatingReminder{}
      |> Teams.RatingReminder.changeset(attrs)
      |> Repo.insert()
    end
  end

  defp build_scenario_summary(teams, users) do
    %{
      total_teams: length(teams),
      total_users: length(users),
      teams_overview: Enum.map(teams, fn team ->
        team_data = Teams.get_team!(team.id)
        sentiment = Teams.calculate_team_sentiment(team.id)

        %{
          name: team.name,
          member_count: length(team_data.members),
          completion: team.completion_percentage,
          sentiment_score: sentiment.sentiment_score,
          vibe_color: sentiment.overall_vibe_color
        }
      end)
    }
  end

  # Helper functions
  defp get_or_create_instructor do
    email = "prof.anderson@university.edu"

    case Frestyl.Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Frestyl.Accounts.create_user(%{
          first_name: "Dr. Jennifer",
          last_name: "Anderson",
          email: email
        })
        user
      user -> user
    end
  end

  defp get_or_create_user(%{first_name: first_name, last_name: last_name, email: email}) do
    case Frestyl.Accounts.get_user_by_email(email) do
      nil ->
        {:ok, user} = Frestyl.Accounts.create_user(%{
          first_name: first_name,
          last_name: last_name,
          email: email
        })
        user
      user -> user
    end
  end

  defp get_secondary_dimension(organization_type) do
    case organization_type do
      "academic" -> "collaboration_effectiveness"
      "creative" -> "innovation_level"
      "business" -> "commercial_viability"
      "technical" -> "technical_execution"
      _ -> "collaboration_effectiveness"
    end
  end
end

# Simple commands for testing
defmodule Frestyl.Teams.Demo do
  @doc """
  Quick demo setup command.
  """
  def setup! do
    case Frestyl.Teams.DemoDataFixed.quick_setup() do
      %{} = demo_data ->
        IO.puts("✅ Demo setup complete!")
        IO.puts("Channel: #{demo_data.channel.name}")
        IO.puts("Team: #{demo_data.team.name}")
        IO.puts("Students: #{length(demo_data.students)}")

        # Show supervisor dashboard
        dashboard = Frestyl.Teams.get_supervisor_dashboard(demo_data.supervisor.id)
        IO.puts("Teams with data: #{length(dashboard.team_cards)}")

        demo_data
      error ->
        IO.puts("❌ Demo setup failed: #{inspect(error)}")
        error
    end
  end

  @doc """
  Reset demo data.
  """
  def reset! do
    Frestyl.Teams.DemoDataFixed.clean_demo_data()
    IO.puts("✅ Demo data cleaned!")
  end
end
