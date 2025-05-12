# Create with: mix ecto.gen.migration add_fields_to_media_items
defmodule Frestyl.Repo.Migrations.AddFieldsToMediaItems do
  use Ecto.Migration

  def change do
    alter table(:media_items) do
      add :title, :string
      modify :media_type, :string  # Will store the Ecto.Enum as a string
      add :description, :string
      modify :file_path, :string
      modify :file_size, :integer
      add :file_type, :string
      modify :content_type, :string
      add :mime_type, :string
      add :duration, :integer
      add :width, :integer
      add :height, :integer
      add :thumbnail_url, :string
      add :is_public, :boolean, default: false
      add :status, :string, default: "processing"  # Will store the Ecto.Enum as a string
      modify :metadata, :map, default: %{}
      modify :category, :string, default: "general"  # Will store the Ecto.Enum as a string

      # Relationships
      add :channel_id, references(:channels, on_delete: :delete_all)
      add :event_id, references(:events, on_delete: :nilify_all), null: true
    end

    create index(:media_items, [:channel_id])
    create index(:media_items, [:event_id])
  end
end
