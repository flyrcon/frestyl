# priv/repo/migrations/20250108000002_create_user_story_preferences.exs
defmodule Frestyl.Repo.Migrations.CreateUserStoryPreferences do
  use Ecto.Migration

  def change do
    create table(:user_story_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :id), null: false
      add :preferred_formats, {:array, :string}, default: []
      add :recent_intents, {:array, :string}, default: []
      add :quick_access_formats, {:array, :string}, default: []
      add :collaboration_preferences, :map, default: %{}
      add :ai_assistance_preferences, :map, default: %{}
      add :format_usage_stats, :map, default: %{}
      add :last_used_intent, :string
      add :story_completion_rate, :float, default: 0.0

      timestamps()
    end

    create unique_index(:user_story_preferences, [:user_id])
    create index(:user_story_preferences, [:last_used_intent])
  end
end
