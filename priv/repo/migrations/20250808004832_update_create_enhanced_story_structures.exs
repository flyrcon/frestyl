# priv/repo/migrations/20250108000004_create_enhanced_story_structures.exs
defmodule Frestyl.Repo.Migrations.CreateEnhancedStoryStructures do
  use Ecto.Migration

  def change do
    alter table(:enhanced_story_structures, primary_key: {:id, :binary_id}) do

      # Core Story Information
      add_if_not_exists :title, :string, null: false
      add_if_not_exists :description, :text
      add_if_not_exists :story_type, :string, null: false
      add_if_not_exists :narrative_structure, :string, null: false
      add_if_not_exists :intent_category, :string
      add_if_not_exists :creation_source, :string, default: "direct"
      add_if_not_exists :quick_start_template, :string

      # Content and Structure
      add_if_not_exists :content, :map, default: "{}"
      add_if_not_exists :template_data, :map, default: "{}"
      add_if_not_exists :outline, :map, default: "{}"
      add_if_not_exists :sections, {:array, :map}, default: []

      # Story Development Data
      add_if_not_exists :character_data, :map, default: "{}"
      add_if_not_exists :world_bible_data, :map, default: "{}"
      add_if_not_exists :timeline_data, :map, default: "{}"
      add_if_not_exists :research_data, :map, default: "{}"
      add_if_not_exists :format_metadata, :map, default: "{}"

      # Format-Specific Data
      add_if_not_exists :screenplay_formatting, :map, default: "{}"
      add_if_not_exists :comic_panels, :map, default: "{}"
      add_if_not_exists :storyboard_shots, :map, default: "{}"
      add_if_not_exists :customer_journey_data, :map, default: "{}"
      add_if_not_exists :audio_data, :map, default: "{}"
      add_if_not_exists :visual_data, :map, default: "{}"

      # AI and Enhancement Features
      add_if_not_exists :ai_suggestions, :map, default: "{\"active\": [], \"history\": []}"
      add_if_not_exists :ai_assistance_level, :string, default: "basic"
      add_if_not_exists :enhancement_requests, {:array, :map}, default: []

      # Collaboration and Workflow
      add_if_not_exists :collaboration_mode, :string, default: "owner_only"
      add_if_not_exists :collaboration_intent, :string
      add_if_not_exists :workflow_stage, :string, default: "development"
      add_if_not_exists :approval_status, :string, default: "draft"
      add_if_not_exists :collaborators, {:array, :string}, default: []
      add_if_not_exists :permissions, :map, default: "{}"
      add_if_not_exists :comments, {:array, :map}, default: []

      # Progress and Analytics
      add_if_not_exists :target_word_count, :integer
      add_if_not_exists :current_word_count, :integer, default: 0
      add_if_not_exists :completion_percentage, :float, default: 0.0
      add_if_not_exists :progress, :integer, default: 0
      add_if_not_exists :version, :integer, default: 1
      add_if_not_exists :revision_history, {:array, :map}, default: []

      # Publication and Sharing
      add_if_not_exists :is_public, :boolean, default: false
      add_if_not_exists :is_featured, :boolean, default: false
      add_if_not_exists :published_at, :utc_datetime
      add_if_not_exists :archived_at, :utc_datetime

      # User Preferences and Settings
      add_if_not_exists :user_preferences, :map, default: "{}"
      add_if_not_exists :privacy_settings, :map, default: "{}"
      add_if_not_exists :notification_settings, :map, default: "{}"

      # Quality and Enhancement
      add_if_not_exists :quality_score, :float
      add_if_not_exists :readability_score, :float
      add_if_not_exists :engagement_score, :float
      add_if_not_exists :structure_score, :float

      # Media and Assets
      add_if_not_exists :attached_media, {:array, :string}, default: []
      add_if_not_exists :export_formats, {:array, :string}, default: []
      add_if_not_exists :generated_assets, :map, default: "{}"

      # Experimental Features
      add_if_not_exists :live_session_data, :map, default: "{}"
      add_if_not_exists :voice_sketch_data, :map, default: "{}"
      add_if_not_exists :narrative_beats_data, :map, default: "{}"
      add_if_not_exists :remix_data, :map, default: "{}"

      # Performance and Caching
      add_if_not_exists :cached_metrics, :map, default: "{}"
      add_if_not_exists :last_calculated_at, :utc_datetime

      # Foreign Keys - CORRECTED SYNTAX
      add_if_not_exists :parent_story_id, references(:enhanced_story_structures, type: :binary_id, on_delete: :nilify_all)

    end

    # Indexes for performance
    create_if_not_exists index(:enhanced_story_structures, [:created_by_id])
    create_if_not_exists index(:enhanced_story_structures, [:session_id])
    create_if_not_exists index(:enhanced_story_structures, [:story_type])
    create_if_not_exists index(:enhanced_story_structures, [:intent_category])
    create_if_not_exists index(:enhanced_story_structures, [:workflow_stage])
    create_if_not_exists index(:enhanced_story_structures, [:collaboration_mode])
    create_if_not_exists index(:enhanced_story_structures, [:is_public])
    create_if_not_exists index(:enhanced_story_structures, [:is_featured])
    create_if_not_exists index(:enhanced_story_structures, [:completion_percentage])
    create_if_not_exists index(:enhanced_story_structures, [:updated_at])
    create_if_not_exists index(:enhanced_story_structures, [:parent_story_id])

    # Composite indexes
    create_if_not_exists index(:enhanced_story_structures, [:created_by_id, :story_type])
    create_if_not_exists index(:enhanced_story_structures, [:created_by_id, :updated_at])
    create_if_not_exists index(:enhanced_story_structures, [:story_type, :is_public])
    create_if_not_exists index(:enhanced_story_structures, [:intent_category, :workflow_stage])

    # GIN indexes for JSON fields
    create_if_not_exists index(:enhanced_story_structures, [:collaborators], using: :gin)
    create_if_not_exists index(:enhanced_story_structures, [:content], using: :gin)
    create_if_not_exists index(:enhanced_story_structures, [:template_data], using: :gin)

    # Unique constraint
    create_if_not_exists unique_index(:enhanced_story_structures, [:title, :created_by_id],
                       name: :enhanced_story_structures_title_user_index)
  end
end
