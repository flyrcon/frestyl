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

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
    end

    {:ok, socket}
  end

  # ============================================================================
  # LIVE UPDATE HANDLERS (from editor)
  # ============================================================================

  @impl true
  def handle_info({:preview_update, data}, socket) when is_map(data) do
    css = Map.get(data, :css, "")
    customization = Map.get(data, :customization, %{})

    {:noreply, socket
    |> assign(:portfolio_css, css)
    |> assign(:customization, customization)}
  end

  @impl true
  def handle_info({:layout_changed, layout_name, customization}, socket) do
    # Generate new CSS with the layout change
    css = generate_portfolio_css(customization)

    socket = socket
    |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)
    |> push_event("update_portfolio_styles", %{css: css})  # Add this line

    {:noreply, socket}
  end

  @impl true
  def handle_info({:customization_updated, customization}, socket) do
    # Generate new CSS with updated customization
    css = generate_portfolio_css(customization)

    socket = socket
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)
    |> push_event("update_portfolio_styles", %{css: css})  # Add this line

    {:noreply, socket}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 Show received unhandled message: #{inspect(msg)}")
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

  defp render_service_provider_layout(assigns) do
    ~H"""
    <div class="service-provider-layout">
      <!-- Hero Section with Service Focus -->
      <section class="hero-section py-20" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.secondary} 100%)"}>
        <div class="container mx-auto px-6 text-center">
          <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-white/90 mb-8 max-w-2xl mx-auto"><%= @portfolio.description %></p>

          <!-- Service CTAs -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
              Book Consultation
            </button>
            <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
              View Services
            </button>
          </div>
        </div>
      </section>

      <!-- Services Grid -->
      <section class="services-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Services</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "services", "skills"]) do %>
              <div class="service-card bg-white rounded-xl p-6 shadow-lg hover:shadow-xl transition-shadow">
                <h3 class="text-xl font-semibold mb-4" style={"color: #{@brand_colors.primary}"}><%= section.title %></h3>
                <p class="text-gray-600 mb-4"><%= get_section_excerpt(section) %></p>
                <button class="text-sm font-medium hover:underline" style={"color: #{@brand_colors.accent}"}>
                  Learn More →
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <!-- Trust Building: Testimonials + Pricing -->
      <section class="trust-section py-16">
        <div class="container mx-auto px-6">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-12">
            <!-- Testimonials -->
            <div class="lg:col-span-2">
              <h2 class="text-3xl font-bold mb-8">Client Testimonials</h2>
              <div class="space-y-6">
                <%= for section <- filter_sections_by_type(@sections, ["testimonial"]) do %>
                  <div class="testimonial-card bg-white p-6 rounded-xl border border-gray-200">
                    <p class="text-gray-700 mb-4 italic">"<%= get_section_excerpt(section) %>"</p>
                    <div class="flex items-center">
                      <div class="w-12 h-12 rounded-full mr-4" style={"background: #{@brand_colors.primary}"}></div>
                      <div>
                        <h4 class="font-semibold"><%= section.title %></h4>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Pricing -->
            <div class="lg:col-span-1">
              <h2 class="text-3xl font-bold mb-8">Pricing</h2>
              <div class="pricing-card bg-white p-6 rounded-xl border-2" style={"border-color: #{@brand_colors.accent}"}>
                <h3 class="text-xl font-semibold mb-4">Consultation</h3>
                <div class="text-4xl font-bold mb-4" style={"color: #{@brand_colors.primary}"}>$150<span class="text-lg text-gray-600">/hour</span></div>
                <ul class="space-y-2 mb-6">
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Expert consultation</li>
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Action plan included</li>
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Follow-up support</li>
                </ul>
                <button class="w-full py-3 rounded-lg font-semibold text-white transition-colors" style={"background: #{@brand_colors.primary}"}>
                  Book Now
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_creative_showcase_layout(assigns) do
    ~H"""
    <div class="creative-showcase-layout">
      <!-- Visual Hero -->
      <section class="hero-section min-h-screen bg-gradient-to-br from-purple-900 via-pink-800 to-orange-600 relative overflow-hidden">
        <div class="absolute inset-0 bg-black/20"></div>
        <div class="relative z-10 container mx-auto px-6 flex items-center min-h-screen">
          <div class="max-w-3xl">
            <h1 class="text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight"><%= @portfolio.title %></h1>
            <p class="text-2xl text-white/90 mb-8"><%= @portfolio.description %></p>
            <div class="flex gap-4">
              <button class="px-8 py-4 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
                View Portfolio
              </button>
              <button class="px-8 py-4 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
                Commission Work
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Portfolio Masonry Grid -->
      <section class="portfolio-section py-20">
        <div class="container mx-auto px-6">
          <h2 class="text-4xl font-bold text-center mb-16">Recent Work</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "featured_project", "media_showcase"]) do %>
              <div class="portfolio-item group cursor-pointer">
                <div class="aspect-square bg-gradient-to-br rounded-2xl overflow-hidden" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.accent} 100%)"}>
                  <div class="w-full h-full flex items-center justify-center bg-black/20 group-hover:bg-black/40 transition-colors">
                    <div class="text-center text-white p-6">
                      <h3 class="text-xl font-bold mb-2"><%= section.title %></h3>
                      <p class="text-white/80 opacity-0 group-hover:opacity-100 transition-opacity">
                        <%= get_section_excerpt(section) %>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_content_creator_layout(assigns) do
    ~H"""
    <div class="content-creator-layout">
      <!-- Streaming Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-purple-600 via-pink-600 to-orange-500">
        <div class="container mx-auto px-6 text-center">
          <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-white/90 mb-8 max-w-2xl mx-auto"><%= @portfolio.description %></p>

          <!-- Creator CTAs -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
              Subscribe
            </button>
            <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
              Collaborate
            </button>
          </div>
        </div>
      </section>

      <!-- Content Metrics -->
      <section class="metrics-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Creator Stats</h2>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>100K+</div>
              <div class="text-gray-600">Followers</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>1M+</div>
              <div class="text-gray-600">Views</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>500+</div>
              <div class="text-gray-600">Videos</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>98%</div>
              <div class="text-gray-600">Positive Rating</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Content Showcase -->
      <section class="content-section py-16">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Latest Content</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "media_showcase"]) do %>
              <div class="content-card bg-white rounded-xl overflow-hidden shadow-lg hover:shadow-xl transition-shadow">
                <div class="aspect-video bg-gradient-to-br rounded-t-xl" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.accent} 100%)"}>
                  <div class="w-full h-full flex items-center justify-center">
                    <div class="text-white text-center">
                      <h3 class="text-lg font-bold"><%= section.title %></h3>
                    </div>
                  </div>
                </div>
                <div class="p-6">
                  <p class="text-gray-600 mb-4"><%= get_section_excerpt(section) %></p>
                  <button class="text-sm font-medium hover:underline" style={"color: #{@brand_colors.accent}"}>
                    Watch Now →
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_corporate_executive_layout(assigns) do
    ~H"""
    <div class="corporate-executive-layout">
      <!-- Executive Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-slate-900 to-blue-900">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl mx-auto text-center">
            <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
            <p class="text-xl text-white/90 mb-8"><%= @portfolio.description %></p>

            <!-- Executive CTAs -->
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
                Schedule Meeting
              </button>
              <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
                Download Resume
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Executive Summary -->
      <section class="summary-section py-16 bg-white">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Executive Summary</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>15+</div>
                <div class="text-gray-600">Years Experience</div>
              </div>
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>$50M+</div>
                <div class="text-gray-600">Revenue Generated</div>
              </div>
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>200+</div>
                <div class="text-gray-600">Team Members Led</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Leadership Experience -->
      <section class="experience-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Leadership Experience</h2>
          <div class="max-w-4xl mx-auto space-y-8">
            <%= for section <- filter_sections_by_type(@sections, ["experience", "achievements"]) do %>
              <div class="experience-card bg-white p-8 rounded-xl shadow-lg">
                <div class="flex items-start justify-between mb-4">
                  <div>
                    <h3 class="text-xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}><%= section.title %></h3>
                    <p class="text-gray-600"><%= get_section_excerpt(section) %></p>
                  </div>
                  <div class="text-right">
                    <div class="text-sm text-gray-500">2020 - Present</div>
                  </div>
                </div>
                <div class="flex flex-wrap gap-2">
                  <span class="px-3 py-1 bg-blue-100 text-blue-800 rounded text-sm">Strategy</span>
                  <span class="px-3 py-1 bg-green-100 text-green-800 rounded text-sm">Growth</span>
                  <span class="px-3 py-1 bg-purple-100 text-purple-800 rounded text-sm">Leadership</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_technical_expert_layout(assigns) do
    ~H"""
    <div class="technical-expert-layout bg-gray-900 text-white">
      <!-- Terminal-Style Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-gray-900 to-gray-800">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl">
            <div class="font-mono text-green-400 mb-4">~/$ whoami</div>
            <h1 class="text-5xl font-bold mb-6"><%= @portfolio.title %></h1>
            <div class="font-mono text-green-400 mb-4">~/$ cat about.txt</div>
            <p class="text-xl text-gray-300 mb-8"><%= @portfolio.description %></p>
            <div class="font-mono text-green-400 mb-6">~/$ ls services/</div>
            <div class="flex gap-4">
              <button class="px-6 py-3 bg-green-600 text-white rounded font-semibold hover:bg-green-700 transition-colors">
                ./hire_me.sh
              </button>
              <button class="px-6 py-3 border border-green-600 text-green-400 rounded font-semibold hover:bg-green-600 hover:text-white transition-colors">
                cat portfolio.md
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Skills Matrix -->
      <section class="skills-section py-16 bg-gray-800">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold mb-12 text-center">Technical Expertise</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <%= for section <- filter_sections_by_type(@sections, ["skills", "experience"]) do %>
              <div class="skill-card bg-gray-700 p-6 rounded-lg border border-gray-600">
                <h3 class="text-lg font-semibold mb-4 text-green-400"><%= section.title %></h3>
                <div class="space-y-2">
                  <div class="flex justify-between text-sm">
                    <span>Proficiency</span>
                    <span>90%</span>
                  </div>
                  <div class="w-full bg-gray-600 rounded-full h-2">
                    <div class="bg-green-500 h-2 rounded-full w-[90%]"></div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <!-- Project Deep Dive -->
      <section class="projects-section py-16 bg-gray-900">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold mb-12 text-center">Featured Projects</h2>
          <div class="space-y-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "featured_project"]) do %>
              <div class="project-card bg-gray-800 p-8 rounded-xl border border-gray-700">
                <h3 class="text-2xl font-bold mb-4 text-green-400"><%= section.title %></h3>
                <p class="text-gray-300 mb-6"><%= get_section_excerpt(section) %></p>
                <div class="flex flex-wrap gap-2 mb-6">
                  <span class="px-3 py-1 bg-green-600 text-white rounded text-sm">React</span>
                  <span class="px-3 py-1 bg-blue-600 text-white rounded text-sm">Node.js</span>
                  <span class="px-3 py-1 bg-purple-600 text-white rounded text-sm">PostgreSQL</span>
                </div>
                <div class="flex gap-4">
                  <button class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors">
                    View Code
                  </button>
                  <button class="px-4 py-2 border border-green-600 text-green-400 rounded hover:bg-green-600 hover:text-white transition-colors">
                    Live Demo
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Add to show.ex mount function
  defp determine_portfolio_layout_type(portfolio) do
    customization = portfolio.customization || %{}

    # Check for dynamic card layout
    layout_style = Map.get(customization, "layout") || portfolio.theme

    dynamic_layouts = [
      "professional_service_provider",
      "creative_portfolio_showcase",
      "technical_expert_dashboard",
      "content_creator_hub",
      "corporate_executive_profile"
    ]

    if layout_style in dynamic_layouts do
      {:dynamic_card, layout_style}
    else
      {:traditional, "default"}
    end
  end

  defp render_portfolio_layout(assigns) do
    # Use the customization layout setting
    layout = assigns.portfolio_layout

    case layout do
      "dashboard" -> render_dashboard_layout(assigns)
      "gallery" -> render_gallery_layout(assigns)
      "minimal" -> render_minimal_layout(assigns)
      _ -> render_minimal_layout(assigns)  # fallback
    end
  end

  defp get_dynamic_layout_config(portfolio, layout_style) do
    customization = portfolio.customization || %{}

    %{
      layout_style: layout_style,
      primary_color: Map.get(customization, "primary_color") || "#3b82f6",
      secondary_color: Map.get(customization, "secondary_color") || "#64748b",
      accent_color: Map.get(customization, "accent_color") || "#f59e0b",
      grid_density: Map.get(customization, "grid_density") || "normal"
    }
  end

  defp get_brand_colors(portfolio) do
    customization = portfolio.customization || %{}

    %{
      primary: Map.get(customization, "primary_color") || "#3b82f6",
      secondary: Map.get(customization, "secondary_color") || "#64748b",
      accent: Map.get(customization, "accent_color") || "#f59e0b"
    }
  end

  defp filter_sections_by_type(sections, types) do
    Enum.filter(sections, fn section ->
      section_type = to_string(section.section_type)
      section_type in types and section.visible
    end)
  end

  defp get_section_excerpt(section) do
    content = section.content || %{}

    # Try to get main content or description
    main_content = Map.get(content, "main_content") ||
                  Map.get(content, "description") ||
                  Map.get(content, "summary") ||
                  ""

    # Truncate to reasonable length
    if String.length(main_content) > 150 do
      String.slice(main_content, 0, 147) <> "..."
    else
      main_content
    end
  end

  defp render_traditional_sections(assigns) do
    ~H"""
    <!-- Your existing traditional section rendering -->
    <div class="traditional-portfolio">
      <%= for section <- @sections do %>
        <%= if section.visible do %>
          <section class="mb-8">
            <h2 class="text-2xl font-bold mb-4"><%= section.title %></h2>
            <div class="prose max-w-none">
              <%= get_section_excerpt(section) %>
            </div>
          </section>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_dynamic_card_layout(assigns, layout_style) do
    # Get layout configuration
    layout_config = get_dynamic_layout_config(assigns.portfolio, layout_style)

    assigns = assigns
    |> assign(:layout_style, layout_style)
    |> assign(:layout_config, layout_config)
    |> assign(:brand_colors, get_brand_colors(assigns.portfolio))

    case layout_style do
      "professional_service_provider" ->
        render_service_provider_layout(assigns)

      "creative_portfolio_showcase" ->
        render_creative_showcase_layout(assigns)

      "technical_expert_dashboard" ->
        render_technical_expert_layout(assigns)

      "content_creator_hub" ->
        render_content_creator_layout(assigns)

      "corporate_executive_profile" ->
        render_corporate_executive_layout(assigns)

      _ ->
        render_service_provider_layout(assigns)  # Default fallback
    end
  end

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

  defp generate_portfolio_css(customization) do
    primary_color = customization["primary_color"] || "#374151"
    secondary_color = customization["secondary_color"] || "#6b7280"
    accent_color = customization["accent_color"] || "#059669"
    background_color = customization["background_color"] || "#ffffff"
    text_color = customization["text_color"] || "#1f2937"

    """
    :root {
      --primary-color: #{primary_color} !important;
      --secondary-color: #{secondary_color} !important;
      --accent-color: #{accent_color} !important;
      --background-color: #{background_color} !important;
      --text-color: #{text_color} !important;
    }

    body {
      background-color: var(--background-color) !important;
      color: var(--text-color) !important;
    }

    .primary { color: var(--primary-color) !important; }
    .secondary { color: var(--secondary-color) !important; }
    .accent { color: var(--accent-color) !important; }

    .bg-primary { background-color: var(--primary-color) !important; }
    .bg-secondary { background-color: var(--secondary-color) !important; }
    .bg-accent { background-color: var(--accent-color) !important; }

    /* Force portfolio header to use custom colors */
    .bg-white:first-of-type { background-color: var(--primary-color) !important; }
    .text-gray-900 { color: var(--accent-color) !important; }
    """
  end

  # Layout rendering functions
  defp render_portfolio_layout(assigns) do
    # Use the customization layout setting
    layout = assigns[:portfolio_layout] || "minimal"

    case layout do
      "dashboard" -> render_dashboard_layout(assigns)
      "gallery" -> render_gallery_layout(assigns)
      "minimal" -> render_minimal_layout(assigns)
      _ -> render_minimal_layout(assigns)  # fallback
    end
  end

  defp render_section_content_safe(section) do
    try do
      content = section.content || %{}

      # Simple content extraction
      description = get_simple_value(content, ["description", "summary", "content", "text", "main_content"])

      if description != "" do
        Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(description)}</p>")
      else
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Section content...</p>")
      end
    rescue
      _ ->
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Loading content...</p>")
    end
  end

  # Safe value extraction function
  defp get_simple_value(content, keys) when is_list(keys) do
    Enum.find_value(keys, "", fn key ->
      case Map.get(content, key) do
        nil -> nil
        "" -> nil
        {:safe, safe_content} when is_binary(safe_content) ->
          String.trim(safe_content)
        {:safe, safe_content} when is_list(safe_content) ->
          safe_content |> Enum.join("") |> String.trim()
        {:safe, safe_content} ->
          "#{safe_content}" |> String.trim()
        value when is_binary(value) ->
          String.trim(value)
        value ->
          "#{value}" |> String.trim()
      end
      |> case do
        "" -> nil
        result -> result
      end
    end)
  end

  defp render_dashboard_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Dashboard Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <h1 class="text-3xl font-bold text-gray-900"><%= @portfolio.title %></h1>
          <p class="text-gray-600 mt-1"><%= @portfolio.description %></p>
        </div>
      </header>

      <!-- Dashboard Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
            <%= for section <- @sections do %>
              <section class="bg-white rounded-xl shadow-sm border p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-4"><%= section.title %></h2>
                <div class="prose max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>
          <div class="space-y-6">
            <div class="bg-white rounded-xl shadow-sm border p-6">
              <h3 class="font-semibold text-gray-900 mb-4">Info</h3>
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Sections:</span>
                  <span class="font-medium"><%= length(@sections) %></span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_gallery_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Gallery Header -->
      <header class="py-16 px-6 text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <p class="text-xl text-gray-600"><%= @portfolio.description %></p>
      </header>

      <!-- Gallery Content -->
      <main class="px-6 py-8">
        <div class="max-w-6xl mx-auto">
          <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
            <%= for section <- @sections do %>
              <section class="break-inside-avoid bg-gray-50 rounded-lg p-6 mb-8">
                <h2 class="text-lg font-semibold text-gray-900 mb-3"><%= section.title %></h2>
                <div class="text-gray-700">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_minimal_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Minimal Header -->
      <header class="py-16 px-6 text-center border-b">
        <h1 class="text-4xl lg:text-6xl font-light text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <p class="text-xl text-gray-600 max-w-2xl mx-auto"><%= @portfolio.description %></p>
      </header>

      <!-- Minimal Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <div class="space-y-16">
          <%= for section <- @sections do %>
            <section class="border-b border-gray-100 pb-16 last:border-b-0">
              <h2 class="text-2xl font-light text-gray-900 mb-8"><%= section.title %></h2>
              <div class="prose prose-lg max-w-none text-gray-700">
                <%= render_section_content_safe(section) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end
end
