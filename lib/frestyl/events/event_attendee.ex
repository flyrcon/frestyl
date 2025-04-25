# lib/frestyl/events/event_attendee.ex
defmodule Frestyl.Events.EventAttendee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "event_attendees" do
    field :status, Ecto.Enum, values: [:registered, :waiting, :admitted, :rejected]
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime
    field :payment_status, Ecto.Enum, values: [:not_required, :pending, :completed, :refunded], default: :not_required
    field :payment_amount_in_cents, :integer
    field :lottery_position, :integer

    belongs_to :event, Frestyl.Events.Event
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(event_attendee, attrs) do
    event_attendee
    |> cast(attrs, [:status, :joined_at, :left_at, :payment_status, :payment_amount_in_cents,
                   :lottery_position, :event_id, :user_id])
    |> validate_required([:status, :event_id, :user_id])
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:event_id, :user_id])
  end
end
