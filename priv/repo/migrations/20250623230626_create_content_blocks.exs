# priv/repo/migrations/007_create_content_blocks.exs
defmodule Frestyl.Repo.Migrations.CreateContentBlocks do
  use Ecto.Migration

  def change do
    create table(:content_blocks) do
      add :chapter_id, references(:story_chapters, on_delete: :delete_all), null: false
      add :block_uuid, :string, null: false  # Frontend generates UUID for each block
      add :block_type, :string, null: false  # text, image, video, gallery, timeline, etc.
      add :position, :integer, null: false
      add :content_data, :map, default: %{}  # The actual text/content
      add :layout_config, :map, default: %{}  # How this block is displayed
      add :interaction_config, :map, default: %{}  # Hover, click behaviors

      timestamps()
    end

    create index(:content_blocks, [:chapter_id])
    create index(:content_blocks, [:block_uuid])
    create index(:content_blocks, [:chapter_id, :position])

    create constraint(:content_blocks, :valid_block_type,
      check: "block_type IN ('text', 'image', 'video', 'gallery', 'timeline', 'card_grid', 'bullet_list', 'quote', 'code_showcase', 'media_showcase')")
  end
end
