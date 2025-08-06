# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex
# CRITICAL FIXES - Render all fixed section types properly

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  # ... existing code above ...

  # ============================================================================
  # SECTION RENDERING - FIXED FOR ALL BROKEN SECTION TYPES
  # ============================================================================

  def render_section_content(section, customization \\ %{}) do
    section_type = to_string(section.section_type)
    content = section.content || %{}

    IO.puts("🔧 Rendering section: #{section_type} with content keys: #{inspect(Map.keys(content))}")

    case section_type do
      # FIXED: Hero Section
      "hero" ->
        render_hero_content(content, customization)

      # Working sections (maintain existing)
      "intro" ->
        render_intro_content(content, customization)

      "contact" ->
        render_contact_content(content, customization)

      # FIXED: Gallery Section
      "gallery" ->
        render_gallery_content(content, customization)

      # FIXED: Blog Section
      "blog" ->
        render_blog_content(content, customization)

      # FIXED: All item-based sections
      "experience" ->
        render_experience_items_content(content, customization)

      "education" ->
        render_education_items_content(content, customization)

      "skills" ->
        render_skills_items_content(content, customization)

      "projects" ->
        render_projects_items_content(content, customization)

      "certifications" ->
        render_certifications_items_content(content, customization)

      "services" ->
        render_services_items_content(content, customization)

      "achievements" ->
        render_achievements_items_content(content, customization)

      "testimonials" ->
        render_testimonials_items_content(content, customization)

      "published_articles" ->
        render_published_articles_items_content(content, customization)

      "collaborations" ->
        render_collaborations_items_content(content, customization)

      "timeline" ->
        render_timeline_items_content(content, customization)

      "pricing" ->
        render_pricing_items_content(content, customization)

      "custom" ->
        render_custom_items_content(content, customization)

      # Fallback
      _ ->
        render_generic_content(content, customization)
    end
  end

  # Static version for compatibility with enhanced_layout_renderer.ex
  def render_section_content_static(section, customization \\ %{}) do
    render_section_content(section, customization)
  end

  # ============================================================================
  # FIXED: HERO SECTION RENDERING
  # ============================================================================

  defp render_hero_content(content, _customization) do
    headline = safe_map_get(content, "headline", "Welcome")
    tagline = safe_map_get(content, "tagline", "")
    description = safe_map_get(content, "description", "")
    cta_text = safe_map_get(content, "cta_text", "")
    cta_link = safe_map_get(content, "cta_link", "")
    social_links = Map.get(content, "social_links", %{})

    html = """
    <div class="hero-section py-20 text-center">
      <div class="max-w-4xl mx-auto">
        <h1 class="text-5xl font-bold text-gray-900 mb-4">#{safe_html_escape(headline)}</h1>
    """

    html = if safe_not_empty?(tagline) do
      html <> """
        <p class="text-xl text-gray-600 mb-6">#{safe_html_escape(tagline)}</p>
      """
    else
      html
    end

    html = if safe_not_empty?(description) do
      html <> """
        <p class="text-lg text-gray-700 mb-8 leading-relaxed">#{safe_html_escape(description)}</p>
      """
    else
      html
    end

    html = if safe_not_empty?(cta_text) and safe_not_empty?(cta_link) do
      html <> """
        <div class="mb-8">
          <a href="#{safe_html_escape(cta_link)}" class="inline-flex items-center px-8 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors">
            #{safe_html_escape(cta_text)}
          </a>
        </div>
      """
    else
      html
    end

    html = if map_size(social_links) > 0 do
      social_html = render_social_links_safe(social_links)
      html <> """
        <div class="flex justify-center space-x-6">
          #{social_html}
        </div>
      """
    else
      html
    end

    html <> """
      </div>
    </div>
    """
  end

  # ============================================================================
  # FIXED: GALLERY SECTION RENDERING
  # ============================================================================

  defp render_gallery_content(content, _customization) do
    display_style = safe_map_get(content, "display_style", "grid")
    items_per_row = safe_map_get(content, "items_per_row", "3")
    show_captions = Map.get(content, "show_captions", true)
    media_files = Map.get(content, "media_files", [])

    if length(media_files) == 0 do
      render_empty_state_safe("No media files added to gallery yet")
    else
      grid_class = case items_per_row do
        "2" -> "grid-cols-1 md:grid-cols-2"
        "3" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
        "4" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
        _ -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      end

      html = """
      <div class="gallery-section py-12">
        <div class="grid #{grid_class} gap-6">
      """

      media_html = media_files
      |> Enum.map(fn media_file ->
        render_media_item_safe(media_file, show_captions)
      end)
      |> Enum.join("")

      html <> media_html <> """
        </div>
      </div>
      """
    end
  end

  # ============================================================================
  # FIXED: BLOG SECTION RENDERING
  # ============================================================================

  defp render_blog_content(content, _customization) do
    blog_url = safe_map_get(content, "blog_url", "")
    auto_sync = Map.get(content, "auto_sync", false)
    max_posts = Map.get(content, "max_posts", 6)
    show_dates = Map.get(content, "show_dates", true)
    description = safe_map_get(content, "description", "")

    html = """
    <div class="blog-section py-12">
      <div class="text-center mb-8">
        <h3 class="text-2xl font-bold text-gray-900 mb-2">My Blog</h3>
    """

    html = if safe_not_empty?(description) do
      html <> """
        <p class="text-gray-600 mb-4">#{safe_html_escape(description)}</p>
      """
    else
      html
    end

    html = if safe_not_empty?(blog_url) do
      html <> """
        <div class="inline-flex items-center bg-blue-50 text-blue-700 px-4 py-2 rounded-lg">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path>
          </svg>
          <a href="#{safe_html_escape(blog_url)}" target="_blank" class="hover:underline">
            Visit My Blog
          </a>
        </div>
      """
    else
      html <> """
        <p class="text-gray-500">Blog URL will be displayed once configured</p>
      """
    end

    html <> """
      </div>
    </div>
    """
  end

  # ============================================================================
  # WORKING SECTIONS - MAINTAIN EXISTING FUNCTIONALITY
  # ============================================================================

  defp render_intro_content(content, _customization) do
    story = safe_map_get(content, "story", "")
    specialties = safe_map_get(content, "specialties", "")
    years_experience = Map.get(content, "years_experience", 0)
    current_focus = safe_map_get(content, "current_focus", "")
    fun_fact = safe_map_get(content, "fun_fact", "")

    html = """
    <div class="intro-section py-12">
      <div class="max-w-4xl mx-auto">
    """

    html = if safe_not_empty?(story) do
      html <> """
        <div class="prose prose-lg max-w-none mb-8">
          <p class="text-gray-700 leading-relaxed">#{safe_html_escape(story) |> String.replace("\n", "<br>")}</p>
        </div>
      """
    else
      html
    end

    # Enhanced details section
    enhanced_details = []

    enhanced_details = if safe_not_empty?(specialties) do
      enhanced_details ++ [{"Specialties", specialties}]
    else
      enhanced_details
    end

    enhanced_details = if years_experience > 0 do
      enhanced_details ++ [{"Experience", "#{years_experience} years"} ]
    else
      enhanced_details
    end

    enhanced_details = if safe_not_empty?(current_focus) do
      enhanced_details ++ [{"Current Focus", current_focus}]
    else
      enhanced_details
    end

    enhanced_details = if safe_not_empty?(fun_fact) do
      enhanced_details ++ [{"Fun Fact", fun_fact}]
    else
      enhanced_details
    end

    html = if length(enhanced_details) > 0 do
      details_html = enhanced_details
      |> Enum.map(fn {label, value} ->
        """
        <div class="bg-white rounded-lg p-4 border border-gray-200">
          <h4 class="font-semibold text-gray-900 mb-2">#{label}</h4>
          <p class="text-gray-700">#{safe_html_escape(value)}</p>
        </div>
        """
      end)
      |> Enum.join("")

      html <> """
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-8">
          #{details_html}
        </div>
      """
    else
      html
    end

    html <> """
      </div>
    </div>
    """
  end

  defp render_contact_content(content, _customization) do
    email = safe_map_get(content, "email", "")
    phone = safe_map_get(content, "phone", "")
    location = safe_map_get(content, "location", "")
    website = safe_map_get(content, "website", "")
    availability = safe_map_get(content, "availability", "")
    social_links = Map.get(content, "social_links", %{})

    html = """
    <div class="contact-section py-12">
      <div class="max-w-4xl mx-auto">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div class="space-y-4">
    """

    # Contact methods
    contact_methods = []

    contact_methods = if safe_not_empty?(email) do
      contact_methods ++ [{"email", "Email", email, "mailto:#{email}"}]
    else
      contact_methods
    end

    contact_methods = if safe_not_empty?(phone) do
      contact_methods ++ [{"phone", "Phone", phone, "tel:#{phone}"}]
    else
      contact_methods
    end

    contact_methods = if safe_not_empty?(location) do
      contact_methods ++ [{"location", "Location", location, nil}]
    else
      contact_methods
    end

    contact_methods = if safe_not_empty?(website) do
      contact_methods ++ [{"website", "Website", website, website}]
    else
      contact_methods
    end

    contact_html = contact_methods
    |> Enum.map(fn {type, label, value, link} ->
      icon = case type do
        "email" ->
          ~s(<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.44a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/></svg>)
        "phone" ->
          ~s(<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/></svg>)
        "location" ->
          ~s(<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/></svg>)
        "website" ->
          ~s(<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>)
        _ -> ""
      end

      content_elem = if link do
        ~s(<a href="#{safe_html_escape(link)}" class="text-blue-600 hover:text-blue-700">#{safe_html_escape(value)}</a>)
      else
        ~s(<span class="text-gray-700">#{safe_html_escape(value)}</span>)
      end

      """
      <div class="flex items-center space-x-3 p-3 bg-white rounded-lg border border-gray-200">
        <div class="text-gray-500">#{icon}</div>
        <div>
          <div class="text-sm text-gray-500">#{label}</div>
          #{content_elem}
        </div>
      </div>
      """
    end)
    |> Enum.join("")

    html = html <> contact_html <> """
          </div>
          <div>
    """

    html = if safe_not_empty?(availability) do
      html <> """
        <div class="bg-green-50 rounded-lg p-4 border border-green-200 mb-6">
          <h4 class="font-semibold text-green-800 mb-2">Availability</h4>
          <p class="text-green-700">#{safe_html_escape(availability)}</p>
        </div>
      """
    else
      html
    end

    html = if map_size(social_links) > 0 do
      social_html = render_social_links_safe(social_links)
      html <> """
        <div>
          <h4 class="font-semibold text-gray-900 mb-4">Connect with me</h4>
          <div class="flex flex-wrap gap-2">
            #{social_html}
          </div>
        </div>
      """
    else
      html
    end

    html <> """
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_experience_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No work experience added yet")
    else
      # Remove centered title/description, make scrollable
      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_experience_item_safe/1)
      |> Enum.join("")

      """
      <div class="experience-section">
        <div class="space-y-4 max-h-96 overflow-y-auto">
          #{items_html}
        </div>
      </div>
      """
    end
  end

  defp render_education_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No education entries added yet")
    else
      html = """
      <div class="education-section space-y-6 py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Education</h3>
          <p class="text-gray-600">Academic background and qualifications</p>
        </div>
        <div class="space-y-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_education_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_skills_items_content(content, customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No skills added yet")
    else
      # Get user's primary color from customization
      user_primary_color = Map.get(customization, "primary_color", "#EC4899")

      # Color palette with user's primary color first
      color_palette = [
        user_primary_color,
        "#8B5CF6",  # Purple-500
        "#06B6D4",  # Cyan-500
        "#10B981",  # Emerald-500
        "#F59E0B",  # Amber-500
        "#EF4444",  # Red-500
        "#6366F1"   # Indigo-500
      ]

      # Group skills by category and assign colors
      grouped_skills = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.group_by(fn item -> Map.get(item, "category", "technical") end)

      categories_with_colors = grouped_skills
      |> Map.keys()
      |> Enum.with_index()
      |> Enum.into(%{}, fn {category, index} ->
        color = Enum.at(color_palette, rem(index, length(color_palette)))
        {category, color}
      end)

      skills_html = grouped_skills
      |> Enum.flat_map(fn {category, category_skills} ->
        base_color = Map.get(categories_with_colors, category)
        Enum.map(category_skills, fn skill ->
          render_skill_pill_safe(skill, base_color)
        end)
      end)
      |> Enum.join("")

      """
      <div class="skills-section">
        <div class="flex flex-wrap gap-2 max-h-64 overflow-y-auto">
          #{skills_html}
        </div>
      </div>
      """
    end
  end

  defp render_projects_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No projects added yet")
    else
      html = """
      <div class="projects-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">My Projects</h3>
          <p class="text-gray-600">Featured work and portfolio pieces</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_project_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  # ============================================================================
  # WORKING SECTION ITEM RENDERERS
  # ============================================================================

  defp render_experience_item_safe(item) do
    title = safe_map_get(item, "title", "")
    company = safe_map_get(item, "company", "")
    description = safe_map_get(item, "description", "")
    start_date = safe_map_get(item, "start_date", "")
    end_date = safe_map_get(item, "end_date", "")

    date_range = case {start_date, end_date} do
      {"", ""} -> ""
      {start, ""} -> start
      {"", finish} -> "Until #{finish}"
      {start, "Present"} -> "#{start} - Present"
      {start, finish} -> "#{start} - #{finish}"
    end

    """
    <div class="bg-white rounded-lg p-6 border border-gray-200">
      <div class="flex justify-between items-start mb-3">
        <div>
          <h4 class="text-lg font-semibold text-gray-900">#{safe_html_escape(title)}</h4>
          <div class="text-blue-600 font-medium">#{safe_html_escape(company)}</div>
        </div>
        #{if date_range != "" do
          "<span class=\"inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-700\">#{safe_html_escape(date_range)}</span>"
        else
          ""
        end}
      </div>
      #{if safe_not_empty?(description) do
        "<p class=\"text-gray-700 leading-relaxed\">#{safe_html_escape(description)}</p>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_education_item_safe(item) do
    degree = safe_map_get(item, "degree", "")
    institution = safe_map_get(item, "institution", "")
    description = safe_map_get(item, "description", "")
    start_date = safe_map_get(item, "start_date", "")
    graduation_date = safe_map_get(item, "graduation_date", "")

    date_range = case {start_date, graduation_date} do
      {"", ""} -> ""
      {start, ""} -> start
      {"", finish} -> "Graduated #{finish}"
      {start, finish} -> "#{start} - #{finish}"
    end

    """
    <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-green-500">
      <div class="flex justify-between items-start mb-3">
        <div>
          <h4 class="text-lg font-semibold text-gray-900">#{safe_html_escape(degree)}</h4>
          <div class="text-green-600 font-medium">#{safe_html_escape(institution)}</div>
        </div>
        #{if date_range != "" do
          "<div class=\"text-sm text-gray-500\">#{safe_html_escape(date_range)}</div>"
        else
          ""
        end}
      </div>
      #{if safe_not_empty?(description) do
        "<p class=\"text-gray-700 leading-relaxed\">#{safe_html_escape(description)}</p>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_skill_pill_safe(item, base_color) do
    name = safe_map_get(item, "name", "")
    level = safe_map_get(item, "level", "intermediate")
    years_experience = safe_map_get(item, "years_experience", "")

    # Calculate opacity based on proficiency level
    opacity = case level do
      "beginner" -> "0.5"
      "intermediate" -> "0.7"
      "advanced" -> "0.85"
      "expert" -> "1.0"
      _ -> "0.7"
    end

    # Create the pill with dynamic color and opacity
    experience_text = if safe_not_empty?(years_experience) do
      " (#{years_experience}y)"
    else
      ""
    end

    """
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium text-white"
          style="background-color: #{base_color}; opacity: #{opacity};"
          title="#{String.capitalize(level)} level#{experience_text}">
      #{safe_html_escape(name)}
    </span>
    """
  end

  defp render_project_item_safe(item) do
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    technologies = safe_map_get(item, "technologies", "")
    url = safe_map_get(item, "url", "")
    github_url = safe_map_get(item, "github_url", "")

    """
    <div class="bg-white rounded-lg shadow-md overflow-hidden hover:shadow-lg transition-shadow">
      <div class="p-6">
        <h4 class="text-lg font-semibold text-gray-900 mb-3">#{safe_html_escape(title)}</h4>
        #{if safe_not_empty?(description) do
          "<p class=\"text-gray-700 mb-4 leading-relaxed\">#{safe_html_escape(description)}</p>"
        else
          ""
        end}
        #{if safe_not_empty?(technologies) do
          tech_list = String.split(technologies, ",") |> Enum.map(&String.trim/1)
          tech_html = Enum.map(tech_list, fn tech ->
            "<span class=\"inline-block bg-blue-100 text-blue-700 text-xs px-2 py-1 rounded mr-2 mb-2\">#{safe_html_escape(tech)}</span>"
          end) |> Enum.join("")
          "<div class=\"mb-4\">#{tech_html}</div>"
        else
          ""
        end}
        <div class="flex space-x-3">
          #{if safe_not_empty?(url) do
            "<a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"inline-flex items-center px-3 py-2 bg-blue-600 text-white text-sm font-medium rounded hover:bg-blue-700 transition-colors\">
              <svg class=\"w-4 h-4 mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
                <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/>
              </svg>
              View Project
            </a>"
          else
            ""
          end}
          #{if safe_not_empty?(github_url) do
            "<a href=\"#{safe_html_escape(github_url)}\" target=\"_blank\" class=\"inline-flex items-center px-3 py-2 bg-gray-800 text-white text-sm font-medium rounded hover:bg-gray-900 transition-colors\">
              <svg class=\"w-4 h-4 mr-1\" fill=\"currentColor\" viewBox=\"0 0 20 20\">
                <path fill-rule=\"evenodd\" d=\"M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z\" clip-rule=\"evenodd\"/>
              </svg>
              Code
            </a>"
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # FIXED: ITEMS-BASED SECTION RENDERERS
  # ============================================================================

  defp render_certifications_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No certifications added yet")
    else
      html = """
      <div class="certifications-section space-y-6 py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Certifications</h3>
          <p class="text-gray-600">Professional certifications and credentials</p>
        </div>
        <div class="space-y-4">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_certification_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_achievements_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No achievements added yet")
    else
      html = """
      <div class="achievements-section space-y-6 py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Achievements & Awards</h3>
          <p class="text-gray-600">Recognition and major accomplishments</p>
        </div>
        <div class="space-y-4">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_achievement_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_testimonials_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No testimonials added yet")
    else
      html = """
      <div class="testimonials-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">What People Say</h3>
          <p class="text-gray-600">Client feedback and recommendations</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_testimonial_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_services_items_content(content, _customization) do
    items = Map.get(content, "items", [])
    service_style = safe_map_get(content, "service_style", "cards")
    show_pricing = Map.get(content, "show_pricing", false)

    if length(items) == 0 do
      render_empty_state_safe("No services added yet")
    else
      html = """
      <div class="services-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Services</h3>
          <p class="text-gray-600">What I can help you with</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(fn item -> render_service_item_safe(item, show_pricing) end)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_published_articles_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No articles added yet")
    else
      html = """
      <div class="articles-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Publications & Writing</h3>
          <p class="text-gray-600">Articles, blog posts, and written content</p>
        </div>
        <div class="space-y-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_article_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_collaborations_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No collaborations added yet")
    else
      html = """
      <div class="collaborations-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Collaborations</h3>
          <p class="text-gray-600">Partnerships and joint projects</p>
        </div>
        <div class="space-y-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_collaboration_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_timeline_items_content(content, _customization) do
    items = Map.get(content, "items", [])
    timeline_type = safe_map_get(content, "timeline_type", "reverse_chronological")
    show_dates = Map.get(content, "show_dates", true)

    if length(items) == 0 do
      render_empty_state_safe("No timeline events added yet")
    else
      # Sort items based on timeline type
      sorted_items = case timeline_type do
        "chronological" -> Enum.sort_by(items, &Map.get(&1, "date", ""), :asc)
        "reverse_chronological" -> Enum.sort_by(items, &Map.get(&1, "date", ""), :desc)
        _ -> items
      end

      html = """
      <div class="timeline-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">My Journey</h3>
          <p class="text-gray-600">Career milestones and important events</p>
        </div>
        <div class="relative">
          <div class="absolute left-1/2 transform -translate-x-1/2 w-0.5 h-full bg-gray-300"></div>
          <div class="space-y-8">
      """

      items_html = sorted_items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.with_index()
      |> Enum.map(fn {item, index} -> render_timeline_item_safe(item, index, show_dates) end)
      |> Enum.join("")

      html <> items_html <> """
          </div>
        </div>
      </div>
      """
    end
  end

  defp render_pricing_items_content(content, _customization) do
    items = Map.get(content, "items", [])
    currency = safe_map_get(content, "currency", "USD")

    if length(items) == 0 do
      render_empty_state_safe("No pricing packages added yet")
    else
      html = """
      <div class="pricing-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Pricing</h3>
          <p class="text-gray-600">Choose the package that works for you</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(fn item -> render_pricing_item_safe(item, currency) end)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_custom_items_content(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No custom content added yet")
    else
      html = """
      <div class="custom-section py-12">
        <div class="space-y-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_custom_item_safe/1)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  # ============================================================================
  # ITEM RENDERERS - COMPLETE FOR ALL NEW SECTION TYPES
  # ============================================================================

  defp render_certification_item_safe(item) do
    name = safe_map_get(item, "name", "")
    issuer = safe_map_get(item, "issuer", "")
    issue_date = safe_map_get(item, "issue_date", "")
    expiry_date = safe_map_get(item, "expiry_date", "")
    credential_id = safe_map_get(item, "credential_id", "")
    verification_url = safe_map_get(item, "verification_url", "")

    html = """
    <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-yellow-500">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-1">#{safe_html_escape(name)}</h4>
          <div class="text-blue-600 font-medium mb-2">#{safe_html_escape(issuer)}</div>
    """

    html = if safe_not_empty?(issue_date) do
      expiry_text = if safe_not_empty?(expiry_date) do
        " - #{expiry_date}"
      else
        ""
      end
      html <> """
        <div class="text-sm text-gray-500 mb-2">
          <span class="inline-flex items-center">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
            #{safe_html_escape(issue_date)}#{expiry_text}
          </span>
        </div>
      """
    else
      html
    end

    html = if safe_not_empty?(credential_id) do
      html <> """
        <div class="text-xs text-gray-400">
          Credential ID: #{safe_html_escape(credential_id)}
        </div>
      """
    else
      html
    end

    html = html <> """
        </div>
    """

    html = if safe_not_empty?(verification_url) do
      html <> """
        <div class="flex-shrink-0 ml-4">
          <a href="#{safe_html_escape(verification_url)}" target="_blank"
             class="inline-flex items-center px-3 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full hover:bg-blue-200">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
            Verify
          </a>
        </div>
      """
    else
      html
    end

    html <> """
      </div>
    </div>
    """
  end

  defp render_achievement_item_safe(item) do
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    date = safe_map_get(item, "date", "")
    type = safe_map_get(item, "type", "award")
    organization = safe_map_get(item, "organization", "")

    type_icon = case type do
      "award" -> "🏆"
      "recognition" -> "🌟"
      "milestone" -> "📍"
      "publication" -> "📝"
      _ -> "🏅"
    end

    """
    <div class="bg-white rounded-lg shadow-md p-6 border-l-4 border-yellow-400">
      <div class="flex items-start">
        <div class="text-2xl mr-4 mt-1">#{type_icon}</div>
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(title)}</h4>
          #{if safe_not_empty?(organization) do
            "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(organization)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(date) do
            "<div class=\"text-sm text-gray-500 mb-2\">#{safe_html_escape(date)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(description) do
            "<p class=\"text-gray-700 leading-relaxed\">#{safe_html_escape(description)}</p>"
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end

  defp render_testimonial_item_safe(item) do
    name = safe_map_get(item, "name", "")
    title_company = safe_map_get(item, "title_company", "")
    testimonial = safe_map_get(item, "testimonial", "")
    rating = safe_map_get(item, "rating", "")
    project = safe_map_get(item, "project", "")

    rating_html = case rating do
      "5" -> "★★★★★"
      "4" -> "★★★★☆"
      "3" -> "★★★☆☆"
      "2" -> "★★☆☆☆"
      "1" -> "★☆☆☆☆"
      _ -> ""
    end

    """
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex items-center mb-4">
        <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center mr-4">
          <span class="text-gray-500 font-semibold">#{String.first(name)}</span>
        </div>
        <div>
          <h5 class="font-semibold text-gray-900">#{safe_html_escape(name)}</h5>
          #{if safe_not_empty?(title_company) do
            "<p class=\"text-sm text-gray-600\">#{safe_html_escape(title_company)}</p>"
          else
            ""
          end}
        </div>
      </div>

      #{if rating_html != "" do
        "<div class=\"text-yellow-400 mb-3\">#{rating_html}</div>"
      else
        ""
      end}

      #{if safe_not_empty?(testimonial) do
        "<blockquote class=\"text-gray-700 italic mb-3\">\"#{safe_html_escape(testimonial)}\"</blockquote>"
      else
        ""
      end}

      #{if safe_not_empty?(project) do
        "<div class=\"text-xs text-gray-500\">Project: #{safe_html_escape(project)}</div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_service_item_safe(item, show_pricing) do
    name = safe_map_get(item, "name", "")
    description = safe_map_get(item, "description", "")
    price = safe_map_get(item, "price", "")
    duration = safe_map_get(item, "duration", "")
    category = safe_map_get(item, "category", "")

    """
    <div class="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div class="text-center">
        <h4 class="text-xl font-semibold text-gray-900 mb-3">#{safe_html_escape(name)}</h4>
        #{if safe_not_empty?(category) do
          "<div class=\"inline-block bg-blue-100 text-blue-700 text-xs font-medium px-2 py-1 rounded-full mb-3\">#{safe_html_escape(String.capitalize(category))}</div>"
        else
          ""
        end}
        #{if safe_not_empty?(description) do
          "<p class=\"text-gray-600 mb-4\">#{safe_html_escape(description)}</p>"
        else
          ""
        end}
        #{if show_pricing and safe_not_empty?(price) do
          "<div class=\"text-2xl font-bold text-blue-600 mb-2\">#{safe_html_escape(price)}</div>"
        else
          ""
        end}
        #{if safe_not_empty?(duration) do
          "<div class=\"text-sm text-gray-500\">#{safe_html_escape(duration)}</div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end

  defp render_article_item_safe(item) do
    title = safe_map_get(item, "title", "")
    publication = safe_map_get(item, "publication", "")
    date = safe_map_get(item, "date", "")
    url = safe_map_get(item, "url", "")
    summary = safe_map_get(item, "summary", "")
    tags = safe_map_get(item, "tags", "")

    """
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(title)}</h4>
          #{if safe_not_empty?(publication) do
            "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(publication)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(date) do
            "<div class=\"text-sm text-gray-500 mb-3\">#{safe_html_escape(date)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(summary) do
            "<p class=\"text-gray-700 mb-3\">#{safe_html_escape(summary)}</p>"
          else
            ""
          end}
          #{if safe_not_empty?(tags) do
            tags_list = String.split(tags, ",") |> Enum.map(&String.trim/1)
            tags_html = Enum.map(tags_list, fn tag ->
              "<span class=\"inline-block bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded mr-2 mb-1\">#{safe_html_escape(tag)}</span>"
            end) |> Enum.join("")
            "<div class=\"mb-3\">#{tags_html}</div>"
          else
            ""
          end}
        </div>
        #{if safe_not_empty?(url) do
          "<div class=\"ml-4\">
            <a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-700\">
              <svg class=\"w-5 h-5\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
                <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/>
              </svg>
            </a>
          </div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end

  defp render_collaboration_item_safe(item) do
    title = safe_map_get(item, "title", "")
    partner = safe_map_get(item, "partner", "")
    role = safe_map_get(item, "role", "")
    date = safe_map_get(item, "date", "")
    description = safe_map_get(item, "description", "")

    """
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex items-start">
        <div class="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4 flex-shrink-0">
          <span class="text-purple-600 text-lg">🤝</span>
        </div>
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(title)}</h4>
          #{if safe_not_empty?(partner) do
            "<div class=\"text-blue-600 font-medium mb-1\">Partner: #{safe_html_escape(partner)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(role) do
            "<div class=\"text-sm text-gray-600 mb-2\">Role: #{safe_html_escape(role)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(date) do
            "<div class=\"text-sm text-gray-500 mb-3\">#{safe_html_escape(date)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(description) do
            "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end

  defp render_timeline_item_safe(item, index, show_dates) do
    title = safe_map_get(item, "title", "")
    date = safe_map_get(item, "date", "")
    type = safe_map_get(item, "type", "career")
    location = safe_map_get(item, "location", "")
    description = safe_map_get(item, "description", "")

    is_left = rem(index, 2) == 0
    alignment_class = if is_left, do: "mr-auto pr-8", else: "ml-auto pl-8"

    type_color = case type do
      "career" -> "bg-blue-500"
      "education" -> "bg-green-500"
      "project" -> "bg-purple-500"
      "achievement" -> "bg-yellow-500"
      "personal" -> "bg-pink-500"
      _ -> "bg-gray-500"
    end

    """
    <div class="relative flex #{if is_left, do: "justify-start", else: "justify-end"}">
      <div class="absolute left-1/2 transform -translate-x-1/2 w-4 h-4 #{type_color} rounded-full border-4 border-white shadow"></div>
      <div class="w-1/2 #{alignment_class}">
        <div class="bg-white rounded-lg shadow-md p-4">
          <h4 class="font-semibold text-gray-900 mb-1">#{safe_html_escape(title)}</h4>
          #{if show_dates and safe_not_empty?(date) do
            "<div class=\"text-sm text-gray-600 mb-2\">#{safe_html_escape(date)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(location) do
            "<div class=\"text-sm text-gray-500 mb-2\">#{safe_html_escape(location)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(description) do
            "<p class=\"text-gray-700 text-sm\">#{safe_html_escape(description)}</p>"
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end

  defp render_pricing_item_safe(item, currency) do
    name = safe_map_get(item, "name", "")
    description = safe_map_get(item, "description", "")
    price = safe_map_get(item, "price", "")
    features = safe_map_get(item, "features", "")
    popular = Map.get(item, "popular", false)

    popular_badge = if popular do
      "<div class=\"absolute -top-3 left-1/2 transform -translate-x-1/2\">
        <span class=\"bg-blue-600 text-white text-xs font-bold px-3 py-1 rounded-full\">Most Popular</span>
      </div>"
    else
      ""
    end

    border_class = if popular, do: "border-blue-500 border-2", else: "border-gray-200"

    """
    <div class="relative bg-white rounded-lg shadow-md border #{border_class} p-6">
      #{popular_badge}
      <div class="text-center">
        <h4 class="text-xl font-semibold text-gray-900 mb-3">#{safe_html_escape(name)}</h4>
        #{if safe_not_empty?(price) do
          "<div class=\"text-3xl font-bold text-blue-600 mb-4\">
            <span class=\"text-sm text-gray-500\">#{currency}</span>#{safe_html_escape(price)}
          </div>"
        else
          ""
        end}
        #{if safe_not_empty?(description) do
          "<p class=\"text-gray-600 mb-4\">#{safe_html_escape(description)}</p>"
        else
          ""
        end}
        #{if safe_not_empty?(features) do
          features_list = String.split(features, ",") |> Enum.map(&String.trim/1)
          features_html = Enum.map(features_list, fn feature ->
            "<div class=\"flex items-center justify-center mb-2\">
              <svg class=\"w-4 h-4 text-green-500 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
                <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 13l4 4L19 7\"/>
              </svg>
              <span class=\"text-sm text-gray-700\">#{safe_html_escape(feature)}</span>
            </div>"
          end) |> Enum.join("")
          "<div class=\"mb-4\">#{features_html}</div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end

  defp render_custom_item_safe(item) do
    title = safe_map_get(item, "title", "")
    subtitle = safe_map_get(item, "subtitle", "")
    content = safe_map_get(item, "content", "")
    url = safe_map_get(item, "url", "")
    date = safe_map_get(item, "date", "")

    """
    <div class="bg-white rounded-lg shadow-md p-6">
      <div class="flex justify-between items-start">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(title)}</h4>
          #{if safe_not_empty?(subtitle) do
            "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(subtitle)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(date) do
            "<div class=\"text-sm text-gray-500 mb-3\">#{safe_html_escape(date)}</div>"
          else
            ""
          end}
          #{if safe_not_empty?(content) do
            "<div class=\"text-gray-700 prose prose-sm max-w-none\">
              #{safe_html_escape(content) |> String.replace("\n", "<br>")}
            </div>"
          else
            ""
          end}
        </div>
        #{if safe_not_empty?(url) do
          "<div class=\"ml-4\">
            <a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-700\">
              <svg class=\"w-5 h-5\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
                <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/>
              </svg>
            </a>
          </div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS - MEDIA AND UTILITY
  # ============================================================================

  defp render_media_item_safe(media_file, show_captions) do
    case media_file do
      %{file_type: file_type, filename: filename} when is_binary(file_type) ->
        cond do
          String.starts_with?(file_type, "image/") ->
            render_image_media_safe(media_file, show_captions)
          String.starts_with?(file_type, "video/") ->
            render_video_media_safe(media_file, show_captions)
          true ->
            render_generic_media_safe(media_file, show_captions)
        end
      _ ->
        """
        <div class="bg-gray-100 rounded-lg p-4 text-center">
          <p class="text-gray-500">Invalid media file</p>
        </div>
        """
    end
  end

  defp render_image_media_safe(media_file, show_captions) do
    filename = safe_map_get(media_file, :filename, "image.jpg")
    caption = safe_map_get(media_file, :caption, "")
    alt_text = safe_map_get(media_file, :alt_text, filename)
    file_path = safe_map_get(media_file, :file_path, "")

    """
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="aspect-w-16 aspect-h-9">
        <img src="/uploads/#{safe_html_escape(file_path)}"
             alt="#{safe_html_escape(alt_text)}"
             class="w-full h-full object-cover">
      </div>
      #{if show_captions and safe_not_empty?(caption) do
        "<div class=\"p-4\">
          <p class=\"text-sm text-gray-700\">#{safe_html_escape(caption)}</p>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_video_media_safe(media_file, show_captions) do
    filename = safe_map_get(media_file, :filename, "video.mp4")
    caption = safe_map_get(media_file, :caption, "")
    file_path = safe_map_get(media_file, :file_path, "")

    """
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="aspect-w-16 aspect-h-9">
        <video controls class="w-full h-full object-cover">
          <source src="/uploads/#{safe_html_escape(file_path)}" type="video/mp4">
          Your browser does not support the video tag.
        </video>
      </div>
      #{if show_captions and safe_not_empty?(caption) do
        "<div class=\"p-4\">
          <p class=\"text-sm text-gray-700\">#{safe_html_escape(caption)}</p>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_generic_media_safe(media_file, _show_captions) do
    filename = safe_map_get(media_file, :filename, "file")
    file_type = safe_map_get(media_file, :file_type, "")

    icon = cond do
      String.contains?(file_type, "pdf") -> "📄"
      String.contains?(file_type, "word") -> "📝"
      String.contains?(file_type, "excel") -> "📊"
      true -> "📁"
    end

    """
    <div class="bg-white rounded-lg shadow-md p-6 text-center">
      <div class="text-4xl mb-2">#{icon}</div>
      <p class="text-sm font-medium text-gray-900">#{safe_html_escape(filename)}</p>
      <p class="text-xs text-gray-500">#{safe_html_escape(file_type)}</p>
    </div>
    """
  end

  defp render_social_links_safe(social_links) do
    social_platforms = [
      {"linkedin", "LinkedIn", "#0077B5"},
      {"twitter", "Twitter", "#1DA1F2"},
      {"github", "GitHub", "#333"},
      {"website", "Website", "#6B7280"},
      {"instagram", "Instagram", "#E4405F"},
      {"facebook", "Facebook", "#1877F2"}
    ]

    social_platforms
    |> Enum.filter(fn {platform, _, _} ->
      link = Map.get(social_links, platform, "")
      safe_not_empty?(link)
    end)
    |> Enum.map(fn {platform, name, color} ->
      link = Map.get(social_links, platform)
      """
      <a href="#{safe_html_escape(link)}" target="_blank"
         class="inline-flex items-center px-4 py-2 rounded-lg text-white hover:opacity-90 transition-opacity"
         style="background-color: #{color}">
        #{name}
      </a>
      """
    end)
    |> Enum.join("")
  end

  defp render_empty_state_safe(message) do
    """
    <div class="text-center py-12">
      <div class="w-16 h-16 mx-auto mb-4 bg-gray-100 rounded-full flex items-center justify-center">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
      </div>
      <p class="text-gray-500">#{safe_html_escape(message)}</p>
    </div>
    """
  end

  defp render_generic_content(content, _customization) do
    description = safe_map_get(content, "description", "")
    items = Map.get(content, "items", [])

    html = """
    <div class="generic-section py-12">
    """

    html = if safe_not_empty?(description) do
      html <> """
        <div class="text-center mb-8">
          <p class="text-gray-600">#{safe_html_escape(description)}</p>
        </div>
      """
    else
      html
    end

    html = if length(items) > 0 do
      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(&render_custom_item_safe/1)
      |> Enum.join("")

      html <> """
        <div class="space-y-6">
          #{items_html}
        </div>
      """
    else
      html <> render_empty_state_safe("No content added yet")
    end

    html <> """
    </div>
    """
  end

  # ============================================================================
  # UTILITY FUNCTIONS - MAINTAIN EXISTING SAFETY
  # ============================================================================

  defp safe_extract({:safe, content}) when is_binary(content), do: content
  defp safe_extract(content) when is_binary(content), do: content
  defp safe_extract(_), do: ""

  defp safe_map_get(map, key, default \\ "") when is_map(map) do
    case Map.get(map, key, default) do
      {:safe, content} -> content
      content when is_binary(content) -> content
      _ -> default
    end
  end

  defp safe_html_escape(content) when is_binary(content) do
    content
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp safe_not_empty?(content) when is_binary(content) do
    String.trim(content) != ""
  end
  defp safe_not_empty?(_), do: false

end
