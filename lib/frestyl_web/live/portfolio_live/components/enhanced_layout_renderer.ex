# File: lib/frestyl_web/live/portfolio_live/components/enhanced_layout_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer do
  @moduledoc """
  Enhanced layout renderer with proper Time Machine support and preserved Skills styling
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]

  # ============================================================================
  # MAIN RENDER FUNCTION - Updated with Time Machine support
  # ============================================================================

  def render_portfolio_layout(portfolio, sections, layout_type, color_scheme, theme, video_options \\ %{}) do
    IO.puts("🎨 ENHANCED LAYOUT RENDERER - REVAMPED VERSION")
    IO.puts("🎨 Portfolio: #{portfolio.title}")
    IO.puts("🎨 Layout: #{layout_type}")
    IO.puts("🎨 Sections count: #{length(sections || [])}")

    # Route to appropriate layout renderer
    result = case normalize_layout_type(layout_type) do
      # Use the main PortfolioLayoutEngine for existing layouts
      layout when layout in [:sidebar, :single, :workspace] ->
        FrestylWeb.PortfolioLive.Components.PortfolioLayoutEngine.render_portfolio_layout(
          portfolio, sections, layout_type, color_scheme, theme
        )

      # Handle grid layout using our custom grid renderer
      :grid ->
        render_grid_layout(portfolio, sections, get_layout_config(layout_type, color_scheme, theme))

      # Handle time_machine layout
      :time_machine ->
        render_time_machine_layout(portfolio, sections, get_layout_config(layout_type, color_scheme, theme))

      # Default fallback
      _ ->
        FrestylWeb.PortfolioLive.Components.PortfolioLayoutEngine.render_portfolio_layout(
          portfolio, sections, "single", color_scheme, theme
        )
    end

    # Convert string results to safe HTML
    case result do
      result when is_binary(result) -> Phoenix.HTML.raw(result)
      result -> result  # Already a safe component
    end
  end

  defp normalize_sections_for_rendering(sections) when is_list(sections) do
    sections
    |> Enum.map(&normalize_section_for_display/1)
    |> Enum.filter(&valid_section?/1)
  end

defp normalize_sections_for_rendering(_), do: []

defp normalize_section_for_display(section) when is_map(section) do
  section
end

defp normalize_section_for_display(_), do: nil

defp valid_section?(nil), do: false
defp valid_section?(section) when is_map(section) do
  Map.has_key?(section, :id) || Map.has_key?(section, "id")
end
defp valid_section?(_), do: false

defp filter_visible_sections(sections) do
  sections
  |> Enum.filter(&(&1.visible))
  |> Enum.sort_by(&(&1.position))
end


  defp normalize_layout_type(layout_type) do
    case to_string(layout_type) |> String.downcase() do
      "sidebar" -> :sidebar
      "single" -> :single
      "workspace" -> :workspace
      "grid" -> :grid                    # Now properly handled
      "time_machine" -> :time_machine    # Now properly handled
      "dashboard" -> :workspace
      "creative_modern" -> :workspace
      _ -> :single
    end
  end

  defp ensure_hero_first(sections) do
  {hero_sections, other_sections} = Enum.split_with(sections, fn section ->
    section.section_type in [:hero, "hero"]
  end)

  hero_sections ++ other_sections
end


defp render_time_machine_layout(portfolio, sections, config) do
  ordered_sections = ensure_hero_first(sections)

  """
  <div class="time-machine-minimal" id="time-machine-container">
    <style>
      .time-machine-minimal {
        height: 100vh;
        overflow: hidden;
        position: relative;
        background: #fafbfc;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
      }

      /* Header */
      .portfolio-header {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        z-index: 100;
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        border-bottom: 1px solid rgba(0, 0, 0, 0.06);
        padding: 20px 0;
        transition: all 0.3s ease;
      }

      .header-content {
        max-width: 800px;
        margin: 0 auto;
        text-align: center;
        padding: 0 32px;
      }

      .portfolio-title {
        font-size: 1.75rem;
        font-weight: 600;
        color: #1e293b;
        margin-bottom: 4px;
        letter-spacing: -0.01em;
      }

      .portfolio-subtitle {
        font-size: 0.875rem;
        color: #64748b;
        font-weight: 400;
      }

      /* Card Stack Container */
      .card-stack {
        position: relative;
        height: 100vh;
        padding-top: 120px;
        display: flex;
        align-items: flex-start;
        justify-content: center;
        perspective: 1000px;
      }

      /* Larger Cards - Better Screen Usage */
      .stack-card {
        position: absolute;
        background: white;
        border-radius: 20px;
        transition: all 0.8s cubic-bezier(0.16, 1, 0.3, 1);
        will-change: transform, opacity, filter;
        overflow: hidden;
        /* Consistent light shadow for all cards */
        box-shadow:
          0 1px 3px rgba(0, 0, 0, 0.05),
          0 8px 32px rgba(0, 0, 0, 0.08),
          0 24px 60px rgba(0, 0, 0, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.8);

        /* Larger card sizes - better screen usage */
        width: 95%;
        max-width: 700px;
        max-height: 75vh;
        min-height: 500px;

        /* Mobile - use more space */
        @media (max-width: 768px) {
          width: 92%;
          max-height: 80vh;
          min-height: 450px;
        }

        /* Desktop - generous sizing */
        @media (min-width: 1024px) {
          width: 650px;
          max-height: 70vh;
          min-height: 550px;
        }

        /* Large screens - even more space */
        @media (min-width: 1440px) {
          width: 750px;
          max-height: 65vh;
          min-height: 600px;
        }
      }

      /* Card stacking positions - same light shadow for all */
      .stack-card[data-position="0"] {
        transform: translateY(0) translateZ(0) scale(1) rotateX(0deg);
        opacity: 1;
        z-index: 50;
        filter: blur(0px) brightness(1);
      }

      .stack-card[data-position="1"] {
        transform: translateY(-15px) translateZ(-30px) scale(0.97) rotateX(1deg);
        opacity: 0.9;
        z-index: 49;
        filter: blur(0.3px) brightness(0.98);
      }

      .stack-card[data-position="2"] {
        transform: translateY(-25px) translateZ(-60px) scale(0.94) rotateX(2deg);
        opacity: 0.8;
        z-index: 48;
        filter: blur(0.6px) brightness(0.96);
      }

      .stack-card[data-position="3"] {
        transform: translateY(-35px) translateZ(-90px) scale(0.91) rotateX(3deg);
        opacity: 0.7;
        z-index: 47;
        filter: blur(0.9px) brightness(0.94);
      }

      .stack-card[data-position="4"],
      .stack-card[data-position="5"],
      .stack-card[data-position="6"],
      .stack-card[data-position="7"],
      .stack-card[data-position="8"],
      .stack-card[data-position="9"] {
        transform: translateY(-45px) translateZ(-120px) scale(0.88) rotateX(4deg);
        opacity: 0.6;
        z-index: 46;
        filter: blur(1.2px) brightness(0.92);
      }

      /* Cards that have been swiped away */
      .stack-card[data-position="-1"] {
        transform: translateY(-100vh) scale(0.9);
        opacity: 0;
        z-index: 1;
      }

      /* Card Structure - No section type display */
      .card-header {
        padding: 32px 32px 20px 32px;
        border-bottom: 1px solid #f1f5f9;
        background: linear-gradient(135deg, #fafafa 0%, #ffffff 100%);
        flex-shrink: 0;
        position: relative;
      }

      .card-accent {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 3px;
        border-radius: 20px 20px 0 0;
      }

      .card-title {
        font-size: 1.75rem;
        font-weight: 600;
        color: #1e293b;
        line-height: 1.3;
        text-align: center;
      }

      @media (min-width: 768px) {
        .card-header {
          padding: 40px 40px 24px 40px;
        }

        .card-title {
          font-size: 2rem;
        }
      }

      /* Scrollable content area */
      .card-body {
        flex: 1;
        overflow-y: auto;
        padding: 24px 32px 32px 32px;
        -webkit-overflow-scrolling: touch;
        position: relative;
      }

      @media (min-width: 768px) {
        .card-body {
          padding: 32px 40px 40px 40px;
        }
      }

      .card-body::-webkit-scrollbar {
        width: 3px;
      }

      .card-body::-webkit-scrollbar-track {
        background: transparent;
      }

      .card-body::-webkit-scrollbar-thumb {
        background: rgba(100, 116, 139, 0.3);
        border-radius: 2px;
      }

      .card-body::-webkit-scrollbar-thumb:hover {
        background: rgba(100, 116, 139, 0.5);
      }

      .card-content {
        color: #475569;
        line-height: 1.6;
        font-size: 1rem;
      }

      @media (min-width: 768px) {
        .card-content {
          font-size: 1.05rem;
          line-height: 1.7;
        }
      }

      /* Smooth scroll fade indicator */
      .card-body::after {
        content: '';
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        height: 24px;
        background: linear-gradient(transparent, white);
        opacity: 0;
        transition: opacity 0.3s ease;
        pointer-events: none;
      }

      .card-body.has-scroll::after {
        opacity: 1;
      }

      /* Minimal Navigation */
      .nav-dots {
        position: fixed;
        bottom: 40px;
        left: 50%;
        transform: translateX(-50%);
        display: flex;
        gap: 12px;
        z-index: 100;
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(20px);
        padding: 12px 20px;
        border-radius: 24px;
        border: 1px solid rgba(0, 0, 0, 0.06);
      }

      .nav-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: rgba(100, 116, 139, 0.3);
        cursor: pointer;
        transition: all 0.3s ease;
      }

      .nav-dot:hover {
        background: rgba(100, 116, 139, 0.6);
        transform: scale(1.2);
      }

      .nav-dot.active {
        background: #3b82f6;
        transform: scale(1.3);
      }

      /* Section-specific accent colors */
      .hero-accent { background: #667eea; }
      .skills-accent { background: #10b981; }
      .experience-accent { background: #f59e0b; }
      .projects-accent { background: #ef4444; }
      .education-accent { background: #8b5cf6; }
      .contact-accent { background: #06b6d4; }
      .achievements-accent { background: #f97316; }
      .timeline-accent { background: #ec4899; }
      .intro-accent { background: #3b82f6; }
      .custom-accent { background: #6b7280; }
    </style>

    <!-- Portfolio Header -->
    <header class="portfolio-header">
      <div class="header-content">
        <h1 class="portfolio-title">#{portfolio.title}</h1>
        #{if portfolio.description, do: "<p class=\"portfolio-subtitle\">#{portfolio.description}</p>", else: ""}
      </div>
    </header>

    <!-- Card Stack -->
    <div class="card-stack" id="card-stack">
      #{ordered_sections |> Enum.with_index() |> Enum.map(fn {section, index} ->
        render_minimal_stack_card(section, index, config)
      end) |> Enum.join("\n")}
    </div>

    <!-- Minimal Navigation -->
    <div class="nav-dots">
      #{0..(length(ordered_sections) - 1) |> Enum.map(fn index ->
        active_class = if index == 0, do: " active", else: ""
        "<div class=\"nav-dot#{active_class}\" data-index=\"#{index}\"></div>"
      end) |> Enum.join("\n")}
    </div>

    <!-- Keep the same smooth JavaScript from before -->
    <script>
      (() => {
        const container = document.getElementById('time-machine-container');
        const cardStack = document.getElementById('card-stack');
        const cards = cardStack.querySelectorAll('.stack-card');
        const dots = document.querySelectorAll('.nav-dot');

        let currentCard = 0;
        let isTransitioning = false;
        let startY = 0;
        let startX = 0;
        let isDragging = false;

        function updateCardPositions() {
          cards.forEach((card, index) => {
            const position = index - currentCard;
            card.setAttribute('data-position', position);

            // Check for scrollable content
            const cardBody = card.querySelector('.card-body');
            if (cardBody) {
              const hasScroll = cardBody.scrollHeight > cardBody.clientHeight;
              cardBody.classList.toggle('has-scroll', hasScroll);
            }
          });

          // Update navigation dots
          dots.forEach((dot, index) => {
            dot.classList.toggle('active', index === currentCard);
          });
        }

        function goToCard(index) {
          if (index >= 0 && index < cards.length && !isTransitioning) {
            isTransitioning = true;
            currentCard = index;
            updateCardPositions();

            setTimeout(() => {
              isTransitioning = false;
            }, 800);
          }
        }

        function nextCard() {
          if (currentCard < cards.length - 1) {
            goToCard(currentCard + 1);
          }
        }

        function prevCard() {
          if (currentCard > 0) {
            goToCard(currentCard - 1);
          }
        }

        // Smooth touch handling
        container.addEventListener('touchstart', (e) => {
          if (isTransitioning) return;
          startY = e.touches[0].clientY;
          startX = e.touches[0].clientX;
          isDragging = true;
        }, { passive: true });

        container.addEventListener('touchend', (e) => {
          if (!isDragging) return;
          isDragging = false;

          const endY = e.changedTouches[0].clientY;
          const endX = e.changedTouches[0].clientX;
          const deltaY = startY - endY;
          const deltaX = Math.abs(startX - endX);
          const threshold = 60;

          // Ignore horizontal swipes or small movements
          if (deltaX > 50 || Math.abs(deltaY) < threshold) return;

          if (deltaY > 0) {
            nextCard();
          } else {
            prevCard();
          }
        }, { passive: true });

        // Smooth wheel handling
        let wheelTimeout;
        container.addEventListener('wheel', (e) => {
          if (isTransitioning) return;

          // Allow scrolling within active card
          const activeCard = cards[currentCard];
          const cardBody = activeCard?.querySelector('.card-body');
          if (cardBody && cardBody.contains(e.target)) {
            return; // Let the card handle scrolling
          }

          e.preventDefault();
          clearTimeout(wheelTimeout);

          wheelTimeout = setTimeout(() => {
            if (e.deltaY > 40) {
              nextCard();
            } else if (e.deltaY < -40) {
              prevCard();
            }
          }, 100);
        }, { passive: false });

        // Keyboard navigation
        document.addEventListener('keydown', (e) => {
          if (isTransitioning) return;

          switch(e.key) {
            case 'ArrowDown':
            case 'PageDown':
              e.preventDefault();
              nextCard();
              break;
            case 'ArrowUp':
            case 'PageUp':
              e.preventDefault();
              prevCard();
              break;
          }
        });

        // Dot navigation
        dots.forEach((dot, index) => {
          dot.addEventListener('click', () => {
            goToCard(index);
          });
        });

        // Initialize
        updateCardPositions();
      })();
    </script>
  </div>
  """
end

defp render_minimal_stack_card(section, index, config) do
  accent_class = get_stack_accent_class(section.section_type)

  """
  <div class="stack-card" data-index="#{index}" data-section="#{section.id}">
    <!-- Card Header - No section type -->
    <div class="card-header">
      <div class="card-accent #{accent_class}"></div>
      <h2 class="card-title">#{section.title}</h2>
    </div>

    <!-- Scrollable Card Body -->
    <div class="card-body">
      <div class="card-content">
        #{render_enhanced_section_content(section, "stack")}
      </div>
    </div>
  </div>
  """
end

defp get_stack_accent_class(section_type) do
  case to_string(section_type) do
    "hero" -> "hero-accent"
    "skills" -> "skills-accent"
    "experience" -> "experience-accent"
    "projects" -> "projects-accent"
    "education" -> "education-accent"
    "contact" -> "contact-accent"
    "achievements" -> "achievements-accent"
    "timeline" -> "timeline-accent"
    "intro" -> "intro-accent"
    "custom" -> "custom-accent"
    _ -> "custom-accent"
  end
end

defp render_grid_layout(portfolio, sections, config) do
  """
  <div class="enhanced-grid-layout min-h-screen bg-gradient-to-br from-gray-50 to-gray-100">
    <!-- Elegant Header -->
    <header class="bg-white/80 backdrop-blur-lg border-b border-gray-200/50 sticky top-0 z-30">
      <div class="max-w-7xl mx-auto px-8 py-8">
        <div class="text-center">
          <h1 class="text-4xl font-light text-gray-900 mb-3 tracking-tight">#{portfolio.title}</h1>
          #{if portfolio.description, do: "<p class=\"text-gray-600 text-lg max-w-2xl mx-auto leading-relaxed\">#{portfolio.description}</p>", else: ""}
        </div>
      </div>
    </header>

    <!-- Enhanced Grid Content -->
    <main class="max-w-7xl mx-auto px-8 py-12">
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-3 gap-8">
        #{sections |> Enum.map(&render_enhanced_grid_card(&1, config)) |> Enum.join("\n")}
      </div>
    </main>
  </div>
  """
end

defp render_enhanced_grid_card(section, config) do
  accent_color = get_section_accent_color(section.section_type)

  """
  <div id="section-#{section.id}" class="enhanced-grid-card group">
    <style>
      .enhanced-grid-card {
        background: white;
        border-radius: 20px;
        height: 400px;
        display: flex;
        flex-direction: column;
        overflow: hidden;
        position: relative;
        transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
        box-shadow:
          0 1px 3px rgba(0, 0, 0, 0.05),
          0 8px 32px rgba(0, 0, 0, 0.08),
          0 24px 60px rgba(0, 0, 0, 0.06);
        border: 1px solid rgba(255, 255, 255, 0.8);
      }

      .enhanced-grid-card:hover {
        transform: translateY(-8px) scale(1.02);
        box-shadow:
          0 4px 6px rgba(0, 0, 0, 0.07),
          0 20px 50px rgba(0, 0, 0, 0.12),
          0 40px 90px rgba(0, 0, 0, 0.08);
      }

      .card-header {
        padding: 24px 24px 16px 24px;
        border-bottom: 1px solid #f1f5f9;
        background: linear-gradient(135deg, #fafafa 0%, #ffffff 100%);
        flex-shrink: 0;
        position: relative;
        overflow: hidden;
      }

      .card-header::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        height: 3px;
        background: #{accent_color};
        transform: scaleX(0);
        transform-origin: left;
        transition: transform 0.4s ease;
      }

      .enhanced-grid-card:hover .card-header::before {
        transform: scaleX(1);
      }

      .card-title {
        font-size: 1.25rem;
        font-weight: 600;
        color: #1e293b;
        margin-bottom: 6px;
        line-height: 1.3;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
        overflow: hidden;
      }

      .card-type {
        font-size: 0.75rem;
        color: #64748b;
        text-transform: uppercase;
        letter-spacing: 1px;
        font-weight: 500;
        display: flex;
        align-items: center;
        gap: 8px;
      }

      .card-type::before {
        content: '';
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: #{accent_color};
        flex-shrink: 0;
      }

      .card-body {
        flex: 1;
        overflow-y: auto;
        padding: 20px 24px 24px 24px;
        position: relative;
        -webkit-overflow-scrolling: touch;
      }

      .card-body::-webkit-scrollbar {
        width: 4px;
      }

      .card-body::-webkit-scrollbar-track {
        background: transparent;
      }

      .card-body::-webkit-scrollbar-thumb {
        background: #{accent_color};
        border-radius: 2px;
        opacity: 0.6;
      }

      .card-body::-webkit-scrollbar-thumb:hover {
        opacity: 1;
      }

      .card-content {
        color: #475569;
        line-height: 1.6;
        font-size: 0.9rem;
      }

      /* Scroll fade indicators */
      .card-body::before {
        content: '';
        position: absolute;
        bottom: 0;
        left: 0;
        right: 0;
        height: 20px;
        background: linear-gradient(transparent, white);
        opacity: 0;
        transition: opacity 0.3s ease;
        pointer-events: none;
        z-index: 10;
      }

      .card-body.has-scroll::before {
        opacity: 1;
      }

      /* Content type specific styling */
      .skills-content .skill-item {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 12px 16px;
        margin-bottom: 8px;
        background: #f8fafc;
        border-radius: 12px;
        border: 1px solid #e2e8f0;
        transition: all 0.2s ease;
      }

      .skills-content .skill-item:hover {
        background: #f1f5f9;
        border-color: #{accent_color};
      }

      .experience-content .experience-item {
        padding: 16px 0;
        border-bottom: 1px solid #f1f5f9;
      }

      .experience-content .experience-item:last-child {
        border-bottom: none;
      }

      .projects-content .project-item {
        padding: 12px;
        background: #fafbfc;
        border-radius: 8px;
        margin-bottom: 12px;
        border-left: 3px solid #{accent_color};
      }

      /* Interactive elements */
      .card-footer {
        padding: 16px 24px;
        background: #fafbfc;
        border-top: 1px solid #f1f5f9;
        flex-shrink: 0;
        opacity: 0;
        transform: translateY(10px);
        transition: all 0.3s ease;
      }

      .enhanced-grid-card:hover .card-footer {
        opacity: 1;
        transform: translateY(0);
      }

      .view-more-btn {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        color: #{accent_color};
        font-size: 0.875rem;
        font-weight: 500;
        text-decoration: none;
        transition: all 0.2s ease;
      }

      .view-more-btn:hover {
        gap: 8px;
        color: #1e293b;
      }

      .view-more-btn svg {
        width: 14px;
        height: 14px;
        transition: transform 0.2s ease;
      }

      .view-more-btn:hover svg {
        transform: translateX(2px);
      }
    </style>

    <!-- Card Header -->
    <div class="card-header">
      <h3 class="card-title">#{section.title}</h3>
      <div class="card-type">
        #{get_section_type_label(section.section_type)}
      </div>
    </div>

    <!-- Scrollable Card Body -->
    <div class="card-body" id="card-body-#{section.id}">
      <div class="card-content">
        #{render_enhanced_section_content(section, "grid")}
      </div>
    </div>

    <!-- Interactive Footer -->
    <div class="card-footer">
      <a href="#section-#{section.id}" class="view-more-btn">
        View Details
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
        </svg>
      </a>
    </div>

    <script>
      // Add scroll fade effect
      (function() {
        const cardBody = document.getElementById('card-body-#{section.id}');

        function checkScroll() {
          const hasScroll = cardBody.scrollHeight > cardBody.clientHeight;
          cardBody.classList.toggle('has-scroll', hasScroll);
        }

        checkScroll();
        window.addEventListener('resize', checkScroll);

        cardBody.addEventListener('scroll', function() {
          const isScrolledToBottom = cardBody.scrollHeight - cardBody.scrollTop === cardBody.clientHeight;
          cardBody.classList.toggle('scrolled-to-bottom', isScrolledToBottom);
        });
      })();
    </script>
  </div>
  """
end

defp get_section_accent_color(section_type) do
  case to_string(section_type) do
    "hero" -> "#667eea"
    "skills" -> "#10b981"
    "experience" -> "#f59e0b"
    "projects" -> "#ef4444"
    "education" -> "#8b5cf6"
    "contact" -> "#06b6d4"
    "achievements" -> "#f97316"
    "timeline" -> "#ec4899"
    "intro" -> "#3b82f6"
    "custom" -> "#6b7280"
    _ -> "#64748b"
  end
end

  # Add this function to enhanced_layout_renderer.ex

defp render_workspace_layout_revamped(portfolio, sections, visible_sections, config) do
  """
  <div class="portfolio-layout workspace-layout min-h-screen bg-white">
    <!-- Top Navigation Bar -->
    <nav class="fixed top-0 left-0 right-0 z-40 bg-white shadow-sm border-b border-gray-200">
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
        <div class="max-w-7xl mx-auto px-6 text-center">
          <h1 class="text-3xl font-bold text-gray-900 mb-4">#{portfolio.title}</h1>
          <p class="text-xl text-gray-600 max-w-3xl mx-auto">#{portfolio.description || "Welcome to my portfolio"}</p>
        </div>
      </div>

      <!-- Dynamic Dashboard Layout -->
      <div class="max-w-7xl mx-auto px-6 py-8">
        #{render_workspace_dynamic_sections(sections, config)}
      </div>
    </main>

    #{render_layout_scripts()}
  </div>
  """
end

# You'll also need these helper functions:

defp render_workspace_nav_items(visible_sections) do
  visible_sections
  |> Enum.map(fn section ->
    """
    <a href="#section-#{section.id}"
       class="text-gray-600 hover:text-gray-900 transition-colors">
      #{section.title}
    </a>
    """
  end)
  |> Enum.join("\n")
end

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
       class="workspace-large-card bg-white rounded-xl p-8 shadow-md hover:shadow-lg transition-all duration-300">
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
       class="workspace-medium-card bg-white rounded-xl p-6 shadow-md hover:shadow-lg transition-all duration-300">
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
       class="workspace-compact-card bg-white rounded-lg p-4 shadow-md hover:shadow-lg transition-all duration-300">
    <div class="mb-3">
      <h3 class="text-base font-semibold text-gray-900">#{section.title}</h3>
    </div>
    <div class="card-content text-sm">
      #{enhanced_content}
    </div>
  </div>
  """
end

defp render_layout_scripts() do
  """
  <script>
    function scrollToSection(sectionId) {
      const element = document.getElementById('section-' + sectionId);
      if (element) {
        element.scrollIntoView({ behavior: 'smooth' });
      }
    }
  </script>
  """
end

  # ============================================================================
  # ENHANCED SECTION CONTENT RENDERING - Preserves Skills styling
  # ============================================================================

  defp render_enhanced_section_content(section, layout_type \\ "default") do
    case to_string(section.section_type) do
      "skills" ->
        render_skills_section_enhanced(section, layout_type)
      "experience" ->
        render_experience_section_enhanced(section, layout_type)
      "projects" ->
        render_projects_section_enhanced(section, layout_type)
      "education" ->
        render_education_section_enhanced(section, layout_type)
      "intro" ->
        render_intro_section_enhanced(section, layout_type)
      "hero" ->
        render_hero_section_enhanced(section, layout_type)
      "contact" ->
        render_contact_section_enhanced(section, layout_type)
      "achievements" ->
        render_achievements_section_enhanced(section, layout_type)
      "timeline" ->
        render_timeline_section_enhanced(section, layout_type)
      "custom" ->
        render_custom_section_enhanced(section, layout_type)
      _ ->
        render_generic_section_enhanced(section, layout_type)
    end
  end

  # ============================================================================
  # SKILLS SECTION - PRESERVED CURATED STYLING
  # ============================================================================

  defp render_skills_section_enhanced(section, layout_type) do
    content = section.content || %{}
    items = Map.get(content, "items", [])

    if is_list(items) and length(items) > 0 do
      skills_html = items
      |> Enum.map(&render_skill_item_with_colors(&1, layout_type))
      |> Enum.join("\n")

      case layout_type do
        "grid" ->
          """
          <div class="skills-grid space-y-3">
            #{skills_html}
          </div>
          """
        _ ->
          """
          <div class="skills-container space-y-4">
            #{skills_html}
          </div>
          """
      end
    else
      """
      <div class="text-center py-8 text-gray-500">
        <svg class="w-12 h-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        <p class="text-sm">No skills added yet</p>
      </div>
      """
    end
  end

  defp render_skill_item_with_colors(skill, layout_type) do
    skill_name = Map.get(skill, "name", "")
    skill_level = Map.get(skill, "level", "beginner")
    skill_category = Map.get(skill, "category", "other")
    years_experience = Map.get(skill, "years_experience", "")

    # PRESERVED: Curated color schemes for different categories
    {bg_color, text_color, border_color} = get_skill_category_colors(skill_category)

    # PRESERVED: Level indicators with proper styling
    level_indicator = get_skill_level_indicator(skill_level)

    experience_badge = if years_experience != "" and years_experience != nil do
      "<span class=\"text-xs text-gray-500 ml-2\">#{years_experience} yrs</span>"
    else
      ""
    end

    case layout_type do
      "grid" ->
        """
        <div class="skill-item-grid flex items-center justify-between p-3 #{bg_color} border #{border_color} rounded-lg">
          <div class="flex items-center space-x-2">
            <span class="skill-name text-sm font-medium #{text_color}">#{skill_name}</span>
            #{experience_badge}
          </div>
          <div class="skill-level">
            #{level_indicator}
          </div>
        </div>
        """
      _ ->
        """
        <div class="skill-item flex items-center justify-between p-4 #{bg_color} border #{border_color} rounded-xl hover:shadow-md transition-all">
          <div class="skill-info">
            <h4 class="skill-name font-semibold #{text_color}">#{skill_name}</h4>
            <p class="skill-category text-xs text-gray-600 capitalize mt-1">#{skill_category}#{experience_badge}</p>
          </div>
          <div class="skill-level">
            #{level_indicator}
          </div>
        </div>
        """
    end
  end

  # PRESERVED: Curated color schemes for skill categories
  defp get_skill_category_colors(category) do
    case String.downcase(to_string(category)) do
      "programming" -> {"bg-blue-50", "text-blue-900", "border-blue-200"}
      "languages" -> {"bg-green-50", "text-green-900", "border-green-200"}
      "design" -> {"bg-purple-50", "text-purple-900", "border-purple-200"}
      "technical" -> {"bg-indigo-50", "text-indigo-900", "border-indigo-200"}
      "soft_skills" -> {"bg-amber-50", "text-amber-900", "border-amber-200"}
      "tools" -> {"bg-gray-50", "text-gray-900", "border-gray-200"}
      "frameworks" -> {"bg-cyan-50", "text-cyan-900", "border-cyan-200"}
      "databases" -> {"bg-emerald-50", "text-emerald-900", "border-emerald-200"}
      _ -> {"bg-gray-50", "text-gray-900", "border-gray-200"}
    end
  end

  # PRESERVED: Level indicators with proper styling
  defp get_skill_level_indicator(level) do
    case String.downcase(to_string(level)) do
      "expert" ->
        """
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-green-500 rounded-full"></div>
          <div class="w-2 h-2 bg-green-500 rounded-full"></div>
          <div class="w-2 h-2 bg-green-500 rounded-full"></div>
          <div class="w-2 h-2 bg-green-500 rounded-full"></div>
          <div class="w-2 h-2 bg-green-500 rounded-full"></div>
        </div>
        """
      "advanced" ->
        """
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
          <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
          <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
          <div class="w-2 h-2 bg-blue-500 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
        </div>
        """
      "intermediate" ->
        """
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
          <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
          <div class="w-2 h-2 bg-yellow-500 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
        </div>
        """
      "beginner" ->
        """
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-orange-500 rounded-full"></div>
          <div class="w-2 h-2 bg-orange-500 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
        </div>
        """
      _ ->
        """
        <div class="flex space-x-1">
          <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
          <div class="w-2 h-2 bg-gray-300 rounded-full"></div>
        </div>
        """
    end
  end

  # ============================================================================
  # OTHER SECTION RENDERERS (Enhanced but simplified)
  # ============================================================================

  defp render_experience_section_enhanced(section, layout_type) do
    content = section.content || %{}
    items = Map.get(content, "items", [])

    if is_list(items) and length(items) > 0 do
      experience_html = items
      |> Enum.map(&render_experience_item(&1, layout_type))
      |> Enum.join("\n")

      "<div class=\"experience-list space-y-4\">#{experience_html}</div>"
    else
      render_empty_state("experience", "briefcase")
    end
  end

  defp render_experience_item(item, layout_type) do
    company = Map.get(item, "company", "")
    position = Map.get(item, "position", "")
    description = Map.get(item, "description", "")
    start_date = Map.get(item, "start_date", "")
    end_date = Map.get(item, "end_date", "")

    date_range = format_date_range(start_date, end_date)

    case layout_type do
      "grid" ->
        """
        <div class="experience-item-grid p-3 border border-gray-200 rounded-lg">
          <h4 class="font-medium text-gray-900 text-sm">#{position}</h4>
          <p class="text-xs text-gray-600 mt-1">#{company}</p>
          #{if date_range != "", do: "<p class=\"text-xs text-gray-500 mt-1\">#{date_range}</p>", else: ""}
        </div>
        """
      _ ->
        """
        <div class="experience-item p-4 border border-gray-200 rounded-xl hover:shadow-md transition-all">
          <div class="flex justify-between items-start mb-2">
            <h4 class="font-semibold text-gray-900">#{position}</h4>
            #{if date_range != "", do: "<span class=\"text-sm text-gray-500\">#{date_range}</span>", else: ""}
          </div>
          <p class="text-gray-600 mb-2">#{company}</p>
          #{if description != "", do: "<p class=\"text-sm text-gray-700\">#{description}</p>", else: ""}
        </div>
        """
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp render_empty_state(section_type, icon) do
    icon_svg = case icon do
      "briefcase" ->
        """
        <svg class="w-12 h-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H6a2 2 0 01-2-2V8a2 2 0 012-2V6z"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-12 h-12 mx-auto mb-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
        </svg>
        """
    end

    """
    <div class="text-center py-8 text-gray-500">
      #{icon_svg}
      <p class="text-sm">No #{section_type} added yet</p>
    </div>
    """
  end

  defp format_date_range(start_date, end_date) do
    cond do
      start_date != "" and end_date != "" -> "#{start_date} - #{end_date}"
      start_date != "" and (end_date == "" or end_date == nil) -> "#{start_date} - Present"
      true -> ""
    end
  end

  defp get_section_type_label(section_type) do
    case to_string(section_type) do
      "hero" -> "Introduction"
      "experience" -> "Experience"
      "education" -> "Education"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "contact" -> "Contact"
      "achievements" -> "Achievements"
      "timeline" -> "Timeline"
      "intro" -> "About"
      "custom" -> "Custom"
      _ -> "Section"
    end
  end

  defp filter_visible_sections(sections) do
    sections
    |> Enum.filter(&(&1.visible))
    |> Enum.sort_by(&(&1.position))
  end

  defp get_layout_config(layout_type, color_scheme, typography) do
    %{
      layout_type: layout_type,
      color_scheme: color_scheme,
      typography: typography
    }
  end

  # Placeholder functions for other section types
  defp render_projects_section_enhanced(section, layout_type), do: render_empty_state("projects", "folder")
  defp render_education_section_enhanced(section, layout_type), do: render_empty_state("education", "academic-cap")
  defp render_intro_section_enhanced(section, layout_type), do: render_empty_state("intro", "user")
  defp render_hero_section_enhanced(section, layout_type), do: render_empty_state("hero", "star")
  defp render_contact_section_enhanced(section, layout_type), do: render_empty_state("contact", "mail")
  defp render_achievements_section_enhanced(section, layout_type), do: render_empty_state("achievements", "trophy")
  defp render_timeline_section_enhanced(section, layout_type), do: render_empty_state("timeline", "clock")
  defp render_custom_section_enhanced(section, layout_type), do: render_empty_state("custom", "puzzle")
  defp render_generic_section_enhanced(section, layout_type), do: render_empty_state("content", "document")

  # Additional layout functions (simplified versions)
  defp render_sidebar_layout(portfolio, sections, config), do: render_single_layout(portfolio, sections, config)
  defp render_workspace_layout(portfolio, sections, config), do: render_single_layout(portfolio, sections, config)

  defp render_single_layout(portfolio, sections, config) do
    """
    <div class="portfolio-layout single-layout min-h-screen bg-white">
      <main class="max-w-4xl mx-auto px-6 py-8">
        <header class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900 mb-4">#{portfolio.title}</h1>
          #{if portfolio.description, do: "<p class=\"text-xl text-gray-600\">#{portfolio.description}</p>", else: ""}
        </header>

        <div class="space-y-8">
          #{sections |> Enum.map(&render_single_section(&1, config)) |> Enum.join("\n")}
        </div>
      </main>
    </div>
    """
  end

  defp render_single_section(section, config) do
    """
    <section id="section-#{section.id}" class="bg-white rounded-lg p-6 shadow-sm border border-gray-100">
      <h2 class="text-2xl font-bold text-gray-900 mb-6">#{section.title}</h2>
      #{render_enhanced_section_content(section, "single")}
    </section>
    """
  end
end
