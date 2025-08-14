# priv/repo/migrations/20250813000003_add_storyboard_to_stories.exs
defmodule Frestyl.Repo.Migrations.AddStoryboardToStories do
  use Ecto.Migration

  def change do
    alter table(:enhanced_story_structures) do
      add :has_storyboard, :boolean, default: false
      add :storyboard_settings, :map, default: %{}
      add :default_canvas_width, :integer, default: 800
      add :default_canvas_height, :integer, default: 600
      add :storyboard_template_id, :uuid, null: true
      add :panel_count, :integer, default: 0
      add :last_storyboard_update, :utc_datetime
    end

    # Indexes for performance
    create index(:enhanced_story_structures, [:has_storyboard])
    create index(:enhanced_story_structures, [:storyboard_template_id])
    create index(:enhanced_story_structures, [:panel_count])
    create index(:enhanced_story_structures, [:last_storyboard_update])

    # GIN index for storyboard_settings JSON queries
    create index(:enhanced_story_structures, [:storyboard_settings], using: :gin)
  end
end
