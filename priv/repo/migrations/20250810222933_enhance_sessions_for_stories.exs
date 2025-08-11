# priv/repo/migrations/20250810000004_enhance_sessions_for_stories.exs
defmodule Frestyl.Repo.Migrations.EnhanceSessionsForStories do
  use Ecto.Migration

  def change do
    # Add story-specific metadata to sessions
    alter table(:sessions) do
      add :story_metadata, :map, default: %{}
      add :collaboration_features, {:array, :string}, default: []
      add :audio_features_enabled, :boolean, default: false
    end

    # Index for story-related session queries
    create index(:sessions, [:story_metadata], using: :gin)
    create index(:sessions, [:audio_features_enabled])
  end
end
