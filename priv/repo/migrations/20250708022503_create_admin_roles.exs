# priv/repo/migrations/20250707000001_create_admin_roles.exs
defmodule Frestyl.Repo.Migrations.CreateAdminRoles do
  use Ecto.Migration

  def change do
    create table(:admin_roles) do
      add :name, :string, null: false
      add :description, :text
      add :permissions, {:array, :string}, default: []
      add :is_system_role, :boolean, default: false
      add :color, :string, default: "#6B7280"

      timestamps()
    end

    create unique_index(:admin_roles, [:name])
    create index(:admin_roles, [:is_system_role])
  end
end
