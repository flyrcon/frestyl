# Create a migration with: mix ecto.gen.migration create_session_invitations
defmodule Frestyl.Repo.Migrations.CreateSessionInvitations do
  use Ecto.Migration

  def change do
    create table(:session_invitations) do
      add :email, :string, null: false
      add :token, :string, null: false
      add :role, :string, default: "participant"
      add :status, :string, default: "pending"
      add :accepted, :boolean, default: false
      add :accepted_at, :utc_datetime
      add :expires_at, :utc_datetime

      add :session_id, references(:sessions, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)
      add :inviter_id, references(:users, on_delete: :nilify_all), null: false

      timestamps()
    end

    create index(:session_invitations, [:session_id])
    create index(:session_invitations, [:user_id])
    create index(:session_invitations, [:inviter_id])
    create unique_index(:session_invitations, [:session_id, :email])
  end
end
