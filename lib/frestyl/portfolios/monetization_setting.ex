
# lib/frestyl/portfolios/monetization_setting.ex
defmodule Frestyl.Portfolios.MonetizationSetting do
  use Ecto.Schema
  import Ecto.Changeset

  schema "monetization_settings" do
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :account, Frestyl.Accounts.Account

    # Payment Configuration
    field :payment_processor, :string, default: "stripe" # stripe, paypal, etc
    field :payment_processor_account_id, :string
    field :currency, :string, default: "USD"
    field :tax_rate_percentage, :decimal, default: Decimal.new("0.00")

    # Service Pricing
    field :hourly_rate_cents, :integer
    field :project_rate_enabled, :boolean, default: true
    field :subscription_enabled, :boolean, default: false
    field :commission_enabled, :boolean, default: false
    field :booking_enabled, :boolean, default: false

    # Commission Settings
    field :commission_rate_percentage, :decimal, default: Decimal.new("15.00")
    field :rush_order_rate_percentage, :decimal, default: Decimal.new("50.00")
    field :revision_fee_cents, :integer, default: 0

    # Booking Settings
    field :booking_calendar_url, :string
    field :booking_lead_time_hours, :integer, default: 24
    field :booking_buffer_minutes, :integer, default: 15
    field :max_booking_advance_days, :integer, default: 90
    field :cancellation_policy, :string, default: "24_hours"

    # Subscription Tiers
    field :subscription_tiers, :map, default: %{}
    field :subscription_benefits, :map, default: %{}

    # Revenue Analytics
    field :total_revenue_cents, :integer, default: 0
    field :monthly_revenue_cents, :integer, default: 0
    field :total_bookings, :integer, default: 0
    field :conversion_rate_percentage, :decimal, default: Decimal.new("0.00")
    field :average_project_value_cents, :integer, default: 0

    # Platform Fees
    field :platform_fee_percentage, :decimal, default: Decimal.new("5.00")
    field :payment_processing_fee_percentage, :decimal, default: Decimal.new("2.90")

    # Status
    field :is_active, :boolean, default: false
    field :verification_status, :string, default: "pending" # pending, verified, suspended
    field :payout_schedule, :string, default: "weekly" # daily, weekly, monthly

    timestamps()
  end

  @doc false
  def changeset(monetization_setting, attrs) do
    monetization_setting
    |> cast(attrs, [
      :portfolio_id, :account_id, :payment_processor, :payment_processor_account_id, :currency, :tax_rate_percentage,
      :hourly_rate_cents, :project_rate_enabled, :subscription_enabled, :commission_enabled, :booking_enabled,
      :commission_rate_percentage, :rush_order_rate_percentage, :revision_fee_cents,
      :booking_calendar_url, :booking_lead_time_hours, :booking_buffer_minutes, :max_booking_advance_days, :cancellation_policy,
      :subscription_tiers, :subscription_benefits,
      :total_revenue_cents, :monthly_revenue_cents, :total_bookings, :conversion_rate_percentage, :average_project_value_cents,
      :platform_fee_percentage, :payment_processing_fee_percentage,
      :is_active, :verification_status, :payout_schedule
    ])
    |> validate_required([:portfolio_id, :account_id, :currency])
    |> validate_inclusion(:currency, ["USD", "EUR", "GBP", "CAD", "AUD"])
    |> validate_inclusion(:payment_processor, ["stripe", "paypal", "square"])
    |> validate_inclusion(:cancellation_policy, ["no_cancellation", "1_hour", "24_hours", "48_hours", "7_days"])
    |> validate_inclusion(:verification_status, ["pending", "verified", "suspended"])
    |> validate_inclusion(:payout_schedule, ["daily", "weekly", "monthly"])
    |> validate_number(:commission_rate_percentage, greater_than_or_equal_to: Decimal.new("0"), less_than_or_equal_to: Decimal.new("50"))
    |> validate_number(:platform_fee_percentage, greater_than_or_equal_to: Decimal.new("0"), less_than_or_equal_to: Decimal.new("15"))
    |> validate_number(:booking_lead_time_hours, greater_than_or_equal_to: 1)
    |> unique_constraint([:portfolio_id])
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:account_id)
  end

  def calculate_net_amount(gross_amount_cents, monetization_setting) do
    platform_fee = Decimal.mult(
      Decimal.new(gross_amount_cents),
      Decimal.div(monetization_setting.platform_fee_percentage, 100)
    )

    processing_fee = Decimal.mult(
      Decimal.new(gross_amount_cents),
      Decimal.div(monetization_setting.payment_processing_fee_percentage, 100)
    )

    total_fees = Decimal.add(platform_fee, processing_fee)
    net_amount = Decimal.sub(Decimal.new(gross_amount_cents), total_fees)

    Decimal.to_integer(net_amount)
  end
end
