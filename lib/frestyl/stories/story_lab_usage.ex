defmodule Frestyl.Stories.StoryLabUsage do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :id, autogenerate: true}
  @foreign_key_type :id

  schema "story_lab_usage" do
    belongs_to :user, Frestyl.Accounts.User

    field :stories_created, :integer, default: 0
    field :chapters_created, :integer, default: 0
    field :recording_minutes_used, :integer, default: 0
    field :last_story_created_at, :utc_datetime
    field :feature_usage, :map, default: %{}

    timestamps()
  end

  def changeset(usage, attrs) do
    usage
    |> cast(attrs, [:stories_created, :chapters_created, :recording_minutes_used,
                   :last_story_created_at, :feature_usage])
    |> validate_required([:user_id])
    |> validate_number(:stories_created, greater_than_or_equal_to: 0)
    |> validate_number(:chapters_created, greater_than_or_equal_to: 0)
    |> validate_number(:recording_minutes_used, greater_than_or_equal_to: 0)
  end
end
