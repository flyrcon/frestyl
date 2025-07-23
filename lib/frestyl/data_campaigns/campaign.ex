# File: lib/frestyl/data_campaigns/campaign.ex

defmodule Frestyl.DataCampaigns.Campaign do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "content_campaigns" do
    field :title, :string
    field :description, :string
    field :content_type, Ecto.Enum, values: [
      :data_story, :book, :podcast, :music_track,
      :blog_post, :news_article, :video_content
    ]
    field :status, Ecto.Enum, values: [
      :draft, :open, :active, :review, :completed, :published, :cancelled
    ], default: :draft

    field :max_contributors, :integer, default: 5
    field :deadline, :utc_datetime
    field :revenue_target, :decimal
    field :minimum_contribution_threshold, :map
    field :contract_terms, :map
    field :platform_integrations, :map
    field :contributor_count, :integer, default: 0
    field :last_contributor_joined, :utc_datetime
    field :target_contributors, :integer, default: 5

    # Dynamic tracking fields
    field :current_metrics, :map, default: %{}
    field :revenue_splits, :map, default: %{}

    belongs_to :creator, Frestyl.Accounts.User
    has_many :contributors, Frestyl.DataCampaigns.Contributor

    timestamps()
  end

  def changeset(campaign, attrs) do
    campaign
    |> cast(attrs, [
      :title, :description, :content_type, :status, :max_contributors,
      :deadline, :revenue_target, :minimum_contribution_threshold,
      :contract_terms, :platform_integrations, :creator_id
    ])
    |> validate_required([:title, :content_type, :creator_id])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 500)
    |> validate_number(:max_contributors, greater_than: 0, less_than: 21)
    |> foreign_key_constraint(:creator_id)
  end
end
