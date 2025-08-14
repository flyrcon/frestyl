# File: lib/frestyl_web/live/portfolio_live/components/enhanced_portfolio_layouts.ex
defmodule FrestylWeb.PortfolioLive.Components.EnhancedPortfolioLayouts do
  @moduledoc """
  Enhanced portfolio layouts: Time Machine (5th) and Grid (6th) options.
  iOS-style polish with smooth animations and mobile-first design.
  Maintains existing functionality including Skills section coloring.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  # ============================================================================
  # MAIN LAYOUT DISPATCHER
  # ============================================================================

  def render_enhanced_portfolio_layout(portfolio, sections, layout_type, color_scheme, customization \\ %{}) do
    case normalize_layout_type(layout_type) do
      :time_machine -> render_time_machine_layout(portfolio, sections, color_scheme, customization)
      :grid -> render_grid_layout(portfolio, sections, color_scheme, customization)
      _ -> render_fallback_layout(portfolio, sections, layout_type, color_scheme)
    end
  end

  # ============================================================================
  # TIME MACHINE LAYOUT (5th Option) - iOS-Style Book Transitions
  # ============================================================================

  defp render_time_machine_layout(portfolio, sections, color_scheme, customization) do
    scroll_direction = Map.get(customization, "scroll_direction", "vertical")
    organized_sections = organize_sections_for_time_machine(sections, portfolio)

    color_config = get_color_configuration(color_scheme, customization)

    assigns = %{
      portfolio: portfolio,
      sections: organized_sections,
      color_config: color_config,
      total_cards: length(organized_sections),
      scroll_direction: scroll_direction,
      customization: customization
    }

    ~H"""
    <div class="time-machine-portfolio fixed inset-0 overflow-hidden"
         style={"background: #{@color_config.background};"}>

      <!-- Time Machine Stage with 3D Perspective -->
      <div id="time-machine-stage"
           class="relative w-full h-full"
           style="perspective: 1200px; perspective-origin: center center;"
           phx-hook="TimeMachineController"
           data-total-cards={@total_cards}
           data-scroll-direction={@scroll_direction}>

        <!-- iOS-Style Navigation Header -->
        <%= render_ios_navigation(@assigns) %>

        <!-- 3D Card Stack Container -->
        <div id="card-stack-container"
             class="absolute inset-0 flex items-center justify-center p-4 md:p-8"
             style="transform-style: preserve-3d;">
          <%= for {section, index} <- Enum.with_index(@sections) do %>
            <%= render_time_machine_card(section, index, @assigns) %>
          <% end %>
        </div>

        <!-- Subtle Progress & Navigation -->
        <%= render_ios_controls(@assigns) %>
      </div>

      <!-- Enhanced JavaScript Controller -->
      <%= render_time_machine_scripts(@assigns) %>
    </div>
    """
  end

  defp render_ios_navigation(assigns) do
    ~H"""
    <nav class="fixed top-0 left-0 right-0 z-50 bg-white/70 backdrop-blur-md border-b border-gray-200/30">
      <div class="max-w-screen-xl mx-auto px-4 h-14 flex items-center justify-between">

        <!-- Portfolio Title -->
        <div class="flex items-center space-x-3">
          <button onclick="TimeMachine.exit()"
                  class="w-8 h-8 rounded-full bg-gray-100/80 flex items-center justify-center hover:bg-gray-200/80 transition-colors">
            <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
            </svg>
          </button>
          <h1 class="text-base font-medium text-gray-900 truncate">
            <%= @portfolio.title %>
          </h1>
        </div>

        <!-- Navigation Dots -->
        <div class="flex items-center space-x-2">
          <%= for {_section, index} <- Enum.with_index(@sections) do %>
            <button onclick={"TimeMachine.navigateToCard(#{index})"}
                    data-card-index={index}
                    class={"nav-dot w-2 h-2 rounded-full transition-all duration-300 #{if index == 0, do: "bg-gray-900 scale-125", else: "bg-gray-300 hover:bg-gray-400"}"}>
            </button>
          <% end %>
        </div>

        <!-- Settings -->
        <div class="flex items-center space-x-2">
          <!-- Scroll Direction Toggle -->
          <button onclick="TimeMachine.toggleScrollDirection()"
                  class="w-8 h-8 rounded-full bg-gray-100/80 flex items-center justify-center hover:bg-gray-200/80 transition-colors"
                  title="Toggle scroll direction">
            <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l4-4 4 4m0 6l-4 4-4-4"/>
            </svg>
          </button>
        </div>
      </div>
    </nav>
    """
  end

  defp render_time_machine_card(section, index, assigns) do
    z_index = 50 - index
    card_id = "tm-card-#{section.id || index}"

    # Enhanced transform calculation for book-like effect
    transform_style = calculate_ios_transform(index)
    opacity_style = calculate_ios_opacity(index)
    blur_style = calculate_ios_blur(index)

    ~H"""
    <div id={card_id}
         data-card-index={index}
         data-section-id={section.id}
         class="time-machine-card absolute will-change-transform cursor-pointer"
         style={"
           z-index: #{z_index};
           transform: #{transform_style};
           opacity: #{opacity_style};
           filter: #{blur_style};
           width: min(90vw, 400px);
           height: min(85vh, 600px);
           transition: all 0.8s cubic-bezier(0.25, 0.1, 0.25, 1);
         "}
         onclick={"TimeMachine.bringToFront(#{index})"}>

      <!-- iOS-Style Card with Proper Shadows -->
      <div class="w-full h-full bg-white rounded-2xl shadow-xl border border-gray-100/50 overflow-hidden backdrop-blur-sm"
           style="box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.15), 0 0 0 1px rgba(255, 255, 255, 0.1);">

        <%= render_card_content(section, index, assigns) %>
      </div>
    </div>
    """
  end

  defp render_card_content(section, index, assigns) do
    case {section.section_type, index} do
      {video_type, 0} when video_type in ["video_intro", "hero"] ->
        render_hero_card_content(section, assigns)
      _ ->
        render_section_card_content(section, assigns)
    end
  end

defp render_hero_card_content(section, assigns) do
  content = section.content || %{}
    video_url = Map.get(content, "video_url")

    # FIX: Get name from section content, not portfolio
    name = Map.get(content, "name") || Map.get(content, "headline") || section.title || "Welcome"
    title = Map.get(content, "title") || Map.get(content, "tagline", "")
    description = Map.get(content, "description") || Map.get(content, "story", "")

    assigns = assign(assigns, :video_url, video_url)
    assigns = assign(assigns, :name, name)
    assigns = assign(assigns, :title, title)
    assigns = assign(assigns, :description, description)
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="h-full flex flex-col">
      <!-- Video or Hero Section -->
      <%= if @video_url do %>
        <div class="flex-1 relative overflow-hidden rounded-t-2xl">
          <video autoplay muted loop playsinline class="w-full h-full object-cover">
            <source src={@video_url} type="video/mp4">
          </video>
          <div class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent"></div>

          <!-- Minimal Video Controls -->
          <div class="absolute top-4 right-4">
            <button class="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-white/30 transition-colors">
              <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zM7 8a1 1 0 012 0v4a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v4a1 1 0 002 0V8a1 1 0 00-1-1z" clip-rule="evenodd"/>
              </svg>
            </button>
          </div>
        </div>
      <% else %>
        <div class="flex-1 bg-gradient-to-br from-gray-50 to-white flex items-center justify-center rounded-t-2xl">
          <div class="text-center">
            <div class={"w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6 #{get_hero_avatar_style(@color_config)}"}>
              <span class="text-white font-semibold text-xl">
                <%= get_user_initials(@name) %>
              </span>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Clean Content Area -->
      <div class="p-6 bg-white rounded-b-2xl">
        <div class="text-center space-y-3">
          <h1 class="text-xl font-semibold text-gray-900"><%= @name %></h1>
          <%= if @title && @title != "" do %>
            <p class="text-gray-600 font-medium"><%= @title %></p>
          <% end %>
          <%= if @description && @description != "" do %>
            <p class="text-sm text-gray-500 leading-relaxed line-clamp-3"><%= @description %></p>
          <% end %>

          <!-- Social Links -->
          <%= render_social_links(@content, @color_config) %>
        </div>
      </div>
    </div>
    """
  end

  defp render_ios_controls(assigns) do
    ~H"""
    <!-- Bottom Progress Indicator -->
    <div class="fixed bottom-8 left-1/2 transform -translate-x-1/2 z-40">
      <div class="bg-white/70 backdrop-blur-md rounded-full px-4 py-2 shadow-lg border border-gray-200/30">
        <div class="flex items-center space-x-2 text-sm text-gray-600">
          <span id="current-card-num">1</span>
          <span class="text-gray-400">of</span>
          <span><%= @total_cards %></span>
        </div>
      </div>
    </div>

    <!-- Floating Side Navigation (Desktop) -->
    <div class="hidden md:block">
      <%= if @scroll_direction == "horizontal" do %>
        <!-- Left/Right Navigation -->
        <button id="nav-left"
                onclick="TimeMachine.navigatePrevious()"
                class="fixed left-6 top-1/2 transform -translate-y-1/2 z-40 w-12 h-12 bg-white/70 backdrop-blur-md rounded-full shadow-lg border border-gray-200/30 flex items-center justify-center text-gray-600 hover:text-gray-900 transition-all duration-200 disabled:opacity-30">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7"/>
          </svg>
        </button>

        <button id="nav-right"
                onclick="TimeMachine.navigateNext()"
                class="fixed right-6 top-1/2 transform -translate-y-1/2 z-40 w-12 h-12 bg-white/70 backdrop-blur-md rounded-full shadow-lg border border-gray-200/30 flex items-center justify-center text-gray-600 hover:text-gray-900 transition-all duration-200 disabled:opacity-30">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </button>
      <% else %>
        <!-- Up/Down Navigation -->
        <button id="nav-up"
                onclick="TimeMachine.navigatePrevious()"
                class="fixed top-20 right-6 z-40 w-12 h-12 bg-white/70 backdrop-blur-md rounded-full shadow-lg border border-gray-200/30 flex items-center justify-center text-gray-600 hover:text-gray-900 transition-all duration-200 disabled:opacity-30">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
          </svg>
        </button>

        <button id="nav-down"
                onclick="TimeMachine.navigateNext()"
                class="fixed bottom-20 right-6 z-40 w-12 h-12 bg-white/70 backdrop-blur-md rounded-full shadow-lg border border-gray-200/30 flex items-center justify-center text-gray-600 hover:text-gray-900 transition-all duration-200 disabled:opacity-30">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # GRID LAYOUT (6th Option) - Clean 3-Column System
  # ============================================================================

  defp render_grid_layout(portfolio, sections, color_scheme, customization) do
    color_config = get_color_configuration(color_scheme, customization)
    filtered_sections = sections |> Enum.filter(&(&1.visible)) |> Enum.sort_by(&(&1.position))

    assigns = %{
      portfolio: portfolio,
      sections: filtered_sections,
      color_config: color_config,
      customization: customization
    }

    ~H"""
    <div class="grid-portfolio min-h-screen" style={"background: #{@color_config.background};"}>

      <!-- Clean Grid Header -->
      <header class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 py-8">
          <div class="text-center">
            <h1 class="text-3xl font-bold text-gray-900"><%= @portfolio.title %></h1>
            <%= if @portfolio.description do %>
              <p class="mt-2 text-gray-600 max-w-2xl mx-auto"><%= @portfolio.description %></p>
            <% end %>
          </div>
        </div>
      </header>

      <!-- Responsive Grid Container -->
      <main class="max-w-7xl mx-auto px-4 py-12">
        <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6 auto-rows-min">
          <%= for section <- @sections do %>
            <%= render_grid_card(section, @assigns) %>
          <% end %>
        </div>
      </main>

      <!-- Grid Footer -->
      <footer class="bg-gray-50 border-t border-gray-200 mt-20">
        <div class="max-w-7xl mx-auto px-4 py-8 text-center">
          <p class="text-sm text-gray-500">
            Made with Frestyl • <%= @portfolio.title %>
          </p>
        </div>
      </footer>
    </div>
    """
  end

  defp render_grid_card(section, assigns) do
    content = section.content || %{}
    section_color = get_section_color(section.section_type, assigns.color_config)

    assigns = Map.merge(assigns, %{
      section: section,
      content: content,
      section_color: section_color
    })

    ~H"""
    <div class="grid-card bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow duration-300">

      <!-- Uniform Card Header -->
      <div class={"p-6 #{@section_color.header_bg} border-b border-gray-100"}>
        <div class="flex items-center space-x-3">
          <div class={"w-3 h-3 rounded-full #{@section_color.accent}"}></div>
          <h3 class={"text-lg font-semibold #{@section_color.text} truncate"}><%= @section.title %></h3>
        </div>
        <p class="text-xs text-gray-500 uppercase tracking-wider mt-1">
          <%= get_section_type_label(@section.section_type) %>
        </p>
      </div>

      <!-- Uniform Card Content -->
      <div class="p-6">
        <div class="h-48 overflow-y-auto">
          <%= render_section_content_enhanced(@section, @content, @color_config) %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # ENHANCED CONTENT RENDERING WITH SECTION-SPECIFIC STYLING
  # ============================================================================

  defp render_section_content_enhanced(section, content, color_config) do
    case section.section_type do
      "skills" -> render_skills_enhanced(content, color_config)
      "experience" -> render_experience_enhanced(content, color_config)
      "education" -> render_education_enhanced(content, color_config)
      "projects" -> render_projects_enhanced(content, color_config)
      "contact" -> render_contact_enhanced(content, color_config)
      _ -> render_generic_enhanced(content, color_config)
    end
  end

  defp render_skills_enhanced(content, color_config) do
    skills = Map.get(content, "skills", [])
    description = Map.get(content, "description", "")

    assigns = %{
      skills: skills,
      description: description,
      color_config: color_config
    }

    ~H"""
    <div class="space-y-4">
      <%= if @description != "" do %>
        <p class="text-sm text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>

      <%= if is_list(@skills) and length(@skills) > 0 do %>
        <div class="flex flex-wrap gap-2">
          <%= for skill <- @skills do %>
            <span class={"px-3 py-1 text-xs rounded-full font-medium #{get_skills_badge_style(@color_config)}"}>
              <%= skill %>
            </span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_section_card_content(section, assigns) do
    content = section.content || %{}
    section_color = get_section_color(section.section_type, assigns.color_config)

    assigns = assign(assigns, :section, section)
    assigns = assign(assigns, :content, content)
    assigns = assign(assigns, :section_color, section_color)

    ~H"""
    <div class="h-full flex flex-col">
      <!-- Section Header with Type-Specific Coloring -->
      <div class={"p-6 #{@section_color.header_bg} border-b border-gray-100"}>
        <div class="flex items-center space-x-3">
          <div class={"w-3 h-3 rounded-full #{@section_color.accent}"}></div>
          <h2 class={"text-lg font-semibold #{@section_color.text}"}><%= @section.title %></h2>
        </div>
        <p class="text-xs text-gray-500 uppercase tracking-wider mt-2">
          <%= get_section_type_label(@section.section_type) %>
        </p>
      </div>

      <!-- Scrollable Content Area -->
      <div class="flex-1 overflow-y-auto">
        <div class="p-6">
          <%= render_section_content_enhanced(@section, @content, @color_config) %>
        </div>
      </div>
    </div>
    """
  end

  defp render_experience_enhanced(content, color_config) do
    company = Map.get(content, "company", "")
    position = Map.get(content, "position", "")
    description = Map.get(content, "description", "")
    duration = Map.get(content, "duration", "")

    assigns = %{
      company: company,
      position: position,
      description: description,
      duration: duration,
      color_config: color_config
    }

    ~H"""
    <div class="space-y-3">
      <%= if @position != "" do %>
        <h4 class="font-semibold text-gray-900"><%= @position %></h4>
      <% end %>

      <div class="flex items-center justify-between">
        <%= if @company != "" do %>
          <p class="text-gray-600 font-medium"><%= @company %></p>
        <% end %>
        <%= if @duration != "" do %>
          <span class="text-xs text-gray-500 bg-gray-100 px-2 py-1 rounded"><%= @duration %></span>
        <% end %>
      </div>

      <%= if @description != "" do %>
        <p class="text-sm text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>
    </div>
    """
  end

  defp render_education_enhanced(content, color_config) do
    school = Map.get(content, "school", "")
    degree = Map.get(content, "degree", "")
    description = Map.get(content, "description", "")

    assigns = %{
      school: school,
      degree: degree,
      description: description,
      color_config: color_config
    }

    ~H"""
    <div class="space-y-3">
      <%= if @degree != "" do %>
        <h4 class="font-semibold text-gray-900"><%= @degree %></h4>
      <% end %>
      <%= if @school != "" do %>
        <p class="text-gray-600 font-medium"><%= @school %></p>
      <% end %>
      <%= if @description != "" do %>
        <p class="text-sm text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>
    </div>
    """
  end

  defp render_projects_enhanced(content, color_config) do
    title = Map.get(content, "title", "")
    description = Map.get(content, "description", "")
    url = Map.get(content, "url", "")
    technologies = Map.get(content, "technologies", [])

    assigns = %{
      title: title,
      description: description,
      url: url,
      technologies: technologies,
      color_config: color_config
    }

    ~H"""
    <div class="space-y-4">
      <%= if @title != "" do %>
        <h4 class="font-semibold text-gray-900"><%= @title %></h4>
      <% end %>

      <%= if @description != "" do %>
        <p class="text-sm text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>

      <%= if is_list(@technologies) and length(@technologies) > 0 do %>
        <div class="flex flex-wrap gap-1">
          <%= for tech <- @technologies do %>
            <span class="px-2 py-1 text-xs bg-gray-100 text-gray-700 rounded">
              <%= tech %>
            </span>
          <% end %>
        </div>
      <% end %>

      <%= if @url != "" do %>
        <a href={@url} target="_blank"
          class={"inline-flex items-center text-sm hover:underline #{@color_config.link_color}"}>
          View Project
          <svg class="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
          </svg>
        </a>
      <% end %>
    </div>
    """
  end

  defp render_contact_enhanced(content, color_config) do
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    website = Map.get(content, "website", "")

    assigns = %{
      email: email,
      phone: phone,
      website: website,
      color_config: color_config
    }

    ~H"""
    <div class="space-y-3">
      <%= if @email != "" do %>
        <div class="flex items-center space-x-3">
          <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
          <a href={"mailto:#{@email}"} class={"text-sm hover:underline #{@color_config.link_color}"}>
            <%= @email %>
          </a>
        </div>
      <% end %>

      <%= if @phone != "" do %>
        <div class="flex items-center space-x-3">
          <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
          <a href={"tel:#{@phone}"} class={"text-sm hover:underline #{@color_config.link_color}"}>
            <%= @phone %>
          </a>
        </div>
      <% end %>

      <%= if @website != "" do %>
        <div class="flex items-center space-x-3">
          <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
          <a href={format_website_url(@website)} target="_blank"
            class={"text-sm hover:underline #{@color_config.link_color}"}>
            <%= @website %>
          </a>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_generic_enhanced(content, color_config) do
    description = Map.get(content, "description", "")

    assigns = %{
      description: description,
      color_config: color_config
    }

    ~H"""
    <div>
      <%= if @description != "" do %>
        <p class="text-sm text-gray-600 leading-relaxed"><%= @description %></p>
      <% else %>
        <div class="flex items-center justify-center h-24 text-gray-400">
          <p class="text-sm">Content coming soon</p>
        </div>
      <% end %>
    </div>
    """
  end



  # ============================================================================
  # TIME MACHINE JAVASCRIPT CONTROLLER
  # ============================================================================

  defp render_time_machine_scripts(assigns) do
    ~H"""
    <script>
    window.TimeMachine = {
      currentIndex: 0,
      totalCards: parseInt(document.querySelector('#time-machine-stage').dataset.totalCards),
      scrollDirection: document.querySelector('#time-machine-stage').dataset.scrollDirection || 'vertical',
      isAnimating: false,
      touchStartX: 0,
      touchStartY: 0,
      wheelTimeout: null,

      init() {
        this.updateCardPositions();
        this.updateNavigation();
        this.updateProgress();
        this.setupEventListeners();
      },

      setupEventListeners() {
        this.setupKeyboardNavigation();
        this.setupTouchNavigation();
        this.setupWheelNavigation();
      },

      navigateToCard(index) {
        if (this.isAnimating || index < 0 || index >= this.totalCards || index === this.currentIndex) return;

        this.isAnimating = true;
        this.currentIndex = index;
        this.updateCardPositions();
        this.updateNavigation();
        this.updateProgress();

        // iOS-style animation timing
        setTimeout(() => { this.isAnimating = false; }, 800);
      },

      navigateNext() {
        this.navigateToCard(this.currentIndex + 1);
      },

      navigatePrevious() {
        this.navigateToCard(this.currentIndex - 1);
      },

      bringToFront(index) {
        this.navigateToCard(index);
      },

      updateCardPositions() {
        const cards = document.querySelectorAll('.time-machine-card');

        cards.forEach((card, index) => {
          const relativeIndex = index - this.currentIndex;
          const absIndex = Math.abs(relativeIndex);

          let transform, opacity, filter, zIndex;

          if (relativeIndex === 0) {
            // Front card - full visibility
            transform = 'translateZ(0px) rotateY(0deg) rotateX(0deg) scale(1)';
            opacity = 1;
            filter = 'blur(0px)';
            zIndex = 50;
          } else if (relativeIndex > 0) {
            // Cards behind - book-like stacking with blur
            const depth = absIndex * 30;
            const rotation = absIndex * 2;
            const scale = Math.max(0.85, 1 - (absIndex * 0.05));
            const blur = absIndex * 1.5;

            transform = `translateZ(-${depth}px) rotateY(-${rotation}deg) rotateX(-1deg) scale(${scale})`;
            opacity = Math.max(0.4, 1 - (absIndex * 0.25));
            filter = `blur(${blur}px)`;
            zIndex = 50 - absIndex;
          } else {
            // Cards in front - hidden but positioned for smooth transition
            const depth = absIndex * 30;
            const rotation = absIndex * 2;
            const scale = Math.max(0.85, 1 - (absIndex * 0.05));

            transform = `translateZ(-${depth}px) rotateY(${rotation}deg) rotateX(1deg) scale(${scale})`;
            opacity = 0;
            filter = 'blur(0px)';
            zIndex = 50 - absIndex;
          }

          // Apply transforms with iOS-style easing
          card.style.transform = transform;
          card.style.opacity = opacity;
          card.style.filter = filter;
          card.style.zIndex = zIndex;
        });
      },

      updateNavigation() {
        // Update navigation dots
        document.querySelectorAll('.nav-dot').forEach((dot, index) => {
          if (index === this.currentIndex) {
            dot.className = 'nav-dot w-2 h-2 rounded-full transition-all duration-300 bg-gray-900 scale-125';
          } else {
            dot.className = 'nav-dot w-2 h-2 rounded-full transition-all duration-300 bg-gray-300 hover:bg-gray-400';
          }
        });

        // Update arrow buttons
        const updateButton = (id, disabled) => {
          const btn = document.getElementById(id);
          if (btn) {
            btn.disabled = disabled;
            btn.style.opacity = disabled ? '0.3' : '1';
          }
        };

        if (this.scrollDirection === 'horizontal') {
          updateButton('nav-left', this.currentIndex === 0);
          updateButton('nav-right', this.currentIndex === this.totalCards - 1);
        } else {
          updateButton('nav-up', this.currentIndex === 0);
          updateButton('nav-down', this.currentIndex === this.totalCards - 1);
        }
      },

      updateProgress() {
        const currentSpan = document.getElementById('current-card-num');
        if (currentSpan) {
          currentSpan.textContent = this.currentIndex + 1;
        }
      },

      setupKeyboardNavigation() {
        document.addEventListener('keydown', (e) => {
          if (this.isAnimating) return;

          switch(e.key) {
            case 'ArrowRight':
              e.preventDefault();
              if (this.scrollDirection === 'horizontal') {
                this.navigateNext();
              }
              break;
            case 'ArrowLeft':
              e.preventDefault();
              if (this.scrollDirection === 'horizontal') {
                this.navigatePrevious();
              }
              break;
            case 'ArrowDown':
              e.preventDefault();
              if (this.scrollDirection === 'vertical') {
                this.navigateNext();
              }
              break;
            case 'ArrowUp':
              e.preventDefault();
              if (this.scrollDirection === 'vertical') {
                this.navigatePrevious();
              }
              break;
            case 'Escape':
              this.exit();
              break;
          }
        });
      },

      setupTouchNavigation() {
        const stage = document.getElementById('time-machine-stage');
        if (!stage) return;

        stage.addEventListener('touchstart', (e) => {
          this.touchStartX = e.touches[0].clientX;
          this.touchStartY = e.touches[0].clientY;
        }, { passive: true });

        stage.addEventListener('touchend', (e) => {
          if (!this.touchStartX || !this.touchStartY || this.isAnimating) return;

          const endX = e.changedTouches[0].clientX;
          const endY = e.changedTouches[0].clientY;
          const diffX = this.touchStartX - endX;
          const diffY = this.touchStartY - endY;

          // Require minimum swipe distance (iOS-style threshold)
          const minSwipeDistance = 80;
          if (Math.abs(diffX) < minSwipeDistance && Math.abs(diffY) < minSwipeDistance) return;

          if (this.scrollDirection === 'horizontal') {
            if (Math.abs(diffX) > Math.abs(diffY)) {
              if (diffX > 0) {
                this.navigateNext(); // Swipe left = next
              } else {
                this.navigatePrevious(); // Swipe right = previous
              }
            }
          } else {
            if (Math.abs(diffY) > Math.abs(diffX)) {
              if (diffY > 0) {
                this.navigateNext(); // Swipe up = next
              } else {
                this.navigatePrevious(); // Swipe down = previous
              }
            }
          }

          this.touchStartX = 0;
          this.touchStartY = 0;
        }, { passive: true });
      },

      setupWheelNavigation() {
        document.addEventListener('wheel', (e) => {
          if (this.isAnimating) return;

          // Prevent default scrolling
          e.preventDefault();

          // Clear existing timeout
          if (this.wheelTimeout) {
            clearTimeout(this.wheelTimeout);
          }

          // Debounce wheel events for smoother navigation
          this.wheelTimeout = setTimeout(() => {
            if (this.scrollDirection === 'vertical') {
              if (e.deltaY > 0) {
                this.navigateNext();
              } else {
                this.navigatePrevious();
              }
            } else {
              if (e.deltaX > 0) {
                this.navigateNext();
              } else {
                this.navigatePrevious();
              }
            }
          }, 100);
        }, { passive: false });
      },

      toggleScrollDirection() {
        this.scrollDirection = this.scrollDirection === 'vertical' ? 'horizontal' : 'vertical';

        // Update stage data attribute
        const stage = document.getElementById('time-machine-stage');
        if (stage) {
          stage.dataset.scrollDirection = this.scrollDirection;
        }

        // Update navigation visibility
        this.updateNavigation();

        // Show brief notification
        this.showNotification(`Scroll direction: ${this.scrollDirection}`);
      },

      showNotification(message) {
        // Create temporary notification
        const notification = document.createElement('div');
        notification.className = 'fixed top-20 left-1/2 transform -translate-x-1/2 z-50 bg-black/80 text-white px-4 py-2 rounded-lg text-sm backdrop-blur-sm';
        notification.textContent = message;

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
          notification.style.opacity = '1';
        }, 10);

        // Remove after delay
        setTimeout(() => {
          notification.style.opacity = '0';
          setTimeout(() => {
            document.body.removeChild(notification);
          }, 300);
        }, 2000);
      },

      exit() {
        // Return to normal portfolio view
        window.history.back();
      }
    };

    // Initialize when DOM is ready
    document.addEventListener('DOMContentLoaded', () => {
      if (window.TimeMachine) {
        TimeMachine.init();
      }
    });

    // Handle window resize
    window.addEventListener('resize', () => {
      if (window.TimeMachine && !window.TimeMachine.isAnimating) {
        setTimeout(() => {
          window.TimeMachine.updateCardPositions();
        }, 100);
      }
    });
    </script>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR STYLING AND CONFIGURATION
  # ============================================================================

  defp normalize_layout_type(layout_type) do
    case layout_type do
      "time_machine" -> :time_machine
      "grid" -> :grid
      _ -> :fallback
    end
  end

  defp render_fallback_layout(portfolio, sections, layout_type, color_scheme) do
    assigns = %{
      portfolio: portfolio,
      sections: sections,
      layout_type: layout_type,
      color_scheme: color_scheme
    }

    ~H"""
    <div class="fallback-layout p-8">
      <h1 class="text-2xl font-bold"><%= @portfolio.title %></h1>
      <p class="text-gray-600">Layout "<%= @layout_type %>" not supported yet.</p>
    </div>
    """
  end

  # iOS-style transform calculations
  defp calculate_ios_transform(index) do
    case index do
      0 -> "translateZ(0px) rotateY(0deg) rotateX(0deg) scale(1)"
      1 -> "translateZ(-30px) rotateY(-2deg) rotateX(-1deg) scale(0.95)"
      2 -> "translateZ(-60px) rotateY(-4deg) rotateX(-2deg) scale(0.90)"
      _ ->
        depth = index * 30
        rotation = index * 2
        scale = max(0.85, 1 - (index * 0.05))
        "translateZ(-#{depth}px) rotateY(-#{rotation}deg) rotateX(-#{index}deg) scale(#{scale})"
    end
  end

  defp calculate_ios_opacity(index) do
    case index do
      0 -> "1"
      1 -> "0.75"
      2 -> "0.5"
      _ -> "#{safe_max(0.4, 1 - (index * 0.25))}"
    end
  end

  defp calculate_ios_blur(index) do
    case index do
      0 -> "blur(0px)"
      1 -> "blur(1.5px)"
      2 -> "blur(3px)"
      _ -> "blur(#{index * 1.5}px)"
    end
  end

  # Color configuration system
  defp get_color_configuration(color_scheme, customization) do
    # Extract colors from customization or use scheme defaults
    primary = Map.get(customization, "primary_color", get_scheme_primary(color_scheme))
    secondary = Map.get(customization, "secondary_color", get_scheme_secondary(color_scheme))
    accent = Map.get(customization, "accent_color", get_scheme_accent(color_scheme))

    %{
      primary: primary,
      secondary: secondary,
      accent: accent,
      background: "linear-gradient(135deg, #{lighten_color(primary, 0.95)} 0%, white 100%)",
      link_color: "text-blue-600 hover:text-blue-800"
    }
  end

  defp get_scheme_primary(scheme) do
    case scheme do
      "blue" -> "#3b82f6"
      "green" -> "#10b981"
      "purple" -> "#8b5cf6"
      "red" -> "#ef4444"
      "orange" -> "#f59e0b"
      _ -> "#3b82f6"
    end
  end

  defp get_scheme_secondary(scheme) do
    case scheme do
      "blue" -> "#64748b"
      "green" -> "#6b7280"
      "purple" -> "#6b7280"
      "red" -> "#6b7280"
      "orange" -> "#6b7280"
      _ -> "#64748b"
    end
  end

  defp get_scheme_accent(scheme) do
    case scheme do
      "blue" -> "#1d4ed8"
      "green" -> "#059669"
      "purple" -> "#7c3aed"
      "red" -> "#dc2626"
      "orange" -> "#ea580c"
      _ -> "#1d4ed8"
    end
  end

  # Section-specific color configuration (maintains Skills section coloring)
  defp get_section_color(section_type, color_config) do
    case section_type do
      "skills" -> %{
        header_bg: "bg-blue-50",
        text: "text-blue-900",
        accent: "bg-blue-500"
      }
      "experience" -> %{
        header_bg: "bg-green-50",
        text: "text-green-900",
        accent: "bg-green-500"
      }
      "education" -> %{
        header_bg: "bg-purple-50",
        text: "text-purple-900",
        accent: "bg-purple-500"
      }
      "projects" -> %{
        header_bg: "bg-orange-50",
        text: "text-orange-900",
        accent: "bg-orange-500"
      }
      "contact" -> %{
        header_bg: "bg-gray-50",
        text: "text-gray-900",
        accent: "bg-gray-500"
      }
      _ -> %{
        header_bg: "bg-gray-50",
        text: "text-gray-900",
        accent: "bg-gray-400"
      }
    end
  end

  defp get_skills_badge_style(color_config) do
    "bg-blue-100 text-blue-800 hover:bg-blue-200 transition-colors"
  end

  defp get_hero_avatar_style(color_config) do
    "bg-gradient-to-r from-blue-600 to-purple-600"
  end

  # Social links rendering
  defp render_social_links(content, color_config) do
    social_links = Map.get(content, "social_links", %{})
    contact_info = Map.get(content, "contact_info", %{})
    all_links = Map.merge(social_links, contact_info)

    if map_size(all_links) > 0 do
      assigns = %{links: all_links, color_config: color_config}

      ~H"""
      <div class="flex justify-center space-x-3 mt-4 pt-4 border-t border-gray-100">
        <%= for {platform, url} <- @links do %>
          <%= if url && url != "" do %>
            <a href={format_link_url(platform, url)}
               target="_blank"
               class="w-8 h-8 bg-gray-100 rounded-full flex items-center justify-center hover:bg-gray-200 transition-colors text-gray-600 hover:text-gray-800">
              <span class="text-xs font-medium">
                <%= String.first(platform) |> String.upcase() %>
              </span>
            </a>
          <% end %>
        <% end %>
      </div>
      """
    else
      assigns = %{}
      ~H"<div></div>"
    end
  end

  # Helper functions
  defp safe_max(a, b) when a > b, do: a
  defp safe_max(_a, b), do: b

  defp lighten_color(hex_color, amount) do
    # Simple color lightening - in production, use a proper color library
    hex_color
  end

  defp format_link_url(platform, url) do
    case platform do
      "email" -> "mailto:#{url}"
      "phone" -> "tel:#{url}"
      _ -> if String.starts_with?(url, "http"), do: url, else: "https://#{url}"
    end
  end

  defp format_website_url(url) do
    if String.starts_with?(url, "http"), do: url, else: "https://#{url}"
  end

  defp get_user_initials(name) when is_binary(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()
  end
  defp get_user_initials(_), do: "U"

  defp get_section_type_label(section_type) do
    case section_type do
      "video_intro" -> "Introduction"
      "hero" -> "Welcome"
      "experience" -> "Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "contact" -> "Contact"
      _ -> "Section"
    end
  end

  # Section organization for Time Machine
  defp organize_sections_for_time_machine(sections, portfolio) do
    video_section = find_video_intro_section(sections, portfolio)

    other_sections = sections
    |> Enum.reject(&(&1.id == (video_section && video_section.id)))
    |> Enum.filter(&(&1.visible))
    |> Enum.sort_by(&(&1.position))

    if video_section do
      [video_section | other_sections]
    else
      hero_card = create_hero_card(portfolio)
      [hero_card | other_sections]
    end
  end

  defp find_video_intro_section(sections, portfolio) do
    video_section = Enum.find(sections, fn section ->
      section.section_type in ["video_intro", "hero"] and
      has_video_content?(section)
    end)

    if !video_section and has_portfolio_video?(portfolio) do
      create_video_section_from_portfolio(portfolio)
    else
      video_section
    end
  end

  defp has_video_content?(section) do
    content = section.content || %{}
    get_in(content, ["video_url"]) != nil
  end

  defp has_portfolio_video?(portfolio) do
    customization = portfolio.customization || %{}
    get_in(customization, ["video_url"]) != nil
  end

  defp create_video_section_from_portfolio(portfolio) do
    customization = portfolio.customization || %{}

    %{
      id: "portfolio_video",
      title: portfolio.title || "Welcome",
      section_type: "video_intro",
      position: 0,
      visible: true,
      content: %{
        "name" => portfolio.title,
        "title" => Map.get(customization, "professional_title", ""),
        "description" => portfolio.description,
        "video_url" => get_in(customization, ["video_url"]),
        "social_links" => %{},
        "contact_info" => portfolio.contact_info || %{}
      }
    }
  end

  defp create_hero_card(portfolio) do
    %{
      id: "hero_card",
      title: "Welcome",
      section_type: "hero",
      position: 0,
      visible: true,
      content: %{
        "name" => portfolio.title || "Portfolio",
        "headline" => portfolio.title || "Welcome",
        "description" => portfolio.description || "",
        "social_links" => %{},
        "contact_info" => portfolio.contact_info || %{}
      }
    }
  end
end
