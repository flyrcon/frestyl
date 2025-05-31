# priv/repo/migrations/20250530000001_create_media_groups.exs
defmodule Frestyl.Repo.Migrations.CreateMediaGroups do
  use Ecto.Migration

  def change do
    create table(:media_groups) do
      add :name, :string, null: false
      add :description, :text
      add :group_type, :string, null: false, default: "auto" # auto, manual, session, album, project
      add :primary_file_id, references(:media_files, on_delete: :nilify_all)
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :metadata, :map, default: %{}
      add :color_theme, :string, default: "#8B5CF6"
      add :position, :float, default: 0.0 # For custom ordering
      add :is_public, :boolean, default: true
      add :auto_expand, :boolean, default: false # Auto-expand in discovery view

      timestamps()
    end

    create index(:media_groups, [:user_id])
    create index(:media_groups, [:channel_id])
    create index(:media_groups, [:group_type])
    create index(:media_groups, [:primary_file_id])
  end
end
