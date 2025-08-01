# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer with Frestyl design philosophy:
  - No inside borders on cards
  - Clean shadows and gradients
  - Smooth hover effects
  - Professional spacing
  - Mobile-first responsive design
  FIXED: Consistent data structure handling with fallbacks and proper error handling
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem
  import Phoenix.HTML, only: [html_escape: 1, raw: 1]

  def render(assigns) do
    ~H"""
    <div class="portfolio-section-container"
         data-section-type={@section.section_type}
         data-section-id={@section.id}>

      <!-- Section Header -->
      <div class="section-header">
        <div class="header-content">
          <div class="header-info">
            <h3 class="section-title"><%= @section.title %></h3>
          </div>

          <%= if @show_actions do %>
            <div class="header-actions">
              <button phx-click="edit_section"
                      phx-value-section_id={@section.id}
                      class="action-button edit-button">
                <svg class="button-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
              <div class="relative">
                <button phx-click="toggle_section_menu"
                        phx-value-section_id={@section.id}
                        class="action-button menu-button">
                  <svg class="button-icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Section Content (Scrollable) -->
      <div class="section-content">
        <%= render_section_content(@section, assigns) %>
      </div>

      <!-- Section Footer (if needed) -->
      <%= if has_footer_content?(@section) do %>
        <div class="section-footer">
          <%= render_section_footer(@section, assigns) %>
        </div>
      <% end %>
    </div>
    """
  end

  # FIXED: Enhanced content rendering with fallbacks and proper error handling
  def render_section_content(section, assigns) do
    content = normalize_section_content(section.content, section.section_type)

    try do
      case to_string(section.section_type) do
        "hero" -> render_hero_content(content, assigns)
        "intro" -> render_intro_content(content, assigns)
        "about" -> render_about_content(content, assigns)
        "experience" -> render_experience_content_enhanced(content, assigns)
        "work_experience" -> render_experience_content_enhanced(content, assigns)
        "education" -> render_education_content_enhanced(content, assigns)
        "skills" -> render_skills_content_enhanced(content, assigns)
        "projects" -> render_projects_content_enhanced(content, assigns)
        "portfolio" -> render_projects_content_enhanced(content, assigns)
        "contact" -> render_contact_content_enhanced(content, assigns)
        "testimonials" -> render_testimonials_content(content, assigns)
        "certifications" -> render_certifications_content(content, assigns)
        "achievements" -> render_achievements_content(content, assigns)
        _ -> render_generic_content_enhanced(content, assigns)
      end
    rescue
      error ->
        IO.puts("❌ Error rendering section #{section.section_type}: #{inspect(error)}")
        render_error_fallback(section, content)
    end
  end

  # FIXED: Normalize content to ensure consistent structure
  defp normalize_section_content(content, section_type) when is_map(content) do
    case to_string(section_type) do
      "experience" ->
        # Handle both old and new formats
        items = content["items"] || content["jobs"] || []
        Map.put(content, "items", normalize_items_list(items))

      "education" ->
        items = content["items"] || content["education"] || []
        Map.put(content, "items", normalize_items_list(items))

      "projects" ->
        items = content["items"] || content["projects"] || []
        Map.put(content, "items", normalize_items_list(items))

      "skills" ->
        # Ensure skills have proper structure
        skills = content["skills"] || content["items"] || []
        Map.merge(content, %{
          "skills" => normalize_items_list(skills),
          "display_style" => content["display_style"] || "categorized"
        })

      _ -> content
    end
  end
  defp normalize_section_content(content, _section_type), do: content || %{}

  defp normalize_items_list(items) when is_list(items), do: items
  defp normalize_items_list(_), do: []

  # FIXED: Enhanced hero content rendering
  defp render_hero_content(content, _assigns) do
    headline = Map.get(content, "headline", "")
    tagline = Map.get(content, "tagline", "")
    description = Map.get(content, "description", "")
    cta_text = Map.get(content, "cta_text", "")
    cta_link = Map.get(content, "cta_link", "")
    video_url = Map.get(content, "video_url", "")

    """
    <div class="hero-content">
      #{if headline != "", do: "<h1 class=\"hero-headline\">#{html_escape(headline)}</h1>", else: ""}
      #{if tagline != "", do: "<h2 class=\"hero-tagline\">#{html_escape(tagline)}</h2>", else: ""}
      #{if description != "", do: "<p class=\"hero-description\">#{html_escape(description)}</p>", else: ""}
      #{if video_url != "", do: render_video_embed(video_url), else: ""}
      #{if cta_text != "" and cta_link != "", do: "<a href=\"#{html_escape(cta_link)}\" class=\"hero-cta\">#{html_escape(cta_text)}</a>", else: ""}
    </div>
    """
  end

  # FIXED: Enhanced intro/about content rendering
  defp render_intro_content(content, _assigns) do
    render_about_content(content, nil)
  end

  defp render_about_content(content, _assigns) do
    story = Map.get(content, "story", Map.get(content, "content", ""))
    highlights = Map.get(content, "highlights", [])
    personality_traits = Map.get(content, "personality_traits", [])

    highlights_html = if is_list(highlights) and length(highlights) > 0 do
      highlight_items = highlights
      |> Enum.map(fn highlight -> "<li>#{html_escape(highlight)}</li>" end)
      |> Enum.join("")

      "<div class=\"about-highlights\"><h4>Highlights</h4><ul>#{highlight_items}</ul></div>"
    else
      ""
    end

    traits_html = if is_list(personality_traits) and length(personality_traits) > 0 do
      trait_items = personality_traits
      |> Enum.map(fn trait -> "<span class=\"trait-tag\">#{html_escape(trait)}</span>" end)
      |> Enum.join("")

      "<div class=\"personality-traits\"><h4>Personality</h4><div class=\"traits-container\">#{trait_items}</div></div>"
    else
      ""
    end

    """
    <div class="about-content">
      #{if story != "", do: "<div class=\"about-story\">#{html_escape(story)}</div>", else: ""}
      #{highlights_html}
      #{traits_html}
    </div>
    """
  end

  # FIXED: Enhanced experience content rendering with proper error handling
  defp render_experience_content_enhanced(content, _assigns) do
    items = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "timeline")

    cond do
      is_list(items) and length(items) > 0 ->
        render_experience_items(items, display_style)

      is_binary(content["content"]) and content["content"] != "" ->
        "<div class=\"fallback-content\">#{html_escape(content["content"])}</div>"

      true ->
        "<div class=\"empty-state\">No experience information available.</div>"
    end
  end

  defp render_experience_items(items, display_style) do
    item_html = items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> render_single_experience_item(item, index, display_style) end)
    |> Enum.join("")

    """
    <div class="experience-items experience-#{display_style}">
      #{item_html}
    </div>
    """
  end

  defp render_single_experience_item(item, index, display_style) when is_map(item) do
    title = Map.get(item, "title", Map.get(item, "position", "Position"))
    company = Map.get(item, "company", "Company")
    location = Map.get(item, "location", "")
    employment_type = Map.get(item, "employment_type", "")
    start_date = Map.get(item, "start_date", "")
    end_date = Map.get(item, "end_date", "")
    is_current = Map.get(item, "is_current", false)
    description = Map.get(item, "description", "")
    achievements = Map.get(item, "achievements", [])
    skills_used = Map.get(item, "skills_used", [])

    # Format date range
    date_range = format_date_range(start_date, end_date, is_current)

    # Format location and employment type
    location_type = [location, employment_type] |> Enum.filter(&(&1 != "")) |> Enum.join(" • ")

    # Format achievements
    achievements_html = if is_list(achievements) and length(achievements) > 0 do
      achievement_items = achievements
      |> Enum.map(fn achievement -> "<div class=\"achievement-item\">#{html_escape(achievement)}</div>" end)
      |> Enum.join("")

      "<div class=\"achievements\"><h5>Key Achievements</h5>#{achievement_items}</div>"
    else
      ""
    end

    # Format skills
    skills_html = if is_list(skills_used) and length(skills_used) > 0 do
      skill_items = skills_used
      |> Enum.map(fn skill -> "<span class=\"skill-tag\">#{html_escape(skill)}</span>" end)
      |> Enum.join("")

      "<div class=\"skills-used\"><div class=\"skills-container\">#{skill_items}</div></div>"
    else
      ""
    end

    """
    <div class="experience-item #{if index == 0, do: "first-item", else: ""}" data-index="#{index}">
      <div class="experience-header">
        <h4 class="experience-title">#{html_escape(title)}</h4>
        <div class="experience-meta">
          <span class="company">#{html_escape(company)}</span>
          #{if date_range != "", do: "<span class=\"date-range\">#{date_range}</span>", else: ""}
          #{if location_type != "", do: "<span class=\"location-type\">#{html_escape(location_type)}</span>", else: ""}
        </div>
      </div>
      #{if description != "", do: "<div class=\"experience-description\">#{html_escape(description)}</div>", else: ""}
      #{achievements_html}
      #{skills_html}
    </div>
    """
  end
  defp render_single_experience_item(_, _, _), do: ""

  # FIXED: Enhanced education content rendering
  defp render_education_content_enhanced(content, _assigns) do
    items = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "timeline")

    cond do
      is_list(items) and length(items) > 0 ->
        render_education_items(items, display_style)

      is_binary(content["content"]) and content["content"] != "" ->
        "<div class=\"fallback-content\">#{html_escape(content["content"])}</div>"

      true ->
        "<div class=\"empty-state\">No education information available.</div>"
    end
  end

  defp render_education_items(items, display_style) do
    item_html = items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> render_single_education_item(item, index, display_style) end)
    |> Enum.join("")

    """
    <div class="education-items education-#{display_style}">
      #{item_html}
    </div>
    """
  end

  defp render_single_education_item(item, index, display_style) when is_map(item) do
    degree = Map.get(item, "degree", "Degree")
    field = Map.get(item, "field", "")
    institution = Map.get(item, "institution", "Institution")
    location = Map.get(item, "location", "")
    start_date = Map.get(item, "start_date", "")
    end_date = Map.get(item, "end_date", "")
    status = Map.get(item, "status", "Completed")
    gpa = Map.get(item, "gpa", "")
    description = Map.get(item, "description", "")
    relevant_coursework = Map.get(item, "relevant_coursework", [])
    honors = Map.get(item, "honors", [])

    # Format degree and field
    degree_field = if field != "", do: "#{degree} in #{field}", else: degree

    # Format date range
    date_range = format_date_range(start_date, end_date, status == "In Progress")

    # Format coursework
    coursework_html = if is_list(relevant_coursework) and length(relevant_coursework) > 0 do
      coursework_items = relevant_coursework
      |> Enum.map(fn course -> "<span class=\"coursework-tag\">#{html_escape(course)}</span>" end)
      |> Enum.join("")

      "<div class=\"relevant-coursework\"><h5>Relevant Coursework</h5><div class=\"coursework-container\">#{coursework_items}</div></div>"
    else
      ""
    end

    # Format honors
    honors_html = if is_list(honors) and length(honors) > 0 do
      honor_items = honors
      |> Enum.map(fn honor -> "<div class=\"honor-item\">#{html_escape(honor)}</div>" end)
      |> Enum.join("")

      "<div class=\"honors\"><h5>Honors & Recognition</h5>#{honor_items}</div>"
    else
      ""
    end

    """
    <div class="education-item #{if index == 0, do: "first-item", else: ""}" data-index="#{index}">
      <div class="education-header">
        <h4 class="education-degree">#{html_escape(degree_field)}</h4>
        <div class="education-meta">
          <span class="institution">#{html_escape(institution)}</span>
          #{if location != "", do: "<span class=\"location\">#{html_escape(location)}</span>", else: ""}
          #{if date_range != "", do: "<span class=\"date-range\">#{date_range}</span>", else: ""}
          #{if gpa != "", do: "<span class=\"gpa\">GPA: #{html_escape(gpa)}</span>", else: ""}
        </div>
      </div>
      #{if description != "", do: "<div class=\"education-description\">#{html_escape(description)}</div>", else: ""}
      #{coursework_html}
      #{honors_html}
    </div>
    """
  end
  defp render_single_education_item(_, _, _), do: ""

  # FIXED: Enhanced skills content rendering
  defp render_skills_content_enhanced(content, _assigns) do
    skills = Map.get(content, "skills", [])
    categories = Map.get(content, "categories", %{})
    display_style = Map.get(content, "display_style", "categorized")

    cond do
      is_list(skills) and length(skills) > 0 ->
        render_skills_items(skills, display_style)

      is_map(categories) and map_size(categories) > 0 ->
        render_skills_categories(categories, display_style)

      is_binary(content["content"]) and content["content"] != "" ->
        "<div class=\"fallback-content\">#{html_escape(content["content"])}</div>"

      true ->
        "<div class=\"empty-state\">No skills information available.</div>"
    end
  end

  defp render_skills_items(skills, display_style) do
    case display_style do
      "categorized" ->
        # Group skills by category if they have one
        grouped_skills = skills
        |> Enum.group_by(fn skill ->
          if is_map(skill), do: Map.get(skill, "category", "Other"), else: "Other"
        end)

        render_grouped_skills(grouped_skills)

      "proficiency_bars" ->
        render_skills_with_proficiency(skills)

      _ ->
        render_skills_flat_list(skills)
    end
  end

  defp render_skills_categories(categories, _display_style) do
    category_html = categories
    |> Enum.map(fn {category_name, category_skills} ->
      if is_list(category_skills) and length(category_skills) > 0 do
        skill_items = category_skills
        |> Enum.map(fn skill ->
          skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
          "<span class=\"skill-tag\">#{html_escape(skill_name)}</span>"
        end)
        |> Enum.join("")

        """
        <div class="skill-category">
          <h4 class="category-title">#{html_escape(category_name)}</h4>
          <div class="skills-container">#{skill_items}</div>
        </div>
        """
      else
        ""
      end
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("")

    """
    <div class="skills-categorized">
      #{category_html}
    </div>
    """
  end

  defp render_grouped_skills(grouped_skills) do
    category_html = grouped_skills
    |> Enum.map(fn {category_name, category_skills} ->
      skill_items = category_skills
      |> Enum.map(fn skill ->
        skill_name = if is_map(skill), do: Map.get(skill, "name", "Skill"), else: skill
        proficiency = if is_map(skill), do: Map.get(skill, "proficiency", ""), else: ""

        proficiency_html = if proficiency != "", do: " <span class=\"proficiency\">(#{proficiency})</span>", else: ""

        "<span class=\"skill-tag\">#{html_escape(skill_name)}#{proficiency_html}</span>"
      end)
      |> Enum.join("")

      """
      <div class="skill-category">
        <h4 class="category-title">#{html_escape(category_name)}</h4>
        <div class="skills-container">#{skill_items}</div>
      </div>
      """
    end)
    |> Enum.join("")

    """
    <div class="skills-grouped">
      #{category_html}
    </div>
    """
  end

  defp render_skills_with_proficiency(skills) do
    skill_html = skills
    |> Enum.map(fn skill ->
      skill_name = if is_map(skill), do: Map.get(skill, "name", "Skill"), else: skill
      proficiency = if is_map(skill), do: Map.get(skill, "proficiency", "Intermediate"), else: "Intermediate"
      years = if is_map(skill), do: Map.get(skill, "years_experience", 0), else: 0

      proficiency_level = case proficiency do
        "Expert" -> 100
        "Advanced" -> 80
        "Intermediate" -> 60
        "Beginner" -> 40
        _ -> 60
      end

      """
      <div class="skill-proficiency-item">
        <div class="skill-info">
          <span class="skill-name">#{html_escape(skill_name)}</span>
          <span class="skill-level">#{html_escape(proficiency)}</span>
          #{if years > 0, do: "<span class=\"skill-years\">#{years} years</span>", else: ""}
        </div>
        <div class="proficiency-bar">
          <div class="proficiency-fill" style="width: #{proficiency_level}%"></div>
        </div>
      </div>
      """
    end)
    |> Enum.join("")

    """
    <div class="skills-proficiency">
      #{skill_html}
    </div>
    """
  end

  defp render_skills_flat_list(skills) do
    skill_items = skills
    |> Enum.map(fn skill ->
      skill_name = if is_map(skill), do: Map.get(skill, "name", "Skill"), else: skill
      "<span class=\"skill-tag\">#{html_escape(skill_name)}</span>"
    end)
    |> Enum.join("")

    """
    <div class="skills-flat">
      <div class="skills-container">#{skill_items}</div>
    </div>
    """
  end

  # FIXED: Enhanced projects content rendering
  defp render_projects_content_enhanced(content, _assigns) do
    items = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "grid")

    cond do
      is_list(items) and length(items) > 0 ->
        render_project_items(items, display_style)

      is_binary(content["content"]) and content["content"] != "" ->
        "<div class=\"fallback-content\">#{html_escape(content["content"])}</div>"

      true ->
        "<div class=\"empty-state\">No projects available.</div>"
    end
  end

  defp render_project_items(items, display_style) do
    item_html = items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} -> render_single_project_item(item, index, display_style) end)
    |> Enum.join("")

    """
    <div class="project-items project-#{display_style}">
      #{item_html}
    </div>
    """
  end

  defp render_single_project_item(item, index, display_style) when is_map(item) do
    title = Map.get(item, "title", "Project")
    description = Map.get(item, "description", "")
    role = Map.get(item, "role", "")
    client = Map.get(item, "client", "")
    start_date = Map.get(item, "start_date", "")
    end_date = Map.get(item, "end_date", "")
    status = Map.get(item, "status", "Completed")
    technologies = Map.get(item, "technologies", [])
    features = Map.get(item, "features", [])
    live_url = Map.get(item, "live_url", "")
    repo_url = Map.get(item, "repo_url", "")

    # Format project meta
    project_meta = [role, client] |> Enum.filter(&(&1 != "")) |> Enum.join(" • ")
    date_range = format_date_range(start_date, end_date, status == "In Progress")

    # Format technologies
    tech_html = if is_list(technologies) and length(technologies) > 0 do
      tech_items = technologies
      |> Enum.map(fn tech -> "<span class=\"tech-tag\">#{html_escape(tech)}</span>" end)
      |> Enum.join("")

      "<div class=\"project-technologies\"><div class=\"tech-container\">#{tech_items}</div></div>"
    else
      ""
    end

    # Format features
    features_html = if is_list(features) and length(features) > 0 do
      feature_items = features
      |> Enum.map(fn feature -> "<li>#{html_escape(feature)}</li>" end)
      |> Enum.join("")

      "<div class=\"project-features\"><h5>Key Features</h5><ul>#{feature_items}</ul></div>"
    else
      ""
    end

    # Format links
    links_html = []
    links_html = if live_url != "", do: ["<a href=\"#{html_escape(live_url)}\" target=\"_blank\" class=\"project-link live-link\">View Live</a>" | links_html], else: links_html
    links_html = if repo_url != "", do: ["<a href=\"#{html_escape(repo_url)}\" target=\"_blank\" class=\"project-link repo-link\">View Code</a>" | links_html], else: links_html

    links_section = if length(links_html) > 0 do
      "<div class=\"project-links\">#{Enum.join(links_html, "")}</div>"
    else
      ""
    end

    """
    <div class="project-item #{if index == 0, do: "first-item", else: ""}" data-index="#{index}">
      <div class="project-header">
        <h4 class="project-title">#{html_escape(title)}</h4>
        <div class="project-meta">
          #{if project_meta != "", do: "<span class=\"project-role\">#{html_escape(project_meta)}</span>", else: ""}
          #{if date_range != "", do: "<span class=\"project-dates\">#{date_range}</span>", else: ""}
          <span class="project-status status-#{String.downcase(status)}">#{html_escape(status)}</span>
        </div>
      </div>
      #{if description != "", do: "<div class=\"project-description\">#{html_escape(description)}</div>", else: ""}
      #{features_html}
      #{tech_html}
      #{links_section}
    </div>
    """
  end
  defp render_single_project_item(_, _, _), do: ""

  # FIXED: Enhanced contact content rendering
  defp render_contact_content_enhanced(content, _assigns) do
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    location = Map.get(content, "location", "")
    website = Map.get(content, "website", "")
    linkedin = Map.get(content, "linkedin", "")
    github = Map.get(content, "github", "")
    availability = Map.get(content, "availability", "")

    contact_items = []
    contact_items = if email != "", do: ["<div class=\"contact-item\"><span class=\"contact-label\">Email:</span> <a href=\"mailto:#{html_escape(email)}\">#{html_escape(email)}</a></div>" | contact_items], else: contact_items
    contact_items = if phone != "", do: ["<div class=\"contact-item\"><span class=\"contact-label\">Phone:</span> <a href=\"tel:#{html_escape(phone)}\">#{html_escape(phone)}</a></div>" | contact_items], else: contact_items
    contact_items = if location != "", do: ["<div class=\"contact-item\"><span class=\"contact-label\">Location:</span> #{html_escape(location)}</div>" | contact_items], else: contact_items
    contact_items = if website != "", do: ["<div class=\"contact-item\"><span class=\"contact-label\">Website:</span> <a href=\"#{html_escape(website)}\" target=\"_blank\">#{html_escape(website)}</a></div>" | contact_items], else: contact_items

    social_links = []
    social_links = if linkedin != "", do: ["<a href=\"#{html_escape(linkedin)}\" target=\"_blank\" class=\"social-link linkedin\">LinkedIn</a>" | social_links], else: social_links
    social_links = if github != "", do: ["<a href=\"#{html_escape(github)}\" target=\"_blank\" class=\"social-link github\">GitHub</a>" | social_links], else: social_links

    social_section = if length(social_links) > 0 do
      "<div class=\"social-links\"><h5>Connect With Me</h5><div class=\"social-container\">#{Enum.join(social_links, "")}</div></div>"
    else
      ""
    end

    availability_section = if availability != "" do
      "<div class=\"availability\"><span class=\"availability-status\">Status: #{html_escape(availability)}</span></div>"
    else
      ""
    end

    if length(contact_items) > 0 or length(social_links) > 0 do
      """
      <div class="contact-content">
        #{if length(contact_items) > 0, do: "<div class=\"contact-info\">#{Enum.join(contact_items, "")}</div>", else: ""}
        #{availability_section}
        #{social_section}
      </div>
      """
    else
      "<div class=\"empty-state\">No contact information available.</div>"
    end
  end

  # FIXED: Generic content rendering with fallbacks
  defp render_generic_content_enhanced(content, _assigns) do
    text_content = Map.get(content, "content", Map.get(content, "description", ""))

    if text_content != "" do
      "<div class=\"generic-content\">#{html_escape(text_content)}</div>"
    else
      "<div class=\"empty-state\">No content available.</div>"
    end
  end

  # Placeholder implementations for other content types
  defp render_testimonials_content(content, _assigns) do
    render_generic_content_enhanced(content, nil)
  end

  defp render_certifications_content(content, _assigns) do
    render_generic_content_enhanced(content, nil)
  end

  defp render_achievements_content(content, _assigns) do
    render_generic_content_enhanced(content, nil)
  end

  # FIXED: Helper functions
  defp format_date_range(start_date, end_date, is_current) do
    cond do
      start_date == "" and end_date == "" -> ""
      start_date != "" and (end_date == "" or is_current) -> "#{start_date} - Present"
      start_date != "" and end_date != "" -> "#{start_date} - #{end_date}"
      end_date != "" -> end_date
      true -> ""
    end
  end

  defp render_video_embed(video_url) do
    cond do
      String.contains?(video_url, "youtube.com") or String.contains?(video_url, "youtu.be") ->
        video_id = extract_youtube_id(video_url)
        "<div class=\"video-embed\"><iframe src=\"https://www.youtube.com/embed/#{video_id}\" frameborder=\"0\" allowfullscreen></iframe></div>"

      String.contains?(video_url, "vimeo.com") ->
        video_id = extract_vimeo_id(video_url)
        "<div class=\"video-embed\"><iframe src=\"https://player.vimeo.com/video/#{video_id}\" frameborder=\"0\" allowfullscreen></iframe></div>"

      true ->
        "<div class=\"video-embed\"><video controls><source src=\"#{html_escape(video_url)}\" type=\"video/mp4\"></video></div>"
    end
  end

  defp extract_youtube_id(url) do
    cond do
      String.contains?(url, "youtu.be/") ->
        url |> String.split("youtu.be/") |> List.last() |> String.split("?") |> List.first()
      String.contains?(url, "watch?v=") ->
        url |> String.split("watch?v=") |> List.last() |> String.split("&") |> List.first()
      true -> ""
    end
  end

  defp extract_vimeo_id(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split("?")
    |> List.first()
  end

  defp has_footer_content?(_section), do: false

  defp render_section_footer(_section, _assigns), do: ""

  defp render_error_fallback(section, content) do
    """
    <div class="error-fallback">
      <p class="error-message">Unable to render #{section.section_type} section properly.</p>
      #{if is_binary(content["content"]), do: "<div class=\"fallback-content\">#{html_escape(content["content"])}</div>", else: ""}
    </div>
    """
  end
end
