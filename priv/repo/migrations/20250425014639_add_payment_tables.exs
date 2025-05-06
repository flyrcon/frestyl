# priv/repo/migrations/YYYYMMDDHHMMSS_add_payment_tables.exs
defmodule Frestyl.Repo.Migrations.AddPaymentTables do
  use Ecto.Migration

  def change do
    # Subscription plans table
    create table(:subscription_plans) do
      add :name, :string, null: false
      add :description, :text
      add :price_monthly_cents, :integer, null: false
      add :price_yearly_cents, :integer, null: false
      add :platform_fee_percentage, :decimal, precision: 5, scale: 2, null: false
      add :features, {:array, :string}, default: []
      add :max_events_per_month, :integer
      add :stripe_price_id_monthly, :string
      add :stripe_price_id_yearly, :string
      add :is_active, :boolean, default: true

      timestamps()
    end

    # User subscriptions
    create table(:user_subscriptions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subscription_plan_id, references(:subscription_plans, on_delete: :restrict), null: false
      add :stripe_subscription_id, :string
      add :stripe_customer_id, :string
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :status, :string, default: "inactive"
      add :payment_method_id, :string
      add :is_yearly, :boolean, default: false
      add :auto_renew, :boolean, default: true
      add :canceled_at, :utc_datetime

      timestamps()
    end
    create index(:user_subscriptions, [:user_id])
    create index(:user_subscriptions, [:stripe_subscription_id])
    create unique_index(:user_subscriptions, [:user_id, :subscription_plan_id], where: "status = 'active'")

    # Ticket types for events
    create table(:ticket_types) do
      add :event_id, references(:events, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :price_cents, :integer, null: false
      add :quantity_available, :integer
      add :quantity_sold, :integer, default: 0
      add :sale_start_date, :utc_datetime
      add :sale_end_date, :utc_datetime
      add :stripe_price_id, :string
      add :is_active, :boolean, default: true

      timestamps()
    end
    create index(:ticket_types, [:event_id])

    # Ticket purchases
    create table(:ticket_purchases) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :ticket_type_id, references(:ticket_types, on_delete: :restrict), null: false
      add :event_id, references(:events, on_delete: :restrict), null: false
      add :quantity, :integer, null: false
      add :total_amount_cents, :integer, null: false
      add :platform_fee_cents, :integer, null: false
      add :payment_status, :string, default: "pending"
      add :stripe_payment_intent_id, :string
      add :stripe_checkout_session_id, :string
      add :confirmation_code, :string
      add :purchase_date, :utc_datetime
      add :refunded_at, :utc_datetime
      add :refund_amount_cents, :integer
      add :attendee_info, :map, default: %{}

      timestamps()
    end
    create index(:ticket_purchases, [:user_id])
    create index(:ticket_purchases, [:event_id])
    create index(:ticket_purchases, [:stripe_payment_intent_id])
    create index(:ticket_purchases, [:confirmation_code])

    # Payouts to event organizers
    create table(:payouts) do
      add :user_id, references(:users, on_delete: :nilify_all), null: false
      add :event_id, references(:events, on_delete: :restrict), null: false
      add :amount_cents, :integer, null: false
      add :status, :string, default: "pending"
      add :stripe_transfer_id, :string
      add :stripe_payout_id, :string
      add :payout_date, :utc_datetime
      add :notes, :text

      timestamps()
    end
    create index(:payouts, [:user_id])
    create index(:payouts, [:event_id])

    # Analytics and reporting table
    create table(:revenue_reports) do
      add :report_date, :date, null: false
      add :total_ticket_sales_cents, :integer, default: 0
      add :total_subscription_revenue_cents, :integer, default: 0
      add :total_platform_fees_cents, :integer, default: 0
      add :total_payouts_cents, :integer, default: 0
      add :new_subscribers_count, :integer, default: 0
      add :canceled_subscribers_count, :integer, default: 0
      add :daily_active_users, :integer, default: 0
      add :total_events_created, :integer, default: 0
      add :total_tickets_sold, :integer, default: 0

      timestamps()
    end
    create unique_index(:revenue_reports, [:report_date])
  end
end
