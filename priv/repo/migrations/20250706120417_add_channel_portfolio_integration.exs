defmodule Frestyl.Repo.Migrations.AddChannelPortfolioIntegration do
  use Ecto.Migration

  def change do
    # Channel Portfolio Activities table
    create table(:channel_portfolio_activities, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :activity_type, :string, null: false
      add :activity_data, :map, default: %{}
      add :engagement_score, :integer, default: 0
      add :visibility, :string, default: "public"
      add :is_featured, :boolean, default: false
      add :tags, {:array, :string}, default: []
      add :skill_areas, {:array, :string}, default: []
      add :career_level, :string
      add :industry_focus, :string

      # Use bigint for foreign keys to match existing tables
      add :channel_id, :bigint
      add :portfolio_id, :bigint
      add :user_id, :bigint
      add :parent_activity_id, :binary_id

      timestamps()
    end

    # Add foreign key constraints with correct types
    alter table(:channel_portfolio_activities) do
      modify :channel_id, references(:channels, on_delete: :delete_all)
      modify :portfolio_id, references(:portfolios, on_delete: :delete_all)
      modify :user_id, references(:users, on_delete: :delete_all)
      modify :parent_activity_id, references(:channel_portfolio_activities, type: :binary_id, on_delete: :delete_all)
    end

    create index(:channel_portfolio_activities, [:channel_id])
    create index(:channel_portfolio_activities, [:portfolio_id])
    create index(:channel_portfolio_activities, [:user_id])
    create index(:channel_portfolio_activities, [:activity_type])

    # Channel Media Wall table
    create table(:channel_media_walls, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :media_type, :string, null: false
      add :title, :string, null: false
      add :description, :text
      add :media_url, :string
      add :thumbnail_url, :string
      add :external_url, :string
      add :position_x, :float, default: 0.0
      add :position_y, :float, default: 0.0
      add :width, :integer, default: 300
      add :height, :integer, default: 200
      add :z_index, :integer, default: 1
      add :tags, {:array, :string}, default: []
      add :color_theme, :string
      add :category, :string
      add :priority_level, :integer, default: 1
      add :view_count, :integer, default: 0
      add :like_count, :integer, default: 0
      add :save_count, :integer, default: 0
      add :comment_count, :integer, default: 0
      add :metadata, :map, default: %{}

      # Use bigint for foreign keys to match existing tables
      add :channel_id, :bigint
      add :user_id, :bigint
      add :activity_id, :binary_id
      add :portfolio_reference_id, :bigint

      timestamps()
    end

    # Add foreign key constraints for media wall
    alter table(:channel_media_walls) do
      modify :channel_id, references(:channels, on_delete: :delete_all)
      modify :user_id, references(:users, on_delete: :delete_all)
      modify :activity_id, references(:channel_portfolio_activities, type: :binary_id, on_delete: :delete_all)
      modify :portfolio_reference_id, references(:portfolios, on_delete: :delete_all)
    end

    create index(:channel_media_walls, [:channel_id])
    create index(:channel_media_walls, [:media_type])
    create index(:channel_media_walls, [:category])

    # Media Wall Interactions table
    create table(:media_wall_interactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :interaction_type, :string, null: false
      add :comment_text, :text
      add :metadata, :map, default: %{}

      add :media_item_id, :binary_id
      add :user_id, :bigint

      timestamps()
    end

    # Add foreign key constraints for interactions
    alter table(:media_wall_interactions) do
      modify :media_item_id, references(:channel_media_walls, type: :binary_id, on_delete: :delete_all)
      modify :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:media_wall_interactions, [:media_item_id])
    create index(:media_wall_interactions, [:user_id])
    create unique_index(:media_wall_interactions, [:media_item_id, :user_id, :interaction_type],
           name: :unique_user_interaction_per_item)

    # Channel Insights table
    create table(:channel_insights, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :insight_type, :string, null: false
      add :title, :string, null: false
      add :content, :text, null: false
      add :summary, :string
      add :difficulty_level, :string, default: "beginner"
      add :target_roles, {:array, :string}, default: []
      add :relevant_skills, {:array, :string}, default: []
      add :industry_focus, {:array, :string}, default: []
      add :career_stages, {:array, :string}, default: []
      add :tags, {:array, :string}, default: []
      add :priority_score, :integer, default: 1
      add :is_featured, :boolean, default: false
      add :is_evergreen, :boolean, default: true
      add :upvote_count, :integer, default: 0
      add :downvote_count, :integer, default: 0
      add :view_count, :integer, default: 0
      add :save_count, :integer, default: 0
      add :implementation_count, :integer, default: 0
      add :source_url, :string
      add :author_credit, :string
      add :estimated_read_time, :integer
      add :actionable_steps, {:array, :string}, default: []
      add :related_resources, {:array, :map}, default: []

      add :channel_id, :bigint
      add :user_id, :bigint

      timestamps()
    end

    # Add foreign key constraints for insights
    alter table(:channel_insights) do
      modify :channel_id, references(:channels, on_delete: :delete_all)
      modify :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:channel_insights, [:channel_id])
    create index(:channel_insights, [:insight_type])
    create index(:channel_insights, [:difficulty_level])

    # Insight Interactions table
    create table(:insight_interactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :interaction_type, :string, null: false
      add :metadata, :map, default: %{}

      add :insight_id, :binary_id
      add :user_id, :bigint

      timestamps()
    end

    # Add foreign key constraints for insight interactions
    alter table(:insight_interactions) do
      modify :insight_id, references(:channel_insights, type: :binary_id, on_delete: :delete_all)
      modify :user_id, references(:users, on_delete: :delete_all)
    end

    create index(:insight_interactions, [:insight_id])
    create index(:insight_interactions, [:user_id])
    create unique_index(:insight_interactions, [:insight_id, :user_id, :interaction_type],
           name: :unique_user_insight_interaction)
  end
end
