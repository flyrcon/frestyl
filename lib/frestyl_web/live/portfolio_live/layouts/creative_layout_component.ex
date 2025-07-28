# lib/frestyl_web/live/portfolio_live/layouts/creative_layout_component.ex
defmodule FrestylWeb.PortfolioLive.Layouts.CreativeLayoutComponent do
  @moduledoc """
  IMDB-inspired layout for creative professionals with project showcase and filmography-style presentation
  """
  use FrestylWeb, :live_component

  def update(assigns, socket) do
    sections = organize_sections_for_creative(assigns.sections)

    socket = socket
    |> assign(assigns)
    |> assign(:organized_sections, sections)
    |> assign(:layout_style, Map.get(assigns, :layout_style, "imdb"))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="creative-portfolio bg-gray-50 min-h-screen">
      <!-- IMDB-style Hero Header -->
      <%= if @organized_sections[:hero] do %>
        <.render_imdb_hero hero_section={@organized_sections[:hero]} portfolio={@portfolio} />
      <% end %>

      <!-- Creative Stats Bar -->
      <section class="py-6 bg-white border-b border-gray-200">
        <div class="max-w-6xl mx-auto px-4">
          <.render_creative_stats sections={@sections} portfolio={@portfolio} />
        </div>
      </section>

      <!-- Featured Project Spotlight -->
      <%= if @organized_sections[:projects] do %>
        <.render_featured_project_spotlight projects_section={@organized_sections[:projects]} />
      <% end %>

      <!-- Portfolio Gallery Grid -->
      <%= if @organized_sections[:media_showcase] do %>
        <section class="py-12 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_portfolio_gallery media_section={@organized_sections[:media_showcase]} />
          </div>
        </section>
      <% end %>

      <!-- Filmography/Projects Grid -->
      <%= if @organized_sections[:projects] do %>
        <section class="py-12 bg-gray-50">
          <div class="max-w-6xl mx-auto px-4">
            <.render_filmography_grid projects_section={@organized_sections[:projects]} />
          </div>
        </section>
      <% end %>

      <!-- Skills & Tools -->
      <%= if @organized_sections[:skills] do %>
        <section class="py-12 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_creative_skills skills_section={@organized_sections[:skills]} />
          </div>
        </section>
      <% end %>

      <!-- Awards & Recognition -->
      <%= if @organized_sections[:achievements] do %>
        <section class="py-12 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_awards_section achievements_section={@organized_sections[:achievements]} />
          </div>
        </section>
      <% end %>

      <!-- Testimonials/Reviews -->
      <%= if @organized_sections[:testimonials] do %>
        <section class="py-12 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_testimonials_section testimonials_section={@organized_sections[:testimonials]} />
          </div>
        </section>
      <% end %>

      <!-- Contact -->
      <%= if @organized_sections[:contact] do %>
        <section class="py-12 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_creative_contact contact_section={@organized_sections[:contact]} />
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # IMDB-style hero section
  defp render_imdb_hero(assigns) do
    content = assigns.hero_section.content || %{}

    ~H"""
    <section class="bg-gradient-to-r from-gray-900 via-gray-800 to-gray-900 text-white py-16">
      <div class="max-w-6xl mx-auto px-4">
        <div class="flex flex-col lg:flex-row items-center lg:items-start space-y-8 lg:space-y-0 lg:space-x-12">
          <!-- Profile Image -->
          <div class="flex-shrink-0">
            <div class="w-48 h-64 bg-gray-600 rounded-lg overflow-hidden shadow-2xl">
              <%= if Map.get(content, "profile_image") do %>
                <img src={Map.get(content, "profile_image")} alt="Profile" class="w-full h-full object-cover" />
              <% else %>
                <div class="w-full h-full flex items-center justify-center text-gray-400">
                  <svg class="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                  </svg>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Profile Info -->
          <div class="flex-1 text-center lg:text-left">
            <h1 class="text-5xl font-bold mb-4">
              <%= Map.get(content, "headline", @portfolio.title) %>
            </h1>

            <p class="text-2xl text-gray-300 mb-6">
              <%= Map.get(content, "tagline", "Creative Professional") %>
            </p>

            <!-- IMDb-style ratings and stats -->
            <div class="flex flex-wrap items-center justify-center lg:justify-start space-x-8 mb-6">
              <div class="flex items-center space-x-2">
                <span class="bg-yellow-500 text-black px-3 py-1 rounded font-bold text-sm">PORTFOLIO</span>
                <div class="flex items-center space-x-1">
                  <svg class="w-5 h-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                  <span class="text-xl font-bold">9.2</span>
                  <span class="text-gray-400">/10</span>
                </div>
              </div>

              <div class="text-gray-300">
                🎬 <%= count_projects(@sections) %> projects
              </div>

              <div class="text-gray-300">
                🏆 <%= count_awards(@sections) %> awards
              </div>
            </div>

            <p class="text-gray-300 text-lg leading-relaxed mb-8 max-w-3xl">
              <%= Map.get(content, "description", "Creative professional with a passion for visual storytelling and innovative design solutions.") %>
            </p>

            <!-- Action buttons -->
            <div class="flex flex-wrap gap-4 justify-center lg:justify-start">
              <button class="bg-yellow-500 hover:bg-yellow-600 text-black px-6 py-3 rounded-lg font-semibold transition-colors flex items-center space-x-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <span>View Portfolio</span>
              </button>

              <button class="border border-gray-400 hover:border-white text-white px-6 py-3 rounded-lg font-semibold transition-colors flex items-center space-x-2">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
                <span>Contact</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Creative stats bar
  defp render_creative_stats(assigns) do
    ~H"""
    <div class="grid grid-cols-2 md:grid-cols-4 gap-8 text-center">
      <div>
        <div class="text-3xl font-bold text-gray-900"><%= count_projects(@sections) %></div>
        <div class="text-gray-600">Projects</div>
      </div>
      <div>
        <div class="text-3xl font-bold text-gray-900"><%= count_clients(@sections) %></div>
        <div class="text-gray-600">Clients</div>
      </div>
      <div>
        <div class="text-3xl font-bold text-gray-900"><%= count_awards(@sections) %></div>
        <div class="text-gray-600">Awards</div>
      </div>
      <div>
        <div class="text-3xl font-bold text-gray-900"><%= count_experience_years(@sections) %></div>
        <div class="text-gray-600">Years</div>
      </div>
    </div>
    """
  end

  # Featured project spotlight
  defp render_featured_project_spotlight(assigns) do
    content = assigns.projects_section.content || %{}
    projects = Map.get(content, "items", [])
    featured_project = Enum.find(projects, &Map.get(&1, "featured", false)) || List.first(projects)

    ~H"""
    <%= if featured_project do %>
      <section class="py-16 bg-gradient-to-r from-purple-900 to-indigo-900 text-white">
        <div class="max-w-6xl mx-auto px-4">
          <div class="text-center mb-12">
            <h2 class="text-4xl font-bold mb-4">Featured Project</h2>
            <p class="text-xl text-purple-200">Latest creative work</p>
          </div>

          <div class="flex flex-col lg:flex-row items-center space-y-8 lg:space-y-0 lg:space-x-12">
            <!-- Project visual -->
            <div class="flex-1">
              <div class="aspect-video bg-gray-800 rounded-xl overflow-hidden shadow-2xl">
                <%= if Map.get(featured_project, "image_url") do %>
                  <img src={Map.get(featured_project, "image_url")} alt={Map.get(featured_project, "title")} class="w-full h-full object-cover" />
                <% else %>
                  <div class="w-full h-full flex items-center justify-center text-gray-400">
                    <svg class="w-24 h-24" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                    </svg>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Project details -->
            <div class="flex-1 text-center lg:text-left">
              <h3 class="text-3xl font-bold mb-4">
                <%= Map.get(featured_project, "title", "Featured Project") %>
              </h3>

              <p class="text-lg text-purple-200 mb-6">
                <%= Map.get(featured_project, "description", "") %>
              </p>

              <!-- Project meta -->
              <div class="space-y-3 mb-8">
                <%= if Map.get(featured_project, "role", "") != "" do %>
                  <div class="flex items-center justify-center lg:justify-start space-x-3">
                    <span class="text-purple-300">Role:</span>
                    <span><%= Map.get(featured_project, "role") %></span>
                  </div>
                <% end %>

                <%= if Map.get(featured_project, "client", "") != "" do %>
                  <div class="flex items-center justify-center lg:justify-start space-x-3">
                    <span class="text-purple-300">Client:</span>
                    <span><%= Map.get(featured_project, "client") %></span>
                  </div>
                <% end %>

                <%= if Map.get(featured_project, "year", "") != "" do %>
                  <div class="flex items-center justify-center lg:justify-start space-x-3">
                    <span class="text-purple-300">Year:</span>
                    <span><%= Map.get(featured_project, "year") %></span>
                  </div>
                <% end %>
              </div>

              <!-- Project actions -->
              <div class="flex flex-wrap gap-4 justify-center lg:justify-start">
                <%= if Map.get(featured_project, "demo_url", "") != "" do %>
                  <a href={Map.get(featured_project, "demo_url")} target="_blank" class="bg-white text-purple-900 px-6 py-3 rounded-lg font-semibold hover:bg-gray-100 transition-colors flex items-center space-x-2">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <span>View Project</span>
                  </a>
                <% end %>

                <%= if Map.get(featured_project, "case_study_url", "") != "" do %>
                  <a href={Map.get(featured_project, "case_study_url")} target="_blank" class="border border-white text-white px-6 py-3 rounded-lg font-semibold hover:bg-white hover:text-purple-900 transition-colors flex items-center space-x-2">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <span>Case Study</span>
                  </a>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </section>
    <% end %>
    """
  end

  # Portfolio gallery
  defp render_portfolio_gallery(assigns) do
    content = assigns.media_section.content || %{}

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-gray-900 mb-8 text-center">
        Portfolio Gallery
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= for i <- 1..6 do %>
          <div class="group relative overflow-hidden rounded-xl bg-gray-200 aspect-square hover:shadow-2xl transition-all duration-300">
            <!-- Placeholder for gallery items -->
            <div class="w-full h-full bg-gradient-to-br from-purple-400 to-pink-400 flex items-center justify-center">
              <div class="text-white text-center">
                <svg class="w-12 h-12 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
                <p class="text-sm">Gallery Item #{i}</p>
              </div>
            </div>

            <!-- Hover overlay -->
            <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-60 transition-all duration-300 flex items-center justify-center">
              <button class="opacity-0 group-hover:opacity-100 bg-white text-gray-900 px-4 py-2 rounded-full font-semibold transform scale-90 group-hover:scale-100 transition-all duration-300">
                View Details
              </button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Filmography-style project grid
  defp render_filmography_grid(assigns) do
    content = assigns.projects_section.content || %{}
    projects = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-gray-900 mb-8 text-center">
        Creative Works
      </h2>

      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        <%= for project <- projects do %>
          <div class="group cursor-pointer">
            <!-- Project poster -->
            <div class="relative overflow-hidden rounded-lg bg-gray-200 aspect-[3/4] mb-4 hover:shadow-xl transition-all duration-300">
              <%= if Map.get(project, "poster_image") do %>
                <img src={Map.get(project, "poster_image")} alt={Map.get(project, "title")} class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
              <% else %>
                <div class="w-full h-full bg-gradient-to-br from-gray-300 to-gray-400 flex items-center justify-center">
                  <svg class="w-12 h-12 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2h4a1 1 0 011 1v1a1 1 0 01-1 1h-1v12a2 2 0 01-2 2H6a2 2 0 01-2-2V7H3a1 1 0 01-1-1V5a1 1 0 011-1h4z"/>
                  </svg>
                </div>
              <% end %>

              <!-- Play button overlay -->
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-50 transition-all duration-300 flex items-center justify-center">
                <button class="opacity-0 group-hover:opacity-100 bg-white text-black p-3 rounded-full transform scale-75 group-hover:scale-100 transition-all duration-300">
                  ▶
                </button>
              </div>
            </div>

            <!-- Project info -->
            <div class="text-center">
              <h3 class="font-semibold text-gray-900 group-hover:text-blue-600 transition-colors">
                <%= Map.get(project, "title", "Project Title") %>
              </h3>
              <p class="text-sm text-gray-600 mt-1">
                <%= Map.get(project, "year", "2023") %> • <%= Map.get(project, "role", "Creative") %>
              </p>
              <%= if Map.get(project, "rating") do %>
                <div class="flex items-center justify-center mt-2 space-x-1">
                  <svg class="w-4 h-4 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                  </svg>
                  <span class="text-sm font-medium"><%= Map.get(project, "rating") %></span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Creative skills section
  defp render_creative_skills(assigns) do
    content = assigns.skills_section.content || %{}
    categories = Map.get(content, "skill_categories", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-gray-900 mb-8 text-center">
        Skills & Tools
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for category <- categories do %>
          <div class="bg-white rounded-xl p-6 shadow-lg border border-gray-100">
            <div class="flex items-center mb-4">
              <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-pink-500 rounded-lg flex items-center justify-center mr-4">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
                </svg>
              </div>
              <h3 class="text-lg font-semibold text-gray-900">
                <%= Map.get(category, "name", "Skills") %>
              </h3>
            </div>

            <div class="flex flex-wrap gap-2">
              <%= for skill <- Map.get(category, "skills", []) do %>
                <span class="bg-purple-100 text-purple-800 px-3 py-1 rounded-full text-sm font-medium">
                  <%= get_skill_name(skill) %>
                </span>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Awards section
  defp render_awards_section(assigns) do
    content = assigns.achievements_section.content || %{}
    awards = Map.get(content, "awards", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-white mb-8 text-center">
        Awards & Recognition
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for award <- awards do %>
          <div class="bg-gray-800 rounded-xl p-6 border border-gray-700">
            <div class="text-center">
              <div class="w-16 h-16 bg-yellow-500 rounded-full flex items-center justify-center mx-auto mb-4">
                <svg class="w-8 h-8 text-yellow-900" fill="currentColor" viewBox="0 0 20 20">
                  <path fill-rule="evenodd" d="M6.267 3.455a3.066 3.066 0 001.745-.723 3.066 3.066 0 013.976 0 3.066 3.066 0 001.745.723 3.066 3.066 0 012.812 2.812c.051.643.304 1.254.723 1.745a3.066 3.066 0 010 3.976 3.066 3.066 0 00-.723 1.745 3.066 3.066 0 01-2.812 2.812 3.066 3.066 0 00-1.745.723 3.066 3.066 0 01-3.976 0 3.066 3.066 0 00-1.745-.723 3.066 3.066 0 01-2.812-2.812 3.066 3.066 0 00-.723-1.745 3.066 3.066 0 010-3.976 3.066 3.066 0 00.723-1.745 3.066 3.066 0 012.812-2.812zm7.44 5.252a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
                </svg>
              </div>

              <h3 class="text-lg font-semibold text-white mb-2">
                <%= Map.get(award, "title", "Award Title") %>
              </h3>

              <p class="text-gray-300 mb-2">
                <%= Map.get(award, "organization", "Organization") %>
              </p>

              <p class="text-yellow-400 font-medium">
                <%= Map.get(award, "year", "2023") %>
              </p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Testimonials section
  defp render_testimonials_section(assigns) do
    content = assigns.testimonials_section.content || %{}
    testimonials = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-3xl font-bold text-gray-900 mb-8 text-center">
        Client Reviews
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
        <%= for testimonial <- testimonials do %>
          <div class="bg-white rounded-xl p-8 shadow-lg border border-gray-100">
            <!-- Rating -->
            <div class="flex items-center mb-4">
              <%= for _i <- 1..5 do %>
                <svg class="w-5 h-5 text-yellow-400" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M9.049 2.927c.3-.921 1.603-.921 1.902 0l1.07 3.292a1 1 0 00.95.69h3.462c.969 0 1.371 1.24.588 1.81l-2.8 2.034a1 1 0 00-.364 1.118l1.07 3.292c.3.921-.755 1.688-1.54 1.118l-2.8-2.034a1 1 0 00-1.175 0l-2.8 2.034c-.784.57-1.838-.197-1.539-1.118l1.07-3.292a1 1 0 00-.364-1.118L2.98 8.72c-.783-.57-.38-1.81.588-1.81h3.461a1 1 0 00.951-.69l1.07-3.292z"/>
                </svg>
              <% end %>
            </div>

            <!-- Testimonial text -->
            <blockquote class="text-gray-600 text-lg mb-6 italic">
              "<%= Map.get(testimonial, "content", "Great work and professional service.") %>"
            </blockquote>

            <!-- Client info -->
            <div class="flex items-center">
              <div class="w-12 h-12 bg-gray-300 rounded-full mr-4 flex items-center justify-center">
                <%= if Map.get(testimonial, "avatar_image") do %>
                  <img src={Map.get(testimonial, "avatar_image")} alt="Client" class="w-full h-full rounded-full object-cover" />
                <% else %>
                  <svg class="w-6 h-6 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                  </svg>
                <% end %>
              </div>
              <div>
                <div class="font-semibold text-gray-900">
                  <%= Map.get(testimonial, "name", "Client Name") %>
                </div>
                <div class="text-gray-600 text-sm">
                  <%= Map.get(testimonial, "title", "Title") %> at <%= Map.get(testimonial, "company", "Company") %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Creative contact section
  defp render_creative_contact(assigns) do
    content = assigns.contact_section.content || %{}

    ~H"""
    <div class="text-center">
      <h2 class="text-3xl font-bold text-white mb-8">
        Let's Create Something Amazing
      </h2>

      <div class="max-w-2xl mx-auto">
        <p class="text-gray-300 text-lg mb-8">
          Ready to bring your vision to life? I'm always excited to take on new creative challenges and collaborate with passionate people.
        </p>

        <div class="flex flex-wrap justify-center gap-4">
          <%= if Map.get(content, "email", "") != "" do %>
            <a href={"mailto:#{Map.get(content, "email")}"} class="bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white px-8 py-4 rounded-lg font-semibold transition-all transform hover:scale-105 flex items-center space-x-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              <span>Start a Project</span>
            </a>
          <% end %>

          <%= if Map.get(content, "portfolio_url", "") != "" do %>
            <a href={Map.get(content, "portfolio_url")} target="_blank" class="border-2 border-white text-white hover:bg-white hover:text-gray-900 px-8 py-4 rounded-lg font-semibold transition-all transform hover:scale-105 flex items-center space-x-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
              <span>View Full Portfolio</span>
            </a>
          <% end %>
        </div>

        <!-- Social links -->
        <div class="flex justify-center space-x-6 mt-8">
          <%= if Map.get(content, "instagram", "") != "" do %>
            <a href={Map.get(content, "instagram")} target="_blank" class="text-gray-400 hover:text-white transition-colors">
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 6.621 5.367 11.988 11.988 11.988s11.987-5.367 11.987-11.988C24.004 5.367 18.637.001 12.017.001zM8.449 16.988c-1.297 0-2.448-.49-3.324-1.297C4.198 14.895 3.708 13.744 3.708 12.447s.49-2.448 1.417-3.325c.876-.876 2.027-1.297 3.324-1.297s2.448.421 3.325 1.297c.876.877 1.296 2.028 1.296 3.325s-.42 2.448-1.296 3.325c-.877.807-2.028 1.297-3.325 1.297zm7.598 0c-1.297 0-2.448-.49-3.324-1.297-.876-.877-1.297-2.028-1.297-3.325s.421-2.448 1.297-3.325c.876-.876 2.027-1.297 3.324-1.297s2.448.421 3.325 1.297c.876.877 1.296 2.028 1.296 3.325s-.42 2.448-1.296 3.325c-.877.807-2.028 1.297-3.325 1.297z"/>
              </svg>
            </a>
          <% end %>

          <%= if Map.get(content, "dribbble", "") != "" do %>
            <a href={Map.get(content, "dribbble")} target="_blank" class="text-gray-400 hover:text-white transition-colors">
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 0C5.374 0 0 5.374 0 12s5.374 12 12 12 12-5.374 12-12S18.626 0 12 0zm7.568 5.302c1.4 1.5 2.252 3.5 2.293 5.698-.653-.653-4.73-.924-8.48-.924-.12 0-.12.12-.24.12C9.832 8.884 8.904 7.02 7.855 5.302c2.784-1.088 5.568-.408 7.568 1.088l2.145-1.088zm-2.145 1.088C15.278 4.302 12.494 3.622 9.71 4.71c1.049 1.718 1.977 3.582 3.286 4.894.12 0 .12-.12.24-.12 3.75 0 7.827.271 8.48.924-.041-2.198-.893-4.198-2.293-5.698z"/>
              </svg>
            </a>
          <% end %>

          <%= if Map.get(content, "behance", "") != "" do %>
            <a href={Map.get(content, "behance")} target="_blank" class="text-gray-400 hover:text-white transition-colors">
              <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
                <path d="M6.938 4.503c.702 0 1.34.06 1.92.188.577.13 1.07.33 1.485.61.41.28.733.65.96 1.12.225.47.34 1.05.34 1.73 0 .74-.17 1.36-.507 1.86-.34.5-.76.9-1.28 1.22.68.26 1.23.65 1.65 1.19.42.54.63 1.2.63 1.98 0 .75-.13 1.39-.4 1.93-.26.55-.63 1-1.11 1.35-.48.35-1.06.6-1.74.75-.68.15-1.45.23-2.29.23H0V4.51h6.938v-.007zM16.94 16.665c.44.428 1.073.643 1.894.643.59 0 1.1-.148 1.53-.447.424-.297.68-.663.773-1.1h2.588c-.403 1.28-1.048 2.2-1.9 2.75-.85.56-1.884.84-3.08.84-1.19 0-2.226-.15-3.1-.45-.87-.3-1.584-.74-2.14-1.32-.56-.58-.99-1.3-1.29-2.16-.297-.86-.447-1.82-.447-2.88 0-1.06.15-2.02.45-2.88.3-.86.73-1.58 1.29-2.16.56-.58 1.27-1.02 2.14-1.32.87-.3 1.91-.45 3.1-.45s2.226.15 3.1.45c.87.3 1.584.74 2.14 1.32.56.58.99 1.3 1.29 2.16.3.86.45 1.82.45 2.88 0 .34-.02.67-.06.99H14.14c.09.862.36 1.547.8 1.975zM3.24 7.325c.46 0 .84.027 1.14.08.3.054.543.14.73.26.188.12.32.27.4.45.08.18.12.39.12.63 0 .48-.17.85-.51 1.1-.34.26-.84.39-1.5.39H3.24V7.325zm10.85-.4c-.38-.33-.9-.495-1.57-.495-.45 0-.84.08-1.17.24-.33.16-.594.37-.79.63-.195.26-.33.55-.4.87-.07.32-.11.63-.13.93h4.69c-.06-.78-.27-1.39-.65-1.715zm-7.93 6.17c.54 0 .99-.06 1.35-.18.36-.12.65-.29.87-.51.22-.22.38-.48.48-.78.1-.3.15-.63.15-.99 0-.36-.05-.69-.15-.99-.1-.3-.26-.56-.48-.78-.22-.22-.51-.39-.87-.51-.36-.12-.81-.18-1.35-.18H3.24v4.91h2.92z"/>
              </svg>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp organize_sections_for_creative(sections) do
    sections
    |> Enum.reduce(%{}, fn section, acc ->
      section_type = normalize_section_type(section.section_type)
      Map.put(acc, section_type, section)
    end)
  end

  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "hero" -> :hero
      "media_showcase" -> :media_showcase
      "projects" -> :projects
      "skills" -> :skills
      "achievements" -> :achievements
      "testimonials" -> :testimonials
      "contact" -> :contact
      _ -> String.to_atom(section_type)
    end
  end

  defp count_projects(sections) do
    projects_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :projects
    end)

    case projects_section do
      nil -> "15"
      section ->
        content = section.content || %{}
        projects = Map.get(content, "items", [])
        to_string(length(projects))
    end
  end

  defp count_clients(sections) do
    # Extract from testimonials or projects
    testimonials_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :testimonials
    end)

    case testimonials_section do
      nil -> "25"
      section ->
        content = section.content || %{}
        testimonials = Map.get(content, "items", [])
        to_string(length(testimonials))
    end
  end

  defp count_awards(sections) do
    achievements_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :achievements
    end)

    case achievements_section do
      nil -> "8"
      section ->
        content = section.content || %{}
        awards = Map.get(content, "awards", [])
        to_string(length(awards))
    end
  end

  defp count_experience_years(_sections) do
    "7+"
  end

  defp get_skill_name(skill) when is_map(skill), do: Map.get(skill, "name", "")
  defp get_skill_name(skill) when is_binary(skill), do: skill
  defp get_skill_name(_), do: ""
end
