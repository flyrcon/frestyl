# lib/frestyl_web/live/portfolio_live/edit.ex - SIMPLIFIED WORKING VERSION

defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view

  # Import all necessary modules
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{PortfolioTemplates, Portfolio}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)

    # Verify ownership
    if portfolio.user_id != socket.assigns.current_user.id do
      raise Ecto.NoResultsError, "Portfolio not found"
    end

    # Load sections and media for the portfolio (with fallbacks)
    sections = try do
      Portfolios.list_portfolio_sections(portfolio.id)
    rescue
      _ -> []
    end

    media_files = try do
      Portfolios.list_portfolio_media(portfolio.id)
    rescue
      _ -> []
    end

    # Get current template config
    current_theme = portfolio.theme || "professional_executive"
    template_config = try do
      PortfolioTemplates.get_template_config(current_theme)
    rescue
      _ -> %{primary_color: "#3b82f6", secondary_color: "#64748b", accent_color: "#f59e0b"}
    end

    # Generate initial CSS
    initial_css = generate_portfolio_css(portfolio.customization || %{}, template_config, current_theme)

    # Create form changeset that TabRenderer expects
    form = try do
      portfolio |> Portfolios.change_portfolio() |> to_form()
    rescue
      _ -> to_form(%{})  # Fallback empty form
    end

    # FIXED: Add video intro specific assigns
    socket =
      socket
      |> assign(:page_title, "Edit Portfolio")
      |> assign(:portfolio, portfolio)
      |> assign(:sections, sections)
      |> assign(:media_files, media_files)
      |> assign(:form, form)

      # Tab management
      |> assign(:active_tab, :overview)
      |> assign(:section_edit_id, nil)
      |> assign(:section_edit_tab, "content")
      |> assign(:editing_section, nil)

      # Template management
      |> assign(:available_templates, get_safe_templates())
      |> assign(:template_config, template_config)
      |> assign(:customization, portfolio.customization || %{})
      |> assign(:selected_template, current_theme)
      |> assign(:current_template, current_theme)
      |> assign(:template_layout, get_template_layout(template_config, current_theme))
      |> assign(:preview_css, initial_css)

      # Portfolio limits
      |> assign(:limits, %{max_portfolios: -1})
      |> assign(:current_portfolio_count, 0)
      |> assign(:can_duplicate, true)
      |> assign(:duplicate_disabled_reason, nil)

      # UI state
      |> assign(:unsaved_changes, false)
      |> assign(:show_add_section_dropdown, false)
      |> assign(:show_preview, false)
      |> assign(:show_media_modal, false)
      |> assign(:show_media_library, false)
      |> assign(:media_preview_id, nil)
      |> assign(:active_customization_tab, "templates")
      |> assign(:show_resume_import_modal, false)

      # FIXED: Video intro specific state
      |> assign(:show_video_intro, false)
      |> assign(:video_intro_component_id, "video-intro-#{:rand.uniform(1000)}")
      |> assign(:preview_device, :desktop)

      # Resume handling
      |> assign(:pdf_export_status, :idle)
      |> assign(:selected_media_ids, [])
      |> assign(:media_modal_section_id, nil)
      |> assign(:resume_parsing, false)
      |> assign(:parsed_resume_data, nil)
      |> assign(:resume_parsing_error, nil)

      # Media handling
      |> assign(:resume_parsing_state, false)
      |> assign(:sections_to_import, %{})
      |> assign(:merge_options, %{})
      |> assign(:upload_progress, 0)
      |> assign(:parsing_progress, 0)
      |> assign(:import_progress, 0)
      |> assign(:resume_error_message, nil)

    {:ok, socket}
  end

  # ============================================================================
  # EVENT HANDLERS - Delegating to appropriate managers
  # ============================================================================

  # Tab switching
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  @impl true
  def handle_event("set_customization_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  @impl true
  def handle_event("set_customization_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  # Overview tab form events
  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = try do
          portfolio |> Portfolios.change_portfolio() |> to_form()
        rescue
          _ -> to_form(%{})
        end

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:form, form)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Portfolio updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update portfolio")}
    end
  end

  @impl true
  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    changeset = try do
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)
    rescue
      _ -> Ecto.Changeset.change(%Portfolio{}, portfolio_params)
    end

    {:noreply,
     socket
     |> assign(:form, to_form(changeset))
     |> assign(:unsaved_changes, true)}
  end

  @impl true
  def handle_event("duplicate_portfolio", _params, socket) do
    if socket.assigns.can_duplicate do
      case duplicate_portfolio_with_sections(socket.assigns.portfolio, socket.assigns.current_user) do
        {:ok, new_portfolio} ->
          {:noreply,
          socket
          |> put_flash(:info, "Portfolio duplicated successfully!")
          |> push_navigate(to: "/portfolios/#{new_portfolio.id}/edit")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to duplicate portfolio: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, socket.assigns.duplicate_disabled_reason)}
    end
  end

  # Simplified event handlers for missing functionality
  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, true)}
  end

  @impl true
  def handle_event("hide_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  @impl true
  def handle_event("show_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  @impl true
  def handle_event("cancel_recording", _params, socket) do
    IO.puts("=== CANCEL RECORDING EVENT IN EDIT ===")
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  @impl true
  def handle_event("camera_ready", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_ready_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("camera_error", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_error_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("video_blob_ready", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        video_blob_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("countdown_update", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        countdown_update_params: params
      )
    end
    {:noreply, socket}
  end

  @impl true
  def handle_event("recording_progress", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_progress_params: params
      )
    end
    {:noreply, socket}
  end

    @impl true
  def handle_event("recording_error", params, socket) do
    if socket.assigns.show_video_intro do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_error_params: params
      )
    end
    {:noreply, socket}
  end

    # CRITICAL: Handle close video modal message from component
  @impl true
  def handle_info({:close_video_intro_modal, _}, socket) do
    IO.puts("=== CLOSE VIDEO INTRO MODAL MESSAGE ===")
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  # CRITICAL: Handle video intro completion
  @impl true
  def handle_info({:video_intro_complete, _data}, socket) do
    # Reload sections to include new video section
    sections = try do
      Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)
    rescue
      _ -> socket.assigns.sections
    end

    {:noreply,
     socket
     |> assign(:sections, sections)
     |> assign(:show_video_intro, false)
     |> put_flash(:info, "Video introduction saved!")}
  end

  # Handle timer messages that might leak from component
  @impl true
  def handle_info({:recording_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  @impl true
  def handle_info({:countdown_tick, _component_id}, socket) do
    # Component handles its own timers, just ignore
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_portfolio", params, socket) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    socket = assign(socket, :pdf_export_status, :generating)

    pid = self()
    Task.start(fn ->
      export_opts = %{
        template: Map.get(params, "template", "resume"),
        format: Map.get(params, "format", "letter"),
        optimize_for_ats: Map.get(params, "ats_optimized", "true") == "true"
      }

      case generate_portfolio_pdf(portfolio, user, export_opts) do
        {:ok, pdf_data} ->
          send(pid, {:pdf_export_complete, pdf_data})
        {:error, reason} ->
          send(pid, {:pdf_export_error, reason})
      end
    end)

    {:noreply,
    socket
    |> put_flash(:info, "Generating PDF export... This may take up to 60 seconds.")}
  end

  @impl true
  def handle_info({:pdf_export_complete, pdf_data}, socket) do
    {:noreply,
    socket
    |> assign(:pdf_export_status, :complete)
    |> put_flash(:info, "Portfolio exported successfully!")
    |> push_event("download_pdf", %{
      filename: pdf_data.filename,
      data: Base.encode64(pdf_data.content)
    })}
  end

  @impl true
  def handle_info({:pdf_export_error, reason}, socket) do
    {:noreply,
    socket
    |> assign(:pdf_export_status, :error)
    |> put_flash(:error, "Export failed: #{reason}")}
  end

  @impl true
  def handle_event("change_preview_device", %{"device" => device}, socket) do
    {:noreply, assign(socket, :preview_device, String.to_atom(device))}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  @impl true
  def handle_event("refresh_preview", _params, socket) do
    {:noreply,
     socket
     |> push_event("refresh_portfolio_preview", %{
       timestamp: System.system_time(:millisecond)
     })}
  end

  # Portfolio settings events (simplified)
  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_atom(visibility)}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Portfolio visibility updated!")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Portfolio deleted successfully!")
         |> redirect(to: "/portfolios")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete portfolio.")}
    end
  end

  @impl true
  def handle_event("update_background", %{"background" => background}, socket) do
    IO.puts("🎛️ Updating background to: #{background}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "background", background)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:preview_css, updated_css)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Background updated to #{background}")
        |> push_event("background-updated", %{background: background})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update background")}
    end
  end

  @impl true
  def handle_event("update_layout_option", params, socket) do
    option = params["option"]

    # Extract value from multiple possible parameter sources
    value = case params do
      %{"value" => val} when val != "" -> val
      %{^option => val} when val != "" -> val
      %{"phx-value-value" => val} when val != "" -> val
      _ ->
        IO.puts("❌ No valid value found for layout option #{option}")
        IO.puts("❌ Available params: #{inspect(params)}")
        nil
    end

    # 🔥 FIX: Handle nil case properly (was causing crashes)
    case value do
      nil ->
        {:noreply, put_flash(socket, :error, "Invalid layout option value")}

      valid_value ->
        IO.puts("🎛️ Updating layout option #{option} to: #{valid_value}")

        current_customization = socket.assigns.customization || %{}
        updated_customization = Map.put(current_customization, option, valid_value)

        case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
          {:ok, portfolio} ->
            updated_css = generate_layout_css(updated_customization, nil, portfolio.theme)

            {:noreply,
            socket
            |> assign(:portfolio, portfolio)
            |> assign(:customization, updated_customization)
            |> assign(:preview_css, updated_css)
            |> assign(:unsaved_changes, false)
            |> put_flash(:info, "#{String.capitalize(option)} updated")
            |> push_event("layout-option-updated", %{option: option, value: valid_value})}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update #{option}")}
        end
    end
  end

    @impl true
  def handle_event("toggle_layout_option", params, socket) do
    option = params["option"]

    IO.puts("🎛️ Toggling layout option: #{option}")

    current_customization = socket.assigns.customization || %{}
    current_value = Map.get(current_customization, option, false)
    new_value = !current_value

    updated_customization = Map.put(current_customization, option, new_value)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> assign(:preview_css, updated_css)
         |> assign(:template_layout, get_layout_from_customization(updated_customization))
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "#{String.capitalize(option)} #{if new_value, do: "enabled", else: "disabled"}")
         |> push_event("layout-option-toggled", %{option: option, value: new_value})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to toggle layout option")}
    end
  end

  @impl true
  def handle_event("update_section_spacing", params, socket) do
    spacing = params["spacing"] || params["value"]

    IO.puts("🎛️ Updating section spacing: #{spacing}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "section_spacing", spacing)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> assign(:preview_css, updated_css)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Section spacing updated to #{spacing}")
         |> push_event("spacing-updated", %{spacing: spacing})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update section spacing")}
    end
  end

  @impl true
  def handle_event("update_font_style", params, socket) do
    font_style = params["font"] || params["value"]

    IO.puts("🎛️ Updating font style: #{font_style}")

    current_customization = socket.assigns.customization || %{}
    current_typography = Map.get(current_customization, "typography", %{})

    # Map font style to actual font family
    font_family = case font_style do
      "inter" -> "Inter"
      "merriweather" -> "Merriweather"
      "roboto" -> "Roboto"
      "jetbrains" -> "JetBrains Mono"
      "playfair" -> "Playfair Display"
      _ -> "Inter"
    end

    updated_typography = Map.put(current_typography, "font_family", font_family)
    updated_customization = Map.put(current_customization, "typography", updated_typography)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> assign(:preview_css, updated_css)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Font style updated to #{font_family}")
         |> push_event("font-style-updated", %{font_style: font_style, font_family: font_family})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update font style")}
    end
  end

  @impl true
  def handle_event("update_grid_layout", params, socket) do
    grid_layout = params["grid"] || params["value"]

    IO.puts("🎛️ Updating grid layout: #{grid_layout}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "grid_layout", grid_layout)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> assign(:preview_css, updated_css)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Grid layout updated to #{grid_layout}")
         |> push_event("grid-layout-updated", %{grid_layout: grid_layout})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update grid layout")}
    end
  end

  defp debug_socket_state(socket, event_name) do
    IO.puts("🔍 Debug #{event_name}:")
    IO.puts("  Portfolio theme: #{socket.assigns.portfolio.theme}")
    IO.puts("  Customization: #{inspect(socket.assigns.customization)}")
    IO.puts("  Sections count: #{length(socket.assigns.sections || [])}")
    socket
  end

  # Enhanced layout handling
  @impl true
  def handle_event("update_layout", params, socket) do
    layout = params["layout"] || params["value"]

    IO.puts("🎛️ Updating layout to: #{layout}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        # Generate updated CSS
        updated_css = generate_layout_css(updated_customization, layout, portfolio.theme)

        {:noreply,
        socket
        |> assign(:portfolio, portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:preview_css, updated_css)
        |> assign(:template_layout, layout)
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Layout updated to #{format_layout_name(layout)}")
        |> push_event("layout-updated", %{layout: layout})}

      {:error, changeset} ->
        IO.puts("❌ Layout update failed: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to update layout")}
    end
  end

  # Helper function to determine layout from customization
  defp get_layout_from_customization(customization) do
    case customization do
      %{"layout_style" => "single_page"} -> "single_page"
      %{"layout_style" => "multi_page"} -> "multi_page"
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> "dashboard"  # default
    end
  end

  @impl true
  def handle_event("toggle_visibility", %{"id" => section_id}, socket) do
    IO.puts("🔧 Toggle visibility clicked for ID: #{section_id}")

    try do
      section_id_int = String.to_integer(section_id)
      section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

      if section do
        case Portfolios.update_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            updated_sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            # Update editing_section if it's the same section being edited
            editing_section = if socket.assigns[:editing_section] &&
                                socket.assigns.editing_section.id == section_id_int do
              updated_section
            else
              socket.assigns[:editing_section]
            end

            visibility_text = if updated_section.visible, do: "visible", else: "hidden"

            {:noreply,
            socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, editing_section)
            |> put_flash(:info, "Section is now #{visibility_text}")
            |> push_event("section-visibility-toggled", %{
              section_id: section_id_int,
              visible: updated_section.visible
            })}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
        end
      else
        {:noreply, put_flash(socket, :error, "Section not found")}
      end
    rescue
      error ->
        IO.puts("❌ Toggle visibility error: #{Exception.message(error)}")
        {:noreply, put_flash(socket, :error, "Failed to toggle visibility")}
    end
  end


  @impl true
  def handle_event("close_add_section_dropdown", _params, socket) do
    IO.puts("🔧 Closing add section dropdown")
    {:noreply, assign(socket, :show_add_section_dropdown, false)}
  end

  @impl true
  def handle_event("switch_section_edit_tab", %{"tab" => tab}, socket) do
    IO.puts("🔧 Switching section edit tab to: #{tab}")
    {:noreply, assign(socket, :section_edit_tab, tab)}
  end

  # 🔥 FIX: Catch-all for any other unhandled section events
  @impl true
  def handle_event(event_name, params, socket) when is_binary(event_name) do
    IO.puts("🔧 UNHANDLED EVENT: #{event_name}")
    IO.puts("🔧 Params: #{inspect(params)}")

    # Try to match common patterns
    cond do
      String.starts_with?(event_name, "section_") ->
        IO.puts("🔧 Section-related event, you may need to add a handler for: #{event_name}")

      String.starts_with?(event_name, "media_") ->
        IO.puts("🔧 Media-related event, you may need to add a handler for: #{event_name}")

      String.starts_with?(event_name, "template_") ->
        IO.puts("🔧 Template-related event, you may need to add a handler for: #{event_name}")

      true ->
        IO.puts("🔧 Truly unknown event: #{event_name}")
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_section_media_library", params, socket) do
    # Handle both "section-id" and "section_id" parameter formats
    section_id = params["section_id"] || params["section-id"]

    IO.puts("🔧 Show media library for section: #{section_id}")
    IO.puts("🔧 Full params: #{inspect(params)}")

    if section_id do
      try do
        section_id_int = String.to_integer(section_id)
        section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

        if section do
          portfolio_media = try do
            Portfolios.list_portfolio_media(socket.assigns.portfolio.id)
          rescue
            _ -> []
          end

          section_media = try do
            Portfolios.list_section_media(section_id_int)
          rescue
            _ -> []
          end

          {:noreply,
          socket
          |> assign(:show_media_library, true)
          |> assign(:media_modal_section_id, section_id)
          |> assign(:portfolio_media, portfolio_media)
          |> assign(:section_media, section_media)
          |> assign(:selected_media_ids, [])
          |> put_flash(:info, "Media library opened for section: #{section.title}")}
        else
          {:noreply, put_flash(socket, :error, "Section not found")}
        end
      rescue
        error ->
          IO.puts("❌ Show media library error: #{Exception.message(error)}")
          {:noreply, put_flash(socket, :error, "Failed to open media library")}
      end
    else
      {:noreply, put_flash(socket, :error, "No section ID provided")}
    end
  end

  # Media upload handling
  @impl true
  def handle_event("upload_section_media", params, socket) do
    section_id = params["section_id"] || socket.assigns.media_modal_section_id

    if section_id do
      section_id_int = String.to_integer(section_id)

      uploaded_files = consume_uploaded_entries(socket, :media, fn %{path: path}, entry ->
        upload_media_file_to_section(path, entry, section_id_int, socket.assigns.portfolio.id)
      end)

      case uploaded_files do
        [] ->
          {:noreply, put_flash(socket, :info, "Processing uploaded files...")}

        results ->
          successful_uploads = Enum.count(results, fn
            {:ok, _} -> true
            _ -> false
          end)

          if successful_uploads > 0 do
            # Reload media lists
            portfolio_media = try do
              Portfolios.list_portfolio_media(socket.assigns.portfolio.id)
            rescue
              _ -> socket.assigns.portfolio_media || []
            end

            section_media = try do
              Portfolios.list_section_media(section_id_int)
            rescue
              _ -> socket.assigns.section_media || []
            end

            {:noreply,
            socket
            |> assign(:portfolio_media, portfolio_media)
            |> assign(:section_media, section_media)
            |> put_flash(:info, "Successfully uploaded #{successful_uploads} files!")}
          else
            {:noreply, put_flash(socket, :error, "Failed to upload files")}
          end
      end
    else
      {:noreply, put_flash(socket, :error, "No section selected for media upload")}
    end
  end

  @impl true
  def handle_event("validate_media_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_section_media_library", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_media_library, false)
    |> assign(:media_modal_section_id, nil)
    |> assign(:portfolio_media, [])
    |> assign(:section_media, [])
    |> assign(:selected_media_ids, [])}
  end

  @impl true
  def handle_event("toggle_media_selection", %{"media_id" => media_id}, socket) do
    media_id_int = String.to_integer(media_id)
    selected_ids = socket.assigns.selected_media_ids || []

    new_selected_ids = if media_id_int in selected_ids do
      List.delete(selected_ids, media_id_int)
    else
      [media_id_int | selected_ids]
    end

    {:noreply, assign(socket, :selected_media_ids, new_selected_ids)}
  end

  # Section visibility toggle
  @impl true
  def handle_event("toggle_section_visibility", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      case Portfolios.update_section(section, %{visible: !section.visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          {:noreply,
           socket
           |> assign(:sections, updated_sections)
           |> put_flash(:info, "Section visibility updated!")}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_section_edit", _params, socket) do
    {:noreply, assign(socket, :section_edit_id, nil)}
  end

  # Resume upload and parsing
  @impl true
  def handle_event("upload_resume", _params, socket) do
    uploaded_files = consume_uploaded_entries(socket, :resume, fn %{path: path}, entry ->
      case File.read(path) do
        {:ok, content} ->
          parse_resume_content(content, entry.client_type, entry.client_name)
        {:error, reason} ->
          {:error, "Failed to read file: #{inspect(reason)}"}
      end
    end)

    case uploaded_files do
      [{:ok, parsed_data}] ->
        {:noreply,
        socket
        |> assign(:parsed_resume_data, parsed_data)
        |> assign(:parsing_resume, false)
        |> put_flash(:info, "Resume parsed successfully! Review sections below.")}

      [{:error, reason}] ->
        {:noreply,
        socket
        |> assign(:parsing_resume, false)
        |> put_flash(:error, "Failed to parse resume: #{reason}")}

      [] ->
        {:noreply, assign(socket, :parsing_resume, true)}
    end
  end

  @impl true
  def handle_event("import_resume_sections", params, socket) do
    case socket.assigns.parsed_resume_data do
      nil ->
        {:noreply, put_flash(socket, :error, "No resume data to import")}

      parsed_data ->
        case import_selected_sections(socket.assigns.portfolio, parsed_data, params) do
          {:ok, imported_count} ->
            updated_sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

            {:noreply,
            socket
            |> assign(:sections, updated_sections)
            |> assign(:show_resume_import_modal, false)
            |> assign(:parsed_resume_data, nil)
            |> put_flash(:info, "Successfully imported #{imported_count} sections!")}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to import: #{reason}")}
        end
    end
  end

  def handle_event("video_uploaded", %{"section_id" => section_id} = params, socket) do
    # Your existing video upload logic here...
    # [Keep existing upload code]

    # 🔥 NEW: Apply video header configuration after successful upload
    video_section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if video_section && is_video_intro_section?(video_section) do
      IO.puts("🔥 Video uploaded to intro section - applying header config")
      socket = apply_video_header_config(socket, video_section)

      # Also update the template layout to support video
      socket = assign(socket, :template_layout, "video_enhanced")

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("activate_video_header", %{"section_id" => section_id}, socket) do
    video_section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if video_section do
      socket = apply_video_header_config(socket, video_section)
      {:noreply, put_flash(socket, :info, "Video header activated for #{socket.assigns.portfolio.theme} theme")}
    else
      {:noreply, put_flash(socket, :error, "Video section not found")}
    end
  end

  defp apply_video_header_config(socket, video_section) do
    current_portfolio = socket.assigns.portfolio
    current_theme = current_portfolio.theme || "executive"

    IO.puts("🔥 APPLYING VIDEO HEADER CONFIG for theme: #{current_theme}")

    # Get current template configuration
    template_config = get_template_config_with_video_support(current_theme)

    # Update customization to include video header config
    current_customization = current_portfolio.customization || %{}

    updated_customization = current_customization
      |> Map.merge(template_config["customization"] || %{})
      |> Map.put("has_video_intro", true)
      |> Map.put("video_style", get_video_style_for_theme(current_theme))
      |> Map.put("header_layout", "video_enhanced")

    IO.puts("🔥 Updated customization keys: #{inspect(Map.keys(updated_customization))}")

    # Update portfolio with enhanced config
    case Portfolios.update_portfolio(current_portfolio, %{
      customization: updated_customization
    }) do
      {:ok, updated_portfolio} ->
        IO.puts("✅ Video header config applied successfully!")
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:has_video_intro, true)
        |> push_event("video_header_activated", %{
          video_style: get_video_style_for_theme(current_theme),
          theme: current_theme
        })

      {:error, changeset} ->
        IO.puts("❌ Failed to apply video header config: #{inspect(changeset.errors)}")
        put_flash(socket, :error, "Failed to activate video header configuration")
    end
  end

  defp format_layout_name(layout) do
    case layout do
      "dashboard" -> "Dashboard"
      "gallery" -> "Gallery"
      "timeline" -> "Timeline"
      "minimal" -> "Minimal"
      "terminal" -> "Terminal"
      "case_study" -> "Case Study"
      "academic" -> "Academic"
      _ -> String.capitalize(layout || "Dashboard")
    end
  end

  defp generate_layout_css(customization, layout, theme) do
    # Generate CSS based on layout and customization
    primary_color = Map.get(customization, "primary_color", "#3b82f6")
    secondary_color = Map.get(customization, "secondary_color", "#64748b")
    accent_color = Map.get(customization, "accent_color", "#f59e0b")

    layout_styles = case layout do
      "dashboard" -> """
        .portfolio-container { display: grid; grid-template-columns: 1fr; gap: 2rem; }
        .portfolio-section { background: white; border-radius: 8px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        """
      "gallery" -> """
        .portfolio-container { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; }
        .portfolio-section { break-inside: avoid; margin-bottom: 1rem; }
        """
      "terminal" -> """
        .portfolio-container { background: #1a1a1a; color: #00ff00; font-family: 'Courier New', monospace; padding: 1rem; }
        .portfolio-section { border: 1px solid #00ff00; padding: 1rem; margin-bottom: 1rem; background: rgba(0,255,0,0.05); }
        """
      "minimal" -> """
        .portfolio-container { max-width: 800px; margin: 0 auto; padding: 2rem; }
        .portfolio-section { border-bottom: 1px solid #eee; padding: 2rem 0; }
        .portfolio-section:last-child { border-bottom: none; }
        """
      _ -> ""
    end

    """
    <style>
    :root {
      --portfolio-primary: #{primary_color};
      --portfolio-secondary: #{secondary_color};
      --portfolio-accent: #{accent_color};
    }

    #{layout_styles}

    .portfolio-primary { color: var(--portfolio-primary); }
    .portfolio-secondary { color: var(--portfolio-secondary); }
    .portfolio-accent { color: var(--portfolio-accent); }
    </style>
    """
  end

  defp get_fallback_template_config(theme) do
    %{
      "primary_color" => "#3b82f6",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "layout" => "dashboard",
      "typography" => %{
        "font_family" => "Inter"
      }
    }
  end

  defp get_template_config_with_video_support(theme) do
    base_config = Frestyl.Portfolios.PortfolioTemplates.get_template_config(theme)

    # Enhance base config with video-specific header settings
    enhanced_header_config = %{
      show_video: true,
      video_style: get_video_style_for_theme(theme),
      show_social: base_config.header_config.show_social || true,
      show_metrics: base_config.header_config.show_metrics || false,
      layout_adjustment: "video_hero"
    }

    Map.put(base_config, :header_config, enhanced_header_config)
  end

  defp is_video_intro_section?(section) do
    result = case section do
      # Check section type and content
      %{section_type: :media_showcase, content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      %{section_type: "media_showcase", content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      # Check by title
      %{title: "Video Introduction"} ->
        true

      %{title: title} when is_binary(title) ->
        title_lower = String.downcase(title)
        String.contains?(title_lower, "video") and
        (String.contains?(title_lower, "intro") or String.contains?(title_lower, "introduction"))

      # Check if content has video_type
      %{content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      _ ->
        false
    end

    if result do
      IO.puts("🔥 SECTION IS VIDEO INTRO: #{section.title} (#{section.section_type})")
      IO.puts("🔥 CONTENT KEYS: #{inspect(Map.keys(section.content || %{}))}")
    end

    result
  end

  @impl true
  def handle_event("toggle_video_visibility", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)

    case Frestyl.Portfolios.SectionPositioning.toggle_section_visibility(section_id_int) do
      {:ok, updated_section} ->
        updated_sections = Enum.map(socket.assigns.sections, fn section ->
          if section.id == section_id_int, do: updated_section, else: section
        end)

        message = if updated_section.visible do
          "Video is now visible in your portfolio"
        else
          "Video is now hidden from your portfolio"
        end

        socket =
          socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, message)

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to update video visibility: #{reason}")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("show_video_position_modal", %{"section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      socket =
        socket
        |> assign(:show_video_position_modal, true)
        |> assign(:selected_video_section, section)

      {:noreply, socket}
    else
      socket = put_flash(socket, :error, "Video section not found")
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_video_position", %{"position" => position, "section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    portfolio_id = socket.assigns.portfolio.id

    case Frestyl.Portfolios.SectionPositioning.update_video_section_position(portfolio_id, section_id_int, position) do
      {:ok, updated_section} ->
        updated_sections = Enum.map(socket.assigns.sections, fn section ->
          if section.id == section_id_int, do: updated_section, else: section
        end)

        socket =
          socket
          |> assign(:sections, updated_sections)
          |> assign(:show_video_position_modal, false)
          |> put_flash(:info, "Video position updated to #{get_position_name(position)}")

        {:noreply, socket}

      {:error, reason} ->
        socket = put_flash(socket, :error, "Failed to update video position: #{reason}")
        {:noreply, socket}
    end
  end


  defp get_video_style_for_theme(theme) do
    case theme do
      "executive" -> "professional"
      "professional_executive" -> "executive"
      "creative_artistic" -> "artistic"
      "creative_designer" -> "showcase"
      "technical_developer" -> "terminal"
      "technical_engineer" -> "technical"
      "minimalist_clean" -> "minimal"
      "minimalist_elegant" -> "elegant"
      _ -> "professional"
    end
  end

  defp get_video_style_classes(header_config) do
    case header_config["video_style"] do
      "minimal" -> "rounded-lg border border-gray-200"
      "elegant" -> "rounded-xl border border-slate-200 shadow-lg"
      "professional" -> "rounded-xl border border-blue-200 shadow-xl"
      "executive" -> "rounded-xl border border-slate-300 shadow-2xl"
      "artistic" -> "rounded-2xl border-2 border-purple-300 shadow-2xl"
      "showcase" -> "rounded-2xl border border-indigo-200 shadow-xl"
      "terminal" -> "rounded-lg border border-green-500 shadow-lg"
      "technical" -> "rounded-lg border border-cyan-400 shadow-lg"
      _ -> "rounded-xl border border-gray-200 shadow-lg"
    end
  end

  # Helper functions
  defp get_default_title_for_type(type) do
    case type do
      "intro" -> "Introduction"
      "experience" -> "Professional Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "projects" -> "Projects"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "achievements" -> "Achievements"
      "testimonial" -> "Testimonials"
      "media_showcase" -> "Media Gallery"
      "code_showcase" -> "Code Showcase"
      "contact" -> "Contact Information"
      "story" -> "My Story"
      "timeline" -> "Career Timeline"
      "narrative" -> "My Journey"
      "journey" -> "Professional Journey"

      "custom" -> "Custom Section"
      _ -> "New Section"
    end
  end

  defp get_default_content_for_type(type) do
    case type do
      # Basic sections
      "intro" -> %{
        "headline" => "Hello, I'm [Your Name]",
        "summary" => "A brief introduction about yourself and your professional journey.",
        "location" => "",
        "email" => "",
        "phone" => "",
        "website" => "",
        "social_links" => %{
          "linkedin" => "",
          "github" => "",
          "twitter" => ""
        }
      }

      "experience" -> %{
        "jobs" => [
          %{
            "title" => "Your Position",
            "company" => "Company Name",
            "start_date" => "Month Year",
            "end_date" => "Present",
            "current" => true,
            "description" => "Key responsibilities and achievements in this role.",
            "location" => "City, State",
            "achievements" => []
          }
        ]
      }

      "education" -> %{
        "education" => [
          %{
            "institution" => "School Name",
            "degree" => "Degree Type",
            "field" => "Field of Study",
            "start_date" => "Year",
            "end_date" => "Year",
            "gpa" => "",
            "achievements" => [],
            "description" => ""
          }
        ]
      }

      "skills" -> %{
        "skills" => ["Skill 1", "Skill 2", "Skill 3"],
        "skill_categories" => %{
          "Technical" => ["Programming", "Software Development"],
          "Soft Skills" => ["Communication", "Leadership"],
          "Tools" => ["Tool 1", "Tool 2"]
        }
      }

      "projects" -> %{
        "projects" => [
          %{
            "title" => "Project Name",
            "description" => "Brief description of the project and your role.",
            "technologies" => ["Tech 1", "Tech 2"],
            "url" => "",
            "github_url" => "",
            "start_date" => "Month Year",
            "end_date" => "Month Year",
            "status" => "completed"
          }
        ]
      }

      "featured_project" -> %{
        "title" => "Featured Project Title",
        "description" => "Detailed description of your most important project.",
        "technologies" => ["Technology 1", "Technology 2", "Technology 3"],
        "url" => "",
        "github_url" => "",
        "challenges" => "Key challenges you overcame",
        "solutions" => "How you solved them",
        "results" => "The impact and outcomes",
        "duration" => "Project timeline",
        "role" => "Your role in the project"
      }

      "case_study" -> %{
        "title" => "Case Study Title",
        "client" => "Client or Company Name",
        "timeline" => "Project duration",
        "overview" => "Brief overview of the project",
        "challenge" => "The problem you were solving",
        "solution" => "Your approach and methodology",
        "results" => "Outcomes and impact",
        "technologies" => ["Tech 1", "Tech 2"],
        "lessons_learned" => "Key takeaways from the project"
      }

      "achievements" -> %{
        "achievements" => [
          %{
            "title" => "Achievement Title",
            "description" => "Description of the achievement",
            "date" => "Date",
            "organization" => "Awarding organization",
            "category" => "Type of achievement"
          }
        ]
      }

      "testimonial" -> %{
        "testimonials" => [
          %{
            "name" => "Client Name",
            "position" => "Their Title",
            "company" => "Company Name",
            "content" => "What they said about working with you",
            "rating" => 5,
            "project" => "Related project",
            "date" => "Date of testimonial"
          }
        ]
      }

      "media_showcase" -> %{
        "title" => "Media Gallery",
        "description" => "Showcase of visual work, photos, videos, and other media.",
        "media_items" => [],
        "layout" => "grid",
        "captions_enabled" => true,
        "what_to_notice" => "Key elements viewers should pay attention to.",
        "techniques_used" => ["Photography", "Video Editing", "Graphic Design"]
      }

      "code_showcase" -> %{
        "title" => "Code Example",
        "description" => "Demonstration of coding skills and problem-solving approach.",
        "language" => "JavaScript",
        "code" => "// Your code example here\nfunction example() {\n  return 'Hello, World!';\n}",
        "key_features" => [
          "Clean, readable code structure",
          "Efficient algorithm implementation"
        ],
        "explanation" => "Detailed explanation of the code logic and design decisions.",
        "line_highlights" => [],
        "repository_url" => ""
      }

      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "availability" => "Available for new opportunities",
        "preferred_contact" => "email",
        "timezone" => "",
        "response_time" => "Within 24 hours",
        "social_links" => %{
          "linkedin" => "",
          "github" => "",
          "twitter" => "",
          "website" => ""
        }
      }

      # NEW: Story & Narrative sections
      "story" -> %{
        "title" => "My Story",
        "narrative" => "Tell your professional journey in a compelling narrative format. Share the experiences, challenges, and achievements that have shaped your career.",
        "chapters" => [
          %{
            "title" => "The Beginning",
            "content" => "Where your professional story starts - your first inspiration, education, or entry into your field.",
            "year" => "2020"
          },
          %{
            "title" => "Growth & Learning",
            "content" => "Key milestones, projects, and experiences that contributed to your professional development.",
            "year" => "2022"
          },
          %{
            "title" => "Today & Future",
            "content" => "Where you are now and where you're heading in your career journey.",
            "year" => "2024"
          }
        ]
      }

      "timeline" -> %{
        "title" => "Career Timeline",
        "description" => "A chronological overview of my professional journey",
        "events" => [
          %{
            "date" => "2024",
            "title" => "Current Position",
            "description" => "Your current role and recent achievements",
            "type" => "work"
          },
          %{
            "date" => "2022",
            "title" => "Career Milestone",
            "description" => "A significant achievement or career change",
            "type" => "achievement"
          },
          %{
            "date" => "2020",
            "title" => "Professional Start",
            "description" => "Beginning of your professional journey",
            "type" => "education"
          }
        ]
      }

      "narrative" -> %{
        "title" => "My Journey",
        "subtitle" => "The story behind my professional path",
        "narrative" => "Every professional has a unique story. Mine began with...\n\nShare your personal narrative here, including the challenges you've overcome, the lessons you've learned, and the passion that drives your work.\n\nThis is your space to connect with others on a human level and show the person behind the professional achievements."
      }

      "journey" -> %{
        "title" => "Professional Journey",
        "introduction" => "My path to where I am today",
        "milestones" => [
          %{
            "title" => "Discovery",
            "description" => "How I discovered my passion for this field",
            "impact" => "What this meant for my career direction"
          },
          %{
            "title" => "Development",
            "description" => "Key experiences that shaped my skills",
            "impact" => "How these experiences transformed my approach"
          },
          %{
            "title" => "Mastery",
            "description" => "Reaching new levels of expertise",
            "impact" => "The difference I can make now"
          }
        ]
      }

      "custom" -> %{
        "title" => "Custom Section",
        "content" => "Add your custom content here.",
        "layout" => "default",
        "custom_fields" => %{}
      }

      _ -> %{}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  defp get_template_layout(config, theme) do
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      _ ->
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

  defp apply_template_header_config(portfolio, template_config) do
    header_config = template_config["header_config"] || %{}

    # Apply video styling based on template
    video_classes = case header_config["video_style"] do
      "minimal" -> "rounded-lg border border-gray-200"
      "executive" -> "rounded-xl border border-slate-300 shadow-2xl"
      "artistic" -> "rounded-2xl border-2 border-purple-300 shadow-2xl"
      _ -> "rounded-xl border border-gray-200 shadow-lg"
    end

    # Update customization to include header config
    Map.merge(portfolio.customization || %{}, %{
      "header_config" => header_config,
      "video_classes" => video_classes
    })
  end

  defp format_section_title(section_type) do
    case section_type do
      "intro" -> "Introduction"
      "experience" -> "Work Experience"
      "education" -> "Education"
      "skills" -> "Skills & Expertise"
      "featured_project" -> "Featured Project"
      "case_study" -> "Case Study"
      "media_showcase" -> "Media Gallery"
      "projects" -> "Projects"
      "achievements" -> "Achievements"
      "testimonial" -> "Testimonials"
      "contact" -> "Contact Information"
      "code_showcase" -> "Code Examples"
      "custom" -> "Custom Section"
      _ -> String.capitalize(String.replace(section_type, "_", " "))
    end
  end

  defp get_available_templates_with_config do
    [
      {"executive", %{
        name: "Executive",
        description: "Professional corporate portfolio with dashboard layout",
        category: "business",
        color_preview: ["#1e40af", "#64748b", "#3b82f6"],
        features: ["Dashboard Layout", "Corporate Styling", "Professional Typography", "Metrics Display"]
      }},
      {"developer", %{
        name: "Developer",
        description: "Technical portfolio with terminal-inspired design",
        category: "technical",
        color_preview: ["#059669", "#374151", "#10b981"],
        features: ["Terminal Style", "Code Showcase", "Dark Theme", "Technical Layout"]
      }},
      {"designer", %{
        name: "Designer",
        description: "Creative visual portfolio with gallery layout",
        category: "creative",
        color_preview: ["#7c3aed", "#ec4899", "#f59e0b"],
        features: ["Gallery Layout", "Visual Focus", "Creative Colors", "Portfolio Showcase"]
      }},
      {"minimalist", %{
        name: "Minimalist",
        description: "Ultra-clean design focused on content and typography",
        category: "minimal",
        color_preview: ["#000000", "#666666", "#333333"],
        features: ["Minimal Design", "Typography Focus", "Clean Layout", "Distraction-Free"]
      }},
      {"clean", %{
        name: "Clean",
        description: "Modern organized layout with subtle visual elements",
        category: "modern",
        color_preview: ["#2563eb", "#64748b", "#3b82f6"],
        features: ["Modern Design", "Organized Grid", "Subtle Shadows", "Professional"]
      }},
      {"elegant", %{
        name: "Elegant",
        description: "Sophisticated design with premium typography and spacing",
        category: "premium",
        color_preview: ["#4c1d95", "#7c3aed", "#c084fc"],
        features: ["Luxury Design", "Premium Typography", "Elegant Spacing", "Sophisticated"]
      }},
      {"consultant", %{
        name: "Consultant",
        description: "Business-focused design for case studies and presentations",
        category: "business",
        color_preview: ["#0891b2", "#0284c7", "#6366f1"],
        features: ["Case Studies", "Business Layout", "Professional", "Structured"]
      }},
      {"academic", %{
        name: "Academic",
        description: "Research-focused design for publications and education",
        category: "academic",
        color_preview: ["#059669", "#047857", "#10b981"],
        features: ["Publication Ready", "Research Focus", "Clean Typography", "Academic Style"]
      }}
    ]
  end

  defp get_template_preview_bg(template_config) do
    case template_config.category do
      "business" -> "linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%)"
      "technical" -> "linear-gradient(135deg, #1f2937 0%, #374151 100%)"
      "creative" -> "linear-gradient(135deg, #fdf2f8 0%, #fce7f3 100%)"
      "minimal" -> "#ffffff"
      "modern" -> "linear-gradient(135deg, #f0f9ff 0%, #e0f2fe 100%)"
      "premium" -> "linear-gradient(135deg, #faf5ff 0%, #f3e8ff 100%)"
      "academic" -> "linear-gradient(135deg, #f0fdfa 0%, #ccfbf1 100%)"
      _ -> "linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%)"
    end
  end

  defp render_template_preview_content(template_key, template_config) do
    case template_key do
      "executive" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full flex flex-col justify-between">
          <div class="space-y-2">
            <div class="h-2 bg-blue-600 rounded w-3/4"></div>
            <div class="h-1 bg-blue-400 rounded w-1/2"></div>
          </div>
          <div class="grid grid-cols-3 gap-1">
            <div class="h-6 bg-blue-200 rounded"></div>
            <div class="h-6 bg-blue-300 rounded"></div>
            <div class="h-6 bg-blue-200 rounded"></div>
          </div>
        </div>
        """)

      "developer" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full bg-gray-900 text-green-400 font-mono text-xs">
          <div class="space-y-1">
            <div class="text-green-500">$ whoami</div>
            <div class="text-green-300">developer</div>
            <div class="text-green-500">$ ls -la projects/</div>
            <div class="text-green-300">portfolio.js</div>
            <div class="text-green-300">awesome-app.py</div>
          </div>
        </div>
        """)

      "designer" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full">
          <div class="grid grid-cols-2 gap-2 h-full">
            <div class="bg-purple-400 rounded-lg"></div>
            <div class="space-y-2">
              <div class="bg-pink-400 rounded h-1/2"></div>
              <div class="bg-orange-400 rounded h-1/3"></div>
            </div>
          </div>
        </div>
        """)

      "minimalist" ->
        Phoenix.HTML.raw("""
        <div class="p-6 h-full flex flex-col justify-center items-center space-y-3">
          <div class="h-1 bg-black rounded w-16"></div>
          <div class="h-1 bg-gray-600 rounded w-12"></div>
          <div class="h-1 bg-gray-400 rounded w-14"></div>
        </div>
        """)

      "clean" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full">
          <div class="space-y-3">
            <div class="h-2 bg-blue-500 rounded w-full"></div>
            <div class="grid grid-cols-2 gap-2">
              <div class="h-8 bg-blue-100 rounded shadow-sm"></div>
              <div class="h-8 bg-blue-100 rounded shadow-sm"></div>
            </div>
            <div class="h-6 bg-blue-50 rounded"></div>
          </div>
        </div>
        """)

      "elegant" ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full bg-gradient-to-br from-purple-50 to-purple-100">
          <div class="space-y-4 text-center">
            <div class="h-2 bg-purple-600 rounded w-20 mx-auto"></div>
            <div class="space-y-1">
              <div class="h-1 bg-purple-400 rounded w-16 mx-auto"></div>
              <div class="h-1 bg-purple-300 rounded w-12 mx-auto"></div>
            </div>
            <div class="w-8 h-8 bg-purple-600 rounded-full mx-auto"></div>
          </div>
        </div>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <div class="p-4 h-full flex items-center justify-center">
          <div class="w-8 h-8 bg-gray-400 rounded"></div>
        </div>
        """)
    end
  end

  defp render_video_intro_modal(assigns) do
    ~H"""
    <%= if @show_video_intro do %>
      <div class="fixed inset-0 z-50 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" phx-click="hide_video_intro"></div>

          <span class="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>

          <div class="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-6xl sm:w-full">
            <.live_component
              module={FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent}
              id={"enhanced-video-intro-#{@portfolio.id}"}
              portfolio={@portfolio}
              current_user={@current_user}
            />
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_section_with_video_controls(assigns) do
    ~H"""
    <div class="section-item bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow">
      <div class="p-4">
        <div class="flex items-center justify-between mb-3">
          <div class="flex items-center">
            <!-- Section Thumbnail/Icon -->
            <div class="w-12 h-12 rounded-lg overflow-hidden mr-3 bg-gray-100 flex items-center justify-center">
              <%= if @section.section_type == :media_showcase and get_in(@section.content, ["video_type"]) == "introduction" do %>
                <%= if get_in(@section.content, ["thumbnail", "url"]) do %>
                  <img src={get_in(@section.content, ["thumbnail", "url"])} alt="Video thumbnail" class="w-full h-full object-cover" />
                <% else %>
                  <svg class="w-6 h-6 text-purple-600" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                  </svg>
                <% end %>
              <% else %>
                <span class="text-2xl"><%= get_section_icon(@section.section_type) %></span>
              <% end %>
            </div>

            <div>
              <h3 class="font-medium text-gray-900"><%= @section.title %></h3>
              <p class="text-sm text-gray-500">
                <%= if @section.section_type == :media_showcase and get_in(@section.content, ["video_type"]) == "introduction" do %>
                  Video Introduction • <%= get_in(@section.content, ["quality"]) || "HD" %> •
                  Position: <%= get_position_name(get_in(@section.content, ["position"]) || "hero") %>
                <% else %>
                  <%= format_section_type(@section.section_type) %>
                <% end %>
              </p>
            </div>
          </div>

          <!-- Section Controls -->
          <div class="flex items-center space-x-2">
            <!-- Visibility Toggle for Video Sections -->
            <%= if @section.section_type == :media_showcase and get_in(@section.content, ["video_type"]) == "introduction" do %>
              <button phx-click="toggle_video_visibility" phx-value-section-id={@section.id}
                      class={"p-2 rounded-lg transition-colors #{if @section.visible, do: 'text-green-600 hover:bg-green-50', else: 'text-gray-400 hover:bg-gray-50'}"}>
                <%= if @section.visible do %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                <% else %>
                  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L8.222 8.222M9.878 9.878l-.88-.88"/>
                  </svg>
                <% end %>
              </button>

              <!-- Position Settings -->
              <button phx-click="show_video_position_modal" phx-value-section-id={@section.id}
                      class="p-2 text-purple-600 hover:bg-purple-50 rounded-lg transition-colors">
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </button>
            <% end %>

            <!-- Standard Section Controls -->
            <button phx-click="edit_section" phx-value-section-id={@section.id}
                    class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>

            <button phx-click="delete_section" phx-value-section-id={@section.id}
                    class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                    data-confirm="Are you sure you want to delete this section?">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Section type label helper
  defp section_type_label(section_type) do
    case section_type do
      :intro -> "Introduction"
      :about -> "About"
      :experience -> "Experience"
      :education -> "Education"
      :skills -> "Skills"
      :projects -> "Projects"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :achievements -> "Achievements"
      :testimonial -> "Testimonials"
      :media_showcase -> "Media Showcase"
      :contact -> "Contact"
      :social -> "Social Profiles"
      :custom -> "Custom Section"
      _ when is_atom(section_type) ->
        section_type |> Atom.to_string() |> Phoenix.Naming.humanize()
      _ when is_binary(section_type) ->
        Phoenix.Naming.humanize(section_type)
      _ -> "Unknown Section"
    end
  end

  # Section color class helper
  defp section_color_class(section_type) do
    case section_type do
      :intro -> "bg-blue-500"
      :about -> "bg-green-500"
      :experience -> "bg-purple-500"
      :education -> "bg-indigo-500"
      :skills -> "bg-yellow-500"
      :projects -> "bg-red-500"
      :featured_project -> "bg-pink-500"
      :case_study -> "bg-orange-500"
      :achievements -> "bg-emerald-500"
      :testimonial -> "bg-cyan-500"
      :media_showcase -> "bg-violet-500"
      :contact -> "bg-gray-500"
      :social -> "bg-blue-400"
      :custom -> "bg-slate-500"
      _ -> "bg-gray-400"
    end
  end

  # Section gradient class helper
  defp section_gradient_class(section_type) do
    case section_type do
      :intro -> "bg-gradient-to-r from-blue-400 to-blue-600"
      :about -> "bg-gradient-to-r from-green-400 to-green-600"
      :experience -> "bg-gradient-to-r from-purple-400 to-purple-600"
      :education -> "bg-gradient-to-r from-indigo-400 to-indigo-600"
      :skills -> "bg-gradient-to-r from-yellow-400 to-yellow-600"
      :projects -> "bg-gradient-to-r from-red-400 to-red-600"
      :featured_project -> "bg-gradient-to-r from-pink-400 to-pink-600"
      :case_study -> "bg-gradient-to-r from-orange-400 to-orange-600"
      :achievements -> "bg-gradient-to-r from-emerald-400 to-emerald-600"
      :testimonial -> "bg-gradient-to-r from-cyan-400 to-cyan-600"
      :media_showcase -> "bg-gradient-to-r from-violet-400 to-violet-600"
      :contact -> "bg-gradient-to-r from-gray-400 to-gray-600"
      :social -> "bg-gradient-to-r from-blue-400 to-cyan-500"
      :custom -> "bg-gradient-to-r from-slate-400 to-slate-600"
      _ -> "bg-gradient-to-r from-gray-400 to-gray-500"
    end
  end

  # Section button class helper
  defp section_button_class(section_type) do
    case section_type do
      :intro -> "border-blue-500 text-blue-600 hover:bg-blue-500 focus:ring-blue-500"
      :about -> "border-green-500 text-green-600 hover:bg-green-500 focus:ring-green-500"
      :experience -> "border-purple-500 text-purple-600 hover:bg-purple-500 focus:ring-purple-500"
      :education -> "border-indigo-500 text-indigo-600 hover:bg-indigo-500 focus:ring-indigo-500"
      :skills -> "border-yellow-500 text-yellow-600 hover:bg-yellow-500 focus:ring-yellow-500"
      :projects -> "border-red-500 text-red-600 hover:bg-red-500 focus:ring-red-500"
      :featured_project -> "border-pink-500 text-pink-600 hover:bg-pink-500 focus:ring-pink-500"
      :case_study -> "border-orange-500 text-orange-600 hover:bg-orange-500 focus:ring-orange-500"
      :achievements -> "border-emerald-500 text-emerald-600 hover:bg-emerald-500 focus:ring-emerald-500"
      :testimonial -> "border-cyan-500 text-cyan-600 hover:bg-cyan-500 focus:ring-cyan-500"
      :media_showcase -> "border-violet-500 text-violet-600 hover:bg-violet-500 focus:ring-violet-500"
      :contact -> "border-gray-500 text-gray-600 hover:bg-gray-500 focus:ring-gray-500"
      :social -> "border-blue-400 text-blue-500 hover:bg-blue-400 focus:ring-blue-400"
      :custom -> "border-slate-500 text-slate-600 hover:bg-slate-500 focus:ring-slate-500"
      _ -> "border-gray-400 text-gray-500 hover:bg-gray-400 focus:ring-gray-400"
    end
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} B"
    end
  end
  defp format_file_size(_), do: "Unknown size"

  # Format time ago
  defp time_ago(datetime) do
    case datetime do
      %DateTime{} = dt ->
        seconds_ago = DateTime.diff(DateTime.utc_now(), dt, :second)
        format_time_difference(seconds_ago)
      %NaiveDateTime{} = ndt ->
        case DateTime.from_naive(ndt, "Etc/UTC") do
          {:ok, dt} -> time_ago(dt)
          {:error, _} -> "Unknown time"
        end
      _ -> "Unknown time"
    end
  end

  defp format_time_difference(seconds) when is_integer(seconds) do
    cond do
      seconds < 60 -> "Just now"
      seconds < 3600 -> "#{div(seconds, 60)} minutes ago"
      seconds < 86400 -> "#{div(seconds, 3600)} hours ago"
      seconds < 604800 -> "#{div(seconds, 86400)} days ago"
      true -> "#{div(seconds, 604800)} weeks ago"
    end
  end
  defp format_time_difference(_), do: "Unknown time"

  # Section icon helper
  defp section_icon(section_type) do
    case section_type do
      :intro -> "👋"
      :about -> "👤"
      :experience -> "💼"
      :education -> "🎓"
      :skills -> "⚡"
      :projects -> "🚀"
      :featured_project -> "⭐"
      :case_study -> "📊"
      :achievements -> "🏆"
      :testimonial -> "💬"
      :media_showcase -> "🎨"
      :contact -> "📞"
      :social -> "🔗"
      :custom -> "📝"
      _ -> "📄"
    end
  end

  # Validation helper for forms
  defp input_error(form, field) do
    case form.errors[field] do
      {msg, opts} -> error_to_string({msg, opts})
      msg when is_binary(msg) -> msg
      _ -> nil
    end
  end

  # Check if section has content
  defp section_has_content?(section) do
    case section.content do
      nil -> false
      content when content == %{} -> false
      content when is_map(content) ->
        content
        |> Map.values()
        |> Enum.any?(fn value ->
          case value do
            nil -> false
            "" -> false
            [] -> false
            %{} -> false
            _ -> true
          end
        end)
      _ -> true
    end
  end

  # Get section completion percentage
  defp section_completion_percentage(section) do
    case section.section_type do
      :intro ->
        content = section.content || %{}
        fields = ["headline", "summary", "location"]
        completed = Enum.count(fields, &(Map.get(content, &1) not in [nil, ""]))
        round(completed / length(fields) * 100)

      :experience ->
        jobs = get_in(section.content, ["jobs"]) || []
        if length(jobs) > 0, do: 100, else: 0

      :education ->
        education = get_in(section.content, ["education"]) || []
        if length(education) > 0, do: 100, else: 0

      :skills ->
        skills = get_in(section.content, ["skills"]) || []
        if length(skills) > 0, do: 100, else: 0

      :projects ->
        projects = get_in(section.content, ["projects"]) || []
        if length(projects) > 0, do: 100, else: 0

      :contact ->
        content = section.content || %{}
        fields = ["email", "phone", "location"]
        completed = Enum.count(fields, &(Map.get(content, &1) not in [nil, ""]))
        round(completed / length(fields) * 100)

      :social ->
        platforms = get_in(section.content, ["platforms"]) || []
        if length(platforms) > 0, do: 100, else: 0

      _ ->
        if section_has_content?(section), do: 100, else: 0
    end
  end

  # Media type icon helper
  defp media_type_icon(media_type) do
    case media_type do
      :image -> "🖼️"
      :video -> "🎥"
      :audio -> "🎵"
      :document -> "📄"
      _ -> "📎"
    end
  end

  # Truncate text helper
  defp truncate(text, length \\ 50) when is_binary(text) do
    if String.length(text) > length do
      String.slice(text, 0, length) <> "..."
    else
      text
    end
  end
  defp truncate(_, _), do: ""

  # Safe get helper for nested maps
  defp safe_get(map, keys, default \\ nil) when is_map(map) and is_list(keys) do
    Enum.reduce(keys, map, fn key, acc ->
      case acc do
        %{} -> Map.get(acc, key)
        _ -> default
      end
    end) || default
  end
  defp safe_get(_, _, default), do: default

    # ============================================================================
    # MESSAGE HANDLERS - Template component communication
    # ============================================================================

  @impl true
  def handle_info({:preview_template, template_key}, socket) do
    {:noreply,
     socket
     |> assign(:show_template_preview, true)
     |> assign(:preview_template, template_key)}
  end

  @impl true
  def handle_info({:section_updated, updated_section}, socket) do
    updated_sections = Enum.map(socket.assigns.sections, fn s ->
      if s.id == updated_section.id, do: updated_section, else: s
    end)

    {:noreply, assign(socket, :sections, updated_sections)}
  end

  # Handle file uploads (if available)
  @impl true
  def handle_info({:file_uploaded, file_info}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info(_, socket) do
    {:noreply, socket}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================
    @impl true
  def handle_event("update_color_scheme", %{"scheme" => scheme_name}, socket) do
    IO.puts("🎨 Updating color scheme to: #{scheme_name}")

    # Define color schemes
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

    # Merge with current customization
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.merge(current_customization, scheme_colors)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        # Generate updated CSS
        updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> assign(:preview_css, updated_css)
         |> assign(:unsaved_changes, false)
         |> put_flash(:info, "Color scheme updated to #{String.capitalize(scheme_name)}")
         |> push_event("color-scheme-updated", %{scheme: scheme_name})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update color scheme")}
    end
  end

  # Individual color updates
  @impl true
  def handle_event("update_primary_color", params, socket) do
    color = params["primary_color"] || params["value"]
    IO.puts("🎨 Updating primary color to: #{color}")

    update_single_color(socket, "primary_color", color)
  end

  @impl true
  def handle_event("update_secondary_color", params, socket) do
    color = params["secondary_color"] || params["value"]
    IO.puts("🎨 Updating secondary color to: #{color}")

    update_single_color(socket, "secondary_color", color)
  end

  @impl true
  def handle_event("update_accent_color", params, socket) do
    color = params["accent_color"] || params["value"]
    IO.puts("🎨 Updating accent color to: #{color}")

    update_single_color(socket, "accent_color", color)
  end

  # Generic color update handler
  @impl true
  def handle_event("update_color", params, socket) do
    color = params["color"] || params["value"]
    color_type = params["type"] || params["field"] || "primary"

    IO.puts("🎨 Generic color update: #{color_type} = #{color}")

    color_field = case color_type do
      "primary" -> "primary_color"
      "secondary" -> "secondary_color"
      "accent" -> "accent_color"
      field when field in ["primary_color", "secondary_color", "accent_color"] -> field
      _ -> "primary_color"
    end

    update_single_color(socket, color_field, color)
  end

  # Typography updates
  @impl true
  def handle_event("update_typography", params, socket) do
    IO.puts("🎨 Typography params received: #{inspect(params)}")

    # Extract font family from different possible parameter formats
    font_family = case params do
      %{"font" => font} when font != "" -> font
      %{"font_family" => font} when font != "" -> font
      %{"value" => font} when font != "" -> font
      %{"field" => "font_family", "font" => font} when font != "" -> font
      _ ->
        # Log the issue and return error
        IO.puts("❌ No valid font family found in params: #{inspect(params)}")
        nil  # Set to nil instead of using return
    end

    # Handle case where no valid font was found
    if font_family == nil do
      {:noreply, put_flash(socket, :error, "Invalid font family parameter")}
    else
      IO.puts("🎨 Updating typography to font: #{font_family}")

      # Update the typography in customization
      current_customization = socket.assigns.customization || %{}
      current_typography = Map.get(current_customization, "typography", %{})
      updated_typography = Map.put(current_typography, "font_family", font_family)
      updated_customization = Map.put(current_customization, "typography", updated_typography)

      case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
        {:ok, portfolio} ->
          # Generate updated CSS with the new font
          updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

          {:noreply,
          socket
          |> assign(:portfolio, portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:preview_css, updated_css)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Typography updated to #{font_family}")
          |> push_event("typography-updated", %{font_family: font_family})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update typography")}
      end
    end
  end

  # Helper function for updating individual colors
  defp update_single_color(socket, color_field, color) do
    if valid_hex_color?(color) do
      current_customization = socket.assigns.customization || %{}
      updated_customization = Map.put(current_customization, color_field, color)

      case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
        {:ok, portfolio} ->
          # Generate updated CSS
          updated_css = generate_portfolio_css(updated_customization, %{}, portfolio.theme)

          color_name = String.replace(color_field, "_color", "")

          {:noreply,
           socket
           |> assign(:portfolio, portfolio)
           |> assign(:customization, updated_customization)
           |> assign(:preview_css, updated_css)
           |> assign(:unsaved_changes, false)
           |> put_flash(:info, "#{String.capitalize(color_name)} color updated")
           |> push_event("color-updated", %{field: color_field, color: color})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update color")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid color format")}
    end
  end

  # Helper function to validate hex colors
  defp valid_hex_color?(color) do
    Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)
  end

  # Helper function to get color scheme colors (for existing handler)
  defp get_color_scheme_colors(scheme) do
    case scheme do
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
  end

  defp get_template_layout(config, theme) do
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      _ ->
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

  defp get_safe_templates do
    try do
      PortfolioTemplates.available_templates()
    rescue
      _ ->
        %{
          "executive" => %{name: "Executive", category: "professional"},
          "developer" => %{name: "Developer", category: "technical"},
          "designer" => %{name: "Designer", category: "creative"}
        }
    end
  end

  defp generate_portfolio_css(customization, template_config, theme) do
    primary = Map.get(customization, "primary_color", Map.get(template_config, :primary_color, "#3b82f6"))
    secondary = Map.get(customization, "secondary_color", Map.get(template_config, :secondary_color, "#64748b"))
    accent = Map.get(customization, "accent_color", Map.get(template_config, :accent_color, "#f59e0b"))

    """
    <style>
    :root {
      --primary-color: #{primary};
      --secondary-color: #{secondary};
      --accent-color: #{accent};
    }
    </style>
    """
  end

  defp get_layout_from_customization(customization) do
    # Priority: layout_style > layout > theme default
    case customization do
      %{"layout_style" => "single_page"} -> "single_page"
      %{"layout_style" => "multi_page"} -> "multi_page"
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> "dashboard"  # default fallback
    end
  end

    # Catch-all for section events (delegate to SectionManager if available)
  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔧 UNHANDLED EVENT: #{event_name}")
    IO.puts("🔧 Params: #{inspect(params)}")

    case event_name do
      # Section-related events we haven't handled yet
      "reorder_sections" ->
        IO.puts("🔧 Section reordering not implemented yet")
        {:noreply, socket}

      "duplicate_section" ->
        IO.puts("🔧 Section duplication not implemented yet")
        {:noreply, socket}

      # Media-related events
      event when event in ["show_media_modal", "hide_media_modal", "upload_media"] ->
        IO.puts("🔧 Media functionality not implemented yet")
        {:noreply, socket}

      # Events that should have been handled by specific handlers above
      event when event in ["toggle_add_section_dropdown", "close_add_section_dropdown", "edit_section", "toggle_visibility", "show_section_media_library"] ->
        IO.puts("🔧 WARNING: #{event_name} should have been handled by specific handler above!")
        {:noreply, socket}

      # Unknown events
      _ ->
        IO.puts("🔧 Truly unknown event: #{event_name}")
        {:noreply, socket}
    end
  end

    # ============================================================================
  # HELPER FUNCTIONS FOR NEW FUNCTIONALITY
  # ============================================================================

  # Resume parsing helpers
  defp parse_resume_content(content, mime_type, _filename) do
    case mime_type do
      "application/pdf" -> parse_pdf_resume(content)
      "text/plain" -> parse_text_resume(content)
      _ -> {:error, "Unsupported file type: #{mime_type}"}
    end
  end

  defp parse_pdf_resume(_content) do
    # Basic implementation - replace with actual PDF parsing
    {:ok, %{
      personal_info: %{"name" => "Extracted Name", "email" => "extracted@email.com"},
      professional_summary: "Extracted summary from PDF",
      work_experience: [],
      education: [],
      skills: []
    }}
  end

  defp parse_text_resume(content) do
    lines = String.split(content, "\n")
    {:ok, %{
      personal_info: %{"name" => "Text Resume", "email" => ""},
      professional_summary: Enum.join(Enum.take(lines, 3), " "),
      work_experience: [],
      education: [],
      skills: []
    }}
  end

  # Portfolio duplication
  defp duplicate_portfolio_with_sections(original_portfolio, user) do
    new_attrs = %{
      title: "#{original_portfolio.title} (Copy)",
      description: original_portfolio.description,
      theme: original_portfolio.theme,
      customization: original_portfolio.customization,
      visibility: :private
    }

    case Portfolios.create_portfolio(user.id, new_attrs) do
      {:ok, new_portfolio} ->
        copy_portfolio_sections(original_portfolio.id, new_portfolio.id)
        {:ok, new_portfolio}
      {:error, _changeset} ->
        {:error, "Failed to create portfolio copy"}
    end
  end

  defp copy_portfolio_sections(from_portfolio_id, to_portfolio_id) do
    sections = Portfolios.list_portfolio_sections(from_portfolio_id)

    Enum.each(sections, fn section ->
      section_attrs = %{
        portfolio_id: to_portfolio_id,
        title: section.title,
        section_type: section.section_type,
        content: section.content,
        position: section.position,
        visible: section.visible
      }
      Portfolios.create_section(section_attrs)
    end)
  end

  # Section duplication
  defp duplicate_section_with_media(section) do
    max_position = get_max_section_position(section.portfolio_id)

    new_attrs = %{
      portfolio_id: section.portfolio_id,
      title: "#{section.title} (Copy)",
      section_type: section.section_type,
      content: section.content,
      position: max_position + 1,
      visible: section.visible
    }

    case Portfolios.create_section(new_attrs) do
      {:ok, new_section} ->
        copy_section_media(section.id, new_section.id)
        {:ok, new_section}
      {:error, changeset} ->
        {:error, "Failed to duplicate section"}
    end
  end

  defp copy_section_media(from_section_id, to_section_id) do
    try do
      media_files = Portfolios.list_section_media(from_section_id)
      Enum.each(media_files, fn media ->
        Portfolios.create_section_media_association(to_section_id, media.id)
      end)
    rescue
      _ -> :ok  # Continue even if media copying fails
    end
  end

  # PDF generation
  defp generate_portfolio_pdf(portfolio, _user, _opts) do
    try do
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      html_content = render_portfolio_for_pdf(portfolio, sections)

      # Basic PDF generation - replace with actual PDF library
      case PdfGenerator.generate_binary(html_content, page_size: "Letter") do
        {:ok, pdf_binary} ->
          timestamp = DateTime.utc_now() |> DateTime.to_unix()
          filename = "#{Slug.slugify(portfolio.title)}-#{timestamp}.pdf"

          {:ok, %{
            content: pdf_binary,
            filename: filename,
            content_type: "application/pdf"
          }}
        {:error, reason} ->
          {:error, "PDF generation failed: #{inspect(reason)}"}
      end
    rescue
      error -> {:error, "PDF export error: #{Exception.message(error)}"}
    end
  end

  defp render_portfolio_for_pdf(portfolio, sections) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>#{portfolio.title}</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .section { margin-bottom: 30px; }
        .section-title { font-size: 18px; font-weight: bold; margin-bottom: 15px; }
      </style>
    </head>
    <body>
      <h1>#{portfolio.title}</h1>
      #{render_sections_for_pdf(sections)}
    </body>
    </html>
    """
  end

  defp render_sections_for_pdf(sections) do
    sections
    |> Enum.filter(& &1.visible)
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn section ->
      """
      <div class="section">
        <h2 class="section-title">#{section.title}</h2>
        <div>#{render_basic_section_content(section)}</div>
      </div>
      """
    end)
    |> Enum.join("\n")
  end

  defp render_basic_section_content(section) do
    case section.content do
      %{"summary" => summary} when is_binary(summary) -> summary
      %{"description" => desc} when is_binary(desc) -> desc
      _ -> "Section content"
    end
  end

  # Portfolio broadcasting for live updates
  defp broadcast_portfolio_update(portfolio_id, event_type) do
    try do
      Phoenix.PubSub.broadcast(
        Frestyl.PubSub,
        "portfolio:#{portfolio_id}",
        {event_type, portfolio_id}
      )
    rescue
      _ -> :ok  # Continue even if broadcast fails
    end
  end

  # Section helpers
  defp get_max_section_position(portfolio_id) do
    sections = Portfolios.list_portfolio_sections(portfolio_id)
    case sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end
  end

  defp import_selected_sections(portfolio, parsed_data, selections) do
    try do
      imported_count = Enum.reduce(selections, 0, fn {section_type, selected}, acc ->
        if selected == "true" do
          case import_resume_section(portfolio, section_type, parsed_data) do
            {:ok, _section} -> acc + 1
            {:error, _reason} -> acc
          end
        else
          acc
        end
      end)
      {:ok, imported_count}
    rescue
      error -> {:error, Exception.message(error)}
    end
  end

  defp import_resume_section(portfolio, section_type, parsed_data) do
    case section_type do
      "personal_info" -> create_contact_section(portfolio, parsed_data.personal_info)
      "professional_summary" -> create_intro_section(portfolio, parsed_data.professional_summary)
      "work_experience" -> create_experience_section(portfolio, parsed_data.work_experience)
      "education" -> create_education_section(portfolio, parsed_data.education)
      "skills" -> create_skills_section(portfolio, parsed_data.skills)
      _ -> {:error, "Unknown section type: #{section_type}"}
    end
  end

  defp create_contact_section(portfolio, personal_info) do
    max_position = get_max_section_position(portfolio.id)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Contact Information",
      section_type: :contact,
      position: max_position + 1,
      content: %{
        "email" => Map.get(personal_info, "email", ""),
        "phone" => Map.get(personal_info, "phone", ""),
        "location" => Map.get(personal_info, "location", ""),
        "name" => Map.get(personal_info, "name", "")
      },
      visible: true
    }
    Portfolios.create_section(section_attrs)
  end

  defp create_intro_section(portfolio, summary) do
    max_position = get_max_section_position(portfolio.id)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Professional Summary",
      section_type: :intro,
      position: max_position + 1,
      content: %{
        "headline" => "Professional Summary",
        "summary" => summary || ""
      },
      visible: true
    }
    Portfolios.create_section(section_attrs)
  end

  defp create_experience_section(portfolio, experience) do
    max_position = get_max_section_position(portfolio.id)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Work Experience",
      section_type: :experience,
      position: max_position + 1,
      content: %{"jobs" => experience || []},
      visible: true
    }
    Portfolios.create_section(section_attrs)
  end

  defp create_education_section(portfolio, education) do
    max_position = get_max_section_position(portfolio.id)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Education",
      section_type: :education,
      position: max_position + 1,
      content: %{"education" => education || []},
      visible: true
    }
    Portfolios.create_section(section_attrs)
  end

  defp create_skills_section(portfolio, skills) do
    max_position = get_max_section_position(portfolio.id)

    section_attrs = %{
      portfolio_id: portfolio.id,
      title: "Skills & Expertise",
      section_type: :skills,
      position: max_position + 1,
      content: %{"skills" => skills || []},
      visible: true
    }
    Portfolios.create_section(section_attrs)
  end

  # Media upload helper
  defp upload_media_file_to_section(temp_path, entry, section_id, portfolio_id) do
    try do
      # Generate unique filename
      file_extension = Path.extname(entry.client_name)
      timestamp = System.unique_integer([:positive])
      filename = "media_#{timestamp}#{file_extension}"

      # Create upload directory
      upload_dir = Path.join(["priv", "static", "uploads", "portfolios", to_string(portfolio_id), "media"])
      File.mkdir_p!(upload_dir)

      # Final file path
      final_path = Path.join(upload_dir, filename)

      # Copy file
      case File.cp(temp_path, final_path) do
        :ok ->
          # Get file info
          %{size: file_size} = File.stat!(final_path)

          # Determine media type
          media_type = determine_media_type(entry.client_type)

          # Public path for serving
          public_path = "/uploads/portfolios/#{portfolio_id}/media/#{filename}"

          # Create database record
          media_attrs = %{
            title: Path.basename(entry.client_name, file_extension),
            description: "",
            file_path: public_path,
            file_size: file_size,
            media_type: media_type,
            mime_type: entry.client_type,
            portfolio_id: portfolio_id,
            visible: true
          }

          case Portfolios.create_portfolio_media(media_attrs) do
            {:ok, media} ->
              # Associate with section
              case Portfolios.create_section_media_association(section_id, media.id) do
                {:ok, _} -> {:ok, media}
                {:error, _} -> {:ok, media}  # Continue even if association fails
              end

            {:error, changeset} ->
              # Clean up uploaded file on database error
              File.rm(final_path)
              {:error, "Database error: #{inspect(changeset.errors)}"}
          end

        {:error, reason} ->
          {:error, "File copy failed: #{inspect(reason)}"}
      end
    rescue
      e ->
        {:error, "Upload failed: #{Exception.message(e)}"}
    end
  end

  defp configure_uploads(socket) do
    limits = socket.assigns[:limits] || %{max_media_size_mb: 50}

    socket
    |> allow_upload(:media,
        accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .avi .pdf .doc .docx .mp3 .wav),
        max_entries: 10,
        max_file_size: limits.max_media_size_mb * 1_048_576)
    |> allow_upload(:resume,
        accept: ~w(.pdf .doc .docx .txt .rtf),
        max_entries: 1,
        max_file_size: 10 * 1_048_576)
  end

  # Add progress handler
  defp handle_progress(:media, entry, socket) do
    if entry.done? do
      # File upload completed
      socket
      |> put_flash(:info, "File uploaded successfully!")
    else
      socket
    end
  end

  defp determine_media_type(mime_type) do
    case mime_type do
      "image/" <> _ -> :image
      "video/" <> _ -> :video
      "audio/" <> _ -> :audio
      "application/pdf" -> :document
      _ -> :file
    end
  end

  # Error handling helper
  defp error_to_string(error) when is_binary(error), do: error
  defp error_to_string(error) when is_atom(error), do: Phoenix.Naming.humanize(error)
  defp error_to_string({msg, opts}) when is_binary(msg) and is_list(opts) do
    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end
  defp error_to_string(error), do: inspect(error)

  defp get_section_icon(:media_showcase), do: "🎥"
  defp get_section_icon(:intro), do: "👋"
  defp get_section_icon(:experience), do: "💼"
  defp get_section_icon(:education), do: "🎓"
  defp get_section_icon(:skills), do: "⚡"
  defp get_section_icon(:projects), do: "🚀"
  defp get_section_icon(:contact), do: "📧"
  defp get_section_icon(_), do: "📄"

  defp get_position_name("hero"), do: "Hero Section"
  defp get_position_name("about"), do: "About Section"
  defp get_position_name("sidebar"), do: "Sidebar"
  defp get_position_name("footer"), do: "Footer"
  defp get_position_name(_), do: "Hero Section"

  defp format_section_type(:media_showcase), do: "Media Showcase"
  defp format_section_type(:intro), do: "Introduction"
  defp format_section_type(:experience), do: "Experience"
  defp format_section_type(:education), do: "Education"
  defp format_section_type(:skills), do: "Skills"
  defp format_section_type(:projects), do: "Projects"
  defp format_section_type(:contact), do: "Contact"
  defp format_section_type(type), do: type |> to_string() |> String.capitalize()

  defp format_video_duration(nil), do: "0:00"
  defp format_video_duration(seconds) when is_number(seconds) do
    minutes = div(trunc(seconds), 60)
    remaining_seconds = rem(trunc(seconds), 60)
    "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end
  defp format_video_duration(_), do: "0:00"
end
