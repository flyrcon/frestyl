defmodule FrestylWeb.PortfolioLive.Edit.TemplateManager do
  @moduledoc """
  Handles template-related operations for the portfolio editor.
  """

  # Import the necessary LiveView components and functions
  import Phoenix.Component, only: [assign: 2, assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3, push_event: 3]

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.Portfolio


  def handle_template_selection(socket, %{"template" => template_name}) do
    require Logger
    Logger.info("Template selection by name: #{template_name}")

    try do
      # Get config from your PortfolioTemplates module
      template_config = Frestyl.Portfolios.PortfolioTemplates.get_template_config(template_name)

      # Convert atom keys to string keys for database storage
      template_config_strings = convert_atoms_to_strings(template_config)

      # Update portfolio in database immediately
      portfolio = socket.assigns.portfolio
      update_attrs = %{
        theme: template_name,
        customization: template_config_strings
      }

      case Portfolios.update_portfolio(portfolio, update_attrs) do
        {:ok, updated_portfolio} ->
          Logger.info("✅ Template saved to database successfully")

          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, template_config_strings)
          |> assign(:selected_template, template_name)
          |> assign(:unsaved_changes, false)
          |> maybe_update_preview_css()
          |> put_flash(:info, "Template changed to #{String.capitalize(template_name)}")

        {:error, changeset} ->
          Logger.error("❌ Failed to save template: #{inspect(changeset.errors)}")
          socket
          |> put_flash(:error, "Failed to save template changes")
      end

    rescue
      error ->
        Logger.error("Error in template selection: #{inspect(error)}")
        socket
    end
  end

  # Add this helper function
  defp convert_atoms_to_strings(map) when is_map(map) do
    map
    |> Enum.map(fn {k, v} ->
      {to_string(k), convert_atoms_to_strings(v)}
    end)
    |> Enum.into(%{})
  end

  defp convert_atoms_to_strings(value), do: value

  def handle_template_selection(socket, %{"template" => template_name}) do
    # Simple template selection without complex operations
    require Logger
    Logger.info("Template selection by name: #{template_name}")
    Logger.info("Current assigns: #{inspect(Map.keys(socket.assigns))}")

    # Check what the current customization looks like
    current_customization = socket.assigns[:customization]
    Logger.info("Current customization: #{inspect(current_customization)}")

    try do
      template_config = get_template_config_by_name(template_name)
      Logger.info("Template config generated successfully")
      Logger.info("New template config: #{inspect(template_config)}")

      updated_socket = socket
      |> assign(:customization, template_config)
      |> assign(:selected_template, template_name)
      |> assign(:current_template, template_name)
      |> assign(:unsaved_changes, true)

      # Log the updated assigns
      Logger.info("Updated customization: #{inspect(updated_socket.assigns.customization)}")
      Logger.info("Selected template: #{inspect(updated_socket.assigns.selected_template)}")

      Logger.info("Socket updated successfully")
      updated_socket

    rescue
      error ->
        Logger.error("Error in template selection: #{inspect(error)}")
        Logger.error("Stacktrace: #{inspect(__STACKTRACE__)}")
        socket
    end
  end

  def handle_template_selection(socket, %{"value" => %{"template" => template_name}}) do
    require Logger
    Logger.info("Template selection nested: #{template_name}")

    try do
      template_config = get_template_config_by_name(template_name)

      socket
      |> assign(:customization, template_config)
      |> assign(:unsaved_changes, true)

    rescue
      error ->
        Logger.error("Error in nested template selection: #{inspect(error)}")
        socket
    end
  end

  def handle_template_selection(socket, params) do
    require Logger
    Logger.warning("Template selection with unhandled params: #{inspect(params)}")
    socket
  end

  def handle_template_event(socket, "set_customization_tab", %{"tab" => tab}) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  def handle_template_event(socket, event_name, params) do
    updated_socket = case event_name do
      "select_template" ->
        handle_template_selection(socket, params)

      "set_customization_tab" ->
        tab = params["tab"] || params["value"]
        assign(socket, :active_customization_tab, tab)

      "update_color_scheme" ->
        handle_scheme_update(socket, params)

      "update_primary_color" ->
        handle_color_update(socket, %{"field" => "primary", "value" => params["color"]})

      "update_secondary_color" ->
        handle_color_update(socket, %{"field" => "secondary", "value" => params["color"]})

      "update_accent_color" ->
        handle_color_update(socket, %{"field" => "accent", "value" => params["color"]})

      "update_background" ->
        # Extract background value from different possible parameter formats
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

      "update_scheme" ->
        handle_scheme_update(socket, params)

      "update_background" ->
        handle_background_update(socket, params)

      "update_card_style" ->
        handle_card_style_update(socket, params)

      "save_template_changes" ->
        handle_save_template_changes(socket)

      "reset_customization" ->
        handle_reset_customization(socket)

      _ ->
        # Generic handler for any customization update
        handle_generic_customization_update(socket, event_name, params)
    end

    {:noreply, updated_socket}
  end

  def handle_save_template_changes(socket) do
    portfolio = socket.assigns.portfolio
    customization = socket.assigns.customization

    # Debug what we're trying to save
    IO.puts("🔥 Saving customization to database:")
    IO.inspect(customization, label: "Customization to save")

    # Also update the theme if it changed
    theme = socket.assigns[:selected_template] || portfolio.theme

    update_attrs = %{
      customization: customization,
      theme: theme
    }

    # Update the portfolio in database
    case Portfolios.update_portfolio(portfolio, update_attrs) do
      {:ok, updated_portfolio} ->
        IO.puts("🔥 Successfully saved to database")
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Template changes saved successfully")

      {:error, changeset} ->
        IO.puts("🔥 Failed to save to database")
        IO.inspect(changeset.errors, label: "Database errors")
        socket
        |> put_flash(:error, "Failed to save changes")
    end
  end

  def handle_reset_customization(socket) do
    # Reset to default config
    default_config = get_default_customization()

    socket
    |> assign(:customization, default_config)
    |> assign(:unsaved_changes, false)
    |> put_flash(:info, "Customization reset to defaults")
  end

  def update_customization_with_preview(socket, field, value) do
    customization = socket.assigns.customization
    updated_customization = put_in(customization, field, value)

    socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)
  end

  @impl true
  def handle_event("update_primary_color", %{"value" => color}, socket) do
    # Direct database update
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "primary_color", color)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("🎨 Primary color updated to: #{color}")
        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> put_flash(:info, "Primary color updated")

        {:noreply, socket}

      {:error, changeset} ->
        IO.puts("❌ Failed to update primary color")
        IO.inspect(changeset.errors)
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  @impl true
  def handle_event("update_secondary_color", %{"value" => color}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "secondary_color", color)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("🎨 Secondary color updated to: #{color}")
        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> put_flash(:info, "Secondary color updated")

        {:noreply, socket}

      {:error, changeset} ->
        IO.puts("❌ Failed to update secondary color")
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  @impl true
  def handle_event("update_accent_color", %{"value" => color}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "accent_color", color)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("🎨 Accent color updated to: #{color}")
        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> put_flash(:info, "Accent color updated")

        {:noreply, socket}

      {:error, changeset} ->
        IO.puts("❌ Failed to update accent color")
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  # Private helper functions

  defp get_template_config_by_name(template_name) do
    # Use your existing PortfolioTemplates module
    Frestyl.Portfolios.PortfolioTemplates.get_template_config(template_name)
  end

  defp handle_color_update(socket, %{"field" => field, "value" => value}) do
    update_customization_field(socket, ["colors", field], value)
  end

  defp handle_color_update(socket, %{"color" => field, "value" => value}) do
    update_customization_field(socket, ["colors", field], value)
  end

  defp handle_color_update(socket, %{"value" => color} = params) do
    # Determine which color field to update
    color_field = cond do
      params["name"] && String.contains?(params["name"], "primary") -> "primary_color"
      params["name"] && String.contains?(params["name"], "secondary") -> "secondary_color"
      params["name"] && String.contains?(params["name"], "accent") -> "accent_color"
      params["phx-value-type"] == "primary" -> "primary_color"
      params["phx-value-type"] == "secondary" -> "secondary_color"
      params["phx-value-type"] == "accent" -> "accent_color"
      params["field"] -> params["field"] <> "_color"
      true -> "primary_color" # default fallback
    end

    # Update the customization
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, color_field, color)

    # Save to database immediately
    portfolio = socket.assigns.portfolio
    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, false)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Color updated and saved")

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "❌ Color save failed")
        socket
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, true)
        |> maybe_update_preview_css()
        |> put_flash(:error, "Color updated but failed to save")
    end
  end

  # Add specific handlers for each color type
  defp handle_color_update(socket, %{"primary_color" => color}) do
    handle_single_color_update(socket, "primary_color", color)
  end

  defp handle_color_update(socket, %{"secondary_color" => color}) do
    handle_single_color_update(socket, "secondary_color", color)
  end

  defp handle_color_update(socket, %{"accent_color" => color}) do
    handle_single_color_update(socket, "accent_color", color)
  end

  defp handle_single_color_update(socket, color_field, color) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, color_field, color)

    # Save immediately
    portfolio = socket.assigns.portfolio
    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, false)
        |> maybe_update_preview_css()

      {:error, _} ->
        socket
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, true)
        |> maybe_update_preview_css()
    end
  end

  defp handle_layout_update(socket, %{"value" => layout}) do
    update_customization_field(socket, ["layout"], layout)
  end

  defp handle_typography_update(socket, %{"font" => font_name}) do
    # Update and save immediately
    socket_with_update = update_customization_field(socket, ["typography", "font_family"], font_name)

    # Save to database
    portfolio = socket_with_update.assigns.portfolio
    customization = socket_with_update.assigns.customization

    case Portfolios.update_portfolio(portfolio, %{customization: customization}) do
      {:ok, updated_portfolio} ->
        socket_with_update
        |> assign(:portfolio, updated_portfolio)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Typography updated")

      {:error, _} ->
        socket_with_update
        |> put_flash(:error, "Failed to save typography changes")
    end
  end

  defp handle_typography_update(socket, %{"field" => field, "value" => value}) do
    update_customization_field(socket, [:typography, String.to_atom(field)], value)
  end

  defp handle_typography_update(socket, %{"font_family" => font_family}) do
    update_customization_field(socket, [:typography, :font_family], font_family)
  end

  defp handle_typography_update(socket, %{"font_size" => font_size}) do
    update_customization_field(socket, [:typography, :font_size], font_size)
  end

  defp handle_typography_update(socket, %{"value" => value} = params) do
    # Handle generic typography updates
    field = params["field"] || "font_family"
    update_customization_field(socket, [:typography, String.to_atom(field)], value)
  end

  defp handle_typography_update(socket, params) do
    # Log the actual params to debug
    require Logger
    Logger.warning("Unhandled typography update with params: #{inspect(params)}")

    # Try to extract any typography-related values
    cond do
      params["font"] ->
        update_customization_field(socket, [:typography, :font_family], params["font"])
      params["typography"] ->
        # Handle nested typography object
        typography_params = params["typography"]
        if is_map(typography_params) do
          current_typography = get_in(socket.assigns.customization, [:typography]) || %{}
          updated_typography = Map.merge(current_typography, typography_params)
          update_customization_field(socket, [:typography], updated_typography)
        else
          socket
        end
      true ->
        socket
    end
  end

  defp handle_spacing_update(socket, %{"value" => spacing}) do
    update_customization_field(socket, ["spacing"], spacing)
  end

  defp handle_scheme_update(socket, %{"scheme" => scheme_name}) do
    scheme_colors = case scheme_name do
      "professional" -> %{
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6"
      }
      "creative" -> %{
        "primary_color" => "#7c3aed",
        "secondary_color" => "#ec4899",
        "accent_color" => "#f59e0b"
      }
      "warm" -> %{
        "primary_color" => "#dc2626",
        "secondary_color" => "#ea580c",
        "accent_color" => "#f59e0b"
      }
      "cool" -> %{
        "primary_color" => "#0891b2",
        "secondary_color" => "#0284c7",
        "accent_color" => "#6366f1"
      }
      "minimal" -> %{
        "primary_color" => "#374151",
        "secondary_color" => "#6b7280",
        "accent_color" => "#059669"
      }
      _ -> %{}
    end

    updated_customization = Map.merge(socket.assigns.customization || %{}, scheme_colors)

    socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)
    |> maybe_update_preview_css()
  end

  defp handle_background_update(socket, %{"background" => background}) do
    IO.puts("🔥 BACKGROUND UPDATE CALLED")
    IO.puts("🔥 New background: #{background}")
    IO.puts("🔥 Current customization: #{inspect(socket.assigns.customization)}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "background", background)

    IO.puts("🔥 Updated customization: #{inspect(updated_customization)}")

    # Save to database immediately
    portfolio = socket.assigns.portfolio
    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        IO.puts("🔥 ✅ Background saved to database successfully")
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, false)
        |> maybe_update_preview_css()
        |> put_flash(:info, "Background updated to #{String.capitalize(background)}")

      {:error, changeset} ->
        IO.puts("🔥 ❌ Failed to save background to database")
        IO.inspect(changeset.errors)
        socket
        |> assign(:customization, updated_customization)
        |> assign(:unsaved_changes, true)
        |> maybe_update_preview_css()
        |> put_flash(:error, "Background updated but failed to save")
    end
  end

  # Also handle the "value" parameter version:
  defp handle_background_update(socket, %{"value" => background}) do
    handle_background_update(socket, %{"background" => background})
  end

  defp handle_card_style_update(socket, %{"value" => card_style}) do
    update_customization_field(socket, ["card_style"], card_style)
  end

  defp handle_generic_customization_update(socket, field_name, %{"value" => value}) do
    # Convert event name to field path
    field_path = event_name_to_field_path(field_name)
    update_customization_field(socket, field_path, value)
  end

  defp handle_generic_customization_update(socket, field_name, params) do
    # Handle complex parameter structures
    case params do
      %{"field" => field, "value" => value} ->
        field_path = [field_name, field]
        update_customization_field(socket, field_path, value)

      %{"scheme" => _scheme} ->
        # Already handled by handle_scheme_update, but fallback
        socket

      %{"color" => color_field, "value" => value} ->
        update_customization_field(socket, ["colors", color_field], value)

      %{"tab" => tab} ->
        assign(socket, :active_customization_tab, tab)

      # Handle direct color assignments
      %{"primary_color" => value} ->
        update_customization_field(socket, ["colors", "primary"], value)
      %{"secondary_color" => value} ->
        update_customization_field(socket, ["colors", "secondary"], value)
      %{"accent_color" => value} ->
        update_customization_field(socket, ["colors", "accent"], value)

      _ ->
        # Log unhandled event for debugging
        require Logger
        Logger.warning("Unhandled template event: #{field_name} with params: #{inspect(params)}")
        socket
    end
  end

  defp update_customization_field(socket, field_path, value) do
    customization = socket.assigns.customization || %{}

    # Convert field path to handle both string and atom keys
    normalized_path = Enum.map(field_path, fn
      key when is_atom(key) -> Atom.to_string(key)
      key when is_binary(key) -> key
      key -> to_string(key)
    end)

    # Ensure nested maps exist before trying to put_in
    updated_customization = ensure_nested_path_exists(customization, normalized_path, value)

    socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)
    |> maybe_update_preview_css()
  end

  # Add this helper function to safely create nested paths
  defp ensure_nested_path_exists(map, path, value) do
    case path do
      [] ->
        value
      [key] ->
        Map.put(map, key, value)
      [key | rest] ->
        nested_map = Map.get(map, key, %{})
        Map.put(map, key, ensure_nested_path_exists(nested_map, rest, value))
    end
  end

  defp maybe_update_preview_css(socket) do
    customization = socket.assigns.customization
    preview_css = generate_preview_css_from_config(customization)
    assign(socket, :preview_css, preview_css)
  end

  defp generate_preview_css_from_config(config) do
    # Handle both atom and string keys from your new template structure
    primary_color = config[:primary_color] || config["primary_color"] || "#3b82f6"
    secondary_color = config[:secondary_color] || config["secondary_color"] || "#64748b"
    accent_color = config[:accent_color] || config["accent_color"] || "#f59e0b"

    # Extract typography - handle nested structure
    typography = config[:typography] || config["typography"] || %{}
    font_family = typography[:font_family] || typography["font_family"] || "Inter"
    font_size = typography[:font_size] || typography["font_size"] || "base"

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

    /* ONLY apply to preview areas and color swatches - NOT the entire interface */
    .portfolio-preview,
    .template-preview-card,
    .color-swatch-primary,
    .color-swatch-secondary,
    .color-swatch-accent,
    .portfolio-primary,
    .portfolio-secondary,
    .portfolio-accent,
    .portfolio-bg-primary,
    .portfolio-bg-secondary,
    .portfolio-bg-accent {
      color: inherit;
    }

    /* Color previews */
    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

    /* Color swatches */
    .color-swatch-primary { background-color: var(--portfolio-primary-color) !important; }
    .color-swatch-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .color-swatch-accent { background-color: var(--portfolio-accent-color) !important; }

    /* Font preview ONLY in typography preview area */
    .portfolio-preview {
      font-family: var(--portfolio-font-family) !important;
    }

    /* Template preview cards */
    .template-preview-card.border-blue-500 {
      border-color: var(--portfolio-primary-color) !important;
    }
    </style>
    """
  end

  defp event_name_to_field_path(event_name) do
    case event_name do
      "update_primary_color" -> ["colors", "primary"]
      "update_secondary_color" -> ["colors", "secondary"]
      "update_accent_color" -> ["colors", "accent"]
      "update_font_family" -> ["typography", "font_family"]
      "update_font_size" -> ["typography", "font_size"]
      _ -> [event_name]
    end
  end

  defp get_template_config_by_id(template_id) do
    # Convert template ID to name for now
    case template_id do
      "1" -> get_template_config_by_name("consultant")
      "2" -> get_template_config_by_name("academic")
      "3" -> get_template_config_by_name("creative")
      "4" -> get_template_config_by_name("designer")
      _ -> get_default_customization()
    end
  end

defp get_template_config_by_name(template_name) do
  # Get config from your PortfolioTemplates module
  config = Frestyl.Portfolios.PortfolioTemplates.get_template_config(template_name)

  # Convert to string keys for consistency
  convert_keys_to_strings(config)
end

defp convert_keys_to_strings(map) when is_map(map) do
  map
  |> Enum.map(fn {k, v} ->
    {to_string(k), convert_keys_to_strings(v)}
  end)
  |> Enum.into(%{})
end

defp convert_keys_to_strings(value), do: value

  defp get_default_customization do
    %{
      "colors" => %{
        "primary" => "#3B82F6",
        "secondary" => "#64748B",
        "accent" => "#F59E0B",
        "text" => "#1F2937",
        "background" => "#FFFFFF"
      },
      "typography" => %{
        "font_family" => "Inter",
        "font_size" => "base",
        "body_weight" => "normal",
        "heading_weight" => "normal"
      },
      "layout" => "default",
      "spacing" => "comfortable",
      "card_style" => "default"
    }
  end

  defp get_template_by_name(template_name) do
    # Map template names to template data
    # In a real app, this would query the database
    # For now, we'll create a mock template based on the name
    case template_name do
      "consultant" ->
        %{
          id: 1,
          name: "Consultant",
          description: "Professional consulting portfolio template",
          default_config: %{
            "colors" => %{
              "primary" => "#1E40AF",
              "secondary" => "#64748B",
              "accent" => "#3B82F6",
              "text" => "#0F172A",
              "background" => "#F8FAFC"
            },
            "typography" => %{
              "font_family" => "Inter",
              "font_size" => "base",
              "body_weight" => "normal",
              "heading_weight" => "semibold"
            },
            "layout" => "professional",
            "spacing" => "comfortable",
            "card_style" => "professional"
          },
          base_css: """
          .portfolio-container {
            font-family: var(--font-family);
            color: var(--text-color);
            background-color: var(--background-color);
          }
          .primary-button {
            background-color: var(--primary-color);
            color: white;
          }
          """
        }

      "academic" ->
        %{
          id: 2,
          name: "Academic",
          description: "Academic and research portfolio template",
          default_config: %{
            "colors" => %{
              "primary" => "#7C2D12",
              "secondary" => "#78716C",
              "accent" => "#DC2626",
              "text" => "#292524",
              "background" => "#FAFAF9"
            },
            "typography" => %{
              "font_family" => "Merriweather",
              "font_size" => "base",
              "body_weight" => "normal",
              "heading_weight" => "bold"
            },
            "layout" => "academic",
            "spacing" => "comfortable",
            "card_style" => "academic"
          },
          base_css: """
          .portfolio-container {
            font-family: var(--font-family);
            color: var(--text-color);
            background-color: var(--background-color);
          }
          """
        }

      "creative" ->
        %{
          id: 3,
          name: "Creative",
          description: "Creative and artistic portfolio template",
          default_config: %{
            "colors" => %{
              "primary" => "#8B5CF6",
              "secondary" => "#06B6D4",
              "accent" => "#F59E0B",
              "text" => "#1F2937",
              "background" => "#FFFFFF"
            },
            "typography" => %{
              "font_family" => "Poppins",
              "font_size" => "base",
              "body_weight" => "normal",
              "heading_weight" => "bold"
            },
            "layout" => "creative",
            "spacing" => "comfortable",
            "card_style" => "creative"
          },
          base_css: """
          .portfolio-container {
            font-family: var(--font-family);
            color: var(--text-color);
            background-color: var(--background-color);
          }
          """
        }

      _ ->
        # Try to get from database as fallback
        Portfolios.get_template_by_name(template_name)
    end
  end

  defp get_scheme_colors(scheme) do
    case scheme do
      "creative" ->
        %{
          "primary" => "#8B5CF6",
          "secondary" => "#06B6D4",
          "accent" => "#F59E0B",
          "text" => "#1F2937",
          "background" => "#FFFFFF"
        }

      "professional" ->
        %{
          "primary" => "#1E40AF",
          "secondary" => "#64748B",
          "accent" => "#3B82F6",
          "text" => "#0F172A",
          "background" => "#F8FAFC"
        }

      "academic" ->
        %{
          "primary" => "#7C2D12",
          "secondary" => "#78716C",
          "accent" => "#DC2626",
          "text" => "#292524",
          "background" => "#FAFAF9"
        }

      "minimal" ->
        %{
          "primary" => "#000000",
          "secondary" => "#6B7280",
          "accent" => "#374151",
          "text" => "#111827",
          "background" => "#FFFFFF"
        }

      _ ->
        # Default scheme
        %{
          "primary" => "#3B82F6",
          "secondary" => "#64748B",
          "accent" => "#F59E0B",
          "text" => "#1F2937",
          "background" => "#FFFFFF"
        }
    end
  end

  defp generate_simple_css(config) do
    # Return empty string instead of actual CSS to avoid showing in HTML
    ""
  end

  defp generate_css_variables(config) do
    """
    <style>
    :root {
      --primary-color: #{get_config_value(config, ["colors", "primary"], "#3B82F6")};
      --secondary-color: #{get_config_value(config, ["colors", "secondary"], "#64748B")};
      --accent-color: #{get_config_value(config, ["colors", "accent"], "#F59E0B")};
      --text-color: #{get_config_value(config, ["colors", "text"], "#1F2937")};
      --background-color: #{get_config_value(config, ["colors", "background"], "#FFFFFF")};
      --font-family: #{get_config_value(config, ["typography", "font_family"], "Inter, sans-serif")};
    }
    </style>
    """
  end

  defp replace_css_variables(css, config) do
    # Replace common CSS variables with config values
    css
    |> String.replace("var(--primary-color)", get_config_value(config, ["colors", "primary"], "#3B82F6"))
    |> String.replace("var(--secondary-color)", get_config_value(config, ["colors", "secondary"], "#10B981"))
    |> String.replace("var(--accent-color)", get_config_value(config, ["colors", "accent"], "#F59E0B"))
    |> String.replace("var(--text-color)", get_config_value(config, ["colors", "text"], "#1F2937"))
    |> String.replace("var(--background-color)", get_config_value(config, ["colors", "background"], "#FFFFFF"))
    |> String.replace("var(--font-family)", get_config_value(config, ["fonts", "primary"], "Inter, sans-serif"))
    |> String.replace("var(--font-size-base)", get_config_value(config, ["fonts", "size", "base"], "16px"))
    |> String.replace("var(--font-size-lg)", get_config_value(config, ["fonts", "size", "lg"], "18px"))
    |> String.replace("var(--font-size-xl)", get_config_value(config, ["fonts", "size", "xl"], "20px"))
    |> String.replace("var(--spacing-sm)", get_config_value(config, ["spacing", "sm"], "0.5rem"))
    |> String.replace("var(--spacing-md)", get_config_value(config, ["spacing", "md"], "1rem"))
    |> String.replace("var(--spacing-lg)", get_config_value(config, ["spacing", "lg"], "2rem"))
    |> String.replace("var(--border-radius)", get_config_value(config, ["layout", "borderRadius"], "0.5rem"))
  end

  defp get_config_value(config, path, default) do
    case get_in(config, path) do
      nil -> default
      value -> value
    end
  end

  defp normalize_template_config(config) when is_map(config), do: config
  defp normalize_template_config(_), do: %{}
end
