# Create rooms table
defmodule Frestyl.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    alter table(:rooms) do
      add :slug, :string, null: false
      add :is_public, :boolean, default: true, null: false

      add :channel_id, references(:channels, on_delete: :delete_all), null: false

      add :override_branding, :boolean, default: false, null: false
      add :primary_color, :string
      add :secondary_color, :string

      timestamps()
    end

    create unique_index(:rooms, [:name, :channel_id])
    create unique_index(:rooms, [:slug, :channel_id])
    create index(:rooms, [:channel_id])
  end
end
