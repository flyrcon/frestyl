# lib/frestyl/sessions/session_participant.ex
defmodule Frestyl.Sessions.SessionParticipant do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Sessions.Session
  alias Frestyl.Accounts.User

  schema "session_participants" do
    field :role, :string, default: "participant"
    field :joined_at, :utc_datetime
    field :last_active_at, :utc_datetime

    belongs_to :session, Session
    belongs_to :user, User

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:session_id, :user_id, :role, :joined_at, :left_at])
    |> validate_required([:session_id, :user_id, :role])
    |> validate_inclusion(:role, ["participant", "moderator", "host", "owner"])
    |> unique_constraint([:session_id, :user_id])
  end

  defp put_join_timestamp(changeset) do
    if is_nil(get_field(changeset, :joined_at)) do
      put_change(changeset, :joined_at, DateTime.utc_now())
    else
      changeset
    end
  end

end
