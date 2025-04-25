# priv/repo/migrations/YYYYMMDDHHMMSS_create_asset_permissions.exs
defmodule Frestyl.Repo.Migrations.CreateAssetPermissions do
  use Ecto.Migration

  def change do
    create table(:asset_permissions) do
      add :permission_level, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:asset_permissions, [:asset_id])
    create index(:asset_permissions, [:user_id])
    create unique_index(:asset_permissions, [:user_id, :asset_id])
  end
end
