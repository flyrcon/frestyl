# lib/frestyl_web/live/portfolio_live/components/portfolio_layout_engine.ex

defmodule FrestylWeb.PortfolioLive.Components.PortfolioLayoutEngine do
  @moduledoc """
  Clean portfolio layout engine with 4 distinct, complementary designs:
  - Professional Flow: Clean vertical layout with smooth animations
  - Creative Grid: Pinterest-style masonry with dynamic sizing
  - Executive Dashboard: Clean grid layout with consistent card sizes
  - Modern Showcase: Asymmetric creative professional layout

  No inside borders, clean shadows, gradient accents, Frestyl design philosophy
  """

  use FrestylWeb, :live_component
  alias FrestylWeb.PortfolioLive.Components.EnhancedSectionRenderer

  def render(assigns) do
    layout_style = Map.get(assigns.customization, "layout_style", "mobile_single")

    ~H"""
    <div class="portfolio-layout-container" data-layout={layout_style} style={get_inline_styles(layout_style)}>
      <!-- Inline CSS for this layout -->
      <style id={"layout-css-#{layout_style}"} phx-update="ignore">
        <%= raw(get_layout_css(layout_style)) %>
      </style>

      <!-- Hero Section (if exists) -->
      <%= if Map.get(assigns, :hero_section) do %>
        <div class="hero-container mb-8">
          <.live_component
            module={EnhancedSectionRenderer}
            id={"hero-#{@hero_section.id}"}
            section={@hero_section}
            show_actions={Map.get(assigns, :show_actions, false)} />
        </div>
      <% end %>

      <!-- Layout-specific rendering -->
      <div class={get_layout_classes(layout_style)}>
        <%= case layout_style do %>
          <% "mobile_single" -> %>
            <%= render_single_column(assigns) %>
          <% "grid_uniform" -> %>
            <%= render_pinterest_grid(assigns) %>
          <% "dashboard" -> %>
            <%= render_true_dashboard(assigns) %>
          <% "creative_modern" -> %>
            <%= render_creative_modern(assigns) %>
          <% _ -> %>
            <%= render_single_column(assigns) %>
        <% end %>
      </div>

      <!-- Empty state -->
      <%= if get_visible_sections(Map.get(assigns, :sections, [])) == [] do %>
        <div class="empty-state">
          <div class="text-center py-16">
            <h3 class="text-xl font-medium text-gray-900 mb-2">Add Portfolio Sections</h3>
            <p class="text-gray-500">Start building your portfolio by adding sections to showcase your work.</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Helper function for inline styles
  defp get_inline_styles(_layout_style) do
    ""
  end

  # Single Column Layout - Professional Flow
  defp render_single_column(assigns) do
    sections = get_non_hero_visible_sections(Map.get(assigns, :sections, []))

    ~H"""
    <div class="single-column-container">
      <%= for section <- sections do %>
        <div class="single-section">
          <.live_component
            module={EnhancedSectionRenderer}
            id={"section-#{section.id}"}
            section={section}
            show_actions={Map.get(assigns, :show_actions, false)} />
        </div>
      <% end %>
    </div>
    """
  end

  # Pinterest-style masonry grid
  defp render_pinterest_grid(assigns) do
    sections = get_non_hero_visible_sections(Map.get(assigns, :sections, []))

    ~H"""
    <div class="pinterest-grid">
      <%= for section <- sections do %>
        <div class="pinterest-item">
          <.live_component
            module={EnhancedSectionRenderer}
            id={"section-#{section.id}"}
            section={section}
            show_actions={Map.get(assigns, :show_actions, false)} />
        </div>
      <% end %>
    </div>
    """
  end

  # Clean dashboard layout
  defp render_true_dashboard(assigns) do
    sections = get_non_hero_visible_sections(Map.get(assigns, :sections, []))

    ~H"""
    <div class="dashboard-container">
      <div class="dashboard-grid">
        <%= for {section, index} <- Enum.with_index(sections) do %>
          <div class={"dashboard-widget dashboard-widget-#{get_dashboard_size(section, index)}"}>
            <.live_component
              module={EnhancedSectionRenderer}
              id={"section-#{section.id}"}
              section={section}
              show_actions={Map.get(assigns, :show_actions, false)} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Creative modern asymmetric layout
  defp render_creative_modern(assigns) do
    sections = get_non_hero_visible_sections(Map.get(assigns, :sections, []))

    ~H"""
    <div class="creative-container">
      <%= for {section, index} <- Enum.with_index(sections) do %>
        <div class={get_creative_position_class(section, index)}>
          <.live_component
            module={EnhancedSectionRenderer}
            id={"section-#{section.id}"}
            section={section}
            show_actions={Map.get(assigns, :show_actions, false)} />
        </div>
      <% end %>
    </div>
    """
  end

  # Helper functions
  defp get_layout_classes(layout_style) do
    case layout_style do
      "mobile_single" -> "layout-single max-w-4xl mx-auto px-4"
      "grid_uniform" -> "layout-grid max-w-7xl mx-auto px-4"
      "dashboard" -> "layout-dashboard max-w-7xl mx-auto px-4"
      "creative_modern" -> "layout-creative max-w-7xl mx-auto px-4"
      _ -> "layout-single max-w-4xl mx-auto px-4"
    end
  end

  defp get_visible_sections(sections) do
    sections |> Enum.filter(& &1.visible)
  end

  defp get_non_hero_visible_sections(sections) do
    sections
    |> Enum.filter(fn section ->
      section.visible && to_string(section.section_type) != "hero"
    end)
    |> Enum.sort_by(& &1.position)
  end

  defp get_dashboard_size(section, index) do
    case {to_string(section.section_type), rem(index, 6)} do
      # Strategic sizing for perfect fit
      {"experience", _} -> "large-wide"      # 2x2
      {"projects", _} -> "large-wide"        # 2x2
      {"intro", _} -> "medium-wide"          # 2x1
      {"contact", _} -> "small"              # 1x1
      {"skills", _} -> "medium"              # 1x2
      {"education", _} -> "medium"           # 1x2

      # Pattern-based efficient layout
      {_, 0} -> "large-wide"    # 2x2
      {_, 1} -> "small"         # 1x1
      {_, 2} -> "small"         # 1x1
      {_, 3} -> "medium"        # 1x2
      {_, 4} -> "medium-wide"   # 2x1
      {_, 5} -> "small"         # 1x1
    end
  end

  defp get_creative_position_class(section, index) do
    base_class = "creative-item"

    position_class = case {to_string(section.section_type), rem(index, 4)} do
      # Important sections get prominence
      {"intro", _} -> "creative-full"
      {"experience", _} -> "creative-large"
      {"projects", _} -> "creative-large"

      # Smaller sections
      {"contact", _} -> "creative-small"
      {"skills", _} -> "creative-small"

      # Pattern-based positioning
      {_, 0} -> "creative-large"
      {_, 1} -> "creative-medium"
      {_, 2} -> "creative-small"
      {_, 3} -> "creative-medium"
    end

    "#{base_class} #{position_class}"
  end

  defp get_layout_css(layout_style) do
    case layout_style do
      "mobile_single" -> single_column_css()
      "grid_uniform" -> pinterest_grid_css()
      "dashboard" -> dashboard_css()
      "creative_modern" -> creative_modern_css()
      _ -> single_column_css()
    end
  end

  # CSS Definitions - Enhanced with Frestyl design philosophy
  defp single_column_css do
    """
    .single-column-container {
      display: flex;
      flex-direction: column;
      gap: 2rem;
    }

    .single-section {
      background: white;
      border-radius: 16px;
      box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
      transition: all 0.4s cubic-bezier(0.4, 0, 0.2, 1);
      position: relative;
      overflow: hidden;
      height: 400px;
      display: flex;
      flex-direction: column;
    }

    .single-section > * {
      flex: 1;
      overflow-y: auto;
    }

    .single-section::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: linear-gradient(90deg, #3b82f6, #8b5cf6, #ec4899);
      transform: translateX(-100%);
      transition: transform 0.6s ease;
    }

    .single-section:hover::before {
      transform: translateX(0);
    }

    .single-section:hover {
      transform: translateY(-8px);
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.12);
    }

    @media (max-width: 768px) {
      .single-column-container {
        gap: 1.5rem;
      }

      .single-section {
        border-radius: 12px;
      }

      .single-section:hover {
        transform: translateY(-4px);
      }
    }
    """
  end

  defp pinterest_grid_css do
    """
    .pinterest-grid {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 1.5rem;
    }

    .pinterest-item {
      background: white;
      border-radius: 20px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      transition: all 0.5s cubic-bezier(0.175, 0.885, 0.32, 1.275);
      position: relative;
      overflow: hidden;
      height: 400px;
      display: flex;
      flex-direction: column;
    }

    .pinterest-item > * {
      flex: 1;
      overflow-y: auto;
    }

    .pinterest-item::after {
      content: '';
      position: absolute;
      top: -50%;
      left: -50%;
      width: 200%;
      height: 200%;
      background: radial-gradient(circle, rgba(248, 250, 252, 0.1) 0%, transparent 70%);
      opacity: 0;
      transition: opacity 0.3s ease;
      pointer-events: none;
    }

    .pinterest-item:hover::after {
      opacity: 1;
    }

    .pinterest-item:hover {
      transform: translateY(-12px) scale(1.02);
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
    }

    @media (max-width: 1024px) {
      .pinterest-grid {
        grid-template-columns: repeat(2, 1fr);
      }
    }

    @media (max-width: 640px) {
      .pinterest-grid {
        grid-template-columns: 1fr;
        gap: 1rem;
      }

      .pinterest-item {
        border-radius: 12px;
        height: 350px;
      }
    }
    """
  end

  defp dashboard_css do
    """
    .dashboard-container {
      background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
      border-radius: 24px;
      padding: 2rem;
      box-shadow: inset 0 2px 4px rgba(0, 0, 0, 0.06);
      min-height: 70vh;
    }

    .dashboard-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      grid-template-rows: repeat(4, 200px);
      gap: 1.5rem;
      height: 100%;
    }

    .dashboard-widget {
      background: white;
      border-radius: 16px;
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.08);
      transition: all 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
      position: relative;
      overflow: hidden;
      border: 1px solid rgba(226, 232, 240, 0.8);
    }

    .dashboard-widget::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      height: 3px;
      background: linear-gradient(90deg, #1e40af, #3b82f6, #06b6d4);
      transform: translateX(-100%);
      transition: transform 0.6s cubic-bezier(0.34, 1.56, 0.64, 1);
    }

    .dashboard-widget:hover::before {
      transform: translateX(0);
    }

    .dashboard-widget:hover {
      transform: translateY(-8px) scale(1.03);
      box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
      border-color: rgba(59, 130, 246, 0.4);
      z-index: 10;
    }

    /* Efficient widget sizing for perfect fit */
    .dashboard-widget-small {
      grid-column: span 1;
      grid-row: span 1;
    }

    .dashboard-widget-medium {
      grid-column: span 1;
      grid-row: span 2;
    }

    .dashboard-widget-medium-wide {
      grid-column: span 2;
      grid-row: span 1;
    }

    .dashboard-widget-large-wide {
      grid-column: span 2;
      grid-row: span 2;
    }

    @media (max-width: 1024px) {
      .dashboard-grid {
        grid-template-columns: repeat(3, 1fr);
        grid-template-rows: repeat(3, 180px);
      }

      .dashboard-widget-large-wide {
        grid-column: span 2;
        grid-row: span 2;
      }

      .dashboard-widget-medium-wide {
        grid-column: span 2;
        grid-row: span 1;
      }
    }

    @media (max-width: 768px) {
      .dashboard-container {
        padding: 1rem;
        border-radius: 16px;
        background: transparent;
        box-shadow: none;
      }

      .dashboard-grid {
        grid-template-columns: 1fr;
        grid-template-rows: auto;
        gap: 1rem;
      }

      .dashboard-widget-small,
      .dashboard-widget-medium,
      .dashboard-widget-medium-wide,
      .dashboard-widget-large-wide {
        grid-column: span 1;
        grid-row: span 1;
      }

      .dashboard-widget {
        min-height: 200px;
      }

      .dashboard-widget:hover {
        transform: translateY(-4px) scale(1.01);
      }
    }
    """
  end

  defp creative_modern_css do
    """
    .creative-container {
      display: grid;
      grid-template-columns: repeat(6, 1fr);
      grid-auto-rows: 280px;
      gap: 2rem;
      align-items: start;
      max-width: 1200px;
      margin: 0 auto;
    }

    .creative-item {
      background: white;
      border-radius: 24px;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
      transition: all 0.6s cubic-bezier(0.23, 1, 0.32, 1);
      position: relative;
      overflow: hidden;
      height: 400px;
      display: flex;
      flex-direction: column;
    }

    .creative-item > * {
      flex: 1;
      overflow-y: auto;
    }

    .creative-item::before {
      content: '';
      position: absolute;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      background: linear-gradient(135deg, rgba(139, 92, 246, 0.1), rgba(59, 130, 246, 0.1));
      opacity: 0;
      transition: opacity 0.4s ease;
      pointer-events: none;
    }

    .creative-item:hover::before {
      opacity: 1;
    }

    .creative-item:hover {
      transform: translateY(-8px) scale(1.02);
      box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
    }

    /* Professional asymmetric positioning - no overlaps */
    .creative-full {
      grid-column: 1 / -1;
      grid-row: span 1;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }

    .creative-large {
      grid-column: span 4;
      grid-row: span 1;
    }

    .creative-medium {
      grid-column: span 3;
      grid-row: span 1;
    }

    .creative-small {
      grid-column: span 2;
      grid-row: span 1;
    }

    /* Balanced layout patterns */
    .creative-item:nth-child(2n) .creative-large {
      grid-column: 3 / -1;
    }

    .creative-item:nth-child(3n) .creative-medium {
      grid-column: 4 / -1;
    }

    /* Responsive creative */
    @media (max-width: 1024px) {
      .creative-container {
        grid-template-columns: repeat(4, 1fr);
        grid-auto-rows: 260px;
        gap: 1.5rem;
        max-width: 900px;
      }

      .creative-large {
        grid-column: span 3;
      }

      .creative-medium {
        grid-column: span 2;
      }

      .creative-small {
        grid-column: span 2;
      }
    }

    @media (max-width: 768px) {
      .creative-container {
        grid-template-columns: 1fr;
        grid-auto-rows: auto;
        gap: 1.5rem;
        max-width: 100%;
      }

      .creative-full,
      .creative-large,
      .creative-medium,
      .creative-small {
        grid-column: span 1;
        grid-row: span 1;
      }

      .creative-item {
        min-height: 220px;
        border-radius: 16px;
      }

      .creative-item:hover {
        transform: translateY(-4px) scale(1.01);
      }
    }
    """
  end

  # Public API functions
  def get_available_layout_styles do
    [
      %{
        key: "mobile_single",
        name: "Professional Flow",
        description: "Clean vertical layout, mobile-first",
        icon: "💼",
        best_for: "Professional, readable content"
      },
      %{
        key: "grid_uniform",
        name: "Creative Grid",
        description: "Masonry-style grid layout",
        icon: "🎨",
        best_for: "Visual portfolios, varied content"
      },
      %{
        key: "dashboard",
        name: "Executive Dashboard",
        description: "Clean grid with consistent card sizes",
        icon: "📊",
        best_for: "Organized, business portfolios"
      },
      %{
        key: "creative_modern",
        name: "Modern Showcase",
        description: "Asymmetric, artistic layout",
        icon: "✨",
        best_for: "Creative professionals, designers"
      }
    ]
  end

  def validate_layout_compatibility(sections, layout_style) do
    visible_sections = get_visible_sections(sections)
    section_count = length(visible_sections)

    case {layout_style, section_count} do
      {"dashboard", count} when count < 3 ->
        %{compatible: false, message: "Dashboard works best with 3+ sections"}

      {"grid_uniform", count} when count < 2 ->
        %{compatible: false, message: "Creative grid needs 2+ sections"}

      {"creative_modern", count} when count < 2 ->
        %{compatible: false, message: "Modern layout needs 2+ sections"}

      _ ->
        %{compatible: true, message: "Layout is compatible"}
    end
  end
end
