defmodule Frestyl.Repo.Migrations.CreateUserToolPreferences do
  use Ecto.Migration

  def change do
    create table(:user_tool_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :tool_layout, :map, null: false, default: %{}
      add :collaboration_mode_preferences, :map, null: false, default: %{}
      add :mobile_preferences, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:user_tool_preferences, [:user_id])
    create_if_not_exists index(:user_tool_preferences, [:user_id])
  end
end
