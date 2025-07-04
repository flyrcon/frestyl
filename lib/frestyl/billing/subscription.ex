defmodule Frestyl.Billing.Subscription do
  use Ecto.Schema           # Provides schema/2 macro
  import Ecto.Changeset

  schema "subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :tier, Ecto.Enum, values: [:personal, :creator, :professional, :enterprise]
    field :status, Ecto.Enum, values: [:active, :past_due, :canceled, :paused]

    # Pricing & billing
    field :base_price_cents, :integer
    field :usage_based_pricing, :map  # For overage charges
    field :billing_cycle, Ecto.Enum, values: [:monthly, :yearly]
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :canceled_at, :utc_datetime

    # Usage-based billing components
    field :included_allowances, :map
    field :overage_rates, :map

    has_many :accounts, Frestyl.Accounts.Account
    has_many :usage_records, Frestyl.Billing.UsageRecord

    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:user_id, :stripe_subscription_id, :stripe_customer_id, :status, :tier, :current_period_start, :current_period_end, :canceled_at])
    |> validate_required([:user_id, :stripe_subscription_id, :stripe_customer_id, :status, :tier])
    |> validate_inclusion(:status, ["active", "trialing", "past_due", "canceled", "unpaid"])
    |> validate_inclusion(:tier, ["storyteller", "professional", "business"])
    |> unique_constraint(:stripe_subscription_id)
  end
end
