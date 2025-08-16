# priv/repo/migrations/20250815000003_update_sessions_for_unified_system.exs
defmodule Frestyl.Repo.Migrations.UpdateSessionsForUnifiedSystem do
  use Ecto.Migration

  def change do
    # Add new session types for unified system
    alter table(:sessions) do
      add :metadata, :map, default: %{}
      add :collaboration_enabled, :boolean, default: true
      add :recording_quality, :string
      add :streaming_quality, :string
      add_if_not_exists :max_participants, :integer
      add :session_mode, :string # broadcast, consultation, tutorial, collaboration, podcast_recording
      add :feature_flags, :map, default: %{}
    end

    create index(:sessions, [:session_mode])
    create index(:sessions, [:session_type])
  end
end
