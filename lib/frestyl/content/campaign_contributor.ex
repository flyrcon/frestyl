# lib/frestyl/content/campaign_contributor.ex
defmodule Frestyl.Content.CampaignContributor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "campaign_contributors" do
    field :role, :string, default: "contributor"
    field :agreed_revenue_share, :decimal
    field :contribution_metrics, :map, default: %{}
    field :joined_at, :utc_datetime
    field :status, :string, default: "active"

    belongs_to :campaign, Frestyl.Content.CollaborationCampaign, type: :binary_id
    belongs_to :user, Frestyl.Accounts.User, type: :id  # users uses bigint
    belongs_to :account, Frestyl.Accounts.Account, type: :id  # accounts uses bigint

    timestamps()
  end

  def changeset(contributor, attrs) do
    contributor
    |> cast(attrs, [
      :role, :agreed_revenue_share, :contribution_metrics,
      :joined_at, :status, :campaign_id, :user_id, :account_id
    ])
    |> validate_required([:campaign_id, :user_id, :account_id])
    |> validate_inclusion(:role, ["lead_writer", "contributor", "reviewer", "researcher"])
    |> validate_inclusion(:status, ["active", "inactive", "removed"])
    |> validate_number(:agreed_revenue_share, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint([:campaign_id, :user_id])
  end
end
