defmodule Frestyl.Repo.Migrations.CreateMediaItems do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :name, :string, null: false
      add :media_type, :string, null: false
      add :content_type, :string, null: false
      add :file_path, :string, null: false
      add :file_size, :integer
      add :metadata, :map, default: "{}"
      add :uploader_id, references(:users, on_delete: :nilify_all), null: false
      add :session_id, references(:sessions, on_delete: :nilify_all)

      timestamps()
    end

    create index(:media_items, [:uploader_id])
    create index(:media_items, [:session_id])
    create index(:media_items, [:media_type])
  end
end
