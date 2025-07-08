# priv/repo/migrations/20250707000002_create_admin_role_assignments.exs
defmodule Frestyl.Repo.Migrations.CreateAdminRoleAssignments do
  use Ecto.Migration

  def change do
    create table(:admin_role_assignments) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :admin_role_id, references(:admin_roles, on_delete: :delete_all), null: false
      add :assigned_by_user_id, references(:users, on_delete: :nilify_all)
      add :revoked_by_user_id, references(:users, on_delete: :nilify_all)

      add :status, :string, default: "active", null: false
      add :assigned_at, :utc_datetime
      add :revoked_at, :utc_datetime
      add :expires_at, :utc_datetime
      add :notes, :text

      timestamps()
    end

    create index(:admin_role_assignments, [:user_id])
    create index(:admin_role_assignments, [:admin_role_id])
    create index(:admin_role_assignments, [:assigned_by_user_id])
    create index(:admin_role_assignments, [:status])

    # Ensure one active role assignment per user per role
    create unique_index(:admin_role_assignments, [:user_id, :admin_role_id],
      where: "status = 'active'",
      name: :unique_active_role_per_user
    )
  end
end
