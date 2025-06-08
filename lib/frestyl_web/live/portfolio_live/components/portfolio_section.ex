# lib/frestyl_web/live/portfolio_live/components/portfolio_section.ex
defmodule FrestylWeb.PortfolioLive.Components.PortfolioSection do
  use FrestylWeb, :live_component
  alias Frestyl.Portfolios

  def render(assigns) do
    ~H"""
    <article class={[
      "portfolio-section",
      get_section_container_class(@template_theme, @section.section_type),
      get_section_size_class(@template_theme, @section.section_type)
    ]}
    id={"section-#{@section.id}"}
    data-section-id={@section.id}>

      <!-- Section Header -->
      <header class={[
        "section-header",
        get_section_header_class(@template_theme, @section.section_type)
      ]}>
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <div class={[
              "section-icon",
              get_section_icon_bg_class(@template_theme, @section.section_type)
            ]}>
              <%= render_section_icon(@section.section_type, @template_theme) %>
            </div>

            <div>
              <h2 class={[
                "section-title",
                get_section_title_class(@template_theme)
              ]}>
                <%= @section.title %>
              </h2>

              <p class={[
                "section-type-badge",
                get_section_badge_class(@template_theme, @section.section_type)
              ]}>
                <%= format_section_type(@section.section_type) %>
              </p>
            </div>
          </div>

          <!-- Collaboration Actions -->
          <%= if @collaboration_enabled do %>
            <div class="flex items-center space-x-2">
              <button phx-click="add_quick_note"
                      phx-value-section-id={@section.id}
                      class="p-2 text-gray-400 hover:text-blue-600 transition-colors"
                      title="Add quick note">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
              </button>

              <button phx-click="highlight_section"
                      phx-value-section-id={@section.id}
                      class="p-2 text-gray-400 hover:text-yellow-600 transition-colors"
                      title="Highlight section">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14"/>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </header>

      <!-- Section Content -->
      <div class={[
        "section-content",
        get_section_content_class(@template_theme)
      ]}>
        <%= render_section_content(assigns) %>
      </div>

      <!-- Section Media (if any) -->
      <%= if has_media?(@section) do %>
        <div class={[
          "section-media",
          get_section_media_class(@template_theme, @section.section_type)
        ]}>
          <%= render_section_media(assigns) %>
        </div>
      <% end %>

      <!-- Collaboration Feedback for this section -->
      <%= if @collaboration_enabled do %>
        <div class="section-feedback mt-6 pt-4 border-t border-gray-200">
          <div class="flex items-center space-x-2 mb-3">
            <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
            <span class="text-sm font-medium text-gray-700">Share your thoughts on this section</span>
          </div>

          <form phx-submit="submit_feedback" phx-target={@myself} class="space-y-3">
            <input type="hidden" name="section_id" value={@section.id} />
            <textarea name="feedback"
                      placeholder="What feedback do you have for this section?"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm"
                      rows="3"></textarea>
            <button type="submit"
                    class="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-blue-700 transition-colors">
              Add Feedback
            </button>
          </form>
        </div>
      <% end %>
    </article>
    """
  end

  # Section content rendering based on type
  defp render_section_content(assigns) do
    case assigns.section.section_type do
      :intro -> render_intro_content(assigns)
      :experience -> render_experience_content(assigns)
      :education -> render_education_content(assigns)
      :skills -> render_skills_content(assigns)
      :featured_project -> render_featured_project_content(assigns)
      :case_study -> render_case_study_content(assigns)
      :media_showcase -> render_media_showcase_content(assigns)
      :testimonial -> render_testimonial_content(assigns)
      :contact -> render_contact_content(assigns)
      _ -> render_generic_content(assigns)
    end
  end

  defp render_intro_content(assigns) do
    headline = get_in(assigns.section.content, ["headline"]) || ""
    summary = get_in(assigns.section.content, ["summary"]) || ""

    ~H"""
    <div class="space-y-6">
      <%= if headline != "" do %>
        <h3 class={[
          "text-2xl font-bold",
          get_content_headline_class(@template_theme)
        ]}>
          <%= headline %>
        </h3>
      <% end %>

      <%= if summary != "" do %>
        <div class={[
          "prose prose-lg max-w-none",
          get_content_text_class(@template_theme)
        ]}>
          <%= Phoenix.HTML.raw(format_text_content(summary)) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_experience_content(assigns) do
    jobs = get_in(assigns.section.content, ["jobs"]) || []

    ~H"""
    <div class="space-y-6">
      <%= for {job, index} <- Enum.with_index(jobs) do %>
        <div class={[
          "experience-item p-6 rounded-xl border-l-4 transition-all duration-300 hover:shadow-lg",
          get_experience_item_class(@template_theme, index == 0)
        ]}>
          <div class="flex justify-between items-start mb-4">
            <div class="flex-1">
              <h4 class={[
                "text-xl font-bold mb-1",
                get_job_title_class(@template_theme)
              ]}>
                <%= Map.get(job, "title", "") %>
              </h4>

              <p class={[
                "text-lg font-semibold mb-2",
                get_company_name_class(@template_theme)
              ]}>
                <%= Map.get(job, "company", "") %>
              </p>

              <p class={[
                "text-sm font-medium",
                get_job_duration_class(@template_theme)
              ]}>
                <%= Map.get(job, "start_date", "") %> -
                <%= if Map.get(job, "current"), do: "Present", else: Map.get(job, "end_date", "") %>
              </p>
            </div>

            <%= if Map.get(job, "current") do %>
              <span class="inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-sm font-bold rounded-full">
                <div class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></div>
                Current
              </span>
            <% end %>
          </div>

          <%= if Map.get(job, "description") do %>
            <div class={[
              "prose max-w-none",
              get_job_description_class(@template_theme)
            ]}>
              <%= Phoenix.HTML.raw(format_text_content(Map.get(job, "description"))) %>
            </div>
          <% end %>

          <!-- Job-specific achievements or highlights -->
          <%= if Map.get(job, "achievements") do %>
            <div class="mt-4">
              <h5 class="text-sm font-semibold text-gray-700 mb-2">Key Achievements:</h5>
              <ul class="list-disc list-inside text-sm text-gray-600 space-y-1">
                <%= for achievement <- Map.get(job, "achievements") do %>
                  <li><%= achievement %></li>
                <% end %>
              </ul>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if Enum.empty?(jobs) do %>
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
            </svg>
          </div>
          <p class="text-gray-500">Professional experience details coming soon</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_skills_content(assigns) do
    skills = get_in(assigns.section.content, ["skills"]) || []

    ~H"""
    <div class="space-y-6">
      <%= if not Enum.empty?(skills) do %>
        <div class="flex flex-wrap gap-3">
          <%= for {skill, index} <- Enum.with_index(skills) do %>
            <span class={[
              "skill-tag px-4 py-2 rounded-xl text-sm font-semibold transition-all duration-300 hover:scale-105",
              get_skill_tag_class(@template_theme, index)
            ]}>
              <%= skill %>
            </span>
          <% end %>
        </div>
      <% else %>
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
            </svg>
          </div>
          <p class="text-gray-500">Skills and competencies will be showcased here</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_featured_project_content(assigns) do
    content = assigns.section.content || %{}

    ~H"""
    <div class="space-y-6">
      <%= if Map.get(content, "description") do %>
        <div class={[
          "prose prose-lg max-w-none",
          get_content_text_class(@template_theme)
        ]}>
          <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "description"))) %>
        </div>
      <% end %>

      <!-- Project Details Grid -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= if Map.get(content, "challenge") do %>
          <div class={[
            "project-detail p-4 rounded-lg border-l-4",
            get_project_detail_class(@template_theme, "challenge")
          ]}>
            <h4 class="font-semibold text-sm uppercase tracking-wide mb-2 text-red-800">Challenge</h4>
            <p class="text-sm text-red-700"><%= Map.get(content, "challenge") %></p>
          </div>
        <% end %>

        <%= if Map.get(content, "solution") do %>
          <div class={[
            "project-detail p-4 rounded-lg border-l-4",
            get_project_detail_class(@template_theme, "solution")
          ]}>
            <h4 class="font-semibold text-sm uppercase tracking-wide mb-2 text-green-800">Solution</h4>
            <p class="text-sm text-green-700"><%= Map.get(content, "solution") %></p>
          </div>
        <% end %>
      </div>

      <!-- Technologies Used -->
      <%= if Map.get(content, "technologies") and not Enum.empty?(Map.get(content, "technologies")) do %>
        <div class="mt-6">
          <h4 class="text-sm font-semibold text-gray-700 mb-3">Technologies Used</h4>
          <div class="flex flex-wrap gap-2">
            <%= for tech <- Map.get(content, "technologies") do %>
              <span class="px-3 py-1 bg-blue-100 text-blue-800 text-xs font-bold rounded-full">
                <%= tech %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Project Links -->
      <div class="flex gap-4 mt-6">
        <%= if Map.get(content, "demo_url") do %>
          <a href={Map.get(content, "demo_url")}
             target="_blank"
             class={[
               "inline-flex items-center px-4 py-2 text-sm font-semibold rounded-lg transition-all duration-300 hover:scale-105",
               get_project_link_class(@template_theme, "demo")
             ]}>
            <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
            Live Demo
          </a>
        <% end %>

        <%= if Map.get(content, "github_url") do %>
          <a href={Map.get(content, "github_url")}
             target="_blank"
             class={[
               "inline-flex items-center px-4 py-2 text-sm font-semibold rounded-lg border transition-all duration-300 hover:scale-105",
               get_project_link_class(@template_theme, "github")
             ]}>
            <svg class="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
            </svg>
            View Code
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  # Media rendering function
  defp render_section_media(assigns) do
    media_files = get_section_media_files(assigns.section)

    ~H"""
    <div class={[
      "media-gallery",
      get_media_gallery_class(@template_theme, @section.section_type)
    ]}>
      <%= for {media, index} <- Enum.with_index(media_files) do %>
        <div class={[
          "media-item group relative overflow-hidden rounded-xl",
          get_media_item_class(@template_theme, media.media_type, index)
        ]}>
          <%= case media.media_type do %>
            <% :image -> %>
              <img src={get_media_url(media)}
                   alt={media.title || "Section media"}
                   class="w-full h-full object-cover transition-transform duration-500 group-hover:scale-110"
                   loading="lazy" />

            <% :video -> %>
              <div class="relative aspect-video bg-black">
                <video class="w-full h-full object-cover"
                       poster={get_video_thumbnail(media)}
                       preload="metadata"
                       controls>
                  <source src={get_media_url(media)} type="video/mp4" />
                  Your browser does not support the video tag.
                </video>
              </div>

            <% :audio -> %>
              <div class="p-6 bg-gradient-to-br from-purple-500 to-indigo-600 text-white">
                <div class="flex items-center space-x-4 mb-4">
                  <div class="w-12 h-12 bg-white/20 rounded-full flex items-center justify-center">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
                    </svg>
                  </div>
                  <div>
                    <h4 class="font-semibold"><%= media.title || "Audio Content" %></h4>
                    <p class="text-white/80 text-sm"><%= media.description || "Audio file" %></p>
                  </div>
                </div>
                <audio controls class="w-full">
                  <source src={get_media_url(media)} type="audio/mpeg" />
                  <source src={get_media_url(media)} type="audio/wav" />
                  Your browser does not support the audio tag.
                </audio>
              </div>

            <% :document -> %>
              <div class="p-6 bg-gradient-to-br from-gray-500 to-gray-600 text-white">
                <div class="flex items-center space-x-4 mb-4">
                  <div class="w-12 h-12 bg-white/20 rounded-full flex items-center justify-center">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
                  <div>
                    <h4 class="font-semibold"><%= media.title || "Document" %></h4>
                    <p class="text-white/80 text-sm"><%= get_file_type_label(media.mime_type) %></p>
                  </div>
                </div>
                <a href={get_media_url(media)}
                   target="_blank"
                   class="inline-flex items-center px-4 py-2 bg-white/20 rounded-lg hover:bg-white/30 transition-colors">
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Download
                </a>
              </div>

            <% _ -> %>
              <div class="p-6 bg-gray-100 text-center">
                <svg class="w-12 h-12 text-gray-400 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                <p class="text-gray-500 text-sm">Unsupported media type</p>
              </div>
          <% end %>

          <!-- Media Overlay Info -->
          <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4 opacity-0 group-hover:opacity-100 transition-opacity">
            <h4 class="text-white font-semibold text-sm">
              <%= media.title || "Media Asset" %>
            </h4>
            <%= if media.description do %>
              <p class="text-white/80 text-xs mt-1">
                <%= String.slice(media.description, 0, 80) %>
                <%= if String.length(media.description) > 80, do: "..." %>
              </p>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

    defp render_case_study_content(assigns) do
    content = assigns.section.content || %{}

    ~H"""
    <div class="space-y-8">
      <!-- Case Study Overview -->
      <%= if Map.get(content, "overview") do %>
        <div class="bg-blue-50 rounded-xl p-6 border-l-4 border-l-blue-500">
          <h4 class="font-semibold text-blue-900 mb-3">Project Overview</h4>
          <div class="prose prose-blue max-w-none">
            <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "overview"))) %>
          </div>
        </div>
      <% end %>

      <!-- Client & Project Title -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= if Map.get(content, "client") do %>
          <div class="text-center md:text-left">
            <h5 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Client</h5>
            <p class="text-xl font-bold text-gray-900 mt-1"><%= Map.get(content, "client") %></p>
          </div>
        <% end %>

        <%= if Map.get(content, "project_title") do %>
          <div class="text-center md:text-left">
            <h5 class="text-sm font-medium text-gray-500 uppercase tracking-wide">Project</h5>
            <p class="text-xl font-bold text-gray-900 mt-1"><%= Map.get(content, "project_title") %></p>
          </div>
        <% end %>
      </div>

      <!-- Problem Statement -->
      <%= if Map.get(content, "problem_statement") do %>
        <div class="bg-red-50 rounded-xl p-6 border-l-4 border-l-red-500">
          <h4 class="font-semibold text-red-900 mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.732-.833-2.5 0L4.232 15.5c-.77.833.192 2.5 1.732 2.5z"/>
            </svg>
            Problem Statement
          </h4>
          <div class="prose prose-red max-w-none">
            <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "problem_statement"))) %>
          </div>
        </div>
      <% end %>

      <!-- Approach -->
      <%= if Map.get(content, "approach") do %>
        <div class="bg-purple-50 rounded-xl p-6 border-l-4 border-l-purple-500">
          <h4 class="font-semibold text-purple-900 mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
            </svg>
            Approach
          </h4>
          <div class="prose prose-purple max-w-none">
            <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "approach"))) %>
          </div>
        </div>
      <% end %>

      <!-- Process Steps -->
      <%= if Map.get(content, "process") and length(Map.get(content, "process")) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-4">Process</h4>
          <div class="space-y-4">
            <%= for {step, index} <- Enum.with_index(Map.get(content, "process"), 1) do %>
              <div class="flex items-start space-x-4">
                <div class="w-8 h-8 bg-blue-600 text-white rounded-full flex items-center justify-center font-bold text-sm">
                  <%= index %>
                </div>
                <div class="flex-1">
                  <p class="text-gray-800"><%= step %></p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Results -->
      <%= if Map.get(content, "results") do %>
        <div class="bg-green-50 rounded-xl p-6 border-l-4 border-l-green-500">
          <h4 class="font-semibold text-green-900 mb-3 flex items-center">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            Results
          </h4>
          <div class="prose prose-green max-w-none">
            <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "results"))) %>
          </div>
        </div>
      <% end %>

      <!-- Metrics -->
      <%= if Map.get(content, "metrics") and length(Map.get(content, "metrics")) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-4">Key Metrics</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <%= for metric <- Map.get(content, "metrics") do %>
              <div class="bg-white border border-gray-200 rounded-lg p-4 text-center">
                <div class="text-2xl font-bold text-blue-600"><%= Map.get(metric, "value", "N/A") %></div>
                <div class="text-sm text-gray-600"><%= Map.get(metric, "label", "Metric") %></div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_media_showcase_content(assigns) do
    content = assigns.section.content || %{}

    ~H"""
    <div class="space-y-6">
      <%= if Map.get(content, "title") do %>
        <h3 class="text-2xl font-bold text-gray-900">
          <%= Map.get(content, "title") %>
        </h3>
      <% end %>

      <%= if Map.get(content, "description") do %>
        <div class="prose prose-lg max-w-none text-gray-700">
          <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "description"))) %>
        </div>
      <% end %>

      <!-- Context & What to Notice -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= if Map.get(content, "context") do %>
          <div class="bg-blue-50 rounded-lg p-4">
            <h4 class="font-semibold text-blue-900 mb-2">Context</h4>
            <p class="text-blue-800 text-sm"><%= Map.get(content, "context") %></p>
          </div>
        <% end %>

        <%= if Map.get(content, "what_to_notice") do %>
          <div class="bg-purple-50 rounded-lg p-4">
            <h4 class="font-semibold text-purple-900 mb-2">What to Notice</h4>
            <p class="text-purple-800 text-sm"><%= Map.get(content, "what_to_notice") %></p>
          </div>
        <% end %>
      </div>

      <!-- Techniques Used -->
      <%= if Map.get(content, "techniques_used") and length(Map.get(content, "techniques_used")) > 0 do %>
        <div>
          <h4 class="font-semibold text-gray-900 mb-3">Techniques Used</h4>
          <div class="flex flex-wrap gap-2">
            <%= for technique <- Map.get(content, "techniques_used") do %>
              <span class="px-3 py-1 bg-gray-100 text-gray-800 text-sm font-medium rounded-full">
                <%= technique %>
              </span>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Media Gallery Placeholder -->
      <div class="bg-gray-100 rounded-xl p-8 text-center">
        <svg class="w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        <p class="text-gray-600">Media gallery will display here</p>
        <p class="text-sm text-gray-500 mt-1">Upload images, videos, or other media to showcase your work</p>
      </div>
    </div>
    """
  end

  defp render_testimonial_content(assigns) do
    content = assigns.section.content || %{}
    testimonials = Map.get(content, "testimonials") || []

    ~H"""
    <div class="space-y-8">
      <%= if length(testimonials) > 0 do %>
        <div class="grid grid-cols-1 gap-8">
          <%= for {testimonial, index} <- Enum.with_index(testimonials) do %>
            <div class={[
              "relative p-6 rounded-2xl shadow-lg transition-all duration-300 hover:shadow-xl",
              get_testimonial_bg_class(index)
            ]}>
              <!-- Quote Icon -->
              <div class="absolute top-4 left-4 w-8 h-8 opacity-20">
                <svg class="w-full h-full" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M14.017 21v-7.391c0-5.704 3.731-9.57 8.983-10.609l.995 2.151c-2.432.917-3.995 3.638-3.995 5.849h4v10h-9.983zm-14.017 0v-7.391c0-5.704 3.748-9.57 9-10.609l.996 2.151c-2.433.917-3.996 3.638-3.996 5.849h4v10h-10z"/>
                </svg>
              </div>

              <!-- Testimonial Content -->
              <blockquote class="relative z-10">
                <p class="text-lg leading-relaxed mb-6 italic">
                  "<%= Map.get(testimonial, "quote", "") %>"
                </p>

                <footer class="flex items-center space-x-4">
                  <!-- Avatar -->
                  <div class="w-12 h-12 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                    <span class="text-lg font-bold">
                      <%= String.first(Map.get(testimonial, "name", "A")) %>
                    </span>
                  </div>

                  <!-- Attribution -->
                  <div>
                    <div class="font-semibold"><%= Map.get(testimonial, "name", "") %></div>
                    <div class="text-sm opacity-80">
                      <%= Map.get(testimonial, "title", "") %>
                      <%= if Map.get(testimonial, "company") do %>
                        at <%= Map.get(testimonial, "company") %>
                      <% end %>
                    </div>
                  </div>
                </footer>
              </blockquote>

              <!-- Rating Stars (if provided) -->
              <%= if Map.get(testimonial, "rating") do %>
                <div class="flex items-center mt-4 space-x-1">
                  <%= for star <- 1..5 do %>
                    <svg class={[
                      "w-5 h-5",
                      if(star <= (Map.get(testimonial, "rating") || 0),
                         do: "text-yellow-400",
                         else: "text-gray-300")
                    ]} fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                    </svg>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="text-center py-12">
          <div class="w-24 h-24 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-6">
            <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
          </div>
          <h3 class="text-xl font-semibold text-gray-900 mb-2">No testimonials yet</h3>
          <p class="text-gray-600">Client testimonials and recommendations will appear here</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function for testimonial background colors
  defp get_testimonial_bg_class(index) do
    case rem(index, 4) do
      0 -> "bg-gradient-to-br from-blue-500 to-purple-600 text-white"
      1 -> "bg-gradient-to-br from-green-500 to-teal-600 text-white"
      2 -> "bg-gradient-to-br from-purple-500 to-pink-600 text-white"
      3 -> "bg-gradient-to-br from-orange-500 to-red-600 text-white"
    end
  end

  # Additional section type renderers
  defp render_education_content(assigns) do
    education = get_in(assigns.section.content, ["education"]) || []

    ~H"""
    <div class="space-y-6">
      <%= for edu <- education do %>
        <div class="education-item p-6 rounded-xl border-l-4 border-l-purple-500 bg-purple-50">
          <h4 class="text-xl font-bold text-purple-900 mb-1">
            <%= Map.get(edu, "degree", "") %>
            <%= if Map.get(edu, "field"), do: "in #{Map.get(edu, "field")}", else: "" %>
          </h4>
          <p class="text-purple-700 font-semibold mb-2">
            <%= Map.get(edu, "institution", "") %>
          </p>
          <p class="text-purple-600 text-sm mb-3">
            <%= Map.get(edu, "start_date", "") %> - <%= Map.get(edu, "end_date", "") %>
          </p>
          <%= if Map.get(edu, "description") do %>
            <p class="text-purple-800 text-sm">
              <%= Map.get(edu, "description") %>
            </p>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_content(assigns) do
    content = assigns.section.content || %{}

    ~H"""
    <div class="space-y-4">
      <%= if Map.get(content, "email") do %>
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-blue-100 rounded-full flex items-center justify-center">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-500">Email</p>
            <a href={"mailto:#{Map.get(content, "email")}"}
               class="text-blue-600 hover:text-blue-700 font-semibold">
              <%= Map.get(content, "email") %>
            </a>
          </div>
        </div>
      <% end %>

      <%= if Map.get(content, "phone") do %>
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-green-100 rounded-full flex items-center justify-center">
            <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-500">Phone</p>
            <a href={"tel:#{Map.get(content, "phone")}"}
               class="text-green-600 hover:text-green-700 font-semibold">
              <%= Map.get(content, "phone") %>
            </a>
          </div>
        </div>
      <% end %>

      <%= if Map.get(content, "location") do %>
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
            <svg class="w-5 h-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
            </svg>
          </div>
          <div>
            <p class="text-sm font-medium text-gray-500">Location</p>
            <p class="text-purple-600 font-semibold">
              <%= Map.get(content, "location") %>
            </p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_generic_content(assigns) do
    content = assigns.section.content || %{}

    ~H"""
    <div class="space-y-4">
      <%= if Map.get(content, "content") do %>
        <div class="prose max-w-none">
          <%= Phoenix.HTML.raw(format_text_content(Map.get(content, "content"))) %>
        </div>
      <% else %>
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
          </div>
          <p class="text-gray-500">Section content will be displayed here</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp has_media?(section) do
    case Map.get(section, :portfolio_media) do
      %Ecto.Association.NotLoaded{} ->
        # Association not loaded, check if we have media_files instead
        case Map.get(section, :media_files, []) do
          [] -> false
          media_files when is_list(media_files) -> length(media_files) > 0
          _ -> false
        end
      media when is_list(media) ->
        length(media) > 0
      _ ->
        false
    end
  end

  defp get_section_media_files(section) do
    Map.get(section, :portfolio_media, []) ||
    Map.get(section, :media_files, []) ||
    []
  end

  defp format_text_content(text) do
    text
    |> String.replace("\n", "<br>")
    |> String.replace("\r\n", "<br>")
  end

  defp get_file_type_label(mime_type) do
    case mime_type do
      "application/pdf" -> "PDF Document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "Word Document"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "PowerPoint Presentation"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "Excel Spreadsheet"
      "text/plain" -> "Text File"
      _ -> "Document"
    end
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  # CSS class helpers based on template theme
  defp get_section_container_class(template_theme, section_type) do
    base_classes = "bg-white rounded-2xl shadow-lg hover:shadow-xl transition-all duration-300 overflow-hidden"

    case template_theme do
      :executive -> "#{base_classes} border border-gray-200"
      :developer -> "#{base_classes} border border-gray-100 hover:border-indigo-200"
      :designer -> "#{base_classes} border-none shadow-2xl"
      :consultant -> "#{base_classes} border-l-4 border-l-blue-500"
      :academic -> "#{base_classes} border border-gray-300"
      _ -> base_classes
    end
  end

  defp get_section_size_class(template_theme, section_type) do
    case {template_theme, section_type} do
      {:developer, :featured_project} -> "md:col-span-2"
      {:designer, _} -> "break-inside-avoid mb-8"
      {:consultant, :case_study} -> "col-span-full"
      {:academic, :intro} -> "col-span-full"
      _ -> ""
    end
  end

  defp get_section_header_class(template_theme, _section_type) do
    case template_theme do
      :executive -> "p-6 border-b border-gray-200"
      :developer -> "p-6 bg-gradient-to-r from-indigo-50 to-purple-50"
      :designer -> "p-8 bg-gradient-to-r from-pink-500 to-rose-500 text-white"
      :consultant -> "p-6 bg-blue-50"
      :academic -> "p-6 bg-emerald-50"
      _ -> "p-6"
    end
  end

  defp get_section_content_class(template_theme) do
    case template_theme do
      :executive -> "p-6"
      :developer -> "p-6"
      :designer -> "p-8"
      :consultant -> "p-6"
      :academic -> "p-6"
      _ -> "p-6"
    end
  end

  defp get_media_gallery_class(template_theme, section_type) do
    case {template_theme, section_type} do
      {:designer, _} -> "grid grid-cols-1 gap-4"
      {:developer, :featured_project} -> "grid grid-cols-2 gap-4"
      _ -> "grid grid-cols-1 md:grid-cols-2 gap-4"
    end
  end

  defp get_media_item_class(template_theme, media_type, index) do
    base = "aspect-video"

    case {template_theme, media_type} do
      {:designer, :image} -> "#{base} rounded-xl overflow-hidden shadow-lg"
      {:developer, :video} -> "#{base} rounded-lg overflow-hidden"
      _ -> "#{base} rounded-lg overflow-hidden"
    end
  end

  # Icon rendering
  defp render_section_icon(section_type, template_theme) do
    icon_color = case template_theme do
      :designer -> "text-white"
      _ -> get_section_icon_color(section_type)
    end

    case section_type do
      :intro ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """)

      :experience ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
        """)

      :skills ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """)

      :featured_project ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """)

      :education ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5"/>
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """)
    end
  end

  defp get_section_icon_color(section_type) do
    case section_type do
      :intro -> "text-blue-600"
      :experience -> "text-green-600"
      :education -> "text-purple-600"
      :skills -> "text-orange-600"
      :featured_project -> "text-pink-600"
      _ -> "text-gray-600"
    end
  end

  # More styling helpers...
  defp get_section_icon_bg_class(template_theme, section_type) do
    case template_theme do
      :designer -> "w-10 h-10 rounded-xl flex items-center justify-center"
      _ ->
        color = case section_type do
          :intro -> "bg-blue-100"
          :experience -> "bg-green-100"
          :education -> "bg-purple-100"
          :skills -> "bg-orange-100"
          :featured_project -> "bg-pink-100"
          _ -> "bg-gray-100"
        end
        "w-10 h-10 #{color} rounded-xl flex items-center justify-center"
    end
  end

  defp get_section_title_class(template_theme) do
    case template_theme do
      :designer -> "text-xl font-bold text-white"
      _ -> "text-xl font-bold text-gray-900"
    end
  end

  defp get_section_badge_class(template_theme, _section_type) do
    case template_theme do
      :designer -> "text-xs font-medium text-white/80 uppercase tracking-wide"
      _ -> "text-xs font-medium text-gray-500 uppercase tracking-wide"
    end
  end

  # Additional styling helpers for content
  defp get_content_headline_class(template_theme) do
    case template_theme do
      :executive -> "text-gray-900"
      :developer -> "text-indigo-900"
      :designer -> "text-gray-900"
      :consultant -> "text-blue-900"
      :academic -> "text-emerald-900"
      _ -> "text-gray-900"
    end
  end

  defp get_content_text_class(template_theme) do
    case template_theme do
      :executive -> "text-gray-700"
      :developer -> "text-gray-700"
      :designer -> "text-gray-700"
      :consultant -> "text-gray-700"
      :academic -> "text-gray-700"
      _ -> "text-gray-700"
    end
  end

  defp get_experience_item_class(template_theme, is_current) do
    base = if is_current, do: "bg-blue-50 border-l-blue-500", else: "bg-gray-50 border-l-gray-300"

    case template_theme do
      :developer -> "#{base} hover:bg-indigo-50"
      :designer -> "#{base} hover:bg-pink-50"
      :consultant -> "#{base} hover:bg-blue-50"
      :academic -> "#{base} hover:bg-emerald-50"
      _ -> base
    end
  end

  defp get_job_title_class(_template_theme), do: "text-gray-900"
  defp get_company_name_class(_template_theme), do: "text-blue-600"
  defp get_job_duration_class(_template_theme), do: "text-gray-500"

  # Section icon background classes
  defp get_section_icon_bg_class(template_theme, section_type) do
    case template_theme do
      :designer -> "w-10 h-10 rounded-xl flex items-center justify-center"
      _ ->
        color = case section_type do
          :intro -> "bg-blue-100"
          :experience -> "bg-green-100"
          :education -> "bg-purple-100"
          :skills -> "bg-orange-100"
          :featured_project -> "bg-pink-100"
          :case_study -> "bg-indigo-100"
          :media_showcase -> "bg-cyan-100"
          :contact -> "bg-gray-100"
          _ -> "bg-gray-100"
        end
        "w-10 h-10 #{color} rounded-xl flex items-center justify-center"
    end
  end

  defp get_section_title_class(template_theme) do
    case template_theme do
      :designer -> "text-xl font-bold text-white"
      _ -> "text-xl font-bold text-gray-900"
    end
  end

  defp get_section_badge_class(template_theme, _section_type) do
    case template_theme do
      :designer -> "text-xs font-medium text-white/80 uppercase tracking-wide"
      _ -> "text-xs font-medium text-gray-500 uppercase tracking-wide"
    end
  end

  # Section container and layout classes
  defp get_section_container_class(template_theme, section_type) do
    base_classes = "bg-white rounded-2xl shadow-lg hover:shadow-xl transition-all duration-300 overflow-hidden"

    case template_theme do
      :executive -> "#{base_classes} border border-gray-200"
      :developer -> "#{base_classes} border border-gray-100 hover:border-indigo-200"
      :designer -> "#{base_classes} border-none shadow-2xl"
      :consultant -> "#{base_classes} border-l-4 border-l-blue-500"
      :academic -> "#{base_classes} border border-gray-300"
      _ -> base_classes
    end
  end

  defp get_section_size_class(template_theme, section_type) do
    case {template_theme, section_type} do
      {:developer, :featured_project} -> "md:col-span-2"
      {:designer, _} -> "break-inside-avoid mb-8"
      {:consultant, :case_study} -> "col-span-full"
      {:academic, :intro} -> "col-span-full"
      _ -> ""
    end
  end

  defp get_section_header_class(template_theme, _section_type) do
    case template_theme do
      :executive -> "p-6 border-b border-gray-200"
      :developer -> "p-6 bg-gradient-to-r from-indigo-50 to-purple-50"
      :designer -> "p-8 bg-gradient-to-r from-pink-500 to-rose-500 text-white"
      :consultant -> "p-6 bg-blue-50"
      :academic -> "p-6 bg-emerald-50"
      _ -> "p-6"
    end
  end

  defp get_section_content_class(template_theme) do
    case template_theme do
      :executive -> "p-6"
      :developer -> "p-6"
      :designer -> "p-8"
      :consultant -> "p-6"
      :academic -> "p-6"
      _ -> "p-6"
    end
  end

  defp get_section_media_class(template_theme, section_type) do
    case template_theme do
      :designer -> "p-8 pt-0"
      _ -> "p-6 pt-0"
    end
  end

  # Media gallery classes
  defp get_media_gallery_class(template_theme, section_type) do
    case {template_theme, section_type} do
      {:designer, _} -> "grid grid-cols-1 gap-4"
      {:developer, :featured_project} -> "grid grid-cols-2 gap-4"
      _ -> "grid grid-cols-1 md:grid-cols-2 gap-4"
    end
  end

  defp get_media_item_class(template_theme, media_type, index) do
    base = "aspect-video"

    case {template_theme, media_type} do
      {:designer, :image} -> "#{base} rounded-xl overflow-hidden shadow-lg"
      {:developer, :video} -> "#{base} rounded-lg overflow-hidden"
      _ -> "#{base} rounded-lg overflow-hidden"
    end
  end

  # Icon color helpers
  defp get_section_icon_color(section_type) do
    case section_type do
      :intro -> "text-blue-600"
      :experience -> "text-green-600"
      :education -> "text-purple-600"
      :skills -> "text-orange-600"
      :featured_project -> "text-pink-600"
      :case_study -> "text-indigo-600"
      :media_showcase -> "text-cyan-600"
      :contact -> "text-gray-600"
      _ -> "text-gray-600"
    end
  end

  # File type helper
  defp get_file_type_label(mime_type) do
    case mime_type do
      "application/pdf" -> "PDF Document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "Word Document"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "PowerPoint Presentation"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "Excel Spreadsheet"
      "text/plain" -> "Text File"
      _ -> "Document"
    end
  end

  # Text formatting helper
  defp format_text_content(text) when is_binary(text) do
    text
    |> String.replace("\n", "<br>")
    |> String.replace("\r\n", "<br>")
  end
  defp format_text_content(_), do: ""

  # Section type formatting
  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end

  # Media helper functions
  defp has_media?(section) do
    media_files = get_section_media_files(section)
    length(media_files) > 0
  end

  defp get_section_media_files(section) do
    Map.get(section, :portfolio_media, []) ||
    Map.get(section, :media_files, []) ||
    []
  end

    # Styling helper functions for different template themes
  defp get_skill_tag_class(template_theme, index) do
    base_classes = "skill-tag px-4 py-2 rounded-xl text-sm font-semibold transition-all duration-300 hover:scale-105"

    color_class = case {template_theme, rem(index, 5)} do
      {:executive, 0} -> "bg-blue-100 text-blue-800"
      {:executive, 1} -> "bg-gray-100 text-gray-800"
      {:executive, 2} -> "bg-indigo-100 text-indigo-800"
      {:executive, 3} -> "bg-slate-100 text-slate-800"
      {:executive, 4} -> "bg-zinc-100 text-zinc-800"

      {:developer, 0} -> "bg-indigo-100 text-indigo-800"
      {:developer, 1} -> "bg-purple-100 text-purple-800"
      {:developer, 2} -> "bg-blue-100 text-blue-800"
      {:developer, 3} -> "bg-cyan-100 text-cyan-800"
      {:developer, 4} -> "bg-teal-100 text-teal-800"

      {:designer, 0} -> "bg-pink-100 text-pink-800"
      {:designer, 1} -> "bg-rose-100 text-rose-800"
      {:designer, 2} -> "bg-purple-100 text-purple-800"
      {:designer, 3} -> "bg-orange-100 text-orange-800"
      {:designer, 4} -> "bg-red-100 text-red-800"

      {:consultant, 0} -> "bg-blue-100 text-blue-800"
      {:consultant, 1} -> "bg-cyan-100 text-cyan-800"
      {:consultant, 2} -> "bg-teal-100 text-teal-800"
      {:consultant, 3} -> "bg-green-100 text-green-800"
      {:consultant, 4} -> "bg-emerald-100 text-emerald-800"

      {:academic, 0} -> "bg-emerald-100 text-emerald-800"
      {:academic, 1} -> "bg-teal-100 text-teal-800"
      {:academic, 2} -> "bg-green-100 text-green-800"
      {:academic, 3} -> "bg-blue-100 text-blue-800"
      {:academic, 4} -> "bg-indigo-100 text-indigo-800"

      _ -> "bg-gray-100 text-gray-800"
    end

    "#{base_classes} #{color_class}"
  end

  defp get_job_description_class(template_theme) do
    case template_theme do
      :executive -> "prose max-w-none text-gray-700"
      :developer -> "prose max-w-none text-gray-700 prose-code:text-indigo-600"
      :designer -> "prose max-w-none text-gray-700 prose-headings:text-pink-600"
      :consultant -> "prose max-w-none text-gray-700 prose-strong:text-blue-600"
      :academic -> "prose max-w-none text-gray-700 prose-em:text-emerald-600"
      _ -> "prose max-w-none text-gray-700"
    end
  end

  defp get_project_detail_class(template_theme, detail_type) do
    base_classes = "project-detail p-4 rounded-lg border-l-4"

    case {template_theme, detail_type} do
      {:executive, "challenge"} -> "#{base_classes} border-l-red-500 bg-red-50"
      {:executive, "solution"} -> "#{base_classes} border-l-green-500 bg-green-50"

      {:developer, "challenge"} -> "#{base_classes} border-l-orange-500 bg-orange-50"
      {:developer, "solution"} -> "#{base_classes} border-l-blue-500 bg-blue-50"

      {:designer, "challenge"} -> "#{base_classes} border-l-pink-500 bg-pink-50"
      {:designer, "solution"} -> "#{base_classes} border-l-purple-500 bg-purple-50"

      {:consultant, "challenge"} -> "#{base_classes} border-l-red-500 bg-red-50"
      {:consultant, "solution"} -> "#{base_classes} border-l-cyan-500 bg-cyan-50"

      {:academic, "challenge"} -> "#{base_classes} border-l-amber-500 bg-amber-50"
      {:academic, "solution"} -> "#{base_classes} border-l-emerald-500 bg-emerald-50"

      _ -> "#{base_classes} border-l-gray-500 bg-gray-50"
    end
  end

  defp get_project_link_class(template_theme, link_type) do
    case {template_theme, link_type} do
      {:executive, "demo"} -> "bg-blue-600 text-white border-blue-600 hover:bg-blue-700"
      {:executive, "github"} -> "bg-white text-blue-600 border-blue-600 hover:bg-blue-50"

      {:developer, "demo"} -> "bg-indigo-600 text-white border-indigo-600 hover:bg-indigo-700"
      {:developer, "github"} -> "bg-white text-indigo-600 border-indigo-600 hover:bg-indigo-50"

      {:designer, "demo"} -> "bg-pink-600 text-white border-pink-600 hover:bg-pink-700"
      {:designer, "github"} -> "bg-white text-pink-600 border-pink-600 hover:bg-pink-50"

      {:consultant, "demo"} -> "bg-cyan-600 text-white border-cyan-600 hover:bg-cyan-700"
      {:consultant, "github"} -> "bg-white text-cyan-600 border-cyan-600 hover:bg-cyan-50"

      {:academic, "demo"} -> "bg-emerald-600 text-white border-emerald-600 hover:bg-emerald-700"
      {:academic, "github"} -> "bg-white text-emerald-600 border-emerald-600 hover:bg-emerald-50"

      _ -> "bg-gray-600 text-white border-gray-600 hover:bg-gray-700"
    end
  end

  # Additional helper functions that were referenced in the component
  defp get_content_headline_class(template_theme) do
    case template_theme do
      :executive -> "text-gray-900"
      :developer -> "text-indigo-900"
      :designer -> "text-pink-900"
      :consultant -> "text-blue-900"
      :academic -> "text-emerald-900"
      _ -> "text-gray-900"
    end
  end

  defp get_content_text_class(template_theme) do
    case template_theme do
      :executive -> "text-gray-700"
      :developer -> "text-gray-700"
      :designer -> "text-gray-700"
      :consultant -> "text-gray-700"
      :academic -> "text-gray-700"
      _ -> "text-gray-700"
    end
  end

  defp get_experience_item_class(template_theme, is_current) do
    base = if is_current, do: "bg-blue-50 border-l-blue-500", else: "bg-gray-50 border-l-gray-300"

    case template_theme do
      :developer -> "#{base} hover:bg-indigo-50"
      :designer -> "#{base} hover:bg-pink-50"
      :consultant -> "#{base} hover:bg-cyan-50"
      :academic -> "#{base} hover:bg-emerald-50"
      _ -> base
    end
  end

  defp get_job_title_class(_template_theme), do: "text-gray-900"
  defp get_company_name_class(_template_theme), do: "text-blue-600"
  defp get_job_duration_class(_template_theme), do: "text-gray-500"

  # Media-related helper functions
  defp get_media_url(%{file_path: file_path}) when not is_nil(file_path) do
    file_path
  end
  defp get_media_url(%{filename: filename}) when not is_nil(filename) do
    "/uploads/#{filename}"
  end
  defp get_media_url(_), do: "/images/placeholder.jpg"

  defp get_video_thumbnail(%{id: id}) do
    "/uploads/thumbnails/video_#{id}.jpg"
  end
  defp get_video_thumbnail(%{file_path: file_path}) when not is_nil(file_path) do
    # Generate thumbnail path based on video file path
    base_name = Path.basename(file_path, Path.extname(file_path))
    "/uploads/thumbnails/#{base_name}.jpg"
  end
  defp get_video_thumbnail(_), do: "/images/video-thumbnail.jpg"

  defp get_file_type_label(mime_type) do
    case mime_type do
      "application/pdf" -> "PDF Document"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document" -> "Word Document"
      "application/vnd.openxmlformats-officedocument.presentationml.presentation" -> "PowerPoint Presentation"
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" -> "Excel Spreadsheet"
      "text/plain" -> "Text File"
      _ -> "Document"
    end
  end

  # Section media helper functions
  defp get_section_media_files(section) do
    Map.get(section, :portfolio_media, []) ||
    Map.get(section, :media_files, []) ||
    []
  end

  defp get_media_gallery_class(template_theme, section_type) do
    case {template_theme, section_type} do
      {:designer, _} -> "grid grid-cols-1 gap-4"
      {:developer, :featured_project} -> "grid grid-cols-2 gap-4"
      _ -> "grid grid-cols-1 md:grid-cols-2 gap-4"
    end
  end

  defp get_media_item_class(template_theme, media_type, index) do
    base = "aspect-video"

    case {template_theme, media_type} do
      {:designer, :image} -> "#{base} rounded-xl overflow-hidden shadow-lg"
      {:developer, :video} -> "#{base} rounded-lg overflow-hidden"
      _ -> "#{base} rounded-lg overflow-hidden"
    end
  end

  # Text formatting helper
  defp format_text_content(text) when is_binary(text) do
    text
    |> String.replace("\n", "<br>")
    |> String.replace("\r\n", "<br>")
  end
  defp format_text_content(_), do: ""

end
