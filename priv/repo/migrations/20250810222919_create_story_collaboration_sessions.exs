# priv/repo/migrations/20250810000003_create_story_collaboration_sessions.exs
defmodule Frestyl.Repo.Migrations.CreateStoryCollaborationSessions do
  use Ecto.Migration

  def change do
    create table(:story_collaboration_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :story_id, references(:enhanced_story_structures, type: :uuid, on_delete: :delete_all), null: false
      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :collaboration_type, :string, null: false
      add :collaboration_settings, :map, default: %{}
      add :status, :string, default: "active"  # active, paused, ended

      timestamps(type: :utc_datetime)
    end

    # Ensure unique story-session pairing
    create unique_index(:story_collaboration_sessions, [:story_id, :session_id])

    # Indexes for lookups
    create index(:story_collaboration_sessions, [:story_id])
    create index(:story_collaboration_sessions, [:session_id])
    create index(:story_collaboration_sessions, [:collaboration_type])
    create index(:story_collaboration_sessions, [:status])
  end
end
