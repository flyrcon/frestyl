# lib/frestyl/payments/ticket_purchase.ex
defmodule Frestyl.Payments.TicketPurchase do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Events.Event
  alias Frestyl.Payments.TicketType

  schema "ticket_purchases" do
    field :quantity, :integer
    field :total_amount_cents, :integer
    field :platform_fee_cents, :integer
    field :payment_status, :string, default: "pending"
    field :stripe_payment_intent_id, :string
    field :stripe_checkout_session_id, :string
    field :confirmation_code, :string
    field :purchase_date, :utc_datetime
    field :refunded_at, :utc_datetime
    field :refund_amount_cents, :integer
    field :attendee_info, :map, default: %{}

    belongs_to :user, User
    belongs_to :ticket_type, TicketType
    belongs_to :event, Event

    timestamps()
  end

  def changeset(ticket_purchase, attrs) do
    ticket_purchase
    |> cast(attrs, [
      :user_id, :ticket_type_id, :event_id, :quantity, :total_amount_cents,
      :platform_fee_cents, :payment_status, :stripe_payment_intent_id,
      :stripe_checkout_session_id, :confirmation_code, :purchase_date,
      :refunded_at, :refund_amount_cents, :attendee_info
    ])
    |> validate_required([
      :ticket_type_id, :event_id, :quantity, :total_amount_cents, :platform_fee_cents
    ])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:total_amount_cents, greater_than_or_equal_to: 0)
  end
end
