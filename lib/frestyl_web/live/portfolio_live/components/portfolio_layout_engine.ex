# lib/frestyl_web/live/portfolio_live/components/portfolio_layout_engine.ex

defmodule FrestylWeb.PortfolioLive.Components.PortfolioLayoutEngine do
  @moduledoc """
  Clean, mobile-first portfolio layout engine with practical designs.
  Supports 3 focused layouts: Sidebar, Single, and Workspace (dashboard-style).
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  alias FrestylWeb.PortfolioLive.Components.DynamicSectionModal

  # ============================================================================
  # MAIN LAYOUT RENDERER
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme) do
    # Filter visible sections for navigation
    visible_sections = filter_visible_sections(sections)

    # Get clean layout configuration
    layout_config = get_layout_config(layout_type, color_scheme)

    # Render based on layout type
    case normalize_layout_type(layout_type) do
      :sidebar -> render_sidebar_layout(portfolio, sections, visible_sections, layout_config)
      :single -> render_single_layout(portfolio, sections, visible_sections, layout_config)
      :workspace -> render_workspace_layout(portfolio, sections, visible_sections, layout_config)
      _ -> render_single_layout(portfolio, sections, visible_sections, layout_config)
    end
  end

  # ============================================================================
  # SIDEBAR LAYOUT - IMDB-style with left navigation
  # ============================================================================

  defp render_sidebar_layout(portfolio, sections, visible_sections, config) do
    has_media = has_portfolio_media?(portfolio, sections)

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
            #{if portfolio.description do
              "<p class=\"text-sm text-gray-600 leading-relaxed\">#{portfolio.description}</p>"
            else
              ""
            end}
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
        <!-- Hero Section -->
        #{render_clean_hero(portfolio, sections, has_media)}

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

    """
    <div class="portfolio-layout workspace-layout min-h-screen bg-gray-50">
      <!-- Workspace Header -->
      <header class="bg-white border-b border-gray-200 sticky top-0 z-30">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-2xl font-bold text-gray-900">#{portfolio.title}</h1>
              #{if portfolio.description do
                "<p class=\"text-gray-600 mt-1\">#{portfolio.description}</p>"
              else
                ""
              end}
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

      <!-- Hero Section -->
      #{render_workspace_hero(portfolio, sections, has_media)}

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
  # CLEAN HERO SECTION
  # ============================================================================

  defp render_clean_hero(portfolio, sections, has_media) do
    intro_video = find_intro_video(sections)
    hero_height = if has_media || intro_video, do: "min-h-[400px]", else: "py-12"

    """
    <section class="hero-section #{hero_height} bg-white border-b border-gray-100">
      <div class="max-w-4xl mx-auto px-6 lg:px-8 py-8">
        #{if intro_video do
          render_video_hero(portfolio, intro_video)
        else
          render_text_hero(portfolio, has_media)
        end}
      </div>
    </section>
    """
  end

  defp render_video_hero(portfolio, video_section) do
    video_content = video_section.content || %{}
    video_url = Map.get(video_content, "video_url")

    """
    <div class="flex flex-col lg:flex-row items-center gap-8">
      <!-- Video -->
      <div class="flex-1">
        #{if video_url do
          "<div class=\"aspect-video bg-gray-100 rounded-lg overflow-hidden\">
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
        #{render_hero_actions(portfolio)}
      </div>
    </div>
    """
  end

  defp render_text_hero(portfolio, has_media) do
    """
    <div class="text-center max-w-3xl mx-auto">
      <h1 class="text-3xl lg:text-5xl font-bold text-gray-900 mb-6">#{portfolio.title}</h1>
      #{if portfolio.description do
        "<p class=\"text-xl text-gray-600 leading-relaxed mb-8\">#{portfolio.description}</p>"
      else
        ""
      end}
      #{render_hero_actions(portfolio)}
    </div>
    """
  end

  defp render_workspace_hero(portfolio, sections, has_media) do
    intro_video = find_intro_video(sections)

    if intro_video || has_media do
      """
      <section class="bg-white border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6 py-8">
          #{render_video_hero(portfolio, intro_video || %{})}
        </div>
      </section>
      """
    else
      ""
    end
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
    |> Enum.filter(&(&1.visible && &1.section_type != "video_intro"))
    |> Enum.map(&render_clean_section(&1, layout_type, config))
    |> Enum.join("\n")
  end

  defp render_clean_section(section, layout_type, config) do
    """
    <section id="section-#{section.id}" class="section-card bg-white rounded-lg border border-gray-200 p-6 lg:p-8 mb-6 last:mb-0">
      <!-- Section Header -->
      <header class="mb-6">
        <h2 class="text-2xl font-bold text-gray-900 mb-2">#{section.title}</h2>
        #{if section.description do
          "<p class=\"text-gray-600\">#{section.description}</p>"
        else
          ""
        end}
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
      "large" -> "bg-white rounded-lg border border-gray-200 p-6 lg:p-8"
      "compact" -> "bg-white rounded-lg border border-gray-200 p-4"
      "grid" -> "bg-white rounded-lg border border-gray-200 p-6"
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

  defp render_quick_actions(portfolio) do
    """
    <div class="space-y-2">
      <button class="w-full px-4 py-2 text-sm bg-gray-900 text-white rounded-md hover:bg-gray-800 transition-colors">
        Contact
      </button>
      <button class="w-full px-4 py-2 text-sm border border-gray-300 text-gray-700 rounded-md hover:bg-gray-50 transition-colors">
        Download Resume
      </button>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp filter_visible_sections(sections) do
    Enum.filter(sections, &(&1.visible && &1.section_type != "video_intro"))
  end

  defp has_portfolio_media?(portfolio, sections) do
    # Check if portfolio has intro video or media sections
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
    # Get the most important sections for main content area
    sections
    |> Enum.filter(&(&1.visible && &1.section_type != "video_intro"))
    |> Enum.filter(&(&1.section_type in ["about", "experience", "projects", "skills"]))
    |> Enum.take(3)
  end

  defp get_secondary_sections(sections) do
    # Get sections for sidebar
    sections
    |> Enum.filter(&(&1.visible && &1.section_type != "video_intro"))
    |> Enum.filter(&(&1.section_type in ["contact", "education", "certifications", "achievements"]))
    |> Enum.take(3)
  end

  defp normalize_layout_type(layout_type) when is_binary(layout_type) do
    case String.downcase(layout_type) do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      _ -> :single
    end
  end
  defp normalize_layout_type(layout_type) when is_atom(layout_type), do: layout_type
  defp normalize_layout_type(_), do: :single

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
      _ -> "text-gray-900"
    end
  end

  defp render_section_content_safe(section) do
    content = section.content || %{}

    case section.section_type do
      "about" -> render_about_content(content)
      "experience" -> render_experience_content(content)
      "projects" -> render_projects_content(content)
      "skills" -> render_skills_content(content)
      "contact" -> render_contact_content(content)
      _ -> render_default_content(content)
    end
  end

  defp render_section_content_preview(section, size) do
    content = render_section_content_safe(section)

    case size do
      "compact" -> truncate_content(content, 100)
      "grid" -> truncate_content(content, 150)
      _ -> content
    end
  end

  defp render_about_content(content) do
    description = Map.get(content, "description", "")
    if String.length(description) > 0 do
      "<p>#{description}</p>"
    else
      "<p class=\"text-gray-500 italic\">No content available</p>"
    end
  end

  defp render_experience_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      items
      |> Enum.take(3)
      |> Enum.map(fn item ->
        title = Map.get(item, "title", "")
        company = Map.get(item, "company", "")
        "<div class=\"mb-3\"><h4 class=\"font-medium\">#{title}</h4><p class=\"text-sm text-gray-600\">#{company}</p></div>"
      end)
      |> Enum.join("")
    else
      "<p class=\"text-gray-500 italic\">No experience listed</p>"
    end
  end

  defp render_projects_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      items
      |> Enum.take(3)
      |> Enum.map(fn item ->
        title = Map.get(item, "title", "")
        description = Map.get(item, "description", "")
        "<div class=\"mb-3\"><h4 class=\"font-medium\">#{title}</h4><p class=\"text-sm text-gray-600\">#{String.slice(description, 0, 100)}...</p></div>"
      end)
      |> Enum.join("")
    else
      "<p class=\"text-gray-500 italic\">No projects listed</p>"
    end
  end

  defp render_skills_content(content) do
    items = Map.get(content, "items", [])
    if length(items) > 0 do
      skills = items |> Enum.take(6) |> Enum.map(&Map.get(&1, "name", "")) |> Enum.join(", ")
      "<p>#{skills}</p>"
    else
      "<p class=\"text-gray-500 italic\">No skills listed</p>"
    end
  end

  defp render_contact_content(content) do
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")

    """
    <div class="space-y-2">
      #{if String.length(email) > 0, do: "<p><strong>Email:</strong> #{email}</p>", else: ""}
      #{if String.length(phone) > 0, do: "<p><strong>Phone:</strong> #{phone}</p>", else: ""}
    </div>
    """
  end

  defp render_default_content(content) do
    description = Map.get(content, "content", Map.get(content, "description", ""))
    if String.length(description) > 0 do
      "<p>#{description}</p>"
    else
      "<p class=\"text-gray-500 italic\">No content available</p>"
    end
  end

  defp truncate_content(content, max_length) do
    if String.length(content) > max_length do
      String.slice(content, 0, max_length) <> "..."
    else
      content
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
        // Simple implementation - could expand for mobile menu
        console.log('Toggle floating navigation');
      }

      // Workspace menu for workspace layout
      function toggleWorkspaceMenu() {
        // Simple implementation - could expand for mobile menu
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
end
