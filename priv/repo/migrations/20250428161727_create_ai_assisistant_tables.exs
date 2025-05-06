defmodule Frestyl.Repo.Migrations.CreateAIAssistantTables do
  use Ecto.Migration

  def change do
    create table(:ai_interactions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :flow_type, :string, null: false
      add :status, :string, null: false
      add :responses, :map
      add :metadata, :map

      timestamps()
    end

    create index(:ai_interactions, [:user_id])
    create index(:ai_interactions, [:flow_type])
    create index(:ai_interactions, [:status])

    create table(:user_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :content_preferences, {:array, :string}
      add :feature_preferences, {:array, :string}
      add :experience_level, :string
      add :guidance_preference, :string
      add :usage_frequency, :string
      add :last_updated, :utc_datetime

      timestamps()
    end

    create unique_index(:user_preferences, [:user_id])

    create table(:ai_recommendations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :category, :string, null: false
      add :title, :string, null: false
      add :description, :string, null: false
      add :relevance_score, :float, null: false
      add :status, :string, null: false
      add :dismissed_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps()
    end

    create index(:ai_recommendations, [:user_id])
    create index(:ai_recommendations, [:category])
    create index(:ai_recommendations, [:status])
  end
end
