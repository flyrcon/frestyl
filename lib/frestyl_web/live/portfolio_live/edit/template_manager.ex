# lib/frestyl_web/live/portfolio_live/edit/template_manager.ex

defmodule FrestylWeb.PortfolioLive.Edit.TemplateManager do
  @moduledoc """
  Handles template-related operations for the portfolio editor.
  """

  use Phoenix.Component
  import Phoenix.LiveView.Helpers
  import Phoenix.HTML

  # Import the necessary LiveView components and functions
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.Portfolio

  # 🔥 FIX: Add template name normalization to map complex names to valid enum values
  @template_name_mapping %{
    # Map complex template names to valid database enum values
    "creative_artistic" => "creative",
    "creative_designer" => "designer",
    "professional_executive" => "executive",
    "professional_corporate" => "corporate",
    "minimalist_clean" => "minimalist",
    "minimalist_elegant" => "minimalist",
    "technical_developer" => "developer",
    "technical_engineer" => "developer"
  }

  def handle_template_selection(socket, %{"template" => template_key}) do
    IO.puts("🎨 Selecting template: #{template_key}")
    IO.puts("🔥 TemplateManager.handle_template_selection called")
    IO.puts("🔥 Trying to select template: #{template_key}")
    IO.puts("🔥 Current portfolio theme: #{socket.assigns.portfolio.theme}")

    # Get enhanced template configuration using existing function
    template_config = get_enhanced_template_config(template_key)

    # Update socket assignments
    socket = socket
    |> assign(:selected_template, template_key)
    |> assign(:current_template, template_key)
    |> assign(:template_config, template_config)
    |> assign(:customization, template_config)
    |> assign(:unsaved_changes, true)

    # Generate updated CSS using existing function
    css = generate_preview_css(template_config, template_key)
    socket = assign(socket, :preview_css, css)

    # Update portfolio in database
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{
      theme: template_key,
      customization: template_config
    }) do
      {:ok, portfolio} ->
        IO.puts("✅ Portfolio updated successfully! New theme: #{portfolio.theme}")
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Template '#{get_theme_name(template_key)}' applied successfully!")

      {:error, changeset} ->
        IO.puts("❌ Portfolio update failed!")
        IO.inspect(changeset.errors, label: "❌ Errors")
        socket
        |> put_flash(:error, "Failed to save template changes")
    end
  end

  defp get_theme_name(template_key) do
    get_theme_variations()
    |> Enum.find_value(fn {key, config} ->
      if key == template_key, do: config.name, else: nil
    end) || String.capitalize(template_key)
  end

  # 🔥 FIX: Add normalization function
  defp normalize_template_name(template_name) do
    # Check if we have a mapping for this template name
    case Map.get(@template_name_mapping, template_name) do
      nil ->
        # If no mapping found, try to extract a valid name
        cond do
          String.contains?(template_name, "creative") -> "creative"
          String.contains?(template_name, "professional") -> "executive"
          String.contains?(template_name, "executive") -> "executive"
          String.contains?(template_name, "minimalist") -> "minimalist"
          String.contains?(template_name, "technical") -> "developer"
          String.contains?(template_name, "developer") -> "developer"
          String.contains?(template_name, "designer") -> "designer"
          String.contains?(template_name, "corporate") -> "corporate"
          true -> "executive"  # Default fallback
        end

      mapped_name ->
        mapped_name
    end
  end

  defp normalize_template_config(config) when is_map(config) do
    # Convert atom keys to string keys for consistency
    Enum.reduce(config, %{}, fn {key, value}, acc ->
      string_key = if is_atom(key), do: Atom.to_string(key), else: key
      normalized_value = if is_map(value), do: normalize_template_config(value), else: value
      Map.put(acc, string_key, normalized_value)
    end)
  end

  defp normalize_template_config(config), do: config || %{}


  # Add this helper function
  defp convert_atoms_to_strings(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {to_string(k), convert_atoms_to_strings(v)}
    end)
    |> Enum.into(%{})
  end

  defp convert_atoms_to_strings(value), do: value

  # Update the preview CSS generation if needed
  defp maybe_update_preview_css(socket) do
    # Generate CSS from current customization
    css = generate_preview_css(socket.assigns.customization, socket.assigns.selected_template)
    assign(socket, :preview_css, css)
  end

  defp generate_preview_css(customization, template) do
    # Extract colors with safe defaults
    primary_color = get_in(customization, ["primary_color"]) || "#3b82f6"
    secondary_color = get_in(customization, ["secondary_color"]) || "#64748b"
    accent_color = get_in(customization, ["accent_color"]) || "#f59e0b"

    # Extract typography
    typography = customization["typography"] || %{}
    font_family = typography["font_family"] || "Inter"

    font_family_css = case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end

    """
    <style>
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{font_family_css};
    }

    /* 🔥 PORTFOLIO CARD FIXED HEIGHT AND SCROLLABLE CONTENT */

    /* Base portfolio card with fixed height */
    .portfolio-card {
      height: 400px; /* Fixed height for all cards */
      display: flex;
      flex-direction: column;
      overflow: hidden;
      background: white;
      border-radius: 12px;
      padding: 1.5rem;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
      border: 1px solid #e5e7eb;
      transition: all 0.3s ease;
    }

    /* Portfolio card header - fixed at top */
    .portfolio-card-header {
      flex-shrink: 0; /* Prevent header from shrinking */
      padding-bottom: 1rem;
      border-bottom: 1px solid rgba(229, 231, 235, 0.5);
      margin-bottom: 1rem;
      min-height: 60px; /* Minimum header height */
      max-height: 120px; /* Maximum header height */
    }

    /* Portfolio card content - scrollable area */
    .portfolio-card-content {
      flex: 1; /* Take remaining space */
      overflow-y: auto; /* Enable vertical scrolling */
      overflow-x: hidden; /* Hide horizontal scrolling */
      padding-right: 0.5rem; /* Space for scrollbar */
      margin-right: -0.5rem; /* Offset padding to align content */
    }

    /* Custom scrollbar styling for webkit browsers */
    .portfolio-card-content::-webkit-scrollbar {
      width: 6px;
    }

    .portfolio-card-content::-webkit-scrollbar-track {
      background: rgba(243, 244, 246, 0.5);
      border-radius: 3px;
    }

    .portfolio-card-content::-webkit-scrollbar-thumb {
      background: rgba(156, 163, 175, 0.7);
      border-radius: 3px;
    }

    .portfolio-card-content::-webkit-scrollbar-thumb:hover {
      background: rgba(107, 114, 128, 0.8);
    }

    /* Firefox scrollbar styling */
    .portfolio-card-content {
      scrollbar-width: thin;
      scrollbar-color: rgba(156, 163, 175, 0.7) rgba(243, 244, 246, 0.5);
    }

    /* Card hover effects with fixed height */
    .portfolio-card:hover {
      transform: translateY(-2px);
      box-shadow: 0 10px 25px -3px rgba(0, 0, 0, 0.1);
    }

    /* Ensure header content doesn't overflow */
    .portfolio-card-title {
      font-size: 1.125rem;
      line-height: 1.4;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .portfolio-card-subtitle {
      font-size: 0.875rem;
      opacity: 0.7;
    }

    /* Ensure content within cards doesn't break layout */
    .portfolio-card-content * {
      max-width: 100%;
      word-wrap: break-word;
    }

    /* Handle long content gracefully */
    .portfolio-card-content pre,
    .portfolio-card-content code {
      white-space: pre-wrap;
      word-break: break-word;
    }

    .portfolio-card-content img {
      max-width: 100%;
      height: auto;
    }

    /* Layout-specific height adjustments */

    /* Dashboard layout - standard cards */
    .portfolio-layout-dashboard .portfolio-card {
      height: 420px;
    }

    /* Gallery layout - varying heights for masonry effect but with max */
    .portfolio-layout-gallery .portfolio-card {
      height: auto;
      max-height: 500px;
      min-height: 350px;
    }

    .portfolio-layout-gallery .portfolio-card-content {
      max-height: 400px; /* Ensure content doesn't exceed reasonable height */
    }

    /* Timeline layout - consistent height */
    .portfolio-layout-timeline .portfolio-card {
      height: 450px;
    }

    /* Minimal layout - slightly shorter */
    .portfolio-layout-minimal .portfolio-card {
      height: 380px;
    }

    /* Corporate layout - professional height */
    .portfolio-layout-corporate .portfolio-card {
      height: 440px;
    }

    /* Terminal layout specific adjustments */
    .terminal-window .portfolio-card {
      height: 400px;
    }

    .terminal-window .portfolio-card-content {
      flex: 1;
      overflow-y: auto;
      font-family: 'JetBrains Mono', 'Fira Code', monospace;
    }

    /* Responsive height adjustments */
    @media (max-width: 768px) {
      .portfolio-card {
        height: 350px; /* Shorter on mobile */
      }

      .portfolio-layout-dashboard .portfolio-card,
      .portfolio-layout-timeline .portfolio-card,
      .portfolio-layout-corporate .portfolio-card {
        height: 350px;
      }

      .portfolio-layout-minimal .portfolio-card {
        height: 320px;
      }

      .portfolio-layout-gallery .portfolio-card {
        max-height: 400px;
        min-height: 300px;
      }
    }

    @media (max-width: 480px) {
      .portfolio-card {
        height: 320px; /* Even shorter on very small screens */
      }

      .portfolio-layout-dashboard .portfolio-card,
      .portfolio-layout-timeline .portfolio-card,
      .portfolio-layout-corporate .portfolio-card,
      .portfolio-layout-minimal .portfolio-card {
        height: 320px;
      }

      .portfolio-layout-gallery .portfolio-card {
        max-height: 350px;
        min-height: 280px;
      }
    }

    /* 🔥 EXISTING COLOR AND TYPOGRAPHY STYLES */
    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

    .portfolio-preview {
      font-family: var(--portfolio-font-family) !important;
    }
    </style>
    """
  end

  # Handle template events with proper routing
  def handle_template_event(socket, event_name, params) do
    updated_socket = case event_name do
      "set_customization_tab" ->
        tab = params["tab"] || params["value"]
        assign(socket, :active_customization_tab, tab)

      "update_color_scheme" ->
        handle_scheme_update(socket, params)

      "update_primary_color" ->
        handle_color_update(socket, %{"field" => "primary_color", "value" => params["color"] || params["value"]})

      "update_secondary_color" ->
        handle_color_update(socket, %{"field" => "secondary_color", "value" => params["color"] || params["value"]})

      "update_accent_color" ->
        handle_color_update(socket, %{"field" => "accent_color", "value" => params["color"] || params["value"]})

      "update_background" ->
        background = params["background"] || params["value"] || params["bg"]
        handle_background_update(socket, %{"background" => background})

      "update_color" ->
        handle_color_update(socket, params)

      "update_layout" ->
        handle_layout_update(socket, params)

      "update_typography" ->
        handle_typography_update(socket, params)

      "update_spacing" ->
        handle_spacing_update(socket, params)

      "refresh_preview" ->
        maybe_update_preview_css(socket)

      _ ->
        socket
    end

    {:noreply, updated_socket}
  end

  # Handle color updates
  defp handle_color_update(socket, %{"field" => field, "value" => value}) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, field, value)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Colors updated!")

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to update colors")
    end
  end

  # Handle scheme updates
  defp handle_scheme_update(socket, %{"scheme" => scheme}) do
    colors = get_scheme_colors(scheme)
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.merge(current_customization, colors)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Color scheme applied!")

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to update color scheme")
    end
  end

  # Handle typography updates
  defp handle_typography_update(socket, params) do
    current_customization = socket.assigns.customization || %{}
    current_typography = current_customization["typography"] || %{}

    updated_typography = case params do
      %{"font" => font} -> Map.put(current_typography, "font_family", font)
      %{"field" => field, "value" => value} -> Map.put(current_typography, field, value)
      _ -> current_typography
    end

    updated_customization = Map.put(current_customization, "typography", updated_typography)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Typography updated!")

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to update typography")
    end
  end

  # Handle background updates
  defp handle_background_update(socket, %{"background" => background}) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "background", background)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Background updated!")

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to update background")
    end
  end

  def handle_layout_selection(socket, %{"layout" => layout_name}) do
    IO.puts("🔥 LAYOUT SELECTION: #{layout_name}")

    # Get current customization
    current_customization = socket.assigns.customization || %{}

    # Update layout in customization
    updated_customization = Map.put(current_customization, "layout", layout_name)

    # Generate updated CSS
    css = generate_layout_specific_css(updated_customization, layout_name, socket.assigns.portfolio.theme)

    # Update portfolio in database
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{
      customization: updated_customization
    }) do
      {:ok, portfolio} ->
        IO.puts("✅ Layout updated successfully! New layout: #{layout_name}")
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:preview_css, css)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Layout changed to #{format_layout_name(layout_name)}")

      {:error, changeset} ->
        IO.puts("❌ Layout update failed!")
        IO.inspect(changeset.errors, label: "❌ Errors")
        socket
        |> assign(:customization, updated_customization)
        |> assign(:preview_css, css)
        |> assign(:unsaved_changes, true)
        |> put_flash(:error, "Failed to save layout changes - will retry")
    end
  end

    defp format_layout_name(layout) do
    case layout do
      "dashboard" -> "Dashboard"
      "gallery" -> "Gallery"
      "timeline" -> "Timeline"
      "minimal" -> "Minimal"
      "corporate" -> "Corporate"
      "academic" -> "Academic"
      _ -> String.capitalize(layout)
    end
  end

  # Generate layout-specific CSS
  defp generate_layout_specific_css(customization, layout, theme) do
    base_css = generate_preview_css(customization, theme)
    layout_css = get_layout_specific_styles(layout)

    """
    #{base_css}
    #{layout_css}
    """
  end

  defp get_layout_specific_styles(layout) do
    case layout do
      "dashboard" ->
        """
        <style>
        .portfolio-layout-dashboard .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
          gap: 2rem;
          padding: 2rem;
        }
        .portfolio-layout-dashboard .portfolio-card {
          height: 420px; /* Fixed height for dashboard */
          display: flex;
          flex-direction: column;
          overflow: hidden;
          background: white;
          border-radius: 12px;
          padding: 1.5rem;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
          border: 1px solid #e5e7eb;
          transition: all 0.3s ease;
        }
        .portfolio-layout-dashboard .portfolio-card:hover {
          transform: translateY(-2px);
          box-shadow: 0 10px 25px -3px rgba(0, 0, 0, 0.1);
        }
        .portfolio-layout-dashboard .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-layout-dashboard .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
        }
        </style>
        """

      "gallery" ->
        """
        <style>
        .portfolio-layout-gallery .portfolio-sections {
          columns: 1;
          column-gap: 2rem;
          padding: 2rem;
        }
        @media (min-width: 768px) {
          .portfolio-layout-gallery .portfolio-sections {
            columns: 2;
          }
        }
        @media (min-width: 1024px) {
          .portfolio-layout-gallery .portfolio-sections {
            columns: 3;
          }
        }
        .portfolio-layout-gallery .portfolio-card {
          break-inside: avoid;
          margin-bottom: 2rem;
          background: white;
          border-radius: 16px;
          padding: 2rem;
          box-shadow: 0 8px 25px -3px rgba(0, 0, 0, 0.1);
          border: 1px solid #f3f4f6;
          height: auto;
          max-height: 500px; /* Max height for gallery cards */
          min-height: 350px; /* Min height for gallery cards */
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }
        .portfolio-layout-gallery .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-layout-gallery .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
          max-height: 400px; /* Ensure content doesn't exceed reasonable height */
        }
        </style>
        """

      "timeline" ->
        """
        <style>
        .portfolio-layout-timeline .portfolio-sections {
          max-width: 4xl;
          margin: 0 auto;
          padding: 2rem;
          position: relative;
        }
        .portfolio-layout-timeline .portfolio-sections::before {
          content: '';
          position: absolute;
          left: 2rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: linear-gradient(to bottom, #3b82f6, #8b5cf6);
        }
        .portfolio-layout-timeline .portfolio-card {
          margin-left: 4rem;
          margin-bottom: 3rem;
          position: relative;
          height: 450px; /* Fixed height for timeline */
          display: flex;
          flex-direction: column;
          overflow: hidden;
          background: white;
          border-radius: 12px;
          padding: 2rem;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        .portfolio-layout-timeline .portfolio-card::before {
          content: '';
          position: absolute;
          left: -3rem;
          top: 1.5rem;
          width: 1rem;
          height: 1rem;
          border-radius: 50%;
          background: #3b82f6;
          border: 3px solid white;
          box-shadow: 0 0 0 3px #3b82f6;
        }
        .portfolio-layout-timeline .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-layout-timeline .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
        }
        </style>
        """

      "minimal" ->
        """
        <style>
        .portfolio-layout-minimal .portfolio-sections {
          max-width: 3xl;
          margin: 0 auto;
          padding: 4rem 2rem;
        }
        .portfolio-layout-minimal .portfolio-card {
          margin-bottom: 4rem;
          height: 380px; /* Fixed height for minimal */
          display: flex;
          flex-direction: column;
          overflow: hidden;
          background: transparent;
          border: none;
          box-shadow: none;
          padding: 2rem 0;
          border-bottom: 1px solid #e5e7eb;
        }
        .portfolio-layout-minimal .portfolio-card:last-child {
          border-bottom: none;
        }
        .portfolio-layout-minimal .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-layout-minimal .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
        }
        </style>
        """

      "corporate" ->
        """
        <style>
        .portfolio-layout-corporate .portfolio-sections {
          display: grid;
          grid-template-columns: 1fr 2fr;
          gap: 3rem;
          padding: 2rem;
          max-width: 7xl;
          margin: 0 auto;
        }
        @media (max-width: 1024px) {
          .portfolio-layout-corporate .portfolio-sections {
            grid-template-columns: 1fr;
          }
        }
        .portfolio-layout-corporate .portfolio-card {
          height: 440px; /* Fixed height for corporate */
          display: flex;
          flex-direction: column;
          overflow: hidden;
          background: white;
          border-radius: 8px;
          padding: 2rem;
          box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
          border-left: 4px solid var(--portfolio-primary-color, #3b82f6);
        }
        .portfolio-layout-corporate .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-layout-corporate .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
        }
        </style>
        """

      _ ->
        """
        <style>
        .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 1.5rem;
          padding: 1.5rem;
        }
        .portfolio-card {
          height: 400px; /* Default fixed height */
          display: flex;
          flex-direction: column;
          overflow: hidden;
        }
        .portfolio-card-header {
          flex-shrink: 0;
          padding-bottom: 1rem;
          border-bottom: 1px solid rgba(229, 231, 235, 0.5);
          margin-bottom: 1rem;
        }
        .portfolio-card-content {
          flex: 1;
          overflow-y: auto;
          overflow-x: hidden;
        }
        </style>
        """
    end
  end

  def get_available_layouts do
    [
      {"dashboard", %{
        name: "Dashboard",
        description: "Modern grid-based layout",
        features: ["Grid Layout", "Card-based", "Responsive", "Professional"]
      }},
      {"gallery", %{
        name: "Gallery",
        description: "Visual masonry-style layout",
        features: ["Masonry", "Image Focus", "Creative"]
      }},
      {"timeline", %{
        name: "Timeline",
        description: "Chronological vertical layout with story features",
        features: ["Timeline", "Chronological", "Story", "Narrative"]
      }},
      {"minimal", %{
        name: "Minimal",
        description: "Clean single-column layout",
        features: ["Single Column", "Clean", "Focus"]
      }},
      {"corporate", %{
        name: "Corporate",
        description: "Structured business layout",
        features: ["Structured", "Professional", "Formal"]
      }},
      {"creative", %{
        name: "Creative",
        description: "Dynamic asymmetric layout",
        features: ["Asymmetric", "Dynamic", "Bold"]
      }},
      {"terminal", %{
        name: "Terminal",
        description: "Developer-focused terminal theme",
        features: ["Code Style", "Dark Theme", "Technical"]
      }},
      {"case_study", %{
        name: "Case Study",
        description: "Business presentation layout",
        features: ["Structured", "Data Focus", "Business"]
      }},
      {"academic", %{
        name: "Academic",
        description: "Research and publication layout",
        features: ["Publication Ready", "Clean Typography", "Academic"]
      }}
    ]
  end

  defp render_layout_preview(layout_key) do
    case layout_key do
      "dashboard" ->
        Phoenix.HTML.raw("""
        <div class="p-2 h-full">
          <div class="grid grid-cols-2 gap-1 h-full">
            <div class="bg-blue-200 rounded"></div>
            <div class="bg-blue-300 rounded"></div>
            <div class="bg-blue-300 rounded"></div>
            <div class="bg-blue-200 rounded"></div>
          </div>
        </div>
        """)

      "gallery" ->
        Phoenix.HTML.raw("""
        <div class="p-2 h-full flex space-x-1">
          <div class="flex-1 space-y-1">
            <div class="bg-purple-200 rounded h-6"></div>
            <div class="bg-purple-300 rounded h-4"></div>
          </div>
          <div class="flex-1 space-y-1">
            <div class="bg-purple-300 rounded h-4"></div>
            <div class="bg-purple-200 rounded h-6"></div>
          </div>
        </div>
        """)

      "timeline" ->
        Phoenix.HTML.raw("""
        <div class="p-2 h-full relative">
          <div class="absolute left-4 top-2 bottom-2 w-0.5 bg-green-400"></div>
          <div class="space-y-1 ml-6">
            <div class="bg-green-200 rounded h-2"></div>
            <div class="bg-green-300 rounded h-2"></div>
            <div class="bg-green-200 rounded h-2"></div>
          </div>
        </div>
        """)

      "minimal" ->
        Phoenix.HTML.raw("""
        <div class="p-3 h-full space-y-2">
          <div class="bg-gray-300 rounded h-1"></div>
          <div class="bg-gray-200 rounded h-1"></div>
          <div class="bg-gray-300 rounded h-1"></div>
          <div class="bg-gray-200 rounded h-1"></div>
        </div>
        """)

      "corporate" ->
        Phoenix.HTML.raw("""
        <div class="p-2 h-full grid grid-cols-3 gap-1">
          <div class="bg-blue-200 rounded"></div>
          <div class="bg-blue-300 rounded col-span-2"></div>
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="p-2 h-full bg-gray-200 rounded flex items-center justify-center">
          <div class="text-xs text-gray-500">Preview</div>
        </div>
        """)
    end
  end

  defp get_layout_features(layout) do
    case layout do
      "dashboard" -> [
        "Responsive grid system",
        "Card-based sections",
        "Hover animations",
        "Mobile optimized"
      ]
      "gallery" -> [
        "Masonry column layout",
        "Creative visual flow",
        "Image-friendly",
        "Dynamic spacing"
      ]
      "timeline" -> [
        "Chronological progression",
        "Visual timeline indicator",
        "Story-telling format",
        "Career-focused"
      ]
      "minimal" -> [
        "Clean typography focus",
        "Reduced visual noise",
        "Maximum readability",
        "Elegant simplicity"
      ]
      "corporate" -> [
        "Professional appearance",
        "Structured information",
        "Business-oriented",
        "Two-column design"
      ]
      _ -> ["Custom layout options"]
    end
  end



  # Handle layout updates
  defp handle_layout_update(socket, %{"layout" => layout}) do
    IO.puts("🔥 LAYOUT UPDATE: #{layout}")

    # Update customization directly (since update_customization_field exists)
    customization = socket.assigns.customization || %{}
    updated_customization = Map.put(customization, "layout", layout)

    # Save immediately to database so it appears in live view
    portfolio = socket.assigns.portfolio

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("🔥 LAYOUT SAVED TO DB: #{layout}")

        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Layout updated to #{layout}")

      {:error, changeset} ->
        IO.puts("🔥 LAYOUT SAVE FAILED: #{inspect(changeset.errors)}")

        socket
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, true)
        |> put_flash(:error, "Failed to save layout changes")
    end
  end

  defp handle_layout_update(socket, %{"value" => layout}) do
    handle_layout_update(socket, %{"layout" => layout})
  end

  defp handle_layout_update(socket, params) do
    # Log unhandled layout params for debugging
    require Logger
    Logger.warning("Unhandled layout update params: #{inspect(params)}")
    socket
  end

  # Handle spacing updates
  defp handle_spacing_update(socket, %{"spacing" => spacing}) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "spacing", spacing)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Spacing updated!")

      {:error, _changeset} ->
        socket
        |> put_flash(:error, "Failed to update spacing")
    end
  end

  # Get scheme colors
  defp get_scheme_colors(scheme) do
    case scheme do
      "creative" ->
        %{
          "primary_color" => "#8B5CF6",
          "secondary_color" => "#06B6D4",
          "accent_color" => "#F59E0B"
        }

      "professional" ->
        %{
          "primary_color" => "#1E40AF",
          "secondary_color" => "#64748B",
          "accent_color" => "#3B82F6"
        }

      "academic" ->
        %{
          "primary_color" => "#7C2D12",
          "secondary_color" => "#78716C",
          "accent_color" => "#DC2626"
        }

      "minimal" ->
        %{
          "primary_color" => "#000000",
          "secondary_color" => "#6B7280",
          "accent_color" => "#374151"
        }

      _ ->
        # Default scheme
        %{
          "primary_color" => "#3B82F6",
          "secondary_color" => "#64748B",
          "accent_color" => "#F59E0B"
        }
    end
  end

  def get_enhanced_template_config(theme) do
    # Try to use the PortfolioTemplates module if it exists, otherwise use fallback
    base_config = case Code.ensure_loaded(Frestyl.Portfolios.PortfolioTemplates) do
      {:module, _} ->
        # Module exists, try to call the function
        try do
          apply(Frestyl.Portfolios.PortfolioTemplates, :get_template_config, [theme])
        rescue
          UndefinedFunctionError ->
            get_fallback_template_config(theme)
          _ ->
            get_fallback_template_config(theme)
        end

      {:error, _} ->
        # Module doesn't exist, use fallback
        get_fallback_template_config(theme)
    end

    enhanced_configs = %{
      "minimalist" => %{
        "layout" => "minimal",
        "primary_color" => "#000000",
        "secondary_color" => "#666666",
        "accent_color" => "#333333",
        "typography" => %{
          "font_family" => "Inter",
          "font_size" => "base",
          "line_height" => "relaxed"
        },
        "spacing" => "comfortable",
        "card_style" => "flat",
        "background" => "white",
        "border_style" => "minimal",
        "shadow_style" => "none"
      },
      "clean" => %{
        "layout" => "dashboard",
        "primary_color" => "#2563eb",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6",
        "typography" => %{
          "font_family" => "Inter",
          "font_size" => "base",
          "line_height" => "normal"
        },
        "spacing" => "normal",
        "card_style" => "minimal",
        "background" => "light_gray",
        "border_style" => "subtle",
        "shadow_style" => "soft"
      },
      "elegant" => %{
        "layout" => "gallery",
        "primary_color" => "#4c1d95",
        "secondary_color" => "#7c3aed",
        "accent_color" => "#c084fc",
        "typography" => %{
          "font_family" => "Playfair Display",
          "font_size" => "large",
          "line_height" => "loose"
        },
        "spacing" => "spacious",
        "card_style" => "elevated",
        "background" => "gradient_subtle",
        "border_style" => "elegant",
        "shadow_style" => "dramatic"
      }
    }

    # Deep merge base config with enhancements
    deep_merge_configs(base_config, Map.get(enhanced_configs, theme, %{}))
  end

  defp get_fallback_template_config(theme) do
    base_template = %{
      "typography" => %{
        "font_family" => "Inter",
        "font_size" => "base",
        "line_height" => "normal"
      },
      "spacing" => "normal",
      "card_style" => "default",
      "background" => "white"
    }

    theme_specific = case theme do
      "executive" -> %{
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6",
        "layout" => "dashboard"
      }
      "developer" -> %{
        "primary_color" => "#059669",
        "secondary_color" => "#374151",
        "accent_color" => "#10b981",
        "layout" => "timeline",
        "typography" => %{
          "font_family" => "JetBrains Mono",
          "font_size" => "base",
          "line_height" => "normal"
        }
      }
      "designer" -> %{
        "primary_color" => "#7c3aed",
        "secondary_color" => "#ec4899",
        "accent_color" => "#f59e0b",
        "layout" => "gallery",
        "typography" => %{
          "font_family" => "Playfair Display",
          "font_size" => "large",
          "line_height" => "loose"
        }
      }
      "consultant" -> %{
        "primary_color" => "#0891b2",
        "secondary_color" => "#0284c7",
        "accent_color" => "#6366f1",
        "layout" => "corporate"
      }
      "academic" -> %{
        "primary_color" => "#059669",
        "secondary_color" => "#047857",
        "accent_color" => "#10b981",
        "layout" => "minimal",
        "typography" => %{
          "font_family" => "Merriweather",
          "font_size" => "base",
          "line_height" => "relaxed"
        }
      }
      "minimalist" -> %{
        "primary_color" => "#000000",
        "secondary_color" => "#666666",
        "accent_color" => "#333333",
        "layout" => "minimal",
        "typography" => %{
          "font_family" => "Inter",
          "font_size" => "base",
          "line_height" => "relaxed"
        }
      }
      "clean" -> %{
        "primary_color" => "#2563eb",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6",
        "layout" => "dashboard"
      }
      "elegant" -> %{
        "primary_color" => "#4c1d95",
        "secondary_color" => "#7c3aed",
        "accent_color" => "#c084fc",
        "layout" => "gallery",
        "typography" => %{
          "font_family" => "Playfair Display",
          "font_size" => "large",
          "line_height" => "loose"
        }
      }
      _ -> %{
        "primary_color" => "#3b82f6",
        "secondary_color" => "#64748b",
        "accent_color" => "#f59e0b",
        "layout" => "dashboard"
      }
    end

    # Merge base template with theme-specific config
    deep_merge_configs(base_template, theme_specific)
  end

  defp deep_merge_configs(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge_configs(v1, v2)
      else
        v2  # Right side takes precedence
      end
    end)
  end
  defp deep_merge_configs(_left, right), do: right


  # ADD this function to get available theme variations:
  def get_theme_variations do
    [
      {"executive", %{
        name: "Executive",
        description: "Professional corporate style",
        category: "business",
        preview_layout: "dashboard",
        color_preview: ["#1e40af", "#64748b", "#3b82f6"],
        features: ["Dashboard Layout", "Corporate Colors", "Professional Typography"]
      }},
      {"developer", %{
        name: "Developer",
        description: "Technical terminal-inspired design",
        category: "technical",
        preview_layout: "timeline",
        color_preview: ["#059669", "#374151", "#10b981"],
        features: ["Terminal Style", "Code Friendly", "Dark Mode Ready"]
      }},
      {"designer", %{
        name: "Designer",
        description: "Creative visual portfolio",
        category: "creative",
        preview_layout: "gallery",
        color_preview: ["#7c3aed", "#ec4899", "#f59e0b"],
        features: ["Gallery Layout", "Visual Focus", "Creative Colors"]
      }},
      {"minimalist", %{
        name: "Minimalist",
        description: "Pure simplicity and focus",
        category: "minimal",
        preview_layout: "minimal",
        color_preview: ["#000000", "#666666", "#333333"],
        features: ["Ultra Clean", "No Distractions", "Typography Focus"]
      }},
      {"clean", %{
        name: "Clean",
        description: "Modern and organized",
        category: "minimal",
        preview_layout: "dashboard",
        color_preview: ["#2563eb", "#64748b", "#3b82f6"],
        features: ["Organized Layout", "Subtle Shadows", "Modern Design"]
      }},
      {"elegant", %{
        name: "Elegant",
        description: "Sophisticated and refined",
        category: "premium",
        preview_layout: "gallery",
        color_preview: ["#4c1d95", "#7c3aed", "#c084fc"],
        features: ["Luxury Feel", "Premium Typography", "Elegant Spacing"]
      }},
      {"consultant", %{
        name: "Consultant",
        description: "Strategic business presentation",
        category: "business",
        preview_layout: "corporate",
        color_preview: ["#0891b2", "#0284c7", "#6366f1"],
        features: ["Case Study Focus", "Business Layout", "Professional"]
      }},
      {"academic", %{
        name: "Academic",
        description: "Research and education focused",
        category: "academic",
        preview_layout: "minimal",
        color_preview: ["#059669", "#047857", "#10b981"],
        features: ["Publication Ready", "Research Focus", "Clean Typography"]
      }}
    ]
  end
end
