# Create this file: priv/repo/migrations/YYYYMMDDHHMMSS_add_status_to_channel_memberships.exs

defmodule Frestyl.Repo.Migrations.AddStatusToChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      modify :status, :string, default: "active", null: false
      modify :joined_at, :utc_datetime, default: fragment("NOW()"), null: false
      add :left_at, :utc_datetime
    end

    create_if_not_exists index(:channel_memberships, [:status])
    create_if_not_exists index(:channel_memberships, [:joined_at])
  end
end
