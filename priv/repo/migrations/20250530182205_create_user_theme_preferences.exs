# priv/repo/migrations/20250530000006_create_user_theme_preferences.exs
defmodule Frestyl.Repo.Migrations.CreateUserThemePreferences do
  use Ecto.Migration

  def change do
    create table(:user_theme_preferences) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :current_theme, :string, default: "cosmic" # cosmic, cyberpunk, liquid, crystal, organic, minimal
      add :theme_settings, :map, default: %{}
      add :auto_switch_themes, :boolean, default: false
      add :preferred_view_mode, :string, default: "discovery" # discovery, grid, list, canvas
      add :animation_intensity, :float, default: 1.0 # 0.0 to 2.0
      add :enable_haptics, :boolean, default: true
      add :enable_sound_effects, :boolean, default: false
      add :custom_colors, :map, default: %{}

      timestamps()
    end

    create unique_index(:user_theme_preferences, [:user_id])
  end
end
