defmodule FrestylWeb.PortfolioLive.Layouts.DeveloperLayoutComponent do
  @moduledoc """
  GitHub-inspired layout for developer portfolios with repository-style project showcase
  """
  use FrestylWeb, :live_component

  def update(assigns, socket) do
    sections = organize_sections_for_developer(assigns.sections)

    socket = socket
    |> assign(assigns)
    |> assign(:organized_sections, sections)
    |> assign(:layout_style, Map.get(assigns, :layout_style, "github"))

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="developer-portfolio bg-gray-50 min-h-screen">
      <!-- Terminal-style Hero Section -->
      <%= if @organized_sections[:hero] do %>
        <.render_terminal_hero hero_section={@organized_sections[:hero]} portfolio={@portfolio} />
      <% end %>

      <!-- Developer Stats Dashboard -->
      <section class="py-8 bg-white border-b">
        <div class="max-w-6xl mx-auto px-4">
          <.render_developer_stats sections={@sections} portfolio={@portfolio} />
        </div>
      </section>

      <!-- Repository-style Projects Grid -->
      <%= if @organized_sections[:projects] do %>
        <section class="py-12 bg-gray-50">
          <div class="max-w-6xl mx-auto px-4">
            <.render_repository_grid projects_section={@organized_sections[:projects]} />
          </div>
        </section>
      <% end %>

      <!-- Code Showcase Section -->
      <%= if @organized_sections[:code_showcase] do %>
        <section class="py-12 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_code_showcase code_section={@organized_sections[:code_showcase]} />
          </div>
        </section>
      <% end %>

      <!-- Tech Stack Visualization -->
      <%= if @organized_sections[:skills] do %>
        <section class="py-12 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_tech_stack skills_section={@organized_sections[:skills]} />
          </div>
        </section>
      <% end %>

      <!-- Commit Timeline (Experience) -->
      <%= if @organized_sections[:experience] do %>
        <section class="py-12 bg-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_commit_timeline experience_section={@organized_sections[:experience]} />
          </div>
        </section>
      <% end %>

      <!-- Developer Contact -->
      <%= if @organized_sections[:contact] do %>
        <section class="py-12 bg-gray-900 text-white">
          <div class="max-w-6xl mx-auto px-4">
            <.render_developer_contact contact_section={@organized_sections[:contact]} />
          </div>
        </section>
      <% end %>
    </div>
    """
  end

  # Terminal-style hero section
  defp render_terminal_hero(assigns) do
    content = assigns.hero_section.content || %{}

    ~H"""
    <section class="bg-gray-900 text-green-400 font-mono py-16">
      <div class="max-w-4xl mx-auto px-4">
        <div class="bg-gray-800 rounded-lg overflow-hidden shadow-2xl">
          <!-- Terminal header -->
          <div class="flex items-center justify-between bg-gray-700 px-4 py-2">
            <div class="flex items-center space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <div class="text-gray-300 text-sm">terminal</div>
          </div>

          <!-- Terminal content -->
          <div class="p-6 space-y-2">
            <div class="flex items-center space-x-2">
              <span class="text-blue-400">$</span>
              <span class="text-white">whoami</span>
            </div>
            <div class="pl-4 text-green-400">
              <%= Map.get(content, "headline", @portfolio.title) %>
            </div>

            <div class="flex items-center space-x-2 mt-4">
              <span class="text-blue-400">$</span>
              <span class="text-white">cat about.txt</span>
            </div>
            <div class="pl-4 text-gray-300 whitespace-pre-line">
              <%= Map.get(content, "description", "Full-stack developer passionate about creating innovative solutions") %>
            </div>

            <div class="flex items-center space-x-2 mt-4">
              <span class="text-blue-400">$</span>
              <span class="text-white">ls skills/</span>
            </div>
            <div class="pl-4 text-yellow-400">
              <%= get_quick_skills_list(@sections) %>
            </div>

            <div class="flex items-center space-x-2 mt-4">
              <span class="text-blue-400">$</span>
              <span class="text-green-400 animate-pulse">_</span>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  # Developer stats dashboard
  defp render_developer_stats(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-4 gap-6">
      <div class="text-center">
        <div class="text-3xl font-bold text-gray-900"><%= count_projects(@sections) %></div>
        <div class="text-gray-600">Public Repos</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-bold text-gray-900"><%= count_languages(@sections) %></div>
        <div class="text-gray-600">Languages</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-bold text-gray-900"><%= count_experience_years(@sections) %></div>
        <div class="text-gray-600">Years Experience</div>
      </div>
      <div class="text-center">
        <div class="text-3xl font-bold text-gray-900"><%= count_contributions(@sections) %></div>
        <div class="text-gray-600">Contributions</div>
      </div>
    </div>
    """
  end

  # Repository-style project grid
  defp render_repository_grid(assigns) do
    content = assigns.projects_section.content || %{}
    projects = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-8 flex items-center">
        <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        Repositories
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for project <- projects do %>
          <div class="border border-gray-200 rounded-lg p-6 hover:border-blue-500 transition-colors bg-white hover:shadow-md">
            <!-- Repo header -->
            <div class="flex items-start justify-between mb-3">
              <div class="flex items-center space-x-2">
                <svg class="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 16 16">
                  <path fill-rule="evenodd" d="M2 2.5A2.5 2.5 0 014.5 0h8.75a.75.75 0 01.75.75v12.5a.75.75 0 01-.75.75h-2.5a.75.75 0 110-1.5h1.75v-2h-8a1 1 0 00-.714 1.7.75.75 0 01-1.072 1.05A2.495 2.495 0 012 11.5v-9zm10.5-1V9h-8c-.356 0-.694.074-1 .208V2.5a1 1 0 011-1h8zM5 12.25v3.25a.25.25 0 00.4.2l1.45-1.087a.25.25 0 01.3 0L8.6 15.7a.25.25 0 00.4-.2v-3.25a.25.25 0 00-.25-.25h-3.5a.25.25 0 00-.25.25z"/>
                </svg>
                <h3 class="font-semibold text-blue-600 hover:underline cursor-pointer">
                  <%= Map.get(project, "title", "Project") %>
                </h3>
              </div>
              <%= if Map.get(project, "featured", false) do %>
                <span class="bg-yellow-100 text-yellow-800 text-xs px-2 py-1 rounded-full">Featured</span>
              <% end %>
            </div>

            <!-- Description -->
            <p class="text-gray-600 text-sm mb-4 line-clamp-2">
              <%= Map.get(project, "description", "") %>
            </p>

            <!-- Tech stack -->
            <div class="flex flex-wrap gap-2 mb-4">
              <%= for tech <- Enum.take(Map.get(project, "technologies", []), 3) do %>
                <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
                  <%= tech %>
                </span>
              <% end %>
            </div>

            <!-- Stats -->
            <div class="flex items-center justify-between text-sm text-gray-500">
              <div class="flex items-center space-x-4">
                <span class="flex items-center space-x-1">
                  <div class="w-3 h-3 bg-blue-500 rounded-full"></div>
                  <span><%= get_primary_language(project) %></span>
                </span>
                <%= if Map.get(project, "demo_url", "") != "" do %>
                  <a href={Map.get(project, "demo_url")} target="_blank" class="flex items-center space-x-1 text-blue-600 hover:underline">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                    <span>Live</span>
                  </a>
                <% end %>
              </div>
              <div class="flex items-center space-x-3">
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 16 16">
                    <path fill-rule="evenodd" d="M8 .25a.75.75 0 01.673.418l1.882 3.815 4.21.612a.75.75 0 01.416 1.279l-3.046 2.97.719 4.192a.75.75 0 01-1.088.791L8 12.347l-3.766 1.98a.75.75 0 01-1.088-.79l.72-4.194L.818 6.374a.75.75 0 01.416-1.28l4.21-.611L7.327.668A.75.75 0 018 .25zm0 2.445L6.615 5.5a.75.75 0 01-.564.41l-3.097.45 2.24 2.184a.75.75 0 01.216.664l-.528 3.084 2.769-1.456a.75.75 0 01.698 0l2.77 1.456-.53-3.084a.75.75 0 01.216-.664l2.24-2.183-3.096-.45a.75.75 0 01-.564-.41L8 2.694v.001z"/>
                  </svg>
                  <span><%= Map.get(project, "stars", "0") %></span>
                </span>
                <span class="flex items-center space-x-1">
                  <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 16 16">
                    <path fill-rule="evenodd" d="M5 3.25a.75.75 0 11-1.5 0 .75.75 0 011.5 0zm0 2.122a2.25 2.25 0 10-1.5 0v.878A2.25 2.25 0 005.75 8.5h1.5v2.128a2.251 2.251 0 101.5 0V8.5h1.5a2.25 2.25 0 002.25-2.25V5.372a2.25 2.25 0 10-1.5 0v.878A.75.75 0 0110.25 7H8.5V4.372a2.25 2.25 0 10-1.5 0V7H5.25A.75.75 0 015 6.25V5.372a2.25 2.25 0 111.5-.878V4.5z"/>
                  </svg>
                  <span><%= Map.get(project, "forks", "0") %></span>
                </span>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Code showcase section
  defp render_code_showcase(assigns) do
    content = assigns.code_section.content || %{}
    examples = Map.get(content, "code_examples", [])

    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-8 flex items-center">
        <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/>
        </svg>
        Code Examples
      </h2>

      <div class="space-y-8">
        <%= for {example, index} <- Enum.with_index(examples) do %>
          <div class="border border-gray-200 rounded-lg overflow-hidden bg-white">
            <!-- Code header -->
            <div class="bg-gray-50 px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h3 class="font-semibold text-gray-900">
                  <%= Map.get(example, "title", "Code Example #{index + 1}") %>
                </h3>
                <span class="bg-gray-200 text-gray-800 text-sm px-3 py-1 rounded-full">
                  <%= Map.get(example, "language", "javascript") %>
                </span>
              </div>
              <%= if Map.get(example, "explanation", "") != "" do %>
                <p class="text-gray-600 mt-2 text-sm">
                  <%= Map.get(example, "explanation", "") %>
                </p>
              <% end %>
            </div>

            <!-- Code block -->
            <div class="bg-gray-900 text-gray-100 p-6 overflow-x-auto">
              <pre class="text-sm font-mono"><code><%= Map.get(example, "code", "") %></code></pre>
            </div>

            <!-- Code footer with links -->
            <%= if Map.get(example, "demo_url", "") != "" or Map.get(example, "github_url", "") != "" do %>
              <div class="bg-gray-50 px-6 py-3 border-t border-gray-200">
                <div class="flex items-center space-x-4">
                  <%= if Map.get(example, "demo_url", "") != "" do %>
                    <a href={Map.get(example, "demo_url")} target="_blank" class="text-blue-600 hover:underline text-sm flex items-center space-x-1">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                      </svg>
                      <span>Live Demo</span>
                    </a>
                  <% end %>
                  <%= if Map.get(example, "github_url", "") != "" do %>
                    <a href={Map.get(example, "github_url")} target="_blank" class="text-gray-600 hover:underline text-sm flex items-center space-x-1">
                      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 16 16">
                        <path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
                      </svg>
                      <span>Source Code</span>
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Tech stack visualization
  defp render_tech_stack(assigns) do
    content = assigns.skills_section.content || %{}
    categories = Map.get(content, "skill_categories", [])

    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-white mb-8 flex items-center">
        <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        Tech Stack
      </h2>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for category <- categories do %>
          <div class="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <h3 class="text-lg font-semibold text-white mb-4 flex items-center">
              <div class="w-2 h-2 bg-green-400 rounded-full mr-3"></div>
              <%= Map.get(category, "name", "Skills") %>
            </h3>

            <div class="space-y-3">
              <%= for skill <- Map.get(category, "skills", []) do %>
                <div class="flex items-center justify-between">
                  <span class="text-gray-300">
                    <%= get_skill_name(skill) %>
                  </span>
                  <div class="flex items-center space-x-2">
                    <%= render_skill_dots(get_skill_proficiency(skill)) %>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Commit timeline for experience
  defp render_commit_timeline(assigns) do
    content = assigns.experience_section.content || %{}
    items = Map.get(content, "items", [])

    ~H"""
    <div>
      <h2 class="text-2xl font-bold text-gray-900 mb-8 flex items-center">
        <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        Professional Timeline
      </h2>

      <div class="relative">
        <!-- Timeline line -->
        <div class="absolute left-8 top-0 bottom-0 w-0.5 bg-gray-300"></div>

        <div class="space-y-8">
          <%= for {item, index} <- Enum.with_index(items) do %>
            <div class="relative flex items-start space-x-6">
              <!-- Commit dot -->
              <div class="relative z-10 flex items-center justify-center w-16 h-16 bg-green-500 rounded-full border-4 border-white shadow-lg">
                <span class="text-white font-mono font-bold text-sm">
                  <%= String.slice(Map.get(item, "company", "C"), 0, 1) %>
                </span>
              </div>

              <!-- Commit content -->
              <div class="flex-1 bg-white rounded-lg border border-gray-200 p-6 shadow-sm">
                <div class="flex items-start justify-between mb-3">
                  <div>
                    <h3 class="font-semibold text-gray-900">
                      <%= Map.get(item, "title", "Position") %>
                    </h3>
                    <p class="text-blue-600 font-medium">
                      <%= Map.get(item, "company", "Company") %>
                    </p>
                  </div>
                  <div class="text-right text-sm text-gray-500">
                    <div><%= Map.get(item, "start_date", "") %> - <%= Map.get(item, "end_date", "") %></div>
                    <div><%= Map.get(item, "location", "") %></div>
                  </div>
                </div>

                <p class="text-gray-600 mb-4">
                  <%= Map.get(item, "description", "") %>
                </p>

                <%= if length(Map.get(item, "achievements", [])) > 0 do %>
                  <div class="mb-4">
                    <h4 class="font-medium text-gray-900 mb-2">Key Achievements:</h4>
                    <ul class="space-y-1">
                      <%= for achievement <- Map.get(item, "achievements", []) do %>
                        <li class="text-sm text-gray-600 flex items-start space-x-2">
                          <span class="text-green-500 mt-1">✓</span>
                          <span><%= achievement %></span>
                        </li>
                      <% end %>
                    </ul>
                  </div>
                <% end %>

                <!-- Skills used -->
                <div class="flex flex-wrap gap-2">
                  <%= for skill <- Map.get(item, "skills_used", []) do %>
                    <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded">
                      <%= skill %>
                    </span>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

# Developer contact section
  defp render_developer_contact(assigns) do
    content = assigns.contact_section.content || %{}

    ~H"""
    <div class="text-center">
      <h2 class="text-2xl font-bold text-white mb-8">
        Let's Build Something Together
      </h2>

      <div class="max-w-2xl mx-auto">
        <p class="text-gray-300 mb-8">
          Interested in collaborating? I'm always open to discussing new opportunities and interesting projects.
        </p>

        <div class="flex flex-wrap justify-center gap-4">
          <%= if Map.get(content, "email", "") != "" do %>
            <a href={"mailto:#{Map.get(content, "email")}"} class="bg-blue-600 hover:bg-blue-700 text-white px-6 py-3 rounded-lg font-medium transition-colors flex items-center space-x-2">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
              <span>Get In Touch</span>
            </a>
          <% end %>

          <%= if Map.get(content, "github", "") != "" do %>
            <a href={Map.get(content, "github")} target="_blank" class="bg-gray-700 hover:bg-gray-600 text-white px-6 py-3 rounded-lg font-medium transition-colors flex items-center space-x-2">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 16 16">
                <path fill-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z"/>
              </svg>
              <span>GitHub</span>
            </a>
          <% end %>

          <%= if Map.get(content, "linkedin", "") != "" do %>
            <a href={Map.get(content, "linkedin")} target="_blank" class="bg-blue-700 hover:bg-blue-800 text-white px-6 py-3 rounded-lg font-medium transition-colors flex items-center space-x-2">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 16 16">
                <path d="M0 1.146C0 .513.526 0 1.175 0h13.65C15.474 0 16 .513 16 1.146v13.708c0 .633-.526 1.146-1.175 1.146H1.175C.526 16 0 15.487 0 14.854V1.146zm4.943 12.248V6.169H2.542v7.225h2.401zm-1.2-8.212c.837 0 1.358-.554 1.358-1.248-.015-.709-.52-1.248-1.342-1.248-.822 0-1.359.54-1.359 1.248 0 .694.521 1.248 1.327 1.248h.016zm4.908 8.212V9.359c0-.216.016-.432.08-.586.173-.431.568-.878 1.232-.878.869 0 1.216.662 1.216 1.634v3.865h2.401V9.25c0-2.22-1.184-3.252-2.764-3.252-1.274 0-1.845.7-2.165 1.193v.025h-.016a5.54 5.54 0 01.016-.025V6.169h-2.4c.03.678 0 7.225 0 7.225h2.4z"/>
              </svg>
              <span>LinkedIn</span>
            </a>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp organize_sections_for_developer(sections) do
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
      "code_showcase" -> :code_showcase
      "projects" -> :projects
      "skills" -> :skills
      "experience" -> :experience
      "contact" -> :contact
      _ -> String.to_atom(section_type)
    end
  end

  defp get_quick_skills_list(sections) do
    skills_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :skills
    end)

    case skills_section do
      nil -> "javascript  react  node.js  python  elixir"
      section ->
        content = section.content || %{}
        categories = Map.get(content, "skill_categories", [])

        categories
        |> Enum.flat_map(fn category ->
          Map.get(category, "skills", [])
        end)
        |> Enum.take(5)
        |> Enum.map(fn skill ->
          case skill do
            %{"name" => name} -> String.downcase(name)
            name when is_binary(name) -> String.downcase(name)
            _ -> "skill"
          end
        end)
        |> Enum.join("  ")
    end
  end

  defp count_projects(sections) do
    projects_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :projects
    end)

    case projects_section do
      nil -> "12"
      section ->
        content = section.content || %{}
        projects = Map.get(content, "items", [])
        to_string(length(projects))
    end
  end

  defp count_languages(sections) do
    skills_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :skills
    end)

    case skills_section do
      nil -> "8"
      section ->
        content = section.content || %{}
        categories = Map.get(content, "skill_categories", [])

        total_skills = categories
        |> Enum.flat_map(fn category ->
          Map.get(category, "skills", [])
        end)
        |> length()

        to_string(total_skills)
    end
  end

  defp count_experience_years(sections) do
    experience_section = Enum.find(sections, fn s ->
      normalize_section_type(s.section_type) == :experience
    end)

    case experience_section do
      nil -> "5+"
      section ->
        content = section.content || %{}
        items = Map.get(content, "items", [])

        # Simple calculation - count number of positions as rough years estimate
        years = length(items) * 2  # Assume average 2 years per position
        "#{years}+"
    end
  end

  defp count_contributions(sections) do
    # Mock GitHub-style contribution count
    "500+"
  end

  defp get_primary_language(project) do
    technologies = Map.get(project, "technologies", [])
    case technologies do
      [first | _] -> first
      [] -> "Code"
    end
  end

  defp get_skill_name(skill) when is_map(skill), do: Map.get(skill, "name", "")
  defp get_skill_name(skill) when is_binary(skill), do: skill
  defp get_skill_name(_), do: ""

  defp get_skill_proficiency(skill) when is_map(skill), do: Map.get(skill, "proficiency", "intermediate")
  defp get_skill_proficiency(_), do: "intermediate"

  defp render_skill_dots(proficiency) do
    dots_count = case proficiency do
      "expert" -> 4
      "advanced" -> 3
      "intermediate" -> 2
      "beginner" -> 1
      _ -> 2
    end

    assigns = %{dots_count: dots_count}

    ~H"""
    <%= for i <- 1..4 do %>
      <div class={[
        "w-2 h-2 rounded-full",
        if(i <= @dots_count, do: "bg-green-400", else: "bg-gray-600")
      ]}></div>
    <% end %>
    """
  end
end
