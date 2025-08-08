# lib/frestyl/live_story/audience_analytics.ex
defmodule Frestyl.LiveStory.AudienceAnalytics do
  @moduledoc """
  Engagement and participation metrics for audience members.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audience_analytics" do
    field :user_identifier, :string
    field :session_duration, :integer
    field :interaction_count, :integer, default: 0
    field :votes_cast, :integer, default: 0
    field :comments_made, :integer, default: 0
    field :engagement_score, :float, default: 0.0
    field :join_timestamp, :utc_datetime
    field :leave_timestamp, :utc_datetime
    field :device_info, :map, default: %{}
    field :referral_source, :string

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :user, User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(analytics, attrs) do
    analytics
    |> cast(attrs, [
      :user_identifier, :session_duration, :interaction_count, :votes_cast,
      :comments_made, :engagement_score, :join_timestamp, :leave_timestamp,
      :device_info, :referral_source, :live_story_session_id, :user_id
    ])
    |> validate_required([:join_timestamp, :live_story_session_id])
    |> validate_number(:session_duration, greater_than_or_equal_to: 0)
    |> validate_number(:interaction_count, greater_than_or_equal_to: 0)
    |> validate_number(:votes_cast, greater_than_or_equal_to: 0)
    |> validate_number(:comments_made, greater_than_or_equal_to: 0)
    |> validate_number(:engagement_score, greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0)
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:user_id)
  end
end
