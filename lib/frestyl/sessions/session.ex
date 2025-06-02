# lib/frestyl/sessions/session.ex
defmodule Frestyl.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Accounts.User
  alias Frestyl.Channels.Channel
  alias Frestyl.Sessions.SessionParticipant

  schema "sessions" do
    field :title, :string
    field :description, :string
    field :session_type, :string
    field :broadcast_type, :string
    field :status, :string, default: "scheduled"
    field :scheduled_for, :utc_datetime
    field :scheduled_end, :utc_datetime  # NEW: Specific end time
    field :duration_minutes, :integer    # NEW: Duration in minutes
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :is_public, :boolean, default: true
    field :waiting_room_enabled, :boolean, default: false
    field :max_participants, :integer

    belongs_to :creator, User
    belongs_to :host, User
    belongs_to :channel, Channel
    has_many :session_participants, SessionParticipant

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :session_type, :broadcast_type, :status,
      :scheduled_for, :scheduled_end, :duration_minutes, :started_at, :ended_at,
      :is_public, :waiting_room_enabled, :max_participants,
      :creator_id, :host_id, :channel_id
    ])
    |> validate_required([:title, :session_type, :creator_id, :channel_id])
    |> validate_inclusion(:session_type, ["regular", "broadcast"])
    |> validate_inclusion(:status, ["scheduled", "active", "ended", "cancelled"])
    |> validate_number(:duration_minutes, greater_than: 0, less_than_or_equal_to: 480)
    |> validate_duration_or_end_time()
    |> calculate_end_time()
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:host_id)
    |> foreign_key_constraint(:channel_id)
  end

  def broadcast_changeset(session \\ %__MODULE__{}, attrs) do
    session
    |> changeset(attrs)
    |> put_change(:session_type, "broadcast")
    |> validate_required([:scheduled_for])
    |> validate_inclusion(:broadcast_type, [
      "standard", "performance", "tutorial", "interview", "q_and_a"
    ])
  end

  def collaboration_changeset(session \\ %__MODULE__{}, attrs) do
    session
    |> changeset(attrs)
    |> put_change(:session_type, "regular")
  end

  def end_session_changeset(session) do
    session
    |> changeset(%{})
    |> put_change(:status, "ended")
    |> put_change(:ended_at, DateTime.utc_now())
  end

  # Custom validation to ensure either duration or end time is provided
  defp validate_duration_or_end_time(changeset) do
    duration = get_field(changeset, :duration_minutes)
    scheduled_end = get_field(changeset, :scheduled_end)

    cond do
      duration && duration > 0 ->
        changeset
      scheduled_end ->
        changeset
      true ->
        # Default to 60 minutes if neither is provided
        put_change(changeset, :duration_minutes, 60)
    end
  end

  # Calculate scheduled_end from duration if not explicitly set
  defp calculate_end_time(changeset) do
    scheduled_for = get_field(changeset, :scheduled_for)
    duration_minutes = get_field(changeset, :duration_minutes)
    scheduled_end = get_field(changeset, :scheduled_end)

    cond do
      # If scheduled_end is already set, use it
      scheduled_end ->
        changeset

      # If we have start time and duration, calculate end time
      scheduled_for && duration_minutes ->
        calculated_end = DateTime.add(scheduled_for, duration_minutes * 60, :second)
        put_change(changeset, :scheduled_end, calculated_end)

      # Otherwise, leave as is
      true ->
        changeset
    end
  end
end
