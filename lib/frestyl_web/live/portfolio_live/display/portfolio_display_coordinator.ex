# lib/frestyl_web/live/portfolio_live/display/portfolio_display_coordinator.ex
defmodule FrestylWeb.PortfolioLive.Display.PortfolioDisplayCoordinator do
  @moduledoc """
  Coordinates portfolio display by detecting professional type and routing to appropriate layout
  """
  use FrestylWeb, :live_component

  alias FrestylWeb.PortfolioLive.Display.LayoutDetector
  alias FrestylWeb.PortfolioLive.Layouts.{
    AchievementsModalComponent,
    BlogArticlesModalComponent,
    DeveloperLayoutComponent,
    CodeShowcaseModalComponent,
    CollaborationsModalComponent,
    CreativeLayoutComponent,
    CustomModalComponent,
    MediaShowcaseModalComponent,
    ProfessionalLayoutComponent,
    ServiceProviderLayoutComponent,
    MusicianLayoutComponent,
    TestimonialsModalComponent
  }

  def update(assigns, socket) do
    professional_type = LayoutDetector.determine_professional_type(assigns.portfolio)
    layout_style = get_layout_style(assigns.portfolio, professional_type)
    layout_component = LayoutDetector.get_layout_component(professional_type, layout_style)

    socket = socket
    |> assign(assigns)
    |> assign(:professional_type, professional_type)
    |> assign(:layout_style, layout_style)
    |> assign(:layout_component, layout_component)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="portfolio-display"
        data-professional-type={@professional_type}
        data-layout-style={@layout_style}
        data-portfolio-layout={Map.get(@customization, "portfolio_layout", "grid")}
        data-theme={Map.get(@customization, "theme", "professional")}>

      <!-- Use the existing layout component system -->
      <.live_component
        module={@layout_component}
        id={"#{@professional_type}-layout"}
        portfolio={@portfolio}
        sections={@sections}
        customization={@customization}
        layout_style={@layout_style} />
    </div>
    """
  end

  defp get_layout_style(portfolio, professional_type) do
    customization = portfolio.customization || %{}

    # Check for explicit layout style
    explicit_style = Map.get(customization, "layout_style")

    case explicit_style do
      nil -> get_default_layout_style(professional_type)
      style -> style
    end
  end

  defp get_default_layout_style(professional_type) do
    case professional_type do
      :developer -> "github"
      :creative -> "imdb"
      :musician -> "playlist"
      :service_provider -> "business"
      _ -> "standard"
    end
  end

  def update(assigns, socket) do
    professional_type = LayoutDetector.determine_professional_type(assigns.portfolio)
    layout_style = get_layout_style(assigns.portfolio, professional_type)
    layout_component = LayoutDetector.get_layout_component(professional_type, layout_style)

    IO.puts("🔍 LAYOUT DETECTION DEBUG:")
    IO.puts("  Portfolio: #{assigns.portfolio.title}")
    IO.puts("  Professional Type: #{inspect(professional_type)}")
    IO.puts("  Layout Style: #{inspect(layout_style)}")
    IO.puts("  Layout Component: #{inspect(layout_component)}")
    IO.puts("  Customization: #{inspect(Map.get(assigns.portfolio, :customization, %{}))}")

    socket = socket
    |> assign(assigns)
    |> assign(:professional_type, professional_type)
    |> assign(:layout_style, layout_style)
    |> assign(:layout_component, layout_component)

    {:ok, socket}
  end
end
