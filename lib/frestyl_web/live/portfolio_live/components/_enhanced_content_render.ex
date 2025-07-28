# PATCH 1: Enhanced Section-Specific Content Display
# File: lib/frestyl_web/live/portfolio_live/components/enhanced_content_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedContentRenderer do
  @moduledoc """
  PATCH 1: Enhanced content rendering for portfolio sections with proper type-specific display.
  Fixes section content rendering to show appropriate information for each section type.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [safe_to_string: 1, raw: 1]

  # ============================================================================
  # MAIN ENHANCED SECTION CONTENT RENDERER
  # ============================================================================

  def render_enhanced_section_content(section, color_scheme \\ "blue") do
    # Skip empty sections entirely
    unless section_has_content?(section) do
      ""
    else
      content = extract_safe_content(section.content || %{})

      case normalize_section_type(section.section_type) do
        :experience -> render_experience_content_enhanced(content, section.title)
        :education -> render_education_content_enhanced(content, section.title)
        :skills -> render_skills_content_enhanced(content, color_scheme, section.title)
        :projects -> render_projects_content_enhanced(content, section.title)
        :hero -> render_hero_content_enhanced(content, section.title)
        :about -> render_about_content_enhanced(content, section.title)
        :contact -> render_contact_content_enhanced(content, section.title)
        :testimonials -> render_testimonials_content_enhanced(content, section.title)
        :media_showcase -> render_media_content_enhanced(content, section.title)
        :custom -> render_custom_content_enhanced(content, section.title)
        _ -> render_generic_content_enhanced(content, section.title)
      end
    end
  end

  # ============================================================================
  # SECTION CONTENT DETECTION
  # ============================================================================

  defp section_has_content?(section) do
    content = section.content || %{}

    case normalize_section_type(section.section_type) do
      :experience ->
        has_experience_content?(content)
      :education ->
        has_education_content?(content)
      :skills ->
        has_skills_content?(content)
      :projects ->
        has_projects_content?(content)
      :hero ->
        has_hero_content?(content)
      :about ->
        has_about_content?(content)
      :contact ->
        has_contact_content?(content)
      :testimonials ->
        has_testimonials_content?(content)
      :media_showcase ->
        has_media_content?(content)
      _ ->
        has_generic_content?(content)
    end
  end

  # Content detection helpers
  defp has_experience_content?(content) do
    jobs = get_content_value(content, ["jobs", "experiences", "work_history"], [])
    length(jobs) > 0 || has_text_content?(content, ["summary", "description"])
  end

  defp has_education_content?(content) do
    education = get_content_value(content, ["education", "schools"], [])
    certifications = get_content_value(content, ["certifications"], [])
    length(education) > 0 || length(certifications) > 0
  end

  defp has_skills_content?(content) do
    skills = get_content_value(content, ["skills"], [])
    skill_categories = get_content_value(content, ["skill_categories"], %{})
    length(skills) > 0 || map_size(skill_categories) > 0
  end

  defp has_projects_content?(content) do
    projects = get_content_value(content, ["projects"], [])
    length(projects) > 0 || has_text_content?(content, ["description", "summary"])
  end

  defp has_hero_content?(content) do
    has_text_content?(content, ["headline", "tagline", "summary"]) ||
    has_media_content?(content) ||
    has_social_content?(content)
  end

  defp has_about_content?(content) do
    has_text_content?(content, ["summary", "bio", "description", "story"])
  end

  defp has_contact_content?(content) do
    has_text_content?(content, ["email", "phone", "location"]) ||
    has_social_content?(content)
  end

  defp has_testimonials_content?(content) do
    testimonials = get_content_value(content, ["testimonials"], [])
    length(testimonials) > 0
  end

  defp has_media_content?(content) do
    media_fields = ["video_url", "image_url", "audio_url", "media_files", "attachments"]
    Enum.any?(media_fields, fn field ->
      value = get_content_value(content, [field])
      value != nil && value != ""
    end)
  end

  defp has_social_content?(content) do
    social_links = get_content_value(content, ["social_links"], %{})
    map_size(social_links) > 0
  end

  defp has_text_content?(content, fields) when is_list(fields) do
    Enum.any?(fields, fn field ->
      value = get_content_value(content, [field])
      value != nil && String.trim(to_string(value)) != ""
    end)
  end

  defp has_text_content?(content, field) when is_binary(field) do
    has_text_content?(content, [field])
  end

  defp has_generic_content?(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.any?(fn value ->
      case value do
        str when is_binary(str) -> String.trim(str) != ""
        list when is_list(list) -> length(list) > 0
        map when is_map(map) -> map_size(map) > 0
        _ -> value != nil
      end
    end)
  end

  # ============================================================================
  # ENHANCED EXPERIENCE CONTENT RENDERER
  # ============================================================================

  defp render_experience_content_enhanced(content, section_title) do
    jobs = get_content_value(content, ["jobs", "experiences", "work_history"], [])
    summary = get_content_value(content, ["summary", "description"], "")

    jobs_html = if length(jobs) > 0 do
      job_items = Enum.map(jobs, fn job ->
        # Extract job information with multiple fallback keys
        role = get_job_value(job, ["role", "title", "position", "job_title"])
        company = get_job_value(job, ["company", "employer", "organization"])
        duties = get_job_value(job, ["duties", "responsibilities", "description", "achievements"])
        start_date = get_job_value(job, ["start_date", "from_date", "start"])
        end_date = get_job_value(job, ["end_date", "to_date", "end"], "Present")
        location = get_job_value(job, ["location", "city"])

        # Build date span
        date_span = case {start_date, end_date} do
          {"", ""} -> ""
          {start, ""} -> start
          {"", finish} -> finish
          {start, finish} -> "#{start} - #{finish}"
        end

        """
        <div class="experience-item border-l-4 border-blue-500 pl-6 pb-6 mb-6 last:mb-0">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between mb-2">
            <div class="flex-1">
              #{if role != "", do: "<h4 class='text-lg font-semibold text-gray-900'>#{role}</h4>", else: ""}
              #{if company != "", do: "<p class='text-blue-600 font-medium'>#{company}</p>", else: ""}
              #{if location != "", do: "<p class='text-sm text-gray-500'>#{location}</p>", else: ""}
            </div>
            #{if date_span != "", do: "<div class='text-sm text-gray-600 font-medium mt-1 sm:mt-0'>#{date_span}</div>", else: ""}
          </div>
          #{if duties != "", do: "<div class='text-gray-700 leading-relaxed'>#{format_duties_content(duties)}</div>", else: ""}
        </div>
        """
      end)

      Enum.join(job_items, "\n")
    else
      ""
    end

    summary_html = if summary != "" do
      "<div class='mb-6 p-4 bg-blue-50 rounded-lg border border-blue-200'>
        <p class='text-gray-700 leading-relaxed'>#{strip_html_safely(summary)}</p>
      </div>"
    else
      ""
    end

    """
    <div class="experience-section">
      #{summary_html}
      #{jobs_html}
    </div>
    """
  end

  # ============================================================================
  # ENHANCED EDUCATION CONTENT RENDERER
  # ============================================================================

  defp render_education_content_enhanced(content, section_title) do
    education = get_content_value(content, ["education", "schools"], [])
    certifications = get_content_value(content, ["certifications"], [])

    education_html = if length(education) > 0 do
      education_items = Enum.map(education, fn edu ->
        institution = get_edu_value(edu, ["institution", "school", "university"])
        degree = get_edu_value(edu, ["degree", "qualification", "title"])
        field = get_edu_value(edu, ["field", "major", "field_of_study"])
        graduation_date = get_edu_value(edu, ["graduation_date", "end_date", "date"])
        gpa = get_edu_value(edu, ["gpa", "grade"])
        location = get_edu_value(edu, ["location", "city"])

        # Build degree display
        degree_display = case {degree, field} do
          {"", ""} -> ""
          {deg, ""} -> deg
          {"", field_name} -> field_name
          {deg, field_name} -> "#{deg} in #{field_name}"
        end

        """
        <div class="education-item border-l-4 border-green-500 pl-6 pb-6 mb-6 last:mb-0">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between mb-2">
            <div class="flex-1">
              #{if institution != "", do: "<h4 class='text-lg font-semibold text-gray-900'>#{institution}</h4>", else: ""}
              #{if degree_display != "", do: "<p class='text-green-600 font-medium'>#{degree_display}</p>", else: ""}
              #{if location != "", do: "<p class='text-sm text-gray-500'>#{location}</p>", else: ""}
            </div>
            <div class='text-right'>
              #{if graduation_date != "", do: "<div class='text-sm text-gray-600 font-medium'>#{graduation_date}</div>", else: ""}
              #{if gpa != "", do: "<div class='text-sm text-gray-500'>GPA: #{gpa}</div>", else: ""}
            </div>
          </div>
        </div>
        """
      end)

      "<div class='education-list mb-6'>#{Enum.join(education_items, "\n")}</div>"
    else
      ""
    end

    certifications_html = if length(certifications) > 0 do
      cert_items = Enum.map(certifications, fn cert ->
        name = get_cert_value(cert, ["name", "title", "certification"])
        issuer = get_cert_value(cert, ["issuer", "organization", "authority"])
        date = get_cert_value(cert, ["date", "issue_date", "earned_date"])

        """
        <div class="certification-item bg-gray-50 p-4 rounded-lg mb-3 last:mb-0">
          <div class="flex justify-between items-start">
            <div>
              #{if name != "", do: "<h5 class='font-medium text-gray-900'>#{name}</h5>", else: ""}
              #{if issuer != "", do: "<p class='text-sm text-gray-600'>#{issuer}</p>", else: ""}
            </div>
            #{if date != "", do: "<span class='text-sm text-gray-500'>#{date}</span>", else: ""}
          </div>
        </div>
        """
      end)

      "<div class='certifications-section'>
        <h4 class='text-lg font-semibold text-gray-900 mb-4'>Certifications</h4>
        #{Enum.join(cert_items, "\n")}
      </div>"
    else
      ""
    end

    """
    <div class="education-section">
      #{education_html}
      #{certifications_html}
    </div>
    """
  end

  # ============================================================================
  # ENHANCED SKILLS CONTENT RENDERER WITH COLOR SCHEME INTEGRATION
  # ============================================================================

  defp render_skills_content_enhanced(content, color_scheme, section_title) do
    skills = get_content_value(content, ["skills"], [])
    skill_categories = get_content_value(content, ["skill_categories"], %{})

    # Get color scheme colors
    colors = get_color_scheme_colors(color_scheme)

    if map_size(skill_categories) > 0 do
      render_categorized_skills(skill_categories, colors)
    else
      render_flat_skills(skills, colors)
    end
  end

  defp render_categorized_skills(skill_categories, colors) do
    category_items = skill_categories
    |> Enum.with_index()
    |> Enum.map(fn {{category, category_skills}, index} ->
      color = Enum.at(colors, rem(index, length(colors)))

      skill_badges = category_skills
      |> Enum.map(fn skill ->
        skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
        proficiency = if is_map(skill), do: Map.get(skill, "proficiency"), else: nil

        proficiency_html = if proficiency do
          "<div class='text-xs text-gray-500 mt-1'>#{proficiency}%</div>"
        else
          ""
        end

        """
        <div class="skill-badge bg-white p-3 rounded-lg border shadow-sm hover:shadow-md transition-shadow">
          <div class="skill-indicator h-1 rounded-full mb-2" style="background-color: #{color}"></div>
          <div class="font-medium text-gray-900">#{skill_name}</div>
          #{proficiency_html}
        </div>
        """
      end)
      |> Enum.join("\n")

      """
      <div class="skill-category mb-8">
        <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <div class="w-4 h-4 rounded-full mr-3" style="background-color: #{color}"></div>
          #{category}
          <span class="ml-2 text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded-full">
            #{length(category_skills)}
          </span>
        </h4>
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          #{skill_badges}
        </div>
      </div>
      """
    end)

    """
    <div class="skills-categorized">
      #{Enum.join(category_items, "\n")}
    </div>
    """
  end

  defp render_flat_skills(skills, colors) do
    if length(skills) > 0 do
      skill_badges = skills
      |> Enum.with_index()
      |> Enum.map(fn {skill, index} ->
        skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
        proficiency = if is_map(skill), do: Map.get(skill, "proficiency"), else: nil
        color = Enum.at(colors, rem(index, length(colors)))

        proficiency_html = if proficiency do
          "<div class='text-xs text-gray-500 mt-1'>#{proficiency}%</div>"
        else
          ""
        end

        """
        <div class="skill-badge bg-white p-3 rounded-lg border shadow-sm hover:shadow-md transition-shadow">
          <div class="skill-indicator h-1 rounded-full mb-2" style="background-color: #{color}"></div>
          <div class="font-medium text-gray-900">#{skill_name}</div>
          #{proficiency_html}
        </div>
        """
      end)
      |> Enum.join("\n")

      """
      <div class="skills-flat">
        <div class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-3">
          #{skill_badges}
        </div>
      </div>
      """
    else
      ""
    end
  end

  # ============================================================================
  # ENHANCED MEDIA CONTENT RENDERER (Including Audio)
  # ============================================================================

  defp render_media_content_enhanced(content, section_title) do
    video_url = get_content_value(content, ["video_url"])
    image_url = get_content_value(content, ["image_url"])
    audio_url = get_content_value(content, ["audio_url"])
    media_files = get_content_value(content, ["media_files", "attachments"], [])
    description = get_content_value(content, ["description", "caption"], "")

    media_items = []

    # Video content
    if video_url && video_url != "" do
      video_html = """
      <div class="media-item video-item mb-6">
        <div class="aspect-video bg-gray-900 rounded-lg overflow-hidden">
          <video controls class="w-full h-full object-cover">
            <source src="#{video_url}" type="video/mp4">
            Your browser does not support the video tag.
          </video>
        </div>
        #{if description != "", do: "<p class='text-sm text-gray-600 mt-2'>#{strip_html_safely(description)}</p>", else: ""}
      </div>
      """
      media_items = [video_html | media_items]
    end

    # Audio content
    if audio_url && audio_url != "" do
      audio_html = """
      <div class="media-item audio-item mb-6">
        <div class="bg-gradient-to-r from-blue-500 to-purple-600 p-6 rounded-lg">
          <div class="flex items-center mb-4">
            <div class="w-12 h-12 bg-white bg-opacity-20 rounded-full flex items-center justify-center mr-4">
              <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"></path>
              </svg>
            </div>
            <div class="text-white">
              <h4 class="font-medium">Audio Content</h4>
              <p class="text-sm opacity-90">Click to play</p>
            </div>
          </div>
          <audio controls class="w-full">
            <source src="#{audio_url}" type="audio/mpeg">
            <source src="#{audio_url}" type="audio/wav">
            <source src="#{audio_url}" type="audio/ogg">
            Your browser does not support the audio element.
          </audio>
        </div>
        #{if description != "", do: "<p class='text-sm text-gray-600 mt-2'>#{strip_html_safely(description)}</p>", else: ""}
      </div>
      """
      media_items = [audio_html | media_items]
    end

    # Image content
    if image_url && image_url != "" do
      image_html = """
      <div class="media-item image-item mb-6">
        <div class="rounded-lg overflow-hidden shadow-lg">
          <img src="#{image_url}" alt="Portfolio media" class="w-full h-auto object-cover">
        </div>
        #{if description != "", do: "<p class='text-sm text-gray-600 mt-2'>#{strip_html_safely(description)}</p>", else: ""}
      </div>
      """
      media_items = [image_html | media_items]
    end

    # Additional media files
    if length(media_files) > 0 do
      file_items = Enum.map(media_files, fn file ->
        filename = Map.get(file, "filename", "Media file")
        file_url = Map.get(file, "url", "")
        file_type = Map.get(file, "type", "")

        icon = case file_type do
          type when type in ["image/jpeg", "image/png", "image/gif"] -> "🖼️"
          type when type in ["video/mp4", "video/avi", "video/mov"] -> "🎥"
          type when type in ["audio/mp3", "audio/wav", "audio/ogg"] -> "🎵"
          _ -> "📎"
        end

        """
        <div class="file-item flex items-center p-3 bg-gray-50 rounded-lg mb-2">
          <span class="text-2xl mr-3">#{icon}</span>
          <div class="flex-1">
            <p class="font-medium text-gray-900">#{filename}</p>
            <p class="text-sm text-gray-500">#{file_type}</p>
          </div>
          #{if file_url != "", do: "<a href='#{file_url}' target='_blank' class='text-blue-600 hover:text-blue-800 text-sm font-medium'>View</a>", else: ""}
        </div>
        """
      end)

      files_html = """
      <div class="media-files">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Additional Files</h4>
        #{Enum.join(file_items, "\n")}
      </div>
      """
      media_items = [files_html | media_items]
    end

    if length(media_items) > 0 do
      """
      <div class="media-showcase">
        #{Enum.join(Enum.reverse(media_items), "\n")}
      </div>
      """
    else
      ""
    end
  end

  # ============================================================================
  # COLOR SCHEME HELPER
  # ============================================================================

  defp get_color_scheme_colors(scheme) do
    case scheme do
      "blue" -> ["#1e40af", "#3b82f6", "#60a5fa"]
      "green" -> ["#065f46", "#059669", "#34d399"]
      "purple" -> ["#581c87", "#7c3aed", "#a78bfa"]
      "red" -> ["#991b1b", "#dc2626", "#f87171"]
      "orange" -> ["#ea580c", "#f97316", "#fb923c"]
      "teal" -> ["#0f766e", "#14b8a6", "#5eead4"]
      _ -> ["#3b82f6", "#60a5fa", "#93c5fd"] # Default blue
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp normalize_section_type(section_type) do
    case section_type do
      "experience" -> :experience
      "work_experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "hero" -> :hero
      "about" -> :about
      "intro" -> :about
      "contact" -> :contact
      "testimonials" -> :testimonials
      "media_showcase" -> :media_showcase
      "custom" -> :custom
      atom when is_atom(atom) -> atom
      _ -> :generic
    end
  end

  defp get_content_value(content, keys, default \\ "") when is_list(keys) do
    Enum.reduce_while(keys, default, fn key, _acc ->
      case Map.get(content, key) do
        nil -> {:cont, default}
        "" -> {:cont, default}
        [] -> {:cont, default}
        value -> {:halt, value}
      end
    end)
  end

  defp get_job_value(job, keys, default \\ "") do
    get_content_value(job, keys, default)
  end

  defp get_edu_value(edu, keys, default \\ "") do
    get_content_value(edu, keys, default)
  end

  defp get_cert_value(cert, keys, default \\ "") do
    get_content_value(cert, keys, default)
  end

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
    |> strip_html_safely()
  end

  defp extract_safe_value({:safe, html_content}) when is_binary(html_content) do
    strip_html_safely(html_content)
  end

  defp extract_safe_value(value) when is_list(value) do
    Enum.map(value, &extract_safe_value/1)
  end

  defp extract_safe_value(value) when is_map(value) do
    extract_safe_content(value)
  end

  defp extract_safe_value(value), do: value

  defp strip_html_safely(content) when is_binary(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&\w+;/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp strip_html_safely(content), do: to_string(content)

  defp format_duties_content(duties) when is_list(duties) do
    if length(duties) > 1 do
      "<ul class='list-disc list-inside space-y-1'>" <>
      Enum.map_join(duties, "", fn duty -> "<li>#{strip_html_safely(duty)}</li>" end) <>
      "</ul>"
    else
      strip_html_safely(List.first(duties) || "")
    end
  end

  defp format_duties_content(duties) when is_binary(duties) do
    # Check if it contains bullet points or line breaks that suggest a list
    if String.contains?(duties, ["\n•", "\n-", "\n*"]) do
      duties
      |> String.split(~r/\n[•\-\*]\s*/)
      |> Enum.reject(&(String.trim(&1) == ""))
      |> case do
        [single] -> strip_html_safely(single)
        items ->
          "<ul class='list-disc list-inside space-y-1'>" <>
          Enum.map_join(items, "", fn item -> "<li>#{strip_html_safely(item)}</li>" end) <>
          "</ul>"
      end
    else
      strip_html_safely(duties)
    end
  end

  defp format_duties_content(duties), do: strip_html_safely(to_string(duties))

  # Additional content renderers for other section types
  defp render_hero_content_enhanced(content, section_title) do
    headline = get_content_value(content, ["headline", "title"], "")
    tagline = get_content_value(content, ["tagline", "subtitle"], "")
    summary = get_content_value(content, ["summary", "description"], "")

    """
    <div class="hero-content text-center">
      #{if headline != "", do: "<h1 class='text-4xl font-bold text-gray-900 mb-4'>#{strip_html_safely(headline)}</h1>", else: ""}
      #{if tagline != "", do: "<p class='text-xl text-gray-600 mb-6'>#{strip_html_safely(tagline)}</p>", else: ""}
      #{if summary != "", do: "<p class='text-gray-700 leading-relaxed max-w-3xl mx-auto'>#{strip_html_safely(summary)}</p>", else: ""}
    </div>
    """
  end

  defp render_about_content_enhanced(content, section_title) do
    bio = get_content_value(content, ["bio", "summary", "description", "story"], "")
    highlights = get_content_value(content, ["highlights", "key_points"], [])

    highlights_html = if length(highlights) > 0 do
      highlight_items = Enum.map(highlights, fn highlight ->
        "<li class='flex items-start'><span class='text-blue-500 mr-2'>▸</span>#{strip_html_safely(highlight)}</li>"
      end)

      "<div class='mt-6'><h4 class='font-semibold text-gray-900 mb-3'>Key Highlights</h4><ul class='space-y-2'>#{Enum.join(highlight_items, "")}</ul></div>"
    else
      ""
    end

    """
    <div class="about-content">
      #{if bio != "", do: "<div class='text-gray-700 leading-relaxed mb-4'>#{strip_html_safely(bio)}</div>", else: ""}
      #{highlights_html}
    </div>
    """
  end

  defp render_contact_content_enhanced(content, section_title) do
    email = get_content_value(content, ["email"], "")
    phone = get_content_value(content, ["phone"], "")
    location = get_content_value(content, ["location", "city"], "")
    website = get_content_value(content, ["website"], "")
    social_links = get_content_value(content, ["social_links"], %{})

    contact_items = []

    if email != "" do
      contact_items = ["<div class='contact-item flex items-center mb-3'><svg class='w-5 h-5 text-blue-500 mr-3' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z'></path></svg><a href='mailto:#{email}' class='text-blue-600 hover:text-blue-800'>#{email}</a></div>" | contact_items]
    end

    if phone != "" do
      contact_items = ["<div class='contact-item flex items-center mb-3'><svg class='w-5 h-5 text-blue-500 mr-3' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z'></path></svg><a href='tel:#{phone}' class='text-blue-600 hover:text-blue-800'>#{phone}</a></div>" | contact_items]
    end

    if location != "" do
      contact_items = ["<div class='contact-item flex items-center mb-3'><svg class='w-5 h-5 text-blue-500 mr-3' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z'></path><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M15 11a3 3 0 11-6 0 3 3 0 016 0z'></path></svg><span class='text-gray-700'>#{location}</span></div>" | contact_items]
    end

    if website != "" do
      contact_items = ["<div class='contact-item flex items-center mb-3'><svg class='w-5 h-5 text-blue-500 mr-3' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9 3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9'></path></svg><a href='#{website}' target='_blank' class='text-blue-600 hover:text-blue-800'>#{website}</a></div>" | contact_items]
    end

    social_html = if map_size(social_links) > 0 do
      social_items = Enum.map(social_links, fn {platform, url} ->
        icon = get_social_icon(platform)
        platform_name = String.capitalize(to_string(platform))

        "<a href='#{url}' target='_blank' class='inline-flex items-center px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-gray-700 hover:text-gray-900 transition-colors mr-3 mb-3'>#{icon}<span class='ml-2'>#{platform_name}</span></a>"
      end)

      "<div class='social-links mt-6'><h4 class='font-semibold text-gray-900 mb-3'>Connect With Me</h4><div class='flex flex-wrap'>#{Enum.join(social_items, "")}</div></div>"
    else
      ""
    end

    """
    <div class="contact-content">
      #{if length(contact_items) > 0, do: Enum.join(Enum.reverse(contact_items), ""), else: ""}
      #{social_html}
    </div>
    """
  end

  defp render_testimonials_content_enhanced(content, section_title) do
    testimonials = get_content_value(content, ["testimonials"], [])

    if length(testimonials) > 0 do
      testimonial_items = Enum.map(testimonials, fn testimonial ->
        quote = get_content_value(testimonial, ["quote", "text", "content"], "")
        author = get_content_value(testimonial, ["author", "name"], "")
        title = get_content_value(testimonial, ["title", "position"], "")
        company = get_content_value(testimonial, ["company", "organization"], "")

        author_info = case {title, company} do
          {"", ""} -> author
          {title_val, ""} -> "#{author}, #{title_val}"
          {"", company_val} -> "#{author}, #{company_val}"
          {title_val, company_val} -> "#{author}, #{title_val} at #{company_val}"
        end

        """
        <div class="testimonial-item bg-gray-50 p-6 rounded-xl mb-6 last:mb-0">
          <div class="flex mb-4">
            #{String.duplicate("<svg class='w-5 h-5 text-yellow-400' fill='currentColor' viewBox='0 0 20 20'><path d='M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z'></path></svg>", 5)}
          </div>
          #{if quote != "", do: "<blockquote class='text-gray-700 leading-relaxed mb-4 italic'>\"#{strip_html_safely(quote)}\"</blockquote>", else: ""}
          #{if author_info != "", do: "<cite class='text-sm font-medium text-gray-900 not-italic'>— #{author_info}</cite>", else: ""}
        </div>
        """
      end)

      """
      <div class="testimonials-content">
        #{Enum.join(testimonial_items, "")}
      </div>
      """
    else
      ""
    end
  end

  defp render_projects_content_enhanced(content, section_title) do
    projects = get_content_value(content, ["projects"], [])
    summary = get_content_value(content, ["summary", "description"], "")

    summary_html = if summary != "" do
      "<div class='mb-6 p-4 bg-purple-50 rounded-lg border border-purple-200'><p class='text-gray-700 leading-relaxed'>#{strip_html_safely(summary)}</p></div>"
    else
      ""
    end

    projects_html = if length(projects) > 0 do
      project_items = Enum.map(projects, fn project ->
        name = get_content_value(project, ["name", "title"], "")
        description = get_content_value(project, ["description", "summary"], "")
        technologies = get_content_value(project, ["technologies", "tech_stack", "tools"], [])
        url = get_content_value(project, ["url", "link", "demo_url"], "")
        github = get_content_value(project, ["github", "repository"], "")
        status = get_content_value(project, ["status"], "")

        tech_badges = if length(technologies) > 0 do
          tech_items = Enum.map(technologies, fn tech ->
            "<span class='inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full mr-2 mb-2'>#{tech}</span>"
          end)
          "<div class='mt-3'>#{Enum.join(tech_items, "")}</div>"
        else
          ""
        end

        links_html = []
        if url != "" do
          links_html = ["<a href='#{url}' target='_blank' class='inline-flex items-center text-blue-600 hover:text-blue-800 text-sm font-medium mr-4'><svg class='w-4 h-4 mr-1' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14'></path></svg>Live Demo</a>" | links_html]
        end
        if github != "" do
          links_html = ["<a href='#{github}' target='_blank' class='inline-flex items-center text-gray-600 hover:text-gray-800 text-sm font-medium'><svg class='w-4 h-4 mr-1' fill='currentColor' viewBox='0 0 20 20'><path fill-rule='evenodd' d='M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z' clip-rule='evenodd'></path></svg>GitHub</a>" | links_html]
        end

        status_badge = if status != "" do
          status_color = case String.downcase(status) do
            "completed" -> "bg-green-100 text-green-800"
            "in progress" -> "bg-yellow-100 text-yellow-800"
            "planning" -> "bg-blue-100 text-blue-800"
            _ -> "bg-gray-100 text-gray-800"
          end
          "<span class='inline-block #{status_color} text-xs px-2 py-1 rounded-full'>#{status}</span>"
        else
          ""
        end

        """
        <div class="project-item border-l-4 border-purple-500 pl-6 pb-6 mb-6 last:mb-0">
          <div class="flex items-start justify-between mb-2">
            <div class="flex-1">
              #{if name != "", do: "<h4 class='text-lg font-semibold text-gray-900'>#{name}</h4>", else: ""}
              #{if description != "", do: "<p class='text-gray-700 mt-2 leading-relaxed'>#{strip_html_safely(description)}</p>", else: ""}
            </div>
            #{status_badge}
          </div>
          #{tech_badges}
          #{if length(links_html) > 0, do: "<div class='mt-4'>#{Enum.join(Enum.reverse(links_html), "")}</div>", else: ""}
        </div>
        """
      end)

      Enum.join(project_items, "")
    else
      ""
    end

    """
    <div class="projects-content">
      #{summary_html}
      #{projects_html}
    </div>
    """
  end

  defp render_custom_content_enhanced(content, section_title) do
    text = get_content_value(content, ["text", "content", "description"], "")

    if text != "" do
      """
      <div class="custom-content">
        <div class="text-gray-700 leading-relaxed">#{strip_html_safely(text)}</div>
      </div>
      """
    else
      ""
    end
  end

  defp render_generic_content_enhanced(content, section_title) do
    # Try to find any meaningful text content
    text_content = content
    |> Map.values()
    |> Enum.find(fn value ->
      is_binary(value) && String.trim(value) != ""
    end)

    if text_content do
      """
      <div class="generic-content">
        <div class="text-gray-700 leading-relaxed">#{strip_html_safely(text_content)}</div>
      </div>
      """
    else
      ""
    end
  end

  # Social media icon helper
  defp get_social_icon(platform) do
    case String.downcase(to_string(platform)) do
      "linkedin" -> "<svg class='w-4 h-4' fill='currentColor' viewBox='0 0 20 20'><path fill-rule='evenodd' d='M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z' clip-rule='evenodd'></path></svg>"
      "github" -> "<svg class='w-4 h-4' fill='currentColor' viewBox='0 0 20 20'><path fill-rule='evenodd' d='M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z' clip-rule='evenodd'></path></svg>"
      "twitter" -> "<svg class='w-4 h-4' fill='currentColor' viewBox='0 0 20 20'><path d='M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84'></path></svg>"
      "instagram" -> "<svg class='w-4 h-4' fill='currentColor' viewBox='0 0 20 20'><path fill-rule='evenodd' d='M10 0C7.284 0 6.944.012 5.877.06 2.246.227.227 2.242.06 5.877.012 6.944 0 7.284 0 10s.012 3.056.06 4.123c.167 3.632 2.182 5.65 5.817 5.817C6.944 19.988 7.284 20 10 20s3.056-.012 4.123-.06c3.629-.167 5.652-2.182 5.817-5.817C19.988 13.056 20 12.716 20 10s-.012-3.056-.06-4.123C19.833 2.245 17.815.227 14.183.06 13.056.012 12.716 0 10 0zm0 1.802c2.67 0 2.987.01 4.042.059 2.71.123 3.975 1.409 4.099 4.099.048 1.054.057 1.37.057 4.04 0 2.672-.01 2.988-.057 4.042-.124 2.687-1.387 3.975-4.1 4.099-1.054.048-1.37.058-4.041.058-2.67 0-2.987-.01-4.04-.058-2.717-.124-3.977-1.416-4.1-4.1-.048-1.054-.058-1.37-.058-4.041 0-2.67.01-2.986.058-4.04.124-2.69 1.387-3.977 4.1-4.1 1.054-.048 1.37-.058 4.04-.058zM10 4.865a5.135 5.135 0 100 10.27 5.135 5.135 0 000-10.27zm0 8.468a3.333 3.333 0 110-6.666 3.333 3.333 0 010 6.666zm5.338-9.87a1.2 1.2 0 100 2.4 1.2 1.2 0 000-2.4z' clip-rule='evenodd'></path></svg>"
      _ -> "<svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1'></path></svg>"
    end
  end
end
