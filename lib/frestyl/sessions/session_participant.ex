# lib/frestyl/sessions/session_participant.ex
defmodule Frestyl.Sessions.SessionParticipant do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Sessions.Session
  alias Frestyl.Accounts.User

  schema "session_participants" do
    field :role, :string, default: "participant"
    field :status, :string, default: "waiting"
    field :joined_at, :utc_datetime
    field :left_at, :utc_datetime
    field :last_active_at, :utc_datetime
    belongs_to :session, Session
    belongs_to :user, User

    timestamps()
  end

  def changeset(participant, attrs) do
    participant
    |> cast(attrs, [:role, :status, :joined_at, :left_at, :session_id, :user_id, :last_active_at])
    |> validate_required([:session_id, :user_id])
    |> validate_inclusion(:role, ["participant", "moderator", "host", "owner"])
    |> validate_inclusion(:status, ["waiting", "active", "left", "kicked"])
    |> unique_constraint([:session_id, :user_id])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:user_id)
    |> put_join_timestamp()
    |> truncate_datetime_fields()
  end

  defp put_join_timestamp(changeset) do
    if is_nil(get_field(changeset, :joined_at)) do
      put_change(changeset, :joined_at, DateTime.truncate(DateTime.utc_now(), :second))
    else
      changeset
    end
  end

  # Helper function to truncate microseconds from all datetime fields
  defp truncate_datetime_fields(changeset) do
    changeset
    |> truncate_field(:joined_at)
    |> truncate_field(:left_at)
    |> truncate_field(:last_active_at)
  end

  defp truncate_field(changeset, field) do
    case get_change(changeset, field) do
      %DateTime{} = datetime ->
        put_change(changeset, field, DateTime.truncate(datetime, :second))
      _ ->
        changeset
    end
  end
end
