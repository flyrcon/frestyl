# priv/repo/migrations/002_create_account_memberships.exs
defmodule Frestyl.Repo.Migrations.CreateAccountMemberships do
  use Ecto.Migration

  def change do
    create table(:account_memberships) do
      add :role, :string, null: false, default: "member"
      add :permissions, :map, default: %{}

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:account_memberships, [:user_id])
    create index(:account_memberships, [:account_id])
    create unique_index(:account_memberships, [:user_id, :account_id])

    # Add constraints
    create constraint(:account_memberships, :valid_role,
      check: "role IN ('owner', 'admin', 'editor', 'viewer')")
  end
end
