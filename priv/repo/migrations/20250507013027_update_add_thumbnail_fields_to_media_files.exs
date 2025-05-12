# priv/repo/migrations/YYYYMMDDHHMMSS_add_thumbnail_fields_to_media_files.ex
defmodule Frestyl.Repo.Migrations.AddThumbnailFieldsToMediaFiles do
  use Ecto.Migration

  def change do
    alter table(:media_files) do
      add :thumbnail_status, :string, default: "pending"
      add :thumbnails, :map, default: %{}
    end
  end
end
