# lib/frestyl/stories/story_comment.ex
defmodule Frestyl.Stories.StoryComment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_comments" do
    field :content, :string
    field :comment_type, :string, default: "general"
    field :thread_id, :binary_id
    field :position_data, :map  # For inline/positional comments
    field :resolved, :boolean, default: false
    field :resolved_at, :utc_datetime
    field :resolved_by_id, :id

    belongs_to :story, Frestyl.Stories.EnhancedStoryStructure, foreign_key: :story_id
    belongs_to :user, Frestyl.Accounts.User, foreign_key: :user_id, type: :id
    belongs_to :parent_comment, __MODULE__, foreign_key: :parent_comment_id

    has_many :replies, __MODULE__, foreign_key: :parent_comment_id

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:content, :comment_type, :thread_id, :position_data, :resolved, :resolved_at, :resolved_by_id, :story_id, :user_id, :parent_comment_id])
    |> validate_required([:content, :story_id, :user_id])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_inclusion(:comment_type, ["general", "suggestion", "correction", "praise", "question"])
  end
end
