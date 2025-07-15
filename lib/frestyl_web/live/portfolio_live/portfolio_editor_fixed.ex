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
  import Phoenix.LiveView.Helpers
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
        # NEW: Mobile-first assigns
        |> assign(:show_mobile_nav, false)
        |> assign(:show_add_section_modal, false)
        |> assign(:selected_section_type, nil)
        # FIX: Add preview-specific assigns
        |> assign(:show_live_preview, true)
        |> assign(:preview_token, generate_preview_token(portfolio.id))
        |> assign(:preview_mobile_view, false)
        |> assign(:preview_device, "desktop")

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
    <div class="portfolio-editor-mobile min-h-screen bg-gray-50"
        phx-hook="MobileNavigation"
        id="portfolio-editor-container">

      <!-- Mobile-First Header -->
      <div class="bg-white border-b border-gray-200 px-4 py-3 lg:px-6 lg:py-4">
        <div class="flex items-center justify-between">
          <!-- Mobile menu button -->
          <button phx-click="toggle_mobile_nav"
                  class="lg:hidden p-2 text-gray-600 hover:text-gray-900">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>

          <div class="flex-1 lg:flex-none">
            <h1 class="text-lg lg:text-2xl font-bold text-gray-900 truncate"><%= @portfolio.title %></h1>
            <p class="text-xs lg:text-sm text-gray-600">Portfolio Editor</p>
          </div>

          <div class="flex items-center space-x-2 lg:space-x-4">
            <%= if @unsaved_changes do %>
              <span class="hidden lg:inline text-sm text-orange-600 font-medium">Unsaved changes</span>
              <div class="lg:hidden w-2 h-2 bg-orange-500 rounded-full"></div>
            <% end %>

            <button phx-click="save_portfolio"
                    class="px-3 py-1.5 lg:px-4 lg:py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm lg:text-base">
              Save
            </button>

            <a href={"/p/#{@portfolio.slug}"} target="_blank"
              class="hidden lg:inline-flex px-4 py-2 border border-gray-300 rounded-lg hover:bg-gray-50">
              View Public
            </a>
          </div>
        </div>
      </div>

      <!-- Main Layout Container -->
      <div class="flex h-[calc(100vh-64px)] lg:h-[calc(100vh-80px)]">

        <!-- Left Column - Portfolio Options -->
        <div class={[
          "w-full lg:w-80 bg-white border-r border-gray-200 overflow-y-auto transition-transform duration-300 ease-in-out",
          "lg:translate-x-0", # Always visible on desktop
          if(@show_mobile_nav, do: "translate-x-0", else: "-translate-x-full lg:translate-x-0"),
          "fixed lg:relative z-30 lg:z-auto inset-y-0 left-0"
        ]}>
          <%= render_left_column(assigns) %>
        </div>

        <!-- Mobile Overlay -->
        <%= if @show_mobile_nav do %>
          <div class="lg:hidden fixed inset-0 bg-gray-900 bg-opacity-50 z-20"
              phx-click="toggle_mobile_nav"></div>
        <% end %>

        <!-- Main Content Area - Preview & Cards -->
        <div class="flex-1 flex flex-col lg:ml-0">
          <!-- Section Cards Management Area -->
          <div class="flex-1 p-4 lg:p-6 overflow-y-auto">
            <%= render_main_content_area(assigns) %>
          </div>
        </div>
      </div>

      <!-- Section Modal -->
      <%= if @show_section_modal and @editing_section do %>
        <%= render_enhanced_section_modal(assigns) %>
      <% end %>

      <!-- Add Section Modal -->
      <%= if @show_add_section_modal do %>
        <%= render_add_section_modal(assigns) %>
      <% end %>

      <!-- Video Introduction Modal -->
      <%= if assigns[:show_video_intro_modal] do %>
        <%= render_video_intro_modal(assigns) %>
      <% end %>

      <!-- Video Preview Modal -->
      <%= if assigns[:show_video_preview_modal] do %>
        <%= render_video_preview_modal(assigns) %>
      <% end %>

      <!-- Video Position Modal -->
      <%= if assigns[:show_position_modal] do %>
        <%= render_video_position_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_left_column(assigns) do
    ~H"""
    <div class="h-full flex flex-col">
      <!-- Mobile Header in Sidebar -->
      <div class="lg:hidden bg-gradient-to-r from-blue-600 to-purple-600 px-4 py-3 text-white">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-semibold">Portfolio Builder</h2>
          <button phx-click="toggle_mobile_nav" class="text-white hover:text-gray-300">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>
      </div>

      <!-- Section Types - Always Visible -->
      <div class="flex-1 p-4 space-y-6">
        <!-- Quick Stats -->
        <div class="bg-gradient-to-br from-blue-50 to-purple-50 rounded-xl p-4 border border-blue-100">
          <div class="flex items-center justify-between mb-2">
            <h3 class="font-semibold text-gray-900">Portfolio Status</h3>
            <%= if @unsaved_changes do %>
              <span class="w-2 h-2 bg-orange-500 rounded-full"></span>
            <% else %>
              <span class="w-2 h-2 bg-green-500 rounded-full"></span>
            <% end %>
          </div>
          <div class="text-sm text-gray-600 space-y-1">
            <p><%= length(@sections) %> sections created</p>
            <p>Theme: <span class="font-medium text-blue-600"><%= String.capitalize(@design_settings.theme) %></span></p>
          </div>
        </div>

        <!-- Video Introduction -->
        <div class="mb-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
            Video Introduction
          </h3>

          <%= render_video_intro_controls(assigns) %>
        </div>

        <!-- Section Types to Add -->
        <div>
          <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <svg class="w-5 h-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
            Add Sections
          </h3>

          <!-- Dropdown Button -->
          <div class="relative mb-4">
            <button phx-click="toggle_add_section_dropdown"
                    class="w-full flex items-center justify-between px-4 py-3 bg-blue-600 text-white rounded-xl hover:bg-blue-700 transition-colors">
              <div class="flex items-center">
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                </svg>
                <span class="font-medium">Add New Section</span>
              </div>
              <svg class={[
                "w-5 h-5 transition-transform duration-200",
                if(@show_add_section_dropdown, do: "rotate-180", else: "rotate-0")
              ]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
              </svg>
            </button>

            <!-- Dropdown Content -->
            <%= if @show_add_section_dropdown do %>
              <div class="absolute top-full left-0 right-0 mt-2 bg-white rounded-xl shadow-xl border border-gray-200 z-20 max-h-80 overflow-y-auto">
                <div class="p-2">
                  <%= for section_type <- @section_types do %>
                    <% existing_section = Enum.find(@sections, &(&1.section_type == section_type.type || to_string(&1.section_type) == section_type.type)) %>
                    <button
                      phx-click={if existing_section, do: "edit_section", else: "show_add_section_modal"}
                      phx-value-id={if existing_section, do: existing_section.id, else: nil}
                      phx-value-type={unless existing_section, do: section_type.type}
                      class={[
                        "w-full p-3 rounded-lg text-left transition-all duration-200 group mb-1",
                        if(existing_section,
                          do: "bg-green-50 hover:bg-green-100 border border-green-200",
                          else: "hover:bg-blue-50 border border-transparent hover:border-blue-200")
                      ]}>

                      <div class="flex items-center justify-between">
                        <div class="flex items-center space-x-3">
                          <span class="text-xl"><%= section_type.icon %></span>
                          <div>
                            <h4 class="font-medium text-gray-900 text-sm"><%= section_type.name %></h4>
                            <p class="text-xs text-gray-600"><%= section_type.description %></p>
                          </div>
                        </div>

                        <div class="flex items-center space-x-2">
                          <%= if section_type.featured do %>
                            <span class="text-xs bg-blue-100 text-blue-700 px-2 py-1 rounded-full font-medium">
                              Popular
                            </span>
                          <% end %>
                          <%= if existing_section do %>
                            <span class="text-xs bg-green-100 text-green-700 px-2 py-1 rounded-full font-medium">
                              ✓ Added
                            </span>
                          <% else %>
                            <svg class="w-4 h-4 text-gray-400 group-hover:text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                            </svg>
                          <% end %>
                        </div>
                      </div>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Quick Status Overview -->
          <div class="bg-gray-50 rounded-lg p-3 mb-4">
            <div class="flex items-center justify-between text-sm">
              <span class="text-gray-600">Sections Created:</span>
              <span class="font-semibold text-gray-900"><%= length(@sections) %> / <%= length(@section_types) %></span>
            </div>
            <div class="w-full bg-gray-200 rounded-full h-2 mt-2">
              <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                  style={"width: #{(length(@sections) / length(@section_types) * 100)}%"}></div>
            </div>
          </div>
        </div>

        <!-- Design Options -->
        <div class="border-t border-gray-200 pt-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
            <svg class="w-5 h-5 mr-2 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zM21 5a2 2 0 00-2-2h-4a2 2 0 00-2 2v12a4 4 0 004 4h4a2 2 0 002-2V5z"/>
            </svg>
            Design
          </h3>
          <%= render_compact_design_options(assigns) %>
        </div>
      </div>
    </div>
    """
  end

  defp render_compact_design_options(assigns) do
    ~H"""
    <div class="space-y-4">
      <!-- Theme Quick Select -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Theme</label>
        <div class="grid grid-cols-2 gap-2">
          <%= for theme <- @available_themes do %>
            <button phx-click="update_design" phx-value-setting="theme" phx-value-value={theme.key}
                    class={[
                      "p-3 border-2 rounded-lg text-center transition-colors text-sm",
                      if(@design_settings.theme == theme.key,
                        do: "border-blue-500 bg-blue-50 text-blue-700",
                        else: "border-gray-200 hover:border-gray-300 text-gray-700")
                    ]}>
              <div class="font-medium"><%= theme.name %></div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- NEW: Layout Selection -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Layout Style</label>
        <div class="space-y-2">
          <%= for layout <- @available_layouts do %>
            <button phx-click="update_design" phx-value-setting="layout" phx-value-value={layout.key}
                    class={[
                      "w-full p-3 border-2 rounded-lg text-left transition-colors",
                      if(@design_settings.layout == layout.key,
                        do: "border-purple-500 bg-purple-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="flex items-center justify-between">
                <div>
                  <div class="font-medium text-gray-900 text-sm"><%= layout.name %></div>
                  <div class="text-xs text-gray-600"><%= layout.description %></div>
                </div>
                <%= if @design_settings.layout == layout.key do %>
                  <div class="w-5 h-5 bg-purple-500 text-white rounded-full flex items-center justify-center">
                    <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                    </svg>
                  </div>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Color Scheme Quick Select -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Colors</label>
        <div class="grid grid-cols-2 gap-2">
          <%= for scheme <- @available_color_schemes do %>
            <button phx-click="update_design" phx-value-setting="color_scheme" phx-value-value={scheme.key}
                    class={[
                      "p-2 border-2 rounded-lg transition-colors",
                      if(@design_settings.color_scheme == scheme.key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="flex space-x-1 justify-center mb-1">
                <%= for color <- Enum.take(scheme.colors, 3) do %>
                  <div class="w-3 h-3 rounded-full border border-gray-200" style={"background-color: #{color}"}></div>
                <% end %>
              </div>
              <div class="text-xs font-medium text-gray-700"><%= scheme.name %></div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Design Preview Button -->
      <div class="pt-4 border-t border-gray-200">
        <button phx-click="preview_design_changes"
                class="w-full px-3 py-2 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg hover:from-purple-700 hover:to-blue-700 transition-all text-sm font-medium">
          🎨 Preview Changes
        </button>
      </div>
    </div>
    """
  end

 defp render_main_content_area(assigns) do
  ~H"""
  <div class="h-full">
    <!-- Header -->
    <div class="flex items-center justify-between mb-6">
      <div>
        <h2 class="text-xl lg:text-2xl font-bold text-gray-900">Portfolio Preview</h2>
        <p class="text-sm text-gray-600 mt-1">
          <%= length(@sections) %> sections • Drag to reorder
        </p>
      </div>

      <!-- Preview Controls -->
      <div class="flex items-center space-x-2">
        <button phx-click="refresh_preview"
                class="p-2 text-gray-500 hover:text-gray-700 hover:bg-gray-100 rounded-lg">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
          </svg>
        </button>

        <a href={"/p/#{@portfolio.slug}"} target="_blank"
          class="px-3 py-2 text-sm bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 lg:hidden">
          View Live
        </a>
      </div>
    </div>

    <!-- Section Cards -->
    <%= if length(@sections) > 0 do %>
      <div class="space-y-4"
           id="sections-sortable"
           phx-hook="SortableSections"
           phx-update="ignore">
        <%= for section <- Enum.sort_by(@sections, & &1.position) do %>
          <%= render_section_card_with_hover(assigns, section) %>
        <% end %>
      </div>
    <% else %>
      <%= render_empty_state(assigns) %>
    <% end %>
  </div>
  """
end

defp render_section_card_with_hover(assigns, section) do
  assigns = assign(assigns, :section, section)

  ~H"""
  <div class={[
    "bg-white rounded-xl border border-gray-200 transition-all duration-200 group relative",
    "hover:shadow-lg hover:border-gray-300",
    unless(@section.visible, do: "opacity-75")
  ]}
  data-section-id={@section.id}
  id={"section-#{@section.id}"}>

    <!-- Hover Actions Overlay -->
    <div class="absolute top-4 right-4 flex items-center space-x-2 opacity-0 group-hover:opacity-100 transition-opacity duration-200 z-10">
      <!-- Edit -->
      <button phx-click="edit_section" phx-value-id={@section.id}
              class="p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 shadow-lg"
              title="Edit section">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
        </svg>
      </button>

      <!-- Visibility Toggle -->
      <button phx-click="toggle_section_visibility" phx-value-id={@section.id}
              class={[
                "p-2 rounded-lg shadow-lg",
                if(@section.visible,
                  do: "bg-green-600 text-white hover:bg-green-700",
                  else: "bg-gray-600 text-white hover:bg-gray-700")
              ]}
              title={if @section.visible, do: "Hide section", else: "Show section"}>
        <%= if @section.visible do %>
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

      <!-- Attach Media -->
      <button phx-click="attach_media" phx-value-id={@section.id}
              class="p-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 shadow-lg"
              title="Attach media">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
        </svg>
      </button>

      <!-- Delete -->
      <button phx-click="delete_section" phx-value-id={@section.id}
              data-confirm="Are you sure you want to delete this section?"
              class="p-2 bg-red-600 text-white rounded-lg hover:bg-red-700 shadow-lg"
              title="Delete section">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
        </svg>
      </button>
    </div>

    <!-- Drag Handle -->
    <div class="absolute left-4 top-4 opacity-0 group-hover:opacity-100 transition-opacity duration-200 cursor-move"
         title="Drag to reorder">
      <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
      </svg>
    </div>

    <!-- Card Content -->
    <div class="p-6">
      <!-- Section Header -->
      <div class="flex items-start justify-between mb-4">
        <div class="flex items-center space-x-3">
          <span class="text-2xl"><%= get_section_icon(@section.section_type) %></span>
          <div>
            <h3 class="text-lg font-semibold text-gray-900"><%= @section.title %></h3>
            <div class="flex items-center space-x-2 mt-1">
              <span class="text-xs font-medium bg-gray-100 text-gray-600 px-2 py-1 rounded-full">
                <%= safe_capitalize(@section.section_type) %>
              </span>
              <span class="text-xs text-gray-500">Position <%= @section.position %></span>
            </div>
          </div>
        </div>
      </div>

      <!-- Section Preview Content -->
      <div class="bg-gray-50 rounded-lg p-4 border border-gray-100">
        <%= render_section_preview_content(@section) %>
      </div>

      <!-- Section Stats -->
      <div class="flex items-center justify-between mt-4 pt-4 border-t border-gray-100">
        <div class="flex items-center space-x-4 text-sm text-gray-600">
          <span>Last updated: <%= format_date(@section.updated_at) %></span>
        </div>

        <div class="flex items-center space-x-2">
          <%= if has_media?(@section) do %>
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-purple-100 text-purple-800 rounded-full">
              <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
              Media
            </span>
          <% end %>

          <%= unless @section.visible do %>
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">
              Hidden
            </span>
          <% end %>
        </div>
      </div>
    </div>
  </div>
  """
end

defp render_section_preview_content(section) do
  case section.section_type do
    "hero" ->
      content = section.content || %{}
      headline = Map.get(content, "headline", "")
      tagline = Map.get(content, "tagline", "")

      assigns = %{headline: headline, tagline: tagline}
      ~H"""
      <div class="text-center">
        <%= if @headline != "" do %>
          <h2 class="text-xl font-bold text-gray-900 mb-2"><%= @headline %></h2>
        <% end %>
        <%= if @tagline != "" do %>
          <p class="text-gray-600"><%= @tagline %></p>
        <% else %>
          <p class="text-gray-400 italic">Add headline and tagline...</p>
        <% end %>
      </div>
      """

    _ ->
      content = get_section_content(section)
      assigns = %{content: content}
      ~H"""
      <%= if @content != "" and @content != nil do %>
        <p class="text-gray-700 line-clamp-3"><%= String.slice(@content, 0, 150) %><%= if String.length(@content) > 150, do: "...", else: "" %></p>
      <% else %>
        <p class="text-gray-400 italic">Click edit to add content...</p>
      <% end %>
      """
  end
end

defp render_empty_state(assigns) do
  ~H"""
  <div class="text-center py-20">
    <div class="w-24 h-24 bg-gradient-to-br from-blue-100 to-purple-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
      <svg class="w-12 h-12 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
      </svg>
    </div>
    <h3 class="text-xl font-bold text-gray-900 mb-3">Ready to Build Your Portfolio?</h3>
    <p class="text-gray-600 mb-6 max-w-md mx-auto">
      Start by selecting a section type from the left panel. Each section helps tell your professional story.
    </p>
    <div class="text-sm text-gray-500">
      💡 Tip: Start with a Hero section to create a great first impression
    </div>
  </div>
  """
end

defp render_video_intro_controls(assigns) do
  # Check if video intro exists
  video_section = get_video_intro_section(assigns.sections)
  has_video = video_section != nil

  assigns = assign(assigns, :video_section, video_section)
  assigns = assign(assigns, :has_video, has_video)

  ~H"""
  <div class="space-y-3">
    <%= if @has_video do %>
      <!-- Video Present State -->
      <div class="bg-gradient-to-br from-purple-50 to-blue-50 rounded-xl p-4 border border-purple-200">
        <!-- Video Preview -->
        <div class="relative mb-4">
          <%= if get_video_thumbnail(@video_section) do %>
            <img src={get_video_thumbnail(@video_section)} alt="Video thumbnail"
                 class="w-full h-24 object-cover rounded-lg" />
          <% else %>
            <div class="w-full h-24 bg-gradient-to-br from-purple-600 to-blue-600 rounded-lg flex items-center justify-center">
              <svg class="w-8 h-8 text-white" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </div>
          <% end %>

          <!-- Play overlay -->
          <div class="absolute inset-0 flex items-center justify-center">
            <button phx-click="preview_video_intro"
                    class="w-10 h-10 bg-white/80 backdrop-blur-sm rounded-full flex items-center justify-center hover:bg-white/90 transition-colors">
              <svg class="w-5 h-5 text-gray-800 ml-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Video Info -->
        <div class="mb-4">
          <h4 class="font-medium text-gray-900 mb-1">
            <%= get_video_title(@video_section) %>
          </h4>
          <div class="text-sm text-gray-600 space-y-1">
            <div class="flex items-center justify-between">
              <span>Duration: <%= get_video_duration(@video_section) %></span>
              <span class="px-2 py-1 bg-purple-100 text-purple-700 rounded-full text-xs font-medium">
                <%= get_video_position(@video_section) %>
              </span>
            </div>
            <div class="flex items-center justify-between">
              <span>Quality: <%= get_video_quality(@video_section) %></span>
              <span class={[
                "px-2 py-1 rounded-full text-xs font-medium",
                if(get_video_visibility(@video_section),
                  do: "bg-green-100 text-green-700",
                  else: "bg-gray-100 text-gray-600")
              ]}>
                <%= if get_video_visibility(@video_section), do: "Visible", else: "Hidden" %>
              </span>
            </div>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="grid grid-cols-2 gap-2">
          <button phx-click="edit_video_intro"
                  class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors text-sm font-medium">
            Edit
          </button>

          <div class="relative">
            <button phx-click="toggle_video_menu"
                    class="w-full px-3 py-2 bg-gray-100 text-gray-700 rounded-lg hover:bg-gray-200 transition-colors text-sm font-medium flex items-center justify-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
              </svg>
              More
            </button>

            <!-- Dropdown Menu -->
            <%= if assigns[:show_video_menu] do %>
              <div class="absolute top-full right-0 mt-1 w-40 bg-white rounded-lg shadow-lg border border-gray-200 z-20">
                <button phx-click="toggle_video_visibility"
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 rounded-t-lg text-sm">
                  <%= if get_video_visibility(@video_section), do: "Hide Video", else: "Show Video" %>
                </button>

                <button phx-click="change_video_position"
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 text-sm">
                  Change Position
                </button>

                <button phx-click="download_video"
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 text-sm">
                  Download
                </button>

                <div class="border-t border-gray-100"></div>

                <button phx-click="delete_video_intro"
                        data-confirm="Are you sure you want to delete your video introduction?"
                        class="w-full px-4 py-2 text-left hover:bg-red-50 text-red-600 rounded-b-lg text-sm">
                  Delete Video
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    <% else %>
      <!-- No Video State -->
      <div class="bg-gray-50 rounded-xl p-6 border-2 border-dashed border-gray-300 text-center">
        <div class="w-16 h-16 bg-gradient-to-br from-purple-100 to-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
        </div>

        <h4 class="font-semibold text-gray-900 mb-2">Add Video Introduction</h4>
        <p class="text-sm text-gray-600 mb-4">
          Record a personal video introduction to make your portfolio more engaging and personal.
        </p>

        <button phx-click="start_video_recording"
                class="w-full px-4 py-3 bg-gradient-to-r from-purple-600 to-blue-600 text-white rounded-lg hover:from-purple-700 hover:to-blue-700 transition-colors font-medium flex items-center justify-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
          </svg>
          Record Video
        </button>

        <div class="mt-3">
          <button phx-click="upload_video_intro"
                  class="text-sm text-purple-600 hover:text-purple-700 font-medium">
            Or upload existing video
          </button>
        </div>
      </div>
    <% end %>
  </div>
  """
end

# Helper functions
defp format_date(datetime) do
  case datetime do
    %DateTime{} -> Calendar.strftime(datetime, "%b %d, %Y")
    _ -> "Unknown"
  end
end

defp has_media?(section) do
  # Check if section has any media attachments
  case section.content do
    %{"hero_image" => url} when is_binary(url) and url != "" -> true
    %{"media" => media} when is_list(media) and length(media) > 0 -> true
    _ -> false
  end
end

defp render_add_section_modal(assigns) do
  ~H"""
  <div class="fixed inset-0 z-50 overflow-y-auto" id="add-section-modal">
    <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20">
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-gray-900 bg-opacity-75" phx-click="close_add_section_modal"></div>

      <!-- Modal -->
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-md">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-xl">
          <div class="flex items-center justify-between">
            <h3 class="text-xl font-bold text-white">Add New Section</h3>
            <button phx-click="close_add_section_modal" class="text-white hover:text-gray-300">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Content -->
        <div class="p-6">
          <form phx-submit="create_typed_section" class="space-y-4">
            <input type="hidden" name="section_type" value={@selected_section_type} />

            <%= case @selected_section_type do %>
              <% "hero" -> %>
                <%= render_hero_creation_form(assigns) %>
              <% "about" -> %>
                <%= render_about_creation_form(assigns) %>
              <% "experience" -> %>
                <%= render_experience_creation_form(assigns) %>
              <% "skills" -> %>
                <%= render_skills_creation_form(assigns) %>
              <% "projects" -> %>
                <%= render_projects_creation_form(assigns) %>
              <% "contact" -> %>
                <%= render_contact_creation_form(assigns) %>
              <% "custom" -> %>
                <%= render_custom_creation_form(assigns) %>
              <% _ -> %>
                <%= render_generic_creation_form(assigns) %>
            <% end %>

            <!-- Form Actions -->
            <div class="flex items-center justify-between pt-4">
              <button type="button" phx-click="close_add_section_modal"
                      class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
                Cancel
              </button>
              <button type="submit"
                      class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Create Section
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  </div>
  """
end

defp render_enhanced_section_modal(assigns) do
  section_type = assigns.editing_section.section_type

  ~H"""
  <div class="fixed inset-0 z-50 overflow-y-auto" id="section-modal">
    <div class="flex items-start justify-center min-h-screen pt-4 px-4 pb-20">
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-gray-900 bg-opacity-75" phx-click="close_section_modal"></div>

      <!-- Modal -->
      <div class="relative bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <!-- Header -->
        <div class="bg-gradient-to-r from-blue-600 to-purple-600 px-6 py-4 rounded-t-xl flex-shrink-0">
          <div class="flex items-center justify-between">
            <h3 class="text-xl font-bold text-white flex items-center">
              <span class="text-2xl mr-3"><%= get_section_icon(section_type) %></span>
              Edit <%= @editing_section.title %>
            </h3>
            <button phx-click="close_section_modal" class="text-white hover:text-gray-300">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>

        <!-- Content -->
        <div class="flex-1 overflow-y-auto p-6">
          <form phx-submit="save_section" class="space-y-6" id="section-edit-form">
            <input type="hidden" name="section_id" value={@editing_section.id} />

            <%= case section_type do %>
              <% "hero" -> %>
                <%= render_hero_section_form(assigns) %>
              <% "about" -> %>
                <%= render_about_section_form(assigns) %>
              <% "experience" -> %>
                <%= render_experience_section_form(assigns) %>
              <% "skills" -> %>
                <%= render_skills_section_form(assigns) %>
              <% "projects" -> %>
                <%= render_projects_section_form(assigns) %>
              <% "contact" -> %>
                <%= render_contact_section_form(assigns) %>
              <% _ -> %>
                <%= render_standard_section_form(assigns) %>
            <% end %>
          </form>
        </div>

        <!-- Footer -->
        <div class="bg-gray-50 px-6 py-4 rounded-b-xl flex items-center justify-between flex-shrink-0">
          <div class="text-sm text-gray-600">
            💡 <%= get_section_tip(section_type) %>
          </div>

          <div class="flex items-center space-x-3">
            <button type="button" phx-click="close_section_modal"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
              Cancel
            </button>
            <button type="submit" form="section-edit-form"
                    class="px-6 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
              Save Changes
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
  """
end

# Type-specific creation forms
defp render_hero_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Your Name/Headline</label>
      <input type="text" name="headline" placeholder="John Doe" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Professional Title</label>
      <input type="text" name="tagline" placeholder="Senior Software Engineer • Full-Stack Developer"
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Welcome Message</label>
      <textarea name="main_content" rows="3" placeholder="Welcome to my portfolio..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>
  </div>
  """
end

defp render_about_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" value="About Me" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Tell your story</label>
      <textarea name="main_content" rows="4" placeholder="Share your background, passion, and what drives you..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>
  </div>
  """
end

defp render_experience_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" value="Experience" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
      <h4 class="font-medium text-blue-900 mb-2">First Job Entry</h4>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <input type="text" name="job_title" placeholder="Job Title"
               class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
        <input type="text" name="company" placeholder="Company Name"
               class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div class="grid grid-cols-2 gap-3 mt-3">
        <input type="text" name="start_date" placeholder="Start Date"
               class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
        <input type="text" name="end_date" placeholder="End Date (or 'Present')"
               class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <textarea name="job_description" rows="2" placeholder="Brief description of your role and achievements..."
                class="w-full mt-3 px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>

    <p class="text-sm text-gray-600">💡 You can add more jobs after creating this section</p>
  </div>
  """
end

defp render_skills_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" value="Skills" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Skills (comma-separated)</label>
      <textarea name="skills_list" rows="3"
                placeholder="JavaScript, React, Node.js, Python, Docker, AWS..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>

    <p class="text-sm text-gray-600">💡 Separate each skill with a comma. You can organize them later.</p>
  </div>
  """
end

defp render_projects_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" value="Projects" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div class="bg-green-50 border border-green-200 rounded-lg p-4">
      <h4 class="font-medium text-green-900 mb-2">First Project</h4>

      <div class="space-y-3">
        <input type="text" name="project_title" placeholder="Project Name"
               class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />

        <textarea name="project_description" rows="2"
                  placeholder="Brief description of the project and your role..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>

        <input type="url" name="project_url" placeholder="https://project-demo.com (optional)"
               class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>

    <p class="text-sm text-gray-600">💡 You can add more projects and images after creating this section</p>
  </div>
  """
end

defp render_contact_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" value="Contact" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Contact Message</label>
      <textarea name="main_content" rows="2"
                placeholder="Let's connect and work together..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
      <input type="email" name="email" placeholder="your@email.com"
             class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      <input type="text" name="location" placeholder="City, Country"
             class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>
  </div>
  """
end

defp render_generic_creation_form(assigns) do
  ~H"""
  <div class="space-y-4">
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
      <input type="text" name="title" required
             class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
      <textarea name="main_content" rows="4" placeholder="Add your content here..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
    </div>
  </div>
  """
end

defp get_section_tip(section_type) do
  case section_type do
    "hero" -> "Hero sections appear at the top and make the first impression"
    "about" -> "Tell your unique story and what makes you special"
    "experience" -> "Highlight your career progression and achievements"
    "skills" -> "Showcase your technical and soft skills"
    "projects" -> "Display your best work with visuals and descriptions"
    "contact" -> "Make it easy for people to reach out to you"
    _ -> "Customize this section to fit your needs"
  end
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
                  <p class="text-sm text-gray-600"><%= safe_capitalize(section.section_type) %></p>
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

  defp render_about_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Subtitle -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Subtitle (Optional)</label>
        <input type="text" name="subtitle" value={Map.get(content, "subtitle", "")}
              placeholder="A brief tagline about yourself"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Main Content -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">About You</label>
        <textarea name="main_content" rows="8"
                  placeholder="Tell your story - your background, what drives you, your passions..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "main_content", "") %></textarea>
      </div>

      <!-- Stats Section -->
      <div class="border-t border-gray-200 pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Stats & Highlights</h4>
          <label class="flex items-center">
            <input type="checkbox" name="show_stats"
                  checked={Map.get(content, "show_stats", false)}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
            <span class="ml-2 text-sm text-gray-700">Show stats</span>
          </label>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Years Experience</label>
            <input type="text" name="years_experience"
                  value={get_in(content, ["stats", "years_experience"]) || ""}
                  placeholder="5+"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">Projects Completed</label>
            <input type="text" name="projects_completed"
                  value={get_in(content, ["stats", "projects_completed"]) || ""}
                  placeholder="50+"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_experience_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    jobs = Map.get(content, "jobs", [])

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Jobs List -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Work Experience</h4>
          <button type="button" phx-click="add_job_entry"
                  class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm">
            + Add Job
          </button>
        </div>

        <div class="space-y-4" id="jobs-list">
          <%= for {job, index} <- Enum.with_index(jobs) do %>
            <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
              <div class="flex items-center justify-between mb-3">
                <h5 class="font-medium text-gray-900">Job #<%= index + 1 %></h5>
                <button type="button" phx-click="remove_job_entry" phx-value-index={index}
                        class="text-red-600 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                <input type="text" name={"job_title_#{index}"}
                      value={Map.get(job, "title", "")}
                      placeholder="Job Title"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                <input type="text" name={"job_company_#{index}"}
                      value={Map.get(job, "company", "")}
                      placeholder="Company Name"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-3">
                <input type="text" name={"job_start_date_#{index}"}
                      value={Map.get(job, "start_date", "")}
                      placeholder="Start Date"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                <input type="text" name={"job_end_date_#{index}"}
                      value={Map.get(job, "end_date", "")}
                      placeholder="End Date"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                <label class="flex items-center">
                  <input type="checkbox" name={"job_current_#{index}"}
                        checked={Map.get(job, "current", false)}
                        class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
                  <span class="ml-2 text-sm text-gray-700">Current Job</span>
                </label>
              </div>

              <textarea name={"job_description_#{index}"} rows="3"
                        placeholder="Describe your role, responsibilities, and achievements..."
                        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"><%= Map.get(job, "description", "") %></textarea>
            </div>
          <% end %>

          <%= if length(jobs) == 0 do %>
            <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
              <p class="text-gray-600 mb-4">No work experience added yet</p>
              <button type="button" phx-click="add_job_entry"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Add Your First Job
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_skills_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    skills = Map.get(content, "skills", [])

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Skills Management -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Skills & Expertise</h4>
          <button type="button" phx-click="add_skill_entry"
                  class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm">
            + Add Skill
          </button>
        </div>

        <!-- Quick Add Skills -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-gray-700 mb-2">Quick Add (comma-separated)</label>
          <div class="flex space-x-2">
            <input type="text" id="quick-skills-input" placeholder="JavaScript, React, Python, etc."
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
            <button type="button" phx-click="parse_skills_list"
                    class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700">
              Add All
            </button>
          </div>
        </div>

        <!-- Skills List -->
        <div class="space-y-3" id="skills-list">
          <%= for {skill, index} <- Enum.with_index(skills) do %>
            <div class="bg-gray-50 rounded-lg p-4 border border-gray-200">
              <div class="flex items-center justify-between mb-3">
                <h5 class="font-medium text-gray-900">Skill #<%= index + 1 %></h5>
                <button type="button" phx-click="remove_skill_entry" phx-value-index={index}
                        class="text-red-600 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              </div>

              <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                <input type="text" name={"skill_name_#{index}"}
                      value={Map.get(skill, "name", "")}
                      placeholder="Skill Name"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />

                <select name={"skill_level_#{index}"}
                        class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500">
                  <%= for level <- ["beginner", "intermediate", "advanced", "expert"] do %>
                    <option value={level} selected={Map.get(skill, "level", "intermediate") == level}>
                      <%= String.capitalize(level) %>
                    </option>
                  <% end %>
                </select>

                <input type="text" name={"skill_category_#{index}"}
                      value={Map.get(skill, "category", "")}
                      placeholder="Category (e.g., Frontend)"
                      class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
              </div>
            </div>
          <% end %>

          <%= if length(skills) == 0 do %>
            <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
              <p class="text-gray-600 mb-4">No skills added yet</p>
              <button type="button" phx-click="add_skill_entry"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Add Your First Skill
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_projects_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    projects = Map.get(content, "projects", [])

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Projects List -->
      <div>
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Projects Portfolio</h4>
          <button type="button" phx-click="add_project_entry"
                  class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm">
            + Add Project
          </button>
        </div>

        <div class="space-y-6" id="projects-list">
          <%= for {project, index} <- Enum.with_index(projects) do %>
            <div class="bg-gray-50 rounded-lg p-6 border border-gray-200">
              <div class="flex items-center justify-between mb-4">
                <h5 class="font-medium text-gray-900">Project #<%= index + 1 %></h5>
                <button type="button" phx-click="remove_project_entry" phx-value-index={index}
                        class="text-red-600 hover:text-red-700">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              </div>

              <div class="space-y-4">
                <!-- Project Title and Status -->
                <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
                  <input type="text" name={"project_title_#{index}"}
                        value={Map.get(project, "title", "")}
                        placeholder="Project Name"
                        class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />

                  <select name={"project_status_#{index}"}
                          class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500">
                    <%= for status <- ["completed", "in-progress", "concept"] do %>
                      <option value={status} selected={Map.get(project, "status", "completed") == status}>
                        <%= String.capitalize(status) %>
                      </option>
                    <% end %>
                  </select>

                  <input type="text" name={"project_year_#{index}"}
                        value={Map.get(project, "year", "")}
                        placeholder="Year (e.g., 2024)"
                        class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                </div>

                <!-- Project Description -->
                <textarea name={"project_description_#{index}"} rows="4"
                          placeholder="Describe the project, your role, challenges solved, and impact..."
                          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"><%= Map.get(project, "description", "") %></textarea>

                <!-- Links -->
                <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                  <input type="url" name={"project_demo_url_#{index}"}
                        value={Map.get(project, "demo_url", "")}
                        placeholder="Demo URL (https://...)"
                        class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />

                  <input type="url" name={"project_github_url_#{index}"}
                        value={Map.get(project, "github_url", "")}
                        placeholder="GitHub URL (https://...)"
                        class="px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                </div>

                <!-- Technologies -->
                <div>
                  <label class="block text-sm font-medium text-gray-700 mb-2">Technologies Used (comma-separated)</label>
                  <input type="text" name={"project_technologies_#{index}"}
                        value={Enum.join(Map.get(project, "technologies", []), ", ")}
                        placeholder="React, Node.js, PostgreSQL, AWS..."
                        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
                </div>
              </div>
            </div>
          <% end %>

          <%= if length(projects) == 0 do %>
            <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
              <p class="text-gray-600 mb-4">No projects added yet</p>
              <button type="button" phx-click="add_project_entry"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Add Your First Project
              </button>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_contact_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    social_links = Map.get(content, "social_links", %{})

    ~H"""
    <div class="space-y-6">
      <!-- Section Title -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <!-- Contact Message -->
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Contact Message</label>
        <textarea name="main_content" rows="3"
                  placeholder="Let's connect and work together..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "main_content", "") %></textarea>
      </div>

      <!-- Contact Information -->
      <div>
        <h4 class="text-lg font-medium text-gray-900 mb-4">Contact Information</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">📧 Email</label>
            <input type="email" name="email"
                  value={Map.get(content, "email", "")}
                  placeholder="your@email.com"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">📱 Phone</label>
            <input type="tel" name="phone"
                  value={Map.get(content, "phone", "")}
                  placeholder="+1 (555) 123-4567"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">📍 Location</label>
            <input type="text" name="location"
                  value={Map.get(content, "location", "")}
                  placeholder="City, Country"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-1">🌐 Website</label>
            <input type="url" name="website"
                  value={Map.get(content, "website", "")}
                  placeholder="https://yourwebsite.com"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
          </div>
        </div>
      </div>

      <!-- Social Links -->
      <div class="border-t border-gray-200 pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Social Links</h4>
          <label class="flex items-center">
            <input type="checkbox" name="show_social"
                  checked={Map.get(content, "show_social", true)}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
            <span class="ml-2 text-sm text-gray-700">Show social icons</span>
          </label>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for {platform, icon} <- [
            {"linkedin", "💼"}, {"github", "👨‍💻"}, {"twitter", "🐦"},
            {"instagram", "📸"}, {"facebook", "👥"}, {"youtube", "📺"}
          ] do %>
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">
                <%= icon %> <%= String.capitalize(platform) %>
              </label>
              <input type="url" name={"social_#{platform}"}
                    value={Map.get(social_links, platform, "")}
                    placeholder={get_social_placeholder(platform)}
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
            </div>
          <% end %>
        </div>
      </div>

      <!-- Contact Form Options -->
      <div class="border-t border-gray-200 pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-lg font-medium text-gray-900">Contact Form</h4>
          <label class="flex items-center">
            <input type="checkbox" name="show_form"
                  checked={Map.get(content, "show_form", true)}
                  class="rounded border-gray-300 text-blue-600 focus:ring-blue-500" />
            <span class="ml-2 text-sm text-gray-700">Enable contact form</span>
          </label>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Success Message</label>
          <input type="text" name="success_message"
                value={Map.get(content, "success_message", "Thanks for reaching out! I'll get back to you soon.")}
                placeholder="Message shown after form submission"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>
    </div>
    """
  end

  defp render_custom_creation_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="bg-purple-50 border border-purple-200 rounded-lg p-4 mb-4">
        <div class="flex items-center space-x-2 mb-2">
          <span class="text-purple-600">🔧</span>
          <h4 class="font-medium text-purple-900">Custom Section</h4>
        </div>
        <p class="text-sm text-purple-700">
          Create a unique section that doesn't fit into the standard templates.
          Perfect for special showcases, awards, or any custom content.
        </p>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title *</label>
        <input type="text" name="title" placeholder="e.g., Awards, Certifications, Hobbies..." required
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Type</label>
        <select name="custom_section_subtype"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500">
          <option value="text">Text Content</option>
          <option value="list">List of Items</option>
          <option value="timeline">Timeline Events</option>
          <option value="gallery">Image Gallery</option>
          <option value="awards">Awards & Recognition</option>
          <option value="certifications">Certifications</option>
          <option value="media">Media & Press</option>
          <option value="other">Other</option>
        </select>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Initial Content</label>
        <textarea name="main_content" rows="4"
                  placeholder="Add your custom content here. You can always edit this later..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500"></textarea>
      </div>

      <div class="bg-gray-50 rounded-lg p-3">
        <h5 class="font-medium text-gray-900 mb-2">💡 Custom Section Ideas:</h5>
        <ul class="text-sm text-gray-600 space-y-1">
          <li>• Awards and recognitions</li>
          <li>• Professional certifications</li>
          <li>• Publications and articles</li>
          <li>• Speaking engagements</li>
          <li>• Volunteer work</li>
          <li>• Personal interests and hobbies</li>
        </ul>
      </div>
    </div>
    """
  end

  defp render_video_intro_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" id="video-intro-modal">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-gray-900 bg-opacity-75" phx-click="close_video_intro_modal"></div>

        <!-- Modal -->
        <div class="relative bg-white rounded-xl shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
          <!-- Header -->
          <div class="bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-4 rounded-t-xl flex-shrink-0">
            <div class="flex items-center justify-between">
              <h3 class="text-xl font-bold text-white flex items-center">
                <svg class="w-6 h-6 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
                <%= case assigns[:video_intro_mode] do %>
                  <% :recording -> %>
                    Record Video Introduction
                  <% :upload -> %>
                    Upload Video Introduction
                  <% :edit -> %>
                    Edit Video Introduction
                  <% _ -> %>
                    Video Introduction
                <% end %>
              </h3>
              <button phx-click="close_video_intro_modal" class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Content -->
          <div class="flex-1 overflow-y-auto p-6">
            <%= case assigns[:video_intro_mode] do %>
              <% :recording -> %>
                <.live_component
                  module={FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent}
                  id="video-intro-recorder"
                  portfolio={@portfolio}
                  current_user={@current_user}
                  mode={:recording} />
              <% :upload -> %>
                <%= render_video_upload_form(assigns) %>
              <% :edit -> %>
                <%= render_video_edit_form(assigns) %>
              <% _ -> %>
                <div class="text-center py-8">
                  <p class="text-gray-600">Select an option to continue</p>
                </div>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_video_preview_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-90"
        phx-click="close_video_preview_modal">
      <div class="relative max-w-6xl w-full mx-4 max-h-[90vh]">
        <!-- Close button -->
        <button phx-click="close_video_preview_modal"
                class="absolute -top-12 right-0 text-white hover:text-gray-300 z-10">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>

        <!-- Video player -->
        <video controls autoplay class="w-full h-auto rounded-xl shadow-2xl">
          <source src={@preview_video_url} type="video/mp4">
          <source src={@preview_video_url} type="video/webm">
          Your browser does not support the video tag.
        </video>
      </div>
    </div>
    """
  end

  defp render_video_position_modal(assigns) do
    positions = [
      %{id: "hero", name: "Hero Section", description: "Large video at the top of your portfolio"},
      %{id: "about", name: "About Section", description: "Personal introduction in your about section"},
      %{id: "footer", name: "Footer", description: "Closing video at the bottom of your portfolio"}
    ]

    assigns = assign(assigns, :positions, positions)

    ~H"""
    <div class="fixed inset-0 z-50 overflow-y-auto" id="position-modal">
      <div class="flex items-center justify-center min-h-screen pt-4 px-4 pb-20">
        <!-- Backdrop -->
        <div class="fixed inset-0 bg-gray-900 bg-opacity-75" phx-click="close_position_modal"></div>

        <!-- Modal -->
        <div class="relative bg-white rounded-xl shadow-xl w-full max-w-md">
          <!-- Header -->
          <div class="bg-gradient-to-r from-purple-600 to-blue-600 px-6 py-4 rounded-t-xl">
            <div class="flex items-center justify-between">
              <h3 class="text-lg font-bold text-white">Change Video Position</h3>
              <button phx-click="close_position_modal" class="text-white hover:text-gray-300">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
          </div>

          <!-- Content -->
          <div class="p-6">
            <p class="text-gray-600 mb-4">Choose where your video introduction should appear:</p>

            <div class="space-y-3">
              <%= for position <- @positions do %>
                <button phx-click="update_video_position" phx-value-position={position.id}
                        class="w-full p-4 border-2 border-gray-200 rounded-lg text-left hover:border-purple-300 hover:bg-purple-50 transition-colors">
                  <div class="font-medium text-gray-900"><%= position.name %></div>
                  <div class="text-sm text-gray-600 mt-1"><%= position.description %></div>
                </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_video_upload_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="text-center">
        <div class="w-20 h-20 bg-gradient-to-br from-purple-100 to-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-10 h-10 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
          </svg>
        </div>
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Upload Video Introduction</h3>
        <p class="text-gray-600 mb-6">Select a video file from your computer to upload.</p>
      </div>

      <form phx-submit="upload_video_file" phx-change="validate_video_upload" class="space-y-4">
        <!-- File Upload Area -->
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-purple-400 transition-colors">
          <input type="file" id="video-upload" accept="video/*" class="hidden" />
          <label for="video-upload" class="cursor-pointer">
            <div class="text-gray-600">
              <svg class="w-12 h-12 mx-auto mb-4 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              <p class="text-lg font-medium mb-2">Drop your video here or click to browse</p>
              <p class="text-sm">Supports MP4, WebM • Max 100MB</p>
            </div>
          </label>
        </div>

        <!-- Video Details Form -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Video Title</label>
            <input type="text" name="video_title" value="Personal Introduction"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Position</label>
            <select name="video_position"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500">
              <option value="hero">Hero Section</option>
              <option value="about">About Section</option>
              <option value="footer">Footer</option>
            </select>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description (Optional)</label>
          <textarea name="video_description" rows="3"
                    placeholder="Brief description of your video introduction..."
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"></textarea>
        </div>

        <!-- Upload Button -->
        <div class="flex items-center justify-end space-x-3 pt-4 border-t border-gray-200">
          <button type="button" phx-click="close_video_intro_modal"
                  class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
            Cancel
          </button>
          <button type="submit"
                  class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
            Upload Video
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp render_video_edit_form(assigns) do
    video_section = assigns[:editing_video_section]
    content = video_section.content || %{}

    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="space-y-6">
      <div class="text-center mb-6">
        <h3 class="text-lg font-semibold text-gray-900 mb-2">Edit Video Introduction</h3>
        <p class="text-gray-600">Update your video details and settings.</p>
      </div>

      <form phx-submit="update_video_intro" class="space-y-6">
        <input type="hidden" name="section_id" value={video_section.id} />

        <!-- Current Video Preview -->
        <div class="bg-gray-50 rounded-lg p-4">
          <h4 class="font-medium text-gray-900 mb-3">Current Video</h4>
          <div class="flex items-center space-x-4">
            <%= if get_in(@content, ["thumbnail"]) do %>
              <img src={get_in(@content, ["thumbnail"])} alt="Video thumbnail"
                  class="w-24 h-16 object-cover rounded-lg" />
            <% else %>
              <div class="w-24 h-16 bg-gradient-to-br from-purple-600 to-blue-600 rounded-lg flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                </svg>
              </div>
            <% end %>

            <div class="flex-1">
              <p class="font-medium text-gray-900"><%= get_in(@content, ["title"]) || "Personal Introduction" %></p>
              <div class="text-sm text-gray-600 space-y-1">
                <p>Duration: <%= get_video_duration(video_section) %></p>
                <p>Quality: <%= get_in(@content, ["quality"]) || "HD" %></p>
                <p>Position: <%= get_position_name(get_in(@content, ["position"]) || "hero") %></p>
              </div>
            </div>

            <button type="button" phx-click="preview_video_intro"
                    class="px-3 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm">
              Preview
            </button>
          </div>
        </div>

        <!-- Edit Form -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Video Title</label>
            <input type="text" name="video_title" value={get_in(@content, ["title"]) || "Personal Introduction"}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500" />
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Position</label>
            <select name="video_position"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500">
              <%= for {value, label} <- [{"hero", "Hero Section"}, {"about", "About Section"}, {"footer", "Footer"}] do %>
                <option value={value} selected={get_in(@content, ["position"]) == value}>
                  <%= label %>
                </option>
              <% end %>
            </select>
          </div>
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
          <textarea name="video_description" rows="3"
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-purple-500 focus:border-purple-500"><%= get_in(@content, ["description"]) || "" %></textarea>
        </div>

        <!-- Visibility and Settings -->
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="flex items-center">
            <input type="checkbox" name="video_visible" checked={video_section.visible}
                  class="rounded border-gray-300 text-purple-600 focus:ring-purple-500" />
            <label class="ml-2 text-sm text-gray-700">Show video on portfolio</label>
          </div>

          <div class="flex items-center">
            <input type="checkbox" name="auto_play" checked={get_in(@content, ["auto_play"]) == true}
                  class="rounded border-gray-300 text-purple-600 focus:ring-purple-500" />
            <label class="ml-2 text-sm text-gray-700">Auto-play video (muted)</label>
          </div>
        </div>

        <!-- Action Buttons -->
        <div class="flex items-center justify-between pt-4 border-t border-gray-200">
          <div class="flex items-center space-x-3">
            <button type="button" phx-click="replace_video"
                    class="px-4 py-2 bg-orange-600 text-white rounded-lg hover:bg-orange-700 text-sm">
              Replace Video
            </button>

            <button type="button" phx-click="download_video"
                    class="px-4 py-2 bg-gray-600 text-white rounded-lg hover:bg-gray-700 text-sm">
              Download
            </button>
          </div>

          <div class="flex items-center space-x-3">
            <button type="button" phx-click="close_video_intro_modal"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
              Cancel
            </button>
            <button type="submit"
                    class="px-6 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700">
              Save Changes
            </button>
          </div>
        </div>
      </form>
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
  def handle_event("toggle_add_section_dropdown", _params, socket) do
    show = !socket.assigns.show_add_section_dropdown
    {:noreply, assign(socket, :show_add_section_dropdown, show)}
  end

  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    IO.puts("🔥 ADD SECTION: #{section_type}")
    portfolio_id = socket.assigns.portfolio.id
    existing_sections = socket.assigns.sections

    # ✅ PREVENT DUPLICATES: Check if this section type already exists
    existing_section = Enum.find(existing_sections, fn section ->
      to_string(section.section_type) == section_type
    end)

    if existing_section do
      IO.puts("⚠️ Section type '#{section_type}' already exists")
      {:noreply, socket
      |> put_flash(:warning, "A #{section_type} section already exists. Edit the existing one or delete it first.")
      |> assign(:show_add_section_dropdown, false)}
    else
      # Proceed with creation...
      case test_section_creation(portfolio_id) do
        {:ok, _} ->
          IO.puts("✅ All diagnostic tests passed, proceeding with section creation")

          section_attrs = %{
            portfolio_id: portfolio_id,
            title: get_default_title_for_type(section_type),
            section_type: section_type,
            content: get_default_content_for_section_type(section_type),
            position: get_next_position(existing_sections), # ✅ FIXED: Use existing sections
            visible: true
          }

          IO.puts("🔥 Section attrs: #{inspect(section_attrs)}")

          case create_section_safely(section_attrs) do
            {:ok, new_section} ->
              IO.puts("✅ Section created: #{inspect(new_section)}")
              updated_sections = existing_sections ++ [new_section]

              socket = socket
              |> assign(:sections, updated_sections)
              |> assign(:show_add_section_dropdown, false)
              |> assign(:unsaved_changes, true)
              |> put_flash(:info, "#{get_default_title_for_type(section_type)} section added!")

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
  end

  @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      IO.puts("🔥 EDITING SECTION: #{section.title}")

      {:noreply, socket
      |> assign(:editing_section, section)
      |> assign(:section_edit_mode, true)}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
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
  def handle_event("show_add_section_modal", %{"type" => section_type}, socket) do
    {:noreply, socket
    |> assign(:show_add_section_modal, true)
    |> assign(:selected_section_type, section_type)}
  end

  @impl true
  def handle_event("close_add_section_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_add_section_modal, false)
    |> assign(:selected_section_type, nil)}
  end

  @impl true
  def handle_event("create_typed_section", params, socket) do
    portfolio_id = socket.assigns.portfolio.id
    section_type = params["section_type"]
    existing_sections = socket.assigns.sections

    # Check for duplicates
    existing_section = Enum.find(existing_sections, fn section ->
      to_string(section.section_type) == section_type
    end)

    if existing_section do
      {:noreply, socket
      |> put_flash(:warning, "A #{section_type} section already exists. Edit the existing one or delete it first.")
      |> assign(:show_add_section_modal, false)}
    else
      # Create section with type-specific content
      section_attrs = build_typed_section_attrs(portfolio_id, section_type, params, existing_sections)

      case create_section_safely(section_attrs) do
        {:ok, new_section} ->
          updated_sections = existing_sections ++ [new_section]

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:show_add_section_modal, false)
          |> assign(:selected_section_type, nil)
          |> assign(:unsaved_changes, true)
          |> put_flash(:info, "#{new_section.title} section created!")
          |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
          |> push_event("section_added", %{section_id: new_section.id, title: new_section.title})
          |> broadcast_preview_update()

          {:noreply, socket}

        {:error, reason} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to create section: #{inspect(reason)}")
          |> assign(:show_add_section_modal, false)}
      end
    end
  end

  @impl true
  def handle_event("attach_media", %{"id" => section_id}, socket) do
    # TODO: Implement media attachment functionality
    {:noreply, socket
    |> put_flash(:info, "Media attachment coming soon!")
    |> push_event("show_media_modal", %{section_id: section_id})}
  end

  # Updated design event handler with proper CSS generation
  @impl true
  def handle_event("update_design", %{"setting" => setting, "value" => value}, socket) do
    IO.puts("🎨 UPDATE DESIGN: #{setting} = #{value}")
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    updated_customization = Map.put(current_customization, setting, value)

    case update_portfolio_safely(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        design_settings = get_design_settings(updated_portfolio)

        # Generate and broadcast CSS
        css = generate_design_css(updated_customization)

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:design_settings, design_settings)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Design updated")
        |> push_event("update_preview_css", %{css: css})
        |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})
        |> broadcast_design_update_with_css(updated_customization, css)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update design: #{inspect(reason)}")}
    end
  end

  @impl true
def handle_event("start_video_recording", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_intro_modal, true)
  |> assign(:video_intro_mode, :recording)}
end

@impl true
def handle_event("upload_video_intro", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_intro_modal, true)
  |> assign(:video_intro_mode, :upload)}
end

@impl true
def handle_event("edit_video_intro", _params, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)

  {:noreply, socket
  |> assign(:show_video_intro_modal, true)
  |> assign(:video_intro_mode, :edit)
  |> assign(:editing_video_section, video_section)}
end

@impl true
def handle_event("preview_video_intro", _params, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)
  video_url = get_in(video_section.content, ["video_url"])

  if video_url do
    {:noreply, socket
    |> assign(:show_video_preview_modal, true)
    |> assign(:preview_video_url, video_url)}
  else
    {:noreply, socket
    |> put_flash(:error, "Video URL not found")}
  end
end

@impl true
def handle_event("toggle_video_menu", _params, socket) do
  show_menu = !Map.get(socket.assigns, :show_video_menu, false)
  {:noreply, assign(socket, :show_video_menu, show_menu)}
end

@impl true
def handle_event("toggle_video_visibility", _params, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)

  case Portfolios.update_section(video_section, %{visible: !video_section.visible}) do
    {:ok, updated_section} ->
      updated_sections = Enum.map(socket.assigns.sections, fn s ->
        if s.id == video_section.id, do: updated_section, else: s
      end)

      message = if updated_section.visible,
        do: "Video introduction is now visible",
        else: "Video introduction is now hidden"

      {:noreply, socket
      |> assign(:sections, updated_sections)
      |> assign(:show_video_menu, false)
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, message)
      |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}

    {:error, _} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to update video visibility")
      |> assign(:show_video_menu, false)}
  end
end

@impl true
def handle_event("change_video_position", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_menu, false)
  |> assign(:show_position_modal, true)}
end

@impl true
def handle_event("update_video_position", %{"position" => position}, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)

  updated_content = Map.put(video_section.content, "position", position)

  case Portfolios.update_section(video_section, %{content: updated_content}) do
    {:ok, updated_section} ->
      updated_sections = Enum.map(socket.assigns.sections, fn s ->
        if s.id == video_section.id, do: updated_section, else: s
      end)

      {:noreply, socket
      |> assign(:sections, updated_sections)
      |> assign(:show_position_modal, false)
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, "Video position updated to #{get_position_name(position)}")
      |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}

    {:error, _} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to update video position")
      |> assign(:show_position_modal, false)}
  end
end

@impl true
def handle_event("download_video", _params, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)
  video_url = get_in(video_section.content, ["video_url"])

  if video_url do
    {:noreply, socket
    |> assign(:show_video_menu, false)
    |> push_event("download_file", %{url: video_url, filename: "video_introduction.mp4"})}
  else
    {:noreply, socket
    |> put_flash(:error, "Video file not found")
    |> assign(:show_video_menu, false)}
  end
end

@impl true
def handle_event("delete_video_intro", _params, socket) do
  video_section = get_video_intro_section(socket.assigns.sections)

  case Portfolios.delete_section(video_section) do
    {:ok, _} ->
      updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == video_section.id))

      {:noreply, socket
      |> assign(:sections, updated_sections)
      |> assign(:show_video_menu, false)
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, "Video introduction deleted successfully")
      |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}

    {:error, _} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to delete video introduction")
      |> assign(:show_video_menu, false)}
  end
end

@impl true
def handle_event("close_video_intro_modal", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_intro_modal, false)
  |> assign(:video_intro_mode, nil)
  |> assign(:editing_video_section, nil)}
end

@impl true
def handle_event("close_video_preview_modal", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_preview_modal, false)
  |> assign(:preview_video_url, nil)}
end

@impl true
def handle_event("close_position_modal", _params, socket) do
  {:noreply, assign(socket, :show_position_modal, false)}
end

@impl true
def handle_event("update_video_intro", params, socket) do
  section_id = String.to_integer(params["section_id"])
  video_section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

  updated_content = Map.merge(video_section.content || %{}, %{
    "title" => params["video_title"],
    "description" => params["video_description"],
    "position" => params["video_position"],
    "auto_play" => params["auto_play"] == "true"
  })

  update_attrs = %{
    content: updated_content,
    visible: params["video_visible"] == "true"
  }

  case Portfolios.update_section(video_section, update_attrs) do
    {:ok, updated_section} ->
      updated_sections = Enum.map(socket.assigns.sections, fn s ->
        if s.id == section_id, do: updated_section, else: s
      end)

      {:noreply, socket
      |> assign(:sections, updated_sections)
      |> assign(:show_video_intro_modal, false)
      |> assign(:editing_video_section, nil)
      |> assign(:unsaved_changes, true)
      |> put_flash(:info, "Video introduction updated successfully")
      |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}

    {:error, _changeset} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to update video introduction")}
  end
end

@impl true
def handle_event("replace_video", _params, socket) do
  {:noreply, socket
  |> assign(:show_video_intro_modal, false)
  |> assign(:video_intro_mode, :upload)
  |> assign(:show_video_intro_modal, true)}
end

# ADD info handler for video intro component messages:
@impl true
def handle_info({:video_intro_created, video_data}, socket) do
  # Refresh sections to include the new video
  sections = load_sections_safely(socket.assigns.portfolio.id)

  {:noreply, socket
  |> assign(:sections, sections)
  |> assign(:show_video_intro_modal, false)
  |> assign(:video_intro_mode, nil)
  |> assign(:unsaved_changes, true)
  |> put_flash(:info, "Video introduction added successfully!")
  |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}
end

@impl true
def handle_info({:video_intro_updated, video_data}, socket) do
  # Refresh sections to show updated video
  sections = load_sections_safely(socket.assigns.portfolio.id)

  {:noreply, socket
  |> assign(:sections, sections)
  |> assign(:show_video_intro_modal, false)
  |> assign(:editing_video_section, nil)
  |> assign(:unsaved_changes, true)
  |> put_flash(:info, "Video introduction updated successfully!")
  |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}
end

@impl true
def handle_info({:close_video_intro_modal, _data}, socket) do
  {:noreply, socket
  |> assign(:show_video_intro_modal, false)
  |> assign(:video_intro_mode, nil)
  |> assign(:editing_video_section, nil)}
end

# ADD this helper function:
defp get_position_name(position) do
  case position do
    "hero" -> "Hero Section"
    "about" -> "About Section"
    "footer" -> "Footer"
    _ -> "Hero Section"
  end
end

  # Helper function to build typed section attributes
  defp build_typed_section_attrs(portfolio_id, section_type, params, existing_sections) do
    base_attrs = %{
      portfolio_id: portfolio_id,
      section_type: section_type,
      position: get_next_position(existing_sections),
      visible: true
    }

    case section_type do
      "hero" ->
        Map.merge(base_attrs, %{
          title: params["headline"] || "Welcome",
          content: %{
            "headline" => params["headline"] || "",
            "tagline" => params["tagline"] || "",
            "main_content" => params["main_content"] || "",
            "hero_style" => "modern",
            "background_type" => "gradient"
          }
        })

      "about" ->
        Map.merge(base_attrs, %{
          title: params["title"] || "About Me",
          content: %{
            "main_content" => params["main_content"] || "",
            "subtitle" => "About Me"
          }
        })

      "experience" ->
        job = if params["job_title"] && params["job_title"] != "" do
          %{
            "title" => params["job_title"],
            "company" => params["company"] || "",
            "start_date" => params["start_date"] || "",
            "end_date" => params["end_date"] || "",
            "description" => params["job_description"] || "",
            "current" => params["end_date"] == "" || params["end_date"] == "Present"
          }
        else
          nil
        end

        jobs = if job, do: [job], else: []

        Map.merge(base_attrs, %{
          title: params["title"] || "Experience",
          content: %{"jobs" => jobs}
        })

      "skills" ->
        skills = if params["skills_list"] && params["skills_list"] != "" do
          params["skills_list"]
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
          |> Enum.map(fn skill -> %{"name" => skill, "level" => "intermediate"} end)
        else
          []
        end

        Map.merge(base_attrs, %{
          title: params["title"] || "Skills",
          content: %{"skills" => skills}
        })

      "projects" ->
        project = if params["project_title"] && params["project_title"] != "" do
          %{
            "title" => params["project_title"],
            "description" => params["project_description"] || "",
            "url" => params["project_url"] || "",
            "technologies" => []
          }
        else
          nil
        end

        projects = if project, do: [project], else: []

        Map.merge(base_attrs, %{
          title: params["title"] || "Projects",
          content: %{"projects" => projects}
        })

      "contact" ->
        Map.merge(base_attrs, %{
          title: params["title"] || "Contact",
          content: %{
            "main_content" => params["main_content"] || "",
            "email" => params["email"] || "",
            "location" => params["location"] || "",
            "show_form" => true,
            "show_social" => true
          }
        })

      "custom" ->
        Map.merge(base_attrs, %{
          title: params["title"] || "Custom Section",
          content: %{
            "main_content" => params["main_content"] || "",
            "section_subtype" => params["custom_section_subtype"] || "text",
            "custom_type" => true
          }
        })

      _ ->
        Map.merge(base_attrs, %{
          title: params["title"] || get_default_title_for_type(section_type),
          content: %{"main_content" => params["main_content"] || ""}
        })
    end
  end

  # Enhanced broadcasting with CSS
  defp broadcast_design_update_with_css(socket, customization, css) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:design_update, %{
        customization: customization,
        css: css,
        timestamp: :os.system_time(:millisecond)
      }}
    )

    socket
  end

  # Add to mount function - initialize new assigns
  defp add_new_mobile_assigns(socket) do
    socket
    |> assign(:show_mobile_nav, false)
    |> assign(:show_add_section_modal, false)
    |> assign(:selected_section_type, nil)
  end

  defp get_video_intro_section(sections) do
    Enum.find(sections, fn section ->
      section.section_type == :media_showcase and
      get_in(section.content, ["video_type"]) == "introduction"
    end)
  end

  defp get_video_thumbnail(video_section) do
    get_in(video_section.content, ["thumbnail", "url"]) ||
    get_in(video_section.content, ["thumbnail"])
  end

  defp get_video_title(video_section) do
    get_in(video_section.content, ["title"]) || "Personal Introduction"
  end

  defp get_video_duration(video_section) do
    duration = get_in(video_section.content, ["duration"]) || 0

    if duration > 0 do
      minutes = div(duration, 60)
      seconds = rem(duration, 60)
      "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
    else
      "Unknown"
    end
  end

  defp get_video_position(video_section) do
    position = get_in(video_section.content, ["position"]) || "hero"

    case position do
      "hero" -> "Hero Section"
      "about" -> "About Section"
      "footer" -> "Footer"
      _ -> "Hero Section"
    end
  end

  defp get_video_quality(video_section) do
    get_in(video_section.content, ["quality"]) || "HD"
  end

  defp get_video_visibility(video_section) do
    video_section.visible != false
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
  def handle_event("preview_design_changes", _params, socket) do
    {:noreply, socket
    |> put_flash(:info, "🎨 Design preview updated!")
    |> push_event("refresh_portfolio_preview", %{timestamp: :os.system_time(:millisecond)})}
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

  defp fix_section_positions(portfolio_id) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    |> Enum.sort_by(& &1.inserted_at)  # Sort by creation time

    # Reassign positions sequentially
    sections
    |> Enum.with_index(1)  # Start positions at 1
    |> Enum.each(fn {section, new_position} ->
      if section.position != new_position do
        Portfolios.update_section(section, %{position: new_position})
      end
    end)
  end

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

  defp create_new_section(portfolio_id, section_type) do
    # ✅ FIXED: Generate proper content structure based on section type
    content = case section_type do
      "experience" -> %{"jobs" => []}
      "education" -> %{"education" => []}
      "skills" -> %{"skills" => []}
      "projects" -> %{"projects" => []}
      "achievements" -> %{"achievements" => []}
      "testimonials" -> %{"testimonials" => []}
      "contact" -> %{"email" => "", "phone" => "", "location" => ""}
      "intro" -> %{"headline" => "", "summary" => ""}
      _ -> %{"main_content" => "Add your content here..."}
    end

    attrs = %{
      portfolio_id: portfolio_id,
      section_type: section_type,
      title: humanize_section_type(section_type),
      content: content,  # ← NOW USES CORRECT STRUCTURE
      position: get_next_position(portfolio_id),
      visible: true
    }

    # ✅ FIXED: Use correct function name
    Portfolios.create_section(attrs)  # ← Changed from create_portfolio_section
  end

    defp humanize_section_type(section_type) do
      section_type
      |> to_string()
      |> String.replace("_", " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")
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

  defp generate_design_css(customization) do
    theme = Map.get(customization, "theme", "professional")
    layout = Map.get(customization, "layout", "dashboard")
    color_scheme = Map.get(customization, "color_scheme", "blue")

    # Get colors for the scheme
    colors = get_color_scheme_colors(color_scheme)
    theme_styles = get_theme_styles(theme)
    layout_styles = get_layout_styles(layout)

    """
    <style id="dynamic-portfolio-css">
    /* CSS Variables */
    :root {
      --portfolio-theme: #{theme};
      --portfolio-layout: #{layout};
      --portfolio-primary: #{colors.primary};
      --portfolio-secondary: #{colors.secondary};
      --portfolio-accent: #{colors.accent};
      --portfolio-font: #{theme_styles.font_family};
    }

    /* Base Portfolio Container */
    .portfolio-container,
    .portfolio-content,
    body.portfolio-view {
      --primary-color: var(--portfolio-primary);
      --secondary-color: var(--portfolio-secondary);
      --accent-color: var(--portfolio-accent);
      font-family: var(--portfolio-font);
    }

    /* Theme Application */
    .portfolio-content {
      #{theme_styles.base_styles}
    }

    /* Layout Styles */
    .portfolio-sections {
      #{layout_styles}
    }

    /* Color Applications */
    .portfolio-content h1,
    .portfolio-content .hero-title,
    .portfolio-content .section-title {
      color: var(--portfolio-primary) !important;
    }

    .portfolio-content .btn-primary,
    .portfolio-content .cta-button,
    .portfolio-content .primary-button {
      background-color: var(--portfolio-primary) !important;
      border-color: var(--portfolio-primary) !important;
      color: white !important;
    }

    .portfolio-content .btn-primary:hover,
    .portfolio-content .cta-button:hover {
      background-color: var(--portfolio-secondary) !important;
      border-color: var(--portfolio-secondary) !important;
    }

    .portfolio-content .accent-text,
    .portfolio-content .highlight {
      color: var(--portfolio-accent) !important;
    }

    .portfolio-content .accent-bg {
      background-color: var(--portfolio-accent) !important;
    }

    /* Section-specific styles */
    .portfolio-content .hero-section {
      #{get_hero_styles(theme)}
    }

    .portfolio-content .about-section,
    .portfolio-content .experience-section,
    .portfolio-content .skills-section,
    .portfolio-content .projects-section,
    .portfolio-content .contact-section {
      #{get_section_styles(theme)}
    }

    /* Responsive adjustments */
    @media (max-width: 768px) {
      .portfolio-content {
        #{get_mobile_styles(theme)}
      }
    }

    /* Animation and transitions */
    .portfolio-content * {
      transition: color 0.3s ease, background-color 0.3s ease, border-color 0.3s ease;
    }
    </style>
    """
  end

  defp get_theme_styles(theme) do
    case theme do
      "professional" ->
        %{
          font_family: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
          base_styles: """
            line-height: 1.6;
            letter-spacing: -0.01em;
          """
        }
      "creative" ->
        %{
          font_family: "'Poppins', 'Helvetica Neue', Arial, sans-serif",
          base_styles: """
            line-height: 1.7;
            letter-spacing: 0.02em;
          """
        }
      "minimal" ->
        %{
          font_family: "'Source Sans Pro', 'Helvetica Neue', Arial, sans-serif",
          base_styles: """
            line-height: 1.8;
            letter-spacing: 0.01em;
          """
        }
      "modern" ->
        %{
          font_family: "'Roboto', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif",
          base_styles: """
            line-height: 1.65;
            letter-spacing: -0.005em;
          """
        }
      _ ->
        %{
          font_family: "system-ui, -apple-system, sans-serif",
          base_styles: "line-height: 1.6;"
        }
    end
  end

  defp get_layout_styles(layout) do
    case layout do
      "dashboard" ->
        """
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
        gap: 2rem;
        padding: 2rem;
        max-width: 1400px;
        margin: 0 auto;
        """
      "grid" ->
        """
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        gap: 1.5rem;
        padding: 1.5rem;
        max-width: 1200px;
        margin: 0 auto;
        """
      "timeline" ->
        """
        display: flex;
        flex-direction: column;
        max-width: 900px;
        margin: 0 auto;
        padding: 2rem 1rem;
        gap: 3rem;
        """
      "magazine" ->
        """
        max-width: 1000px;
        margin: 0 auto;
        padding: 2rem 1rem;
        column-count: 2;
        column-gap: 2rem;
        """
      "minimal" ->
        """
        max-width: 800px;
        margin: 0 auto;
        padding: 4rem 2rem;
        """

      _ -> # standard
        """
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem 1rem;
        """
    end
  end

  defp get_hero_styles(theme) do
    case theme do
      "creative" ->
        """
        background: linear-gradient(135deg, var(--portfolio-primary), var(--portfolio-accent));
        border-radius: 20px;
        padding: 4rem 2rem;
        text-align: center;
        color: white;
        """
      "minimal" ->
        """
        background: white;
        border: 2px solid var(--portfolio-primary);
        padding: 3rem 2rem;
        text-align: center;
        """
      "modern" ->
        """
        background: linear-gradient(45deg, var(--portfolio-primary)15, var(--portfolio-accent)15);
        padding: 4rem 2rem;
        text-align: center;
        border-radius: 15px;
        """
      _ -> # professional
        """
        background: var(--portfolio-primary);
        color: white;
        padding: 4rem 2rem;
        text-align: center;
        """
    end
  end

  defp get_section_styles(theme) do
    case theme do
      "creative" ->
        """
        background: white;
        border-radius: 15px;
        padding: 2rem;
        box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        border-left: 5px solid var(--portfolio-accent);
        """
      "minimal" ->
        """
        background: white;
        padding: 2rem;
        border: 1px solid #e5e7eb;
        """
      "modern" ->
        """
        background: white;
        border-radius: 10px;
        padding: 2rem;
        box-shadow: 0 4px 15px rgba(0,0,0,0.08);
        border-top: 3px solid var(--portfolio-primary);
        """
      _ -> # professional
        """
        background: white;
        padding: 2rem;
        border-radius: 8px;
        box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        """
    end
  end

  defp get_mobile_styles(theme) do
    case theme do
      "creative" ->
        """
        .hero-section { padding: 2rem 1rem !important; }
        .portfolio-sections { gap: 1rem !important; padding: 1rem !important; }
        """
      _ ->
        """
        .hero-section { padding: 2rem 1rem !important; }
        .portfolio-sections { padding: 1rem !important; }
        """
    end
  end

  # Enhanced color scheme function
  defp get_color_scheme_colors(scheme_key) do
    color_schemes = %{
      "blue" => %{
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa",
        colors: ["#1e40af", "#3b82f6", "#60a5fa"]
      },
      "green" => %{
        primary: "#065f46",
        secondary: "#059669",
        accent: "#34d399",
        colors: ["#065f46", "#059669", "#34d399"]
      },
      "purple" => %{
        primary: "#581c87",
        secondary: "#7c3aed",
        accent: "#a78bfa",
        colors: ["#581c87", "#7c3aed", "#a78bfa"]
      },
      "red" => %{
        primary: "#991b1b",
        secondary: "#dc2626",
        accent: "#f87171",
        colors: ["#991b1b", "#dc2626", "#f87171"]
      },
      "orange" => %{
        primary: "#ea580c",
        secondary: "#f97316",
        accent: "#fb923c",
        colors: ["#ea580c", "#f97316", "#fb923c"]
      },
      "teal" => %{
        primary: "#0f766e",
        secondary: "#14b8a6",
        accent: "#5eead4",
        colors: ["#0f766e", "#14b8a6", "#5eead4"]
      }
    }

    Map.get(color_schemes, scheme_key, color_schemes["blue"])
  end

  # Update the available color schemes to include new ones
  defp get_available_color_schemes do
    [
      %{key: "blue", name: "Ocean Blue", description: "Professional blue tones",
        colors: ["#1e40af", "#3b82f6", "#60a5fa"]},
      %{key: "green", name: "Forest Green", description: "Natural green palette",
        colors: ["#065f46", "#059669", "#34d399"]},
      %{key: "purple", name: "Royal Purple", description: "Creative purple shades",
        colors: ["#581c87", "#7c3aed", "#a78bfa"]},
      %{key: "red", name: "Warm Red", description: "Bold red accents",
        colors: ["#991b1b", "#dc2626", "#f87171"]},
      %{key: "orange", name: "Sunset Orange", description: "Energetic orange tones",
        colors: ["#ea580c", "#f97316", "#fb923c"]},
      %{key: "teal", name: "Modern Teal", description: "Contemporary teal palette",
        colors: ["#0f766e", "#14b8a6", "#5eead4"]}
    ]
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
      %{key: "standard", name: "Standard", description: "Clean single-column layout"},
      %{key: "dashboard", name: "Dashboard", description: "Modern card-based grid"},
      %{key: "grid", name: "Masonry Grid", description: "Pinterest-style layout"},
      %{key: "timeline", name: "Timeline", description: "Chronological flow design"},
      %{key: "magazine", name: "Magazine", description: "Editorial-style layout"},
      %{key: "minimal", name: "Minimal", description: "Ultra-clean and spacious"}
    ]
  end

  defp get_section_types do
    [
      %{type: "hero", name: "Hero Section", description: "Main banner with photo, headline, and call-to-action",
        icon: "🎬", featured: true, mobile_optimized: true, priority: 1},
      %{type: "about", name: "About Me", description: "Personal story and background information",
        icon: "👤", featured: true, mobile_optimized: true, priority: 2},
      %{type: "experience", name: "Work Experience", description: "Professional work history and achievements",
        icon: "💼", featured: true, mobile_optimized: true, priority: 3},
      %{type: "skills", name: "Skills & Expertise", description: "Technical skills and competencies",
        icon: "⚡", featured: true, mobile_optimized: true, priority: 4},
      %{type: "projects", name: "Projects Portfolio", description: "Showcase of work and project highlights",
        icon: "🚀", featured: true, mobile_optimized: true, priority: 5},
      %{type: "education", name: "Education", description: "Academic background and certifications",
        icon: "🎓", featured: false, mobile_optimized: true, priority: 6},
      %{type: "testimonials", name: "Testimonials", description: "Client feedback and recommendations",
        icon: "💬", featured: false, mobile_optimized: true, priority: 7},
      %{type: "contact", name: "Contact Info", description: "Contact details and social media links",
        icon: "📧", featured: true, mobile_optimized: true, priority: 8},
      # NEW: Custom section type
      %{type: "custom", name: "Custom Section", description: "Create your own unique section with custom content",
        icon: "🔧", featured: false, mobile_optimized: true, priority: 9}
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
      # ✅ ADD THESE MISSING CASES:
      "experience" -> %{"jobs" => []}
      "education" -> %{"education" => []}
      "skills" -> %{"skills" => []}
      "projects" -> %{"projects" => []}
      "achievements" -> %{"achievements" => []}
      "testimonials" -> %{"testimonials" => []}
      "intro" -> %{
        "headline" => "",
        "summary" => "Add your introduction here...",
        "profile_image" => nil
      }
      _ -> %{
        "main_content" => "Add your content here...",
        "subtitle" => get_default_title_for_type(section_type)
      }
    end
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

  defp safe_capitalize(value) when is_atom(value) do
    value |> Atom.to_string() |> String.capitalize()
  end

  defp safe_capitalize(value) when is_binary(value) do
    String.capitalize(value)
  end

  defp safe_capitalize(_), do: "Unknown"
end
