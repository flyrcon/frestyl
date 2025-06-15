# lib/frestyl_web/live/portfolio_live/view.ex - UPDATED with customization support

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Repo
  import Ecto.Query

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
  def mount(%{"token" => token} = params, _session, socket) do
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
        IO.puts("🔥 MOUNTING PORTFOLIO VIEW")
        IO.puts("🔥 Portfolio theme: #{portfolio.theme}")
        IO.puts("🔥 Portfolio customization: #{inspect(portfolio.customization)}")

        # Force preload user if not loaded
        portfolio = if Ecto.assoc_loaded?(portfolio.user) do
          portfolio
        else
          Repo.preload(portfolio, :user, force: true)
        end

        # Check if portfolio is publicly accessible
        if portfolio_accessible?(portfolio) do
          # Track visit
          track_portfolio_visit(portfolio, socket)

          # 🔥 NEW: Process customization data with WORKING template system
          {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

          IO.puts("🔥 Generated CSS length: #{String.length(customization_css)}")
          IO.puts("🔥 Template layout: #{template_layout}")

          socket =
            socket
            |> assign(:page_title, portfolio.title)
            |> assign(:portfolio, portfolio)
            |> assign(:owner, portfolio.user)
            |> assign(:sections, Map.get(portfolio, :portfolio_sections, []))
            |> assign(:template_config, template_config)
            |> assign(:template_theme, normalize_theme(portfolio.theme))
            |> assign(:template_layout, template_layout)  # 🔥 NEW
            |> assign(:customization_css, customization_css)
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
        {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

        socket =
          socket
          |> assign(:page_title, "#{portfolio.title} - Shared")
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, portfolio.sections || [])
          |> assign(:template_config, template_config)
          |> assign(:template_theme, normalize_theme(portfolio.theme))
          |> assign(:template_layout, template_layout)  # 🔥 NEW
          |> assign(:customization_css, customization_css)
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

  defp process_portfolio_customization_fixed(portfolio) do
    IO.puts("🔥 PROCESSING PORTFOLIO CUSTOMIZATION")
    IO.puts("🔥 Portfolio theme: #{portfolio.theme}")
    IO.inspect(portfolio.customization, label: "🔥 Raw customization")

    # Get base template config from the template system
    theme = portfolio.theme || "executive"
    base_template_config = PortfolioTemplates.get_template_config(theme)

    IO.puts("🔥 Base template config loaded for theme: #{theme}")

    # Get user customization from database (this overrides template defaults)
    user_customization = portfolio.customization || %{}

    # 🔥 DEEP MERGE: User customization overrides template defaults
    merged_config = deep_merge_maps(base_template_config, user_customization)

    IO.puts("🔥 Merged config created")

    # 🔥 DETERMINE LAYOUT: Get layout from merged config
    template_layout = get_template_layout(merged_config, theme)

    IO.puts("🔥 Template layout determined: #{template_layout}")

    # 🔥 GENERATE CSS: Create CSS variables from merged config
    css_variables = generate_portfolio_css_variables(merged_config, theme)

    IO.puts("🔥 CSS variables generated: #{String.length(css_variables)} characters")

    {merged_config, css_variables, template_layout}
  end

  # 🔥 DEEP MERGE HELPER: Properly merge nested maps
  defp deep_merge_maps(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge_maps(v1, v2)
      else
        v2  # User customization takes precedence
      end
    end)
  end
  defp deep_merge_maps(_left, right), do: right

  # 🔥 GET LAYOUT: Determine which layout to use
  defp get_template_layout(config, theme) do
    # Priority: 1) User-selected layout, 2) Template default layout, 3) Theme-based layout
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      %{"layout" => layout} when is_atom(layout) -> to_string(layout)
      %{:layout => layout} when is_atom(layout) -> to_string(layout)
      _ ->
        # Fallback to theme-based layout
        case theme do
          "executive" -> "dashboard"
          "developer" -> "terminal"
          "designer" -> "gallery"
          "consultant" -> "case_study"
          "academic" -> "academic"
          "creative" -> "gallery"
          "minimalist" -> "minimal"
          _ -> "dashboard"
        end
    end
  end

  # 🔥 GENERATE CSS: Create comprehensive CSS variables for templates
  defp generate_portfolio_css_variables(config, theme) do
    # Extract colors with proper fallbacks
    primary_color = get_config_value(config, "primary_color") || get_config_value(config, :primary_color) || "#3b82f6"
    secondary_color = get_config_value(config, "secondary_color") || get_config_value(config, :secondary_color) || "#64748b"
    accent_color = get_config_value(config, "accent_color") || get_config_value(config, :accent_color) || "#f59e0b"

    # Extract typography
    typography = get_config_value(config, "typography") || get_config_value(config, :typography) || %{}
    font_family = get_config_value(typography, "font_family") || get_config_value(typography, :font_family) || "Inter"

    # Extract background
    background = get_config_value(config, "background") || get_config_value(config, :background) || "default"

    IO.puts("🔥 CSS Generation Values:")
    IO.puts("  Primary: #{primary_color}")
    IO.puts("  Secondary: #{secondary_color}")
    IO.puts("  Accent: #{accent_color}")
    IO.puts("  Font: #{font_family}")
    IO.puts("  Background: #{background}")

    """
    <style>
    /* 🔥 PORTFOLIO CSS VARIABLES */
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{get_font_family_css(font_family)};
      #{get_background_css_vars(background)}
    }

    /* 🔥 APPLY VARIABLES TO ELEMENTS */
    body, html {
      font-family: var(--portfolio-font-family) !important;
      color: var(--portfolio-text-color) !important;
      background: var(--portfolio-bg) !important;
      margin: 0 !important;
      padding: 0 !important;
    }

    /* 🔥 COLOR CLASSES */
    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

    /* 🔥 TEMPLATE-SPECIFIC OVERRIDES */
    .bg-white { background-color: var(--portfolio-card-bg) !important; }
    .text-gray-900 { color: var(--portfolio-text-color) !important; }
    .text-gray-600 { color: var(--portfolio-secondary-text) !important; }
    .bg-blue-600, .bg-slate-900 { background-color: var(--portfolio-primary-color) !important; }
    .text-blue-600 { color: var(--portfolio-primary-color) !important; }

    /* 🔥 LAYOUT-SPECIFIC STYLES */
    #{get_layout_specific_css(theme, background)}
    </style>
    """
  end

  # 🔥 BACKGROUND CSS VARIABLES
  defp get_background_css_vars(background) do
    case background do
      "gradient-ocean" ->
        """
        --portfolio-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: rgba(255, 255, 255, 0.8);
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        --portfolio-header-bg: rgba(0, 0, 0, 0.3);
        """
      "gradient-sunset" ->
        """
        --portfolio-bg: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: rgba(255, 255, 255, 0.8);
        --portfolio-card-bg: rgba(255, 255, 255, 0.15);
        --portfolio-header-bg: rgba(0, 0, 0, 0.2);
        """
      "gradient-forest" ->
        """
        --portfolio-bg: linear-gradient(135deg, #4ecdc4 0%, #44a08d 100%);
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: rgba(255, 255, 255, 0.8);
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        --portfolio-header-bg: rgba(0, 0, 0, 0.3);
        """
      "dark-mode" ->
        """
        --portfolio-bg: #1a1a1a;
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: #cccccc;
        --portfolio-card-bg: #2a2a2a;
        --portfolio-header-bg: #000000;
        """
      "terminal-dark" ->
        """
        --portfolio-bg: #0f172a;
        --portfolio-text-color: #22c55e;
        --portfolio-secondary-text: #64748b;
        --portfolio-card-bg: #1e293b;
        --portfolio-header-bg: #000000;
        """
      _ ->
        """
        --portfolio-bg: #ffffff;
        --portfolio-text-color: #1f2937;
        --portfolio-secondary-text: #6b7280;
        --portfolio-card-bg: #ffffff;
        --portfolio-header-bg: #f9fafb;
        """
    end
  end

  defp get_background_body_css(background) do
    case background do
      "gradient-ocean" -> "background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;"
      "gradient-sunset" -> "background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important;"
      "gradient-forest" -> "background: linear-gradient(135deg, #4ecdc4 0%, #44a08d 100%) !important;"
      "dark-mode" -> "background: #1a1a1a !important;"
      "terminal-dark" -> "background: #0f172a !important;"
      _ -> "background: var(--portfolio-bg, var(--portfolio-background-color, #ffffff)) !important;"
    end
  end

  # Update your existing helper functions if they don't exist:

  defp get_layout_specific_css(layout) do
    case layout do
      "dashboard" ->
        """
        .portfolio-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 1.5rem;
        }
        """
      "minimal" ->
        """
        .portfolio-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
          gap: 2rem;
          max-width: 1200px;
          margin: 0 auto;
        }
        """
      "creative" ->
        """
        .portfolio-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
          gap: 1.5rem;
        }
        """
      _ -> ""
    end
  end

  defp get_card_style_css_vars(card_style) do
    case card_style do
      "modern" ->
        """
        --portfolio-card-border: 1px solid #e5e7eb;
        --portfolio-card-radius: 12px;
        --portfolio-card-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        """
      "minimal" ->
        """
        --portfolio-card-border: 1px solid #f3f4f6;
        --portfolio-card-radius: 8px;
        --portfolio-card-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
        """
      "creative" ->
        """
        --portfolio-card-border: 2px solid var(--portfolio-accent-color);
        --portfolio-card-radius: 16px;
        --portfolio-card-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1);
        """
      _ ->
        """
        --portfolio-card-border: 1px solid #e5e7eb;
        --portfolio-card-radius: 8px;
        --portfolio-card-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
        """
    end
  end

  defp get_card_style_specific_css(card_style) do
    """
    .portfolio-card, .bg-white {
      border: var(--portfolio-card-border) !important;
      border-radius: var(--portfolio-card-radius) !important;
      box-shadow: var(--portfolio-card-shadow) !important;
    }
    """
  end

  # Add these new helper functions
  defp get_layout_css_vars(layout) do
    case layout do
      "dashboard" ->
        """
        --portfolio-layout: dashboard;
        --portfolio-grid-cols: repeat(auto-fit, minmax(300px, 1fr));
        --portfolio-container-max-width: 1280px;
        """
      "single_page" ->
        """
        --portfolio-layout: single-page;
        --portfolio-grid-cols: 1fr;
        --portfolio-container-max-width: 800px;
        """
      "professional" ->
        """
        --portfolio-layout: professional;
        --portfolio-grid-cols: repeat(auto-fit, minmax(350px, 1fr));
        --portfolio-container-max-width: 1200px;
        """
      _ ->
        """
        --portfolio-layout: default;
        --portfolio-grid-cols: repeat(auto-fit, minmax(300px, 1fr));
        --portfolio-container-max-width: 1024px;
        """
    end
  end

  defp get_card_style_css_vars(card_style) do
    case card_style do
      "modern" ->
        """
        --portfolio-card-bg: #ffffff;
        --portfolio-card-border: 1px solid #e5e7eb;
        --portfolio-card-radius: 12px;
        --portfolio-card-shadow: 0 4px 6px -1px rgb(0 0 0 / 0.1);
        """
      "professional" ->
        """
        --portfolio-card-bg: #ffffff;
        --portfolio-card-border: 1px solid #d1d5db;
        --portfolio-card-radius: 8px;
        --portfolio-card-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
        """
      "creative" ->
        """
        --portfolio-card-bg: #ffffff;
        --portfolio-card-border: 2px solid var(--portfolio-accent-color);
        --portfolio-card-radius: 16px;
        --portfolio-card-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1);
        """
      _ ->
        """
        --portfolio-card-bg: #ffffff;
        --portfolio-card-border: 1px solid #e5e7eb;
        --portfolio-card-radius: 8px;
        --portfolio-card-shadow: 0 1px 3px 0 rgb(0 0 0 / 0.1);
        """
    end
  end

  defp get_layout_specific_css(theme, background) do
    base_styles = """
    /* Layout-specific overrides */
    .portfolio-card {
      background: var(--portfolio-card-bg) !important;
      color: var(--portfolio-text-color) !important;
      border-radius: 0.75rem;
      backdrop-filter: blur(10px);
    }

    .portfolio-header {
      background: var(--portfolio-header-bg) !important;
      color: var(--portfolio-text-color) !important;
    }
    """

    case theme do
      "designer" -> base_styles <> """
        .gallery-section {
          background: var(--portfolio-card-bg) !important;
          backdrop-filter: blur(12px) !important;
        }
        .floating-nav {
          background: rgba(255, 255, 255, 0.1) !important;
          backdrop-filter: blur(10px) !important;
        }
      """
      "developer" -> base_styles <> """
        .terminal-window {
          background: var(--portfolio-card-bg) !important;
          border-color: var(--portfolio-primary-color) !important;
        }
        .terminal-content {
          color: var(--portfolio-text-color) !important;
        }
      """
      "executive" -> base_styles <> """
        .metric-card {
          background: var(--portfolio-card-bg) !important;
          color: var(--portfolio-text-color) !important;
        }
        .sidebar {
          background: var(--portfolio-header-bg) !important;
        }
      """
      _ -> base_styles
    end
  end

  defp get_card_style_specific_css(card_style) do
    """
    .portfolio-card, .bg-white {
      background: var(--portfolio-card-bg) !important;
      border: var(--portfolio-card-border) !important;
      border-radius: var(--portfolio-card-radius) !important;
      box-shadow: var(--portfolio-card-shadow) !important;
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

  defp get_background_css_vars(background) do
    case background do
      "gradient-ocean" ->
        """
        --portfolio-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        --portfolio-text: #ffffff;
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        """
      "dark-mode" ->
        """
        --portfolio-bg: #1a1a1a;
        --portfolio-text: #ffffff;
        --portfolio-card-bg: #2a2a2a;
        """
      _ ->
        """
        --portfolio-bg: #ffffff;
        --portfolio-text: #1f2937;
        --portfolio-card-bg: #ffffff;
        """
    end
  end

  # Helper to get config values (handles both string and atom keys)
  defp get_config_value(config, key) when is_map(config) do
    config[key] || config[String.to_atom(key)] || config[to_string(key)]
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
      :link_only -> true
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
  def handle_event("export_resume", _params, socket) do
    portfolio = socket.assigns.portfolio

    # Set loading state
    socket = assign(socket, :exporting_resume, true)

    # Start PDF export in background task
    Task.start(fn ->
      case Frestyl.PdfExport.export_portfolio_with_template(portfolio.slug, :resume) do
        {:ok, export_info} ->
          send(self(), {:resume_export_complete, export_info})
        {:error, reason} ->
          send(self(), {:resume_export_error, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:resume_export_complete, export_info}, socket) do
    socket =
      socket
      |> assign(:exporting_resume, false)
      |> put_flash(:info, "Resume downloaded successfully!")
      |> push_event("download_file", %{
          url: export_info.url,
          filename: export_info.filename
        })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:resume_export_error, reason}, socket) do
    socket =
      socket
      |> assign(:exporting_resume, false)
      |> put_flash(:error, "Export failed: #{reason}")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    # 🔥 ROUTE TO CORRECT LAYOUT BASED ON TEMPLATE
    layout = assigns[:template_layout] || "dashboard"

    IO.puts("🔥 RENDERING LAYOUT: #{layout}")

    case layout do
      "dashboard" -> render_dashboard_layout(assigns)
      "gallery" -> render_gallery_layout(assigns)
      "terminal" -> render_terminal_layout(assigns)
      "case_study" -> render_case_study_layout(assigns)
      "minimal" -> render_minimal_layout(assigns)
      "academic" -> render_academic_layout(assigns)
      _ -> render_dashboard_layout(assigns)  # fallback
    end
  end

    defp render_dashboard_layout(assigns) do
    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <div class="min-h-screen portfolio-bg">
      <!-- Dashboard Header -->
      <header class="portfolio-header border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div class="grid lg:grid-cols-3 gap-8 items-center">
            <div class="lg:col-span-2">
              <h1 class="text-4xl lg:text-5xl font-bold mb-4 portfolio-primary">
                <%= @portfolio.title %>
              </h1>
              <p class="text-xl mb-6 portfolio-secondary">
                <%= @portfolio.description %>
              </p>

              <!-- Metrics -->
              <div class="grid grid-cols-3 gap-6">
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-accent">10+</div>
                  <div class="text-sm portfolio-secondary">Years</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-primary">50+</div>
                  <div class="text-sm portfolio-secondary">Projects</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-accent">150%</div>
                  <div class="text-sm portfolio-secondary">Growth</div>
                </div>
              </div>
            </div>

            <div class="lg:justify-self-end">
              <div class="w-64 h-64 portfolio-bg-primary rounded-xl shadow-2xl flex items-center justify-center">
                <span class="text-6xl font-bold text-white">
                  <%= String.first(@portfolio.title) %>
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <div class="grid gap-6 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3">
          <%= for section <- @sections do %>
            <div class="portfolio-card p-6 shadow-lg">
              <h2 class="text-xl font-bold mb-4 portfolio-primary">
                <%= section.title %>
              </h2>
              <div class="portfolio-secondary">
                <%= render_section_content(section) %>
              </div>
            </div>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  # 🔥 GALLERY LAYOUT RENDERER
  defp render_gallery_layout(assigns) do
    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <div class="min-h-screen">
      <!-- Gallery Header -->
      <header class="h-screen flex items-center justify-center relative overflow-hidden">
        <div class="absolute inset-0"></div>

        <!-- Floating Navigation -->
        <nav class="fixed top-6 left-1/2 transform -translate-x-1/2 z-50 floating-nav rounded-full px-6 py-3">
          <div class="flex space-x-6">
            <%= for section <- @sections do %>
              <a href={"#section-#{section.id}"} class="portfolio-primary hover:portfolio-accent transition-colors text-sm font-medium">
                <%= section.title %>
              </a>
            <% end %>
          </div>
        </nav>

        <!-- Hero Content -->
        <div class="relative text-center z-10">
          <h1 class="text-6xl lg:text-8xl font-bold mb-6 portfolio-primary">
            <%= @portfolio.title %>
          </h1>
          <p class="text-2xl lg:text-3xl portfolio-secondary opacity-90 max-w-4xl mx-auto leading-relaxed">
            <%= @portfolio.description %>
          </p>
        </div>
      </header>

      <!-- Masonry Content -->
      <main class="px-6 py-16">
        <div class="max-w-7xl mx-auto columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
          <%= for section <- @sections do %>
            <section id={"section-#{section.id}"} class="break-inside-avoid portfolio-card p-8 mb-8">
              <h2 class="text-2xl font-bold mb-6 portfolio-primary">
                <%= section.title %>
              </h2>
              <div class="portfolio-secondary">
                <%= render_section_content(section) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  # 🔥 TERMINAL LAYOUT RENDERER
  defp render_terminal_layout(assigns) do
    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <div class="min-h-screen">
      <!-- Terminal Header -->
      <header class="border-b portfolio-header">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center space-x-4">
            <div class="flex space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <span class="portfolio-secondary">~/portfolio/<%= String.downcase(String.replace(@portfolio.title, " ", "_")) %></span>
          </div>
        </div>
      </header>

      <!-- Terminal Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <!-- README Section -->
        <div class="terminal-window mb-6">
          <div class="portfolio-header border-b px-4 py-2">
            <span class="portfolio-primary">$</span>
            <span class="portfolio-accent">cat</span>
            <span class="portfolio-primary">README.md</span>
          </div>
          <div class="portfolio-card p-6">
            <h1 class="text-2xl font-bold portfolio-primary mb-4"># <%= @portfolio.title %></h1>
            <p class="portfolio-secondary mb-4"><%= @portfolio.description %></p>
          </div>
        </div>

        <!-- Sections as Terminal Commands -->
        <%= for section <- @sections do %>
          <div class="terminal-window mb-6">
            <div class="portfolio-header border-b px-4 py-2">
              <span class="portfolio-primary">$</span>
              <span class="portfolio-accent">cat</span>
              <span class="portfolio-primary"><%= String.downcase(String.replace(section.title, " ", "_")) %>.md</span>
            </div>
            <div class="portfolio-card p-6">
              <h2 class="portfolio-primary font-bold mb-4"># <%= section.title %></h2>
              <div class="portfolio-secondary">
                <%= render_section_content(section) %>
              </div>
            </div>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  # Other layout renderers (case_study, minimal, academic) would follow similar patterns...
  defp render_case_study_layout(assigns), do: render_dashboard_layout(assigns)
  defp render_minimal_layout(assigns), do: render_dashboard_layout(assigns)
  defp render_academic_layout(assigns), do: render_dashboard_layout(assigns)

  # 🔥 SECTION CONTENT RENDERER
  defp render_section_content(section) do
    case section.content do
      %{"summary" => summary} when is_binary(summary) -> summary
      %{"description" => desc} when is_binary(desc) -> desc
      %{"content" => content} when is_binary(content) -> content
      _ -> "Content coming soon..."
    end
  end

  defp get_template_background_class(template_config) do
    background = template_config[:background] || template_config["background"] || "default"

    case background do
      "gradient-ocean" -> ""
      "gradient-sunset" -> ""
      "gradient-forest" -> ""
      "dark-mode" -> "bg-gray-900"
      "terminal-dark" -> "bg-slate-900"
      _ -> "bg-gray-50"
    end
  end

  defp get_template_background_style(template_config) do
    background = template_config[:background] || template_config["background"] || "default"

    case background do
      "gradient-ocean" -> "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
      "gradient-sunset" -> "linear-gradient(135deg, #f093fb 0%, #f5576c 100%)"
      "gradient-forest" -> "linear-gradient(135deg, #4ecdc4 0%, #44a08d 100%)"
      "corporate-clean" -> "#f8fafc"
      "tech-dark" -> "#1f2937"
      "creative-gradient" -> "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
      "consulting-professional" -> "linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%)"
      "academic-clean" -> "linear-gradient(135deg, #f0f9ff 0%, #ecfdf5 100%)"
      _ -> "var(--portfolio-bg, #f8fafc)"
    end
  end

  defp get_template_specific_layout(template_config) do
    layout = template_config[:layout] || template_config["layout"] || "professional"

    case layout do
      "dashboard" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      "professional" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "creative" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      "academic" -> "grid-cols-1 lg:grid-cols-2"
      "consulting" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
      "minimal" -> "grid-cols-1 lg:grid-cols-2 max-w-4xl mx-auto"
      "artistic" -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4"
      _ -> "grid-cols-1 md:grid-cols-2 lg:grid-cols-3"
    end
  end

  defp get_section_color_from_template(section_type, template_config) do
    # Get base color from template
    primary_color = template_config[:primary_color] || template_config["primary_color"] || "#3b82f6"
    secondary_color = template_config[:secondary_color] || template_config["secondary_color"] || "#64748b"
    accent_color = template_config[:accent_color] || template_config["accent_color"] || "#f59e0b"

    # Assign colors based on section type importance
    case section_type do
      :intro -> primary_color
      :featured_project -> accent_color
      :experience -> primary_color
      :skills -> secondary_color
      :case_study -> accent_color
      :education -> secondary_color
      :contact -> primary_color
      _ -> secondary_color
    end
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

  defp get_section_card_size(section_type) do
    case section_type do
      :featured_project -> "lg:col-span-2 lg:row-span-2"  # Larger featured cards
      :case_study -> "lg:col-span-2"                       # Wide case studies
      :media_showcase -> "lg:col-span-2 lg:row-span-2"    # Large media displays
      :intro -> "lg:col-span-2"                           # Wide intro sections
      _ -> ""                                             # Standard sizing
    end
  end

  # Get color coding for different section types
  defp get_section_color(section_type) do
    case section_type do
      :featured_project -> "#f59e0b"  # Amber
      :experience -> "#3b82f6"       # Blue
      :skills -> "#10b981"           # Emerald
      :education -> "#8b5cf6"        # Violet
      :case_study -> "#ec4899"       # Pink
      :media_showcase -> "#6366f1"   # Indigo
      :intro -> "#059669"            # Emerald
      :contact -> "#0891b2"          # Cyan
      :testimonial -> "#84cc16"      # Lime
      :awards -> "#eab308"           # Yellow
      :certifications -> "#06b6d4"   # Cyan
      :publications -> "#7c3aed"     # Violet
      :languages -> "#14b8a6"        # Teal
      _ -> "#6b7280"                 # Gray (default)
    end
  end



  defp render_section_icon_svg(section_type) do
    case section_type do
      :intro ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """)

      :experience ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8zM16 10h.01"/>
        </svg>
        """)

      :skills ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """)

      :education ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5m0 0l-9 5-9-5m9-5l-9 5"/>
        </svg>
        """)

      :featured_project ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """)

      :case_study ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
        </svg>
        """)

      :media_showcase ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
        """)

      :contact ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """)

      :testimonial ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 8h10M7 12h4m1 8l-4-4H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-3l-4 4z"/>
        </svg>
        """)

      :awards ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
        </svg>
        """)

      :certifications ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
        </svg>
        """)

      :publications ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.206 5 7.5 5A3.5 3.5 0 004 8.5c0 2.155 1.572 3.923 3.654 4.382C10.748 13.993 12 15.5 12 17.255m0-13C13.168 5.477 14.794 5 16.5 5A3.5 3.5 0 0120 8.5c0 2.155-1.572 3.923-3.654 4.382C13.252 13.993 12 15.5 12 17.255"/>
        </svg>
        """)

      :languages ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"/>
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
        </svg>
        """)
    end
  end

  # Dashboard-specific section content rendering
  defp render_dashboard_section_content(section, assigns) do
    ~H"""
    <div class="w-full overflow-hidden">
      <%= case section.section_type do %>
        <% :intro -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_intro(section, assigns) %>
          </div>
        <% :experience -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_experience(section, assigns) %>
          </div>
        <% :skills -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_skills(section, assigns) %>
          </div>
        <% :featured_project -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_project(section, assigns) %>
          </div>
        <% :case_study -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_case_study(section, assigns) %>
          </div>
        <% :media_showcase -> %>
          <div class="space-y-4">
            <%= render_dashboard_media(section, assigns) %>
          </div>
        <% :education -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_education(section, assigns) %>
          </div>
        <% :contact -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_contact(section, assigns) %>
          </div>
        <% _ -> %>
          <div class="space-y-4 break-words">
            <%= render_dashboard_generic(section, assigns) %>
          </div>
      <% end %>
    </div>
    """
  end

  # Dashboard intro section
  defp render_dashboard_intro(section, assigns) do
    headline = get_in(section.content, ["headline"]) || ""
    summary = get_in(section.content, ["summary"]) || ""
    location = get_in(section.content, ["location"]) || ""

    assigns = assign(assigns, headline: headline, summary: summary, location: location)

    ~H"""
    <div class="space-y-4">
      <%= if String.length(@headline) > 0 do %>
        <h4 class="text-xl font-bold text-gray-900"><%= @headline %></h4>
      <% end %>

      <%= if String.length(@summary) > 0 do %>
        <p class="text-gray-600 leading-relaxed"><%= @summary %></p>
      <% end %>

      <%= if String.length(@location) > 0 do %>
        <div class="flex items-center text-sm text-gray-500">
          <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <%= @location %>
        </div>
      <% end %>
    </div>
    """
  end

  # Dashboard experience section
  defp render_dashboard_experience(section, assigns) do
    position = get_in(section.content, ["position"]) || ""
    company = get_in(section.content, ["company"]) || ""
    duration = get_in(section.content, ["duration"]) || ""
    description = get_in(section.content, ["description"]) || ""

    assigns = assign(assigns, position: position, company: company, duration: duration, description: description)

    ~H"""
    <div class="space-y-3">
      <div class="flex items-start justify-between">
        <div>
          <%= if String.length(@position) > 0 do %>
            <h4 class="text-lg font-bold text-gray-900"><%= @position %></h4>
          <% end %>
          <%= if String.length(@company) > 0 do %>
            <p class="text-blue-600 font-medium"><%= @company %></p>
          <% end %>
        </div>
        <%= if String.length(@duration) > 0 do %>
          <span class="text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded"><%= @duration %></span>
        <% end %>
      </div>

      <%= if String.length(@description) > 0 do %>
        <p class="text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>
    </div>
    """
  end

  # Dashboard skills section
  defp render_dashboard_skills(section, assigns) do
    skills = get_in(section.content, ["skills"]) || []

    assigns = assign(assigns, skills: skills)

    ~H"""
    <div class="space-y-4">
      <%= if length(@skills) > 0 do %>
        <div class="grid grid-cols-2 lg:grid-cols-3 gap-3">
          <%= for skill <- @skills do %>
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <span class="font-medium text-gray-900"><%= skill["name"] || skill %></span>
              <%= if skill["level"] do %>
                <div class="flex items-center space-x-1">
                  <%= for i <- 1..5 do %>
                    <div class={[
                      "w-2 h-2 rounded-full",
                      if(i <= (skill["level"] || 0), do: "bg-blue-500", else: "bg-gray-300")
                    ]}></div>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-gray-500 italic">Skills information coming soon...</p>
      <% end %>
    </div>
    """
  end

  # Dashboard project section
  defp render_dashboard_project(section, assigns) do
    title = get_in(section.content, ["title"]) || section.title
    description = get_in(section.content, ["description"]) || ""
    technologies = get_in(section.content, ["technologies"]) || []
    demo_url = get_in(section.content, ["demo_url"]) || ""
    repo_url = get_in(section.content, ["repo_url"]) || ""

    assigns = assign(assigns,
      project_title: title,
      description: description,
      technologies: technologies,
      demo_url: demo_url,
      repo_url: repo_url
    )

    ~H"""
    <div class="space-y-4">
      <h4 class="text-xl font-bold text-gray-900"><%= @project_title %></h4>

      <%= if String.length(@description) > 0 do %>
        <p class="text-gray-600 leading-relaxed"><%= @description %></p>
      <% end %>

      <%= if length(@technologies) > 0 do %>
        <div class="flex flex-wrap gap-2">
          <%= for tech <- @technologies do %>
            <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
              <%= tech %>
            </span>
          <% end %>
        </div>
      <% end %>

      <div class="flex items-center space-x-4">
        <%= if String.length(@demo_url) > 0 do %>
          <a href={@demo_url} target="_blank"
            class="inline-flex items-center text-sm font-medium text-blue-600 hover:text-blue-800">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
            Live Demo
          </a>
        <% end %>

        <%= if String.length(@repo_url) > 0 do %>
          <a href={@repo_url} target="_blank"
            class="inline-flex items-center text-sm font-medium text-gray-600 hover:text-gray-800">
            <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M12.316 3.051a1 1 0 01.633 1.265l-4 12a1 1 0 11-1.898-.632l4-12a1 1 0 011.265-.633zM5.707 6.293a1 1 0 010 1.414L3.414 10l2.293 2.293a1 1 0 11-1.414 1.414l-3-3a1 1 0 010-1.414l3-3a1 1 0 011.414 0zm8.586 0a1 1 0 011.414 0l3 3a1 1 0 010 1.414l-3 3a1 1 0 11-1.414-1.414L16.586 10l-2.293-2.293a1 1 0 010-1.414z" clip-rule="evenodd"/>
            </svg>
            View Code
          </a>
        <% end %>
      </div>
    </div>
    """
  end

  # Dashboard case study section
  defp render_dashboard_case_study(section, assigns) do
    client = get_in(section.content, ["client"]) || ""
    challenge = get_in(section.content, ["challenge"]) || ""
    solution = get_in(section.content, ["solution"]) || ""
    results = get_in(section.content, ["results"]) || ""

    assigns = assign(assigns, client: client, challenge: challenge, solution: solution, results: results)

    ~H"""
    <div class="space-y-4">
      <%= if String.length(@client) > 0 do %>
        <div class="flex items-center">
          <span class="text-sm font-medium text-gray-500 mr-2">Client:</span>
          <span class="font-bold text-gray-900"><%= @client %></span>
        </div>
      <% end %>

      <div class="grid gap-4">
        <%= if String.length(@challenge) > 0 do %>
          <div>
            <h5 class="font-semibold text-gray-900 mb-2">Challenge</h5>
            <p class="text-gray-600 text-sm"><%= @challenge %></p>
          </div>
        <% end %>

        <%= if String.length(@solution) > 0 do %>
          <div>
            <h5 class="font-semibold text-gray-900 mb-2">Solution</h5>
            <p class="text-gray-600 text-sm"><%= @solution %></p>
          </div>
        <% end %>

        <%= if String.length(@results) > 0 do %>
          <div>
            <h5 class="font-semibold text-gray-900 mb-2">Results</h5>
            <p class="text-gray-600 text-sm"><%= @results %></p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Dashboard media section
  defp render_dashboard_media(section, assigns) do
    description = get_in(section.content, ["description"]) || ""
    media_files = Map.get(section, :media_files, [])

    assigns = assign(assigns, description: description, media_files: media_files)

    ~H"""
    <div class="space-y-4">
      <%= if String.length(@description) > 0 do %>
        <p class="text-gray-600"><%= @description %></p>
      <% end %>

      <%= if length(@media_files) > 0 do %>
        <div class="grid grid-cols-2 lg:grid-cols-3 gap-3">
          <%= for media <- Enum.take(@media_files, 6) do %>
            <div class="aspect-square bg-gray-100 rounded-lg overflow-hidden">
              <%= if media.file_type == "image" do %>
                <img src={media.url} alt={media.filename} class="w-full h-full object-cover">
              <% else %>
                <div class="w-full h-full flex items-center justify-center">
                  <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 4V2a1 1 0 011-1h8a1 1 0 011 1v2M7 4h10M7 4l-2 14h14l-2-14M7 4h10"/>
                  </svg>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if length(@media_files) > 6 do %>
          <p class="text-sm text-gray-500 text-center">
            +<%= length(@media_files) - 6 %> more items
          </p>
        <% end %>
      <% else %>
        <div class="text-center py-8">
          <svg class="w-12 h-12 text-gray-300 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <p class="text-gray-500 text-sm">Media content coming soon</p>
        </div>
      <% end %>
    </div>
    """
  end

  # Dashboard education section
  defp render_dashboard_education(section, assigns) do
    degree = get_in(section.content, ["degree"]) || ""
    institution = get_in(section.content, ["institution"]) || ""
    graduation_year = get_in(section.content, ["graduation_year"]) || ""
    description = get_in(section.content, ["description"]) || ""

    assigns = assign(assigns, degree: degree, institution: institution, graduation_year: graduation_year, description: description)

    ~H"""
    <div class="space-y-3">
      <div class="flex items-start justify-between">
        <div>
          <%= if String.length(@degree) > 0 do %>
            <h4 class="text-lg font-bold text-gray-900"><%= @degree %></h4>
          <% end %>
          <%= if String.length(@institution) > 0 do %>
            <p class="text-purple-600 font-medium"><%= @institution %></p>
          <% end %>
        </div>
        <%= if String.length(@graduation_year) > 0 do %>
          <span class="text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded"><%= @graduation_year %></span>
        <% end %>
      </div>

      <%= if String.length(@description) > 0 do %>
        <p class="text-gray-600 leading-relaxed text-sm"><%= @description %></p>
      <% end %>
    </div>
    """
  end

  # Dashboard contact section
  defp render_dashboard_contact(section, assigns) do
    email = get_in(section.content, ["email"]) || ""
    phone = get_in(section.content, ["phone"]) || ""
    location = get_in(section.content, ["location"]) || ""
    website = get_in(section.content, ["website"]) || ""

    assigns = assign(assigns, email: email, phone: phone, location: location, website: website)

    ~H"""
    <div class="space-y-3">
      <%= if String.length(@email) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
          </svg>
          <a href={"mailto:#{@email}"} class="text-blue-600 hover:text-blue-800 font-medium"><%= @email %></a>
        </div>
      <% end %>

      <%= if String.length(@phone) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
          </svg>
          <a href={"tel:#{@phone}"} class="text-blue-600 hover:text-blue-800 font-medium"><%= @phone %></a>
        </div>
      <% end %>

      <%= if String.length(@location) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
          </svg>
          <span class="text-gray-600"><%= @location %></span>
        </div>
      <% end %>

      <%= if String.length(@website) > 0 do %>
        <div class="flex items-center">
          <svg class="w-5 h-5 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9v-9m0-9v9"/>
          </svg>
          <a href={@website} target="_blank" class="text-blue-600 hover:text-blue-800 font-medium"><%= @website %></a>
        </div>
      <% end %>
    </div>
    """
  end

  # Generic dashboard section
  defp render_dashboard_generic(section, assigns) do
    content = case section.content do
      %{"summary" => summary} -> summary
      %{"description" => desc} -> desc
      %{"content" => content} -> content
      _ -> "Content coming soon..."
    end

    assigns = assign(assigns, content: content, section_type: section.section_type)

    ~H"""
    <div class="space-y-3">
      <%= if String.length(@content) > 0 do %>
        <p class="text-gray-600 leading-relaxed"><%= @content %></p>
      <% else %>
        <div class="text-center py-6">
          <svg class="w-8 h-8 text-gray-300 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          <p class="text-gray-500 text-sm italic">
            This <%= format_section_type(@section_type) %> section is being developed.
          </p>
        </div>
      <% end %>
    </div>
    """
  end

  # Get helper functions for template styling (from PortfolioTemplates module)
  defp get_header_classes(template_config) do
    Frestyl.Portfolios.PortfolioTemplates.get_header_classes(template_config)
  end

  defp get_card_classes(template_config) do
    card_style = template_config[:card_style] || template_config["card_style"] || "modern"
    layout = template_config[:layout] || template_config["layout"] || "professional"

    base = "bg-white rounded-xl shadow-lg border transition-all duration-300 hover:shadow-xl overflow-hidden"

    case {layout, card_style} do
      {"academic", _} -> "#{base} border-emerald-200 hover:border-emerald-300 bg-gradient-to-br from-white to-emerald-50/30"
      {"creative", _} -> "#{base} border-purple-200 hover:border-purple-300 bg-gradient-to-br from-white to-purple-50/30 hover:scale-[1.02]"
      {"consulting", _} -> "#{base} border-blue-200 hover:border-blue-300 bg-gradient-to-br from-white to-blue-50/30"
      {"minimal", _} -> "#{base} border-gray-100 hover:border-gray-200 shadow-sm hover:shadow-md"
      {"dashboard", "technical"} -> "#{base} border-gray-300 bg-gray-50 hover:border-gray-400"
      _ -> "#{base} border-gray-200 hover:border-gray-300"
    end
  end

  defp get_dashboard_layout_classes(template_config) do
    Frestyl.Portfolios.PortfolioTemplates.get_dashboard_layout_classes(template_config)
  end

  # Helper to get video thumbnail (placeholder for now)
  defp get_video_thumbnail(video) do
    # Return a placeholder or actual thumbnail if available
    "/images/video-placeholder.jpg"
  end

  # Helper to get media URL
  defp get_media_url(media) do
    case media do
      %{url: url} -> url
      %{file_path: path} -> path
      _ -> "#"
    end
  end

  # Format section type for display
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
      :awards -> "Awards & Recognition"
      :certifications -> "Certifications"
      :publications -> "Publications"
      :languages -> "Languages"
      _ -> String.capitalize(to_string(section_type)) |> String.replace("_", " ")
    end
  end# Helper functions to add to lib/frestyl_web/live/portfolio_live/view.ex

  # Dashboard-specific helper functions for the portfolio view

  # Get section-specific card sizing for dashboard layout
  defp get_section_card_size(section_type) do
    case section_type do
      :featured_project -> "lg:col-span-2 lg:row-span-2"  # Larger featured cards
      :case_study -> "lg:col-span-2"                       # Wide case studies
      :media_showcase -> "lg:col-span-2 lg:row-span-2"    # Large media displays
      :intro -> "lg:col-span-2"                           # Wide intro sections
      _ -> ""                                             # Standard sizing
    end
  end

  # Get color coding for different section types
  defp get_section_color(section_type) do
    case section_type do
      :featured_project -> "#f59e0b"  # Amber
      :experience -> "#3b82f6"       # Blue
      :skills -> "#10b981"           # Emerald
      :education -> "#8b5cf6"        # Violet
      :case_study -> "#ec4899"       # Pink
      :media_showcase -> "#6366f1"   # Indigo
      :intro -> "#059669"            # Emerald
      :contact -> "#0891b2"          # Cyan
      :testimonial -> "#84cc16"      # Lime
      :awards -> "#eab308"           # Yellow
      :certifications -> "#06b6d4"   # Cyan
      :publications -> "#7c3aed"     # Violet
      :languages -> "#14b8a6"        # Teal
      _ -> "#6b7280"                 # Gray (default)
    end
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

  # Add this helper function near the other helper functions in view.ex
  defp safe_user_name(user) do
    case user do
      %{name: name} when is_binary(name) and name != "" -> name
      %{username: username} when is_binary(username) and username != "" -> username
      %{email: email} when is_binary(email) -> String.split(email, "@") |> List.first()
      _ -> "Anonymous User"
    end
  end

  defp safe_user_initial(user) do
    safe_user_name(user) |> String.first() |> String.upcase()
  end
end
