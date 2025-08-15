defmodule Frestyl.Teams.ChannelTeam do
  use Ecto.Schema
  import Ecto.Changeset
  alias Frestyl.Teams.{TeamMembership, VibeRating, TeamActivitySession}

  schema "channel_teams" do
    field :name, :string
    field :description, :string
    field :project_assignment, :string
    field :status, :string, default: "active"
    field :due_date, :utc_datetime
    field :completion_percentage, :integer, default: 0
    field :metadata, :map, default: %{}
    field :rating_config, :map

    belongs_to :channel, Frestyl.Channels.Channel
    belongs_to :supervisor, Frestyl.Accounts.User
    belongs_to :created_by, Frestyl.Accounts.User

    has_many :team_memberships, TeamMembership, foreign_key: :team_id
    has_many :members, through: [:team_memberships, :user]
    has_many :vibe_ratings, VibeRating, foreign_key: :team_id
    has_many :activity_sessions, TeamActivitySession, foreign_key: :team_id

    timestamps()
  end

  def changeset(team, attrs) do
    team
    |> cast(attrs, [:name, :description, :project_assignment, :supervisor_id,
                    :status, :due_date, :completion_percentage, :metadata, :rating_config])
    |> validate_required([:name, :channel_id, :created_by_id])
    |> validate_length(:name, min: 2, max: 100)
    |> validate_inclusion(:status, ["active", "archived", "completed"])
    |> validate_number(:completion_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:channel_id)
    |> foreign_key_constraint(:supervisor_id)
  end
end
