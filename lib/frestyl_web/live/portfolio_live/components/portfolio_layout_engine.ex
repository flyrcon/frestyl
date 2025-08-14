# File: lib/frestyl_web/live/portfolio_live/components/portfolio_layout_engine.ex
# UPDATED: Add Time Machine (5th) and Grid (6th) layout support

defmodule FrestylWeb.PortfolioLive.Components.PortfolioLayoutEngine do
  @moduledoc """
  Enhanced portfolio layout engine with 5 focused layouts:
  Sidebar, Single, Workspace, Time Machine, and Grid.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.{DynamicSectionModal, EnhancedPortfolioLayouts}

  # ============================================================================
  # MAIN LAYOUT RENDERER - UPDATED WITH NEW LAYOUTS
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme) do
    # Filter visible sections for navigation
    visible_sections = filter_visible_sections(sections)

    # Get customization from portfolio
    customization = portfolio.customization || %{}

    # Route to appropriate layout renderer
    case normalize_layout_type(layout_type) do
      :sidebar -> render_sidebar_layout(portfolio, sections, visible_sections, color_scheme, theme)
      :single -> render_single_layout(portfolio, sections, visible_sections, color_scheme, theme)
      :workspace -> render_workspace_layout(portfolio, sections, visible_sections, color_scheme, theme)
      :time_machine -> EnhancedPortfolioLayouts.render_enhanced_portfolio_layout(portfolio, sections, :time_machine, color_scheme, customization)
      :grid -> EnhancedPortfolioLayouts.render_enhanced_portfolio_layout(portfolio, sections, :grid, color_scheme, customization)
      _ -> render_single_layout(portfolio, sections, visible_sections, color_scheme, theme)
    end
  end

  # ============================================================================
  # LAYOUT TYPE NORMALIZATION - UPDATED
  # ============================================================================

  defp normalize_layout_type(layout_type) when is_binary(layout_type) do
    case String.downcase(layout_type) do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      "time_machine" -> :time_machine
      "grid" -> :grid
      _ -> :single
    end
  end
  defp normalize_layout_type(layout_type) when is_atom(layout_type), do: layout_type
  defp normalize_layout_type(_), do: :single

  # ============================================================================
  # LAYOUT OPTIONS HELPER - UPDATED
  # ============================================================================

  def get_available_layouts do
    [
      %{
        key: "sidebar",
        name: "Sidebar",
        description: "IMDB-style with left navigation",
        icon: "📑",
        mobile_friendly: true
      },
      %{
        key: "single",
        name: "Single",
        description: "Clean single column flow",
        icon: "📄",
        mobile_friendly: true
      },
      %{
        key: "workspace",
        name: "Workspace",
        description: "Dashboard-style grid layout",
        icon: "🏢",
        mobile_friendly: true
      },
      %{
        key: "time_machine",
        name: "Time Machine",
        description: "iOS-style card stack with smooth transitions",
        icon: "📱",
        mobile_friendly: true,
        features: ["3D Transitions", "Touch Gestures", "Scroll Direction Toggle"]
      },
      %{
        key: "grid",
        name: "Grid",
        description: "Clean 3-column uniform card layout",
        icon: "⊞",
        mobile_friendly: true,
        features: ["Responsive Grid", "Uniform Cards", "Clean Design"]
      }
    ]
  end

  # ============================================================================
  # EXISTING LAYOUTS (Sidebar, Single, Workspace) - Keep as-is
  # ============================================================================

  # SIDEBAR LAYOUT - IMDB-style with left navigation
  defp render_sidebar_layout(portfolio, sections, visible_sections, color_scheme, theme) do
    has_media = has_portfolio_media?(portfolio, sections)
    layout_config = get_layout_config("sidebar", color_scheme)

    # Return raw HTML string for existing layouts
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

          <!-- Portfolio Header -->
          <div class="p-6 border-b border-gray-100">
            <h1 class="text-xl font-bold text-gray-900 mb-2">#{portfolio.title}</h1>
            #{if portfolio.description, do: "<p class=\"text-sm text-gray-600 leading-relaxed\">#{portfolio.description}</p>", else: ""}
          </div>

          <!-- Section Navigation -->
          <nav class="p-4">
            <h3 class="text-xs font-semibold text-gray-500 uppercase tracking-wider mb-3">Contents</h3>
            <ul class="space-y-1">
              #{render_section_nav_items(visible_sections)}
            </ul>
          </nav>

          <!-- Quick Actions -->
          <div class="p-4 border-t border-gray-100 mt-auto">
            #{render_quick_actions(portfolio)}
          </div>
        </aside>

        <!-- Main Content -->
        <main class="flex-1 lg:ml-0">
          <!-- Hero Section -->
          #{render_clean_hero(portfolio, sections, has_media)}

          <!-- Content Sections -->
          <div class="max-w-4xl mx-auto px-6 lg:px-8 py-8">
            #{render_clean_sections(sections, "sidebar", layout_config)}
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

  defp render_clean_hero(portfolio, sections, has_media) do
  """
  <section class="relative bg-gradient-to-br from-gray-50 to-white py-16 lg:py-24">
    <div class="max-w-4xl mx-auto px-6 lg:px-8 text-center">
      <h1 class="text-4xl lg:text-5xl font-bold text-gray-900 mb-6">
        #{portfolio.title}
      </h1>
      #{if portfolio.description, do: "<p class=\"text-xl text-gray-600 leading-relaxed max-w-3xl mx-auto\">#{portfolio.description}</p>", else: ""}
    </div>
  </section>
  """
end

  defp render_clean_sections(sections, layout_type, config) do
    sections
    |> Enum.filter(&(&1.visible))
    |> Enum.map(fn section ->
      section_content = case section.section_type do
        "skills" -> render_skills_with_meta_pills(section)
        _ -> render_section_content_safe(section)
      end

      """
      <section id="section-#{section.id}" class="mb-12 last:mb-0">
        <div class="bg-white rounded-lg shadow-sm p-6 lg:p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">
            #{section.title}
          </h2>
          <div class="section-content prose prose-gray max-w-none">
            #{section_content}
          </div>
        </div>
      </section>
      """
    end)
    |> Enum.join("\n")
  end


  # SINGLE LAYOUT - Clean single column
  defp render_single_layout(portfolio, sections, visible_sections, color_scheme, theme) do
    has_media = has_portfolio_media?(portfolio, sections)
    layout_config = get_layout_config("single", color_scheme)

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
        <!-- Hero Section -->
        #{render_clean_hero_html(portfolio, sections, has_media)}

        <!-- Content Sections -->
        <div class="px-6 lg:px-8 py-8">
          #{render_clean_sections_html(sections, "single", layout_config)}
        </div>
      </main>

      #{render_layout_scripts_html()}
    </div>
    """
  end

  # WORKSPACE LAYOUT - Dashboard-style
  defp render_workspace_layout(portfolio, sections, visible_sections, color_scheme, theme) do
    has_media = has_portfolio_media?(portfolio, sections)
    primary_sections = get_primary_sections(sections)
    secondary_sections = get_secondary_sections(sections)
    layout_config = get_layout_config("workspace", color_scheme)

    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-gray-50">
      <!-- Workspace Header -->
      <header class="bg-white border-b border-gray-200 sticky top-0 z-30">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">#{portfolio.title}</h1>
              #{if portfolio.description, do: "<p class=\"text-gray-600 mt-1\">#{portfolio.description}</p>", else: ""}
            </div>

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

      <!-- Workspace Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <!-- Hero Section -->
        #{if has_media, do: render_clean_hero_html(portfolio, sections, has_media), else: ""}

        <!-- Primary Sections -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mb-8">
          #{render_primary_workspace_sections_html(primary_sections)}
        </div>

        <!-- Secondary Sections -->
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
          #{render_secondary_workspace_sections_html(secondary_sections)}
        </div>

        <!-- Additional Sections -->
        #{if length(sections) > 5, do: render_additional_workspace_sections_html(Enum.drop(sections, 5)), else: ""}
      </main>

      #{render_layout_scripts_html()}
    </div>
    """
  end

  # ============================================================================
  # HTML HELPER FUNCTIONS FOR EXISTING LAYOUTS
  # ============================================================================

  defp render_section_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
          class="block px-3 py-2 text-sm text-gray-700 hover:bg-gray-100 rounded-md transition-colors">
          #{section.title}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_quick_actions(portfolio) do
    """
    <div class="space-y-2">
      <button class="w-full text-left px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-md transition-colors">
        Download Resume
      </button>
      <button class="w-full text-left px-3 py-2 text-sm text-gray-600 hover:bg-gray-100 rounded-md transition-colors">
        Contact Info
      </button>
    </div>
    """
  end

  defp render_compact_nav_items(sections) do
    sections
    |> Enum.map(fn section ->
      """
      <li>
        <a href="#section-#{section.id}"
           class="block px-3 py-1 text-xs text-gray-600 hover:text-gray-900 hover:bg-gray-50 rounded transition-colors">
          #{section.title}
        </a>
      </li>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_workspace_nav_items(sections) do
    sections
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

  defp render_clean_hero_html(portfolio, sections, has_media) do
    """
    <section class="relative bg-gradient-to-br from-gray-50 to-white py-16 lg:py-24">
      <div class="max-w-4xl mx-auto px-6 lg:px-8 text-center">
        <h1 class="text-4xl lg:text-5xl font-bold text-gray-900 mb-6">
          #{portfolio.title}
        </h1>
        #{if portfolio.description, do: "<p class=\"text-xl text-gray-600 leading-relaxed max-w-3xl mx-auto\">#{portfolio.description}</p>", else: ""}
      </div>
    </section>
    """
  end

  defp render_clean_sections_html(sections, layout_type, config) do
    sections
    |> Enum.filter(&(&1.visible))
    |> Enum.map(fn section ->
      """
      <section id="section-#{section.id}" class="mb-12 last:mb-0">
        <div class="bg-white rounded-lg shadow-sm p-6 lg:p-8">
          <h2 class="text-2xl font-bold text-gray-900 mb-6">
            #{section.title}
          </h2>
          <div class="section-content prose prose-gray max-w-none">
            #{render_section_content_safe_html(section)}
          </div>
        </div>
      </section>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_primary_workspace_sections_html(sections) do
    sections
    |> Enum.take(2)
    |> Enum.map(&render_workspace_card_html(&1, "large"))
    |> Enum.join("\n")
  end

  defp render_secondary_workspace_sections_html(sections) do
    sections
    |> Enum.take(3)
    |> Enum.map(&render_workspace_card_html(&1, "compact"))
    |> Enum.join("\n")
  end

  defp render_additional_workspace_sections_html(sections) do
    """
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      #{sections |> Enum.map(&render_workspace_card_html(&1, "grid")) |> Enum.join("\n")}
    </div>
    """
  end

  defp render_workspace_card_html(section, size) do
    card_classes = case size do
      "large" -> "bg-white rounded-lg border border-gray-200 p-6 lg:p-8"
      "compact" -> "bg-white rounded-lg border border-gray-200 p-4"
      "grid" -> "bg-white rounded-lg border border-gray-200 p-6"
    end

    """
    <div id="section-#{section.id}" class="#{card_classes}">
      <h3 class="text-lg font-semibold text-gray-900 mb-3">#{section.title}</h3>
      <div class="section-content text-gray-600">
        #{render_section_content_preview_html(section, size)}
      </div>
    </div>
    """
  end

  defp render_section_content_safe_html(section) do
    content = section.content || %{}
    description = Map.get(content, "description", "")

    if description != "" do
      description
    else
      "Content for #{section.title}"
    end
  end

  defp render_section_content_preview_html(section, size) do
    content = section.content || %{}
    description = Map.get(content, "description", "")

    max_length = case size do
      "large" -> 300
      "compact" -> 150
      "grid" -> 200
    end

    if description != "" do
      if String.length(description) > max_length do
        String.slice(description, 0, max_length) <> "..."
      else
        description
      end
    else
      "Content for #{section.title}"
    end
  end

  defp render_layout_scripts_html do
    """
    <script>
      // Mobile navigation for sidebar layout
      function toggleMobileNav() {
        const sidebar = document.getElementById('portfolio-sidebar');
        const overlay = document.getElementById('mobile-overlay');

        if (sidebar.classList.contains('-translate-x-full')) {
          sidebar.classList.remove('-translate-x-full');
          overlay.classList.remove('hidden');
        } else {
          sidebar.classList.add('-translate-x-full');
          overlay.classList.add('hidden');
        }
      }

      // Floating navigation for single layout
      function toggleFloatingNav() {
        console.log('Toggle floating navigation');
      }

      // Workspace menu for workspace layout
      function toggleWorkspaceMenu() {
        console.log('Toggle workspace menu');
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
            }
          });
        });
      });
    </script>
    """
  end

  defp render_section_content_safe(section) do
    # Use the enhanced section renderer for proper Skills display
    case section.section_type do
      "skills" -> render_skills_with_meta_pills(section)
      _ ->
        content = section.content || %{}
        description = Map.get(content, "description", "")
        if description != "", do: description, else: "Content for #{section.title}"
    end
  end

  defp render_skills_with_meta_pills(section) do
    content = section.content || %{}
    items = Map.get(content, "items", [])
    description = Map.get(content, "description", "")

    description_html = if description != "", do: "<p class=\"text-sm text-gray-600 leading-relaxed mb-4\">#{description}</p>", else: ""

    skills_html = if is_list(items) and length(items) > 0 do
      skill_pills = items
      |> Enum.map(fn item ->
        skill_name = Map.get(item, "name", "Unknown")
        level = Map.get(item, "level", "intermediate")
        category = Map.get(item, "category", "general")
        pill_classes = get_skill_pill_classes(category, level)

        """
        <span class="#{pill_classes} px-3 py-1 text-xs rounded-full font-medium inline-block mr-2 mb-2">
          #{skill_name}
        </span>
        """
      end)
      |> Enum.join("")

      "<div class=\"flex flex-wrap\">#{skill_pills}</div>"
    else
      ""
    end

    """
    <div class="skills-section">
      #{description_html}
      #{skills_html}
    </div>
    """
  end

  defp parse_skill_data(skill) when is_binary(skill) do
    # Handle simple string skills
    {skill, "intermediate", "general"}
  end

  defp parse_skill_data(skill) when is_map(skill) do
    # Handle structured skill data
    name = Map.get(skill, "name", Map.get(skill, :name, "Unknown"))
    proficiency = Map.get(skill, "proficiency", Map.get(skill, :proficiency, "intermediate"))
    category = Map.get(skill, "category", Map.get(skill, :category, "general"))
    {name, proficiency, category}
  end

  defp parse_skill_data(_), do: {"Unknown Skill", "beginner", "general"}

  defp get_skill_pill_classes(category, proficiency) do
    base_classes = "transition-colors hover:scale-105 transform"

    # Category-based colors (Meta-style)
    category_color = case String.downcase(to_string(category)) do
      cat when cat in ["frontend", "ui", "design"] -> "blue"
      cat when cat in ["backend", "server", "database"] -> "green"
      cat when cat in ["mobile", "ios", "android"] -> "purple"
      cat when cat in ["devops", "cloud", "infrastructure"] -> "orange"
      cat when cat in ["data", "analytics", "ml", "ai"] -> "red"
      cat when cat in ["tools", "productivity"] -> "gray"
      _ -> "indigo"  # Default/general
    end

    # Proficiency-based intensity (light to dark)
    intensity = case String.downcase(to_string(proficiency)) do
      prof when prof in ["beginner", "basic", "learning"] -> "100"
      prof when prof in ["intermediate", "good", "competent"] -> "200"
      prof when prof in ["advanced", "proficient", "strong"] -> "300"
      prof when prof in ["expert", "master", "senior"] -> "400"
      _ -> "200"  # Default
    end

    "#{base_classes} bg-#{category_color}-#{intensity} text-#{category_color}-800 border border-#{category_color}-300"
  end

  defp render_section_content_preview(section, size) do
    content = section.content || %{}
    description = Map.get(content, "description", "")

    max_length = case size do
      "large" -> 300
      "compact" -> 150
      "grid" -> 200
    end

    if description != "" do
      if String.length(description) > max_length do
        String.slice(description, 0, max_length) <> "..."
      else
        description
      end
    else
      "Content for #{section.title}"
    end
  end

  defp render_layout_scripts do
    """
    <script>
      // Mobile navigation for sidebar layout
      function toggleMobileNav() {
        const sidebar = document.getElementById('portfolio-sidebar');
        const overlay = document.getElementById('mobile-overlay');

        if (sidebar.classList.contains('-translate-x-full')) {
          sidebar.classList.remove('-translate-x-full');
          overlay.classList.remove('hidden');
        } else {
          sidebar.classList.add('-translate-x-full');
          overlay.classList.add('hidden');
        }
      }

      // Floating navigation for single layout
      function toggleFloatingNav() {
        console.log('Toggle floating navigation');
      }

      // Workspace menu for workspace layout
      function toggleWorkspaceMenu() {
        console.log('Toggle workspace menu');
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
            }
          });
        });
      });
    </script>
    """
  end

  defp filter_visible_sections(sections) do
    sections
    |> Enum.filter(&(&1.visible))
    |> Enum.sort_by(&(&1.position))
  end

  defp has_portfolio_media?(portfolio, sections) do
    intro_video = find_intro_video(sections)
    intro_video != nil
  end

  defp find_intro_video(sections) do
    Enum.find(sections, fn section ->
      section.section_type in ["video_intro", "media_showcase"] &&
      (section.content && Map.get(section.content, "video_url"))
    end)
  end

  defp get_primary_sections(sections) do
    sections
    |> Enum.filter(&(&1.visible && &1.section_type != "video_intro"))
    |> Enum.filter(&(&1.section_type in ["about", "experience", "projects", "skills"]))
    |> Enum.take(3)
  end

  defp get_secondary_sections(sections) do
    sections
    |> Enum.filter(&(&1.visible && &1.section_type != "video_intro"))
    |> Enum.filter(&(&1.section_type in ["contact", "education", "certifications", "achievements"]))
    |> Enum.take(3)
  end

  defp get_layout_config(layout_type, color_scheme) do
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
      _ -> "text-blue-600"
    end
  end


  defp render_section_content_preview(section, size) do
    content = section.content || %{}
    description = Map.get(content, "description", "")

    max_length = case size do
      "large" -> 300
      "compact" -> 150
      "grid" -> 200
    end

    if description != "" do
      if String.length(description) > max_length do
        String.slice(description, 0, max_length) <> "..."
      else
        description
      end
    else
      "Content for #{section.title}"
    end
  end

end
