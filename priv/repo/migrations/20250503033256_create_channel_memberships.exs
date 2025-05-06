defmodule Frestyl.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      add :role, :string, default: "member"
      add :joined_at, :utc_datetime, default: fragment("NOW()")

    end

    create unique_index(:channel_memberships, [:channel_id, :user_id])
  end
end
