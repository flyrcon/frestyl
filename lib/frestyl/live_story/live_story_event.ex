# lib/frestyl/live_story/live_story_event.ex
defmodule Frestyl.LiveStory.LiveStoryEvent do
  @moduledoc """
  Real-time narrative events and milestones during live story sessions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "live_story_events" do
    field :event_type, :string
    field :event_data, :map, default: %{}
    field :timestamp, :utc_datetime
    field :triggered_by, :string
    field :impact_on_story, :map, default: %{}
    field :audience_reaction, :map, default: %{}

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :narrator, User, foreign_key: :narrator_id, type: :id

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [
      :event_type, :event_data, :timestamp, :triggered_by,
      :impact_on_story, :audience_reaction, :live_story_session_id, :narrator_id
    ])
    |> validate_required([:event_type, :timestamp, :live_story_session_id])
    |> validate_inclusion(:event_type, [
      "story_beat", "choice_point", "narrator_change", "audience_milestone",
      "technical_event", "moderation_action", "special_moment"
    ])
    |> validate_inclusion(:triggered_by, [
      "audience_vote", "narrator_action", "system_event", "timer_event", "moderator_action"
    ])
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:narrator_id)
  end
end
