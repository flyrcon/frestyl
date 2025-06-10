# Replace your portfolio_controller.ex with this working version:

defmodule FrestylWeb.PortfolioController do
  use FrestylWeb, :controller
  alias Frestyl.Portfolios

  def show(conn, %{"slug" => slug}) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")

      {:ok, portfolio} ->
        # Get customization from database
        user_customization = portfolio.customization || %{}
        IO.inspect(user_customization, label: "🎨 Portfolio customization")

        # Get the layout from database
        layout = user_customization["layout"] || "gallery"
        IO.puts("🎭 Using layout: #{layout}")

        # Generate CSS for your templates
        portfolio_css = generate_portfolio_css(user_customization)

        # Get sections
        sections = Map.get(portfolio, :portfolio_sections, [])

        # Prepare assigns for templates
        assigns = %{
          portfolio: portfolio,
          sections: sections,
          customization_css: portfolio_css,
          user_customization: user_customization,
          layout: layout
        }

        # 🔥 DYNAMIC LAYOUT SWITCHING
        html_content = case layout do
          "gallery" -> FrestylWeb.PortfolioHTML.render_gallery_layout(assigns)
          "services" -> FrestylWeb.PortfolioHTML.render_services_layout(assigns)
          "dashboard" -> FrestylWeb.PortfolioHTML.render_dashboard_layout(assigns)
          "terminal" -> FrestylWeb.PortfolioHTML.render_terminal_layout(assigns)
          "fullscreen" -> FrestylWeb.PortfolioHTML.render_fullscreen_layout(assigns)
          "typography" -> FrestylWeb.PortfolioHTML.render_minimal_layout(assigns)
          _ ->
            IO.puts("⚠️  Unknown layout '#{layout}', falling back to gallery")
            FrestylWeb.PortfolioHTML.render_gallery_layout(assigns)
        end

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html_content)
    end
  end

  # Generate CSS that matches your database customization
  defp generate_portfolio_css(customization) do
    primary_color = customization["primary_color"] || "#f59e0b"
    secondary_color = customization["secondary_color"] || "#8b5cf6"
    accent_color = customization["accent_color"] || "#f59e0b"

    # Handle typography
    typography = customization["typography"] || %{}
    font_family = typography["font_family"] || "Playfair Display"

    # Handle background
    background = customization["background"] || "gradient-vibrant"

    # Handle layout config
    layout_config = customization["layout_config"] || %{}
    spacing = layout_config["spacing"] || "spacious"

    """
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{get_font_family_css(font_family)};
      --portfolio-spacing: #{get_spacing_css(spacing)};
      #{get_background_css_vars(background)}
    }

    /* Apply CSS variables globally */
    body {
      font-family: var(--portfolio-font-family) !important;
      background: var(--portfolio-bg) !important;
      color: var(--portfolio-text) !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* Custom portfolio classes */
    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }
    .portfolio-card {
      background: var(--portfolio-card-bg) !important;
      padding: var(--portfolio-spacing) !important;
    }
    """
  end

  defp get_font_family_css(font_family) do
    case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Roboto" -> "'Roboto', system-ui, sans-serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end
  end

  defp get_spacing_css(spacing) do
    case spacing do
      "compact" -> "0.75rem"
      "normal" -> "1rem"
      "spacious" -> "1.5rem"
      "extra-spacious" -> "2rem"
      _ -> "1.5rem"  # Default to spacious since your DB shows "spacious"
    end
  end

  defp get_background_css_vars(background) do
    case background do
      "gradient-vibrant" ->  # This matches your DB data
        "--portfolio-bg: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); --portfolio-text: #ffffff; --portfolio-card-bg: rgba(255, 255, 255, 0.15);"
      "gradient-teal" ->
        "--portfolio-bg: linear-gradient(135deg, #14b8a6 0%, #0891b2 100%); --portfolio-text: #ffffff; --portfolio-card-bg: rgba(255, 255, 255, 0.1);"
      "gradient-ocean" ->
        "--portfolio-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%); --portfolio-text: #ffffff; --portfolio-card-bg: rgba(255, 255, 255, 0.1);"
      "dark-mode" ->
        "--portfolio-bg: #1a1a1a; --portfolio-text: #ffffff; --portfolio-card-bg: #2a2a2a;"
      _ ->
        "--portfolio-bg: #ffffff; --portfolio-text: #1f2937; --portfolio-card-bg: #ffffff;"
    end
  end
end
