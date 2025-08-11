# lib/frestyl/stories.ex - Fixed get_favorite_formats function call
defmodule Frestyl.Stories do
  @moduledoc """
  The Stories context with enhanced story structure support.
  """

  import Ecto.Query, warn: false

  alias Frestyl.Stories.{Collaboration, EnhancedStoryStructure}
  alias Frestyl.Accounts.User
  alias Frestyl.StoryEngine.{CollaborationModes, UserPreferences, QuickStartTemplates}
  alias Frestyl.Features.TierManager
  alias Frestyl.{Channels, Repo, Sessions}

  # ============================================================================
  # ENHANCED STORY STRUCTURE FUNCTIONS
  # ============================================================================

  @doc """
  Returns the list of enhanced story structures for a user.
  """
  def list_user_stories(user_id, opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)
    story_type = Keyword.get(opts, :story_type)
    intent = Keyword.get(opts, :intent)

    query = EnhancedStoryStructure
    |> EnhancedStoryStructure.for_user(user_id)
    |> order_by([s], desc: s.updated_at)
    |> limit(^limit)

    query = if story_type do
      EnhancedStoryStructure.by_story_type(query, story_type)
    else
      query
    end

    query = if intent do
      EnhancedStoryStructure.by_intent(query, intent)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Gets a single enhanced story structure.
  """
  def get_enhanced_story!(id), do: Repo.get!(EnhancedStoryStructure, id)

  @doc """
  Gets a single enhanced story structure with user access check.
  """
  def get_user_story!(user_id, story_id) do
    EnhancedStoryStructure
    |> EnhancedStoryStructure.for_user(user_id)
    |> Repo.get!(story_id)
  end

  @doc """
  Creates an enhanced story structure.
  """
  def create_enhanced_story(attrs, user, session_id \\ nil) do
    # Generate session_id if not provided
    session_id = session_id || Ecto.UUID.generate()

    # Get template if quick_start_template is specified
    template = case Map.get(attrs, "quick_start_template") do
      nil -> nil
      template_key ->
        [format, intent] = String.split(template_key, "_", parts: 2)
        QuickStartTemplates.get_template(format, intent)
    end

    # Merge template data if available
    enhanced_attrs = case template do
      nil -> attrs
      template -> Map.merge(attrs, %{"template_data" => template})
    end

    # Calculate initial completion percentage
    initial_completion = calculate_initial_completion(enhanced_attrs)

    # Create the story structure
    result = %EnhancedStoryStructure{
      session_id: session_id,
      created_by_id: user.id
    }
    |> EnhancedStoryStructure.changeset(Map.put(enhanced_attrs, "completion_percentage", initial_completion))
    |> Repo.insert()

    case result do
      {:ok, story} ->
        # Track user preferences
        if Map.has_key?(enhanced_attrs, "intent_category") do
          UserPreferences.track_format_usage(
            user.id,
            enhanced_attrs["story_type"],
            enhanced_attrs["intent_category"]
          )
        end

        # Broadcast story creation
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "user_stories:#{user.id}",
          {:story_created, story}
        )

        {:ok, story}

      error -> error
    end
  end

  @doc """
  Updates an enhanced story structure.
  """
  def update_enhanced_story(%EnhancedStoryStructure{} = story, attrs) do
    # Recalculate completion if content changed
    updated_attrs = if Map.has_key?(attrs, "content") || Map.has_key?(attrs, "sections") do
      completion = EnhancedStoryStructure.calculate_completion_percentage(
        struct(story, Enum.into(attrs, %{}, fn {k, v} -> {String.to_atom(k), v} end))
      )
      Map.put(attrs, "completion_percentage", completion)
    else
      attrs
    end

    result = story
    |> EnhancedStoryStructure.changeset(updated_attrs)
    |> Repo.update()

    case result do
      {:ok, updated_story} ->
        # Broadcast update
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "user_stories:#{story.created_by_id}",
          {:story_updated, updated_story}
        )

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Deletes an enhanced story structure.
  """
  def delete_enhanced_story(%EnhancedStoryStructure{} = story) do
    result = Repo.delete(story)

    case result do
      {:ok, deleted_story} ->
        # Broadcast deletion
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "user_stories:#{story.created_by_id}",
          {:story_deleted, deleted_story}
        )

        {:ok, deleted_story}

      error -> error
    end
  end

    @doc """
  Creates a story with automatic session management for collaboration features.
  This replaces the existing create_story_for_engine/2 function.
  """
  def create_story_with_collaboration_support(story_params, user, opts \\ []) do
    collaboration_requested = Keyword.get(opts, :collaboration, false)
    audio_features_requested = Keyword.get(opts, :audio_features, false)

    # Determine if we need a session for this story type
    story_type = Map.get(story_params, "story_type", "novel")
    needs_session = should_create_session?(story_type, collaboration_requested, audio_features_requested)

    # Create the story first
    case create_enhanced_story(story_params, user) do
      {:ok, story} ->
        if needs_session do
          case create_writing_session_for_story(story, user) do
            {:ok, session} ->
              # Link story to session
              case update_enhanced_story(story, %{"session_id" => session.id}) do
                {:ok, updated_story} ->
                  {:ok, updated_story, session}
                {:error, reason} ->
                  # Clean up session if story update fails
                  Sessions.delete_session(session.id)
                  {:error, reason}
              end

            {:error, reason} ->
              {:error, "Failed to create collaboration session: #{reason}"}
          end
        else
          {:ok, story, nil}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Determines if a story needs an active session for collaboration/audio features.
  """
  def should_create_session?(story_type, collaboration_requested \\ false, audio_features_requested \\ false) do
    cond do
      # Explicit requests
      collaboration_requested -> true
      audio_features_requested -> true

      # Frestyl Originals always need sessions
      CollaborationModes.requires_active_session?(story_type) -> true

      # Traditional story types only need sessions when requested
      true -> false
    end
  end

  @doc """
  Creates a writing session specifically for story collaboration.
  """
  def create_writing_session_for_story(story, user) do
    # Get or create personal workspace
    case Channels.get_or_create_personal_workspace(user) do
      {:ok, workspace} ->
        collaboration_mode = CollaborationModes.get_collaboration_mode(story.story_type)

        session_attrs = %{
          "title" => "Writing: #{story.title}",
          "session_type" => "regular",
          "channel_id" => workspace.id,
          "creator_id" => user.id,
          "collaboration_mode" => collaboration_mode.session_type || "story_development",
          "metadata" => %{
            "story_id" => story.id,
            "story_type" => story.story_type,
            "collaboration_features" => collaboration_mode.primary_tools || [],
            "audio_features" => collaboration_mode.audio_features || [],
            "created_for" => "story_collaboration"
          }
        }

        Sessions.create_session(session_attrs)

      {:error, reason} ->
        {:error, "Failed to create workspace: #{reason}"}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking enhanced story structure changes.
  """
  def change_enhanced_story(%EnhancedStoryStructure{} = story, attrs \\ %{}) do
    EnhancedStoryStructure.changeset(story, attrs)
  end

  # ============================================================================
  # COLLABORATION FUNCTIONS
  # ============================================================================

  @doc """
  Adds a collaborator to a story.
  """
  def add_story_collaborator(%EnhancedStoryStructure{} = story, user_id, role \\ "collaborator") do
    changeset = EnhancedStoryStructure.add_collaborator(story, user_id, role)

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast collaboration change
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "story_collaboration:#{story.id}",
          {:collaborator_added, updated_story, user_id, role}
        )

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Removes a collaborator from a story.
  """
  def remove_story_collaborator(%EnhancedStoryStructure{} = story, user_id) do
    changeset = EnhancedStoryStructure.remove_collaborator(story, user_id)

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast collaboration change
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "story_collaboration:#{story.id}",
          {:collaborator_removed, updated_story, user_id}
        )

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Gets stories where user is a collaborator.
  """
  def list_collaborative_stories(user_id) do
    from(s in EnhancedStoryStructure,
      where: ^user_id in s.collaborators or s.collaboration_mode in ["open", "public"],
      order_by: [desc: s.updated_at]
    )
    |> Repo.all()
  end

    @doc """
  Detects if collaboration is currently active for a story.
  """
  def collaboration_active?(story) do
    case story.session_id do
      nil -> false
      session_id ->
        case Sessions.get_participants_count(session_id) do
          count when count > 1 -> true
          _ -> false
        end
    end
  end

  @doc """
  Enables collaboration for an existing story.
  """
  def enable_story_collaboration(story, user) do
    case story.session_id do
      nil ->
        # Create new session
        case create_writing_session_for_story(story, user) do
          {:ok, session} ->
            case update_enhanced_story(story, %{
              "session_id" => session.id,
              "collaboration_mode" => "collaborative"
            }) do
              {:ok, updated_story} -> {:ok, updated_story, session}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} -> {:error, reason}
        end

      session_id ->
        # Session already exists
        case Sessions.get_session(session_id) do
          nil -> {:error, "Session not found"}
          session -> {:ok, story, session}
        end
    end
  end

  @doc """
  Disables collaboration for a story (ends session but preserves story).
  """
  def disable_story_collaboration(story) do
    case story.session_id do
      nil -> {:ok, story}
      session_id ->
        # End the session
        case Sessions.end_session(session_id) do
          :ok ->
            case update_enhanced_story(story, %{
              "session_id" => nil,
              "collaboration_mode" => "owner_only"
            }) do
              {:ok, updated_story} -> {:ok, updated_story}
              {:error, reason} -> {:error, reason}
            end

          {:error, reason} -> {:error, reason}
        end
    end
  end

    # ============================================================================
  # VOICE NOTES INTEGRATION
  # ============================================================================

  @doc """
  Gets voice notes for a story, optionally filtered by section.
  """
  def get_story_voice_notes(story_id, section_id \\ nil) do
    base_query = from(vn in "voice_notes",
      where: vn.story_id == ^story_id,
      order_by: [desc: vn.created_at]
    )

    query = if section_id do
      from(vn in base_query, where: vn.section_id == ^section_id)
    else
      base_query
    end

    Repo.all(query)
  end

  @doc """
  Creates a voice note for a story section.
  """
  def create_voice_note(attrs) do
    %{
      id: Ecto.UUID.generate(),
      story_id: attrs.story_id,
      section_id: attrs.section_id,
      user_id: attrs.user_id,
      audio_file_path: attrs.audio_file_path,
      duration_seconds: attrs.duration_seconds,
      transcription: attrs.transcription,
      metadata: attrs.metadata || %{},
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
    |> then(fn voice_note ->
      # Insert into database (would need proper Ecto schema)
      # For now, store in story metadata
      case get_enhanced_story(attrs.story_id) do
        nil -> {:error, "Story not found"}
        story ->
          current_voice_notes = Map.get(story, :voice_notes_data, [])
          updated_voice_notes = [voice_note | current_voice_notes]

          update_enhanced_story(story, %{"voice_notes_data" => updated_voice_notes})
      end
    end)
  end

  # ============================================================================
  # COLLABORATION DETECTION HELPERS
  # ============================================================================

  @doc """
  Gets active collaborators for a story session.
  """
  def get_story_collaborators(story) do
    case story.session_id do
      nil -> []
      session_id ->
        Sessions.get_session_participants(session_id)
        |> Enum.map(&get_user_basic_info/1)
    end
  end

  @doc """
  Checks if a user can collaborate on a story.
  """
  def can_collaborate_on_story?(story, user) do
    cond do
      story.created_by_id == user.id -> true
      story.collaboration_mode == "open" -> true
      story.collaboration_mode == "public" -> true
      user.id in (story.collaborators || []) -> true
      true -> false
    end
  end

  defp get_user_basic_info(user_id) do
    # Would fetch from Accounts context
    %{
      id: user_id,
      username: "User #{user_id}",  # Placeholder
      avatar_url: nil
    }
  end

  # ============================================================================
  # ENHANCED STORY ENGINE INTEGRATION
  # ============================================================================

  @doc """
  Updated story creation for Story Engine Hub with session support.
  """
  def create_story_for_engine_with_sessions(story_params, user) do
    # Determine collaboration needs from story type and intent
    story_type = Map.get(story_params, "story_type")
    intent_category = Map.get(story_params, "intent_category")

    collaboration_needed = story_type in ["live_story", "voice_sketch", "audio_portfolio", "data_jam", "story_remix", "narrative_beats"]
    audio_features_needed = story_type in ["voice_sketch", "audio_portfolio", "narrative_beats"] or
                           intent_category in ["entertain", "audio_focused"]

    create_story_with_collaboration_support(story_params, user, [
      collaboration: collaboration_needed,
      audio_features: audio_features_needed
    ])
  end

  # ============================================================================
  # AI INTEGRATION FUNCTIONS
  # ============================================================================

  @doc """
  Adds an AI suggestion to a story.
  """
  def add_ai_suggestion(%EnhancedStoryStructure{} = story, suggestion_type, content) do
    changeset = EnhancedStoryStructure.add_ai_suggestion(story, suggestion_type, content)

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast AI suggestion
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "story_ai:#{story.id}",
          {:ai_suggestion_added, updated_story, suggestion_type, content}
        )

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Accepts an AI suggestion.
  """
  def accept_ai_suggestion(%EnhancedStoryStructure{} = story, suggestion_id) do
    changeset = EnhancedStoryStructure.accept_ai_suggestion(story, suggestion_id)

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast AI suggestion acceptance
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "story_ai:#{story.id}",
          {:ai_suggestion_accepted, updated_story, suggestion_id}
        )

        {:ok, updated_story}

      error -> error
    end
  end

  # ============================================================================
  # ANALYTICS AND INSIGHTS
  # ============================================================================

  @doc """
  Gets story statistics for a user.
  """
  def get_user_story_stats(user_id) do
    base_query = EnhancedStoryStructure.for_user(EnhancedStoryStructure, user_id)

    %{
      total_stories: get_total_stories(base_query),
      completed_stories: get_completed_stories(base_query),
      active_collaborations: get_active_collaborations(base_query),
      words_written: get_total_words(base_query),
      favorite_formats: get_favorite_formats(user_id),  # This line was the issue
      avg_completion_rate: get_avg_completion_rate(base_query),
      stories_this_month: get_stories_this_month(base_query)
    }
  end

  @doc """
  Gets public stories with optional filtering.
  """
  def list_public_stories(opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    story_type = Keyword.get(opts, :story_type)
    featured_only = Keyword.get(opts, :featured_only, false)

    query = from(s in EnhancedStoryStructure)
    |> EnhancedStoryStructure.public_stories()
    |> order_by([s], desc: s.updated_at)
    |> limit(^limit)

    query = if story_type do
      EnhancedStoryStructure.by_story_type(query, story_type)
    else
      query
    end

    query = if featured_only do
      EnhancedStoryStructure.featured_stories(query)
    else
      query
    end

    Repo.all(query)
  end

  @doc """
  Searches stories by title or content.
  """
  def search_stories(search_term, user_id \\ nil) do
    query = from(s in EnhancedStoryStructure,
      where: ilike(s.title, ^"%#{search_term}%") or
             fragment("? @> ?", s.content, ^"%#{search_term}%"),
      order_by: [desc: s.updated_at]
    )

    query = if user_id do
      where(query, [s], s.created_by_id == ^user_id or s.is_public == true)
    else
      EnhancedStoryStructure.public_stories(query)
    end

    Repo.all(query)
  end

  # ============================================================================
  # STORY EXPORT AND SHARING
  # ============================================================================

  @doc """
  Exports a story in a specific format.
  """
  def export_story(%EnhancedStoryStructure{} = story, format) do
    case format do
      "markdown" -> export_to_markdown(story)
      "pdf" -> export_to_pdf(story)
      "docx" -> export_to_docx(story)
      "html" -> export_to_html(story)
      "json" -> export_to_json(story)
      _ -> {:error, "Unsupported export format"}
    end
  end

  @doc """
  Creates a story remix/version.
  """
  def create_story_remix(%EnhancedStoryStructure{} = original_story, user, remix_attrs \\ %{}) do
    remix_data = %{
      "original_story_id" => original_story.id,
      "remix_type" => Map.get(remix_attrs, "remix_type", "adaptation"),
      "changes_made" => Map.get(remix_attrs, "changes_made", []),
      "attribution" => %{
        "original_author" => original_story.created_by_id,
        "original_title" => original_story.title,
        "remix_date" => DateTime.utc_now()
      }
    }

    attrs = %{
      "title" => "#{original_story.title} (Remix)",
      "story_type" => original_story.story_type,
      "narrative_structure" => original_story.narrative_structure,
      "intent_category" => original_story.intent_category,
      "template_data" => original_story.template_data,
      "content" => original_story.content,
      "parent_story_id" => original_story.id,
      "remix_data" => remix_data,
      "creation_source" => "story_remix"
    }

    create_enhanced_story(attrs, user)
  end

  # ============================================================================
  # PRIVATE HELPER FUNCTIONS
  # ============================================================================

  defp calculate_initial_completion(attrs) do
    story_type = Map.get(attrs, "story_type", "article")
    content = Map.get(attrs, "content", %{})
    sections = Map.get(attrs, "sections", [])

    cond do
      map_size(content) > 0 || length(sections) > 0 -> 10.0
      true -> 0.0
    end
  end

  defp get_total_stories(query) do
    Repo.aggregate(query, :count)
  end

  defp get_completed_stories(query) do
    query
    |> where([s], s.completion_percentage >= 90.0)
    |> Repo.aggregate(:count)
  end

  defp get_active_collaborations(query) do
    query
    |> where([s], s.collaboration_mode in ["open", "public", "team", "department"])
    |> Repo.aggregate(:count)
  end

  defp get_total_words(query) do
    query
    |> select([s], sum(s.current_word_count))
    |> Repo.one() || 0
  end

  # FIXED: Make this function public or call it differently
  defp get_favorite_formats(user_id) do
    from(s in EnhancedStoryStructure,
      where: s.created_by_id == ^user_id,
      group_by: s.story_type,
      select: {s.story_type, count(s.id)},
      order_by: [desc: count(s.id)],
      limit: 3
    )
    |> Repo.all()
  end

  defp get_avg_completion_rate(query) do
    case Repo.aggregate(query, :avg, :completion_percentage) do
      nil -> 0.0
      rate -> Float.round(rate, 1)
    end
  end

  defp get_stories_this_month(query) do
    start_of_month = DateTime.utc_now() |> DateTime.beginning_of_month()

    query
    |> where([s], s.inserted_at >= ^start_of_month)
    |> Repo.aggregate(:count)
  end

  # Export helper functions
  defp export_to_markdown(story) do
    content = """
    # #{story.title}

    #{story.description || ""}

    #{format_story_content_as_markdown(story)}
    """

    {:ok, content}
  end

  defp export_to_html(story) do
    content = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>#{story.title}</title>
        <meta charset="UTF-8">
        <style>
            body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
            h1 { color: #333; border-bottom: 2px solid #eee; }
            .meta { color: #666; font-style: italic; margin-bottom: 20px; }
        </style>
    </head>
    <body>
        <h1>#{story.title}</h1>
        <div class="meta">
            Story Type: #{story.story_type} |
            Created: #{DateTime.to_date(story.inserted_at)} |
            Completion: #{story.completion_percentage}%
        </div>
        #{format_story_content_as_html(story)}
    </body>
    </html>
    """

    {:ok, content}
  end

  defp export_to_json(story) do
    data = %{
      id: story.id,
      title: story.title,
      description: story.description,
      story_type: story.story_type,
      narrative_structure: story.narrative_structure,
      content: story.content,
      sections: story.sections,
      completion_percentage: story.completion_percentage,
      word_count: story.current_word_count,
      created_at: story.inserted_at,
      updated_at: story.updated_at
    }

    {:ok, Jason.encode!(data, pretty: true)}
  end

  defp export_to_pdf(_story) do
    # PDF export would require a PDF library like PuppeteerPDF or similar
    {:error, "PDF export requires additional setup"}
  end

  defp export_to_docx(_story) do
    # DOCX export would require a Word document library
    {:error, "DOCX export requires additional setup"}
  end

  defp format_story_content_as_markdown(story) do
    case story.sections do
      [] ->
        # Use content map if no sections
        story.content
        |> Map.values()
        |> Enum.join("\n\n")

      sections ->
        sections
        |> Enum.map(fn section ->
          title = Map.get(section, "title", "Section")
          content = Map.get(section, "content", "")
          "## #{title}\n\n#{content}"
        end)
        |> Enum.join("\n\n")
    end
  end

  defp format_story_content_as_html(story) do
    case story.sections do
      [] ->
        # Use content map if no sections
        story.content
        |> Map.values()
        |> Enum.map(&"<p>#{&1}</p>")
        |> Enum.join("\n")

      sections ->
        sections
        |> Enum.map(fn section ->
          title = Map.get(section, "title", "Section")
          content = Map.get(section, "content", "")
          "<h2>#{title}</h2>\n<p>#{content}</p>"
        end)
        |> Enum.join("\n")
    end
  end

    # ============================================================================
  # EDITOR SUPPORT FUNCTIONS
  # ============================================================================

  @doc """
  Get story template with error handling
  """
  defp get_story_template(story_type, intent) do
    try do
      case QuickStartTemplates.get_template(story_type, intent) do
        nil -> get_default_template(story_type)
        template -> template
      end
    rescue
      UndefinedFunctionError ->
        get_default_template(story_type)
    end
  end

  @doc """
  Get format configuration with error handling
  """
  defp get_format_configuration(story_type) do
    try do
      FormatManager.get_format_config(story_type)
    rescue
      UndefinedFunctionError ->
        %{
          editor_mode: "standard",
          export_formats: ["pdf", "html"],
          ai_assistance: true
        }
    end
  end

  defp get_default_template(story_type) do
    %{
      title: get_default_story_title(story_type),
      outline: %{},
      character_data: %{},
      initial_sections: []
    }
  end

  defp build_section_metadata(section, story_type) do
    base_metadata = %{
      word_target: Map.get(section, :word_target),
      page_target: Map.get(section, :page_target),
      seo_target: Map.get(section, :seo_target)
    }

    format_metadata = case story_type do
      "screenplay" -> %{
        scene_type: "int_day",
        characters: []
      }
      "blog_series" -> %{
        seo_keywords: [],
        readability_target: "grade_8"
      }
      _ -> %{}
    end

    Map.merge(base_metadata, format_metadata)
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end

  # Default content helpers
  defp get_default_section_title(story_type) do
    case story_type do
      "novel" -> "Chapter 1"
      "screenplay" -> "Scene 1"
      "case_study" -> "Executive Summary"
      "blog_series" -> "Introduction"
      _ -> "Section 1"
    end
  end

  defp get_default_section_type(story_type) do
    case story_type do
      "novel" -> "chapter"
      "screenplay" -> "scene"
      "case_study" -> "section"
      "blog_series" -> "post"
      _ -> "section"
    end
  end

  defp get_default_section_content(story_type) do
    case story_type do
      "novel" ->
        "Once upon a time...\n\nBegin your novel here. Use the character panel to develop your protagonists."

      "screenplay" ->
        "FADE IN:\n\nEXT. LOCATION - DAY\n\nYour screenplay begins here."

      "case_study" ->
        "Executive Summary\n\nProvide a compelling overview of your findings and recommendations."

      "blog_series" ->
        "Introduction\n\nHook your readers with an engaging opening that previews the value they'll get from this series."

      _ ->
        "Start writing here...\n\nUse the tools in the sidebar to organize your thoughts."
    end
  end

  defp get_default_story_title(story_type) do
    case story_type do
      "novel" -> "Untitled Novel"
      "screenplay" -> "Untitled Screenplay"
      "case_study" -> "New Case Study"
      "blog_series" -> "New Blog Series"
      _ -> "New Story"
    end
  end

  @doc """
  Get enhanced story with permissions, including editor state
  """
  def get_enhanced_story_with_permissions(story_id, user_id) do
    case get_enhanced_story(story_id) do
      nil ->
        {:error, :not_found}

      story ->
        permissions = calculate_user_permissions(story, user_id)

        case permissions.can_view do
          true ->
            # Load editor state if available
            editor_state = load_editor_state(story)
            story_with_state = Map.put(story, :editor_state, editor_state)
            {:ok, story_with_state, permissions}

          false ->
            {:error, :access_denied}
        end
    end
  end

  @doc """
  Load editor state from story preferences
  """
  defp load_editor_state(story) do
    case story.editor_preferences do
      nil -> %{}
      preferences when is_map(preferences) -> preferences
      _ -> %{}
    end
  end

  @doc """
  Update story with format-specific validation
  """
  def update_story_with_format_validation(story, attrs) do
    # Apply format-specific validation rules
    validated_attrs = apply_format_validation(story.story_type, attrs)

    changeset = EnhancedStoryStructure.changeset(story, validated_attrs)

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Trigger format-specific post-update actions
        handle_format_specific_updates(updated_story, attrs)

        # Broadcast update
        Phoenix.PubSub.broadcast(Frestyl.PubSub, "story:#{story.id}",
          {:story_updated, updated_story})

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Calculate user permissions for a story
  """
  def calculate_user_permissions(story, user_id) do
    cond do
      story.created_by_id == user_id ->
        owner_permissions()

      is_collaborator?(story, user_id) ->
        get_collaborator_permissions(story, user_id)

      story.is_public ->
        public_permissions()

      true ->
        no_permissions()
    end
  end

  @doc """
  Update a specific section of a story
  """
  def update_story_section(story_id, section_id, content) do
    story = get_enhanced_story!(story_id)
    section_id_int = String.to_integer(section_id)

    updated_sections = Enum.map(story.sections, fn section ->
      if section.id == section_id_int do
        %{section | content: content, updated_at: DateTime.utc_now()}
      else
        section
      end
    end)

    changeset = EnhancedStoryStructure.changeset(story, %{
      sections: updated_sections,
      current_word_count: calculate_total_word_count(updated_sections)
    })

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast to collaborators
        Phoenix.PubSub.broadcast(Frestyl.PubSub, "story_collaboration:#{story_id}",
          {:section_updated, section_id, content})

        {:ok, updated_story}

      error -> error
    end
  end

  def update_story_editor_preferences(story, preferences) do
    changeset = EnhancedStoryStructure.changeset(story, %{
      editor_preferences: preferences,
      updated_at: DateTime.utc_now()
    })

    case Repo.update(changeset) do
      {:ok, updated_story} ->
        # Broadcast preferences update
        Phoenix.PubSub.broadcast(Frestyl.PubSub, "story:#{story.id}",
          {:preferences_updated, preferences})

        {:ok, updated_story}

      error -> error
    end
  end

  @doc """
  Export story in specified format
  """
  def export_story(story, format) do
    case format do
      "pdf" -> export_to_pdf(story)
      "html" -> export_to_html(story)
      "epub" -> export_to_epub(story)
      "docx" -> export_to_docx(story)
      "fdx" -> export_to_final_draft(story)
      "fountain" -> export_to_fountain(story)
      "mp3" -> export_to_audio(story)
      _ -> {:error, "Unsupported export format"}
    end
  end

  @doc """
  Create story from Story Engine with proper initialization
  """
def create_story_for_engine(attrs, user) when is_map(attrs) do
  case Repo.transaction(fn ->
    try do
      # Create a Studio Session for the story
      session_attrs = %{
        "title" => "Story Creation: #{Map.get(attrs, :title, "Untitled Story")}",
        "session_type" => "regular",  # Changed from "story_creation" to "regular"
        "creator_id" => user.id,
        "status" => "active",
        "channel_id" => get_default_channel_for_user(user.id)  # Add required channel_id
      }

      case Frestyl.Sessions.create_session(session_attrs) do
        {:ok, session} ->
          # Rest of your story creation code...
          story_attrs = attrs
          |> Map.put(:session_id, session.id)
          |> Map.put(:sections, build_initial_sections(attrs.initial_section_config || %{}, attrs.story_type))
          |> Map.put(:outline, %{})
          |> Map.put(:character_data, %{})
          |> Map.put(:format_metadata, attrs.format_metadata || %{})
          |> Map.put(:editor_preferences, attrs.editor_preferences || %{})
          |> Map.put(:collaboration_mode, attrs.collaboration_mode || "owner_only")
          |> Map.put(:workflow_stage, "first_draft")
          |> Map.put(:narrative_structure, get_default_narrative_structure(attrs.story_type))
          |> Map.put(:completion_percentage, 0.0)
          |> Map.put(:current_word_count, 0)

          changeset = EnhancedStoryStructure.changeset(%EnhancedStoryStructure{}, story_attrs)
          |> Ecto.Changeset.put_change(:created_by_id, user.id)

          case Repo.insert(changeset) do
            {:ok, story} ->
              story
            {:error, changeset} ->
              Repo.rollback(changeset)
          end

        {:error, session_changeset} ->
          Repo.rollback(session_changeset)
      end

    rescue
      error ->
        Repo.rollback(error)
    end
  end) do
    {:ok, story} -> {:ok, story}
    {:error, reason} -> {:error, reason}
  end
end

# Add this helper function
defp get_default_channel_for_user(user_id) do
  # You'll need to either:
  # 1. Get the user's default/personal channel
  # 2. Or create a default channel for story creation
  # For now, let's try to get their first channel or create a default one

  case Frestyl.Channels.get_user_default_channel(user_id) do
    nil ->
      # Create a default personal channel for the user
      {:ok, channel} = Frestyl.Channels.create_personal_channel(user_id)
      channel.id
    channel ->
      channel.id
  end
end

  defp get_default_narrative_structure(story_type) do
    case story_type do
      "novel" -> "three_act"
      "screenplay" -> "three_act"
      "case_study" -> "business_case"
      "blog_series" -> "series"
      _ -> "standard"
    end
  end

  # ============================================================================
  # PERMISSION HELPERS
  # ============================================================================

  defp owner_permissions do
    %{
      can_view: true,
      can_edit: true,
      can_delete: true,
      can_invite: true,
      can_export: true,
      can_publish: true,
      can_use_ai: true,
      can_use_voice: true,
      can_manage_settings: true
    }
  end

  defp get_collaborator_permissions(story, user_id) do
    collaboration = get_user_collaboration(story.id, user_id)

    base_permissions = %{
      can_view: true,
      can_edit: collaboration.permissions.can_edit || false,
      can_delete: collaboration.permissions.can_delete || false,
      can_invite: collaboration.permissions.can_invite || false,
      can_export: collaboration.permissions.can_export || false,
      can_publish: false,
      can_use_ai: collaboration.permissions.can_use_ai || false,
      can_use_voice: collaboration.permissions.can_use_voice || false,
      can_manage_settings: false
    }

    # Apply tier-based restrictions
    apply_tier_restrictions(base_permissions, collaboration.user_tier)
  end

  defp public_permissions do
    %{
      can_view: true,
      can_edit: false,
      can_delete: false,
      can_invite: false,
      can_export: false,
      can_publish: false,
      can_use_ai: false,
      can_use_voice: false,
      can_manage_settings: false
    }
  end

  defp no_permissions do
    %{
      can_view: false,
      can_edit: false,
      can_delete: false,
      can_invite: false,
      can_export: false,
      can_publish: false,
      can_use_ai: false,
      can_use_voice: false,
      can_manage_settings: false
    }
  end

  defp apply_tier_restrictions(permissions, user_tier) do
    case user_tier do
      "personal" ->
        permissions
        |> Map.put(:can_use_ai, false)
        |> Map.put(:can_use_voice, false)
        |> Map.put(:can_export, false)

      "creator" ->
        permissions

      "professional" ->
        permissions

      _ ->
        permissions
        |> Map.put(:can_use_ai, false)
        |> Map.put(:can_use_voice, false)
    end
  end

  defp build_initial_sections(section_config, story_type) do
    case section_config do
      %{sections: sections} when is_list(sections) ->
        sections
        |> Enum.with_index()
        |> Enum.map(fn {section, index} ->
          %{
            id: index + 1,
            title: section.title,
            type: section.type,
            content: section.placeholder || "",
            order: section.order || index + 1,
            word_count: 0,
            created_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now(),
            metadata: build_section_metadata(section, story_type)
          }
        end)

      _ ->
        # Default single section
        [%{
          id: 1,
          title: get_default_section_title(story_type),
          type: get_default_section_type(story_type),
          content: get_default_section_content(story_type),
          order: 1,
          word_count: 0,
          created_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          metadata: %{}
        }]
    end
  end


  # ============================================================================
  # EXPORT FUNCTIONS
  # ============================================================================

  defp export_to_pdf(story) do
    # Generate PDF using a library like PuppeteerPdf or wkhtmltopdf
    html_content = render_story_as_html(story)

    case generate_pdf_from_html(html_content) do
      {:ok, pdf_path} ->
        {:ok, pdf_path}
      error -> error
    end
  end

  defp export_to_html(story) do
    html_content = render_story_as_html(story)
    file_path = "/tmp/story_#{story.id}_#{DateTime.utc_now() |> DateTime.to_unix()}.html"

    case File.write(file_path, html_content) do
      :ok -> {:ok, file_path}
      error -> error
    end
  end

  defp export_to_epub(story) do
    # Generate EPUB using a library
    # This would involve creating the EPUB structure with metadata, chapters, etc.
    {:error, "EPUB export not yet implemented"}
  end

  defp export_to_final_draft(story) do
    if story.story_type == "screenplay" do
      fdx_content = render_story_as_fdx(story)
      file_path = "/tmp/story_#{story.id}.fdx"

      case File.write(file_path, fdx_content) do
        :ok -> {:ok, file_path}
        error -> error
      end
    else
      {:error, "Final Draft export only available for screenplays"}
    end
  end

  defp export_to_fountain(story) do
    if story.story_type == "screenplay" do
      fountain_content = render_story_as_fountain(story)
      file_path = "/tmp/story_#{story.id}.fountain"

      case File.write(file_path, fountain_content) do
        :ok -> {:ok, file_path}
        error -> error
      end
    else
      {:error, "Fountain export only available for screenplays"}
    end
  end

  defp export_to_docx(story) do
    # Generate DOCX using a library
    {:error, "DOCX export not yet implemented"}
  end

  defp export_to_audio(story) do
    # Text-to-speech conversion
    {:error, "Audio export not yet implemented"}
  end

  @doc """
  Initialize format-specific features after story creation
  """
  defp initialize_format_features(story, format, intent) do
    case format do
      "novel" ->
        initialize_novel_features(story, intent)
      "screenplay" ->
        initialize_screenplay_features(story, intent)
      "case_study" ->
        initialize_case_study_features(story, intent)
      "blog_series" ->
        initialize_blog_features(story, intent)
      _ ->
        :ok
    end
  end

  defp initialize_novel_features(story, _intent) do
    # Initialize character tracking
    Characters.initialize_for_story(story.id)

    # Initialize plot tracking
    PlotTracker.initialize_for_story(story.id)

    # Set up three-act structure outline
    Outline.create_default_structure(story.id, "three_act")
  end

  defp initialize_screenplay_features(story, _intent) do
    # Initialize scene breakdown
    SceneBreakdown.initialize_for_story(story.id)

    # Set up screenplay formatting rules
    FormattingRules.apply_screenplay_rules(story.id)

    # Initialize character list
    Characters.initialize_screenplay_characters(story.id)
  end

  defp initialize_case_study_features(story, _intent) do
    # Initialize stakeholder tracking
    Stakeholders.initialize_for_story(story.id)

    # Set up business case structure
    BusinessStructure.initialize_case_study(story.id)

    # Initialize data panel
    DataPanel.initialize_for_story(story.id)
  end

  defp initialize_blog_features(story, _intent) do
    # Initialize SEO tracking
    SEOTracker.initialize_for_story(story.id)

    # Set up publishing workflow
    PublishingWorkflow.initialize_for_story(story.id)

    # Initialize social media preview
    SocialPreview.initialize_for_story(story.id)
  end

  # ============================================================================
  # TEMPLATE AND RENDERING FUNCTIONS
  # ============================================================================

  defp get_story_template(story_type, narrative_structure) do
    case story_type do
      "novel" ->
        %{
          initial_sections: [
            %{
              id: 1,
              type: "chapter",
              title: "Chapter 1",
              content: "",
              order: 1
            }
          ],
          outline: %{
            items: [
              %{title: "Opening Hook", description: "Grab the reader's attention"},
              %{title: "Character Introduction", description: "Introduce your protagonist"},
              %{title: "Inciting Incident", description: "The event that starts the story"},
              %{title: "Rising Action", description: "Build tension and conflict"},
              %{title: "Climax", description: "The story's turning point"},
              %{title: "Resolution", description: "Tie up loose ends"}
            ]
          },
          character_data: %{
            characters: []
          }
        }

      "screenplay" ->
        %{
          initial_sections: [
            %{
              id: 1,
              type: "scene",
              title: "Scene 1",
              content: "FADE IN:\n\nEXT. LOCATION - DAY\n\n",
              order: 1
            }
          ],
          outline: %{
            items: [
              %{title: "Act I - Setup", description: "Establish world and characters (25%)"},
              %{title: "Plot Point 1", description: "Inciting incident"},
              %{title: "Act II - Confrontation", description: "Rising action (50%)"},
              %{title: "Midpoint", description: "Major revelation or setback"},
              %{title: "Plot Point 2", description: "All seems lost"},
              %{title: "Act III - Resolution", description: "Climax and resolution (25%)"}
            ]
          },
          character_data: %{
            characters: []
          },
          format_metadata: %{
            screenplay_format: "feature",
            page_count_target: 120
          }
        }

      "case_study" ->
        %{
          initial_sections: [
            %{
              id: 1,
              type: "overview",
              title: "Executive Summary",
              content: "",
              order: 1
            },
            %{
              id: 2,
              type: "problem",
              title: "Problem Statement",
              content: "",
              order: 2
            }
          ],
          outline: %{
            items: [
              %{title: "Executive Summary", description: "Key findings and recommendations"},
              %{title: "Problem Statement", description: "Define the challenge"},
              %{title: "Solution Approach", description: "How you addressed it"},
              %{title: "Results & Impact", description: "Measurable outcomes"},
              %{title: "Lessons Learned", description: "Key takeaways"},
              %{title: "Next Steps", description: "Future recommendations"}
            ]
          },
          format_metadata: %{
            stakeholders: [],
            metrics: []
          }
        }

      _ ->
        %{
          initial_sections: [
            %{
              id: 1,
              type: "section",
              title: "Getting Started",
              content: "",
              order: 1
            }
          ],
          outline: %{items: []},
          character_data: %{}
        }
    end
  end

  defp render_story_as_html(story) do
    sections_html = Enum.map(story.sections, fn section ->
      "<section class='story-section'>" <>
      "<h2>#{section.title}</h2>" <>
      "<div class='content'>#{section.content}</div>" <>
      "</section>"
    end) |> Enum.join("\n")

    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>#{story.title}</title>
      <style>
        body { font-family: serif; max-width: 800px; margin: 0 auto; padding: 20px; }
        .story-section { margin-bottom: 2em; }
        h1, h2 { color: #333; }
      </style>
    </head>
    <body>
      <h1>#{story.title}</h1>
      #{sections_html}
    </body>
    </html>
    """
  end

  defp render_story_as_fdx(story) do
    # Final Draft XML format
    # This would be a more complex implementation
    "<?xml version='1.0' encoding='UTF-8'?><FinalDraft>...</FinalDraft>"
  end

  defp render_story_as_fountain(story) do
    # Fountain format for screenplays
    story.sections
    |> Enum.map(& &1.content)
    |> Enum.join("\n\n")
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp is_collaborator?(story, user_id) do
    user_id in (story.collaborators || [])
  end

  defp get_user_collaboration(story_id, user_id) do
    # This would fetch from your collaboration table
    Collaboration.get_by_story_and_user(story_id, user_id)
  end

  defp calculate_total_word_count(sections) do
    sections
    |> Enum.map(fn section ->
      (section.content || "")
      |> String.replace(~r/<[^>]*>/, "")  # Strip HTML
      |> String.split()
      |> length()
    end)
    |> Enum.sum()
  end

  defp setup_initial_collaboration(story, collaboration_type, user) do
    # Initialize collaboration based on type
    case collaboration_type do
      "small_team" ->
        Collaboration.create_collaboration_setup(story.id, %{
          max_collaborators: 5,
          permissions: %{can_edit: true, can_comment: true}
        })

      "writing_group" ->
        Collaboration.create_collaboration_setup(story.id, %{
          max_collaborators: 10,
          permissions: %{can_edit: true, can_comment: true, can_suggest: true}
        })

      _ -> :ok
    end
  end

  defp generate_pdf_from_html(html_content) do
    # This would use a PDF generation library
    # For now, return a placeholder
    {:ok, "/tmp/placeholder.pdf"}
  end

  # Add missing functions that are referenced
  def get_enhanced_story(story_id) do
    Repo.get(EnhancedStoryStructure, story_id)
  end

  def get_enhanced_story!(story_id) do
    Repo.get!(EnhancedStoryStructure, story_id)
  end

  defp apply_format_validation(story_type, attrs) do
    case story_type do
      "screenplay" ->
        # Validate screenplay formatting
        validate_screenplay_formatting(attrs)

      "case_study" ->
        # Validate business case structure
        validate_case_study_structure(attrs)

      "blog_series" ->
        # Validate SEO requirements
        validate_blog_seo_requirements(attrs)

      _ ->
        attrs
    end
  end

  defp validate_screenplay_formatting(attrs) do
    # Apply screenplay-specific validation
    # This would include scene heading validation, character name formatting, etc.
    attrs
  end

  defp validate_case_study_structure(attrs) do
    # Validate required sections for case studies
    # This would ensure executive summary, problem statement, etc. are present
    attrs
  end

  defp validate_blog_seo_requirements(attrs) do
    # Validate SEO requirements for blog posts
    # This would check meta descriptions, keyword density, etc.
    attrs
  end

  defp handle_format_specific_updates(story, attrs) do
    case story.story_type do
      "screenplay" ->
        # Update scene breakdown if content changed
        if Map.has_key?(attrs, :sections) do
          SceneBreakdown.update_from_content(story.id, attrs.sections)
        end

      "blog_series" ->
        # Update SEO analysis if content changed
        if Map.has_key?(attrs, :sections) do
          SEOTracker.analyze_content(story.id, attrs.sections)
        end

      _ ->
        :ok
    end
  end

end
