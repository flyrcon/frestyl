# priv/repo/migrations/20250422000001_create_users.exs
defmodule Frestyl.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :username, :string, null: false
      add :display_name, :string
      add :bio, :text
      add :avatar_url, :string
      add :role, :string, null: false
      add :verified, :boolean, default: false, null: false

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
