# File: priv/repo/migrations/20250105120000_create_user_invitations.exs
defmodule Frestyl.Repo.Migrations.CreateUserInvitations do
  use Ecto.Migration

  def change do
    alter table(:user_invitations) do
      add_if_not_exists :email, :string, null: false
      add_if_not_exists :status, :string, null: false, default: "pending"
      add_if_not_exists :token, :string, null: false
      add_if_not_exists :expires_at, :utc_datetime, null: false


    end

    create_if_not_exists unique_index(:user_invitations, [:token])
    create_if_not_exists index(:user_invitations, [:invited_by_id])
  end
end
