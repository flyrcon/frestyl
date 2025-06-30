# lib/frestyl/portfolios/social_post.ex
defmodule Frestyl.Portfolios.SocialPost do
  use Ecto.Schema
  import Ecto.Changeset

  schema "social_posts" do
    field :platform_post_id, :string
    field :content, :string
    field :media_urls, {:array, :string}
    field :post_url, :string
    field :posted_at, :utc_datetime
    field :likes_count, :integer, default: 0
    field :comments_count, :integer, default: 0
    field :shares_count, :integer, default: 0
    field :post_type, :string # "text", "image", "video", "link"
    field :hashtags, {:array, :string}
    field :mentions, {:array, :string}

    belongs_to :social_integration, Frestyl.Portfolios.SocialIntegration

    timestamps()
  end

  def changeset(social_post, attrs) do
    social_post
    |> cast(attrs, [
      :platform_post_id, :content, :media_urls, :post_url, :posted_at,
      :likes_count, :comments_count, :shares_count, :post_type,
      :hashtags, :mentions, :social_integration_id
    ])
    |> validate_required([:platform_post_id, :content, :posted_at, :social_integration_id])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_inclusion(:post_type, ["text", "image", "video", "link"])
    |> validate_number(:likes_count, greater_than_or_equal_to: 0)
    |> validate_number(:comments_count, greater_than_or_equal_to: 0)
    |> validate_number(:shares_count, greater_than_or_equal_to: 0)
    |> unique_constraint([:social_integration_id, :platform_post_id])
    |> foreign_key_constraint(:social_integration_id)
  end
end
