# Create with: mix ecto.gen.migration add_category_to_media_items
defmodule Frestyl.Repo.Migrations.AddCategoryToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :category, :string, default: "general"
    end

    create index(:media_items, [:category])
  end
end
