# priv/repo/migrations/YYYYMMDDHHMMSS_create_assets.exs
defmodule Frestyl.Repo.Migrations.CreateAssets do
  use Ecto.Migration

  def change do
    create table(:assets) do
      add :name, :string, null: false
      add :description, :text
      add :type, :string, null: false
      add :mime_type, :string
      add :metadata, :map, default: "{}"
      add :owner_id, references(:users, on_delete: :nilify_all)
      add :status, :string, default: "active"

      timestamps()
    end

    create index(:assets, [:owner_id])
    create index(:assets, [:type])
  end
end
