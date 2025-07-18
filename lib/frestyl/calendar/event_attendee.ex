defmodule Frestyl.Calendar.EventAttendee do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "calendar_event_attendees" do
    field :email, :string
    field :name, :string
    field :status, :string, default: "invited"
    field :role, :string, default: "attendee"
    field :notification_preferences, :map, default: %{}

    field :event_id, :binary_id
    field :user_id, :integer

    # Manual associations
    belongs_to :event, Frestyl.Calendar.Event, foreign_key: :event_id, references: :id, define_field: false
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, references: :id, define_field: false

    timestamps()
  end

  def changeset(attendee, attrs) do
    attendee
    |> cast(attrs, [:event_id, :user_id, :email, :name, :status, :role, :notification_preferences])
    |> validate_required([:event_id])
    |> validate_inclusion(:status, ["invited", "accepted", "declined", "tentative"])
    |> validate_inclusion(:role, ["organizer", "attendee", "optional"])
    |> validate_attendee_identity()
    |> unique_constraint([:event_id, :user_id])
    |> unique_constraint([:event_id, :email])
  end

  defp validate_attendee_identity(changeset) do
    user_id = get_field(changeset, :user_id)
    email = get_field(changeset, :email)

    if is_nil(user_id) and is_nil(email) do
      add_error(changeset, :base, "must provide either user_id or email")
    else
      changeset
    end
  end
end
