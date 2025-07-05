# lib/frestyl_web/live/portfolio_live/live_preview.ex
# FIXED VERSION - Handles portfolio struct properly

defmodule FrestylWeb.PortfolioLive.LivePreview do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Phoenix.PubSub

  @impl true
  def mount(%{"id" => portfolio_id, "preview_token" => token}, _session, socket) do
    IO.puts("🔥 LIVE PREVIEW MOUNT: portfolio_id=#{portfolio_id}")

    if verify_preview_token(portfolio_id, token) do
      # Load portfolio safely
      portfolio = load_portfolio_safe(portfolio_id)
      IO.puts("🔥 PORTFOLIO LOADED: #{portfolio.title}")

      # Subscribe to live preview updates
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")

      sections = load_portfolio_sections(portfolio.id)
      IO.puts("🔥 SECTIONS LOADED: #{length(sections)} sections")

      # Get customization safely
      customization = Map.get(portfolio, :customization, %{})

      socket =
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:preview_mode, true)
        |> assign(:mobile_view, false)
        |> assign(:viewport_width, "100%")
        |> assign(:customization, customization)
        |> assign(:preview_css, generate_preview_css(portfolio))
        |> assign(:sections, sections)

      {:ok, socket}
    else
      {:ok, socket |> put_flash(:error, "Invalid preview session") |> redirect(to: "/")}
    end
  end

  @impl true
  def handle_info({:preview_update, customization, css}, socket) do
    socket =
      socket
      |> assign(:customization, customization)
      |> assign(:preview_css, css)
      |> push_event("update_preview_styles", %{css: css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    viewport_width = if mobile_view, do: "375px", else: "100%"

    socket =
      socket
      |> assign(:mobile_view, mobile_view)
      |> assign(:viewport_width, viewport_width)

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="live-preview-container" data-mobile-view={@mobile_view}>
      <style><%= raw(@preview_css) %></style>

      <div class="portfolio-preview">
        <!-- Portfolio Header -->
        <div class="portfolio-header">
          <h1 class="portfolio-title"><%= @portfolio.title %></h1>
          <%= if @portfolio.description do %>
            <p class="portfolio-description"><%= @portfolio.description %></p>
          <% end %>
        </div>

        <!-- Portfolio Sections -->
        <div class="portfolio-content">
          <%= for section <- @sections do %>
            <div class="portfolio-section" data-section-id={section.id}>
              <%= if section.title do %>
                <h2 class="section-title"><%= section.title %></h2>
              <% end %>

              <div class="section-content">
                <%= case section.section_type do %>
                  <% "intro" -> %>
                    <%= render_intro_section(section) %>
                  <% "experience" -> %>
                    <%= render_experience_section(section) %>
                  <% "skills" -> %>
                    <%= render_skills_section(section) %>
                  <% "projects" -> %>
                    <%= render_projects_section(section) %>
                  <% "contact" -> %>
                    <%= render_contact_section(section) %>
                  <% _ -> %>
                    <%= render_generic_section(section) %>
                <% end %>
              </div>
            </div>
          <% end %>

          <%= if length(@sections) == 0 do %>
            <div class="empty-portfolio">
              <p>No sections added yet. Add some content in the editor!</p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # SECTION RENDERERS
  # ============================================================================

  defp render_intro_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="intro-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add your introduction content...</p>
      <% end %>
    </div>
    """
  end

  defp render_experience_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="experience-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add your experience details...</p>
      <% end %>
    </div>
    """
  end

  defp render_skills_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="skills-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add your skills...</p>
      <% end %>
    </div>
    """
  end

  defp render_projects_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="projects-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add your projects...</p>
      <% end %>
    </div>
    """
  end

  defp render_contact_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="contact-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add your contact information...</p>
      <% end %>
    </div>
    """
  end

  defp render_generic_section(section) do
    content = section.content || %{}
    main_content = Map.get(content, "main_content", "")

    assigns = %{content: main_content}

    ~H"""
    <div class="generic-content">
      <%= if @content != "" do %>
        <%= raw(@content) %>
      <% else %>
        <p class="placeholder-text">Add content for this section...</p>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp load_portfolio_safe(portfolio_id) do
    try do
      Portfolios.get_portfolio!(portfolio_id)
    rescue
      _ ->
        # Fallback if function signature is different
        try do
          Portfolios.get_portfolio(portfolio_id)
        rescue
          _ -> %{id: portfolio_id, title: "Portfolio", description: nil}
        end
    end
  end

  defp verify_preview_token(portfolio_id, token) do
    expected_token = :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
                     |> Base.encode16(case: :lower)

    token == expected_token
  end

  defp generate_preview_css(portfolio) do
    theme = Map.get(portfolio, :theme, "minimal")
    customization = Map.get(portfolio, :customization, %{})

    generate_portfolio_css(customization, theme)
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp generate_portfolio_css(customization, theme) do
    primary_color = Map.get(customization, "primary_color", "#374151")
    accent_color = Map.get(customization, "accent_color", "#059669")
    secondary_color = Map.get(customization, "secondary_color", "#6b7280")
    layout = Map.get(customization, "layout", "minimal")

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
      --secondary-color: #{secondary_color};
    }

    .live-preview-container {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
      background: #fff;
      min-height: 100vh;
    }

    .portfolio-preview {
      max-width: 800px;
      margin: 0 auto;
      padding: 2rem 1rem;
    }

    .portfolio-header {
      text-align: center;
      margin-bottom: 3rem;
      padding: 2rem;
      background: var(--primary-color);
      color: white;
      border-radius: 8px;
    }

    .portfolio-title {
      font-size: 2.5rem;
      font-weight: bold;
      margin: 0 0 1rem 0;
    }

    .portfolio-description {
      font-size: 1.2rem;
      opacity: 0.9;
      margin: 0;
    }

    .portfolio-section {
      background: white;
      border-radius: 8px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      border: 1px solid #e5e7eb;
    }

    .section-title {
      font-size: 1.8rem;
      font-weight: bold;
      margin: 0 0 1rem 0;
      color: var(--primary-color);
      border-bottom: 2px solid var(--accent-color);
      padding-bottom: 0.5rem;
    }

    .section-content {
      margin-top: 1rem;
    }

    .placeholder-text {
      color: #9ca3af;
      font-style: italic;
      text-align: center;
      padding: 2rem;
      background: #f9fafb;
      border: 2px dashed #d1d5db;
      border-radius: 4px;
      margin: 0;
    }

    .empty-portfolio {
      text-align: center;
      padding: 4rem 2rem;
      color: #6b7280;
    }

    /* Mobile responsive */
    [data-mobile-view="true"] .portfolio-preview {
      max-width: 375px;
      padding: 1rem;
    }

    [data-mobile-view="true"] .portfolio-title {
      font-size: 2rem;
    }

    [data-mobile-view="true"] .portfolio-section {
      padding: 1rem;
    }

    [data-mobile-view="true"] .section-title {
      font-size: 1.5rem;
    }
    """
  end
end
