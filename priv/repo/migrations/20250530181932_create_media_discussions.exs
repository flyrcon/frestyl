
# priv/repo/migrations/20250530000003_create_media_discussions.exs
defmodule Frestyl.Repo.Migrations.CreateMediaDiscussions do
  use Ecto.Migration

  def change do
    create table(:media_discussions) do
      add :title, :string, null: false
      add :description, :text
      add :media_file_id, references(:media_files, on_delete: :delete_all)
      add :media_group_id, references(:media_groups, on_delete: :delete_all)
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :creator_id, references(:users, on_delete: :delete_all), null: false
      add :discussion_type, :string, default: "general" # feedback, critique, collaboration, etc.
      add :status, :string, default: "active" # active, closed, archived
      add :is_pinned, :boolean, default: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:media_discussions, [:media_file_id])
    create index(:media_discussions, [:media_group_id])
    create index(:media_discussions, [:channel_id])
    create index(:media_discussions, [:creator_id])
    create index(:media_discussions, [:status])
  end
end
