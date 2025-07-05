# lib/frestyl_web/live/portfolio_live/show.ex
# FIXED VERSION - Renders portfolios with dynamic card layout support

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Phoenix.PubSub

  # ============================================================================
  # MOUNT - Load and render portfolio
  # ============================================================================

  # ============================================================================
  # MOUNT - Load and render portfolio
  # ============================================================================

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case load_portfolio_by_slug(slug) do
      {:ok, portfolio} ->
        mount_portfolio(portfolio, socket)
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case load_portfolio_by_id(id) do
      {:ok, portfolio} ->
        mount_portfolio(portfolio, socket)
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> put_flash(:error, "Invalid portfolio") |> redirect(to: "/")}
  end

  defp mount_portfolio(portfolio, socket) do
    # Subscribe to live updates from editor
    Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")

    # Track portfolio visit
    track_portfolio_visit_safe(portfolio, socket)

    socket = socket
    |> assign_portfolio_data(portfolio)
    |> assign_rendering_data(portfolio)
    |> assign_ui_state()

    {:ok, socket}
  end

  # ============================================================================
  # LIVE UPDATE HANDLERS (from editor)
  # ============================================================================

  @impl true
  def handle_info({:preview_update, customization, css}, socket) do
    socket = socket
    |> assign(:customization, customization)
    |> assign(:custom_css, css)
    |> push_event("update_styles", %{css: css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:content_update, section}, socket) do
    sections = update_section_in_list(socket.assigns.sections, section)

    socket = socket
    |> assign(:sections, sections)
    |> push_event("update_section_content", %{
      section_id: section.id,
      content: section.content
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:sections_update, sections}, socket) do
    socket = assign(socket, :sections, sections)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dynamic_layout_update, layout_zones}, socket) do
    socket = socket
    |> assign(:layout_zones, layout_zones)
    |> assign(:is_dynamic_layout, true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:brand_update, brand_settings}, socket) do
    # Regenerate design tokens with new brand settings
    design_tokens = generate_design_tokens_with_brand(socket.assigns.portfolio, brand_settings)
    custom_css = generate_brand_css(brand_settings)

    socket = socket
    |> assign(:brand_settings, brand_settings)
    |> assign(:design_tokens, design_tokens)
    |> assign(:custom_css, custom_css)
    |> push_event("update_styles", %{css: custom_css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    socket = assign(socket, :mobile_view, mobile_view)
    {:noreply, socket}
  end

  # ============================================================================
  # RENDERING LOGIC
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <div class="portfolio-show" data-portfolio-id={@portfolio.id}>
      <!-- Dynamic CSS injection -->
      <%= if @custom_css do %>
        <style><%= raw(@custom_css) %></style>
      <% end %>

      <!-- Portfolio Header -->
      <div class="portfolio-header">
        <h1 class="portfolio-title"><%= @portfolio.title %></h1>
        <%= if @portfolio.description do %>
          <p class="portfolio-description"><%= @portfolio.description %></p>
        <% end %>
      </div>

      <!-- Portfolio Content -->
      <div class={["portfolio-content", portfolio_layout_class(@portfolio)]}>
        <%= if @is_dynamic_layout do %>
          <!-- Dynamic Card Layout -->
          <%= render_dynamic_card_layout(assigns) %>
        <% else %>
          <!-- Traditional Section Layout -->
          <%= render_traditional_layout(assigns) %>
        <% end %>
      </div>

      <!-- Portfolio Footer -->
      <div class="portfolio-footer">
        <%= if @show_branding do %>
          <p class="powered-by">
            Powered by <a href="/" class="frestyl-link">Frestyl</a>
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # LAYOUT RENDERING FUNCTIONS
  # ============================================================================

  defp render_dynamic_card_layout(assigns) do
    ~H"""
    <div class="dynamic-card-layout">
      <!-- Hero Zone -->
      <%= if Map.get(@layout_zones, :hero, []) != [] do %>
        <div class="layout-zone hero-zone">
          <%= for block <- Map.get(@layout_zones, :hero, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>
      <% end %>

      <!-- Main Content Zone -->
      <div class="main-content-wrapper">
        <div class="layout-zone main-content-zone">
          <%= for block <- Map.get(@layout_zones, :main_content, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>

        <!-- Sidebar Zone -->
        <%= if Map.get(@layout_zones, :sidebar, []) != [] do %>
          <div class="layout-zone sidebar-zone">
            <%= for block <- Map.get(@layout_zones, :sidebar, []) do %>
              <%= render_dynamic_card_block(block, assigns) %>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Footer Zone -->
      <%= if Map.get(@layout_zones, :footer, []) != [] do %>
        <div class="layout-zone footer-zone">
          <%= for block <- Map.get(@layout_zones, :footer, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_traditional_layout(assigns) do
    ~H"""
    <div class="traditional-layout">
      <!-- Always show edit button for owner at top -->
      <%= if Map.get(assigns, :current_user) && Map.get(assigns.current_user, :id) == Map.get(@portfolio, :user_id) do %>
        <div class="owner-actions" style="text-align: center; margin-bottom: 2rem;">
          <.link navigate={"/portfolios/#{@portfolio.id}/edit"}
                class="btn-primary">
            Edit Portfolio
          </.link>
        </div>
      <% end %>

      <%= if length(@sections) > 0 do %>
        <%= for section <- @sections do %>
          <%= if Map.get(section, :visible, true) do %>
            <div class={["portfolio-section", "section-#{Map.get(section, :section_type, "generic")}"]}
                data-section-id={Map.get(section, :id)}>
              <%= render_portfolio_section(section, assigns) %>
            </div>
          <% end %>
        <% end %>
      <% else %>
        <!-- Empty state (without edit button since it's moved above) -->
        <div class="empty-portfolio">
          <div class="empty-content">
            <svg class="empty-icon" width="64" height="64" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <h3>Portfolio Under Construction</h3>
            <p>This portfolio is being set up. Check back soon!</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_dynamic_card_block(block, assigns) do
    assigns = assign(assigns, :block, block)

    ~H"""
    <div class={["dynamic-card-block", "block-#{@block.block_type}"]}
         data-block-id={@block.id}>
      <%= case @block.block_type do %>
        <% :intro_card -> %>
          <%= render_intro_card_block(@block, assigns) %>
        <% :experience_card -> %>
          <%= render_experience_card_block(@block, assigns) %>
        <% :skills_card -> %>
          <%= render_skills_card_block(@block, assigns) %>
        <% :projects_card -> %>
          <%= render_projects_card_block(@block, assigns) %>
        <% :contact_card -> %>
          <%= render_contact_card_block(@block, assigns) %>
        <% _ -> %>
          <%= render_generic_card_block(@block, assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_portfolio_section(section, assigns) do
    assigns = assign(assigns, :section, section)

    ~H"""
    <div class="section-content">
      <%= if @section.title do %>
        <h2 class="section-title"><%= @section.title %></h2>
      <% end %>

      <%= case @section.section_type do %>
        <% "intro" -> %>
          <%= render_intro_section(@section, assigns) %>
        <% "experience" -> %>
          <%= render_experience_section(@section, assigns) %>
        <% "skills" -> %>
          <%= render_skills_section(@section, assigns) %>
        <% "projects" -> %>
          <%= render_projects_section(@section, assigns) %>
        <% "contact" -> %>
          <%= render_contact_section(@section, assigns) %>
        <% _ -> %>
          <%= render_generic_section(@section, assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # CARD BLOCK RENDERERS
  # ============================================================================

  defp render_intro_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="intro-card">
      <%= if @content["title"] do %>
        <h3 class="card-title"><%= @content["title"] %></h3>
      <% end %>
      <%= if @content["description"] do %>
        <p class="card-description"><%= @content["description"] %></p>
      <% end %>
      <%= if @content["image_url"] do %>
        <img src={@content["image_url"]} alt="Profile" class="card-image" />
      <% end %>
    </div>
    """
  end

  defp render_experience_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="experience-card">
      <%= if @content["company"] do %>
        <h4 class="company-name"><%= @content["company"] %></h4>
      <% end %>
      <%= if @content["position"] do %>
        <p class="position-title"><%= @content["position"] %></p>
      <% end %>
      <%= if @content["duration"] do %>
        <p class="duration"><%= @content["duration"] %></p>
      <% end %>
      <%= if @content["description"] do %>
        <p class="description"><%= @content["description"] %></p>
      <% end %>
    </div>
    """
  end

  defp render_skills_card_block(block, assigns) do
    content = block.content_data || %{}
    skills = content["skills"] || []
    assigns = assign(assigns, :skills, skills)

    ~H"""
    <div class="skills-card">
      <h4 class="card-title">Skills</h4>
      <div class="skills-list">
        <%= for skill <- @skills do %>
          <span class="skill-tag"><%= skill %></span>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_projects_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="projects-card">
      <%= if @content["title"] do %>
        <h4 class="project-title"><%= @content["title"] %></h4>
      <% end %>
      <%= if @content["description"] do %>
        <p class="project-description"><%= @content["description"] %></p>
      <% end %>
      <%= if @content["technologies"] do %>
        <div class="technologies">
          <%= for tech <- @content["technologies"] do %>
            <span class="tech-tag"><%= tech %></span>
          <% end %>
        </div>
      <% end %>
      <%= if @content["link"] do %>
        <a href={@content["link"]} class="project-link" target="_blank">View Project</a>
      <% end %>
    </div>
    """
  end

  defp render_contact_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="contact-card">
      <h4 class="card-title">Contact</h4>
      <%= if @content["email"] do %>
        <p class="contact-item">
          <span class="contact-label">Email:</span>
          <a href={"mailto:#{@content["email"]}"} class="contact-link"><%= @content["email"] %></a>
        </p>
      <% end %>
      <%= if @content["phone"] do %>
        <p class="contact-item">
          <span class="contact-label">Phone:</span>
          <a href={"tel:#{@content["phone"]}"} class="contact-link"><%= @content["phone"] %></a>
        </p>
      <% end %>
      <%= if @content["linkedin"] do %>
        <p class="contact-item">
          <span class="contact-label">LinkedIn:</span>
          <a href={@content["linkedin"]} class="contact-link" target="_blank">Profile</a>
        </p>
      <% end %>
    </div>
    """
  end

  defp render_generic_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="generic-card">
      <%= if @content["title"] do %>
        <h4 class="card-title"><%= @content["title"] %></h4>
      <% end %>
      <%= if @content["content"] do %>
        <div class="card-content"><%= raw(@content["content"]) %></div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # TRADITIONAL SECTION RENDERERS
  # ============================================================================

  defp render_intro_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="intro-section">
      <%= if @content["main_content"] do %>
        <div class="intro-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_experience_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="experience-section">
      <%= if @content["main_content"] do %>
        <div class="experience-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_skills_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="skills-section">
      <%= if @content["main_content"] do %>
        <div class="skills-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_projects_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="projects-section">
      <%= if @content["main_content"] do %>
        <div class="projects-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_contact_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="contact-section">
      <%= if @content["main_content"] do %>
        <div class="contact-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_generic_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="generic-section">
      <%= if @content["main_content"] do %>
        <div class="section-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp load_portfolio_by_slug(slug) do
    try do
      case Portfolios.get_portfolio_by_slug_with_sections(slug) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ ->
        try do
          case Portfolios.get_portfolio_by_slug(slug) do
            nil -> {:error, :not_found}
            portfolio -> {:ok, portfolio}
          end
        rescue
          _ -> {:error, :not_found}
        end
    end
  end

  defp load_portfolio_by_id(id) do
    try do
      portfolio_id = String.to_integer(id)
      case Portfolios.get_portfolio_with_sections(portfolio_id) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ ->
        try do
          portfolio_id = String.to_integer(id)
          case Portfolios.get_portfolio!(portfolio_id) do
            nil -> {:error, :not_found}
            portfolio -> {:ok, portfolio}
          end
        rescue
          _ -> {:error, :not_found}
        end
    end
  end

  defp assign_portfolio_data(socket, portfolio) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:owner, portfolio.user)
    |> assign(:page_title, portfolio.title)
  end

  defp assign_rendering_data(socket, portfolio) do
    # Determine if this is a dynamic card layout
    is_dynamic_layout = is_dynamic_card_layout?(portfolio)

    # Load appropriate data based on layout type
    {sections, layout_zones} = if is_dynamic_layout do
      {[], load_dynamic_layout_zones(portfolio.id)}
    else
      # Try to load sections from multiple sources
      sections = load_portfolio_sections_for_display(portfolio)
      {sections, %{}}
    end

    # Process customization and generate CSS safely
    customization = Map.get(portfolio, :customization, %{})
    theme = Map.get(portfolio, :theme, "professional")
    template_config = get_template_config(theme)
    custom_css = generate_safe_portfolio_css(customization, template_config)

    socket
    |> assign(:sections, sections)
    |> assign(:layout_zones, layout_zones)
    |> assign(:is_dynamic_layout, is_dynamic_layout)
    |> assign(:customization, customization)
    |> assign(:template_config, template_config)
    |> assign(:custom_css, custom_css)
    |> assign(:design_tokens, generate_design_tokens(portfolio))
    |> assign(:brand_settings, nil)
  end

  # Safe CSS generation function
  defp generate_safe_portfolio_css(customization, template_config) do
    # Extract colors safely - prioritize customization over template
    primary_color = Map.get(customization, "primary_color") ||
                   Map.get(template_config, "primary_color") ||
                   "#1e40af"

    accent_color = Map.get(customization, "accent_color") ||
                  Map.get(template_config, "accent_color") ||
                  "#f59e0b"

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
    }

    .portfolio-show {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
    }

    .portfolio-header {
      text-align: center;
      padding: 2rem 1rem;
      background: var(--primary-color);
      color: white;
    }

    .portfolio-title {
      font-size: 2.5rem;
      font-weight: bold;
      margin-bottom: 0.5rem;
    }

    .portfolio-description {
      font-size: 1.2rem;
      opacity: 0.9;
    }

    .traditional-layout {
      max-width: 800px;
      margin: 0 auto;
      padding: 2rem 1rem;
    }

    .portfolio-section {
      background: white;
      border-radius: 8px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .section-title {
      font-size: 1.8rem;
      font-weight: bold;
      margin-bottom: 1rem;
      color: var(--primary-color);
    }

    .empty-portfolio {
      text-align: center;
      padding: 4rem 2rem;
      min-height: 400px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .empty-content {
      max-width: 400px;
    }

    .empty-icon {
      color: #9ca3af;
      margin: 0 auto 1.5rem;
    }

    .empty-content h3 {
      font-size: 1.5rem;
      font-weight: bold;
      color: #374151;
      margin-bottom: 0.5rem;
    }

    .empty-content p {
      color: #6b7280;
      margin-bottom: 2rem;
    }

    .btn-primary {
      display: inline-block;
      background: var(--primary-color);
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 8px;
      text-decoration: none;
      font-weight: medium;
      transition: background-color 0.2s;
    }

    .btn-primary:hover {
      opacity: 0.9;
    }

    .debug-info {
      font-family: monospace;
      font-size: 0.75rem;
      line-height: 1.4;
    }

    .portfolio-footer {
      text-align: center;
      padding: 2rem;
      background: #f8f9fa;
      color: #666;
    }
    """
  end

  defp load_portfolio_sections_for_display(portfolio) do
    # First try to get sections from portfolio association
    sections = case Map.get(portfolio, :sections) do
      %Ecto.Association.NotLoaded{} ->
        # Association not loaded, try to load manually
        load_sections_manually(portfolio.id)
      sections when is_list(sections) ->
        sections
      _ ->
        # No sections or unexpected format
        load_sections_manually(portfolio.id)
    end

    # Also try portfolio_sections association
    if length(sections) == 0 do
      case Map.get(portfolio, :portfolio_sections) do
        %Ecto.Association.NotLoaded{} ->
          load_sections_manually(portfolio.id)
        portfolio_sections when is_list(portfolio_sections) ->
          portfolio_sections
        _ ->
          []
      end
    else
      sections
    end
  end

  defp load_sections_manually(portfolio_id) do
    try do
      # Try standard function first
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ ->
        try do
          # Try alternative function name
          Portfolios.get_portfolio_sections(portfolio_id)
        rescue
          _ ->
            try do
              # Try direct query as last resort
              import Ecto.Query

              # Query the portfolio_sections table directly
              query = from ps in "portfolio_sections",
                where: ps.portfolio_id == ^portfolio_id,
                order_by: [asc: ps.position],
                select: %{
                  id: ps.id,
                  portfolio_id: ps.portfolio_id,
                  title: ps.title,
                  section_type: ps.section_type,
                  content: ps.content,
                  position: ps.position,
                  visible: ps.visible
                }

              Repo.all(query)
            rescue
              _ ->
                IO.puts("⚠️ Could not load sections for portfolio #{portfolio_id}")
                []
            end
        end
    end
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:mobile_view, false)
    |> assign(:show_branding, true)
    |> assign(:current_user, Map.get(socket.assigns, :current_user, nil))  # ADD THIS LINE
  end

  defp is_dynamic_card_layout?(portfolio) do
    # Get layout safely with fallback
    layout = Map.get(portfolio, :layout, "traditional")

    layout in ["dynamic_card", "professional_cards", "creative_cards"] ||
    Map.get(Map.get(portfolio, :customization, %{}), "use_dynamic_cards", false)
  end

  defp load_dynamic_layout_zones(_portfolio_id) do
    # This would load from database in real implementation
    %{
      hero: [],
      main_content: [],
      sidebar: [],
      footer: []
    }
  end

  defp get_template_config(theme) do
    try do
      case PortfolioTemplates.get_template_config(theme || "professional") do
        config when is_map(config) -> config
        _ -> get_default_template_config()
      end
    rescue
      _ -> get_default_template_config()
    end
  end

  defp get_default_template_config do
    %{
      "primary_color" => "#1e40af",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "layout" => "traditional"
    }
  end

  defp generate_portfolio_css(customization, template_config) do
    primary_color = Map.get(customization, "primary_color", template_config.primary_color)
    accent_color = Map.get(customization, "accent_color", template_config.secondary_color)

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
    }

    .portfolio-show {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
    }

    .portfolio-header {
      text-align: center;
      padding: 2rem 1rem;
      background: var(--primary-color);
      color: white;
    }

    .portfolio-title {
      font-size: 2.5rem;
      font-weight: bold;
      margin-bottom: 0.5rem;
    }

    .portfolio-description {
      font-size: 1.2rem;
      opacity: 0.9;
    }

    .dynamic-card-layout {
      display: grid;
      grid-template-areas:
        "hero hero"
        "main sidebar"
        "footer footer";
      grid-template-columns: 2fr 1fr;
      gap: 2rem;
      padding: 2rem;
    }

    .hero-zone { grid-area: hero; }
    .main-content-zone { grid-area: main; }
    .sidebar-zone { grid-area: sidebar; }
    .footer-zone { grid-area: footer; }

    .dynamic-card-block {
      background: white;
      border-radius: 8px;
      padding: 1.5rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      margin-bottom: 1rem;
    }

    .traditional-layout {
      max-width: 800px;
      margin: 0 auto;
      padding: 2rem 1rem;
    }

    .portfolio-section {
      background: white;
      border-radius: 8px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .section-title {
      font-size: 1.8rem;
      font-weight: bold;
      margin-bottom: 1rem;
      color: var(--primary-color);
    }

    .card-title {
      font-size: 1.4rem;
      font-weight: bold;
      margin-bottom: 1rem;
      color: var(--primary-color);
    }

    .skill-tag, .tech-tag {
      display: inline-block;
      background: var(--accent-color);
      color: white;
      padding: 0.25rem 0.75rem;
      border-radius: 1rem;
      margin: 0.25rem;
      font-size: 0.875rem;
    }

    .portfolio-footer {
      text-align: center;
      padding: 2rem;
      background: #f8f9fa;
      color: #666;
    }

    .empty-portfolio {
      text-align: center;
      padding: 4rem 2rem;
      min-height: 400px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .empty-content {
      max-width: 400px;
    }

    .empty-icon {
      color: #9ca3af;
      margin: 0 auto 1.5rem;
    }

    .empty-content h3 {
      font-size: 1.5rem;
      font-weight: bold;
      color: #374151;
      margin-bottom: 0.5rem;
    }

    .empty-content p {
      color: #6b7280;
      margin-bottom: 2rem;
    }

    .owner-actions {
      margin-top: 1rem;
    }

    .btn-primary {
      display: inline-block;
      background: var(--primary-color);
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 8px;
      text-decoration: none;
      font-weight: medium;
      transition: background-color 0.2s;
    }

    .btn-primary:hover {
      background: color-mix(in srgb, var(--primary-color) 90%, black);
    }

    .debug-info {
      font-family: monospace;
      font-size: 0.75rem;
      line-height: 1.4;
    }

    @media (max-width: 768px) {
      .dynamic-card-layout {
        grid-template-areas:
          "hero"
          "main"
          "sidebar"
          "footer";
        grid-template-columns: 1fr;
      }

      .portfolio-title {
        font-size: 2rem;
      }

      .empty-portfolio {
        padding: 2rem 1rem;
        min-height: 300px;
      }
    }
    """
  end

  defp generate_design_tokens(portfolio) do
    customization = Map.get(portfolio, :customization, %{})

    %{
      primary_color: Map.get(customization, "primary_color", "#1e40af"),
      accent_color: Map.get(customization, "accent_color", "#f59e0b"),
      font_family: Map.get(customization, "font_family", "Inter")
    }
  end

  defp generate_design_tokens_with_brand(portfolio, brand_settings) do
    base_tokens = generate_design_tokens(portfolio)

    # Handle both atom and string keys for brand_settings
    brand_primary = case brand_settings do
      %{primary_color: color} -> color
      %{"primary_color" => color} -> color
      _ -> "#1e40af"
    end

    brand_secondary = case brand_settings do
      %{secondary_color: color} -> color
      %{"secondary_color" => color} -> color
      _ -> "#64748b"
    end

    brand_accent = case brand_settings do
      %{accent_color: color} -> color
      %{"accent_color" => color} -> color
      _ -> "#f59e0b"
    end

    Map.merge(base_tokens, %{
      brand_primary: brand_primary,
      brand_secondary: brand_secondary,
      brand_accent: brand_accent
    })
  end

  defp generate_brand_css(brand_settings) do
    # Handle both atom and string keys for brand_settings
    primary = case brand_settings do
      %{primary_color: color} -> color
      %{"primary_color" => color} -> color
      _ -> "#1e40af"
    end

    secondary = case brand_settings do
      %{secondary_color: color} -> color
      %{"secondary_color" => color} -> color
      _ -> "#64748b"
    end

    accent = case brand_settings do
      %{accent_color: color} -> color
      %{"accent_color" => color} -> color
      _ -> "#f59e0b"
    end

    """
    :root {
      --brand-primary: #{primary};
      --brand-secondary: #{secondary};
      --brand-accent: #{accent};
    }
    """
  end

  defp portfolio_layout_class(portfolio) do
    layout = Map.get(portfolio, :layout, "traditional")

    case layout do
      "dynamic_card" -> "layout-dynamic-card"
      "professional_cards" -> "layout-professional-cards"
      "creative_cards" -> "layout-creative-cards"
      _ -> "layout-traditional"
    end
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        updated_section
      else
        section
      end
    end)
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      current_user = Map.get(socket.assigns, :current_user, nil)

      visit_attrs = %{
        portfolio_id: portfolio.id,
        ip_address: get_client_ip(socket),
        user_agent: get_user_agent(socket),
        referrer: get_referrer(socket)
      }

      visit_attrs = if current_user do
        Map.put(visit_attrs, :user_id, current_user.id)
      else
        visit_attrs
      end

      Portfolios.create_portfolio_visit(visit_attrs)
    rescue
      _ -> :ok
    end
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> :inet.ntoa(address) |> to_string()
      _ -> "127.0.0.1"
    end
  end

  defp get_user_agent(socket) do
    get_connect_info(socket, :user_agent) || ""
  end

  defp get_referrer(socket) do
    get_connect_params(socket)["ref"]
  end
end
