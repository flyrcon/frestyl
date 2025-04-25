# lib/frestyl/payments/subscription_plan.ex
defmodule Frestyl.Payments.SubscriptionPlan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "subscription_plans" do
    field :name, :string
    field :description, :string
    field :price_monthly_cents, :integer
    field :price_yearly_cents, :integer
    field :platform_fee_percentage, :decimal
    field :features, {:array, :string}, default: []
    field :max_events_per_month, :integer
    field :stripe_price_id_monthly, :string
    field :stripe_price_id_yearly, :string
    field :is_active, :boolean, default: true

    has_many :user_subscriptions, Frestyl.Payments.UserSubscription

    timestamps()
  end

  def changeset(subscription_plan, attrs) do
    subscription_plan
    |> cast(attrs, [:name, :description, :price_monthly_cents, :price_yearly_cents,
                    :platform_fee_percentage, :features, :max_events_per_month,
                    :stripe_price_id_monthly, :stripe_price_id_yearly, :is_active])
    |> validate_required([:name, :price_monthly_cents, :price_yearly_cents, :platform_fee_percentage])
  end
end
