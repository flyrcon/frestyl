defmodule Frestyl.Repo.Migrations.AddThumbnailUrlToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :thumbnail_url, :string
    end
  end
end
