# Database migration for user_interests table
# priv/repo/migrations/xxx_create_user_interests.exs
defmodule Frestyl.Repo.Migrations.CreateUserInterests do
  use Ecto.Migration

  def change do
    create table(:user_interests) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :genres, {:array, :string}, default: []
      add :sub_genres, {:array, :string}, default: []
      add :skill_levels, :map, default: %{}
      add :collaboration_preferences, {:array, :string}, default: []
      add :engagement_level, :string
      add :onboarding_completed_at, :utc_datetime

      timestamps()
    end

    create unique_index(:user_interests, [:user_id])
    create index(:user_interests, [:genres])
    create index(:user_interests, [:engagement_level])
  end
end
