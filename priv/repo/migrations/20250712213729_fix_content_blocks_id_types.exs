# priv/repo/migrations/xxx_create_portfolio_content_blocks.exs
defmodule Frestyl.Repo.Migrations.CreatePortfolioContentBlocks do
  use Ecto.Migration

  def up do
    # Create the portfolio_content_blocks table with correct ID types
    create table(:portfolio_content_blocks, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :block_uuid, :string, null: false
      add :block_type, :string, null: false
      add :position, :integer, null: false
      add :content_data, :map, default: "{}"
      add :layout_config, :map, default: "{}"
      add :monetization_config, :map, default: "{}"
      add :streaming_config, :map, default: "{}"
      add :visibility_rules, :map, default: "{}"
      add :interaction_config, :map, default: "{}"
      add :media_limit, :integer, default: 3
      add :requires_subscription_tier, :string
      add :is_premium_feature, :boolean, default: false

      # Foreign keys using bigint to match existing tables
      add :portfolio_section_id, references(:portfolio_sections, type: :bigint, on_delete: :delete_all)
      add :chapter_id, references(:story_chapters, type: :bigint, on_delete: :delete_all)

      timestamps()
    end

    # Create indexes
    create index(:portfolio_content_blocks, [:portfolio_section_id])
    create index(:portfolio_content_blocks, [:chapter_id])
    create index(:portfolio_content_blocks, [:block_type])
    create index(:portfolio_content_blocks, [:position])
    create unique_index(:portfolio_content_blocks, [:block_uuid])

    # Create related tables if they don't exist
    unless table_exists?(:portfolio_block_media) do
      create table(:portfolio_block_media, primary_key: false) do
        add :id, :bigserial, primary_key: true
        add :attachment_type, :string, null: false
        add :display_config, :map, default: "{}"
        add :interaction_triggers, {:array, :string}, default: []
        add :position_in_block, :integer, default: 0
        add :alt_text, :string
        add :caption, :string

        add :content_block_id, references(:portfolio_content_blocks, type: :bigint, on_delete: :delete_all)
        add :media_file_id, references(:portfolio_media, type: :bigint, on_delete: :delete_all)

        timestamps()
      end

      create index(:portfolio_block_media, [:content_block_id])
      create index(:portfolio_block_media, [:media_file_id])
      create index(:portfolio_block_media, [:attachment_type])
    end
  end

  def down do
    drop_if_exists table(:portfolio_block_media)
    drop_if_exists table(:portfolio_content_blocks)
  end

  # Helper function to check if table exists
  defp table_exists?(table_name) do
    query = """
    SELECT EXISTS (
      SELECT FROM information_schema.tables
      WHERE table_schema = 'public'
      AND table_name = '#{table_name}'
    )
    """

    case Ecto.Adapters.SQL.query(Frestyl.Repo, query, []) do
      {:ok, %{rows: [[true]]}} -> true
      _ -> false
    end
  end
end
