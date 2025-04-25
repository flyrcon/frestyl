# Migration for roles
defmodule Frestyl.Repo.Migrations.CreateRoles do
  use Ecto.Migration

  def change do
    create table(:roles) do
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:roles, [:name])

    # Join table for roles and permissions
    create table(:role_permissions, primary_key: false) do
      add :role_id, references(:roles, on_delete: :delete_all), null: false
      add :permission_id, references(:permissions, on_delete: :delete_all), null: false
    end

    create unique_index(:role_permissions, [:role_id, :permission_id])
  end
end
