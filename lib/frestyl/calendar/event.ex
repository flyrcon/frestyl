defmodule Frestyl.Calendar.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "calendar_events" do
    field :title, :string
    field :description, :string
    field :event_type, :string
    field :status, :string, default: "scheduled"

    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :timezone, :string, default: "UTC"
    field :all_day, :boolean, default: false

    field :visibility, :string, default: "private"
    field :booking_enabled, :boolean, default: false
    field :max_attendees, :integer
    field :requires_approval, :boolean, default: false
    field :meeting_url, :string
    field :location, :string

    field :is_paid, :boolean, default: false
    field :price_cents, :integer, default: 0
    field :currency, :string, default: "USD"

    field :external_calendar_id, :string
    field :external_event_id, :string
    field :external_provider, :string
    field :sync_status, :string, default: "pending"

    field :metadata, :map, default: %{}
    field :reminders, {:array, :map}, default: []
    field :recurrence_rule, :string

    # Foreign keys - all bigint to match existing schema
    field :creator_id, :integer
    field :account_id, :integer
    field :portfolio_id, :integer
    field :channel_id, :integer
    field :service_booking_id, :integer
    field :broadcast_id, :integer
    field :parent_event_id, :binary_id

    # Associations (using manual belongs_to since we have mixed foreign key types)
    belongs_to :creator, Frestyl.Accounts.User, foreign_key: :creator_id, references: :id, define_field: false
    belongs_to :account, Frestyl.Accounts.Account, foreign_key: :account_id, references: :id, define_field: false
    belongs_to :parent_event, __MODULE__, foreign_key: :parent_event_id, references: :id, define_field: false

    has_many :attendees, Frestyl.Calendar.EventAttendee, foreign_key: :event_id
    has_many :child_events, __MODULE__, foreign_key: :parent_event_id

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :title, :description, :event_type, :status, :starts_at, :ends_at,
      :timezone, :all_day, :visibility, :booking_enabled, :max_attendees,
      :requires_approval, :meeting_url, :location, :is_paid, :price_cents,
      :currency, :metadata, :reminders, :recurrence_rule, :creator_id,
      :account_id, :portfolio_id, :channel_id, :service_booking_id,
      :broadcast_id, :parent_event_id
    ])
    |> validate_required([:title, :starts_at, :ends_at, :event_type])
    |> validate_inclusion(:event_type, ["service_booking", "broadcast", "collaboration", "channel_event", "personal"])
    |> validate_inclusion(:status, ["scheduled", "confirmed", "in_progress", "completed", "cancelled"])
    |> validate_inclusion(:visibility, ["private", "channel", "public", "account"])
    |> validate_datetime_order()
    |> validate_attendee_limit()
  end

  defp validate_datetime_order(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(starts_at, ends_at) != :lt do
      add_error(changeset, :ends_at, "must be after start time")
    else
      changeset
    end
  end

  defp validate_attendee_limit(changeset) do
    max_attendees = get_field(changeset, :max_attendees)

    if max_attendees && max_attendees < 1 do
      add_error(changeset, :max_attendees, "must be at least 1")
    else
      changeset
    end
  end
end
