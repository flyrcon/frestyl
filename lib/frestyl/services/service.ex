defmodule Frestyl.Services.Service do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Services.{ServiceBooking, ServiceAvailability}

  schema "services" do
    field :title, :string
    field :description, :string
    field :service_type, Ecto.Enum, values: [:consultation, :coaching, :design_work, :lessons, :custom]
    field :duration_minutes, :integer
    field :price_cents, :integer
    field :currency, :string, default: "USD"
    field :is_active, :boolean, default: true
    field :booking_buffer_minutes, :integer, default: 15
    field :advance_booking_days, :integer, default: 30
    field :cancellation_policy_hours, :integer, default: 24
    field :max_bookings_per_day, :integer
    field :tags, {:array, :string}, default: []
    field :requirements, :string
    field :preparation_notes, :string
    field :location_type, Ecto.Enum, values: [:online, :in_person, :hybrid], default: :online
    field :location_details, :map, default: %{}
    field :auto_confirm, :boolean, default: true
    field :deposit_required, :boolean, default: false
    field :deposit_percentage, :decimal
    field :settings, :map, default: %{}

    belongs_to :user, User
    belongs_to :portfolio, Portfolio
    has_many :bookings, ServiceBooking
    has_many :availabilities, ServiceAvailability

    timestamps()
  end

  def changeset(service, attrs) do
    service
    |> cast(attrs, [
      :title, :description, :service_type, :duration_minutes, :price_cents,
      :currency, :is_active, :booking_buffer_minutes, :advance_booking_days,
      :cancellation_policy_hours, :max_bookings_per_day, :tags, :requirements,
      :preparation_notes, :location_type, :location_details, :auto_confirm,
      :deposit_required, :deposit_percentage, :settings, :user_id, :portfolio_id
    ])
    |> validate_required([:title, :service_type, :duration_minutes, :price_cents, :user_id])
    |> validate_length(:title, min: 3, max: 100)
    |> validate_number(:duration_minutes, greater_than: 0, less_than_or_equal_to: 480)
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
    |> validate_number(:booking_buffer_minutes, greater_than_or_equal_to: 0)
    |> validate_number(:advance_booking_days, greater_than: 0, less_than_or_equal_to: 365)
    |> validate_number(:cancellation_policy_hours, greater_than_or_equal_to: 0)
    |> validate_inclusion(:currency, ["USD", "EUR", "GBP", "CAD", "AUD"])
  end
end
