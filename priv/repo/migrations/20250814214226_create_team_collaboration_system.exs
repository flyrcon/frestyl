# Database Schema for Team Collaboration System
# File: priv/repo/migrations/xxx_create_team_collaboration_system.exs

defmodule Frestyl.Repo.Migrations.CreateTeamCollaborationSystem do
  use Ecto.Migration

  def change do
    # Channel Teams - Groups within channels
    create table(:channel_teams) do
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :project_assignment, :text
      add :supervisor_id, references(:users, on_delete: :nilify_all)
      add :created_by_id, references(:users, on_delete: :nilify_all), null: false
      add :status, :string, default: "active" # active, archived, completed
      add :due_date, :utc_datetime
      add :completion_percentage, :integer, default: 0
      add :metadata, :map, default: %{}

      # Rating configuration
      add :rating_config, :map, default: %{
        "primary_dimension" => "quality",
        "secondary_dimension" => "collaboration_effectiveness",
        "organization_type" => "academic",
        "rating_frequency" => "milestone_based",
        "intervention_thresholds" => %{
          "sentiment_deviation" => 2.0,
          "collaboration_variance" => 3.0,
          "completion_threshold" => 50
        }
      }

      timestamps()
    end

    # Team Memberships
    create table(:team_memberships) do
      add :team_id, references(:channel_teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :role, :string, default: "member" # member, team_lead
      add :assigned_by_id, references(:users, on_delete: :nilify_all)
      add :status, :string, default: "active" # active, inactive, removed
      add :joined_at, :utc_datetime, default: fragment("now()")
      add :participation_score, :float, default: 0.0
      add :contribution_tokens, :integer, default: 0

      timestamps()
    end

    # Vibe Ratings - Color-based peer ratings
    create table(:vibe_ratings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:channel_teams, on_delete: :delete_all), null: false
      add :reviewer_id, references(:users, on_delete: :delete_all), null: false
      add :reviewee_id, references(:users, on_delete: :delete_all), null: false
      add :session_id, :string # Optional: link to collaboration session

      # Color gradient ratings (0-100 values)
      add :primary_score, :float, null: false # Horizontal axis (red to green)
      add :secondary_score, :float # Vertical axis (configurable dimension)
      add :rating_coordinates, :map # {x: 73, y: 45} for exact positioning

      # Rating context
      add :rating_type, :string, default: "peer_review" # peer_review, milestone, pulse_check
      add :dimension_context, :string # collaboration_effectiveness, innovation_level, etc.
      add :rating_session_duration, :integer # How long they spent considering (ms)
      add :is_self_rating, :boolean, default: false

      # Translated scores for analytics
      add :translated_scores, :map, default: %{
        "quality" => 0.0,
        "collaboration" => 0.0
      }

      # Rating metadata
      add :rating_prompt, :text # What specific question/context was rated
      add :milestone_checkpoint, :string # "25%", "50%", "75%", "final"

      timestamps()
    end

    # Team Activity Sessions - Track collaboration time
    create table(:team_activity_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:channel_teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :session_type, :string # collaboration, meeting, individual_work
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_minutes, :integer
      add :activity_data, :map # Tools used, contributions made, etc.
      add :quality_score, :float # Derived from peer ratings of this session

      timestamps()
    end

    # Supervisor Interventions - Track when supervisors take action
    create table(:supervisor_interventions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:channel_teams, on_delete: :delete_all), null: false
      add :supervisor_id, references(:users, on_delete: :delete_all), null: false
      add :trigger_reason, :string # sentiment_low, collaboration_variance, completion_lagging
      add :intervention_type, :string # message, check_in, reassignment, deadline_extension
      add :trigger_data, :map # The metrics that caused the trigger
      add :action_taken, :text
      add :outcome, :text
      add :resolved_at, :utc_datetime

      timestamps()
    end

    # Rating Reminders - Track reminder state
    create table(:rating_reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :team_id, references(:channel_teams, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :reminder_type, :string # pulse_check, milestone_rating
      add :due_at, :utc_datetime, null: false
      add :escalation_level, :integer, default: 0 # 0=badge, 1=modal, 2=persistent, 3=supervisor
      add :last_reminded_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :status, :string, default: "pending" # pending, completed, escalated

      timestamps()
    end

    # Indexes for performance
    create unique_index(:team_memberships, [:team_id, :user_id])
    create unique_index(:vibe_ratings, [:team_id, :reviewer_id, :reviewee_id, :rating_type, :inserted_at])
    create index(:vibe_ratings, [:team_id, :rating_type])
    create index(:vibe_ratings, [:reviewee_id])
    create index(:team_activity_sessions, [:team_id, :started_at])
    create index(:supervisor_interventions, [:team_id, :inserted_at])
    create index(:rating_reminders, [:user_id, :status, :due_at])
    create index(:channel_teams, [:supervisor_id])
    create index(:channel_teams, [:channel_id])
  end
end
