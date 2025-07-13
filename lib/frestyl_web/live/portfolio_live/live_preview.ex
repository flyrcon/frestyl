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
  def handle_info({:preview_update, data}, socket) when is_map(data) do
    css = Map.get(data, :css, "")
    customization = Map.get(data, :customization, %{})

    {:noreply, socket
    |> assign(:portfolio_css, css)
    |> assign(:customization, customization)}
  end

  # Catch-all for any other preview messages
  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 LivePreview received unhandled message: #{inspect(msg)}")
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
      <style id="mobile_view" phx-update="ignore"><%= raw(@preview_css) %></style>

      <!-- FIXED: Error boundary wrapper -->
      <div class="portfolio-preview-wrapper">
        <%= if @portfolio do %>
          <div class="portfolio-preview" style={"width: #{@viewport_width}; margin: 0 auto;"}>
            <!-- Portfolio Header -->
            <div class="portfolio-header bg-white shadow-sm">
              <div class="max-w-4xl mx-auto px-6 py-8">
                <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
                <%= if @portfolio.description do %>
                  <p class="text-xl text-gray-600 leading-relaxed"><%= @portfolio.description %></p>
                <% end %>
              </div>
            </div>

            <!-- Portfolio Sections -->
            <div class="portfolio-content">
              <%= if length(@sections) > 0 do %>
                <%= for section <- Enum.filter(@sections, & &1.visible) do %>
                  <div class="portfolio-section mb-8" data-section-type={section.section_type}>
                    <%= render_section_safe(section) %>
                  </div>
                <% end %>
              <% else %>
                <div class="empty-portfolio text-center py-16">
                  <div class="max-w-md mx-auto">
                    <div class="text-gray-400 mb-4">
                      <svg class="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                      </svg>
                    </div>
                    <h3 class="text-lg font-medium text-gray-900 mb-2">No content yet</h3>
                    <p class="text-gray-500">This portfolio is empty. Add some sections to see content here.</p>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Portfolio Footer -->
            <div class="portfolio-footer bg-gray-50 mt-16">
              <div class="max-w-4xl mx-auto px-6 py-8 text-center">
                <p class="text-gray-500 text-sm">
                  Created with Frestyl
                </p>
              </div>
            </div>
          </div>
        <% else %>
          <!-- Error state -->
          <div class="preview-error text-center py-16">
            <div class="text-red-400 mb-4">
              <svg class="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">Preview Error</h3>
            <p class="text-gray-500">Unable to load portfolio preview. Please refresh the page.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # SAFE SECTION RENDERING
  defp render_section_safe(section) do
    content = section.content || %{}

    case section.section_type do
      "hero" -> render_hero_section(section, content)
      "about" -> render_about_section(section, content)
      "experience" -> render_experience_section(section, content)
      "skills" -> render_skills_section(section, content)
      "portfolio" -> render_portfolio_section(section, content)
      "contact" -> render_contact_section(section, content)
      _ -> render_generic_section(section, content)
    end
  end

  defp render_hero_section(section, content) do
    assigns = %{section: section, content: content}

    ~H"""
    <div class="hero-section bg-gradient-to-br from-blue-600 to-purple-700 text-white">
      <div class="max-w-4xl mx-auto px-6 py-16 text-center">
        <h2 class="text-5xl font-bold mb-6"><%= @section.title %></h2>
        <%= if @content["subtitle"] do %>
          <p class="text-xl mb-8 opacity-90"><%= @content["subtitle"] %></p>
        <% end %>
        <%= if @content["description"] do %>
          <p class="text-lg leading-relaxed opacity-80"><%= @content["description"] %></p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_about_section(section, content) do
    assigns = %{section: section, content: content}

    ~H"""
    <div class="about-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <%= if @content["description"] do %>
          <div class="prose prose-lg max-w-none">
            <p class="text-gray-600 leading-relaxed"><%= @content["description"] %></p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_experience_section(section, content) do
    assigns = %{section: section, content: content}
    experiences = Map.get(content, "experiences", [])

    ~H"""
    <div class="experience-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <%= if length(experiences) > 0 do %>
          <div class="space-y-8">
            <%= for experience <- experiences do %>
              <div class="border-l-4 border-blue-500 pl-6">
                <h3 class="text-xl font-semibold text-gray-900"><%= experience["title"] || "Position" %></h3>
                <p class="text-blue-600 font-medium"><%= experience["company"] || "Company" %></p>
                <p class="text-gray-500 text-sm mb-2"><%= experience["duration"] || "Duration" %></p>
                <%= if experience["description"] do %>
                  <p class="text-gray-600"><%= experience["description"] %></p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500">No experience entries yet.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_skills_section(section, content) do
    assigns = %{section: section, content: content}
    skills = Map.get(content, "skills", [])

    ~H"""
    <div class="skills-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <%= if length(skills) > 0 do %>
          <div class="grid grid-cols-2 md:grid-cols-3 gap-4">
            <%= for skill <- skills do %>
              <div class="bg-gray-50 rounded-lg p-4 text-center">
                <h3 class="font-medium text-gray-900"><%= skill["name"] || "Skill" %></h3>
                <%= if skill["level"] do %>
                  <p class="text-sm text-gray-500"><%= skill["level"] %></p>
                <% end %>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500">No skills listed yet.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_portfolio_section(section, content) do
    assigns = %{section: section, content: content}
    projects = Map.get(content, "projects", [])

    ~H"""
    <div class="portfolio-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <%= if length(projects) > 0 do %>
          <div class="grid md:grid-cols-2 gap-8">
            <%= for project <- projects do %>
              <div class="bg-white border border-gray-200 rounded-lg overflow-hidden shadow-sm">
                <%= if project["image"] do %>
                  <img src={project["image"]} alt={project["title"] || "Project"} class="w-full h-48 object-cover" />
                <% end %>
                <div class="p-6">
                  <h3 class="text-xl font-semibold text-gray-900 mb-2"><%= project["title"] || "Project" %></h3>
                  <%= if project["description"] do %>
                    <p class="text-gray-600 mb-4"><%= project["description"] %></p>
                  <% end %>
                  <%= if project["technologies"] do %>
                    <div class="flex flex-wrap gap-2">
                      <%= for tech <- String.split(project["technologies"], ",") do %>
                        <span class="px-2 py-1 bg-blue-100 text-blue-800 text-xs rounded"><%= String.trim(tech) %></span>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <p class="text-gray-500">No projects showcased yet.</p>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_contact_section(section, content) do
    assigns = %{section: section, content: content}

    ~H"""
    <div class="contact-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <div class="bg-gray-50 rounded-lg p-8">
          <%= if @content["email"] do %>
            <p class="mb-4">
              <span class="font-medium text-gray-900">Email:</span>
              <a href={"mailto:#{@content["email"]}"} class="text-blue-600 hover:text-blue-800 ml-2"><%= @content["email"] %></a>
            </p>
          <% end %>
          <%= if @content["phone"] do %>
            <p class="mb-4">
              <span class="font-medium text-gray-900">Phone:</span>
              <span class="text-gray-600 ml-2"><%= @content["phone"] %></span>
            </p>
          <% end %>
          <%= if @content["location"] do %>
            <p class="mb-4">
              <span class="font-medium text-gray-900">Location:</span>
              <span class="text-gray-600 ml-2"><%= @content["location"] %></span>
            </p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_generic_section(section, content) do
    assigns = %{section: section, content: content}

    ~H"""
    <div class="generic-section">
      <div class="max-w-4xl mx-auto px-6 py-12">
        <h2 class="text-3xl font-bold text-gray-900 mb-8"><%= @section.title %></h2>
        <%= if @content["description"] do %>
          <p class="text-gray-600 leading-relaxed"><%= @content["description"] %></p>
        <% else %>
          <p class="text-gray-500">Section content will appear here.</p>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp load_portfolio_safe(portfolio_id) do
    try do
      case Portfolios.get_portfolio(portfolio_id) do
        nil ->
          %{id: portfolio_id, title: "Portfolio", description: nil, customization: %{}}
        portfolio ->
          portfolio
      end
    rescue
      _ ->
        %{id: portfolio_id, title: "Portfolio", description: nil, customization: %{}}
    end
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp verify_preview_token(portfolio_id, token) do
    # Basic token verification - enhance as needed
    is_binary(token) and String.length(token) > 10
  end

  defp determine_template_layout(portfolio) do
    case Map.get(portfolio, :customization, %{}) do
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> "traditional"
    end
  end

  defp generate_preview_css(portfolio) do
    customization = Map.get(portfolio, :customization, %{})
    primary_color = Map.get(customization, "primary_color", "#1e40af")
    secondary_color = Map.get(customization, "secondary_color", "#64748b")
    accent_color = Map.get(customization, "accent_color", "#f59e0b")

    """
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
      --accent-color: #{accent_color};
    }

    .portfolio-preview {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
    }

    .hero-section {
      background: linear-gradient(135deg, var(--primary-color), var(--accent-color));
    }

    .text-blue-600 {
      color: var(--primary-color) !important;
    }

    .bg-blue-100 {
      background-color: color-mix(in srgb, var(--primary-color) 10%, white) !important;
    }

    .border-blue-500 {
      border-color: var(--primary-color) !important;
    }
    """
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  @impl true
  def handle_info({:customization_updated, customization}, socket) do
    # Refresh the preview with new customization
    {:noreply, socket
    |> assign(:customization, customization)
    |> assign(:brand_colors, get_brand_colors_from_customization(customization))}
  end

  @impl true
  def handle_info({:layout_changed, layout_name, customization}, socket) do
    # Refresh the preview with new layout and customization
    {:noreply, socket
    |> assign(:layout_style, layout_name)
    |> assign(:customization, customization)
    |> assign(:brand_colors, get_brand_colors_from_customization(customization))}
  end

  defp get_brand_colors_from_customization(customization) do
    %{
      primary: Map.get(customization, "primary_color") || "#3b82f6",
      secondary: Map.get(customization, "secondary_color") || "#64748b",
      accent: Map.get(customization, "accent_color") || "#f59e0b"
    }
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
