# File: lib/frestyl/data_campaigns/contract.ex

defmodule Frestyl.DataCampaigns.Contract do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "campaign_contracts" do
    field :contract_type, Ecto.Enum, values: [
      :revenue_sharing, :fixed_payment, :equity_based, :milestone_based
    ], default: :revenue_sharing

    field :terms, :map
    field :revenue_split, :map
    field :quality_requirements, :map
    field :timeline, :map
    field :legal_terms, :string

    field :status, Ecto.Enum, values: [
      :draft, :pending_signature, :active, :completed, :terminated
    ], default: :draft

    field :signed_at, :utc_datetime
    field :signature_hash, :string
    field :signature_metadata, :map

    # Financial tracking
    field :total_payments_made, :decimal, default: Decimal.new("0.00")
    field :last_payment_date, :utc_datetime
    field :payment_schedule, :map

    belongs_to :campaign, Frestyl.DataCampaigns.Campaign
    belongs_to :contributor, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(contract, attrs) do
    contract
    |> cast(attrs, [
      :contract_type, :terms, :revenue_split, :quality_requirements,
      :timeline, :legal_terms, :status, :signed_at, :signature_hash,
      :signature_metadata, :total_payments_made, :last_payment_date,
      :payment_schedule, :campaign_id, :contributor_id
    ])
    |> validate_required([:contract_type, :terms, :campaign_id, :contributor_id])
    |> validate_revenue_split()
    |> validate_quality_requirements()
    |> foreign_key_constraint(:campaign_id)
    |> foreign_key_constraint(:contributor_id)
  end

  defp validate_revenue_split(changeset) do
    case get_change(changeset, :revenue_split) do
      nil -> changeset
      revenue_split ->
        if is_valid_revenue_split?(revenue_split) do
          changeset
        else
          add_error(changeset, :revenue_split, "invalid revenue split configuration")
        end
    end
  end

  defp validate_quality_requirements(changeset) do
    case get_change(changeset, :quality_requirements) do
      nil -> changeset
      requirements ->
        if is_list(requirements) and length(requirements) > 0 do
          changeset
        else
          add_error(changeset, :quality_requirements, "must include at least one quality requirement")
        end
    end
  end

  defp is_valid_revenue_split?(revenue_split) do
    case revenue_split do
      %{"percentage" => percentage} when is_number(percentage) and percentage > 0 and percentage <= 100 ->
        true
      _ ->
        false
    end
  end
end
