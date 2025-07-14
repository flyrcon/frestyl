# Create new file: lib/frestyl_web/live/portfolio_live/dynamic_card_css_manager.ex

defmodule FrestylWeb.PortfolioLive.DynamicCardCssManager do
  @moduledoc """
  Manages CSS generation for Dynamic Card Layout portfolios.
  Ensures consistent styling across editor and public views.
  Handles proper CSS reset and prevents style persistence issues.
  """

  @doc """
  Generates complete CSS for a portfolio with proper reset and theming
  """
  def generate_portfolio_css(portfolio, brand_settings, customization \\ %{}) do
    css_reset() <>
    css_variables(brand_settings, customization) <>
    base_layout_styles() <>
    dynamic_card_styles(brand_settings) <>
    responsive_styles() <>
    custom_overrides(customization)
  end

  @doc """
  CSS reset to prevent style leakage from previous themes
  """
  defp css_reset do
    """
    /* Dynamic Card Layout CSS Reset */
    .portfolio-public-view,
    .dynamic-card-layout-manager {
      /* Reset all inherited styles */
      all: initial;
      font-family: system-ui, -apple-system, sans-serif;
    }

    .portfolio-public-view *,
    .dynamic-card-layout-manager * {
      box-sizing: border-box;
      margin: 0;
      padding: 0;
    }

    /* Clear any previous portfolio theme styles */
    [class*="template-"],
    [class*="theme-"],
    [id*="portfolio-css"] {
      display: none !important;
    }
    """
  end

  @doc """
  CSS custom properties for theming
  """
  defp css_variables(brand_settings, customization) do
    primary = brand_settings.primary_color || "#3b82f6"
    secondary = brand_settings.secondary_color || "#64748b"
    accent = brand_settings.accent_color || "#f59e0b"
    background = customization["background_color"] || "#ffffff"
    text = customization["text_color"] || "#1f2937"
    font_family = brand_settings.font_family || "system-ui, sans-serif"

    """
    /* Dynamic Card Layout CSS Variables */
    .portfolio-public-view,
    .dynamic-card-layout-manager {
      --dcl-primary: #{primary};
      --dcl-secondary: #{secondary};
      --dcl-accent: #{accent};
      --dcl-background: #{background};
      --dcl-text: #{text};
      --dcl-font-family: #{font_family};
      --dcl-primary-rgb: #{hex_to_rgb(primary)};
      --dcl-accent-rgb: #{hex_to_rgb(accent)};
    }
    """
  end

  @doc """
  Base layout styles for Dynamic Card Layout
  """
  defp base_layout_styles do
    """
    /* Dynamic Card Layout Base Styles */
    .portfolio-public-view {
      font-family: var(--dcl-font-family);
      color: var(--dcl-text);
      background-color: var(--dcl-background);
      line-height: 1.6;
      min-height: 100vh;
    }

    .layout-zones-public {
      width: 100%;
    }

    .layout-zone-hero {
      min-height: 60vh;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(135deg, rgba(var(--dcl-primary-rgb), 0.1) 0%, rgba(var(--dcl-accent-rgb), 0.05) 100%);
    }

    .layout-zone-about,
    .layout-zone-services,
    .layout-zone-portfolio,
    .layout-zone-contact {
      padding: 4rem 0;
    }

    .layout-zone-services {
      background-color: rgba(var(--dcl-primary-rgb), 0.02);
    }
    """
  end

  @doc """
  Dynamic card specific styles
  """
  defp dynamic_card_styles(brand_settings) do
    """
    /* Dynamic Card Components */
    .service-card,
    .project-card {
      transition: transform 0.3s ease, box-shadow 0.3s ease;
    }

    .service-card:hover,
    .project-card:hover {
      transform: translateY(-4px);
      box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
    }

    .hero-section h1 {
      font-weight: 700;
      line-height: 1.2;
    }

    .about-section,
    .contact-section {
      max-width: 1200px;
      margin: 0 auto;
    }

    /* Service Cards Grid */
    .services-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
      gap: 2rem;
      padding: 0 2rem;
    }

    /* Projects Grid */
    .projects-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
      gap: 2rem;
      padding: 0 2rem;
    }
    """
  end

  @doc """
  Responsive styles for mobile/tablet
  """
  defp responsive_styles do
    """
    /* Responsive Design */
    @media (max-width: 768px) {
      .hero-section {
        padding: 3rem 1rem;
      }

      .hero-section h1 {
        font-size: 2.5rem;
      }

      .about-section,
      .contact-section {
        padding: 2rem 1rem;
      }

      .services-grid,
      .projects-grid {
        grid-template-columns: 1fr;
        padding: 0 1rem;
      }

      .about-section .grid {
        grid-template-columns: 1fr;
        gap: 2rem;
      }
    }

    @media (max-width: 480px) {
      .hero-section h1 {
        font-size: 2rem;
      }

      .hero-section p {
        font-size: 1rem;
      }
    }
    """
  end

  @doc """
  Custom CSS overrides from portfolio customization
  """
  defp custom_overrides(customization) do
    custom_css = customization["custom_css"] || ""

    """
    /* Custom Portfolio Overrides */
    #{custom_css}
    """
  end

  @doc """
  Convert hex color to RGB values for CSS custom properties
  """
  defp hex_to_rgb(hex) when is_binary(hex) do
    hex = String.replace(hex, "#", "")

    case String.length(hex) do
      6 ->
        {r, ""} = String.slice(hex, 0, 2) |> Integer.parse(16)
        {g, ""} = String.slice(hex, 2, 2) |> Integer.parse(16)
        {b, ""} = String.slice(hex, 4, 2) |> Integer.parse(16)
        "#{r}, #{g}, #{b}"

      3 ->
        r = String.slice(hex, 0, 1) |> String.duplicate(2)
        g = String.slice(hex, 1, 1) |> String.duplicate(2)
        b = String.slice(hex, 2, 1) |> String.duplicate(2)
        hex_to_rgb("##{r}#{g}#{b}")

      _ ->
        "59, 130, 246" # Default blue
    end
  rescue
    _ -> "59, 130, 246" # Default blue
  end

  defp hex_to_rgb(_), do: "59, 130, 246" # Default blue

  @doc """
  Generates editor-specific CSS (isolated from public view)
  """
  def generate_editor_css do
    """
    /* Dynamic Card Layout Editor Styles */
    .dynamic-card-layout-manager {
      font-family: system-ui, -apple-system, sans-serif;
      background-color: #f9fafb;
      height: 100vh;
      display: flex;
    }

    .layout-edit-interface {
      display: flex;
      width: 100%;
      height: 100%;
    }

    .layout-sidebar {
      flex-shrink: 0;
      overflow-y: auto;
    }

    .layout-canvas {
      flex: 1;
      overflow-y: auto;
      background-color: #ffffff;
    }

    .layout-zone {
      min-height: 120px;
      border: 2px dashed #d1d5db;
      border-radius: 0.5rem;
      padding: 1.5rem;
      margin-bottom: 2rem;
      transition: border-color 0.2s ease;
    }

    .layout-zone:hover {
      border-color: #3b82f6;
    }

    .layout-zone[data-drag-over="true"] {
      border-color: #10b981;
      background-color: #ecfdf5;
    }

    .content-block {
      cursor: move;
      transition: transform 0.2s ease;
      position: relative;
    }

    .content-block:hover {
      transform: translateY(-2px);
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    }

    .content-block[dragging="true"] {
      opacity: 0.5;
      transform: rotate(5deg);
    }
    """
  end
end
