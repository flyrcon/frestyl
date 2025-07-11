# lib/frestyl_web/live/portfolio_live/components/content_tab.ex - ENHANCED VERSION

defmodule FrestylWeb.PortfolioLive.Components.ContentTab do
  use Phoenix.Component
  import FrestylWeb.CoreComponents
  alias FrestylWeb.PortfolioLive.Components.ContentRenderer

  def render_content_tab(assigns) do
    ~H"""
    <div class="content-tab-container">
      <%= if @editing_section do %>
        <%= render_section_editor(assigns) %>
      <% else %>
        <%= render_sections_overview(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SECTIONS OVERVIEW - FIXED WITH WORKING BUTTONS
  # ============================================================================

  defp render_sections_overview(assigns) do
    ~H"""
    <div class="sections-overview space-y-6">
      <!-- Header with Add Section -->
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Portfolio Sections</h2>
          <p class="text-gray-600 mt-1">Organize and manage your portfolio content</p>
        </div>

        <!-- FIXED: Add Section Dropdown with Working Handler -->
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
              if(@show_add_section_dropdown, do: "rotate-180", else: "rotate-0")
            ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
            </svg>
          </button>

          <%= if @show_add_section_dropdown do %>
            <div class="absolute right-0 mt-2 w-72 bg-white rounded-xl shadow-lg border border-gray-200 py-2 z-50">
              <div class="px-4 py-2 border-b border-gray-100">
                <h3 class="text-sm font-semibold text-gray-900">Choose Section Type</h3>
              </div>

              <div class="max-h-80 overflow-y-auto">
                <%= for {section_type, section_info} <- get_section_types() do %>
                  <button type="button"
                          phx-click="add_section"
                          phx-value-section_type={section_type}
                          class="w-full text-left px-4 py-3 hover:bg-gray-50 flex items-start space-x-3 transition-colors">
                    <div class={[
                      "w-10 h-10 rounded-lg flex items-center justify-center flex-shrink-0",
                      section_info.bg_color
                    ]}>
                      <span class="text-lg"><%= section_info.emoji %></span>
                    </div>
                    <div class="flex-1 min-w-0">
                      <div class="font-medium text-gray-900"><%= section_info.title %></div>
                      <div class="text-sm text-gray-500"><%= section_info.description %></div>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Sections List with Enhanced Controls -->
      <%= if length(@sections) > 0 do %>
        <div class="sections-list space-y-4" id="sortable-sections" phx-hook="SortableSections">
          <%= for {section, index} <- Enum.with_index(@sections) do %>
            <div class="section-card bg-white border border-gray-200 rounded-xl shadow-sm hover:shadow-md transition-all duration-200"
                 id={"section-#{section.id}"}
                 data-section-id={section.id}
                 data-position={index}>

              <!-- FIXED: Section Header with All Controls -->
              <div class="section-header p-6 border-b border-gray-100">
                <div class="flex items-center justify-between">
                  <!-- Left: Drag Handle + Section Info -->
                  <div class="flex items-center space-x-4">
                    <!-- FIXED: Drag Handle for Sortability -->
                    <div class="drag-handle cursor-move p-2 text-gray-400 hover:text-gray-600" title="Drag to reorder">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16"/>
                      </svg>
                    </div>

                    <!-- Section Type Icon and Info -->
                    <div class="flex items-center space-x-3">
                      <div class={[
                        "w-12 h-12 rounded-xl flex items-center justify-center shadow-sm",
                        get_section_bg_color(section.section_type)
                      ]}>
                        <span class="text-lg"><%= get_section_emoji(section.section_type) %></span>
                      </div>
                      <div>
                        <h3 class="text-lg font-semibold text-gray-900"><%= section.title %></h3>
                        <div class="flex items-center space-x-3 text-sm text-gray-500">
                          <span><%= format_section_type(section.section_type) %></span>
                          <span>•</span>
                          <span>Position <%= index + 1 %></span>
                          <%= if has_content?(section) do %>
                            <span>•</span>
                            <span class="text-green-600 font-medium">Has Content</span>
                          <% end %>
                        </div>
                      </div>
                    </div>
                  </div>

                  <!-- Right: Action Buttons -->
                  <div class="flex items-center space-x-2">
                    <!-- FIXED: Toggle Visibility Button -->
                    <button type="button"
                            phx-click="toggle_section_visibility"
                            phx-value-section-id={section.id}
                            class={[
                              "p-2 rounded-lg transition-colors",
                              if(section.visible,
                                 do: "text-green-600 bg-green-50 hover:bg-green-100",
                                 else: "text-gray-400 bg-gray-50 hover:bg-gray-100")
                            ]}
                            title={if(section.visible, do: "Hide section", else: "Show section")}>
                      <%= if section.visible do %>
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                      <% else %>
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
                        </svg>
                      <% end %>
                    </button>

                    <!-- FIXED: Media Button (if section supports media) -->
                    <%= if section_allows_media?(section) do %>
                      <button type="button"
                              phx-click="manage_section_media"
                              phx-value-section-id={section.id}
                              class="p-2 text-purple-600 bg-purple-50 hover:bg-purple-100 rounded-lg transition-colors"
                              title="Manage media">
                        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                        </svg>
                        <span class="sr-only">Manage Media</span>
                      </button>
                    <% end %>

                    <!-- FIXED: Copy/Duplicate Button -->
                    <button type="button"
                            phx-click="duplicate_section"
                            phx-value-section-id={section.id}
                            class="p-2 text-blue-600 bg-blue-50 hover:bg-blue-100 rounded-lg transition-colors"
                            title="Duplicate section">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                      </svg>
                      <span class="sr-only">Duplicate</span>
                    </button>

                    <!-- FIXED: Edit Button -->
                    <button type="button"
                            phx-click="edit_section"
                            phx-value-section-id={section.id}
                            class="px-4 py-2 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors font-medium">
                      Edit
                    </button>

                    <!-- Delete Button -->
                    <button type="button"
                            phx-click="delete_section"
                            phx-value-section-id={section.id}
                            data-confirm="Are you sure you want to delete this section? This action cannot be undone."
                            class="p-2 text-red-600 bg-red-50 hover:bg-red-100 rounded-lg transition-colors"
                            title="Delete section">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                      <span class="sr-only">Delete</span>
                    </button>
                  </div>
                </div>
              </div>

              <!-- Section Content Preview -->
              <div class="section-content p-6">
                <%= if has_content?(section) do %>
                  <div class="prose prose-sm max-w-none text-gray-700">
                    <%= ContentRenderer.render_section_content(%{section: section}) %>
                  </div>
                <% else %>
                  <div class="text-center py-8 text-gray-500">
                    <svg class="w-12 h-12 mx-auto text-gray-300 mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <p class="text-sm">No content added yet</p>
                    <button type="button"
                            phx-click="edit_section"
                            phx-value-section-id={section.id}
                            class="mt-2 text-blue-600 hover:text-blue-800 text-sm font-medium">
                      Add content →
                    </button>
                  </div>
                <% end %>
              </div>

              <!-- Section Footer with Status -->
              <div class="section-footer px-6 py-3 bg-gray-50 border-t border-gray-100">
                <div class="flex items-center justify-between text-xs text-gray-500">
                  <div class="flex items-center space-x-4">
                    <span class="flex items-center space-x-1">
                      <div class={[
                        "w-2 h-2 rounded-full",
                        if(section.visible, do: "bg-green-500", else: "bg-gray-400")
                      ]}></div>
                      <span><%= if section.visible, do: "Visible", else: "Hidden" %></span>
                    </span>
                    <span>Updated: <%= format_relative_time(section.updated_at) %></span>
                    <%= if section_has_media?(section.id) do %>
                      <span class="text-purple-600 font-medium">Has Media</span>
                    <% end %>
                  </div>
                  <div class="text-gray-400">
                    <span>Drag to reorder</span>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Helpful Tips -->
        <div class="bg-blue-50 border border-blue-200 rounded-xl p-6">
          <div class="flex items-start space-x-4">
            <div class="w-10 h-10 bg-blue-100 rounded-xl flex items-center justify-center flex-shrink-0">
              <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </div>
            <div>
              <h4 class="font-semibold text-gray-900 mb-2">Section Management Tips</h4>
              <ul class="text-sm text-gray-700 space-y-1">
                <li>• Drag the ≡ handle to reorder sections</li>
                <li>• Use the eye icon to hide/show sections on your portfolio</li>
                <li>• Add media files to make sections more engaging</li>
                <li>• Duplicate sections to save time on similar content</li>
                <li>• Hidden sections won't appear on your public portfolio</li>
              </ul>
            </div>
          </div>
        </div>

      <% else %>
        <!-- Enhanced Empty State -->
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
                  class="bg-blue-600 text-white px-8 py-4 rounded-xl font-semibold text-lg hover:bg-blue-700 transition-all duration-200 shadow-lg hover:shadow-xl">
            Add Your First Section
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # SECTION EDITOR - ENHANCED WITH PROPER CONTENT HANDLING
  # ============================================================================

  defp render_section_editor(assigns) do
    ~H"""
    <div class="section-editor space-y-6">
      <!-- Editor Header -->
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-4">
          <button type="button"
                  phx-click="close_section_editor"
                  class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg transition-colors">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <div>
            <h2 class="text-xl font-bold text-gray-900">
              Editing: <%= @editing_section.title %>
            </h2>
            <p class="text-gray-600">
              <%= format_section_type(@editing_section.section_type) %> Section
            </p>
          </div>
        </div>

        <div class="flex items-center space-x-3">
          <button type="button"
                  phx-click="preview_section"
                  phx-value-section-id={@editing_section.id}
                  class="px-4 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors">
            Preview
          </button>
          <button type="button"
                  phx-click="save_section"
                  phx-value-section-id={@editing_section.id}
                  class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
            Save Section
          </button>
        </div>
      </div>

      <!-- Section Editor Tabs -->
      <div class="bg-white rounded-xl border border-gray-200">
        <div class="border-b border-gray-200">
          <nav class="flex space-x-8 px-6" aria-label="Tabs">
            <%= for {tab_key, tab_name, tab_icon} <- [
              {"content", "Content", "M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"},
              {"media", "Media", "M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"},
              {"settings", "Settings", "M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"}
            ] do %>
              <button type="button"
                      phx-click="switch_section_tab"
                      phx-value-tab={tab_key}
                      class={[
                        "py-4 px-1 border-b-2 font-medium text-sm transition-colors flex items-center space-x-2",
                        if(@section_edit_tab == tab_key,
                           do: "border-blue-500 text-blue-600",
                           else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={tab_icon}/>
                </svg>
                <span><%= tab_name %></span>
                <%= if tab_key == "media" and section_has_media?(@editing_section.id) do %>
                  <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
                    <%= count_section_media(@editing_section.id) %>
                  </span>
                <% end %>
              </button>
            <% end %>
          </nav>
        </div>

        <!-- Tab Content -->
        <div class="p-6">
          <%= case @section_edit_tab || "content" do %>
            <% "content" -> %>
              <%= render_section_content_editor(assigns) %>
            <% "media" -> %>
              <%= render_section_media_editor(assigns) %>
            <% "settings" -> %>
              <%= render_section_settings_editor(assigns) %>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # CONTENT EDITOR BASED ON SECTION TYPE
  # ============================================================================

  defp render_section_content_editor(assigns) do
    ~H"""
    <div class="section-content-editor space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-3">Section Title</label>
        <input type="text"
               value={@editing_section.title}
               phx-blur="update_section_field"
               phx-value-field="title"
               phx-value-section-id={@editing_section.id}
               placeholder="Enter section title..."
               class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-semibold" />
      </div>

      <!-- Dynamic Content Fields Based on Section Type -->
      <%= render_section_type_fields(assigns) %>
    </div>
    """
  end

  defp render_section_type_fields(assigns) do
    section_type = @editing_section.section_type
    content = @editing_section.content || %{}

    assigns = assign(assigns, content: content)

    case section_type do
      "intro" -> render_intro_editor(assigns)
      "experience" -> render_experience_editor(assigns)
      "education" -> render_education_editor(assigns)
      "skills" -> render_skills_editor(assigns)
      "projects" -> render_projects_editor(assigns)
      "featured_project" -> render_featured_project_editor(assigns)
      "achievements" -> render_achievements_editor(assigns)
      "testimonial" -> render_testimonial_editor(assigns)
      "contact" -> render_contact_editor(assigns)
      _ -> render_generic_editor(assigns)
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_section_types() do
    %{
      "intro" => %{
        title: "Introduction",
        description: "Welcome message and personal summary",
        emoji: "👋",
        bg_color: "bg-blue-100"
      },
      "experience" => %{
        title: "Professional Experience",
        description: "Work history and job experience",
        emoji: "💼",
        bg_color: "bg-green-100"
      },
      "education" => %{
        title: "Education",
        description: "Academic background and qualifications",
        emoji: "🎓",
        bg_color: "bg-purple-100"
      },
      "skills" => %{
        title: "Skills & Expertise",
        description: "Technical and professional skills",
        emoji: "⚡",
        bg_color: "bg-yellow-100"
      },
      "projects" => %{
        title: "Projects",
        description: "Portfolio of work and projects",
        emoji: "🛠️",
        bg_color: "bg-indigo-100"
      },
      "featured_project" => %{
        title: "Featured Project",
        description: "Highlight a specific project",
        emoji: "🚀",
        bg_color: "bg-red-100"
      },
      "case_study" => %{
        title: "Case Study",
        description: "Detailed project analysis",
        emoji: "📊",
        bg_color: "bg-teal-100"
      },
      "achievements" => %{
        title: "Achievements",
        description: "Awards, certifications, and accomplishments",
        emoji: "🏆",
        bg_color: "bg-orange-100"
      },
      "testimonial" => %{
        title: "Testimonials",
        description: "Client and colleague recommendations",
        emoji: "💬",
        bg_color: "bg-pink-100"
      },
      "contact" => %{
        title: "Contact Information",
        description: "How to get in touch",
        emoji: "📧",
        bg_color: "bg-gray-100"
      }
    }
  end

  defp get_section_emoji("intro"), do: "👋"
  defp get_section_emoji("experience"), do: "💼"
  defp get_section_emoji("education"), do: "🎓"
  defp get_section_emoji("skills"), do: "⚡"
  defp get_section_emoji("projects"), do: "🛠️"
  defp get_section_emoji("featured_project"), do: "🚀"
  defp get_section_emoji("case_study"), do: "📊"
  defp get_section_emoji("achievements"), do: "🏆"
  defp get_section_emoji("testimonial"), do: "💬"
  defp get_section_emoji("contact"), do: "📧"
  defp get_section_emoji(_), do: "📄"

  defp get_section_bg_color("intro"), do: "bg-blue-100"
  defp get_section_bg_color("experience"), do: "bg-green-100"
  defp get_section_bg_color("education"), do: "bg-purple-100"
  defp get_section_bg_color("skills"), do: "bg-yellow-100"
  defp get_section_bg_color("projects"), do: "bg-indigo-100"
  defp get_section_bg_color("featured_project"), do: "bg-red-100"
  defp get_section_bg_color("case_study"), do: "bg-teal-100"
  defp get_section_bg_color("achievements"), do: "bg-orange-100"
  defp get_section_bg_color("testimonial"), do: "bg-pink-100"
  defp get_section_bg_color("contact"), do: "bg-gray-100"
  defp get_section_bg_color(_), do: "bg-gray-100"

  defp format_section_type(section_type) do
    section_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp has_content?(section) do
    content = section.content || %{}

    case content do
      %{} when map_size(content) == 0 -> false
      %{"main_content" => ""} -> false
      %{"main_content" => nil} -> false
      _ -> true
    end
  end

  defp section_allows_media?(section) do
    # Define which section types support media
    section.section_type in [
      "intro", "experience", "projects", "featured_project",
      "case_study", "achievements", "testimonial", "media_showcase"
    ]
  end

  defp section_has_media?(section_id) do
    # This would check if the section has associated media
    # Implement based on your media system
    false
  end

  defp count_section_media(section_id) do
    # This would count media items for the section
    # Implement based on your media system
    0
  end

  defp format_relative_time(datetime) do
    # Simple relative time formatting
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      diff when diff < 60 -> "Just now"
      diff when diff < 3600 -> "#{div(diff, 60)}m ago"
      diff when diff < 86400 -> "#{div(diff, 3600)}h ago"
      _ -> "#{div(DateTime.diff(DateTime.utc_now(), datetime, :day), 1)}d ago"
    end
  end

  # Placeholder editor functions (implement based on your needs)
  defp render_intro_editor(assigns), do: render_generic_editor(assigns)
  defp render_experience_editor(assigns), do: render_generic_editor(assigns)
  defp render_education_editor(assigns), do: render_generic_editor(assigns)
  defp render_skills_editor(assigns), do: render_generic_editor(assigns)
  defp render_projects_editor(assigns), do: render_generic_editor(assigns)
  defp render_featured_project_editor(assigns), do: render_generic_editor(assigns)
  defp render_achievements_editor(assigns), do: render_generic_editor(assigns)
  defp render_testimonial_editor(assigns), do: render_generic_editor(assigns)
  defp render_contact_editor(assigns), do: render_generic_editor(assigns)

  defp render_generic_editor(assigns) do
    main_content = get_in(assigns.content, ["main_content"]) || ""
    assigns = assign(assigns, main_content: main_content)

    ~H"""
    <div class="generic-editor">
      <div>
        <label class="block text-sm font-semibold text-gray-800 mb-3">Content</label>
        <textarea phx-blur="update_section_content"
                  phx-value-field="main_content"
                  phx-value-section-id={@editing_section.id}
                  rows="12"
                  placeholder="Add content for this section..."
                  class="w-full px-4 py-3 border border-gray-300 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-none"><%= @main_content %></textarea>
        <p class="text-xs text-gray-500 mt-2">
          Content will be automatically formatted for display. HTML will be cleaned for security.
        </p>
      </div>
    </div>
    """
  end

  defp render_section_media_editor(assigns) do
    ~H"""
    <div class="section-media-editor">
      <div class="text-center py-12">
        <div class="w-16 h-16 bg-purple-100 rounded-xl flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
        </div>
        <h3 class="text-lg font-medium text-gray-900 mb-2">Media Management</h3>
        <p class="text-gray-600 mb-6">Add images, videos, and documents to enhance this section</p>

        <div class="flex items-center justify-center space-x-4">
          <button type="button"
                  phx-click="upload_media"
                  phx-value-section-id={@editing_section.id}
                  class="bg-purple-600 text-white px-6 py-3 rounded-lg font-medium hover:bg-purple-700 transition-colors">
            Upload Media
          </button>
          <button type="button"
                  phx-click="browse_media_library"
                  phx-value-section-id={@editing_section.id}
                  class="bg-gray-200 text-gray-700 px-6 py-3 rounded-lg font-medium hover:bg-gray-300 transition-colors">
            Browse Library
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_settings_editor(assigns) do
    ~H"""
    <div class="section-settings-editor space-y-6">
      <!-- Visibility Settings -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Visibility Settings</h4>
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="flex items-center justify-between">
            <div>
              <h5 class="font-medium text-gray-900">Section Visible</h5>
              <p class="text-sm text-gray-600">Show this section in your public portfolio</p>
            </div>
            <label class="relative inline-flex items-center cursor-pointer">
              <input type="checkbox"
                     checked={@editing_section.visible}
                     phx-click="toggle_section_visibility"
                     phx-value-section-id={@editing_section.id}
                     class="sr-only peer">
              <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
            </label>
          </div>
        </div>
      </div>

      <!-- Position Settings -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Position</h4>
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="flex items-center justify-between">
            <div>
              <h5 class="font-medium text-gray-900">Section Order</h5>
              <p class="text-sm text-gray-600">Current position: <%= @editing_section.position || 0 %></p>
            </div>
            <div class="flex items-center space-x-2">
              <button type="button"
                      phx-click="move_section_up"
                      phx-value-section-id={@editing_section.id}
                      class="p-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 14l5-5 5 5"/>
                </svg>
              </button>
              <button type="button"
                      phx-click="move_section_down"
                      phx-value-section-id={@editing_section.id}
                      class="p-2 bg-white border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 10l-5 5-5-5"/>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- Advanced Settings -->
      <div>
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Advanced Settings</h4>
        <div class="space-y-4">
          <div class="bg-gray-50 rounded-lg p-4">
            <h5 class="font-medium text-gray-900 mb-2">Section Template</h5>
            <p class="text-sm text-gray-600 mb-3">Choose how this section is displayed</p>
            <select class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="default">Default Layout</option>
              <option value="compact">Compact Layout</option>
              <option value="expanded">Expanded Layout</option>
              <option value="grid">Grid Layout</option>
            </select>
          </div>

          <%= if section_allows_media?(@editing_section) do %>
            <div class="bg-gray-50 rounded-lg p-4">
              <h5 class="font-medium text-gray-900 mb-2">Media Display</h5>
              <p class="text-sm text-gray-600 mb-3">Configure how media is shown in this section</p>
              <div class="space-y-3">
                <label class="flex items-center">
                  <input type="radio" name="media_layout" value="gallery" class="text-blue-600 focus:ring-blue-500">
                  <span class="ml-2 text-sm text-gray-700">Gallery View</span>
                </label>
                <label class="flex items-center">
                  <input type="radio" name="media_layout" value="carousel" class="text-blue-600 focus:ring-blue-500">
                  <span class="ml-2 text-sm text-gray-700">Carousel View</span>
                </label>
                <label class="flex items-center">
                  <input type="radio" name="media_layout" value="featured" class="text-blue-600 focus:ring-blue-500">
                  <span class="ml-2 text-gray-700">Featured Image</span>
                </label>
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Danger Zone -->
      <div>
        <h4 class="text-lg font-semibold text-red-600 mb-4">Danger Zone</h4>
        <div class="bg-red-50 border border-red-200 rounded-lg p-4">
          <div class="flex items-center justify-between">
            <div>
              <h5 class="font-medium text-red-900">Delete Section</h5>
              <p class="text-sm text-red-700">Permanently remove this section and all its content</p>
            </div>
            <button type="button"
                    phx-click="delete_section"
                    phx-value-section-id={@editing_section.id}
                    data-confirm="Are you sure you want to delete this section? This action cannot be undone."
                    class="px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors font-medium">
              Delete Section
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp enhanced_add_section_dropdown(assigns) do
    ~H"""
    <div class="relative" x-data="{ open: false }">
      <!-- Add Block Button -->
      <button
        @click="open = !open"
        class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-lg text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-colors">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
        Add Content Block
      </button>

      <!-- Dropdown Panel -->
      <div
        x-show="open"
        @click.away="open = false"
        x-transition:enter="transition ease-out duration-200"
        x-transition:enter-start="opacity-0 scale-95"
        x-transition:enter-end="opacity-100 scale-100"
        x-transition:leave="transition ease-in duration-150"
        x-transition:leave-start="opacity-100 scale-100"
        x-transition:leave-end="opacity-0 scale-95"
        class="absolute right-0 z-50 mt-2 w-96 bg-white rounded-xl shadow-xl border border-gray-200">

        <div class="p-6">
          <!-- Zone Selection -->
          <div class="mb-6">
            <label class="block text-sm font-medium text-gray-700 mb-3">Choose Layout Zone</label>
            <div class="grid grid-cols-2 gap-2" id="zone-selector">
              <%= for {zone_key, zone_config} <- [
                {"hero", %{name: "Hero Section", icon: "⭐", description: "Top banner area"}},
                {"main_content", %{name: "Main Content", icon: "📝", description: "Primary content area"}},
                {"sidebar", %{name: "Sidebar", icon: "📋", description: "Side information"}},
                {"footer", %{name: "Footer", icon: "🔗", description: "Contact & links"}}
              ] do %>
                <button
                  phx-click="select_zone"
                  phx-value-zone={zone_key}
                  class="p-3 border border-gray-200 hover:border-gray-300 rounded-lg text-left transition-colors zone-selector"
                  data-zone={zone_key}>
                  <div class="flex items-center mb-1">
                    <span class="text-lg mr-2"><%= zone_config.icon %></span>
                    <span class="font-medium text-sm"><%= zone_config.name %></span>
                  </div>
                  <p class="text-xs text-gray-500"><%= zone_config.description %></p>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Block Type Categories -->
          <div class="mb-4">
            <label class="block text-sm font-medium text-gray-700 mb-3">Content Block Type</label>

            <!-- Essential Blocks -->
            <div class="mb-4">
              <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Essential</h4>
              <div class="grid grid-cols-2 gap-2">
                <%= for {block_type, block_config} <- [
                  {"hero_card", %{name: "Hero Banner", icon: "🌟", description: "Main introduction"}},
                  {"about_card", %{name: "About Me", icon: "👤", description: "Personal story"}},
                  {"contact_card", %{name: "Contact Info", icon: "📞", description: "How to reach you"}},
                  {"text_card", %{name: "Text Block", icon: "📄", description: "Custom content"}}
                ] do %>
                  <button
                    phx-click="add_content_block"
                    phx-value-block_type={block_type}
                    phx-value-zone="main_content"
                    class="p-3 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 text-left transition-colors group add-block-btn"
                    data-block-type={block_type}>
                    <div class="flex items-center mb-1">
                      <span class="text-lg mr-2"><%= block_config.icon %></span>
                      <span class="font-medium text-sm text-gray-900 group-hover:text-blue-700"><%= block_config.name %></span>
                    </div>
                    <p class="text-xs text-gray-500"><%= block_config.description %></p>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Professional Blocks -->
            <div class="mb-4">
              <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Professional</h4>
              <div class="grid grid-cols-2 gap-2">
                <%= for {block_type, block_config} <- [
                  {"experience_card", %{name: "Work Experience", icon: "💼", description: "Career history"}},
                  {"skills_card", %{name: "Skills", icon: "🎯", description: "Abilities & expertise"}},
                  {"project_card", %{name: "Projects", icon: "🚀", description: "Portfolio showcase"}},
                  {"testimonial_card", %{name: "Testimonials", icon: "💬", description: "Client feedback"}}
                ] do %>
                  <button
                    phx-click="add_content_block"
                    phx-value-block_type={block_type}
                    phx-value-zone="main_content"
                    class="p-3 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 text-left transition-colors group add-block-btn"
                    data-block-type={block_type}>
                    <div class="flex items-center mb-1">
                      <span class="text-lg mr-2"><%= block_config.icon %></span>
                      <span class="font-medium text-sm text-gray-900 group-hover:text-blue-700"><%= block_config.name %></span>
                    </div>
                    <p class="text-xs text-gray-500"><%= block_config.description %></p>
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Creative Blocks -->
            <div class="mb-4">
              <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-2">Creative</h4>
              <div class="grid grid-cols-2 gap-2">
                <%= for {block_type, block_config} <- [
                  {"gallery_card", %{name: "Image Gallery", icon: "🖼️", description: "Photo showcase"}},
                  {"video_card", %{name: "Video", icon: "🎥", description: "Video content"}},
                  {"social_card", %{name: "Social Links", icon: "🔗", description: "Social media"}},
                  {"service_card", %{name: "Services", icon: "⚙️", description: "What you offer"}}
                ] do %>
                  <button
                    phx-click="add_content_block"
                    phx-value-block_type={block_type}
                    phx-value-zone="sidebar"
                    class="p-3 border border-gray-200 rounded-lg hover:border-blue-300 hover:bg-blue-50 text-left transition-colors group add-block-btn"
                    data-block-type={block_type}>
                    <div class="flex items-center mb-1">
                      <span class="text-lg mr-2"><%= block_config.icon %></span>
                      <span class="font-medium text-sm text-gray-900 group-hover:text-blue-700"><%= block_config.name %></span>
                    </div>
                    <p class="text-xs text-gray-500"><%= block_config.description %></p>
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Import Options -->
          <div class="pt-4 border-t border-gray-200">
            <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wide mb-3">Quick Import</h4>
            <div class="space-y-2">
              <button
                phx-click="show_resume_import"
                class="w-full flex items-center px-3 py-2 text-sm text-left text-gray-700 hover:bg-gray-50 rounded-lg transition-colors">
                <svg class="w-4 h-4 mr-3 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10"/>
                </svg>
                Import from Resume
                <span class="ml-auto text-xs text-gray-500">PDF, DOCX</span>
              </button>

              <button
                phx-click="show_linkedin_import"
                class="w-full flex items-center px-3 py-2 text-sm text-left text-gray-700 hover:bg-gray-50 rounded-lg transition-colors">
                <svg class="w-4 h-4 mr-3 text-blue-600" fill="currentColor" viewBox="0 0 24 24">
                  <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
                </svg>
                Import from LinkedIn
                <span class="ml-auto text-xs text-orange-600">Pro</span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Simple JavaScript for zone selection enhancement -->
    <script>
      document.addEventListener('DOMContentLoaded', function() {
        let selectedZone = 'main_content';

        // Handle zone selection with visual feedback
        document.addEventListener('click', function(e) {
          if (e.target.closest('.zone-selector')) {
            const button = e.target.closest('.zone-selector');
            const zone = button.dataset.zone;
            selectedZone = zone;

            // Update visual selection
            document.querySelectorAll('.zone-selector').forEach(btn => {
              btn.classList.remove('border-blue-500', 'bg-blue-50', 'text-blue-700');
              btn.classList.add('border-gray-200');
            });
            button.classList.remove('border-gray-200');
            button.classList.add('border-blue-500', 'bg-blue-50', 'text-blue-700');
          }

          // Update block buttons with selected zone before Phoenix handles them
          if (e.target.closest('.add-block-btn')) {
            const button = e.target.closest('.add-block-btn');
            button.setAttribute('phx-value-zone', selectedZone);
          }
        });

        // Set default selection
        const defaultButton = document.querySelector('.zone-selector[data-zone="main_content"]');
        if (defaultButton) {
          defaultButton.classList.add('border-blue-500', 'bg-blue-50', 'text-blue-700');
          defaultButton.classList.remove('border-gray-200');
        }
      });
    </script>
    """
  end


  defp map_block_type_to_section_type(block_type) do
    case block_type do
      "hero_card" -> "hero"
      "about_card" -> "about"
      "experience_card" -> "experience"
      "skills_card" -> "skills"
      "project_card" -> "portfolio"
      "contact_card" -> "contact"
      "testimonial_card" -> "testimonials"
      "service_card" -> "services"
      "gallery_card" -> "gallery"
      "video_card" -> "video"
      "social_card" -> "social"
      "text_card" -> "text"
      _ -> "text"
    end
  end

  defp get_default_title_for_block_type(block_type) do
    case block_type do
      "hero_card" -> "Welcome"
      "about_card" -> "About Me"
      "experience_card" -> "Work Experience"
      "skills_card" -> "Skills & Expertise"
      "project_card" -> "Featured Projects"
      "contact_card" -> "Get In Touch"
      "testimonial_card" -> "What People Say"
      "service_card" -> "Services"
      "gallery_card" -> "Gallery"
      "video_card" -> "Video"
      "social_card" -> "Connect With Me"
      "text_card" -> "Custom Content"
      _ -> "New Section"
    end
  end

  defp get_default_content_for_block_type(block_type) do
    base_content = %{
      "created_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "block_type" => block_type
    }

    case block_type do
      "hero_card" ->
        Map.merge(base_content, %{
          "subtitle" => "Professional [Your Title]",
          "description" => "Brief introduction about yourself and what you do.",
          "cta_text" => "Get Started",
          "background_style" => "gradient"
        })
      "about_card" ->
        Map.merge(base_content, %{
          "description" => "Tell your story here. What drives you? What's your background?",
          "image_url" => "",
          "highlights" => []
        })
      "experience_card" ->
        Map.merge(base_content, %{
          "experiences" => [
            %{
              "title" => "Your Job Title",
              "company" => "Company Name",
              "duration" => "2020 - Present",
              "description" => "Brief description of your role and achievements."
            }
          ]
        })
      "skills_card" ->
        Map.merge(base_content, %{
          "skills" => [
            %{"name" => "Skill 1", "level" => "Expert"},
            %{"name" => "Skill 2", "level" => "Advanced"},
            %{"name" => "Skill 3", "level" => "Intermediate"}
          ]
        })
      "contact_card" ->
        Map.merge(base_content, %{
          "email" => "your.email@example.com",
          "phone" => "",
          "location" => "Your City, Country",
          "social_links" => []
        })
      _ ->
        Map.merge(base_content, %{
          "description" => "Add your content here."
        })
    end
  end

  defp get_next_position_for_zone(portfolio_id, zone) do
    # Get current sections in this zone
    case Portfolios.list_portfolio_sections(portfolio_id) do
      sections when is_list(sections) ->
        zone_sections = Enum.filter(sections, fn section ->
          get_in(section, [:metadata, "zone"]) == zone
        end)
        length(zone_sections) + 1
      _ -> 1
    end
  rescue
    _ -> 1
  end

  defp add_section_to_zone(layout_zones, zone, section) do
    zone_atom = String.to_atom(zone)
    current_blocks = Map.get(layout_zones, zone_atom, [])

    new_block = %{
      id: section.id,
      block_type: String.to_atom(get_in(section, [:metadata, "block_type"]) || "text_card"),
      content_data: section.content || %{},
      original_section: section,
      position: section.position,
      visible: section.visible,
      zone: zone_atom
    }

    Map.put(layout_zones, zone_atom, current_blocks ++ [new_block])
  end

  defp get_block_display_name(block_type) do
    case block_type do
      "hero_card" -> "Hero Banner"
      "about_card" -> "About Section"
      "experience_card" -> "Work Experience"
      "skills_card" -> "Skills"
      "project_card" -> "Projects"
      "contact_card" -> "Contact Info"
      "testimonial_card" -> "Testimonials"
      "service_card" -> "Services"
      "gallery_card" -> "Image Gallery"
      "video_card" -> "Video"
      "social_card" -> "Social Links"
      "text_card" -> "Text Block"
      _ -> "Content Block"
    end
  end

  defp format_zone_name(zone) do
    case zone do
      "hero" -> "Hero Section"
      "main_content" -> "Main Content"
      "sidebar" -> "Sidebar"
      "footer" -> "Footer"
      _ -> String.replace(zone, "_", " ") |> String.capitalize()
    end
  end
end
