# lib/frestyl_web/live/portfolio_live/components/portfolio_editor_layout.ex
# Main layout component that replaces TabRenderer

defmodule FrestylWeb.PortfolioLive.Components.PortfolioEditorLayout do
  use FrestylWeb, :live_component

  # ============================================================================
  # MAIN EDITOR LAYOUT
  # ============================================================================

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Editor Header -->
      <.editor_header
        portfolio={@portfolio}
        account={@account}
        unsaved_changes={@unsaved_changes}
        can_monetize={@can_monetize}
        can_stream={@can_stream} />

      <!-- Main Editor Content -->
      <div class="flex h-[calc(100vh-4rem)]">
        <!-- Sidebar Navigation -->
        <.editor_sidebar
          active_tab={@active_tab}
          sections={@sections}
          features={@features}
          editing_section={@editing_section} />

        <!-- Main Content Area -->
        <div class="flex-1 flex">
          <!-- Content Editor -->
          <div class="flex-1 overflow-y-auto">
            <%= case @active_tab do %>
              <% :content -> %>
                <.content_tab
                  sections={@sections}
                  editing_section={@editing_section}
                  editing_mode={@editing_mode}
                  design_tokens={@design_tokens}
                  can_monetize={@can_monetize}
                  limits={@limits} />

              <% :design -> %>
                <.design_tab
                  portfolio={@portfolio}
                  available_layouts={@available_layouts}
                  brand_constraints={@brand_constraints}
                  design_tokens={@design_tokens} />

              <% :monetization -> %>
                <.monetization_tab
                  portfolio={@portfolio}
                  monetization_data={@monetization_data}
                  revenue_analytics={@revenue_analytics}
                  can_monetize={@can_monetize} />

              <% :streaming -> %>
                <.streaming_tab
                  portfolio={@portfolio}
                  streaming_config={@streaming_config}
                  can_stream={@can_stream} />

              <% :analytics -> %>
                <.analytics_tab
                  portfolio={@portfolio}
                  revenue_analytics={@revenue_analytics}
                  features={@features} />

              <% :content -> %>
                <.enhanced_content_tab
                  sections={@sections}
                  content_blocks={@content_blocks}
                  editing_section={@editing_section}
                  editing_block={@editing_block}
                  editing_mode={@editing_mode}
                  can_monetize={@can_monetize}
                  limits={@limits} />

            <% end %>
          </div>

          <!-- Live Preview (if enabled) -->
          <%= if @show_preview do %>
            <div class="w-1/3 border-l border-gray-200 bg-white">
              <.live_preview
                portfolio={@portfolio}
                sections={@sections}
                design_tokens={@design_tokens} />
            </div>
          <% end %>
        </div>
      </div>

      <!-- Global Modals -->
      <.video_recorder_modal
        :if={@show_video_recorder}
        portfolio={@portfolio}
        limits={@limits} />

      <.media_library_modal
        :if={@show_media_library}
        media_library={@media_library}
        editing_section={@editing_section} />

      <.block_builder_modal
        :if={@block_builder_open}
        section_id={@block_builder_section_id}
        available_blocks={@available_block_types}
        can_monetize={@can_monetize} />
    </div>
    """
  end

  # ============================================================================
  # HEADER COMPONENT
  # ============================================================================

  defp editor_header(assigns) do
    ~H"""
    <header class="bg-white border-b border-gray-200 px-6 py-4">
      <div class="flex items-center justify-between">
        <!-- Portfolio Info -->
        <div class="flex items-center space-x-4">
          <.link navigate="/portfolios" class="text-gray-400 hover:text-gray-600">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
            </svg>
          </.link>

          <div>
            <h1 class="text-xl font-bold text-gray-900"><%= @portfolio.title %></h1>
            <p class="text-sm text-gray-500">
              <%= @account.subscription_tier |> String.capitalize() %> Account
              <%= if @can_monetize, do: "• Monetization Enabled" %>
              <%= if @can_stream, do: "• Streaming Enabled" %>
            </p>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center space-x-3">
          <!-- Save Status -->
          <%= if @unsaved_changes do %>
            <span class="text-sm text-amber-600 flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              Unsaved changes
            </span>
          <% else %>
            <span class="text-sm text-green-600 flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
              </svg>
              All changes saved
            </span>
          <% end %>

          <!-- Preview Toggle -->
          <button
            phx-click="toggle_preview"
            class="px-3 py-2 text-sm bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors">
            Preview
          </button>

          <!-- Publish Button -->
          <button
            phx-click="publish_portfolio"
            class="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 transition-colors">
            Publish
          </button>
        </div>
      </div>
    </header>
    """
  end

  # ============================================================================
  # SIDEBAR NAVIGATION
  # ============================================================================

  defp editor_sidebar(assigns) do
    ~H"""
    <div class="w-64 bg-white border-r border-gray-200 overflow-y-auto">
      <!-- Main Navigation Tabs -->
      <nav class="p-4 space-y-2">
        <.nav_item
          active={@active_tab == :content}
          icon="document-text"
          label="Content"
          count={length(@sections)}
          phx_click="switch_tab"
          phx_value_tab="content" />

        <.nav_item
          active={@active_tab == :design}
          icon="color-swatch"
          label="Design"
          phx_click="switch_tab"
          phx_value_tab="design" />

        <%= if @features.monetization_enabled do %>
          <.nav_item
            active={@active_tab == :monetization}
            icon="currency-dollar"
            label="Monetization"
            phx_click="switch_tab"
            phx_value_tab="monetization" />
        <% end %>

        <%= if @features.streaming_enabled do %>
          <.nav_item
            active={@active_tab == :streaming}
            icon="video-camera"
            label="Streaming"
            phx_click="switch_tab"
            phx_value_tab="streaming" />
        <% end %>

        <%= if @features.advanced_analytics do %>
          <.nav_item
            active={@active_tab == :analytics}
            icon="chart-bar"
            label="Analytics"
            phx_click="switch_tab"
            phx_value_tab="analytics" />
        <% end %>
      </nav>

      <!-- Section List (when in content tab) -->
      <%= if @active_tab == :content do %>
        <div class="border-t border-gray-200 pt-4">
          <.section_list
            sections={@sections}
            editing_section={@editing_section} />
        </div>
      <% end %>
    </div>
    """
  end

  defp nav_item(assigns) do
    ~H"""
    <button
      phx-click={@phx_click}
      phx-value-tab={assigns[:phx_value_tab]}
      class={[
        "w-full flex items-center px-3 py-2 text-sm font-medium rounded-lg transition-colors",
        if(@active,
          do: "bg-blue-50 text-blue-700 border border-blue-200",
          else: "text-gray-700 hover:bg-gray-50")
      ]}>

      <.icon name={@icon} class="w-5 h-5 mr-3" />
      <span class="flex-1 text-left"><%= @label %></span>

      <%= if assigns[:count] do %>
        <span class="bg-gray-100 text-gray-600 text-xs px-2 py-1 rounded-full">
          <%= @count %>
        </span>
      <% end %>
    </button>
    """
  end

  # ============================================================================
  # CONTENT TAB COMPONENT
  # ============================================================================

  defp content_tab(assigns) do
    ~H"""
    <div class="p-6">
      <%= if @editing_mode == :overview do %>
        <.sections_overview
          sections={@sections}
          design_tokens={@design_tokens}
          can_monetize={@can_monetize}
          limits={@limits} />
      <% else %>
        <.section_editor
          editing_section={@editing_section}
          design_tokens={@design_tokens}
          can_monetize={@can_monetize} />
      <% end %>
    </div>
    """
  end

  defp enhanced_content_tab(assigns) do
    ~H"""
    <div class="p-6">
      <%= case @editing_mode do %>
        <% :overview -> %>
          <.enhanced_sections_overview
            sections={@sections}
            content_blocks={@content_blocks}
            can_monetize={@can_monetize}
            limits={@limits} />

        <% :block_detail -> %>
          <.enhanced_block_editor
            editing_block={@editing_block}
            can_monetize={@can_monetize} />

        <% _ -> %>
          <.sections_overview
            sections={@sections}
            design_tokens={@design_tokens}
            can_monetize={@can_monetize}
            limits={@limits} />
      <% end %>
    </div>
    """
  end

  defp enhanced_sections_overview(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Portfolio Sections</h2>
          <p class="text-gray-600 mt-1">
            <%= length(@sections) %> sections with content blocks
          </p>
        </div>
        <.add_section_dropdown can_monetize={@can_monetize} />
      </div>

      <%= if length(@sections) > 0 do %>
        <div class="space-y-4">
          <%= for section <- @sections do %>
            <.enhanced_section_card
              section={section}
              content_blocks={Map.get(@content_blocks, section.id, [])}
              can_monetize={@can_monetize} />
          <% end %>
        </div>
      <% else %>
        <.empty_portfolio_state />
      <% end %>
    </div>
    """
  end

  # ADD NEW COMPONENT after enhanced_sections_overview:
  defp enhanced_section_card(assigns) do
    content_block_count = length(assigns.content_blocks)
    assigns = assign(assigns, :content_block_count, content_block_count)

    ~H"""
    <div class="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition-shadow cursor-pointer group">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center space-x-3 mb-2">
            <.section_type_icon type={@section.section_type} />
            <h3 class="font-semibold text-gray-900"><%= @section.title %></h3>

            <%= if @content_block_count > 0 do %>
              <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full">
                <%= @content_block_count %> blocks
              </span>
            <% end %>
          </div>

          <p class="text-gray-600 text-sm">
            <%= if @content_block_count > 0 do %>
              Contains <%= @content_block_count %> content blocks
            <% else %>
              <%= get_section_preview(@section) %>
            <% end %>
          </p>
        </div>

        <div class="flex items-center space-x-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            phx-click="open_block_builder"
            phx-value-section_id={@section.id}
            class="p-1.5 hover:bg-blue-100 rounded text-blue-600"
            title="Add Content Block">
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z"/>
            </svg>
          </button>

          <!-- existing action buttons stay the same -->
          <button phx-click="delete_section" phx-value-id={@section.id} class="p-1 hover:bg-gray-100 rounded">
            <.icon name="trash" class="w-4 h-4 text-red-500" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ADD NEW COMPONENT after enhanced_section_card:
  defp enhanced_block_editor(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto">
      <div class="flex items-center justify-between mb-6">
        <div>
          <button
            phx-click="switch_editing_mode"
            phx-value-mode="overview"
            class="flex items-center text-blue-600 hover:text-blue-700 mb-2">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
            </svg>
            Back to Overview
          </button>
          <h2 class="text-2xl font-bold text-gray-900">
            Edit <%= humanize_block_type(@editing_block.block_type) %>
          </h2>
        </div>
      </div>

      <div class="bg-white rounded-xl border border-gray-200 p-6">
        <p class="text-gray-600">Block editor for <%= @editing_block.block_type %></p>
        <!-- Block editing interface will be implemented in next phase -->
      </div>
    </div>
    """
  end

  defp sections_overview(assigns) do
    ~H"""
    <div>
      <!-- Header with Add Section -->
      <div class="flex items-center justify-between mb-6">
        <div>
          <h2 class="text-2xl font-bold text-gray-900">Portfolio Sections</h2>
          <p class="text-gray-600 mt-1">
            <%= length(@sections) %> of <%= if @limits.max_sections == -1, do: "unlimited", else: @limits.max_sections %> sections
          </p>
        </div>

        <.add_section_dropdown can_monetize={@can_monetize} />
      </div>

      <!-- Sections Grid -->
      <%= if length(@sections) > 0 do %>
        <div class="space-y-4" id="sections-sortable" phx-hook="SortableSections">
          <%= for section <- Enum.sort_by(@sections, & &1.position) do %>
            <.section_card
              section={section}
              design_tokens={@design_tokens} />
          <% end %>
        </div>
      <% else %>
        <.empty_portfolio_state />
      <% end %>
    </div>
    """
  end

  defp section_card(assigns) do
    ~H"""
    <div
      class="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition-shadow cursor-pointer group"
      data-section-id={@section.id}
      phx-click="edit_section"
      phx-value-id={@section.id}>

      <div class="flex items-start justify-between">
        <div class="flex-1">
          <div class="flex items-center space-x-3 mb-2">
            <.section_type_icon type={@section.section_type} />
            <h3 class="font-semibold text-gray-900"><%= @section.title %></h3>

            <%= if @section.monetization_config && map_size(@section.monetization_config) > 0 do %>
              <span class="bg-green-100 text-green-800 text-xs px-2 py-1 rounded-full">
                Monetized
              </span>
            <% end %>
          </div>

          <p class="text-gray-600 text-sm">
            <%= get_section_preview(@section) %>
          </p>
        </div>

        <!-- Section Actions -->
        <div class="flex items-center space-x-2 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            phx-click="toggle_section_visibility"
            phx-value-id={@section.id}
            class="p-1 hover:bg-gray-100 rounded">
            <.icon
              name={if @section.visible, do: "eye", else: "eye-slash"}
              class="w-4 h-4 text-gray-500" />
          </button>

          <button
            phx-click="duplicate_section"
            phx-value-id={@section.id}
            class="p-1 hover:bg-gray-100 rounded">
            <.icon name="duplicate" class="w-4 h-4 text-gray-500" />
          </button>

          <button
            phx-click="delete_section"
            phx-value-id={@section.id}
            class="p-1 hover:bg-gray-100 rounded">
            <.icon name="trash" class="w-4 h-4 text-red-500" />
          </button>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp section_type_icon(assigns) do
    icon_map = %{
      "intro" => "user-circle",
      "experience" => "briefcase",
      "education" => "academic-cap",
      "skills" => "lightning-bolt",
      "projects" => "collection",
      "custom" => "puzzle",
      "services" => "currency-dollar",
      "testimonials" => "chat-alt",
      "contact" => "mail"
    }

    icon_name = Map.get(icon_map, assigns.type, "document-text")

    assigns = assign(assigns, :icon_name, icon_name)

    ~H"""
    <.icon name={@icon_name} class="w-5 h-5 text-blue-600" />
    """
  end

  defp get_section_preview(section) do
    case section.section_type do
      "intro" -> get_in(section.content, ["summary"]) || "Add your introduction"
      "experience" -> "#{length(get_in(section.content, ["jobs"]) || [])} positions"
      "skills" -> "#{length(get_in(section.content, ["skills"]) || [])} skills"
      "projects" -> "#{length(get_in(section.content, ["projects"]) || [])} projects"
      _ -> "Click to edit content"
    end
  end

  defp add_section_dropdown(assigns) do
    ~H"""
    <div class="relative" phx-click-away="close_add_section_dropdown">
      <button
        phx-click="toggle_add_section_dropdown"
        class="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors flex items-center space-x-2">
        <.icon name="plus" class="w-4 h-4" />
        <span>Add Section</span>
      </button>

      <%= if assigns[:show_add_section_dropdown] do %>
        <div class="absolute right-0 mt-2 w-80 bg-white rounded-xl shadow-xl border border-gray-200 z-50">
          <div class="p-4">
            <h3 class="font-semibold text-gray-900 mb-3">Add New Section</h3>

            <div class="grid grid-cols-2 gap-2">
              <!-- Standard sections -->
              <.section_type_option type="intro" name="Introduction" icon="user-circle" />
              <.section_type_option type="experience" name="Experience" icon="briefcase" />
              <.section_type_option type="education" name="Education" icon="academic-cap" />
              <.section_type_option type="skills" name="Skills" icon="lightning-bolt" />
              <.section_type_option type="projects" name="Projects" icon="collection" />
              <.section_type_option type="testimonials" name="Testimonials" icon="chat-alt" />

              <!-- Monetization sections (if enabled) -->
              <%= if @can_monetize do %>
                <.section_type_option type="services" name="Services" icon="currency-dollar" />
                <.section_type_option type="booking" name="Book Me" icon="calendar" />
              <% end %>

              <!-- Custom section -->
              <.section_type_option type="custom" name="Custom" icon="puzzle" />
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp block_builder_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-gray-500 bg-opacity-75 flex items-center justify-center z-50">
      <div class="bg-white rounded-lg shadow-xl max-w-2xl w-full mx-4">
        <div class="px-6 py-4 border-b border-gray-200">
          <h3 class="text-lg font-semibold text-gray-900">Add Content Block</h3>
        </div>

        <div class="p-6">
          <div class="grid grid-cols-2 gap-4">
            <%= for block_type <- @available_blocks do %>
              <button
                phx-click="create_content_block"
                phx-value-section_id={@section_id}
                phx-value-block_type={block_type.type}
                class="p-4 border border-gray-200 rounded-lg text-left hover:border-blue-300 hover:bg-blue-50 transition-colors">
                <h4 class="font-medium text-gray-900 mb-1"><%= block_type.name %></h4>
                <p class="text-sm text-gray-600"><%= block_type.description %></p>
              </button>
            <% end %>
          </div>
        </div>

        <div class="px-6 py-4 border-t border-gray-200 flex justify-end">
          <button
            phx-click="close_block_builder"
            class="px-4 py-2 border border-gray-300 text-gray-700 text-sm font-medium rounded-lg hover:bg-gray-50">
            Cancel
          </button>
        </div>
      </div>
    </div>
    """
  end

  defp section_type_option(assigns) do
    ~H"""
    <button
      phx-click="add_section"
      phx-value-type={@type}
      class="flex items-center p-3 text-left hover:bg-gray-50 rounded-lg transition-colors">
      <.icon name={@icon} class="w-5 h-5 text-gray-600 mr-3" />
      <span class="text-sm font-medium text-gray-900"><%= @name %></span>
    </button>
    """
  end

  defp empty_portfolio_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <.icon name="document-add" class="w-16 h-16 text-gray-300 mx-auto mb-4" />
      <h3 class="text-lg font-medium text-gray-900 mb-2">No sections yet</h3>
      <p class="text-gray-600 mb-6">Start building your portfolio by adding your first section</p>
      <.add_section_dropdown can_monetize={false} />
    </div>
    """
  end

  # Placeholder components for subsequent prompts
  defp design_tab(assigns), do: ~H"<div>Design tab - Coming in Prompt 3</div>"
  defp monetization_tab(assigns), do: ~H"<div>Monetization tab - Coming in Prompt 5</div>"
  defp streaming_tab(assigns), do: ~H"<div>Streaming tab - Coming in Prompt 4</div>"
  defp analytics_tab(assigns), do: ~H"<div>Analytics tab - Coming in Prompt 6</div>"
  defp section_editor(assigns), do: ~H"<div>Section editor - Coming in Prompt 2</div>"
  defp section_list(assigns), do: ~H"<div>Section list - Enhanced in Prompt 2</div>"
  defp live_preview(assigns), do: ~H"<div>Live preview - Enhanced in Prompt 3</div>"
  defp video_recorder_modal(assigns), do: ~H"<div>Video recorder - Coming in Prompt 4</div>"
  defp media_library_modal(assigns), do: ~H"<div>Media library - Enhanced in Prompt 2</div>"

  defp humanize_block_type(block_type) when is_atom(block_type) do
    block_type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
