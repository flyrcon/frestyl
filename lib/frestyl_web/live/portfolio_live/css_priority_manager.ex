# lib/frestyl_web/live/portfolio_live/css_priority_manager.ex
# SINGLE SOURCE OF TRUTH FOR ALL PORTFOLIO CSS WITH PROPER SPECIFICITY HIERARCHY

defmodule FrestylWeb.PortfolioLive.CssPriorityManager do
  @moduledoc """
  Manages CSS generation with proper specificity hierarchy to ensure
  user customizations ALWAYS override template defaults.

  Priority Order (highest to lowest):
  1. User customizations (!important when needed)
  2. Template variations
  3. Theme base styles
  4. System defaults
  """

  @doc """
  Generates complete CSS for portfolio with guaranteed user customization priority.
  This is the ONLY function that should be used for portfolio CSS generation.
  """
  def generate_portfolio_css(portfolio, options \\ []) do
    mobile_view = Keyword.get(options, :mobile_view, false)
    preview_mode = Keyword.get(options, :preview_mode, false)

    # Get all style components in priority order
    theme_base = get_theme_base_css(portfolio.theme || "minimal")
    template_variations = get_template_variation_css(portfolio.theme || "minimal")
    user_customizations = get_user_customization_css(portfolio.customization || %{})
    responsive_css = get_responsive_css(mobile_view)
    specificity_overrides = get_specificity_overrides(portfolio.customization || %{})

    # Combine with strict priority hierarchy
    css_id = if preview_mode, do: "portfolio-preview-css", else: "portfolio-display-css"

    """
    <style id="#{css_id}">
    /* =========================== */
    /* THEME BASE STYLES (LOWEST PRIORITY) */
    /* =========================== */
    #{theme_base}

    /* =========================== */
    /* TEMPLATE VARIATIONS */
    /* =========================== */
    #{template_variations}

    /* =========================== */
    /* RESPONSIVE STYLES */
    /* =========================== */
    #{responsive_css}

    /* =========================== */
    /* USER CUSTOMIZATIONS (HIGH PRIORITY) */
    /* =========================== */
    #{user_customizations}

    /* =========================== */
    /* SPECIFICITY OVERRIDES (HIGHEST PRIORITY) */
    /* These use !important to guarantee user choices win */
    /* =========================== */
    #{specificity_overrides}
    </style>
    """
  end

  @doc """
  Theme base styles - foundation level, can be overridden
  """
  defp get_theme_base_css(theme) do
    case theme do
      "minimal" ->
        """
        .portfolio-container {
          font-family: 'Inter', system-ui, sans-serif;
          line-height: 1.6;
          background-color: #ffffff;
          color: #111827;
        }

        .portfolio-header {
          padding: 3rem 0 2rem 0;
          text-align: center;
        }

        .portfolio-sections {
          max-width: 800px;
          margin: 0 auto;
          padding: 0 1rem;
        }

        .section {
          padding: 2rem 0;
          border-bottom: 1px solid #e5e7eb;
        }

        .section:last-child {
          border-bottom: none;
        }
        """

      "professional" ->
        """
        .portfolio-container {
          font-family: 'Inter', system-ui, sans-serif;
          line-height: 1.7;
          background-color: #ffffff;
          color: #0f172a;
        }

        .portfolio-header {
          background: linear-gradient(135deg, #1e40af 0%, #3b82f6 100%);
          color: white;
          padding: 4rem 0;
          text-align: center;
        }

        .portfolio-sections {
          max-width: 1200px;
          margin: 0 auto;
          padding: 2rem;
          display: grid;
          gap: 2rem;
        }

        .section {
          background: white;
          padding: 2rem;
          border-radius: 12px;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        """

      "creative" ->
        """
        .portfolio-container {
          font-family: 'Inter', system-ui, sans-serif;
          line-height: 1.6;
          background: linear-gradient(135deg, #faf7ff 0%, #f3e8ff 100%);
          color: #1f2937;
          min-height: 100vh;
        }

        .portfolio-header {
          padding: 4rem 0;
          text-align: center;
          background: linear-gradient(135deg, #7c3aed 0%, #ec4899 100%);
          color: white;
          clip-path: polygon(0 0, 100% 0, 100% 85%, 0 100%);
        }

        .portfolio-sections {
          max-width: 1000px;
          margin: -2rem auto 0;
          padding: 0 1rem;
          display: grid;
          gap: 2rem;
        }

        .section {
          background: white;
          padding: 2.5rem;
          border-radius: 20px;
          box-shadow: 0 10px 25px rgba(124, 58, 237, 0.1);
          transform: perspective(1000px) rotateX(2deg);
          transition: transform 0.3s ease;
        }

        .section:hover {
          transform: perspective(1000px) rotateX(0deg);
        }
        """

      "developer" ->
        """
        .portfolio-container {
          font-family: 'JetBrains Mono', 'Fira Code', monospace;
          line-height: 1.8;
          background-color: #0f172a;
          color: #e2e8f0;
          min-height: 100vh;
        }

        .portfolio-header {
          padding: 3rem 0;
          text-align: left;
          padding-left: 2rem;
          border-left: 4px solid #10b981;
          background: linear-gradient(90deg, rgba(16, 185, 129, 0.1) 0%, transparent 50%);
        }

        .portfolio-sections {
          max-width: 1000px;
          margin: 0 auto;
          padding: 2rem;
        }

        .section {
          background: #1e293b;
          padding: 2rem;
          margin-bottom: 2rem;
          border-radius: 8px;
          border: 1px solid #334155;
          position: relative;
        }

        .section::before {
          content: '>';
          position: absolute;
          left: 1rem;
          top: 1rem;
          color: #10b981;
          font-weight: bold;
        }

        .section h2 {
          margin-left: 2rem;
          color: #10b981;
        }
        """

      _ ->
        get_theme_base_css("minimal")
    end
  end

  @doc """
  Template variation styles - layout modifications
  """
  defp get_template_variation_css(template) do
    case template do
      "dashboard" ->
        """
        .portfolio-sections {
          display: grid !important;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)) !important;
          gap: 1.5rem !important;
        }

        .section {
          min-height: 200px;
        }
        """

      "timeline" ->
        """
        .portfolio-sections {
          position: relative;
          max-width: 800px !important;
        }

        .portfolio-sections::before {
          content: '';
          position: absolute;
          left: 2rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: var(--user-accent-color, #3b82f6);
        }

        .section {
          margin-left: 4rem;
          position: relative;
        }

        .section::before {
          content: '';
          position: absolute;
          left: -3rem;
          top: 1rem;
          width: 12px;
          height: 12px;
          border-radius: 50%;
          background: var(--user-accent-color, #3b82f6);
          border: 3px solid var(--user-background-color, #ffffff);
        }
        """

      "gallery" ->
        """
        .portfolio-sections {
          columns: 2;
          column-gap: 2rem;
        }

        @media (max-width: 768px) {
          .portfolio-sections {
            columns: 1;
          }
        }

        .section {
          break-inside: avoid;
          margin-bottom: 2rem;
        }
        """

      _ ->
        "" # Default layout
    end
  end

  @doc """
  User customization styles - medium priority, uses CSS variables
  """
  defp get_user_customization_css(customization) do
    # Extract user colors and settings
    primary_color = Map.get(customization, "primary_color")
    secondary_color = Map.get(customization, "secondary_color")
    accent_color = Map.get(customization, "accent_color")
    background_color = Map.get(customization, "background_color")
    text_color = Map.get(customization, "text_color")
    layout = Map.get(customization, "layout")

    # Generate CSS variables for user colors
    variables = build_css_variables(customization)
    layout_css = build_layout_css(layout)

    """
    /* User Color Variables */
    :root {
      #{variables}
    }

    /* Apply User Colors (medium specificity) */
    .portfolio-container {
      #{if background_color, do: "background-color: var(--user-background-color);"}
      #{if text_color, do: "color: var(--user-text-color);"}
    }

    .text-primary {
      #{if primary_color, do: "color: var(--user-primary-color);"}
    }

    .bg-primary {
      #{if primary_color, do: "background-color: var(--user-primary-color);"}
    }

    .text-accent {
      #{if accent_color, do: "color: var(--user-accent-color);"}
    }

    .bg-accent {
      #{if accent_color, do: "background-color: var(--user-accent-color);"}
    }

    .text-secondary {
      #{if secondary_color, do: "color: var(--user-secondary-color);"}
    }

    .bg-secondary {
      #{if secondary_color, do: "background-color: var(--user-secondary-color);"}
    }

    /* User Layout Overrides */
    #{layout_css}
    """
  end

  @doc """
  Highest priority overrides with !important to guarantee user choices win
  """
  defp get_specificity_overrides(customization) do
    primary_color = Map.get(customization, "primary_color")
    secondary_color = Map.get(customization, "secondary_color")
    accent_color = Map.get(customization, "accent_color")
    background_color = Map.get(customization, "background_color")
    text_color = Map.get(customization, "text_color")

    overrides = []

    # Only add !important overrides if user has customized
    overrides = if primary_color do
      ["""
      .portfolio-container .text-primary,
      .portfolio-container .btn-primary,
      .portfolio-container .link-primary {
        color: #{primary_color} !important;
      }

      .portfolio-container .bg-primary,
      .portfolio-container .btn-primary {
        background-color: #{primary_color} !important;
      }

      .portfolio-container .border-primary {
        border-color: #{primary_color} !important;
      }
      """ | overrides]
    else
      overrides
    end

    overrides = if accent_color do
      ["""
      .portfolio-container .text-accent,
      .portfolio-container .accent {
        color: #{accent_color} !important;
      }

      .portfolio-container .bg-accent {
        background-color: #{accent_color} !important;
      }
      """ | overrides]
    else
      overrides
    end

    overrides = if background_color do
      ["""
      .portfolio-container {
        background-color: #{background_color} !important;
      }
      """ | overrides]
    else
      overrides
    end

    overrides = if text_color do
      ["""
      .portfolio-container,
      .portfolio-container p,
      .portfolio-container span,
      .portfolio-container div {
        color: #{text_color} !important;
      }
      """ | overrides]
    else
      overrides
    end

    Enum.join(overrides, "\n")
  end

  @doc """
  Responsive CSS for mobile/desktop views
  """
  defp get_responsive_css(mobile_view) do
    if mobile_view do
      """
      .portfolio-container {
        max-width: 375px !important;
        margin: 0 auto !important;
        padding: 1rem !important;
      }

      .portfolio-header {
        padding: 2rem 1rem !important;
      }

      .portfolio-sections {
        padding: 0 !important;
        grid-template-columns: 1fr !important;
        columns: 1 !important;
      }

      .section {
        margin-bottom: 1rem !important;
        padding: 1.5rem !important;
      }

      h1 { font-size: 1.75rem !important; }
      h2 { font-size: 1.5rem !important; }
      h3 { font-size: 1.25rem !important; }
      """
    else
      """
      @media (max-width: 768px) {
        .portfolio-container {
          padding: 1rem;
        }

        .portfolio-sections {
          grid-template-columns: 1fr !important;
          columns: 1 !important;
          gap: 1rem;
        }

        .section {
          padding: 1.5rem;
        }
      }
      """
    end
  end

  # Helper functions
  defp build_css_variables(customization) do
    variables = []

    variables = if primary = Map.get(customization, "primary_color") do
      ["--user-primary-color: #{primary};" | variables]
    else
      variables
    end

    variables = if secondary = Map.get(customization, "secondary_color") do
      ["--user-secondary-color: #{secondary};" | variables]
    else
      variables
    end

    variables = if accent = Map.get(customization, "accent_color") do
      ["--user-accent-color: #{accent};" | variables]
    else
      variables
    end

    variables = if background = Map.get(customization, "background_color") do
      ["--user-background-color: #{background};" | variables]
    else
      variables
    end

    variables = if text = Map.get(customization, "text_color") do
      ["--user-text-color: #{text};" | variables]
    else
      variables
    end

    Enum.join(variables, "\n  ")
  end

  defp build_layout_css(layout) do
    case layout do
      "single_column" ->
        """
        .portfolio-sections {
          max-width: 700px !important;
          margin: 0 auto !important;
        }
        """
      "two_column" ->
        """
        .portfolio-sections {
          display: grid !important;
          grid-template-columns: 1fr 1fr !important;
          gap: 2rem !important;
          max-width: 1200px !important;
          margin: 0 auto !important;
        }

        @media (max-width: 768px) {
          .portfolio-sections {
            grid-template-columns: 1fr !important;
          }
        }
        """
      "masonry" ->
        """
        .portfolio-sections {
          columns: 3 !important;
          column-gap: 2rem !important;
          max-width: 1200px !important;
          margin: 0 auto !important;
        }

        @media (max-width: 768px) {
          .portfolio-sections {
            columns: 1 !important;
          }
        }

        .section {
          break-inside: avoid !important;
          margin-bottom: 2rem !important;
        }
        """
      _ -> ""
    end
  end

  @doc """
  Builds preview URL with proper CSS parameters for consistency
  """
  def build_preview_url(portfolio, customization \\ %{}) do
    base_url = "/portfolios/#{portfolio.id}/live_preview"
    preview_token = generate_preview_token(portfolio.id)

    params = %{
      "preview_token" => preview_token,
      "theme" => portfolio.theme || "minimal",
      "mobile" => "false",
      "t" => System.system_time(:second)
    }

    query_string = URI.encode_query(params)
    "#{base_url}?#{query_string}"
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
end
