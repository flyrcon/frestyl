# priv/repo/migrations/005_create_story_chapters.exs
defmodule Frestyl.Repo.Migrations.CreateStoryChapters do
  use Ecto.Migration

  def change do
    create table(:story_chapters) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false

      add :title, :string, null: false
      add :chapter_type, :string, null: false, default: "content"
      add :content, :map, default: %{}
      add :position, :integer, null: false, default: 0
      add :visible, :boolean, null: false, default: true

      # Story-specific fields
      add :narrative_purpose, :string
      add :emotional_tone, :string

      # Media and interactions
      add :featured_media_id, :bigint
      add :interactive_elements, :map, default: %{}

      # Analytics
      add :view_time_seconds, :integer, default: 0
      add :engagement_score, :decimal, precision: 3, scale: 2, default: 0.0

      timestamps()
    end

    create index(:story_chapters, [:portfolio_id])
    create index(:story_chapters, [:portfolio_id, :position])

    # Add constraints
    create constraint(:story_chapters, :valid_chapter_type,
      check: "chapter_type IN ('intro', 'content', 'media_showcase', 'case_study_problem', 'case_study_solution', 'call_to_action', 'conclusion')")

    create constraint(:story_chapters, :valid_narrative_purpose,
      check: "narrative_purpose IN ('hook', 'context', 'conflict', 'journey', 'resolution', 'call_to_action')")

    create constraint(:story_chapters, :valid_emotional_tone,
      check: "emotional_tone IN ('inspiring', 'analytical', 'personal', 'professional', 'dramatic', 'conversational')")
  end
end
