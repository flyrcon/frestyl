# PATCH 5: Create this new file: lib/frestyl_web/live/portfolio_live/components/content_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.ContentRenderer do
  @moduledoc """
  Enhanced content rendering component that safely handles Phoenix.HTML.safe tuples
  and provides robust rendering for all portfolio section types.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [safe_to_string: 1]

  # ============================================================================
  # MAIN CONTENT RENDERING FUNCTION
  # ============================================================================

  def render_section_content_safe(section) do
    content = extract_safe_content(section.content || %{})

    case section.section_type do
      "intro" -> render_intro_content_safe(content)
      "experience" -> render_experience_content_safe(content)
      "skills" -> render_skills_content_safe(content)
      "projects" -> render_projects_content_safe(content)
      _ -> render_generic_content_safe(content)
    end
  end

  # ============================================================================
  # CONTENT EXTRACTION - SAFE HTML HANDLING
  # ============================================================================

  defp extract_safe_content(content) when is_map(content) do
    content
    |> Enum.map(fn {key, value} -> {key, extract_safe_value(value)} end)
    |> Enum.into(%{})
  end

  defp extract_safe_content(content), do: content

  defp extract_safe_value({:safe, html_content}) when is_list(html_content) do
    html_content
    |> Enum.map(&to_string/1)
    |> Enum.join("")
    |> strip_html_tags()
  end

  defp extract_safe_value({:safe, html_content}) when is_binary(html_content) do
    strip_html_tags(html_content)
  end

  defp extract_safe_value(value) when is_list(value) do
    Enum.map(value, &extract_safe_value/1)
  end

  defp extract_safe_value(value) when is_map(value) do
    extract_safe_content(value)
  end

  defp extract_safe_value(value), do: value

  defp strip_html_tags(content) when is_binary(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&\w+;/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp strip_html_tags(content), do: content

  # ============================================================================
  # SECTION TYPE RENDERERS
  # ============================================================================

  defp render_intro_content_safe(content) do
    headline = get_content_field(content, "headline", "")
    summary = get_content_field(content, "summary", "")

    case {headline, summary} do
      {"", ""} -> {:safe, "<p class='text-gray-500 italic'>No introduction content added yet.</p>"}
      {headline, ""} -> {:safe, "<h3 class='font-semibold text-gray-900'>#{Phoenix.HTML.html_escape(headline)}</h3>"}
      {"", summary} -> {:safe, "<p class='text-gray-700'>#{Phoenix.HTML.html_escape(summary)}</p>"}
      {headline, summary} ->
        {:safe, """
        <div class='space-y-2'>
          <h3 class='font-semibold text-gray-900'>#{Phoenix.HTML.html_escape(headline)}</h3>
          <p class='text-gray-700'>#{Phoenix.HTML.html_escape(summary)}</p>
        </div>
        """}
    end
  end

  defp render_experience_content_safe(content) do
    experiences = get_content_field(content, "experiences", [])

    case experiences do
      [] ->
        {:safe, "<p class='text-gray-500 italic'>No experience entries added yet.</p>"}
      experiences ->
        experience_html = experiences
        |> Enum.take(2) # Show first 2 experiences in preview
        |> Enum.map(fn exp ->
          title = get_field(exp, "title", "")
          company = get_field(exp, "company", "")
          duration = get_field(exp, "duration", "")

          """
          <div class='mb-3 p-3 bg-gray-50 rounded-lg'>
            <div class='font-medium text-gray-900'>#{Phoenix.HTML.html_escape(title)}</div>
            <div class='text-sm text-blue-600'>#{Phoenix.HTML.html_escape(company)}</div>
            <div class='text-xs text-gray-500'>#{Phoenix.HTML.html_escape(duration)}</div>
          </div>
          """
        end)
        |> Enum.join("")

        total_count = length(experiences)
        count_text = if total_count > 2, do: " (#{total_count - 2} more...)", else: ""

        {:safe, experience_html <> "<p class='text-xs text-gray-500 mt-2'>#{total_count} experience entries#{count_text}</p>"}
    end
  end

  defp render_skills_content_safe(content) do
    skill_categories = get_content_field(content, "skill_categories", %{})

    case map_size(skill_categories) do
      0 ->
        {:safe, "<p class='text-gray-500 italic'>No skills added yet.</p>"}
      _ ->
        total_skills = skill_categories
        |> Map.values()
        |> List.flatten()
        |> length()

        category_count = map_size(skill_categories)

        # Show first few skills
        sample_skills = skill_categories
        |> Map.values()
        |> List.flatten()
        |> Enum.take(4)
        |> Enum.map(fn skill ->
          name = get_field(skill, "name", "")
          proficiency = get_field(skill, "proficiency", "beginner")
          "<span class='inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-1 mb-1'>#{Phoenix.HTML.html_escape(name)} (#{Phoenix.HTML.html_escape(proficiency)})</span>"
        end)
        |> Enum.join("")

        more_text = if total_skills > 4, do: " and #{total_skills - 4} more...", else: ""

        {:safe, """
        <div class='space-y-2'>
          <div>#{sample_skills}</div>
          <p class='text-xs text-gray-500'>#{total_skills} skills across #{category_count} categories#{more_text}</p>
        </div>
        """}
    end
  end

  defp render_projects_content_safe(content) do
    projects = get_content_field(content, "projects", [])

    case projects do
      [] ->
        {:safe, "<p class='text-gray-500 italic'>No projects added yet.</p>"}
      projects ->
        project_html = projects
        |> Enum.take(2) # Show first 2 projects in preview
        |> Enum.map(fn project ->
          title = get_field(project, "title", "")
          description = get_field(project, "description", "")
          technologies = get_field(project, "technologies", [])

          tech_html = case technologies do
            [] -> ""
            techs ->
              tech_tags = techs
              |> Enum.take(3)
              |> Enum.map(&"<span class='text-xs bg-gray-200 text-gray-700 px-1 rounded'>#{Phoenix.HTML.html_escape(&1)}</span>")
              |> Enum.join(" ")
              "<div class='mt-1'>#{tech_tags}</div>"
          end

          """
          <div class='mb-3 p-3 bg-gray-50 rounded-lg'>
            <div class='font-medium text-gray-900'>#{Phoenix.HTML.html_escape(title)}</div>
            <div class='text-sm text-gray-600 mt-1'>#{Phoenix.HTML.html_escape(String.slice(description, 0, 100))}#{if String.length(description) > 100, do: "...", else: ""}</div>
            #{tech_html}
          </div>
          """
        end)
        |> Enum.join("")

        total_count = length(projects)
        count_text = if total_count > 2, do: " (#{total_count - 2} more...)", else: ""

        {:safe, project_html <> "<p class='text-xs text-gray-500 mt-2'>#{total_count} projects#{count_text}</p>"}
    end
  end

  defp render_generic_content_safe(content) do
    main_content = get_content_field(content, "main_content", "")

    case main_content do
      "" ->
        {:safe, "<p class='text-gray-500 italic'>No content added yet.</p>"}
      content ->
        # Limit preview content length
        preview_content = String.slice(content, 0, 200)
        preview_content = if String.length(content) > 200, do: preview_content <> "...", else: preview_content

        {:safe, "<p class='text-gray-700'>#{Phoenix.HTML.html_escape(preview_content)}</p>"}
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp get_content_field(content, field, default) when is_map(content) do
    Map.get(content, field, default)
  end

  defp get_content_field(_content, _field, default), do: default

  defp get_field(item, field, default) when is_map(item) do
    Map.get(item, field, default)
  end

  defp get_field(_item, _field, default), do: default
end
