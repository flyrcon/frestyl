# priv/repo/migrations/20250530000002_create_media_group_files.exs
defmodule Frestyl.Repo.Migrations.CreateMediaGroupFiles do
  use Ecto.Migration

  def change do
    create table(:media_group_files) do
      add :media_group_id, references(:media_groups, on_delete: :delete_all), null: false
      add :media_file_id, references(:media_files, on_delete: :delete_all), null: false
      add :role, :string, default: "component" # primary, component, alternate, reference
      add :position, :integer, default: 0
      add :relationship_type, :string # cover_art, stem, lyrics, documentation, etc.
      add :metadata, :map, default: %{}

      timestamps()
    end

    create unique_index(:media_group_files, [:media_group_id, :media_file_id])
    create index(:media_group_files, [:media_group_id])
    create index(:media_group_files, [:media_file_id])
    create index(:media_group_files, [:role])
  end
end
