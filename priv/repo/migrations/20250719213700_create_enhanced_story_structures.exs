
# priv/repo/migrations/20250719_create_enhanced_story_structures_corrected.exs
defmodule Frestyl.Repo.Migrations.CreateEnhancedStoryStructuresCorrected do
  use Ecto.Migration

  def change do
    create table(:enhanced_story_structures, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :story_type, :string, null: false
      add :narrative_structure, :string, null: false
      add :template_data, :map, default: %{}

      # Enhanced story development fields
      add :character_data, :map, default: %{}
      add :world_bible_data, :map, default: %{}
      add :timeline_data, :map, default: %{}
      add :research_data, :map, default: %{}
      add :ai_suggestions, :map, default: %{}

      # Format-specific data
      add :screenplay_formatting, :map, default: %{}
      add :comic_panels, :map, default: %{}
      add :storyboard_shots, :map, default: %{}
      add :customer_journey_data, :map, default: %{}

      # Collaboration and workflow
      add :collaboration_mode, :string, default: "open"
      add :workflow_stage, :string, default: "development"
      add :approval_status, :string, default: "draft"

      # Metadata
      add :target_word_count, :integer
      add :current_word_count, :integer, default: 0
      add :completion_percentage, :float, default: 0.0
      add :is_public, :boolean, default: false
      add :version, :integer, default: 1

      # Sessions table uses regular :id (bigint), so reference with type: :id
      add :session_id, references(:sessions, type: :id), null: false
      # Users table likely also uses regular :id (bigint)
      add :created_by_id, references(:users, type: :id), null: false

      timestamps()
    end

    create index(:enhanced_story_structures, [:session_id])
    create index(:enhanced_story_structures, [:created_by_id])
    create index(:enhanced_story_structures, [:story_type])
    create index(:enhanced_story_structures, [:workflow_stage])
    create index(:enhanced_story_structures, [:completion_percentage])
  end
end
