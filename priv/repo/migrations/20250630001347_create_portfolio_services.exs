
# ============================================================================
# MIGRATION
# ============================================================================

# priv/repo/migrations/20250629000002_create_portfolio_services.exs
defmodule Frestyl.Repo.Migrations.CreatePortfolioServices do
  use Ecto.Migration

  def change do
    alter table(:portfolio_services) do
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # Service Basic Info
      add_if_not_exists :title, :string, null: false
      add_if_not_exists :description, :text
      add_if_not_exists :service_type, :string, null: false
      add_if_not_exists :category, :string

      # Pricing Information
      add :base_price_cents, :integer, default: 0
      add :currency, :string, default: "USD"
      add :pricing_model, :string, default: "fixed"
      add :billing_cycle, :string, default: "one_time"

      # Service Details
      add :duration_estimate, :string
      add :delivery_time, :string
      add :revision_count, :integer, default: 2
      add :includes, {:array, :string}, default: fragment("ARRAY[]::text[]")
      add :requirements, {:array, :string}, default: fragment("ARRAY[]::text[]")

      # Booking & Availability
      add :booking_enabled, :boolean, default: false
      add_if_not_exists :booking_type, :string, default: "inquiry"
      add_if_not_exists :availability_schedule, :map, default: "{}"
      add_if_not_exists :lead_time_hours, :integer, default: 24
      add_if_not_exists :max_bookings_per_month, :integer

      # Service Status
      add_if_not_exists :is_active, :boolean, default: true
      add :is_featured, :boolean, default: false
      add :position, :integer, default: 0

      # Monetization Tracking
      add :total_bookings, :integer, default: 0
      add :total_revenue_cents, :integer, default: 0
      add :average_rating, :decimal, precision: 3, scale: 2
      add :last_booked_at, :utc_datetime

      # Portfolio Integration
      add :portfolio_section_id, :string
      add :display_style, :string, default: "card"
      add :custom_fields, :map, default: "{}"

    end

    create index(:portfolio_services, [:is_active])
    create index(:portfolio_services, [:is_featured])
    create index(:portfolio_services, [:position])
  end
end
