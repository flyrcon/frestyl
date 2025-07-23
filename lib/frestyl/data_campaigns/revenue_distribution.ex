# File: lib/frestyl/data_campaigns/revenue_distribution.ex

defmodule Frestyl.DataCampaigns.RevenueDistribution do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

    schema "revenue_distributions" do
    field :total_revenue, :decimal
    field :platform_fee, :decimal
    field :payment_processing_fee, :decimal
    field :contributor_splits, :map
    field :payment_instructions, :map

    field :status, Ecto.Enum, values: [
      :pending_payment, :processing, :completed, :failed, :partially_failed
    ], default: :pending_payment

    field :calculated_at, :utc_datetime
    field :processed_at, :utc_datetime
    field :completion_rate, :decimal, default: Decimal.new("0.00")

    # Payment tracking
    field :successful_payments, :integer, default: 0
    field :failed_payments, :integer, default: 0
    field :total_payments_attempted, :integer, default: 0

    belongs_to :campaign, Frestyl.DataCampaigns.Campaign

    timestamps()
  end

  def changeset(revenue_distribution, attrs) do
    revenue_distribution
    |> cast(attrs, [
      :total_revenue, :platform_fee, :payment_processing_fee,
      :contributor_splits, :payment_instructions, :status,
      :calculated_at, :processed_at, :completion_rate,
      :successful_payments, :failed_payments, :total_payments_attempted,
      :campaign_id
    ])
    |> validate_required([:total_revenue, :contributor_splits, :campaign_id])
    |> validate_number(:completion_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:campaign_id)
  end
end
