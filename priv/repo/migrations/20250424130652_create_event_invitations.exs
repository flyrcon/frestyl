# priv/repo/migrations/TIMESTAMP_create_event_invitations.exs
defmodule Frestyl.Repo.Migrations.CreateEventInvitations do
  use Ecto.Migration

  def change do
    create table(:event_invitations) do
      add :email, :string, null: false
      add :token, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :expires_at, :utc_datetime, null: false

      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :invitee_id, references(:users, on_delete: :nilify_all)

      timestamps()
    end

    create index(:event_invitations, [:event_id])
    create index(:event_invitations, [:invitee_id])
    create unique_index(:event_invitations, [:event_id, :email])
    create unique_index(:event_invitations, [:token])
  end
end
