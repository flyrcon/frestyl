# priv/repo/migrations/20250422000005_create_media_items.exs
defmodule Frestyl.Repo.Migrations.CreateMediaItems do
  use Ecto.Migration

  def change do
    create table(:media_items) do
      add :title, :string, null: false
      add :description, :text
      add :file_path, :string, null: false
      add :file_size, :bigint
      add :file_type, :string, null: false
      add :mime_type, :string, null: false
      add :duration, :integer
      add :width, :integer
      add :height, :integer
      add :thumbnail_url, :string
      add :is_public, :boolean, default: false, null: false
      add :status, :string, null: false, default: "processing"
      add :media_type, :string, null: false
      add :metadata, :map
      add :uploader_id, references(:users, on_delete: :restrict), null: false
      add :channel_id, references(:channels, on_delete: :nilify_all)
      add :session_id, references(:sessions, on_delete: :nilify_all)
      add :event_id, references(:events, on_delete: :nilify_all)

      timestamps()
    end

    create index(:media_items, [:uploader_id])
    create index(:media_items, [:channel_id])
    create index(:media_items, [:session_id])
    create index(:media_items, [:event_id])
    create index(:media_items, [:media_type])
    create index(:media_items, [:status])
  end
end
