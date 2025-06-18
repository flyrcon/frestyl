# lib/frestyl_web/live/portfolio_live/components/portfolio_section.ex - ENHANCED VERSION

defmodule FrestylWeb.PortfolioLive.Components.PortfolioSection do
  use Phoenix.Component
  import FrestylWeb.CoreComponents

  # 🔥 MAIN: Enhanced section rendering with proper content handling
  def render_section(assigns) do
    # Ensure we have proper content structure
    assigns = assign(assigns,
      content: assigns.section.content || %{},
      section_type: assigns.section.section_type,
      section_id: assigns.section.id,
      section_title: assigns.section.title
    )

    ~H"""
    <div class="portfolio-section mb-8 bg-white rounded-xl shadow-lg border border-gray-200 overflow-hidden hover:shadow-xl transition-all duration-300">
      <!-- Section Header with Icon -->
      <div class="border-b border-gray-100 px-6 py-5 bg-gradient-to-r from-gray-50 to-white">
        <div class="flex items-center space-x-4">
          <div class={[
            "w-12 h-12 rounded-xl flex items-center justify-center shadow-md",
            get_section_icon_bg(@section_type)
          ]}>
            <%= render_section_icon(@section_type) %>
          </div>
          <div class="flex-1">
            <h2 class="text-2xl font-bold text-gray-900"><%= @section_title %></h2>
            <p class="text-sm text-gray-600 font-medium">
              <%= format_section_type(@section_type) %>
            </p>
          </div>
          <div class="flex items-center space-x-2 text-gray-400">
            <%= if has_content?(@content) do %>
              <div class="w-2 h-2 bg-green-400 rounded-full"></div>
              <span class="text-xs font-medium text-green-600">Active</span>
            <% else %>
              <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
              <span class="text-xs font-medium text-gray-500">Empty</span>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Section Content -->
      <div class="p-6">
        <%= case @section_type do %>
          <% type when type in [:intro, "intro"] -> %>
            <%= render_intro_section(assigns) %>
          <% type when type in [:experience, "experience"] -> %>
            <%= render_experience_section(assigns) %>
          <% type when type in [:education, "education"] -> %>
            <%= render_education_section(assigns) %>
          <% type when type in [:skills, "skills"] -> %>
            <%= render_skills_section(assigns) %>
          <% type when type in [:projects, "projects"] -> %>
            <%= render_projects_section(assigns) %>
          <% type when type in [:featured_project, "featured_project"] -> %>
            <%= render_featured_project_section(assigns) %>
          <% type when type in [:contact, "contact"] -> %>
            <%= render_contact_section(assigns) %>
          <% type when type in [:achievements, "achievements"] -> %>
            <%= render_achievements_section(assigns) %>
          <% type when type in [:case_study, "case_study"] -> %>
            <%= render_case_study_section(assigns) %>
          <% type when type in [:testimonial, "testimonial"] -> %>
            <%= render_testimonial_section(assigns) %>
          <% type when type in [:media_showcase, "media_showcase"] -> %>
            <%= render_media_showcase_section(assigns) %>
          <% _ -> %>
            <%= render_generic_section(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  # 🔥 ENHANCED: Introduction section with better content extraction
  defp render_intro_section(assigns) do
    headline = get_content_value(assigns.content, ["headline", "title"], "")
    summary = get_content_value(assigns.content, ["summary", "description", "bio"], "")
    location = get_content_value(assigns.content, ["location"], "")
    website = get_content_value(assigns.content, ["website", "portfolio_url"], "")
    social_links = get_content_value(assigns.content, ["social_links"], %{})
    availability = get_content_value(assigns.content, ["availability", "status"], "")

    assigns = assign(assigns,
      headline: headline,
      summary: summary,
      location: location,
      website: website,
      social_links: social_links,
      availability: availability
    )

    ~H"""
    <div class="space-y-6">
      <%= if @headline != "" do %>
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl p-6 border border-blue-200">
          <h3 class="text-3xl font-bold text-gray-900 mb-2"><%= @headline %></h3>
          <%= if @availability != "" do %>
            <div class="inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-sm font-medium rounded-full">
              <div class="w-2 h-2 bg-green-500 rounded-full mr-2"></div>
              <%= @availability %>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if @summary != "" do %>
        <div class="prose max-w-none">
          <p class="text-lg text-gray-700 leading-relaxed"><%= @summary %></p>
        </div>
      <% end %>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= if @location != "" do %>
          <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
            <div class="w-10 h-10 bg-gray-200 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
            </div>
            <div>
              <p class="font-semibold text-gray-900">Location</p>
              <p class="text-gray-600"><%= @location %></p>
            </div>
          </div>
        <% end %>

        <%= if @website != "" do %>
          <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-lg">
            <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9v-9m0-9v9"/>
              </svg>
            </div>
            <div>
              <p class="font-semibold text-gray-900">Website</p>
              <a href={@website} target="_blank" class="text-blue-600 hover:text-blue-700 font-medium">
                <%= format_url_display(@website) %>
              </a>
            </div>
          </div>
        <% end %>
      </div>

      <%= if map_size(@social_links) > 0 do %>
        <div class="border-t border-gray-200 pt-6">
          <h4 class="text-lg font-semibold text-gray-900 mb-4">Connect</h4>
          <div class="flex flex-wrap gap-3">
            <%= for {platform, url} <- @social_links, url != "" do %>
              <a href={url} target="_blank"
                 class="inline-flex items-center px-4 py-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors font-medium text-gray-700">
                <%= get_social_icon(platform) %>
                <span class="ml-2"><%= String.capitalize(platform) %></span>
              </a>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # 🔥 ENHANCED: Experience section with comprehensive job data handling
  defp render_experience_section(assigns) do
    jobs = get_content_value(assigns.content, ["jobs", "experience", "work_history"], [])
    summary_stats = get_content_value(assigns.content, ["summary_stats"], %{})

    assigns = assign(assigns, jobs: ensure_list(jobs), summary_stats: summary_stats)

    ~H"""
    <div class="space-y-8">
      <%= if map_size(@summary_stats) > 0 do %>
        <div class="grid grid-cols-3 gap-4 mb-8">
          <%= if @summary_stats["total_years"] do %>
            <div class="text-center p-4 bg-blue-50 rounded-xl">
              <div class="text-2xl font-bold text-blue-600"><%= @summary_stats["total_years"] %>+</div>
              <div class="text-sm text-blue-800">Years Experience</div>
            </div>
          <% end %>
          <%= if @summary_stats["companies_count"] do %>
            <div class="text-center p-4 bg-green-50 rounded-xl">
              <div class="text-2xl font-bold text-green-600"><%= @summary_stats["companies_count"] %></div>
              <div class="text-sm text-green-800">Companies</div>
            </div>
          <% end %>
          <%= if @summary_stats["current_role"] do %>
            <div class="text-center p-4 bg-purple-50 rounded-xl">
              <div class="text-sm font-bold text-purple-600">Current</div>
              <div class="text-xs text-purple-800"><%= @summary_stats["current_role"] %></div>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if length(@jobs) > 0 do %>
        <div class="space-y-8">
          <%= for {job, index} <- Enum.with_index(@jobs) do %>
            <div class={[
              "relative pl-8 pb-8",
              if(index < length(@jobs) - 1, do: "border-l-2 border-gray-200", else: "")
            ]}>
              <!-- Timeline dot -->
              <div class="absolute left-0 top-0 transform -translate-x-1/2">
                <div class={[
                  "w-4 h-4 rounded-full border-2 border-white shadow-md",
                  if(get_job_value(job, ["current"], false), do: "bg-green-500", else: "bg-blue-500")
                ]}></div>
              </div>

              <!-- Job Content -->
              <div class="bg-white border border-gray-200 rounded-xl p-6 shadow-sm hover:shadow-md transition-shadow ml-4">
                <div class="flex items-start justify-between mb-4">
                  <div class="flex-1">
                    <h3 class="text-xl font-bold text-gray-900">
                      <%= get_job_value(job, ["title", "position", "job_title"], "Position") %>
                    </h3>
                    <p class="text-lg font-semibold text-blue-600">
                      <%= get_job_value(job, ["company", "employer", "organization"], "Company") %>
                    </p>
                    <p class="text-sm text-gray-600">
                      <%= get_job_value(job, ["location"], "") %>
                      <%= if get_job_value(job, ["employment_type"], "") != "" do %>
                        • <%= get_job_value(job, ["employment_type"]) %>
                      <% end %>
                    </p>
                  </div>
                  <div class="text-right">
                    <div class="text-sm font-medium text-gray-700">
                      <%= format_job_dates(job) %>
                    </div>
                    <%= if get_job_value(job, ["current"], false) do %>
                      <span class="inline-flex items-center px-2 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full mt-1">
                        Current Position
                      </span>
                    <% end %>
                  </div>
                </div>

                <%= if get_job_value(job, ["description"], "") != "" do %>
                  <div class="mb-4">
                    <p class="text-gray-700 leading-relaxed">
                      <%= get_job_value(job, ["description"]) %>
                    </p>
                  </div>
                <% end %>

                <%= if length(get_job_value(job, ["responsibilities"], [])) > 0 do %>
                  <div class="mb-4">
                    <h4 class="font-semibold text-gray-900 mb-2">Key Responsibilities</h4>
                    <ul class="list-disc list-inside space-y-1 text-gray-700">
                      <%= for responsibility <- get_job_value(job, ["responsibilities"]) do %>
                        <li><%= responsibility %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if length(get_job_value(job, ["achievements"], [])) > 0 do %>
                  <div class="mb-4">
                    <h4 class="font-semibold text-gray-900 mb-2">Key Achievements</h4>
                    <ul class="list-disc list-inside space-y-1 text-gray-700">
                      <%= for achievement <- get_job_value(job, ["achievements"]) do %>
                        <li class="text-green-700 font-medium"><%= achievement %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <%= if length(get_job_value(job, ["skills"], [])) > 0 do %>
                  <div class="flex flex-wrap gap-2">
                    <%= for skill <- get_job_value(job, ["skills"]) do %>
                      <span class="inline-flex items-center px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
                        <%= skill %>
                      </span>
                    <% end %>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <%= render_empty_state("briefcase", "No work experience added yet", "Your professional experience will appear here") %>
      <% end %>
    </div>
    """
  end

  # 🔥 ENHANCED: Skills section with categorized and flat display
  defp render_skills_section(assigns) do
    skills = get_content_value(assigns.content, ["skills"], [])
    skill_categories = get_content_value(assigns.content, ["skill_categories"], %{})
    display_mode = get_content_value(assigns.content, ["skill_display_mode"], "flat")
    show_proficiency = get_content_value(assigns.content, ["show_proficiency"], true)

    assigns = assign(assigns,
      skills: ensure_list(skills),
      skill_categories: skill_categories,
      display_mode: display_mode,
      show_proficiency: show_proficiency
    )

    ~H"""
    <div class="space-y-6">
      <%= if @display_mode == "categorized" and map_size(@skill_categories) > 0 do %>
        <!-- Categorized Skills Display -->
        <div class="space-y-8">
          <%= for {category, category_skills} <- @skill_categories do %>
            <div>
              <h3 class="text-lg font-bold text-gray-900 mb-4 flex items-center">
                <div class={["w-3 h-3 rounded-full mr-3", get_category_color(category)]}></div>
                <%= category %>
                <span class="ml-2 text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded-full">
                  <%= length(ensure_list(category_skills)) %>
                </span>
              </h3>
              <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
                <%= for skill <- ensure_list(category_skills) do %>
                  <%= render_skill_badge(skill, @show_proficiency) %>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Flat Skills Display -->
        <%= if length(@skills) > 0 do %>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
            <%= for skill <- @skills do %>
              <%= render_skill_badge(skill, @show_proficiency) %>
            <% end %>
          </div>
        <% else %>
          <%= render_empty_state("lightning-bolt", "No skills added yet", "Your technical skills and expertise will appear here") %>
        <% end %>
      <% end %>
    </div>
    """
  end

  # 🔥 ENHANCED: Education section with detailed information
  defp render_education_section(assigns) do
    education = get_content_value(assigns.content, ["education"], [])
    certifications = get_content_value(assigns.content, ["certifications"], [])

    assigns = assign(assigns,
      education: ensure_list(education),
      certifications: ensure_list(certifications)
    )

    ~H"""
    <div class="space-y-8">
      <%= if length(@education) > 0 do %>
        <div>
          <h3 class="text-xl font-bold text-gray-900 mb-6 flex items-center">
            <svg class="w-6 h-6 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
            </svg>
            Education
          </h3>
          <div class="space-y-6">
            <%= for edu <- @education do %>
              <div class="border-l-4 border-green-500 bg-gradient-to-r from-green-50 to-white p-6 rounded-r-xl">
                <div class="flex items-start justify-between mb-3">
                  <div class="flex-1">
                    <h4 class="text-lg font-bold text-gray-900">
                      <%= get_edu_value(edu, ["degree"], "") %>
                      <%= if get_edu_value(edu, ["field"], "") != "" do %>
                        in <%= get_edu_value(edu, ["field"]) %>
                      <% end %>
                    </h4>
                    <p class="text-lg font-semibold text-green-600">
                      <%= get_edu_value(edu, ["institution"], "") %>
                    </p>
                    <p class="text-sm text-gray-600">
                      <%= get_edu_value(edu, ["location"], "") %>
                    </p>
                  </div>
                  <div class="text-right">
                    <p class="text-sm font-medium text-gray-700">
                      <%= format_education_dates(edu) %>
                    </p>
                    <%= if get_edu_value(edu, ["status"]) == "In Progress" do %>
                      <span class="inline-flex items-center px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full mt-1">
                        In Progress
                      </span>
                    <% end %>
                    <%= if get_edu_value(edu, ["gpa"], "") != "" do %>
                      <p class="text-xs text-gray-600 mt-1">GPA: <%= get_edu_value(edu, ["gpa"]) %></p>
                    <% end %>
                  </div>
                </div>

                <%= if get_edu_value(edu, ["description"], "") != "" do %>
                  <p class="text-gray-700 mb-3"><%= get_edu_value(edu, ["description"]) %></p>
                <% end %>

                <%= if length(get_edu_value(edu, ["relevant_coursework"], [])) > 0 do %>
                  <div class="mb-3">
                    <h5 class="font-semibold text-gray-900 mb-2">Relevant Coursework</h5>
                    <div class="flex flex-wrap gap-2">
                      <%= for course <- get_edu_value(edu, ["relevant_coursework"]) do %>
                        <span class="inline-flex items-center px-2 py-1 bg-gray-100 text-gray-800 text-xs font-medium rounded">
                          <%= course %>
                        </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if length(get_edu_value(edu, ["activities"], [])) > 0 do %>
                  <div>
                    <h5 class="font-semibold text-gray-900 mb-2">Activities & Honors</h5>
                    <ul class="list-disc list-inside text-sm text-gray-700">
                      <%= for activity <- get_edu_value(edu, ["activities"]) do %>
                        <li><%= activity %></li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if length(@certifications) > 0 do %>
        <div>
          <h3 class="text-xl font-bold text-gray-900 mb-6 flex items-center">
            <svg class="w-6 h-6 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
            </svg>
            Certifications
          </h3>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for cert <- @certifications do %>
              <div class="bg-gradient-to-r from-purple-50 to-blue-50 rounded-xl p-6 border border-purple-200 hover:shadow-lg transition-shadow">
                <h4 class="font-bold text-gray-900 mb-2">
                  <%= get_cert_value(cert, ["name"], "") %>
                </h4>
                <p class="text-purple-600 font-semibold mb-2">
                  <%= get_cert_value(cert, ["issuer"], "") %>
                </p>
                <div class="text-sm text-gray-600 mb-3">
                  <p>Earned: <%= get_cert_value(cert, ["date_earned"], "") %></p>
                  <%= if get_cert_value(cert, ["expiry_date"], "") != "" do %>
                    <p>Expires: <%= get_cert_value(cert, ["expiry_date"]) %></p>
                  <% end %>
                  <%= if get_cert_value(cert, ["credential_id"], "") != "" do %>
                    <p class="font-mono text-xs">ID: <%= get_cert_value(cert, ["credential_id"]) %></p>
                  <% end %>
                </div>
                <%= if get_cert_value(cert, ["verification_url"], "") != "" do %>
                  <a href={get_cert_value(cert, ["verification_url"])} target="_blank"
                     class="inline-flex items-center text-blue-600 hover:text-blue-700 text-sm font-medium">
                    Verify Credential
                    <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if length(@education) == 0 and length(@certifications) == 0 do %>
        <%= render_empty_state("academic-cap", "No education added yet", "Your educational background and certifications will appear here") %>
      <% end %>
    </div>
    """
  end

  # 🔥 ENHANCED: Contact section with comprehensive contact options
  defp render_contact_section(assigns) do
    email = get_content_value(assigns.content, ["primary_email", "email"], "")
    secondary_email = get_content_value(assigns.content, ["secondary_email"], "")
    phone = get_content_value(assigns.content, ["phone"], "")
    location = get_content_value(assigns.content, ["location"], %{})
    social_links = get_content_value(assigns.content, ["social_links"], %{})
    professional_profiles = get_content_value(assigns.content, ["professional_profiles"], %{})
    availability = get_content_value(assigns.content, ["availability"], %{})

    # Handle location as either string or map
    location_text = case location do
      %{"city" => city, "state" => state, "country" => country} ->
        [city, state, country] |> Enum.filter(&(&1 != "")) |> Enum.join(", ")
      location_string when is_binary(location_string) -> location_string
      _ -> ""
    end

    assigns = assign(assigns,
      email: email,
      secondary_email: secondary_email,
      phone: phone,
      location_text: location_text,
      social_links: social_links,
      professional_profiles: professional_profiles,
      availability: availability
    )

    ~H"""
    <div class="space-y-8">
      <!-- Primary Contact Information -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= if @email != "" do %>
          <div class="flex items-center space-x-4 p-6 bg-blue-50 rounded-xl border border-blue-200 hover:bg-blue-100 transition-colors">
            <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="font-semibold text-gray-900">Primary Email</p>
              <a href={"mailto:#{@email}"} class="text-blue-600 hover:text-blue-700 font-medium break-all">
                <%= @email %>
              </a>
            </div>
          </div>
        <% end %>

        <%= if @phone != "" do %>
          <div class="flex items-center space-x-4 p-6 bg-green-50 rounded-xl border border-green-200 hover:bg-green-100 transition-colors">
            <div class="w-12 h-12 bg-green-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="font-semibold text-gray-900">Phone</p>
              <a href={"tel:#{@phone}"} class="text-green-600 hover:text-green-700 font-medium">
                <%= @phone %>
              </a>
            </div>
          </div>
        <% end %>

        <%= if @location_text != "" do %>
          <div class="flex items-center space-x-4 p-6 bg-purple-50 rounded-xl border border-purple-200 hover:bg-purple-100 transition-colors">
            <div class="w-12 h-12 bg-purple-100 rounded-xl flex items-center justify-center">
              <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
              </svg>
            </div>
            <div class="flex-1">
              <p class="font-semibold text-gray-900">Location</p>
              <p class="text-purple-600 font-medium"><%= @location_text %></p>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Availability Status -->
      <%= if map_size(@availability) > 0 do %>
        <div class="bg-gradient-to-r from-green-50 to-blue-50 rounded-xl p-6 border border-green-200">
          <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <div class="w-3 h-3 bg-green-500 rounded-full mr-2 animate-pulse"></div>
            Availability
          </h4>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 text-sm">
            <%= if get_availability_value(@availability, "status") != "" do %>
              <div>
                <span class="font-medium text-gray-700">Status:</span>
                <span class="ml-1 text-green-600 font-semibold">
                  <%= get_availability_value(@availability, "status") %>
                </span>
              </div>
            <% end %>
            <%= if get_availability_value(@availability, "response_time") != "" do %>
              <div>
                <span class="font-medium text-gray-700">Response:</span>
                <span class="ml-1 text-gray-600">
                  <%= get_availability_value(@availability, "response_time") %>
                </span>
              </div>
            <% end %>
            <%= if get_availability_value(@availability, "working_hours") != "" do %>
              <div>
                <span class="font-medium text-gray-700">Hours:</span>
                <span class="ml-1 text-gray-600">
                  <%= get_availability_value(@availability, "working_hours") %>
                </span>
              </div>
            <% end %>
            <%= if length(get_availability_value(@availability, "open_to", [])) > 0 do %>
              <div>
                <span class="font-medium text-gray-700">Open to:</span>
                <div class="mt-1 flex flex-wrap gap-1">
                  <%= for opportunity <- get_availability_value(@availability, "open_to") do %>
                    <span class="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded-full">
                      <%= opportunity %>
                    </span>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Social Links -->
      <%= if map_size(@social_links) > 0 do %>
        <div class="border-t border-gray-200 pt-8">
          <h4 class="text-lg font-semibold text-gray-900 mb-6">Social Media</h4>
          <div class="grid grid-cols-2 md:grid-cols-4 lg:grid-cols-6 gap-4">
            <%= for {platform, url} <- @social_links, url != "" do %>
              <a href={url} target="_blank"
                 class="flex items-center justify-center p-4 bg-gray-50 hover:bg-gray-100 rounded-xl transition-colors group">
                <%= get_social_icon(platform) %>
                <span class="ml-2 text-sm font-medium text-gray-700 group-hover:text-gray-900">
                  <%= String.capitalize(platform) %>
                </span>
              </a>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Professional Profiles -->
      <%= if map_size(@professional_profiles) > 0 do %>
        <div class="border-t border-gray-200 pt-8">
          <h4 class="text-lg font-semibold text-gray-900 mb-6">Professional Profiles</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <%= for {platform, url} <- @professional_profiles, url != "" do %>
              <a href={url} target="_blank"
                 class="flex items-center space-x-3 p-4 bg-white border border-gray-200 rounded-xl hover:border-gray-300 hover:shadow-md transition-all">
                <%= get_professional_icon(platform) %>
                <div>
                  <p class="font-medium text-gray-900"><%= format_platform_name(platform) %></p>
                  <p class="text-sm text-gray-600">View Profile</p>
                </div>
              </a>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Secondary Contact -->
      <%= if @secondary_email != "" do %>
        <div class="border-t border-gray-200 pt-8">
          <h4 class="text-lg font-semibold text-gray-900 mb-4">Alternative Contact</h4>
          <div class="flex items-center space-x-3 p-4 bg-gray-50 rounded-xl">
            <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
            </svg>
            <div>
              <p class="font-medium text-gray-900">Secondary Email</p>
              <a href={"mailto:#{@secondary_email}"} class="text-blue-600 hover:text-blue-700">
                <%= @secondary_email %>
              </a>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # 🔥 ENHANCED: Projects section with detailed project information
  defp render_projects_section(assigns) do
    projects = get_content_value(assigns.content, ["projects"], [])
    assigns = assign(assigns, projects: ensure_list(projects))

    ~H"""
    <div class="space-y-6">
      <%= if length(@projects) > 0 do %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <%= for project <- @projects do %>
            <div class="bg-white border border-gray-200 rounded-xl shadow-sm hover:shadow-md transition-all duration-300 overflow-hidden">
              <!-- Project Header -->
              <div class="p-6 border-b border-gray-100">
                <div class="flex items-start justify-between mb-3">
                  <h3 class="text-xl font-bold text-gray-900 flex-1">
                    <%= get_project_value(project, ["title"], "Project") %>
                  </h3>
                  <%= if get_project_value(project, ["status"], "") != "" do %>
                    <span class={[
                      "px-3 py-1 text-xs font-medium rounded-full",
                      get_status_color(get_project_value(project, ["status"]))
                    ]}>
                      <%= get_project_value(project, ["status"]) %>
                    </span>
                  <% end %>
                </div>

                <div class="flex items-center justify-between text-sm text-gray-600">
                  <%= if get_project_value(project, ["role"], "") != "" do %>
                    <span class="font-medium"><%= get_project_value(project, ["role"]) %></span>
                  <% end %>
                  <span><%= format_project_dates(project) %></span>
                </div>
              </div>

              <!-- Project Content -->
              <div class="p-6">
                <%= if get_project_value(project, ["description"], "") != "" do %>
                  <p class="text-gray-700 leading-relaxed mb-4">
                    <%= get_project_value(project, ["description"]) %>
                  </p>
                <% end %>

                <%= if length(get_project_value(project, ["technologies"], [])) > 0 do %>
                  <div class="mb-4">
                    <h4 class="font-semibold text-gray-900 mb-2">Technologies Used</h4>
                    <div class="flex flex-wrap gap-2">
                      <%= for tech <- get_project_value(project, ["technologies"]) do %>
                        <span class="inline-flex items-center px-2 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded">
                          <%= tech %>
                        </span>
                      <% end %>
                    </div>
                  </div>
                <% end %>

                <%= if get_project_value(project, ["my_contribution"], "") != "" do %>
                  <div class="mb-4">
                    <h4 class="font-semibold text-gray-900 mb-2">My Contribution</h4>
                    <p class="text-gray-700 text-sm">
                      <%= get_project_value(project, ["my_contribution"]) %>
                    </p>
                  </div>
                <% end %>

                <!-- Project Links -->
                <div class="flex items-center space-x-4 pt-4 border-t border-gray-100">
                  <%= if get_project_value(project, ["demo_url"], "") != "" do %>
                    <a href={get_project_value(project, ["demo_url"])} target="_blank"
                       class="inline-flex items-center text-blue-600 hover:text-blue-700 font-medium text-sm">
                      <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                      </svg>
                      Live Demo
                    </a>
                  <% end %>
                  <%= if get_project_value(project, ["github_url"], "") != "" do %>
                    <a href={get_project_value(project, ["github_url"])} target="_blank"
                       class="inline-flex items-center text-gray-600 hover:text-gray-700 font-medium text-sm">
                      <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
                      </svg>
                      View Code
                    </a>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% else %>
        <%= render_empty_state("briefcase", "No projects added yet", "Your portfolio projects will appear here") %>
      <% end %>
    </div>
    """
  end

  # 🔥 Additional section renderers (keeping concise)
  defp render_featured_project_section(assigns) do
    title = get_content_value(assigns.content, ["title"], "")
    subtitle = get_content_value(assigns.content, ["subtitle"], "")
    description = get_content_value(assigns.content, ["description"], "")

    assigns = assign(assigns, title: title, subtitle: subtitle, description: description)

    ~H"""
    <div class="space-y-6">
      <%= if @title != "" do %>
        <div class="text-center">
          <h3 class="text-3xl font-bold text-gray-900 mb-2"><%= @title %></h3>
          <%= if @subtitle != "" do %>
            <p class="text-xl text-gray-600 font-medium"><%= @subtitle %></p>
          <% end %>
        </div>
      <% end %>
      <%= if @description != "" do %>
        <div class="prose max-w-none">
          <p class="text-lg text-gray-700 leading-relaxed"><%= @description %></p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_achievements_section(assigns) do
    achievements = get_content_value(assigns.content, ["achievements"], [])
    assigns = assign(assigns, achievements: ensure_list(achievements))

    ~H"""
    <div class="space-y-4">
      <%= if length(@achievements) > 0 do %>
        <%= for achievement <- @achievements do %>
          <div class="bg-gradient-to-r from-yellow-50 to-orange-50 border border-yellow-200 rounded-lg p-6 hover:shadow-md transition-shadow">
            <div class="flex items-start space-x-4">
              <div class="w-12 h-12 bg-yellow-100 rounded-full flex items-center justify-center flex-shrink-0">
                <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                </svg>
              </div>
              <div class="flex-1">
                <h3 class="font-bold text-gray-900 mb-2">
                  <%= get_achievement_value(achievement, ["title"], "") %>
                </h3>
                <p class="text-gray-700 mb-3">
                  <%= get_achievement_value(achievement, ["description"], "") %>
                </p>
                <div class="flex items-center justify-between text-sm">
                  <span class="text-yellow-600 font-medium">
                    <%= get_achievement_value(achievement, ["organization"], "") %>
                  </span>
                  <span class="text-gray-500">
                    <%= get_achievement_value(achievement, ["date"], "") %>
                  </span>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% else %>
        <%= render_empty_state("trophy", "No achievements added yet", "Your awards and recognition will appear here") %>
      <% end %>
    </div>
    """
  end

  # 🔥 Generic and fallback renderers
  defp render_case_study_section(assigns), do: render_generic_section(assigns)
  defp render_testimonial_section(assigns), do: render_generic_section(assigns)
  defp render_media_showcase_section(assigns), do: render_generic_section(assigns)

  defp render_generic_section(assigns) do
    content = get_content_value(assigns.content, ["content", "description", "summary"], "")
    assigns = assign(assigns, content_text: content)

    ~H"""
    <div class="prose max-w-none">
      <%= if @content_text != "" do %>
        <p class="text-gray-700 leading-relaxed"><%= @content_text %></p>
      <% else %>
        <%= render_empty_state("document-text", "Content coming soon", "This section is being developed") %>
      <% end %>
    </div>
    """
  end

  # 🔥 HELPER FUNCTIONS

  # Safe content extraction with multiple key fallbacks
  defp get_content_value(content, keys, default \\ "") when is_list(keys) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(content, key) do
        nil -> nil
        "" -> nil
        value -> value
      end
    end)
  end

  defp get_content_value(content, key, default) when is_binary(key) do
    case Map.get(content, key, default) do
      "" -> default
      nil -> default
      value -> value
    end
  end

  # Specialized getters for different data structures
  defp get_job_value(job, keys, default \\ "") when is_map(job) do
    get_content_value(job, keys, default)
  end

  defp get_edu_value(edu, keys, default \\ "") when is_map(edu) do
    get_content_value(edu, keys, default)
  end

  defp get_cert_value(cert, keys, default \\ "") when is_map(cert) do
    get_content_value(cert, keys, default)
  end

  defp get_project_value(project, keys, default \\ "") when is_map(project) do
    get_content_value(project, keys, default)
  end

  defp get_achievement_value(achievement, keys, default \\ "") when is_map(achievement) do
    get_content_value(achievement, keys, default)
  end

  defp get_availability_value(availability, key, default \\ "") when is_map(availability) do
    get_content_value(availability, key, default)
  end

  # Ensure data is in list format
  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(_), do: []

  # Check if content exists and is meaningful
  defp has_content?(content) when is_map(content) do
    content
    |> Map.values()
    |> Enum.any?(fn
      value when is_binary(value) -> String.trim(value) != ""
      value when is_list(value) -> length(value) > 0
      value when is_map(value) -> map_size(value) > 0
      _ -> false
    end)
  end
  defp has_content?(_), do: false

  # Date formatting helpers
  defp format_job_dates(job) do
    start_date = get_job_value(job, ["start_date"], "")
    end_date = get_job_value(job, ["end_date"], "")
    current = get_job_value(job, ["current"], false)

    cond do
      current and start_date != "" -> "#{start_date} - Present"
      start_date != "" and end_date != "" -> "#{start_date} - #{end_date}"
      start_date != "" -> "Since #{start_date}"
      true -> ""
    end
  end

  defp format_education_dates(edu) do
    start_date = get_edu_value(edu, ["start_date"], "")
    end_date = get_edu_value(edu, ["end_date"], "")
    status = get_edu_value(edu, ["status"], "")

    cond do
      status == "In Progress" and start_date != "" -> "#{start_date} - Present"
      start_date != "" and end_date != "" -> "#{start_date} - #{end_date}"
      start_date != "" -> "Since #{start_date}"
      true -> ""
    end
  end

  defp format_project_dates(project) do
    start_date = get_project_value(project, ["start_date"], "")
    end_date = get_project_value(project, ["end_date"], "")
    status = get_project_value(project, ["status"], "")

    cond do
      status == "In Progress" and start_date != "" -> "#{start_date} - Present"
      start_date != "" and end_date != "" -> "#{start_date} - #{end_date}"
      start_date != "" -> "Since #{start_date}"
      true -> ""
    end
  end

  # UI helpers for styling and icons
  defp get_section_icon_bg(section_type) do
    case section_type do
      type when type in [:intro, "intro"] -> "bg-blue-100"
      type when type in [:experience, "experience"] -> "bg-green-100"
      type when type in [:education, "education"] -> "bg-purple-100"
      type when type in [:skills, "skills"] -> "bg-yellow-100"
      type when type in [:projects, "projects"] -> "bg-indigo-100"
      type when type in [:contact, "contact"] -> "bg-gray-100"
      _ -> "bg-gray-100"
    end
  end

  defp render_section_icon(section_type) do
    Phoenix.HTML.raw(case section_type do
      type when type in [:intro, "intro"] ->
        """
        <svg class="w-6 h-6 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """
      type when type in [:experience, "experience"] ->
        """
        <svg class="w-6 h-6 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8zM16 10h.01"/>
        </svg>
        """
      type when type in [:education, "education"] ->
        """
        <svg class="w-6 h-6 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
        </svg>
        """
      type when type in [:skills, "skills"] ->
        """
        <svg class="w-6 h-6 text-yellow-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """
      type when type in [:contact, "contact"] ->
        """
        <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
        </svg>
        """
    end)
  end

  defp format_section_type(section_type) do
    case section_type do
      type when type in [:intro, "intro"] -> "Introduction"
      type when type in [:experience, "experience"] -> "Work Experience"
      type when type in [:education, "education"] -> "Education"
      type when type in [:skills, "skills"] -> "Skills & Expertise"
      type when type in [:projects, "projects"] -> "Projects"
      type when type in [:featured_project, "featured_project"] -> "Featured Project"
      type when type in [:contact, "contact"] -> "Contact Information"
      type when type in [:achievements, "achievements"] -> "Achievements"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  defp render_skill_badge(skill, show_proficiency \\ true) do
    {skill_name, proficiency, years} = case skill do
      %{"name" => name, "proficiency" => prof, "years" => y} -> {name, prof, y}
      %{"name" => name, "proficiency" => prof} -> {name, prof, nil}
      %{"name" => name} -> {name, "intermediate", nil}
      skill_string when is_binary(skill_string) -> {skill_string, "intermediate", nil}
      _ -> {"Unknown Skill", "intermediate", nil}
    end

    assigns = %{
      skill_name: skill_name,
      proficiency: proficiency,
      years: years,
      show_proficiency: show_proficiency
    }

    ~H"""
    <div class={[
      "relative inline-flex items-center justify-center px-4 py-3 rounded-lg text-sm font-semibold border-2 transition-all duration-200 hover:scale-105",
      get_skill_badge_color(@proficiency)
    ]}>
      <span class="text-white relative z-10"><%= @skill_name %></span>
      <%= if @years do %>
        <span class="absolute -top-1 -right-1 bg-white text-gray-800 text-xs px-1.5 py-0.5 rounded-full font-bold text-[10px]">
          <%= @years %>y
        </span>
      <% end %>
      <%= if @show_proficiency do %>
        <div class="absolute bottom-1 left-1/2 transform -translate-x-1/2 flex space-x-0.5">
          <%= for i <- 1..3 do %>
            <div class={[
              "w-1 h-1 rounded-full",
              get_proficiency_dot_color(@proficiency, i)
            ]}></div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_skill_badge_color(proficiency) do
    case proficiency do
      "expert" -> "bg-blue-900 border-blue-950 shadow-lg"
      "advanced" -> "bg-blue-700 border-blue-800"
      "intermediate" -> "bg-blue-500 border-blue-600"
      "beginner" -> "bg-blue-300 border-blue-400"
      _ -> "bg-blue-500 border-blue-600"
    end
  end

  defp get_proficiency_dot_color(proficiency, dot_index) do
    dots = case proficiency do
      "beginner" -> 1
      "intermediate" -> 2
      "advanced" -> 3
      "expert" -> 3
      _ -> 2
    end

    if dot_index <= dots do
      if proficiency == "expert" do
        "bg-yellow-300 ring-1 ring-yellow-400"
      else
        "bg-white"
      end
    else
      "bg-white bg-opacity-40"
    end
  end

  defp get_category_color(category) do
    case String.downcase(to_string(category)) do
      cat when cat in ["programming", "programming languages"] -> "bg-blue-500"
      cat when cat in ["frameworks", "frameworks & libraries"] -> "bg-indigo-500"
      cat when cat in ["tools", "tools & platforms"] -> "bg-orange-500"
      cat when cat in ["databases", "data & analytics"] -> "bg-green-500"
      cat when cat in ["design", "design & creative"] -> "bg-purple-500"
      cat when cat in ["soft skills", "communication"] -> "bg-emerald-500"
      cat when cat in ["leadership", "leadership & management"] -> "bg-red-500"
      _ -> "bg-gray-500"
    end
  end

  defp get_status_color(status) do
    case String.downcase(to_string(status)) do
      "completed" -> "bg-green-100 text-green-800"
      "in progress" -> "bg-blue-100 text-blue-800"
      "on hold" -> "bg-yellow-100 text-yellow-800"
      "cancelled" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp get_social_icon(platform) do
    Phoenix.HTML.raw(case String.downcase(to_string(platform)) do
      "linkedin" ->
        """
        <svg class="w-5 h-5 text-blue-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z" clip-rule="evenodd"/>
        </svg>
        """
      "github" ->
        """
        <svg class="w-5 h-5 text-gray-900" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"/>
        </svg>
        """
      "twitter" ->
        """
        <svg class="w-5 h-5 text-blue-400" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """
    end)
  end

  defp get_professional_icon(platform) do
    Phoenix.HTML.raw(case String.downcase(to_string(platform)) do
      "stackoverflow" ->
        """
        <svg class="w-6 h-6 text-orange-500" fill="currentColor" viewBox="0 0 20 20">
          <path d="M12.658 14.577v-4.27h1.423V16H1.23v-5.693h1.423v4.27h9.005zm-8.583-1.423h7.16V11.73h-7.16v1.424zm.173-3.235l6.987 1.46.3-1.383L4.55 8.54l-.302 1.379zm.906-3.37l6.47 3.02.602-1.292-6.47-3.02-.602 1.292zm1.81-3.19l5.478 4.57.906-1.08L7.87 2.28l-.906 1.079zM10.502 0L9.338.863l4.27 5.735 1.164-.862L10.502 0z"/>
        </svg>
        """
      "medium" ->
        """
        <svg class="w-6 h-6 text-green-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M2.846 6.887c.03-.295-.083-.586-.303-.784l-2.24-2.7v-.403h6.958l5.378 11.795 4.728-11.795H20L20 5.55l-1.917 1.837c-.165.126-.25.333-.222.538v13.498c-.028.205.057.412.222.538L20 23.334v.403h-8.365v-.403l1.75-1.749c.172-.172.172-.223.172-.537V9.66l-4.866 12.352h-.658L2.846 9.66v8.281c-.046.386.077.774.334 1.053l2.42 2.94v.403H0v-.403l2.42-2.94c.257-.279.38-.667.334-1.053V6.887z" clip-rule="evenodd"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-6 h-6 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9v-9m0-9v9"/>
        </svg>
        """
    end)
  end

  defp format_platform_name(platform) do
    case String.downcase(to_string(platform)) do
      "stackoverflow" -> "Stack Overflow"
      "dev_to" -> "Dev.to"
      "codepen" -> "CodePen"
      _ -> String.capitalize(to_string(platform))
    end
  end

  defp format_url_display(url) when is_binary(url) do
    url
    |> String.replace(~r/^https?:\/\//, "")
    |> String.replace(~r/^www\./, "")
    |> String.split("/")
    |> List.first()
  end
  defp format_url_display(_), do: ""

  defp render_empty_state(icon, title, description) do
    icon_svg = case icon do
      "briefcase" ->
        """
        <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8zM16 10h.01"/>
        </svg>
        """
      "academic-cap" ->
        """
        <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
        </svg>
        """
      "lightning-bolt" ->
        """
        <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
        </svg>
        """
      "trophy" ->
        """
        <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-12 h-12 text-gray-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """
    end

    assigns = %{icon_svg: icon_svg, title: title, description: description}

    ~H"""
    <div class="text-center py-12">
      <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <%= Phoenix.HTML.raw(@icon_svg) %>
      </div>
      <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= @title %></h3>
      <p class="text-gray-600"><%= @description %></p>
    </div>
    """
  end
end
