# lib/frestyl/live_story/narrator_collaboration.ex - CORRECTED (removed misplaced query functions)
defmodule Frestyl.LiveStory.NarratorCollaboration do
  @moduledoc """
  Multiple storytellers working together in a live story session.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "narrator_collaborations" do
    field :narrator_role, :string
    field :permissions, :map, default: %{}
    field :character_assignments, {:array, :string}, default: []
    field :active_segments, {:array, :string}, default: []
    field :contribution_stats, :map, default: %{}
    field :last_activity_at, :utc_datetime
    field :is_currently_speaking, :boolean, default: false
    field :speaking_order, :integer

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :user, User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(collaboration, attrs) do
    collaboration
    |> cast(attrs, [
      :narrator_role, :permissions, :character_assignments, :active_segments,
      :contribution_stats, :last_activity_at, :is_currently_speaking,
      :speaking_order, :live_story_session_id, :user_id
    ])
    |> validate_required([:narrator_role, :live_story_session_id, :user_id])
    |> validate_inclusion(:narrator_role, [
      "primary", "secondary", "voice_actor", "director", "moderator"
    ])
    |> validate_number(:speaking_order, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:user_id)
    |> unique_constraint([:live_story_session_id, :user_id])
  end
end
