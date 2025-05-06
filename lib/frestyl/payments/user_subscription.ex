# lib/frestyl/payments/user_subscription.ex
defmodule Frestyl.Payments.UserSubscription do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Payments.SubscriptionPlan
  alias Frestyl.Accounts.User

  schema "user_subscriptions" do
    field :stripe_subscription_id, :string
    field :stripe_customer_id, :string
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :status, :string, default: "inactive"
    field :payment_method_id, :string
    field :is_yearly, :boolean, default: false
    field :auto_renew, :boolean, default: true
    field :canceled_at, :utc_datetime

    belongs_to :user, User
    belongs_to :subscription_plan, SubscriptionPlan

    timestamps()
  end

  def changeset(user_subscription, attrs) do
    user_subscription
    |> cast(attrs, [
      :user_id, :subscription_plan_id, :stripe_subscription_id, :stripe_customer_id,
      :current_period_start, :current_period_end, :status, :payment_method_id,
      :is_yearly, :auto_renew, :canceled_at
    ])
    |> validate_required([
      :user_id, :subscription_plan_id, :stripe_subscription_id,
      :stripe_customer_id, :current_period_start, :current_period_end, :status
    ])
  end
end
