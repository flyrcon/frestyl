# File: lib/frestyl_web/live/portfolio_live/components/enhanced_section_cards.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedSectionCards do
  @moduledoc """
  PATCH 4: Enhanced section cards with fixed heights, scrollable content, and modal expansion.
  Provides consistent card sizing with overflow handling and detailed modal views.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.EnhancedContentRenderer

  # ============================================================================
  # MAIN SECTION CARD RENDERER
  # ============================================================================

  def render_section_card(section, config, card_type \\ "standard") do
    card_config = get_card_config(card_type, config)

    """
    <div id="section-#{section.id}"
         class="section-card #{card_config.container_class} cursor-pointer group"
         data-section-id="#{section.id}"
         onclick="openSectionModal('#{section.id}')">

      <!-- Card Header -->
      <div class="card-header #{card_config.header_class}">
        #{render_card_header(section, card_config)}
      </div>

      <!-- Card Content -->
      <div class="card-content #{card_config.content_class}">
        <div class="content-scroll #{card_config.scroll_class}">
          #{render_card_content_preview(section, config.color_scheme)}
        </div>
      </div>

      <!-- Card Footer -->
      <div class="card-footer #{card_config.footer_class}">
        #{render_card_footer(section, card_config)}
      </div>

    </div>

    <!-- Section Modal -->
    <div id="modal-#{section.id}"
         class="section-modal fixed inset-0 bg-black bg-opacity-50 hidden z-50 flex items-center justify-center p-4"
         onclick="closeSectionModal('#{section.id}', event)">

      <div class="modal-content bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden"
           onclick="event.stopPropagation()">

        <!-- Modal Header -->
        <div class="modal-header #{card_config.modal_header_class}">
          #{render_modal_header(section, card_config)}
        </div>

        <!-- Modal Body -->
        <div class="modal-body #{card_config.modal_body_class}">
          #{render_modal_content(section, config.color_scheme)}
        </div>

        <!-- Modal Footer -->
        <div class="modal-footer #{card_config.modal_footer_class}">
          #{render_modal_footer(section, card_config)}
        </div>

      </div>
    </div>
    """
  end

  # ============================================================================
  # CARD HEADER RENDERING
  # ============================================================================

  defp render_card_header(section, card_config) do
    """
    <div class="flex items-center justify-between">

      <!-- Section Info -->
      <div class="flex items-center space-x-3 flex-1 min-w-0">

        <!-- Section Icon -->
        <div class="section-icon #{card_config.icon_class}">
          #{get_section_icon_svg(section.section_type)}
        </div>

        <!-- Section Title & Type -->
        <div class="flex-1 min-w-0">
          <h3 class="section-title #{card_config.title_class} truncate">
            #{section.title}
          </h3>
          <p class="section-type #{card_config.type_class}">
            #{get_section_type_label(section.section_type)}
          </p>
        </div>

      </div>

      <!-- Expand Button -->
      <button class="expand-btn #{card_config.expand_btn_class} group-hover:opacity-100 transition-opacity"
              onclick="event.stopPropagation(); openSectionModal('#{section.id}')">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
                d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
        </svg>
      </button>

    </div>
    """
  end

  # ============================================================================
  # CARD CONTENT PREVIEW RENDERING
  # ============================================================================

  defp render_card_content_preview(section, color_scheme) do
    case normalize_section_type(section.section_type) do
      :experience -> render_experience_preview(section, color_scheme)
      :education -> render_education_preview(section, color_scheme)
      :skills -> render_skills_preview(section, color_scheme)
      :projects -> render_projects_preview(section, color_scheme)
      :about -> render_about_preview(section, color_scheme)
      :contact -> render_contact_preview(section, color_scheme)
      :testimonials -> render_testimonials_preview(section, color_scheme)
      _ -> render_generic_preview(section, color_scheme)
    end
  end

  defp render_experience_preview(section, color_scheme) do
    content = section.content || %{}
    jobs = Map.get(content, "jobs", [])

    if length(jobs) > 0 do
      # Show first 2 jobs in preview
      preview_jobs = Enum.take(jobs, 2)

      job_items = Enum.map(preview_jobs, fn job ->
        role = Map.get(job, "role", Map.get(job, "title", ""))
        company = Map.get(job, "company", "")
        dates = get_job_dates(job)

        """
        <div class="job-preview mb-3 last:mb-0">
          <div class="flex justify-between items-start mb-1">
            <h4 class="font-medium text-gray-900 text-sm">#{role}</h4>
            <span class="text-xs text-gray-500">#{dates}</span>
          </div>
          #{if company != "", do: "<p class='text-blue-600 text-sm font-medium'>#{company}</p>", else: ""}
        </div>
        """
      end)

      jobs_html = Enum.join(job_items, "")
      remaining = length(jobs) - 2

      """
      #{jobs_html}
      #{if remaining > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining} more positions</p>", else: ""}
      """
    else
      "<p class='text-gray-500 text-sm'>No work experience added yet</p>"
    end
  end

  defp render_education_preview(section, color_scheme) do
    content = section.content || %{}
    education = Map.get(content, "education", [])

    if length(education) > 0 do
      first_edu = List.first(education)
      institution = Map.get(first_edu, "institution", "")
      degree = Map.get(first_edu, "degree", "")
      field = Map.get(first_edu, "field", "")
      graduation_date = Map.get(first_edu, "graduation_date", "")

      remaining = length(education) - 1

      """
      <div class="education-preview">
        <h4 class="font-medium text-gray-900 text-sm mb-1">#{institution}</h4>
        #{if degree != "" || field != "", do: "<p class='text-green-600 text-sm'>#{degree}#{if degree != "" && field != "", do: " in ", else: ""}#{field}</p>", else: ""}
        #{if graduation_date != "", do: "<p class='text-xs text-gray-500 mt-1'>#{graduation_date}</p>", else: ""}
        #{if remaining > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining} more schools</p>", else: ""}
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No education added yet</p>"
    end
  end

  defp render_skills_preview(section, color_scheme) do
    content = section.content || %{}
    skills = Map.get(content, "skills", [])
    skill_categories = Map.get(content, "skill_categories", %{})

    colors = get_color_scheme_colors(color_scheme)

    cond do
      map_size(skill_categories) > 0 ->
        # Show skill categories
        category_items = skill_categories
        |> Enum.take(3)
        |> Enum.with_index()
        |> Enum.map(fn {{category, category_skills}, index} ->
          color = Enum.at(colors, rem(index, length(colors)))
          skill_count = length(category_skills)

          """
          <div class="skill-category-preview flex items-center justify-between mb-2">
            <div class="flex items-center space-x-2">
              <div class="w-3 h-3 rounded-full" style="background-color: #{color}"></div>
              <span class="text-sm font-medium text-gray-900">#{category}</span>
            </div>
            <span class="text-xs text-gray-500">#{skill_count}</span>
          </div>
          """
        end)

        remaining_categories = map_size(skill_categories) - 3

        """
        #{Enum.join(category_items, "")}
        #{if remaining_categories > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining_categories} more categories</p>", else: ""}
        """

      length(skills) > 0 ->
        # Show individual skills
        skill_badges = skills
        |> Enum.take(6)
        |> Enum.with_index()
        |> Enum.map(fn {skill, index} ->
          skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
          color = Enum.at(colors, rem(index, length(colors)))

          """
          <span class="skill-badge inline-block px-2 py-1 text-xs rounded-full mr-1 mb-1"
                style="background-color: #{color}20; color: #{color}; border: 1px solid #{color}40;">
            #{skill_name}
          </span>
          """
        end)

        remaining_skills = length(skills) - 6

        """
        <div class="skills-preview">
          #{Enum.join(skill_badges, "")}
          #{if remaining_skills > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining_skills} more skills</p>", else: ""}
        </div>
        """

      true ->
        "<p class='text-gray-500 text-sm'>No skills added yet</p>"
    end
  end

  defp render_projects_preview(section, color_scheme) do
    content = section.content || %{}
    projects = Map.get(content, "projects", [])

    if length(projects) > 0 do
      first_project = List.first(projects)
      name = Map.get(first_project, "name", Map.get(first_project, "title", ""))
      description = Map.get(first_project, "description", "")
      technologies = Map.get(first_project, "technologies", [])

      remaining = length(projects) - 1

      """
      <div class="project-preview">
        #{if name != "", do: "<h4 class='font-medium text-gray-900 text-sm mb-1'>#{name}</h4>", else: ""}
        #{if description != "", do: "<p class='text-gray-600 text-sm mb-2 line-clamp-2'>#{String.slice(description, 0, 80)}#{if String.length(description) > 80, do: "...", else: ""}</p>", else: ""}
        #{if length(technologies) > 0 do
          tech_badges = Enum.take(technologies, 3)
          |> Enum.map(fn tech -> "<span class='text-xs bg-purple-100 text-purple-700 px-2 py-1 rounded'>#{tech}</span>" end)
          |> Enum.join("")

          remaining_tech = if length(technologies) > 3, do: "<span class='text-xs text-gray-400'>+#{length(technologies) - 3}</span>", else: ""

          "<div class='flex flex-wrap gap-1 mb-2'>#{tech_badges}#{remaining_tech}</div>"
        else
          ""
        end}
        #{if remaining > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining} more projects</p>", else: ""}
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No projects added yet</p>"
    end
  end

  defp render_about_preview(section, color_scheme) do
    content = section.content || %{}
    bio = Map.get(content, "bio", Map.get(content, "summary", ""))

    if bio != "" do
      preview_text = bio
      |> String.replace(~r/<[^>]*>/, "")
      |> String.slice(0, 120)
      |> String.trim()

      preview_text = if String.length(bio) > 120, do: "#{preview_text}...", else: preview_text

      """
      <div class="about-preview">
        <p class="text-gray-600 text-sm leading-relaxed">#{preview_text}</p>
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No about information added yet</p>"
    end
  end

  defp render_contact_preview(section, color_scheme) do
    content = section.content || %{}
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    location = Map.get(content, "location", "")
    social_links = Map.get(content, "social_links", %{})

    contact_items = []

    if email != "" do
      contact_items = ["<div class='flex items-center space-x-2 mb-1'><svg class='w-3 h-3 text-gray-400' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z'></path></svg><span class='text-sm text-gray-600'>#{email}</span></div>" | contact_items]
    end

    if phone != "" do
      contact_items = ["<div class='flex items-center space-x-2 mb-1'><svg class='w-3 h-3 text-gray-400' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z'></path></svg><span class='text-sm text-gray-600'>#{phone}</span></div>" | contact_items]
    end

    if location != "" do
      contact_items = ["<div class='flex items-center space-x-2 mb-1'><svg class='w-3 h-3 text-gray-400' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z'></path></svg><span class='text-sm text-gray-600'>#{location}</span></div>" | contact_items]
    end

    social_count = map_size(social_links)

    if length(contact_items) > 0 || social_count > 0 do
      """
      <div class="contact-preview">
        #{Enum.join(Enum.reverse(contact_items), "")}
        #{if social_count > 0, do: "<p class='text-xs text-gray-400 mt-2'>#{social_count} social platforms</p>", else: ""}
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No contact information added yet</p>"
    end
  end

  defp render_testimonials_preview(section, color_scheme) do
    content = section.content || %{}
    testimonials = Map.get(content, "testimonials", [])

    if length(testimonials) > 0 do
      first_testimonial = List.first(testimonials)
      quote = Map.get(first_testimonial, "quote", Map.get(first_testimonial, "text", ""))
      author = Map.get(first_testimonial, "author", "")

      remaining = length(testimonials) - 1

      preview_quote = if quote != "" do
        quote
        |> String.slice(0, 80)
        |> String.trim()
        |> then(fn text -> if String.length(quote) > 80, do: "#{text}...", else: text end)
      else
        ""
      end

      """
      <div class="testimonial-preview">
        #{if preview_quote != "", do: "<p class='text-gray-600 text-sm italic mb-2'>\"#{preview_quote}\"</p>", else: ""}
        #{if author != "", do: "<p class='text-sm font-medium text-gray-900'>— #{author}</p>", else: ""}
        #{if remaining > 0, do: "<p class='text-xs text-gray-400 mt-2'>+#{remaining} more testimonials</p>", else: ""}
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No testimonials added yet</p>"
    end
  end

  defp render_generic_preview(section, color_scheme) do
    content = section.content || %{}

    # Try to find any meaningful text content
    preview_text = content
    |> Map.values()
    |> Enum.find(fn value ->
      is_binary(value) && String.trim(value) != ""
    end)

    if preview_text do
      clean_text = preview_text
      |> String.replace(~r/<[^>]*>/, "")
      |> String.slice(0, 100)
      |> String.trim()

      clean_text = if String.length(preview_text) > 100, do: "#{clean_text}...", else: clean_text

      """
      <div class="generic-preview">
        <p class="text-gray-600 text-sm leading-relaxed">#{clean_text}</p>
      </div>
      """
    else
      "<p class='text-gray-500 text-sm'>No content available</p>"
    end
  end

  # ============================================================================
  # CARD FOOTER RENDERING
  # ============================================================================

  defp render_card_footer(section, card_config) do
    content_indicator = get_content_length_indicator(section)
    last_updated = get_section_last_updated(section)

    """
    <div class="flex items-center justify-between text-xs">

      <!-- Content Indicator -->
      <span class="#{card_config.footer_text_class}">
        #{content_indicator}
      </span>

      <!-- Last Updated -->
      <span class="#{card_config.footer_meta_class}">
        #{last_updated}
      </span>

    </div>
    """
  end

  # ============================================================================
  # MODAL RENDERING
  # ============================================================================

  defp render_modal_header(section, card_config) do
    """
    <div class="flex items-center justify-between">

      <!-- Modal Title -->
      <div class="flex items-center space-x-4">
        <div class="modal-icon #{card_config.modal_icon_class}">
          #{get_section_icon_svg(section.section_type)}
        </div>
        <div>
          <h2 class="#{card_config.modal_title_class}">
            #{section.title}
          </h2>
          <p class="#{card_config.modal_subtitle_class}">
            #{get_section_type_label(section.section_type)}
          </p>
        </div>
      </div>

      <!-- Close Button -->
      <button class="modal-close #{card_config.modal_close_class}"
              onclick="closeSectionModal('#{section.id}')">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>

    </div>
    """
  end

  defp render_modal_content(section, color_scheme) do
    # Use the full enhanced content renderer for modal
    full_content = EnhancedContentRenderer.render_enhanced_section_content(section, color_scheme)

    """
    <div class="modal-content-full">
      #{full_content}
    </div>
    """
  end

  defp render_modal_footer(section, card_config) do
    """
    <div class="flex items-center justify-between">

      <!-- Section Stats -->
      <div class="flex items-center space-x-6 text-sm">
        <span class="#{card_config.modal_footer_text}">
          <strong>Content:</strong> #{get_content_length_indicator(section)}
        </span>
        <span class="#{card_config.modal_footer_text}">
          <strong>Type:</strong> #{get_section_type_label(section.section_type)}
        </span>
        <span class="#{card_config.modal_footer_text}">
          <strong>Updated:</strong> #{get_section_last_updated(section)}
        </span>
      </div>

      <!-- Action Buttons -->
      <div class="flex items-center space-x-3">
        <button class="#{card_config.modal_secondary_btn}"
                onclick="shareSectionContent('#{section.id}')">
          Share
        </button>
        <button class="#{card_config.modal_primary_btn}"
                onclick="closeSectionModal('#{section.id}')">
          Close
        </button>
      </div>

    </div>
    """
  end

  # ============================================================================
  # CARD CONFIGURATION
  # ============================================================================

  defp get_card_config(card_type, base_config) do
    base = %{
      # Container classes
      container_class: "bg-white rounded-xl border border-gray-200 shadow-md hover:shadow-lg transition-all duration-300 overflow-hidden",

      # Header classes
      header_class: "p-4 border-b border-gray-100",
      icon_class: "w-8 h-8 bg-blue-50 rounded-lg flex items-center justify-center flex-shrink-0",
      title_class: "font-semibold text-gray-900 text-sm",
      type_class: "text-xs text-gray-500",
      expand_btn_class: "opacity-0 p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-50 rounded-lg transition-all",

      # Content classes
      content_class: "p-4 h-32 overflow-hidden",
      scroll_class: "h-full overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300 scrollbar-track-gray-100",

      # Footer classes
      footer_class: "p-4 pt-0",
      footer_text_class: "text-gray-600",
      footer_meta_class: "text-gray-400",

      # Modal classes
      modal_header_class: "p-6 border-b border-gray-200",
      modal_body_class: "p-6 max-h-[60vh] overflow-y-auto scrollbar-thin scrollbar-thumb-gray-300",
      modal_footer_class: "p-6 border-t border-gray-200 bg-gray-50",
      modal_icon_class: "w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center",
      modal_title_class: "text-xl font-bold text-gray-900",
      modal_subtitle_class: "text-sm text-gray-500",
      modal_close_class: "p-2 text-gray-400 hover:text-gray-600 hover:bg-gray-100 rounded-lg transition-colors",
      modal_footer_text: "text-gray-600",
      modal_primary_btn: "px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors",
      modal_secondary_btn: "px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
    }

    case card_type do
      "dashboard" -> Map.merge(base, %{
        container_class: "#{base.container_class} dashboard-card",
        content_class: "p-4 h-28 overflow-hidden",
        icon_class: "w-6 h-6 #{base_config.icon_bg || "bg-blue-50"} rounded-lg flex items-center justify-center flex-shrink-0"
      })

      "masonry" -> Map.merge(base, %{
        container_class: "#{base.container_class} masonry-card",
        content_class: "p-4 flex-1 overflow-hidden",
        header_class: "p-4"
      })

      "timeline" -> Map.merge(base, %{
        container_class: "#{base.container_class} timeline-card ml-20",
        content_class: "p-6 h-24 overflow-hidden"
      })

      "magazine" -> Map.merge(base, %{
        container_class: "#{base.container_class} magazine-card",
        content_class: "p-6 h-16 overflow-hidden"
      })

      "minimal" -> Map.merge(base, %{
        container_class: "bg-transparent border-none shadow-none hover:shadow-none minimal-card",
        header_class: "text-center mb-4",
        content_class: "text-center h-32 overflow-hidden",
        footer_class: "text-center pt-0"
      })

      _ -> base
    end
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp normalize_section_type(section_type) do
    case section_type do
      "experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "about" -> :about
      "intro" -> :about
      "contact" -> :contact
      "testimonials" -> :testimonials
      atom when is_atom(atom) -> atom
      _ -> :other
    end
  end

  defp get_section_icon_svg(section_type) do
    case normalize_section_type(section_type) do
      :experience ->
        """
        <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 00-2 2H6a2 2 0 00-2-2V4m16 4.016A25.717 25.717 0 0112 8c-4.998 0-9.553.895-13.207 2.016A3.014 3.014 0 003 13.011v2.978c0 1.656 1.334 2.989 2.98 2.989h.09c1.646 0 2.98-1.333 2.98-2.989V13.01c0-.657.18-1.297.52-1.849z"/>
        </svg>
        """

      :education ->
        """
        <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
        </svg>
        """

      :skills ->
        """
        <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
        </svg>
        """

      :projects ->
        """
        <svg class="w-4 h-4 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.387-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z"/>
        </svg>
        """

      :about ->
        """
        <svg class="w-4 h-4 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """

      :contact ->
        """
        <svg class="w-4 h-4 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """

      :testimonials ->
        """
        <svg class="w-4 h-4 text-pink-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        """

      _ ->
        """
        <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """
    end
  end

  defp get_section_type_label(section_type) do
    case normalize_section_type(section_type) do
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :projects -> "Projects"
      :about -> "About Me"
      :contact -> "Contact Information"
      :testimonials -> "Testimonials"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_color_scheme_colors(scheme) do
    case scheme do
      "blue" -> ["#1e40af", "#3b82f6", "#60a5fa"]
      "green" -> ["#065f46", "#059669", "#34d399"]
      "purple" -> ["#581c87", "#7c3aed", "#a78bfa"]
      "red" -> ["#991b1b", "#dc2626", "#f87171"]
      "orange" -> ["#ea580c", "#f97316", "#fb923c"]
      "teal" -> ["#0f766e", "#14b8a6", "#5eead4"]
      _ -> ["#3b82f6", "#60a5fa", "#93c5fd"]
    end
  end

  defp get_job_dates(job) do
    start_date = Map.get(job, "start_date", "")
    end_date = Map.get(job, "end_date", "Present")

    case {start_date, end_date} do
      {"", ""} -> "Present"
      {start, ""} -> start
      {"", finish} -> finish
      {start, finish} -> "#{start} - #{finish}"
    end
  end

  defp get_content_length_indicator(section) do
    content = section.content || %{}

    length = content
    |> Map.values()
    |> Enum.map(fn value ->
      case value do
        str when is_binary(str) -> String.length(str)
        list when is_list(list) -> length(list) * 50
        map when is_map(map) -> map_size(map) * 30
        _ -> 0
      end
    end)
    |> Enum.sum()

    cond do
      length > 500 -> "Detailed"
      length > 200 -> "Medium"
      length > 50 -> "Brief"
      true -> "Short"
    end
  end

  defp get_section_last_updated(section) do
    # For now, return a default since we don't have updated_at tracking
    # In a real app, you'd use section.updated_at
    "Recently"
  end
end
