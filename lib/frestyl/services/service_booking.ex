defmodule Frestyl.Services.ServiceBooking do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Services.Service

  schema "service_bookings" do
    field :booking_reference, :string
    field :scheduled_at, :utc_datetime
    field :client_name, :string
    field :client_email, :string
    field :client_phone, :string
    field :client_notes, :string
    field :status, Ecto.Enum, values: [:pending, :confirmed, :completed, :cancelled, :no_show], default: :pending
    field :total_amount_cents, :integer
    field :platform_fee_cents, :integer
    field :provider_amount_cents, :integer
    field :deposit_amount_cents, :integer
    field :payment_status, Ecto.Enum, values: [:pending, :deposit_paid, :fully_paid, :refunded], default: :pending
    field :stripe_payment_intent_id, :string
    field :stripe_checkout_session_id, :string
    field :confirmation_sent_at, :utc_datetime
    field :reminder_sent_at, :utc_datetime
    field :cancelled_at, :utc_datetime
    field :cancellation_reason, :string
    field :completed_at, :utc_datetime
    field :provider_notes, :string
    field :client_rating, :integer
    field :client_feedback, :string
    field :meeting_link, :string
    field :meeting_details, :map, default: %{}

    belongs_to :service, Service
    belongs_to :client, User, foreign_key: :client_id
    belongs_to :provider, User, foreign_key: :provider_id

    timestamps()
  end

  def changeset(booking, attrs) do
    booking
    |> cast(attrs, [
      :scheduled_at, :client_name, :client_email, :client_phone, :client_notes,
      :status, :total_amount_cents, :platform_fee_cents, :provider_amount_cents,
      :deposit_amount_cents, :payment_status, :stripe_payment_intent_id,
      :stripe_checkout_session_id, :cancellation_reason, :provider_notes,
      :client_rating, :client_feedback, :meeting_link, :meeting_details,
      :service_id, :client_id, :provider_id
    ])
    |> validate_required([:scheduled_at, :client_name, :client_email, :service_id, :provider_id])
    |> validate_format(:client_email, ~r/@/)
    |> validate_number(:client_rating, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
    |> generate_booking_reference()
    |> unique_constraint(:booking_reference)
  end

  defp generate_booking_reference(changeset) do
    if changeset.valid? && is_nil(get_field(changeset, :booking_reference)) do
      put_change(changeset, :booking_reference, generate_reference())
    else
      changeset
    end
  end

  defp generate_reference do
    timestamp = DateTime.utc_now()
                |> DateTime.to_unix()
                |> Integer.to_string()
                |> String.slice(-8..-1)

    random_part = :crypto.strong_rand_bytes(3)
                  |> Base.encode16()
                  |> String.slice(0..2)

    "FS" <> timestamp <> random_part
  end
end
