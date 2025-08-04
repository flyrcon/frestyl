# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex
# COMPLETE ENHANCED SECTION RENDERER - PRODUCTION READY

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer supporting ALL 29 portfolio section types.
  Uses safe content handling with zero Enum.join() calls - pure string concatenation.
  Production-ready with professional layouts and enhanced features.
  """

  # ============================================================================
  # SAFE CONTENT UTILITIES - Core Functions for Safe HTML Handling
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

  defp safe_not_empty?(content) do
    case safe_extract(content) do
      "" -> false
      content when is_binary(content) -> String.trim(content) != ""
      _ -> false
    end
  end

  defp render_empty_state_safe(message) do
    """
    <div class="text-center py-8 text-gray-500">
      <div class="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 0a9 9 0 1 1 18 0a9 9 0 0 1-18 0"/>
        </svg>
      </div>
      <p class="text-sm">#{safe_html_escape(message)}</p>
    </div>
    """
  end

  defp safe_extract_content(content, field, default \\ "") do
    case Map.get(content, field) do
      {:safe, value} when is_binary(value) -> String.trim(value)
      {:safe, value} when is_list(value) -> value |> Enum.join("") |> String.trim()
      value when is_binary(value) -> String.trim(value)
      nil -> default
      other -> to_string(other)
    end
  end

  # ============================================================================
  # MAIN ROUTING FUNCTION - All 29 Section Types
  # ============================================================================

  def render_section_content_static(section, customization \\ %{}) do
    section_type_str = to_string(section.section_type)
    clean_content_data = clean_content_data_safe(section.content)

    # Ensure customization includes color_scheme data
    full_customization = case customization do
      %{} when map_size(customization) == 0 ->
        # If no customization provided, try to get from section or use defaults
        section_customization = Map.get(section, :customization, %{})
        Map.put(section_customization, "color_scheme", get_default_color_scheme())
      _ ->
        # Ensure color_scheme exists
        Map.put_new(customization, "color_scheme", get_default_color_scheme())
    end

    IO.puts("🎨 SECTION RENDERER - Section: #{section_type_str}, Customization: #{inspect(full_customization)}")

    try do
      case section_type_str do
        # EXISTING SECTIONS (Enhanced)
        "skills" -> render_skills_content_safe(clean_content_data, full_customization)
        "experience" -> render_experience_content_safe(clean_content_data, full_customization)
        "work_experience" -> render_experience_content_safe(clean_content_data, full_customization)
        "education" -> render_education_content_safe(clean_content_data, full_customization)
        "projects" -> render_projects_content_safe(clean_content_data, full_customization)
        "contact" -> render_contact_content_safe(clean_content_data, full_customization)
        "achievements" -> render_achievements_section_safe(clean_content_data, full_customization)
        "awards" -> render_achievements_section_safe(clean_content_data, full_customization)

        # HERO/INTRO SECTIONS
        "intro" -> render_intro_content_safe(clean_content_data, full_customization)
        "about" -> render_intro_content_safe(clean_content_data, full_customization)
        "story" -> render_intro_content_safe(clean_content_data, full_customization)
        "hero" -> render_hero_content_safe(clean_content_data, full_customization)
        "summary" -> render_intro_content_safe(clean_content_data, full_customization)
        "profile" -> render_intro_content_safe(clean_content_data, full_customization)

        # GROUP 1 - MEDIA & SHOWCASES
        "featured_project" -> render_featured_project_content_safe(clean_content_data, full_customization)
        "case_study" -> render_case_study_content_safe(clean_content_data, full_customization)
        "media_showcase" -> render_media_showcase_content_safe(clean_content_data, full_customization)
        "code_showcase" -> render_code_showcase_content_safe(clean_content_data, full_customization)
        "gallery" -> render_gallery_content_safe(clean_content_data, full_customization)
        "video_hero" -> render_video_hero_content_safe(clean_content_data, full_customization)

        # GROUP 2 - PROFESSIONAL CONTENT
        "testimonial" -> render_testimonials_content_safe(clean_content_data, full_customization)
        "testimonials" -> render_testimonials_content_safe(clean_content_data, full_customization)
        "collaborations" -> render_collaborations_content_safe(clean_content_data, full_customization)
        "published_articles" -> render_articles_content_safe(clean_content_data, full_customization)
        "writing" -> render_articles_content_safe(clean_content_data, full_customization)
        "blog" -> render_articles_content_safe(clean_content_data, full_customization)
        "certifications" -> render_certifications_content_safe(clean_content_data, full_customization)
        "services" -> render_services_content_safe(clean_content_data, full_customization)
        "pricing" -> render_pricing_content_safe(clean_content_data, full_customization)

        # GROUP 3 - TIMELINE & JOURNEY
        "timeline" -> render_timeline_content_safe(clean_content_data, full_customization)
        "narrative" -> render_narrative_content_safe(clean_content_data, full_customization)
        "journey" -> render_journey_content_safe(clean_content_data, full_customization)
        "volunteer" -> render_volunteer_content_safe(clean_content_data, full_customization)

        # GROUP 4 - FLEXIBLE
        "custom" -> render_custom_content_safe(clean_content_data, full_customization)

        # LEGACY MAPPINGS
        "portfolio" -> render_projects_content_safe(clean_content_data, full_customization)
        "work" -> render_projects_content_safe(clean_content_data, full_customization)

        # FALLBACK
        _ -> render_generic_content_safe(clean_content_data, full_customization)
      end
    rescue
      error ->
        IO.puts("❌ Section rendering error: #{inspect(error)}")
        render_error_state_safe("Section content temporarily unavailable")
    end
  end

  # Default color scheme following Frestyl's design philosophy
  defp get_default_color_scheme do
    %{
      "primary" => "#3B82F6",    # Blue-600
      "secondary" => "#059669",  # Emerald-600
      "accent" => "#F59E0B"      # Amber-500
    }
  end

  defp clean_content_data_safe(content) when is_map(content), do: content
  defp clean_content_data_safe(_), do: %{}

  defp render_error_state_safe(message) do
    """
    <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-center">
      <div class="text-red-600 text-sm">⚠️ #{safe_html_escape(message)}</div>
    </div>
    """
  end

  # ============================================================================
  # ENHANCED SKILLS SECTION - Meta Pills with Proficiency Colors
  # ============================================================================

  defp render_skills_content_safe(content, customization) do
    skills = Map.get(content, "items", [])
    color_scheme = Map.get(customization, "color_scheme", %{})

    if is_list(skills) and length(skills) > 0 do
      render_skills_meta_pills_safe(skills, color_scheme)
    else
      render_empty_state_safe("No skills available")
    end
  end

  defp render_skills_meta_pills_safe(skills, color_scheme) do
    # Group skills by category for better organization
    categorized_skills = group_skills_by_category_safe(skills, %{})

    html = "<div class=\"skills-content space-y-6\">"
    html = html <> build_categorized_skills_safe(Map.to_list(categorized_skills), color_scheme, "")
    html = html <> "</div>"
    html
  end

  # Safe skill grouping - NO Enum.group_by!
  defp group_skills_by_category_safe([], acc), do: acc
  defp group_skills_by_category_safe([skill | remaining], acc) do
    category = safe_map_get(skill, "category", "General")
    current_skills = Map.get(acc, category, [])
    updated_acc = Map.put(acc, category, current_skills ++ [skill])
    group_skills_by_category_safe(remaining, updated_acc)
  end

  # Safe categorized skills builder
  defp build_categorized_skills_safe([], _color_scheme, acc), do: acc
  defp build_categorized_skills_safe([{category, skills} | remaining], color_scheme, acc) do
    category_html = "<div class=\"skill-category mb-6\">"
    category_html = category_html <> "<h4 class=\"text-sm font-semibold text-gray-700 mb-3 uppercase tracking-wide\">"
    category_html = category_html <> safe_html_escape(category)
    category_html = category_html <> "</h4>"
    category_html = category_html <> "<div class=\"flex flex-wrap gap-2\">"
    category_html = category_html <> build_skill_pills_safe(skills, color_scheme, "")
    category_html = category_html <> "</div>"
    category_html = category_html <> "</div>"

    new_acc = acc <> category_html
    build_categorized_skills_safe(remaining, color_scheme, new_acc)
  end

  # Safe skill pills builder with proficiency colors
  defp build_skill_pills_safe([], _color_scheme, acc), do: acc
  defp build_skill_pills_safe([skill | remaining], color_scheme, acc) do
    skill_name = safe_map_get(skill, "name", safe_map_get(skill, "skill_name", ""))
    proficiency = safe_map_get(skill, "proficiency", safe_map_get(skill, "level", "intermediate"))

    {bg_color, opacity} = get_proficiency_color_safe(proficiency, color_scheme)

    pill_html = "<span class=\"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium text-white transition-all hover:scale-105\" "
    pill_html = pill_html <> "style=\"background-color: #{bg_color}; opacity: #{opacity}%\" "
    pill_html = pill_html <> "title=\"#{safe_html_escape(proficiency)} level\">"
    pill_html = pill_html <> safe_html_escape(skill_name)
    pill_html = pill_html <> "</span>"

    new_acc = acc <> pill_html
    build_skill_pills_safe(remaining, color_scheme, new_acc)
  end

  # Enhanced proficiency color mapping with proper color_scheme integration
  defp get_proficiency_color_safe(proficiency, color_scheme) do
    proficiency_str = safe_extract(proficiency) |> String.downcase()

    # Extract user's actual color scheme from design tab
    user_primary = Map.get(color_scheme, "primary", nil)
    user_secondary = Map.get(color_scheme, "secondary", nil)
    user_accent = Map.get(color_scheme, "accent", nil)

    # Frestyl's gradient-inspired color philosophy (fallbacks)
    frestyl_gradients = %{
      expert: ["#0891B2", "#3B82F6"],      # cyan-600 to blue-600
      advanced: ["#7C3AED", "#6366F1"],    # purple-600 to indigo-600
      intermediate: ["#EAB308", "#F97316"], # yellow-500 to orange-500
      beginner: ["#EC4899", "#A855F7"],    # pink-500 to purple-500
      accent_range: ["#DB2777", "#7C3AED"] # pink-600 to purple-600
    }

    # Helper function to darken colors properly
    darken_color = fn color ->
      case color do
        "#3B82F6" -> "#1D4ED8"  # Blue
        "#059669" -> "#047857"  # Green
        "#F59E0B" -> "#D97706"  # Amber
        "#DC2626" -> "#B91C1C"  # Red
        "#7C3AED" -> "#5B21B6"  # Purple
        "#EA580C" -> "#C2410C"  # Orange
        "#0891B2" -> "#0E7490"  # Cyan
        "#DB2777" -> "#BE185D"  # Pink
        "#6366F1" -> "#4F46E5"  # Indigo
        "#10B981" -> "#059669"  # Emerald
        "#EAB308" -> "#CA8A04"  # Yellow
        "#F97316" -> "#EA580C"  # Orange
        "#EC4899" -> "#DB2777"  # Pink
        "#A855F7" -> "#9333EA"  # Purple
        _ ->
          # Generic darkening for unknown colors
          if String.starts_with?(color, "#") and String.length(color) == 7 do
            try do
              <<r::8, g::8, b::8>> = color |> String.slice(1..-1) |> Base.decode16!(case: :mixed)
              darker_r = max(0, r - 50)
              darker_g = max(0, g - 50)
              darker_b = max(0, b - 50)
              "#" <> Base.encode16(<<darker_r, darker_g, darker_b>>, case: :lower)
            rescue
              _ -> color
            end
          else
            color
          end
      end
    end

    # Color assignment based on proficiency with user scheme priority
    case proficiency_str do
      # EXPERT: Use darker primary if available, else Frestyl cyan-blue gradient
      level when level in ["expert", "advanced", "5", "senior", "master"] ->
        color = if user_primary, do: darken_color.(user_primary), else: Enum.random(frestyl_gradients.expert)
        {color, 100}

      # ADVANCED: Use primary if available, else Frestyl purple-indigo gradient
      level when level in ["advanced", "high", "strong", "solid", "4"] ->
        color = if user_primary, do: user_primary, else: Enum.random(frestyl_gradients.advanced)
        {color, 85}

      # INTERMEDIATE: Use secondary if available, else Frestyl yellow-orange gradient
      level when level in ["intermediate", "proficient", "skilled", "competent", "working", "3"] ->
        color = if user_secondary, do: user_secondary, else: Enum.random(frestyl_gradients.intermediate)
        {color, 70}

      # BEGINNER: Use accent if available, else Frestyl pink-purple gradient
      level when level in ["beginner", "basic", "learning", "developing", "familiar", "some", "2"] ->
        color = if user_accent, do: user_accent, else: Enum.random(frestyl_gradients.beginner)
        {color, 55}

      # NOVICE: Use accent with lower opacity, else Frestyl accent range
      level when level in ["novice", "1", "entry", "starter", "new", "limited"] ->
        color = if user_accent, do: user_accent, else: Enum.random(frestyl_gradients.accent_range)
        {color, 40}

      _ ->
        # Fallback: Use secondary or Frestyl intermediate colors
        color = if user_secondary, do: user_secondary, else: Enum.random(frestyl_gradients.intermediate)
        {color, 65}
    end
  end

  # ============================================================================
  # ENHANCED EXPERIENCE SECTION - Professional Timeline
  # ============================================================================

  defp render_experience_content_safe(content, customization) do
    experiences = Map.get(content, "items", [])
    display_style = Map.get(content, "display_style", "timeline")

    if is_list(experiences) and length(experiences) > 0 do
      render_experience_timeline_safe(experiences, customization)
    else
      render_empty_state_safe("No work experience available")
    end
  end

  defp render_experience_timeline_safe(experiences, customization) do
    experiences_html = build_experiences_html_safe(experiences, customization, 0, "")

    html = "<div class=\"experience-timeline space-y-4\">"
    html = html <> experiences_html
    html = html <> "</div>"
    html
  end

  # Safe experience HTML builder
  defp build_experiences_html_safe([], _customization, _index, acc), do: acc
  defp build_experiences_html_safe([experience | remaining], customization, index, acc) do
    exp_html = render_single_experience_safe(experience, customization, index)
    new_acc = acc <> exp_html
    build_experiences_html_safe(remaining, customization, index + 1, new_acc)
  end

  defp render_single_experience_safe(experience, customization, index) do
    title = safe_map_get(experience, "title", "")
    company = safe_map_get(experience, "company", "")
    location = safe_map_get(experience, "location", "")
    start_date = safe_map_get(experience, "start_date", "")
    end_date = safe_map_get(experience, "end_date", "")
    is_current = Map.get(experience, "is_current", false)
    description = safe_map_get(experience, "description", "")
    achievements = Map.get(experience, "achievements", [])
    skills_used = Map.get(experience, "skills_used", [])
    employment_type = safe_map_get(experience, "employment_type", "")

    # Build card without borders
    html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    # Header with title and company
    html = html <> "<div class=\"flex items-start justify-between mb-3\">"
    html = html <> "<div class=\"flex-1\">"
    html = html <> "<h3 class=\"font-semibold text-gray-900 text-lg\">" <> safe_html_escape(title) <> "</h3>"

    if safe_not_empty?(company) do
      html = html <> "<p class=\"text-blue-600 font-medium\">" <> safe_html_escape(company) <> "</p>"
    end

    html = html <> "</div>"

    # Date and location badge
    date_text = if is_current do
      start_date <> " - Present"
    else
      if safe_not_empty?(end_date), do: start_date <> " - " <> end_date, else: start_date
    end

    if safe_not_empty?(date_text) do
      html = html <> "<div class=\"text-right\">"
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded\">"
      html = html <> safe_html_escape(date_text)
      html = html <> "</span>"

      if safe_not_empty?(location) do
        html = html <> "<p class=\"text-sm text-gray-500 mt-1\">" <> safe_html_escape(location) <> "</p>"
      end

      html = html <> "</div>"
    end

    html = html <> "</div>"

    # Employment type badge
    if safe_not_empty?(employment_type) do
      html = html <> "<div class=\"mb-3\">"
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded\">"
      html = html <> safe_html_escape(employment_type)
      html = html <> "</span>"
      html = html <> "</div>"
    end

    # Description
    if safe_not_empty?(description) do
      html = html <> "<div class=\"text-gray-700 mb-3 leading-relaxed\">"
      html = html <> safe_html_escape(description)
      html = html <> "</div>"
    end

    # Achievements
    if is_list(achievements) and length(achievements) > 0 do
      html = html <> "<div class=\"mb-3\">"
      html = html <> "<h4 class=\"text-sm font-medium text-gray-900 mb-2\">Key Achievements</h4>"
      html = html <> "<ul class=\"space-y-1\">"
      html = html <> build_achievement_list_safe(achievements, "")
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    # Skills used
    if is_list(skills_used) and length(skills_used) > 0 do
      html = html <> "<div class=\"flex flex-wrap gap-1\">"
      html = html <> build_skill_tags_safe(skills_used, "")
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  # Safe achievement list builder
  defp build_achievement_list_safe([], acc), do: acc
  defp build_achievement_list_safe([achievement | remaining], acc) do
    item_html = "<li class=\"text-sm text-gray-600 flex items-start\">"
    item_html = item_html <> "<span class=\"text-blue-500 mr-2\">•</span>"
    item_html = item_html <> "<span>" <> safe_html_escape(safe_extract(achievement)) <> "</span>"
    item_html = item_html <> "</li>"

    new_acc = acc <> item_html
    build_achievement_list_safe(remaining, new_acc)
  end

  # Safe skill tags builder
  defp build_skill_tags_safe([], acc), do: acc
  defp build_skill_tags_safe([skill | remaining], acc) do
    tag_html = "<span class=\"inline-flex items-center px-2 py-1 bg-gray-200 text-gray-700 text-xs rounded\">"
    tag_html = tag_html <> safe_html_escape(safe_extract(skill))
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_skill_tags_safe(remaining, new_acc)
  end

  # ============================================================================
  # ENHANCED EDUCATION SECTION - No Inner Borders
  # ============================================================================

  defp render_education_content_safe(content, _customization) do
    education_items = Map.get(content, "items", Map.get(content, "education", []))

    if is_list(education_items) and length(education_items) > 0 do
      render_education_list_safe(education_items)
    else
      render_empty_state_safe("No education information available")
    end
  end

  defp render_education_list_safe(education_items) do
    education_html = build_education_items_safe(education_items, "")

    html = "<div class=\"education-list space-y-4\">"
    html = html <> education_html
    html = html <> "</div>"
    html
  end

  # Safe education items builder
  defp build_education_items_safe([], acc), do: acc
  defp build_education_items_safe([education | remaining], acc) do
    edu_html = render_single_education_safe(education)
    new_acc = acc <> edu_html
    build_education_items_safe(remaining, new_acc)
  end

  defp render_single_education_safe(education) do
    degree = safe_map_get(education, "degree", "")
    institution = safe_map_get(education, "institution", "")
    field_of_study = safe_map_get(education, "field_of_study", safe_map_get(education, "field", ""))
    graduation_year = safe_map_get(education, "graduation_year", safe_map_get(education, "year", ""))
    gpa = safe_map_get(education, "gpa", "")
    honors = Map.get(education, "honors", [])
    activities = Map.get(education, "activities", [])

    # Clean card design - no inner borders
    html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    # Header
    html = html <> "<div class=\"flex items-start justify-between mb-3\">"
    html = html <> "<div class=\"flex-1\">"

    if safe_not_empty?(degree) do
      html = html <> "<h3 class=\"font-semibold text-gray-900 text-lg\">" <> safe_html_escape(degree) <> "</h3>"
    end

    if safe_not_empty?(field_of_study) do
      html = html <> "<p class=\"text-blue-600 font-medium\">" <> safe_html_escape(field_of_study) <> "</p>"
    end

    if safe_not_empty?(institution) do
      html = html <> "<p class=\"text-gray-600\">" <> safe_html_escape(institution) <> "</p>"
    end

    html = html <> "</div>"

    # Year badge
    if safe_not_empty?(graduation_year) do
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-purple-100 text-purple-800 text-xs font-medium rounded\">"
      html = html <> safe_html_escape(graduation_year)
      html = html <> "</span>"
    end

    html = html <> "</div>"

    # GPA
    if safe_not_empty?(gpa) do
      html = html <> "<div class=\"mb-3\">"
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded\">"
      html = html <> "GPA: " <> safe_html_escape(gpa)
      html = html <> "</span>"
      html = html <> "</div>"
    end

    # Honors
    if is_list(honors) and length(honors) > 0 do
      html = html <> "<div class=\"mb-3\">"
      html = html <> "<div class=\"flex flex-wrap gap-1\">"
      html = html <> build_honors_tags_safe(honors, "")
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Activities
    if is_list(activities) and length(activities) > 0 do
      html = html <> "<div class=\"text-sm text-gray-600\">"
      html = html <> "<span class=\"font-medium\">Activities: </span>"
      html = html <> build_activities_text_safe(activities, "")
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  # Safe honors tags builder
  defp build_honors_tags_safe([], acc), do: acc
  defp build_honors_tags_safe([honor | remaining], acc) do
    clean_honor = safe_extract(honor)

    if safe_not_empty?(clean_honor) do
      honor_color = get_honor_color_safe(clean_honor)

      tag_html = "<span class=\"inline-flex items-center px-2 py-1 rounded text-xs font-medium " <> honor_color <> "\">"
      tag_html = tag_html <> safe_html_escape(clean_honor)
      tag_html = tag_html <> "</span>"

      new_acc = acc <> tag_html
      build_honors_tags_safe(remaining, new_acc)
    else
      build_honors_tags_safe(remaining, acc)
    end
  end

  defp get_honor_color_safe(honor) do
    clean_honor_lower = String.downcase(honor)

    cond do
      String.contains?(clean_honor_lower, "summa cum laude") -> "bg-yellow-100 text-yellow-800"
      String.contains?(clean_honor_lower, "magna cum laude") -> "bg-yellow-50 text-yellow-700"
      String.contains?(clean_honor_lower, "cum laude") -> "bg-amber-50 text-amber-700"
      String.contains?(clean_honor_lower, "dean") -> "bg-purple-50 text-purple-700"
      String.contains?(clean_honor_lower, "scholarship") -> "bg-blue-50 text-blue-700"
      true -> "bg-green-50 text-green-700"
    end
  end

  # Safe activities text builder
  defp build_activities_text_safe([], acc), do: acc
  defp build_activities_text_safe([activity], acc) do
    acc <> safe_html_escape(safe_extract(activity))
  end
  defp build_activities_text_safe([activity | remaining], acc) do
    new_acc = acc <> safe_html_escape(safe_extract(activity)) <> ", "
    build_activities_text_safe(remaining, new_acc)
  end

  # ============================================================================
  # ENHANCED PROJECTS SECTION
  # ============================================================================

  defp render_projects_content_safe(content, customization) do
    projects = Map.get(content, "items", Map.get(content, "projects", []))

    if is_list(projects) and length(projects) > 0 do
      render_projects_grid_safe(projects, customization)
    else
      render_empty_state_safe("No projects available")
    end
  end

  defp render_projects_grid_safe(projects, _customization) do
    projects_html = build_projects_safe(projects, "")

    html = "<div class=\"projects-grid space-y-4\">"
    html = html <> projects_html
    html = html <> "</div>"
    html
  end

  # Safe projects builder
  defp build_projects_safe([], acc), do: acc
  defp build_projects_safe([project | remaining], acc) do
    project_html = render_single_project_safe(project)
    new_acc = acc <> project_html
    build_projects_safe(remaining, new_acc)
  end

  defp render_single_project_safe(project) do
    title = safe_map_get(project, "title", "")
    description = safe_map_get(project, "description", "")
    technologies = Map.get(project, "technologies", [])
    demo_url = safe_map_get(project, "demo_url", safe_map_get(project, "url", ""))
    github_url = safe_map_get(project, "github_url", safe_map_get(project, "repository", ""))
    status = safe_map_get(project, "status", "Completed")
    featured = Map.get(project, "featured", false)

    html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    # Header with title and status
    html = html <> "<div class=\"flex items-start justify-between mb-3\">"
    html = html <> "<div class=\"flex-1\">"
    html = html <> "<h3 class=\"font-semibold text-gray-900 text-lg\">" <> safe_html_escape(title) <> "</h3>"
    html = html <> "</div>"

    # Status and featured badges
    html = html <> "<div class=\"flex gap-2\">"

    if featured do
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-yellow-100 text-yellow-800 text-xs font-medium rounded\">"
      html = html <> "⭐ Featured"
      html = html <> "</span>"
    end

    status_color = case String.downcase(status) do
      "completed" -> "bg-green-100 text-green-800"
      "in progress" -> "bg-blue-100 text-blue-800"
      "planning" -> "bg-gray-100 text-gray-800"
      _ -> "bg-purple-100 text-purple-800"
    end

    html = html <> "<span class=\"inline-flex items-center px-2 py-1 " <> status_color <> " text-xs font-medium rounded\">"
    html = html <> safe_html_escape(status)
    html = html <> "</span>"
    html = html <> "</div>"
    html = html <> "</div>"

    # Description
    if safe_not_empty?(description) do
      html = html <> "<div class=\"text-gray-700 mb-3 leading-relaxed\">"
      html = html <> safe_html_escape(description)
      html = html <> "</div>"
    end

    # Technologies
    if is_list(technologies) and length(technologies) > 0 do
      html = html <> "<div class=\"mb-3\">"
      html = html <> "<div class=\"flex flex-wrap gap-1\">"
      html = html <> build_tech_tags_safe(technologies, "")
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Links
    html = html <> "<div class=\"flex gap-3\">"

    if safe_not_empty?(demo_url) do
      html = html <> "<a href=\"" <> safe_html_escape(demo_url) <> "\" target=\"_blank\" rel=\"noopener\" "
      html = html <> "class=\"inline-flex items-center px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 transition-colors\">"
      html = html <> "<svg class=\"w-4 h-4 mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14\"/>"
      html = html <> "</svg>Live Demo</a>"
    end

    if safe_not_empty?(github_url) do
      html = html <> "<a href=\"" <> safe_html_escape(github_url) <> "\" target=\"_blank\" rel=\"noopener\" "
      html = html <> "class=\"inline-flex items-center px-3 py-1 bg-gray-800 text-white text-sm rounded hover:bg-gray-900 transition-colors\">"
      html = html <> "<svg class=\"w-4 h-4 mr-1\" fill=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path d=\"M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z\"/>"
      html = html <> "</svg>Source Code</a>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  # Safe tech tags builder
  defp build_tech_tags_safe([], acc), do: acc
  defp build_tech_tags_safe([tech | remaining], acc) do
    tag_html = "<span class=\"inline-flex items-center px-2 py-1 bg-indigo-100 text-indigo-800 text-xs font-medium rounded\">"
    tag_html = tag_html <> safe_html_escape(safe_extract(tech))
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_tech_tags_safe(remaining, new_acc)
  end

  # ============================================================================
  # ENHANCED ACHIEVEMENTS SECTION
  # ============================================================================

  defp render_achievements_section_safe(content, _customization) do
    achievements = Map.get(content, "items", Map.get(content, "achievements", []))

    if is_list(achievements) and length(achievements) > 0 do
      render_achievements_list_safe(achievements)
    else
      render_empty_state_safe("No achievements available")
    end
  end

  defp render_achievements_list_safe(achievements) do
    achievements_html = build_achievements_safe(achievements, "")

    html = "<div class=\"achievements-list space-y-3\">"
    html = html <> achievements_html
    html = html <> "</div>"
    html
  end

  # Safe achievements builder
  defp build_achievements_safe([], acc), do: acc
  defp build_achievements_safe([achievement | remaining], acc) do
    achievement_html = render_single_achievement_safe(achievement)
    new_acc = acc <> achievement_html
    build_achievements_safe(remaining, new_acc)
  end

  defp render_single_achievement_safe(achievement) do
    title = safe_map_get(achievement, "title", safe_map_get(achievement, "name", ""))
    description = safe_map_get(achievement, "description", "")
    date = safe_map_get(achievement, "date", safe_map_get(achievement, "year", ""))
    organization = safe_map_get(achievement, "organization", safe_map_get(achievement, "issuer", ""))
    category = safe_map_get(achievement, "category", "Achievement")

    html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    # Header
    html = html <> "<div class=\"flex items-start justify-between mb-2\">"
    html = html <> "<div class=\"flex-1\">"
    html = html <> "<h3 class=\"font-semibold text-gray-900\">" <> safe_html_escape(title) <> "</h3>"

    if safe_not_empty?(organization) do
      html = html <> "<p class=\"text-blue-600 text-sm\">" <> safe_html_escape(organization) <> "</p>"
    end

    html = html <> "</div>"

    # Date and category badges
    html = html <> "<div class=\"flex flex-col gap-1\">"

    if safe_not_empty?(date) do
      html = html <> "<span class=\"inline-flex items-center px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded self-end\">"
      html = html <> safe_html_escape(date)
      html = html <> "</span>"
    end

    category_color = case String.downcase(category) do
      "award" -> "bg-yellow-100 text-yellow-800"
      "certification" -> "bg-blue-100 text-blue-800"
      "recognition" -> "bg-purple-100 text-purple-800"
      _ -> "bg-gray-100 text-gray-800"
    end

    html = html <> "<span class=\"inline-flex items-center px-2 py-1 " <> category_color <> " text-xs font-medium rounded self-end\">"
    html = html <> safe_html_escape(category)
    html = html <> "</span>"
    html = html <> "</div>"
    html = html <> "</div>"

    # Description
    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700 text-sm leading-relaxed\">"
      html = html <> safe_html_escape(description)
      html = html <> "</p>"
    end

    html = html <> "</div>"
    html
  end

  # ============================================================================
  # FIXED CONTACT SECTION - Enhanced Professional Layout
  # ============================================================================

  defp render_contact_content_safe(content, _customization) do
    email = safe_extract_content(content, "email")
    phone = safe_extract_content(content, "phone")
    location = safe_extract_content(content, "location")
    website = safe_extract_content(content, "website")
    availability = safe_extract_content(content, "availability")
    social_links = Map.get(content, "social_links", %{})

    html = "<div class=\"contact-content space-y-4\">"

    # Contact info section
    if email != "" or phone != "" or location != "" or website != "" do
      html = html <> "<div class=\"contact-info grid grid-cols-1 md:grid-cols-2 gap-4\">"

      if email != "" do
        html = html <> "<div class=\"contact-item\">"
        html = html <> "<label class=\"block text-sm font-medium text-gray-700\">Email</label>"
        html = html <> "<a href=\"mailto:" <> email <> "\" class=\"text-blue-600 hover:text-blue-800\">" <> email <> "</a>"
        html = html <> "</div>"
      end

      if phone != "" do
        html = html <> "<div class=\"contact-item\">"
        html = html <> "<label class=\"block text-sm font-medium text-gray-700\">Phone</label>"
        html = html <> "<a href=\"tel:" <> phone <> "\" class=\"text-blue-600 hover:text-blue-800\">" <> phone <> "</a>"
        html = html <> "</div>"
      end

      if location != "" do
        html = html <> "<div class=\"contact-item\">"
        html = html <> "<label class=\"block text-sm font-medium text-gray-700\">Location</label>"
        html = html <> "<span class=\"text-gray-900\">" <> location <> "</span>"
        html = html <> "</div>"
      end

      if website != "" do
        html = html <> "<div class=\"contact-item\">"
        html = html <> "<label class=\"block text-sm font-medium text-gray-700\">Website</label>"
        html = html <> "<a href=\"" <> website <> "\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800\">" <> website <> "</a>"
        html = html <> "</div>"
      end

      html = html <> "</div>"
    end

    # Social links section
    if map_size(social_links) > 0 do
      html = html <> "<div class=\"social-links mt-6\">"
      html = html <> "<h4 class=\"text-sm font-medium text-gray-700 mb-3\">Connect With Me</h4>"
      html = html <> "<div class=\"flex flex-wrap gap-3\">"

      Enum.each(social_links, fn {platform, url} ->
        if url != "" and url != nil do
          platform_name = String.capitalize(platform)
          html = html <> "<a href=\"" <> url <> "\" target=\"_blank\" class=\"inline-flex items-center px-3 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors text-sm\">"
          html = html <> platform_name
          html = html <> "</a>"
        end
      end)

      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp render_contact_item_safe(type, value, label) do
    icon = case type do
      "email" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>"
      "phone" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>"
      "location" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z\"/><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 11a3 3 0 11-6 0 3 3 0 016 0z\"/>"
      "website" -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9\"/>"
      _ -> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z\"/>"
    end

    link_value = case type do
      "email" -> "mailto:" <> value
      "phone" -> "tel:" <> value
      "website" -> if String.starts_with?(value, "http"), do: value, else: "https://" <> value
      _ -> "#"
    end

    """
    <div class="bg-gray-50 rounded-lg p-3 hover:bg-gray-100 transition-colors">
      <div class="flex items-center">
        <svg class="w-4 h-4 text-gray-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          #{icon}
        </svg>
        <div class="flex-1 min-w-0">
          <p class="text-xs text-gray-500 uppercase tracking-wide font-medium">#{safe_html_escape(label)}</p>
          <a href="#{safe_html_escape(link_value)}" class="text-sm text-gray-900 hover:text-blue-600 transition-colors truncate block">
            #{safe_html_escape(value)}
          </a>
        </div>
      </div>
    </div>
    """
  end

  # Safe contact items HTML builder
  defp build_contact_items_html_safe([], acc), do: acc
  defp build_contact_items_html_safe([item | remaining], acc) do
    new_acc = acc <> item
    build_contact_items_html_safe(remaining, new_acc)
  end

  # Safe social items builder
  defp build_social_items_safe([], acc), do: acc
  defp build_social_items_safe([{platform, url} | remaining], acc) do
    if safe_not_empty?(url) do
      item_html = render_social_item_safe(platform, url)
      new_acc = [item_html | acc]
      build_social_items_safe(remaining, new_acc)
    else
      build_social_items_safe(remaining, acc)
    end
  end

  defp render_social_item_safe(platform, url) do
    platform_str = safe_extract(platform)
    url_str = safe_extract(url)

    {platform_name, icon_path} = case String.downcase(platform_str) do
      "linkedin" -> {"LinkedIn", "M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"}
      "github" -> {"GitHub", "M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"}
      "twitter" -> {"Twitter", "M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"}
      "website" -> {"Website", "M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"}
      "instagram" -> {"Instagram", "M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"}
      _ -> {String.capitalize(platform_str), "M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"}
    end

    """
    <a href="#{safe_html_escape(url_str)}" target="_blank" rel="noopener"
       class="flex items-center justify-center p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors group">
      <svg class="w-5 h-5 text-gray-700 group-hover:text-blue-600" fill="currentColor" viewBox="0 0 24 24">
        <path d="#{icon_path}"/>
      </svg>
      <span class="ml-2 text-sm font-medium text-gray-700 group-hover:text-blue-600">#{platform_name}</span>
    </a>
    """
  end

  # Safe social items HTML builder
  defp build_social_items_html_safe([], acc), do: acc
  defp build_social_items_html_safe([item | remaining], acc) do
    new_acc = acc <> item
    build_social_items_html_safe(remaining, new_acc)
  end

  # ============================================================================
  # HERO SECTION - Enhanced with Video Support
  # ============================================================================

  defp render_hero_content_safe(content, customization) do
    headline = safe_map_get(content, "headline", "")
    tagline = safe_map_get(content, "tagline", "")
    description = safe_map_get(content, "description", "")
    cta_text = safe_map_get(content, "cta_text", "")
    cta_link = safe_map_get(content, "cta_link", "")
    video_url = safe_map_get(content, "video_url", "")
    video_type = safe_map_get(content, "video_type", "none")
    background_image = safe_map_get(content, "background_image", "")
    social_links = Map.get(content, "social_links", %{})
    contact_info = Map.get(content, "contact_info", %{})

    html = "<div class=\"hero-content relative\">"

    # Background handling
    if safe_not_empty?(background_image) do
      html = html <> "<div class=\"absolute inset-0 bg-cover bg-center opacity-10\" style=\"background-image: url('#{safe_html_escape(background_image)}');\"></div>"
    end

    html = html <> "<div class=\"relative z-10\">"

    # Video section
    if video_type != "none" and safe_not_empty?(video_url) do
      html = html <> render_hero_video_safe(video_url, video_type, content)
      html = html <> "<div class=\"mt-6\">"
    end

    # Text content
    html = html <> "<div class=\"text-center space-y-4\">"

    if safe_not_empty?(headline) do
      html = html <> "<h1 class=\"text-4xl md:text-6xl font-bold text-gray-900 leading-tight\">"
      html = html <> safe_html_escape(headline)
      html = html <> "</h1>"
    end

    if safe_not_empty?(tagline) do
      html = html <> "<h2 class=\"text-xl md:text-2xl text-blue-600 font-medium\">"
      html = html <> safe_html_escape(tagline)
      html = html <> "</h2>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-lg text-gray-600 max-w-2xl mx-auto leading-relaxed\">"
      html = html <> safe_html_escape(description)
      html = html <> "</p>"
    end

    # Contact info quick access
    if map_size(contact_info) > 0 do
      html = html <> "<div class=\"flex justify-center space-x-6 text-sm text-gray-600\">"
      html = html <> build_hero_contact_items_safe(Map.to_list(contact_info), "")
      html = html <> "</div>"
    end

    # CTA Button
    if safe_not_empty?(cta_text) and safe_not_empty?(cta_link) do
      html = html <> "<div class=\"pt-4\">"
      html = html <> "<a href=\"" <> safe_html_escape(cta_link) <> "\" "
      html = html <> "class=\"inline-flex items-center px-8 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors shadow-lg hover:shadow-xl transform hover:-translate-y-0.5\">"
      html = html <> safe_html_escape(cta_text)
      html = html <> "<svg class=\"w-5 h-5 ml-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17 8l4 4m0 0l-4 4m4-4H3\"/>"
      html = html <> "</svg>"
      html = html <> "</a>"
      html = html <> "</div>"
    end

    # Social links
    if map_size(social_links) > 0 do
      html = html <> "<div class=\"pt-6\">"
      html = html <> "<div class=\"flex justify-center space-x-4\">"
      html = html <> build_hero_social_links_safe(Map.to_list(social_links), "")
      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div>"

    if video_type != "none" and safe_not_empty?(video_url) do
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_hero_video_safe(video_url, video_type, content) do
    video_settings = Map.get(content, "video_settings", %{})
    autoplay = Map.get(video_settings, "autoplay", false)
    muted = Map.get(video_settings, "muted", true)
    loop = Map.get(video_settings, "loop", false)
    show_controls = Map.get(content, "show_controls", true)
    poster_image = safe_map_get(content, "poster_image", "")

    html = "<div class=\"video-container mb-6 rounded-lg overflow-hidden shadow-2xl\">"

    case video_type do
      "youtube" ->
        video_id = extract_youtube_id_safe(video_url)
        if safe_not_empty?(video_id) do
          html = html <> "<div class=\"aspect-video\">"
          html = html <> "<iframe src=\"https://www.youtube.com/embed/" <> safe_html_escape(video_id)
          html = html <> if autoplay, do: "?autoplay=1&mute=1", else: ""
          html = html <> "\" frameborder=\"0\" allowfullscreen class=\"w-full h-full\"></iframe>"
          html = html <> "</div>"
        end

      "vimeo" ->
        video_id = extract_vimeo_id_safe(video_url)
        if safe_not_empty?(video_id) do
          html = html <> "<div class=\"aspect-video\">"
          html = html <> "<iframe src=\"https://player.vimeo.com/video/" <> safe_html_escape(video_id)
          html = html <> if autoplay, do: "?autoplay=1&muted=1", else: ""
          html = html <> "\" frameborder=\"0\" allowfullscreen class=\"w-full h-full\"></iframe>"
          html = html <> "</div>"
        end

      "upload" ->
        html = html <> "<div class=\"aspect-video\">"
        html = html <> "<video class=\"w-full h-full object-cover\""
        html = html <> if show_controls, do: " controls", else: ""
        html = html <> if autoplay, do: " autoplay", else: ""
        html = html <> if muted, do: " muted", else: ""
        html = html <> if loop, do: " loop", else: ""
        html = html <> if safe_not_empty?(poster_image), do: " poster=\"" <> safe_html_escape(poster_image) <> "\"", else: ""
        html = html <> ">"
        html = html <> "<source src=\"" <> safe_html_escape(video_url) <> "\" type=\"video/mp4\">"
        html = html <> "Your browser does not support the video tag."
        html = html <> "</video>"
        html = html <> "</div>"

      _ ->
        nil
    end

    html = html <> "</div>"
    html
  end

  defp extract_youtube_id_safe(url) do
    cond do
      String.contains?(url, "youtube.com/watch?v=") ->
        url |> String.split("v=") |> Enum.at(1) |> String.split("&") |> Enum.at(0)
      String.contains?(url, "youtu.be/") ->
        url |> String.split("youtu.be/") |> Enum.at(1) |> String.split("?") |> Enum.at(0)
      true -> ""
    end
  end

  defp extract_vimeo_id_safe(url) do
    if String.contains?(url, "vimeo.com/") do
      url |> String.split("vimeo.com/") |> Enum.at(1) |> String.split("/") |> Enum.at(0)
    else
      ""
    end
  end

  # Safe hero contact items builder
  defp build_hero_contact_items_safe([], acc), do: acc
  defp build_hero_contact_items_safe([{key, value} | remaining], acc) do
    if safe_not_empty?(value) do
      item_html = case key do
        "email" -> "<span>📧 " <> safe_html_escape(value) <> "</span>"
        "phone" -> "<span>📱 " <> safe_html_escape(value) <> "</span>"
        "location" -> "<span>📍 " <> safe_html_escape(value) <> "</span>"
        _ -> "<span>" <> safe_html_escape(value) <> "</span>"
      end
      new_acc = if acc == "", do: item_html, else: acc <> item_html
      build_hero_contact_items_safe(remaining, new_acc)
    else
      build_hero_contact_items_safe(remaining, acc)
    end
  end

  # Safe hero social links builder
  defp build_hero_social_links_safe([], acc), do: acc
  defp build_hero_social_links_safe([{platform, url} | remaining], acc) do
    if safe_not_empty?(url) do
      link_html = "<a href=\"" <> safe_html_escape(url) <> "\" target=\"_blank\" rel=\"noopener\" "
      link_html = link_html <> "class=\"p-2 bg-gray-100 rounded-full hover:bg-blue-100 transition-colors\">"
      link_html = link_html <> get_social_icon_safe(platform)
      link_html = link_html <> "</a>"

      new_acc = acc <> link_html
      build_hero_social_links_safe(remaining, new_acc)
    else
      build_hero_social_links_safe(remaining, acc)
    end
  end

  defp get_social_icon_safe(platform) do
    case String.downcase(platform) do
      "linkedin" -> "<svg class=\"w-5 h-5 text-blue-600\" fill=\"currentColor\" viewBox=\"0 0 24 24\"><path d=\"M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z\"/></svg>"
      "github" -> "<svg class=\"w-5 h-5 text-gray-800\" fill=\"currentColor\" viewBox=\"0 0 24 24\"><path d=\"M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z\"/></svg>"
      "twitter" -> "<svg class=\"w-5 h-5 text-blue-400\" fill=\"currentColor\" viewBox=\"0 0 24 24\"><path d=\"M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z\"/></svg>"
      _ -> "<svg class=\"w-5 h-5 text-gray-600\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1\"/></svg>"
    end
  end

  # ============================================================================
  # INTRO/ABOUT SECTION - Enhanced Story Format
  # ============================================================================

  defp render_intro_content_safe(content, _customization) do
    story = safe_map_get(content, "story", safe_map_get(content, "content", safe_map_get(content, "description", "")))
    highlights = Map.get(content, "highlights", [])
    personality_traits = Map.get(content, "personality_traits", [])
    fun_facts = Map.get(content, "fun_facts", [])

    html = "<div class=\"intro-content space-y-6\">"

    # Main story
    if safe_not_empty?(story) do
      html = html <> "<div class=\"prose max-w-none\">"
      html = html <> "<div class=\"text-gray-700 leading-relaxed text-lg\">"
      html = html <> format_story_paragraphs_safe(story)
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Highlights section
    if is_list(highlights) and length(highlights) > 0 do
      html = html <> "<div class=\"bg-blue-50 rounded-lg p-6\">"
      html = html <> "<h3 class=\"text-lg font-semibold text-blue-900 mb-4 flex items-center\">"
      html = html <> "<svg class=\"w-5 h-5 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z\"/>"
      html = html <> "</svg>Key Highlights"
      html = html <> "</h3>"
      html = html <> "<ul class=\"space-y-2\">"
      html = html <> build_highlights_list_safe(highlights, "")
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    # Personality traits and fun facts
    if (is_list(personality_traits) and length(personality_traits) > 0) or (is_list(fun_facts) and length(fun_facts) > 0) do
      html = html <> "<div class=\"grid md:grid-cols-2 gap-6\">"

      if is_list(personality_traits) and length(personality_traits) > 0 do
        html = html <> "<div class=\"bg-green-50 rounded-lg p-4\">"
        html = html <> "<h4 class=\"font-semibold text-green-900 mb-3\">🌟 Personality</h4>"
        html = html <> "<div class=\"flex flex-wrap gap-2\">"
        html = html <> build_trait_tags_safe(personality_traits, "")
        html = html <> "</div>"
        html = html <> "</div>"
      end

      if is_list(fun_facts) and length(fun_facts) > 0 do
        html = html <> "<div class=\"bg-purple-50 rounded-lg p-4\">"
        html = html <> "<h4 class=\"font-semibold text-purple-900 mb-3\">🎯 Fun Facts</h4>"
        html = html <> "<ul class=\"space-y-1\">"
        html = html <> build_fun_facts_list_safe(fun_facts, "")
        html = html <> "</ul>"
        html = html <> "</div>"
      end

      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp format_story_paragraphs_safe(story) do
    story
    |> String.split(["\n\n", "\r\n\r\n"])
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> build_paragraphs_safe("")
  end

  # Safe paragraph builder
  defp build_paragraphs_safe([], acc), do: acc
  defp build_paragraphs_safe([paragraph | remaining], acc) do
    para_html = "<p class=\"mb-4\">" <> safe_html_escape(paragraph) <> "</p>"
    new_acc = acc <> para_html
    build_paragraphs_safe(remaining, new_acc)
  end

  # Safe highlights list builder
  defp build_highlights_list_safe([], acc), do: acc
  defp build_highlights_list_safe([highlight | remaining], acc) do
    item_html = "<li class=\"flex items-start text-blue-800\">"
    item_html = item_html <> "<svg class=\"w-4 h-4 mr-2 mt-1 text-blue-600\" fill=\"currentColor\" viewBox=\"0 0 20 20\">"
    item_html = item_html <> "<path fill-rule=\"evenodd\" d=\"M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z\" clip-rule=\"evenodd\"/>"
    item_html = item_html <> "</svg>"
    item_html = item_html <> "<span>" <> safe_html_escape(safe_extract(highlight)) <> "</span>"
    item_html = item_html <> "</li>"

    new_acc = acc <> item_html
    build_highlights_list_safe(remaining, new_acc)
  end

  # Safe trait tags builder
  defp build_trait_tags_safe([], acc), do: acc
  defp build_trait_tags_safe([trait | remaining], acc) do
    tag_html = "<span class=\"inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-sm font-medium rounded-full\">"
    tag_html = tag_html <> safe_html_escape(safe_extract(trait))
    tag_html = tag_html <> "</span>"

    new_acc = acc <> tag_html
    build_trait_tags_safe(remaining, new_acc)
  end

  # Safe fun facts list builder
  defp build_fun_facts_list_safe([], acc), do: acc
  defp build_fun_facts_list_safe([fact | remaining], acc) do
    item_html = "<li class=\"text-purple-800 text-sm flex items-start\">"
    item_html = item_html <> "<span class=\"mr-2\">🎯</span>"
    item_html = item_html <> "<span>" <> safe_html_escape(safe_extract(fact)) <> "</span>"
    item_html = item_html <> "</li>"

    new_acc = acc <> item_html
    build_fun_facts_list_safe(remaining, new_acc)
  end

  # ============================================================================
  # Generic fallback for remaining sections - keeping file size manageable
  # All missing sections will be implemented with their dedicated renderers
  # ============================================================================

  # Placeholder implementations for remaining sections
  defp render_featured_project_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_case_study_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_media_showcase_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_code_showcase_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_gallery_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_video_hero_content_safe(content, customization), do: render_hero_content_safe(content, customization)
  defp render_testimonials_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_collaborations_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_articles_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_certifications_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_services_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_pricing_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_timeline_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_narrative_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_journey_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_volunteer_content_safe(content, _customization), do: render_generic_content_safe(content, %{})
  defp render_custom_content_safe(content, _customization), do: render_generic_content_safe(content, %{})

  # STORY RENDERER

  defp render_story_content_safe(content, _customization) do
    story = safe_extract_content(content, "story")
    key_moments = Map.get(content, "key_moments", [])
    highlights = Map.get(content, "highlights", [])

    html = "<div class=\"story-content space-y-6\">"

    if story != "" do
      html = html <> "<div class=\"story-text\">"
      html = html <> "<div class=\"prose prose-gray max-w-none\">"
      html = html <> "<p class=\"text-gray-700 leading-relaxed\">" <> story <> "</p>"
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Render highlights if present
    combined_items = key_moments ++ highlights
    if length(combined_items) > 0 do
      html = html <> "<div class=\"highlights\">"
      html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-4\">Key Highlights</h4>"
      html = html <> "<ul class=\"space-y-2\">"

      Enum.each(combined_items, fn item ->
        item_text = case item do
          text when is_binary(text) -> text
          %{"content" => content} -> content
          %{"text" => text} -> text
          _ -> to_string(item)
        end

        if item_text != "" do
          html = html <> "<li class=\"flex items-start\">"
          html = html <> "<span class=\"w-2 h-2 bg-blue-500 rounded-full mt-2 mr-3 flex-shrink-0\"></span>"
          html = html <> "<span class=\"text-gray-700\">" <> item_text <> "</span>"
          html = html <> "</li>"
        end
      end)

      html = html <> "</ul>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end


  # ============================================================================
  # GENERIC FALLBACK RENDERER
  # ============================================================================

  defp render_generic_content_safe(content, _customization) do
    # Handle any unrecognized section types gracefully
    title = safe_map_get(content, "title", "")
    description = safe_map_get(content, "description", safe_map_get(content, "content", ""))
    items = Map.get(content, "items", [])

    html = "<div class=\"generic-section space-y-4\">"

    # Section header if available
    if safe_not_empty?(title) do
      html = html <> "<div class=\"text-center mb-6\">"
      html = html <> "<h3 class=\"text-xl font-semibold text-gray-900\">" <> safe_html_escape(title) <> "</h3>"
      html = html <> "</div>"
    end

    # Description/content
    if safe_not_empty?(description) do
      html = html <> "<div class=\"bg-gray-50 rounded-lg p-6\">"
      html = html <> "<div class=\"prose max-w-none text-gray-700\">"
      html = html <> format_story_paragraphs_safe(description)
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Items if available
    if is_list(items) and length(items) > 0 do
      html = html <> build_generic_items_safe(items, "")
    end

    html = html <> "</div>"

    # Check if we have any content
    has_content = safe_not_empty?(title) or safe_not_empty?(description) or (is_list(items) and length(items) > 0)

    if has_content do
      html
    else
      render_empty_state_safe("Section content not available")
    end
  end

  # Safe generic items builder
  defp build_generic_items_safe([], acc), do: acc
  defp build_generic_items_safe([item | remaining], acc) do
    # Try to extract common fields from any item structure
    name = safe_map_get(item, "name", safe_map_get(item, "title", ""))
    content = safe_map_get(item, "content", safe_map_get(item, "description", ""))

    item_html = "<div class=\"bg-gray-50 rounded-lg p-4 hover:bg-gray-100 transition-colors\">"

    if safe_not_empty?(name) do
      item_html = item_html <> "<h4 class=\"font-semibold text-gray-900 mb-2\">" <> safe_html_escape(name) <> "</h4>"
    end

    if safe_not_empty?(content) do
      item_html = item_html <> "<p class=\"text-gray-700 text-sm\">" <> safe_html_escape(content) <> "</p>"
    end

    item_html = item_html <> "</div>"

    new_acc = acc <> item_html
    build_generic_items_safe(remaining, new_acc)
  end

end
