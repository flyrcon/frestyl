# Migration for permissions
defmodule Frestyl.Repo.Migrations.CreatePermissions do
  use Ecto.Migration

  def change do
    create table(:permissions) do
      add :name, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:permissions, [:name])
  end
end
