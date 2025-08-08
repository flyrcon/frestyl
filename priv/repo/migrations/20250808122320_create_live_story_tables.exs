# priv/repo/migrations/20250808120002_create_live_story_tables.exs
defmodule Frestyl.Repo.Migrations.CreateLiveStoryTables do
  use Ecto.Migration

  def change do
    # Main Live Story Sessions
    create table(:live_story_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :story_concept, :map, default: %{}
      add :current_narrative_state, :map, default: %{}
      add :session_state, :string, default: "preparing" # preparing, live, paused, ended
      add :streaming_config, :map, default: %{}
      add :audience_interaction_settings, :map, default: %{}
      add :recording_settings, :map, default: %{}
      add :scheduled_start_time, :utc_datetime
      add :actual_start_time, :utc_datetime
      add :end_time, :utc_datetime
      add :duration_minutes, :integer, default: 0
      add :max_audience_size, :integer, default: 100
      add :is_public, :boolean, default: true
      add :archive_enabled, :boolean, default: true

      add :session_id, references(:sessions), null: false
      add :created_by_id, references(:users, type: :id), null: false

      timestamps()
    end

    # Story Branches (for branching narratives based on audience input)
    create table(:story_branches, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :branch_name, :string, null: false
      add :branch_description, :text
      add :parent_branch_id, references(:story_branches, type: :binary_id)
      add :story_content, :map, default: %{}
      add :narrative_state, :map, default: %{}
      add :choice_point_data, :map, default: %{}
      add :is_active, :boolean, default: false
      add :audience_votes, :integer, default: 0
      add :selection_timestamp, :utc_datetime
      add :created_by_narrator_id, references(:users, type: :id)

      timestamps()
    end

    # Audience Interactions (votes, comments, suggestions)
    create table(:audience_interactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :story_branch_id, references(:story_branches, type: :binary_id)
      add :interaction_type, :string, null: false # vote, comment, suggestion, reaction
      add :content, :text
      add :interaction_data, :map, default: %{}
      add :timestamp, :utc_datetime, null: false
      add :is_anonymous, :boolean, default: false
      add :user_identifier, :string # For anonymous users
      add :weight, :float, default: 1.0 # For weighted voting
      add :is_processed, :boolean, default: false

      add :user_id, references(:users, type: :id) # Null for anonymous users

      timestamps()
    end

    # Narrator Collaborations (multiple storytellers)
    create table(:narrator_collaborations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :id), null: false
      add :narrator_role, :string, null: false # primary, secondary, voice_actor, director
      add :permissions, :map, default: %{}
      add :character_assignments, {:array, :string}, default: []
      add :active_segments, {:array, :string}, default: []
      add :contribution_stats, :map, default: %{}
      add :last_activity_at, :utc_datetime
      add :is_currently_speaking, :boolean, default: false
      add :speaking_order, :integer

      timestamps()
    end

    # Live Events (real-time narrative events and milestones)
    create table(:live_story_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :event_type, :string, null: false # story_beat, choice_point, narrator_change, audience_milestone
      add :event_data, :map, default: %{}
      add :timestamp, :utc_datetime, null: false
      add :narrator_id, references(:users, type: :id)
      add :triggered_by, :string # audience_vote, narrator_action, system_event
      add :impact_on_story, :map, default: %{}
      add :audience_reaction, :map, default: %{}

      timestamps()
    end

    # Session Archives (recordings and transcripts)
    create table(:session_archives, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :archive_type, :string, null: false # video, audio, transcript, session_data
      add :file_path, :string
      add :file_size, :bigint
      add :duration_seconds, :integer
      add :metadata, :map, default: %{}
      add :processing_status, :string, default: "pending" # pending, processing, complete, failed
      add :is_public, :boolean, default: false
      add :download_count, :integer, default: 0

      timestamps()
    end

    # Audience Analytics (engagement and participation metrics)
    create table(:audience_analytics, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :id) # Null for anonymous users
      add :user_identifier, :string # For tracking anonymous users
      add :session_duration, :integer # How long they stayed
      add :interaction_count, :integer, default: 0
      add :votes_cast, :integer, default: 0
      add :comments_made, :integer, default: 0
      add :engagement_score, :float, default: 0.0
      add :join_timestamp, :utc_datetime
      add :leave_timestamp, :utc_datetime
      add :device_info, :map, default: %{}
      add :referral_source, :string

      timestamps()
    end

    # Choice Templates (pre-defined choice patterns for quick story branching)
    create table(:choice_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :template_name, :string, null: false
      add :description, :text
      add :choice_pattern, :map, default: %{}
      add :genre_tags, {:array, :string}, default: []
      add :difficulty_level, :string, default: "medium" # easy, medium, hard
      add :usage_count, :integer, default: 0
      add :community_rating, :float, default: 0.0
      add :is_public, :boolean, default: true

      add :created_by_id, references(:users, type: :id), null: false

      timestamps()
    end

    # Live Chat Messages (audience chat during live sessions)
    create table(:live_chat_messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :live_story_session_id, references(:live_story_sessions, type: :binary_id), null: false
      add :user_id, references(:users, type: :id) # Null for anonymous users
      add :user_identifier, :string # For anonymous users
      add :message_content, :text, null: false
      add :message_type, :string, default: "chat" # chat, system, moderator, narrator
      add :timestamp, :utc_datetime, null: false
      add :is_highlighted, :boolean, default: false # Highlighted by moderator
      add :is_moderated, :boolean, default: false
      add :moderation_reason, :string
      add :reply_to_message_id, references(:live_chat_messages, type: :binary_id)

      timestamps()
    end

    # Indexes for performance
    create index(:live_story_sessions, [:session_id])
    create index(:live_story_sessions, [:created_by_id])
    create index(:live_story_sessions, [:session_state])
    create index(:live_story_sessions, [:scheduled_start_time])
    create index(:live_story_sessions, [:is_public])

    create index(:story_branches, [:live_story_session_id])
    create index(:story_branches, [:parent_branch_id])
    create index(:story_branches, [:is_active])
    create index(:story_branches, [:created_by_narrator_id])

    create index(:audience_interactions, [:live_story_session_id])
    create index(:audience_interactions, [:story_branch_id])
    create index(:audience_interactions, [:interaction_type])
    create index(:audience_interactions, [:timestamp])
    create index(:audience_interactions, [:user_id])
    create index(:audience_interactions, [:is_processed])

    create index(:narrator_collaborations, [:live_story_session_id, :user_id])
    create index(:narrator_collaborations, [:narrator_role])
    create index(:narrator_collaborations, [:is_currently_speaking])

    create index(:live_story_events, [:live_story_session_id])
    create index(:live_story_events, [:event_type])
    create index(:live_story_events, [:timestamp])
    create index(:live_story_events, [:narrator_id])

    create index(:session_archives, [:live_story_session_id])
    create index(:session_archives, [:archive_type])
    create index(:session_archives, [:processing_status])
    create index(:session_archives, [:is_public])

    create index(:audience_analytics, [:live_story_session_id])
    create index(:audience_analytics, [:user_id])
    create index(:audience_analytics, [:join_timestamp])

    create index(:choice_templates, [:created_by_id])
    create index(:choice_templates, [:is_public])
    create index(:choice_templates, [:genre_tags], using: :gin)

    create index(:live_chat_messages, [:live_story_session_id])
    create index(:live_chat_messages, [:timestamp])
    create index(:live_chat_messages, [:user_id])
    create index(:live_chat_messages, [:message_type])
    create index(:live_chat_messages, [:reply_to_message_id])
  end
end
