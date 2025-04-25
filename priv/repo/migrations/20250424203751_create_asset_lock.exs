# priv/repo/migrations/YYYYMMDDHHMMSS_create_asset_locks.exs
defmodule Frestyl.Repo.Migrations.CreateAssetLocks do
  use Ecto.Migration

  def change do
    create table(:asset_locks) do
      add :expires_at, :utc_datetime, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:asset_locks, [:user_id])
    create unique_index(:asset_locks, [:asset_id])
  end
end
