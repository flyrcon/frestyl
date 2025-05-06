defmodule Frestyl.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :name, :string, null: false
      modify :description, :text
      add :visibility, :string, null: false, default: "public"
      modify :category, :string
      add :icon_url, :string

    end

    create_if_not_exists unique_index(:channels, [:name])
    create_if_not_exists index(:channels, [:visibility])
    create_if_not_exists index(:channels, [:category])
  end
end
