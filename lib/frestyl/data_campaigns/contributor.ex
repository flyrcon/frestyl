# File: lib/frestyl/data_campaigns/contributor.ex

defmodule Frestyl.DataCampaigns.Contributor do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "campaign_contributors" do
    field :role, Ecto.Enum, values: [:creator, :lead, :contributor, :reviewer], default: :contributor
    field :revenue_percentage, :decimal, default: Decimal.new("0.0")
    field :contribution_data, :map, default: %{}
    field :joined_at, :utc_datetime
    field :last_active_at, :utc_datetime

    belongs_to :campaign, Frestyl.DataCampaigns.Campaign
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(contributor, attrs) do
    contributor
    |> cast(attrs, [:role, :revenue_percentage, :contribution_data, :joined_at, :last_active_at, :campaign_id, :user_id])
    |> validate_required([:campaign_id, :user_id, :joined_at])
    |> validate_number(:revenue_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:campaign_id, :user_id])
  end
end
