# File: lib/frestyl_web/live/portfolio_live/components/enhanced_layout_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer do
  @moduledoc """
  PATCH 3: Enhanced layout rendering system that makes each layout type visually distinct.
  Supports: Standard, Dashboard, Masonry Grid, Timeline, Magazine, and Minimal layouts.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.EnhancedContentRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedHeroRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedSectionCards

  # ============================================================================
  # MAIN LAYOUT RENDERER
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme) do
    # Filter out empty sections
    filtered_sections = filter_non_empty_sections(sections)

    # Get layout configuration
    layout_config = get_layout_config(layout_type, theme, color_scheme)

    # Render based on layout type
    case normalize_layout_type(layout_type) do
      :standard -> render_standard_layout(portfolio, filtered_sections, layout_config)
      :dashboard -> render_dashboard_layout(portfolio, filtered_sections, layout_config)
      :grid -> render_masonry_grid_layout(portfolio, filtered_sections, layout_config)
      :timeline -> render_timeline_layout(portfolio, filtered_sections, layout_config)
      :magazine -> render_magazine_layout(portfolio, filtered_sections, layout_config)
      :minimal -> render_minimal_layout(portfolio, filtered_sections, layout_config)
      _ -> render_standard_layout(portfolio, filtered_sections, layout_config)
    end
  end

  # ============================================================================
  # STANDARD LAYOUT - Clean Single-Column
  # ============================================================================

  defp render_standard_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout standard-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Main Content -->
      <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
        <div class="space-y-16">
          #{render_sections_standard(sections, config)}
        </div>
      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "standard")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>
    """
  end

  defp render_sections_standard(sections, config) do
    sections
    |> Enum.map(fn section ->
      """
      <section id="section-#{section.id}" class="standard-section">
        <div class="#{config.section_card} rounded-xl p-8 shadow-sm border #{config.border_color}">
          <header class="section-header mb-6">
            <h2 class="text-2xl font-bold #{config.heading_color} mb-2">#{section.title}</h2>
            <div class="h-1 w-16 #{config.accent_bg} rounded-full"></div>
          </header>
          <div class="section-content #{config.content_spacing}">
            #{EnhancedContentRenderer.render_enhanced_section_content(section, config.color_scheme)}
          </div>
        </div>
      </section>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # DASHBOARD LAYOUT - Modern Card-Based Grid
  # ============================================================================

  defp render_dashboard_layout(portfolio, sections, config) do
    # Organize sections into dashboard widgets
    {primary_sections, secondary_sections} = organize_dashboard_sections(sections)

    """
    <div class="portfolio-layout dashboard-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Dashboard Grid -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

        <!-- Dashboard Header -->
        <div class="dashboard-header mb-8">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold #{config.heading_color}">Portfolio Dashboard</h1>
              <p class="#{config.subtext_color} mt-1">#{length(sections)} sections • Last updated today</p>
            </div>
            <div class="dashboard-stats flex space-x-6">
              <div class="stat-item text-center">
                <div class="text-2xl font-bold #{config.primary_color}">#{calculate_completion_percentage(sections)}%</div>
                <div class="text-xs #{config.subtext_color}">Complete</div>
              </div>
              <div class="stat-item text-center">
                <div class="text-2xl font-bold #{config.primary_color}">#{length(sections)}</div>
                <div class="text-xs #{config.subtext_color}">Sections</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Primary Dashboard Grid -->
        <div class="dashboard-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-8">
          #{render_dashboard_cards(primary_sections, config, "primary")}
        </div>

        <!-- Secondary Dashboard Grid -->
        #{if length(secondary_sections) > 0 do
          "<div class='secondary-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6'>
            #{render_dashboard_cards(secondary_sections, config, "secondary")}
          </div>"
        else
          ""
        end}

      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "dashboard")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>
    """
  end

  defp render_dashboard_cards(sections, config, card_type) do
    sections
    |> Enum.map(fn section ->
      card_class = if card_type == "primary", do: "dashboard-card-primary", else: "dashboard-card-secondary"

      """
      <div id="section-#{section.id}" class="dashboard-card #{card_class} #{config.card_bg} rounded-xl border #{config.border_color} hover:shadow-lg transition-all duration-300 group cursor-pointer"
           onclick="openSectionModal('#{section.id}')">

        <!-- Card Header -->
        <div class="card-header p-4 border-b #{config.border_color}">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="section-icon w-8 h-8 #{config.icon_bg} rounded-lg flex items-center justify-center">
                #{get_section_icon(section.section_type)}
              </div>
              <h3 class="font-semibold #{config.heading_color} truncate">#{section.title}</h3>
            </div>
            <button class="expand-btn opacity-0 group-hover:opacity-100 transition-opacity p-1 hover:#{config.hover_bg} rounded">
              <svg class="w-4 h-4 #{config.text_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"></path>
              </svg>
            </button>
          </div>
        </div>

        <!-- Card Content -->
        <div class="card-content p-4 h-32 overflow-hidden">
          <div class="content-preview #{config.content_text} text-sm leading-relaxed">
            #{get_section_preview(section, 120)}
          </div>
        </div>

        <!-- Card Footer -->
        <div class="card-footer p-4 pt-0">
          <div class="flex items-center justify-between text-xs #{config.subtext_color}">
            <span>#{get_section_type_label(section.section_type)}</span>
            <span>#{get_content_length_indicator(section)}</span>
          </div>
        </div>

      </div>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # MASONRY GRID LAYOUT - Pinterest-Style
  # ============================================================================

  defp render_masonry_grid_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout masonry-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Masonry Grid -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

        <!-- Grid Header -->
        <div class="grid-header text-center mb-12">
          <h1 class="text-4xl font-bold #{config.heading_color} mb-4">Portfolio Gallery</h1>
          <p class="text-lg #{config.subtext_color} max-w-2xl mx-auto">Explore my work through this visual showcase</p>
        </div>

        <!-- Masonry Container -->
        <div class="masonry-container" data-masonry='{"percentPosition": true, "itemSelector": ".masonry-item", "columnWidth": ".masonry-sizer"}'>
          <!-- Grid Sizer for Masonry -->
          <div class="masonry-sizer w-full sm:w-1/2 lg:w-1/3 xl:w-1/4"></div>

          #{render_masonry_items(sections, config)}
        </div>

      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "masonry")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>

    <!-- Masonry JavaScript -->
    <script src="https://unpkg.com/masonry-layout@4/dist/masonry.pkgd.min.js"></script>
    <script>
      document.addEventListener('DOMContentLoaded', function() {
        new Masonry('.masonry-container', {
          itemSelector: '.masonry-item',
          columnWidth: '.masonry-sizer',
          percentPosition: true,
          gutter: 24
        });
      });
    </script>
    """
  end

  defp render_masonry_items(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      # Vary heights for visual interest
      height_class = case rem(index, 4) do
        0 -> "h-64"  # Short
        1 -> "h-80"  # Medium
        2 -> "h-96"  # Tall
        3 -> "h-72"  # Medium-tall
      end

      """
      <div id="section-#{section.id}" class="masonry-item w-full sm:w-1/2 lg:w-1/3 xl:w-1/4 mb-6 cursor-pointer"
           onclick="openSectionModal('#{section.id}')">
        <div class="masonry-card #{config.card_bg} rounded-2xl shadow-md hover:shadow-xl transition-all duration-300 overflow-hidden group #{height_class}">

          <!-- Card Image/Visual -->
          <div class="card-visual h-1/2 #{config.gradient_bg} relative overflow-hidden">
            #{render_section_visual(section, config)}
            <div class="absolute inset-0 bg-gradient-to-t from-black/30 to-transparent"></div>
            <div class="absolute bottom-4 left-4 right-4">
              <h3 class="text-white font-bold text-lg mb-1">#{section.title}</h3>
              <p class="text-white/80 text-sm">#{get_section_type_label(section.section_type)}</p>
            </div>
          </div>

          <!-- Card Content -->
          <div class="card-content p-4 h-1/2 flex flex-col">
            <div class="content-preview flex-1 overflow-hidden">
              <p class="#{config.content_text} text-sm leading-relaxed">
                #{get_section_preview(section, 100)}
              </p>
            </div>

            <!-- Expand Button -->
            <div class="card-footer mt-4 flex justify-between items-center">
              <span class="text-xs #{config.subtext_color}">#{get_content_length_indicator(section)}</span>
              <button class="expand-btn opacity-0 group-hover:opacity-100 transition-opacity #{config.primary_bg} text-white p-2 rounded-full">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"></path>
                </svg>
              </button>
            </div>
          </div>

        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # TIMELINE LAYOUT - Chronological Flow
  # ============================================================================

  defp render_timeline_layout(portfolio, sections, config) do
    # Sort sections chronologically where possible
    sorted_sections = sort_sections_chronologically(sections)

    """
    <div class="portfolio-layout timeline-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Timeline Container -->
      <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

        <!-- Timeline Header -->
        <div class="timeline-header text-center mb-16">
          <h1 class="text-4xl font-bold #{config.heading_color} mb-4">Professional Journey</h1>
          <p class="text-lg #{config.subtext_color}">Follow my career timeline and key milestones</p>
        </div>

        <!-- Timeline -->
        <div class="timeline-container relative">

          <!-- Timeline Line -->
          <div class="timeline-line absolute left-8 top-0 bottom-0 w-0.5 #{config.primary_bg}"></div>

          #{render_timeline_items(sorted_sections, config)}

        </div>

      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "timeline")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>
    """
  end

  defp render_timeline_items(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      is_left = rem(index, 2) == 0
      position_class = if is_left, do: "timeline-left", else: "timeline-right"

      """
      <div id="section-#{section.id}" class="timeline-item #{position_class} relative mb-12 cursor-pointer"
           onclick="openSectionModal('#{section.id}')">

        <!-- Timeline Dot -->
        <div class="timeline-dot absolute left-6 w-4 h-4 #{config.primary_bg} rounded-full border-4 border-white shadow-lg z-10"></div>

        <!-- Timeline Card -->
        <div class="timeline-card ml-20 #{config.card_bg} rounded-xl border #{config.border_color} shadow-md hover:shadow-lg transition-all duration-300 group">

          <!-- Card Header -->
          <div class="card-header p-6 border-b #{config.border_color}">
            <div class="flex items-start justify-between">
              <div>
                <h3 class="text-xl font-bold #{config.heading_color} mb-2">#{section.title}</h3>
                <p class="#{config.subtext_color} text-sm">#{get_section_type_label(section.section_type)}</p>
              </div>
              <div class="flex items-center space-x-2">
                <span class="timeline-date text-xs #{config.subtext_color} bg-gray-100 px-2 py-1 rounded">
                  #{get_section_date(section)}
                </span>
                <button class="expand-btn opacity-0 group-hover:opacity-100 transition-opacity p-1 hover:#{config.hover_bg} rounded">
                  <svg class="w-4 h-4 #{config.text_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"></path>
                  </svg>
                </button>
              </div>
            </div>
          </div>

          <!-- Card Content -->
          <div class="card-content p-6">
            <div class="content-preview max-h-24 overflow-hidden">
              <p class="#{config.content_text} leading-relaxed">
                #{get_section_preview(section, 150)}
              </p>
            </div>

            <!-- Progress Indicator -->
            <div class="progress-indicator mt-4 flex items-center space-x-2">
              <div class="flex-1 h-1 bg-gray-200 rounded-full overflow-hidden">
                <div class="h-full #{config.primary_bg} rounded-full" style="width: #{calculate_section_progress(section, index)}%"></div>
              </div>
              <span class="text-xs #{config.subtext_color}">#{get_content_length_indicator(section)}</span>
            </div>
          </div>

        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # MAGAZINE LAYOUT - Editorial Style
  # ============================================================================

  defp render_magazine_layout(portfolio, sections, config) do
    # Organize sections into magazine-style layout
    {featured_section, regular_sections} = organize_magazine_sections(sections)

    """
    <div class="portfolio-layout magazine-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Magazine Container -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">

        <!-- Magazine Header -->
        <div class="magazine-header mb-12">
          <div class="flex items-end justify-between border-b-4 #{config.primary_border} pb-4">
            <div>
              <h1 class="text-5xl font-bold #{config.heading_color} mb-2">#{portfolio.title}</h1>
              <p class="text-lg #{config.subtext_color}">Professional Portfolio • #{format_current_date()}</p>
            </div>
            <div class="magazine-issue text-right">
              <div class="text-2xl font-bold #{config.primary_color}">Issue #1</div>
              <div class="text-sm #{config.subtext_color}">#{length(sections)} Articles</div>
            </div>
          </div>
        </div>

        #{if featured_section do
          "<!-- Featured Article -->
          <div class='featured-article mb-16'>
            #{render_featured_magazine_article(featured_section, config)}
          </div>"
        else
          ""
        end}

        <!-- Regular Articles Grid -->
        <div class="magazine-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          #{render_magazine_articles(regular_sections, config)}
        </div>

      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "magazine")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>
    """
  end

  defp render_featured_magazine_article(section, config) do
    """
    <article id="section-#{section.id}" class="featured-magazine-article #{config.card_bg} rounded-2xl overflow-hidden shadow-lg hover:shadow-xl transition-all duration-300 cursor-pointer"
             onclick="openSectionModal('#{section.id}')">

      <div class="grid lg:grid-cols-2 gap-8">

        <!-- Article Visual -->
        <div class="article-visual h-64 lg:h-auto #{config.gradient_bg} relative overflow-hidden">
          #{render_section_visual(section, config)}
          <div class="absolute inset-0 bg-gradient-to-r from-black/40 to-transparent"></div>
          <div class="absolute top-4 left-4">
            <span class="featured-badge #{config.accent_bg} text-white px-3 py-1 rounded-full text-sm font-semibold">
              Featured
            </span>
          </div>
        </div>

        <!-- Article Content -->
        <div class="article-content p-8 flex flex-col justify-center">
          <div class="article-meta mb-4">
            <span class="category #{config.primary_color} text-sm font-semibold uppercase tracking-wide">
              #{get_section_type_label(section.section_type)}
            </span>
          </div>

          <h2 class="article-title text-3xl font-bold #{config.heading_color} mb-4">#{section.title}</h2>

          <div class="article-excerpt #{config.content_text} leading-relaxed mb-6">
            <p>#{get_section_preview(section, 200)}</p>
          </div>

          <div class="article-footer flex items-center justify-between">
            <span class="read-time text-sm #{config.subtext_color}">
              #{calculate_read_time(section)} min read
            </span>
            <button class="read-more #{config.primary_bg} text-white px-4 py-2 rounded-lg hover:#{config.primary_hover} transition-colors">
              Read Article
            </button>
          </div>
        </div>

      </div>
    </article>
    """
  end

  defp render_magazine_articles(sections, config) do
    sections
    |> Enum.map(fn section ->
      """
      <article id="section-#{section.id}" class="magazine-article #{config.card_bg} rounded-xl overflow-hidden shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer group"
               onclick="openSectionModal('#{section.id}')">

        <!-- Article Visual -->
        <div class="article-visual h-40 #{config.gradient_bg} relative overflow-hidden">
          #{render_section_visual(section, config)}
          <div class="absolute inset-0 bg-gradient-to-t from-black/50 to-transparent"></div>
          <div class="absolute bottom-4 left-4 right-4">
            <span class="category text-white/90 text-xs font-semibold uppercase tracking-wide">
              #{get_section_type_label(section.section_type)}
            </span>
          </div>
        </div>

        <!-- Article Content -->
        <div class="article-content p-6">
          <h3 class="article-title text-lg font-bold #{config.heading_color} mb-3 group-hover:#{config.primary_color} transition-colors">
            #{section.title}
          </h3>

          <div class="article-excerpt #{config.content_text} text-sm leading-relaxed mb-4 max-h-16 overflow-hidden">
            <p>#{get_section_preview(section, 100)}</p>
          </div>

          <div class="article-footer flex items-center justify-between text-xs #{config.subtext_color}">
            <span>#{calculate_read_time(section)} min read</span>
            <span>#{get_content_length_indicator(section)}</span>
          </div>
        </div>

      </article>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # MINIMAL LAYOUT - Ultra-Clean and Spacious
  # ============================================================================

  defp render_minimal_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout minimal-layout #{config.background}">
      <!-- Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Minimal Content -->
      <main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-16">

        <div class="minimal-sections space-y-24">
          #{render_minimal_sections(sections, config)}
        </div>

      </main>

      <!-- Floating Navigation -->
      #{render_floating_navigation(sections, "minimal")}

      <!-- Footer Actions -->
      #{render_footer_actions(config)}
    </div>
    """
  end

  defp render_minimal_sections(sections, config) do
    sections
    |> Enum.map(fn section ->
      """
      <section id="section-#{section.id}" class="minimal-section cursor-pointer group"
               onclick="openSectionModal('#{section.id}')">

        <!-- Section Header -->
        <header class="section-header mb-8 text-center">
          <h2 class="text-3xl font-light #{config.heading_color} mb-4">#{section.title}</h2>
          <div class="section-divider w-24 h-px #{config.primary_bg} mx-auto opacity-50"></div>
        </header>

        <!-- Section Content -->
        <div class="section-content max-w-2xl mx-auto">
          <div class="content-preview text-center #{config.content_text} leading-loose text-lg max-h-32 overflow-hidden">
            #{get_section_preview(section, 180)}
          </div>

          <!-- Subtle Expand Hint -->
          <div class="expand-hint text-center mt-8 opacity-0 group-hover:opacity-100 transition-opacity">
            <button class="expand-btn text-sm #{config.primary_color} hover:#{config.primary_hover} font-medium">
              Read More
            </button>
          </div>
        </div>

      </section>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # SHARED COMPONENTS
  # ============================================================================

  defp render_floating_navigation(sections, layout_type) do
    nav_items = sections
    |> Enum.map(fn section ->
      """
      <a href="#section-#{section.id}" class="nav-item block p-2 text-gray-600 hover:text-blue-600 hover:bg-blue-50 rounded transition-colors"
         title="#{section.title}">
        <div class="flex items-center space-x-2">
          <span class="nav-icon">#{get_section_icon(section.section_type)}</span>
          <span class="nav-label text-sm font-medium truncate">#{section.title}</span>
        </div>
      </a>
      """
    end)
    |> Enum.join("\n")

    """
    <nav class="floating-navigation fixed right-6 top-1/2 transform -translate-y-1/2 bg-white rounded-lg shadow-lg border border-gray-200 p-2 hidden lg:block z-50">
      <div class="nav-items space-y-1 max-h-80 overflow-y-auto">
        #{nav_items}
      </div>
    </nav>
    """
  end

  defp render_footer_actions(config) do
    """
    <footer class="portfolio-footer bg-white border-t border-gray-200 py-8 mt-16">
      <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex flex-col sm:flex-row items-center justify-between space-y-4 sm:space-y-0">

          <!-- More Actions -->
          <div class="more-actions">
            <div class="dropdown relative">
              <button class="more-btn #{config.secondary_button} px-4 py-2 rounded-lg font-medium transition-colors flex items-center space-x-2">
                <span>More</span>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"></path>
                </svg>
              </button>
              <div class="dropdown-menu absolute bottom-full left-0 mb-2 bg-white border border-gray-200 rounded-lg shadow-lg p-2 hidden">
                <a href="#" class="dropdown-item block p-2 text-gray-700 hover:bg-gray-50 rounded text-sm whitespace-nowrap">
                  📄 Export PDF
                </a>
                <a href="#" class="dropdown-item block p-2 text-gray-700 hover:bg-gray-50 rounded text-sm whitespace-nowrap">
                  💾 Save Resume
                </a>
                <a href="#" class="dropdown-item block p-2 text-gray-700 hover:bg-gray-50 rounded text-sm whitespace-nowrap">
                  📧 Share Portfolio
                </a>
              </div>
            </div>
          </div>

          <!-- Return to Top -->
          <button id="return-to-top" class="return-to-top #{config.primary_button} p-3 rounded-full shadow-lg hover:shadow-xl transition-all duration-300 fixed bottom-6 right-6 z-50 hidden">
            <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"></path>
            </svg>
          </button>

        </div>
      </div>
    </footer>

    <!-- Footer JavaScript -->
    <script>
      // More dropdown functionality
      document.addEventListener('DOMContentLoaded', function() {
        const moreBtn = document.querySelector('.more-btn');
        const dropdown = document.querySelector('.dropdown-menu');

        moreBtn?.addEventListener('click', function(e) {
          e.preventDefault();
          dropdown?.classList.toggle('hidden');
        });

        document.addEventListener('click', function(e) {
          if (!e.target.closest('.dropdown')) {
            dropdown?.classList.add('hidden');
          }
        });

        // Return to top functionality
        const returnToTopBtn = document.getElementById('return-to-top');

        window.addEventListener('scroll', function() {
          if (window.scrollY > 400) {
            returnToTopBtn?.classList.remove('hidden');
          } else {
            returnToTopBtn?.classList.add('hidden');
          }
        });

        returnToTopBtn?.addEventListener('click', function() {
          window.scrollTo({ top: 0, behavior: 'smooth' });
        });

        // Smooth scrolling for floating navigation
        document.querySelectorAll('.floating-navigation a[href^="#"]').forEach(anchor => {
          anchor.addEventListener('click', function(e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
              target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
          });
        });
      });

      // Modal functionality (to be implemented in next patch)
      function openSectionModal(sectionId) {
        console.log('Opening modal for section:', sectionId);
        // This will be implemented in PATCH 4: Section Cards Enhancement
      }
    </script>
    """
  end

  # ============================================================================
  # UTILITY FUNCTIONS
  # ============================================================================

  defp normalize_layout_type(layout_type) do
    case String.downcase(to_string(layout_type)) do
      "standard" -> :standard
      "dashboard" -> :dashboard
      "grid" -> :grid
      "masonry" -> :grid
      "masonry_grid" -> :grid
      "timeline" -> :timeline
      "magazine" -> :magazine
      "minimal" -> :minimal
      _ -> :standard
    end
  end

  defp get_layout_config(layout_type, theme, color_scheme) do
    base_config = %{
      color_scheme: color_scheme,
      theme: theme
    }

    theme_colors = get_theme_colors(theme, color_scheme)
    layout_specific = get_layout_specific_config(layout_type)

    Map.merge(base_config, Map.merge(theme_colors, layout_specific))
  end

  defp get_theme_colors(theme, color_scheme) do
    scheme_colors = get_color_scheme_colors(color_scheme)

    case theme do
      "professional" -> %{
        background: "bg-gray-50",
        card_bg: "bg-white",
        heading_color: "text-gray-900",
        text_color: "text-gray-700",
        content_text: "text-gray-600",
        subtext_color: "text-gray-500",
        border_color: "border-gray-200",
        primary_color: "text-#{color_scheme}-600",
        primary_bg: "bg-#{color_scheme}-600",
        primary_border: "border-#{color_scheme}-600",
        primary_hover: "bg-#{color_scheme}-700",
        accent_bg: "bg-#{color_scheme}-500",
        icon_bg: "bg-#{color_scheme}-50",
        hover_bg: "bg-gray-50",
        gradient_bg: "bg-gradient-to-br from-#{color_scheme}-500 to-#{color_scheme}-600",
        primary_button: "bg-#{color_scheme}-600 hover:bg-#{color_scheme}-700 text-white",
        secondary_button: "border border-gray-300 text-gray-700 hover:bg-gray-50"
      }

      "creative" -> %{
        background: "bg-gradient-to-br from-purple-50 via-pink-50 to-orange-50",
        card_bg: "bg-white/90 backdrop-blur-sm",
        heading_color: "text-gray-900",
        text_color: "text-gray-700",
        content_text: "text-gray-600",
        subtext_color: "text-purple-500",
        border_color: "border-purple-200",
        primary_color: "text-purple-600",
        primary_bg: "bg-gradient-to-r from-purple-500 to-pink-500",
        primary_border: "border-purple-500",
        primary_hover: "from-purple-600 to-pink-600",
        accent_bg: "bg-gradient-to-r from-orange-400 to-pink-400",
        icon_bg: "bg-purple-50",
        hover_bg: "bg-purple-50",
        gradient_bg: "bg-gradient-to-br from-purple-400 via-pink-400 to-orange-400",
        primary_button: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white",
        secondary_button: "border border-purple-300 text-purple-700 hover:bg-purple-50"
      }

      "minimal" -> %{
        background: "bg-white",
        card_bg: "bg-gray-50",
        heading_color: "text-gray-900",
        text_color: "text-gray-700",
        content_text: "text-gray-600",
        subtext_color: "text-gray-400",
        border_color: "border-gray-100",
        primary_color: "text-gray-900",
        primary_bg: "bg-gray-900",
        primary_border: "border-gray-900",
        primary_hover: "bg-gray-800",
        accent_bg: "bg-gray-700",
        icon_bg: "bg-gray-100",
        hover_bg: "bg-gray-50",
        gradient_bg: "bg-gradient-to-br from-gray-600 to-gray-700",
        primary_button: "bg-gray-900 hover:bg-gray-800 text-white",
        secondary_button: "border border-gray-300 text-gray-700 hover:bg-gray-50"
      }

      "modern" -> %{
        background: "bg-gradient-to-br from-blue-50 to-indigo-50",
        card_bg: "bg-white/80 backdrop-blur-sm",
        heading_color: "text-gray-900",
        text_color: "text-gray-700",
        content_text: "text-gray-600",
        subtext_color: "text-blue-500",
        border_color: "border-blue-200",
        primary_color: "text-blue-600",
        primary_bg: "bg-gradient-to-r from-blue-500 to-indigo-500",
        primary_border: "border-blue-500",
        primary_hover: "from-blue-600 to-indigo-600",
        accent_bg: "bg-gradient-to-r from-blue-400 to-indigo-400",
        icon_bg: "bg-blue-50",
        hover_bg: "bg-blue-50",
        gradient_bg: "bg-gradient-to-br from-blue-400 to-indigo-500",
        primary_button: "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white",
        secondary_button: "border border-blue-300 text-blue-700 hover:bg-blue-50"
      }

      _ -> %{
        background: "bg-gray-50",
        card_bg: "bg-white",
        heading_color: "text-gray-900",
        text_color: "text-gray-700",
        content_text: "text-gray-600",
        subtext_color: "text-gray-500",
        border_color: "border-gray-200",
        primary_color: "text-blue-600",
        primary_bg: "bg-blue-600",
        primary_border: "border-blue-600",
        primary_hover: "bg-blue-700",
        accent_bg: "bg-blue-500",
        icon_bg: "bg-blue-50",
        hover_bg: "bg-gray-50",
        gradient_bg: "bg-gradient-to-br from-blue-500 to-blue-600",
        primary_button: "bg-blue-600 hover:bg-blue-700 text-white",
        secondary_button: "border border-gray-300 text-gray-700 hover:bg-gray-50"
      }
    end
  end

  defp get_layout_specific_config(layout_type) do
    case layout_type do
      "dashboard" -> %{content_spacing: "space-y-4"}
      "timeline" -> %{content_spacing: "space-y-6"}
      "magazine" -> %{content_spacing: "space-y-4"}
      "minimal" -> %{content_spacing: "space-y-8"}
      _ -> %{content_spacing: "space-y-6"}
    end
  end

  defp get_color_scheme_colors(scheme) do
    case scheme do
      "blue" -> ["#1e40af", "#3b82f6", "#60a5fa"]
      "green" -> ["#065f46", "#059669", "#34d399"]
      "purple" -> ["#581c87", "#7c3aed", "#a78bfa"]
      "red" -> ["#991b1b", "#dc2626", "#f87171"]
      "orange" -> ["#ea580c", "#f97316", "#fb923c"]
      "teal" -> ["#0f766e", "#14b8a6", "#5eead4"]
      _ -> ["#3b82f6", "#60a5fa", "#93c5fd"]
    end
  end

  # ============================================================================
  # SECTION ORGANIZATION AND UTILITIES
  # ============================================================================

  defp filter_non_empty_sections(sections) do
    Enum.filter(sections, fn section ->
      # Check if section has meaningful content
      content = section.content || %{}

      # Simple content check - you can enhance this based on your needs
      content_has_data = content
      |> Map.values()
      |> Enum.any?(fn value ->
        case value do
          str when is_binary(str) -> String.trim(str) != ""
          list when is_list(list) -> length(list) > 0
          map when is_map(map) -> map_size(map) > 0
          _ -> value != nil
        end
      end)

      content_has_data
    end)
  end

  defp organize_dashboard_sections(sections) do
    # Prioritize certain section types for primary dashboard
    primary_types = [:experience, :skills, :projects, :about]

    {primary, secondary} = Enum.split_with(sections, fn section ->
      normalize_section_type(section.section_type) in primary_types
    end)

    {Enum.take(primary, 8), secondary}
  end

  defp organize_magazine_sections(sections) do
    # Use the longest or most detailed section as featured
    featured = Enum.max_by(sections, fn section ->
      content_length = get_content_length(section)
      case section.section_type do
        :about -> content_length + 100  # Bonus for about sections
        :projects -> content_length + 50  # Bonus for projects
        _ -> content_length
      end
    end, fn -> nil end)

    regular = if featured, do: List.delete(sections, featured), else: sections

    {featured, regular}
  end

  defp sort_sections_chronologically(sections) do
    # Sort by section type priority for chronological flow
    type_priority = %{
      about: 1, education: 2, experience: 3, skills: 4,
      projects: 5, testimonials: 6, contact: 7
    }

    Enum.sort_by(sections, fn section ->
      Map.get(type_priority, normalize_section_type(section.section_type), 999)
    end)
  end

  defp normalize_section_type(section_type) do
    case section_type do
      "experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "about" -> :about
      "intro" -> :about
      "contact" -> :contact
      "testimonials" -> :testimonials
      atom when is_atom(atom) -> atom
      _ -> :other
    end
  end

  # ============================================================================
  # CONTENT HELPERS
  # ============================================================================

  defp get_section_preview(section, max_length) do
    content = section.content || %{}

    # Try to find meaningful preview text
    preview_text = case normalize_section_type(section.section_type) do
      :experience ->
        jobs = Map.get(content, "jobs", [])
        if length(jobs) > 0 do
          first_job = List.first(jobs)
          role = Map.get(first_job, "role", Map.get(first_job, "title", ""))
          company = Map.get(first_job, "company", "")
          "#{role} at #{company}"
        else
          Map.get(content, "summary", "")
        end

      :education ->
        education = Map.get(content, "education", [])
        if length(education) > 0 do
          first_edu = List.first(education)
          degree = Map.get(first_edu, "degree", "")
          institution = Map.get(first_edu, "institution", "")
          "#{degree} from #{institution}"
        else
          "Educational background and qualifications"
        end

      :skills ->
        skills = Map.get(content, "skills", [])
        if length(skills) > 0 do
          skill_count = length(skills)
          sample_skills = skills |> Enum.take(3) |> Enum.join(", ")
          "#{skill_count} skills including #{sample_skills}"
        else
          "Technical skills and expertise"
        end

      _ ->
        # Try common content fields
        Enum.find_value(["summary", "description", "bio", "content", "text"], fn field ->
          value = Map.get(content, field, "")
          if String.trim(value) != "", do: value, else: nil
        end) || "View section content"
    end

    # Clean and truncate
    preview_text
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
    |> truncate_text(max_length)
  end

  defp get_section_icon(section_type) do
    case normalize_section_type(section_type) do
      :experience -> "💼"
      :education -> "🎓"
      :skills -> "⚡"
      :projects -> "🚀"
      :about -> "👤"
      :contact -> "📧"
      :testimonials -> "💬"
      _ -> "📄"
    end
  end

  defp get_section_type_label(section_type) do
    case normalize_section_type(section_type) do
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :projects -> "Projects"
      :about -> "About Me"
      :contact -> "Contact Information"
      :testimonials -> "Testimonials"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_content_length_indicator(section) do
    length = get_content_length(section)
    cond do
      length > 500 -> "Detailed"
      length > 200 -> "Medium"
      length > 50 -> "Brief"
      true -> "Short"
    end
  end

  defp get_content_length(section) do
    content = section.content || %{}

    content
    |> Map.values()
    |> Enum.map(fn value ->
      case value do
        str when is_binary(str) -> String.length(str)
        list when is_list(list) -> length(list) * 50
        map when is_map(map) -> map_size(map) * 30
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp get_section_date(section) do
    content = section.content || %{}

    # Try to extract date from content
    case normalize_section_type(section.section_type) do
      :experience ->
        jobs = Map.get(content, "jobs", [])
        if length(jobs) > 0 do
          first_job = List.first(jobs)
          Map.get(first_job, "start_date", "Recent")
        else
          "Recent"
        end

      :education ->
        education = Map.get(content, "education", [])
        if length(education) > 0 do
          first_edu = List.first(education)
          Map.get(first_edu, "graduation_date", "Recent")
        else
          "Recent"
        end

      _ -> "Recent"
    end
  end

  defp calculate_completion_percentage(sections) do
    if length(sections) == 0 do
      0
    else
      completed_sections = Enum.count(sections, fn section ->
        get_content_length(section) > 100
      end)

      round(completed_sections / length(sections) * 100)
    end
  end

  defp calculate_section_progress(section, index) do
    base_progress = 60
    content_bonus = min(get_content_length(section) / 10, 30)
    index_bonus = min(index * 2, 10)

    round(base_progress + content_bonus + index_bonus)
  end

  defp calculate_read_time(section) do
    words = get_content_length(section) / 5  # Rough word count
    max(round(words / 200), 1)  # 200 words per minute, minimum 1 minute
  end

  defp render_section_visual(section, config) do
    # Create visual representation based on section type
    case normalize_section_type(section.section_type) do
      :experience ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-4xl text-white/80">💼</div>
        </div>
        """

      :skills ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="grid grid-cols-3 gap-2">
            <div class="w-4 h-4 bg-white/60 rounded"></div>
            <div class="w-4 h-4 bg-white/80 rounded"></div>
            <div class="w-4 h-4 bg-white/60 rounded"></div>
            <div class="w-4 h-4 bg-white/80 rounded"></div>
            <div class="w-4 h-4 bg-white/90 rounded"></div>
            <div class="w-4 h-4 bg-white/70 rounded"></div>
          </div>
        </div>
        """

      :projects ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-4xl text-white/80">🚀</div>
        </div>
        """

      _ ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-4xl text-white/80">#{get_section_icon(section.section_type)}</div>
        </div>
        """
    end
  end

  defp format_current_date do
    case Date.utc_today() do
      %Date{month: month, year: year} ->
        month_name = case month do
          1 -> "January"; 2 -> "February"; 3 -> "March"; 4 -> "April"
          5 -> "May"; 6 -> "June"; 7 -> "July"; 8 -> "August"
          9 -> "September"; 10 -> "October"; 11 -> "November"; 12 -> "December"
        end
        "#{month_name} #{year}"
      _ -> "2025"
    end
  end

  defp truncate_text(text, max_length) when is_binary(text) do
    if String.length(text) <= max_length do
      text
    else
      text
      |> String.slice(0, max_length - 3)
      |> String.trim()
      |> Kernel.<>("...")
    end
  end

  defp truncate_text(text, _max_length), do: to_string(text)
end
