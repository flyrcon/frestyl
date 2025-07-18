# File: lib/frestyl_web/live/portfolio_live/components/theme_consistency_manager.ex

defmodule FrestylWeb.PortfolioLive.Components.ThemeConsistencyManager do
  @moduledoc """
  PATCH 5: Theme consistency manager that ensures all portfolio elements
  (hero, sections, cards, layouts) properly reflect the selected theme,
  layout, and color scheme with complete visual coherence.
  """

  use Phoenix.Component
  import Phoenix.HTML, only: [raw: 1]

  # ============================================================================
  # MAIN THEME CONSISTENCY COORDINATOR
  # ============================================================================

  def apply_complete_theme_consistency(portfolio, sections, assigns) do
    # Extract all theme settings
    theme_settings = extract_complete_theme_settings(portfolio)

    # Generate comprehensive CSS
    complete_css = generate_complete_theme_css(theme_settings)

    # Update assigns with theme data
    enhanced_assigns = assigns
    |> assign(:theme_settings, theme_settings)
    |> assign(:complete_theme_css, complete_css)
    |> assign(:theme, theme_settings.theme)
    |> assign(:layout_type, theme_settings.layout)
    |> assign(:color_scheme, theme_settings.color_scheme)

    {enhanced_assigns, complete_css}
  end

  # ============================================================================
  # COMPLETE THEME SETTINGS EXTRACTION
  # ============================================================================

  defp extract_complete_theme_settings(portfolio) do
    customization = portfolio.customization || %{}

    # Extract theme (Professional, Creative, Minimal, Modern)
    theme = normalize_theme(portfolio.theme || "professional")

    # Extract layout (Standard, Dashboard, Masonry Grid, Timeline, Magazine, Minimal)
    layout = normalize_layout(Map.get(customization, "layout", "standard"))

    # Extract color scheme (Ocean Blue, Forest Green, Royal Purple, Warm Red, Sunset Orange, Modern Teal)
    color_scheme = determine_color_scheme(customization)

    # Extract individual colors
    colors = extract_individual_colors(customization, color_scheme)

    # Get theme-specific configuration
    theme_config = get_theme_specific_config(theme)
    layout_config = get_layout_specific_config(layout)
    color_config = get_color_scheme_config(color_scheme)

    %{
      theme: theme,
      layout: layout,
      color_scheme: color_scheme,
      colors: colors,
      theme_config: theme_config,
      layout_config: layout_config,
      color_config: color_config,
      portfolio: portfolio,
      customization: customization
    }
  end

  defp normalize_theme(theme) do
    case String.downcase(to_string(theme)) do
      "professional" -> "professional"
      "creative" -> "creative"
      "minimal" -> "minimal"
      "modern" -> "modern"
      _ -> "professional"
    end
  end

  defp normalize_layout(layout) do
    case String.downcase(to_string(layout)) do
      "standard" -> "standard"
      "dashboard" -> "dashboard"
      "grid" -> "grid"
      "masonry" -> "grid"
      "masonry_grid" -> "grid"
      "timeline" -> "timeline"
      "magazine" -> "magazine"
      "minimal" -> "minimal"
      _ -> "standard"
    end
  end

  defp determine_color_scheme(customization) do
    # Check if explicitly set
    if scheme = Map.get(customization, "color_scheme") do
      case scheme do
        scheme when scheme in ["blue", "green", "purple", "red", "orange", "teal"] -> scheme
        _ -> determine_scheme_from_colors(customization)
      end
    else
      determine_scheme_from_colors(customization)
    end
  end

  defp determine_scheme_from_colors(customization) do
    primary = Map.get(customization, "primary_color", "#3b82f6")

    case primary do
      "#1e40af" -> "blue"     # Ocean Blue
      "#3b82f6" -> "blue"
      "#60a5fa" -> "blue"
      "#065f46" -> "green"    # Forest Green
      "#059669" -> "green"
      "#34d399" -> "green"
      "#581c87" -> "purple"   # Royal Purple
      "#7c3aed" -> "purple"
      "#a78bfa" -> "purple"
      "#991b1b" -> "red"      # Warm Red
      "#dc2626" -> "red"
      "#f87171" -> "red"
      "#ea580c" -> "orange"   # Sunset Orange
      "#f97316" -> "orange"
      "#fb923c" -> "orange"
      "#0f766e" -> "teal"     # Modern Teal
      "#14b8a6" -> "teal"
      "#5eead4" -> "teal"
      _ -> "blue"             # Default
    end
  end

  defp extract_individual_colors(customization, color_scheme) do
    scheme_defaults = get_color_scheme_colors(color_scheme)

    %{
      primary: Map.get(customization, "primary_color", Enum.at(scheme_defaults, 0)),
      secondary: Map.get(customization, "secondary_color", Enum.at(scheme_defaults, 1)),
      accent: Map.get(customization, "accent_color", Enum.at(scheme_defaults, 2)),
      background: Map.get(customization, "background_color", "#ffffff"),
      text: Map.get(customization, "text_color", "#1f2937")
    }
  end

  # ============================================================================
  # THEME-SPECIFIC CONFIGURATIONS
  # ============================================================================

  defp get_theme_specific_config(theme) do
    case theme do
      "professional" -> %{
        typography: %{
          font_family: "Inter, system-ui, sans-serif",
          heading_weight: "font-semibold",
          body_weight: "font-normal",
          line_height: "leading-relaxed"
        },
        spacing: %{
          section_gap: "space-y-16",
          card_padding: "p-6",
          container_padding: "px-4 sm:px-6 lg:px-8"
        },
        borders: %{
          radius: "rounded-xl",
          card_border: "border border-gray-200",
          subtle_border: "border-gray-100"
        },
        shadows: %{
          card: "shadow-lg",
          hover: "hover:shadow-xl",
          subtle: "shadow-sm"
        },
        animations: %{
          transition: "transition-all duration-300",
          hover_scale: "hover:scale-[1.02]",
          button_transition: "transition-colors duration-200"
        }
      }

      "creative" -> %{
        typography: %{
          font_family: "Inter, system-ui, sans-serif",
          heading_weight: "font-bold",
          body_weight: "font-normal",
          line_height: "leading-loose"
        },
        spacing: %{
          section_gap: "space-y-20",
          card_padding: "p-8",
          container_padding: "px-6 sm:px-8 lg:px-12"
        },
        borders: %{
          radius: "rounded-2xl",
          card_border: "border-2 border-purple-200",
          subtle_border: "border-purple-100"
        },
        shadows: %{
          card: "shadow-2xl",
          hover: "hover:shadow-3xl",
          subtle: "shadow-lg"
        },
        animations: %{
          transition: "transition-all duration-500",
          hover_scale: "hover:scale-105",
          button_transition: "transition-all duration-300"
        }
      }

      "minimal" -> %{
        typography: %{
          font_family: "Inter, system-ui, sans-serif",
          heading_weight: "font-light",
          body_weight: "font-light",
          line_height: "leading-loose"
        },
        spacing: %{
          section_gap: "space-y-24",
          card_padding: "p-8",
          container_padding: "px-4 sm:px-6 lg:px-8"
        },
        borders: %{
          radius: "rounded-none",
          card_border: "border-none",
          subtle_border: "border-gray-50"
        },
        shadows: %{
          card: "shadow-none",
          hover: "hover:shadow-sm",
          subtle: "shadow-none"
        },
        animations: %{
          transition: "transition-opacity duration-300",
          hover_scale: "hover:scale-[1.01]",
          button_transition: "transition-opacity duration-200"
        }
      }

      "modern" -> %{
        typography: %{
          font_family: "Inter, system-ui, sans-serif",
          heading_weight: "font-medium",
          body_weight: "font-normal",
          line_height: "leading-relaxed"
        },
        spacing: %{
          section_gap: "space-y-18",
          card_padding: "p-6",
          container_padding: "px-4 sm:px-6 lg:px-8"
        },
        borders: %{
          radius: "rounded-xl",
          card_border: "border border-blue-200",
          subtle_border: "border-blue-100"
        },
        shadows: %{
          card: "shadow-lg",
          hover: "hover:shadow-2xl",
          subtle: "shadow-md"
        },
        animations: %{
          transition: "transition-all duration-400",
          hover_scale: "hover:scale-[1.03]",
          button_transition: "transition-all duration-250"
        }
      }
    end
  end

  defp get_layout_specific_config(layout) do
    case layout do
      "dashboard" -> %{
        container_max_width: "max-w-7xl",
        grid_columns: "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4",
        card_height: "h-64",
        section_spacing: "gap-6"
      }

      "grid" -> %{
        container_max_width: "max-w-7xl",
        grid_columns: "masonry-layout",
        card_height: "variable",
        section_spacing: "gap-6"
      }

      "timeline" -> %{
        container_max_width: "max-w-4xl",
        grid_columns: "single-column",
        card_height: "auto",
        section_spacing: "space-y-12"
      }

      "magazine" -> %{
        container_max_width: "max-w-7xl",
        grid_columns: "grid-cols-1 md:grid-cols-2 lg:grid-cols-3",
        card_height: "h-80",
        section_spacing: "gap-8"
      }

      "minimal" -> %{
        container_max_width: "max-w-3xl",
        grid_columns: "single-column",
        card_height: "auto",
        section_spacing: "space-y-24"
      }

      _ -> %{ # standard
        container_max_width: "max-w-4xl",
        grid_columns: "single-column",
        card_height: "auto",
        section_spacing: "space-y-16"
      }
    end
  end

  defp get_color_scheme_config(color_scheme) do
    colors = get_color_scheme_colors(color_scheme)

    %{
      primary: Enum.at(colors, 0),
      secondary: Enum.at(colors, 1),
      accent: Enum.at(colors, 2),
      name: get_color_scheme_name(color_scheme),
      css_class_prefix: color_scheme
    }
  end

  defp get_color_scheme_colors(scheme) do
    case scheme do
      "blue" -> ["#1e40af", "#3b82f6", "#60a5fa"]      # Ocean Blue
      "green" -> ["#065f46", "#059669", "#34d399"]     # Forest Green
      "purple" -> ["#581c87", "#7c3aed", "#a78bfa"]    # Royal Purple
      "red" -> ["#991b1b", "#dc2626", "#f87171"]       # Warm Red
      "orange" -> ["#ea580c", "#f97316", "#fb923c"]    # Sunset Orange
      "teal" -> ["#0f766e", "#14b8a6", "#5eead4"]      # Modern Teal
      _ -> ["#3b82f6", "#60a5fa", "#93c5fd"]           # Default Blue
    end
  end

  defp get_color_scheme_name(scheme) do
    case scheme do
      "blue" -> "Ocean Blue"
      "green" -> "Forest Green"
      "purple" -> "Royal Purple"
      "red" -> "Warm Red"
      "orange" -> "Sunset Orange"
      "teal" -> "Modern Teal"
      _ -> "Ocean Blue"
    end
  end

  # ============================================================================
  # COMPLETE THEME CSS GENERATION
  # ============================================================================

  def generate_complete_theme_css(theme_settings) do
    """
    <style id="complete-theme-css">
    /* PATCH 5: Complete Theme Consistency CSS */

    #{generate_css_variables(theme_settings)}
    #{generate_theme_base_styles(theme_settings)}
    #{generate_layout_specific_styles(theme_settings)}
    #{generate_component_styles(theme_settings)}
    #{generate_responsive_styles(theme_settings)}
    #{generate_animation_styles(theme_settings)}
    </style>
    """
  end

  defp generate_css_variables(theme_settings) do
    colors = theme_settings.colors
    theme_config = theme_settings.theme_config

    """
    :root {
      /* Color Variables */
      --theme-primary: #{colors.primary};
      --theme-secondary: #{colors.secondary};
      --theme-accent: #{colors.accent};
      --theme-background: #{colors.background};
      --theme-text: #{colors.text};

      /* Theme-specific adjustments */
      --theme-primary-50: #{lighten_color(colors.primary, 90)};
      --theme-primary-100: #{lighten_color(colors.primary, 80)};
      --theme-primary-200: #{lighten_color(colors.primary, 60)};
      --theme-primary-300: #{lighten_color(colors.primary, 40)};
      --theme-primary-400: #{lighten_color(colors.primary, 20)};
      --theme-primary-500: #{colors.primary};
      --theme-primary-600: #{darken_color(colors.primary, 10)};
      --theme-primary-700: #{darken_color(colors.primary, 20)};
      --theme-primary-800: #{darken_color(colors.primary, 30)};
      --theme-primary-900: #{darken_color(colors.primary, 40)};

      /* Typography Variables */
      --theme-font-family: #{theme_config.typography.font_family};
      --theme-heading-weight: #{extract_weight(theme_config.typography.heading_weight)};
      --theme-body-weight: #{extract_weight(theme_config.typography.body_weight)};

      /* Spacing Variables */
      --theme-section-gap: #{extract_spacing(theme_config.spacing.section_gap)};
      --theme-card-padding: #{extract_spacing(theme_config.spacing.card_padding)};

      /* Border Variables */
      --theme-border-radius: #{extract_radius(theme_config.borders.radius)};

      /* Shadow Variables */
      --theme-card-shadow: #{extract_shadow(theme_config.shadows.card)};
      --theme-hover-shadow: #{extract_shadow(theme_config.shadows.hover)};
    }
    """
  end

  defp generate_theme_base_styles(theme_settings) do
    theme = theme_settings.theme

    """
    /* Base Theme Styles - #{String.capitalize(theme)} */
    .portfolio-layout {
      font-family: var(--theme-font-family);
      color: var(--theme-text);
      background-color: var(--theme-background);
    }

    .portfolio-layout h1,
    .portfolio-layout h2,
    .portfolio-layout h3,
    .portfolio-layout h4,
    .portfolio-layout h5,
    .portfolio-layout h6 {
      font-weight: var(--theme-heading-weight);
      color: var(--theme-primary);
    }

    .portfolio-layout p,
    .portfolio-layout span,
    .portfolio-layout div {
      font-weight: var(--theme-body-weight);
    }

    /* Theme-specific base adjustments */
    #{case theme do
      "creative" -> """
        .portfolio-layout {
          background: linear-gradient(135deg, var(--theme-primary-50) 0%, var(--theme-accent)10 100%);
        }
        """
      "minimal" -> """
        .portfolio-layout {
          background: #ffffff;
        }
        """
      "modern" -> """
        .portfolio-layout {
          background: linear-gradient(to bottom right, var(--theme-primary-50), var(--theme-secondary)20);
        }
        """
      _ -> """
        .portfolio-layout {
          background-color: #f9fafb;
        }
        """
    end}
    """
  end

  defp generate_layout_specific_styles(theme_settings) do
    layout = theme_settings.layout
    layout_config = theme_settings.layout_config

    """
    /* Layout-Specific Styles - #{String.capitalize(layout)} */
    .#{layout}-layout .section-card {
      border-radius: var(--theme-border-radius);
      box-shadow: var(--theme-card-shadow);
      border-color: var(--theme-primary-200);
      #{case layout do
        "dashboard" -> "height: #{layout_config.card_height};"
        "magazine" -> "height: #{layout_config.card_height};"
        _ -> ""
      end}
    }

    .#{layout}-layout .section-card:hover {
      box-shadow: var(--theme-hover-shadow);
      border-color: var(--theme-primary-300);
    }

    .#{layout}-layout .card-header {
      background-color: var(--theme-primary-50);
      border-bottom-color: var(--theme-primary-100);
    }

    .#{layout}-layout .section-icon {
      background-color: var(--theme-primary-100);
      color: var(--theme-primary-700);
    }

    .#{layout}-layout .expand-btn:hover {
      background-color: var(--theme-primary-100);
      color: var(--theme-primary-700);
    }
    """
  end

  defp generate_component_styles(theme_settings) do
    """
    /* Component Consistency Styles */

    /* Buttons */
    .btn-primary {
      background-color: var(--theme-primary);
      color: white;
      border-radius: var(--theme-border-radius);
      transition: all 0.2s ease;
    }

    .btn-primary:hover {
      background-color: var(--theme-primary-700);
      transform: translateY(-1px);
    }

    .btn-secondary {
      border: 2px solid var(--theme-primary);
      color: var(--theme-primary);
      background-color: transparent;
      border-radius: var(--theme-border-radius);
      transition: all 0.2s ease;
    }

    .btn-secondary:hover {
      background-color: var(--theme-primary);
      color: white;
    }

    /* Cards */
    .portfolio-card {
      background-color: white;
      border: 1px solid var(--theme-primary-200);
      border-radius: var(--theme-border-radius);
      box-shadow: var(--theme-card-shadow);
      transition: all 0.3s ease;
    }

    .portfolio-card:hover {
      box-shadow: var(--theme-hover-shadow);
      border-color: var(--theme-primary-300);
    }

    /* Hero Section */
    .hero-section {
      background: linear-gradient(135deg, var(--theme-primary-50) 0%, white 100%);
    }

    .hero-section h1 {
      color: var(--theme-primary-900);
    }

    .hero-section h2 {
      color: var(--theme-primary-700);
    }

    /* Navigation */
    .floating-navigation {
      background-color: white;
      border: 1px solid var(--theme-primary-200);
      border-radius: var(--theme-border-radius);
      box-shadow: var(--theme-card-shadow);
    }

    .floating-navigation .nav-item:hover {
      background-color: var(--theme-primary-50);
      color: var(--theme-primary-700);
    }

    /* Modal */
    .section-modal .modal-content {
      border-radius: var(--theme-border-radius);
      box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
    }

    .section-modal .modal-header {
      border-bottom-color: var(--theme-primary-200);
    }

    .section-modal .modal-footer {
      border-top-color: var(--theme-primary-200);
      background-color: var(--theme-primary-50);
    }
    """
  end

  defp generate_responsive_styles(theme_settings) do
    """
    /* Responsive Theme Adjustments */

    @media (max-width: 768px) {
      .portfolio-layout {
        padding: 1rem;
      }

      .section-card {
        margin-bottom: 1rem;
      }

      .hero-section {
        padding: 2rem 0;
      }

      .hero-section h1 {
        font-size: 2rem;
      }
    }

    @media (max-width: 640px) {
      .portfolio-layout {
        padding: 0.75rem;
      }

      .floating-navigation {
        display: none;
      }

      .return-to-top {
        bottom: 1rem;
        right: 1rem;
      }
    }
    """
  end

  defp generate_animation_styles(theme_settings) do
    theme_config = theme_settings.theme_config

    """
    /* Theme-Consistent Animations */

    .theme-transition {
      #{theme_config.animations.transition};
    }

    .theme-hover-scale:hover {
      #{theme_config.animations.hover_scale};
    }

    .theme-button {
      #{theme_config.animations.button_transition};
    }

    /* Fade-in animations for content */
    @keyframes theme-fade-in {
      from {
        opacity: 0;
        transform: translateY(20px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .theme-animate-in {
      animation: theme-fade-in 0.6s ease-out forwards;
    }

    /* Loading states */
    .theme-loading {
      background: linear-gradient(90deg, var(--theme-primary-100) 25%, var(--theme-primary-200) 50%, var(--theme-primary-100) 75%);
      background-size: 200% 100%;
      animation: theme-loading 1.5s infinite;
    }

    @keyframes theme-loading {
      0% {
        background-position: 200% 0;
      }
      100% {
        background-position: -200% 0;
      }
    }
    """
  end

  # ============================================================================
  # COLOR MANIPULATION HELPERS
  # ============================================================================

  defp lighten_color(hex_color, percentage) do
    # Simple color lightening - in production, use a proper color library
    case hex_color do
      "#" <> color_code ->
        # This is a simplified implementation
        # In production, you'd want to use a proper color manipulation library
        lightened = case String.length(color_code) do
          6 -> lighten_hex_6(color_code, percentage)
          3 -> lighten_hex_3(color_code, percentage)
          _ -> hex_color
        end
        "##{lightened}"
      _ -> hex_color
    end
  end

  defp darken_color(hex_color, percentage) do
    # Simple color darkening - in production, use a proper color library
    case hex_color do
      "#" <> color_code ->
        darkened = case String.length(color_code) do
          6 -> darken_hex_6(color_code, percentage)
          3 -> darken_hex_3(color_code, percentage)
          _ -> hex_color
        end
        "##{darkened}"
      _ -> hex_color
    end
  end

  # Simplified color manipulation (replace with proper color library in production)
  defp lighten_hex_6(color_code, percentage) do
    try do
      r = String.slice(color_code, 0, 2) |> String.to_integer(16)
      g = String.slice(color_code, 2, 2) |> String.to_integer(16)
      b = String.slice(color_code, 4, 2) |> String.to_integer(16)

      factor = percentage / 100
      r_new = min(255, round(r + (255 - r) * factor))
      g_new = min(255, round(g + (255 - g) * factor))
      b_new = min(255, round(b + (255 - b) * factor))

      "#{pad_hex(Integer.to_string(r_new, 16))}#{pad_hex(Integer.to_string(g_new, 16))}#{pad_hex(Integer.to_string(b_new, 16))}"
    rescue
      _ -> color_code
    end
  end

  defp darken_hex_6(color_code, percentage) do
    try do
      r = String.slice(color_code, 0, 2) |> String.to_integer(16)
      g = String.slice(color_code, 2, 2) |> String.to_integer(16)
      b = String.slice(color_code, 4, 2) |> String.to_integer(16)

      factor = 1 - (percentage / 100)
      r_new = max(0, round(r * factor))
      g_new = max(0, round(g * factor))
      b_new = max(0, round(b * factor))

      "#{pad_hex(Integer.to_string(r_new, 16))}#{pad_hex(Integer.to_string(g_new, 16))}#{pad_hex(Integer.to_string(b_new, 16))}"
    rescue
      _ -> color_code
    end
  end

  defp lighten_hex_3(color_code, percentage) do
    # Convert 3-digit to 6-digit and process
    expanded = String.graphemes(color_code) |> Enum.map(&(&1 <> &1)) |> Enum.join("")
    lighten_hex_6(expanded, percentage)
  end

  defp darken_hex_3(color_code, percentage) do
    # Convert 3-digit to 6-digit and process
    expanded = String.graphemes(color_code) |> Enum.map(&(&1 <> &1)) |> Enum.join("")
    darken_hex_6(expanded, percentage)
  end

  defp pad_hex(hex_string) do
    String.pad_leading(hex_string, 2, "0")
  end

  # ============================================================================
  # CSS VALUE EXTRACTORS
  # ============================================================================

  defp extract_weight(weight_class) do
    case weight_class do
      "font-light" -> "300"
      "font-normal" -> "400"
      "font-medium" -> "500"
      "font-semibold" -> "600"
      "font-bold" -> "700"
      _ -> "400"
    end
  end

  defp extract_spacing(spacing_class) do
    case spacing_class do
      "space-y-16" -> "4rem"
      "space-y-18" -> "4.5rem"
      "space-y-20" -> "5rem"
      "space-y-24" -> "6rem"
      "p-6" -> "1.5rem"
      "p-8" -> "2rem"
      "px-4 sm:px-6 lg:px-8" -> "1rem"
      _ -> "1rem"
    end
  end

  defp extract_radius(radius_class) do
    case radius_class do
      "rounded-none" -> "0"
      "rounded-xl" -> "0.75rem"
      "rounded-2xl" -> "1rem"
      _ -> "0.5rem"
    end
  end

  defp extract_shadow(shadow_class) do
    case shadow_class do
      "shadow-none" -> "none"
      "shadow-sm" -> "0 1px 2px 0 rgba(0, 0, 0, 0.05)"
      "shadow-lg" -> "0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05)"
      "shadow-xl" -> "0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)"
      "shadow-2xl" -> "0 25px 50px -12px rgba(0, 0, 0, 0.25)"
      "shadow-3xl" -> "0 35px 60px -12px rgba(0, 0, 0, 0.3)"
      "hover:shadow-sm" -> "0 1px 2px 0 rgba(0, 0, 0, 0.05)"
      "hover:shadow-xl" -> "0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04)"
      "hover:shadow-2xl" -> "0 25px 50px -12px rgba(0, 0, 0, 0.25)"
      "hover:shadow-3xl" -> "0 35px 60px -12px rgba(0, 0, 0, 0.3)"
      _ -> "0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06)"
    end
  end

  # ============================================================================
  # THEME CONSISTENCY VALIDATORS
  # ============================================================================

  def validate_theme_consistency(theme_settings) do
    issues = []

    # Check color contrast
    issues = if has_sufficient_contrast?(theme_settings.colors.primary, theme_settings.colors.background) do
      issues
    else
      ["Low contrast between primary color and background" | issues]
    end

    # Check theme coherence
    issues = if theme_layout_compatible?(theme_settings.theme, theme_settings.layout) do
      issues
    else
      ["Theme and layout combination may not be optimal" | issues]
    end

    # Check color scheme consistency
    issues = if color_scheme_matches_theme?(theme_settings.color_scheme, theme_settings.theme) do
      issues
    else
      ["Color scheme doesn't match theme personality" | issues]
    end

    case issues do
      [] -> {:ok, "Theme consistency validated successfully"}
      issues -> {:warning, issues}
    end
  end

  defp has_sufficient_contrast?(color1, color2) do
    # Simplified contrast check - in production, use proper WCAG contrast calculation
    true # Placeholder - implement proper contrast calculation
  end

  defp theme_layout_compatible?(theme, layout) do
    compatible_combinations = %{
      "professional" => ["standard", "dashboard", "timeline"],
      "creative" => ["grid", "magazine", "timeline"],
      "minimal" => ["minimal", "standard", "timeline"],
      "modern" => ["dashboard", "grid", "magazine"]
    }

    layout in Map.get(compatible_combinations, theme, [layout])
  end

  defp color_scheme_matches_theme?(color_scheme, theme) do
    recommended_schemes = %{
      "professional" => ["blue", "teal"],
      "creative" => ["purple", "orange", "red"],
      "minimal" => ["blue", "teal"],
      "modern" => ["blue", "purple", "teal"]
    }

    color_scheme in Map.get(recommended_schemes, theme, [color_scheme])
  end

  # ============================================================================
  # THEME SUGGESTIONS AND IMPROVEMENTS
  # ============================================================================

  def suggest_theme_improvements(theme_settings) do
    suggestions = []

    # Suggest better color combinations
    suggestions = if theme_settings.theme == "creative" && theme_settings.color_scheme == "blue" do
      ["Consider using Purple or Orange color scheme for a more creative feel" | suggestions]
    else
      suggestions
    end

    # Suggest layout improvements
    suggestions = if theme_settings.theme == "minimal" && theme_settings.layout == "dashboard" do
      ["Consider using Standard or Minimal layout for better minimalist aesthetic" | suggestions]
    else
      suggestions
    end

    # Suggest typography improvements
    suggestions = if theme_settings.theme == "creative" do
      ["Consider adding custom fonts for more creative expression" | suggestions]
    else
      suggestions
    end

    suggestions
  end

  # ============================================================================
  # COMPLETE THEME APPLICATION
  # ============================================================================

  def apply_theme_to_all_components(portfolio, sections, base_assigns) do
    # Extract complete theme settings
    theme_settings = extract_complete_theme_settings(portfolio)

    # Generate comprehensive CSS
    complete_css = generate_complete_theme_css(theme_settings)

    # Validate theme consistency
    validation_result = validate_theme_consistency(theme_settings)

    # Get improvement suggestions
    suggestions = suggest_theme_improvements(theme_settings)

    # Enhanced assigns with theme data
    enhanced_assigns = base_assigns
    |> assign(:theme_settings, theme_settings)
    |> assign(:complete_theme_css, complete_css)
    |> assign(:theme, theme_settings.theme)
    |> assign(:layout_type, theme_settings.layout)
    |> assign(:color_scheme, theme_settings.color_scheme)
    |> assign(:theme_validation, validation_result)
    |> assign(:theme_suggestions, suggestions)
    |> assign(:theme_applied, true)

    {enhanced_assigns, complete_css, theme_settings}
  end
end
