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


  def should_render_section?(section) do
    case to_string(section.section_type) do
      # Field-based sections (always show if section is visible)
      type when type in ["hero", "intro", "contact"] ->
        Map.get(section, :visible, true)

      # Item-based sections (only show if has visible items)
      type when type in ["experience", "education", "skills", "projects", "certifications",
                        "services", "achievements", "testimonials", "published_articles",
                        "collaborations", "timeline", "pricing", "code_showcase"] ->
        section_visible = Map.get(section, :visible, true)
        has_visible_items = has_visible_items?(section)

        section_visible and has_visible_items

      # Default: show if section is visible
      _ ->
        Map.get(section, :visible, true)
    end
  end

  defp has_visible_items?(section) do
    items = get_in(section.content, ["items"]) || []

    visible_items = Enum.filter(items, fn item ->
      Map.get(item, "visible", true)
    end)

    length(visible_items) > 0
  end

  defp filter_visible_sections(sections) do
    sections
    |> Enum.filter(&should_render_section?/1)
  end

  # Update enhanced_layout_renderer.ex to use the new filtering
  defp normalize_sections_for_rendering(sections) do
    sections
    |> Enum.filter(fn section ->
      section && Map.get(section, :id) && Map.get(section, :title)
    end)
    |> Enum.map(&normalize_section_data/1)
    |> Enum.filter(&should_render_section?/1)  # Add this line
  end

  # Add this function to enhanced_section_renderer.ex
  defp normalize_section_data(section) do
    section
    |> Map.put_new(:content, %{})
    |> Map.put_new(:section_type, "custom")
    |> Map.put_new(:title, "Untitled Section")
    |> Map.put_new(:visible, true)
    |> ensure_section_structure()
  end

  # Helper function to ensure proper section structure
  defp ensure_section_structure(section) do
    # Normalize section_type to string for consistency
    section_type = case Map.get(section, :section_type) do
      atom when is_atom(atom) -> to_string(atom)
      string when is_binary(string) -> string
      _ -> "custom"
    end

    # Ensure content is a map
    content = case Map.get(section, :content) do
      map when is_map(map) -> map
      _ -> %{}
    end

    section
    |> Map.put(:section_type, section_type)
    |> Map.put(:content, content)
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

  # CRITICAL: Skills section with user's color palette
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

  # Add this function to enhanced_section_renderer.ex
defp get_user_primary_color(customization) do
  # Extract user's primary color from customization or use default
  case customization do
    %{} = custom when is_map(custom) ->
      Map.get(custom, "primary_color", "#3B82F6")
    _ ->
      "#3B82F6"  # Default blue
  end
end

defp render_skills_categorized_with_colors(items, show_categories, user_primary_color) do
  visible_items = Enum.filter(items, fn item -> Map.get(item, "visible", true) end)

  # Define color palette with user's primary color first
  color_palette = [
    user_primary_color,  # User's primary color
    "#8B5CF6",          # Purple-500
    "#06B6D4",          # Cyan-500
    "#10B981",          # Emerald-500
    "#F59E0B",          # Amber-500
    "#EF4444",          # Red-500
    "#6366F1"           # Indigo-500
  ]

  # Group by category and assign colors
  grouped_skills = visible_items
  |> Enum.group_by(fn item -> Map.get(item, "category", "General") end)
  |> Enum.with_index()

  html = """
  <div class="skills-section py-12">
    <div class="text-center mb-8">
      <h3 class="text-2xl font-bold text-gray-900 mb-2">Skills & Expertise</h3>
      <p class="text-gray-600">Technologies and tools I work with</p>
    </div>
    <div class="space-y-6">
  """

  categories_html = grouped_skills
  |> Enum.map(fn {{category, skills}, color_index} ->
    # Get color for this category (cycle through palette)
    category_color = Enum.at(color_palette, rem(color_index, length(color_palette)))

    # Subtle category header with color accent
    category_header = if show_categories and category != "General" do
      "<h4 class=\"text-sm font-medium text-gray-500 uppercase tracking-wide mb-3 border-b-2 pb-1\" style=\"border-color: #{category_color};\">#{safe_html_escape(category)}</h4>"
    else
      ""
    end

    skills_html = grouped_skills


    "<div class=\"mb-6\">#{category_header}<div class=\"flex flex-wrap gap-2\">#{skills_html}</div></div>"
  end)
  |> Enum.join("")

  html <> categories_html <> """
    </div>
  </div>
  """
end

defp get_skill_colors_by_level(base_color, level) do
  case level do
    "beginner" ->
      # Very light shade
      {lighten_color(base_color, 0.9), darken_color(base_color, 0.3), lighten_color(base_color, 0.7)}

    "intermediate" ->
      # Medium light shade
      {lighten_color(base_color, 0.7), darken_color(base_color, 0.2), lighten_color(base_color, 0.5)}

    "advanced" ->
      # Medium shade
      {lighten_color(base_color, 0.5), "#ffffff", base_color}

    "expert" ->
      # Dark shade
      {darken_color(base_color, 0.2), "#ffffff", darken_color(base_color, 0.1)}

    _ ->
      # Default intermediate
      {lighten_color(base_color, 0.7), darken_color(base_color, 0.2), lighten_color(base_color, 0.5)}
  end
end

defp get_level_indicator(level) do
  case level do
    "beginner" -> "●"
    "intermediate" -> "●●"
    "advanced" -> "●●●"
    "expert" -> "●●●●"
    _ -> "●●"
  end
end

# Color manipulation helpers
defp lighten_color(hex_color, amount) do
  # Simple color lightening - would need proper color manipulation library
  # This is a placeholder that returns increasingly lighter versions
  case amount do
    x when x >= 0.9 -> "#F8FAFC"  # Very light
    x when x >= 0.7 -> "#F1F5F9"  # Light
    x when x >= 0.5 -> "#E2E8F0"  # Medium light
    _ -> hex_color
  end
end

defp darken_color(hex_color, amount) do
  # Simple color darkening - placeholder implementation
  case amount do
    x when x >= 0.3 -> "#1E293B"  # Dark
    x when x >= 0.2 -> "#334155"  # Medium dark
    x when x >= 0.1 -> "#475569"  # Slightly dark
    _ -> hex_color
  end
end

  defp render_projects_items_content(content, customization) do
    items = Map.get(content, "items", [])
    display_style = Map.get(customization, "projects_display", "rows")

    if length(items) == 0 do
      render_empty_state_safe("No projects added yet")
    else
      html = """
      <div class="projects-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Projects</h3>
          <p class="text-gray-600">A showcase of my recent work</p>
        </div>
        <!-- FIXED: Single column layout using space-y-4 -->
        <div class="space-y-4">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(fn item -> render_project_item_safe(item) end)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end


  defp render_code_showcase_items_content(content, _customization) do
    items = Map.get(content, "items", [])
    primary_language = Map.get(content, "primary_language", "JavaScript")
    repository_url = Map.get(content, "repository_url", "")
    show_stats = Map.get(content, "show_stats", true)

    if length(items) == 0 do
      render_empty_state_safe("No code samples added yet")
    else
      html = """
      <div class="code-showcase-section py-12">
        <div class="text-center mb-8">
          <h3 class="text-2xl font-bold text-gray-900 mb-2">Code Portfolio</h3>
          <p class="text-gray-600">Examples of my work and coding style</p>
          #{if repository_url != "" do
            "<div class=\"mt-4\"><a href=\"#{repository_url}\" target=\"_blank\" class=\"inline-flex items-center px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors\"><svg class=\"w-4 h-4 mr-2\" fill=\"currentColor\" viewBox=\"0 0 20 20\"><path fill-rule=\"evenodd\" d=\"M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z\" clip-rule=\"evenodd\"/></svg>View Repository</a></div>"
          else
            ""
          end}
        </div>
        <div class="space-y-6">
      """

      items_html = items
      |> Enum.filter(fn item -> Map.get(item, "visible", true) end)
      |> Enum.map(fn item -> render_code_showcase_item_safe(item, show_stats, primary_language) end)
      |> Enum.join("")

      html <> items_html <> """
        </div>
      </div>
      """
    end
  end

  defp render_code_showcase_item_safe(item, show_stats, primary_language) do
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    language = safe_map_get(item, "language", primary_language)
    repository_url = safe_map_get(item, "repository_url", "")
    live_url = safe_map_get(item, "live_url", "")
    code_sample = safe_map_get(item, "code_sample", "")

    """
    <div class="bg-white rounded-lg shadow-md overflow-hidden">
      <div class="p-6">
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1">
            <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(title)}</h4>
            <p class="text-gray-600 mb-3">#{safe_html_escape(description)}</p>
            <div class="flex items-center space-x-4">
              <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                #{safe_html_escape(language)}
              </span>
              #{if repository_url != "" do
                "<a href=\"#{repository_url}\" target=\"_blank\" class=\"text-gray-600 hover:text-gray-900\">
                  <svg class=\"w-4 h-4\" fill=\"currentColor\" viewBox=\"0 0 20 20\"><path fill-rule=\"evenodd\" d=\"M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z\" clip-rule=\"evenodd\"/></svg>
                </a>"
              else
                ""
              end}
              #{if live_url != "" do
                "<a href=\"#{live_url}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800\">
                  <svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/></svg>
                </a>"
              else
                ""
              end}
            </div>
          </div>
        </div>
        #{if code_sample != "" do
          "<div class=\"bg-gray-900 rounded-md p-4 text-sm text-green-400 font-mono overflow-x-auto\">
            <pre>#{safe_html_escape(code_sample)}</pre>
          </div>"
        else
          ""
        end}
      </div>
    </div>
    """
  end


  # ============================================================================
  # WORKING SECTION ITEM RENDERERS
  # ============================================================================

  defp render_experience_item_safe(item) do
    title = safe_map_get(item, "title", "")
    company = safe_map_get(item, "company", "")
    location = safe_map_get(item, "location", "")
    start_date = safe_map_get(item, "start_date", "")
    end_date = safe_map_get(item, "end_date", "")
    description = safe_map_get(item, "description", "")
    achievements = safe_map_get(item, "achievements", [])

    date_range = if safe_not_empty?(start_date) do
      end_text = if safe_not_empty?(end_date), do: end_date, else: "Present"
      "#{start_date} - #{end_text}"
    else
      ""
    end

    achievements_html = if is_list(achievements) and length(achievements) > 0 do
      achievements_list = achievements
      |> Enum.map(fn achievement -> "<li class=\"mb-1\">#{safe_html_escape(to_string(achievement))}</li>" end)
      |> Enum.join("")
      "<ul class=\"list-disc list-inside text-gray-600 mt-3 space-y-1\">#{achievements_list}</ul>"
    else
      ""
    end

    # CRITICAL FIX: Remove border, add subtle shadow like Projects
    """
    <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-1">#{safe_html_escape(title)}</h4>
          <div class="text-blue-600 font-medium mb-1">#{safe_html_escape(company)}</div>
          #{if safe_not_empty?(location) do
            "<div class=\"text-sm text-gray-500 mb-2\">#{safe_html_escape(location)}</div>"
          else
            ""
          end}
        </div>
        #{if date_range != "" do
          "<div class=\"text-sm text-gray-500 font-medium\">#{safe_html_escape(date_range)}</div>"
        else
          ""
        end}
      </div>
      #{if safe_not_empty?(description) do
        "<p class=\"text-gray-600 mb-3\">#{safe_html_escape(description)}</p>"
      else
        ""
      end}
      #{achievements_html}
    </div>
    """
  end

  defp render_education_item_safe(item) do
    degree = safe_map_get(item, "degree", "")
    institution = safe_map_get(item, "institution", "")
    field = safe_map_get(item, "field", "")
    graduation_date = safe_map_get(item, "graduation_date", "")
    gpa = safe_map_get(item, "gpa", "")
    honors = safe_map_get(item, "honors", "")
    description = safe_map_get(item, "description", "")

    # CRITICAL FIX: Remove border, add subtle shadow like Projects
    """
    <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-1">#{safe_html_escape(degree)}</h4>
          <div class="text-blue-600 font-medium mb-1">#{safe_html_escape(institution)}</div>
          #{if safe_not_empty?(field) do
            "<div class=\"text-gray-600 mb-2\">#{safe_html_escape(field)}</div>"
          else
            ""
          end}
        </div>
        #{if safe_not_empty?(graduation_date) do
          "<div class=\"text-sm text-gray-500 font-medium\">#{safe_html_escape(graduation_date)}</div>"
        else
          ""
        end}
      </div>

      <div class="flex flex-wrap gap-4 mb-3">
        #{if safe_not_empty?(gpa) do
          "<span class=\"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800\">
            GPA: #{safe_html_escape(gpa)}
          </span>"
        else
          ""
        end}
        #{if safe_not_empty?(honors) do
          "<span class=\"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800\">
            #{safe_html_escape(honors)}
          </span>"
        else
          ""
        end}
      </div>

      #{if safe_not_empty?(description) do
        "<p class=\"text-gray-600\">#{safe_html_escape(description)}</p>"
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
    technologies = safe_map_get(item, "technologies", [])
    live_url = safe_map_get(item, "live_url", "")
    github_url = safe_map_get(item, "github_url", "")
    image_url = safe_map_get(item, "image_url", "")

    tech_tags = if is_list(technologies) and length(technologies) > 0 do
      technologies
      |> Enum.take(4) # Limit to 4 tags
      |> Enum.map(fn tech -> "<span class=\"inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-2 mb-2\">#{safe_html_escape(to_string(tech))}</span>" end)
      |> Enum.join("")
    else
      ""
    end

    image_section = if image_url != "" do
      "<div class=\"w-full h-48 bg-gray-200 rounded-lg overflow-hidden mb-4\">
        <img src=\"#{safe_html_escape(image_url)}\" alt=\"#{safe_html_escape(title)}\" class=\"w-full h-full object-cover\">
      </div>"
    else
      ""
    end

    links_section = if live_url != "" or github_url != "" do
      live_link = if live_url != "" do
        "<a href=\"#{safe_html_escape(live_url)}\" target=\"_blank\" class=\"inline-flex items-center px-3 py-2 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors mr-2\">
          <svg class=\"w-4 h-4 mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/></svg>
          Live Demo
        </a>"
      else
        ""
      end

      github_link = if github_url != "" do
        "<a href=\"#{safe_html_escape(github_url)}\" target=\"_blank\" class=\"inline-flex items-center px-3 py-2 text-sm font-medium text-gray-600 bg-gray-50 rounded-md hover:bg-gray-100 transition-colors\">
          <svg class=\"w-4 h-4 mr-1\" fill=\"currentColor\" viewBox=\"0 0 20 20\"><path fill-rule=\"evenodd\" d=\"M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z\" clip-rule=\"evenodd\"/></svg>
          Code
        </a>"
      else
        ""
      end

      "<div class=\"flex items-center space-x-2 mt-4\">#{live_link}#{github_link}</div>"
    else
      ""
    end

    # CRITICAL FIX: Remove border, add subtle shadow like Projects items
    """
    <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
      #{image_section}
      <div>
        <h4 class="text-xl font-semibold text-gray-900 mb-3">#{safe_html_escape(title)}</h4>
        <p class="text-gray-600 mb-4">#{safe_html_escape(description)}</p>
        #{if tech_tags != "", do: "<div class=\"mb-4\">#{tech_tags}</div>", else: ""}
        #{links_section}
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
    currency = Map.get(content, "currency", "USD")
    billing_period = Map.get(content, "billing_period", "project")
    show_popular = Map.get(content, "show_popular", true)

    if length(items) == 0 do
      render_empty_state_safe("No pricing tiers added yet")
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
      |> Enum.map(fn item -> render_pricing_item_safe(item, currency, billing_period, show_popular) end)
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
    organization = safe_map_get(item, "organization", "")
    date = safe_map_get(item, "date", "")
    description = safe_map_get(item, "description", "")
    certificate_url = safe_map_get(item, "certificate_url", "")

    # CRITICAL FIX: Remove border, add subtle shadow like Projects
    """
    <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
      <div class="flex justify-between items-start mb-3">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-1">#{safe_html_escape(title)}</h4>
          #{if safe_not_empty?(organization) do
            "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(organization)}</div>"
          else
            ""
          end}
        </div>
        #{if safe_not_empty?(date) do
          "<div class=\"text-sm text-gray-500 font-medium\">#{safe_html_escape(date)}</div>"
        else
          ""
        end}
      </div>
      #{if safe_not_empty?(description) do
        "<p class=\"text-gray-600 mb-4\">#{safe_html_escape(description)}</p>"
      else
        ""
      end}
      #{if safe_not_empty?(certificate_url) do
        "<div class=\"flex justify-end\">
          <a href=\"#{safe_html_escape(certificate_url)}\" target=\"_blank\"
            class=\"inline-flex items-center px-3 py-2 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 transition-colors\">
            <svg class=\"w-4 h-4 mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
              <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/>
            </svg>
            View Certificate
          </a>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_testimonial_item_safe(item) do
    content = safe_map_get(item, "content", "")
    client_name = safe_map_get(item, "client_name", "")
    client_title = safe_map_get(item, "client_title", "")
    client_company = safe_map_get(item, "client_company", "")
    rating = safe_map_get(item, "rating", "")

    rating_stars = if safe_not_empty?(rating) do
      rating_num = case Integer.parse(rating) do
        {num, _} when num >= 1 and num <= 5 -> num
        _ -> 0
      end

      if rating_num > 0 do
        stars = for i <- 1..5 do
          if i <= rating_num do
            "<svg class=\"w-4 h-4 text-yellow-400 fill-current\" viewBox=\"0 0 24 24\"><path d=\"M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z\"/></svg>"
          else
            "<svg class=\"w-4 h-4 text-gray-300 fill-current\" viewBox=\"0 0 24 24\"><path d=\"M12 17.27L18.18 21l-1.64-7.03L22 9.24l-7.19-.61L12 2 9.19 8.63 2 9.24l5.46 4.73L5.82 21z\"/></svg>"
          end
        end
        "<div class=\"flex items-center mb-3\">#{Enum.join(stars, "")}</div>"
      else
        ""
      end
    else
      ""
    end

    # CRITICAL FIX: Remove border, add subtle shadow like Projects
    """
    <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
      #{rating_stars}
      <blockquote class="text-gray-700 mb-4 italic">
        "#{safe_html_escape(content)}"
      </blockquote>
      <div class="flex items-center">
        <div>
          <div class="font-semibold text-gray-900">#{safe_html_escape(client_name)}</div>
          #{if safe_not_empty?(client_title) do
            title_company = if safe_not_empty?(client_company) do
              "#{client_title}, #{client_company}"
            else
              client_title
            end
            "<div class=\"text-sm text-gray-600\">#{safe_html_escape(title_company)}</div>"
          else
            if safe_not_empty?(client_company) do
              "<div class=\"text-sm text-gray-600\">#{safe_html_escape(client_company)}</div>"
            else
              ""
            end
          end}
        </div>
      </div>
    </div>
    """
  end

defp render_service_item_safe(item, show_pricing) do
  name = safe_map_get(item, "name", "")
  description = safe_map_get(item, "description", "")
  price = safe_map_get(item, "price", "")
  duration = safe_map_get(item, "duration", "")
  features = safe_map_get(item, "features", [])

  features_html = if is_list(features) and length(features) > 0 do
    features_list = features
    |> Enum.map(fn feature -> "<li class=\"flex items-center mb-1\"><svg class=\"w-4 h-4 text-green-500 mr-2 flex-shrink-0\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 13l4 4L19 7\"/></svg>#{safe_html_escape(to_string(feature))}</li>" end)
    |> Enum.join("")
    "<ul class=\"mb-4\">#{features_list}</ul>"
  else
    ""
  end

  pricing_html = if show_pricing and safe_not_empty?(price) do
    duration_text = if safe_not_empty?(duration), do: " / #{duration}", else: ""
    "<div class=\"text-2xl font-bold text-blue-600 mb-2\">#{safe_html_escape(price)}#{duration_text}</div>"
  else
    ""
  end

  # CRITICAL FIX: Remove border, add subtle shadow like Projects
  """
  <div class="bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow p-6">
    <h4 class="text-xl font-semibold text-gray-900 mb-3">#{safe_html_escape(name)}</h4>
    #{pricing_html}
    <p class="text-gray-600 mb-4">#{safe_html_escape(description)}</p>
    #{features_html}
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

  defp render_pricing_item_safe(item, currency, billing_period, show_popular) do
    name = safe_map_get(item, "name", "")
    price = safe_map_get(item, "price", "")
    description = safe_map_get(item, "description", "")
    features = safe_map_get(item, "features", [])
    is_popular = Map.get(item, "is_popular", false) and show_popular
    button_text = safe_map_get(item, "button_text", "Get Started")
    button_url = safe_map_get(item, "button_url", "#")

    popular_badge = if is_popular do
      "<div class=\"absolute top-0 right-0 transform translate-x-1/2 -translate-y-1/2\">
        <span class=\"inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-blue-600 text-white\">
          Most Popular
        </span>
      </div>"
    else
      ""
    end

    border_class = if is_popular, do: "border-blue-500 border-2", else: "border-gray-200"

    features_html = if is_list(features) and length(features) > 0 do
      features_list = features
      |> Enum.map(fn feature -> "<li class=\"flex items-center\"><svg class=\"w-4 h-4 text-green-500 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M5 13l4 4L19 7\"/></svg>#{safe_html_escape(to_string(feature))}</li>" end)
      |> Enum.join("")
      "<ul class=\"space-y-2 mb-6\">#{features_list}</ul>"
    else
      ""
    end

    """
    <div class="relative bg-white rounded-lg shadow-md #{border_class} p-6">
      #{popular_badge}
      <div class="text-center">
        <h4 class="text-lg font-semibold text-gray-900 mb-2">#{safe_html_escape(name)}</h4>
        <div class="mb-4">
          <span class="text-3xl font-bold text-gray-900">#{currency} #{safe_html_escape(price)}</span>
          <span class="text-gray-500">/ #{billing_period}</span>
        </div>
        <p class="text-gray-600 mb-6">#{safe_html_escape(description)}</p>
        #{features_html}
        <a href="#{safe_html_escape(button_url)}" class="w-full inline-flex justify-center items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors">
          #{safe_html_escape(button_text)}
        </a>
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
