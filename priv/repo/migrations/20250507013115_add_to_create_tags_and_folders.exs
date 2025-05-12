# priv/repo/migrations/YYYYMMDDHHMMSS_create_tags_and_folders.ex
defmodule Frestyl.Repo.Migrations.CreateTagsAndFolders do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all)
      add :color, :string, default: "#cccccc"

      timestamps()
    end

    create index(:tags, [:user_id])
    create unique_index(:tags, [:name, :user_id])

    create table(:media_files_tags) do
      add :media_file_id, references(:media_files, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:media_files_tags, [:media_file_id, :tag_id])

    create table(:folders) do
      add :name, :string, null: false
      add :parent_id, references(:folders, on_delete: :nilify_all)
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps()
    end

    create index(:folders, [:parent_id])
    create index(:folders, [:user_id])

    alter table(:media_files) do
      add :folder_id, references(:folders, on_delete: :nilify_all)
    end

    create index(:media_files, [:folder_id])
  end
end
