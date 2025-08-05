# lib/frestyl_web/live/portfolio_live/components/enhanced_section_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer do
  @moduledoc """
  Enhanced section renderer supporting consolidated 17 portfolio section types.
  Fixed data flow from DynamicSectionModal with proper rendering for all section types.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]
  alias Phoenix.HTML

  # ============================================================================
  # SKILLS COLOR PALETTE - Different Hues as Requested
  # ============================================================================

  @skills_colors [
    "#EC4899",   # Pink-500
    "#8B5CF6",   # Purple-500
    "#06B6D4",   # Cyan-500
    "#10B981",   # Emerald-500
    "#F59E0B",   # Amber-500
    "#EF4444",   # Red-500
    "#6366F1"    # Indigo-500
  ]

  # ============================================================================
  # SAFE CONTENT UTILITIES
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

  defp clean_content_data_safe(content) when is_map(content) do
    content
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      clean_value = case value do
        {:safe, val} -> val
        val -> val
      end
      Map.put(acc, key, clean_value)
    end)
  end
  defp clean_content_data_safe(_), do: %{}

  defp get_default_color_scheme, do: "blue"

  # ============================================================================
  # MAIN RENDERING FUNCTION
  # ============================================================================

  def render_section_content_static(section, customization \\ %{}) do
    section_type_str = to_string(section.section_type)
    clean_content_data = clean_content_data_safe(section.content)

    # FIXED: Handle missing customization properly - no KeyError
    full_customization = case customization do
      %{} when map_size(customization) == 0 ->
        # Safely try to get customization from section, or use defaults
        section_customization = case Map.get(section, :customization) do
          custom when is_map(custom) -> custom
          _ -> %{}
        end
        Map.put(section_customization, "color_scheme", get_default_color_scheme())
      _ ->
        Map.put_new(customization, "color_scheme", get_default_color_scheme())
    end

    IO.puts("🎨 RENDERING SECTION: #{section_type_str}")
    IO.puts("🎨 CONTENT KEYS: #{inspect(Map.keys(clean_content_data))}")

    try do
      case section_type_str do
        # ESSENTIAL SECTIONS
        "hero" -> render_hero_content_safe(clean_content_data, full_customization)
        "intro" -> render_intro_content_safe(clean_content_data, full_customization)
        "contact" -> render_contact_content_safe(clean_content_data, full_customization)

        # PROFESSIONAL SECTIONS
        "experience" -> render_experience_content_safe(clean_content_data, full_customization)
        "education" -> render_education_content_safe(clean_content_data, full_customization)
        "skills" -> render_skills_content_safe(clean_content_data, full_customization)
        "projects" -> render_projects_content_safe(clean_content_data, full_customization)
        "certifications" -> render_certifications_content_safe(clean_content_data, full_customization)
        "services" -> render_services_content_safe(clean_content_data, full_customization)

        # CONTENT SECTIONS
        "achievements" -> render_achievements_content_safe(clean_content_data, full_customization)
        "testimonials" -> render_testimonials_content_safe(clean_content_data, full_customization)
        "published_articles" -> render_published_articles_content_safe(clean_content_data, full_customization)
        "collaborations" -> render_collaborations_content_safe(clean_content_data, full_customization)
        "timeline" -> render_timeline_content_safe(clean_content_data, full_customization)

        # MEDIA SECTIONS
        "gallery" -> render_gallery_content_safe(clean_content_data, full_customization)
        "blog" -> render_blog_content_safe(clean_content_data, full_customization)

        # FLEXIBLE
        "custom" -> render_custom_content_safe(clean_content_data, full_customization)

        # FALLBACK
        _ -> render_generic_content_safe(clean_content_data, full_customization)
      end
    rescue
      error ->
        IO.puts("❌ RENDERING ERROR for #{section_type_str}: #{inspect(error)}")
        render_error_state_safe(section_type_str, error)
    end
  end

  # ============================================================================
  # HERO SECTION RENDERER
  # ============================================================================

  defp render_hero_content_safe(content, _customization) do
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

    html = "<div class=\"hero-section relative bg-gradient-to-br from-blue-50 to-indigo-100 py-20\">"

    # Background handling
    if safe_not_empty?(background_image) do
      html = html <> "<div class=\"absolute inset-0 bg-cover bg-center opacity-20\" style=\"background-image: url('#{safe_html_escape(background_image)}');\"></div>"
    end

    html = html <> "<div class=\"relative z-10 max-w-4xl mx-auto px-6 text-center\">"

    # Video section
    if video_type != "none" and safe_not_empty?(video_url) do
      html = html <> render_hero_video_safe(video_url, video_type)
      html = html <> "<div class=\"mt-8\">"
    end

    # Main content
    if safe_not_empty?(headline) do
      html = html <> "<h1 class=\"text-4xl md:text-6xl font-bold text-gray-900 leading-tight mb-6\">"
      html = html <> safe_html_escape(headline)
      html = html <> "</h1>"
    end

    if safe_not_empty?(tagline) do
      html = html <> "<h2 class=\"text-xl md:text-2xl text-blue-600 font-medium mb-4\">"
      html = html <> safe_html_escape(tagline)
      html = html <> "</h2>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-lg text-gray-600 max-w-2xl mx-auto leading-relaxed mb-8\">"
      html = html <> safe_html_escape(description)
      html = html <> "</p>"
    end

    # CTA Button
    if safe_not_empty?(cta_text) and safe_not_empty?(cta_link) do
      html = html <> "<div class=\"mb-8\">"
      html = html <> "<a href=\"" <> safe_html_escape(cta_link) <> "\" "
      html = html <> "class=\"inline-flex items-center px-8 py-4 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-all shadow-lg hover:shadow-xl transform hover:-translate-y-1\">"
      html = html <> safe_html_escape(cta_text)
      html = html <> "<svg class=\"w-5 h-5 ml-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17 8l4 4m0 0l-4 4m4-4H3\"/>"
      html = html <> "</svg>"
      html = html <> "</a>"
      html = html <> "</div>"
    end

    # Contact info and social links
    if map_size(contact_info) > 0 or map_size(social_links) > 0 do
      html = html <> "<div class=\"flex flex-wrap justify-center items-center gap-6 text-gray-600\">"

      # Contact info
      if map_size(contact_info) > 0 do
        html = html <> build_hero_contact_items_safe(Map.to_list(contact_info))
      end

      # Social links
      if map_size(social_links) > 0 do
        html = html <> "<div class=\"flex space-x-4\">"
        html = html <> build_hero_social_links_safe(Map.to_list(social_links))
        html = html <> "</div>"
      end

      html = html <> "</div>"
    end

    if video_type != "none" and safe_not_empty?(video_url) do
      html = html <> "</div>"
    end

    html = html <> "</div></div>"
    html
  end

  defp render_hero_video_safe(video_url, video_type) do
    case video_type do
      "youtube" ->
        video_id = extract_youtube_id_safe(video_url)
        if safe_not_empty?(video_id) do
          "<div class=\"aspect-video rounded-lg overflow-hidden shadow-2xl mb-6\"><iframe src=\"https://www.youtube.com/embed/#{video_id}\" class=\"w-full h-full\" frameborder=\"0\" allowfullscreen></iframe></div>"
        else
          ""
        end
      "vimeo" ->
        video_id = extract_vimeo_id_safe(video_url)
        if safe_not_empty?(video_id) do
          "<div class=\"aspect-video rounded-lg overflow-hidden shadow-2xl mb-6\"><iframe src=\"https://player.vimeo.com/video/#{video_id}\" class=\"w-full h-full\" frameborder=\"0\" allowfullscreen></iframe></div>"
        else
          ""
        end
      _ -> ""
    end
  end

  defp extract_youtube_id_safe(url) do
    cond do
      String.contains?(url, "watch?v=") ->
        url |> String.split("watch?v=") |> List.last() |> String.split("&") |> List.first()
      String.contains?(url, "youtu.be/") ->
        url |> String.split("youtu.be/") |> List.last() |> String.split("?") |> List.first()
      true -> ""
    end
  end

  defp extract_vimeo_id_safe(url) do
    url |> String.split("/") |> List.last() |> String.split("?") |> List.first()
  end

  defp build_hero_contact_items_safe(contact_list) do
    contact_list
    |> Enum.filter(fn {_key, value} -> safe_not_empty?(value) end)
    |> Enum.map(fn {key, value} ->
      icon = case key do
        "email" -> "📧"
        "phone" -> "📞"
        "location" -> "📍"
        _ -> "📄"
      end
      "<span class=\"flex items-center\">#{icon} #{safe_html_escape(value)}</span>"
    end)
    |> Enum.join(" ")
  end

  defp build_hero_social_links_safe(social_list) do
    social_list
    |> Enum.filter(fn {_key, value} -> safe_not_empty?(value) end)
    |> Enum.map(fn {platform, url} ->
      platform_name = String.capitalize(platform)
      "<a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800 transition-colors\">#{platform_name}</a>"
    end)
    |> Enum.join(" ")
  end

  # ============================================================================
  # INTRO SECTION RENDERER
  # ============================================================================

  defp render_intro_content_safe(content, _customization) do
    story = safe_map_get(content, "story", "")
    highlights = Map.get(content, "highlights", [])
    personality_traits = Map.get(content, "personality_traits", [])
    fun_facts = Map.get(content, "fun_facts", [])
    specialties = Map.get(content, "specialties", [])
    years_experience = Map.get(content, "years_experience", 0)
    current_focus = safe_map_get(content, "current_focus", "")

    html = "<div class=\"intro-section space-y-8 py-12\">"

    # Main story
    if safe_not_empty?(story) do
      html = html <> "<div class=\"bg-white rounded-lg shadow-md p-8\">"
      html = html <> "<div class=\"prose prose-lg max-w-none text-gray-700\">"
      html = html <> format_story_paragraphs_safe(story)
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Professional info grid
    if years_experience > 0 or safe_not_empty?(current_focus) or length(specialties) > 0 do
      html = html <> "<div class=\"grid md:grid-cols-3 gap-6\">"

      if years_experience > 0 do
        html = html <> "<div class=\"bg-blue-50 rounded-lg p-6 text-center\">"
        html = html <> "<div class=\"text-3xl font-bold text-blue-600\">#{years_experience}</div>"
        html = html <> "<div class=\"text-gray-600\">Years Experience</div>"
        html = html <> "</div>"
      end

      if safe_not_empty?(current_focus) do
        html = html <> "<div class=\"bg-green-50 rounded-lg p-6\">"
        html = html <> "<h4 class=\"font-semibold text-green-800 mb-2\">Current Focus</h4>"
        html = html <> "<p class=\"text-green-700\">#{safe_html_escape(current_focus)}</p>"
        html = html <> "</div>"
      end

      if length(specialties) > 0 do
        html = html <> "<div class=\"bg-purple-50 rounded-lg p-6\">"
        html = html <> "<h4 class=\"font-semibold text-purple-800 mb-3\">Specialties</h4>"
        html = html <> "<div class=\"flex flex-wrap gap-2\">"
        html = html <> build_tag_list_safe(specialties, "text-purple-700 bg-purple-100")
        html = html <> "</div>"
        html = html <> "</div>"
      end

      html = html <> "</div>"
    end

    # Highlights
    if length(highlights) > 0 do
      html = html <> "<div class=\"bg-white rounded-lg shadow-md p-8\">"
      html = html <> "<h3 class=\"text-xl font-semibold text-gray-900 mb-6\">Key Highlights</h3>"
      html = html <> "<ul class=\"space-y-3\">"
      html = html <> build_highlights_list_safe(highlights)
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    # Personality and fun facts
    if length(personality_traits) > 0 or length(fun_facts) > 0 do
      html = html <> "<div class=\"grid md:grid-cols-2 gap-6\">"

      if length(personality_traits) > 0 do
        html = html <> "<div class=\"bg-yellow-50 rounded-lg p-6\">"
        html = html <> "<h4 class=\"font-semibold text-yellow-800 mb-4\">Personality</h4>"
        html = html <> "<div class=\"flex flex-wrap gap-2\">"
        html = html <> build_tag_list_safe(personality_traits, "text-yellow-700 bg-yellow-100")
        html = html <> "</div>"
        html = html <> "</div>"
      end

      if length(fun_facts) > 0 do
        html = html <> "<div class=\"bg-pink-50 rounded-lg p-6\">"
        html = html <> "<h4 class=\"font-semibold text-pink-800 mb-4\">Fun Facts</h4>"
        html = html <> "<ul class=\"space-y-2\">"
        html = html <> build_fun_facts_list_safe(fun_facts)
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
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
    |> Enum.map(&("<p>#{safe_html_escape(&1)}</p>"))
    |> Enum.join("")
  end

  defp build_tag_list_safe(tags, css_class) do
    tags
    |> Enum.map(fn tag ->
      tag_text = case tag do
        text when is_binary(text) -> text
        _ -> to_string(tag)
      end
      "<span class=\"inline-block px-3 py-1 rounded-full text-sm #{css_class}\">#{safe_html_escape(tag_text)}</span>"
    end)
    |> Enum.join("")
  end

  defp build_highlights_list_safe(highlights) do
    highlights
    |> Enum.map(fn highlight ->
      highlight_text = case highlight do
        text when is_binary(text) -> text
        _ -> to_string(highlight)
      end
      "<li class=\"flex items-start\"><span class=\"w-2 h-2 bg-blue-500 rounded-full mt-2 mr-3 flex-shrink-0\"></span><span>#{safe_html_escape(highlight_text)}</span></li>"
    end)
    |> Enum.join("")
  end

  defp build_fun_facts_list_safe(facts) do
    facts
    |> Enum.map(fn fact ->
      fact_text = case fact do
        text when is_binary(text) -> text
        _ -> to_string(fact)
      end
      "<li class=\"flex items-start\"><span class=\"mr-2\">🎯</span><span>#{safe_html_escape(fact_text)}</span></li>"
    end)
    |> Enum.join("")
  end

  # ============================================================================
  # CONTACT SECTION RENDERER
  # ============================================================================

  defp render_contact_content_safe(content, _customization) do
    email = safe_map_get(content, "email", "")
    phone = safe_map_get(content, "phone", "")
    location = safe_map_get(content, "location", "")
    availability = safe_map_get(content, "availability", "")
    social_links = Map.get(content, "social_links", %{})
    preferred_contact = safe_map_get(content, "preferred_contact", "email")

    html = "<div class=\"contact-section bg-white rounded-lg shadow-md p-8\">"
    html = html <> "<div class=\"max-w-2xl mx-auto\">"

    # Main contact info
    html = html <> "<div class=\"grid md:grid-cols-2 gap-6 mb-8\">"

    if safe_not_empty?(email) do
      html = html <> "<div class=\"flex items-center p-4 bg-blue-50 rounded-lg\">"
      html = html <> "<div class=\"w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mr-4\">"
      html = html <> "<span class=\"text-2xl\">📧</span>"
      html = html <> "</div>"
      html = html <> "<div>"
      html = html <> "<div class=\"font-medium text-gray-900\">Email</div>"
      html = html <> "<a href=\"mailto:#{safe_html_escape(email)}\" class=\"text-blue-600 hover:text-blue-800\">#{safe_html_escape(email)}</a>"
      html = html <> "</div>"
      html = html <> "</div>"
    end

    if safe_not_empty?(phone) do
      html = html <> "<div class=\"flex items-center p-4 bg-green-50 rounded-lg\">"
      html = html <> "<div class=\"w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mr-4\">"
      html = html <> "<span class=\"text-2xl\">📞</span>"
      html = html <> "</div>"
      html = html <> "<div>"
      html = html <> "<div class=\"font-medium text-gray-900\">Phone</div>"
      html = html <> "<a href=\"tel:#{safe_html_escape(phone)}\" class=\"text-green-600 hover:text-green-800\">#{safe_html_escape(phone)}</a>"
      html = html <> "</div>"
      html = html <> "</div>"
    end

    if safe_not_empty?(location) do
      html = html <> "<div class=\"flex items-center p-4 bg-purple-50 rounded-lg\">"
      html = html <> "<div class=\"w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mr-4\">"
      html = html <> "<span class=\"text-2xl\">📍</span>"
      html = html <> "</div>"
      html = html <> "<div>"
      html = html <> "<div class=\"font-medium text-gray-900\">Location</div>"
      html = html <> "<div class=\"text-purple-600\">#{safe_html_escape(location)}</div>"
      html = html <> "</div>"
      html = html <> "</div>"
    end

    if safe_not_empty?(availability) do
      html = html <> "<div class=\"flex items-center p-4 bg-amber-50 rounded-lg\">"
      html = html <> "<div class=\"w-12 h-12 bg-amber-100 rounded-lg flex items-center justify-center mr-4\">"
      html = html <> "<span class=\"text-2xl\">⏰</span>"
      html = html <> "</div>"
      html = html <> "<div>"
      html = html <> "<div class=\"font-medium text-gray-900\">Availability</div>"
      html = html <> "<div class=\"text-amber-600\">#{safe_html_escape(availability)}</div>"
      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div>"

    # Preferred contact method
    if safe_not_empty?(preferred_contact) do
      html = html <> "<div class=\"text-center mb-6\">"
      html = html <> "<p class=\"text-gray-600\">Preferred contact method: <span class=\"font-medium text-gray-900\">#{String.capitalize(preferred_contact)}</span></p>"
      html = html <> "</div>"
    end

    # Social links
    if map_size(social_links) > 0 do
      html = html <> "<div class=\"border-t pt-6\">"
      html = html <> "<h4 class=\"font-semibold text-gray-900 mb-4 text-center\">Connect With Me</h4>"
      html = html <> "<div class=\"flex flex-wrap justify-center gap-4\">"
      html = html <> build_contact_social_links_safe(Map.to_list(social_links))
      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div></div>"
    html
  end

  defp build_contact_social_links_safe(social_list) do
    social_list
    |> Enum.filter(fn {_key, value} -> safe_not_empty?(value) end)
    |> Enum.map(fn {platform, url} ->
      platform_name = String.capitalize(platform)
      icon = get_social_icon(platform)
      "<a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"flex items-center px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors\">#{icon}<span class=\"ml-2\">#{platform_name}</span></a>"
    end)
    |> Enum.join("")
  end

  defp get_social_icon(platform) do
    case platform do
      "linkedin" -> "<span class=\"text-blue-600\">💼</span>"
      "github" -> "<span class=\"text-gray-800\">🐙</span>"
      "twitter" -> "<span class=\"text-blue-400\">🐦</span>"
      "website" -> "<span class=\"text-green-600\">🌐</span>"
      "behance" -> "<span class=\"text-blue-500\">🎨</span>"
      "dribbble" -> "<span class=\"text-pink-500\">⚡</span>"
      _ -> "<span class=\"text-gray-600\">🔗</span>"
    end
  end

  # ============================================================================
  # SKILLS SECTION RENDERER - WITH SPECIFIED COLORS
  # ============================================================================

  defp render_skills_content_safe(content, customization) do
    items = Map.get(content, "items", [])
    primary_color = Map.get(customization, "primary_color", "#3B82F6")

    if length(items) == 0 do
      render_empty_state_safe("No skills added yet")
    else
      # Group skills by category
      skills_by_category = group_skills_by_category(items)

      html = "<div class=\"skills-section space-y-8 py-12\">"
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900 mb-2\">Skills & Expertise</h3>"
      html = html <> "<p class=\"text-gray-600\">Technologies and skills I work with</p>"
      html = html <> "</div>"

      # Render each category
      {html, _} = Enum.reduce(skills_by_category, {html, 0}, fn {category, skills}, {acc_html, color_index} ->
        category_color = get_skills_category_color(color_index, primary_color)
        category_html = render_skills_category_safe(category, skills, category_color)
        {acc_html <> category_html, color_index + 1}
      end)

      html = html <> "</div>"
      html
    end
  end

  defp group_skills_by_category(items) do
    items
    |> Enum.group_by(fn item ->
      Map.get(item, "category", "other")
    end)
    |> Enum.sort_by(fn {category, _} ->
      case category do
        "frontend" -> 1
        "backend" -> 2
        "database" -> 3
        "devops" -> 4
        "design" -> 5
        "tools" -> 6
        "soft_skills" -> 7
        _ -> 8
      end
    end)
  end

  defp get_skills_category_color(index, primary_color) do
    colors = [primary_color | @skills_colors]
    color_index = rem(index, length(colors))
    Enum.at(colors, color_index)
  end

  defp render_skills_category_safe(category, skills, color) do
    category_name = get_category_display_name(category)

    html = "<div class=\"skills-category mb-8\">"
    html = html <> "<h4 class=\"text-lg font-semibold mb-4\" style=\"color: #{color}\">#{category_name}</h4>"
    html = html <> "<div class=\"grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4\">"

    skills_html = skills
    |> Enum.map(&render_skill_item_safe(&1, color))
    |> Enum.join("")

    html = html <> skills_html
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp get_category_display_name(category) do
    case category do
      "frontend" -> "Frontend Development"
      "backend" -> "Backend Development"
      "database" -> "Database & Storage"
      "devops" -> "DevOps & Infrastructure"
      "design" -> "Design & UI/UX"
      "soft_skills" -> "Soft Skills"
      "tools" -> "Tools & Utilities"
      "other" -> "Other Skills"
      _ -> String.capitalize(category)
    end
  end

  defp render_skill_item_safe(skill, color) do
    name = safe_map_get(skill, "name", "")
    proficiency = safe_map_get(skill, "proficiency", "intermediate")
    years_experience = Map.get(skill, "years_experience", 0)
    description = safe_map_get(skill, "description", "")

    proficiency_width = case proficiency do
      "beginner" -> "25%"
      "intermediate" -> "50%"
      "advanced" -> "75%"
      "expert" -> "100%"
      _ -> "50%"
    end

    html = "<div class=\"skill-item bg-white rounded-lg shadow-sm border p-4 hover:shadow-md transition-shadow\">"
    html = html <> "<div class=\"flex justify-between items-start mb-2\">"
    html = html <> "<h5 class=\"font-medium text-gray-900\">#{safe_html_escape(name)}</h5>"
    html = html <> "<span class=\"text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded\">#{String.capitalize(proficiency)}</span>"
    html = html <> "</div>"

    # Proficiency bar
    html = html <> "<div class=\"mb-3\">"
    html = html <> "<div class=\"w-full bg-gray-200 rounded-full h-2\">"
    html = html <> "<div class=\"h-2 rounded-full transition-all\" style=\"width: #{proficiency_width}; background-color: #{color}\"></div>"
    html = html <> "</div>"
    html = html <> "</div>"

    # Additional info
    if years_experience > 0 or safe_not_empty?(description) do
      html = html <> "<div class=\"text-sm text-gray-600\">"
      if years_experience > 0 do
        html = html <> "<div>#{years_experience} years experience</div>"
      end
      if safe_not_empty?(description) do
        html = html <> "<div class=\"mt-1\">#{safe_html_escape(description)}</div>"
      end
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  # ============================================================================
  # EXPERIENCE SECTION RENDERER
  # ============================================================================

  defp render_experience_content_safe(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No work experience added yet")
    else
      html = "<div class=\"experience-section space-y-6 py-12\">"
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900 mb-2\">Work Experience</h3>"
      html = html <> "<p class=\"text-gray-600\">My professional journey and achievements</p>"
      html = html <> "</div>"

      # Sort by start date (most recent first)
      sorted_items = sort_experience_items(items)

      experience_html = sorted_items
      |> Enum.map(&render_experience_item_safe/1)
      |> Enum.join("")

      html = html <> "<div class=\"space-y-8\">" <> experience_html <> "</div>"
      html = html <> "</div>"
      html
    end
  end

  defp sort_experience_items(items) do
    items
    |> Enum.sort_by(fn item ->
      start_date = Map.get(item, "start_date", "")
      parse_date_for_sorting(start_date)
    end, &>=/2)
  end

  defp parse_date_for_sorting(date_str) when is_binary(date_str) do
    case String.split(date_str, "/") do
      [month, year] -> {String.to_integer(year), String.to_integer(month)}
      [year] -> {String.to_integer(year), 1}
      _ -> {0, 0}
    end
  rescue
    _ -> {0, 0}
  end
  defp parse_date_for_sorting(_), do: {0, 0}

  defp render_experience_item_safe(item) do
    title = safe_map_get(item, "title", "")
    company = safe_map_get(item, "company", "")
    location = safe_map_get(item, "location", "")
    start_date = safe_map_get(item, "start_date", "")
    end_date = safe_map_get(item, "end_date", "")
    description = safe_map_get(item, "description", "")
    technologies = Map.get(item, "technologies", [])
    achievements = Map.get(item, "achievements", [])
    company_url = safe_map_get(item, "company_url", "")

    html = "<div class=\"experience-item bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow\">"

    # Header
    html = html <> "<div class=\"flex flex-col md:flex-row md:justify-between md:items-start mb-4\">"
    html = html <> "<div>"
    html = html <> "<h4 class=\"text-xl font-semibold text-gray-900\">#{safe_html_escape(title)}</h4>"

    if safe_not_empty?(company) do
      company_html = if safe_not_empty?(company_url) do
        "<a href=\"#{safe_html_escape(company_url)}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800 text-lg font-medium\">#{safe_html_escape(company)}</a>"
      else
        "<span class=\"text-blue-600 text-lg font-medium\">#{safe_html_escape(company)}</span>"
      end
      html = html <> company_html
    end

    if safe_not_empty?(location) do
      html = html <> "<div class=\"text-gray-600\">📍 #{safe_html_escape(location)}</div>"
    end
    html = html <> "</div>"

    # Date range
    html = html <> "<div class=\"text-right\">"
    if safe_not_empty?(start_date) do
      date_range = if safe_not_empty?(end_date) and end_date != "Present" do
        "#{start_date} - #{end_date}"
      else
        "#{start_date} - Present"
      end
      html = html <> "<span class=\"text-gray-600 bg-gray-100 px-3 py-1 rounded-full text-sm\">#{safe_html_escape(date_range)}</span>"
    end
    html = html <> "</div>"
    html = html <> "</div>"

    # Description
    if safe_not_empty?(description) do
      html = html <> "<div class=\"mb-4\">"
      html = html <> "<div class=\"prose text-gray-700\">"
      html = html <> format_story_paragraphs_safe(description)
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Achievements
    if length(achievements) > 0 do
      html = html <> "<div class=\"mb-4\">"
      html = html <> "<h5 class=\"font-medium text-gray-900 mb-2\">Key Achievements</h5>"
      html = html <> "<ul class=\"space-y-1\">"
      html = html <> build_achievements_list_safe(achievements)
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    # Technologies
    if length(technologies) > 0 do
      html = html <> "<div class=\"flex flex-wrap gap-2\">"
      html = html <> build_tag_list_safe(technologies, "text-blue-700 bg-blue-100")
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp build_achievements_list_safe(achievements) do
    achievements
    |> Enum.map(fn achievement ->
      achievement_text = case achievement do
        text when is_binary(text) -> text
        _ -> to_string(achievement)
      end
      "<li class=\"flex items-start\"><span class=\"text-green-500 mr-2 mt-1\">✓</span><span>#{safe_html_escape(achievement_text)}</span></li>"
    end)
    |> Enum.join("")
  end

  # ============================================================================
  # EDUCATION SECTION RENDERER
  # ============================================================================

  defp render_education_content_safe(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No education information added yet")
    else
      html = "<div class=\"education-section space-y-6 py-12\">"
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900 mb-2\">Education</h3>"
      html = html <> "<p class=\"text-gray-600\">Academic background and qualifications</p>"
      html = html <> "</div>"

      # Sort by graduation date (most recent first)
      sorted_items = sort_education_items(items)

      education_html = sorted_items
      |> Enum.map(&render_education_item_safe/1)
      |> Enum.join("")

      html = html <> "<div class=\"space-y-6\">" <> education_html <> "</div>"
      html = html <> "</div>"
      html
    end
  end

  defp sort_education_items(items) do
    items
    |> Enum.sort_by(fn item ->
      graduation_date = Map.get(item, "graduation_date", "")
      parse_date_for_sorting(graduation_date)
    end, &>=/2)
  end

  defp render_education_item_safe(item) do
    degree = safe_map_get(item, "degree", "")
    field = safe_map_get(item, "field", "")
    institution = safe_map_get(item, "institution", "")
    location = safe_map_get(item, "location", "")
    graduation_date = safe_map_get(item, "graduation_date", "")
    gpa = safe_map_get(item, "gpa", "")
    honors = Map.get(item, "honors", [])
    relevant_coursework = Map.get(item, "relevant_coursework", [])

    html = "<div class=\"education-item bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow\">"

    # Header with degree and institution
    html = html <> "<div class=\"flex flex-col lg:flex-row lg:justify-between lg:items-start mb-4\">"
    html = html <> "<div class=\"flex-1\">"

    # Degree and field
    html =
      cond do
        safe_not_empty?(degree) and safe_not_empty?(field) ->
          html <> "<h4 class=\"text-xl font-semibold text-gray-900 mb-1\">#{safe_html_escape(degree)} in #{safe_html_escape(field)}</h4>"

        safe_not_empty?(degree) ->
          html <> "<h4 class=\"text-xl font-semibold text-gray-900 mb-1\">#{safe_html_escape(degree)}</h4>"

        safe_not_empty?(field) ->
          html <> "<h4 class=\"text-xl font-semibold text-gray-900 mb-1\">#{safe_html_escape(field)}</h4>"

        true ->
          html
      end

    # Institution
    if safe_not_empty?(institution) do
      html = html <> "<div class=\"text-blue-600 text-lg font-medium mb-1\">#{safe_html_escape(institution)}</div>"
    end

    # Location
    if safe_not_empty?(location) do
      html = html <> "<div class=\"text-gray-600 flex items-center\">"
      html = html <> "<svg class=\"w-4 h-4 mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z\"/>"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 11a3 3 0 11-6 0 3 3 0 016 0z\"/>"
      html = html <> "</svg>"
      html = html <> safe_html_escape(location)
      html = html <> "</div>"
    end

    html = html <> "</div>" # end .flex-1

    # Right section
    html = html <> "<div class=\"lg:text-right mt-2 lg:mt-0 lg:ml-4\">"

    # Graduation date
    if safe_not_empty?(graduation_date) do
      html = html <> "<div class=\"inline-block lg:block mb-2\">"
      html = html <> "<span class=\"text-gray-600 bg-gray-100 px-3 py-1 rounded-full text-sm font-medium\">"
      html = html <> "<svg class=\"w-4 h-4 inline mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z\"/>"
      html = html <> "</svg>"
      html = html <> safe_html_escape(graduation_date)
      html = html <> "</span>"
      html = html <> "</div>"
    end

    # GPA
    if safe_not_empty?(gpa) do
      html = html <> "<div class=\"inline-block lg:block\">"
      html = html <> "<span class=\"text-green-700 bg-green-100 px-3 py-1 rounded-full text-sm font-semibold\">"
      html = html <> "<svg class=\"w-4 h-4 inline mr-1\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z\"/>"
      html = html <> "</svg>"
      html = html <> "GPA: #{safe_html_escape(gpa)}"
      html = html <> "</span>"
      html = html <> "</div>"
    end

    html = html <> "</div>" # end right section
    html = html <> "</div>" # end header

    # Honors and recognition
    if length(honors) > 0 do
      html = html <> "<div class=\"mb-4 p-4 bg-yellow-50 rounded-lg border-l-4 border-yellow-400\">"
      html = html <> "<h5 class=\"font-semibold text-yellow-800 mb-3 flex items-center\">"
      html = html <> "<svg class=\"w-5 h-5 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z\"/>"
      html = html <> "</svg>"
      html = html <> "Honors & Recognition"
      html = html <> "</h5>"
      html = html <> "<div class=\"flex flex-wrap gap-2\">"

      honors_html =
        honors
        |> Enum.map(fn honor ->
          honor_text = case honor do
            text when is_binary(text) -> text
            _ -> to_string(honor)
          end
          "<span class=\"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-yellow-100 text-yellow-800 border border-yellow-200\">#{safe_html_escape(honor_text)}</span>"
        end)
        |> Enum.join("")

      html = html <> honors_html
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Relevant coursework
    if length(relevant_coursework) > 0 do
      html = html <> "<div class=\"p-4 bg-purple-50 rounded-lg border-l-4 border-purple-400\">"
      html = html <> "<h5 class=\"font-semibold text-purple-800 mb-3 flex items-center\">"
      html = html <> "<svg class=\"w-5 h-5 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">"
      html = html <> "<path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253\"/>"
      html = html <> "</svg>"
      html = html <> "Relevant Coursework"
      html = html <> "</h5>"
      html = html <> "<div class=\"flex flex-wrap gap-2\">"

      coursework_html =
        relevant_coursework
        |> Enum.map(fn course ->
          course_text = case course do
            text when is_binary(text) -> text
            _ -> to_string(course)
          end
          "<span class=\"inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800 border border-purple-200\">#{safe_html_escape(course_text)}</span>"
        end)
        |> Enum.join("")

      html = html <> coursework_html
      html = html <> "</div>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end


  # ============================================================================
  # PROJECTS SECTION RENDERER
  # ============================================================================

  defp render_projects_content_safe(content, _customization) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No projects added yet")
    else
      html = "<div class=\"projects-section space-y-8 py-12\">"
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900 mb-2\">Projects</h3>"
      html = html <> "<p class=\"text-gray-600\">Featured work and notable projects</p>"
      html = html <> "</div>"

      # Sort by start date (most recent first)
      sorted_items = sort_project_items(items)

      projects_html = sorted_items
      |> Enum.map(&render_project_item_safe/1)
      |> Enum.join("")

      html = html <> "<div class=\"grid md:grid-cols-2 gap-8\">" <> projects_html <> "</div>"
      html = html <> "</div>"
      html
    end
  end

  defp sort_project_items(items) do
    items
    |> Enum.sort_by(fn item ->
      start_date = Map.get(item, "start_date", "")
      parse_date_for_sorting(start_date)
    end, &>=/2)
  end

  defp render_project_item_safe(item) do
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    technologies = Map.get(item, "technologies", [])
    project_url = safe_map_get(item, "project_url", "")
    github_url = safe_map_get(item, "github_url", "")
    status = safe_map_get(item, "status", "completed")
    role = safe_map_get(item, "role", "")
    team_size = Map.get(item, "team_size", 0)

    html = "<div class=\"project-item bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow\">"

    # Header
    html = html <> "<div class=\"mb-4\">"
    html = html <> "<div class=\"flex justify-between items-start mb-2\">"
    html = html <> "<h4 class=\"text-xl font-semibold text-gray-900\">#{safe_html_escape(title)}</h4>"
    html = html <> "<span class=\"#{get_status_color_class(status)} px-2 py-1 rounded-full text-xs font-medium\">#{String.capitalize(status)}</span>"
    html = html <> "</div>"

    if safe_not_empty?(role) or team_size > 0 do
      html = html <> "<div class=\"text-gray-600 text-sm\">"
      if safe_not_empty?(role) do
        html = html <> "Role: #{safe_html_escape(role)}"
      end
      if team_size > 0 do
        team_text = if safe_not_empty?(role), do: " • Team size: #{team_size}", else: "Team size: #{team_size}"
        html = html <> team_text
      end
      html = html <> "</div>"
    end
    html = html <> "</div>"

    # Description
    if safe_not_empty?(description) do
      html = html <> "<div class=\"mb-4\">"
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
      html = html <> "</div>"
    end

    # Technologies
    if length(technologies) > 0 do
      html = html <> "<div class=\"mb-4\">"
      html = html <> "<div class=\"flex flex-wrap gap-2\">"
      html = html <> build_tag_list_safe(technologies, "text-blue-700 bg-blue-100")
      html = html <> "</div>"
      html = html <> "</div>"
    end

    # Links
    if safe_not_empty?(project_url) or safe_not_empty?(github_url) do
      html = html <> "<div class=\"flex space-x-4\">"

      if safe_not_empty?(project_url) do
        html = html <> "<a href=\"#{safe_html_escape(project_url)}\" target=\"_blank\" class=\"inline-flex items-center text-blue-600 hover:text-blue-800\">"
        html = html <> "<span class=\"mr-1\">🌐</span> Live Demo"
        html = html <> "</a>"
      end

      if safe_not_empty?(github_url) do
        html = html <> "<a href=\"#{safe_html_escape(github_url)}\" target=\"_blank\" class=\"inline-flex items-center text-gray-700 hover:text-gray-900\">"
        html = html <> "<span class=\"mr-1\">💻</span> Source Code"
        html = html <> "</a>"
      end

      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp get_status_color_class(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "in_progress" -> "bg-yellow-100 text-yellow-800"
      "planned" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  # ============================================================================
  # REMAINING SECTION RENDERERS - COMPLETE IMPLEMENTATIONS
  # ============================================================================

  defp render_certifications_content_safe(content, _customization) do
    render_items_section_safe(content, "Certifications", "Professional certifications and credentials", &render_certification_item_safe/1)
  end

  defp render_services_content_safe(content, _customization) do
    render_items_section_safe(content, "Services", "Services and packages offered", &render_service_item_safe/1)
  end

  defp render_achievements_content_safe(content, _customization) do
    render_items_section_safe(content, "Achievements & Awards", "Recognition and accomplishments", &render_achievement_item_safe/1)
  end

  defp render_testimonials_content_safe(content, _customization) do
    render_items_section_safe(content, "Testimonials", "What clients and colleagues say", &render_testimonial_item_safe/1)
  end

  defp render_published_articles_content_safe(content, _customization) do
    render_items_section_safe(content, "Publications & Writing", "Articles, blog posts, and written content", &render_article_item_safe/1)
  end

  defp render_collaborations_content_safe(content, _customization) do
    render_items_section_safe(content, "Collaborations", "Partnerships and joint projects", &render_collaboration_item_safe/1)
  end

  defp render_timeline_content_safe(content, _customization) do
    render_items_section_safe(content, "Timeline", "Career milestones and journey", &render_timeline_item_safe/1)
  end

  defp render_gallery_content_safe(content, _customization) do
    render_items_section_safe(content, "Gallery", "Visual portfolio and media", &render_gallery_item_safe/1)
  end

  defp render_blog_content_safe(content, _customization) do
    render_items_section_safe(content, "Blog", "Recent posts and articles", &render_blog_item_safe/1)
  end

  defp render_custom_content_safe(content, _customization) do
    section_title = safe_map_get(content, "section_title", "Custom Section")
    render_items_section_safe(content, section_title, "Custom content section", &render_custom_item_safe/1)
  end

  # Helper function for items-based sections
  defp render_items_section_safe(content, title, description, item_renderer) do
    items = Map.get(content, "items", [])

    if length(items) == 0 do
      render_empty_state_safe("No #{String.downcase(title)} added yet")
    else
      html = "<div class=\"items-section space-y-6 py-12\">"
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900 mb-2\">#{title}</h3>"
      html = html <> "<p class=\"text-gray-600\">#{description}</p>"
      html = html <> "</div>"

      items_html = items
      |> Enum.map(item_renderer)
      |> Enum.join("")

      html = html <> "<div class=\"space-y-6\">" <> items_html <> "</div>"
      html = html <> "</div>"
      html
    end
  end

  # Individual item renderers for all section types
  defp render_certification_item_safe(item) do
    name = safe_map_get(item, "name", "")
    issuer = safe_map_get(item, "issuer", "")
    issue_date = safe_map_get(item, "issue_date", "")
    credential_id = safe_map_get(item, "credential_id", "")
    verification_url = safe_map_get(item, "verification_url", "")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">#{safe_html_escape(name)}</h4>"
    html = html <> "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(issuer)}</div>"

    if safe_not_empty?(issue_date) do
      html = html <> "<div class=\"text-gray-600 mb-2\">Issued: #{safe_html_escape(issue_date)}</div>"
    end

    if safe_not_empty?(credential_id) do
      html = html <> "<div class=\"text-gray-600 mb-2\">Credential ID: #{safe_html_escape(credential_id)}</div>"
    end

    if safe_not_empty?(verification_url) do
      html = html <> "<a href=\"#{safe_html_escape(verification_url)}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800\">Verify Credential</a>"
    end

    html = html <> "</div>"
    html
  end

  defp render_service_item_safe(item) do
    name = safe_map_get(item, "name", "")
    description = safe_map_get(item, "description", "")
    price = safe_map_get(item, "price", "")
    duration = safe_map_get(item, "duration", "")
    deliverables = Map.get(item, "deliverables", [])

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<div class=\"flex justify-between items-start mb-4\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900\">#{safe_html_escape(name)}</h4>"
    if safe_not_empty?(price) do
      html = html <> "<span class=\"text-green-600 font-bold\">#{safe_html_escape(price)}</span>"
    end
    html = html <> "</div>"

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700 mb-4\">#{safe_html_escape(description)}</p>"
    end

    if safe_not_empty?(duration) do
      html = html <> "<div class=\"text-gray-600 mb-4\">⏱️ Duration: #{safe_html_escape(duration)}</div>"
    end

    if length(deliverables) > 0 do
      html = html <> "<div>"
      html = html <> "<h5 class=\"font-medium text-gray-900 mb-2\">Deliverables</h5>"
      html = html <> "<ul class=\"space-y-1\">"
      html = html <> build_achievements_list_safe(deliverables)
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp render_achievement_item_safe(item) do
    title = safe_map_get(item, "title", "")
    issuer = safe_map_get(item, "issuer", "")
    date = safe_map_get(item, "date", "")
    description = safe_map_get(item, "description", "")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<div class=\"flex items-start\">"
    html = html <> "<div class=\"w-12 h-12 bg-yellow-100 rounded-lg flex items-center justify-center mr-4\">"
    html = html <> "<span class=\"text-2xl\">🏆</span>"
    html = html <> "</div>"
    html = html <> "<div class=\"flex-1\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-1\">#{safe_html_escape(title)}</h4>"
    html = html <> "<div class=\"text-blue-600 font-medium mb-2\">#{safe_html_escape(issuer)}</div>"

    if safe_not_empty?(date) do
      html = html <> "<div class=\"text-gray-600 mb-2\">#{safe_html_escape(date)}</div>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_testimonial_item_safe(item) do
    quote = safe_map_get(item, "quote", "")
    author = safe_map_get(item, "author", "")
    title = safe_map_get(item, "title", "")
    company = safe_map_get(item, "company", "")
    rating = safe_map_get(item, "rating", "5")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<div class=\"mb-4\">"
    html = html <> "<div class=\"flex mb-2\">"

    # Star rating
    rating_num = case Integer.parse(rating) do
      {num, _} -> num
      _ -> 5
    end

    stars = for _ <- 1..rating_num, do: "⭐"
    html = html <> "<div>#{Enum.join(stars, "")}</div>"
    html = html <> "</div>"

    html = html <> "<blockquote class=\"text-gray-700 italic\">\"#{safe_html_escape(quote)}\"</blockquote>"
    html = html <> "</div>"

    html = html <> "<div class=\"border-t pt-4\">"
    html = html <> "<div class=\"font-semibold text-gray-900\">#{safe_html_escape(author)}</div>"

    if safe_not_empty?(title) or safe_not_empty?(company) do
      attribution = [title, company] |> Enum.filter(&safe_not_empty?/1) |> Enum.join(", ")
      html = html <> "<div class=\"text-gray-600\">#{safe_html_escape(attribution)}</div>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_article_item_safe(item) do
    title = safe_map_get(item, "title", "")
    publication = safe_map_get(item, "publication", "")
    publish_date = safe_map_get(item, "publish_date", "")
    url = safe_map_get(item, "url", "")
    excerpt = safe_map_get(item, "excerpt", "")
    read_time = safe_map_get(item, "read_time", "")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">"

    if safe_not_empty?(url) do
      html = html <> "<a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"hover:text-blue-600\">#{safe_html_escape(title)}</a>"
    else
      html = html <> safe_html_escape(title)
    end

    html = html <> "</h4>"

    html = html <> "<div class=\"flex items-center text-gray-600 text-sm mb-3\">"
    html = html <> "<span>#{safe_html_escape(publication)}</span>"

    if safe_not_empty?(publish_date) do
      html = html <> "<span class=\"mx-2\">•</span>"
      html = html <> "<span>#{safe_html_escape(publish_date)}</span>"
    end

    if safe_not_empty?(read_time) do
      html = html <> "<span class=\"mx-2\">•</span>"
      html = html <> "<span>#{safe_html_escape(read_time)}</span>"
    end

    html = html <> "</div>"

    if safe_not_empty?(excerpt) do
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(excerpt)}</p>"
    end

    html = html <> "</div>"
    html
  end

  defp render_collaboration_item_safe(item) do
    title = safe_map_get(item, "title", "")
    partner = safe_map_get(item, "partner", "")
    description = safe_map_get(item, "description", "")
    role = safe_map_get(item, "role", "")
    outcomes = Map.get(item, "outcomes", [])

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">#{safe_html_escape(title)}</h4>"
    html = html <> "<div class=\"text-blue-600 font-medium mb-2\">with #{safe_html_escape(partner)}</div>"

    if safe_not_empty?(role) do
      html = html <> "<div class=\"text-gray-600 mb-3\">Role: #{safe_html_escape(role)}</div>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700 mb-4\">#{safe_html_escape(description)}</p>"
    end

    if length(outcomes) > 0 do
      html = html <> "<div>"
      html = html <> "<h5 class=\"font-medium text-gray-900 mb-2\">Outcomes</h5>"
      html = html <> "<ul class=\"space-y-1\">"
      html = html <> build_achievements_list_safe(outcomes)
      html = html <> "</ul>"
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp render_timeline_item_safe(item) do
    date = safe_map_get(item, "date", "")
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    category = safe_map_get(item, "category", "career")
    location = safe_map_get(item, "location", "")

    category_color = case category do
      "career" -> "bg-blue-100 text-blue-800"
      "education" -> "bg-green-100 text-green-800"
      "personal" -> "bg-purple-100 text-purple-800"
      "achievement" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<div class=\"flex items-start\">"
    html = html <> "<div class=\"w-16 h-16 bg-gray-100 rounded-lg flex items-center justify-center mr-4 flex-shrink-0\">"
    html = html <> "<span class=\"text-xl\">📅</span>"
    html = html <> "</div>"
    html = html <> "<div class=\"flex-1\">"

    html = html <> "<div class=\"flex items-center mb-2\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mr-3\">#{safe_html_escape(title)}</h4>"
    html = html <> "<span class=\"#{category_color} px-2 py-1 rounded-full text-xs font-medium\">#{String.capitalize(category)}</span>"
    html = html <> "</div>"

    html = html <> "<div class=\"text-gray-600 mb-2\">"
    html = html <> "<span>#{safe_html_escape(date)}</span>"
    if safe_not_empty?(location) do
      html = html <> "<span class=\"mx-2\">•</span>"
      html = html <> "<span>#{safe_html_escape(location)}</span>"
    end
    html = html <> "</div>"

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
    end

    html = html <> "</div>"
    html = html <> "</div>"
    html = html <> "</div>"
    html
  end

  defp render_gallery_item_safe(item) do
    title = safe_map_get(item, "title", "")
    description = safe_map_get(item, "description", "")
    category = safe_map_get(item, "category", "")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<div class=\"aspect-video bg-gray-200 rounded-lg mb-4 flex items-center justify-center\">"
    html = html <> "<span class=\"text-4xl\">🖼️</span>"
    html = html <> "</div>"

    if safe_not_empty?(title) do
      html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">#{safe_html_escape(title)}</h4>"
    end

    if safe_not_empty?(category) do
      html = html <> "<div class=\"text-blue-600 text-sm font-medium mb-2\">#{safe_html_escape(category)}</div>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
    end

    html = html <> "</div>"
    html
  end

  defp render_blog_item_safe(item) do
    title = safe_map_get(item, "title", "")
    excerpt = safe_map_get(item, "excerpt", "")
    url = safe_map_get(item, "url", "")
    publish_date = safe_map_get(item, "publish_date", "")
    tags = Map.get(item, "tags", [])

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">"

    if safe_not_empty?(url) do
      html = html <> "<a href=\"#{safe_html_escape(url)}\" target=\"_blank\" class=\"hover:text-blue-600\">#{safe_html_escape(title)}</a>"
    else
      html = html <> safe_html_escape(title)
    end

    html = html <> "</h4>"

    if safe_not_empty?(publish_date) do
      html = html <> "<div class=\"text-gray-600 text-sm mb-3\">#{safe_html_escape(publish_date)}</div>"
    end

    if safe_not_empty?(excerpt) do
      html = html <> "<p class=\"text-gray-700 mb-4\">#{safe_html_escape(excerpt)}</p>"
    end

    if length(tags) > 0 do
      html = html <> "<div class=\"flex flex-wrap gap-2\">"
      html = html <> build_tag_list_safe(tags, "text-blue-700 bg-blue-100")
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  defp render_custom_item_safe(item) do
    title = safe_map_get(item, "title", "")
    content = safe_map_get(item, "content", "")
    link = safe_map_get(item, "link", "")
    date = safe_map_get(item, "date", "")
    tags = Map.get(item, "tags", [])
    additional_info = safe_map_get(item, "additional_info", "")

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"

    html = html <> "<div class=\"flex justify-between items-start mb-3\">"
    html = html <> "<h4 class=\"text-lg font-semibold text-gray-900\">"

    if safe_not_empty?(link) do
      html = html <> "<a href=\"#{safe_html_escape(link)}\" target=\"_blank\" class=\"hover:text-blue-600\">#{safe_html_escape(title)}</a>"
    else
      html = html <> safe_html_escape(title)
    end

    html = html <> "</h4>"

    if safe_not_empty?(date) do
      html = html <> "<span class=\"text-gray-600 text-sm\">#{safe_html_escape(date)}</span>"
    end

    html = html <> "</div>"

    if safe_not_empty?(content) do
      html = html <> "<p class=\"text-gray-700 mb-4\">#{safe_html_escape(content)}</p>"
    end

    if safe_not_empty?(additional_info) do
      html = html <> "<div class=\"text-gray-600 text-sm mb-4\">#{safe_html_escape(additional_info)}</div>"
    end

    if length(tags) > 0 do
      html = html <> "<div class=\"flex flex-wrap gap-2\">"
      html = html <> build_tag_list_safe(tags, "text-gray-700 bg-gray-100")
      html = html <> "</div>"
    end

    html = html <> "</div>"
    html
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp render_empty_state_safe(message) do
    """
    <div class="text-center py-12 text-gray-500">
      <div class="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mb-4">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
      </div>
      <p class="text-sm">#{safe_html_escape(message)}</p>
    </div>
    """
  end

  defp render_error_state_safe(section_type, error) do
    """
    <div class="bg-red-50 border border-red-200 rounded-lg p-6 text-center">
      <div class="text-red-600 mb-2">
        <svg class="w-8 h-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16c-.77.833.192 2.5 1.732 2.5z"/>
        </svg>
      </div>
      <p class="text-red-800 font-medium">Error rendering #{String.capitalize(section_type)} section</p>
      <p class="text-red-600 text-sm mt-2">Please check the section configuration and try again.</p>
    </div>
    """
  end

  defp render_generic_content_safe(content, _customization) do
    title = safe_map_get(content, "title", "")
    description = safe_map_get(content, "description", "")
    items = Map.get(content, "items", [])

    html = "<div class=\"generic-section space-y-6 py-12\">"

    if safe_not_empty?(title) do
      html = html <> "<div class=\"text-center mb-8\">"
      html = html <> "<h3 class=\"text-2xl font-bold text-gray-900\">#{safe_html_escape(title)}</h3>"
      html = html <> "</div>"
    end

    if safe_not_empty?(description) do
      html = html <> "<div class=\"bg-white rounded-lg shadow-md p-8\">"
      html = html <> "<div class=\"prose max-w-none text-gray-700\">"
      html = html <> format_story_paragraphs_safe(description)
      html = html <> "</div>"
      html = html <> "</div>"
    end

    if length(items) > 0 do
      html = html <> "<div class=\"space-y-4\">"
      items_html = items
      |> Enum.map(&render_generic_item_safe/1)
      |> Enum.join("")
      html = html <> items_html
      html = html <> "</div>"
    end

    html = html <> "</div>"

    # Check if we have any meaningful content
    has_content = safe_not_empty?(title) or safe_not_empty?(description) or length(items) > 0

    if has_content do
      html
    else
      render_empty_state_safe("No content available for this section")
    end
  end

  defp render_generic_item_safe(item) when is_map(item) do
    title = safe_map_get(item, "title", safe_map_get(item, "name", ""))
    description = safe_map_get(item, "description", safe_map_get(item, "content", ""))

    html = "<div class=\"bg-white rounded-lg shadow-md p-6\">"

    if safe_not_empty?(title) do
      html = html <> "<h4 class=\"text-lg font-semibold text-gray-900 mb-2\">#{safe_html_escape(title)}</h4>"
    end

    if safe_not_empty?(description) do
      html = html <> "<p class=\"text-gray-700\">#{safe_html_escape(description)}</p>"
    end

    html = html <> "</div>"
    html
  end

  defp render_generic_item_safe(item) when is_binary(item) do
    "<div class=\"bg-white rounded-lg shadow-md p-6\"><p class=\"text-gray-700\">#{safe_html_escape(item)}</p></div>"
  end

  defp render_generic_item_safe(_), do: ""
end
