# Create this file: priv/repo/migrations/YYYYMMDDHHMMSS_add_archived_to_channels.exs

defmodule Frestyl.Repo.Migrations.AddArchivedToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :archived, :boolean, default: false, null: false
      modify :archived_at, :utc_datetime
      add :archived_by_id, references(:users, on_delete: :nilify_all)
    end

    create_if_not_exists index(:channels, [:archived])
    create index(:channels, [:archived_at])
  end
end
