# lib/frestyl/payments/ticket_type.ex
defmodule Frestyl.Payments.TicketType do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Events.Event

  schema "ticket_types" do
    field :name, :string
    field :description, :string
    field :price_cents, :integer
    field :quantity_available, :integer
    field :quantity_sold, :integer, default: 0
    field :sale_start_date, :utc_datetime
    field :sale_end_date, :utc_datetime
    field :stripe_price_id, :string
    field :is_active, :boolean, default: true

    belongs_to :event, Event
    has_many :ticket_purchases, Frestyl.Payments.TicketPurchase

    timestamps()
  end

  def changeset(ticket_type, attrs) do
    ticket_type
    |> cast(attrs, [
      :name, :description, :price_cents, :quantity_available,
      :quantity_sold, :sale_start_date, :sale_end_date,
      :stripe_price_id, :is_active, :event_id
    ])
    |> validate_required([
      :name, :price_cents, :event_id
    ])
    |> validate_number(:price_cents, greater_than_or_equal_to: 0)
  end
end
