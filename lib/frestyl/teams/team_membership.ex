defmodule Frestyl.Teams.TeamMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "team_memberships" do
    field :role, :string, default: "member"
    field :status, :string, default: "active"
    field :joined_at, :utc_datetime
    field :participation_score, :float, default: 0.0
    field :contribution_tokens, :integer, default: 0

    belongs_to :team, Frestyl.Teams.ChannelTeam
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :assigned_by, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(membership, attrs) do
    membership
    |> cast(attrs, [:role, :status, :joined_at, :participation_score, :contribution_tokens])
    |> validate_required([:team_id, :user_id])
    |> validate_inclusion(:role, ["member", "team_lead"])
    |> validate_inclusion(:status, ["active", "inactive", "removed"])
    |> validate_number(:participation_score, greater_than_or_equal_to: 0.0)
    |> validate_number(:contribution_tokens, greater_than_or_equal_to: 0)
    |> unique_constraint([:team_id, :user_id])
  end
end
