
# priv/repo/migrations/20250530000010_create_saved_filters.exs
defmodule Frestyl.Repo.Migrations.CreateSavedFilters do
  use Ecto.Migration

  def change do
    create table(:saved_filters) do
      add :name, :string, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :filter_data, :map, null: false # Complete filter configuration
      add :is_default, :boolean, default: false
      add :usage_count, :integer, default: 0
      add :last_used_at, :utc_datetime
      add :is_public, :boolean, default: false # Shareable filters
      add :description, :text

      timestamps()
    end

    create index(:saved_filters, [:user_id])
    create index(:saved_filters, [:is_public])
    create unique_index(:saved_filters, [:user_id, :name])
  end
end
