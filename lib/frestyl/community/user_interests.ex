# lib/frestyl/community/user_interests.ex - Schema for user interests
defmodule Frestyl.Community.UserInterests do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_interests" do
    field :genres, {:array, :string}, default: []
    field :sub_genres, {:array, :string}, default: []
    field :skill_levels, :map, default: %{}
    field :collaboration_preferences, {:array, :string}, default: []
    field :engagement_level, :string
    field :onboarding_completed_at, :utc_datetime

    belongs_to :user, Frestyl.Accounts.User

    timestamps()
  end

  def changeset(user_interests, attrs) do
    user_interests
    |> cast(attrs, [:user_id, :genres, :sub_genres, :skill_levels, :collaboration_preferences, :engagement_level, :onboarding_completed_at])
    |> validate_required([:user_id, :genres])
    |> validate_length(:genres, min: 1, max: 5)
    |> validate_length(:sub_genres, max: 15)
    |> validate_inclusion(:engagement_level, ["casual_interest", "active_learner", "regular_practitioner", "serious_developer", "professional_level", "expert_contributor"])
    |> unique_constraint(:user_id)
  end
end
