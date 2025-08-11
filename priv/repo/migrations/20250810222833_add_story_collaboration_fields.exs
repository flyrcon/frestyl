# priv/repo/migrations/20250810000001_add_story_collaboration_fields.exs
defmodule Frestyl.Repo.Migrations.AddStoryCollaborationFields do
  use Ecto.Migration

  def change do
    # Add collaboration fields to enhanced_story_structures
    alter table(:enhanced_story_structures) do
      add_if_not_exists :collaboration_mode, :string, default: "owner_only"
      add :audio_features_enabled, :boolean, default: false
      add :voice_notes_data, :map, default: %{}
      add_if_not_exists :collaboration_metadata, :map, default: %{}
    end

    # Add indexes for performance
    create_if_not_exists index(:enhanced_story_structures, [:session_id])
    create_if_not_exists index(:enhanced_story_structures, [:collaboration_mode])
    create_if_not_exists index(:enhanced_story_structures, [:audio_features_enabled])
  end
end
