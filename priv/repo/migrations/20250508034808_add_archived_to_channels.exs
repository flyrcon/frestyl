# priv/repo/migrations/TIMESTAMP_add_archived_to_channels.exs
defmodule Frestyl.Repo.Migrations.AddArchivedToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add :archived, :boolean, default: false
      add :archived_at, :utc_datetime
    end

    create index(:channels, [:archived])
  end
end
