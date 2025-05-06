defmodule Frestyl.Repo.Migrations.CreateChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add_if_not_exists :slug, :string

    end

    create_if_not_exists index(:channels, [:slug], unique: true)

  end
end
