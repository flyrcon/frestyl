# lib/frestyl/events/event.ex
defmodule Frestyl.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :title, :string
    field :description, :string
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :status, Ecto.Enum, values: [:draft, :scheduled, :live, :completed, :cancelled]
    field :admission_type, Ecto.Enum, values: [:open, :invite_only, :paid, :lottery]
    field :price_in_cents, :integer, default: 0
    field :max_attendees, :integer
    field :waiting_room_opens_at, :utc_datetime

    belongs_to :host, Frestyl.Accounts.User
    belongs_to :session, Frestyl.Sessions.Session

    has_many :event_attendees, Frestyl.Events.EventAttendee
    has_many :attendees, through: [:event_attendees, :user]
    has_many :event_invitations, Frestyl.Events.EventInvitation
    has_many :votes, Frestyl.Events.Vote

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:title, :description, :starts_at, :ends_at, :status, :admission_type,
                   :price_in_cents, :max_attendees, :waiting_room_opens_at, :host_id, :session_id])
    |> validate_required([:title, :starts_at, :status, :admission_type, :host_id])
    |> validate_admission_requirements()
    |> validate_dates()
    |> foreign_key_constraint(:host_id)
    |> foreign_key_constraint(:session_id)
  end

  defp validate_admission_requirements(changeset) do
    case get_field(changeset, :admission_type) do
      :paid ->
        changeset
        |> validate_required([:price_in_cents])
        |> validate_number(:price_in_cents, greater_than: 0)
      :lottery ->
        validate_required(changeset, [:max_attendees])
      _ ->
        changeset
    end
  end

  defp validate_dates(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)
    waiting_room_opens_at = get_field(changeset, :waiting_room_opens_at)

    changeset
    |> validate_starts_before_ends(starts_at, ends_at)
    |> validate_waiting_room_before_start(waiting_room_opens_at, starts_at)
  end

  defp validate_starts_before_ends(changeset, starts_at, ends_at) do
    if starts_at && ends_at && DateTime.compare(starts_at, ends_at) != :lt do
      add_error(changeset, :ends_at, "must be after the start time")
    else
      changeset
    end
  end

  defp validate_waiting_room_before_start(changeset, waiting_room_opens_at, starts_at) do
    if waiting_room_opens_at && starts_at && DateTime.compare(waiting_room_opens_at, starts_at) != :lt do
      add_error(changeset, :waiting_room_opens_at, "must be before the start time")
    else
      changeset
    end
  end
end
