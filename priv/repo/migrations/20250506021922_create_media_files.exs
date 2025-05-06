# priv/repo/migrations/20250506000001_create_media_files.exs
defmodule Frestyl.Repo.Migrations.CreateMediaFiles do
  use Ecto.Migration

  def change do
    create table(:media_files) do
      add :filename, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :media_type, :string, null: false # "image", "video", "audio", "document"
      add :file_path, :string, null: false
      add :storage_type, :string, default: "local"
      add :status, :string, default: "active"
      add :title, :string
      add :description, :text
      add :metadata, :map
      add :duration, :integer
      add :width, :integer
      add :height, :integer
      add :thumbnail_url, :string

      add :channel_id, references(:channels, on_delete: :delete_all), null: true
      add :user_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:media_files, [:channel_id])
    create index(:media_files, [:user_id])
    create index(:media_files, [:media_type])
  end
end
