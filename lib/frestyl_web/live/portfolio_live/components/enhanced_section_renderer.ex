# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer with Frestyl design philosophy:
  - No inside borders on cards
  - Clean shadows and gradients
  - Smooth hover effects
  - Professional spacing
  - Mobile-first responsive design
  - Color scheme integration from user settings
  - Secure code display with isolation
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
      <div class="section-header mb-6">
        <div class="flex items-center justify-between">
          <div class="header-info">
            <h3 class="text-2xl font-bold text-gray-900 mb-2"><%= @section.title %></h3>
          </div>

          <%= if Map.get(assigns, :show_actions, false) do %>
            <div class="header-actions flex items-center space-x-2">
              <button phx-click="edit_section"
                      phx-value-section_id={@section.id}
                      class="p-2 text-gray-500 hover:text-gray-700 rounded-lg hover:bg-gray-100 transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Section Content -->
      <div class="section-content">
        <%= render_section_content(@section, assigns) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MAIN CONTENT ROUTING - Static Functions for Layout Renderer
  # ============================================================================

  # Static function that can be called from EnhancedLayoutRenderer
  def render_section_content_static(section, customization \\ %{}) do
    content = normalize_section_content(section.content, section.section_type)

    try do
      case to_string(section.section_type) do
        "skills" -> render_skills_content_enhanced(content, customization)
        "projects" -> render_projects_content_enhanced(content, customization)
        "experience" -> render_experience_content_enhanced(content, customization)
        "work_experience" -> render_experience_content_enhanced(content, customization)
        "contact" -> render_contact_content_enhanced(content, customization)
        "education" -> render_education_content_enhanced(content, customization)
        "intro" -> render_intro_content_enhanced(content, customization)
        "about" -> render_intro_content_enhanced(content, customization)
        _ -> render_generic_content_enhanced(content, customization)
      end
    rescue
      error ->
        IO.puts("❌ Error rendering section #{section.section_type}: #{inspect(error)}")
        render_error_fallback(section, content)
    end
  end

  def render_section_content(section, assigns) do
    customization = Map.get(assigns, :customization, %{})
    render_section_content_static(section, customization)
  end

  # ============================================================================
  # SKILLS SECTION - Enhanced with Color Scheme Integration
  # ============================================================================

  defp render_skills_content_enhanced(content, customization) do
    # Compatible with DynamicSectionModal format - check for "items" first (new format)
    skills = Map.get(content, "items", Map.get(content, "skills", []))
    categories = Map.get(content, "categories", %{})
    display_style = Map.get(content, "display_style", "categorized")

    # Extract color scheme from user settings
    color_scheme = get_user_color_scheme(customization)

    cond do
      is_list(skills) and length(skills) > 0 ->
        render_skills_items(skills, display_style, color_scheme)

      is_map(categories) and map_size(categories) > 0 ->
        render_skills_categories(categories, display_style, color_scheme)

      true ->
        render_empty_state("No skills information available")
    end
  end

  defp render_skills_items(skills, display_style, color_scheme) do
    case display_style do
      "categorized" ->
        grouped_skills = Enum.group_by(skills, &Map.get(&1, "category", "Other"))
        render_skills_grouped(grouped_skills, color_scheme)

      "proficiency_bars" ->
        render_skills_with_proficiency_visual(skills, color_scheme)

      _ ->
        render_skills_flat_grid(skills, color_scheme)
    end
  end

  defp render_skills_grouped(grouped_skills, color_scheme) do
    category_html = grouped_skills
    |> Enum.map(fn {category_name, category_skills} ->
      render_skills_category_section(category_name, category_skills, color_scheme)
    end)
    |> Enum.join("")

    """
    <div class="skills-section space-y-8">
      #{category_html}
    </div>
    """
  end

  defp render_skills_categories(categories, display_style, color_scheme) do
    category_html = categories
    |> Enum.map(fn {category_name, category_skills} ->
      render_skills_category_section(category_name, category_skills, color_scheme)
    end)
    |> Enum.join("")

    """
    <div class="skills-section space-y-8">
      #{category_html}
    </div>
    """
  end

  defp render_skills_with_proficiency_visual(skills, color_scheme) do
    skills_html = skills
    |> Enum.map(&render_single_skill_card(&1, color_scheme))
    |> Enum.join("")

    """
    <div class="skills-proficiency-grid grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      #{skills_html}
    </div>
    """
  end

  defp render_skills_flat_grid(skills, color_scheme) do
    skills_html = skills
    |> Enum.map(&render_simple_skill_tag(&1, color_scheme))
    |> Enum.join("")

    """
    <div class="skills-flat-grid">
      <div class="flex flex-wrap gap-3">
        #{skills_html}
      </div>
    </div>
    """
  end

  defp render_simple_skill_tag(skill, color_scheme) do
    # EXACT compatibility with DynamicSectionModal field names
    skill_name = case skill do
      skill_map when is_map(skill_map) -> Map.get(skill_map, "skill_name", "Skill")
      skill_str when is_binary(skill_str) -> skill_str
      _ -> "Skill"
    end

    """
    <span class="inline-flex items-center px-3 py-2 rounded-lg text-sm font-medium bg-white shadow-sm border-0 hover:shadow-md transition-shadow duration-200">
      #{html_escape(skill_name)}
    </span>
    """
  end

  defp render_skills_category_section(category_name, skills, color_scheme) do
    skills_html = skills
    |> Enum.map(&render_single_skill_card(&1, color_scheme))
    |> Enum.join("")

    """
    <div class="skill-category">
      <h4 class="text-lg font-semibold text-gray-800 mb-4">#{html_escape(category_name)}</h4>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
        #{skills_html}
      </div>
    </div>
    """
  end

  defp render_single_skill_card(skill, color_scheme) when is_map(skill) do
    # EXACT compatibility with DynamicSectionModal field names
    skill_name = Map.get(skill, "skill_name", "Skill")  # Modal uses "skill_name"
    proficiency = Map.get(skill, "proficiency", "Intermediate")
    years = Map.get(skill, "years_experience", 0)

    {color_classes, intensity} = get_proficiency_colors(proficiency, color_scheme)
    years_badge = if years > 0, do: render_years_badge(years), else: ""

    """
    <div class="skill-card bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-200 p-4 border-0">
      <div class="flex items-center justify-between mb-3">
        <h5 class="font-medium text-gray-900">#{html_escape(skill_name)}</h5>
        #{years_badge}
      </div>
      <div class="skill-proficiency">
        <div class="flex items-center justify-between mb-2">
          <span class="text-sm text-gray-600">#{html_escape(proficiency)}</span>
          <span class="text-xs text-gray-500">#{intensity}%</span>
        </div>
        <div class="proficiency-visual h-2 bg-gray-100 rounded-full overflow-hidden">
          <div class="proficiency-fill h-full #{color_classes} rounded-full transition-all duration-500"
               style="width: #{intensity}%"></div>
        </div>
      </div>
    </div>
    """
  end

  defp render_single_skill_card(skill, _color_scheme) when is_binary(skill) do
    """
    <div class="skill-card bg-white rounded-xl shadow-sm hover:shadow-md transition-all duration-200 p-4 border-0">
      <h5 class="font-medium text-gray-900">#{html_escape(skill)}</h5>
    </div>
    """
  end

  defp render_years_badge(years) do
    """
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700">
      #{years}y
    </span>
    """
  end

  defp get_proficiency_colors(proficiency, color_scheme) do
    base_colors = get_color_scheme_classes(color_scheme)

    case String.downcase(proficiency) do
      level when level in ["expert", "advanced"] ->
        {base_colors.dark, 95}
      level when level in ["intermediate", "proficient"] ->
        {base_colors.medium, 75}
      level when level in ["beginner", "basic", "learning"] ->
        {base_colors.light, 45}
      _ ->
        {base_colors.medium, 60}
    end
  end

  defp get_color_scheme_classes(customization) do
    primary_color = Map.get(customization, "primary_color", "#3b82f6")

    # Convert hex to Tailwind-equivalent classes based on hue
    case get_color_family(primary_color) do
      "blue" -> %{light: "bg-blue-400", medium: "bg-blue-600", dark: "bg-blue-800"}
      "green" -> %{light: "bg-emerald-400", medium: "bg-emerald-600", dark: "bg-emerald-800"}
      "purple" -> %{light: "bg-purple-400", medium: "bg-purple-600", dark: "bg-purple-800"}
      "red" -> %{light: "bg-red-400", medium: "bg-red-600", dark: "bg-red-800"}
      _ -> %{light: "bg-gray-400", medium: "bg-gray-600", dark: "bg-gray-800"}
    end
  end

  defp get_color_family(hex_color) do
    # Simple color family detection based on hex values
    # In production, you might want more sophisticated color analysis
    case String.downcase(hex_color) do
      color when color in ["#3b82f6", "#2563eb", "#1d4ed8"] -> "blue"
      color when color in ["#10b981", "#059669", "#047857"] -> "green"
      color when color in ["#8b5cf6", "#7c3aed", "#6d28d9"] -> "purple"
      color when color in ["#ef4444", "#dc2626", "#b91c1c"] -> "red"
      _ -> "blue" # default
    end
  end

  # ============================================================================
  # PROJECTS SECTION - Enhanced with Methodology Badges & Code Blocks
  # ============================================================================

  defp render_projects_content_enhanced(content, customization) do
    # Compatible with DynamicSectionModal - uses "items" array format
    projects = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "grid")

    if length(projects) > 0 do
      render_projects_grid(projects, customization)
    else
      render_empty_state("No projects available")
    end
  end

  defp render_projects_grid(projects, customization) do
    projects_html = projects
    |> Enum.map(&render_single_project_card(&1, customization))
    |> Enum.join("")

    """
    <div class="projects-grid grid grid-cols-1 lg:grid-cols-2 gap-6">
      #{projects_html}
    </div>
    """
  end

  defp render_single_project_card(project, customization) when is_map(project) do
    title = Map.get(project, "title", "Project")
    description = Map.get(project, "description", "")
    methodology = Map.get(project, "methodology", "")
    technologies = Map.get(project, "technologies", [])
    live_url = Map.get(project, "live_url", "")
    repo_url = Map.get(project, "repo_url", "")
    code_excerpts = Map.get(project, "code_excerpts", [])

    methodology_badge = if methodology != "", do: render_methodology_badge(methodology), else: ""
    tech_tags = render_technology_tags(technologies)
    action_buttons = render_project_actions(live_url, repo_url)
    code_blocks = render_code_excerpts(code_excerpts)

    """
    <div class="project-card bg-white rounded-xl shadow-sm hover:shadow-lg transition-all duration-300 p-6 border-0">
      <div class="project-header mb-4">
        <div class="flex items-start justify-between">
          <h4 class="text-xl font-semibold text-gray-900 mb-2">#{html_escape(title)}</h4>
          #{methodology_badge}
        </div>
        <p class="text-gray-600 leading-relaxed">#{html_escape(description)}</p>
      </div>

      #{if length(technologies) > 0, do: tech_tags, else: ""}
      #{code_blocks}
      #{action_buttons}
    </div>
    """
  end

  defp render_methodology_badge(methodology) do
    """
    <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
      #{html_escape(methodology)}
    </span>
    """
  end

  defp render_technology_tags(technologies) when is_list(technologies) do
    tags_html = technologies
    |> Enum.map(fn tech ->
      """
      <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-gray-100 text-gray-700">
        #{html_escape(tech)}
      </span>
      """
    end)
    |> Enum.join("")

    """
    <div class="technology-tags mb-4">
      <div class="flex flex-wrap gap-2">
        #{tags_html}
      </div>
    </div>
    """
  end

  defp render_technology_tags(_), do: ""

  defp render_project_actions(live_url, repo_url) do
    buttons = []

    buttons = if live_url != "", do: [render_action_button("View Live", live_url, "external") | buttons], else: buttons
    buttons = if repo_url != "", do: [render_action_button("View Code", repo_url, "code") | buttons], else: buttons

    if length(buttons) > 0 do
      """
      <div class="project-actions mt-4 flex gap-3">
        #{Enum.join(buttons, "")}
      </div>
      """
    else
      ""
    end
  end

  defp render_action_button(text, url, type) do
    icon = case type do
      "external" -> """
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
        </svg>
        """
      "code" -> """
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
        </svg>
        """
      _ -> ""
    end

    """
    <a href="#{html_escape(url)}"
       target="_blank"
       rel="noopener noreferrer"
       class="inline-flex items-center px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors">
      #{icon}
      <span class="ml-2">#{html_escape(text)}</span>
    </a>
    """
  end

  defp render_code_excerpts(code_excerpts) when is_list(code_excerpts) and length(code_excerpts) > 0 do
    excerpts_html = code_excerpts
    |> Enum.with_index()
    |> Enum.map(fn {excerpt, index} -> render_single_code_excerpt(excerpt, index) end)
    |> Enum.join("")

    """
    <div class="code-excerpts mb-4">
      #{excerpts_html}
    </div>
    """
  end

  defp render_code_excerpts(_), do: ""

  defp render_single_code_excerpt(excerpt, index) when is_map(excerpt) do
    title = Map.get(excerpt, "title", "Code Snippet")
    language = Map.get(excerpt, "language", "text")
    code = Map.get(excerpt, "code", "")

    # Secure code rendering - no execution, isolated display
    escaped_code = html_escape(code)

    """
    <div class="code-excerpt mb-3">
      <button type="button"
              onclick="toggleCodeBlock('code-block-#{index}')"
              class="w-full text-left p-3 bg-gray-50 hover:bg-gray-100 rounded-lg border border-gray-200 transition-colors">
        <div class="flex items-center justify-between">
          <div class="flex items-center">
            <svg class="w-4 h-4 text-gray-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
            </svg>
            <span class="font-medium text-gray-700">#{html_escape(title)}</span>
            <span class="ml-2 text-xs text-gray-500 bg-gray-200 px-2 py-1 rounded">#{html_escape(language)}</span>
          </div>
          <svg class="w-4 h-4 text-gray-400 transition-transform duration-200" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </div>
      </button>
      <div id="code-block-#{index}" class="hidden mt-2 p-4 bg-gray-900 rounded-lg overflow-auto">
        <pre class="text-sm text-gray-100 whitespace-pre-wrap font-mono leading-relaxed">#{escaped_code}</pre>
      </div>
    </div>

    <script>
      function toggleCodeBlock(id) {
        const block = document.getElementById(id);
        const button = block.previousElementSibling.querySelector('svg:last-child');
        if (block.classList.contains('hidden')) {
          block.classList.remove('hidden');
          button.style.transform = 'rotate(180deg)';
        } else {
          block.classList.add('hidden');
          button.style.transform = 'rotate(0deg)';
        }
      }
    </script>
    """
  end

  defp render_single_code_excerpt(_, _), do: ""

  # ============================================================================
  # EXPERIENCE SECTION - Enhanced with Smart Achievement Display
  # ============================================================================

  defp render_experience_content_enhanced(content, customization) do
    # Compatible with DynamicSectionModal - uses "items" array format
    experiences = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "timeline")

    if length(experiences) > 0 do
      render_experience_timeline(experiences, customization)
    else
      render_empty_state("No work experience available")
    end
  end

  defp render_experience_timeline(experiences, customization) do
    experiences_html = experiences
    |> Enum.with_index()
    |> Enum.map(fn {exp, index} -> render_single_experience_item(exp, index, customization) end)
    |> Enum.join("")

    """
    <div class="experience-timeline space-y-8">
      #{experiences_html}
    </div>
    """
  end

  defp render_single_experience_item(experience, index, customization) when is_map(experience) do
    title = Map.get(experience, "title", "Position")
    company = Map.get(experience, "company", "Company")
    location = Map.get(experience, "location", "")
    employment_type = Map.get(experience, "employment_type", "")
    start_date = Map.get(experience, "start_date", "")
    end_date = Map.get(experience, "end_date", "")
    is_current = Map.get(experience, "is_current", false)
    description = Map.get(experience, "description", "")
    achievements = Map.get(experience, "achievements", [])
    skills_used = Map.get(experience, "skills_used", [])

    date_range = format_date_range(start_date, end_date, is_current)
    employment_badge = if employment_type != "", do: render_employment_badge(employment_type), else: ""
    achievements_display = render_achievements_smart(achievements)
    skills_display = render_skills_used(skills_used)

    """
    <div class="experience-item bg-white rounded-xl shadow-sm p-6 border-0 #{if index == 0, do: "border-l-4 border-blue-500", else: ""}">
      <div class="experience-header mb-4">
        <div class="flex items-start justify-between">
          <div>
            <h4 class="text-xl font-semibold text-gray-900 mb-1">#{html_escape(title)}</h4>
            <div class="flex items-center text-gray-600 mb-2">
              <span class="font-medium">#{html_escape(company)}</span>
              #{if location != "", do: "<span class=\"mx-2\">•</span><span>#{html_escape(location)}</span>", else: ""}
            </div>
          </div>
          <div class="text-right">
            #{employment_badge}
            <div class="text-sm text-gray-500 mt-1">#{date_range}</div>
          </div>
        </div>
        #{if description != "", do: "<p class=\"text-gray-700 leading-relaxed\">#{html_escape(description)}</p>", else: ""}
      </div>

      #{achievements_display}
      #{skills_display}
    </div>
    """
  end

  defp render_employment_badge(employment_type) do
    """
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
      #{html_escape(employment_type)}
    </span>
    """
  end

  defp render_achievements_smart(achievements) when is_list(achievements) and length(achievements) > 0 do
    # Smart logic based on content length
    total_length = achievements |> Enum.map(&String.length/1) |> Enum.sum()
    avg_length = total_length / length(achievements)

    if avg_length > 100 do
      # Long achievements - use expandable cards
      render_achievements_expandable(achievements)
    else
      # Short achievements - use bullet list
      render_achievements_bullets(achievements)
    end
  end

  defp render_achievements_smart(_), do: ""

  defp render_achievements_bullets(achievements) do
    bullets_html = achievements
    |> Enum.map(fn achievement ->
      """
      <li class="flex items-start">
        <span class="flex-shrink-0 w-1.5 h-1.5 bg-blue-500 rounded-full mt-2 mr-3"></span>
        <span class="text-gray-700">#{html_escape(achievement)}</span>
      </li>
      """
    end)
    |> Enum.join("")

    """
    <div class="achievements mb-4">
      <h5 class="font-medium text-gray-900 mb-2">Key Achievements</h5>
      <ul class="space-y-2">
        #{bullets_html}
      </ul>
    </div>
    """
  end

  defp render_achievements_expandable(achievements) do
    preview = achievements |> List.first() |> String.slice(0, 120)
    remaining_count = length(achievements) - 1

    """
    <div class="achievements mb-4">
      <h5 class="font-medium text-gray-900 mb-2">Key Achievements</h5>
      <div class="achievement-preview p-3 bg-gray-50 rounded-lg">
        <p class="text-gray-700">#{html_escape(preview)}#{if String.length(List.first(achievements)) > 120, do: "...", else: ""}</p>
        #{if remaining_count > 0 do
          """
          <button type="button" class="mt-2 text-sm text-blue-600 hover:text-blue-700 font-medium">
            View #{remaining_count} more achievement#{if remaining_count > 1, do: "s", else: ""}
          </button>
          """
        else
          ""
        end}
      </div>
    </div>
    """
  end

  defp render_skills_used(skills) when is_list(skills) and length(skills) > 0 do
    skills_html = skills
    |> Enum.map(fn skill ->
      """
      <span class="inline-flex items-center px-2 py-1 rounded-md text-xs font-medium bg-blue-100 text-blue-700">
        #{html_escape(skill)}
      </span>
      """
    end)
    |> Enum.join("")

    """
    <div class="skills-used">
      <div class="flex flex-wrap gap-2">
        #{skills_html}
      </div>
    </div>
    """
  end

  defp render_skills_used(_), do: ""

  # ============================================================================
  # CONTACT SECTION - Enhanced with Professional Icon Grid
  # ============================================================================

  defp render_contact_content_enhanced(content, customization) do
    # Compatible with DynamicSectionModal - direct field access for contact fields
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    location = Map.get(content, "location", "")
    availability = Map.get(content, "availability", "")
    # Handle both map format and individual social link fields
    social_links = case Map.get(content, "social_links") do
      social_map when is_map(social_map) -> social_map
      _ ->
        # Extract individual social fields that might be saved directly
        %{
          "linkedin" => Map.get(content, "linkedin", ""),
          "github" => Map.get(content, "github", ""),
          "twitter" => Map.get(content, "twitter", ""),
          "website" => Map.get(content, "website", "")
        }
        |> Enum.filter(fn {_, url} -> url != "" end)
        |> Enum.into(%{})
    end

    contact_info = render_contact_info(email, phone, location, availability)
    social_grid = render_social_links_grid(social_links)

    """
    <div class="contact-section">
      #{contact_info}
      #{social_grid}
    </div>
    """
  end

  defp render_contact_info(email, phone, location, availability) do
    info_items = []

    info_items = if email != "", do: [render_contact_item("email", email, "mailto:#{email}") | info_items], else: info_items
    info_items = if phone != "", do: [render_contact_item("phone", phone, "tel:#{phone}") | info_items], else: info_items
    info_items = if location != "", do: [render_contact_item("location", location, "") | info_items], else: info_items

    availability_display = if availability != "" do
      """
      <div class="availability-status mt-4 p-3 bg-green-50 rounded-lg">
        <div class="flex items-center">
          <div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
          <span class="text-green-800 font-medium">#{html_escape(availability)}</span>
        </div>
      </div>
      """
    else
      ""
    end

    if length(info_items) > 0 do
      """
      <div class="contact-info mb-6">
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          #{Enum.join(info_items, "")}
        </div>
        #{availability_display}
      </div>
      """
    else
      ""
    end
  end

  defp render_contact_item(type, value, link) do
    {icon, label} = case type do
      "email" -> {render_email_icon(), "Email"}
      "phone" -> {render_phone_icon(), "Phone"}
      "location" -> {render_location_icon(), "Location"}
      _ -> {"", "Contact"}
    end

    content = if link != "" do
      """
      <a href="#{html_escape(link)}" class="text-blue-600 hover:text-blue-700 transition-colors">
        #{html_escape(value)}
      </a>
      """
    else
      html_escape(value)
    end

    """
    <div class="contact-item bg-white rounded-lg shadow-sm p-4 border-0">
      <div class="flex items-center mb-2">
        #{icon}
        <span class="text-sm font-medium text-gray-500 ml-2">#{label}</span>
      </div>
      <div class="text-gray-900">#{content}</div>
    </div>
    """
  end

  defp render_social_links_grid(social_links) when is_map(social_links) do
    active_links = social_links |> Enum.filter(fn {_, url} -> url != "" end)

    if length(active_links) > 0 do
      links_html = active_links
      |> Enum.map(fn {platform, url} -> render_social_link_item(platform, url) end)
      |> Enum.join("")

      """
      <div class="social-links">
        <h5 class="font-medium text-gray-900 mb-4">Connect</h5>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          #{links_html}
        </div>
      </div>
      """
    else
      ""
    end
  end

  defp render_social_links_grid(_), do: ""

  defp render_social_link_item(platform, url) do
    {icon, platform_name, color_class} = get_platform_details(platform)

    """
    <a href="#{html_escape(url)}"
       target="_blank"
       rel="noopener noreferrer"
       class="social-link-item flex items-center p-3 bg-white rounded-lg shadow-sm hover:shadow-md transition-all duration-200 border-0 #{color_class}">
      #{icon}
      <span class="ml-2 text-sm font-medium text-gray-700">#{platform_name}</span>
    </a>
    """
  end

  defp get_platform_details(platform) do
    case String.downcase(to_string(platform)) do
      "linkedin" -> {render_linkedin_icon(), "LinkedIn", "hover:bg-blue-50"}
      "github" -> {render_github_icon(), "GitHub", "hover:bg-gray-50"}
      "twitter" -> {render_twitter_icon(), "Twitter", "hover:bg-blue-50"}
      "website" -> {render_website_icon(), "Website", "hover:bg-green-50"}
      "email" -> {render_email_icon(), "Email", "hover:bg-red-50"}
      _ -> {render_link_icon(), String.capitalize(to_string(platform)), "hover:bg-gray-50"}
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp normalize_section_content(content, section_type) when is_map(content) do
    # Handle Phoenix {:safe, content} tuples and ensure clean data
    cleaned_content = content
    |> Enum.map(fn {key, value} ->
      clean_value = case value do
        {:safe, safe_content} when is_binary(safe_content) -> safe_content
        {:safe, safe_content} when is_list(safe_content) -> Enum.join(safe_content, "")
        other -> other
      end
      {key, clean_value}
    end)
    |> Enum.into(%{})

    # Compatible with current DynamicSectionModal - data should already be in correct format
    # Just ensure we have the expected structure, no complex migrations needed
    case to_string(section_type) do
      "experience" ->
        # DynamicSectionModal saves as "items" already
        items = Map.get(cleaned_content, "items", [])
        Map.put(cleaned_content, "items", normalize_items_list(items))

      "education" ->
        # DynamicSectionModal saves as "items" already
        items = Map.get(cleaned_content, "items", [])
        Map.put(cleaned_content, "items", normalize_items_list(items))

      "projects" ->
        # DynamicSectionModal saves as "items" already
        items = Map.get(cleaned_content, "items", [])
        Map.put(cleaned_content, "items", normalize_items_list(items))

      "skills" ->
        # DynamicSectionModal may save as "items" or "skills" - check both
        skills = Map.get(cleaned_content, "items", Map.get(cleaned_content, "skills", []))
        Map.merge(cleaned_content, %{"items" => normalize_items_list(skills)})

      _ ->
        cleaned_content
    end
  end

  defp normalize_section_content(content, _), do: content || %{}

  defp normalize_items_list(items) when is_list(items) do
    # Clean any {:safe, content} tuples from items
    items
    |> Enum.map(fn item when is_map(item) ->
      item
      |> Enum.map(fn {key, value} ->
        clean_value = case value do
          {:safe, safe_content} when is_binary(safe_content) -> safe_content
          {:safe, safe_content} when is_list(safe_content) -> Enum.join(safe_content, "")
          other -> other
        end
        {key, clean_value}
      end)
      |> Enum.into(%{})
    end)
  end
  defp normalize_items_list(_), do: []

  defp get_user_color_scheme(customization) when is_map(customization) do
    Map.get(customization, "color_scheme", "professional")
  end
  defp get_user_color_scheme(_), do: "professional"

  defp format_date_range(start_date, end_date, is_current) do
    start_formatted = format_date_display(start_date)

    cond do
      is_current -> "#{start_formatted} - Present"
      end_date != "" -> "#{start_formatted} - #{format_date_display(end_date)}"
      true -> start_formatted
    end
  end

  defp format_date_display(date) when is_binary(date) and date != "" do
    # Simple date formatting - can be enhanced based on your date format
    case String.split(date, "-") do
      [year, month | _] -> "#{format_month(month)}/#{year}"
      _ -> date
    end
  end

  defp format_date_display(_), do: ""

  defp format_month(month_str) do
    case month_str do
      "01" -> "Jan"
      "02" -> "Feb"
      "03" -> "Mar"
      "04" -> "Apr"
      "05" -> "May"
      "06" -> "Jun"
      "07" -> "Jul"
      "08" -> "Aug"
      "09" -> "Sep"
      "10" -> "Oct"
      "11" -> "Nov"
      "12" -> "Dec"
      _ -> month_str
    end
  end

  defp render_empty_state(message) do
    """
    <div class="empty-state text-center py-12">
      <div class="text-gray-400 mb-2">
        <svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
      </div>
      <p class="text-gray-500">#{html_escape(message)}</p>
    </div>
    """
  end

  defp render_error_fallback(section, content) do
    """
    <div class="error-fallback bg-red-50 border border-red-200 rounded-lg p-4">
      <div class="flex items-center text-red-800 mb-2">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <span class="font-medium">Section Display Error</span>
      </div>
      <p class="text-red-700 text-sm">Unable to render #{section.section_type} section. Please check the section configuration.</p>
    </div>
    """
  end

  # ============================================================================
  # ADDITIONAL SECTION RENDERERS
  # ============================================================================

  defp render_intro_content_enhanced(content, _customization) do
    story = Map.get(content, "story", Map.get(content, "description", ""))
    highlights = Map.get(content, "highlights", [])

    highlights_display = if length(highlights) > 0 do
      highlights_html = highlights
      |> Enum.map(fn highlight ->
        """
        <li class="flex items-start">
          <span class="flex-shrink-0 w-1.5 h-1.5 bg-blue-500 rounded-full mt-2 mr-3"></span>
          <span class="text-gray-700">#{html_escape(highlight)}</span>
        </li>
        """
      end)
      |> Enum.join("")

      """
      <div class="highlights mt-6">
        <h4 class="font-medium text-gray-900 mb-3">Highlights</h4>
        <ul class="space-y-2">
          #{highlights_html}
        </ul>
      </div>
      """
    else
      ""
    end

    """
    <div class="intro-content">
      <div class="prose max-w-none">
        <p class="text-gray-700 leading-relaxed text-lg">#{html_escape(story)}</p>
      </div>
      #{highlights_display}
    </div>
    """
  end

  defp render_education_content_enhanced(content, _customization) do
    # Compatible with DynamicSectionModal - uses "items" array format
    education_items = Map.get(content, "items", [])

    if length(education_items) > 0 do
      education_html = education_items
      |> Enum.map(&render_single_education_item/1)
      |> Enum.join("")

      """
      <div class="education-timeline space-y-6">
        #{education_html}
      </div>
      """
    else
      render_empty_state("No education information available")
    end
  end

  defp render_single_education_item(education) when is_map(education) do
    degree = Map.get(education, "degree", "Degree")
    field = Map.get(education, "field", "")
    institution = Map.get(education, "institution", "Institution")
    location = Map.get(education, "location", "")
    start_date = Map.get(education, "start_date", "")
    end_date = Map.get(education, "end_date", "")
    gpa = Map.get(education, "gpa", "")

    date_range = format_date_range(start_date, end_date, false)
    gpa_display = if gpa != "" and gpa != "0" do
      """
      <div class="text-sm text-gray-600 mt-1">GPA: #{html_escape(gpa)}</div>
      """
    else
      ""
    end

    """
    <div class="education-item bg-white rounded-xl shadow-sm p-6 border-0">
      <div class="flex items-start justify-between">
        <div>
          <h4 class="text-lg font-semibold text-gray-900">#{html_escape(degree)}</h4>
          #{if field != "", do: "<p class=\"text-gray-600 mb-1\">#{html_escape(field)}</p>", else: ""}
          <p class="text-gray-600 font-medium">#{html_escape(institution)}</p>
          #{if location != "", do: "<p class=\"text-gray-500 text-sm\">#{html_escape(location)}</p>", else: ""}
          #{gpa_display}
        </div>
        <div class="text-right text-sm text-gray-500">
          #{date_range}
        </div>
      </div>
    </div>
    """
  end

  defp render_generic_content_enhanced(content, _customization) do
    description = Map.get(content, "description", Map.get(content, "content", ""))

    if description != "" do
      """
      <div class="generic-content prose max-w-none">
        <p class="text-gray-700 leading-relaxed">#{html_escape(description)}</p>
      </div>
      """
    else
      render_empty_state("No content available")
    end
  end

  # ============================================================================
  # ICON COMPONENTS (Minimal Professional Icons)
  # ============================================================================

  defp render_email_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
    </svg>
    """
  end

  defp render_phone_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
    </svg>
    """
  end

  defp render_location_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
    </svg>
    """
  end

  defp render_linkedin_icon do
    """
    <svg class="w-4 h-4 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
      <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
    </svg>
    """
  end

  defp render_github_icon do
    """
    <svg class="w-4 h-4 text-gray-800" fill="currentColor" viewBox="0 0 24 24">
      <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
    </svg>
    """
  end

  defp render_twitter_icon do
    """
    <svg class="w-4 h-4 text-blue-500" fill="currentColor" viewBox="0 0 24 24">
      <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
    </svg>
    """
  end

  defp render_website_icon do
    """
    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
    </svg>
    """
  end

  defp render_link_icon do
    """
    <svg class="w-4 h-4 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
    </svg>
    """
  end
end
