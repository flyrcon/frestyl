# priv/repo/migrations/create_channel_invitations.exs
defmodule Frestyl.Repo.Migrations.CreateChannelInvitations do
  use Ecto.Migration

  def change do
    create table(:channel_invitations) do
      add :email, :string, null: false
      add :token, :string, null: false
      add :status, :string, default: "pending", null: false
      add :expires_at, :utc_datetime, null: false

      add :channel_id, references(:channels, on_delete: :delete_all), null: false
      add :role_id, references(:roles, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:channel_invitations, [:email])
    create index(:channel_invitations, [:token])
    create index(:channel_invitations, [:channel_id])
    create unique_index(:channel_invitations, [:email, :channel_id])
  end
end
