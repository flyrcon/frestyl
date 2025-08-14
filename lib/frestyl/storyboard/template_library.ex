# lib/frestyl/storyboard/template_library.ex
defmodule Frestyl.Storyboard.TemplateLibrary do
  @moduledoc """
  Manages storyboard templates for quick panel creation and standardized layouts.
  """

  import Ecto.Query, warn: false
  alias Frestyl.{Repo}
  alias Frestyl.Storyboard.StoryboardTemplate

  @doc """
  Lists all available templates, optionally filtered by category.
  """
  def list_templates(category \\ nil) do
    base_query = from(t in StoryboardTemplate,
      where: t.is_public == true,
      order_by: [asc: t.category, asc: t.name]
    )

    query = case category do
      nil -> base_query
      category -> from(t in base_query, where: t.category == ^category)
    end

    Repo.all(query)
  end

  @doc """
  Gets a template by ID.
  """
  def get_template(template_id) do
    Repo.get(StoryboardTemplate, template_id)
  end

  @doc """
  Gets templates by category.
  """
  def get_templates_by_category(category) do
    from(t in StoryboardTemplate,
      where: t.category == ^category and t.is_public == true,
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  @doc """
  Creates a new custom template.
  """
  def create_template(attrs, user_id) do
    template_attrs = Map.put(attrs, :created_by, user_id)

    %StoryboardTemplate{}
    |> StoryboardTemplate.changeset(template_attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an existing template.
  """
  def update_template(template, attrs) do
    template
    |> StoryboardTemplate.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a template.
  """
  def delete_template(template) do
    Repo.delete(template)
  end

  @doc """
  Gets template categories with counts.
  """
  def get_template_categories do
    from(t in StoryboardTemplate,
      where: t.is_public == true,
      group_by: t.category,
      select: {t.category, count(t.id)},
      order_by: [asc: t.category]
    )
    |> Repo.all()
    |> Enum.map(fn {category, count} ->
      %{
        name: category,
        display_name: format_category_name(category),
        count: count,
        description: get_category_description(category)
      }
    end)
  end

  @doc """
  Creates a template from an existing panel.
  """
  def create_template_from_panel(panel, template_attrs, user_id) do
    attrs = %{
      name: template_attrs["name"],
      description: template_attrs["description"],
      category: template_attrs["category"] || "custom",
      default_width: panel.canvas_data["width"],
      default_height: panel.canvas_data["height"],
      canvas_data: panel.canvas_data,
      is_public: Map.get(template_attrs, "is_public", false),
      created_by: user_id
    }

    create_template(attrs, user_id)
  end

  @doc """
  Gets user's custom templates.
  """
  def get_user_templates(user_id) do
    from(t in StoryboardTemplate,
      where: t.created_by == ^user_id,
      order_by: [desc: t.updated_at]
    )
    |> Repo.all()
  end

  @doc """
  Gets popular templates based on usage.
  """
  def get_popular_templates(limit \\ 10) do
    # This would track usage in a real implementation
    # For now, return basic templates
    from(t in StoryboardTemplate,
      where: t.is_public == true and t.category in ["basic", "comic", "film"],
      order_by: [asc: t.name],
      limit: ^limit
    )
    |> Repo.all()
  end

  @doc """
  Searches templates by name or description.
  """
  def search_templates(search_term) do
    search_pattern = "%#{search_term}%"

    from(t in StoryboardTemplate,
      where: t.is_public == true and
             (ilike(t.name, ^search_pattern) or ilike(t.description, ^search_pattern)),
      order_by: [asc: t.name]
    )
    |> Repo.all()
  end

  @doc """
  Gets recommended templates for a story type.
  """
  def get_recommended_templates(story_type) do
    category = map_story_type_to_category(story_type)

    base_templates = get_templates_by_category(category)
    fallback_templates = get_templates_by_category("basic")

    # Combine and dedupe
    (base_templates ++ fallback_templates)
    |> Enum.uniq_by(& &1.id)
    |> Enum.take(6)
  end

  # ============================================================================
  # Private Helper Functions
  # ============================================================================

  defp format_category_name(category) do
    case category do
      "basic" -> "Basic Templates"
      "comic" -> "Comic Book"
      "film" -> "Film & Video"
      "character" -> "Character Design"
      "mobile" -> "Mobile Optimized"
      "custom" -> "Custom Templates"
      _ -> String.capitalize(category)
    end
  end

  defp get_category_description(category) do
    case category do
      "basic" -> "Simple layouts for general storyboarding"
      "comic" -> "Comic book and graphic novel panels"
      "film" -> "Film, animation, and video storyboards"
      "character" -> "Character development and design sheets"
      "mobile" -> "Optimized for mobile device creation"
      "custom" -> "User-created custom templates"
      _ -> "Templates for #{category} projects"
    end
  end

  defp map_story_type_to_category(story_type) do
    case story_type do
      "screenplay" -> "film"
      "voice_sketch" -> "film"
      "live_story" -> "film"
      "comic_book" -> "comic"
      "graphic_novel" -> "comic"
      "character_development" -> "character"
      _ -> "basic"
    end
  end
end
