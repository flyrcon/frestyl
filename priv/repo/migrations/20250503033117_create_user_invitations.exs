defmodule Frestyl.Repo.Migrations.CreateUserInvitations do
  use Ecto.Migration

  def change do
    create table(:user_invitations) do
      add :email, :string, null: false
      add :status, :string, null: false, default: "pending"
      add :token, :string, null: false
      add :expires_at, :utc_datetime, null: false
      add :invited_by_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:user_invitations, [:token])
    create index(:user_invitations, [:email])
  end
end
