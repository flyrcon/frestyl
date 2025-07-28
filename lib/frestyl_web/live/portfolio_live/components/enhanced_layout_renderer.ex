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
    # Filter visible sections for navigation
    visible_sections = filter_visible_sections(sections)

    # Get clean layout configuration
    layout_config = get_clean_layout_config(layout_type, color_scheme)

    # Render based on layout type
    case normalize_layout_type(layout_type) do
      :sidebar -> render_sidebar_layout(portfolio, sections, visible_sections, layout_config)
      :single -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :workspace -> render_workspace_layout(portfolio, sections, visible_sections, layout_config)
      # Legacy support - map old layout names to new ones
      :standard -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :dashboard -> render_workspace_layout(portfolio, sections, visible_sections, layout_config)
      :grid -> render_workspace_layout(portfolio, sections, visible_sections, layout_config)
      :timeline -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :magazine -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :minimal -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      _ -> render_single_layout(portfolio, sections, visible_sections, layout_config)
    end
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
    primary_sections = get_primary_sections(sections)
    secondary_sections = get_secondary_sections(sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-gray-50">
      <!-- Workspace Header -->
      <header class="bg-white border-b border-gray-200 sticky top-0 z-30">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center justify-between">
            #{render_unified_workspace_header(portfolio, social_links, contact_info)}

            <!-- Workspace Nav -->
            <nav class="hidden lg:flex items-center space-x-6">
              #{render_workspace_nav_items(visible_sections)}
            </nav>

            <!-- Mobile Menu Button -->
            <button onclick="toggleWorkspaceMenu()" class="lg:hidden p-2 text-gray-600 hover:text-gray-900">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
              </svg>
            </button>
          </div>
        </div>
      </header>

      <!-- Hero Section -->
      #{render_clean_hero(portfolio, sections, has_media, "workspace")}

      <!-- Workspace Grid -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <!-- Primary Content Grid -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-8">
          <!-- Main Content Column -->
          <div class="lg:col-span-2 space-y-6">
            #{render_primary_workspace_sections(primary_sections, config)}
          </div>

          <!-- Sidebar Column -->
          <div class="space-y-6">
            #{render_secondary_workspace_sections(secondary_sections, config)}
          </div>
        </div>

        <!-- Additional Sections -->
        #{if length(sections) > length(primary_sections) + length(secondary_sections) do
          render_additional_workspace_sections(sections -- primary_sections -- secondary_sections, config)
        else
          ""
        end}
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
    defp render_clean_hero(portfolio, sections, has_media, layout_type) do
    intro_video = find_intro_video(sections)
    social_links = extract_social_links_from_portfolio(portfolio)
    contact_info = extract_contact_info_from_portfolio(portfolio, sections)

    # Determine hero height based on content
    hero_height = cond do
      intro_video && Map.get(intro_video.content || %{}, "video_url") -> "min-h-[500px]"
      has_media -> "min-h-[400px]"
      true -> "py-16"
    end

    hero_bg = case layout_type do
      "workspace" -> "bg-white border-b border-gray-200"
      _ -> "bg-white border-b border-gray-100"
    end

    """
    <section class="hero-section #{hero_height} #{hero_bg}">
      <div class="max-w-4xl mx-auto px-6 lg:px-8 py-8">
        #{if intro_video do
          render_video_hero(portfolio, intro_video, social_links, contact_info, layout_type)
        else
          render_text_hero(portfolio, social_links, contact_info, layout_type)
        end}
      </div>
    </section>
    """
  end

  defp render_video_hero(portfolio, video_section, social_links, contact_info, layout_type) do
    video_content = video_section.content || %{}
    video_url = Map.get(video_content, "video_url")

    """
    <div class="flex flex-col lg:flex-row items-center gap-8">
      <!-- Video -->
      <div class="flex-1">
        #{if video_url do
          "<div class=\"aspect-video bg-gray-100 rounded-lg overflow-hidden shadow-sm\">
            <video controls class=\"w-full h-full object-cover\">
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
    """
  end

  defp render_text_hero(portfolio, social_links, contact_info, layout_type) do
    """
    <div class="text-center max-w-3xl mx-auto">
      <h1 class="text-3xl lg:text-5xl font-bold text-gray-900 mb-6">#{portfolio.title}</h1>
      #{if portfolio.description do
        "<p class=\"text-xl text-gray-600 leading-relaxed mb-8\">#{portfolio.description}</p>"
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
    """
  end

  defp render_hero_social_contact(social_links, contact_info) do
    """
    <div class="flex flex-col sm:flex-row items-center justify-center gap-6 mb-8">
      #{if length(social_links) > 0 do
        render_hero_social_links(social_links)
      else
        ""
      end}

      #{if contact_info[:email] || contact_info[:phone] do
        render_hero_contact_info(contact_info)
      else
        ""
      end}
    </div>
    """
  end

  defp render_hero_actions(portfolio) do
    """
    <div class="flex flex-col sm:flex-row items-center justify-center gap-4">
      <button class="px-6 py-3 bg-gray-900 text-white rounded-lg hover:bg-gray-800 transition-colors font-medium">
        Get in Touch
      </button>
      <button class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors font-medium">
        View Work
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

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp filter_visible_sections(sections) do
    Enum.filter(sections, &(&1.visible && &1.section_type not in ["video_intro", "media_showcase"]))
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

  defp normalize_layout_type(layout_type) when is_binary(layout_type) do
    case String.downcase(layout_type) do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      # Legacy mappings
      "standard" -> :single
      "dashboard" -> :workspace
      "grid" -> :workspace
      "timeline" -> :single
      "magazine" -> :single
      "minimal" -> :single
      _ -> :single
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
  # LAYOUT SCRIPTS
  # ============================================================================

  defp render_layout_scripts() do
    """
    <script>
      // Mobile navigation for sidebar layout
      function toggleMobileNav() {
        const sidebar = document.getElementById('portfolio-sidebar');
        const overlay = document.getElementById('mobile-overlay');

        if (sidebar && overlay) {
          if (sidebar.classList.contains('-translate-x-full')) {
            sidebar.classList.remove('-translate-x-full');
            overlay.classList.remove('hidden');
          } else {
            sidebar.classList.add('-translate-x-full');
            overlay.classList.add('hidden');
          }
        }
      }

      // Floating navigation for single layout
      function toggleFloatingNav() {
        console.log('Toggle floating navigation');
        // Could expand for mobile menu
      }

      // Workspace menu for workspace layout
      function toggleWorkspaceMenu() {
        console.log('Toggle workspace menu');
        // Could expand for mobile menu
      }

      // Smooth scrolling for navigation links
      document.addEventListener('DOMContentLoaded', function() {
        const links = document.querySelectorAll('a[href^="#section-"]');
        links.forEach(link => {
          link.addEventListener('click', function(e) {
            e.preventDefault();
            const targetId = this.getAttribute('href').substring(1);
            const targetElement = document.getElementById(targetId);
            if (targetElement) {
              targetElement.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
              });

              // Close mobile nav if open
              const sidebar = document.getElementById('portfolio-sidebar');
              const overlay = document.getElementById('mobile-overlay');
              if (sidebar && overlay && !sidebar.classList.contains('-translate-x-full')) {
                sidebar.classList.add('-translate-x-full');
                overlay.classList.add('hidden');
              }
            }
          });
        });
      });

      // Close mobile nav when clicking overlay
      document.addEventListener('DOMContentLoaded', function() {
        const overlay = document.getElementById('mobile-overlay');
        if (overlay) {
          overlay.addEventListener('click', toggleMobileNav);
        }
      });
    </script>
    """
  end
end
