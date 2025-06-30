# priv/repo/migrations/create_monetization_settings.exs
defmodule Frestyl.Repo.Migrations.CreateMonetizationSettings do
  use Ecto.Migration

  def change do
    create table(:monetization_settings) do
      add :portfolio_id, references(:portfolios, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :delete_all), null: false

      # Payment Configuration
      add :payment_processor, :string, default: "stripe"
      add :payment_processor_account_id, :string
      add :currency, :string, default: "USD"
      add :tax_rate_percentage, :decimal, precision: 5, scale: 2, default: 0.00

      # Service Pricing
      add :hourly_rate_cents, :integer
      add :project_rate_enabled, :boolean, default: true
      add :subscription_enabled, :boolean, default: false
      add :commission_enabled, :boolean, default: false
      add :booking_enabled, :boolean, default: false

      # Commission Settings
      add :commission_rate_percentage, :decimal, precision: 5, scale: 2, default: 15.00
      add :rush_order_rate_percentage, :decimal, precision: 5, scale: 2, default: 50.00
      add :revision_fee_cents, :integer, default: 0

      # Booking Settings
      add :booking_calendar_url, :string
      add :booking_lead_time_hours, :integer, default: 24
      add :booking_buffer_minutes, :integer, default: 15
      add :max_booking_advance_days, :integer, default: 90
      add :cancellation_policy, :string, default: "24_hours"

      # Subscription Tiers
      add :subscription_tiers, :map, default: "{}"
      add :subscription_benefits, :map, default: "{}"

      # Revenue Analytics
      add :total_revenue_cents, :integer, default: 0
      add :monthly_revenue_cents, :integer, default: 0
      add :total_bookings, :integer, default: 0
      add :conversion_rate_percentage, :decimal, precision: 5, scale: 2, default: 0.00
      add :average_project_value_cents, :integer, default: 0

      # Platform Fees
      add :platform_fee_percentage, :decimal, precision: 5, scale: 2, default: 5.00
      add :payment_processing_fee_percentage, :decimal, precision: 5, scale: 2, default: 2.90

      # Status
      add :is_active, :boolean, default: false
      add :verification_status, :string, default: "pending"
      add :payout_schedule, :string, default: "weekly"

      timestamps()
    end

    create unique_index(:monetization_settings, [:portfolio_id])
    create index(:monetization_settings, [:account_id])
    create index(:monetization_settings, [:verification_status])
    create index(:monetization_settings, [:is_active])
  end
end
