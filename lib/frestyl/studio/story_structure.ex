# lib/frestyl/studio/story_structure.ex
defmodule Frestyl.Studio.StoryStructure do
  @moduledoc """
  Schema for managing story structures, outlines, and collaborative storytelling data.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Studio.Session
  alias Frestyl.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_structures" do
    field :title, :string
    field :template_type, :string
    field :outline_data, :map
    field :characters_data, :map
    field :world_bible_data, :map
    field :timeline_data, :map
    field :is_public, :boolean, default: true
    field :collaboration_mode, :string, default: "open"
    field :version, :integer, default: 1

    belongs_to :session, Session
    belongs_to :created_by, User

    has_many :story_comments, Frestyl.Studio.StoryComment, foreign_key: :story_structure_id
    has_many :story_versions, Frestyl.Studio.StoryVersion, foreign_key: :story_structure_id

    timestamps()
  end

  @doc false
  def changeset(story_structure, attrs) do
    story_structure
    |> cast(attrs, [
      :title, :template_type, :outline_data, :characters_data,
      :world_bible_data, :timeline_data, :is_public, :collaboration_mode,
      :session_id, :created_by_id
    ])
    |> validate_required([:title, :session_id, :created_by_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:template_type, [
      "three_act", "heros_journey", "seven_point", "custom"
    ])
    |> validate_inclusion(:collaboration_mode, [
      "open", "invite_only", "view_only", "owner_only"
    ])
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:created_by_id)
  end

  # Query Functions

  def for_session(query \\ __MODULE__, session_id) do
    from s in query, where: s.session_id == ^session_id
  end

  def for_user(query \\ __MODULE__, user_id) do
    from s in query, where: s.created_by_id == ^user_id
  end

  def public_stories(query \\ __MODULE__) do
    from s in query, where: s.is_public == true
  end

  def by_template(query \\ __MODULE__, template_type) do
    from s in query, where: s.template_type == ^template_type
  end

  # Business Logic Functions

  def create_story_structure(attrs, %User{} = user, session_id) do
    %__MODULE__{
      session_id: session_id,
      created_by_id: user.id,
      outline_data: %{template: "three_act", sections: []},
      characters_data: %{characters: [], relationships: []},
      world_bible_data: %{},
      timeline_data: %{events: [], chronology: []}
    }
    |> changeset(attrs)
    |> Frestyl.Repo.insert()
  end

  def update_outline(%__MODULE__{} = story_structure, outline_data) do
    story_structure
    |> changeset(%{
      outline_data: outline_data,
      version: story_structure.version + 1
    })
    |> Frestyl.Repo.update()
  end

  def update_characters(%__MODULE__{} = story_structure, characters_data) do
    story_structure
    |> changeset(%{
      characters_data: characters_data,
      version: story_structure.version + 1
    })
    |> Frestyl.Repo.update()
  end

  def update_world_bible(%__MODULE__{} = story_structure, world_bible_data) do
    story_structure
    |> changeset(%{
      world_bible_data: world_bible_data,
      version: story_structure.version + 1
    })
    |> Frestyl.Repo.update()
  end

  def add_collaborator_permission(%__MODULE__{} = story_structure, user_id, permission_level) do
    # This would integrate with your existing permissions system
    # For now, we'll just update the collaboration_mode if needed
    story_structure
  end

  def get_story_for_session(session_id) do
    __MODULE__
    |> for_session(session_id)
    |> Frestyl.Repo.one()
  end

  def get_story_with_preloads(story_id) do
    __MODULE__
    |> Frestyl.Repo.get(story_id)
    |> Frestyl.Repo.preload([:created_by, :story_comments, :story_versions])
  end
end

# lib/frestyl/studio/story_comment.ex
defmodule Frestyl.Studio.StoryComment do
  @moduledoc """
  Schema for collaborative story feedback and comments.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_comments" do
    field :content, :string
    field :comment_type, :string  # "general", "section", "character", "world"
    field :target_id, :string     # ID of the specific element being commented on
    field :target_type, :string   # "section", "character", "world_entry"
    field :position, :map         # For inline comments: {line: 1, column: 5}
    field :is_resolved, :boolean, default: false
    field :is_suggestion, :boolean, default: false
    field :suggestion_data, :map  # For suggested changes

    belongs_to :story_structure, Frestyl.Studio.StoryStructure
    belongs_to :user, Frestyl.Accounts.User
    belongs_to :reply_to, __MODULE__, foreign_key: :parent_comment_id

    has_many :replies, __MODULE__, foreign_key: :parent_comment_id

    timestamps()
  end

  def changeset(story_comment, attrs) do
    story_comment
    |> cast(attrs, [
      :content, :comment_type, :target_id, :target_type, :position,
      :is_resolved, :is_suggestion, :suggestion_data,
      :story_structure_id, :user_id, :parent_comment_id
    ])
    |> validate_required([:content, :comment_type, :story_structure_id, :user_id])
    |> validate_length(:content, min: 1, max: 2000)
    |> validate_inclusion(:comment_type, [
      "general", "section", "character", "world", "timeline"
    ])
    |> foreign_key_constraint(:story_structure_id)
    |> foreign_key_constraint(:user_id)
  end
end

# lib/frestyl/studio/story_version.ex
defmodule Frestyl.Studio.StoryVersion do
  @moduledoc """
  Schema for story version control and branching.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "story_versions" do
    field :version_number, :integer
    field :version_name, :string
    field :description, :string
    field :snapshot_data, :map
    field :changes_summary, :string
    field :is_published, :boolean, default: false
    field :is_branch, :boolean, default: false
    field :branch_name, :string

    belongs_to :story_structure, Frestyl.Studio.StoryStructure
    belongs_to :created_by, Frestyl.Accounts.User
    belongs_to :parent_version, __MODULE__, foreign_key: :parent_version_id

    timestamps()
  end

  def changeset(story_version, attrs) do
    story_version
    |> cast(attrs, [
      :version_number, :version_name, :description, :snapshot_data,
      :changes_summary, :is_published, :is_branch, :branch_name,
      :story_structure_id, :created_by_id, :parent_version_id
    ])
    |> validate_required([:version_number, :snapshot_data, :story_structure_id, :created_by_id])
    |> validate_length(:version_name, max: 100)
    |> validate_length(:description, max: 500)
    |> foreign_key_constraint(:story_structure_id)
    |> foreign_key_constraint(:created_by_id)
  end

  def create_version(%Frestyl.Studio.StoryStructure{} = story, %Frestyl.Accounts.User{} = user, attrs \\ %{}) do
    snapshot = %{
      outline_data: story.outline_data,
      characters_data: story.characters_data,
      world_bible_data: story.world_bible_data,
      timeline_data: story.timeline_data
    }

    %__MODULE__{
      story_structure_id: story.id,
      created_by_id: user.id,
      version_number: story.version,
      snapshot_data: snapshot
    }
    |> changeset(attrs)
    |> Frestyl.Repo.insert()
  end
end
