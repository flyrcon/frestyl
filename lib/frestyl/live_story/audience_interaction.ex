# lib/frestyl/live_story/audience_interaction.ex
defmodule Frestyl.LiveStory.AudienceInteraction do
  @moduledoc """
  Audience interactions including votes, comments, suggestions, and reactions.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "audience_interactions" do
    field :interaction_type, :string
    field :content, :string
    field :interaction_data, :map, default: %{}
    field :timestamp, :utc_datetime
    field :is_anonymous, :boolean, default: false
    field :user_identifier, :string
    field :weight, :float, default: 1.0
    field :is_processed, :boolean, default: false

    belongs_to :live_story_session, Frestyl.LiveStory.Session
    belongs_to :story_branch, Frestyl.LiveStory.StoryBranch
    belongs_to :user, User, foreign_key: :user_id, type: :id

    timestamps()
  end

  def changeset(interaction, attrs) do
    interaction
    |> cast(attrs, [
      :interaction_type, :content, :interaction_data, :timestamp,
      :is_anonymous, :user_identifier, :weight, :is_processed,
      :live_story_session_id, :story_branch_id, :user_id
    ])
    |> validate_required([:interaction_type, :timestamp, :live_story_session_id])
    |> validate_inclusion(:interaction_type, ["vote", "comment", "suggestion", "reaction", "poll_response"])
    |> validate_number(:weight, greater_than: 0.0, less_than_or_equal_to: 10.0)
    |> validate_anonymous_or_user()
    |> foreign_key_constraint(:live_story_session_id)
    |> foreign_key_constraint(:story_branch_id)
    |> foreign_key_constraint(:user_id)
  end

  defp validate_anonymous_or_user(changeset) do
    is_anonymous = get_field(changeset, :is_anonymous)
    user_id = get_field(changeset, :user_id)
    user_identifier = get_field(changeset, :user_identifier)

    cond do
      is_anonymous and is_nil(user_identifier) ->
        add_error(changeset, :user_identifier, "required for anonymous users")

      not is_anonymous and is_nil(user_id) ->
        add_error(changeset, :user_id, "required for registered users")

      true ->
        changeset
    end
  end
end
