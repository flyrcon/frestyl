# priv/repo/migrations/20250707000006_add_auto_joined_to_channel_memberships.exs
defmodule Frestyl.Repo.Migrations.AddAutoJoinedToChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      add :auto_joined, :boolean, default: false
      add_if_not_exists :last_activity_at, :utc_datetime
    end

    create index(:channel_memberships, [:auto_joined])
    create index(:channel_memberships, [:last_activity_at])
  end
end
