defmodule FrestylWeb.PortfolioLive.Edit.TabRenderer do
  @moduledoc """
  Phase 4: Enhanced UI rendering with integrated media management,
  drag-and-drop interfaces, and seamless section-media workflows.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  alias FrestylWeb.PortfolioLive.Edit.HelperFunctions
  alias FrestylWeb.PortfolioLive.VideoIntroComponent
  import Phoenix.LiveView, only: [assign: 2, assign: 3, put_flash: 3]

  # ============================================================================
  # MAIN LAYOUT RENDERER
  # ============================================================================


  # Helper function to safely get allow_media value
  defp section_allows_media?(section) do
    Map.get(section, :allow_media, true)
  end

  def render_main_layout(assigns) do
    theme_classes = HelperFunctions.get_theme_classes(assigns.customization, assigns.portfolio)
    assigns = assign(assigns, :theme_classes, theme_classes)

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Header -->
      <%= render_header(assigns) %>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if @show_preview do %>
          <%= render_preview_section(assigns) %>
        <% end %>

        <!-- Tab Content -->
        <div class="bg-white rounded-xl shadow-sm border border-gray-200">
          <%= case @active_tab do %>
            <% :overview -> %>
              <%= render_overview_tab(assigns) %>
            <% :sections -> %>
              <%= render_sections_tab(assigns) %>
            <% :design -> %>
              <%= render_design_tab(assigns) %>
            <% :settings -> %>
              <%= render_settings_tab(assigns) %>
          <% end %>
        </div>
      </main>

      <!-- Modals -->
      <%= render_modals(assigns) %>
    </div>
    """
  end

  # ============================================================================
  # HEADER RENDERER
  # ============================================================================

  defp render_header(assigns) do
    ~H"""
    <header class="bg-white shadow-sm border-b border-gray-200">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center py-4">
          <div class="flex items-center space-x-4">
            <.link navigate="/portfolios" class="text-gray-500 hover:text-gray-700 transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
              </svg>
            </.link>

            <div>
              <h1 class="text-2xl font-bold text-gray-900">Edit Portfolio</h1>
              <p class="text-sm text-gray-600 mt-1">
                <span class="font-medium"><%= @portfolio.title %></span>
                <%= if assigns[:unsaved_changes] do %>
                  <span class="ml-2 inline-flex items-center px-2 py-1 bg-yellow-100 text-yellow-800 text-xs font-medium rounded-full">
                    <div class="w-2 h-2 bg-yellow-400 rounded-full mr-1 animate-pulse"></div>
                    Unsaved changes
                  </span>
                <% end %>
              </p>
            </div>
          </div>

          <div class="flex items-center space-x-4">
            <!-- Preview Toggle -->
            <button phx-click="toggle_preview"
                    class={[
                      "inline-flex items-center px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium transition-all duration-200",
                      if(@show_preview,
                         do: "bg-blue-600 text-white border-blue-600 shadow-md",
                         else: "bg-white text-gray-700 hover:bg-gray-50 hover:border-gray-400")
                    ]}>
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
              </svg>
              <%= if @show_preview, do: "Hide Preview", else: "Show Preview" %>
            </button>

            <!-- View Live Portfolio -->
            <.link href={"/p/#{@portfolio.slug}"} target="_blank"
                   class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg text-sm font-medium hover:bg-green-700 transition-all duration-200 shadow-md hover:shadow-lg">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              View Live
            </.link>
          </div>
        </div>

        <!-- Enhanced Navigation Tabs -->
        <nav class="flex space-x-8 border-t border-gray-200 pt-4">
          <%= for {tab_key, tab_label, tab_icon, tab_description} <- [
            {:overview, "Overview", "M9 5H7a2 2 0 00-2 2v6a2 2 0 002 2h6a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2", "Basic portfolio information"},
            {:sections, "Sections", "M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10", "Content and media management"},
            {:design, "Design", "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01", "Templates and customization"},
            {:settings, "Settings", "M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4", "Privacy and advanced options"}
          ] do %>
            <button phx-click="change_tab" phx-value-tab={tab_key}
                    class={[
                      "group flex items-center space-x-2 py-2 px-1 border-b-2 font-medium text-sm transition-all duration-200",
                      if(@active_tab == tab_key,
                         do: "border-blue-500 text-blue-600",
                         else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                    ]}
                    title={tab_description}>
              <svg class="w-4 h-4 transition-transform group-hover:scale-110" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={tab_icon}/>
              </svg>
              <span><%= tab_label %></span>
              <%= if tab_key == :sections and assigns[:unsaved_changes] do %>
                <div class="w-2 h-2 bg-yellow-400 rounded-full animate-pulse"></div>
              <% end %>
              <%= if tab_key == :sections and length(@sections || []) > 0 do %>
                <span class="ml-1 px-2 py-0.5 text-xs bg-gray-100 text-gray-600 rounded-full">
                  <%= length(@sections) %>
                </span>
              <% end %>
            </button>
          <% end %>
        </nav>
      </div>
    </header>
    """
  end

  # ============================================================================
  # SECTION EDITOR WITH INTEGRATED MEDIA MANAGEMENT
  # ============================================================================

  defp render_section_editor(assigns) do
    section = Enum.find(assigns.sections, &(to_string(&1.id) == assigns.section_edit_id))
    assigns = assign(assigns, :editing_section, section)

    ~H"""
    <div class="space-y-6">
      <!-- Section Editor Header -->
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <div class="w-12 h-12 bg-blue-100 rounded-xl flex items-center justify-center">
            <span class="text-2xl"><%= HelperFunctions.get_section_emoji(@editing_section.section_type) %></span>
          </div>
          <div>
            <h2 class="text-2xl font-bold text-gray-900">Edit Section</h2>
            <p class="text-gray-600">
              <span class="font-medium"><%= @editing_section.title %></span> •
              <%= HelperFunctions.format_section_type(@editing_section.section_type) %>
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <button phx-click="save_section" phx-value-id={@editing_section.id}
                  class="bg-blue-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-blue-700 transition-all duration-200 flex items-center space-x-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            <span>Save Changes</span>
          </button>

          <button phx-click="cancel_edit"
                  class="bg-gray-200 text-gray-700 px-6 py-3 rounded-xl font-semibold hover:bg-gray-300 transition-all duration-200">
            Cancel
          </button>
        </div>
      </div>

      <!-- Section Editor Tabs -->
      <div class="border-b border-gray-200">
        <nav class="flex space-x-8" aria-label="Section editor tabs">
          <%= for {tab_key, tab_label, tab_icon} <- [
            {"content", "Content", "M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"},
            {"media", "Media", "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"},
            {"settings", "Settings", "M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"}
          ] do %>
            <button phx-click="switch_section_edit_tab" phx-value-tab={tab_key}
                    class={[
                      "py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 transition-colors",
                      if((assigns[:section_edit_tab] || "content") == tab_key,
                         do: "border-blue-500 text-blue-600",
                         else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                    ]}>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={tab_icon}/>
              </svg>
              <span><%= tab_label %></span>
              <%= if tab_key == "media" do %>
                <span class="bg-blue-100 text-blue-800 text-xs font-medium px-2 py-1 rounded-full">
                  <%= length(assigns[:editing_section_media] || []) %>
                </span>
              <% end %>
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Tab Content -->
      <div class="min-h-[600px]">
        <%= case assigns[:section_edit_tab] || "content" do %>
          <% "content" -> %>
            <%= render_section_content_editor(assigns) %>
          <% "media" -> %>
            <%= render_section_media_editor(assigns) %>
          <% "settings" -> %>
            <%= render_section_settings_editor(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SECTION CONTENT EDITOR
  # ============================================================================

  defp render_section_content_editor(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-8 space-y-8">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-3">Section Title</label>
        <input type="text"
               value={@editing_section.title}
               phx-blur="update_section_field"
               phx-value-field="title"
               phx-value-section-id={@editing_section.id}
               class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-semibold" />
      </div>

      <!-- Dynamic Content Fields Based on Section Type -->
      <%= render_section_type_fields(assigns) %>

      <!-- Section Description/Content -->
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-3">Content</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="main_content"
                  phx-value-section-id={@editing_section.id}
                  rows="8"
                  placeholder="Add content for this section..."
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= HelperFunctions.get_section_main_content(@editing_section) %></textarea>
      </div>

      <!-- Quick Actions -->
      <div class="flex items-center justify-between pt-6 border-t border-gray-200">
        <div class="flex items-center space-x-3">
          <button phx-click="apply_section_template"
                  phx-value-section-id={@editing_section.id}
                  phx-value-template="default"
                  class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
            Apply Template
          </button>

          <button phx-click="export_section_template"
                  phx-value-section-id={@editing_section.id}
                  class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
            Export as Template
          </button>
        </div>

        <div class="text-sm text-gray-500">
          Last updated: <%= HelperFunctions.format_relative_time(@editing_section.updated_at) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DYNAMIC SECTION TYPE FIELDS
  # ============================================================================

  defp render_section_type_fields(assigns) do
    ~H"""
    <%= case @editing_section.section_type do %>
      <% :featured_project -> %>
        <%= render_featured_project_fields(assigns) %>
      <% "featured_project" -> %>
        <%= render_featured_project_fields(assigns) %>
      <% :case_study -> %>
        <%= render_case_study_fields(assigns) %>
      <% "case_study" -> %>
        <%= render_case_study_fields(assigns) %>
      <% :experience -> %>
        <%= render_experience_fields(assigns) %>
      <% "experience" -> %>
        <%= render_experience_fields(assigns) %>
      <% :skills -> %>
        <%= render_skills_fields(assigns) %>
      <% "skills" -> %>
        <%= render_skills_fields(assigns) %>
      <% _ -> %>
        <!-- Default content editor for other section types -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <p class="text-blue-800 text-sm">
            <strong><%= String.capitalize(to_string(@editing_section.section_type)) %></strong> section -
            Use the content area below to add your information.
          </p>
        </div>
    <% end %>
    """
  end

  defp render_featured_project_fields(assigns) do
    # FIXED: Assign content to assigns instead of using it as a variable
    content = assigns.editing_section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Project URL</label>
        <input type="url"
              value={Map.get(@content, "url", "")}
              phx-blur="update_section_content"
              phx-value-field="url"
              phx-value-section-id={@editing_section.id}
              placeholder="https://example.com"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">GitHub URL</label>
        <input type="url"
              value={Map.get(@content, "github_url", "")}
              phx-blur="update_section_content"
              phx-value-field="github_url"
              phx-value-section-id={@editing_section.id}
              placeholder="https://github.com/username/repo"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>

    <div>
      <label class="block text-sm font-semibold text-gray-800 mb-2">Technologies Used</label>
      <input type="text"
            value={case Map.get(@content, "technologies") do
              list when is_list(list) -> Enum.join(list, ", ")
              string when is_binary(string) -> string
              _ -> ""
            end}
            phx-blur="update_section_content"
            phx-value-field="technologies_string"
            phx-value-section-id={@editing_section.id}
            placeholder="React, Node.js, PostgreSQL, AWS"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
      <p class="text-sm text-gray-600 mt-1">Separate technologies with commas</p>
    </div>
    """
  end

  defp render_case_study_fields(assigns) do
    # FIXED: Assign content to assigns instead of using it as a variable
    content = assigns.editing_section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Client/Company</label>
          <input type="text"
                value={Map.get(@content, "client", "")}
                phx-blur="update_section_content"
                phx-value-field="client"
                phx-value-section-id={@editing_section.id}
                placeholder="Company Name"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <div>
          <label class="block text-sm font-semibold text-gray-800 mb-2">Timeline</label>
          <input type="text"
                value={Map.get(@content, "timeline", "")}
                phx-blur="update_section_content"
                phx-value-field="timeline"
                phx-value-section-id={@editing_section.id}
                placeholder="3 months, Q2 2024"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Challenge</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="challenge"
                  phx-value-section-id={@editing_section.id}
                  rows="3"
                  placeholder="What problem needed to be solved?"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(@content, "challenge", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Solution</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="solution"
                  phx-value-section-id={@editing_section.id}
                  rows="3"
                  placeholder="How did you solve it?"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(@content, "solution", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-2">Results</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="results"
                  phx-value-section-id={@editing_section.id}
                  rows="3"
                  placeholder="What was the impact/outcome?"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(@content, "results", "") %></textarea>
      </div>
    </div>
    """
  end

  defp render_experience_fields(assigns) do
    ~H"""
    <div class="bg-amber-50 border border-amber-200 rounded-lg p-4">
      <div class="flex items-start">
        <svg class="w-5 h-5 text-amber-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        <div>
          <h4 class="font-medium text-amber-900 mb-1">Experience Section</h4>
          <p class="text-sm text-amber-800">
            Use the main content area to add your work experience. You can also import experience data from your resume using the Import Resume feature.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp render_skills_fields(assigns) do
    ~H"""
    <div class="bg-green-50 border border-green-200 rounded-lg p-4">
      <div class="flex items-start">
        <svg class="w-5 h-5 text-green-600 mt-0.5 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        <div>
          <h4 class="font-medium text-green-900 mb-1">Skills Section</h4>
          <p class="text-sm text-green-800">
            Add your technical skills, soft skills, and expertise areas. Consider grouping them by category (e.g., Programming Languages, Frameworks, Tools).
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_media_editor(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Media Editor Header -->
      <div class="flex items-center justify-between">
        <div>
          <h3 class="text-lg font-semibold text-gray-900">Section Media</h3>
          <p class="text-gray-600">Manage images, videos, and files for this section</p>
        </div>

        <div class="flex items-center space-x-3">
          <!-- Upload Button -->
          <%= if Map.has_key?(assigns, :uploads) && Map.has_key?(@uploads, :media) do %>
            <div class="relative">
              <.form for={%{}} phx-submit="upload_media" phx-change="validate_upload">
                <input type="hidden" name="section_id" value={@editing_section.id} />
                <.live_file_input upload={@uploads.media} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                <button type="button"
                        class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                  </svg>
                  <span>Upload Files</span>
                </button>
              </.form>
            </div>
          <% end %>

          <!-- Media Library Button -->
          <button phx-click="show_section_media_library"
                  phx-value-section-id={@editing_section.id}
                  class="bg-gray-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-gray-700 transition-colors flex items-center space-x-2">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
            <span>Media Library</span>
          </button>
        </div>
      </div>

      <!-- Upload Progress Area -->
      <%= if Map.has_key?(assigns, :uploads) && Map.has_key?(@uploads, :media) && @uploads.media.entries != [] do %>
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-6">
          <h4 class="font-medium text-blue-900 mb-4">Uploading Files</h4>
          <div class="space-y-3">
            <%= for entry <- @uploads.media.entries do %>
              <div class="flex items-center justify-between bg-white rounded-lg p-3">
                <div class="flex items-center space-x-3">
                  <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
                    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
                  <div>
                    <p class="font-medium text-gray-900"><%= entry.client_name %></p>
                    <p class="text-sm text-gray-500"><%= Float.round(entry.client_size / 1024 / 1024, 1) %> MB</p>
                  </div>
                </div>

                <div class="flex items-center space-x-3">
                  <!-- Progress Bar -->
                  <div class="w-32 bg-gray-200 rounded-full h-2">
                    <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}></div>
                  </div>
                  <span class="text-sm font-medium text-gray-700"><%= entry.progress %>%</span>

                  <!-- Cancel Button -->
                  <button phx-click="cancel_upload" phx-value-ref={entry.ref}
                          class="text-gray-400 hover:text-red-500 transition-colors">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                    </svg>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Media Layout Settings - FIXED VERSION -->
      <div class="bg-gray-50 rounded-xl p-6">
        <h4 class="font-medium text-gray-900 mb-4">Media Layout</h4>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <%= for {layout_key, layout_config} <- [
            {"grid", %{name: "Grid", icon: "M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"}},
            {"masonry", %{name: "Masonry", icon: "M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v6a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2z"}},
            {"carousel", %{name: "Carousel", icon: "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"}},
            {"hero", %{name: "Hero", icon: "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"}}
          ] do %>
            <button phx-click="update_section_media_layout"
                    phx-value-section-id={@editing_section.id}
                    phx-value-layout={layout_key}
                    class={[
                      "p-3 rounded-lg border-2 transition-all duration-200 flex flex-col items-center space-y-2",
                      if(get_section_media_layout(@editing_section) == layout_key,
                        do: "border-blue-500 bg-blue-50 text-blue-700",
                        else: "border-gray-200 bg-white text-gray-600 hover:border-gray-300")
                    ]}>
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={layout_config.icon}/>
              </svg>
              <span class="text-sm font-medium"><%= layout_config.name %></span>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Current Media Files -->
      <%= if length(assigns[:editing_section_media] || []) > 0 do %>
        <div class="bg-white rounded-xl border border-gray-200 p-6">
          <div class="flex items-center justify-between mb-6">
            <h4 class="font-medium text-gray-900">Current Media (<%= length(@editing_section_media) %>)</h4>

            <div class="flex items-center space-x-2">
              <!-- View Mode Toggle -->
              <div class="bg-gray-100 rounded-lg p-1 flex">
                <button class="px-3 py-1 text-sm font-medium bg-white text-gray-900 rounded shadow-sm">
                  Grid
                </button>
                <button class="px-3 py-1 text-sm font-medium text-gray-600 hover:text-gray-900">
                  List
                </button>
              </div>
            </div>
          </div>

          <!-- Drag and Drop Media Grid -->
          <div id={"section-media-#{@editing_section.id}"}
               phx-hook="SortableMedia"
               data-section-id={@editing_section.id}
               class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
            <%= for media <- Enum.sort_by(@editing_section_media, &(&1.position || 0)) do %>
              <div class="media-item group relative bg-gray-50 rounded-xl overflow-hidden border-2 border-transparent hover:border-blue-300 transition-all duration-200"
                   data-media-id={media.id}>

                <!-- Media Preview -->
                <div class="aspect-square relative">
                  <%= if media.media_type == "image" do %>
                    <img src={media.thumbnail_path || media.file_path}
                         alt={media.title}
                         class="w-full h-full object-cover" />
                  <% else %>
                    <div class="w-full h-full flex items-center justify-center bg-gray-100">
                      <div class="text-center">
                        <svg class="w-8 h-8 mx-auto text-gray-400 mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <%= case media.media_type do %>
                            <% "video" -> %>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                            <% "audio" -> %>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
                            <% _ -> %>
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                          <% end %>
                        </svg>
                        <p class="text-xs text-gray-500 uppercase font-medium"><%= media.media_type %></p>
                      </div>
                    </div>
                  <% end %>

                  <!-- Overlay Actions -->
                  <div class="absolute inset-0 bg-black bg-opacity-50 opacity-0 group-hover:opacity-100 transition-opacity duration-200 flex items-center justify-center">
                    <div class="flex items-center space-x-2">
                      <!-- Preview Button -->
                      <button phx-click="show_media_preview"
                              phx-value-media-id={media.id}
                              class="p-2 bg-white bg-opacity-20 backdrop-blur rounded-lg text-white hover:bg-opacity-30 transition-all">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                      </button>

                      <!-- Edit Button -->
                      <button phx-click="toggle_metadata_editing"
                              phx-value-media-id={media.id}
                              class="p-2 bg-white bg-opacity-20 backdrop-blur rounded-lg text-white hover:bg-opacity-30 transition-all">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                        </svg>
                      </button>

                      <!-- Delete Button -->
                      <button phx-click="delete_media"
                              phx-value-media-id={media.id}
                              data-confirm="Are you sure you want to delete this media file?"
                              class="p-2 bg-red-500 bg-opacity-20 backdrop-blur rounded-lg text-white hover:bg-opacity-30 transition-all">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                        </svg>
                      </button>
                    </div>
                  </div>

                  <!-- Drag Handle -->
                  <div class="absolute top-2 right-2 p-1 bg-white bg-opacity-80 rounded cursor-move opacity-0 group-hover:opacity-100 transition-opacity">
                    <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"/>
                    </svg>
                  </div>

                  <!-- Visibility Badge -->
                  <%= if not media.visible do %>
                    <div class="absolute top-2 left-2 px-2 py-1 bg-yellow-100 text-yellow-800 text-xs font-medium rounded">
                      Hidden
                    </div>
                  <% end %>
                </div>

                <!-- Media Info -->
                <div class="p-3">
                  <h5 class="font-medium text-gray-900 text-sm truncate"><%= media.title %></h5>
                  <p class="text-xs text-gray-500 mt-1">
                    <%= HelperFunctions.format_file_size(media.file_size) %> •
                    <%= String.upcase(media.media_type) %>
                  </p>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Bulk Actions -->
          <div class="mt-6 pt-6 border-t border-gray-200 flex items-center justify-between">
            <div class="text-sm text-gray-500">
              Drag to reorder • Click to edit
            </div>

            <button phx-click="detach_all_media"
                    phx-value-section-id={@editing_section.id}
                    data-confirm="Remove all media from this section?"
                    class="text-sm text-red-600 hover:text-red-700 font-medium">
              Remove All Media
            </button>
          </div>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="bg-gray-50 rounded-xl border-2 border-dashed border-gray-300 p-12 text-center">
          <div class="w-16 h-16 bg-gray-200 rounded-xl flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>
          </div>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No media files</h3>
          <p class="text-gray-600 mb-6">Upload images, videos, or documents to enhance this section</p>

          <div class="flex items-center justify-center space-x-4">
            <button phx-click="show_section_media_library"
                    phx-value-section-id={@editing_section.id}
                    class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors">
              Browse Media Library
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SECTION SETTINGS EDITOR
  # ============================================================================

  defp render_section_settings_editor(assigns) do
    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-8 space-y-8">
      <!-- Visibility Settings -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Visibility</h4>
        <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
          <div>
            <h5 class="font-medium text-gray-900">Section Visible</h5>
            <p class="text-sm text-gray-600">Show this section in your portfolio</p>
          </div>
          <label class="relative inline-flex items-center cursor-pointer">
            <input type="checkbox"
                   checked={@editing_section.visible}
                   phx-click="toggle_visibility"
                   phx-value-id={@editing_section.id}
                   class="sr-only peer" />
            <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
          </label>
        </div>
      </div>

      <!-- Advanced Settings -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Advanced</h4>
        <div class="space-y-4">
          <!-- Media Support - FIXED -->
          <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
            <div>
              <h5 class="font-medium text-gray-900">Allow Media</h5>
              <p class="text-sm text-gray-600">Enable media attachments for this section</p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input type="checkbox"
                     checked={section_allows_media?(@editing_section)}
                     phx-click="toggle_section_media_support"
                     phx-value-id={@editing_section.id}
                     class="sr-only peer" />
              <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
            </label>
          </div>

          <!-- Rest of the settings remain the same -->
        </div>
      </div>
    </div>
    """
  end

  defp render_sections_tab(assigns) do
    ~H"""
    <div class="p-8">
      <%= if assigns[:section_edit_id] do %>
        <%= render_section_editor(assigns) %>
      <% else %>
        <%= render_sections_list(assigns) %>
      <% end %>

      <!-- Media Modal Integration -->
      <%= if assigns[:show_media_modal] || assigns[:show_media_library] do %>
        <%= render_media_modal(assigns) %>
      <% end %>

      <!-- Media Preview Modal -->
      <%= if assigns[:media_preview_id] do %>
        <%= render_media_preview_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SECTIONS LIST RENDERER
  # ============================================================================

  defp render_sections_list(assigns) do
    ~H"""
    <div class="flex items-center justify-between mb-8">
      <div>
        <h2 class="text-2xl font-bold text-gray-900">Portfolio Sections</h2>
        <p class="text-gray-600 mt-1">Organize and manage your portfolio content</p>
      </div>

      <!-- FIXED: Add Section Dropdown with proper event handling -->
      <div class="relative" phx-click-away="close_add_section_dropdown">
        <button type="button"
                phx-click="toggle_add_section_dropdown"
                class="bg-blue-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-blue-700 transition-all duration-200 flex items-center space-x-2 shadow-md hover:shadow-lg">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          <span>Add Section</span>
          <svg class={[
            "w-4 h-4 transition-transform duration-200",
            if(assigns[:show_add_section_dropdown], do: "rotate-180", else: "rotate-0")
          ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>

        <!-- FIXED: Dropdown Menu with proper z-index and positioning -->
        <%= if assigns[:show_add_section_dropdown] do %>
          <div class="absolute right-0 mt-3 w-96 bg-white rounded-2xl shadow-2xl border border-gray-200 z-50 max-h-96 overflow-y-auto">
            <div class="p-6">
              <h3 class="font-bold text-gray-900 mb-4 text-lg">Choose Section Type</h3>
              <div class="grid grid-cols-2 gap-3">
                <%= for {section_type, config} <- [
                  {"intro", %{name: "Introduction", icon: "👋", desc: "Personal intro & contact"}},
                  {"experience", %{name: "Experience", icon: "💼", desc: "Work history & roles"}},
                  {"education", %{name: "Education", icon: "🎓", desc: "Schools & certifications"}},
                  {"skills", %{name: "Skills", icon: "⚡", desc: "Technical & soft skills"}},
                  {"featured_project", %{name: "Featured Project", icon: "🚀", desc: "Highlight key project"}},
                  {"case_study", %{name: "Case Study", icon: "📊", desc: "Detailed project analysis"}},
                  {"media_showcase", %{name: "Media Gallery", icon: "🖼️", desc: "Images & videos"}},
                  {"projects", %{name: "Projects", icon: "🛠️", desc: "Project portfolio"}},
                  {"achievements", %{name: "Achievements", icon: "🏆", desc: "Awards & recognition"}},
                  {"testimonial", %{name: "Testimonials", icon: "💬", desc: "Client feedback"}},
                  {"code_showcase", %{name: "Code Showcase", icon: "💻", desc: "Code samples"}},
                  {"contact", %{name: "Contact", icon: "📧", desc: "Contact information"}},
                  {"custom", %{name: "Custom", icon: "🎨", desc: "Flexible content"}}
                ] do %>
                  <button type="button"
                          phx-click="add_section"
                          phx-value-type={section_type}
                          class="text-left p-4 rounded-xl border-2 border-gray-200 hover:border-blue-300 hover:bg-blue-50 transition-all duration-200 group">
                    <div class="flex items-start space-x-3">
                      <span class="text-2xl flex-shrink-0"><%= config.icon %></span>
                      <div class="min-w-0 flex-1">
                        <h4 class="font-semibold text-gray-900 text-sm group-hover:text-blue-700 transition-colors"><%= config.name %></h4>
                        <p class="text-xs text-gray-500 mt-1 leading-tight"><%= config.desc %></p>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>

    <%= if length(@sections || []) > 0 do %>
      <!-- Enhanced Sections Grid with drag and drop -->
      <div id="sections-list"
           phx-hook="SortableSections"
           class="space-y-6">
        <%= for section <- Enum.sort_by(@sections, & &1.position) do %>
          <div data-section-id={section.id}
               class="section-item group bg-white rounded-2xl border-2 border-gray-200 hover:border-blue-300 transition-all duration-300 p-6 shadow-sm hover:shadow-md">

            <!-- Section Header -->
            <div class="flex items-start justify-between mb-4">
              <div class="flex items-start space-x-4 flex-1">
                <!-- FIXED: Drag Handle with better visibility -->
                <div class="section-drag-handle mt-1 p-2 text-gray-400 hover:text-gray-600 cursor-move opacity-0 group-hover:opacity-100 transition-all duration-200 hover:bg-gray-100 rounded-lg">
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"/>
                  </svg>
                </div>

                <!-- Section Icon & Info -->
                <div class="flex items-start space-x-4 flex-1">
                  <div class="w-14 h-14 bg-gradient-to-br from-blue-100 to-purple-100 rounded-xl flex items-center justify-center flex-shrink-0 group-hover:from-blue-200 group-hover:to-purple-200 transition-all duration-200">
                    <span class="text-2xl"><%= HelperFunctions.get_section_emoji(section.section_type) %></span>
                  </div>

                  <div class="flex-1 min-w-0">
                    <div class="flex items-center space-x-3 mb-2">
                      <h3 class="text-xl font-bold text-gray-900 truncate group-hover:text-blue-700 transition-colors"><%= section.title %></h3>

                      <!-- FIXED: Enhanced badges with better styling -->
                      <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-600 border border-gray-200">
                        <%= HelperFunctions.format_section_type(section.section_type) %>
                      </span>

                      <!-- Visibility Badge -->
                      <%= if not section.visible do %>
                        <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-yellow-100 text-yellow-800 border border-yellow-200">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                          </svg>
                          Hidden
                        </span>
                      <% end %>

                      <!-- Media Count Badge -->
                      <%= if section_allows_media?(section) do %>
                        <% media_count = get_safe_media_count(section.id) %>
                        <%= if media_count > 0 do %>
                          <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-purple-100 text-purple-800 border border-purple-200">
                            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                            </svg>
                            <%= media_count %> files
                          </span>
                        <% end %>
                      <% end %>
                    </div>

                    <p class="text-gray-600 line-clamp-2 mb-3">
                      <%= HelperFunctions.get_section_content_summary(section) %>
                    </p>

                    <!-- Enhanced Section Stats -->
                    <div class="flex items-center space-x-4 text-sm text-gray-500">
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16V4m0 0L3 8m4-4l4 4m6 0v12m0 0l4-4m-4 4l-4-4"/>
                        </svg>
                        Position <%= section.position %>
                      </span>
                      <span>•</span>
                      <span class="flex items-center">
                        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                        </svg>
                        <%= HelperFunctions.format_relative_time(section.updated_at) %>
                      </span>
                      <%= if section_allows_media?(section) do %>
                        <span>•</span>
                        <span class="flex items-center text-purple-600">
                          <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                          </svg>
                          Media enabled
                        </span>
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>

              <!-- FIXED: Section Actions with consistent styling -->
              <div class="flex items-center space-x-2">
                <!-- Quick Actions -->
                <div class="flex items-center space-x-1 opacity-0 group-hover:opacity-100 transition-opacity duration-200">
                  <!-- Visibility Toggle -->
                  <button type="button"
                          phx-click="toggle_section_visibility"
                          phx-value-id={section.id}
                          title={if section.visible, do: "Hide section", else: "Show section"}
                          class={[
                            "p-2 rounded-lg transition-all duration-200 hover:scale-110",
                            if(section.visible,
                               do: "text-green-600 hover:bg-green-50 hover:text-green-700",
                               else: "text-gray-400 hover:bg-gray-50 hover:text-gray-600")
                          ]}>
                    <%= if section.visible do %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                      </svg>
                    <% end %>
                  </button>

                  <!-- Media Library (if supported) -->
                  <%= if section_allows_media?(section) do %>
                    <button type="button"
                            phx-click="show_section_media_library"
                            phx-value-section-id={section.id}
                            title="Manage media"
                            class="p-2 text-purple-600 hover:bg-purple-50 hover:text-purple-700 rounded-lg transition-all duration-200 hover:scale-110">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                    </button>
                  <% end %>

                  <!-- Duplicate -->
                  <button type="button"
                          phx-click="duplicate_section"
                          phx-value-id={section.id}
                          title="Duplicate section"
                          class="p-2 text-gray-600 hover:bg-gray-50 hover:text-gray-700 rounded-lg transition-all duration-200 hover:scale-110">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                    </svg>
                  </button>
                </div>

                <!-- FIXED: Primary Actions with enhanced styling -->
                <div class="flex items-center space-x-3">
                  <button type="button"
                          phx-click="edit_section"
                          phx-value-id={section.id}
                          class="bg-blue-600 text-white px-5 py-2.5 rounded-xl font-semibold hover:bg-blue-700 transition-all duration-200 flex items-center space-x-2 shadow-md hover:shadow-lg transform hover:scale-105">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                    <span>Edit</span>
                  </button>

                  <button type="button"
                          phx-click="delete_section"
                          phx-value-id={section.id}
                          data-confirm="Are you sure you want to delete this section? This action cannot be undone."
                          class="p-2.5 text-red-600 hover:bg-red-50 hover:text-red-700 rounded-xl transition-all duration-200 hover:scale-110">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>

            <!-- Enhanced Media Preview -->
            <%= if section_allows_media?(section) do %>
              <% section_media = get_safe_media_preview(section.id, 4) %>
              <%= if length(section_media) > 0 do %>
                <div class="border-t border-gray-100 pt-4 mt-4">
                  <div class="flex items-center justify-between mb-3">
                    <h4 class="text-sm font-semibold text-gray-700 flex items-center">
                      <svg class="w-4 h-4 mr-1.5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                      </svg>
                      Media Files
                    </h4>
                    <button type="button"
                            phx-click="show_section_media_library"
                            phx-value-section-id={section.id}
                            class="text-sm text-blue-600 hover:text-blue-700 font-semibold hover:underline transition-colors">
                      View All (<%= get_safe_media_count(section.id) %>)
                    </button>
                  </div>

                  <div class="grid grid-cols-4 gap-2">
                    <%= for media <- section_media do %>
                      <div class="aspect-square bg-gray-100 rounded-lg overflow-hidden group/media hover:shadow-md transition-all duration-200">
                        <%= if media.media_type == "image" do %>
                          <img src={media.thumbnail_path || media.file_path}
                               alt={media.title}
                               class="w-full h-full object-cover group-hover/media:scale-105 transition-transform duration-200" />
                        <% else %>
                          <div class="w-full h-full flex items-center justify-center bg-gradient-to-br from-gray-100 to-gray-200">
                            <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <%= case media.media_type do %>
                                <% "video" -> %>
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                                <% "audio" -> %>
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
                                <% _ -> %>
                                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                              <% end %>
                            </svg>
                          </div>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                </div>
              <% end %>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- ENHANCED: Better section management tips -->
      <div class="mt-8 bg-gradient-to-r from-blue-50 to-purple-50 rounded-2xl p-6 border border-blue-200">
        <div class="flex items-start space-x-4">
          <div class="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center flex-shrink-0">
            <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
          </div>
          <div>
            <h4 class="font-semibold text-gray-900 mb-2">Section Management Tips</h4>
            <ul class="text-sm text-gray-700 space-y-1">
              <li>• Drag sections to reorder them</li>
              <li>• Use the eye icon to hide/show sections</li>
              <li>• Add media files to make sections more engaging</li>
              <li>• Duplicate sections to save time on similar content</li>
            </ul>
          </div>
        </div>
      </div>
    <% else %>
      <!-- ENHANCED: Empty state with better call-to-action -->
      <div class="text-center py-20">
        <div class="w-24 h-24 bg-gradient-to-br from-blue-100 to-purple-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
          <svg class="w-12 h-12 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
          </svg>
        </div>
        <h3 class="text-2xl font-bold text-gray-900 mb-3">Ready to Build Your Portfolio?</h3>
        <p class="text-gray-600 mb-8 max-w-md mx-auto">
          Start by adding your first section. Choose from professional templates like Experience, Skills, Projects, and more.
        </p>
        <button type="button"
                phx-click="toggle_add_section_dropdown"
                class="bg-blue-600 text-white px-8 py-4 rounded-xl font-semibold hover:bg-blue-700 transition-all duration-200 shadow-lg hover:shadow-xl transform hover:scale-105">
          Add Your First Section
        </button>
      </div>
    <% end %>
    """
  end

  # ============================================================================
  # OTHER TAB RENDERERS
  # ============================================================================

defp render_overview_tab(assigns) do
    ~H"""
    <div class="p-8">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Portfolio Overview</h2>

      <.form for={@form} phx-submit="update_portfolio" phx-change="validate_portfolio" class="space-y-6">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Basic Information -->
          <div class="space-y-6">
            <div>
              <.input field={@form[:title]} label="Portfolio Title"
                       placeholder="My Professional Portfolio"
                       class="text-lg font-semibold" />
            </div>

            <div>
              <.input field={@form[:slug]} label="Portfolio URL"
                      placeholder="my-portfolio-url" />
              <p class="mt-2 text-sm text-gray-600">
                Your portfolio will be available at:
                <code class="text-blue-600 bg-blue-50 px-2 py-1 rounded">frestyl.com/p/<span><%= @portfolio.slug %></span></code>
              </p>
            </div>

            <div>
              <.input field={@form[:description]} type="textarea" label="Description"
                       placeholder="Brief description of your portfolio..."
                       rows="4" />
            </div>

            <div class="flex items-center space-x-4">
              <button type="submit"
                      class="bg-blue-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-blue-700 transition-all duration-200 shadow-md hover:shadow-lg">
                Save Changes
              </button>

              <!-- Enhanced Duplicate Button with Limits -->
              <%= if @can_duplicate do %>
                <button type="button" phx-click="duplicate_portfolio"
                        class="bg-gray-600 text-white px-6 py-3 rounded-xl font-semibold hover:bg-gray-700 transition-all duration-200 shadow-md hover:shadow-lg">
                  Duplicate Portfolio
                </button>
              <% else %>
                <div class="relative group">
                  <button type="button"
                          disabled
                          class="bg-gray-300 text-gray-500 px-6 py-3 rounded-xl font-semibold cursor-not-allowed">
                    Duplicate Portfolio
                  </button>
                  <!-- Tooltip -->
                  <div class="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-10">
                    <%= @duplicate_disabled_reason %>
                    <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
                  </div>
                </div>
              <% end %>
            </div>
          </div>

          <!-- Enhanced Portfolio Stats with Limits -->
          <div class="space-y-6">
            <!-- Portfolio Limits Card -->
            <div class="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-2xl p-6 border border-blue-200">
              <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
                <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/>
                </svg>
                Portfolio Usage
              </h3>

              <div class="grid grid-cols-2 gap-4">
                <div class="text-center p-4 bg-white rounded-xl border border-blue-100">
                  <div class="text-2xl font-bold text-blue-600 mb-1">
                    <%= @current_portfolio_count %>/<%= if @limits.max_portfolios == -1, do: "∞", else: @limits.max_portfolios %>
                  </div>
                  <div class="text-sm text-gray-600">Portfolios</div>
                  <%= if @limits.max_portfolios != -1 do %>
                    <div class="mt-2 bg-gray-200 rounded-full h-2">
                      <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                           style={"width: #{min(100, (@current_portfolio_count / @limits.max_portfolios) * 100)}%"}></div>
                    </div>
                  <% end %>
                </div>

                <div class="text-center p-4 bg-white rounded-xl border border-blue-100">
                  <div class="text-lg font-bold text-green-600 mb-1">
                    <%= String.capitalize(String.replace(to_string(@current_user.subscription_tier || "free"), "_", " ")) %>
                  </div>
                  <div class="text-sm text-gray-600">Plan</div>
                  <%= unless @limits.max_portfolios == -1 do %>
                    <button class="mt-2 text-xs text-blue-600 hover:text-blue-700 font-medium">
                      Upgrade Plan
                    </button>
                  <% end %>
                </div>
              </div>
            </div>

            <!-- Portfolio Statistics -->
            <div class="bg-gradient-to-br from-gray-50 to-blue-50 rounded-2xl p-8 border border-gray-200">
              <h3 class="text-lg font-semibold text-gray-900 mb-6 flex items-center">
                <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v4"/>
                </svg>
                Portfolio Statistics
              </h3>

              <div class="grid grid-cols-2 gap-6">
                <div class="text-center p-4 bg-white rounded-xl border border-gray-100">
                  <div class="text-3xl font-bold text-blue-600 mb-1">
                    <%= HelperFunctions.get_portfolio_view_count(@portfolio) %>
                  </div>
                  <div class="text-sm text-gray-600">Total Views</div>
                </div>

                <div class="text-center p-4 bg-white rounded-xl border border-gray-100">
                  <div class="text-3xl font-bold text-green-600 mb-1">
                    <%= length(@sections || []) %>
                  </div>
                  <div class="text-sm text-gray-600">Sections</div>
                </div>

                <div class="text-center p-4 bg-white rounded-xl border border-gray-100">
                  <div class="text-3xl font-bold text-purple-600 mb-1">
                    <%= HelperFunctions.get_portfolio_media_count(@portfolio) %>
                  </div>
                  <div class="text-sm text-gray-600">Media Files</div>
                </div>

                <div class="text-center p-4 bg-white rounded-xl border border-gray-100">
                  <div class="text-lg font-bold text-orange-600 mb-1">
                    <%= HelperFunctions.format_date(@portfolio.updated_at) %>
                  </div>
                  <div class="text-sm text-gray-600">Last Updated</div>
                </div>
              </div>
            </div>

            <!-- Quick Actions -->
            <div class="bg-white rounded-lg border border-gray-200 p-4">
              <h3 class="text-base font-semibold text-gray-900 mb-3 flex items-center">
                <svg class="w-4 h-4 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
                </svg>
                Quick Actions
              </h3>

              <div class="grid grid-cols-2 gap-2">
                <!-- Import Resume -->
                <button phx-click="show_resume_import"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-emerald-700 bg-emerald-50 border border-emerald-200 rounded-md hover:bg-emerald-100 hover:border-emerald-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Import Resume
                </button>

                <!-- Record Video -->
                <button phx-click="show_video_intro"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-purple-700 bg-purple-50 border border-purple-200 rounded-md hover:bg-purple-100 hover:border-purple-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                  </svg>
                  Video Intro
                </button>

                <!-- View Live -->
                <.link href={"/p/#{@portfolio.slug}"} target="_blank"
                      class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-blue-700 bg-blue-50 border border-blue-200 rounded-md hover:bg-blue-100 hover:border-blue-300 transition-all duration-200">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                  </svg>
                  View Live
                </.link>

                <!-- Export PDF -->
                <button id="export-pdf-overview"
                        phx-click="export_portfolio"
                        class="group flex items-center justify-center px-3 py-2 text-xs font-medium text-gray-700 bg-gray-50 border border-gray-200 rounded-md hover:bg-gray-100 hover:border-gray-300 transition-all duration-200"
                        phx-hook="PdfDownload">
                  <svg class="w-4 h-4 mr-1.5 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                  </svg>
                  Export PDF
                </button>
              </div>
            </div>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  def render_design_tab(assigns) do
    ~H"""
    <div class="p-8 bg-gradient-to-br from-gray-50 to-blue-50 min-h-screen">
      <!-- Real-time CSS injection -->
      <%= if assigns[:preview_css] do %>
        <%= Phoenix.HTML.raw(assigns.preview_css) %>
      <% end %>

      <div class="flex items-center justify-between mb-8">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Design & Templates</h2>
          <p class="text-gray-600 mt-1">Customize your portfolio's appearance with real-time preview</p>
        </div>
      </div>

      <!-- Template Selection with WORKING previews -->
      <div class="mb-8">
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Choose Template</h3>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
          <%= for {template_key, template_config} <- Frestyl.Portfolios.PortfolioTemplates.available_templates() do %>
            <div class={[
              "relative group cursor-pointer rounded-xl overflow-hidden border-2 transition-all duration-200 template-preview-card",
              if((@portfolio.theme || "executive") == template_key,
                 do: "border-blue-500 shadow-lg ring-2 ring-blue-200",
                 else: "border-gray-200 hover:border-gray-300 hover:shadow-md")
            ]}
            phx-click="select_template"
            phx-value-template={template_key}>

              <!-- Template Preview -->
              <div class={[
                "h-32 bg-gradient-to-br relative overflow-hidden",
                template_config.preview_color
              ]}>
                <div class="p-4 text-white relative z-10">
                  <div class="w-16 h-2 bg-white/30 rounded mb-2"></div>
                  <div class="w-12 h-2 bg-white/20 rounded mb-3"></div>
                  <div class="grid grid-cols-2 gap-1">
                    <div class="h-6 bg-white/20 rounded"></div>
                    <div class="h-6 bg-white/20 rounded"></div>
                  </div>
                </div>

                <!-- Preview overlay with current colors if selected -->
                <%= if (@portfolio.theme || "executive") == template_key do %>
                  <div class="absolute inset-0 bg-gradient-to-br opacity-20"
                       style={"background: linear-gradient(135deg, #{Map.get(@customization, "primary_color", "#6366f1")}, #{Map.get(@customization, "secondary_color", "#8b5cf6")})"}>
                  </div>
                <% end %>
              </div>

              <!-- Template Info -->
              <div class="p-4 bg-white">
                <h4 class="font-semibold text-gray-900 mb-1 portfolio-primary"><%= template_config.name %></h4>
                <p class="text-sm text-gray-600 mb-3"><%= template_config.description %></p>

                <!-- Features with smaller icons -->
                <div class="space-y-1">
                  <%= for feature <- Enum.take(template_config.features, 2) do %>
                    <div class="text-xs text-gray-500 flex items-center">
                      <svg class="w-3 h-3 mr-1 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                      <%= feature %>
                    </div>
                  <% end %>
                </div>
              </div>

              <!-- Selected Indicator -->
              <%= if (@portfolio.theme || "executive") == template_key do %>
                <div class="absolute top-2 right-2 w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Customization Tabs -->
      <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <!-- Tab Navigation -->
        <div class="border-b border-gray-200">
          <nav class="flex space-x-8 px-6" aria-label="Customization tabs">
            <%= for {tab_key, tab_label, tab_icon} <- [
              {"colors", "Colors & Theme", "M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"},
              {"typography", "Typography", "M4 5a1 1 0 011-1h14a1 1 0 011 1v2a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM4 13a1 1 0 011-1h6a1 1 0 011 1v6a1 1 0 01-1 1H5a1 1 0 01-1-1v-6zM16 13a1 1 0 011-1h2a1 1 0 011 1v6a1 1 0 01-1 1h-2a1 1 0 01-1-1v-6z"},
              {"backgrounds", "Backgrounds", "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"}
            ] do %>
              <button phx-click="set_customization_tab" phx-value-tab={tab_key}
                      class={[
                        "py-4 px-1 border-b-2 font-medium text-sm flex items-center space-x-2 transition-colors",
                        if(@active_customization_tab == tab_key,
                           do: "border-blue-500 text-blue-600",
                           else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={tab_icon}/>
                </svg>
                <span><%= tab_label %></span>
              </button>
            <% end %>
          </nav>
        </div>

        <!-- Tab Content -->
        <div class="p-6">
          <%= case @active_customization_tab do %>
            <% "colors" -> %>
              <%= render_colors_customization_fixed(assigns) %>
            <% "typography" -> %>
              <%= render_typography_customization_fixed(assigns) %>
            <% "backgrounds" -> %>
              <%= render_backgrounds_customization_fixed(assigns) %>
            <% _ -> %>
              <%= render_colors_customization_fixed(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # FIXED COLORS CUSTOMIZATION WITH REAL-TIME PREVIEW
  # ============================================================================

  defp render_colors_customization_fixed(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Predefined Color Schemes with WORKING buttons -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Color Schemes</h3>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
          <%= for {scheme_name, colors} <- [
            {"professional", %{primary: "#1e40af", secondary: "#64748b", accent: "#3b82f6"}},
            {"creative", %{primary: "#7c3aed", secondary: "#ec4899", accent: "#f59e0b"}},
            {"warm", %{primary: "#dc2626", secondary: "#ea580c", accent: "#f59e0b"}},
            {"cool", %{primary: "#0891b2", secondary: "#0284c7", accent: "#6366f1"}},
            {"minimal", %{primary: "#374151", secondary: "#6b7280", accent: "#059669"}}
          ] do %>
            <button phx-click="update_color_scheme"
                    phx-value-scheme={scheme_name}
                    class="group p-3 bg-white border border-gray-200 rounded-lg hover:border-gray-300 transition-all hover:shadow-md">
              <div class="flex space-x-1 mb-2">
                <div class="w-6 h-6 rounded" style={"background-color: #{colors.primary}"}></div>
                <div class="w-6 h-6 rounded" style={"background-color: #{colors.secondary}"}></div>
                <div class="w-6 h-6 rounded" style={"background-color: #{colors.accent}"}></div>
              </div>
              <p class="text-sm font-medium text-gray-900 capitalize"><%= scheme_name %></p>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Individual Color Pickers with WORKING updates -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Custom Colors</h4>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
            <div class="flex items-center space-x-3">
              <input type="color"
                    value={Map.get(@customization, "primary_color", "#6366f1")}
                    phx-change="update_primary_color"
                    name="primary_color"
                    class="w-12 h-10 border border-gray-300 rounded cursor-pointer">
              <input type="text"
                    value={Map.get(@customization, "primary_color", "#6366f1")}
                    phx-change="update_primary_color"
                    name="primary_color"
                    placeholder="#6366f1"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md text-sm font-mono">
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Secondary Color</label>
            <div class="flex items-center space-x-3">
              <input type="color"
                    value={Map.get(@customization, "secondary_color", "#8b5cf6")}
                    phx-change="update_secondary_color"
                    name="secondary_color"
                    class="w-12 h-10 border border-gray-300 rounded cursor-pointer">
              <input type="text"
                    value={Map.get(@customization, "secondary_color", "#8b5cf6")}
                    phx-change="update_secondary_color"
                    name="secondary_color"
                    placeholder="#8b5cf6"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md text-sm font-mono">
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
            <div class="flex items-center space-x-3">
              <input type="color"
                    value={Map.get(@customization, "accent_color", "#f59e0b")}
                    phx-change="update_accent_color"
                    name="accent_color"
                    class="w-12 h-10 border border-gray-300 rounded cursor-pointer">
              <input type="text"
                    value={Map.get(@customization, "accent_color", "#f59e0b")}
                    phx-change="update_accent_color"
                    name="accent_color"
                    placeholder="#f59e0b"
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-md text-sm font-mono">
            </div>
          </div>
        </div>
      </div>

      <!-- Live Color Preview -->
      <div class="bg-gray-50 rounded-lg p-4">
        <h4 class="text-md font-semibold text-gray-900 mb-3">Live Preview</h4>
        <div class="bg-white rounded-lg p-4 border border-gray-200 portfolio-preview">
          <div class="space-y-3">
            <h1 class="text-2xl font-bold portfolio-primary">
              Portfolio Title
            </h1>
            <p class="text-base portfolio-secondary">
              This is how your portfolio text will look with the selected colors.
            </p>
            <button class="px-4 py-2 rounded-lg text-white font-medium portfolio-bg-accent">
              Call to Action
            </button>
            <div class="flex space-x-2 mt-4">
              <div class="w-8 h-8 rounded color-swatch-primary"></div>
              <div class="w-8 h-8 rounded color-swatch-secondary"></div>
              <div class="w-8 h-8 rounded color-swatch-accent"></div>
            </div>
          </div>
        </div>
      </div>
      <div class="mt-6 pt-6 border-t border-gray-200">
        <button phx-click="save_template_changes"
                class="w-full bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors">
          Save Color Changes
        </button>
      </div>
    </div>

    """
  end

  # ============================================================================
  # TYPOGRAPHY CUSTOMIZATION
  # ============================================================================

  defp render_typography_customization_fixed(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Typography</h3>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Font Family</label>
            <div class="space-y-2">
              <%= for {font_key, font_config} <- [
                {"Inter", %{preview: "Modern and clean", description: "Perfect for professional portfolios"}},
                {"Merriweather", %{preview: "Traditional and elegant", description: "Great for academic content"}},
                {"JetBrains Mono", %{preview: "Technical and precise", description: "Ideal for developers"}},
                {"Playfair Display", %{preview: "Creative and distinctive", description: "Best for creative portfolios"}}
              ] do %>
                <button phx-click="update_typography"
                        phx-value-font={font_key}
                        class={[
                          "w-full p-4 text-left border-2 rounded-lg transition-all",
                          get_font_class(font_key),
                          if(get_current_font(@customization) == font_key,
                             do: "border-blue-500 bg-blue-50",
                             else: "border-gray-200 hover:border-gray-300")
                        ]}>
                  <div class="font-semibold text-lg text-gray-900"><%= font_key %></div>
                  <div class="text-base text-gray-700 mt-1"><%= font_config.preview %></div>
                  <div class="text-sm text-gray-500 mt-1"><%= font_config.description %></div>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Typography Preview -->
          <div class="bg-gray-50 rounded-lg p-4">
            <h4 class="text-md font-semibold text-gray-900 mb-3">Typography Preview</h4>
            <div class="bg-white rounded-lg p-6 border border-gray-200 space-y-4 portfolio-preview">
              <h1 class={["text-3xl font-bold", get_font_class(get_current_font(@customization))]}>
                Heading Example
              </h1>
              <h2 class={["text-xl font-semibold", get_font_class(get_current_font(@customization))]}>
                Subheading Example
              </h2>
              <p class={["text-base", get_font_class(get_current_font(@customization))]}>
                This is an example of body text in your selected typography. It shows how paragraphs will appear with your chosen font family.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # BACKGROUNDS CUSTOMIZATION
  # ============================================================================

  defp render_backgrounds_customization_fixed(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Background Styles</h3>
        <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
          <%= for {bg_key, bg_config} <- [
            {"default", %{name: "Default", preview: "#ffffff"}},
            {"gradient-ocean", %{name: "Ocean Gradient", preview: "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"}},
            {"gradient-sunset", %{name: "Sunset Gradient", preview: "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)"}},
            {"gradient-forest", %{name: "Forest Gradient", preview: "linear-gradient(135deg, #4ecdc4 0%, #44a08d 100%)"}},
            {"dark-mode", %{name: "Dark Mode", preview: "#1a1a1a"}},
            {"terminal-dark", %{name: "Terminal Dark", preview: "#0f172a"}}
          ] do %>
            <button phx-click="update_background"
                    phx-value-background={bg_key}
                    class={[
                      "p-4 rounded-lg border-2 transition-all text-center group relative overflow-hidden",
                      if(get_current_background(@customization) == bg_key,
                         do: "border-blue-500 ring-2 ring-blue-200",
                         else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="w-full h-12 rounded mb-3 border border-gray-200"
                   style={"background: #{bg_config.preview}"}></div>
              <p class="text-sm font-medium text-gray-900"><%= bg_config.name %></p>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp section_allows_media?(section) do
    Map.get(section, :allow_media, true)
  end

  # Helper function to safely get media count
  defp get_safe_media_count(section_id) do
    try do
      HelperFunctions.get_section_media_count(section_id)
    rescue
      _ -> 0
    end
  end

  defp get_section_media_layout(section) do
    # Check multiple possible locations for media layout setting
    cond do
      # Check if section has media_layout field
      Map.has_key?(section, :media_layout) && section.media_layout != nil ->
        section.media_layout

      # Check if it's stored in content
      is_map(section.content) && Map.has_key?(section.content, "media_layout") ->
        section.content["media_layout"]

      # Default to grid layout
      true ->
        "grid"
    end
  end

  # Helper function to safely get media preview - SINGLE DEFINITION
  defp get_safe_media_preview(section_id, limit \\ 4)
  defp get_safe_media_preview(section_id, limit) do
    try do
      HelperFunctions.get_section_media_preview(section_id, limit)
    rescue
      _ -> []
    end
  end

  # Helper functions for typography
  defp get_font_family_class(customization) do
    case get_in(customization, ["font_family"]) do
      "inter" -> "font-sans"
      "merriweather" -> "font-serif"
      "jetbrains" -> "font-mono"
      "playfair" -> "font-serif"
      _ -> "font-sans"
    end
  end

    # Helper function to safely get allow_media value
  defp section_allows_media?(section) do
    Map.get(section, :allow_media, true)
  end


  defp get_typography_classes(customization, element) do
    base_size = get_in(customization, ["font_size"]) || "base"

    case element do
      "heading" ->
        weight = get_in(customization, ["heading_weight"]) || "semibold"
        "font-#{weight}"

      "subheading" ->
        weight = get_in(customization, ["heading_weight"]) || "semibold"
        "font-#{weight}"

      "body" ->
        weight = get_in(customization, ["body_weight"]) || "normal"
        line_height = get_in(customization, ["line_height"]) || "normal"
        "font-#{weight} leading-#{line_height}"

      "button" ->
        "font-medium"

      "link" ->
        "font-medium"

      _ ->
        "font-normal"
    end
  end

  defp render_layout_customization(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Section Spacing -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Layout & Spacing</h3>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Section Spacing</label>
            <div class="space-y-2">
              <%= for {spacing_key, spacing_config} <- [
                {"compact", %{name: "Compact", description: "Minimal spacing between sections", visual: "py-2"}},
                {"normal", %{name: "Normal", description: "Balanced spacing for readability", visual: "py-4"}},
                {"comfortable", %{name: "Comfortable", description: "Generous spacing for focus", visual: "py-6"}},
                {"spacious", %{name: "Spacious", description: "Maximum spacing for impact", visual: "py-8"}}
              ] do %>
                <button phx-click="update_spacing"
                        phx-value-spacing={spacing_key}
                        class={[
                          "w-full p-3 text-left border-2 rounded-lg transition-all flex items-center justify-between",
                          if(get_in(@customization, ["section_spacing"]) == spacing_key,
                             do: "border-blue-500 bg-blue-50",
                             else: "border-gray-200 hover:border-gray-300")
                        ]}>
                  <div>
                    <div class="font-medium text-gray-900"><%= spacing_config.name %></div>
                    <div class="text-sm text-gray-600"><%= spacing_config.description %></div>
                  </div>
                  <!-- Visual indicator -->
                  <div class="flex flex-col space-y-1">
                    <div class={["w-8 h-1 bg-gray-400 rounded", spacing_config.visual]}></div>
                    <div class={["w-8 h-1 bg-gray-400 rounded", spacing_config.visual]}></div>
                    <div class={["w-8 h-1 bg-gray-400 rounded", spacing_config.visual]}></div>
                  </div>
                </button>
              <% end %>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Card Style</label>
            <div class="space-y-2">
              <%= for {card_key, card_config} <- [
                {"minimal", %{name: "Minimal", description: "Clean borders, subtle shadows"}},
                {"elevated", %{name: "Elevated", description: "Prominent shadows and depth"}},
                {"bordered", %{name: "Bordered", description: "Strong borders, no shadows"}},
                {"flat", %{name: "Flat", description: "No borders or shadows"}}
              ] do %>
                <button phx-click="update_card_style"
                        phx-value-style={card_key}
                        class={[
                          "w-full p-3 text-left border-2 rounded-lg transition-all",
                          if(get_in(@customization, ["card_style"]) == card_key,
                             do: "border-blue-500 bg-blue-50",
                             else: "border-gray-200 hover:border-gray-300")
                        ]}>
                  <div class="font-medium text-gray-900"><%= card_config.name %></div>
                  <div class="text-sm text-gray-600"><%= card_config.description %></div>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Layout Options -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Layout Options</h4>
        <div class="space-y-3">
          <%= for {option_key, option_config} <- [
            {"fixed_navigation", %{name: "Fixed Navigation", description: "Keep navigation visible while scrolling"}},
            {"full_width", %{name: "Full Width Layout", description: "Use full browser width"}},
            {"center_content", %{name: "Center Content", description: "Center content with max width"}},
            {"dark_mode_support", %{name: "Dark Mode Support", description: "Enable dark/light mode toggle"}}
          ] do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <h5 class="font-medium text-gray-900"><%= option_config.name %></h5>
                <p class="text-sm text-gray-600"><%= option_config.description %></p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox"
                       checked={get_in(@customization, [option_key]) || false}
                       phx-click="toggle_layout_option"
                       phx-value-option={option_key}
                       class="sr-only peer" />
                <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
              </label>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Grid Layout Options -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Grid Layout</h4>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <%= for {grid_key, grid_config} <- [
            {"single", %{name: "Single Column", cols: 1}},
            {"two", %{name: "Two Columns", cols: 2}},
            {"three", %{name: "Three Columns", cols: 3}},
            {"masonry", %{name: "Masonry", cols: "auto"}}
          ] do %>
            <button phx-click="update_grid_layout"
                    phx-value-layout={grid_key}
                    class={[
                      "p-3 border-2 rounded-lg transition-all text-center",
                      if(get_in(@customization, ["grid_layout"]) == grid_key,
                         do: "border-blue-500 bg-blue-50",
                         else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <!-- Visual grid representation -->
              <div class="mb-2 h-8 flex items-center justify-center">
                <%= case grid_config.cols do %>
                  <% 1 -> %>
                    <div class="w-8 h-6 bg-gray-400 rounded"></div>
                  <% 2 -> %>
                    <div class="flex space-x-1">
                      <div class="w-3 h-6 bg-gray-400 rounded"></div>
                      <div class="w-3 h-6 bg-gray-400 rounded"></div>
                    </div>
                  <% 3 -> %>
                    <div class="flex space-x-1">
                      <div class="w-2 h-6 bg-gray-400 rounded"></div>
                      <div class="w-2 h-6 bg-gray-400 rounded"></div>
                      <div class="w-2 h-6 bg-gray-400 rounded"></div>
                    </div>
                  <% "auto" -> %>
                    <div class="flex space-x-1">
                      <div class="w-2 h-4 bg-gray-400 rounded"></div>
                      <div class="w-2 h-6 bg-gray-400 rounded"></div>
                      <div class="w-2 h-3 bg-gray-400 rounded"></div>
                    </div>
                <% end %>
              </div>
              <p class="text-sm font-medium text-gray-900"><%= grid_config.name %></p>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_advanced_customization(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Custom CSS -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Advanced Customization</h3>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Custom CSS</label>
          <p class="text-sm text-gray-600 mb-3">
            Add custom CSS to override default styles. Use with caution as this can affect portfolio functionality.
          </p>
          <textarea phx-change="update_custom_css"
                    phx-debounce="1000"
                    rows="10"
                    placeholder="/* Your custom CSS here */
                      .portfolio-section {
                        /* Custom styles */
                      }

                      .portfolio-header {
                        /* Header customization */
                      }

                      /* Use CSS variables for consistent theming */
                      :root {
                        --primary-color: #3b82f6;
                        --secondary-color: #6b7280;
                      }"
                    class="w-full px-3 py-2 border border-gray-300 rounded-md font-mono text-sm"><%= get_in(@customization, ["custom_css"]) || "" %></textarea>

          <div class="mt-2 flex items-center space-x-4">
            <button phx-click="validate_css"
                    class="px-3 py-1 text-sm bg-blue-100 text-blue-700 rounded hover:bg-blue-200 transition-colors">
              Validate CSS
            </button>
            <button phx-click="reset_custom_css"
                    class="px-3 py-1 text-sm bg-red-100 text-red-700 rounded hover:bg-red-200 transition-colors">
              Reset CSS
            </button>
            <div class="text-xs text-gray-500">
              Auto-saves after 1 second of inactivity
            </div>
          </div>
        </div>
      </div>

      <!-- Animation Settings -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Animation & Effects</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="space-y-3">
            <%= for {animation_key, animation_config} <- [
              {"fade_in", %{name: "Fade In Animations", description: "Smooth fade-in effects for sections"}},
              {"slide_up", %{name: "Slide Up Animations", description: "Content slides up when scrolling"}},
              {"hover_effects", %{name: "Hover Effects", description: "Interactive hover animations"}},
              {"smooth_scroll", %{name: "Smooth Scrolling", description: "Smooth page navigation"}}
            ] do %>
              <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                <div>
                  <h5 class="font-medium text-gray-900"><%= animation_config.name %></h5>
                  <p class="text-sm text-gray-600"><%= animation_config.description %></p>
                </div>
                <label class="relative inline-flex items-center cursor-pointer">
                  <input type="checkbox"
                         checked={get_in(@customization, ["animations", animation_key]) || false}
                         phx-click="toggle_animation"
                         phx-value-animation={animation_key}
                         class="sr-only peer" />
                  <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                </label>
              </div>
            <% end %>
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Animation Speed</label>
            <select phx-change="update_animation_speed"
                    value={get_in(@customization, ["animation_speed"]) || "normal"}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md mb-4">
              <option value="slow">Slow (0.8s)</option>
              <option value="normal">Normal (0.5s)</option>
              <option value="fast">Fast (0.3s)</option>
            </select>

            <label class="block text-sm font-medium text-gray-700 mb-3">Scroll Behavior</label>
            <select phx-change="update_scroll_behavior"
                    value={get_in(@customization, ["scroll_behavior"]) || "auto"}
                    class="w-full px-3 py-2 border border-gray-300 rounded-md">
              <option value="auto">Auto</option>
              <option value="smooth">Smooth</option>
              <option value="instant">Instant</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Template Management -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Template Management</h4>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <button phx-click="export_template"
                  class="p-4 border border-gray-300 rounded-lg hover:border-gray-400 transition-colors text-center group">
            <svg class="w-6 h-6 mx-auto mb-2 text-gray-600 group-hover:text-blue-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <p class="font-medium text-gray-900">Export Template</p>
            <p class="text-sm text-gray-600">Save current design as template</p>
          </button>

          <button phx-click="show_import_modal"
                  class="p-4 border border-gray-300 rounded-lg hover:border-gray-400 transition-colors text-center group">
            <svg class="w-6 h-6 mx-auto mb-2 text-gray-600 group-hover:text-blue-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
            </svg>
            <p class="font-medium text-gray-900">Import Template</p>
            <p class="text-sm text-gray-600">Load saved template design</p>
          </button>

          <button phx-click="share_template"
                  class="p-4 border border-gray-300 rounded-lg hover:border-gray-400 transition-colors text-center group">
            <svg class="w-6 h-6 mx-auto mb-2 text-gray-600 group-hover:text-blue-600 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.367 2.684 3 3 0 00-5.367-2.684z"/>
            </svg>
            <p class="font-medium text-gray-900">Share Template</p>
            <p class="text-sm text-gray-600">Share with community</p>
          </button>
        </div>
      </div>

      <!-- Responsive Preview -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Responsive Preview</h4>
        <div class="bg-gray-100 rounded-lg p-4">
          <div class="flex items-center justify-center space-x-4 mb-4">
            <%= for {device, icon, size} <- [
              {:desktop, "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z", "1920×1080"},
              {:tablet, "M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z", "768×1024"},
              {:mobile, "M12 18h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z", "375×667"}
            ] do %>
              <button phx-click="preview_portfolio"
                      phx-value-device={device}
                      class={[
                        "p-3 bg-white rounded-lg border border-gray-300 hover:border-gray-400 transition-colors text-center",
                        if(assigns[:preview_device] == device, do: "border-blue-500 bg-blue-50", else: "")
                      ]}>
                <svg class="w-5 h-5 text-gray-600 mx-auto mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon}/>
                </svg>
                <p class="text-xs font-medium text-gray-900 capitalize"><%= device %></p>
                <p class="text-xs text-gray-500"><%= size %></p>
              </button>
            <% end %>
          </div>
          <p class="text-sm text-gray-600 text-center">Preview your portfolio on different devices</p>
        </div>
      </div>

      <!-- Performance & SEO -->
      <div>
        <h4 class="text-md font-semibold text-gray-900 mb-3">Performance & SEO</h4>
        <div class="bg-green-50 border border-green-200 rounded-lg p-4">
          <div class="flex items-start space-x-3">
            <svg class="w-5 h-5 text-green-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
            </svg>
            <div>
              <h5 class="font-medium text-green-900">Optimization Status</h5>
              <ul class="text-sm text-green-800 mt-2 space-y-1">
                <li>✓ Mobile-responsive design</li>
                <li>✓ Fast loading optimized</li>
                <li>✓ SEO-friendly structure</li>
                <li>✓ ATS-compatible export</li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

defp render_settings_tab(assigns) do
    ~H"""
    <div class="p-8">
      <h2 class="text-xl font-bold text-gray-900 mb-6">Portfolio Settings</h2>

      <div class="space-y-8">
        <!-- Visibility Settings -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Visibility & Privacy</h3>
          <div class="bg-gray-50 rounded-lg p-6">
            <div class="space-y-4">
              <%= for {visibility_key, title, description} <- [
                {:public, "Public", "Anyone can find and view your portfolio"},
                {:link_only, "Link Only", "Only people with the link can view"},
                {:private, "Private", "Only you can view (portfolio is hidden)"}
              ] do %>
                <label class="flex items-start space-x-3 cursor-pointer">
                  <input type="radio"
                         name="visibility"
                         value={visibility_key}
                         checked={@portfolio.visibility == visibility_key}
                         phx-click="update_visibility"
                         phx-value-visibility={visibility_key}
                         class="mt-1 text-blue-600" />
                  <div class="flex-1">
                    <span class="font-medium text-gray-900"><%= title %></span>
                    <p class="text-sm text-gray-600 mt-1"><%= description %></p>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>

        <!-- Advanced Settings -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Advanced Settings</h3>
          <div class="space-y-4">
            <!-- Approval Required -->
            <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <h4 class="font-medium text-gray-900">Require Approval</h4>
                <p class="text-sm text-gray-600">Require approval before portfolio changes go live</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox"
                       checked={@portfolio.approval_required}
                       phx-click="toggle_approval_required"
                       class="sr-only peer" />
                <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
              </label>
            </div>

            <!-- Resume Export -->
            <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div>
                <h4 class="font-medium text-gray-900">Allow Resume Export</h4>
                <p class="text-sm text-gray-600">Allow visitors to download your resume as PDF</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox"
                       checked={@portfolio.allow_resume_export}
                       phx-click="toggle_resume_export"
                       class="sr-only peer" />
                <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-focus:ring-4 peer-focus:ring-blue-300 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
              </label>
            </div>
          </div>
        </div>

        <!-- Portfolio Actions -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Portfolio Actions</h3>
          <div class="space-y-4">
            <!-- Export Portfolio -->
            <div class="flex items-center justify-between p-4 bg-blue-50 rounded-lg border border-blue-200">
              <div>
                <h4 class="font-medium text-gray-900">Export Portfolio</h4>
                <p class="text-sm text-gray-600">Download your portfolio as a PDF file</p>
              </div>
              <button id="export-pdf-settings"
                      phx-click="export-portfolio"
                      phx-hook="PdfDownload"
                      class="bg-blue-600 text-white px-4 py-2 rounded-lg hover:bg-blue-700 transition-colors">
                Export PDF
              </button>
            </div>

            <!-- Duplicate Portfolio -->
            <%= if @can_duplicate do %>
              <div class="flex items-center justify-between p-4 bg-green-50 rounded-lg border border-green-200">
                <div>
                  <h4 class="font-medium text-gray-900">Duplicate Portfolio</h4>
                  <p class="text-sm text-gray-600">Create a copy of this portfolio</p>
                </div>
                <button phx-click="duplicate_portfolio"
                        class="bg-green-600 text-white px-4 py-2 rounded-lg hover:bg-green-700 transition-colors">
                  Duplicate
                </button>
              </div>
            <% else %>
              <div class="flex items-center justify-between p-4 bg-gray-100 rounded-lg border border-gray-300">
                <div>
                  <h4 class="font-medium text-gray-500">Duplicate Portfolio</h4>
                  <p class="text-sm text-gray-500"><%= @duplicate_disabled_reason %></p>
                </div>
                <button disabled
                        class="bg-gray-400 text-white px-4 py-2 rounded-lg cursor-not-allowed">
                  Duplicate
                </button>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Danger Zone -->
        <div>
          <h3 class="text-lg font-semibold text-red-900 mb-4">Danger Zone</h3>
          <div class="bg-red-50 border border-red-200 rounded-lg p-6">
            <div>
              <h4 class="font-medium text-red-900 mb-2">Delete Portfolio</h4>
              <p class="text-sm text-red-700 mb-4">
                Once you delete a portfolio, there is no going back. Please be certain.
              </p>
              <button phx-click="delete_portfolio"
                      data-confirm="Are you absolutely sure? This action cannot be undone."
                      class="bg-red-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-red-700 transition-colors">
                Delete This Portfolio
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # PREVIEW SECTION RENDERER
  # ============================================================================

  defp render_preview_section(assigns) do
    ~H"""
    <div class="mb-8">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-lg font-semibold text-gray-900">Portfolio Preview</h2>

        <!-- Device Preview Toggles -->
        <div class="flex items-center space-x-2 bg-gray-100 rounded-lg p-1">
          <%= for {device, icon, label} <- [
            {:desktop, "M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z", "Desktop"},
            {:tablet, "M12 18h.01M8 21h8a2 2 0 002-2V5a2 2 0 00-2-2H8a2 2 0 00-2 2v14a2 2 0 002 2z", "Tablet"},
            {:mobile, "M12 18h.01M7 21h10a2 2 0 002-2V5a2 2 0 00-2-2H7a2 2 0 00-2 2v14a2 2 0 002 2z", "Mobile"}
          ] do %>
            <button phx-click="change_preview_device" phx-value-device={device}
                    class={[
                      "p-2 rounded text-sm font-medium transition-colors",
                      if(assigns[:preview_device] == device,
                         do: "bg-white text-blue-600 shadow-sm",
                         else: "text-gray-600 hover:text-gray-900")
                    ]}
                    title={label}>
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={icon}/>
              </svg>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Preview Frame -->
      <div class={[
        "bg-gray-800 rounded-xl p-4 mx-auto",
        case assigns[:preview_device] do
          :desktop -> "max-w-full"
          :tablet -> "max-w-3xl"
          :mobile -> "max-w-sm"
          _ -> "max-w-full"
        end
      ]}>
        <div class={[
          "bg-white rounded-lg overflow-hidden shadow-lg",
          case assigns[:preview_device] do
            :desktop -> "aspect-[16/10]"
            :tablet -> "aspect-[4/3]"
            :mobile -> "aspect-[9/16]"
            _ -> "aspect-[16/10]"
          end
        ]}>
          <iframe src={"/p/#{@portfolio.slug}?preview=true"}
                  class="w-full h-full border-0"
                  title="Portfolio Preview"></iframe>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MODAL RENDERERS
  # ============================================================================

  defp render_media_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm"
         phx-click="hide_media_modal">
      <div class="bg-white rounded-2xl shadow-2xl max-w-7xl w-full mx-4 max-h-[90vh] overflow-hidden"
           phx-click-away="hide_media_modal">

        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-8 py-6">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>
              <div>
                <h3 class="text-2xl font-bold text-white">Media Library</h3>
                <p class="text-blue-100">Portfolio media management</p>
              </div>
            </div>

            <button phx-click="hide_media_modal"
                    class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-8">
          <p class="text-gray-600">Media management interface would be rendered here...</p>
        </div>

        <!-- Modal Footer -->
        <div class="bg-gray-50 px-8 py-4 border-t border-gray-200 flex items-center justify-between">
          <div class="text-sm text-gray-600">
            Media management interface
          </div>

          <div class="flex items-center space-x-3">
            <button phx-click="hide_media_modal"
                    class="px-4 py-2 text-gray-700 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_media_preview_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75"
         phx-click="hide_media_preview">
      <div class="max-w-5xl w-full mx-4 max-h-[90vh] overflow-hidden"
           phx-click-away="hide_media_preview">

        <!-- Preview Header -->
        <div class="bg-black bg-opacity-50 text-white p-4 flex items-center justify-between">
          <div class="flex items-center space-x-3">
            <h3 class="text-lg font-semibold">Media Preview</h3>
          </div>

          <button phx-click="hide_media_preview"
                  class="p-2 bg-white bg-opacity-20 rounded-lg hover:bg-opacity-30 transition-all">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Preview Content -->
        <div class="bg-white">
          <p class="p-8 text-gray-600">Media preview content would be rendered here...</p>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MODALS RENDERER
  # ============================================================================

  def render_video_intro_modal(assigns) do
    ~H"""
    <%= if @show_video_intro do %>
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm"
          phx-click="hide_video_intro"
          phx-window-keydown="hide_video_intro"
          phx-key="escape">

        <div class="relative max-w-6xl w-full mx-4"
            phx-click-away="hide_video_intro">

          <.live_component
            module={FrestylWeb.PortfolioLive.VideoIntroComponent}
            id={@video_intro_component_id}
            portfolio={@portfolio}
            current_user={@current_user}
          />
        </div>
      </div>
    <% end %>
    """
  end

  defp render_resume_import_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm">
      <div class="bg-white rounded-2xl shadow-2xl max-w-4xl w-full mx-4 max-h-[90vh] overflow-y-auto">
        <!-- Modal Header -->
        <div class="bg-gradient-to-r from-emerald-600 to-green-600 px-8 py-6 rounded-t-2xl">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-12 h-12 bg-white bg-opacity-20 rounded-xl flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div>
                <h3 class="text-2xl font-bold text-white">Import Resume Data</h3>
                <p class="text-emerald-100">Upload your resume to automatically populate your portfolio</p>
              </div>
            </div>
            <button phx-click="hide_resume_import"
                    class="text-white hover:text-gray-200 transition-colors p-2 hover:bg-white hover:bg-opacity-10 rounded-lg">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Modal Content -->
        <div class="p-8">
          <p class="text-gray-600">Resume import interface would be rendered here...</p>
        </div>
      </div>
    </div>
    """
  end

  defp render_resume_import_modal(assigns) do
    ~H"""
    <!-- Resume Import Modal -->
    <%= if assigns[:show_resume_import_modal] do %>
      <%= render_resume_import_modal(assigns) %>
    <% end %>
    """
  end

  defp render_modals(assigns) do
    ~H"""
    <%= render_video_intro_modal(assigns) %>
    """
  end

  def render_enhanced_javascript(assigns) do
    ~H"""
    <script>
      // Enhanced section management JavaScript
      document.addEventListener('DOMContentLoaded', function() {

        // Auto-close add section dropdown when clicking outside
        document.addEventListener('click', function(e) {
          const dropdown = document.querySelector('[phx-click="toggle_add_section_dropdown"]');
          const dropdownMenu = dropdown?.nextElementSibling;

          if (dropdown && dropdownMenu && !dropdown.contains(e.target) && !dropdownMenu.contains(e.target)) {
            // Send close event to LiveView
            const liveSocket = window.liveSocket;
            if (liveSocket) {
              liveSocket.execJS(dropdown, "phx:hide-dropdown");
            }
          }
        });

        // Enhanced drag and drop feedback
        window.addEventListener('phx:section-added', (e) => {
          const newSection = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
          if (newSection) {
            newSection.classList.add('bg-green-50', 'border-green-300');
            newSection.scrollIntoView({ behavior: 'smooth', block: 'center' });

            setTimeout(() => {
              newSection.classList.remove('bg-green-50', 'border-green-300');
            }, 3000);
          }
        });

        // Section edit started feedback
        window.addEventListener('phx:section-edit-started', (e) => {
          const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
          if (section) {
            section.classList.add('ring-2', 'ring-blue-300', 'bg-blue-50');
          }
        });

        // Section edit cancelled feedback
        window.addEventListener('phx:section-edit-cancelled', (e) => {
          document.querySelectorAll('.section-item').forEach(section => {
            section.classList.remove('ring-2', 'ring-blue-300', 'bg-blue-50');
          });
        });

        // Section saved feedback
        window.addEventListener('phx:section-saved', (e) => {
          document.querySelectorAll('.section-item').forEach(section => {
            section.classList.remove('ring-2', 'ring-blue-300', 'bg-blue-50');
          });

          // Show success animation
          const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
          if (section) {
            section.classList.add('bg-green-50', 'border-green-300');
            setTimeout(() => {
              section.classList.remove('bg-green-50', 'border-green-300');
            }, 2000);
          }
        });

        // Enhanced section deletion feedback
        window.addEventListener('phx:section-deleted', (e) => {
          const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
          if (section) {
            section.style.transform = 'translateX(-100%)';
            section.style.opacity = '0';
            setTimeout(() => section.remove(), 300);
          }
        });

        // Section visibility toggle feedback
        window.addEventListener('phx:section-visibility-toggled', (e) => {
          const section = document.querySelector(`[data-section-id="${e.detail.section_id}"]`);
          if (section) {
            if (e.detail.visible) {
              section.classList.remove('opacity-60', 'bg-gray-50');
            } else {
              section.classList.add('opacity-60', 'bg-gray-50');
            }
          }
        });

        // Section duplication feedback
        window.addEventListener('phx:section-duplicated', (e) => {
          const newSection = document.querySelector(`[data-section-id="${e.detail.new_id}"]`);
          if (newSection) {
            newSection.classList.add('bg-blue-50', 'border-blue-300');
            newSection.scrollIntoView({ behavior: 'smooth', block: 'center' });

            setTimeout(() => {
              newSection.classList.remove('bg-blue-50', 'border-blue-300');
            }, 3000);
          }
        });

        // Better form field updates
        window.addEventListener('phx:section-field-updated', (e) => {
          console.log(`Section ${e.detail.section_id} field ${e.detail.field} updated to:`, e.detail.value);
        });

        // Enhanced loading states
        const originalFetch = window.fetch;
        window.fetch = function(...args) {
          document.body.classList.add('loading');
          return originalFetch.apply(this, args).finally(() => {
            setTimeout(() => document.body.classList.remove('loading'), 100);
          });
        };
      });
    </script>

    <style>
      /* Enhanced CSS for better section management */
      .section-item {
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      }

      .section-item:hover {
        transform: translateY(-2px);
      }

      .section-drag-handle:hover {
        cursor: grab;
      }

      .section-drag-handle:active {
        cursor: grabbing;
      }

      .line-clamp-2 {
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }

      /* Loading state */
      body.loading {
        cursor: wait;
      }

      body.loading * {
        pointer-events: none;
      }

      /* Enhanced button animations */
      .hover\\:scale-105:hover {
        transform: scale(1.05);
      }

      .hover\\:scale-110:hover {
        transform: scale(1.1);
      }

      /* Better focus states */
      button:focus-visible {
        outline: 2px solid #3b82f6;
        outline-offset: 2px;
      }

      /* Smooth transitions for state changes */
      .transition-all {
        transition-property: all;
        transition-timing-function: cubic-bezier(0.4, 0, 0.2, 1);
      }

      /* Enhanced dropdown animations */
      .animate-dropdown-in {
        animation: dropdownIn 0.2s ease-out;
      }

      @keyframes dropdownIn {
        from {
          opacity: 0;
          transform: translateY(-10px) scale(0.95);
        }
        to {
          opacity: 1;
          transform: translateY(0) scale(1);
        }
      }
    </style>
    """
  end

  defp get_font_class(font_family) do
    case font_family do
      "Inter" -> "font-sans"
      "Merriweather" -> "font-serif"
      "JetBrains Mono" -> "font-mono"
      "Playfair Display" -> "font-serif"
      _ -> "font-sans"
    end
  end

  defp get_current_font(customization) do
    get_in(customization, ["typography", "font_family"]) || "Inter"
  end

  defp get_current_background(customization) do
    Map.get(customization, "background", "gradient-vibrant")
  end
end
