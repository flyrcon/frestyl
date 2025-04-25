# priv/repo/migrations/YYYYMMDDHHMMSS_create_asset_versions.exs
defmodule Frestyl.Repo.Migrations.CreateAssetVersions do
  use Ecto.Migration

  def change do
    create table(:asset_versions) do
      add :version_number, :integer
      add :file_path, :string, null: false
      add :file_size, :integer
      add :metadata, :map, default: "{}"
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :asset_id, references(:assets, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:asset_versions, [:asset_id])
    create index(:asset_versions, [:created_by_id])
  end
end
