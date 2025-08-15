defmodule Frestyl.Teams.TeamActivitySession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "team_activity_sessions" do
    field :session_type, :string
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_minutes, :integer
    field :activity_data, :map
    field :quality_score, :float

    belongs_to :team, Frestyl.Teams.ChannelTeam
    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:session_type, :started_at, :ended_at, :duration_minutes,
                    :activity_data, :quality_score])
    |> validate_required([:team_id, :user_id, :started_at])
    |> validate_inclusion(:session_type, ["collaboration", "meeting", "individual_work"])
    |> validate_number(:duration_minutes, greater_than: 0)
    |> validate_number(:quality_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 5.0)
    |> foreign_key_constraint(:team_id)
    |> foreign_key_constraint(:user_id)
  end
end
