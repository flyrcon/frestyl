# priv/repo/migrations/20250719_create_ai_generations_corrected.exs
defmodule Frestyl.Repo.Migrations.CreateAIGenerationsCorrected do
  use Ecto.Migration

  def change do
    create table(:ai_generations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :generation_type, :string, null: false
      add :prompt, :text, null: false
      add :result, :map, default: %{}
      add :context, :map, default: %{}
      add :status, :string, default: "pending"
      add :feedback, :text
      add :usage_metadata, :map, default: %{}

      # Reference the enhanced_story_structures table (binary_id)
      add :story_id, references(:enhanced_story_structures, type: :binary_id), null: false
      # Reference users table (regular id)
      add :user_id, references(:users, type: :id), null: false

      timestamps()
    end

    create index(:ai_generations, [:story_id])
    create index(:ai_generations, [:user_id])
    create index(:ai_generations, [:generation_type])
    create index(:ai_generations, [:status])
  end
end
