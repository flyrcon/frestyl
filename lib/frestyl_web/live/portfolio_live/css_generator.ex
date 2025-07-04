# lib/frestyl_web/live/portfolio_live/css_generator.ex
# NEW MODULE - Centralized CSS generation for consistent styling

defmodule FrestylWeb.PortfolioLive.CssGenerator do
  @moduledoc """
  Centralized CSS generation for portfolio themes, templates, and customizations.
  This module ensures consistent styling across preview and live views.
  """

  @doc """
  Generates complete CSS for a portfolio including theme, template, and user customizations.
  Priority order: User Customizations > Template Styles > Theme Defaults
  """
  def generate_portfolio_css(portfolio, options \\ []) do
    mobile_view = Keyword.get(options, :mobile_view, false)

    # Get all style components
    theme_css = get_theme_css(portfolio.theme || "minimal")
    template_css = get_template_css(portfolio.theme || "minimal")
    customization_css = get_customization_css(portfolio.customization || %{})
    responsive_css = get_responsive_css(mobile_view)

    # Combine all CSS with proper precedence
    """
    <style id="portfolio-generated-css">
    /* ===== THEME BASE STYLES (lowest priority) ===== */
    #{theme_css}

    /* ===== TEMPLATE SPECIFIC STYLES ===== */
    #{template_css}

    /* ===== RESPONSIVE STYLES ===== */
    #{responsive_css}

    /* ===== USER CUSTOMIZATIONS (highest priority) ===== */
    #{customization_css}

    /* ===== OVERRIDE SAFEGUARDS ===== */
    .portfolio-container {
      font-family: var(--portfolio-font-family, 'Inter', system-ui, sans-serif) !important;
      line-height: var(--portfolio-line-height, 1.6) !important;
    }

    /* Ensure user colors always take precedence */
    .portfolio-container .text-primary { color: var(--primary-color) !important; }
    .portfolio-container .bg-primary { background-color: var(--primary-color) !important; }
    .portfolio-container .text-accent { color: var(--accent-color) !important; }
    .portfolio-container .bg-accent { background-color: var(--accent-color) !important; }
    </style>
    """
  end

  @doc """
  Gets theme-specific base CSS with CSS variables
  """
  defp get_theme_css(theme) do
    case theme do
      "minimal" ->
        """
        :root {
          --theme-primary: #374151;
          --theme-secondary: #6b7280;
          --theme-accent: #3b82f6;
          --theme-background: #ffffff;
          --theme-text: #111827;
          --theme-font-family: 'Inter', system-ui, sans-serif;
          --theme-line-height: 1.6;
        }

        .portfolio-container {
          background-color: var(--theme-background);
          color: var(--theme-text);
          font-family: var(--theme-font-family);
          line-height: var(--theme-line-height);
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
        :root {
          --theme-primary: #1e40af;
          --theme-secondary: #64748b;
          --theme-accent: #0ea5e9;
          --theme-background: #ffffff;
          --theme-text: #0f172a;
          --theme-font-family: 'Inter', system-ui, sans-serif;
          --theme-line-height: 1.7;
        }

        .portfolio-container {
          background-color: var(--theme-background);
          color: var(--theme-text);
          font-family: var(--theme-font-family);
          line-height: var(--theme-line-height);
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
        :root {
          --theme-primary: #7c3aed;
          --theme-secondary: #a855f7;
          --theme-accent: #ec4899;
          --theme-background: #faf7ff;
          --theme-text: #1f2937;
          --theme-font-family: 'Inter', system-ui, sans-serif;
          --theme-line-height: 1.6;
        }

        .portfolio-container {
          background: linear-gradient(135deg, #faf7ff 0%, #f3e8ff 100%);
          color: var(--theme-text);
          font-family: var(--theme-font-family);
          line-height: var(--theme-line-height);
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
        :root {
          --theme-primary: #059669;
          --theme-secondary: #374151;
          --theme-accent: #10b981;
          --theme-background: #0f172a;
          --theme-text: #e2e8f0;
          --theme-font-family: 'JetBrains Mono', 'Fira Code', monospace;
          --theme-line-height: 1.8;
        }

        .portfolio-container {
          background-color: var(--theme-background);
          color: var(--theme-text);
          font-family: var(--theme-font-family);
          line-height: var(--theme-line-height);
          min-height: 100vh;
        }

        .portfolio-header {
          padding: 3rem 0;
          text-align: left;
          padding-left: 2rem;
          border-left: 4px solid var(--theme-accent);
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
          color: var(--theme-accent);
          font-weight: bold;
        }

        .section h2 {
          margin-left: 2rem;
          color: var(--theme-accent);
        }
        """

      _ ->
        get_theme_css("minimal")
    end
  end

  @doc """
  Gets template-specific CSS (layout variations within themes)
  """
  defp get_template_css(template) do
    case template do
      "dashboard" ->
        """
        .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 1.5rem;
        }

        .section {
          min-height: 200px;
        }
        """

      "timeline" ->
        """
        .portfolio-sections {
          position: relative;
          max-width: 800px;
        }

        .portfolio-sections::before {
          content: '';
          position: absolute;
          left: 2rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: var(--accent-color, var(--theme-accent));
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
          background: var(--accent-color, var(--theme-accent));
          border: 3px solid var(--background-color, var(--theme-background));
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
  Generates CSS from user customizations with proper CSS variable assignment
  """
  defp get_customization_css(customization) do
    primary_color = Map.get(customization, "primary_color")
    secondary_color = Map.get(customization, "secondary_color")
    accent_color = Map.get(customization, "accent_color")
    background_color = Map.get(customization, "background_color")
    text_color = Map.get(customization, "text_color")
    font_family = Map.get(customization, "font_family")
    layout = Map.get(customization, "layout")

    # Build CSS variables only for defined customizations
    css_vars = []
    css_vars = if primary_color, do: ["--primary-color: #{primary_color};" | css_vars], else: css_vars
    css_vars = if secondary_color, do: ["--secondary-color: #{secondary_color};" | css_vars], else: css_vars
    css_vars = if accent_color, do: ["--accent-color: #{accent_color};" | css_vars], else: css_vars
    css_vars = if background_color, do: ["--background-color: #{background_color};" | css_vars], else: css_vars
    css_vars = if text_color, do: ["--text-color: #{text_color};" | css_vars], else: css_vars
    css_vars = if font_family, do: ["--portfolio-font-family: #{font_family};" | css_vars], else: css_vars

    variables_css = if length(css_vars) > 0 do
      """
      :root {
        #{Enum.join(css_vars, "\n  ")}
      }
      """
    else
      ""
    end

    # Layout-specific customizations
    layout_css = case layout do
      "single_column" ->
        """
        .portfolio-sections {
          max-width: 700px;
          margin: 0 auto;
        }
        """
      "two_column" ->
        """
        .portfolio-sections {
          display: grid;
          grid-template-columns: 1fr 1fr;
          gap: 2rem;
          max-width: 1200px;
          margin: 0 auto;
        }

        @media (max-width: 768px) {
          .portfolio-sections {
            grid-template-columns: 1fr;
          }
        }
        """
      "masonry" ->
        """
        .portfolio-sections {
          columns: 3;
          column-gap: 2rem;
          max-width: 1200px;
          margin: 0 auto;
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
      _ -> ""
    end

    """
    #{variables_css}

    /* Apply customizations with fallbacks to theme defaults */
    .portfolio-container {
      background-color: var(--background-color, var(--theme-background));
      color: var(--text-color, var(--theme-text));
      font-family: var(--portfolio-font-family, var(--theme-font-family));
    }

    #{layout_css}
    """
  end

  @doc """
  Responsive CSS for mobile/desktop views
  """
  defp get_responsive_css(mobile_view) do
    if mobile_view do
      """
      .portfolio-container {
        max-width: 375px;
        margin: 0 auto;
        padding: 1rem;
      }

      .portfolio-header {
        padding: 2rem 1rem;
      }

      .portfolio-sections {
        padding: 0;
        grid-template-columns: 1fr !important;
        columns: 1 !important;
      }

      .section {
        margin-bottom: 1rem;
        padding: 1.5rem;
      }

      h1 { font-size: 1.75rem; }
      h2 { font-size: 1.5rem; }
      h3 { font-size: 1.25rem; }
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

  @doc """
  Builds preview URL with proper CSS parameters
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

    # Add customization params if present
    params = if primary_color = Map.get(customization, "primary_color") do
      Map.put(params, "primary", String.replace(primary_color, "#", ""))
    else
      params
    end

    params = if accent_color = Map.get(customization, "accent_color") do
      Map.put(params, "accent", String.replace(accent_color, "#", ""))
    else
      params
    end

    query_string = URI.encode_query(params)
    "#{base_url}?#{query_string}"
  end

  @doc """
  Generates secure preview token
  """
  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
    |> String.slice(0, 16)
  end
end
