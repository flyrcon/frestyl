# lib/frestyl_web/live/portfolio_live/components/enhanced_layout_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer do
  @moduledoc """
  Clean, mobile-first portfolio layout renderer with practical designs.
  Supports 3 focused layouts: Sidebar, Single, and Workspace.
  Complete overhaul for clean white cards on white background.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.EnhancedContentRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedHeroRenderer
  alias FrestylWeb.PortfolioLive.Components.EnhancedSectionCards

  # ============================================================================
  # MAIN LAYOUT RENDERER - Updated Interface
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme) do
    IO.puts("🎨 ENHANCED LAYOUT RENDERER called")
    IO.puts("🎨 Layout: #{layout_type}")
    IO.puts("🎨 Color scheme: #{color_scheme}")
    IO.puts("🎨 Theme: #{theme}")
    IO.puts("🎨 Sections count: #{length(sections)}")

    # Filter visible sections for navigation
    visible_sections = filter_visible_sections(sections)
    IO.puts("🎨 Visible sections: #{length(visible_sections)}")

    # Get clean layout configuration
    layout_config = get_clean_layout_config(layout_type, color_scheme)
    IO.puts("🎨 Layout config: #{inspect(layout_config)}")

    # Render based on layout type
    normalized_layout = normalize_layout_type(layout_type)
    IO.puts("🎨 Normalized layout: #{normalized_layout}")

    result = case normalized_layout do
      :sidebar -> render_sidebar_layout(portfolio, sections, visible_sections, layout_config)
      :single -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :workspace -> render_workspace_layout(portfolio, sections, visible_sections, layout_config)
      _ -> render_single_layout(portfolio, sections, visible_sections, layout_config)
    end

    IO.puts("🎨 Layout rendered successfully")
    result
  end

  defp render_workspace_cards(sections, config) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      # Get section details
      section_title = get_section_title(section)
      section_preview = get_section_preview(section)
      section_emoji = get_section_emoji(section.section_type)

      # Calculate grid positioning
      grid_class = case rem(index, 3) do
        0 -> "md:col-span-2"  # First item spans 2 columns
        _ -> "md:col-span-1"  # Others span 1 column
      end

      """
      <div id="section-#{section.id}"
          class="workspace-card bg-white rounded-xl border border-gray-200 p-6 hover:shadow-lg hover:border-#{config.color_scheme}-200 transition-all duration-300 cursor-pointer #{grid_class}"
          onclick="scrollToSection('#{section.id}')">

        <!-- Card Header -->
        <div class="flex items-center mb-4">
          <div class="w-12 h-12 bg-#{config.color_scheme}-100 rounded-xl flex items-center justify-center mr-4 flex-shrink-0">
            <span class="text-xl">#{section_emoji}</span>
          </div>
          <div class="flex-1 min-w-0">
            <h3 class="font-semibold text-gray-900 truncate">#{section_title}</h3>
            <p class="text-sm text-#{config.color_scheme}-600">#{format_section_type_title(section.section_type)}</p>
          </div>
        </div>

        <!-- Card Content Preview -->
        <div class="mb-4">
          <p class="text-sm text-gray-600 line-clamp-3">#{section_preview}</p>
        </div>

        <!-- Card Footer with Action -->
        <div class="flex items-center justify-between pt-4 border-t border-gray-100">
          <span class="text-xs text-gray-500 uppercase tracking-wide">#{get_section_category(section.section_type)}</span>
          <svg class="w-4 h-4 text-#{config.color_scheme}-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
          </svg>
        </div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  # ============================================================================
  # SIDEBAR LAYOUT - IMDB-style with left navigation
  # ============================================================================

  defp render_sidebar_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    """
    <div class="portfolio-layout sidebar-layout min-h-screen bg-white">
      <!-- Mobile Navigation Toggle -->
      <div class="lg:hidden fixed top-4 left-4 z-50">
        <button onclick="toggleMobileNav()"
                class="p-2 bg-white rounded-lg shadow-md border border-gray-200 hover:bg-gray-50">
          <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
      </div>

      <div class="flex">
        <!-- Sidebar Navigation -->
        <aside id="portfolio-sidebar"
               class="fixed lg:sticky top-0 left-0 w-80 h-screen bg-white border-r border-gray-100 overflow-y-auto z-40 transform -translate-x-full lg:translate-x-0 transition-transform">

          <!-- Unified Portfolio Header -->
          #{render_unified_sidebar_header(portfolio, social_links, contact_info)}

          <!-- Section Navigation -->
          <nav class="p-4">
            <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Contents</h3>
            <ul class="space-y-1">
              #{render_section_nav_items(visible_sections)}
            </ul>
          </nav>

          <!-- Quick Actions -->
          <div class="p-4 border-t border-gray-100 mt-auto">
            #{render_quick_actions(portfolio, contact_info)}
          </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 lg:ml-0">
          <!-- Hero Section -->
          #{render_clean_hero(portfolio, sections, has_media, "sidebar")}

          <!-- Content Sections -->
          <div class="max-w-4xl mx-auto px-6 lg:px-8 py-8">
            #{render_clean_sections(sections, "sidebar", config)}
          </div>
        </main>
      </div>

      <!-- Mobile Overlay -->
      <div id="mobile-overlay"
           class="fixed inset-0 bg-black bg-opacity-50 z-30 lg:hidden hidden"
           onclick="toggleMobileNav()"></div>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # SINGLE LAYOUT - Clean single column
  # ============================================================================

  defp render_single_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)

    """
    <div class="portfolio-layout single-layout min-h-screen bg-white">
      <!-- Floating Navigation -->
      <nav class="fixed top-6 right-6 z-40 lg:block hidden">
        <div class="bg-white rounded-lg shadow-lg border border-gray-200 p-2 max-w-xs">
          <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider px-3 py-2">Navigation</h4>
          <ul class="space-y-1">
            #{render_compact_nav_items(visible_sections)}
          </ul>
        </div>
      </nav>

      <!-- Mobile Navigation -->
      <div class="lg:hidden fixed bottom-6 right-6 z-40">
        <button onclick="toggleFloatingNav()"
                class="p-3 bg-gray-900 text-white rounded-full shadow-lg hover:bg-gray-800">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
      </div>

      <!-- Main Content -->
      <main class="max-w-4xl mx-auto">
        <!-- Unified Hero Section -->
        #{render_clean_hero(portfolio, sections, has_media, "single")}

        <!-- Content Sections -->
        <div class="px-6 lg:px-8 py-8">
          #{render_clean_sections(sections, "single", config)}
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # WORKSPACE LAYOUT - Unique dashboard-style layout
  # ============================================================================

  defp render_workspace_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)

    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-white">
      <!-- Top Navigation Bar -->
      <nav class="fixed top-0 left-0 right-0 z-40 bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6">
          <div class="flex items-center justify-between h-16">
            <h1 class="text-xl font-bold text-gray-900">#{portfolio.title}</h1>
            <div class="flex items-center space-x-4">
              #{render_workspace_nav_items(visible_sections)}
            </div>
          </div>
        </div>
      </nav>

      <!-- Main Content with Grid -->
      <main class="pt-16 min-h-screen">
        <!-- Hero Section -->
        <div class="bg-gray-50 py-12">
          #{render_clean_hero(portfolio, sections, has_media, "workspace")}
        </div>

        <!-- Dashboard Grid -->
        <div class="max-w-7xl mx-auto px-6 py-8">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            #{render_workspace_cards(sections, config)}
          </div>
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # UNIFIED HEADER SYSTEM
  # ============================================================================

  defp render_unified_sidebar_header(portfolio, social_links, contact_info) do
    """
    <div class="p-6 border-b border-gray-100">
      <h1 class="text-xl font-bold text-gray-900 mb-2">#{portfolio.title}</h1>
      #{if portfolio.description do
        "<p class=\"text-sm text-gray-600 leading-relaxed mb-4\">#{portfolio.description}</p>"
      else
        ""
      end}

      <!-- Social Links -->
      #{if length(social_links) > 0 do
        render_compact_social_links(social_links)
      else
        ""
      end}

      <!-- Contact Info -->
      #{if contact_info[:email] || contact_info[:phone] do
        render_compact_contact_info(contact_info)
      else
        ""
      end}
    </div>
    """
  end

  defp render_unified_workspace_header(portfolio, social_links, contact_info) do
    """
    <div>
      <h1 class="text-2xl font-bold text-gray-900">#{portfolio.title}</h1>
      #{if portfolio.description do
        "<p class=\"text-gray-600 mt-1\">#{portfolio.description}</p>"
      else
        ""
      end}
    </div>
    """
  end

# ============================================================================
# HERO RENDERING FUNCTIONS
# ============================================================================


  defp render_clean_hero(portfolio, sections, has_media, layout_type) do
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    if has_media do
      render_media_hero(portfolio, social_links, contact_info, layout_type)
    else
      render_text_hero(portfolio, social_links, contact_info, layout_type)
    end
  end

  defp render_media_hero(portfolio, social_links, contact_info, layout_type) do
    video_url = get_portfolio_video_url(portfolio)

    """
    <section class="py-12 px-6 lg:px-8">
      <div class="max-w-4xl mx-auto">
        <div class="flex flex-col lg:flex-row items-center gap-8">
          <!-- Media -->
          <div class="w-full lg:w-1/2">
            #{if video_url do
              "<div class=\"aspect-video rounded-lg overflow-hidden shadow-lg\">
                <video controls preload=\"metadata\" class=\"w-full h-full object-cover\">
                  <source src=\"#{video_url}\" type=\"video/mp4\">
                  Your browser does not support the video tag.
                </video>
              </div>"
            else
              "<div class=\"aspect-video bg-gray-100 rounded-lg flex items-center justify-center\">
                <div class=\"text-center text-gray-500\">
                  <svg class=\"w-12 h-12 mx-auto mb-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
                    <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"1\" d=\"M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z\"/>
                  </svg>
                  <p class=\"text-sm\">Video introduction</p>
                </div>
              </div>"
            end}
          </div>

          <!-- Content -->
          <div class="flex-1">
            <h1 class="text-3xl lg:text-4xl font-bold text-gray-900 mb-4">#{portfolio.title}</h1>
            #{if portfolio.description do
              "<p class=\"text-lg text-gray-600 leading-relaxed mb-6\">#{portfolio.description}</p>"
            else
              ""
            end}

            <!-- Social & Contact for non-sidebar layouts -->
            #{if layout_type != "sidebar" do
              render_hero_social_contact(social_links, contact_info)
            else
              ""
            end}

            #{render_hero_actions(portfolio)}
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp render_text_hero(portfolio, social_links, contact_info, layout_type) do
    """
    <section class="py-16 px-6 lg:px-8">
      <div class="max-w-4xl mx-auto text-center">
        <h1 class="text-4xl lg:text-6xl font-bold text-gray-900 mb-6">#{portfolio.title}</h1>
        #{if portfolio.description do
          "<p class=\"text-xl text-gray-600 leading-relaxed mb-8 max-w-2xl mx-auto\">#{portfolio.description}</p>"
        else
          ""
        end}

        <!-- Social & Contact for non-sidebar layouts -->
        #{if layout_type != "sidebar" do
          "<div class=\"flex justify-center\">" <> render_hero_social_contact(social_links, contact_info) <> "</div>"
        else
          ""
        end}

        #{render_hero_actions(portfolio)}
      </div>
    </section>
    """
  end

  defp render_hero_social_contact(social_links, contact_info) do
    social_html = social_links
    |> Enum.map(fn {platform, url} ->
      """
      <a href="#{url}" target="_blank"
        class="inline-flex items-center px-4 py-2 bg-gray-100 hover:bg-gray-200 rounded-lg text-sm text-gray-700 transition-colors mr-3 mb-3">
        #{get_social_icon_simple(platform)}
        <span class="ml-2">#{format_platform_name(platform)}</span>
      </a>
      """
    end)
    |> Enum.join("\n")

    contact_html = if contact_info[:email] do
      """
      <a href="mailto:#{contact_info[:email]}"
        class="inline-flex items-center px-4 py-2 bg-blue-600 hover:bg-blue-700 text-white rounded-lg text-sm transition-colors mr-3 mb-3">
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        Contact
      </a>
      """
    else
      ""
    end

    "<div class=\"flex flex-wrap items-center justify-center mb-8\">" <> social_html <> contact_html <> "</div>"
  end

  defp render_hero_actions(portfolio) do
    """
    <div class="flex flex-col sm:flex-row gap-4 justify-center">
      <button onclick="scrollToSection('content')"
              class="px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors">
        View Portfolio
      </button>
      <button onclick="openContactModal()"
              class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
        Get in Touch
      </button>
    </div>
    """
  end

  # ============================================================================
  # CLEAN SECTION RENDERING
  # ============================================================================

  defp render_clean_sections(sections, layout_type, config) do
    sections
    |> filter_content_sections()
    |> Enum.map(&render_clean_section(&1, layout_type, config))
    |> Enum.join("\n")
  end

  defp render_clean_section(section, layout_type, config) do
    """
    <section id="section-#{section.id}" class="section-card bg-white rounded-lg border border-gray-200 p-6 lg:p-8 mb-6 last:mb-0 hover:shadow-sm transition-shadow">
      <!-- Section Header -->
      <header class="mb-6">
        <h2 class="text-2xl font-bold text-gray-900 mb-2">#{section.title}</h2>
      </header>

      <!-- Section Content -->
      <div class="section-content prose prose-gray max-w-none">
        #{render_section_content_safe(section)}
      </div>
    </section>
    """
  end


  defp render_primary_workspace_sections(sections, config) do
    sections
    |> Enum.take(2)
    |> Enum.map(&render_workspace_card(&1, "large"))
    |> Enum.join("\n")
  end

  defp render_secondary_workspace_sections(sections, config) do
    sections
    |> Enum.take(3)
    |> Enum.map(&render_workspace_card(&1, "compact"))
    |> Enum.join("\n")
  end

  defp render_additional_workspace_sections(sections, config) do
    """
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      #{sections |> Enum.map(&render_workspace_card(&1, "grid")) |> Enum.join("\n")}
    </div>
    """
  end

  defp render_workspace_card(section, size) do
    card_classes = case size do
      "large" -> "bg-white rounded-lg border border-gray-200 p-6 lg:p-8 hover:shadow-sm transition-shadow"
      "compact" -> "bg-white rounded-lg border border-gray-200 p-4 hover:shadow-sm transition-shadow"
      "grid" -> "bg-white rounded-lg border border-gray-200 p-6 hover:shadow-sm transition-shadow"
    end

    """
    <div id="section-#{section.id}" class="#{card_classes}">
      <h3 class="text-lg font-semibold text-gray-900 mb-3">#{section.title}</h3>
      <div class="section-content text-gray-600">
        #{render_section_content_preview(section, size)}
      </div>
    </div>
    """
  end

  # ============================================================================
  # SOCIAL LINKS & CONTACT INFO
  # ============================================================================

  defp render_compact_social_links(social_links) do
    """
    <div class="flex items-center gap-2 mb-3">
      #{social_links |> Enum.take(4) |> Enum.map(&render_social_icon/1) |> Enum.join("")}
    </div>
    """
  end

  defp render_hero_social_links(social_links) do
    """
    <div class="flex items-center gap-3">
      #{social_links |> Enum.take(5) |> Enum.map(&render_hero_social_icon/1) |> Enum.join("")}
    </div>
    """
  end

  defp render_social_icon({platform, url}) do
    """
    <a href="#{url}" target="_blank" rel="noopener noreferrer"
       class="w-8 h-8 bg-gray-100 hover:bg-gray-200 rounded-full flex items-center justify-center transition-colors">
      #{get_social_icon_svg(platform)}
    </a>
    """
  end

  defp render_hero_social_icon({platform, url}) do
    """
    <a href="#{url}" target="_blank" rel="noopener noreferrer"
       class="w-10 h-10 bg-gray-100 hover:bg-gray-200 rounded-full flex items-center justify-center transition-colors">
      #{get_social_icon_svg(platform)}
    </a>
    """
  end

  defp render_compact_contact_info(contact_info) do
    """
    <div class="text-xs text-gray-600 space-y-1">
      #{if contact_info[:email] && String.length(String.trim(contact_info[:email])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-3 h-3\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>
          </svg>
          <a href=\"mailto:#{contact_info[:email]}\" class=\"hover:text-gray-800\">#{contact_info[:email]}</a>
        </div>"
      else
        ""
      end}
      #{if contact_info[:phone] && String.length(String.trim(contact_info[:phone])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-3 h-3\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>
          </svg>
          <a href=\"tel:#{contact_info[:phone]}\" class=\"hover:text-gray-800\">#{contact_info[:phone]}</a>
        </div>"
      else
        ""
      end}
      #{if contact_info[:location] && String.length(String.trim(contact_info[:location])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-3 h-3\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z\"/>
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 11a3 3 0 11-6 0 3 3 0 016 0z\"/>
          </svg>
          <span>#{contact_info[:location]}</span>
        </div>"
      else
        ""
      end}
      #{if contact_info[:website] && String.length(String.trim(contact_info[:website])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-3 h-3\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1\"/>
          </svg>
          <a href=\"#{contact_info[:website]}\" target=\"_blank\" rel=\"noopener\" class=\"hover:text-gray-800\">#{String.replace(contact_info[:website], ~r/^https?:\/\//, "")}</a>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_hero_contact_info(contact_info) do
    """
    <div class="text-sm text-gray-600 space-y-2">
      #{if contact_info[:email] && String.length(String.trim(contact_info[:email])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>
          </svg>
          <a href=\"mailto:#{contact_info[:email]}\" class=\"hover:text-gray-800\">#{contact_info[:email]}</a>
        </div>"
      else
        ""
      end}
      #{if contact_info[:phone] && String.length(String.trim(contact_info[:phone])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>
          </svg>
          <a href=\"tel:#{contact_info[:phone]}\" class=\"hover:text-gray-800\">#{contact_info[:phone]}</a>
        </div>"
      else
        ""
      end}
      #{if contact_info[:location] && String.length(String.trim(contact_info[:location])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z\"/>
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 11a3 3 0 11-6 0 3 3 0 016 0z\"/>
          </svg>
          <span>#{contact_info[:location]}</span>
        </div>"
      else
        ""
      end}
      #{if contact_info[:website] && String.length(String.trim(contact_info[:website])) > 0 do
        "<div class=\"flex items-center gap-2\">
          <svg class=\"w-4 h-4\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1\"/>
          </svg>
          <a href=\"#{contact_info[:website]}\" target=\"_blank\" rel=\"noopener\" class=\"hover:text-gray-800\">#{String.replace(contact_info[:website], ~r/^https?:\/\//, "")}</a>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  # ============================================================================
  # NAVIGATION COMPONENTS
  # ============================================================================

  defp render_section_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
           class="block px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 hover:text-gray-900 rounded-md transition-colors">
          #{section.title}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_compact_nav_items(sections) do
    sections
    |> Enum.take(6)
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
           class="block px-3 py-1 text-xs text-gray-600 hover:text-gray-900 transition-colors">
          #{section.title}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_workspace_nav_items(sections) do
    sections
    |> Enum.take(5)
    |> Enum.map(fn section ->
      """
      <a href="#section-#{section.id}"
         class="text-sm text-gray-600 hover:text-gray-900 transition-colors">
        #{section.title}
      </a>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_quick_actions(portfolio, contact_info) do
    """
    <div class="space-y-2">
      #{if contact_info[:email] && String.length(String.trim(contact_info[:email])) > 0 do
        "<a href=\"mailto:#{contact_info[:email]}\" class=\"w-full px-4 py-2 text-sm bg-gray-900 text-white rounded-md hover:bg-gray-800 transition-colors block text-center\">
          Contact Me
        </a>"
      else
        "<button class=\"w-full px-4 py-2 text-sm bg-gray-900 text-white rounded-md hover:bg-gray-800 transition-colors\"
                onclick=\"alert('Contact information not available')\">
          Contact Me
        </button>"
      end}
      <button class="w-full px-4 py-2 text-sm border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors"
              onclick="window.print()">
        Download Resume
      </button>
      #{if contact_info[:website] && String.length(String.trim(contact_info[:website])) > 0 do
        "<a href=\"#{contact_info[:website]}\" target=\"_blank\" rel=\"noopener\" class=\"w-full px-4 py-2 text-sm border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors block text-center\">
          Visit Website
        </a>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_sidebar_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    """
    <div class="portfolio-layout sidebar-layout min-h-screen bg-white">
      <div class="flex">
        <!-- Sidebar Navigation -->
        <nav class="fixed left-0 top-0 w-64 h-full bg-gray-50 border-r border-gray-200 z-30 lg:block hidden">
          <div class="p-6">
            <!-- Portfolio Owner -->
            <div class="text-center mb-8">
              <div class="w-16 h-16 bg-gray-200 rounded-full mx-auto mb-3 flex items-center justify-center">
                <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                </svg>
              </div>
              <h2 class="font-semibold text-gray-900">#{portfolio.title}</h2>
            </div>

            <!-- Navigation -->
            <ul class="space-y-2">
              #{render_sidebar_nav_items(visible_sections)}
            </ul>

            <!-- Contact & Social -->
            <div class="mt-8 pt-8 border-t border-gray-200">
              #{render_sidebar_contact_social(social_links, contact_info)}
            </div>
          </div>
        </nav>

        <!-- Main Content -->
        <main class="flex-1 lg:ml-64">
          <!-- Unified Hero Section -->
          #{render_clean_hero(portfolio, sections, has_media, "sidebar")}

          <!-- Content Sections -->
          <div class="px-6 lg:px-8 py-8">
            #{render_clean_sections(sections, "sidebar", config)}
          </div>
        </main>
      </div>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # SINGLE LAYOUT - Clean single-column with floating navigation
  # ============================================================================

  defp render_single_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    """
    <div class="portfolio-layout single-layout min-h-screen bg-white">
      <!-- Floating Navigation -->
      <nav class="fixed top-6 right-6 z-40 lg:block hidden">
        <div class="bg-white rounded-lg shadow-lg border border-gray-200 p-2 max-w-xs">
          <h4 class="text-xs font-semibold text-gray-500 uppercase tracking-wider px-3 py-2">Navigation</h4>
          <ul class="space-y-1">
            #{render_compact_nav_items(visible_sections)}
          </ul>
        </div>
      </nav>

      <!-- Mobile Navigation -->
      <div class="lg:hidden fixed bottom-6 right-6 z-40">
        <button onclick="toggleFloatingNav()"
                class="p-3 bg-gray-900 text-white rounded-full shadow-lg hover:bg-gray-800">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
      </div>

      <!-- Main Content -->
      <main class="max-w-4xl mx-auto">
        <!-- Unified Hero Section -->
        #{render_clean_hero(portfolio, sections, has_media, "single")}

        <!-- Content Sections -->
        <div class="px-6 lg:px-8 py-8">
          #{render_clean_sections(sections, "single", config)}
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # WORKSPACE LAYOUT - Unique dashboard-style layout
  # ============================================================================

  defp render_workspace_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-white">
      <!-- Top Navigation Bar -->
      <nav class="fixed top-0 left-0 right-0 z-40 bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6">
          <div class="flex items-center justify-between h-16">
            <h1 class="text-xl font-bold text-gray-900">#{portfolio.title}</h1>
            <div class="flex items-center space-x-4">
              #{render_workspace_nav_items(visible_sections)}
            </div>
          </div>
        </div>
      </nav>

      <!-- Main Content with Grid -->
      <main class="pt-16 min-h-screen">
        <!-- Hero Section -->
        <div class="bg-gray-50 py-12">
          #{render_clean_hero(portfolio, sections, has_media, "workspace")}
        </div>

        <!-- Dashboard Grid -->
        <div class="max-w-7xl mx-auto px-6 py-8">
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            #{render_workspace_cards(sections, config)}
          </div>
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end


  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp render_sidebar_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
          class="flex items-center px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-lg transition-colors">
          <span class="mr-3">#{get_section_emoji(section.section_type)}</span>
          #{get_section_title(section)}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_compact_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
          class="block px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded transition-colors">
          #{get_section_title(section)}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_workspace_nav_items(sections) do
    sections
    |> Enum.take(5)  # Limit to 5 items for top nav
    |> Enum.map(fn section ->
      """
      <a href="#section-#{section.id}"
        class="text-sm text-gray-600 hover:text-gray-900 transition-colors">
        #{get_section_title(section)}
      </a>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_sidebar_contact_social(social_links, contact_info) do
    social_html = social_links
    |> Enum.map(fn {platform, url} ->
      """
      <a href="#{url}" target="_blank"
        class="flex items-center text-sm text-gray-600 hover:text-gray-900 mb-2">
        #{get_social_icon_simple(platform)}
        <span class="ml-2">#{format_platform_name(platform)}</span>
      </a>
      """
    end)
    |> Enum.join("\n")

    contact_html = if contact_info[:email] do
      """
      <a href="mailto:#{contact_info[:email]}"
        class="flex items-center text-sm text-gray-600 hover:text-gray-900 mb-2">
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        Contact
      </a>
      """
    else
      ""
    end

    social_html <> contact_html
  end


  defp render_hero_actions(portfolio) do
    """
    <div class="flex flex-col sm:flex-row gap-4 justify-center">
      <button onclick="scrollToSection('content')"
              class="px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors">
        View Portfolio
      </button>
      <button onclick="openContactModal()"
              class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors">
        Get in Touch
      </button>
    </div>
    """
  end

  defp render_clean_sections(sections, layout_type, config) do
    sections
    |> Enum.map(fn section ->
      render_clean_section_card(section, layout_type, config)
    end)
    |> Enum.join("\n")
  end

  defp render_clean_section_card(section, layout_type, config) do
    """
    <section id="section-#{section.id}" class="mb-12 scroll-mt-20">
      <div class="bg-white rounded-lg border border-gray-200 p-6 lg:p-8 shadow-sm hover:shadow-md transition-shadow">
        <div class="flex items-center mb-6">
          <div class="w-10 h-10 bg-#{config.color_scheme}-100 rounded-lg flex items-center justify-center mr-4">
            <span class="text-lg">#{get_section_emoji(section.section_type)}</span>
          </div>
          <h2 class="text-2xl font-bold text-gray-900">#{get_section_title(section)}</h2>
        </div>

        <div class="prose prose-gray max-w-none">
          #{render_section_content_safe(section)}
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

defp get_portfolio_video_url(portfolio) do
  # Safely access video_url - it might be in different locations
  video_url = case portfolio do
    %{video_url: url} when url != nil and url != "" -> url
    _ ->
      # Check if it's in customization
      customization = Map.get(portfolio, :customization, %{})
      Map.get(customization, "video_url") ||
      Map.get(customization, "intro_video") ||
      nil
  end

  case video_url do
    nil -> nil
    "" -> nil
    url -> url
  end
end

defp has_portfolio_media?(portfolio, sections) do
  # Safely check if portfolio has video
  has_video = case get_portfolio_video_url(portfolio) do
    nil -> false
    "" -> false
    _url -> true
  end

  # Check if any section has media
  has_section_media = Enum.any?(sections, fn section ->
    content = section.content || %{}
    Map.has_key?(content, "image_url") ||
    Map.has_key?(content, "video_url") ||
    Map.has_key?(content, "media_url")
  end)

  has_video || has_section_media
end

defp extract_social_links_from_portfolio(portfolio) do
  customization = portfolio.customization || %{}
  social_links = Map.get(customization, "social_links", %{})

  # Convert string keys to atoms and filter out empty values
  social_links
  |> Enum.filter(fn {_key, value} -> value && value != "" end)
  |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
end

defp extract_contact_info_from_portfolio(portfolio, sections) do
  # Try to get contact info from portfolio customization first
  customization = portfolio.customization || %{}

  contact_email = Map.get(customization, "contact_email") ||
                  Map.get(customization, "email")

  # If not found, look in contact sections
  contact_email = contact_email || find_contact_email_in_sections(sections)

  %{
    email: contact_email,
    phone: Map.get(customization, "phone"),
    location: Map.get(customization, "location")
  }
end

defp find_contact_email_in_sections(sections) do
  contact_section = Enum.find(sections, fn section ->
    String.contains?(to_string(section.section_type), "contact")
  end)

  case contact_section do
    nil -> nil
    section ->
      content = section.content || %{}
      Map.get(content, "email")
  end
end

defp get_section_emoji(section_type) do
  case to_string(section_type) do
    "about" -> "👋"
    "intro" -> "👋"
    "experience" -> "💼"
    "work_experience" -> "💼"
    "education" -> "🎓"
    "skills" -> "⚡"
    "projects" -> "🚀"
    "portfolio" -> "🎨"
    "contact" -> "📧"
    "testimonials" -> "💬"
    "certifications" -> "📜"
    "achievements" -> "🏆"
    _ -> "📄"
  end
end

defp get_section_title(section) do
  case section.content do
    %{"title" => title} when title != nil and title != "" -> title
    _ -> format_section_type_title(section.section_type)
  end
end

defp format_section_type_title(section_type) do
  section_type
  |> to_string()
  |> String.replace("_", " ")
  |> String.split(" ")
  |> Enum.map(&String.capitalize/1)
  |> Enum.join(" ")
end

defp get_section_preview(section) do
  content = section.content || %{}

  preview = Map.get(content, "summary") ||
            Map.get(content, "description") ||
            Map.get(content, "content")

  case preview do
    nil -> "Click to view details"
    text when is_binary(text) ->
      text
      |> String.slice(0, 100)
      |> then(fn truncated ->
        if String.length(text) > 100 do
          truncated <> "..."
        else
          truncated
        end
      end)
    _ -> "Click to view details"
  end
end

defp get_social_icon_simple(platform) do
  case to_string(platform) do
    "linkedin" -> """
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z"/>
      </svg>
    """
    "github" -> """
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z"/>
      </svg>
    """
    "twitter" -> """
      <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
        <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"/>
      </svg>
    """
    "email" -> """
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
      </svg>
    """
    _ -> """
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
      </svg>
    """
  end
end

defp format_platform_name(platform) do
  case to_string(platform) do
    "linkedin" -> "LinkedIn"
    "github" -> "GitHub"
    "twitter" -> "Twitter"
    "instagram" -> "Instagram"
    "email" -> "Email"
    name -> String.capitalize(name)
  end
end

defp render_about_content(content) do
  """
  #{Map.get(content, "content", Map.get(content, "description", ""))}
  """
end

defp render_experience_content(content) do
  experiences = Map.get(content, "experiences", [])

  if Enum.empty?(experiences) do
    Map.get(content, "content", "")
  else
    experiences
    |> Enum.map(fn exp ->
      """
      <div class="mb-6 pb-6 border-b border-gray-200 last:border-b-0">
        <h4 class="font-semibold text-gray-900">#{Map.get(exp, "position", "Position")}</h4>
        <p class="text-gray-600 mb-2">#{Map.get(exp, "company", "Company")} • #{Map.get(exp, "duration", "Duration")}</p>
        <p class="text-gray-700">#{Map.get(exp, "description", "")}</p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end

defp render_education_content(content) do
  education = Map.get(content, "education", [])

  if Enum.empty?(education) do
    Map.get(content, "content", "")
  else
    education
    |> Enum.map(fn edu ->
      """
      <div class="mb-4">
        <h4 class="font-semibold text-gray-900">#{Map.get(edu, "degree", "Degree")}</h4>
        <p class="text-gray-600">#{Map.get(edu, "institution", "Institution")} • #{Map.get(edu, "year", "Year")}</p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end

defp render_skills_content(content) do
  skills = Map.get(content, "skills", [])

  if Enum.empty?(skills) do
    Map.get(content, "content", "")
  else
    """
    <div class="flex flex-wrap gap-2">
      #{skills
        |> Enum.map(fn skill ->
          skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
          "<span class=\"px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm\">#{skill_name}</span>"
        end)
        |> Enum.join("\n")}
    </div>
    """
  end
end

defp render_projects_content(content) do
  projects = Map.get(content, "projects", [])

  if Enum.empty?(projects) do
    Map.get(content, "content", "")
  else
    projects
    |> Enum.map(fn project ->
      """
      <div class="mb-6 pb-6 border-b border-gray-200 last:border-b-0">
        <h4 class="font-semibold text-gray-900 mb-2">#{Map.get(project, "title", "Project")}</h4>
        <p class="text-gray-700 mb-3">#{Map.get(project, "description", "")}</p>
        #{if Map.get(project, "url") do
          "<a href=\"#{Map.get(project, "url")}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800 text-sm\">View Project →</a>"
        else
          ""
        end}
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end

defp render_contact_content(content) do
  """
  <div class="space-y-4">
    #{if Map.get(content, "email") do
      "<p class=\"flex items-center text-gray-700\">
        <svg class=\"w-4 h-4 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
          <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>
        </svg>
        <a href=\"mailto:#{Map.get(content, "email")}\" class=\"text-blue-600 hover:text-blue-800\">#{Map.get(content, "email")}</a>
      </p>"
    else
      ""
    end}

    #{if Map.get(content, "phone") do
      "<p class=\"flex items-center text-gray-700\">
        <svg class=\"w-4 h-4 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
          <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>
        </svg>
        #{Map.get(content, "phone")}
      </p>"
    else
      ""
    end}

    #{Map.get(content, "content", "")}
  </div>
  """
end

defp render_testimonials_content(content) do
  testimonials = Map.get(content, "testimonials", [])

  if Enum.empty?(testimonials) do
    Map.get(content, "content", "")
  else
    testimonials
    |> Enum.map(fn testimonial ->
      """
      <div class="mb-6 p-4 bg-gray-50 rounded-lg">
        <p class="text-gray-700 italic mb-3">"#{Map.get(testimonial, "quote", "")}"</p>
        <p class="text-gray-600 text-sm">— #{Map.get(testimonial, "author", "Anonymous")}</p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end

defp render_certifications_content(content) do
  certifications = Map.get(content, "certifications", [])

  if Enum.empty?(certifications) do
    Map.get(content, "content", "")
  else
    certifications
    |> Enum.map(fn cert ->
      """
      <div class="mb-4">
        <h4 class="font-semibold text-gray-900">#{Map.get(cert, "name", "Certification")}</h4>
        <p class="text-gray-600">#{Map.get(cert, "issuer", "Issuer")} • #{Map.get(cert, "date", "Date")}</p>
      </div>
      """
    end)
    |> Enum.join("\n")
  end
end

defp render_achievements_content(content) do
  achievements = Map.get(content, "achievements", [])

  if Enum.empty?(achievements) do
    Map.get(content, "content", "")
  else
    """
    <ul class="space-y-3">
      #{achievements
        |> Enum.map(fn achievement ->
          achievement_text = if is_map(achievement), do: Map.get(achievement, "title", achievement), else: achievement
          "<li class=\"flex items-start\">
            <span class=\"text-green-500 mr-2 mt-1\">✓</span>
            <span class=\"text-gray-700\">#{achievement_text}</span>
          </li>"
        end)
        |> Enum.join("\n")}
    </ul>
    """
  end
end

defp render_generic_content(content) do
  Map.get(content, "content", Map.get(content, "description", "No content available"))
end

# ============================================================================
# LAYOUT SCRIPTS
# ============================================================================

defp render_layout_scripts() do
  """
  <script>
    // Smooth scrolling
    function scrollToSection(sectionId) {
      const element = document.getElementById('section-' + sectionId) || document.getElementById(sectionId);
      if (element) {
        element.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }
    }

    // Mobile navigation toggle
    function toggleFloatingNav() {
      // Implementation for mobile nav toggle
      console.log('Toggle mobile navigation');
    }

    // Contact modal
    function openContactModal() {
      // Send event to LiveView to open contact modal
      window.dispatchEvent(new CustomEvent('phx:open_contact_modal'));
    }

    // Initialize layout
    document.addEventListener('DOMContentLoaded', function() {
      console.log('Portfolio layout initialized');

      // Add smooth scroll behavior to all nav links
      document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
          e.preventDefault();
          const target = document.querySelector(this.getAttribute('href'));
          if (target) {
            target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          }
        });
      });
    });
  </script>
  """
end

#####




  defp filter_visible_sections(sections) do
    Enum.filter(sections, fn section ->
      Map.get(section, :visible, true) &&
      Map.get(section, :content, %{}) != %{}
    end)
  end

  defp filter_content_sections(sections) do
    Enum.filter(sections, &(&1.visible && &1.section_type not in ["video_intro", "media_showcase"]))
  end

  defp has_portfolio_media?(portfolio, sections) do
    intro_video = find_intro_video(sections)
    intro_video != nil
  end

  defp find_intro_video(sections) do
    Enum.find(sections, fn section ->
      section.section_type in ["video_intro", "media_showcase"] &&
      section.visible &&
      (section.content && Map.get(section.content, "video_url"))
    end)
  end

  defp extract_social_links_from_portfolio(portfolio) do
    # Extract from portfolio customization (works with SocialContactEditor)
    customization = portfolio.customization || %{}
    social_links = Map.get(customization, "social_links", [])

    # Handle different formats from SocialContactEditor
    Enum.map(social_links, fn
      {platform, url} -> {platform, url}
      %{"platform" => platform, "url" => url} -> {platform, url}
      %{platform: platform, url: url} -> {platform, url}
      social_link when is_map(social_link) ->
        platform = Map.get(social_link, "platform") || Map.get(social_link, :platform)
        url = Map.get(social_link, "url") || Map.get(social_link, :url)
        if platform && url, do: {platform, url}, else: nil
      _ -> nil
    end)
    |> Enum.filter(& &1)
    |> Enum.filter(fn {_platform, url} -> url && String.length(String.trim(url)) > 0 end)
  end

  defp extract_contact_info_from_portfolio(portfolio, sections) do
    # Primary: Extract from portfolio customization (SocialContactEditor integration)
    customization = portfolio.customization || %{}

    # SocialContactEditor typically stores contact info in customization
    contact_info = %{
      email: Map.get(customization, "contact_email") || Map.get(customization, "email"),
      phone: Map.get(customization, "contact_phone") || Map.get(customization, "phone"),
      location: Map.get(customization, "location"),
      website: Map.get(customization, "website")
    }

    # Fallback: Check for contact section if customization is empty
    if !contact_info.email && !contact_info.phone do
      contact_section = Enum.find(sections, &(&1.section_type == "contact" && &1.visible))

      if contact_section do
        content = contact_section.content || %{}
        %{
          email: Map.get(content, "email"),
          phone: Map.get(content, "phone"),
          location: Map.get(content, "location") || Map.get(content, "address"),
          website: Map.get(content, "website")
        }
      else
        contact_info
      end
    else
      contact_info
    end
  end

  defp get_primary_sections(sections) do
    # Get the most important sections for main content area
    sections
    |> filter_content_sections()
    |> Enum.filter(&(&1.section_type in ["about", "experience", "projects", "skills"]))
    |> Enum.take(3)
  end

  defp get_secondary_sections(sections) do
    # Get sections for sidebar
    sections
    |> filter_content_sections()
    |> Enum.filter(&(&1.section_type in ["contact", "education", "certifications", "achievements"]))
    |> Enum.take(3)
  end

  defp filter_visible_sections(sections) do
    Enum.filter(sections, fn section ->
      Map.get(section, :is_visible, true) &&
      Map.get(section, :content, %{}) != %{}
    end)
  end

  defp get_clean_layout_config(layout_type, color_scheme) do
    %{
      layout_type: layout_type,
      color_scheme: color_scheme,
      primary_color: get_color_scheme_primary(color_scheme),
      secondary_color: get_color_scheme_secondary(color_scheme),
      accent_color: get_color_scheme_accent(color_scheme)
    }
  end

  defp get_color_scheme_primary(scheme) do
    case scheme do
      "professional" -> "#1e40af"
      "creative" -> "#7c3aed"
      "tech" -> "#059669"
      "warm" -> "#ea580c"
      _ -> "#1e40af"
    end
  end

  defp get_color_scheme_secondary(scheme) do
    case scheme do
      "professional" -> "#3b82f6"
      "creative" -> "#a855f7"
      "tech" -> "#10b981"
      "warm" -> "#f97316"
      _ -> "#3b82f6"
    end
  end

  defp get_color_scheme_accent(scheme) do
    case scheme do
      "professional" -> "#60a5fa"
      "creative" -> "#c084fc"
      "tech" -> "#34d399"
      "warm" -> "#fb923c"
      _ -> "#60a5fa"
    end
  end

  defp normalize_layout_type(layout_type) do
    layout_string = to_string(layout_type)
    IO.puts("🎨 NORMALIZING LAYOUT: #{layout_string}")

    case layout_string do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      # Legacy layout mapping
      "standard" -> :single
      "dashboard" -> :workspace
      "grid" -> :workspace
      "masonry_grid" -> :workspace
      "timeline" -> :single
      "magazine" -> :single
      "minimal" -> :single
      _ ->
        IO.puts("🎨 Unknown layout type: #{layout_string}, defaulting to single")
        :single
    end
  end

  defp normalize_layout_type(layout_type) when is_atom(layout_type), do: layout_type
  defp normalize_layout_type(_), do: :single

  defp get_clean_layout_config(layout_type, color_scheme) do
    %{
      layout_type: layout_type,
      color_scheme: color_scheme,
      primary_color: get_primary_color(color_scheme),
      text_color: "text-gray-900",
      subtext_color: "text-gray-600"
    }
  end

  defp get_primary_color(color_scheme) do
    case color_scheme do
      "professional" -> "text-blue-600"
      "creative" -> "text-purple-600"
      "tech" -> "text-green-600"
      "warm" -> "text-orange-600"
      _ -> "text-gray-900"
    end
  end

  defp get_social_icon_svg(platform) do
    case String.downcase(to_string(platform)) do
      "twitter" -> """
        <svg class="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"/>
        </svg>
        """
      "linkedin" -> """
        <svg class="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z" clip-rule="evenodd"/>
        </svg>
        """
      "github" -> """
        <svg class="w-4 h-4 text-gray-600" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"/>
        </svg>
        """
      "email" -> """
        <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """
      _ -> """
        <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """
    end
  end

  # ============================================================================
  # SECTION CONTENT RENDERING
  # ============================================================================

  defp render_section_content_safe(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "about" -> render_about_content(content)
      "intro" -> render_about_content(content)
      "experience" -> render_experience_content(content)
      "work_experience" -> render_experience_content(content)
      "projects" -> render_projects_content(content)
      "portfolio" -> render_projects_content(content)
      "skills" -> render_skills_content(content)
      "contact" -> render_contact_content(content)
      "education" -> render_education_content(content)
      "certifications" -> render_certifications_content(content)
      "achievements" -> render_achievements_content(content)
      "testimonials" -> render_testimonials_content(content)
      _ -> render_default_content(content)
    end
  end

  defp render_section_content_preview(section, size) do
    content = render_section_content_safe(section)

    case size do
      "compact" -> truncate_html_content(content, 100)
      "grid" -> truncate_html_content(content, 150)
      _ -> content
    end
  end

  defp render_about_content(content) do
    description = Map.get(content, "description", Map.get(content, "content", ""))
    if String.length(description) > 0 do
      "<div class=\"text-gray-700 leading-relaxed\">#{format_text_content(description)}</div>"
    else
      "<p class=\"text-gray-500 italic\">No content available</p>"
    end
  end

  defp render_experience_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      experience_html = items
      |> Enum.map(fn item ->
        title = Map.get(item, "title", "")
        company = Map.get(item, "company", "")
        duration = Map.get(item, "duration", "")
        description = Map.get(item, "description", "")

        """
        <div class="mb-6 pb-6 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-2">
            <h4 class="font-semibold text-gray-900">#{title}</h4>
            #{if String.length(duration) > 0 do
              "<span class=\"text-sm text-gray-500\">#{duration}</span>"
            else
              ""
            end}
          </div>
          #{if String.length(company) > 0 do
            "<p class=\"text-gray-600 mb-2\">#{company}</p>"
          else
            ""
          end}
          #{if String.length(description) > 0 do
            "<p class=\"text-gray-700 text-sm leading-relaxed\">#{description}</p>"
          else
            ""
          end}
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"experience-list\">#{experience_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No experience listed</p>"
    end
  end

  defp render_projects_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      projects_html = items
      |> Enum.map(fn item ->
        title = Map.get(item, "title", "")
        description = Map.get(item, "description", "")
        technologies = Map.get(item, "technologies", [])
        url = Map.get(item, "url", "")

        """
        <div class="mb-6 pb-6 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          <div class="flex items-start justify-between mb-2">
            <h4 class="font-semibold text-gray-900">#{title}</h4>
            #{if String.length(url) > 0 do
              "<a href=\"#{url}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800 text-sm\">
                View →
              </a>"
            else
              ""
            end}
          </div>
          #{if String.length(description) > 0 do
            "<p class=\"text-gray-700 text-sm leading-relaxed mb-3\">#{description}</p>"
          else
            ""
          end}
          #{if length(technologies) > 0 do
            tech_tags = technologies |> Enum.take(5) |> Enum.map(fn tech ->
              "<span class=\"inline-block bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded mr-2 mb-1\">#{tech}</span>"
            end) |> Enum.join("")
            "<div class=\"technologies\">#{tech_tags}</div>"
          else
            ""
          end}
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"projects-list\">#{projects_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No projects listed</p>"
    end
  end

  defp render_skills_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      skills_html = items
      |> Enum.map(fn item ->
        name = Map.get(item, "name", "")
        level = Map.get(item, "level", "")

        """
        <div class="flex items-center justify-between mb-3">
          <span class="font-medium text-gray-900">#{name}</span>
          #{if String.length(level) > 0 do
            "<span class=\"text-sm text-gray-500\">#{level}</span>"
          else
            ""
          end}
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"skills-list\">#{skills_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No skills listed</p>"
    end
  end

  defp render_contact_content(content) do
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    address = Map.get(content, "address", "")

    """
    <div class="space-y-3">
      #{if String.length(email) > 0 do
        "<div class=\"flex items-center gap-3\">
          <svg class=\"w-5 h-5 text-gray-400\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>
          </svg>
          <a href=\"mailto:#{email}\" class=\"text-gray-700 hover:text-gray-900\">#{email}</a>
        </div>"
      else
        ""
      end}
      #{if String.length(phone) > 0 do
        "<div class=\"flex items-center gap-3\">
          <svg class=\"w-5 h-5 text-gray-400\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>
          </svg>
          <a href=\"tel:#{phone}\" class=\"text-gray-700 hover:text-gray-900\">#{phone}</a>
        </div>"
      else
        ""
      end}
      #{if String.length(address) > 0 do
        "<div class=\"flex items-start gap-3\">
          <svg class=\"w-5 h-5 text-gray-400 mt-0.5\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z\"/>
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 11a3 3 0 11-6 0 3 3 0 016 0z\"/>
          </svg>
          <span class=\"text-gray-700\">#{address}</span>
        </div>"
      else
        ""
      end}
    </div>
    """
  end

  defp render_education_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      education_html = items
      |> Enum.map(fn item ->
        degree = Map.get(item, "degree", "")
        institution = Map.get(item, "institution", "")
        year = Map.get(item, "year", "")

        """
        <div class="mb-4 pb-4 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h4 class="font-semibold text-gray-900">#{degree}</h4>
              <p class="text-gray-600">#{institution}</p>
            </div>
            #{if String.length(year) > 0 do
              "<span class=\"text-sm text-gray-500 mt-1 sm:mt-0\">#{year}</span>"
            else
              ""
            end}
          </div>
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"education-list\">#{education_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No education listed</p>"
    end
  end

  defp render_certifications_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      cert_html = items
      |> Enum.map(fn item ->
        name = Map.get(item, "name", "")
        issuer = Map.get(item, "issuer", "")
        date = Map.get(item, "date", "")

        """
        <div class="mb-3 pb-3 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between">
            <div>
              <h4 class="font-medium text-gray-900">#{name}</h4>
              #{if String.length(issuer) > 0 do
                "<p class=\"text-sm text-gray-600\">#{issuer}</p>"
              else
                ""
              end}
            </div>
            #{if String.length(date) > 0 do
              "<span class=\"text-xs text-gray-500 mt-1 sm:mt-0\">#{date}</span>"
            else
              ""
            end}
          </div>
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"certifications-list\">#{cert_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No certifications listed</p>"
    end
  end

  defp render_achievements_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      achievement_html = items
      |> Enum.map(fn item ->
        title = Map.get(item, "title", "")
        description = Map.get(item, "description", "")
        date = Map.get(item, "date", "")

        """
        <div class="mb-4 pb-4 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          <div class="flex flex-col sm:flex-row sm:items-start sm:justify-between">
            <div class="flex-1">
              <h4 class="font-medium text-gray-900">#{title}</h4>
              #{if String.length(description) > 0 do
                "<p class=\"text-sm text-gray-600 mt-1\">#{description}</p>"
              else
                ""
              end}
            </div>
            #{if String.length(date) > 0 do
              "<span class=\"text-xs text-gray-500 mt-1 sm:mt-0 sm:ml-4\">#{date}</span>"
            else
              ""
            end}
          </div>
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"achievements-list\">#{achievement_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No achievements listed</p>"
    end
  end

  defp render_testimonials_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      testimonial_html = items
      |> Enum.map(fn item ->
        quote = Map.get(item, "quote", "")
        author = Map.get(item, "author", "")
        position = Map.get(item, "position", "")
        company = Map.get(item, "company", "")

        """
        <div class="mb-6 pb-6 border-b border-gray-100 last:border-b-0 last:mb-0 last:pb-0">
          #{if String.length(quote) > 0 do
            "<blockquote class=\"text-gray-700 italic mb-3\">\"#{quote}\"</blockquote>"
          else
            ""
          end}
          <div class="text-sm text-gray-600">
            #{if String.length(author) > 0 do
              "<span class=\"font-medium\">#{author}</span>"
            else
              ""
            end}
            #{if String.length(position) > 0 do
              "<span>, #{position}</span>"
            else
              ""
            end}
            #{if String.length(company) > 0 do
              "<span> at #{company}</span>"
            else
              ""
            end}
          </div>
        </div>
        """
      end)
      |> Enum.join("")

      "<div class=\"testimonials-list\">#{testimonial_html}</div>"
    else
      "<p class=\"text-gray-500 italic\">No testimonials available</p>"
    end
  end

  defp render_default_content(content) do
    description = Map.get(content, "content", Map.get(content, "description", ""))
    if String.length(description) > 0 do
      "<div class=\"text-gray-700 leading-relaxed\">#{format_text_content(description)}</div>"
    else
      "<p class=\"text-gray-500 italic\">No content available</p>"
    end
  end

  defp format_text_content(text) do
    # Basic text formatting - convert line breaks to paragraphs
    text
    |> String.split("\n\n")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(String.length(&1) > 0))
    |> Enum.map(&"<p>#{&1}</p>")
    |> Enum.join("")
  end

  defp truncate_html_content(content, max_length) do
    # Strip HTML and truncate
    plain_text = content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()

    if String.length(plain_text) > max_length do
      String.slice(plain_text, 0, max_length) <> "..."
    else
      plain_text
    end
  end

  # ============================================================================
  # SECTIONS RENDERING FUNCTIONS
  # ============================================================================

  defp render_clean_sections(sections, layout_type, config) do
    sections
    |> Enum.map(fn section ->
      render_clean_section_card(section, layout_type, config)
    end)
    |> Enum.join("\n")
  end

  defp render_clean_section_card(section, layout_type, config) do
    """
    <section id="section-#{section.id}" class="mb-12 scroll-mt-20">
      <div class="bg-white rounded-lg border border-gray-200 p-6 lg:p-8 shadow-sm hover:shadow-md transition-shadow">
        <div class="flex items-center mb-6">
          <div class="w-10 h-10 bg-#{config.color_scheme}-100 rounded-lg flex items-center justify-center mr-4">
            <span class="text-lg">#{get_section_emoji(section.section_type)}</span>
          </div>
          <h2 class="text-2xl font-bold text-gray-900">#{get_section_title(section)}</h2>
        </div>

        <div class="prose prose-gray max-w-none">
          #{render_section_content_safe(section)}
        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # UTILITY AND HELPER FUNCTIONS
  # ============================================================================

  defp has_portfolio_media?(portfolio, sections) do
    # Check if portfolio has video or if any section has media
    has_video = portfolio.video_url && portfolio.video_url != ""
    has_section_media = Enum.any?(sections, fn section ->
      content = section.content || %{}
      Map.has_key?(content, "image_url") || Map.has_key?(content, "video_url")
    end)

    has_video || has_section_media
  end

  defp get_portfolio_video_url(portfolio) do
    case portfolio.video_url do
      nil -> nil
      "" -> nil
      url -> url
    end
  end

  defp extract_social_links_from_portfolio(portfolio) do
    customization = portfolio.customization || %{}
    social_links = Map.get(customization, "social_links", %{})

    # Convert string keys to atoms and filter out empty values
    social_links
    |> Enum.filter(fn {_key, value} -> value && value != "" end)
    |> Enum.map(fn {key, value} -> {String.to_atom(key), value} end)
  end

  defp extract_contact_info_from_portfolio(portfolio, sections) do
    # Try to get contact info from portfolio customization first
    customization = portfolio.customization || %{}

    contact_email = Map.get(customization, "contact_email") ||
                    Map.get(customization, "email")

    # If not found, look in contact sections
    contact_email = contact_email || find_contact_email_in_sections(sections)

    %{
      email: contact_email,
      phone: Map.get(customization, "phone"),
      location: Map.get(customization, "location")
    }
  end

  defp find_contact_email_in_sections(sections) do
    contact_section = Enum.find(sections, fn section ->
      String.contains?(to_string(section.section_type), "contact")
    end)

    case contact_section do
      nil -> nil
      section ->
        content = section.content || %{}
        Map.get(content, "email")
    end
  end

  defp get_section_emoji(section_type) do
    case to_string(section_type) do
      "about" -> "👋"
      "intro" -> "👋"
      "experience" -> "💼"
      "work_experience" -> "💼"
      "education" -> "🎓"
      "skills" -> "⚡"
      "projects" -> "🚀"
      "portfolio" -> "🎨"
      "contact" -> "📧"
      "testimonials" -> "💬"
      "certifications" -> "📜"
      "achievements" -> "🏆"
      _ -> "📄"
    end
  end

  defp get_section_title(section) do
    case section.content do
      %{"title" => title} when title != nil and title != "" -> title
      _ -> format_section_type_title(section.section_type)
    end
  end

  defp format_section_type_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_section_preview(section) do
    content = section.content || %{}

    preview = Map.get(content, "summary") ||
              Map.get(content, "description") ||
              Map.get(content, "content")

    case preview do
      nil -> "Click to view details"
      text when is_binary(text) ->
        text
        |> String.slice(0, 120)
        |> then(fn truncated ->
          if String.length(text) > 120 do
            truncated <> "..."
          else
            truncated
          end
        end)
      _ -> "Click to view details"
    end
  end

  defp get_section_category(section_type) do
    case to_string(section_type) do
      "about" -> "Introduction"
      "intro" -> "Introduction"
      "experience" -> "Professional"
      "work_experience" -> "Professional"
      "education" -> "Academic"
      "skills" -> "Technical"
      "projects" -> "Portfolio"
      "portfolio" -> "Portfolio"
      "contact" -> "Contact"
      "testimonials" -> "Social Proof"
      "certifications" -> "Credentials"
      "achievements" -> "Recognition"
      _ -> "Content"
    end
  end

  defp get_social_icon_simple(platform) do
    case to_string(platform) do
      "linkedin" -> """
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z"/>
        </svg>
      """
      "github" -> """
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z"/>
        </svg>
      """
      "twitter" -> """
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"/>
        </svg>
      """
      "email" -> """
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
      """
      _ -> """
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
      """
    end
  end

  defp format_platform_name(platform) do
    case to_string(platform) do
      "linkedin" -> "LinkedIn"
      "github" -> "GitHub"
      "twitter" -> "Twitter"
      "instagram" -> "Instagram"
      "email" -> "Email"
      name -> String.capitalize(name)
    end
  end

  defp get_color_scheme_primary(scheme) do
    case scheme do
      "professional" -> "#1e40af"
      "creative" -> "#7c3aed"
      "tech" -> "#059669"
      "warm" -> "#ea580c"
      _ -> "#1e40af"
    end
  end

  defp get_color_scheme_secondary(scheme) do
    case scheme do
      "professional" -> "#3b82f6"
      "creative" -> "#a855f7"
      "tech" -> "#10b981"
      "warm" -> "#f97316"
      _ -> "#3b82f6"
    end
  end

  defp get_color_scheme_accent(scheme) do
    case scheme do
      "professional" -> "#60a5fa"
      "creative" -> "#c084fc"
      "tech" -> "#34d399"
      "warm" -> "#fb923c"
      _ -> "#60a5fa"
    end
  end

  # ============================================================================
  # SECTION CONTENT RENDERING FUNCTIONS
  # ============================================================================

  defp render_section_content_safe(section) do
    content = section.content || %{}

    case to_string(section.section_type) do
      "about" -> render_about_content(content)
      "intro" -> render_about_content(content)
      "experience" -> render_experience_content(content)
      "work_experience" -> render_experience_content(content)
      "education" -> render_education_content(content)
      "skills" -> render_skills_content(content)
      "projects" -> render_projects_content(content)
      "portfolio" -> render_projects_content(content)
      "contact" -> render_contact_content(content)
      "testimonials" -> render_testimonials_content(content)
      "certifications" -> render_certifications_content(content)
      "achievements" -> render_achievements_content(content)
      _ -> render_generic_content(content)
    end
  end

  defp render_about_content(content) do
    """
    #{Map.get(content, "content", Map.get(content, "description", ""))}
    """
  end

  defp render_experience_content(content) do
    experiences = Map.get(content, "experiences", [])

    if Enum.empty?(experiences) do
      Map.get(content, "content", "")
    else
      experiences
      |> Enum.map(fn exp ->
        """
        <div class="mb-6 pb-6 border-b border-gray-200 last:border-b-0">
          <h4 class="font-semibold text-gray-900">#{Map.get(exp, "position", "Position")}</h4>
          <p class="text-gray-600 mb-2">#{Map.get(exp, "company", "Company")} • #{Map.get(exp, "duration", "Duration")}</p>
          <p class="text-gray-700">#{Map.get(exp, "description", "")}</p>
        </div>
        """
      end)
      |> Enum.join("\n")
    end
  end

  defp render_education_content(content) do
    education = Map.get(content, "education", [])

    if Enum.empty?(education) do
      Map.get(content, "content", "")
    else
      education
      |> Enum.map(fn edu ->
        """
        <div class="mb-4">
          <h4 class="font-semibold text-gray-900">#{Map.get(edu, "degree", "Degree")}</h4>
          <p class="text-gray-600">#{Map.get(edu, "institution", "Institution")} • #{Map.get(edu, "year", "Year")}</p>
        </div>
        """
      end)
      |> Enum.join("\n")
    end
  end

  defp render_skills_content(content) do
    skills = Map.get(content, "skills", [])

    if Enum.empty?(skills) do
      Map.get(content, "content", "")
    else
      """
      <div class="flex flex-wrap gap-2">
        #{skills
          |> Enum.map(fn skill ->
            skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
            "<span class=\"px-3 py-1 bg-gray-100 text-gray-700 rounded-full text-sm\">#{skill_name}</span>"
          end)
          |> Enum.join("\n")}
      </div>
      """
    end
  end

  defp render_projects_content(content) do
    projects = Map.get(content, "projects", [])

    if Enum.empty?(projects) do
      Map.get(content, "content", "")
    else
      projects
      |> Enum.map(fn project ->
        """
        <div class="mb-6 pb-6 border-b border-gray-200 last:border-b-0">
          <h4 class="font-semibold text-gray-900 mb-2">#{Map.get(project, "title", "Project")}</h4>
          <p class="text-gray-700 mb-3">#{Map.get(project, "description", "")}</p>
          #{if Map.get(project, "url") do
            "<a href=\"#{Map.get(project, "url")}\" target=\"_blank\" class=\"text-blue-600 hover:text-blue-800 text-sm\">View Project →</a>"
          else
            ""
          end}
        </div>
        """
      end)
      |> Enum.join("\n")
    end
  end

  defp render_contact_content(content) do
    """
    <div class="space-y-4">
      #{if Map.get(content, "email") do
        "<p class=\"flex items-center text-gray-700\">
          <svg class=\"w-4 h-4 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/>
          </svg>
          <a href=\"mailto:#{Map.get(content, "email")}\" class=\"text-blue-600 hover:text-blue-800\">#{Map.get(content, "email")}</a>
        </p>"
      else
        ""
      end}

      #{if Map.get(content, "phone") do
        "<p class=\"flex items-center text-gray-700\">
          <svg class=\"w-4 h-4 mr-2\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\">
            <path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z\"/>
          </svg>
          #{Map.get(content, "phone")}
        </p>"
      else
        ""
      end}

      #{Map.get(content, "content", "")}
    </div>
    """
  end

  defp render_testimonials_content(content) do
    testimonials = Map.get(content, "testimonials", [])

    if Enum.empty?(testimonials) do
      Map.get(content, "content", "")
    else
      testimonials
      |> Enum.map(fn testimonial ->
        """
        <div class="mb-6 p-4 bg-gray-50 rounded-lg">
          <p class="text-gray-700 italic mb-3">"#{Map.get(testimonial, "quote", "")}"</p>
          <p class="text-gray-600 text-sm">— #{Map.get(testimonial, "author", "Anonymous")}</p>
        </div>
        """
      end)
      |> Enum.join("\n")
    end
  end

  defp render_certifications_content(content) do
    certifications = Map.get(content, "certifications", [])

    if Enum.empty?(certifications) do
      Map.get(content, "content", "")
    else
      certifications
      |> Enum.map(fn cert ->
        """
        <div class="mb-4">
          <h4 class="font-semibold text-gray-900">#{Map.get(cert, "name", "Certification")}</h4>
          <p class="text-gray-600">#{Map.get(cert, "issuer", "Issuer")} • #{Map.get(cert, "date", "Date")}</p>
        </div>
        """
      end)
      |> Enum.join("\n")
    end
  end

  defp render_achievements_content(content) do
    achievements = Map.get(content, "achievements", [])

    if Enum.empty?(achievements) do
      Map.get(content, "content", "")
    else
      """
      <ul class="space-y-3">
        #{achievements
          |> Enum.map(fn achievement ->
            achievement_text = if is_map(achievement), do: Map.get(achievement, "title", achievement), else: achievement
            "<li class=\"flex items-start\">
              <span class=\"text-green-500 mr-2 mt-1\">✓</span>
              <span class=\"text-gray-700\">#{achievement_text}</span>
            </li>"
          end)
          |> Enum.join("\n")}
      </ul>
      """
    end
  end

  defp render_generic_content(content) do
    Map.get(content, "content", Map.get(content, "description", "No content available"))
  end

  # ============================================================================
  # LAYOUT SCRIPTS
  # ============================================================================

  defp render_layout_scripts() do
    """
    <script>
      // Smooth scrolling
      function scrollToSection(sectionId) {
        const element = document.getElementById('section-' + sectionId) || document.getElementById(sectionId);
        if (element) {
          element.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      }

      // Mobile navigation toggle
      function toggleFloatingNav() {
        console.log('Toggle mobile navigation');
      }

      // Contact modal
      function openContactModal() {
        window.dispatchEvent(new CustomEvent('phx:open_contact_modal'));
      }

      // Initialize layout
      document.addEventListener('DOMContentLoaded', function() {
        console.log('Portfolio layout initialized');

        // Add smooth scroll behavior to all nav links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
          anchor.addEventListener('click', function (e) {
            e.preventDefault();
            const target = document.querySelector(this.getAttribute('href'));
            if (target) {
              target.scrollIntoView({ behavior: 'smooth', block: 'start' });
            }
          });
        });
      });
    </script>
    """
  end
end
