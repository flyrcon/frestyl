defmodule Frestyl.Billing.Subscription do
  use Ecto.Schema           # Provides schema/2 macro
  import Ecto.Changeset

  schema "subscriptions" do
    field :stripe_subscription_id, :string
    field :tier, Ecto.Enum, values: [:personal, :creator, :professional, :enterprise]
    field :status, Ecto.Enum, values: [:active, :past_due, :canceled, :paused]

    # Pricing & billing
    field :base_price_cents, :integer
    field :usage_based_pricing, :map  # For overage charges
    field :billing_cycle, Ecto.Enum, values: [:monthly, :yearly]
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime

    # Usage-based billing components
    field :included_allowances, :map
    field :overage_rates, :map

    has_many :accounts, Frestyl.Accounts.Account
    has_many :usage_records, Frestyl.Billing.UsageRecord

    timestamps()
  end
end
