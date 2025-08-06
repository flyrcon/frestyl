# lib/frestyl_web/live/portfolio_live/components/dynamic_section_modal.ex
# 🔧 COMPLETE FIX - All 18 Section Types with Full Implementation

defmodule FrestylWeb.PortfolioLive.Components.DynamicSectionModal do
  @moduledoc """
  COMPLETE FIXED: Dynamic section modal with ALL 18 section types.
  Addresses all broken functionality while maintaining working sections.
  """

  use FrestylWeb, :live_component
  alias Frestyl.Portfolios.EnhancedSectionSystem
  alias Frestyl.Media

  @impl true
  def update(assigns, socket) do
    # Initialize form data from editing section or defaults
    form_data = case assigns[:editing_section] do
      %{content: content, title: title, section_type: section_type} when is_map(content) ->
        extract_content_for_editing(content, title, section_type)
      %{title: title, section_type: section_type} ->
        %{"title" => title, "section_type" => to_string(section_type)}
      _ ->
        get_default_form_data(assigns.section_type)
        |> Map.put("section_type", assigns.section_type)
    end

    socket = socket
    |> assign(assigns)
    |> assign(:form_data, form_data)
    |> assign(:validation_errors, %{})
    |> assign(:save_status, nil)
    |> assign(:show_enhanced_fields, false)
    |> assign(:show_media_section, has_media_support?(assigns.section_type))
    |> assign(:form_changeset, build_form_changeset(form_data, assigns.section_type))
    |> allow_upload(:media,
      accept: get_accepted_file_types(assigns.section_type),
      max_file_size: 50_000_000, # 50MB
      max_entries: 10
    )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4"
         phx-window-keydown="close_modal_on_escape"
         phx-key="Escape">

      <div class="bg-white rounded-xl shadow-2xl max-w-5xl w-full max-h-[95vh] overflow-hidden"
           phx-click={JS.exec("event.stopPropagation()")}>

        <!-- Modal Header -->
        <%= render_modal_header(assigns) %>

        <!-- Modal Content -->
        <div class="flex-1 overflow-y-auto max-h-[75vh]">
          <form id="section-form" phx-submit="save_section" phx-target={@myself} class="space-y-6 p-6">

            <!-- Hidden Fields -->
            <input type="hidden" name="section_type" value={@section_type} />
            <%= if @editing_section do %>
              <input type="hidden" name="section_id" value={@editing_section.id} />
              <input type="hidden" name="action" value="update" />
            <% else %>
              <input type="hidden" name="action" value="create" />
            <% end %>

            <!-- Essential Fields (Always Visible) -->
            <%= render_essential_fields(assigns) %>

            <!-- Enhanced Fields (Collapsible) -->
            <%= render_enhanced_fields_section(assigns) %>

            <!-- Items Section (if applicable) -->
            <%= if has_essential_items?(@section_type) do %>
              <%= render_essential_items_section(assigns) %>
            <% end %>

            <!-- Media Upload Section -->
            <%= if @show_media_section do %>
              <%= render_media_upload_section(assigns) %>
            <% end %>

            <!-- Validation Errors -->
            <%= render_validation_errors(assigns) %>
          </form>
        </div>

        <!-- Modal Footer -->
        <%= render_modal_footer(assigns) %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # MODAL HEADER - COMPLETE IMPLEMENTATION
  # ============================================================================

  defp render_modal_header(assigns) do
    ~H"""
    <div class="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-indigo-50">
      <div class="flex items-center">
        <div class="w-12 h-12 rounded-xl flex items-center justify-center mr-4 shadow-lg"
             style={"background: linear-gradient(135deg, #{get_section_color(@section_type)} 0%, #{darken_color(get_section_color(@section_type))} 100%)"}>
          <span class="text-white text-xl"><%= get_section_icon(@section_type) %></span>
        </div>
        <div>
          <h3 class="text-xl font-bold text-gray-900">
            <%= if @editing_section, do: "Edit", else: "Create" %> <%= get_section_name(@section_type) %>
          </h3>
          <p class="text-gray-600 text-sm"><%= get_section_description(@section_type) %></p>
        </div>
      </div>
      <button type="button"
              phx-click="close_section_modal" phx-target={@myself}
              class="text-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
        </svg>
      </button>
    </div>
    """
  end

  # ============================================================================
  # ESSENTIAL FIELDS RENDERING - COMPLETE IMPLEMENTATION FOR ALL BROKEN SECTIONS
  # ============================================================================

  defp render_essential_fields(assigns) do
    essential_fields = get_essential_fields(assigns.section_type)
    assigns = assign(assigns, :essential_fields, essential_fields)

    ~H"""
    <div class="bg-white rounded-lg border border-gray-200 p-6">
      <div class="flex items-center mb-4">
        <svg class="w-5 h-5 text-blue-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 0a9 9 0 1118 0 9 9 0 01-18 0z"/>
        </svg>
        <h4 class="text-lg font-semibold text-gray-900">Essential Information</h4>
        <span class="ml-2 text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Required</span>
      </div>

      <!-- Section Title Field (Always First) -->
      <%= render_section_title_field(assigns) %>

      <!-- Essential Fields Grid -->
      <%= if @essential_fields != [] do %>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
          <%= for {field_name, field_config} <- @essential_fields do %>
            <%= render_field(field_name, field_config, assigns, "essential") %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # FIELD DEFINITIONS - FIXED FOR ALL BROKEN SECTIONS
  # ============================================================================

  defp get_essential_fields(section_type) do
    case section_type do
      # FIXED: Hero Section
      "hero" ->
        [
          {"headline", %{type: :string, required: true, placeholder: "Your Name or Professional Brand"}},
          {"tagline", %{type: :string, required: true, placeholder: "Professional Title or Key Message"}},
          {"description", %{type: :text, placeholder: "Brief introduction or elevator pitch..."}}
        ]

      # Working sections (maintain as-is)
      "intro" ->
        [
          {"story", %{type: :text, required: true, placeholder: "Tell your professional story in 2-3 paragraphs..."}}
        ]

      "contact" ->
        [
          {"email", %{type: :string, required: true, placeholder: "your@email.com"}},
          {"phone", %{type: :string, placeholder: "+1 (555) 123-4567"}},
          {"location", %{type: :string, placeholder: "City, State/Country"}}
        ]

      # FIXED: Gallery Section
      "gallery" ->
        [
          {"display_style", %{type: :select, options: ["grid", "masonry", "carousel"], default: "grid"}},
          {"items_per_row", %{type: :select, options: ["2", "3", "4"], default: "3"}},
          {"show_captions", %{type: :boolean, default: true}}
        ]

      # FIXED: Blog Section
      "blog" ->
        [
          {"blog_url", %{type: :string, required: true, placeholder: "https://yourblog.com"}},
          {"auto_sync", %{type: :boolean, default: false}},
          {"max_posts", %{type: :integer, default: 6}}
        ]

      # FIXED: Timeline Section
      "timeline" ->
        [
          {"timeline_type", %{type: :select, options: ["chronological", "reverse_chronological", "milestone"], default: "reverse_chronological"}},
          {"show_dates", %{type: :boolean, default: true}}
        ]

      # FIXED: Services Section
      "services" ->
        [
          {"service_style", %{type: :select, options: ["cards", "list", "grid"], default: "cards"}},
          {"show_pricing", %{type: :boolean, default: false}}
        ]

      # FIXED: Pricing Section
      "pricing" ->
        [
          {"currency", %{type: :select, options: ["USD", "EUR", "GBP", "CAD", "AUD"], default: "USD"}},
          {"billing_period", %{type: :select, options: ["hourly", "daily", "weekly", "monthly", "yearly", "project"], default: "project"}},
          {"show_popular", %{type: :boolean, default: true}}
        ]

      # FIXED: Code Showcase Section
      "code_showcase" ->
        [
          {"primary_language", %{type: :select, options: ["JavaScript", "Python", "Elixir", "Ruby", "Java", "Go", "Rust", "TypeScript", "PHP", "Other"], default: "JavaScript"}},
          {"repository_url", %{type: :string, placeholder: "https://github.com/yourusername"}},
          {"show_stats", %{type: :boolean, default: true}}
        ]

      # All other sections return empty list (they use items instead)
      _ ->
        []
    end
  end

  # ============================================================================
  # ENHANCED FIELDS SECTION - COMPLETE IMPLEMENTATION
  # ============================================================================

  defp render_enhanced_fields_section(assigns) do
    enhanced_fields = get_enhanced_fields(assigns.section_type)

    if enhanced_fields != [] do
      assigns = assign(assigns, :enhanced_fields, enhanced_fields)

      ~H"""
      <div class="bg-green-50 rounded-lg border border-green-200 overflow-hidden">
        <button type="button"
                phx-click="toggle_enhanced_fields" phx-target={@myself}
                class="w-full flex items-center justify-between p-4 text-left hover:bg-green-100 transition-colors">
          <div class="flex items-center">
            <svg class="w-5 h-5 text-green-600 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"/>
            </svg>
            <h4 class="text-lg font-semibold text-green-800">Enhanced Details</h4>
            <span class="ml-2 text-xs bg-green-200 text-green-700 px-2 py-1 rounded-full">Optional</span>
          </div>
          <svg class={"w-5 h-5 text-green-600 transition-transform #{if @show_enhanced_fields, do: "rotate-180", else: ""}"}
               fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>

        <%= if @show_enhanced_fields do %>
          <div class="p-6 border-t border-green-200 bg-white">
            <p class="text-sm text-gray-600 mb-4">Add more details to make your portfolio stand out.</p>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {field_name, field_config} <- @enhanced_fields do %>
                <%= render_field(field_name, field_config, assigns, "enhanced") %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
      """
    else
      ~H""
    end
  end

  # ============================================================================
  # ITEMS SECTION - COMPLETE IMPLEMENTATION WITH EDIT/DELETE/REORDER
  # ============================================================================

  defp render_essential_items_section(assigns) do
    items = get_current_items(assigns)
    assigns = assign(assigns, :items, items)

    ~H"""
    <div class="bg-purple-50 rounded-lg border border-purple-200 p-6">
      <div class="flex items-center justify-between mb-4">
        <h5 class="text-lg font-semibold text-purple-900 flex items-center">
          <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v10a2 2 0 002 2h8a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2"/>
          </svg>
          <%= get_items_label(@section_type) %>
        </h5>
        <button type="button"
                phx-click="add_item" phx-target={@myself}
                class="inline-flex items-center px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors font-medium text-sm">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
          Add <%= get_item_name(@section_type) %>
        </button>
      </div>

      <%= if @items != [] do %>
        <div class="space-y-4">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <div class="bg-white border border-purple-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <div class="flex items-center space-x-3">
                  <!-- Sort Controls -->
                  <div class="flex flex-col space-y-1">
                    <%= if index > 0 do %>
                      <button type="button"
                              phx-click="move_item_up" phx-target={@myself} phx-value-index={index}
                              class="text-gray-400 hover:text-gray-600 transition-colors"
                              title="Move up">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
                        </svg>
                      </button>
                    <% else %>
                      <div class="w-3 h-3"></div>
                    <% end %>

                    <%= if index < length(@items) - 1 do %>
                      <button type="button"
                              phx-click="move_item_down" phx-target={@myself} phx-value-index={index}
                              class="text-gray-400 hover:text-gray-600 transition-colors"
                              title="Move down">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                        </svg>
                      </button>
                    <% else %>
                      <div class="w-3 h-3"></div>
                    <% end %>
                  </div>

                  <h6 class="font-medium text-gray-900">
                    <%= get_item_name(@section_type) %> #<%= index + 1 %>
                  </h6>

                  <!-- Visibility Toggle -->
                  <button type="button"
                          phx-click="toggle_item_visibility" phx-target={@myself} phx-value-index={index}
                          class={"px-2 py-1 text-xs rounded #{if Map.get(item, "visible", true), do: "bg-green-100 text-green-700", else: "bg-gray-100 text-gray-500"}"}>
                    <%= if Map.get(item, "visible", true), do: "Visible", else: "Hidden" %>
                  </button>
                </div>

                <div class="flex items-center space-x-2">
                  <!-- Copy Item -->
                  <button type="button"
                          phx-click="copy_item" phx-target={@myself} phx-value-index={index}
                          class="text-blue-500 hover:text-blue-700 transition-colors"
                          title="Copy item">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                    </svg>
                  </button>

                  <!-- Delete Item -->
                  <button type="button"
                          phx-click="remove_item" phx-target={@myself} phx-value-index={index}
                          class="text-red-500 hover:text-red-700 transition-colors"
                          title="Delete item">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>

              <!-- Dynamic Item Fields Based on Section Type -->
              <%= render_item_fields(assigns, item, index) %>
            </div>
          <% end %>
        </div>
      <% else %>
        <%= render_empty_items_state(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # DYNAMIC ITEM FIELDS - COMPLETE IMPLEMENTATION FOR ALL SECTION TYPES
  # ============================================================================

  defp render_item_fields(assigns, item, index) do
    assigns = assigns |> assign(:item, item) |> assign(:index, index)

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-sm">
      <%= case @section_type do %>
        <% "experience" -> %>
          <input type="text" placeholder="Job Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Company *"
                 name={"items[#{@index}][company]"}
                 value={Map.get(@item, "company", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Start Date *"
                 name={"items[#{@index}][start_date]"}
                 value={Map.get(@item, "start_date", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="End Date (or 'Present')"
                 name={"items[#{@index}][end_date]"}
                 value={Map.get(@item, "end_date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "education" -> %>
          <input type="text" placeholder="Degree/Certificate *"
                 name={"items[#{@index}][degree]"}
                 value={Map.get(@item, "degree", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Institution *"
                 name={"items[#{@index}][institution]"}
                 value={Map.get(@item, "institution", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Start Date"
                 name={"items[#{@index}][start_date]"}
                 value={Map.get(@item, "start_date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Graduation Date"
                 name={"items[#{@index}][graduation_date]"}
                 value={Map.get(@item, "graduation_date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description"
                    name={"items[#{@index}][description]"}
                    rows="2"
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "skills" -> %>
          <input type="text" placeholder="Skill Name *"
                 name={"items[#{@index}][name]"}
                 value={Map.get(@item, "name", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <select name={"items[#{@index}][level]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="beginner" selected={Map.get(@item, "level") == "beginner"}>Beginner</option>
            <option value="intermediate" selected={Map.get(@item, "level") == "intermediate"}>Intermediate</option>
            <option value="advanced" selected={Map.get(@item, "level") == "advanced"}>Advanced</option>
            <option value="expert" selected={Map.get(@item, "level") == "expert"}>Expert</option>
          </select>
          <select name={"items[#{@index}][category]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="technical" selected={Map.get(@item, "category") == "technical"}>Technical</option>
            <option value="programming" selected={Map.get(@item, "category") == "programming"}>Programming</option>
            <option value="design" selected={Map.get(@item, "category") == "design"}>Design</option>
            <option value="soft_skills" selected={Map.get(@item, "category") == "soft_skills"}>Soft Skills</option>
            <option value="languages" selected={Map.get(@item, "category") == "languages"}>Languages</option>
          </select>
          <input type="number" placeholder="Years Experience"
                 name={"items[#{@index}][years_experience]"}
                 value={Map.get(@item, "years_experience", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />

        <% "projects" -> %>
          <input type="text" placeholder="Project Name *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Technologies Used"
                 name={"items[#{@index}][technologies]"}
                 value={Map.get(@item, "technologies", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="url" placeholder="Project URL"
                 name={"items[#{@index}][url]"}
                 value={Map.get(@item, "url", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="url" placeholder="GitHub URL"
                 name={"items[#{@index}][github_url]"}
                 value={Map.get(@item, "github_url", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "certifications" -> %>
          <input type="text" placeholder="Certification Name *"
                 name={"items[#{@index}][name]"}
                 value={Map.get(@item, "name", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Issuing Authority *"
                 name={"items[#{@index}][issuer]"}
                 value={Map.get(@item, "issuer", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Issue Date"
                 name={"items[#{@index}][issue_date]"}
                 value={Map.get(@item, "issue_date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Expiry Date"
                 name={"items[#{@index}][expiry_date]"}
                 value={Map.get(@item, "expiry_date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Credential ID"
                 name={"items[#{@index}][credential_id]"}
                 value={Map.get(@item, "credential_id", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="url" placeholder="Verification URL"
                 name={"items[#{@index}][verification_url]"}
                 value={Map.get(@item, "verification_url", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />

        <% "achievements" -> %>
          <input type="text" placeholder="Achievement Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Date Achieved"
                 name={"items[#{@index}][date]"}
                 value={Map.get(@item, "date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <select name={"items[#{@index}][type]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="award" selected={Map.get(@item, "type") == "award"}>Award</option>
            <option value="recognition" selected={Map.get(@item, "type") == "recognition"}>Recognition</option>
            <option value="milestone" selected={Map.get(@item, "type") == "milestone"}>Milestone</option>
            <option value="publication" selected={Map.get(@item, "type") == "publication"}>Publication</option>
          </select>
          <input type="text" placeholder="Awarding Organization"
                 name={"items[#{@index}][organization]"}
                 value={Map.get(@item, "organization", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "collaborations" -> %>
          <input type="text" placeholder="Project/Collaboration Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Partner/Organization *"
                 name={"items[#{@index}][partner]"}
                 value={Map.get(@item, "partner", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Your Role"
                 name={"items[#{@index}][role]"}
                 value={Map.get(@item, "role", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Date/Duration"
                 name={"items[#{@index}][date]"}
                 value={Map.get(@item, "date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description & Outcomes *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "testimonials" -> %>
          <input type="text" placeholder="Client/Colleague Name *"
                 name={"items[#{@index}][name]"}
                 value={Map.get(@item, "name", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Title & Company"
                 name={"items[#{@index}][title_company]"}
                 value={Map.get(@item, "title_company", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <select name={"items[#{@index}][rating]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="">No Rating</option>
            <option value="5" selected={Map.get(@item, "rating") == "5"}>★★★★★ (5 stars)</option>
            <option value="4" selected={Map.get(@item, "rating") == "4"}>★★★★☆ (4 stars)</option>
            <option value="3" selected={Map.get(@item, "rating") == "3"}>★★★☆☆ (3 stars)</option>
          </select>
          <input type="text" placeholder="Project/Context"
                 name={"items[#{@index}][project]"}
                 value={Map.get(@item, "project", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Testimonial Text *"
                    name={"items[#{@index}][testimonial]"}
                    rows="4"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "testimonial", "") %></textarea>

        <% "services" -> %>
          <input type="text" placeholder="Service Name *"
                 name={"items[#{@index}][name]"}
                 value={Map.get(@item, "name", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Pricing (optional)"
                 name={"items[#{@index}][price]"}
                 value={Map.get(@item, "price", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Duration/Timeline"
                 name={"items[#{@index}][duration]"}
                 value={Map.get(@item, "duration", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <select name={"items[#{@index}][category]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="consulting" selected={Map.get(@item, "category") == "consulting"}>Consulting</option>
            <option value="development" selected={Map.get(@item, "category") == "development"}>Development</option>
            <option value="design" selected={Map.get(@item, "category") == "design"}>Design</option>
            <option value="strategy" selected={Map.get(@item, "category") == "strategy"}>Strategy</option>
            <option value="other" selected={Map.get(@item, "category") == "other"}>Other</option>
          </select>
          <textarea placeholder="Service Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "published_articles" -> %>
          <input type="text" placeholder="Article Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Publication/Platform *"
                 name={"items[#{@index}][publication]"}
                 value={Map.get(@item, "publication", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Publication Date"
                 name={"items[#{@index}][date]"}
                 value={Map.get(@item, "date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="url" placeholder="Article URL"
                 name={"items[#{@index}][url]"}
                 value={Map.get(@item, "url", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Tags (comma-separated)"
                 name={"items[#{@index}][tags]"}
                 value={Map.get(@item, "tags", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Article Summary"
                    name={"items[#{@index}][summary]"}
                    rows="2"
                    class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "summary", "") %></textarea>

        <% "timeline" -> %>
          <input type="text" placeholder="Event/Milestone Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Date *"
                 name={"items[#{@index}][date]"}
                 value={Map.get(@item, "date", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <select name={"items[#{@index}][type]"}
                  class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500">
            <option value="career" selected={Map.get(@item, "type") == "career"}>Career</option>
            <option value="education" selected={Map.get(@item, "type") == "education"}>Education</option>
            <option value="project" selected={Map.get(@item, "type") == "project"}>Project</option>
            <option value="achievement" selected={Map.get(@item, "type") == "achievement"}>Achievement</option>
            <option value="personal" selected={Map.get(@item, "type") == "personal"}>Personal</option>
          </select>
          <input type="text" placeholder="Location/Organization"
                 name={"items[#{@index}][location]"}
                 value={Map.get(@item, "location", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>

        <% "custom" -> %>
          <input type="text" placeholder="Item Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Subtitle/Category"
                 name={"items[#{@index}][subtitle]"}
                 value={Map.get(@item, "subtitle", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="url" placeholder="Related URL"
                 name={"items[#{@index}][url]"}
                 value={Map.get(@item, "url", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <input type="text" placeholder="Date/Period"
                 name={"items[#{@index}][date]"}
                 value={Map.get(@item, "date", "")}
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Content/Description *"
                    name={"items[#{@index}][content]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "content", "") %></textarea>

        <% _ -> %>
          <input type="text" placeholder="Title *"
                 name={"items[#{@index}][title]"}
                 value={Map.get(@item, "title", "")}
                 required
                 class="px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500" />
          <textarea placeholder="Description *"
                    name={"items[#{@index}][description]"}
                    rows="3"
                    required
                    class="md:col-span-2 px-3 py-2 border border-gray-300 rounded text-sm focus:ring-2 focus:ring-blue-500"><%= Map.get(@item, "description", "") %></textarea>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # MEDIA UPLOAD SECTION - INTEGRATED WITH EXISTING SYSTEM
  # ============================================================================

  defp render_media_upload_section(assigns) do
    ~H"""
    <div class="bg-orange-50 rounded-lg border border-orange-200 p-6">
      <div class="flex items-center justify-between mb-4">
        <h5 class="text-lg font-semibold text-orange-900 flex items-center">
          <svg class="w-5 h-5 mr-2 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          Media Files
        </h5>
        <span class="text-xs bg-orange-200 text-orange-700 px-2 py-1 rounded-full">
          <%= get_supported_media_text(@section_type) %>
        </span>
      </div>

      <!-- File Upload Area -->
      <div class="border-2 border-dashed border-orange-300 rounded-lg p-6 text-center"
           phx-drop-target={@uploads.media.ref}
           id="media-dropzone">
        <div class="flex flex-col items-center">
          <svg class="w-12 h-12 text-orange-400 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
          <p class="text-base text-gray-600 mb-4">Drag and drop files here or click to browse</p>
          <label class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-orange-600 hover:bg-orange-700 cursor-pointer">
            Browse Files
            <.live_file_input upload={@uploads.media} class="sr-only" />
          </label>
          <p class="text-xs text-gray-500 mt-2">
            Max size: 50MB • Accepted: <%= Enum.join(get_accepted_file_types(@section_type), ", ") %>
          </p>
        </div>
      </div>

      <!-- Upload Progress & Preview -->
      <%= if !Enum.empty?(@uploads.media.entries) do %>
        <div class="mt-6">
          <h6 class="text-base font-medium text-gray-900 mb-3">Selected Files</h6>
          <div class="space-y-3">
            <%= for entry <- @uploads.media.entries do %>
              <div class="flex items-center bg-white p-3 rounded-lg border border-orange-200">
                <div class="flex-shrink-0 mr-3">
                  <%= if String.starts_with?(entry.client_type, "image/") do %>
                    <.live_img_preview entry={entry} width="48" height="48" class="object-cover rounded" />
                  <% else %>
                    <div class="w-12 h-12 bg-gray-200 rounded flex items-center justify-center text-gray-500">
                      <%= get_file_type_icon(entry.client_type) %>
                    </div>
                  <% end %>
                </div>
                <div class="flex-1">
                  <p class="text-sm font-medium text-gray-900"><%= entry.client_name %></p>
                  <p class="text-xs text-gray-500">
                    <%= format_file_size(entry.client_size) %> •
                    <%= if entry.progress > 0 do %>
                      <%= entry.progress %>% uploaded
                    <% else %>
                      Ready to upload
                    <% end %>
                  </p>
                  <%= if entry.progress > 0 and entry.progress < 100 do %>
                    <div class="w-full bg-gray-200 rounded-full h-1.5 mt-1">
                      <div class="bg-orange-600 h-1.5 rounded-full" style={"width: #{entry.progress}%"}></div>
                    </div>
                  <% end %>
                </div>
                <button type="button"
                        phx-click="cancel_upload" phx-target={@myself} phx-value-ref={entry.ref}
                        class="text-red-500 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <!-- Upload Errors -->
      <%= for err <- upload_errors(@uploads.media) do %>
        <div class="mt-2 text-sm text-red-600">
          <%= error_to_string(err) %>
        </div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # FIELD RENDERING - COMPLETE IMPLEMENTATION FOR ALL TYPES
  # ============================================================================

  defp render_field(field_name, field_config, assigns, field_level) do
    field_name_str = to_string(field_name)
    field_type = Map.get(field_config, :type, :string)
    required = Map.get(field_config, :required, false)
    placeholder = Map.get(field_config, :placeholder, "")
    current_value = get_field_value(assigns.form_data, field_name_str, field_config)

    assigns = assigns
    |> assign(:field_name_str, field_name_str)
    |> assign(:field_type, field_type)
    |> assign(:required, required)
    |> assign(:placeholder, placeholder)
    |> assign(:current_value, current_value)
    |> assign(:field_config, field_config)

    ~H"""
    <div class="field-container">
      <%= case @field_type do %>
        <% :string -> %>
          <%= render_string_field(assigns) %>
        <% :text -> %>
          <%= render_text_field(assigns) %>
        <% :select -> %>
          <%= render_select_field(assigns) %>
        <% :boolean -> %>
          <%= render_boolean_field(assigns) %>
        <% :integer -> %>
          <%= render_integer_field(assigns) %>
        <% :social_links -> %>
          <%= render_social_links_field(assigns) %>
        <% _ -> %>
          <%= render_string_field(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_string_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= get_field_label(@field_name_str) %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <input type="text"
             name={@field_name_str}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_text_field(assigns) do
    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= get_field_label(@field_name_str) %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <textarea name={@field_name_str}
                placeholder={@placeholder}
                required={@required}
                rows="4"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= @current_value %></textarea>
    </div>
    """
  end

  defp render_select_field(assigns) do
    options = Map.get(assigns.field_config, :options, [])
    assigns = assign(assigns, :options, options)

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= get_field_label(@field_name_str) %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <select name={@field_name_str}
              required={@required}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
        <%= for option <- @options do %>
          <option value={option} selected={@current_value == option}>
            <%= String.capitalize(option) %>
          </option>
        <% end %>
      </select>
    </div>
    """
  end

  defp render_boolean_field(assigns) do
    checked = @current_value == true or @current_value == "true"
    assigns = assign(assigns, :checked, checked)

    ~H"""
    <div class="flex items-center">
      <input type="checkbox"
             name={@field_name_str}
             value="true"
             checked={@checked}
             class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
      <label class="ml-2 block text-sm text-gray-700">
        <%= get_field_label(@field_name_str) %>
      </label>
    </div>
    """
  end

  defp render_integer_field(assigns) do
    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">
        <%= get_field_label(@field_name_str) %>
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>
      <input type="number"
             name={@field_name_str}
             value={@current_value}
             placeholder={@placeholder}
             required={@required}
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
    </div>
    """
  end

  defp render_social_links_field(assigns) do
    social_platforms = ["linkedin", "twitter", "github", "website", "instagram", "facebook"]
    current_links = get_social_links_value(assigns.form_data)
    assigns = assigns |> assign(:social_platforms, social_platforms) |> assign(:current_links, current_links)

    ~H"""
    <div class="md:col-span-2">
      <label class="block text-sm font-medium text-gray-700 mb-3">
        Social Links
      </label>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <%= for platform <- @social_platforms do %>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">
              <%= String.capitalize(platform) %>
            </label>
            <input type="url"
                   name={"social_links[#{platform}]"}
                   value={Map.get(@current_links, platform, "")}
                   placeholder={"https://#{platform}.com/yourprofile"}
                   class="w-full px-3 py-2 text-sm border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SECTION TITLE FIELD - COMPLETE IMPLEMENTATION
  # ============================================================================

  defp render_section_title_field(assigns) do
    current_title = case assigns.editing_section do
      %{title: title} when is_binary(title) -> title
      _ -> Map.get(assigns.form_data, "title", get_default_section_title(assigns.section_type))
    end

    assigns = assign(assigns, :current_title, current_title)

    ~H"""
    <div class="mb-6">
      <label class="block text-sm font-medium text-gray-700 mb-2">
        Section Title <span class="text-red-500">*</span>
      </label>
      <input type="text"
             name="title"
             value={@current_title}
             placeholder={"Enter custom title for your #{get_section_name(@section_type)} section"}
             required
             maxlength="100"
             class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-medium" />
      <p class="text-xs text-gray-500 mt-1">
        This title will appear as the section heading in your portfolio.
        Default: "<%= get_default_section_title(@section_type) %>"
      </p>
    </div>
    """
  end

  # ============================================================================
  # MODAL FOOTER - COMPLETE IMPLEMENTATION
  # ============================================================================

  defp render_modal_footer(assigns) do
    ~H"""
    <div class="border-t border-gray-200 px-6 py-4 bg-gray-50">
      <div class="flex items-center justify-end space-x-3">
        <button type="button"
                phx-click="close_section_modal" phx-target={@myself}
                class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors font-medium">
          Cancel
        </button>
        <button type="submit"
                form="section-form"
                class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-semibold shadow-sm">
          <%= if @editing_section, do: "Update Section", else: "Create Section" %>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # VALIDATION ERRORS - COMPLETE IMPLEMENTATION
  # ============================================================================

  defp render_validation_errors(assigns) do
    if map_size(assigns.validation_errors) > 0 do
      ~H"""
      <div class="bg-red-50 border border-red-200 rounded-lg p-4">
        <h4 class="text-red-800 font-semibold">Please fix the following errors:</h4>
        <ul class="text-red-700 text-sm mt-2 space-y-1">
          <%= for {field, message} <- @validation_errors do %>
            <li>• <%= field %>: <%= message %></li>
          <% end %>
        </ul>
      </div>
      """
    else
      ~H""
    end
  end

  defp render_empty_items_state(assigns) do
    ~H"""
    <div class="text-center py-8">
      <div class="w-16 h-16 mx-auto mb-4 bg-purple-100 rounded-full flex items-center justify-center">
        <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
      </div>
      <h5 class="text-lg font-semibold text-gray-900 mb-2">No <%= get_items_label(@section_type) %> Added</h5>
      <p class="text-gray-600 mb-6">Start building your <%= String.downcase(get_items_label(@section_type)) %> section by adding your first <%= String.downcase(get_item_name(@section_type)) %>.</p>
      <button type="button"
              phx-click="add_item" phx-target={@myself}
              class="inline-flex items-center px-6 py-3 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors font-semibold">
        <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
        Add Your First <%= get_item_name(@section_type) %>
      </button>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS - COMPLETE IMPLEMENTATIONS
  # ============================================================================

  @impl true
  def handle_event("toggle_enhanced_fields", _params, socket) do
    {:noreply, assign(socket, :show_enhanced_fields, !socket.assigns.show_enhanced_fields)}
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    current_items = get_current_items(socket.assigns)
    new_item = get_default_item_for_section(socket.assigns.section_type)
    updated_items = current_items ++ [new_item]

    form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, form_data)}
  end

  @impl true
  def handle_event("remove_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_items = get_current_items(socket.assigns)
    updated_items = List.delete_at(current_items, index)

    form_data = Map.put(socket.assigns.form_data, "items", updated_items)

    {:noreply, assign(socket, :form_data, form_data)}
  end

  @impl true
  def handle_event("move_item_up", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_items = get_current_items(socket.assigns)

    if index > 0 do
      updated_items = swap_items(current_items, index - 1, index)
      form_data = Map.put(socket.assigns.form_data, "items", updated_items)
      {:noreply, assign(socket, :form_data, form_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_item_down", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_items = get_current_items(socket.assigns)

    if index < length(current_items) - 1 do
      updated_items = swap_items(current_items, index, index + 1)
      form_data = Map.put(socket.assigns.form_data, "items", updated_items)
      {:noreply, assign(socket, :form_data, form_data)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("copy_item", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_items = get_current_items(socket.assigns)

    case Enum.at(current_items, index) do
      nil -> {:noreply, socket}
      item ->
        # Create a copy with "(Copy)" suffix in title
        copied_item = Map.update(item, "title", "", fn title ->
          if title == "", do: "Copy", else: "#{title} (Copy)"
        end)

        updated_items = List.insert_at(current_items, index + 1, copied_item)
        form_data = Map.put(socket.assigns.form_data, "items", updated_items)
        {:noreply, assign(socket, :form_data, form_data)}
    end
  end

  @impl true
  def handle_event("toggle_item_visibility", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current_items = get_current_items(socket.assigns)

    updated_items = List.update_at(current_items, index, fn item ->
      current_visibility = Map.get(item, "visible", true)
      Map.put(item, "visible", !current_visibility)
    end)

    form_data = Map.put(socket.assigns.form_data, "items", updated_items)
    {:noreply, assign(socket, :form_data, form_data)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :media, ref)}
  end

  @impl true
  def handle_event("save_section", params, socket) do
    IO.puts("🔧 SAVE_SECTION RAW PARAMS:")
    IO.puts("🔧 #{inspect(params, pretty: true)}")

    socket = assign(socket, :save_status, :saving)

    # Process uploaded media files first
    uploaded_media = process_uploaded_media(socket, params)

    {form_data, validation_errors} = process_form_params(params, socket.assigns.section_type, uploaded_media)

    if validation_errors == %{} do
      send(self(), {:save_section, form_data, socket.assigns.editing_section})
      {:noreply, assign(socket, :save_status, :saved)}
    else
      socket = socket
      |> assign(:form_data, form_data)
      |> assign(:validation_errors, validation_errors)
      |> assign(:save_status, :error)

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    send(self(), :close_section_modal)
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal_on_escape", _params, socket) do
    send(self(), :close_section_modal)
    {:noreply, socket}
  end

  # ============================================================================
  # MEDIA PROCESSING - INTEGRATION WITH EXISTING SYSTEM
  # ============================================================================

  defp process_uploaded_media(socket, _params) do
    uploaded_files = consume_uploaded_entries(socket, :media, fn %{path: path} = _upload_entry, entry ->
      # Use existing media system
      case Media.process_upload(entry, socket.assigns.current_user, nil, %{
        section_type: socket.assigns.section_type,
        portfolio_id: socket.assigns.portfolio_id
      }) do
        {:ok, media_file} -> {:ok, media_file}
        {:error, reason} -> {:error, reason}
      end
    end)

    # Filter successful uploads
    Enum.filter(uploaded_files, fn
      {:ok, _media_file} -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, media_file} -> media_file end)
  end

  # ============================================================================
  # FORM PROCESSING - FIXED FOR ALL BROKEN SECTIONS
  # ============================================================================

  defp process_form_params(params, section_type, uploaded_media \\ []) do
    # Extract basic form data
    form_data = %{
      "title" => Map.get(params, "title", ""),
      "visible" => Map.get(params, "visible") != "false",
      "section_type" => section_type
    }

    # Process section-specific content
    content = process_section_specific_content(params, section_type, uploaded_media)

    # Merge content into form_data
    final_data = Map.merge(form_data, content)

    # Basic validation
    validation_errors = validate_form_data(final_data, section_type)

    {final_data, validation_errors}
  end

  defp process_section_specific_content(params, section_type, uploaded_media) do
    base_content = case section_type do
      # FIXED: Hero Section
      "hero" ->
        %{
          "headline" => Map.get(params, "headline", ""),
          "tagline" => Map.get(params, "tagline", ""),
          "description" => Map.get(params, "description", ""),
          "cta_text" => Map.get(params, "cta_text", ""),
          "cta_link" => Map.get(params, "cta_link", ""),
          "social_links" => process_social_links_from_params(params)
        }

      # Working sections (maintain as-is)
      "intro" ->
        %{
          "story" => Map.get(params, "story", ""),
          "specialties" => Map.get(params, "specialties", ""),
          "years_experience" => parse_integer(Map.get(params, "years_experience", "0")),
          "current_focus" => Map.get(params, "current_focus", ""),
          "fun_fact" => Map.get(params, "fun_fact", "")
        }

      "contact" ->
        %{
          "email" => Map.get(params, "email", ""),
          "phone" => Map.get(params, "phone", ""),
          "location" => Map.get(params, "location", ""),
          "website" => Map.get(params, "website", ""),
          "availability" => Map.get(params, "availability", ""),
          "timezone" => Map.get(params, "timezone", ""),
          "preferred_contact" => Map.get(params, "preferred_contact", ""),
          "social_links" => process_social_links_from_params(params)
        }

      # FIXED: Gallery Section
      "gallery" ->
        %{
          "display_style" => Map.get(params, "display_style", "grid"),
          "items_per_row" => Map.get(params, "items_per_row", "3"),
          "show_captions" => Map.get(params, "show_captions") == "true",
          "enable_lightbox" => Map.get(params, "enable_lightbox") == "true"
        }

      # FIXED: Blog Section
      "blog" ->
        %{
          "blog_url" => Map.get(params, "blog_url", ""),
          "auto_sync" => Map.get(params, "auto_sync") == "true",
          "max_posts" => parse_integer(Map.get(params, "max_posts", "6")),
          "show_dates" => Map.get(params, "show_dates") == "true"
        }

      # FIXED: Timeline Section (has items)
      "timeline" ->
        items = process_items_from_params(params, section_type)
        %{
          "timeline_type" => Map.get(params, "timeline_type", "reverse_chronological"),
          "show_dates" => Map.get(params, "show_dates") == "true",
          "items" => items
        }

      # FIXED: Services Section (has items)
      "services" ->
        items = process_items_from_params(params, section_type)
        %{
          "service_style" => Map.get(params, "service_style", "cards"),
          "show_pricing" => Map.get(params, "show_pricing") == "true",
          "items" => items
        }

      # FIXED: Pricing Section (has items)
      "pricing" ->
        items = process_items_from_params(params, section_type)
        %{
          "currency" => Map.get(params, "currency", "USD"),
          "billing_period" => Map.get(params, "billing_period", "project"),
          "items" => items
        }

      # Item-based sections (FIXED)
      section_type when section_type in ["experience", "education", "skills", "projects", "certifications",
                                         "achievements", "testimonials", "collaborations", "published_articles", "custom"] ->
        items = process_items_from_params(params, section_type)
        IO.puts("🔧 Processed #{length(items)} items for #{section_type}: #{inspect(items)}")
        %{
          "items" => items
        }

      # Fallback
      _ ->
        %{
          "description" => Map.get(params, "description", "")
        }
    end

    # Add media files if any were uploaded
    if uploaded_media != [] do
      Map.put(base_content, "media_files", uploaded_media)
    else
      base_content
    end
  end

  defp process_social_links_from_params(params) do
    social_platforms = ["linkedin", "twitter", "github", "website", "instagram", "facebook"]

    Enum.reduce(social_platforms, %{}, fn platform, acc ->
      key = "social_links[#{platform}]"
      case Map.get(params, key) do
        value when is_binary(value) and value != "" ->
          Map.put(acc, platform, value)
        _ ->
          acc
      end
    end)
  end

  defp process_items_from_params(params, section_type) do
    IO.puts("🔧 Raw params for items: #{inspect(Map.get(params, "items", %{}))}")

    case Map.get(params, "items") do
      # Handle new format: items => %{"0" => %{"title" => "...", "company" => "..."}}
      items_map when is_map(items_map) ->
        items_list = items_map
        |> Enum.map(fn {_index, item_data} -> item_data end)
        |> Enum.reject(fn item ->
          item == %{} or (Map.get(item, "title", "") == "" and Map.get(item, "name", "") == "")
        end)

        IO.puts("🔧 Final processed items: #{inspect(items_list, pretty: true)}")
        items_list

      # Handle old format: items[0][field] (fallback)
      _ ->
        items_data = params
        |> Enum.filter(fn {key, _value} -> String.starts_with?(key, "items[") end)
        |> Enum.group_by(fn {key, _value} ->
          case Regex.run(~r/items\[(\d+)\]/, key) do
            [_, index] -> String.to_integer(index)
            _ -> nil
          end
        end)
        |> Enum.filter(fn {index, _fields} -> index != nil end)
        |> Enum.sort_by(fn {index, _fields} -> index end)
        |> Enum.map(fn {_index, fields} ->
          Enum.reduce(fields, %{}, fn {key, value}, item_acc ->
            case Regex.run(~r/items\[\d+\]\[(.+)\]/, key) do
              [_, field_name] -> Map.put(item_acc, field_name, value)
              _ -> item_acc
            end
          end)
        end)
        |> Enum.reject(fn item ->
          item == %{} or (Map.get(item, "title", "") == "" and Map.get(item, "name", "") == "")
        end)

        IO.puts("🔧 Final processed items: #{inspect(items_data, pretty: true)}")
        items_data
    end
  end

  defp parse_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      :error -> 0
    end
  end
  defp parse_integer(value) when is_integer(value), do: value
  defp parse_integer(_), do: 0

  defp validate_form_data(form_data, section_type) do
    errors = %{}

    # Validate title
    errors = if String.trim(Map.get(form_data, "title", "")) == "" do
      Map.put(errors, "title", "Title is required")
    else
      errors
    end

    # Validate section-specific required fields
    essential_fields = get_essential_fields(section_type)

    Enum.reduce(essential_fields, errors, fn {field_name, field_config}, acc_errors ->
      is_required = Map.get(field_config, :required, false)
      value = Map.get(form_data, to_string(field_name), "")

      if is_required and (is_nil(value) or String.trim(to_string(value)) == "") do
        Map.put(acc_errors, to_string(field_name), "This field is required")
      else
        acc_errors
      end
    end)
  end

  # ============================================================================
  # ENHANCED FIELDS - COMPLETE FOR ALL SECTIONS
  # ============================================================================

  defp get_enhanced_fields(section_type) do
    case section_type do
      # Essential sections enhanced fields
      "hero" ->
        [
          {"cta_text", %{type: :string, placeholder: "Call-to-action button text (e.g., 'Get In Touch')"}},
          {"cta_link", %{type: :string, placeholder: "Where the CTA button should link to"}},
          {"background_type", %{type: :select, options: ["color", "image", "video"], default: "color"}}
        ]

      "contact" ->
        [
          {"website", %{type: :string, placeholder: "https://yourwebsite.com"}},
          {"availability", %{type: :text, placeholder: "Available for new projects, consulting, etc."}},
          {"timezone", %{type: :string, placeholder: "EST, PST, GMT+1, etc."}},
          {"preferred_contact", %{type: :select, options: ["Email", "Phone", "Website Form", "Social Media"], default: "Email"}}
        ]

      "intro" ->
        [
          {"specialties", %{type: :string, placeholder: "Key areas of expertise (comma-separated)"}},
          {"years_experience", %{type: :integer, placeholder: "Years of professional experience"}},
          {"current_focus", %{type: :string, placeholder: "What you're currently focused on"}},
          {"fun_fact", %{type: :string, placeholder: "An interesting fact about yourself"}}
        ]

      # Media sections enhanced fields
      "gallery" ->
        [
          {"enable_lightbox", %{type: :boolean, default: true}},
          {"auto_play", %{type: :boolean, default: false}},
          {"show_metadata", %{type: :boolean, default: false}}
        ]

      "blog" ->
        [
          {"description", %{type: :text, placeholder: "Brief description of your blog content"}},
          {"featured_tags", %{type: :string, placeholder: "Main topics you write about (comma-separated)"}},
          {"show_dates", %{type: :boolean, default: true}}
        ]

      _ ->
        []
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS - ALL 18 SECTION TYPES COMPLETE
  # ============================================================================

  defp get_default_section_title(section_type) do
    case section_type do
      # Essential sections (3)
      "hero" -> "Welcome"
      "intro" -> "About Me"
      "contact" -> "Get In Touch"

      # Professional sections (6)
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "My Projects"
      "certifications" -> "Certifications"
      "services" -> "Services"

      # Content sections (5)
      "achievements" -> "Achievements & Awards"
      "testimonials" -> "What People Say"
      "published_articles" -> "My Writing"
      "collaborations" -> "Collaborations"
      "timeline" -> "My Journey"

      # Media sections (2)
      "gallery" -> "Gallery"
      "blog" -> "Blog"

      # Flexible (2)
      "pricing" -> "Pricing"
      "custom" -> "Custom Items"

      _ -> "Items"
    end
  end

  defp get_item_name(section_type) do
    case section_type do
      # Professional sections (6)
      "experience" -> "Job"
      "education" -> "Degree/Course"
      "skills" -> "Skill"
      "projects" -> "Project"
      "certifications" -> "Certification"
      "services" -> "Service"

      # Content sections (5)
      "achievements" -> "Achievement"
      "testimonials" -> "Testimonial"
      "published_articles" -> "Article"
      "collaborations" -> "Collaboration"
      "timeline" -> "Event"

      # Flexible (2)
      "pricing" -> "Package"
      "custom" -> "Item"

      _ -> "Item"
    end
  end

  # ============================================================================
  # MEDIA HELPER FUNCTIONS
  # ============================================================================

  defp get_accepted_file_types(section_type) do
    case section_type do
      "gallery" -> [".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".webm"]
      "projects" -> [".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".pdf", ".doc", ".docx"]
      "hero" -> [".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".webm"]
      "services" -> [".jpg", ".jpeg", ".png", ".gif", ".pdf"]
      "testimonials" -> [".jpg", ".jpeg", ".png"]
      "achievements" -> [".jpg", ".jpeg", ".png", ".pdf", ".doc", ".docx"]
      "collaborations" -> [".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".pdf", ".doc", ".docx"]
      "custom" -> [".jpg", ".jpeg", ".png", ".gif", ".mp4", ".mov", ".pdf", ".doc", ".docx", ".xls", ".xlsx"]
      _ -> [".jpg", ".jpeg", ".png", ".gif"]
    end
  end

  defp get_supported_media_text(section_type) do
    case section_type do
      "gallery" -> "Images & Videos"
      "projects" -> "Images, Videos & Documents"
      "hero" -> "Images & Videos"
      "services" -> "Images & PDFs"
      "testimonials" -> "Profile Images"
      "achievements" -> "Images & Documents"
      "collaborations" -> "All Media Types"
      "custom" -> "All File Types"
      _ -> "Images Only"
    end
  end

  defp get_file_type_icon(mime_type) do
    cond do
      String.starts_with?(mime_type, "image/") -> "🖼️"
      String.starts_with?(mime_type, "video/") -> "🎬"
      String.starts_with?(mime_type, "audio/") -> "🎵"
      String.contains?(mime_type, "pdf") -> "📄"
      String.contains?(mime_type, "word") or String.contains?(mime_type, "document") -> "📝"
      String.contains?(mime_type, "excel") or String.contains?(mime_type, "sheet") -> "📊"
      true -> "📁"
    end
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 1)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "0 B"

  defp error_to_string(:too_large), do: "File is too large (max 50MB)"
  defp error_to_string(:too_many_files), do: "Too many files (max 10)"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{error}"

  # ============================================================================
  # FORM PROCESSING - COMPLETE IMPLEMENTATIONS FOR ALL 18 TYPES
  # ============================================================================

  defp get_default_form_data(section_type) do
    base_data = %{
      "title" => get_default_section_title(section_type),
      "visible" => true
    }

    # Add section-specific defaults
    section_defaults = case section_type do
      "hero" ->
        %{
          "headline" => "",
          "tagline" => ""
        }
      "contact" ->
        %{
          "email" => "",
          "social_links" => %{}
        }
      "gallery" ->
        %{
          "display_style" => "grid",
          "items_per_row" => "3"
        }
      "blog" ->
        %{
          "auto_sync" => false
        }
      "timeline" ->
        %{
          "timeline_type" => "reverse_chronological"
        }
      "services" ->
        %{
          "service_style" => "cards"
        }
      "pricing" ->
        %{
          "currency" => "USD",
          "billing_period" => "project"
        }
      _ ->
        %{}
    end

    Map.merge(base_data, section_defaults)
  end

  defp extract_content_for_editing(content, title, section_type) do
    base_data = %{
      "title" => title,
      "section_type" => to_string(section_type),
      "visible" => true
    }

    case content do
      content when is_map(content) ->
        Map.merge(base_data, content)
      _ ->
        base_data
    end
  end

  defp build_form_changeset(form_data, section_type) do
    types = get_form_field_types(section_type)
    {%{}, types}
    |> Ecto.Changeset.cast(form_data, Map.keys(types))
  end

  defp get_form_field_types(section_type) do
    base_types = %{
      title: :string,
      section_type: :string,
      visible: :boolean
    }

    section_specific_types = case section_type do
      # Essential sections (3)
      "hero" ->
        %{
          headline: :string,
          tagline: :string,
          description: :string,
          cta_text: :string,
          cta_link: :string,
          background_type: :string
        }

      "intro" ->
        %{
          story: :string,
          specialties: :string,
          years_experience: :integer,
          current_focus: :string,
          fun_fact: :string
        }

      "contact" ->
        %{
          email: :string,
          phone: :string,
          location: :string,
          website: :string,
          availability: :string,
          timezone: :string,
          preferred_contact: :string
        }

      # Media sections (2)
      "gallery" ->
        %{
          display_style: :string,
          items_per_row: :string,
          show_captions: :boolean,
          enable_lightbox: :boolean,
          auto_play: :boolean,
          show_metadata: :boolean
        }

      "blog" ->
        %{
          blog_url: :string,
          auto_sync: :boolean,
          description: :string,
          featured_tags: :string,
          max_posts: :integer,
          show_dates: :boolean
        }

      # Content sections (5)
      "timeline" ->
        %{
          timeline_type: :string,
          description: :string,
          show_dates: :boolean,
          compact_view: :boolean,
          color_scheme: :string
        }

      "services" ->
        %{
          service_style: :string,
          show_pricing: :boolean
        }

      "pricing" ->
        %{
          currency: :string,
          billing_period: :string
        }

      # All other sections with items
      _ ->
        %{}
    end

    Map.merge(base_types, section_specific_types)
  end

  defp get_field_value(form_data, field_name, field_config) do
    default_value = Map.get(field_config, :default, "")
    Map.get(form_data, field_name, default_value)
  end

  defp get_social_links_value(form_data) do
    case Map.get(form_data, "social_links") do
      links when is_map(links) -> links
      _ -> %{}
    end
  end

  defp get_current_items(assigns) do
    case Map.get(assigns.form_data, "items") do
      items when is_list(items) -> items
      _ -> []
    end
  end

  defp get_default_item_for_section(section_type) do
    case section_type do
      # Professional sections (6)
      "experience" ->
        %{
          "title" => "",
          "company" => "",
          "description" => "",
          "start_date" => "",
          "end_date" => "",
          "visible" => true
        }

      "education" ->
        %{
          "degree" => "",
          "institution" => "",
          "description" => "",
          "start_date" => "",
          "graduation_date" => "",
          "visible" => true
        }

      "skills" ->
        %{
          "name" => "",
          "level" => "intermediate",
          "category" => "technical",
          "years_experience" => "",
          "visible" => true
        }

      "projects" ->
        %{
          "title" => "",
          "description" => "",
          "technologies" => "",
          "url" => "",
          "github_url" => "",
          "visible" => true
        }

      "certifications" ->
        %{
          "name" => "",
          "issuer" => "",
          "issue_date" => "",
          "expiry_date" => "",
          "credential_id" => "",
          "verification_url" => "",
          "visible" => true
        }

      "services" ->
        %{
          "name" => "",
          "description" => "",
          "price" => "",
          "duration" => "",
          "category" => "consulting",
          "visible" => true
        }

      # Content sections (5)
      "achievements" ->
        %{
          "title" => "",
          "description" => "",
          "date" => "",
          "type" => "award",
          "organization" => "",
          "visible" => true
        }

      "testimonials" ->
        %{
          "name" => "",
          "title_company" => "",
          "testimonial" => "",
          "rating" => "",
          "project" => "",
          "visible" => true
        }

      "published_articles" ->
        %{
          "title" => "",
          "publication" => "",
          "date" => "",
          "url" => "",
          "tags" => "",
          "summary" => "",
          "visible" => true
        }

      "collaborations" ->
        %{
          "title" => "",
          "partner" => "",
          "role" => "",
          "date" => "",
          "description" => "",
          "visible" => true
        }

      "timeline" ->
        %{
          "title" => "",
          "date" => "",
          "type" => "career",
          "location" => "",
          "description" => "",
          "visible" => true
        }

      # Flexible (2)
      "pricing" ->
        %{
          "name" => "",
          "description" => "",
          "price" => "",
          "features" => "",
          "popular" => false,
          "visible" => true
        }

      "custom" ->
        %{
          "title" => "",
          "subtitle" => "",
          "content" => "",
          "url" => "",
          "date" => "",
          "visible" => true
        }

      # Fallback
      _ ->
        %{
          "title" => "",
          "description" => "",
          "visible" => true
        }
    end
  end

  # Helper function for swapping items in list
  defp swap_items(list, index1, index2) do
    item1 = Enum.at(list, index1)
    item2 = Enum.at(list, index2)

    list
    |> List.replace_at(index1, item2)
    |> List.replace_at(index2, item1)
  end
    defp get_section_name(section_type) do
    case section_type do
      # Essential sections (3)
      "hero" -> "Hero Section"
      "intro" -> "Introduction"
      "contact" -> "Contact Information"

      # Professional sections (6)
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "certifications" -> "Certifications"
      "services" -> "Services"

      # Content sections (5)
      "achievements" -> "Achievements & Awards"
      "testimonials" -> "Testimonials"
      "published_articles" -> "Publications & Writing"
      "collaborations" -> "Collaborations"
      "timeline" -> "Timeline"

      # Media sections (2)
      "gallery" -> "Gallery"
      "blog" -> "Blog"

      # Flexible (2)
      "pricing" -> "Pricing"
      "custom" -> "Custom Section"

      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_section_description(section_type) do
    case section_type do
      # Essential sections (3)
      "hero" -> "Main introduction with CTAs and social links"
      "intro" -> "Personal and professional story"
      "contact" -> "Contact information and social media links"

      # Professional sections (6)
      "experience" -> "Professional work history and achievements"
      "education" -> "Academic background and qualifications"
      "skills" -> "Technical and soft skills with proficiency levels"
      "projects" -> "Portfolio projects with descriptions and links"
      "certifications" -> "Professional certifications and credentials"
      "services" -> "Services offered to clients or customers"

      # Content sections (5)
      "achievements" -> "Awards, recognition, and major accomplishments"
      "testimonials" -> "Client feedback and recommendations"
      "published_articles" -> "Articles, blog posts, and published content"
      "collaborations" -> "Joint projects and partnerships"
      "timeline" -> "Career journey and major milestones"

      # Media sections (2)
      "gallery" -> "Visual showcase of work and media"
      "blog" -> "Blog posts and written content"

      # Flexible (2)
      "pricing" -> "Service packages and pricing information"
      "custom" -> "Create your own custom section type"

      _ -> "Add content to showcase your work"
    end
  end

  defp get_section_icon(section_type) do
    case section_type do
      # Essential sections (3)
      "hero" -> "🏠"
      "intro" -> "👋"
      "contact" -> "📞"

      # Professional sections (6)
      "experience" -> "💼"
      "education" -> "🎓"
      "skills" -> "🛠️"
      "projects" -> "🚀"
      "certifications" -> "🏆"
      "services" -> "⚡"

      # Content sections (5)
      "achievements" -> "🏅"
      "testimonials" -> "💬"
      "published_articles" -> "📝"
      "collaborations" -> "🤝"
      "timeline" -> "📅"

      # Media sections (2)
      "gallery" -> "🖼️"
      "blog" -> "📄"

      # Flexible (2)
      "pricing" -> "💰"
      "custom" -> "⚙️"

      _ -> "📄"
    end
  end

  defp get_section_color(section_type) do
    case section_type do
      # Essential sections (3)
      "hero" -> "#3B82F6"        # Blue
      "intro" -> "#06B6D4"       # Cyan
      "contact" -> "#10B981"     # Emerald

      # Professional sections (6)
      "experience" -> "#059669"  # Emerald-600
      "education" -> "#7C3AED"   # Purple
      "skills" -> "#DC2626"      # Red
      "projects" -> "#EA580C"    # Orange
      "certifications" -> "#F59E0B"  # Amber
      "services" -> "#EC4899"    # Pink

      # Content sections (5)
      "achievements" -> "#FDE047"    # Yellow
      "testimonials" -> "#F472B6"    # Pink-400
      "published_articles" -> "#93C5FD"  # Blue-300
      "collaborations" -> "#A78BFA"  # Purple-300
      "timeline" -> "#34D399"        # Emerald-300

      # Media sections (2)
      "gallery" -> "#8B5CF6"     # Purple-500
      "blog" -> "#06B6D4"        # Cyan

      # Flexible (2)
      "pricing" -> "#F59E0B"     # Amber
      "custom" -> "#6B7280"      # Gray

      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    case hex_color do
      "#3B82F6" -> "#1D4ED8"  # hero
      "#06B6D4" -> "#0891B2"  # intro/blog
      "#10B981" -> "#059669"  # contact
      "#059669" -> "#047857"  # experience
      "#7C3AED" -> "#5B21B6"  # education
      "#DC2626" -> "#B91C1C"  # skills
      "#EA580C" -> "#C2410C"  # projects
      "#F59E0B" -> "#D97706"  # certifications/pricing
      "#EC4899" -> "#DB2777"  # services
      "#FDE047" -> "#EAB308"  # achievements
      "#F472B6" -> "#EC4899"  # testimonials
      "#93C5FD" -> "#60A5FA"  # published_articles
      "#A78BFA" -> "#8B5CF6"  # collaborations
      "#34D399" -> "#10B981"  # timeline
      "#8B5CF6" -> "#7C3AED"  # gallery
      _ -> "#374151"
    end
  end

  defp get_field_label(field_name) do
    case field_name do
      # Hero fields
      "headline" -> "Headline"
      "tagline" -> "Tagline"
      "description" -> "Description"
      "cta_text" -> "Call-to-Action Text"
      "cta_link" -> "Call-to-Action Link"
      "background_type" -> "Background Type"

      # Contact fields
      "email" -> "Email Address"
      "phone" -> "Phone Number"
      "location" -> "Location"
      "website" -> "Website"
      "availability" -> "Availability"
      "timezone" -> "Timezone"
      "preferred_contact" -> "Preferred Contact Method"

      # Gallery fields
      "display_style" -> "Display Style"
      "items_per_row" -> "Items Per Row"
      "show_captions" -> "Show Captions"
      "enable_lightbox" -> "Enable Lightbox"

      # Blog fields
      "blog_url" -> "Blog URL"
      "auto_sync" -> "Auto Sync"
      "max_posts" -> "Maximum Posts"
      "show_dates" -> "Show Dates"

      # Timeline fields
      "timeline_type" -> "Timeline Type"

      # Services fields
      "service_style" -> "Service Style"
      "show_pricing" -> "Show Pricing"

      # Pricing fields
      "currency" -> "Currency"
      "billing_period" -> "Billing Period"

      _ -> String.capitalize(String.replace(field_name, "_", " "))
    end
  end

  defp has_essential_items?(section_type) do
    section_type in [
      "experience", "education", "skills", "projects",
      "certifications", "services", "achievements",
      "testimonials", "published_articles", "collaborations",
      "timeline", "pricing", "custom"
    ]
  end

  defp has_media_support?(section_type) do
    section_type in [
      "gallery", "projects", "hero", "services", "testimonials",
      "achievements", "collaborations", "custom"
    ]
  end

  defp get_items_label(section_type) do
    case section_type do
      # Professional sections (6)
      "experience" -> "Work Experiences"
      "education" -> "Education Entries"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "certifications" -> "Certifications"
      "services" -> "Services"

      # Content sections (5)
      "achievements" -> "Achievements"
      "testimonials" -> "Testimonials"
      "published_articles" -> "Articles"
      "collaborations" -> "Collaborations"
      "timeline" -> "Timeline Events"

      # Flexible (2)
      "pricing" -> "Pricing Packages"
      "custom" -> "Custom Section"

      _ -> "New Section"
    end
  end

end
