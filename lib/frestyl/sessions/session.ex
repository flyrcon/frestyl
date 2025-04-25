defmodule Frestyl.Sessions.Session do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sessions" do
    field :title, :string
    field :description, :string
    field :start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :session_type, Ecto.Enum, values: [:co_working, :music_creation, :meeting, :other]
    field :status, Ecto.Enum, values: [:scheduled, :in_progress, :completed, :cancelled], default: :scheduled

    # Relations
    belongs_to :creator, Frestyl.Accounts.User
    many_to_many :participants, Frestyl.Accounts.User, join_through: "session_participants"
    many_to_many :channels, Frestyl.Channels.Channel, join_through: "session_channels"
    has_many :media_items, Frestyl.Media.MediaItem

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:title, :description, :start_time, :end_time, :session_type, :status, :creator_id])
    |> validate_required([:title, :start_time, :session_type, :creator_id])
    |> validate_session_timeframe()
  end

  defp validate_session_timeframe(changeset) do
    start_time = get_field(changeset, :start_time)
    end_time = get_field(changeset, :end_time)

    if start_time && end_time && DateTime.compare(end_time, start_time) == :lt do
      add_error(changeset, :end_time, "must be after start time")
    else
      changeset
    end
  end
end
