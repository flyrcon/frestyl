# lib/frestyl/events/vote.ex
defmodule Frestyl.Events.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :score, :integer
    field :comment, :string

    belongs_to :event, Frestyl.Events.Event
    belongs_to :voter, Frestyl.Accounts.User
    belongs_to :creator, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:score, :comment, :event_id, :voter_id, :creator_id])
    |> validate_required([:score, :event_id, :voter_id, :creator_id])
    |> validate_number(:score, greater_than_or_equal_to: 1, less_than_or_equal_to: 10)
    |> foreign_key_constraint(:event_id)
    |> foreign_key_constraint(:voter_id)
    |> foreign_key_constraint(:creator_id)
    |> unique_constraint([:event_id, :voter_id, :creator_id])
  end
end
