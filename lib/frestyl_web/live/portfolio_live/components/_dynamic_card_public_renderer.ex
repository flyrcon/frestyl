# lib/frestyl_web/live/portfolio_live/components/dynamic_card_public_renderer.ex
defmodule FrestylWeb.PortfolioLive.DynamicCardPublicRenderer do
  @moduledoc """
  Public-facing renderer for Dynamic Card Layout portfolios.
  Supports multiple layout types, mobile optimization, and advanced interactions.
  """

  use FrestylWeb, :live_component

  # Import the PublicBlockRenderer component
  import Phoenix.LiveView.Helpers
  alias FrestylWeb.PortfolioLive.Components.PublicBlockRenderer

  # Layout types available for public view
  @layout_types [:minimal, :list, :gallery, :dashboard]

  @impl true
  def mount(socket) do
    {:ok, socket
      |> assign(:current_layout_type, :dashboard)
      |> assign(:mobile_nav_sections, [])
      |> assign(:scroll_position, 0)
      |> assign(:active_section, nil)
    }
  end

  @impl true
  def update(assigns, socket) do
    layout_type = determine_layout_type(assigns.public_view_settings)
    mobile_sections = generate_mobile_navigation(assigns.layout_zones)

    {:ok, socket
      |> assign(assigns)
      |> assign(:current_layout_type, layout_type)
      |> assign(:mobile_nav_sections, mobile_sections)
      |> assign(:render_context, %{
          is_mobile: false, # Will be updated by JS hook
          device_type: :desktop,
          supports_animations: Map.get(assigns.public_view_settings, :enable_animations, true)
        })
    }
  end

  @impl true
  def handle_event("scroll_to_section", %{"section" => section_id}, socket) do
    {:noreply, push_event(socket, "scroll_to_element", %{id: section_id})}
  end

  @impl true
  def handle_event("update_scroll_position", %{"position" => position}, socket) do
    active_section = determine_active_section(position, socket.assigns.mobile_nav_sections)
    {:noreply, assign(socket, :scroll_position, position) |> assign(:active_section, active_section)}
  end

  @impl true
  def handle_event("toggle_mobile_nav", _params, socket) do
    current = Map.get(socket.assigns, :mobile_nav_open, false)
    {:noreply, assign(socket, :mobile_nav_open, !current)}
  end

  @impl true
  def handle_event("change_layout_type", %{"type" => type}, socket) when type in ["minimal", "list", "gallery", "dashboard"] do
    new_type = String.to_atom(type)
    {:noreply, assign(socket, :current_layout_type, new_type)}
  end

  @impl true
  def handle_event("device_change", %{"type" => device_type, "is_mobile" => is_mobile}, socket) do
    render_context = Map.merge(socket.assigns.render_context, %{
      device_type: String.to_atom(device_type),
      is_mobile: is_mobile
    })
    {:noreply, assign(socket, :render_context, render_context)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="dynamic-card-public-renderer"
         id={"public-renderer-#{@portfolio.id}"}
         phx-hook="PublicPortfolioRenderer"
         phx-target={@myself}
         data-layout-type={@current_layout_type}
         data-enable-animations={@public_view_settings.enable_animations}>

      <!-- Sticky Navigation (if enabled) -->
      <%= if @public_view_settings.enable_sticky_nav do %>
        <%= render_sticky_navigation(assigns) %>
      <% end %>

      <!-- Main Content Area -->
      <main class="portfolio-main-content">
        <%= case @current_layout_type do %>
          <% :minimal -> %>
            <%= render_minimal_layout(assigns) %>
          <% :list -> %>
            <%= render_list_layout(assigns) %>
          <% :gallery -> %>
            <%= render_gallery_layout(assigns) %>
          <% :dashboard -> %>
            <%= render_dashboard_layout(assigns) %>
          <% _ -> %>
            <%= render_dashboard_layout(assigns) %>
        <% end %>
      </main>

      <!-- Mobile Navigation Overlay -->
      <%= if Map.get(assigns, :mobile_nav_open, false) do %>
        <%= render_mobile_nav_overlay(assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT RENDERERS
  # ============================================================================

  defp render_minimal_layout(assigns) do
    ~H"""
    <div class="minimal-layout max-w-2xl mx-auto py-8 px-4 space-y-8">
      <!-- Hero Section (Simplified) -->
      <%= for block <- Map.get(@layout_zones, :hero, []) do %>
        <.live_component
          module={PublicBlockRenderer}
          id={"minimal-hero-#{block.id}"}
          block={block}
          layout_type={:minimal}
          render_context={@render_context}
          public_view_settings={@public_view_settings} />
      <% end %>

      <!-- Main Content (Linear) -->
      <%= for zone_name <- [:about, :experience, :services, :projects] do %>
        <%= for block <- Map.get(@layout_zones, zone_name, []) do %>
          <.live_component
            module={PublicBlockRenderer}
            id={"minimal-#{zone_name}-#{block.id}"}
            block={block}
            layout_type={:minimal}
            render_context={@render_context}
            public_view_settings={@public_view_settings} />
        <% end %>
      <% end %>

      <!-- Contact (Simplified) -->
      <%= for block <- Map.get(@layout_zones, :contact, []) do %>
        <.live_component
          module={PublicBlockRenderer}
          id={"minimal-contact-#{block.id}"}
          block={block}
          layout_type={:minimal}
          render_context={@render_context}
          public_view_settings={@public_view_settings} />
      <% end %>
    </div>
    """
  end

  defp render_list_layout(assigns) do
    ~H"""
    <div class="list-layout max-w-4xl mx-auto py-8 px-4">
      <!-- Hero Section (Full Width) -->
      <section class="hero-section mb-12" id="hero-section">
        <%= for block <- Map.get(@layout_zones, :hero, []) do %>
          <.live_component
            module={PublicBlockRenderer}
            id={"list-hero-#{block.id}"}
            block={block}
            layout_type={:list}
            render_context={@render_context}
            public_view_settings={@public_view_settings} />
        <% end %>
      </section>

      <!-- Timeline/List Sections -->
      <div class="timeline-container space-y-16">
        <%= for {zone_name, zone_blocks} <- get_ordered_content_zones(@layout_zones) do %>
          <%= if length(zone_blocks) > 0 do %>
            <section class="timeline-section" id={"#{zone_name}-section"}>
              <div class="section-header mb-8">
                <h2 class="text-3xl font-bold text-gray-900 capitalize">
                  <%= humanize_zone_name(zone_name) %>
                </h2>
                <div class="h-1 w-20 bg-gradient-to-r from-blue-500 to-purple-500 rounded"></div>
              </div>

              <div class="timeline-items space-y-8">
                <%= for block <- zone_blocks do %>
                  <div class="timeline-item flex items-start space-x-6">
                    <!-- Timeline Dot -->
                    <div class="flex-shrink-0 w-4 h-4 bg-blue-500 rounded-full mt-2 relative">
                      <div class="absolute top-4 left-1/2 transform -translate-x-1/2 w-0.5 h-16 bg-blue-200"></div>
                    </div>

                    <!-- Timeline Content -->
                    <div class="flex-1 min-w-0">
                      <.live_component
                        module={PublicBlockRenderer}
                        id={"list-#{zone_name}-#{block.id}"}
                        block={block}
                        layout_type={:list}
                        render_context={@render_context}
                        public_view_settings={@public_view_settings} />
                    </div>
                  </div>
                <% end %>
              </div>
            </section>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_gallery_layout(assigns) do
    ~H"""
    <div class="gallery-layout">
      <!-- Hero Section (Full Width) -->
      <section class="hero-section relative h-screen flex items-center justify-center" id="hero-section">
        <%= for block <- Map.get(@layout_zones, :hero, []) do %>
          <.live_component
            module={PublicBlockRenderer}
            id={"gallery-hero-#{block.id}"}
            block={block}
            layout_type={:gallery}
            render_context={@render_context}
            public_view_settings={@public_view_settings} />
        <% end %>
      </section>

      <!-- Gallery Grid Sections -->
      <div class="gallery-content py-16 px-4">
        <%= for {zone_name, zone_blocks} <- get_ordered_content_zones(@layout_zones) do %>
          <%= if length(zone_blocks) > 0 do %>
            <section class="gallery-section mb-20" id={"#{zone_name}-section"}>
              <div class="container mx-auto max-w-7xl">
                <h2 class="text-4xl font-bold text-center mb-12 text-gray-900">
                  <%= humanize_zone_name(zone_name) %>
                </h2>

                <!-- Masonry/Grid Layout -->
                <div class="gallery-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
                  <%= for block <- zone_blocks do %>
                    <div class="gallery-item group">
                      <.live_component
                        module={PublicBlockRenderer}
                        id={"gallery-#{zone_name}-#{block.id}"}
                        block={block}
                        layout_type={:gallery}
                        render_context={@render_context}
                        public_view_settings={@public_view_settings} />
                    </div>
                  <% end %>
                </div>
              </div>
            </section>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_dashboard_layout(assigns) do
    ~H"""
    <div class="dashboard-layout">
      <!-- Hero Zone (Full Width) -->
      <section class="hero-zone bg-gradient-to-br from-blue-50 via-white to-purple-50" id="hero-section">
        <div class="container mx-auto px-4 py-16">
          <%= for block <- Map.get(@layout_zones, :hero, []) do %>
            <.live_component
              module={PublicBlockRenderer}
              id={"dashboard-hero-#{block.id}"}
              block={block}
              layout_type={:dashboard}
              render_context={@render_context}
              public_view_settings={@public_view_settings} />
          <% end %>
        </div>
      </section>

      <!-- Main Dashboard Grid -->
      <section class="main-content-zone py-16 px-4">
        <div class="container mx-auto max-w-7xl">
          <!-- About & Services Row -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8 mb-12">
            <!-- About Column -->
            <div class="lg:col-span-2 space-y-8">
              <%= for block <- Map.get(@layout_zones, :about, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-about-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>

            <!-- Services Sidebar -->
            <div class="space-y-6">
              <%= for block <- Map.get(@layout_zones, :services, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-services-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>
          </div>

          <!-- Experience & Projects Grid -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 mb-12">
            <!-- Experience Column -->
            <div class="space-y-8">
              <h3 class="text-2xl font-bold text-gray-900 mb-6">Experience</h3>
              <%= for block <- Map.get(@layout_zones, :experience, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-experience-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>

            <!-- Projects Column -->
            <div class="space-y-8">
              <h3 class="text-2xl font-bold text-gray-900 mb-6">Projects</h3>
              <%= for block <- Map.get(@layout_zones, :projects, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-projects-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>
          </div>

          <!-- Skills & Media Showcase -->
          <div class="grid grid-cols-1 lg:grid-cols-4 gap-8 mb-12">
            <!-- Skills (2 columns) -->
            <div class="lg:col-span-2 space-y-6">
              <%= for block <- Map.get(@layout_zones, :skills, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-skills-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>

            <!-- Media Showcase (2 columns) -->
            <div class="lg:col-span-2 space-y-6">
              <%= for block <- Map.get(@layout_zones, :media, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-media-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>
          </div>

          <!-- Testimonials & Contact Row -->
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
            <!-- Testimonials (2 columns) -->
            <div class="lg:col-span-2 space-y-6">
              <%= for block <- Map.get(@layout_zones, :testimonials, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-testimonials-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>

            <!-- Contact (1 column) -->
            <div class="space-y-6">
              <%= for block <- Map.get(@layout_zones, :contact, []) do %>
                <.live_component
                  module={PublicBlockRenderer}
                  id={"dashboard-contact-#{block.id}"}
                  block={block}
                  layout_type={:dashboard}
                  render_context={@render_context}
                  public_view_settings={@public_view_settings} />
              <% end %>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  # ============================================================================
  # NAVIGATION COMPONENTS
  # ============================================================================

  defp render_sticky_navigation(assigns) do
    ~H"""
    <nav class="sticky-navigation fixed top-0 left-0 right-0 z-30 bg-white/90 backdrop-blur-md border-b border-gray-200 transition-all duration-200"
         id="sticky-nav"
         style="transform: translateY(-100%); opacity: 0;">
      <div class="container mx-auto px-4">
        <div class="flex items-center justify-between h-16">
          <!-- Portfolio Title -->
          <div class="flex items-center space-x-3">
            <h1 class="text-xl font-bold text-gray-900">
              <%= @portfolio.title %>
            </h1>
          </div>

          <!-- Desktop Navigation -->
          <div class="hidden md:flex items-center space-x-6">
            <%= for section <- @mobile_nav_sections do %>
              <button class={[
                "nav-link px-3 py-2 text-sm font-medium rounded-lg transition-colors duration-200",
                if(@active_section == section.id, do: "bg-blue-100 text-blue-700", else: "text-gray-600 hover:text-gray-900 hover:bg-gray-100")
              ]}
                      phx-click="scroll_to_section"
                      phx-value-section={section.id}
                      phx-target={@myself}>
                <%= section.title %>
              </button>
            <% end %>
          </div>

          <!-- Mobile Menu Button -->
          <button class="md:hidden p-2 text-gray-600 hover:text-gray-900"
                  phx-click="toggle_mobile_nav"
                  phx-target={@myself}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
            </svg>
          </button>
        </div>
      </div>
    </nav>
    """
  end

  defp render_mobile_nav_overlay(assigns) do
    ~H"""
    <div class="mobile-nav-overlay fixed inset-0 z-50 md:hidden">
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black/50 backdrop-blur-sm"
           phx-click="toggle_mobile_nav"
           phx-target={@myself}></div>

      <!-- Navigation Panel -->
      <div class="fixed top-0 left-0 w-80 h-full bg-white shadow-xl transform transition-transform duration-300">
        <!-- Header -->
        <div class="flex items-center justify-between p-6 border-b border-gray-200">
          <h2 class="text-xl font-bold text-gray-900">Navigation</h2>
          <button class="p-2 text-gray-500 hover:text-gray-700"
                  phx-click="toggle_mobile_nav"
                  phx-target={@myself}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>
        </div>

        <!-- Navigation Links -->
        <div class="py-6">
          <%= for section <- @mobile_nav_sections do %>
            <button class={[
              "w-full text-left px-6 py-4 text-lg font-medium transition-colors duration-200",
              if(@active_section == section.id, do: "bg-blue-50 text-blue-700 border-r-4 border-blue-500", else: "text-gray-700 hover:bg-gray-50")
            ]}
                    phx-click="scroll_to_section"
                    phx-value-section={section.id}
                    phx-target={@myself}>
              <%= section.title %>
            </button>
          <% end %>
        </div>

        <!-- Layout Type Switcher (Optional) -->
        <div class="border-t border-gray-200 p-6">
          <h3 class="text-sm font-semibold text-gray-900 mb-3">View Style</h3>
          <div class="grid grid-cols-2 gap-2">
            <%= for layout_type <- @layout_types do %>
              <button class={[
                "p-3 text-sm font-medium rounded-lg border transition-colors duration-200",
                if(@current_layout_type == layout_type,
                   do: "bg-blue-100 text-blue-700 border-blue-300",
                   else: "bg-gray-50 text-gray-700 border-gray-200 hover:bg-gray-100")
              ]}
                      phx-click="change_layout_type"
                      phx-value-type={layout_type}
                      phx-target={@myself}>
                <%= humanize_layout_type(layout_type) %>
              </button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end

    # Helper function to render blocks without live_component
  defp render_public_block(block, layout_type, render_context, public_view_settings, parent_assigns) do
    block_assigns = %{
      block: block,
      layout_type: layout_type,
      render_context: render_context,
      public_view_settings: public_view_settings
    }

    # Use the PublicBlockRenderer functions directly
    case get_block_type_safe(block) do
      :hero_card -> render_hero_block_content(block_assigns)
      :about_card -> render_about_block_content(block_assigns)
      :experience_card -> render_experience_block_content(block_assigns)
      :service_card -> render_service_block_content(block_assigns)
      :project_card -> render_project_block_content(block_assigns)
      :skill_card -> render_skill_block_content(block_assigns)
      :testimonial_card -> render_testimonial_block_content(block_assigns)
      :contact_card -> render_contact_block_content(block_assigns)
      :media_showcase -> render_media_showcase_block_content(block_assigns)
      _ -> render_generic_block_content(block_assigns)
    end
  end

  defp get_block_type_safe(block) do
    case block do
      %{block_type: type} -> type
      %{"block_type" => type} when is_binary(type) -> String.to_atom(type)
      %{type: type} -> type
      %{"type" => type} when is_binary(type) -> String.to_atom(type)
      _ -> :text_card
    end
  end

  # Simple block renderers - these create basic HTML without the full PublicBlockRenderer component
  defp render_hero_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="hero-block bg-gradient-to-br from-blue-50 to-purple-50 rounded-lg p-8 text-center">
      <%= if @block_content["title"] do %>
        <h1 class="text-4xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h1>
      <% end %>

      <%= if @block_content["subtitle"] do %>
        <p class="text-xl text-gray-600 mb-6">
          <%= @block_content["subtitle"] %>
        </p>
      <% end %>

      <%= if @block_content["description"] do %>
        <div class="text-gray-700 mb-8">
          <%= Phoenix.HTML.raw(String.replace(@block_content["description"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_about_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="about-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h2 class="text-2xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h2>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_experience_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="experience-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-2">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["subtitle"] do %>
        <p class="text-lg text-gray-700 mb-3">
          <%= @block_content["subtitle"] %>
        </p>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-600">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_service_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="service-block bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-3">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["description"] do %>
        <p class="text-gray-600 mb-4">
          <%= @block_content["description"] %>
        </p>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_project_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="project-block bg-white rounded-lg shadow p-6 hover:shadow-lg transition-shadow">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-3">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["description"] do %>
        <p class="text-gray-600 mb-4">
          <%= @block_content["description"] %>
        </p>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_skill_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="skill-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_testimonial_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="testimonial-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["content"] do %>
        <blockquote class="text-lg text-gray-700 italic mb-4">
          "<%= @block_content["content"] %>"
        </blockquote>
      <% end %>

      <%= if @block_content["title"] do %>
        <div class="font-semibold text-gray-900">
          <%= @block_content["title"] %>
        </div>
      <% end %>

      <%= if @block_content["subtitle"] do %>
        <div class="text-sm text-gray-600">
          <%= @block_content["subtitle"] %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="contact-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_media_showcase_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="media-showcase-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-4">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["description"] do %>
        <p class="text-gray-600 mb-4">
          <%= @block_content["description"] %>
        </p>
      <% end %>

      <div class="text-center py-8 text-gray-500">
        <p>Media gallery would appear here</p>
      </div>
    </div>
    """
  end

  defp render_generic_block_content(assigns) do
    block_content = get_block_content_safe(assigns.block)
    assigns = assign(assigns, :block_content, block_content)

    ~H"""
    <div class="generic-block bg-white rounded-lg shadow p-6">
      <%= if @block_content["title"] do %>
        <h3 class="text-xl font-bold text-gray-900 mb-3">
          <%= @block_content["title"] %>
        </h3>
      <% end %>

      <%= if @block_content["content"] do %>
        <div class="text-gray-700">
          <%= Phoenix.HTML.raw(String.replace(@block_content["content"] || "", "\n", "<br>")) %>
        </div>
      <% end %>
    </div>
    """
  end

    defp get_block_content_safe(block) do
    case block do
      %{content_data: content} when is_map(content) -> content
      %{"content_data" => content} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"content" => content} when is_map(content) -> content
      _ -> %{}
    end
  end

  defp determine_layout_type(public_view_settings) do
    requested_type = Map.get(public_view_settings, :layout_type, "dashboard")
    case requested_type do
      type when type in ["minimal", "list", "gallery", "dashboard"] -> String.to_atom(type)
      _ -> :dashboard
    end
  end

  defp generate_mobile_navigation(layout_zones) do
    zones_with_content = Enum.filter(layout_zones, fn {_zone, blocks} -> length(blocks) > 0 end)

    Enum.map(zones_with_content, fn {zone_name, _blocks} ->
      %{
        id: "#{zone_name}-section",
        title: humanize_zone_name(zone_name),
        zone: zone_name
      }
    end)
  end

  defp get_ordered_content_zones(layout_zones) do
    # Define the order we want zones to appear in
    zone_order = [:about, :experience, :services, :projects, :skills, :media, :testimonials, :contact]

    zone_order
    |> Enum.map(fn zone -> {zone, Map.get(layout_zones, zone, [])} end)
    |> Enum.filter(fn {_zone, blocks} -> length(blocks) > 0 end)
  end

  defp determine_active_section(scroll_position, nav_sections) do
    # This would be enhanced with actual section positions from JS
    # For now, return the first section
    case nav_sections do
      [first | _] -> first.id
      [] -> nil
    end
  end


  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp determine_layout_type(public_view_settings) do
    requested_type = Map.get(public_view_settings, :layout_type, "dashboard")
    case requested_type do
      type when type in ["minimal", "list", "gallery", "dashboard"] -> String.to_atom(type)
      _ -> :dashboard
    end
  end

  defp generate_mobile_navigation(layout_zones) do
    zones_with_content = Enum.filter(layout_zones, fn {_zone, blocks} -> length(blocks) > 0 end)

    Enum.map(zones_with_content, fn {zone_name, _blocks} ->
      %{
        id: "#{zone_name}-section",
        title: humanize_zone_name(zone_name),
        zone: zone_name
      }
    end)
  end

  defp get_ordered_content_zones(layout_zones) do
    # Define the order we want zones to appear in
    zone_order = [:about, :experience, :services, :projects, :skills, :media, :testimonials, :contact]

    zone_order
    |> Enum.map(fn zone -> {zone, Map.get(layout_zones, zone, [])} end)
    |> Enum.filter(fn {_zone, blocks} -> length(blocks) > 0 end)
  end

  defp determine_active_section(scroll_position, nav_sections) do
    # This would be enhanced with actual section positions from JS
    # For now, return the first section
    case nav_sections do
      [first | _] -> first.id
      [] -> nil
    end
  end

  defp humanize_zone_name(zone_name) do
    zone_name
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_layout_type(layout_type) do
    case layout_type do
      :minimal -> "Minimal"
      :list -> "Timeline"
      :gallery -> "Gallery"
      :dashboard -> "Dashboard"
      _ -> "Dashboard"
    end
  end
end
