# lib/frestyl/stories/enhanced_story_structure.ex (corrected belongs_to)
defmodule Frestyl.Stories.EnhancedStoryStructure do
  @moduledoc """
  Enhanced story structure schema with corrected foreign key types
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Studio.Session
  alias Frestyl.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  # Don't set @foreign_key_type since we have mixed types

  schema "enhanced_story_structures" do
    field :title, :string
    field :story_type, :string
    field :narrative_structure, :string
    field :template_data, :map

    # Enhanced story development fields
    field :character_data, :map
    field :world_bible_data, :map
    field :timeline_data, :map
    field :research_data, :map
    field :ai_suggestions, :map

    # Format-specific data
    field :screenplay_formatting, :map
    field :comic_panels, :map
    field :storyboard_shots, :map
    field :customer_journey_data, :map

    # Collaboration and workflow
    field :collaboration_mode, :string, default: "open"
    field :workflow_stage, :string, default: "development"
    field :approval_status, :string, default: "draft"

    # Metadata
    field :target_word_count, :integer
    field :current_word_count, :integer, default: 0
    field :completion_percentage, :float, default: 0.0
    field :is_public, :boolean, default: false
    field :version, :integer, default: 1

    # Explicitly specify foreign key types to match your existing tables
    belongs_to :session, Session, foreign_key: :session_id, type: :id
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :id

    has_many :story_comments, Frestyl.Studio.StoryComment, foreign_key: :story_structure_id
    has_many :story_versions, Frestyl.Studio.StoryVersion, foreign_key: :story_structure_id
    has_many :ai_generations, Frestyl.Stories.AIGeneration, foreign_key: :story_id

    timestamps()
  end

  @doc false
  def changeset(story_structure, attrs) do
    story_structure
    |> cast(attrs, [
      :title, :story_type, :narrative_structure, :template_data,
      :character_data, :world_bible_data, :timeline_data, :research_data,
      :ai_suggestions, :screenplay_formatting, :comic_panels,
      :storyboard_shots, :customer_journey_data, :collaboration_mode,
      :workflow_stage, :approval_status, :target_word_count,
      :current_word_count, :completion_percentage, :is_public,
      :session_id, :created_by_id
    ])
    |> validate_required([:title, :story_type, :narrative_structure, :session_id, :created_by_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_inclusion(:story_type, [
      "personal_narrative", "professional_showcase", "case_study", "creative_portfolio",
      "novel", "screenplay", "comic_book", "customer_story", "storyboard"
    ])
    |> validate_inclusion(:collaboration_mode, [
      "open", "invite_only", "view_only", "owner_only"
    ])
    |> validate_inclusion(:workflow_stage, [
      "concept", "development", "first_draft", "revision", "editing", "final", "published"
    ])
    |> validate_inclusion(:approval_status, [
      "draft", "review", "approved", "published", "archived"
    ])
    |> validate_number(:completion_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
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

  def by_story_type(query \\ __MODULE__, story_type) do
    from s in query, where: s.story_type == ^story_type
  end

  def by_workflow_stage(query \\ __MODULE__, stage) do
    from s in query, where: s.workflow_stage == ^stage
  end

  def completed_stories(query \\ __MODULE__) do
    from s in query, where: s.completion_percentage >= 90.0
  end

  # Business Logic Functions
  def create_enhanced_story(attrs, %User{} = user, session_id) do
    template = Frestyl.Stories.EnhancedTemplates.get_template(
      attrs["story_type"] || attrs[:story_type],
      attrs["narrative_structure"] || attrs[:narrative_structure]
    )

    %__MODULE__{
      session_id: session_id,
      created_by_id: user.id,
      template_data: template,
      character_data: initialize_character_data(template),
      world_bible_data: initialize_world_data(template),
      timeline_data: %{events: [], chronology: []},
      research_data: %{sources: [], notes: []},
      ai_suggestions: %{active: [], history: []},
      target_word_count: get_target_word_count(template)
    }
    |> changeset(attrs)
    |> Frestyl.Repo.insert()
  end

  defp initialize_character_data(template) do
    case template.story_type do
      :novel -> %{
        main_characters: [],
        supporting_characters: [],
        relationships: [],
        character_arcs: [],
        voice_notes: %{}
      }
      :screenplay -> %{
        characters: [],
        dialogue_notes: %{},
        character_descriptions: %{}
      }
      :comic_book -> %{
        characters: [],
        character_designs: [],
        model_sheets: []
      }
      _ -> %{characters: []}
    end
  end

  defp initialize_world_data(template) do
    case template.story_type do
      :novel -> %{
        locations: [],
        cultures: [],
        history: [],
        rules: [],
        technology: []
      }
      :screenplay -> %{
        locations: [],
        production_notes: %{}
      }
      :comic_book -> %{
        environments: [],
        style_guides: []
      }
      _ -> %{}
    end
  end

  defp get_target_word_count(template) do
    case template.story_type do
      :novel -> 80000
      :screenplay -> 25000  # Roughly 90-120 pages
      :short_story -> 5000
      _ -> nil
    end
  end

  # AI Integration Functions
  def add_ai_suggestion(%__MODULE__{} = story, suggestion_type, content) do
    current_suggestions = story.ai_suggestions || %{active: [], history: []}

    new_suggestion = %{
      id: Ecto.UUID.generate(),
      type: suggestion_type,
      content: content,
      created_at: DateTime.utc_now(),
      status: "pending"
    }

    updated_suggestions = %{
      active: [new_suggestion | current_suggestions.active],
      history: current_suggestions.history
    }

    story
    |> changeset(%{ai_suggestions: updated_suggestions})
    |> Frestyl.Repo.update()
  end

  def accept_ai_suggestion(%__MODULE__{} = story, suggestion_id) do
    current_suggestions = story.ai_suggestions || %{active: [], history: []}

    {accepted, remaining} = Enum.split_with(current_suggestions.active, fn s -> s.id == suggestion_id end)

    updated_suggestions = %{
      active: remaining,
      history: accepted ++ current_suggestions.history
    }

    story
    |> changeset(%{ai_suggestions: updated_suggestions})
    |> Frestyl.Repo.update()
  end

  def calculate_completion_percentage(%__MODULE__{} = story) do
    case story.story_type do
      "novel" -> calculate_novel_completion(story)
      "screenplay" -> calculate_screenplay_completion(story)
      "comic_book" -> calculate_comic_completion(story)
      _ -> calculate_general_completion(story)
    end
  end

  defp calculate_novel_completion(story) do
    word_count_progress = if story.target_word_count && story.target_word_count > 0 do
      min(story.current_word_count / story.target_word_count * 80, 80)
    else
      0
    end

    character_progress = calculate_character_development_progress(story) * 0.1
    world_progress = calculate_world_building_progress(story) * 0.1

    word_count_progress + character_progress + world_progress
  end

  defp calculate_character_development_progress(story) do
    character_data = story.character_data || %{}
    main_characters = character_data["main_characters"] || []

    if length(main_characters) > 0 do
      developed_characters = Enum.count(main_characters, fn char ->
        has_backstory = Map.get(char, "backstory", "") != ""
        has_motivation = Map.get(char, "motivation", "") != ""
        has_arc = Map.get(char, "character_arc", []) != []

        has_backstory && has_motivation && has_arc
      end)

      developed_characters / length(main_characters) * 100
    else
      0
    end
  end

  defp calculate_world_building_progress(story) do
    world_data = story.world_bible_data || %{}
    locations = world_data["locations"] || []
    rules = world_data["rules"] || []

    location_score = min(length(locations) * 20, 60)
    rules_score = min(length(rules) * 10, 40)

    location_score + rules_score
  end

  defp calculate_screenplay_completion(story) do
    story.current_word_count / (story.target_word_count || 25000) * 100
  end

  defp calculate_comic_completion(story) do
    comic_data = story.comic_panels || %{}
    total_pages = comic_data["total_pages"] || 22
    completed_pages = comic_data["completed_pages"] || 0

    completed_pages / total_pages * 100
  end

  defp calculate_general_completion(story) do
    template = story.template_data || %{}
    chapters = template["chapters"] || []

    if length(chapters) > 0 do
      50.0  # Placeholder - would calculate based on actual content
    else
      0.0
    end
  end
end
