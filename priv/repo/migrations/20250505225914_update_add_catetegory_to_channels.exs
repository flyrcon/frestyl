# priv/repo/migrations/20250505222327_update_add_category_to_channels.exs
defmodule Frestyl.Repo.Migrations.UpdateCategoryInChannels do # Changed name
  use Ecto.Migration

  def change do
    alter table(:channels) do
      modify :category, :string
    end

    create_if_not_exists index(:channels, [:category])
  end
end
