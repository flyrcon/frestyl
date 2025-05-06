# lib/frestyl/payments/payout.ex
defmodule Frestyl.Payments.Payout do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Events.Event

  schema "payouts" do
    field :amount_cents, :integer
    field :status, :string, default: "pending"
    field :stripe_transfer_id, :string
    field :stripe_payout_id, :string
    field :payout_date, :utc_datetime
    field :notes, :string

    belongs_to :user, User
    belongs_to :event, Event

    timestamps()
  end

  def changeset(payout, attrs) do
    payout
    |> cast(attrs, [
      :user_id, :event_id, :amount_cents, :status, :stripe_transfer_id,
      :stripe_payout_id, :payout_date, :notes
    ])
    |> validate_required([
      :user_id, :event_id, :amount_cents
    ])
    |> validate_number(:amount_cents, greater_than: 0)
  end
end
