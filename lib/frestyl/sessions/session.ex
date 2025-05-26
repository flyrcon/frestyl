# lib/frestyl/sessions/session.ex
defmodule Frestyl.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Channels.Channel
  alias Frestyl.Accounts.User
  alias Frestyl.Sessions.SessionParticipant
  alias Frestyl.Sessions.Message

  schema "sessions" do
    field :title, :string
    field :description, :string
    field :status, :string, default: "active"
    field :session_type, :string, default: "mixed"
    field :is_public, :boolean, default: true
    field :scheduled_for, :utc_datetime
    field :ended_at, :utc_datetime
    field :workspace_state, :map
    field :recording_available, :boolean, default: false
    field :recording_url, :string
    field :max_participants, :integer

    # Virtual fields
    field :participants_count, :integer, virtual: true
    field :creator_name, :string, virtual: true
    field :host_name, :string, virtual: true
    field :registered_count, :integer, virtual: true

    # Broadcast-specific fields
    field :broadcast_type, :string
    field :waiting_room_enabled, :boolean, default: true
    field :waiting_room_open_time, :utc_datetime
    field :started_at, :utc_datetime

    # Relationships
    belongs_to :channel, Channel
    belongs_to :creator, User
    belongs_to :host, User
    has_many :session_participants, SessionParticipant
    has_many :participants, through: [:session_participants, :user]
    has_many :messages, Message

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :status, :session_type, :is_public,
      :scheduled_for, :ended_at, :channel_id, :creator_id,
      :workspace_state, :recording_available, :recording_url,
      :max_participants, :broadcast_type, :waiting_room_enabled,
      :waiting_room_open_time, :host_id
    ])
    |> validate_required([:title, :channel_id])
    |> validate_inclusion(:status, ["active", "scheduled", "ended", "cancelled"])
    |> validate_inclusion(:session_type, ["mixed", "audio", "text", "visual", "midi", "broadcast"]) # Added "broadcast"
    |> validate_broadcast_fields()
    |> validate_session_scheduling()
  end

  defp validate_broadcast_fields(changeset) do
    broadcast_type = get_field(changeset, :broadcast_type)

    if broadcast_type do
      changeset
      |> validate_required([:scheduled_for, :host_id])
      |> validate_inclusion(:broadcast_type, ["standard", "performance", "tutorial", "interview", "q_and_a"])
    else
      changeset
    end
  end

  defp validate_session_scheduling(changeset) do
    scheduled_for = get_change(changeset, :scheduled_for)
    status = get_change(changeset, :status)

    if scheduled_for && status == "active" do
      # If a session is scheduled for the future, it can't be active yet
      now = DateTime.utc_now()

      if DateTime.compare(scheduled_for, now) == :gt do
        put_change(changeset, :status, "scheduled")
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Creates a session for a standard real-time collaboration
  """
  def collaboration_changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :description, :session_type, :is_public, :channel_id, :creator_id, :max_participants])
    |> validate_required([:title, :channel_id, :creator_id])
    |> validate_inclusion(:session_type, ["mixed", "audio", "text", "visual", "midi", "broadcast"]) # Added "broadcast"
    |> put_change(:status, "active")
  end

  @doc """
  Creates a session for a broadcast event
  """
  def broadcast_changeset(session, attrs) do
    IO.inspect(attrs, label: "Input attrs")

    changeset = session
    |> cast(attrs, [
      :title, :description, :broadcast_type, :is_public, :channel_id,
      :host_id, :creator_id, :scheduled_for, :waiting_room_enabled, :waiting_room_open_time,
      :max_participants, :session_type
    ])
    |> validate_required([:title, :channel_id, :host_id, :creator_id, :scheduled_for, :broadcast_type])
    |> validate_inclusion(:broadcast_type, ["standard", "performance", "tutorial", "interview", "q_and_a"])
    |> validate_scheduled_time()
    |> put_change(:status, "scheduled")
    |> put_change(:session_type, "broadcast")
    |> set_default_waiting_room_time()

    IO.inspect(changeset.changes, label: "Changeset changes")
    IO.inspect(changeset.errors, label: "Changeset errors")
    IO.inspect(changeset.valid?, label: "Changeset valid?")

    changeset
  end

  defp validate_scheduled_time(changeset) do
    scheduled_for = get_field(changeset, :scheduled_for)

    if scheduled_for do
      now = DateTime.utc_now()

      if DateTime.compare(scheduled_for, now) == :lt do
        add_error(changeset, :scheduled_for, "must be in the future")
      else
        changeset
      end
    else
      changeset
    end
  end

  defp set_default_waiting_room_time(changeset) do
    waiting_room_enabled = get_field(changeset, :waiting_room_enabled)
    waiting_room_open_time = get_field(changeset, :waiting_room_open_time)
    scheduled_for = get_field(changeset, :scheduled_for)

    if waiting_room_enabled && is_nil(waiting_room_open_time) && scheduled_for do
      # Default to opening waiting room 15 minutes before scheduled time
      open_time = DateTime.add(scheduled_for, -15 * 60, :second)
      # Truncate microseconds to match database precision
      truncated_open_time = DateTime.truncate(open_time, :second)
      put_change(changeset, :waiting_room_open_time, truncated_open_time)
    else
      changeset
    end
  end

  @doc """
  Updates workspace state for a session
  """
  def workspace_state_changeset(session, workspace_state) do
    session
    |> cast(%{workspace_state: workspace_state}, [:workspace_state])
  end

  @doc """
  Ends a session
  """
  def end_session_changeset(session) do
    session
    |> change(%{
      status: "ended",
      ended_at: DateTime.utc_now()
    })
  end

  @doc """
  Updates a session's recording information
  """
  def recording_changeset(session, attrs) do
    session
    |> cast(attrs, [:recording_available, :recording_url])
    |> validate_required([:recording_available])
  end
end
