
# lib/frestyl/stories/enhanced_story_structure.ex
defmodule Frestyl.Stories.EnhancedStoryStructure do
  @moduledoc """
  Enhanced story structure schema with comprehensive story creation and collaboration support.

  This schema supports all Story Engine formats including novels, screenplays, comics,
  case studies, and experimental formats like Live Story and Narrative Beats.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Frestyl.Accounts.User
  alias Frestyl.Studio.Session

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "enhanced_story_structures" do
    # Core Story Information
    field :title, :string
    field :description, :string
    field :story_type, :string
    field :narrative_structure, :string
    field :intent_category, :string
    field :creation_source, :string, default: "direct"
    field :quick_start_template, :string

    # Content and Structure
    field :content, :map, default: %{}
    field :template_data, :map, default: %{}
    field :outline, :map, default: %{}
    field :sections, {:array, :map}, default: []

    # Story Development Data
    field :character_data, :map, default: %{}
    field :world_bible_data, :map, default: %{}
    field :timeline_data, :map, default: %{}
    field :research_data, :map, default: %{}
    field :format_metadata, :map, default: %{}

    # Format-Specific Data
    field :screenplay_formatting, :map, default: %{}
    field :comic_panels, :map, default: %{}
    field :storyboard_shots, :map, default: %{}
    field :customer_journey_data, :map, default: %{}
    field :audio_data, :map, default: %{}
    field :visual_data, :map, default: %{}

    # AI and Enhancement Features
    field :ai_suggestions, :map, default: %{active: [], history: []}
    field :ai_assistance_level, :string, default: "basic"
    field :enhancement_requests, {:array, :map}, default: []

    # Collaboration and Workflow
    field :collaboration_mode, :string, default: "owner_only"
    field :collaboration_intent, :string
    field :workflow_stage, :string, default: "development"
    field :approval_status, :string, default: "draft"
    field :collaborators, {:array, :string}, default: []
    field :permissions, :map, default: %{}
    field :comments, {:array, :map}, default: []

    # Progress and Analytics
    field :target_word_count, :integer
    field :current_word_count, :integer, default: 0
    field :completion_percentage, :float, default: 0.0
    field :progress, :integer, default: 0
    field :version, :integer, default: 1
    field :revision_history, {:array, :map}, default: []

    # Publication and Sharing
    field :is_public, :boolean, default: false
    field :is_featured, :boolean, default: false
    field :published_at, :utc_datetime
    field :archived_at, :utc_datetime

    # User Preferences and Settings
    field :user_preferences, :map, default: %{}
    field :privacy_settings, :map, default: %{}
    field :notification_settings, :map, default: %{}

    # Quality and Enhancement
    field :quality_score, :float
    field :readability_score, :float
    field :engagement_score, :float
    field :structure_score, :float

    # Media and Assets
    field :attached_media, {:array, :string}, default: []
    field :export_formats, {:array, :string}, default: []
    field :generated_assets, :map, default: %{}

    # Experimental Features (for Frestyl Originals)
    field :live_session_data, :map, default: %{}
    field :voice_sketch_data, :map, default: %{}
    field :narrative_beats_data, :map, default: %{}
    field :remix_data, :map, default: %{}

    # Performance and Caching
    field :cached_metrics, :map, default: %{}
    field :last_calculated_at, :utc_datetime

    # Relationships
    belongs_to :session, Session, foreign_key: :session_id, type: :id
    belongs_to :created_by, User, foreign_key: :created_by_id, type: :id
    belongs_to :parent_story, __MODULE__, foreign_key: :parent_story_id, type: :binary_id

    has_many :child_stories, __MODULE__, foreign_key: :parent_story_id
    has_many :story_comments, Frestyl.Stories.StoryComment, foreign_key: :story_id
    has_many :story_versions, Frestyl.Stories.StoryVersion, foreign_key: :story_id
    has_many :ai_generations, Frestyl.Stories.AIGeneration, foreign_key: :story_id

    timestamps()
  end

  @doc false
  def changeset(story_structure, attrs) do
    story_structure
    |> cast(attrs, [
      # Core fields
      :title, :description, :story_type, :narrative_structure, :intent_category,
      :creation_source, :quick_start_template,

      # Content fields
      :content, :template_data, :outline, :sections,

      # Story development
      :character_data, :world_bible_data, :timeline_data, :research_data, :format_metadata,

      # Format-specific
      :screenplay_formatting, :comic_panels, :storyboard_shots, :customer_journey_data,
      :audio_data, :visual_data,

      # AI features
      :ai_suggestions, :ai_assistance_level, :enhancement_requests,

      # Collaboration
      :collaboration_mode, :collaboration_intent, :workflow_stage, :approval_status,
      :collaborators, :permissions, :comments,

      # Progress
      :target_word_count, :current_word_count, :completion_percentage, :progress,
      :version, :revision_history,

      # Publication
      :is_public, :is_featured, :published_at, :archived_at,

      # Settings
      :user_preferences, :privacy_settings, :notification_settings,

      # Quality
      :quality_score, :readability_score, :engagement_score, :structure_score,

      # Media
      :attached_media, :export_formats, :generated_assets,

      # Experimental
      :live_session_data, :voice_sketch_data, :narrative_beats_data, :remix_data,

      # Performance
      :cached_metrics, :last_calculated_at,

      # Relationships
      :session_id, :created_by_id, :parent_story_id
    ])
    |> validate_required([:title, :story_type, :narrative_structure, :created_by_id])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_length(:description, max: 1000)
    |> validate_inclusion(:story_type, [
      # Personal & Professional
      "biography", "professional_portfolio", "article", "thought_leadership", "memoir",

      # Business & Growth
      "case_study", "marketing_story", "data_story", "customer_journey", "white_paper",

      # Creative Expression
      "novel", "screenplay", "comic_book", "song", "audiobook", "poetry",

      # Experimental (Frestyl Originals)
      "live_story", "voice_sketch", "audio_portfolio", "narrative_beats", "story_remix", "data_jam"
    ])
    |> validate_inclusion(:collaboration_mode, [
      "owner_only", "invite_only", "open", "public", "team", "department"
    ])
    |> validate_inclusion(:workflow_stage, [
      "concept", "development", "first_draft", "revision", "editing", "final", "published", "archived"
    ])
    |> validate_inclusion(:approval_status, [
      "draft", "review", "approved", "published", "archived", "rejected"
    ])
    |> validate_inclusion(:ai_assistance_level, [
      "none", "basic", "standard", "advanced", "expert"
    ])
    |> validate_number(:completion_percentage, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:current_word_count, greater_than_or_equal_to: 0)
    |> validate_number(:target_word_count, greater_than_or_equal_to: 0)
    |> validate_number(:version, greater_than_or_equal_to: 1)
    |> foreign_key_constraint(:session_id)
    |> foreign_key_constraint(:created_by_id)
    |> foreign_key_constraint(:parent_story_id)
    |> unique_constraint(:title, name: :enhanced_story_structures_title_user_index)
  end

  # ============================================================================
  # QUERY FUNCTIONS
  # ============================================================================

  @doc """
  Query stories for a specific session.
  """
  def for_session(query \\ __MODULE__, session_id) do
    from s in query, where: s.session_id == ^session_id
  end

  @doc """
  Query stories for a specific user.
  """
  def for_user(query \\ __MODULE__, user_id) do
    from s in query, where: s.created_by_id == ^user_id
  end

  @doc """
  Query public stories.
  """
  def public_stories(query \\ __MODULE__) do
    from s in query, where: s.is_public == true
  end

  @doc """
  Query stories by type.
  """
  def by_story_type(query \\ __MODULE__, story_type) do
    from s in query, where: s.story_type == ^story_type
  end

  @doc """
  Query stories by workflow stage.
  """
  def by_workflow_stage(query \\ __MODULE__, stage) do
    from s in query, where: s.workflow_stage == ^stage
  end

  @doc """
  Query completed stories (90%+ completion).
  """
  def completed_stories(query \\ __MODULE__) do
    from s in query, where: s.completion_percentage >= 90.0
  end

  @doc """
  Query stories with active collaboration.
  """
  def collaborative_stories(query \\ __MODULE__) do
    from s in query, where: s.collaboration_mode in ["open", "public", "team", "department"]
  end

  @doc """
  Query featured stories.
  """
  def featured_stories(query \\ __MODULE__) do
    from s in query, where: s.is_featured == true
  end

  @doc """
  Query stories by intent category.
  """
  def by_intent(query \\ __MODULE__, intent_category) do
    from s in query, where: s.intent_category == ^intent_category
  end

  @doc """
  Query recently updated stories.
  """
  def recently_updated(query \\ __MODULE__, limit \\ 10) do
    from s in query,
      order_by: [desc: s.updated_at],
      limit: ^limit
  end

  @doc """
  Query stories with word count range.
  """
  def with_word_count_range(query \\ __MODULE__, min_words, max_words) do
    from s in query,
      where: s.current_word_count >= ^min_words and s.current_word_count <= ^max_words
  end

  # ============================================================================
  # BUSINESS LOGIC FUNCTIONS
  # ============================================================================

  @doc """
  Creates a new enhanced story structure.
  """
  def create_enhanced_story(attrs, user, session_id \\ nil) do
    session_id = session_id || Ecto.UUID.generate()

    %__MODULE__{
      session_id: session_id,
      created_by_id: user.id
    }
    |> changeset(attrs)
    |> Ecto.Changeset.put_change(:created_by_id, user.id)
    |> Ecto.Changeset.put_change(:session_id, session_id)
  end

  @doc """
  Updates story completion percentage based on content.
  """
  def calculate_completion_percentage(%__MODULE__{} = story) do
    case story.story_type do
      "novel" -> calculate_novel_completion(story)
      "screenplay" -> calculate_screenplay_completion(story)
      "comic_book" -> calculate_comic_completion(story)
      "case_study" -> calculate_case_study_completion(story)
      _ -> calculate_general_completion(story)
    end
  end

  @doc """
  Adds AI suggestion to story.
  """
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

    changeset(story, %{ai_suggestions: updated_suggestions})
  end

  @doc """
  Accepts an AI suggestion and moves it to history.
  """
  def accept_ai_suggestion(%__MODULE__{} = story, suggestion_id) do
    current_suggestions = story.ai_suggestions || %{active: [], history: []}

    {accepted, remaining} = Enum.split_with(current_suggestions.active, fn s -> s.id == suggestion_id end)

    updated_suggestions = %{
      active: remaining,
      history: accepted ++ current_suggestions.history
    }

    changeset(story, %{ai_suggestions: updated_suggestions})
  end

  @doc """
  Updates story word count and recalculates completion.
  """
  def update_word_count(%__MODULE__{} = story, new_word_count) do
    completion = if story.target_word_count && story.target_word_count > 0 do
      min(new_word_count / story.target_word_count * 100, 100.0)
    else
      story.completion_percentage || 0.0
    end

    changeset(story, %{
      current_word_count: new_word_count,
      completion_percentage: completion
    })
  end

  @doc """
  Adds collaborator to story.
  """
  def add_collaborator(%__MODULE__{} = story, user_id, role \\ "collaborator") do
    updated_collaborators = [user_id | (story.collaborators || [])] |> Enum.uniq()

    updated_permissions = Map.put(
      story.permissions || %{},
      user_id,
      %{role: role, added_at: DateTime.utc_now()}
    )

    changeset(story, %{
      collaborators: updated_collaborators,
      permissions: updated_permissions
    })
  end

  @doc """
  Removes collaborator from story.
  """
  def remove_collaborator(%__MODULE__{} = story, user_id) do
    updated_collaborators = (story.collaborators || []) |> Enum.reject(&(&1 == user_id))
    updated_permissions = Map.delete(story.permissions || %{}, user_id)

    changeset(story, %{
      collaborators: updated_collaborators,
      permissions: updated_permissions
    })
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp calculate_novel_completion(story) do
    word_count_progress = if story.target_word_count && story.target_word_count > 0 do
      min(story.current_word_count / story.target_word_count * 100, 100.0)
    else
      0.0
    end

    character_progress = calculate_character_development_progress(story)
    plot_progress = calculate_plot_progress(story)

    # Weighted average: 60% word count, 25% character development, 15% plot structure
    (word_count_progress * 0.6 + character_progress * 0.25 + plot_progress * 0.15)
    |> Float.round(1)
  end

  defp calculate_screenplay_completion(story) do
    page_count = story.current_word_count / 250  # Rough words per page
    target_pages = case Map.get(story.format_metadata || %{}, "target_pages") do
      nil -> 90  # Default feature screenplay length
      pages -> pages
    end

    scene_progress = calculate_scene_completion(story)

    page_progress = min(page_count / target_pages * 100, 100.0)

    # Weighted: 70% page count, 30% scene structure
    (page_progress * 0.7 + scene_progress * 0.3)
    |> Float.round(1)
  end

  defp calculate_comic_completion(story) do
    panels_data = story.comic_panels || %{}
    completed_panels = Map.get(panels_data, "completed_panels", 0)
    total_panels = Map.get(panels_data, "total_panels", 22)  # Standard comic issue

    if total_panels > 0 do
      (completed_panels / total_panels * 100) |> Float.round(1)
    else
      0.0
    end
  end

  defp calculate_case_study_completion(story) do
    sections = story.sections || []
    required_sections = ["challenge", "solution", "results"]

    completed_sections = sections
    |> Enum.count(fn section ->
      section_type = Map.get(section, "type", "")
      content = Map.get(section, "content", "")
      section_type in required_sections && String.length(content) > 100
    end)

    (completed_sections / length(required_sections) * 100) |> Float.round(1)
  end

  defp calculate_general_completion(story) do
    sections = story.sections || []

    if length(sections) == 0 do
      # Use word count if no sections
      if story.current_word_count > 500 do
        50.0
      else
        story.current_word_count / 10  # 10 words = 1%
      end
    else
      completed_sections = Enum.count(sections, fn section ->
        content = Map.get(section, "content", "")
        String.length(content) > 50
      end)

      (completed_sections / length(sections) * 100) |> Float.round(1)
    end
  end

  defp calculate_character_development_progress(story) do
    character_data = story.character_data || %{}
    main_characters = Map.get(character_data, "main_characters", [])

    if length(main_characters) == 0 do
      0.0
    else
      developed_characters = Enum.count(main_characters, fn char ->
        Map.has_key?(char, "backstory") && Map.has_key?(char, "motivation")
      end)

      (developed_characters / length(main_characters) * 100) |> Float.round(1)
    end
  end

  defp calculate_plot_progress(story) do
    outline = story.outline || %{}
    plot_points = Map.get(outline, "plot_points", [])

    if length(plot_points) == 0 do
      0.0
    else
      completed_points = Enum.count(plot_points, fn point ->
        Map.get(point, "completed", false)
      end)

      (completed_points / length(plot_points) * 100) |> Float.round(1)
    end
  end

  defp calculate_scene_completion(story) do
    screenplay_data = story.screenplay_formatting || %{}
    scenes = Map.get(screenplay_data, "scenes", [])

    if length(scenes) == 0 do
      0.0
    else
      completed_scenes = Enum.count(scenes, fn scene ->
        content = Map.get(scene, "content", "")
        String.length(content) > 100
      end)

      (completed_scenes / length(scenes) * 100) |> Float.round(1)
    end
  end
end
