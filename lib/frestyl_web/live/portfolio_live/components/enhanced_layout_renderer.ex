# lib/frestyl_web/live/portfolio_live/components/enhanced_layout_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer do
  @moduledoc """
  Revamped portfolio layout renderer that properly integrates with EnhancedSectionRenderer.
  Supports 3 clean layouts: Sidebar, Single, and Workspace.
  Maintains Frestyl design philosophy: clean shadows, NO borders, NO icons, responsive design.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer

  # ============================================================================
  # MAIN LAYOUT RENDERER - Fixed Integration
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme, video_options \\ %{}) do
    IO.puts("🎨 ENHANCED LAYOUT RENDERER - REVAMPED VERSION")
    IO.puts("🎨 Portfolio: #{portfolio.title}")
    IO.puts("🎨 Layout: #{layout_type}")
    IO.puts("🎨 Sections count: #{length(sections || [])}")

    # Normalize inputs
    clean_sections = normalize_sections_for_rendering(sections)
    visible_sections = filter_visible_sections(clean_sections)
    layout_config = get_layout_config(layout_type, color_scheme, theme)

    IO.puts("🎨 Using EnhancedSectionRenderer for all content")

    # Route to appropriate layout renderer
    case normalize_layout_type(layout_type) do
      :sidebar -> render_sidebar_layout_revamped(portfolio, clean_sections, visible_sections, layout_config)
      :single -> render_single_layout_revamped(portfolio, clean_sections, visible_sections, layout_config)
      :workspace -> render_workspace_layout_revamped(portfolio, clean_sections, visible_sections, layout_config)
      _ -> render_single_layout_revamped(portfolio, clean_sections, visible_sections, layout_config)
    end
  end

  # ============================================================================
  # SECTION CONTENT RENDERING - Fixed Integration
  # ============================================================================

  defp render_enhanced_section_content(section) do
    IO.puts("🔄 Rendering section #{section.id} (#{section.section_type}) with EnhancedSectionRenderer")

    # Let EnhancedSectionRenderer handle everything - it already has normalization
    content = EnhancedSectionRenderer.render_section_content_static(section, %{})

    IO.puts("✅ Enhanced rendering completed for section #{section.id}")
    content
  end

  # Normalize {:safe, content} tuples in section content
  defp normalize_safe_content_tuples(section) do
    normalized_content = deep_normalize_safe_tuples(section.content || %{})
    Map.put(section, :content, normalized_content)
  end

  # Recursively normalize {:safe, content} tuples in nested data structures
  defp deep_normalize_safe_tuples(data) when is_map(data) do
    data
    |> Enum.map(fn {key, value} ->
      {key, deep_normalize_safe_tuples(value)}
    end)
    |> Enum.into(%{})
  end

  defp deep_normalize_safe_tuples(data) when is_list(data) do
    Enum.map(data, &deep_normalize_safe_tuples/1)
  end

  defp deep_normalize_safe_tuples({:safe, content}) when is_binary(content) do
    content
  end

  defp deep_normalize_safe_tuples({:safe, content}) when is_list(content) do
    Enum.join(content, "")
  end

  defp deep_normalize_safe_tuples(data), do: data

  defp render_fallback_section_content(section) do
    """
    <div class="fallback-content p-4 bg-gray-50 rounded-lg">
      <h4 class="font-medium text-gray-900 mb-2">#{section.title}</h4>
      <p class="text-gray-600">Section content temporarily unavailable. (Type: #{section.section_type})</p>
    </div>
    """
  end

  # ============================================================================
  # SIDEBAR LAYOUT - Clean with left navigation
  # ============================================================================

  defp render_sidebar_layout_revamped(portfolio, sections, visible_sections, config) do
    """
    <div class="portfolio-layout sidebar-layout min-h-screen bg-white">
      <!-- Mobile Navigation Toggle -->
      <div class="lg:hidden fixed top-4 left-4 z-50">
        <button onclick="toggleMobileNav()"
                class="p-3 bg-white rounded-lg shadow-md hover:shadow-lg transition-shadow">
          <svg class="w-5 h-5 text-gray-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
      </div>

      <div class="flex">
        <!-- Sidebar Navigation -->
        <aside id="portfolio-sidebar"
               class="fixed lg:sticky top-0 left-0 w-80 h-screen bg-white shadow-lg overflow-y-auto z-40 transform -translate-x-full lg:translate-x-0 transition-transform duration-300">

          <!-- Portfolio Header in Sidebar -->
          <div class="p-6">
            <div class="text-center">
              #{render_portfolio_avatar(portfolio)}
              <h1 class="text-xl font-bold text-gray-900 mt-3">#{portfolio.title}</h1>
              #{render_portfolio_tagline(portfolio)}
            </div>
          </div>

          <!-- Section Navigation -->
          <nav class="p-4">
            <ul class="space-y-1">
              #{render_sidebar_nav_items(visible_sections)}
            </ul>
          </nav>

          <!-- Contact Info -->
          #{render_sidebar_footer(portfolio)}
        </aside>

        <!-- Main Content -->
        <main class="flex-1 lg:ml-0">
          <!-- Hero Section -->
          #{render_hero_section(portfolio, "sidebar")}

          <!-- Enhanced Sections -->
          <div class="max-w-4xl mx-auto px-6 lg:px-8 py-8">
            #{render_enhanced_sections(sections, "sidebar", config)}
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
  # SINGLE LAYOUT - Clean single-column
  # ============================================================================

  defp render_single_layout_revamped(portfolio, sections, visible_sections, config) do
    """
    <div class="portfolio-layout single-layout min-h-screen bg-white">
      <!-- Floating Navigation -->
      <nav class="fixed top-6 right-6 z-40 lg:block hidden">
        <div class="bg-white rounded-xl shadow-lg p-3 max-w-xs">
          <ul class="space-y-1">
            #{render_floating_nav_items(visible_sections)}
          </ul>
        </div>
      </nav>

      <!-- Mobile Navigation -->
      <div class="lg:hidden fixed bottom-6 right-6 z-40">
        <button onclick="toggleFloatingNav()"
                class="p-3 bg-gray-900 text-white rounded-full shadow-lg hover:bg-gray-800 transition-colors">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        </button>
      </div>

      <!-- Main Content -->
      <main class="max-w-4xl mx-auto">
        <!-- Hero Section -->
        #{render_hero_section(portfolio, "single")}

        <!-- Enhanced Sections -->
        <div class="px-6 lg:px-8 py-8">
          #{render_enhanced_sections(sections, "single", config)}
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # WORKSPACE LAYOUT - Dynamic dashboard-style (NO uniform grid)
  # ============================================================================

  defp render_workspace_layout_revamped(portfolio, sections, visible_sections, config) do
    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-white">
      <!-- Top Navigation Bar -->
      <nav class="fixed top-0 left-0 right-0 z-40 bg-white shadow-sm">
        <div class="max-w-7xl mx-auto px-6">
          <div class="flex items-center justify-between h-16">
            <h1 class="text-xl font-bold text-gray-900">#{portfolio.title}</h1>
            <div class="flex items-center space-x-6">
              #{render_workspace_nav_items(visible_sections)}
            </div>
          </div>
        </div>
      </nav>

      <!-- Main Content -->
      <main class="pt-16 min-h-screen">
        <!-- Hero Section -->
        <div class="bg-gray-50 py-12">
          #{render_hero_section(portfolio, "workspace")}
        </div>

        <!-- Dynamic Dashboard Layout (Original Style) -->
        <div class="max-w-7xl mx-auto px-6 py-8">
          #{render_workspace_dynamic_sections(sections, config)}
        </div>
      </main>

      #{render_layout_scripts()}
    </div>
    """
  end

  # ============================================================================
  # ENHANCED SECTIONS RENDERING - Core Integration (NO BORDERS, NO ICONS)
  # ============================================================================

  defp render_enhanced_sections(sections, layout_type, config) do
    sections
    |> filter_content_sections()
    |> Enum.map(&render_enhanced_section_wrapper(&1, layout_type, config))
    |> Enum.join("\n")
  end

  defp render_enhanced_section_wrapper(section, layout_type, config) do
    enhanced_content = render_enhanced_section_content(section)

    """
    <section id="section-#{section.id}"
             class="enhanced-section bg-white rounded-lg p-6 lg:p-8 mb-6 last:mb-0 shadow-md hover:shadow-lg transition-shadow duration-200"
             data-section-type="#{section.section_type}">

      <!-- Section Header (NO ICONS) -->
      <header class="section-header mb-6">
        <h2 class="text-2xl font-bold text-gray-900">#{section.title}</h2>
      </header>

      <!-- Enhanced Section Content -->
      <div class="enhanced-content">
        #{enhanced_content}
      </div>
    </section>
    """
  end

  # ============================================================================
  # WORKSPACE DYNAMIC LAYOUT (Restore Original Variable Sizing)
  # ============================================================================

  defp render_workspace_dynamic_sections(sections, config) do
    # Split sections into different groups for dynamic layout
    {primary_sections, secondary_sections, additional_sections} = split_sections_for_workspace(sections)

    """
    <!-- Primary Sections (Large Cards) -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
      #{primary_sections |> Enum.map(&render_workspace_large_card(&1, config)) |> Enum.join("\n")}
    </div>

    <!-- Secondary Sections (Medium Cards) -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
      #{secondary_sections |> Enum.map(&render_workspace_medium_card(&1, config)) |> Enum.join("\n")}
    </div>

    <!-- Additional Sections (Compact Cards) -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      #{additional_sections |> Enum.map(&render_workspace_compact_card(&1, config)) |> Enum.join("\n")}
    </div>
    """
  end

  defp split_sections_for_workspace(sections) do
    # First 2 sections get large cards
    primary = Enum.take(sections, 2)

    # Next 3 sections get medium cards
    secondary = sections |> Enum.drop(2) |> Enum.take(3)

    # Remaining sections get compact cards
    additional = Enum.drop(sections, 5)

    {primary, secondary, additional}
  end

  defp render_workspace_large_card(section, config) do
    enhanced_content = render_enhanced_section_content(section)

    """
    <div id="section-#{section.id}"
         class="workspace-large-card bg-white rounded-xl p-8 shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer"
         onclick="scrollToSection('#{section.id}')">

      <div class="mb-6">
        <h3 class="text-xl font-semibold text-gray-900 mb-2">#{section.title}</h3>
      </div>

      <div class="card-content">
        #{enhanced_content}
      </div>
    </div>
    """
  end

  defp render_workspace_medium_card(section, config) do
    enhanced_content = render_enhanced_section_content(section)

    """
    <div id="section-#{section.id}"
         class="workspace-medium-card bg-white rounded-xl p-6 shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer"
         onclick="scrollToSection('#{section.id}')">

      <div class="mb-4">
        <h3 class="text-lg font-semibold text-gray-900 mb-1">#{section.title}</h3>
      </div>

      <div class="card-content">
        #{enhanced_content}
      </div>
    </div>
    """
  end

  defp render_workspace_compact_card(section, config) do
    enhanced_content = render_enhanced_section_content(section)

    """
    <div id="section-#{section.id}"
         class="workspace-compact-card bg-white rounded-lg p-4 shadow-md hover:shadow-lg transition-all duration-300 cursor-pointer"
         onclick="scrollToSection('#{section.id}')">

      <div class="mb-3">
        <h3 class="text-base font-semibold text-gray-900">#{section.title}</h3>
      </div>

      <div class="card-content text-sm">
        #{enhanced_content}
      </div>
    </div>
    """
  end

  # ============================================================================
  # HERO SECTION RENDERING (NO BORDERS)
  # ============================================================================

  defp render_hero_section(portfolio, layout_type) do
    case layout_type do
      "sidebar" ->
        """
        <div class="hero-section bg-gray-50 py-12">
          <div class="max-w-4xl mx-auto px-6 lg:px-8 text-center">
            <p class="text-lg text-gray-600">#{portfolio.description || "Professional Portfolio"}</p>
          </div>
        </div>
        """

      "workspace" ->
        """
        <div class="max-w-7xl mx-auto px-6 text-center">
          <h1 class="text-3xl font-bold text-gray-900 mb-4">#{portfolio.title}</h1>
          <p class="text-xl text-gray-600 max-w-3xl mx-auto">#{portfolio.description || "Welcome to my portfolio"}</p>
        </div>
        """

      _ ->
        """
        <div class="hero-section py-16 lg:py-24">
          <div class="max-w-4xl mx-auto px-6 lg:px-8 text-center">
            <h1 class="text-4xl lg:text-5xl font-bold text-gray-900 mb-6">#{portfolio.title}</h1>
            <p class="text-xl text-gray-600 max-w-3xl mx-auto mb-8">#{portfolio.description || "Welcome to my portfolio"}</p>
          </div>
        </div>
        """
    end
  end

  # ============================================================================
  # NAVIGATION RENDERING (NO ICONS)
  # ============================================================================

  defp render_sidebar_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
           class="block px-3 py-2 text-sm text-gray-700 rounded-lg hover:bg-gray-100 transition-colors">
          #{section.title}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_floating_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
           class="block px-3 py-2 text-sm text-gray-700 rounded-lg hover:bg-gray-100 transition-colors">
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

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp normalize_sections_for_rendering(sections) do
    sections
    |> Enum.filter(fn section ->
      section && Map.get(section, :id) && Map.get(section, :title)
    end)
    |> Enum.map(&normalize_section_data/1)
  end

  defp normalize_section_data(section) do
    section
    |> Map.put_new(:content, %{})
    |> Map.put_new(:section_type, "about")
    |> Map.put_new(:title, "Untitled Section")
  end

  defp filter_visible_sections(sections) do
    sections
    |> Enum.filter(fn section ->
      !Map.get(section, :hidden, false)
    end)
  end

  defp filter_content_sections(sections) do
    sections
    |> Enum.filter(fn section ->
      section.section_type != "hero" && !is_empty_section?(section)
    end)
  end

  defp is_empty_section?(section) do
    content = section.content || %{}
    case content do
      %{} when map_size(content) == 0 -> true
      _ -> false
    end
  end

  defp normalize_layout_type(layout_type) do
    case to_string(layout_type) |> String.downcase() do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      _ -> :single
    end
  end

  defp get_layout_config(layout_type, color_scheme, theme) do
    %{
      layout_type: layout_type,
      color_scheme: color_scheme || "blue",
      theme: theme || "light",
      spacing: "comfortable"
    }
  end

  defp format_section_type_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp render_portfolio_avatar(portfolio) do
    if Map.get(portfolio, :avatar_url) do
      """
      <img src="#{portfolio.avatar_url}"
           alt="#{portfolio.title}"
           class="w-16 h-16 rounded-full mx-auto object-cover shadow-sm">
      """
    else
      """
      <div class="w-16 h-16 bg-gray-200 rounded-full mx-auto flex items-center justify-center shadow-sm">
        <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
      </div>
      """
    end
  end

  defp render_portfolio_tagline(portfolio) do
    if tagline = Map.get(portfolio, :tagline) do
      """
      <p class="text-sm text-gray-600 mt-2">#{tagline}</p>
      """
    else
      ""
    end
  end

  defp render_sidebar_footer(portfolio) do
    """
    <div class="p-4 mt-auto">
      <div class="text-center">
        <p class="text-xs text-gray-500">Portfolio by #{portfolio.title}</p>
      </div>
    </div>
    """
  end

  defp render_layout_scripts() do
    """
    <script>
      function toggleMobileNav() {
        const sidebar = document.getElementById('portfolio-sidebar');
        const overlay = document.getElementById('mobile-overlay');

        if (sidebar && overlay) {
          sidebar.classList.toggle('-translate-x-full');
          overlay.classList.toggle('hidden');
        }
      }

      function toggleFloatingNav() {
        const nav = document.querySelector('.fixed.top-6.right-6 nav');
        if (nav) {
          nav.classList.toggle('hidden');
        }
      }

      function scrollToSection(sectionId) {
        const section = document.getElementById('section-' + sectionId);
        if (section) {
          section.scrollIntoView({ behavior: 'smooth' });
        }
      }

      document.addEventListener('click', function(e) {
        if (e.target.tagName === 'A' && e.target.getAttribute('href').startsWith('#')) {
          const sidebar = document.getElementById('portfolio-sidebar');
          const overlay = document.getElementById('mobile-overlay');

          if (sidebar && overlay && window.innerWidth < 1024) {
            sidebar.classList.add('-translate-x-full');
            overlay.classList.add('hidden');
          }
        }
      });
    </script>
    """
  end
end
