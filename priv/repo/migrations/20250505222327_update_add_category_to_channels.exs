defmodule Frestyl.Repo.Migrations.AddCategoryToChannels do
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :category, :string
    end

    create_if_not_exists index(:channels, [:category])
  end
end
