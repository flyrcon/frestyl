# lib/frestyl/live_story/story_branch.ex
defmodule Frestyl.LiveStory.StoryBranch do
  @moduledoc """
  Story branches for branching narratives based on audience input.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_branches" do
    field :branch_name, :string
    field :branch_description, :string
    field :story_content, :map, default: %{}
    field :narrative_state, :map, default: %{}
    field :choice_point_data, :map, default: %{}
    field :is_active, :boolean, default: false
    field :audience_votes, :integer, default: 0
    field :selection_timestamp, :utc_datetime

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :parent_branch, __MODULE__, foreign_key: :parent_branch_id
    belongs_to :created_by_narrator, User, foreign_key: :created_by_narrator_id, type: :id

    has_many :child_branches, __MODULE__, foreign_key: :parent_branch_id
    has_many :audience_interactions, Frestyl.LiveStory.AudienceInteraction

    timestamps()
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [
      :branch_name, :branch_description, :story_content, :narrative_state,
      :choice_point_data, :is_active, :audience_votes, :selection_timestamp,
      :live_story_session_id, :parent_branch_id, :created_by_narrator_id
    ])
    |> validate_required([:branch_name, :live_story_session_id])
    |> validate_length(:branch_name, min: 1, max: 200)
    |> validate_number(:audience_votes, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:parent_branch_id)
    |> foreign_key_constraint(:created_by_narrator_id)
  end
end
