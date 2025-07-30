# lib/frestyl/sessions/session.ex
defmodule Frestyl.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query
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
    field :workspace_state, :map, default: %{}
    field :visibility, :string, default: "public"  # public, private, unlisted
    field :allow_audience_participation, :boolean, default: true
    field :actual_duration, :integer        # in minutes

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

  def studio_changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :session_type, :enhancement_context, :creator_id, :host_id, :is_public])
    |> validate_required([:title, :session_type, :creator_id])
    |> validate_inclusion(:session_type, ["portfolio_enhancement", "collaboration", "broadcast"])
    |> put_change(:status, "active")
  end

  @doc """
  Changeset for broadcast creation and updates.
  """
  def broadcast_changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :session_type, :broadcast_type, :visibility,
      :scheduled_for, :allow_audience_participation, :max_participants,
      :channel_id, :creator_id, :host_id, :status
    ])
    |> validate_required([:title, :session_type, :channel_id, :creator_id])
    |> validate_inclusion(:session_type, ["broadcast"])
    |> validate_inclusion(:broadcast_type, [
      "live_audio", "podcast", "talk_show", "interview",
      "music_performance", "educational", "gaming"
    ])
    |> validate_inclusion(:visibility, ["public", "private", "unlisted"])
    |> validate_inclusion(:status, ["scheduled", "active", "ended", "cancelled"])
    |> validate_number(:max_participants, greater_than: 0)
    |> validate_future_date()
    |> set_host_defaults()
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:creator_id)
    |> foreign_key_constraint(:host_id)
  end

  # ============================================================================
  # ADD VALIDATION HELPERS
  # ============================================================================

  defp validate_future_date(%Ecto.Changeset{valid?: true} = changeset) do
    case get_change(changeset, :scheduled_for) do
      nil -> changeset
      scheduled_time ->
        if DateTime.compare(scheduled_time, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, :scheduled_for, "must be in the future")
        end
    end
  end

  defp validate_future_date(changeset), do: changeset

  defp set_host_defaults(%Ecto.Changeset{valid?: true} = changeset) do
    # Set host_id to creator_id if not specified
    case get_change(changeset, :host_id) do
      nil ->
        creator_id = get_change(changeset, :creator_id) || get_field(changeset, :creator_id)
        if creator_id, do: put_change(changeset, :host_id, creator_id), else: changeset
      _ -> changeset
    end
  end

  defp set_host_defaults(changeset), do: changeset

  # ============================================================================
  # ADD BROADCAST STATUS HELPERS
  # ============================================================================

  @doc """
  Checks if session is a broadcast.
  """
  def is_broadcast?(%__MODULE__{session_type: "broadcast"}), do: true
  def is_broadcast?(_), do: false

  @doc """
  Checks if broadcast is currently live.
  """
  def is_live?(%__MODULE__{session_type: "broadcast", status: "active"}), do: true
  def is_live?(_), do: false

  @doc """
  Checks if broadcast is scheduled for the future.
  """
  def is_scheduled?(%__MODULE__{session_type: "broadcast", status: "scheduled", scheduled_for: scheduled_for})
    when not is_nil(scheduled_for) do
    DateTime.compare(scheduled_for, DateTime.utc_now()) == :gt
  end
  def is_scheduled?(_), do: false

  @doc """
  Gets broadcast duration in minutes.
  """
  def get_duration(%__MODULE__{started_at: started_at, ended_at: ended_at})
    when not is_nil(started_at) and not is_nil(ended_at) do
    DateTime.diff(ended_at, started_at, :second) |> div(60)
  end

  def get_duration(%__MODULE__{started_at: started_at}) when not is_nil(started_at) do
    DateTime.diff(DateTime.utc_now(), started_at, :second) |> div(60)
  end

  def get_duration(_), do: 0



end
