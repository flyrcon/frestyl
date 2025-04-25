# Create a new migration
# priv/repo/migrations/TIMESTAMP_add_roles_and_profile_to_users.exs
defmodule Frestyl.Repo.Migrations.AddRolesAndProfileToUsers do
  use Ecto.Migration

  def change do
    # Add role field
    alter table(:users) do
      modify :role, :string, default: "user", null: false
      add :subscription_tier, :string, default: "free", null: false

      # Profile fields
      add :website, :string
      add :social_links, :map, default: "{}", null: false

      # Additional fields for tracking
      add :last_active_at, :utc_datetime
    end

    create index(:users, [:role])
    create index(:users, [:subscription_tier])
  end
end
