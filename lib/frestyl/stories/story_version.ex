# lib/frestyl/stories/story_version.ex
defmodule Frestyl.Stories.StoryVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_versions" do
    field :version_number, :integer
    field :title, :string
    field :content_snapshot, :map
    field :changes_summary, :string
    field :change_type, :string  # "auto_save", "manual_save", "major_revision"
    field :word_count_delta, :integer
    field :completion_delta, :float

    belongs_to :story, Frestyl.Stories.EnhancedStoryStructure, foreign_key: :story_id
    belongs_to :created_by, Frestyl.Accounts.User, foreign_key: :created_by_id, type: :id

    timestamps()
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version_number, :title, :content_snapshot, :changes_summary, :change_type, :word_count_delta, :completion_delta, :story_id, :created_by_id])
    |> validate_required([:version_number, :content_snapshot, :story_id, :created_by_id])
    |> validate_inclusion(:change_type, ["auto_save", "manual_save", "major_revision", "collaboration"])
    |> unique_constraint([:story_id, :version_number])
  end
end
