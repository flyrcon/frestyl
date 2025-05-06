defmodule Frestyl.Repo.Migrations.UpdateCreateChannelMemberships do
  use Ecto.Migration

  def change do
    alter table(:channel_memberships) do
      modify :role, :string, null: false, default: "member"
      add :status, :string, null: false, default: "active"
      add :last_activity_at, :utc_datetime

    end

    create_if_not_exists index(:channel_memberships, [:role])
  end
end
