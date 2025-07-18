# File: lib/frestyl_web/live/portfolio_live/components/enhanced_layout_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer do
  @moduledoc """
  PATCH 4: Enhanced layout rendering system with superior designs from temp_show.ex.
  Supports: Standard, Dashboard, Masonry Grid, Timeline, Magazine, and Minimal layouts
  with improved visual hierarchy, interactions, and professional styling.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.EnhancedContentRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedHeroRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedSectionCards
  alias FrestylWeb.PortfolioLive.Components.ThemeConsistencyManager

  # ============================================================================
  # MAIN LAYOUT RENDERER
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme) do
    # Filter out empty sections
    filtered_sections = filter_non_empty_sections(sections)

    # Get enhanced layout configuration with theme consistency
    layout_config = get_enhanced_layout_config(layout_type, theme, color_scheme)

    # Render based on layout type with enhanced designs
    case normalize_layout_type(layout_type) do
      :standard -> render_enhanced_standard_layout(portfolio, filtered_sections, layout_config)
      :dashboard -> render_enhanced_dashboard_layout(portfolio, filtered_sections, layout_config)
      :grid -> render_enhanced_masonry_grid_layout(portfolio, filtered_sections, layout_config)
      :timeline -> render_enhanced_timeline_layout(portfolio, filtered_sections, layout_config)
      :magazine -> render_enhanced_magazine_layout(portfolio, filtered_sections, layout_config)
      :minimal -> render_enhanced_minimal_layout(portfolio, filtered_sections, layout_config)
      _ -> render_enhanced_standard_layout(portfolio, filtered_sections, layout_config)
    end
  end

  # ============================================================================
  # ENHANCED STANDARD LAYOUT - Premium Single-Column Design
  # ============================================================================

defp render_enhanced_standard_layout(portfolio, sections, config) do
  social_links = extract_social_links_from_portfolio(portfolio)

  """
  <div class="portfolio-layout standard-layout #{config.background} min-h-screen">
    <!-- Enhanced Hero Section -->
    #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

    <!-- Main Content with Enhanced Typography -->
    <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
      <!-- Portfolio Introduction -->
      <div class="text-center mb-16">
        <h2 class="text-3xl font-bold #{config.heading_color} mb-4">About & Experience</h2>
        <div class="w-24 h-1 #{config.accent_bg} mx-auto rounded-full mb-6"></div>
        <p class="text-lg #{config.content_text} max-w-2xl mx-auto leading-relaxed">
          Learn more about my background, experience, and expertise
        </p>
      </div>

      <!-- Enhanced Sections Grid -->
      <div class="space-y-12">
        #{render_enhanced_standard_sections(sections, config)}
      </div>

      <!-- Enhanced Call to Action -->
      <div class="text-center mt-20 py-16 bg-gradient-to-r #{config.cta_gradient} rounded-2xl">
        <h3 class="text-2xl font-bold text-white mb-4">Ready to Work Together?</h3>
        <p class="text-white/90 mb-8 max-w-2xl mx-auto">
          Let's discuss your project and see how I can help bring your vision to life.
        </p>
        <div class="flex flex-col sm:flex-row gap-4 justify-center">
          <button class="px-8 py-4 bg-white #{config.primary_color} rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
            Start a Project
          </button>
          <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:#{config.primary_color} transition-all duration-300">
            View Resume
          </button>
        </div>
      </div>
    </main>

    <!-- Enhanced Floating Navigation -->
    #{render_enhanced_floating_navigation(sections, "standard", config)}

    <!-- Enhanced Footer -->
    #{render_enhanced_footer_actions(config, social_links)}

    <!-- Enhanced JavaScript -->
    #{render_enhanced_javascript()}
  </div>
  """
end

  # ============================================================================
  # ENHANCED MAGAZINE LAYOUT - Editorial Excellence
  # ============================================================================

  defp render_enhanced_magazine_layout(portfolio, sections, config) do
    {featured_section, regular_sections} = organize_magazine_sections(sections)

    """
    <div class="portfolio-layout magazine-layout #{config.background} min-h-screen">
      <!-- Enhanced Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Enhanced Magazine Header -->
      <header class="magazine-header py-16 bg-white">
        <div class="max-w-7xl mx-auto px-6">
          <div class="flex items-end justify-between border-b-4 #{config.primary_border} pb-6 mb-12">
            <div>
              <h1 class="text-6xl font-bold #{config.heading_color} mb-3">#{portfolio.title}</h1>
              <p class="text-xl #{config.subtext_color}">Professional Portfolio • #{format_current_date()}</p>
            </div>
            <div class="magazine-issue text-right hidden md:block">
              <div class="text-4xl font-bold #{config.primary_color}">Issue #1</div>
              <div class="text-lg #{config.subtext_color}">#{length(sections)} Articles</div>
            </div>
          </div>

          <!-- Enhanced Magazine Stats -->
          <div class="grid grid-cols-2 md:grid-cols-4 gap-6">
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-2xl font-bold #{config.primary_color}">#{length(sections)}</div>
              <div class="text-sm #{config.subtext_color}">Articles</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-2xl font-bold #{config.primary_color}">#{calculate_total_read_time(sections)}</div>
              <div class="text-sm #{config.subtext_color}">Min Read</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-2xl font-bold #{config.primary_color}">100%</div>
              <div class="text-sm #{config.subtext_color}">Professional</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-2xl font-bold #{config.primary_color}">Latest</div>
              <div class="text-sm #{config.subtext_color}">Edition</div>
            </div>
          </div>
        </div>
      </header>

      <!-- Enhanced Magazine Content -->
      <main class="max-w-7xl mx-auto px-6 py-12">
        #{if featured_section do
          """
          <!-- Enhanced Featured Article -->
          <div class="featured-article mb-20">
            #{render_enhanced_featured_magazine_article(featured_section, config)}
          </div>
          """
        else
          ""
        end}

        <!-- Enhanced Regular Articles Grid -->
        <div class="magazine-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          #{render_enhanced_magazine_articles(regular_sections, config)}
        </div>
      </main>

      <!-- Enhanced Floating Navigation -->
      #{render_enhanced_floating_navigation(sections, "magazine", config)}

      <!-- Enhanced Footer -->
      #{render_enhanced_footer_actions(config, extract_social_links_from_portfolio(portfolio))}

      <!-- Enhanced JavaScript -->
      #{render_enhanced_javascript()}
    </div>
    """
  end

  defp render_enhanced_featured_magazine_article(section, config) do
    """
    <article id="section-#{section.id}"
             class="featured-magazine-article bg-white rounded-2xl overflow-hidden shadow-2xl hover:shadow-3xl transition-all duration-500 cursor-pointer group"
             onclick="openSectionModal('#{section.id}')"
             data-section-id="#{section.id}">

      <div class="grid lg:grid-cols-2 gap-0">
        <!-- Enhanced Article Visual -->
        <div class="article-visual relative h-80 lg:h-auto overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-br #{config.featured_gradient}"></div>
          #{render_enhanced_section_visual(section, config)}
          <div class="absolute inset-0 bg-gradient-to-r from-black/50 to-transparent"></div>

          <!-- Enhanced Featured Badge -->
          <div class="absolute top-6 left-6">
            <span class="featured-badge px-4 py-2 #{config.accent_bg} text-white rounded-full text-sm font-bold shadow-lg">
              ⭐ Featured Article
            </span>
          </div>

          <!-- Enhanced Category Badge -->
          <div class="absolute bottom-6 left-6">
            <span class="category-badge px-3 py-1 bg-white/90 backdrop-blur-sm #{config.primary_color} text-xs font-bold rounded-full">
              #{get_section_type_label(section.section_type)}
            </span>
          </div>
        </div>

        <!-- Enhanced Article Content -->
        <div class="article-content p-8 lg:p-12 flex flex-col justify-center bg-gradient-to-br from-white to-gray-50">
          <div class="article-meta mb-6">
            <div class="flex items-center space-x-4 text-sm #{config.subtext_color} mb-4">
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                #{calculate_read_time(section)} min read
              </span>
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 7h.01M7 3h5c.512 0 1.024.195 1.414.586l7 7a2 2 0 010 2.828l-7 7a2 2 0 01-2.828 0l-7-7A1.994 1.994 0 013 12V7a4 4 0 014-4z"/>
                </svg>
                #{get_content_length_indicator(section)}
              </span>
            </div>
          </div>

          <h2 class="article-title text-4xl font-bold #{config.heading_color} mb-6 leading-tight">#{section.title}</h2>

          <div class="article-excerpt #{config.content_text} leading-relaxed mb-8 text-lg">
            <p>#{get_enhanced_section_preview(section, 300)}</p>
          </div>

          <div class="article-footer flex items-center justify-between">
            <div class="article-stats flex items-center space-x-6 text-sm #{config.subtext_color}">
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
                Premium Content
              </span>
            </div>
            <button class="read-more #{config.primary_bg} text-white px-6 py-3 rounded-xl font-semibold hover:#{config.primary_hover} transition-all duration-300 transform hover:scale-105 group-hover:scale-105">
              Read Full Article
            </button>
          </div>
        </div>
      </div>
    </article>
    """
  end

  defp render_enhanced_magazine_articles(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      animation_delay = index * 150

      """
      <article id="section-#{section.id}"
               class="magazine-article bg-white rounded-2xl overflow-hidden shadow-lg hover:shadow-2xl transition-all duration-500 cursor-pointer group transform hover:-translate-y-2"
               style="animation-delay: #{animation_delay}ms;"
               onclick="openSectionModal('#{section.id}')"
               data-section-id="#{section.id}">

        <!-- Enhanced Article Visual -->
        <div class="article-visual relative h-48 overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-br #{config.article_gradient}"></div>
          #{render_enhanced_section_visual(section, config)}
          <div class="absolute inset-0 bg-gradient-to-t from-black/60 to-transparent"></div>

          <!-- Enhanced Category Badge -->
          <div class="absolute bottom-4 left-4 right-4">
            <span class="category text-white/90 text-xs font-bold uppercase tracking-wide">
              #{get_section_type_label(section.section_type)}
            </span>
          </div>

          <!-- Enhanced Read Time Badge -->
          <div class="absolute top-4 right-4">
            <span class="px-2 py-1 bg-white/20 backdrop-blur-sm text-white text-xs font-medium rounded-full">
              #{calculate_read_time(section)}m
            </span>
          </div>
        </div>

        <!-- Enhanced Article Content -->
        <div class="article-content p-6">
          <h3 class="article-title text-xl font-bold #{config.heading_color} mb-3 group-hover:#{config.primary_color} transition-colors leading-tight">
            #{section.title}
          </h3>

          <div class="article-excerpt #{config.content_text} text-sm leading-relaxed mb-4 max-h-16 overflow-hidden">
            <p>#{get_enhanced_section_preview(section, 120)}</p>
          </div>

          <div class="article-footer flex items-center justify-between text-xs #{config.subtext_color}">
            <div class="flex items-center space-x-3">
              <span class="flex items-center">
                <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
                #{get_content_length_indicator(section)}
              </span>
            </div>
            <button class="read-more text-xs font-medium #{config.accent_color} hover:#{config.primary_color} transition-colors opacity-0 group-hover:opacity-100">
              Read Article &rarr;
            </button>
          </div>
        </div>
      </article>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # ENHANCED MINIMAL LAYOUT - Ultra-Clean Sophistication
  # ============================================================================

  defp render_enhanced_minimal_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout minimal-layout #{config.background} min-h-screen">
      <!-- Enhanced Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Enhanced Minimal Content -->
      <main class="max-w-3xl mx-auto px-4 sm:px-6 lg:px-8 py-20">
        <!-- Enhanced Minimal Header -->
        <div class="text-center mb-20">
          <h1 class="text-4xl font-light #{config.heading_color} mb-6">Portfolio Overview</h1>
          <div class="w-16 h-px #{config.primary_bg} mx-auto mb-8"></div>
          <p class="text-lg #{config.content_text} font-light leading-loose max-w-2xl mx-auto">
            A carefully curated selection of my professional work, experience, and creative endeavors
          </p>
        </div>

        <!-- Enhanced Minimal Sections -->
        <div class="minimal-sections space-y-32">
          #{render_enhanced_minimal_sections(sections, config)}
        </div>

        <!-- Enhanced Minimal Footer -->
        <div class="text-center mt-32 pt-16 border-t border-gray-100">
          <p class="text-sm #{config.subtext_color} font-light mb-8">
            Thank you for exploring my portfolio
          </p>
          <div class="flex justify-center space-x-8">
            <button class="px-6 py-3 #{config.primary_bg} text-white rounded font-medium hover:#{config.primary_hover} transition-colors">
              Get In Touch
            </button>
            <button class="px-6 py-3 border border-gray-300 #{config.text_color} rounded font-medium hover:bg-gray-50 transition-colors">
              Download Resume
            </button>
          </div>
        </div>
      </main>

      <!-- Enhanced Floating Navigation -->
      #{render_enhanced_floating_navigation(sections, "minimal", config)}

      <!-- Enhanced JavaScript -->
      #{render_enhanced_javascript()}
    </div>
    """
  end

  defp render_enhanced_minimal_sections(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      animation_delay = index * 300

      """
      <section id="section-#{section.id}"
               class="minimal-section cursor-pointer group"
               style="animation-delay: #{animation_delay}ms;"
               onclick="openSectionModal('#{section.id}')"
               data-section-id="#{section.id}">

        <!-- Enhanced Section Header -->
        <header class="section-header text-center mb-12">
          <div class="inline-flex items-center space-x-3 mb-6">
            <div class="w-8 h-8 #{config.icon_bg} rounded-full flex items-center justify-center">
              #{get_enhanced_section_icon(section.section_type, config.primary_color)}
            </div>
            <span class="text-xs font-medium #{config.subtext_color} uppercase tracking-wider">
              #{get_section_type_label(section.section_type)}
            </span>
          </div>
          <h2 class="text-3xl font-light #{config.heading_color} mb-6">#{section.title}</h2>
          <div class="section-divider w-12 h-px #{config.primary_bg} mx-auto opacity-60"></div>
        </header>

        <!-- Enhanced Section Content -->
        <div class="section-content max-w-2xl mx-auto">
          <div class="content-preview text-center #{config.content_text} leading-loose text-lg max-h-24 overflow-hidden mb-8">
            #{get_enhanced_section_preview(section, 200)}
          </div>

          <!-- Enhanced Metrics -->
          <div class="metrics-bar flex justify-center items-center space-x-8 text-sm #{config.subtext_color} mb-8">
            <span class="flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
              </svg>
              #{get_content_length_indicator(section)}
            </span>
            <span class="flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              #{calculate_read_time(section)} min read
            </span>
          </div>

          <!-- Enhanced Expand Hint -->
          <div class="expand-hint text-center opacity-0 group-hover:opacity-100 transition-all duration-500">
            <button class="expand-btn text-sm #{config.primary_color} hover:#{config.primary_hover} font-medium">
              Explore This Section
            </button>
          </div>
        </div>
      </section>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # ENHANCED SHARED COMPONENTS
  # ============================================================================

  defp render_enhanced_floating_navigation(sections, layout_type, config) do
    nav_items = sections
    |> Enum.map(fn section ->
      """
      <a href="#section-#{section.id}"
         class="nav-item group flex items-center p-3 #{config.nav_item_bg} hover:#{config.nav_item_hover} rounded-xl transition-all duration-300 transform hover:scale-105"
         title="#{section.title}">
        <div class="flex items-center space-x-3">
          <div class="nav-icon w-8 h-8 #{config.nav_icon_bg} rounded-lg flex items-center justify-center group-hover:#{config.nav_icon_hover} transition-colors">
            #{get_enhanced_section_icon(section.section_type, "w-4 h-4")}
          </div>
          <div class="nav-content">
            <div class="nav-label text-sm font-medium #{config.nav_text} truncate max-w-32">#{section.title}</div>
            <div class="nav-type text-xs #{config.nav_subtext} opacity-75">#{get_section_type_label(section.section_type)}</div>
          </div>
        </div>
      </a>
      """
    end)
    |> Enum.join("\n")

    """
    <nav class="floating-navigation fixed right-6 top-1/2 transform -translate-y-1/2 bg-white/90 backdrop-blur-lg rounded-2xl shadow-2xl border #{config.border_color} p-3 hidden lg:block z-50 max-w-64">
      <div class="nav-header text-center mb-3 pb-3 border-b #{config.border_color}">
        <h4 class="text-sm font-semibold #{config.heading_color}">Navigation</h4>
      </div>
      <div class="nav-items space-y-2 max-h-80 overflow-y-auto">
        #{nav_items}
      </div>
    </nav>
    """
  end

  defp render_enhanced_footer_actions(config, social_links) do
    """
    <footer class="portfolio-footer bg-gradient-to-r from-white to-gray-50 border-t #{config.border_color} py-12 mt-20">
      <div class="max-w-6xl mx-auto px-6">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mb-8">

          <!-- Enhanced Quick Actions -->
          <div class="footer-section">
            <h4 class="text-lg font-semibold #{config.heading_color} mb-4">Quick Actions</h4>
            <div class="space-y-3">
              <button class="footer-action w-full text-left p-3 #{config.footer_item_bg} hover:#{config.footer_item_hover} rounded-xl transition-all duration-300 flex items-center space-x-3">
                <svg class="w-5 h-5 #{config.primary_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
                <span class="font-medium">Download Resume</span>
              </button>
              <button class="footer-action w-full text-left p-3 #{config.footer_item_bg} hover:#{config.footer_item_hover} rounded-xl transition-all duration-300 flex items-center space-x-3">
                <svg class="w-5 h-5 #{config.primary_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6l6.632-3.316m0 0a3 3 0 105.367-2.684 3 3 0 11-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 11-5.368-2.684z"/>
                </svg>
                <span class="font-medium">Share Portfolio</span>
              </button>
              <button class="footer-action w-full text-left p-3 #{config.footer_item_bg} hover:#{config.footer_item_hover} rounded-xl transition-all duration-300 flex items-center space-x-3">
                <svg class="w-5 h-5 #{config.primary_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
                <span class="font-medium">Contact Me</span>
              </button>
            </div>
          </div>

          <!-- Enhanced Social Links -->
          #{if length(social_links) > 0 do
            """
            <div class="footer-section">
              <h4 class="text-lg font-semibold #{config.heading_color} mb-4">Connect</h4>
              <div class="grid grid-cols-2 gap-3">
                #{render_enhanced_social_footer_links(social_links, config)}
              </div>
            </div>
            """
          else
            """
            <div class="footer-section">
              <h4 class="text-lg font-semibold #{config.heading_color} mb-4">Portfolio Stats</h4>
              <div class="space-y-2 text-sm #{config.content_text}">
                <div class="flex justify-between">
                  <span>Sections</span>
                  <span class="font-medium">Professional</span>
                </div>
                <div class="flex justify-between">
                  <span>Updated</span>
                  <span class="font-medium">Recently</span>
                </div>
                <div class="flex justify-between">
                  <span>Status</span>
                  <span class="text-green-600 font-medium">Active</span>
                </div>
              </div>
            </div>
            """
          end}

          <!-- Enhanced Portfolio Info -->
          <div class="footer-section">
            <h4 class="text-lg font-semibold #{config.heading_color} mb-4">Portfolio Info</h4>
            <div class="space-y-2 text-sm #{config.content_text}">
              <div class="flex justify-between">
                <span>Last Updated</span>
                <span class="font-medium">#{format_current_date()}</span>
              </div>
              <div class="flex justify-between">
                <span>Version</span>
                <span class="font-medium">2024.1</span>
              </div>
              <div class="flex justify-between">
                <span>Status</span>
                <span class="text-green-600 font-medium">Live</span>
              </div>
            </div>
          </div>
        </div>

        <!-- Enhanced Return to Top -->
        <div class="text-center pt-8 border-t #{config.border_color}">
          <button id="return-to-top"
                  class="return-to-top #{config.primary_bg} hover:#{config.primary_hover} text-white p-4 rounded-full shadow-lg hover:shadow-xl transition-all duration-300 transform hover:scale-110"
                  onclick="window.scrollTo({top: 0, behavior: 'smooth'})">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
            </svg>
          </button>
          <p class="text-sm #{config.subtext_color} mt-4">© 2024 Professional Portfolio. All rights reserved.</p>
        </div>
      </div>
    </footer>
    """
  end

  defp render_enhanced_social_footer_links(social_links, config) do
    social_links
    |> Enum.map(fn {platform, url} ->
      icon = get_social_icon_enhanced(platform)
      platform_name = format_platform_name(platform)

      """
      <a href="#{url}" target="_blank" rel="noopener noreferrer"
         class="social-link flex items-center p-3 #{config.social_bg} hover:#{config.social_hover} rounded-xl transition-all duration-300 transform hover:scale-105"
         title="#{platform_name}">
        <div class="flex items-center space-x-2">
          #{icon}
          <span class="text-sm font-medium">#{platform_name}</span>
        </div>
      </a>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # ENHANCED JAVASCRIPT AND INTERACTIONS
  # ============================================================================

  defp render_enhanced_javascript() do
    """
    <script>
      // Enhanced Portfolio JavaScript with Modal System
      document.addEventListener('DOMContentLoaded', function() {
        console.log('🎨 Enhanced Portfolio Layout Loaded');

        // Initialize enhanced animations
        initializeEnhancedAnimations();

        // Initialize scroll effects
        initializeScrollEffects();

        // Initialize interactive elements
        initializeInteractiveElements();

        // Initialize modal system
        initializeModalSystem();

        // Initialize floating navigation
        initializeFloatingNavigation();
      });

      // Enhanced Animation System
      function initializeEnhancedAnimations() {
        const observerOptions = {
          threshold: 0.1,
          rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              entry.target.classList.add('animate-fade-in-up');
              entry.target.style.opacity = '1';
              entry.target.style.transform = 'translateY(0)';
            }
          });
        }, observerOptions);

        // Observe all enhanced cards
        document.querySelectorAll('.enhanced-section-card, .enhanced-dashboard-card, .masonry-card, .timeline-card, .magazine-article, .minimal-section').forEach(card => {
          card.style.opacity = '0';
          card.style.transform = 'translateY(20px)';
          card.style.transition = 'all 0.6s ease-out';
          observer.observe(card);
        });
      }

      // Enhanced Scroll Effects
      function initializeScrollEffects() {
        let ticking = false;

        function updateScrollEffects() {
          const scrolled = window.pageYOffset;
          const parallaxElements = document.querySelectorAll('.parallax-element');

          parallaxElements.forEach(element => {
            const speed = element.dataset.speed || 0.5;
            element.style.transform = `translateY(${scrolled * speed}px)`;
          });

          // Update floating navigation visibility
          const floatingNav = document.querySelector('.floating-navigation');
          if (floatingNav) {
            if (scrolled > 400) {
              floatingNav.style.opacity = '1';
              floatingNav.style.pointerEvents = 'auto';
            } else {
              floatingNav.style.opacity = '0.7';
              floatingNav.style.pointerEvents = 'none';
            }
          }

          // Update return to top button
          const returnToTop = document.getElementById('return-to-top');
          if (returnToTop) {
            if (scrolled > 400) {
              returnToTop.style.opacity = '1';
              returnToTop.style.transform = 'scale(1)';
            } else {
              returnToTop.style.opacity = '0';
              returnToTop.style.transform = 'scale(0.8)';
            }
          }

          ticking = false;
        }

        window.addEventListener('scroll', function() {
          if (!ticking) {
            requestAnimationFrame(updateScrollEffects);
            ticking = true;
          }
        });
      }

      // Enhanced Interactive Elements
      function initializeInteractiveElements() {
        // Enhanced card hover effects
        document.querySelectorAll('.enhanced-section-card, .enhanced-dashboard-card, .masonry-card, .timeline-card, .magazine-article').forEach(card => {
          card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-8px) scale(1.02)';
            this.style.boxShadow = '0 25px 50px -12px rgba(0, 0, 0, 0.25)';
          });

          card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0) scale(1)';
            this.style.boxShadow = '';
          });
        });

        // Enhanced button interactions
        document.querySelectorAll('button:not(.no-enhance)').forEach(button => {
          button.addEventListener('click', function(e) {
            // Create ripple effect
            const ripple = document.createElement('span');
            const rect = this.getBoundingClientRect();
            const size = Math.max(rect.width, rect.height);
            const x = e.clientX - rect.left - size / 2;
            const y = e.clientY - rect.top - size / 2;

            ripple.style.width = ripple.style.height = size + 'px';
            ripple.style.left = x + 'px';
            ripple.style.top = y + 'px';
            ripple.classList.add('ripple');

            this.appendChild(ripple);

            setTimeout(() => {
              ripple.remove();
            }, 600);
          });
        });

        // Enhanced filter functionality for masonry
        document.querySelectorAll('.filter-btn').forEach(btn => {
          btn.addEventListener('click', function() {
            const filter = this.dataset.filter;

            // Update active button
            document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
            this.classList.add('active');

            // Filter items
            const items = document.querySelectorAll('.masonry-item');
            items.forEach(item => {
              if (filter === 'all' || item.classList.contains(`filter-${filter}`)) {
                item.style.display = 'block';
                item.style.opacity = '1';
                item.style.transform = 'scale(1)';
              } else {
                item.style.opacity = '0';
                item.style.transform = 'scale(0.8)';
                setTimeout(() => {
                  item.style.display = 'none';
                }, 300);
              }
            });
          });
        });
      }

      // Enhanced Modal System
      function initializeModalSystem() {
        window.openSectionModal = function(sectionId) {
          console.log('🔍 Opening enhanced modal for section:', sectionId);

          // Create enhanced modal backdrop
          const backdrop = document.createElement('div');
          backdrop.className = 'fixed inset-0 bg-black bg-opacity-75 backdrop-blur-sm flex items-center justify-center z-50 p-4';
          backdrop.id = `section-modal-${sectionId}`;

          // Enhanced modal content
          const modal = document.createElement('div');
          modal.className = 'bg-white rounded-2xl shadow-3xl max-w-4xl w-full max-h-[90vh] overflow-hidden transform transition-all duration-300';
          modal.style.transform = 'scale(0.9) translateY(20px)';
          modal.style.opacity = '0';

          modal.innerHTML = `
            <div class="flex items-center justify-between p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-indigo-50">
              <div>
                <h2 class="text-2xl font-bold text-gray-900">Section Details</h2>
                <p class="text-sm text-gray-600 mt-1">Detailed view of portfolio section</p>
              </div>
              <button onclick="closeSectionModal('${sectionId}')"
                      class="w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors group">
                <svg class="w-5 h-5 text-gray-600 group-hover:text-gray-800" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>
            <div class="p-6 overflow-y-auto max-h-[70vh]">
              <div class="prose prose-lg max-w-none">
                <div class="flex items-center space-x-4 mb-6">
                  <div class="w-12 h-12 bg-blue-500 rounded-xl flex items-center justify-center">
                    <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                  </div>
                  <div>
                    <h3 class="text-xl font-semibold text-gray-900 m-0">Enhanced Section View</h3>
                    <p class="text-gray-600 m-0">Detailed content would be loaded here</p>
                  </div>
                </div>
                <p class="text-gray-700 leading-relaxed">
                  This is an enhanced modal view that would display the full section content with rich formatting,
                  media elements, and interactive features. The content would be dynamically loaded based on the
                  section type and provide an immersive reading experience.
                </p>
                <div class="mt-6 p-4 bg-blue-50 rounded-xl">
                  <h4 class="text-lg font-semibold text-blue-900 mb-2">Interactive Features</h4>
                  <ul class="text-blue-800 space-y-1">
                    <li>• Enhanced typography and formatting</li>
                    <li>• Media gallery integration</li>
                    <li>• Social sharing capabilities</li>
                    <li>• Print and export options</li>
                  </ul>
                </div>
              </div>
            </div>
            <div class="p-6 border-t border-gray-200 bg-gray-50 flex justify-between items-center">
              <div class="flex items-center space-x-4 text-sm text-gray-600">
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  5 min read
                </span>
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  </svg>
                  Professional content
                </span>
              </div>
              <div class="flex space-x-3">
                <button class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                  Share
                </button>
                <button onclick="closeSectionModal('${sectionId}')"
                        class="px-4 py-2 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300 transition-colors">
                  Close
                </button>
              </div>
            </div>
          `;

          backdrop.appendChild(modal);
          document.body.appendChild(backdrop);

          // Enhanced modal animations
          setTimeout(() => {
            backdrop.style.opacity = '1';
            modal.style.transform = 'scale(1) translateY(0)';
            modal.style.opacity = '1';
          }, 10);

          // Enhanced click outside to close
          backdrop.addEventListener('click', function(e) {
            if (e.target === backdrop) {
              closeSectionModal(sectionId);
            }
          });

          // Enhanced keyboard navigation
          document.addEventListener('keydown', function escapeHandler(e) {
            if (e.key === 'Escape') {
              closeSectionModal(sectionId);
              document.removeEventListener('keydown', escapeHandler);
            }
          });
        };

        window.closeSectionModal = function(sectionId) {
          const modal = document.getElementById(`section-modal-${sectionId}`);
          if (modal) {
            const modalContent = modal.querySelector('.bg-white');
            modalContent.style.transform = 'scale(0.9) translateY(20px)';
            modalContent.style.opacity = '0';
            modal.style.opacity = '0';

            setTimeout(() => {
              modal.remove();
            }, 300);
          }
        };
      }

      // Enhanced Floating Navigation
      function initializeFloatingNavigation() {
        const navLinks = document.querySelectorAll('.floating-navigation a[href^="#"]');

        navLinks.forEach(link => {
          link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const target = document.getElementById(targetId);

            if (target) {
              // Enhanced smooth scroll with offset
              const yOffset = -80;
              const y = target.getBoundingClientRect().top + window.pageYOffset + yOffset;

              window.scrollTo({
                top: y,
                behavior: 'smooth'
              });

              // Add visual feedback
              this.style.transform = 'scale(0.95)';
              setTimeout(() => {
                this.style.transform = 'scale(1)';
              }, 150);
            }
          });
        });

        // Enhanced active section highlighting
        const sections = document.querySelectorAll('[id^="section-"]');
        const observerOptions = {
          threshold: 0.3,
          rootMargin: '-80px 0px -80px 0px'
        };

        const sectionObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            const navLink = document.querySelector(`.floating-navigation a[href="#${entry.target.id}"]`);
            if (navLink) {
              if (entry.isIntersecting) {
                navLink.classList.add('active-section');
                navLink.style.backgroundColor = 'rgb(59 130 246 / 0.1)';
                navLink.style.borderColor = 'rgb(59 130 246)';
              } else {
                navLink.classList.remove('active-section');
                navLink.style.backgroundColor = '';
                navLink.style.borderColor = '';
              }
            }
          });
        }, observerOptions);

        sections.forEach(section => sectionObserver.observe(section));
      }

      // Enhanced ripple effect styles
      const style = document.createElement('style');
      style.textContent = `
        .ripple {
          position: absolute !important;
          border-radius: 50% !important;
          background: rgba(255, 255, 255, 0.3) !important;
          transform: scale(0) !important;
          animation: ripple-animation 0.6s linear !important;
          pointer-events: none !important;
        }

        @keyframes ripple-animation {
          to {
            transform: scale(2);
            opacity: 0;
          }
        }

        .animate-fade-in-up {
          animation: fade-in-up 0.6s ease-out forwards;
        }

        @keyframes fade-in-up {
          from {
            opacity: 0;
            transform: translateY(20px);
          }
          to {
            opacity: 1;
            transform: translateY(0);
          }
        }

        .line-clamp-4 {
          display: -webkit-box;
          -webkit-line-clamp: 4;
          -webkit-box-orient: vertical;
          overflow: hidden;
        }

        .shadow-3xl {
          box-shadow: 0 35px 60px -12px rgba(0, 0, 0, 0.3);
        }
      `;
      document.head.appendChild(style);
    </script>
    """
  end

  defp render_enhanced_masonry_javascript() do
    """
    <!-- Enhanced Masonry JavaScript -->
    <script src="https://unpkg.com/masonry-layout@4/dist/masonry.pkgd.min.js"></script>
    <script>
      document.addEventListener('DOMContentLoaded', function() {
        // Initialize enhanced masonry
        const masonryContainer = document.querySelector('.masonry-container');
        if (masonryContainer) {
          const masonry = new Masonry(masonryContainer, {
            itemSelector: '.masonry-item',
            columnWidth: '.masonry-sizer',
            percentPosition: true,
            gutter: 24,
            transitionDuration: '0.4s'
          });

          // Enhanced masonry animations
          masonry.on('layoutComplete', function() {
            console.log('🎯 Enhanced masonry layout complete');
          });

          // Enhanced filter integration
          window.filterMasonryItems = function(filter) {
            const items = document.querySelectorAll('.masonry-item');

            items.forEach(item => {
              if (filter === 'all' || item.classList.contains(`filter-${filter}`)) {
                item.style.display = 'block';
              } else {
                item.style.display = 'none';
              }
            });

            // Re-layout masonry after filtering
            setTimeout(() => {
              masonry.layout();
            }, 100);
          };
        }
      });
    </script>
    """
  end

  # ============================================================================
  # ENHANCED UTILITY FUNCTIONS
  # ============================================================================

  defp get_enhanced_layout_config(layout_type, theme, color_scheme) do
    base_config = %{
      color_scheme: color_scheme,
      theme: theme
    }

    theme_colors = get_enhanced_theme_colors(theme, color_scheme)
    layout_specific = get_enhanced_layout_specific_config(layout_type)

    Map.merge(base_config, Map.merge(theme_colors, layout_specific))
  end

  defp get_enhanced_theme_colors(theme, color_scheme) do
    scheme_colors = get_color_scheme_colors(color_scheme)
    primary = Enum.at(scheme_colors, 0)
    secondary = Enum.at(scheme_colors, 1)
    accent = Enum.at(scheme_colors, 2)

    base_colors = %{
      primary_color: "text-#{color_scheme}-600",
      primary_bg: "bg-#{color_scheme}-600",
      primary_border: "border-#{color_scheme}-600",
      primary_hover: "bg-#{color_scheme}-700",
      accent_bg: "bg-#{color_scheme}-500",
      accent_color: "text-#{color_scheme}-500",
      icon_bg: "bg-#{color_scheme}-500",
      border_color: "border-gray-200",
      heading_color: "text-gray-900",
      text_color: "text-gray-700",
      content_text: "text-gray-600",
      subtext_color: "text-gray-500"
    }

    theme_specific = case theme do
      "professional" -> %{
        background: "bg-gray-50",
        header_gradient: "from-#{color_scheme}-500 to-#{color_scheme}-600",
        card_gradient: "from-#{color_scheme}-500 to-#{color_scheme}-600",
        visual_gradient: "from-#{color_scheme}-400 to-#{color_scheme}-600",
        timeline_gradient: "from-#{color_scheme}-400 to-#{color_scheme}-600",
        timeline_card_gradient: "from-#{color_scheme}-500 to-#{color_scheme}-600",
        featured_gradient: "from-#{color_scheme}-500 to-#{color_scheme}-600",
        article_gradient: "from-#{color_scheme}-400 to-#{color_scheme}-500",
        cta_gradient: "from-#{color_scheme}-600 to-#{color_scheme}-700",
        nav_item_bg: "bg-white",
        nav_item_hover: "bg-#{color_scheme}-50",
        nav_icon_bg: "bg-#{color_scheme}-100",
        nav_icon_hover: "bg-#{color_scheme}-500",
        nav_text: "text-gray-700",
        nav_subtext: "text-gray-500",
        footer_item_bg: "bg-gray-50",
        footer_item_hover: "bg-gray-100",
        social_bg: "bg-gray-100",
        social_hover: "bg-#{color_scheme}-100"
      }

      "creative" -> %{
        background: "bg-gradient-to-br from-purple-50 via-pink-50 to-orange-50",
        header_gradient: "from-purple-500 via-pink-500 to-orange-500",
        card_gradient: "from-purple-500 via-pink-500 to-orange-500",
        visual_gradient: "from-purple-400 via-pink-400 to-orange-400",
        timeline_gradient: "from-purple-400 via-pink-400 to-orange-400",
        timeline_card_gradient: "from-purple-500 via-pink-500 to-orange-500",
        featured_gradient: "from-purple-500 via-pink-500 to-orange-500",
        article_gradient: "from-purple-400 to-pink-400",
        cta_gradient: "from-purple-600 via-pink-600 to-orange-600",
        nav_item_bg: "bg-white/90",
        nav_item_hover: "bg-purple-50",
        nav_icon_bg: "bg-purple-100",
        nav_icon_hover: "bg-purple-500",
        nav_text: "text-gray-700",
        nav_subtext: "text-purple-500",
        footer_item_bg: "bg-white/80",
        footer_item_hover: "bg-purple-50",
        social_bg: "bg-purple-100",
        social_hover: "bg-purple-200"
      }

      "minimal" -> %{
        background: "bg-white",
        header_gradient: "from-gray-600 to-gray-700",
        card_gradient: "from-gray-600 to-gray-700",
        visual_gradient: "from-gray-500 to-gray-600",
        timeline_gradient: "from-gray-500 to-gray-600",
        timeline_card_gradient: "from-gray-600 to-gray-700",
        featured_gradient: "from-gray-600 to-gray-700",
        article_gradient: "from-gray-500 to-gray-600",
        cta_gradient: "from-gray-700 to-gray-800",
        nav_item_bg: "bg-gray-50",
        nav_item_hover: "bg-gray-100",
        nav_icon_bg: "bg-gray-200",
        nav_icon_hover: "bg-gray-700",
        nav_text: "text-gray-700",
        nav_subtext: "text-gray-500",
        footer_item_bg: "bg-gray-50",
        footer_item_hover: "bg-gray-100",
        social_bg: "bg-gray-100",
        social_hover: "bg-gray-200"
      }

      "modern" -> %{
        background: "bg-gradient-to-br from-blue-50 to-indigo-50",
        header_gradient: "from-blue-500 to-indigo-600",
        card_gradient: "from-blue-500 to-indigo-600",
        visual_gradient: "from-blue-400 to-indigo-500",
        timeline_gradient: "from-blue-400 to-indigo-500",
        timeline_card_gradient: "from-blue-500 to-indigo-600",
        featured_gradient: "from-blue-500 to-indigo-600",
        article_gradient: "from-blue-400 to-indigo-400",
        cta_gradient: "from-blue-600 to-indigo-700",
        nav_item_bg: "bg-white/90",
        nav_item_hover: "bg-blue-50",
        nav_icon_bg: "bg-blue-100",
        nav_icon_hover: "bg-blue-500",
        nav_text: "text-gray-700",

        nav_subtext: "text-blue-500",
        footer_item_bg: "bg-white/80",
        footer_item_hover: "bg-blue-50",
        social_bg: "bg-blue-100",
        social_hover: "bg-blue-200"
      }

      _ -> %{
        background: "bg-gray-50",
        header_gradient: "from-blue-500 to-blue-600",
        card_gradient: "from-blue-500 to-blue-600",
        visual_gradient: "from-blue-400 to-blue-600",
        timeline_gradient: "from-blue-400 to-blue-600",
        timeline_card_gradient: "from-blue-500 to-blue-600",
        featured_gradient: "from-blue-500 to-blue-600",
        article_gradient: "from-blue-400 to-blue-500",
        cta_gradient: "from-blue-600 to-blue-700",
        nav_item_bg: "bg-white",
        nav_item_hover: "bg-blue-50",
        nav_icon_bg: "bg-blue-100",
        nav_icon_hover: "bg-blue-500",
        nav_text: "text-gray-700",
        nav_subtext: "text-gray-500",
        footer_item_bg: "bg-gray-50",
        footer_item_hover: "bg-gray-100",
        social_bg: "bg-gray-100",
        social_hover: "bg-blue-100"
      }
    end

    Map.merge(base_colors, theme_specific)
  end

  defp get_enhanced_layout_specific_config(layout_type) do
    case layout_type do
      "dashboard" -> %{content_spacing: "space-y-4"}
      "timeline" -> %{content_spacing: "space-y-6"}
      "magazine" -> %{content_spacing: "space-y-4"}
      "minimal" -> %{content_spacing: "space-y-8"}
      _ -> %{content_spacing: "space-y-6"}
    end
  end


  # ============================================================================
  # ENHANCED STANDARD LAYOUT - Premium Single-Column Design
  # ============================================================================

  defp render_enhanced_standard_layout(portfolio, sections, config) do
    social_links = extract_social_links_from_portfolio(portfolio)

    """
    <div class="portfolio-layout standard-layout #{config.background} min-h-screen">
      <!-- Enhanced Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Main Content with Enhanced Typography -->
      <main class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-16">
        <!-- Portfolio Introduction -->
        <div class="text-center mb-16">
          <h2 class="text-3xl font-bold #{config.heading_color} mb-4">About & Experience</h2>
          <div class="w-24 h-1 #{config.accent_bg} mx-auto rounded-full mb-6"></div>
          <p class="text-lg #{config.content_text} max-w-2xl mx-auto leading-relaxed">
            Learn more about my background, experience, and expertise
          </p>
        </div>

        <!-- Enhanced Sections Grid -->
        <div class="space-y-12">
          #{render_enhanced_standard_sections(sections, config)}
        </div>

        <!-- Enhanced Call to Action -->
        <div class="text-center mt-20 py-16 bg-gradient-to-r #{config.cta_gradient} rounded-2xl">
          <h3 class="text-2xl font-bold text-white mb-4">Ready to Work Together?</h3>
          <p class="text-white/90 mb-8 max-w-2xl mx-auto">
            Let's discuss your project and see how I can help bring your vision to life.
          </p>
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-4 bg-white #{config.primary_color} rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
              Start a Project
            </button>
            <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:#{config.primary_color} transition-all duration-300">
              View Resume
            </button>
          </div>
        </div>
      </main>

      <!-- Enhanced Floating Navigation -->
      #{render_enhanced_floating_navigation(sections, "standard", config)}

      <!-- Enhanced Footer -->
      #{render_enhanced_footer_actions(config, social_links)}

      <!-- Enhanced JavaScript -->
      #{render_enhanced_javascript()}
    </div>
    """
  end


  defp render_enhanced_standard_sections(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      animation_delay = index * 100

      """
      <section id="section-#{section.id}"
               class="enhanced-section-card bg-white rounded-2xl shadow-lg border #{config.border_color} overflow-hidden hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2"
               style="animation-delay: #{animation_delay}ms;"
               data-section-id="#{section.id}">

        <!-- Enhanced Card Header -->
        <div class="card-header relative overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-r #{config.header_gradient} opacity-90"></div>
          <div class="relative p-8">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="w-12 h-12 #{config.icon_bg} rounded-xl flex items-center justify-center shadow-lg">
                  #{get_enhanced_section_icon(section.section_type, "text-white text-xl")}
                </div>
                <div>
                  <h3 class="text-2xl font-bold text-white mb-1">#{section.title}</h3>
                  <span class="text-white/80 text-sm font-medium uppercase tracking-wide">
                    #{get_section_type_label(section.section_type)}
                  </span>
                </div>
              </div>
              <button class="expand-btn w-10 h-10 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-white/30 transition-all duration-300"
                      onclick="openSectionModal('#{section.id}')"
                      title="Expand section">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
                </svg>
              </button>
            </div>
          </div>
        </div>

        <!-- Enhanced Card Content -->
        <div class="card-content p-8">
          <div class="prose prose-lg max-w-none #{config.content_text}">
            #{EnhancedContentRenderer.render_enhanced_section_content(section, config.color_scheme)}
          </div>

          <!-- Content Metrics -->
          <div class="flex items-center justify-between mt-6 pt-6 border-t #{config.border_color}">
            <div class="flex items-center space-x-4 text-sm #{config.subtext_color}">
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
                #{get_content_length_indicator(section)}
              </span>
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                #{calculate_read_time(section)} min read
              </span>
            </div>
            <button class="text-sm font-medium #{config.accent_color} hover:#{config.primary_color} transition-colors"
                    onclick="openSectionModal('#{section.id}')">
              Read More &rarr;
            </button>
          </div>
        </div>
      </section>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # ENHANCED DASHBOARD LAYOUT - Modern Professional Grid
  # ============================================================================

  defp render_enhanced_dashboard_layout(portfolio, sections, config) do
    {primary_sections, secondary_sections} = organize_dashboard_sections(sections)
    stats = calculate_dashboard_stats(sections)

    """
    <div class="portfolio-layout dashboard-layout #{config.background} min-h-screen">
      <!-- Enhanced Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Enhanced Dashboard Header -->
      <header class="dashboard-header bg-white shadow-sm border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6 py-8">
          <div class="flex items-center justify-between mb-8">
            <div>
              <h1 class="text-4xl font-bold #{config.heading_color} mb-2">Portfolio Dashboard</h1>
              <p class="#{config.subtext_color} text-lg">Professional overview and key highlights</p>
            </div>
            <div class="hidden lg:flex items-center space-x-6">
              <div class="text-center">
                <div class="text-3xl font-bold #{config.primary_color}">#{stats.completion}%</div>
                <div class="text-sm #{config.subtext_color}">Complete</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold #{config.primary_color}">#{stats.sections}</div>
                <div class="text-sm #{config.subtext_color}">Sections</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold #{config.primary_color}">#{stats.experience}+</div>
                <div class="text-sm #{config.subtext_color}">Years Exp</div>
              </div>
            </div>
          </div>

          <!-- Enhanced Stats Grid for Mobile -->
          <div class="grid grid-cols-3 gap-4 lg:hidden">
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-xl font-bold #{config.primary_color}">#{stats.completion}%</div>
              <div class="text-xs #{config.subtext_color}">Complete</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-xl font-bold #{config.primary_color}">#{stats.sections}</div>
              <div class="text-xs #{config.subtext_color}">Sections</div>
            </div>
            <div class="text-center p-4 bg-gray-50 rounded-xl">
              <div class="text-xl font-bold #{config.primary_color}">#{stats.experience}+</div>
              <div class="text-xs #{config.subtext_color}">Years</div>
            </div>
          </div>
        </div>
      </header>

      <!-- Enhanced Dashboard Grid -->
      <main class="max-w-7xl mx-auto px-6 py-12">
        <!-- Primary Dashboard Cards -->
        <div class="dashboard-grid grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6 mb-12">
          #{render_enhanced_dashboard_cards(primary_sections, config, "primary")}
        </div>

        <!-- Secondary Content -->
        #{if length(secondary_sections) > 0 do
          """
          <div class="secondary-content">
            <h2 class="text-2xl font-bold #{config.heading_color} mb-8 text-center">Additional Information</h2>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              #{render_enhanced_dashboard_cards(secondary_sections, config, "secondary")}
            </div>
          </div>
          """
        else
          ""
        end}

        <!-- Enhanced Call to Action -->
        <div class="mt-16 text-center">
          <div class="bg-gradient-to-r #{config.cta_gradient} rounded-2xl p-12">
            <h3 class="text-3xl font-bold text-white mb-4">Let's Build Something Amazing</h3>
            <p class="text-white/90 text-lg mb-8 max-w-2xl mx-auto">
              Ready to turn your ideas into reality? Let's discuss your next project.
            </p>
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <button class="px-8 py-4 bg-white #{config.primary_color} rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
                Start a Conversation
              </button>
              <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:#{config.primary_color} transition-all duration-300">
                View Portfolio
              </button>
            </div>
          </div>
        </div>
      </main>

      <!-- Enhanced Floating Navigation -->
      #{render_enhanced_floating_navigation(sections, "dashboard", config)}

      <!-- Enhanced Footer -->
      #{render_enhanced_footer_actions(config, extract_social_links_from_portfolio(portfolio))}

      <!-- Enhanced JavaScript -->
      #{render_enhanced_javascript()}
    </div>
    """
  end

  defp render_enhanced_dashboard_cards(sections, config, card_type) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      card_class = if card_type == "primary", do: "dashboard-card-primary", else: "dashboard-card-secondary"
      animation_delay = index * 150
      card_height = if card_type == "primary", do: "h-80", else: "h-64"

      """
      <div id="section-#{section.id}"
           class="enhanced-dashboard-card #{card_class} #{card_height} bg-white rounded-2xl border #{config.border_color} shadow-lg hover:shadow-2xl transition-all duration-500 transform hover:-translate-y-2 group cursor-pointer overflow-hidden"
           style="animation-delay: #{animation_delay}ms;"
           onclick="openSectionModal('#{section.id}')"
           data-section-id="#{section.id}">

        <!-- Enhanced Card Header with Gradient -->
        <div class="card-header relative overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-r #{config.card_gradient} opacity-90"></div>
          <div class="relative p-6 border-b #{config.border_color}">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3">
                <div class="section-icon w-10 h-10 bg-white/20 backdrop-blur-sm rounded-xl flex items-center justify-center shadow-lg">
                  #{get_enhanced_section_icon(section.section_type, "text-white")}
                </div>
                <div>
                  <h3 class="font-bold text-white text-lg leading-tight">#{section.title}</h3>
                  <span class="text-white/80 text-xs font-medium uppercase tracking-wider">
                    #{get_section_type_label(section.section_type)}
                  </span>
                </div>
              </div>
              <button class="expand-btn opacity-0 group-hover:opacity-100 transition-all duration-300 w-8 h-8 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-white/30">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
                </svg>
              </button>
            </div>
          </div>
        </div>

        <!-- Enhanced Card Content -->
        <div class="card-content p-6 flex-1 flex flex-col">
          <div class="content-preview flex-1 overflow-hidden">
            <div class="#{config.content_text} text-sm leading-relaxed line-clamp-4">
              #{get_enhanced_section_preview(section, 150)}
            </div>
          </div>

          <!-- Enhanced Card Footer -->
          <div class="card-footer mt-4 pt-4 border-t #{config.border_color}">
            <div class="flex items-center justify-between text-xs #{config.subtext_color}">
              <div class="flex items-center space-x-3">
                <span class="flex items-center">
                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                  </svg>
                  #{get_content_length_indicator(section)}
                </span>
                <span class="flex items-center">
                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  #{calculate_read_time(section)}m
                </span>
              </div>
              <div class="flex items-center #{config.accent_color} opacity-0 group-hover:opacity-100 transition-opacity">
                <span class="text-xs font-medium mr-1">View</span>
                <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                </svg>
              </div>
            </div>
          </div>
        </div>

        <!-- Enhanced Hover Effect Overlay -->
        <div class="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 pointer-events-none"></div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # ENHANCED MASONRY GRID LAYOUT - Visual Showcase
  # ============================================================================

  defp render_enhanced_masonry_grid_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout masonry-layout #{config.background} min-h-screen">
      <!-- Enhanced Hero Section -->
      #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

      <!-- Enhanced Masonry Header -->
      <header class="masonry-header py-20 text-center bg-gradient-to-b from-white to-gray-50">
        <div class="max-w-6xl mx-auto px-6">
          <h1 class="text-5xl font-bold #{config.heading_color} mb-6">Portfolio Showcase</h1>
          <div class="w-32 h-1 #{config.accent_bg} mx-auto rounded-full mb-8"></div>
          <p class="text-xl #{config.content_text} max-w-3xl mx-auto leading-relaxed">
            Explore my work through this curated visual collection of projects, experiences, and achievements
          </p>

          <!-- Enhanced Filter Buttons -->
          <div class="flex flex-wrap justify-center gap-3 mt-10">
            <button class="filter-btn active px-6 py-3 #{config.primary_bg} text-white rounded-full font-medium transition-all duration-300 hover:shadow-lg" data-filter="all">
              All Sections
            </button>
            #{render_section_filter_buttons(sections, config)}
          </div>
        </div>
      </header>

      <!-- Enhanced Masonry Container -->
      <main class="max-w-7xl mx-auto px-6 py-16">
        <div class="masonry-container" data-masonry='{"percentPosition": true, "itemSelector": ".masonry-item", "columnWidth": ".masonry-sizer", "gutter": 24}'>
          <!-- Grid Sizer for Masonry -->
          <div class="masonry-sizer w-full sm:w-1/2 lg:w-1/3 xl:w-1/4"></div>

          #{render_enhanced_masonry_items(sections, config)}
        </div>
      </main>

      <!-- Enhanced Floating Navigation -->
      #{render_enhanced_floating_navigation(sections, "masonry", config)}

      <!-- Enhanced Footer -->
      #{render_enhanced_footer_actions(config, extract_social_links_from_portfolio(portfolio))}

      <!-- Enhanced Masonry JavaScript -->
      #{render_enhanced_masonry_javascript()}
    </div>
    """
  end

  defp render_enhanced_masonry_items(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      # Enhanced height variation for visual interest
      height_class = case rem(index, 5) do
        0 -> "h-72"   # Short
        1 -> "h-96"   # Medium
        2 -> "h-80"   # Medium-short
        3 -> "h-[28rem]" # Tall
        4 -> "h-64"   # Short
      end

      animation_delay = index * 100

      """
      <div id="section-#{section.id}"
           class="masonry-item w-full sm:w-1/2 lg:w-1/3 xl:w-1/4 mb-6 cursor-pointer filter-#{normalize_section_type(section.section_type)}"
           style="animation-delay: #{animation_delay}ms;"
           onclick="openSectionModal('#{section.id}')"
           data-section-id="#{section.id}">

        <div class="masonry-card #{height_class} bg-white rounded-2xl shadow-lg hover:shadow-2xl transition-all duration-500 overflow-hidden group transform hover:-translate-y-2">

          <!-- Enhanced Card Visual Header -->
          <div class="card-visual relative h-2/5 overflow-hidden">
            <div class="absolute inset-0 bg-gradient-to-br #{config.visual_gradient}"></div>
            #{render_enhanced_section_visual(section, config)}
            <div class="absolute inset-0 bg-gradient-to-t from-black/40 via-transparent to-transparent"></div>

            <!-- Enhanced Floating Category Badge -->
            <div class="absolute top-4 left-4">
              <span class="px-3 py-1 bg-white/90 backdrop-blur-sm #{config.primary_color} text-xs font-bold rounded-full shadow-lg">
                #{get_section_type_label(section.section_type)}
              </span>
            </div>

            <!-- Enhanced Overlay Content -->
            <div class="absolute bottom-4 left-4 right-4">
              <h3 class="text-white font-bold text-lg mb-1 leading-tight">#{section.title}</h3>
              <div class="flex items-center text-white/90 text-sm">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                #{calculate_read_time(section)} min read
              </div>
            </div>
          </div>

          <!-- Enhanced Card Content -->
          <div class="card-content p-6 h-3/5 flex flex-col">
            <div class="content-preview flex-1 overflow-hidden">
              <p class="#{config.content_text} text-sm leading-relaxed line-clamp-4">
                #{get_enhanced_section_preview(section, 120)}
              </p>
            </div>

            <!-- Enhanced Card Footer -->
            <div class="card-footer mt-4 flex justify-between items-center">
              <div class="flex items-center space-x-2 text-xs #{config.subtext_color}">
                <span class="flex items-center">
                  <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                  </svg>
                  #{get_content_length_indicator(section)}
                </span>
              </div>
              <button class="expand-btn opacity-0 group-hover:opacity-100 transition-all duration-300 w-8 h-8 #{config.primary_bg} text-white rounded-full flex items-center justify-center hover:scale-110">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
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
  # ENHANCED TIMELINE LAYOUT - Chronological Journey
  # ============================================================================

  defp render_enhanced_timeline_layout(portfolio, sections, config) do
  sorted_sections = sort_sections_chronologically(sections)

  """
  <div class="portfolio-layout timeline-layout #{config.background} min-h-screen">
    <!-- Enhanced Hero Section -->
    #{EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, config.color_scheme)}

    <!-- Enhanced Timeline Header -->
    <header class="timeline-header py-20 text-center bg-gradient-to-b from-white to-gray-50">
      <div class="max-w-4xl mx-auto px-6">
        <h1 class="text-5xl font-bold #{config.heading_color} mb-6">Professional Journey</h1>
        <div class="w-32 h-1 #{config.accent_bg} mx-auto rounded-full mb-8"></div>
        <p class="text-xl #{config.content_text} leading-relaxed">
          Follow my career progression, key milestones, and professional development over the years
        </p>
      </div>
    </header>

    <!-- Enhanced Timeline Container -->
    <main class="max-w-4xl mx-auto px-6 py-16">
      <div class="timeline-container relative">
        <!-- Enhanced Timeline Line -->
        <div class="timeline-line absolute left-8 top-0 bottom-0 w-1 bg-gradient-to-b #{config.timeline_gradient} rounded-full shadow-sm"></div>

        <!-- Enhanced Timeline Items -->
        <div class="space-y-16">
          #{render_enhanced_timeline_items(sorted_sections, config)}
        </div>
      </div>
    </main>

    <!-- Enhanced Floating Navigation -->
    #{render_enhanced_floating_navigation(sections, "timeline", config)}

    <!-- Enhanced Footer -->
    #{render_enhanced_footer_actions(config, extract_social_links_from_portfolio(portfolio))}

    <!-- Enhanced JavaScript -->
    #{render_enhanced_javascript()}
  </div>
  """
end

defp render_enhanced_timeline_items(sections, config) do
  sections
  |> Enum.with_index()
  |> Enum.map(fn {section, index} ->
    is_left = rem(index, 2) == 0
    position_class = if is_left, do: "timeline-left", else: "timeline-right"
    animation_delay = index * 200

    """
    <div id="section-#{section.id}"
         class="timeline-item #{position_class} relative cursor-pointer group"
         style="animation-delay: #{animation_delay}ms;"
         onclick="openSectionModal('#{section.id}')"
         data-section-id="#{section.id}">

      <!-- Enhanced Timeline Dot -->
      <div class="timeline-dot absolute left-6 w-6 h-6 #{config.primary_bg} rounded-full border-4 border-white shadow-lg z-10 flex items-center justify-center group-hover:scale-125 transition-transform duration-300">
        <div class="w-2 h-2 bg-white rounded-full"></div>
      </div>

      <!-- Enhanced Timeline Card -->
      <div class="timeline-card ml-20 bg-white rounded-2xl border #{config.border_color} shadow-lg hover:shadow-2xl transition-all duration-500 group-hover:-translate-y-2 overflow-hidden">

        <!-- Enhanced Card Header -->
        <div class="card-header relative overflow-hidden">
          <div class="absolute inset-0 bg-gradient-to-r #{config.timeline_card_gradient} opacity-90"></div>
          <div class="relative p-6 border-b #{config.border_color}">
            <div class="flex items-start justify-between">
              <div class="flex-1">
                <h3 class="text-2xl font-bold text-white mb-2 leading-tight">#{section.title}</h3>
                <div class="flex items-center space-x-3">
                  <span class="px-3 py-1 bg-white/20 backdrop-blur-sm text-white text-xs font-medium rounded-full">
                    #{get_section_type_label(section.section_type)}
                  </span>
                  <span class="text-white/80 text-sm">
                    #{get_section_date(section)}
                  </span>
                </div>
              </div>
              <button class="expand-btn opacity-0 group-hover:opacity-100 transition-all duration-300 w-10 h-10 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-white/30">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
                </svg>
              </button>
            </div>
          </div>
        </div>

        <!-- Enhanced Card Content -->
        <div class="card-content p-6">
          <div class="content-preview max-h-32 overflow-hidden mb-4">
            <p class="#{config.content_text} leading-relaxed">
              #{get_enhanced_section_preview(section, 200)}
            </p>
          </div>

          <!-- Enhanced Progress Indicator -->
          <div class="progress-section">
            <div class="flex items-center justify-between mb-2">
              <span class="text-sm font-medium #{config.subtext_color}">Completion</span>
              <span class="text-sm font-bold #{config.primary_color}">#{calculate_section_progress(section, index)}%</span>
            </div>
            <div class="progress-bar w-full h-2 bg-gray-200 rounded-full overflow-hidden">
              <div class="h-full #{config.primary_bg} rounded-full transition-all duration-1000"
                   style="width: #{calculate_section_progress(section, index)}%"></div>
            </div>
          </div>

          <!-- Enhanced Metrics -->
          <div class="metrics-section mt-4 pt-4 border-t #{config.border_color}">
            <div class="flex items-center justify-between text-sm #{config.subtext_color}">
              <div class="flex items-center space-x-4">
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                  </svg>
                  #{get_content_length_indicator(section)}
                </span>
                <span class="flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                  </svg>
                  #{calculate_read_time(section)} min
                </span>
              </div>
              <button class="text-sm font-medium #{config.accent_color} hover:#{config.primary_color} transition-colors">
                View Details &rarr;
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end)
  |> Enum.join("\n")
end

    # ============================================================================
  # ENHANCED SECTION ORGANIZATION AND UTILITIES
  # ============================================================================

  defp filter_non_empty_sections(sections) do
    Enum.filter(sections, fn section ->
      content = section.content || %{}

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
    primary_types = [:experience, :skills, :projects, :about]

    {primary, secondary} = Enum.split_with(sections, fn section ->
      normalize_section_type(section.section_type) in primary_types
    end)

    {Enum.take(primary, 8), secondary}
  end

  defp organize_magazine_sections(sections) do
    featured = Enum.max_by(sections, fn section ->
      content_length = get_content_length(section)
      case section.section_type do
        :about -> content_length + 100
        :projects -> content_length + 50
        _ -> content_length
      end
    end, fn -> nil end)

    regular = if featured, do: List.delete(sections, featured), else: sections
    {featured, regular}
  end

  defp sort_sections_chronologically(sections) do
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

    # ============================================================================
  # ENHANCED CONTENT HELPERS
  # ============================================================================

 defp get_enhanced_section_preview(section, max_length) do
  content = section.content || %{}

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
      Enum.find_value(["summary", "description", "bio", "content", "text"], fn field ->
        value = Map.get(content, field, "")
        if String.trim(value) != "", do: value, else: nil
      end) || "View section content"
  end

  preview_text
  |> String.replace(~r/<[^>]*>/, "")
  |> String.trim()
  |> truncate_text(max_length)
end

defp calculate_section_progress(section, index) do
  base_progress = 60
  content_bonus = min(get_content_length(section) / 10, 30)
  index_bonus = min(index * 2, 10)

  round(base_progress + content_bonus + index_bonus)
end

defp get_section_date(section) do
  content = section.content || %{}

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

  defp get_enhanced_section_icon(section_type, class_override \\ "") do
    icon_class = if class_override != "", do: class_override, else: "w-5 h-5"

    case normalize_section_type(section_type) do
      :experience ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
        """
      :education ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z"/>
        </svg>
        """
      :skills ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """
      :projects ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """
      :about ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """
      :contact ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """
      :testimonials ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
        </svg>
        """
      _ ->
        """
        <svg class="#{icon_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """
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

  defp calculate_section_progress(section, index) do
    base_progress = 60
    content_bonus = min(get_content_length(section) / 10, 30)
    index_bonus = min(index * 2, 10)

    round(base_progress + content_bonus + index_bonus)
  end

  defp calculate_read_time(section) do
    words = get_content_length(section) / 5
    max(round(words / 200), 1)
  end

  defp calculate_total_read_time(sections) do
    sections
    |> Enum.map(&calculate_read_time/1)
    |> Enum.sum()
  end

  defp calculate_dashboard_stats(sections) do
    %{
      completion: calculate_completion_percentage(sections),
      sections: length(sections),
      experience: get_experience_years_estimate(sections)
    }
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

  defp get_experience_years_estimate(sections) do
    experience_section = Enum.find(sections, fn section ->
      normalize_section_type(section.section_type) == :experience
    end)

    if experience_section do
      content = experience_section.content || %{}
      jobs = Map.get(content, "jobs", [])

      if length(jobs) > 0 do
        # Simple estimation based on number of jobs
        min(length(jobs) * 2, 15)
      else
        5
      end
    else
      3
    end
  end

  defp render_enhanced_section_visual(section, config) do
    case normalize_section_type(section.section_type) do
      :experience ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-5xl text-white/80">
            <svg class="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
            </svg>
          </div>
        </div>
        """

      :skills ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="grid grid-cols-4 gap-2">
            <div class="w-4 h-4 bg-white/60 rounded"></div>
            <div class="w-4 h-4 bg-white/80 rounded"></div>
            <div class="w-4 h-4 bg-white/60 rounded"></div>
            <div class="w-4 h-4 bg-white/90 rounded"></div>
            <div class="w-4 h-4 bg-white/80 rounded"></div>
            <div class="w-4 h-4 bg-white/90 rounded"></div>
            <div class="w-4 h-4 bg-white/70 rounded"></div>
            <div class="w-4 h-4 bg-white/85 rounded"></div>
          </div>
        </div>
        """

      :projects ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-5xl text-white/80">
            <svg class="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
          </div>
        </div>
        """

      _ ->
        """
        <div class="section-visual flex items-center justify-center h-full">
          <div class="text-5xl text-white/80">
            #{get_enhanced_section_icon(section.section_type, "w-16 h-16")}
          </div>
        </div>
        """
    end
  end

  defp render_section_filter_buttons(sections, config) do
    sections
    |> Enum.map(&normalize_section_type(&1.section_type))
    |> Enum.uniq()
    |> Enum.map(fn section_type ->
      label = get_section_type_label(section_type)
      """
      <button class="filter-btn px-4 py-2 bg-white #{config.primary_color} border #{config.border_color} rounded-full text-sm font-medium transition-all duration-300 hover:#{config.primary_bg} hover:text-white" data-filter="#{section_type}">
        #{label}
      </button>
      """
    end)
    |> Enum.join("")
  end

  defp get_social_icon_enhanced(platform) do
    case String.downcase(to_string(platform)) do
      "linkedin" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
        </svg>
        """

      "github" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
        </svg>
        """

      "twitter" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
        </svg>
        """

      "instagram" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/>
        </svg>
        """

      "website" ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9 3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
        </svg>
        """

      _ ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """
    end
  end

defp extract_social_links_from_portfolio(portfolio) do
  contact_info = portfolio.contact_info || %{}
  customization = portfolio.customization || %{}

  social_platforms = ["linkedin", "twitter", "github", "instagram", "website"]

  Enum.reduce(social_platforms, [], fn platform, acc ->
    url = Map.get(contact_info, platform) || Map.get(customization, "#{platform}_url")
    if url && String.length(url) > 0 do
      [{platform, url} | acc]
    else
      acc
    end
  end)
  |> Enum.reverse()
end

  defp format_platform_name(platform) do
    platform
    |> to_string()
    |> String.capitalize()
    |> case do
      "Github" -> "GitHub"
      "Linkedin" -> "LinkedIn"
      "Youtube" -> "YouTube"
      other -> other
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
