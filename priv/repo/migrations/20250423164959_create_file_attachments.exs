# priv/repo/migrations/create_file_attachments.exs
defmodule Frestyl.Repo.Migrations.CreateFileAttachments do
  use Ecto.Migration

  def change do
    create table(:file_attachments) do
      add :filename, :string, null: false
      add :file_url, :string, null: false
      add :file_size, :integer
      add :mime_type, :string
      add :description, :string

      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :room_id, references(:rooms, on_delete: :delete_all)
      add :channel_id, references(:channels, on_delete: :delete_all)

      timestamps()
    end

    create index(:file_attachments, [:user_id])
    create index(:file_attachments, [:room_id])
    create index(:file_attachments, [:channel_id])
    create index(:file_attachments, [:inserted_at])

    # Add a check constraint to ensure either room_id or channel_id is set, but not both
    create constraint(:file_attachments, :attachment_location_check,
                     check: "(room_id IS NULL AND channel_id IS NOT NULL) OR (room_id IS NOT NULL AND channel_id IS NULL)")
  end
end
