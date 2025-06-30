
# Migration 3: Create social_posts table
# File: priv/repo/migrations/20241201000003_create_social_posts.exs

defmodule Frestyl.Repo.Migrations.CreateSocialPosts do
  use Ecto.Migration

  def change do
    create table(:social_posts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :platform_post_id, :string, null: false
      add :content, :text, null: false
      add :media_urls, {:array, :string}, default: []
      add :post_url, :string
      add :posted_at, :utc_datetime, null: false
      add :likes_count, :integer, default: 0
      add :comments_count, :integer, default: 0
      add :shares_count, :integer, default: 0
      add :post_type, :string, default: "text"
      add :hashtags, {:array, :string}, default: []
      add :mentions, {:array, :string}, default: []

      add :social_integration_id, references(:social_integrations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:social_posts, [:social_integration_id, :platform_post_id])
    create index(:social_posts, [:posted_at])
    create index(:social_posts, [:post_type])
    create index(:social_posts, [:social_integration_id, :posted_at])

    # Add check constraints
    create constraint(:social_posts, :valid_post_type,
      check: "post_type IN ('text', 'image', 'video', 'link')")
    create constraint(:social_posts, :non_negative_counts,
      check: "likes_count >= 0 AND comments_count >= 0 AND shares_count >= 0")
  end
end
