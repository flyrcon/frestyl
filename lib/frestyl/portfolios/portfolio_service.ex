# lib/frestyl/portfolios/portfolio_service.ex
defmodule Frestyl.Portfolios.PortfolioService do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_services" do
    belongs_to :portfolio, Frestyl.Portfolios.Portfolio
    belongs_to :user, Frestyl.Accounts.User

    # Service Basic Info
    field :title, :string
    field :description, :string
    field :service_type, :string # consultation, project, subscription, etc.
    field :category, :string # design, development, consulting, etc.

    # Pricing Information
    field :base_price_cents, :integer
    field :currency, :string, default: "USD"
    field :pricing_model, :string # fixed, hourly, project, subscription
    field :billing_cycle, :string # one_time, weekly, monthly, yearly

    # Service Details
    field :duration_estimate, :string # "2-3 weeks", "1 hour", etc.
    field :delivery_time, :string # "3 business days", "within 24 hours"
    field :revision_count, :integer, default: 2
    field :includes, {:array, :string}, default: []
    field :requirements, {:array, :string}, default: []

    # Booking & Availability
    field :booking_enabled, :boolean, default: false
    field :booking_type, :string, default: "inquiry" # inquiry, calendar, instant
    field :availability_schedule, :map # JSON with time slots
    field :lead_time_hours, :integer, default: 24
    field :max_bookings_per_month, :integer

    # Service Status
    field :is_active, :boolean, default: true
    field :is_featured, :boolean, default: false
    field :position, :integer, default: 0

    # Monetization Tracking
    field :total_bookings, :integer, default: 0
    field :total_revenue_cents, :integer, default: 0
    field :average_rating, :decimal
    field :last_booked_at, :utc_datetime

    # Service Portfolio Integration
    field :portfolio_section_id, :string # Which section this service appears in
    field :display_style, :string, default: "card" # card, list, featured
    field :custom_fields, :map, default: %{} # Additional service-specific data

    timestamps()
  end

  @doc false
  def changeset(portfolio_service, attrs) do
    portfolio_service
    |> cast(attrs, [
      :portfolio_id, :user_id, :title, :description, :service_type, :category,
      :base_price_cents, :currency, :pricing_model, :billing_cycle,
      :duration_estimate, :delivery_time, :revision_count, :includes, :requirements,
      :booking_enabled, :booking_type, :availability_schedule, :lead_time_hours,
      :max_bookings_per_month, :is_active, :is_featured, :position,
      :total_bookings, :total_revenue_cents, :average_rating, :last_booked_at,
      :portfolio_section_id, :display_style, :custom_fields
    ])
    |> validate_required([:portfolio_id, :user_id, :title, :service_type])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:pricing_model, ["fixed", "hourly", "project", "subscription"])
    |> validate_inclusion(:billing_cycle, ["one_time", "weekly", "monthly", "yearly"])
    |> validate_inclusion(:booking_type, ["inquiry", "calendar", "instant"])
    |> validate_inclusion(:display_style, ["card", "list", "featured"])
    |> validate_number(:base_price_cents, greater_than_or_equal_to: 0)
    |> validate_number(:revision_count, greater_than_or_equal_to: 0)
    |> validate_number(:lead_time_hours, greater_than_or_equal_to: 0)
    |> validate_number(:position, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:portfolio_id)
    |> foreign_key_constraint(:user_id)
  end

  # Helper functions for service management

  def format_price(%__MODULE__{} = service) do
    case service.pricing_model do
      "fixed" ->
        format_currency_amount(service.base_price_cents, service.currency)
      "hourly" ->
        "#{format_currency_amount(service.base_price_cents, service.currency)}/hour"
      "project" ->
        "Starting at #{format_currency_amount(service.base_price_cents, service.currency)}"
      "subscription" ->
        "#{format_currency_amount(service.base_price_cents, service.currency)}/#{service.billing_cycle}"
      _ ->
        format_currency_amount(service.base_price_cents, service.currency)
    end
  end

  def calculate_total_price(%__MODULE__{} = service, options \\ %{}) do
    base_price = service.base_price_cents

    # Add any additional costs based on service options
    additional_costs = calculate_additional_costs(service, options)

    base_price + additional_costs
  end

  def is_bookable?(%__MODULE__{} = service) do
    service.is_active && service.booking_enabled
  end

  def get_next_available_slot(%__MODULE__{} = service) do
    # This would integrate with calendar/booking system
    # For now, return a placeholder
    DateTime.add(DateTime.utc_now(), service.lead_time_hours * 3600, :second)
  end

  defp format_currency_amount(cents, currency) when is_integer(cents) do
    dollars = cents / 100

    case currency do
      "USD" -> "$#{:erlang.float_to_binary(dollars, [{:decimals, 2}])}"
      "EUR" -> "€#{:erlang.float_to_binary(dollars, [{:decimals, 2}])}"
      "GBP" -> "£#{:erlang.float_to_binary(dollars, [{:decimals, 2}])}"
      _ -> "#{currency} #{:erlang.float_to_binary(dollars, [{:decimals, 2}])}"
    end
  end
  defp format_currency_amount(_, _), do: "$0.00"

  defp calculate_additional_costs(_service, _options) do
    # Placeholder for additional cost calculations
    # Could include rush delivery, extra revisions, etc.
    0
  end
end
