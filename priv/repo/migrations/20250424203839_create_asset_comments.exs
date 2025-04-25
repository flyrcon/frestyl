# priv/repo/migrations/YYYYMMDDHHMMSS_create_asset_comments.exs
defmodule Frestyl.Repo.Migrations.CreateAssetComments do
  use Ecto.Migration

  def change do
    create table(:asset_comments) do
      add :content, :text, null: false
      add :metadata, :map, default: "{}"
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :asset_id, references(:assets, on_delete: :delete_all), null: false
      add :parent_id, references(:asset_comments, on_delete: :nilify_all)

      timestamps()
    end

    create index(:asset_comments, [:asset_id])
    create index(:asset_comments, [:user_id])
    create index(:asset_comments, [:parent_id])
  end
end
