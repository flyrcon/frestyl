# lib/frestyl/portfolios/monetization_setting.ex
defmodule Frestyl.Portfolios.MonetizationSetting do
  @moduledoc """
  Monetization configuration for individual content blocks.
  Handles pricing, booking, payments at the granular block level.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "portfolio_monetization_settings" do
    field :setting_type, Ecto.Enum, values: [
      :hourly_rate, :fixed_price, :service_package, :consultation_fee,
      :subscription_tier, :one_time_payment, :booking_fee, :streaming_access
    ]

    field :pricing_data, :map, default: %{}
    field :booking_config, :map, default: %{}
    field :payment_integration, :map, default: %{}
    field :availability_rules, :map, default: %{}
    field :currency, :string, default: "USD"
    field :is_negotiable, :boolean, default: false
    field :requires_approval, :boolean, default: false
    field :stripe_price_id, :string
    field :stripe_product_id, :string

    belongs_to :content_block, Frestyl.Portfolios.ContentBlock
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio

    timestamps()
  end

  def changeset(monetization_setting, attrs) do
    monetization_setting
    |> cast(attrs, [
      :setting_type, :pricing_data, :booking_config, :payment_integration,
      :availability_rules, :currency, :is_negotiable, :requires_approval,
      :stripe_price_id, :stripe_product_id, :content_block_id, :portfolio_id
    ])
    |> validate_required([:setting_type, :content_block_id, :portfolio_id])
    |> validate_pricing_data()
    |> validate_currency_format()
  end

  defp validate_pricing_data(changeset) do
    case get_change(changeset, :pricing_data) do
      %{"amount" => amount} when is_number(amount) and amount > 0 ->
        changeset
      %{"min_amount" => min, "max_amount" => max} when is_number(min) and is_number(max) and min <= max ->
        changeset
      nil ->
        changeset
      _ ->
        add_error(changeset, :pricing_data, "must contain valid pricing information")
    end
  end

  defp validate_currency_format(changeset) do
    case get_change(changeset, :currency) do
      currency when currency in ["USD", "EUR", "GBP", "CAD", "AUD"] ->
        changeset
      nil ->
        changeset
      _ ->
        add_error(changeset, :currency, "must be a valid currency code")
    end
  end
end
