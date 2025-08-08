# priv/repo/migrations/20250108000001_enhance_story_structures_for_engine.exs
defmodule Frestyl.Repo.Migrations.EnhanceStoryStructuresForEngine do
  use Ecto.Migration

  def change do
    alter table(:enhanced_story_structures) do
      add :intent_category, :string
      add :creation_source, :string, default: "direct"
      add :quick_start_template, :string
      add :user_preferences, :map, default: %{}
      add :ai_assistance_level, :string, default: "basic"
      add :collaboration_intent, :string
      add :format_metadata, :map, default: %{}
    end

    create index(:enhanced_story_structures, [:intent_category])
    create index(:enhanced_story_structures, [:creation_source])
    create index(:enhanced_story_structures, [:created_by_id, :intent_category])
  end
end
