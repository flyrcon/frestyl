# priv/repo/migrations/20250422000002_create_channels.exs
defmodule Frestyl.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    create table(:channels) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :logo_url, :string
      add :banner_url, :string
      add :theme_color, :string
      add :is_public, :boolean, default: true, null: false
      add :is_verified, :boolean, default: false, null: false
      add :owner_id, references(:users, on_delete: :restrict), null: false
      add :primary_color, :string
      add :secondary_color, :string

      add :parent_id, references(:channels, on_delete: :nilify_all)

      add :category, :string
      add :tags, {:array, :string}, default: []

      timestamps()
    end

    create unique_index(:channels, [:slug])
    create index(:channels, [:owner_id])
    create unique_index(:channels, [:name])
    create index(:channels, [:parent_id])
  end
end
