# lib/frestyl_web/live/portfolio_live/view.ex - UPDATED with customization support

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates

  # FIXED: Handle both public portfolio view and share token view
  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    # Check if this is a share token (longer, alphanumeric) or portfolio slug
    if String.length(slug) > 20 do
      # This looks like a share token
      mount_share_view(slug, socket)
    else
      # This is a portfolio slug
      mount_public_view(slug, socket)
    end
  end

  # Handle share token view (collaboration links)
  @impl true
  def mount(%{"token" => token}, _session, socket) do
    mount_share_view(token, socket)
  end

  # Mount public portfolio view
  defp mount_public_view(slug, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket
         |> put_flash(:error, "Portfolio not found")
         |> redirect(to: "/")}

      {:ok, portfolio} ->
        # Check if portfolio is publicly accessible
        if portfolio_accessible?(portfolio) do
          # Track visit
          track_portfolio_visit(portfolio, socket)

          # 🔥 NEW: Process customization data
          {template_config, customization_css} = process_portfolio_customization(portfolio)

          socket =
            socket
            |> assign(:page_title, portfolio.title)
            |> assign(:portfolio, portfolio)
            |> assign(:owner, portfolio.user)
            |> assign(:sections, Map.get(portfolio, :portfolio_sections, []))
            |> assign(:template_config, template_config)
            |> assign(:template_theme, normalize_theme(portfolio.theme))
            |> assign(:customization_css, customization_css)  # 🔥 NEW
            |> assign(:intro_video, get_intro_video(portfolio))
            |> assign(:share, nil)
            |> assign(:is_shared_view, false)
            |> assign(:show_stats, false)
            |> assign(:portfolio_stats, %{})
            |> assign(:collaboration_enabled, false)
            |> assign(:feedback_panel_open, false)

          {:ok, socket}
        else
          {:ok, socket
           |> put_flash(:error, "This portfolio is private")
           |> redirect(to: "/")}
        end
    end
  end

  # Mount share token view (for collaboration)
  defp mount_share_view(token, socket) do
    case Portfolios.get_portfolio_by_share_token_simple(token) do
      {:error, :not_found} ->
        {:ok, socket
         |> put_flash(:error, "Portfolio link not found or expired")
         |> redirect(to: "/")}

      {:ok, portfolio, share} ->
        # Track share visit
        Portfolios.increment_share_view_count(token)
        track_share_visit(portfolio, share, socket)

        # Check if this is a collaboration request
        collaboration_mode = get_connect_params(socket)["collaboration"] == "true"

        # 🔥 NEW: Process customization data
        {template_config, customization_css} = process_portfolio_customization(portfolio)

        socket =
          socket
          |> assign(:page_title, "#{portfolio.title} - Shared")
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, portfolio.sections || [])
          |> assign(:template_config, template_config)
          |> assign(:template_theme, normalize_theme(portfolio.theme))
          |> assign(:customization_css, customization_css)  # 🔥 NEW
          |> assign(:intro_video, get_intro_video(portfolio))
          |> assign(:share, %{"name" => share.name || "shared user", "token" => token, "id" => share.id})
          |> assign(:is_shared_view, true)
          |> assign(:collaboration_enabled, collaboration_mode)
          |> assign(:feedback_panel_open, collaboration_mode)
          |> assign(:show_stats, false)
          |> assign(:portfolio_stats, %{})

        {:ok, socket}
    end
  end

  # 🔥 NEW: Process portfolio customization data
  defp process_portfolio_customization(portfolio) do
    # Get base template config
    base_template_config = PortfolioTemplates.get_template_config(portfolio.theme || "executive")

    # Get user customization (this is where the saved data is!)
    user_customization = portfolio.customization || %{}

    # Merge user customization with template defaults
    merged_config = deep_merge(base_template_config, user_customization)

    # Generate CSS variables from the merged config
    css_variables = generate_css_variables(merged_config)

    {merged_config, css_variables}
  end

  # 🔥 NEW: Generate CSS variables from customization
  defp generate_css_variables(config) do
    primary_color = get_config_value(config, "primary_color") || config[:primary_color] || "#3b82f6"
    secondary_color = get_config_value(config, "secondary_color") || config[:secondary_color] || "#64748b"
    accent_color = get_config_value(config, "accent_color") || config[:accent_color] || "#f59e0b"

    # Handle typography
    typography = get_config_value(config, "typography") || config[:typography] || %{}
    font_family = get_config_value(typography, "font_family") || typography[:font_family] || "Inter"
    font_size = get_config_value(typography, "font_size") || typography[:font_size] || "base"

    # Handle background
    background = get_config_value(config, "background") || config[:background] || "white-clean"
    spacing = get_config_value(config, "spacing") || config[:spacing] || "normal"

    """
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{get_font_family_css(font_family)};
      --portfolio-font-size: #{get_font_size_css(font_size)};
      --portfolio-spacing: #{get_spacing_css(spacing)};
      #{get_background_css_vars(background)}
    }

    /* Apply CSS variables to elements */
    body {
      font-family: var(--portfolio-font-family);
      font-size: var(--portfolio-font-size);
      background: var(--portfolio-bg);
      color: var(--portfolio-text);
    }

    .portfolio-primary { color: var(--portfolio-primary-color); }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color); }
    .portfolio-border-primary { border-color: var(--portfolio-primary-color); }

    .portfolio-secondary { color: var(--portfolio-secondary-color); }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color); }

    .portfolio-accent { color: var(--portfolio-accent-color); }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color); }

    .portfolio-card {
      background: var(--portfolio-card-bg);
      padding: var(--portfolio-spacing);
      margin-bottom: var(--portfolio-spacing);
    }

    .portfolio-header {
      background: var(--portfolio-header-bg);
      color: var(--portfolio-header-text);
    }
    """
  end

  # Helper to get config values (handles both string and atom keys)
  defp get_config_value(config, key) when is_map(config) do
    config[key] || config[String.to_atom(key)]
  end
  defp get_config_value(_, _), do: nil

  # Deep merge two maps (user customization overrides template defaults)
  defp deep_merge(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge(v1, v2)
      else
        v2
      end
    end)
  end
  defp deep_merge(_left, right), do: right

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

  defp get_font_size_css(font_size) do
    case font_size do
      "small" -> "14px"
      "base" -> "16px"
      "large" -> "18px"
      "xl" -> "20px"
      _ -> "16px"
    end
  end

  defp get_spacing_css(spacing) do
    case spacing do
      "compact" -> "0.75rem"
      "normal" -> "1rem"
      "spacious" -> "1.5rem"
      "extra-spacious" -> "2rem"
      _ -> "1rem"
    end
  end

  defp get_background_css_vars(background) do
    case background do
      "gradient-ocean" ->
        """
        --portfolio-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        --portfolio-text: #ffffff;
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        --portfolio-header-bg: rgba(0, 0, 0, 0.3);
        --portfolio-header-text: #ffffff;
        """
      "gradient-sunset" ->
        """
        --portfolio-bg: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        --portfolio-text: #ffffff;
        --portfolio-card-bg: rgba(255, 255, 255, 0.15);
        --portfolio-header-bg: rgba(0, 0, 0, 0.2);
        --portfolio-header-text: #ffffff;
        """
      "gradient-forest" ->
        """
        --portfolio-bg: linear-gradient(135deg, #4ecdc4 0%, #44a08d 100%);
        --portfolio-text: #ffffff;
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        --portfolio-header-bg: rgba(0, 0, 0, 0.3);
        --portfolio-header-text: #ffffff;
        """
      "dark-mode" ->
        """
        --portfolio-bg: #1a1a1a;
        --portfolio-text: #ffffff;
        --portfolio-card-bg: #2a2a2a;
        --portfolio-header-bg: #000000;
        --portfolio-header-text: #ffffff;
        """
      "terminal-dark" ->
        """
        --portfolio-bg: #0f172a;
        --portfolio-text: #22c55e;
        --portfolio-card-bg: #1e293b;
        --portfolio-header-bg: #000000;
        --portfolio-header-text: #22c55e;
        """
      _ ->
        """
        --portfolio-bg: #ffffff;
        --portfolio-text: #1f2937;
        --portfolio-card-bg: #ffffff;
        --portfolio-header-bg: #f9fafb;
        --portfolio-header-text: #1f2937;
        """
    end
  end

  # Check if portfolio is accessible to public
  defp portfolio_accessible?(portfolio) do
    case portfolio.visibility do
      :public -> true
      :link_only -> true  # Link-only portfolios are accessible via direct URL
      :private -> false
    end
  end

  # EVENT HANDLERS
  @impl true
  def handle_event("toggle_stats", _params, socket) do
    new_show_stats = !socket.assigns.show_stats
    {:noreply, assign(socket, :show_stats, new_show_stats)}
  end

  @impl true
  def handle_event("toggle_feedback_panel", _params, socket) do
    new_state = !socket.assigns.feedback_panel_open
    {:noreply, assign(socket, :feedback_panel_open, new_state)}
  end

  @impl true
  def handle_event("submit_feedback", %{"feedback" => feedback_content, "section_id" => section_id}, socket) do
    if socket.assigns.is_shared_view and socket.assigns.collaboration_enabled do
      attrs = %{
        content: feedback_content,
        feedback_type: :comment,
        portfolio_id: socket.assigns.portfolio.id,
        section_id: section_id,
        share_id: get_share_id(socket),
        section_reference: "section-#{section_id}"
      }

      case Portfolios.create_feedback(attrs) do
        {:ok, _feedback} ->
          {:noreply,
           socket
           |> put_flash(:info, "Feedback submitted successfully!")
           |> push_event("feedback_submitted", %{})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to submit feedback. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Feedback is only available for collaboration sessions.")}
    end
  end

  @impl true
  def handle_event("quick_highlight", %{"text" => highlighted_text, "section_id" => section_id}, socket) do
    if socket.assigns.collaboration_enabled do
      attrs = %{
        content: highlighted_text,
        feedback_type: :highlight,
        portfolio_id: socket.assigns.portfolio.id,
        section_id: section_id,
        share_id: get_share_id(socket),
        metadata: %{
          highlighted_text: highlighted_text,
          timestamp: DateTime.utc_now()
        }
      }

      case Portfolios.create_feedback(attrs) do
        {:ok, _feedback} ->
          {:noreply, put_flash(socket, :info, "Text highlighted and saved!")}
        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to save highlight.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- 🔥 INJECT CUSTOMIZATION CSS -->
    <style>
      <%= Phoenix.HTML.raw(@customization_css) %>
    </style>

    <div class="min-h-screen portfolio-bg">
      <!-- Portfolio Header -->
      <header class="portfolio-header relative overflow-hidden">
        <!-- Background Pattern -->
        <div class="absolute inset-0 opacity-5">
          <div class="absolute inset-0" style="background-image: radial-gradient(circle at 1px 1px, currentColor 1px, transparent 0); background-size: 20px 20px;"></div>
        </div>

        <div class="relative max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-12 lg:py-16">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <!-- Profile Information -->
            <div class="space-y-6">
              <div class="flex items-center space-x-4">
                <div class="w-20 h-20 portfolio-bg-primary rounded-full shadow-lg flex items-center justify-center">
                  <span class="text-2xl font-bold text-white">
                    <%= String.first(@owner.name || @owner.username || "U") %>
                  </span>
                </div>

                <div>
                  <h1 class="text-3xl lg:text-4xl font-bold portfolio-primary">
                    <%= @owner.name || @owner.username %>
                  </h1>

                  <%= if @owner.bio do %>
                    <p class="text-lg mt-1 opacity-90">
                      <%= @owner.bio %>
                    </p>
                  <% end %>
                </div>
              </div>

              <p class="text-lg leading-relaxed opacity-80">
                <%= @portfolio.description || "Welcome to my professional portfolio. Explore my work, experience, and achievements." %>
              </p>

              <!-- Share Attribution -->
              <%= if @is_shared_view and @share do %>
                <div class="portfolio-card rounded-lg p-4 border portfolio-border-primary">
                  <p class="text-sm opacity-80">
                    <span class="font-medium">Shared by:</span> <%= @share["name"] %>
                  </p>
                </div>
              <% end %>
            </div>

            <!-- Intro Video or Visual -->
            <div class="lg:justify-self-end">
              <%= if @intro_video do %>
                <div class="relative rounded-2xl overflow-hidden shadow-2xl aspect-video bg-black">
                  <video controls class="w-full h-full object-cover">
                    <source src={get_media_url(@intro_video)} type="video/mp4" />
                  </video>

                  <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-4">
                    <p class="text-white text-sm font-medium">
                      👋 Personal Introduction
                    </p>
                  </div>
                </div>
              <% else %>
                <div class="w-full aspect-square rounded-2xl shadow-2xl flex items-center justify-center portfolio-bg-secondary">
                  <div class="text-center">
                    <div class="w-24 h-24 mx-auto mb-4 portfolio-bg-accent rounded-full flex items-center justify-center opacity-20">
                      <svg class="w-12 h-12 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                    <h3 class="text-white text-lg font-semibold mb-2">Professional Portfolio</h3>
                    <p class="text-white/80 text-sm">Showcasing expertise and achievements</p>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content Area -->
      <main class="py-8" style={"padding: var(--portfolio-spacing)"}>
        <div class={get_template_layout_class(@template_theme)}>
          <!-- Portfolio Sections -->
          <%= for section <- @sections do %>
            <div class={[
              "portfolio-card rounded-xl shadow-lg border portfolio-border-primary hover:shadow-xl transition-shadow duration-300 mb-6",
              if(@collaboration_enabled, do: "hover:ring-2 hover:ring-blue-200", else: "")
            ]} id={"section-#{section.id}"}>
              <h2 class="text-2xl font-bold portfolio-primary mb-4"><%= section.title %></h2>

              <!-- Render section content based on type -->
              <%= render_section_content(section, assigns) %>

              <!-- Collaboration feedback button -->
              <%= if @collaboration_enabled do %>
                <div class="mt-4 pt-4 border-t portfolio-border-primary">
                  <button phx-click="submit_feedback"
                          phx-value-section_id={section.id}
                          phx-value-feedback="Quick feedback on this section"
                          class="text-sm portfolio-accent hover:opacity-80 font-medium">
                    💬 Add Feedback
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>

          <!-- Empty State -->
          <%= if Enum.empty?(@sections) do %>
            <div class="text-center py-16">
              <div class="mx-auto w-24 h-24 portfolio-card rounded-full flex items-center justify-center mb-6">
                <svg class="w-12 h-12 portfolio-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
                </svg>
              </div>
              <h3 class="text-xl font-semibold portfolio-primary mb-2">Portfolio Coming Soon</h3>
              <p class="portfolio-secondary max-w-md mx-auto">
                <%= @owner.name || @owner.username %> is currently building their portfolio.
                Check back soon to see their professional journey!
              </p>
            </div>
          <% end %>
        </div>
      </main>

      <!-- Feedback Panel Toggle (for collaboration) -->
      <%= if @collaboration_enabled do %>
        <div class="fixed bottom-6 left-6 z-40">
          <button phx-click="toggle_feedback_panel"
                  class={[
                    "portfolio-bg-primary text-white shadow-lg rounded-full p-4 hover:opacity-90 transition-all duration-200",
                    @feedback_panel_open && "opacity-90"
                  ]}>
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
          </button>
        </div>
      <% end %>
    </div>
    """
  end

  # Rest of your existing helper functions remain the same...
  # (render_section_content, normalize_theme, get_template_*, track_*, etc.)

  # [Include all your existing helper functions here - they remain unchanged]

  # Render section content based on section type
  defp render_section_content(%{section_type: :intro} = section, assigns) do
    headline = get_in(section.content, ["headline"]) || ""
    summary = get_in(section.content, ["summary"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = assign(assigns, headline: headline, summary: summary, location: location)

    ~H"""
    <%= if String.length(@headline) > 0 do %>
      <h3 class="text-xl font-semibold portfolio-primary mb-3"><%= @headline %></h3>
    <% end %>
    <%= if String.length(@summary) > 0 do %>
      <p class="portfolio-secondary leading-relaxed mb-3"><%= @summary %></p>
    <% end %>
    <%= if String.length(@location) > 0 do %>
      <p class="text-sm portfolio-secondary flex items-center">
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
        </svg>
        <%= @location %>
      </p>
    <% end %>
    """
  end

  defp render_section_content(%{section_type: :contact} = section, assigns) do
    email = get_in(section.content, ["email"]) || ""
    phone = get_in(section.content, ["phone"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = assign(assigns, email: email, phone: phone, location: location)

    ~H"""
    <div class="space-y-3">
      <%= if String.length(@email) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 portfolio-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
          </svg>
          <a href={"mailto:#{@email}"} class="portfolio-accent hover:opacity-80"><%= @email %></a>
        </div>
      <% end %>

      <%= if String.length(@phone) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 portfolio-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
          </svg>
          <a href={"tel:#{@phone}"} class="portfolio-accent hover:opacity-80"><%= @phone %></a>
        </div>
      <% end %>

      <%= if String.length(@location) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 portfolio-secondary mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <span class="portfolio-secondary"><%= @location %></span>
        </div>
      <% end %>
    </div>
    """
  end

  # Generic section content renderer
  defp render_section_content(section, _assigns) do
    content = case section.content do
      %{"summary" => summary} -> summary
      %{"description" => desc} -> desc
      %{"content" => content} -> content
      _ -> "Content coming soon..."
    end

    assigns = %{content: content, section_type: section.section_type}

    ~H"""
    <div class="prose max-w-none">
      <%= if String.length(@content) > 0 do %>
        <p class="portfolio-secondary leading-relaxed"><%= @content %></p>
      <% else %>
        <p class="portfolio-secondary opacity-60 italic">
          This <%= format_section_type(@section_type) %> section is being developed.
        </p>
      <% end %>
    </div>
    """
  end

  # HELPER FUNCTIONS
  defp normalize_theme(theme) when is_binary(theme) do
    case theme do
      "executive" -> :executive
      "developer" -> :developer
      "designer" -> :designer
      "consultant" -> :consultant
      "academic" -> :academic
      _ -> :executive
    end
  end
  defp normalize_theme(theme) when is_atom(theme), do: theme
  defp normalize_theme(_), do: :executive

  defp get_template_layout_class(template_theme) do
    case template_theme do
      :executive -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :developer -> "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8"
      :designer -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :consultant -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
      :academic -> "max-w-4xl mx-auto px-4 sm:px-6 lg:px-8"
      _ -> "max-w-6xl mx-auto px-4 sm:px-6 lg:px-8"
    end
  end

  defp track_portfolio_visit(portfolio, socket) do
    try do
      ip_address = get_connect_info(socket, :peer_data) |> Map.get(:address, {127, 0, 0, 1}) |> :inet.ntoa() |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      Portfolios.create_visit(%{
        portfolio_id: portfolio.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
      })
    rescue
      _ -> :ok
    end
  end

  defp track_share_visit(portfolio, share, socket) do
    try do
      ip_address = get_connect_info(socket, :peer_data) |> Map.get(:address, {127, 0, 0, 1}) |> :inet.ntoa() |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      Portfolios.create_visit(%{
        portfolio_id: portfolio.id,
        share_id: share.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
      })
    rescue
      _ -> :ok
    end
  end

  defp get_intro_video(portfolio) do
    case Map.get(portfolio, :intro_video_id) do
      nil -> nil
      video_id -> Portfolios.get_media!(video_id)
    end
  rescue
    _ -> nil
  end

  defp get_share_id(socket) do
    case socket.assigns.share do
      %{"id" => id} -> id
      _ -> nil
    end
  end

  defp get_media_url(media) do
    Portfolios.get_media_url(media)
  end

  defp format_section_type(section_type) do
    case section_type do
      :intro -> "Introduction"
      :experience -> "Work Experience"
      :education -> "Education"
      :skills -> "Skills & Expertise"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :media_showcase -> "Media Showcase"
      :testimonial -> "Testimonials"
      :contact -> "Contact Information"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end
end
