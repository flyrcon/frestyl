# Create channel_memberships table
defmodule Frestyl.Repo.Migrations.CreateChannelMemberships do
  use Ecto.Migration

  def change do
    create table(:channel_memberships) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :role, :string, default: "member", null: false

      timestamps()
    end

    create unique_index(:channel_memberships, [:user_id, :channel_id])
    create index(:channel_memberships, [:user_id])
    create index(:channel_memberships, [:channel_id])
  end
end
