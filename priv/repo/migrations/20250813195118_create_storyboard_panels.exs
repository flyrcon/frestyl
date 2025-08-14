# priv/repo/migrations/20250813000001_create_storyboard_panels.exs
defmodule Frestyl.Repo.Migrations.CreateStoryboardPanels do
  use Ecto.Migration

  def change do
    create table(:storyboard_panels, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :story_id, references(:enhanced_story_structures, type: :uuid, on_delete: :delete_all), null: false
      add :section_id, :uuid  # References story sections (stored in JSON)
      add :panel_order, :integer, null: false
      add :canvas_data, :map, null: false, default: %{}
      add :thumbnail_url, :string, size: 500
      add :voice_note_id, :uuid  # Links to voice notes
      add :created_by, references(:users, type: :bigint, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes for performance
    create index(:storyboard_panels, [:story_id])
    create index(:storyboard_panels, [:section_id])
    create index(:storyboard_panels, [:created_by])
    create index(:storyboard_panels, [:panel_order])
    create index(:storyboard_panels, [:voice_note_id])

    # Composite indexes for common queries
    create_if_not_exists index(:storyboard_panels, [:story_id, :panel_order])
    create index(:storyboard_panels, [:story_id, :section_id])

    # Unique constraint to prevent duplicate panel orders within a story
    create_if_not_exists unique_index(:storyboard_panels, [:story_id, :panel_order])

    # GIN index for canvas_data JSON queries
    create index(:storyboard_panels, [:canvas_data], using: :gin)
  end
end
