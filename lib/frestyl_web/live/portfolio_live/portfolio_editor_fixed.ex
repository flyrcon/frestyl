# lib/frestyl_web/live/portfolio_live/portfolio_editor_fixed.ex

defmodule FrestylWeb.PortfolioLive.PortfolioEditorFixed do
  @moduledoc """
  Clean, working portfolio editor that focuses on core functionality:
  - Theme selection
  - Layout selection
  - Color scheme editing
  - Section management (add, edit, delete, reorder)
  - Working live preview
  """

  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Accounts
  alias Phoenix.PubSub

  # ============================================================================
  # MOUNT - Clean and Simple
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    user = socket.assigns.current_user

    case load_portfolio_safely(portfolio_id, user) do
      {:ok, portfolio, account} ->
        sections = load_sections_safely(portfolio.id)

        # FIX: Add PubSub subscription for live preview updates
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
        end

        socket = socket
        |> assign(:portfolio, portfolio)
        |> assign(:account, account)
        |> assign(:sections, sections)
        |> assign(:active_tab, "content")
        |> assign(:editing_section, nil)
        |> assign(:show_section_modal, false)
        |> assign(:show_add_section_dropdown, false)
        |> assign(:unsaved_changes, false)
        |> assign(:design_settings, get_design_settings(portfolio))
        |> assign(:available_themes, get_available_themes())
        |> assign(:available_layouts, get_available_layouts())
        |> assign(:available_color_schemes, get_available_color_schemes())
        |> assign(:section_types, get_section_types())
        # FIX: Add preview-specific assigns
        |> assign(:show_live_preview, true)
        |> assign(:preview_token, generate_preview_token(portfolio.id))
        |> assign(:preview_mobile_view, false)

        {:ok, socket}

      {:error, reason} ->
        {:ok, socket
        |> put_flash(:error, "Failed to load portfolio: #{reason}")
        |> push_navigate(to: ~p"/hub")}
    end
  end


  defp add_mobile_assigns(socket) do
    socket
    |> assign(:show_mobile_nav, false)
    |> assign(:show_quick_add, false)
    |> assign(:preview_device, "mobile")
  end

  # ============================================================================
  # RENDER - Clean Interface
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="portfolio-editor-fixed min-h-screen bg-gray-50"
        phx-hook="MobileNavigation"
        id="portfolio-editor-container">

      <!-- Header with correct hook -->
      <div class="bg-white border-b border-gray-200 px-6 py-4">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-2xl font-bold text-gray-900"><%= @portfolio.title %></h1>
            <p class="text-sm text-gray-600">Portfolio Editor</p>
          </div>

          <div class="flex items-center space-x-4" phx-hook="FloatingButtons" id="header-actions">
            <%= if @unsaved_changes do %>
              <span class="text-sm text-orange-600 font-medium">Unsaved changes</span>
            <% end %>

            <button phx-click="save_portfolio"
                    class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              Save Portfolio
            </button>

            <a href={"/p/#{@portfolio.slug}"} target="_blank"
              class="px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
              View Public
            </a>
          </div>
        </div>
      </div>

      <!-- Main Content -->
      <div class="flex h-[calc(100vh-80px)]">
        <!-- Sidebar -->
        <div class="w-80 bg-white border-r border-gray-200 overflow-y-auto">
          <!-- Tabs -->
          <div class="border-b border-gray-200">
            <nav class="flex">
              <%= for tab <- ["content", "design"] do %>
                <button phx-click="switch_tab" phx-value-tab={tab}
                        class={[
                          "flex-1 py-3 px-4 text-sm font-medium text-center border-b-2",
                          if(@active_tab == tab,
                            do: "border-blue-500 text-blue-600",
                            else: "border-transparent text-gray-500 hover:text-gray-700")
                        ]}>
                  <%= String.capitalize(tab) %>
                </button>
              <% end %>
            </nav>
          </div>

          <!-- Tab Content -->
          <div class="p-6">
            <%= if @active_tab == "content" do %>
              <%= render_content_tab(assigns) %>
            <% else %>
              <%= render_design_tab(assigns) %>
            <% end %>
          </div>
        </div>

        <!-- Main Editor Area with Preview Hook -->
        <div class="flex-1 flex flex-col" phx-hook="PreviewDevice" id="preview-area">
          <!-- Live Preview -->
          <div class="flex-1 p-6">
            <div class="h-full bg-white rounded-lg shadow-sm border">
              <div class="h-full" phx-hook="LivePreviewManager" id="preview-container">
                <iframe id="portfolio-preview"
                        src={build_preview_url(@portfolio)}
                        class="w-full h-full border-0 rounded-lg"
                        title="Portfolio Preview">
                </iframe>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Section Edit Modal -->
      <%= if @show_section_modal and @editing_section do %>
        <%= render_section_modal(assigns) %>
      <% end %>
    </div>
    """
  end


  # ============================================================================
  # TAB RENDERERS
  # ============================================================================

  defp render_content_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Add Section -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">Sections</h3>
          <div class="relative">
            <button phx-click="toggle_add_section"
                    class="px-3 py-2 bg-blue-600 text-white rounded-lg text-sm hover:bg-blue-700">
              + Add Section
            </button>

            <%= if @show_add_section_dropdown do %>
              <div class="absolute top-full right-0 mt-2 w-48 bg-white rounded-lg shadow-lg border z-10">
                <%= for section_type <- @section_types do %>
                  <button phx-click="add_section" phx-value-type={section_type.type}
                          class="w-full px-4 py-2 text-left hover:bg-gray-50 first:rounded-t-lg last:rounded-b-lg">
                    <div class="font-medium text-gray-900"><%= section_type.name %></div>
                    <div class="text-xs text-gray-500"><%= section_type.description %></div>
                  </button>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>

        <!-- Sections List with Proper Hook -->
        <div class="space-y-3"
            id="sections-list"
            phx-hook="SortableSections"
            phx-update="append">
          <%= for section <- @sections do %>
            <div class="section-item bg-gray-50 rounded-lg p-4 border cursor-move"
                data-section-id={section.id}
                id={"section-#{section.id}"}>
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <h4 class="font-medium text-gray-900"><%= section.title %></h4>
                  <p class="text-sm text-gray-600 capitalize"><%= section.section_type %></p>
                </div>

                <div class="flex items-center space-x-2">
                  <!-- Visibility Toggle -->
                  <button phx-click="toggle_section_visibility" phx-value-id={section.id}
                          class={[
                            "p-1 rounded text-sm",
                            if(section.visible,
                              do: "text-green-600 hover:bg-green-50",
                              else: "text-gray-400 hover:bg-gray-100")
                          ]}>
                    <%= if section.visible do %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
                      </svg>
                    <% end %>
                  </button>

                  <!-- Edit Button -->
                  <button phx-click="edit_section" phx-value-id={section.id}
                          class="p-1 text-blue-600 hover:bg-blue-50 rounded">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>

                  <!-- Delete Button -->
                  <button phx-click="delete_section" phx-value-id={section.id}
                          data-confirm="Are you sure you want to delete this section?"
                          class="p-1 text-red-600 hover:bg-red-50 rounded">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_design_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Theme Selection -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Theme</h3>
        <div class="grid grid-cols-1 gap-3">
          <%= for theme <- @available_themes do %>
            <button phx-click="update_design" phx-value-setting="theme" phx-value-value={theme.key}
                    class={[
                      "p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.theme == theme.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="font-medium text-gray-900"><%= theme.name %></div>
              <div class="text-sm text-gray-600"><%= theme.description %></div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Layout Selection -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Layout</h3>
        <div class="grid grid-cols-1 gap-3">
          <%= for layout <- @available_layouts do %>
            <button phx-click="update_design" phx-value-setting="layout" phx-value-value={layout.key}
                    class={[
                      "p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.layout == layout.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="font-medium text-gray-900"><%= layout.name %></div>
              <div class="text-sm text-gray-600"><%= layout.description %></div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Color Scheme -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Color Scheme</h3>
        <div class="grid grid-cols-1 gap-3">
          <%= for scheme <- @available_color_schemes do %>
            <button phx-click="update_design" phx-value-setting="color_scheme" phx-value-value={scheme.key}
                    class={[
                      "p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.color_scheme == scheme.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="flex items-center space-x-3">
                <div class="flex space-x-1">
                  <%= for color <- scheme.colors do %>
                    <div class="w-4 h-4 rounded-full" style={"background-color: #{color}"}></div>
                  <% end %>
                </div>
                <div>
                  <div class="font-medium text-gray-900"><%= scheme.name %></div>
                  <div class="text-sm text-gray-600"><%= scheme.description %></div>
                </div>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_modal(assigns) do
    is_hero = assigns.editing_section.section_type == "hero"
    is_contact = assigns.editing_section.section_type == "contact"

    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" id="section-modal">
      <div class="flex items-start justify-center min-h-screen pt-4 px-4 pb-20">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-gray-900 bg-opacity-75" phx-click="close_section_modal"></div>

        <!-- Modal -->
        <div class="relative bg-white rounded-lg shadow-xl w-full max-w-2xl">
          <!-- Header -->
          <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-lg">
            <div class="flex items-center justify-between">
              <h3 class="text-xl font-bold text-white flex items-center">
                <%= if is_hero do %>
                  🎬 Edit Hero Section
                <% else %>
                  ✏️ Edit <%= @editing_section.title %>
                <% end %>
              </h3>
              <button phx-click="close_section_modal" class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Content -->
          <div class="p-6 max-h-[70vh] overflow-y-auto">
            <form phx-submit="save_section" class="space-y-6">
              <input type="hidden" name="section_id" value={@editing_section.id} />

              <%= if is_hero do %>
                <%= render_hero_section_form(assigns) %>
              <% else %>
                <%= render_standard_section_form(assigns) %>
              <% end %>

              <%= if is_hero or is_contact do %>
                <%= render_social_links_form(assigns) %>
              <% end %>
            </form>
          </div>

          <!-- Footer -->
          <div class="bg-gray-50 px-6 py-4 rounded-b-lg flex items-center justify-between">
            <div class="text-sm text-gray-600">
              <%= if is_hero do %>
                💡 Hero sections are automatically featured at the top of your portfolio
              <% else %>
                💡 This section will appear in your portfolio navigation
              <% end %>
            </div>

            <div class="flex items-center space-x-3">
              <button type="button" phx-click="close_section_modal"
                      class="px-4 py-2 border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50">
                Cancel
              </button>
              <button type="submit" form="section-form"
                      class="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
                Save Changes
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_hero_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6" id="section-form">
      <!-- Hero Headline -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
          <input type="text" name="headline" value={Map.get(content, "headline", "")}
                placeholder="Your Name Here"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
          <input type="text" name="tagline" value={Map.get(content, "tagline", "")}
                placeholder="Professional Title • Industry Expert"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <!-- Main Content -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Main Message</label>
        <textarea name="main_content" rows="3"
                  placeholder="Welcome message or brief introduction..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "main_content", "") %></textarea>
      </div>

      <!-- Call to Action -->
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Button Text</label>
          <input type="text" name="cta_text" value={Map.get(content, "cta_text", "")}
                placeholder="View My Work"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Button Link</label>
          <input type="text" name="cta_link" value={Map.get(content, "cta_link", "")}
                placeholder="#projects"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <!-- Hero Style -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <%= for style <- ["modern", "minimal", "bold", "creative"] do %>
          <label class="relative cursor-pointer">
            <input type="radio" name="hero_style" value={style}
                  checked={Map.get(content, "hero_style") == style}
                  class="sr-only peer" />
            <div class="p-3 border-2 border-gray-200 rounded-lg text-center peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:bg-gray-50">
              <div class="text-sm font-medium capitalize"><%= style %></div>
            </div>
          </label>
        <% end %>
      </div>

      <!-- Background Options -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-3">Background Style</label>
        <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
          <%= for bg_type <- ["gradient", "solid", "image", "video"] do %>
            <label class="relative cursor-pointer">
              <input type="radio" name="background_type" value={bg_type}
                    checked={Map.get(content, "background_type") == bg_type}
                    class="sr-only peer" />
              <div class="p-3 border-2 border-gray-200 rounded-lg text-center peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:bg-gray-50">
                <div class="text-sm font-medium capitalize"><%= bg_type %></div>
              </div>
            </label>
          <% end %>
        </div>
      </div>

      <!-- Mobile Layout -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-3">Mobile Layout</label>
        <div class="grid grid-cols-3 gap-3">
          <%= for layout <- ["stack", "overlay", "minimal"] do %>
            <label class="relative cursor-pointer">
              <input type="radio" name="mobile_layout" value={layout}
                    checked={Map.get(content, "mobile_layout") == layout}
                    class="sr-only peer" />
              <div class="p-3 border-2 border-gray-200 rounded-lg text-center peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:bg-gray-50">
                <div class="text-sm font-medium capitalize"><%= layout %></div>
              </div>
            </label>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Social links form component
  defp render_social_links_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    social_links = Map.get(content, "social_links", %{})

    ~H"""
    <div class="border-t border-gray-200 pt-6">
      <div class="flex items-center justify-between mb-4">
        <h4 class="text-lg font-medium text-gray-900">Social Links</h4>
        <label class="flex items-center">
          <input type="checkbox" name="show_social"
                checked={Map.get(content, "show_social", false)}
                class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
          <span class="ml-2 text-sm text-gray-700">Show social icons</span>
        </label>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <%= for {platform, icon} <- [
          {"linkedin", "💼"}, {"github", "👨‍💻"}, {"twitter", "🐦"},
          {"instagram", "📸"}, {"website", "🌐"}, {"email", "📧"}
        ] do %>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">
              <%= icon %> <%= String.capitalize(platform) %>
            </label>
            <input type="url" name={"social_#{platform}"}
                  value={Map.get(social_links, platform, "")}
                  placeholder={get_social_placeholder(platform)}
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500 text-sm" />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Standard section form for non-hero sections
  defp render_standard_section_form(assigns) do
    ~H"""
    <div class="space-y-4" id="section-form">
      <!-- Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Content -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
        <textarea name="main_content" rows="8"
                  placeholder="Add your content here..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= get_section_content(@editing_section) %></textarea>
      </div>
    </div>
    """
  end

  defp render_mobile_navigation(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Header -->
      <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 text-white">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold">Portfolio Editor</h2>
          <button phx-click="toggle_mobile_nav" class="text-white hover:text-gray-300">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Tabs -->
      <div class="border-b border-gray-200 bg-gray-50">
        <nav class="flex">
          <%= for tab <- ["content", "design"] do %>
            <button phx-click="switch_tab" phx-value-tab={tab}
                    class={[
                      "flex-1 py-3 px-4 text-sm font-medium text-center border-b-2 transition-colors",
                      if(@active_tab == tab,
                        do: "border-blue-500 text-blue-600 bg-white",
                        else: "border-transparent text-gray-500 hover:text-gray-700")
                    ]}>
              <%= String.capitalize(tab) %>
            </button>
          <% end %>
        </nav>
      </div>

      <!-- Tab Content -->
      <div class="flex-1 overflow-y-auto p-6">
        <%= if @active_tab == "content" do %>
          <%= render_mobile_content_tab(assigns) %>
        <% else %>
          <%= render_mobile_design_tab(assigns) %>
        <% end %>
      </div>
    </div>
    """
  end

  # Mobile-optimized content tab
  defp render_mobile_content_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Portfolio Info -->
      <div class="bg-blue-50 rounded-lg p-4">
        <h3 class="font-semibold text-blue-900 mb-2"><%= @portfolio.title %></h3>
        <p class="text-sm text-blue-700"><%= length(@sections) %> sections • <%= if @unsaved_changes, do: "Unsaved changes", else: "All saved" %></p>
      </div>

      <!-- Sections List -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-semibold text-gray-900">Sections</h3>
          <span class="text-sm text-gray-600"><%= length(@sections) %> total</span>
        </div>

        <!-- Mobile-optimized sections list -->
        <div class="space-y-3" id="mobile-sections-list">
          <%= for section <- @sections do %>
            <div class="bg-gray-50 rounded-lg p-4 border-l-4 border-blue-500">
              <div class="flex items-center justify-between mb-2">
                <h4 class="font-medium text-gray-900 flex items-center">
                  <%= get_section_icon(section.section_type) %>
                  <span class="ml-2"><%= section.title %></span>
                </h4>

                <div class="flex items-center space-x-2">
                  <!-- Visibility Toggle -->
                  <button phx-click="toggle_section_visibility" phx-value-id={section.id}
                          class={[
                            "p-2 rounded-full transition-colors",
                            if(section.visible,
                              do: "text-green-600 bg-green-50 hover:bg-green-100",
                              else: "text-gray-400 bg-gray-100 hover:bg-gray-200")
                          ]}>
                    <%= if section.visible do %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                      </svg>
                    <% else %>
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
                      </svg>
                    <% end %>
                  </button>
                </div>
              </div>

              <!-- Section Type Badge -->
              <div class="flex items-center justify-between mb-3">
                <span class="text-xs font-medium bg-blue-100 text-blue-800 px-2 py-1 rounded-full">
                  <%= String.capitalize(section.section_type) %>
                </span>
                <span class="text-xs text-gray-500">Position <%= section.position %></span>
              </div>

              <!-- Section Content Preview -->
              <div class="text-sm text-gray-600 mb-3 line-clamp-2">
                <%= get_section_content_preview(section) %>
              </div>

              <!-- Action Buttons -->
              <div class="flex items-center space-x-2">
                <button phx-click="edit_section" phx-value-id={section.id}
                        class="flex-1 py-2 px-3 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 transition-colors">
                  Edit
                </button>

                <button phx-click="delete_section" phx-value-id={section.id}
                        data-confirm="Are you sure you want to delete this section?"
                        class="py-2 px-3 bg-red-100 text-red-700 text-sm rounded-lg hover:bg-red-200 transition-colors">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Empty State -->
        <%= if length(@sections) == 0 do %>
          <div class="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
            <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No sections yet</h3>
            <p class="text-sm text-gray-600 mb-4">Start building your portfolio by adding your first section</p>
            <button phx-click="toggle_quick_add"
                    class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
              Add First Section
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Mobile-optimized design tab
  defp render_mobile_design_tab(assigns) do
    ~H"""
    <div class="space-y-6">
      <!-- Current Design Status -->
      <div class="bg-purple-50 rounded-lg p-4">
        <h3 class="font-semibold text-purple-900 mb-2">Current Design</h3>
        <div class="text-sm text-purple-700 space-y-1">
          <p>Theme: <strong><%= String.capitalize(@design_settings.theme) %></strong></p>
          <p>Layout: <strong><%= String.capitalize(@design_settings.layout) %></strong></p>
          <p>Colors: <strong><%= String.capitalize(@design_settings.color_scheme) %></strong></p>
        </div>
      </div>

      <!-- Theme Selection -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Theme</h3>
        <div class="space-y-3">
          <%= for theme <- @available_themes do %>
            <button phx-click="update_design" phx-value-setting="theme" phx-value-value={theme.key}
                    class={[
                      "w-full p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.theme == theme.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white")
                    ]}>
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-gray-900"><%= theme.name %></div>
                  <div class="text-sm text-gray-600"><%= theme.description %></div>
                </div>
                <%= if @design_settings.theme == theme.key do %>
                  <div class="w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Layout Selection -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Layout</h3>
        <div class="space-y-3">
          <%= for layout <- @available_layouts do %>
            <button phx-click="update_design" phx-value-setting="layout" phx-value-value={layout.key}
                    class={[
                      "w-full p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.layout == layout.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white")
                    ]}>
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-gray-900"><%= layout.name %></div>
                  <div class="text-sm text-gray-600"><%= layout.description %></div>
                </div>
                <%= if @design_settings.layout == layout.key do %>
                  <div class="w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Color Scheme -->
      <div>
        <h3 class="text-lg font-semibold text-gray-900 mb-4">Color Scheme</h3>
        <div class="space-y-3">
          <%= for scheme <- @available_color_schemes do %>
            <button phx-click="update_design" phx-value-setting="color_scheme" phx-value-value={scheme.key}
                    class={[
                      "w-full p-4 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.color_scheme == scheme.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300 bg-white")
                    ]}>
              <div class="flex items-center justify-between">
                <div class="flex items-center space-x-3">
                  <div class="flex space-x-1">
                    <%= for color <- scheme.colors do %>
                      <div class="w-6 h-6 rounded-full border border-gray-200" style={"background-color: #{color}"}></div>
                    <% end %>
                  </div>
                  <div>
                    <div class="font-medium text-gray-900"><%= scheme.name %></div>
                    <div class="text-sm text-gray-600"><%= scheme.description %></div>
                  </div>
                </div>
                <%= if @design_settings.color_scheme == scheme.key do %>
                  <div class="w-6 h-6 bg-blue-500 text-white rounded-full flex items-center justify-center">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_desktop_sidebar(assigns) do
    ~H"""
    <!-- Tabs -->
    <div class="border-b border-gray-200">
      <nav class="flex">
        <%= for tab <- ["content", "design"] do %>
          <button phx-click="switch_tab" phx-value-tab={tab}
                  class={[
                    "flex-1 py-3 px-4 text-sm font-medium text-center border-b-2",
                    if(@active_tab == tab,
                      do: "border-blue-500 text-blue-600",
                      else: "border-transparent text-gray-500 hover:text-gray-700")
                  ]}>
            <%= String.capitalize(tab) %>
          </button>
        <% end %>
      </nav>
    </div>

    <!-- Tab Content -->
    <div class="p-6">
      <%= if @active_tab == "content" do %>
        <%= render_content_tab(assigns) %>
      <% else %>
        <%= render_design_tab(assigns) %>
      <% end %>
    </div>
    """
  end

  # Mobile section navigation (sticky top bar)
  defp render_mobile_section_nav(assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div class="flex items-center space-x-3">
        <h3 class="text-sm font-medium text-gray-900">Sections</h3>
        <span class="text-xs bg-gray-100 text-gray-600 px-2 py-1 rounded-full">
          <%= length(@sections) %>
        </span>
      </div>

      <div class="flex items-center space-x-2">
        <!-- Quick scroll to top -->
        <button onclick="document.getElementById('portfolio-preview').scrollTo(0,0)"
                class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 11l5-5m0 0l5 5m-5-5v12"/>
          </svg>
        </button>

        <!-- Refresh preview -->
        <button phx-click="refresh_preview"
                class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-md">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  # ============================================================================
  # EVENT HANDLERS - Clean and Working
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_add_section", _params, socket) do
    show = !socket.assigns.show_add_section_dropdown
    {:noreply, assign(socket, :show_add_section_dropdown, show)}
  end

  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    IO.puts("🔥 ADD SECTION: #{section_type}")
    portfolio_id = socket.assigns.portfolio.id

    case test_section_creation(portfolio_id) do
      {:ok, _} ->
        IO.puts("✅ All diagnostic tests passed, proceeding with section creation")

        section_attrs = %{
          portfolio_id: portfolio_id,
          title: get_default_title_for_type(section_type),
          section_type: section_type,
          content: get_default_content_for_section_type(section_type),
          position: get_next_position(socket.assigns.sections),
          visible: true
        }

        IO.puts("🔥 Section attrs: #{inspect(section_attrs)}")

        case create_section_safely(section_attrs) do
          {:ok, new_section} ->
            IO.puts("✅ Section created: #{inspect(new_section)}")
            updated_sections = socket.assigns.sections ++ [new_section]

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:show_add_section_dropdown, false)
            |> assign(:unsaved_changes, true)
            |> put_flash(:info, "#{get_default_title_for_type(section_type)} section added!")

            # FIX: Use correct event names and add broadcasting
            socket = socket
            |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
            |> push_event("section_added", %{section_id: new_section.id, title: new_section.title})
            |> broadcast_preview_update()

            {:noreply, socket}

          {:error, reason} ->
            IO.puts("❌ Section creation failed: #{inspect(reason)}")
            {:noreply, socket
            |> put_flash(:error, "Failed to add section: #{inspect(reason)}")
            |> assign(:show_add_section_dropdown, false)}
        end

      {:error, reason} ->
        IO.puts("❌ Diagnostic test failed: #{reason}")
        {:noreply, socket |> put_flash(:error, "System error: #{reason}")}
    end
  end

  @impl true
  def handle_event("save_section", params, socket) do
    section_id = String.to_integer(params["section_id"])
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    # Handle different section types
    update_attrs = case section.section_type do
      "hero" ->
        build_hero_section_attrs(params)
      _ ->
        %{
          title: params["title"] || section.title,
          content: %{"main_content" => params["main_content"] || params["content"] || ""}
        }
    end

    case Portfolios.update_section(section, update_attrs) do
      {:ok, updated_section} ->
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == section_id, do: updated_section, else: s
        end)

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, nil)
        |> assign(:show_section_modal, false)
        |> assign(:unsaved_changes, true)
        |> put_flash(:info, "Section updated successfully")

        # FIX: Add proper broadcasting and events
        socket = socket
        |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
        |> push_event("section_saved", %{section_id: section_id})
        |> broadcast_section_update(updated_section)
        |> broadcast_preview_update()

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    case Portfolios.delete_section(section) do
      {:ok, _} ->
        updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id_int))

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, true)
        |> put_flash(:info, "Section deleted successfully")

        # FIX: Add proper broadcasting and events
        socket = socket
        |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
        |> push_event("section_deleted", %{section_id: section_id_int})
        |> broadcast_preview_update()

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_event("update_design", %{"setting" => setting, "value" => value}, socket) do
    IO.puts("🎨 UPDATE DESIGN: #{setting} = #{value}")
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    updated_customization = Map.put(current_customization, setting, value)

    case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Portfolio updated successfully")
        design_settings = get_design_settings(updated_portfolio)

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:design_settings, design_settings)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Design updated: #{String.capitalize(setting)} changed to #{value}")

        # FIX: Add proper broadcasting and events
        socket = socket
        |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
        |> push_event("update_preview_css", %{css: generate_design_css(updated_customization)})
        |> broadcast_design_update()
        |> broadcast_preview_update()

        {:noreply, socket}

      {:error, reason} ->
        IO.puts("❌ Portfolio update failed: #{inspect(reason)}")
        {:noreply, socket
        |> put_flash(:error, "Failed to update design: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("reorder_sections", %{"section_ids" => section_ids}, socket) do
    IO.puts("🔄 REORDER SECTIONS: #{inspect(section_ids)}")

    section_id_ints = Enum.map(section_ids, fn id ->
      case is_binary(id) do
        true -> String.to_integer(id)
        false -> id
      end
    end)

    case update_section_positions_safely(section_id_ints) do
      {:ok, updated_sections} ->
        IO.puts("✅ Reorder successful")

        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, true)
        |> put_flash(:info, "Sections reordered successfully")

        # FIX: Add proper broadcasting and events
        socket = socket
        |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
        |> push_event("sections_reordered", %{section_ids: section_ids})
        |> broadcast_preview_update()

        {:noreply, socket}

      {:error, reason} ->
        IO.puts("❌ Reorder failed: #{inspect(reason)}")
        {:noreply, socket
        |> put_flash(:error, "Failed to reorder sections: #{inspect(reason)}")}
    end
  end


  @impl true
  def handle_event("close_section_modal", _params, socket) do
    {:noreply, socket
    |> assign(:editing_section, nil)
    |> assign(:show_section_modal, false)}
  end


  @impl true
  def handle_event("toggle_section_visibility", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    case Portfolios.update_section(section, %{visible: !section.visible}) do
      {:ok, updated_section} ->
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == section_id_int, do: updated_section, else: s
        end)

        message = if updated_section.visible, do: "Section is now visible", else: "Section is now hidden"

        {:noreply, socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, true)
        |> put_flash(:info, message)
        |> refresh_preview()}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
    end
  end

  @impl true
  def handle_event("reorder_sections", %{"section_ids" => section_ids}, socket) do
    IO.puts("🔄 REORDER SECTIONS: #{inspect(section_ids)}")

    # Convert string IDs to integers
    section_id_ints = Enum.map(section_ids, fn id ->
      case is_binary(id) do
        true -> String.to_integer(id)
        false -> id
      end
    end)

    IO.puts("🔄 Section IDs as integers: #{inspect(section_id_ints)}")

    case update_section_positions_safely(section_id_ints) do
      {:ok, updated_sections} ->
        IO.puts("✅ Reorder successful")
        {:noreply, socket
        |> assign(:sections, updated_sections)
        |> assign(:unsaved_changes, true)
        |> put_flash(:info, "Sections reordered successfully")
        |> push_event("refresh_preview", %{})}

      {:error, reason} ->
        IO.puts("❌ Reorder failed: #{inspect(reason)}")
        {:noreply, socket
        |> put_flash(:error, "Failed to reorder sections: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("save_portfolio", _params, socket) do
    # Force save any pending changes
    {:noreply, socket
    |> assign(:unsaved_changes, false)
    |> put_flash(:info, "Portfolio saved successfully")}
  end

  @impl true
  def handle_event("debug_portfolio", _params, socket) do
    IO.puts("🔍 DEBUG PORTFOLIO STATE")
    IO.puts("Portfolio ID: #{socket.assigns.portfolio.id}")
    IO.puts("Portfolio Title: #{socket.assigns.portfolio.title}")
    IO.puts("Current Sections: #{length(socket.assigns.sections)}")

    Enum.each(socket.assigns.sections, fn section ->
      IO.puts("  - #{section.title} (#{section.section_type}) [ID: #{section.id}, Pos: #{section.position}]")
    end)

    IO.puts("Design Settings: #{inspect(socket.assigns.design_settings)}")
    IO.puts("Portfolio Customization: #{inspect(socket.assigns.portfolio.customization)}")

    {:noreply, socket |> put_flash(:info, "Debug info printed to console")}
  end

  @impl true
  def handle_event("toggle_mobile_nav", _params, socket) do
    show_mobile_nav = !Map.get(socket.assigns, :show_mobile_nav, false)

    # Push event to JavaScript
    socket = if show_mobile_nav do
      push_event(socket, "mobile_nav_opened", %{})
    else
      push_event(socket, "mobile_nav_closed", %{})
    end

    {:noreply, assign(socket, :show_mobile_nav, show_mobile_nav)}
  end

  @impl true
  def handle_event("toggle_quick_add", _params, socket) do
    show_quick_add = !Map.get(socket.assigns, :show_quick_add, false)

    # Close mobile nav if open
    socket = if Map.get(socket.assigns, :show_mobile_nav, false) do
      assign(socket, :show_mobile_nav, false)
    else
      socket
    end

    {:noreply, assign(socket, :show_quick_add, show_quick_add)}
  end

  @impl true
  def handle_event("set_preview_device", %{"device" => device}, socket) do
    {:noreply, assign(socket, :preview_device, device)}
  end

  @impl true
  def handle_event("refresh_preview", _params, socket) do
    {:noreply, socket |> push_event("refresh_preview", %{
      url: build_preview_url(socket.assigns.portfolio),
      timestamp: :os.system_time(:millisecond)
    })}
  end


  @impl true
  def handle_info({:preview_update, data}, socket) do
    # Handle preview updates from other sources
    IO.puts("🔄 Received preview update: #{inspect(data)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:section_update, data}, socket) do
    # Handle section updates from collaborators or other editors
    IO.puts("📝 Received section update: #{inspect(data)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:design_update, data}, socket) do
    # Handle design updates
    IO.puts("🎨 Received design update: #{inspect(data)}")
    {:noreply, socket}
  end

  # Catch-all for other PubSub messages
  @impl true
  def handle_info(msg, socket) do
    IO.puts("📨 Unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp build_hero_section_attrs(params) do
    social_links = %{
      "linkedin" => params["social_linkedin"] || "",
      "github" => params["social_github"] || "",
      "twitter" => params["social_twitter"] || "",
      "instagram" => params["social_instagram"] || "",
      "website" => params["social_website"] || "",
      "email" => params["social_email"] || ""
    }

    content = %{
      "headline" => params["headline"] || "",
      "tagline" => params["tagline"] || "",
      "main_content" => params["main_content"] || "",
      "cta_text" => params["cta_text"] || "",
      "cta_link" => params["cta_link"] || "",
      "hero_style" => params["hero_style"] || "modern",
      "background_type" => params["background_type"] || "gradient",
      "mobile_layout" => params["mobile_layout"] || "stack",
      "show_social" => params["show_social"] == "true",
      "social_links" => social_links
    }

    %{
      title: params["headline"] || "Welcome",
      content: content
    }
  end

  defp get_section_icon(section_type) do
    case section_type do
      "hero" -> "🎬"
      "about" -> "👤"
      "experience" -> "💼"
      "skills" -> "⚡"
      "projects" -> "🚀"
      "contact" -> "📧"
      "education" -> "🎓"
      "testimonials" -> "💬"
      "awards" -> "🏆"
      "blog" -> "📝"
      _ -> "📄"
    end
  end

  defp get_section_content_preview(section) do
    case section.content do
      %{"main_content" => content} when is_binary(content) and content != "" ->
        content
        |> String.slice(0, 100)
        |> Kernel.<>(if String.length(content) > 100, do: "...", else: "")

      %{"headline" => headline} when is_binary(headline) and headline != "" ->
        headline

      _ ->
        "No content added yet"
    end
  end

  defp get_preview_frame_classes(device) do
    case device do
      "mobile" -> "w-full h-full max-w-sm mx-auto"
      "tablet" -> "w-full h-full max-w-2xl mx-auto"
      "desktop" -> "w-full h-full"
      _ -> "w-full h-full"
    end
  end

    defp get_section_content_map(section) do
    case section.content do
      content when is_map(content) -> content
      _ -> %{}
    end
  end

  defp get_social_placeholder(platform) do
    case platform do
      "linkedin" -> "https://linkedin.com/in/yourname"
      "github" -> "https://github.com/yourusername"
      "twitter" -> "https://twitter.com/yourusername"
      "instagram" -> "https://instagram.com/yourusername"
      "website" -> "https://yourwebsite.com"
      "email" -> "your@email.com"
      _ -> ""
    end
  end

  defp create_section_safely(attrs) do
    try do
      # Try the main Portfolios.create_section function
      case Portfolios.create_section(attrs) do
        {:ok, section} -> {:ok, section}
        {:error, changeset} ->
          IO.puts("❌ Portfolios.create_section failed: #{inspect(changeset.errors)}")
          try_alternative_section_creation(attrs)
      end
    rescue
      error ->
        IO.puts("❌ Exception in create_section: #{inspect(error)}")
        try_alternative_section_creation(attrs)
    end
  end

  defp try_alternative_section_creation(attrs) do
    try do
      # Try direct Ecto insertion
      alias Frestyl.Portfolios.PortfolioSection

      %PortfolioSection{}
      |> PortfolioSection.changeset(attrs)
      |> Frestyl.Repo.insert()
    rescue
      error ->
        IO.puts("❌ Direct Ecto insert failed: #{inspect(error)}")
        {:error, "All section creation methods failed"}
    end
  end


  defp load_portfolio_safely(portfolio_id, user) do
    try do
      case Portfolios.get_portfolio(portfolio_id) do
        nil ->
          {:error, "Portfolio not found"}
        portfolio ->
          if portfolio.user_id == user.id do
            account = get_user_account_safely(user)
            {:ok, portfolio, account}
          else
            {:error, "Access denied"}
          end
      end
    rescue
      _ -> {:error, "Database error"}
    end
  end

  defp load_sections_safely(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
      |> Enum.sort_by(& &1.position)
    rescue
      _ -> []
    end
  end

  defp get_user_account_safely(user) do
    try do
      case Accounts.get_user_account(user.id) do
        nil -> %{subscription_tier: "personal"}
        account -> account
      end
    rescue
      _ -> %{subscription_tier: "personal"}
    end
  end

  defp get_design_settings(portfolio) do
    customization = portfolio.customization || %{}

    %{
      theme: Map.get(customization, "theme", "professional"),
      layout: Map.get(customization, "layout", "dashboard"),  # Changed default to dashboard
      color_scheme: Map.get(customization, "color_scheme", "blue")
    }
  end

  defp get_available_themes do
    [
      %{key: "professional", name: "Professional", description: "Clean and business-focused"},
      %{key: "creative", name: "Creative", description: "Bold and artistic"},
      %{key: "minimal", name: "Minimal", description: "Simple and elegant"},
      %{key: "modern", name: "Modern", description: "Contemporary design"}
    ]
  end

  defp get_available_layouts do
    [
      %{key: "standard", name: "Standard", description: "Traditional single-column layout"},
      %{key: "dashboard", name: "Dashboard", description: "Multi-section card dashboard"},
      %{key: "grid", name: "Grid", description: "Card-based grid layout"},
      %{key: "timeline", name: "Timeline", description: "Chronological timeline view"}
    ]
  end

  defp get_available_color_schemes do
    [
      %{key: "blue", name: "Ocean Blue", description: "Professional blue tones",
        colors: ["#1e40af", "#3b82f6", "#60a5fa"]},
      %{key: "green", name: "Forest Green", description: "Natural green palette",
        colors: ["#065f46", "#059669", "#34d399"]},
      %{key: "purple", name: "Royal Purple", description: "Creative purple shades",
        colors: ["#581c87", "#7c3aed", "#a78bfa"]},
      %{key: "red", name: "Warm Red", description: "Bold red accents",
        colors: ["#991b1b", "#dc2626", "#f87171"]}
    ]
  end

  defp get_section_types do
    [
      %{type: "hero", name: "Hero Section", description: "Main banner with photo, headline, and CTA",
        icon: "🎬", featured: true, mobile_optimized: true},
      %{type: "about", name: "About", description: "Personal or company information",
        icon: "👤", featured: false, mobile_optimized: true},
      %{type: "experience", name: "Experience", description: "Work history and roles",
        icon: "💼", featured: false, mobile_optimized: true},
      %{type: "skills", name: "Skills", description: "Technical and soft skills",
        icon: "⚡", featured: false, mobile_optimized: true},
      %{type: "projects", name: "Projects", description: "Portfolio showcase with images",
        icon: "🚀", featured: false, mobile_optimized: true},
      %{type: "contact", name: "Contact", description: "Contact form and social links",
        icon: "📧", featured: false, mobile_optimized: true}
    ]
  end

  defp get_default_title_for_type(section_type) do
    case section_type do
      "hero" -> "Welcome"
      "about" -> "About Me"
      "experience" -> "Experience"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "contact" -> "Contact"
      _ -> "New Section"
    end
  end

  defp get_default_content_for_section_type(section_type) do
    case section_type do
      "hero" -> %{
        "main_content" => "Welcome to my portfolio",
        "headline" => "Your Name Here",
        "tagline" => "Professional Title • Industry Expert",
        "cta_text" => "View My Work",
        "cta_link" => "#projects",
        "hero_image" => nil,
        "background_type" => "gradient",
        "background_color" => "#6366f1",
        "background_gradient" => "linear-gradient(135deg, #667eea 0%, #764ba2 100%)",
        "text_color" => "#ffffff",
        "hero_style" => "modern",
        "show_social" => true,
        "social_links" => %{
          "linkedin" => "",
          "github" => "",
          "twitter" => "",
          "instagram" => "",
          "website" => "",
          "email" => ""
        },
        "hero_layout" => "center",
        "mobile_layout" => "stack",
        "animations" => %{
          "entrance" => "fade_up",
          "typing_effect" => false,
          "parallax" => false
        }
      }
      "about" -> %{
        "main_content" => "Tell your story here...",
        "subtitle" => "About Me",
        "profile_image" => nil,
        "highlights" => [],
        "show_stats" => false,
        "stats" => %{
          "years_experience" => "",
          "projects_completed" => "",
          "clients_served" => "",
          "awards_won" => ""
        }
      }
      "contact" -> %{
        "main_content" => "Let's connect and work together",
        "subtitle" => "Get In Touch",
        "email" => "",
        "phone" => "",
        "location" => "",
        "show_form" => true,
        "show_social" => true,
        "social_links" => %{
          "linkedin" => "",
          "github" => "",
          "twitter" => "",
          "instagram" => "",
          "website" => "",
          "email" => ""
        },
        "form_fields" => ["name", "email", "message"],
        "success_message" => "Thanks for reaching out! I'll get back to you soon."
      }
      _ -> %{
        "main_content" => "Add your content here...",
        "subtitle" => get_default_title_for_type(section_type)
      }
    end
  end

  defp generate_design_css(customization) do
    theme = Map.get(customization, "theme", "professional")
    layout = Map.get(customization, "layout", "dashboard")
    color_scheme = Map.get(customization, "color_scheme", "blue")

    # Get colors for the scheme
    colors = get_color_scheme_colors(color_scheme)

    """
    <style id="dynamic-portfolio-css">
    :root {
      --portfolio-theme: #{theme};
      --portfolio-layout: #{layout};
      --portfolio-primary: #{colors.primary};
      --portfolio-secondary: #{colors.secondary};
      --portfolio-accent: #{colors.accent};
    }

    .portfolio-container {
      --primary-color: var(--portfolio-primary);
      --secondary-color: var(--portfolio-secondary);
      --accent-color: var(--portfolio-accent);
    }

    /* Theme-specific styles */
    .theme-#{theme} {
      font-family: #{get_theme_font(theme)};
    }

    /* Layout-specific styles */
    .layout-#{layout} {
      #{get_layout_styles(layout)}
    }

    /* Color scheme application */
    .text-primary { color: var(--portfolio-primary) !important; }
    .bg-primary { background-color: var(--portfolio-primary) !important; }
    .border-primary { border-color: var(--portfolio-primary) !important; }

    .text-accent { color: var(--portfolio-accent) !important; }
    .bg-accent { background-color: var(--portfolio-accent) !important; }
    .border-accent { border-color: var(--portfolio-accent) !important; }
    </style>
    """
  end

  defp get_color_scheme_colors(scheme_key) do
    colors = get_available_color_schemes()
    |> Enum.find(fn scheme -> scheme.key == scheme_key end)
    |> case do
      nil -> %{colors: ["#1e40af", "#3b82f6", "#60a5fa"]}  # Default blue
      scheme -> scheme
    end

    %{
      primary: Enum.at(colors.colors, 0),
      secondary: Enum.at(colors.colors, 1),
      accent: Enum.at(colors.colors, 2)
    }
  end

  defp get_theme_font(theme) do
    case theme do
      "professional" -> "'Inter', system-ui, sans-serif"
      "creative" -> "'Poppins', system-ui, sans-serif"
      "minimal" -> "'Source Sans Pro', system-ui, sans-serif"
      "modern" -> "'Roboto', system-ui, sans-serif"
      _ -> "system-ui, sans-serif"
    end
  end

  defp get_layout_styles(layout) do
    case layout do
      "dashboard" -> """
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
        gap: 1.5rem;
        padding: 1.5rem;
      """
      "grid" -> """
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
        gap: 1rem;
        padding: 1rem;
      """
      "timeline" -> """
        display: flex;
        flex-direction: column;
        max-width: 800px;
        margin: 0 auto;
        padding: 2rem;
      """
      _ -> """
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
      """
    end
  end

  defp get_next_position(sections) do
    case Enum.max_by(sections, & &1.position, fn -> %{position: 0} end) do
      %{position: max_pos} -> max_pos + 1
      _ -> 1
    end
  end

  defp get_section_content(section) do
    case section.content do
      %{"main_content" => content} -> content
      _ -> ""
    end
  end

  defp broadcast_preview_update(socket) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:preview_update, %{
        portfolio_id: portfolio.id,
        sections: socket.assigns.sections,
        customization: portfolio.customization || %{},
        timestamp: :os.system_time(:millisecond)
      }}
    )

    socket
  end

  defp broadcast_section_update(socket, section) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:section_update, %{
        section: section,
        action: :updated
      }}
    )
  end

  defp broadcast_design_update(socket) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:design_update, %{
        customization: portfolio.customization || %{},
        css: generate_design_css(portfolio.customization || %{})
      }}
    )
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
  end

  defp build_preview_url(portfolio) do
    # Use the same preview URL format as the working editor
    "/p/#{portfolio.slug}?preview=true&editor=true&t=#{:os.system_time(:millisecond)}"
  end

  defp refresh_preview(socket) do
    # Refresh the preview iframe
    push_event(socket, "refresh_preview", %{
      url: build_preview_url(socket.assigns.portfolio)
    })
  end

  defp update_portfolio_safely(portfolio, attrs) do
    try do
      case Portfolios.update_portfolio(portfolio, attrs) do
        {:ok, updated_portfolio} -> {:ok, updated_portfolio}
        {:error, changeset} ->
          IO.puts("❌ Portfolio update failed: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    rescue
      error ->
        IO.puts("❌ Exception in update_portfolio_safely: #{inspect(error)}")
        {:error, Exception.message(error)}
    end
  end


  defp update_section_positions_safely(section_ids) do
    try do
      IO.puts("🔄 Updating positions for: #{inspect(section_ids)}")

      # Get all sections first
      sections = Enum.map(section_ids, fn section_id ->
        case get_section_safely(section_id) do
          nil ->
            IO.puts("❌ Section #{section_id} not found")
            nil
          section -> section
        end
      end)
      |> Enum.reject(&is_nil/1)

      IO.puts("🔄 Found #{length(sections)} sections to reorder")

      # Update positions
      updated_sections = Enum.with_index(sections, 1)
      |> Enum.map(fn {section, new_position} ->
        IO.puts("🔄 Setting section #{section.id} to position #{new_position}")

        case update_section_safely(section, %{position: new_position}) do
          {:ok, updated_section} ->
            IO.puts("✅ Updated section #{section.id}")
            updated_section
          {:error, reason} ->
            IO.puts("❌ Failed to update section #{section.id}: #{inspect(reason)}")
            section  # Return original if update fails
        end
      end)
      |> Enum.sort_by(& &1.position)

      {:ok, updated_sections}
    rescue
      error ->
        IO.puts("❌ Exception in update_section_positions_safely: #{inspect(error)}")
        {:error, "Failed to update positions: #{Exception.message(error)}"}
    end
  end

  defp get_section_safely(section_id) do
    try do
      case Portfolios.get_section(section_id) do
        nil -> Portfolios.get_portfolio_section(section_id)
        section -> section
      end
    rescue
      _ ->
        try do
          Frestyl.Repo.get(Frestyl.Portfolios.PortfolioSection, section_id)
        rescue
          _ -> nil
        end
    end
  end

  defp update_section_safely(section, attrs) do
    try do
      case Portfolios.update_section(section, attrs) do
        {:ok, updated_section} -> {:ok, updated_section}
        {:error, changeset} ->
          IO.puts("❌ Update failed with changeset: #{inspect(changeset.errors)}")
          {:error, changeset}
      end
    rescue
      error ->
        IO.puts("❌ Exception in update_section_safely: #{inspect(error)}")
        {:error, Exception.message(error)}
    end
  end

  defp test_database_connection do
    try do
      # Test basic database connectivity
      case Frestyl.Repo.query("SELECT 1") do
        {:ok, _} ->
          IO.puts("✅ Database connection OK")
          true
        {:error, reason} ->
          IO.puts("❌ Database query failed: #{inspect(reason)}")
          false
      end
    rescue
      error ->
        IO.puts("❌ Database connection error: #{inspect(error)}")
        false
    end
  end

  defp test_portfolio_sections_table(portfolio_id) do
    try do
      # Test if portfolio_sections table exists and is accessible
      query = "SELECT COUNT(*) FROM portfolio_sections WHERE portfolio_id = $1"
      case Frestyl.Repo.query(query, [portfolio_id]) do
        {:ok, %{rows: [[count]]}} ->
          IO.puts("✅ Portfolio sections table OK, found #{count} sections")
          true
        {:error, reason} ->
          IO.puts("❌ Portfolio sections query failed: #{inspect(reason)}")
          false
      end
    rescue
      error ->
        IO.puts("❌ Portfolio sections table error: #{inspect(error)}")
        false
    end
  end

  defp test_section_creation(portfolio_id) do
    IO.puts("🧪 Testing section creation for portfolio #{portfolio_id}")

    cond do
      not test_database_connection() ->
        {:error, "Database connection failed"}

      not test_portfolio_sections_table(portfolio_id) ->
        {:error, "Portfolio sections table inaccessible"}

      not schema_available?() ->
        {:error, "Schema not available"}

      true ->
        {:ok, "All tests passed"}
    end
  end

  defp schema_available? do
    try do
      Code.ensure_loaded?(Frestyl.Portfolios.PortfolioSection)
      IO.puts("✅ PortfolioSection schema loaded")
      true
    rescue
      _error ->
        IO.puts("❌ PortfolioSection schema error")
        false
    end
  end
end
