# lib/frestyl/live_story/session.ex - CORRECTED
defmodule Frestyl.LiveStory.Session do
  @moduledoc """
  Schema for Live Story sessions - real-time collaborative storytelling with audience interaction.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Accounts.User
  alias Frestyl.Studio.Session, as: StudioSession

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "live_story_sessions" do
    field :title, :string
    field :description, :string
    field :story_concept, :map, default: %{}
    field :current_narrative_state, :map, default: %{}
    field :session_state, :string, default: "preparing"
    field :streaming_config, :map, default: %{}
    field :audience_interaction_settings, :map, default: %{}
    field :recording_settings, :map, default: %{}
    field :scheduled_start_time, :utc_datetime
    field :actual_start_time, :utc_datetime
    field :end_time, :utc_datetime
    field :duration_minutes, :integer, default: 0
    field :max_audience_size, :integer, default: 100
    field :is_public, :boolean, default: true
    field :archive_enabled, :boolean, default: true

    belongs_to :session, StudioSession, foreign_key: :session_id
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :id

    has_many :story_branches, Frestyl.LiveStory.StoryBranch
    has_many :audience_interactions, Frestyl.LiveStory.AudienceInteraction
    has_many :narrator_collaborations, Frestyl.LiveStory.NarratorCollaboration
    has_many :live_story_events, Frestyl.LiveStory.LiveStoryEvent
    has_many :session_archives, Frestyl.LiveStory.SessionArchive
    has_many :audience_analytics, Frestyl.LiveStory.AudienceAnalytics
    has_many :live_chat_messages, Frestyl.LiveStory.LiveChatMessage

    timestamps()
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :title, :description, :story_concept, :current_narrative_state,
      :session_state, :streaming_config, :audience_interaction_settings,
      :recording_settings, :scheduled_start_time, :actual_start_time,
      :end_time, :duration_minutes, :max_audience_size, :is_public,
      :archive_enabled, :session_id, :created_by_id
    ])
    |> validate_required([:title, :session_id, :created_by_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:session_state, [
      "preparing", "live", "paused", "ended", "cancelled"
    ])
    |> validate_number(:max_audience_size, greater_than: 0, less_than: 10000)
    |> validate_number(:duration_minutes, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:created_by_id)
  end

  # Query functions - MOVED HERE FROM NarratorCollaboration
  def for_session(query \\ __MODULE__, session_id) do
    from ls in query, where: ls.session_id == ^session_id
  end

  def for_user(query \\ __MODULE__, user_id) do
    from ls in query, where: ls.created_by_id == ^user_id
  end

  def by_state(query \\ __MODULE__, state) do
    from ls in query, where: ls.session_state == ^state
  end

  def public_sessions(query \\ __MODULE__) do
    from ls in query, where: ls.is_public == true
  end

  def scheduled_sessions(query \\ __MODULE__) do
    from ls in query, where: not is_nil(ls.scheduled_start_time)
  end

  def live_sessions(query \\ __MODULE__) do
    from ls in query, where: ls.session_state == "live"
  end
end
