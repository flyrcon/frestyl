# File: priv/repo/migrations/xxx_add_story_lab_support.exs
# ============================================================================

defmodule Frestyl.Repo.Migrations.AddStoryLabSupport do
  use Ecto.Migration

  def change do
    # Add story lab usage tracking
    create table(:story_lab_usage, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :bigint, on_delete: :delete_all)
      add :stories_created, :integer, default: 0
      add :chapters_created, :integer, default: 0
      add :recording_minutes_used, :integer, default: 0
      add :last_story_created_at, :utc_datetime
      add :feature_usage, :map, default: %{}

      timestamps()
    end

    create unique_index(:story_lab_usage, [:user_id])

    # Add story lab specific fields to accounts if needed
    alter table(:accounts) do
      add :story_lab_enabled, :boolean, default: true
      add :story_lab_limits, :map, default: %{}
    end
  end
end
