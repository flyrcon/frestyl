# lib/frestyl/stories.ex - Fixed get_favorite_formats function call
defmodule Frestyl.Stories do
  @moduledoc """
  The Stories context with enhanced story structure support.
  """

  import Ecto.Query, warn: false
  alias Frestyl.Repo

  alias Frestyl.Stories.EnhancedStoryStructure
  alias Frestyl.Accounts.User
  alias Frestyl.StoryEngine.{UserPreferences, QuickStartTemplates}

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
end
