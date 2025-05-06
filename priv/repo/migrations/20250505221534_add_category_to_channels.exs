defmodule Frestyl.Repo.Migrations.AddCategoryToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      add_if_not_exists :category, :string
    end

    create_if_not_exists index(:channels, [:category])
  end
end
