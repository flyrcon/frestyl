# lib/frestyl_web/live/portfolio_live/edit.ex - FIXED Resume Import
defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view
  require Logger

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias FrestylWeb.PortfolioLive.Edit.{TabRenderer, SectionManager, ResumeImporter, ResumeImportModal}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    portfolio = Portfolios.get_portfolio!(id)

    # Verify user owns this portfolio
    if portfolio.user_id != socket.assigns.current_user.id do
      {:ok,
      socket
      |> put_flash(:error, "You don't have permission to edit this portfolio.")
      |> redirect(to: "/portfolios")}
    else
      sections = Portfolios.list_portfolio_sections(portfolio.id)
      limits = Portfolios.get_portfolio_limits(socket.assigns.current_user)
      portfolio_count = length(Portfolios.list_user_portfolios(socket.assigns.current_user.id))

      # Check if user can duplicate portfolios
      can_duplicate = portfolio_count < limits.max_portfolios || limits.max_portfolios == -1
      duplicate_reason = if can_duplicate, do: nil, else: "Portfolio limit reached for your subscription tier"

      # FIXED: Process portfolio customization properly
      {template_config, customization_css, active_template} = process_portfolio_customization(portfolio)

      socket =
        socket
        |> assign(:page_title, "Edit #{portfolio.title}")
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:active_tab, :overview)
        |> assign(:show_preview, false)
        |> assign(:preview_device, :desktop)
        |> assign(:limits, limits)
        |> assign(:current_portfolio_count, portfolio_count)
        |> assign(:can_duplicate, can_duplicate)
        |> assign(:duplicate_disabled_reason, duplicate_reason)
        # FIXED: Proper customization handling
        |> assign(:customization, portfolio.customization || %{})
        |> assign(:template_config, template_config)
        |> assign(:customization_css, customization_css)
        |> assign(:active_template, active_template)
        |> assign(:active_customization_tab, "colors")
        |> assign(:section_edit_id, nil)
        |> assign(:section_edit_tab, "content")
        |> assign(:show_add_section_dropdown, false)
        |> assign(:show_resume_import_modal, false)
        |> assign(:show_video_intro, false)
        |> assign(:video_intro_component_id, "video-intro-#{id}")
        |> assign(:form, to_form(Portfolios.change_portfolio(portfolio)))
        |> assign(:editing_section, nil)
        |> assign(:editing_section_media, [])
        |> assign(:unsaved_changes, false)
        |> assign(:resume_parsing_state, :idle)
        |> assign(:parsed_resume_data, nil)
        |> assign(:resume_error_message, nil)
        |> assign(:upload_progress, 0)
        |> assign(:parsing_progress, 0)
        |> assign(:import_progress, 0)
        |> assign(:sections_to_import, %{})
        |> assign(:merge_options, %{})

      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    TabRenderer.render_main_layout(assigns)
  end

  # Resume Import Events
  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_resume_import_modal, true)
    |> assign(:resume_parsing_state, :idle)
    |> assign(:parsed_resume_data, nil)
    |> assign(:resume_error_message, nil)
    |> assign(:upload_progress, 0)
    |> assign(:parsing_progress, 0)
    |> assign(:import_progress, 0)
    |> assign(:sections_to_import, %{})
    |> assign(:merge_options, %{})
    |> put_flash(:info, "Enhanced resume import ready!")}
  end

  @impl true
  def handle_event("hide_resume_import", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_resume_import_modal, false)
    |> assign(:parsed_resume_data, nil)
    |> assign(:resume_parsing_state, :idle)
    |> assign(:resume_error_message, nil)
    |> assign(:import_progress, 0)
    |> assign(:sections_to_import, %{})
    |> assign(:merge_options, %{})}
  end

  @impl true
  def handle_event("close_resume_import_modal", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  # Video Intro Events
  @impl true
  def handle_event("show_video_intro", _params, socket) do
    IO.puts("=== SHOW VIDEO INTRO IN EDIT LIVEVIEW ===")

    socket = socket
    |> assign(:show_video_intro, true)  # Make sure this matches your template

    {:noreply, socket}
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    IO.puts("=== HIDE VIDEO INTRO IN EDIT LIVEVIEW ===")

    socket = socket
    |> assign(:show_video_intro, false)  # Make sure this matches your template

    {:noreply, socket}
  end

  @impl true
  def handle_event("camera_ready", params, socket) do
    IO.puts("=== CAMERA READY IN EDIT LIVEVIEW ===")
    IO.inspect(params, label: "Camera params")

    # Forward to the video intro component if it exists
    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_ready_params: params
      )

      IO.puts("Camera ready event forwarded to component: #{socket.assigns.video_intro_component_id}")
    end

    {:noreply, socket}
  end

  # Handle camera_error events from VideoCapture hook
  @impl true
  def handle_event("camera_error", params, socket) do
    IO.puts("=== CAMERA ERROR IN EDIT LIVEVIEW ===")
    IO.inspect(params, label: "Error params")

    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        camera_error_params: params
      )
    end

    {:noreply, socket}
  end

  # Handle countdown_update events from VideoCapture hook
  @impl true
  def handle_event("countdown_update", params, socket) do
    IO.puts("=== COUNTDOWN UPDATE IN EDIT LIVEVIEW ===")
    IO.inspect(params, label: "Countdown params")

    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        countdown_update_params: params
      )
    end

    {:noreply, socket}
  end

  # Handle recording_progress events from VideoCapture hook
  @impl true
  def handle_event("recording_progress", params, socket) do
    IO.puts("=== RECORDING PROGRESS IN EDIT LIVEVIEW ===")

    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_progress_params: params
      )
    end

    {:noreply, socket}
  end

  # Handle recording_error events from VideoCapture hook
  @impl true
  def handle_event("recording_error", params, socket) do
    IO.puts("=== RECORDING ERROR IN EDIT LIVEVIEW ===")

    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        recording_error_params: params
      )
    end

    {:noreply, socket}
  end

  # Handle video_blob_ready events from VideoCapture hook
  @impl true
  def handle_event("video_blob_ready", params, socket) do
    IO.puts("=== VIDEO BLOB READY IN EDIT LIVEVIEW ===")

    if socket.assigns[:show_video_intro] do
      send_update(FrestylWeb.PortfolioLive.VideoIntroComponent,
        id: socket.assigns.video_intro_component_id,
        video_blob_params: params
      )
    end

    {:noreply, socket}
  end

  # PDF Export Events
  @impl true
  def handle_event("export_portfolio", _params, socket) do
    # Trigger PDF export
    send(self(), {:start_pdf_export, "portfolio"})
    {:noreply, put_flash(socket, :info, "Generating PDF export...")}
  end

  # Tab Navigation
  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  # Preview Toggle
  @impl true
  def handle_event("toggle_preview", _params, socket) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  @impl true
  def handle_event("change_preview_device", %{"device" => device}, socket) do
    {:noreply, assign(socket, :preview_device, String.to_existing_atom(device))}
  end

  # Portfolio Management
  @impl true
  def handle_event("update_portfolio", %{"portfolio" => portfolio_params}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:form, to_form(Portfolios.change_portfolio(portfolio)))
         |> put_flash(:info, "Portfolio updated successfully!")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate_portfolio", %{"portfolio" => portfolio_params}, socket) do
    changeset =
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("duplicate_portfolio", _params, socket) do
    if socket.assigns.can_duplicate do
      case duplicate_portfolio(socket.assigns.portfolio, socket.assigns.current_user) do
        {:ok, new_portfolio} ->
          {:noreply,
           socket
           |> put_flash(:info, "Portfolio duplicated successfully!")
           |> redirect(to: "/portfolios/#{new_portfolio.id}/edit")}

        {:error, reason} ->
          {:noreply, put_flash(socket, :error, "Failed to duplicate portfolio: #{reason}")}
      end
    else
      {:noreply, put_flash(socket, :error, socket.assigns.duplicate_disabled_reason)}
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

  # Section Management
  @impl true
  def handle_event("toggle_add_section_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_add_section_dropdown, !socket.assigns.show_add_section_dropdown)}
  end

  @impl true
  def handle_event("close_add_section_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_add_section_dropdown, false)}
  end

  @impl true
  def handle_event("set_merge_strategy", %{"section" => section_type, "strategy" => strategy}, socket) do
    current_merge_options = socket.assigns[:merge_options] || %{}
    updated_merge_options = Map.put(current_merge_options, section_type, strategy)

    {:noreply, assign(socket, :merge_options, updated_merge_options)}
  end

  @impl true
  def handle_event("toggle_section_selection", %{"section" => section_type}, socket) do
    current_selections = socket.assigns[:sections_to_import] || %{}
    current_value = Map.get(current_selections, section_type, false)
    updated_selections = Map.put(current_selections, section_type, !current_value)

    {:noreply, assign(socket, :sections_to_import, updated_selections)}
  end

  @impl true
  def handle_event("update_skills_section", %{"section-id" => section_id, "skills_data" => skills_data}, socket) do
    Logger.info("🔍 SKILLS UPDATE: Enhanced skills section update")

    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      # Parse the enhanced skills data
      enhanced_content = parse_enhanced_skills_data(skills_data)

      case Portfolios.update_section(section, %{content: enhanced_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
            updated_section
          else
            socket.assigns[:editing_section]
          end

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, editing_section)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Enhanced skills updated successfully!")
          |> push_event("skills-updated", %{
            section_id: section_id_int,
            categories: Map.keys(Map.get(enhanced_content, "skill_categories", %{}))
          })

          {:noreply, socket}

        {:error, changeset} ->
          Logger.error("🔍 SKILLS UPDATE: Failed: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to update skills section")}
      end
    else
      {:noreply, put_flash(socket, :error, "Skills section not found")}
    end
  end

    @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      socket = socket
      |> assign(:editing_section, section)
      |> assign(:section_edit_id, to_string(section_id_int))
      |> assign(:section_edit_tab, "content")
      |> assign(:active_tab, :sections)

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("save_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)

    # Get the latest section data from database
    case Portfolios.get_section!(section_id_int) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      current_section ->
        # Update sections list with latest data
        updated_sections = Enum.map(socket.assigns.sections, fn s ->
          if s.id == section_id_int, do: current_section, else: s
        end)

        # CRITICAL: KEEP EDIT MODE OPEN - don't clear editing_section
        socket = socket
        |> assign(:sections, updated_sections)
        |> assign(:editing_section, current_section)  # Keep editing with latest data
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Section saved successfully!")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket = socket
    |> assign(:editing_section, nil)
    |> assign(:section_edit_id, nil)
    |> assign(:section_edit_tab, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_section_field", %{"field" => field, "value" => value, "section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    sections = socket.assigns.sections
    section = Enum.find(sections, &(&1.id == section_id_int))

    if section do
      case Portfolios.update_section(section, %{String.to_atom(field) => value}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          # CRITICAL: Update editing_section if it matches
          editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
            updated_section
          else
            socket.assigns[:editing_section]
          end

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, editing_section)
          |> assign(:unsaved_changes, false)

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update section")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("update_section_content", params, socket) do
    IO.puts("🔍 CONTENT DEBUG: update_section_content called")
    IO.puts("🔍 CONTENT DEBUG: Params: #{inspect(params)}")

    # Handle both parameter formats: "section-id" and "section_id"
    {field, value, section_id} = case params do
      %{"field" => field, "value" => value, "section-id" => section_id} ->
        {field, value, section_id}

      %{"field" => field, "value" => value, "section_id" => section_id} ->
        {field, value, section_id}

      # Handle phx-value format (what your template is using)
      %{"value" => value} = all_params ->
        field = Map.get(all_params, "field") ||
                extract_phx_value_field(all_params)
        section_id = Map.get(all_params, "section_id") ||
                    Map.get(all_params, "section-id")
        {field, value, section_id}

      _ ->
        IO.puts("🔍 CONTENT DEBUG: Could not parse params")
        {nil, nil, nil}
    end

    IO.puts("🔍 CONTENT DEBUG: Extracted - Field: #{field}, Value: #{inspect(value)}, Section ID: #{section_id}")

    if field && value && section_id do
      section_id_int = String.to_integer(section_id)
      sections = socket.assigns.sections
      section = Enum.find(sections, &(&1.id == section_id_int))

      if section do
        IO.puts("🔍 CONTENT DEBUG: Found section: #{section.title}")
        IO.puts("🔍 CONTENT DEBUG: Current content: #{inspect(section.content)}")

        current_content = section.content || %{}
        updated_content = Map.put(current_content, field, value)

        IO.puts("🔍 CONTENT DEBUG: Updated content: #{inspect(updated_content)}")

        case Portfolios.update_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            IO.puts("🔍 CONTENT DEBUG: ✅ Section updated successfully")

            updated_sections = Enum.map(sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            socket = socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, updated_section)

            {:noreply, socket}

          {:error, changeset} ->
            IO.puts("🔍 CONTENT DEBUG: ❌ Section update failed: #{inspect(changeset.errors)}")
            {:noreply, put_flash(socket, :error, "Failed to update section content")}
        end
      else
        IO.puts("🔍 CONTENT DEBUG: ❌ Section not found with ID: #{section_id_int}")
        {:noreply, put_flash(socket, :error, "Section not found")}
      end
    else
      IO.puts("🔍 CONTENT DEBUG: ❌ Missing required parameters")
      {:noreply, put_flash(socket, :error, "Missing required parameters")}
    end
  end

  @impl true
  def handle_event("update_section_summary", %{"value" => value, "section-id" => section_id}, socket) do
    IO.puts("🔍 SUMMARY DEBUG: Updating summary for section #{section_id}")

    # Use the same logic as update_section_content but specifically for summary
    params = %{"field" => "summary", "value" => value, "section-id" => section_id}
    handle_event("update_section_content", params, socket)
  end

  @impl true
  def handle_event("update_section_headline", %{"value" => value, "section-id" => section_id}, socket) do
    IO.puts("🔍 HEADLINE DEBUG: Updating headline for section #{section_id}")

    params = %{"field" => "headline", "value" => value, "section-id" => section_id}
    handle_event("update_section_content", params, socket)
  end

  # Generic content field updater
  @impl true
  def handle_event("update_content_field", %{"field" => field, "value" => value, "section_id" => section_id}, socket) do
    IO.puts("🔍 FIELD DEBUG: Updating #{field} for section #{section_id}")

    params = %{"field" => field, "value" => value, "section-id" => section_id}
    handle_event("update_section_content", params, socket)
  end

  @impl true
  def handle_event("update_display_setting", %{"setting" => setting}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    # Get current display settings
    display_settings = get_in(current_customization, ["display_settings"]) || %{}

    # Toggle the setting
    current_value = Map.get(display_settings, setting, true)
    new_value = !current_value

    # Update display settings
    updated_display_settings = Map.put(display_settings, setting, new_value)
    updated_customization = put_in(current_customization, ["display_settings"], updated_display_settings)

    # Save to database
    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Display setting updated")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update display setting")}
    end
  end

  @impl true
  def handle_event("add_custom_metric", _params, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    # Get current custom metrics
    current_metrics = get_in(current_customization, ["display_settings", "custom_metrics"]) || []

    # Add new empty metric
    new_metric = %{
      "label" => "",
      "value" => "",
      "description" => ""
    }

    updated_metrics = current_metrics ++ [new_metric]
    updated_customization = put_in(current_customization, ["display_settings", "custom_metrics"], updated_metrics)

    # Save to database
    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        {:noreply,
        socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> put_flash(:info, "Custom metric added")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add custom metric")}
    end
  end

  @impl true
  def handle_event("remove_custom_metric", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    # Get current custom metrics
    current_metrics = get_in(current_customization, ["display_settings", "custom_metrics"]) || []

    # Remove metric at index
    if index >= 0 and index < length(current_metrics) do
      updated_metrics = List.delete_at(current_metrics, index)
      updated_customization = put_in(current_customization, ["display_settings", "custom_metrics"], updated_metrics)

      # Save to database
      case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
        {:ok, updated_portfolio} ->
          {:noreply,
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> put_flash(:info, "Custom metric removed")}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to remove custom metric")}
      end
    else
      {:noreply, put_flash(socket, :error, "Invalid metric index")}
    end
  end

  @impl true
  def handle_event("update_custom_metric", %{"index" => index_str, "field" => field, "value" => value}, socket) do
    index = String.to_integer(index_str)
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}

    # Get current custom metrics
    current_metrics = get_in(current_customization, ["display_settings", "custom_metrics"]) || []

    # Update metric at index
    if index >= 0 and index < length(current_metrics) do
      updated_metrics = List.update_at(current_metrics, index, fn metric ->
        Map.put(metric, field, value)
      end)

      updated_customization = put_in(current_customization, ["display_settings", "custom_metrics"], updated_metrics)

      # Save to database
      case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
        {:ok, updated_portfolio} ->
          {:noreply,
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update custom metric")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("toggle_add_section_dropdown", _params, socket) do
    current_state = socket.assigns[:show_add_section_dropdown] || false
    {:noreply, assign(socket, :show_add_section_dropdown, !current_state)}
  end

  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    max_position = case socket.assigns.sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end

    # Get default content for section type
    default_content = get_default_content_for_section_type(section_type)

    section_attrs = %{
      portfolio_id: socket.assigns.portfolio.id,
      title: format_section_title(section_type),
      section_type: section_type,
      position: max_position + 1,
      content: default_content,
      visible: true
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, section} ->
        sections = socket.assigns.sections ++ [section]

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:show_add_section_dropdown, false)
         |> put_flash(:info, "#{format_section_title(section_type)} section added successfully!")
         |> push_event("section-added", %{section_id: section.id, section_type: section_type})}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add section: #{format_changeset_errors(changeset)}")}
    end
  end

  @impl true
  def handle_event("delete_section", params, socket) do
    SectionManager.handle_delete_section(socket, params)
  end

  @impl true
  def handle_event("toggle_section_visibility", params, socket) do
    SectionManager.handle_toggle_visibility(socket, params)
  end

  @impl true
  def handle_event("duplicate_section", %{"id" => section_id}, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_duplicate_section(socket, %{"id" => section_id})
  end


  @impl true
  def handle_event("reorder_sections", %{"sections" => section_ids}, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_reorder_sections(socket, %{"sections" => section_ids})
  end

  @impl true
  def handle_event("switch_section_edit_tab", params, socket) do
    SectionManager.handle_switch_section_edit_tab(socket, params)
  end

  # Experience/Education/Skills management
  @impl true
  def handle_event("add_experience_entry", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_add_experience_entry(socket, params)
  end

  @impl true
  def handle_event("remove_experience_entry", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_remove_experience_entry(socket, params)
  end

  @impl true
  def handle_event("update_experience_field", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_update_experience_field(socket, params)
  end

  @impl true
  def handle_event("add_education_entry", params, socket) do
    SectionManager.handle_add_education_entry(socket, params)
  end

  @impl true
  def handle_event("update_education_field", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_update_education_field(socket, params)
  end

  @impl true
  def handle_event("remove_education_entry", params, socket) do
    SectionManager.handle_remove_education_entry(socket, params)
  end

  @impl true
  def handle_event("add_skill", params, socket) do
    SectionManager.handle_add_skill(socket, params)
  end

  @impl true
  def handle_event("remove_skill", params, socket) do
    SectionManager.handle_remove_skill(socket, params)
  end

  @impl true
  def handle_event("update_section_content", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_update_section_content(socket, params)
  end

  # Section media layout updating - delegate to MediaManager
  @impl true
  def handle_event("show_section_media_library", %{"section-id" => section_id}, socket) do
    FrestylWeb.PortfolioLive.Edit.MediaManager.handle_show_section_media_library(socket, section_id)
  end

  @impl true
  def handle_event("hide_section_media_library", _params, socket) do
    FrestylWeb.PortfolioLive.Edit.MediaManager.handle_hide_section_media_library(socket)
  end

  @impl true
  def handle_event("update_section_media_layout", params, socket) do
    case FrestylWeb.PortfolioLive.Edit.MediaManager do
      module when not is_nil(module) ->
        module.handle_update_section_media_layout(socket, params)
      _ ->
        # Fallback implementation if MediaManager doesn't exist yet
        handle_update_section_media_layout_fallback(socket, params)
    end
  end

  @impl true
  def handle_event("attach_media_to_section", params, socket) do
    FrestylWeb.PortfolioLive.Edit.MediaManager.handle_attach_media_to_section(socket, params)
  end

  # Add more missing handlers that might be called from the UI
  @impl true
  def handle_event("toggle_section_media_support", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_toggle_section_media_support(socket, params)
  end

  @impl true
  def handle_event("apply_section_template", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_apply_section_template(socket, params)
  end

  @impl true
  def handle_event("export_section_template", params, socket) do
    FrestylWeb.PortfolioLive.Edit.SectionManager.handle_export_section_template(socket, params)
  end

  # Template and Customization
  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    Logger.info("🎨 TEMPLATE: Selecting template: #{template}")

    # Get template configuration
    template_config = PortfolioTemplates.get_template_config(template)

    # Update portfolio with new theme
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: template}) do
      {:ok, updated_portfolio} ->
        Logger.info("🎨 TEMPLATE: Portfolio theme updated successfully")

        # Generate new CSS based on template
        customization_css = generate_template_css(template_config, socket.assigns.customization)

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:active_template, template)
          |> assign(:template_config, template_config)
          |> assign(:customization_css, customization_css)
          |> put_flash(:info, "Template updated successfully!")
          # FIXED: Push real-time CSS update to client
          |> push_event("template-changed", %{
            template: template,
            css: customization_css,
            config: template_config
          })

        {:noreply, socket}

      {:error, changeset} ->
        Logger.error("🎨 TEMPLATE: Failed to update template: #{inspect(changeset.errors)}")
        {:noreply, put_flash(socket, :error, "Failed to update template.")}
    end
  end

  @impl true
  def handle_event("set_customization_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  @impl true
  def handle_event("update_color", params, socket) do
    field = params["field"] || params["color_field"]
    value = params["value"] || params["color"]

    if field && value do
      update_color_field_live(socket, field, value)
    else
      {:noreply, put_flash(socket, :error, "Invalid color update")}
    end
  end

  @impl true
  def handle_event("update_primary_color", %{"primary_color" => color}, socket) do
    update_color_with_preview(socket, "primary_color", color)
  end

  @impl true
  def handle_event("update_secondary_color", %{"secondary_color" => color}, socket) do
    update_color_with_preview(socket, "secondary_color", color)
  end

  @impl true
  def handle_event("update_accent_color", %{"accent_color" => color}, socket) do
    update_color_with_preview(socket, "accent_color", color)
  end

  @impl true
  def handle_event("prevent_default", _params, socket) do
    {:noreply, socket}
  end

  defp update_color_field_live(socket, field, value) do
    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, field, value)

    socket = socket
    |> assign(:customization, updated_customization)
    |> assign(:unsaved_changes, true)

    # Push CSS update to client
    socket = push_event(socket, "update-color-css", %{
      field: field,
      value: value,
      css_vars: get_css_variables(updated_customization)
    })

    # Save to database (non-blocking)
    Task.start(fn ->
      case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
        {:ok, _portfolio} ->
          send(self(), {:color_saved, field, value})
        {:error, error} ->
          send(self(), {:color_save_failed, field, error})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_template_changes", _params, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: socket.assigns.customization}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Design changes saved successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to save changes.")}
    end
  end

  @impl true
  def handle_event("update_typography", %{"font" => font_family}, socket) do
    Logger.info("🎨 FONT: Updating font to: #{font_family}")

    current_customization = socket.assigns.customization || %{}
    typography = get_in(current_customization, ["typography"]) || %{}
    updated_typography = Map.put(typography, "font_family", font_family)
    updated_customization = put_in(current_customization, ["typography"], updated_typography)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        # Generate updated CSS
        customization_css = generate_template_css(socket.assigns.template_config, updated_customization)

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:customization_css, customization_css)
          |> put_flash(:info, "Typography updated successfully!")
          # FIXED: Push real-time update
          |> push_event("typography-updated", %{
            font_family: font_family,
            css: customization_css
          })

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update typography.")}
    end
  end

  @impl true
  def handle_info({:typography_saved, font_value}, socket) do
    socket = socket
    |> assign(:unsaved_changes, false)
    |> put_flash(:info, "Font updated to #{font_value}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:typography_save_failed, _error}, socket) do
    socket = socket
    |> put_flash(:error, "Failed to save font changes")

    {:noreply, socket}
  end


  # Settings
  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_existing_atom(visibility)}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Visibility updated successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update visibility.")}
    end
  end

  @impl true
  def handle_event("toggle_approval_required", _params, socket) do
    new_value = !socket.assigns.portfolio.approval_required

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{approval_required: new_value}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Approval setting updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update setting.")}
    end
  end

  @impl true
  def handle_event("toggle_resume_export", _params, socket) do
    new_value = !socket.assigns.portfolio.allow_resume_export

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{allow_resume_export: new_value}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Resume export setting updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update setting.")}
    end
  end

  # Resume Import Handling
  @impl true
  def handle_info(:close_resume_import_modal, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  @impl true
  def handle_info({:resume_import_complete, result}, socket) do
    Logger.info("🔍 EDIT DEBUG: Enhanced resume import complete message received")
    Logger.info("🔍 EDIT DEBUG: Result keys: #{inspect(Map.keys(result))}")

    case result do
      %{sections: updated_sections, flash_message: message} ->
        Logger.info("🔍 EDIT DEBUG: Updated sections count: #{length(updated_sections)}")

        {:noreply,
        socket
        |> assign(:sections, updated_sections)
        |> assign(:show_resume_import_modal, false)
        |> assign(:parsed_resume_data, nil)
        |> assign(:resume_parsing_state, :idle)
        |> assign(:import_progress, 0)
        |> assign(:sections_to_import, %{})
        |> assign(:merge_options, %{})
        |> put_flash(:info, message)}

      %{resume_parsing_state: :error, resume_error_message: error_msg} ->
        Logger.error("🔍 EDIT DEBUG: Import failed: #{error_msg}")

        {:noreply,
        socket
        |> assign(:resume_parsing_state, :error)
        |> assign(:resume_error_message, error_msg)
        |> put_flash(:error, error_msg)}

      _ ->
        Logger.warn("🔍 EDIT DEBUG: Unexpected result format: #{inspect(result)}")
        {:noreply, put_flash(socket, :error, "Import completed with unexpected result")}
    end
  end

  @impl true
  def handle_info({:import_sections_with_options, {section_selections, merge_options}}, socket) do
    Logger.info("🔍 EDIT: Starting enhanced import with merge options")
    Logger.info("🔍 EDIT: Section selections: #{inspect(section_selections)}")
    Logger.info("🔍 EDIT: Merge options: #{inspect(merge_options)}")

    case socket.assigns[:parsed_resume_data] do
      nil ->
        {:noreply, put_flash(socket, :error, "No parsed resume data available")}

      parsed_data ->
        # Start background import process
        portfolio = socket.assigns.portfolio

        Task.start(fn ->
          result = ResumeImporter.import_sections_to_portfolio(
            portfolio,
            parsed_data,
            section_selections,
            merge_options
          )
          send(self(), {:resume_import_complete, result})
        end)

        {:noreply,
        socket
        |> assign(:resume_parsing_state, :importing)
        |> assign(:import_progress, 50)
        |> put_flash(:info, "Importing sections with enhanced skills processing...")}
    end
  end

  # FIXED: Handle the parsing schedule request from component
  @impl true
  def handle_info({:schedule_parsing_complete, delay}, socket) do
    # Schedule the completion and then send update to component
    Process.send_after(self(), :complete_parsing_simulation, delay)
    {:noreply, socket}
  end

  # FIXED: Complete the parsing and update component
  @impl true
  def handle_info(:complete_parsing_simulation, socket) do
    # Send event to update the component state
    send_update(FrestylWeb.PortfolioLive.Edit.ResumeImportModal,
                id: "resume-import-modal",
                parsing_stage: :parsed)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:start_pdf_export, format}, socket) do
    # Handle PDF export in background
    portfolio = socket.assigns.portfolio

    Task.start(fn ->
      case Frestyl.PdfExport.export_portfolio(portfolio.slug, format: format) do
        {:ok, result} ->
          send(self(), {:pdf_export_complete, result.url})
        {:error, reason} ->
          send(self(), {:pdf_export_failed, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pdf_export_complete, download_url}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, "PDF export ready!")
     |> push_event("pdf-ready", %{download_url: download_url})}
  end

  @impl true
  def handle_info({:pdf_export_failed, reason}, socket) do
    {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
  end

  @impl true
  def handle_event("update_background", %{"background" => background}, socket) do
    Logger.info("🎨 BACKGROUND: Updating to: #{background}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, "background", background)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        customization_css = generate_template_css(socket.assigns.template_config, updated_customization)

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:customization_css, customization_css)
          |> put_flash(:info, "Background updated successfully!")
          |> push_event("background-updated", %{
            background: background,
            css: customization_css
          })

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update background.")}
    end
  end

  # FIXED: Spacing updates
  @impl true
  def handle_event("update_spacing", params, socket) do
    spacing = params["spacing"] || params["value"]

    if spacing do
      current_customization = socket.assigns.customization || %{}
      updated_customization = put_in(current_customization, ["layout", "section_spacing"], spacing)

      socket = socket
      |> assign(:customization, updated_customization)
      |> push_event("update-spacing-css", %{
        spacing: spacing,
        css_class: get_spacing_css_class(spacing)
      })

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  # Also add this catch-all handler to see what events are actually being sent
  @impl true
  def handle_event(event_name, params, socket) when event_name in ["update_section_content", "update_section_field"] do
    IO.puts("🔍 CATCH-ALL DEBUG: Event '#{event_name}' with params: #{inspect(params)}")

    # Try to handle it anyway
    case extract_update_params(params) do
      {field, value, section_id, update_type} ->
        IO.puts("🔍 CATCH-ALL DEBUG: Extracted params - Field: #{field}, Type: #{update_type}")

        section_id_int = String.to_integer(section_id)
        sections = socket.assigns.sections
        section = Enum.find(sections, &(&1.id == section_id_int))

        if section do
          case update_type do
            :content ->
              current_content = section.content || %{}
              updated_content = Map.put(current_content, field, value)
              Portfolios.update_section(section, %{content: updated_content})

            :field ->
              Portfolios.update_section(section, %{String.to_atom(field) => value})
          end
          |> case do
            {:ok, updated_section} ->
              updated_sections = Enum.map(sections, fn s ->
                if s.id == section_id_int, do: updated_section, else: s
              end)

              socket = socket
              |> assign(:sections, updated_sections)
              |> assign(:editing_section, updated_section)

              {:noreply, socket}

            {:error, _} ->
              {:noreply, put_flash(socket, :error, "Update failed")}
          end
        else
          {:noreply, put_flash(socket, :error, "Section not found")}
        end

      nil ->
        IO.puts("🔍 CATCH-ALL DEBUG: Could not extract update parameters")
        {:noreply, socket}
    end
  end


  # Helper functions

    defp process_portfolio_customization(portfolio) do
    Logger.info("🎨 PROCESSING: Portfolio customization")

    # Get active template
    active_template = portfolio.theme || "executive"

    # Get template configuration
    template_config = PortfolioTemplates.get_template_config(active_template)

    # Get user customizations (overrides template defaults)
    user_customization = portfolio.customization || %{}

    # Generate CSS from both template and user customizations
    customization_css = generate_template_css(template_config, user_customization)

    Logger.info("🎨 PROCESSING: Complete - Template: #{active_template}")

    {template_config, customization_css, active_template}
  end

  defp generate_template_css(template_config, user_customization) do
    # Merge template defaults with user overrides
    primary_color = user_customization["primary_color"] || template_config[:primary_color] || "#3b82f6"
    secondary_color = user_customization["secondary_color"] || template_config[:secondary_color] || "#64748b"
    accent_color = user_customization["accent_color"] || template_config[:accent_color] || "#f59e0b"

    # Typography
    typography = user_customization["typography"] || template_config[:typography] || %{}
    font_family = typography["font_family"] || typography[:font_family] || "Inter"

    # Background
    background = user_customization["background"] || template_config[:background] || "default"

    font_family_css = get_font_family_css(font_family)
    background_css = get_background_css(background)

    """
    <style id="portfolio-customization-css">
    :root {
      --portfolio-primary-color: #{primary_color};
      --portfolio-secondary-color: #{secondary_color};
      --portfolio-accent-color: #{accent_color};
      --portfolio-font-family: #{font_family_css};
    }

    /* Apply to portfolio elements */
    .portfolio-primary { color: var(--portfolio-primary-color) !important; }
    .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
    .portfolio-accent { color: var(--portfolio-accent-color) !important; }
    .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
    .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

    /* Color swatches for preview */
    .color-swatch-primary { background-color: var(--portfolio-primary-color) !important; }
    .color-swatch-secondary { background-color: var(--portfolio-secondary-color) !important; }
    .color-swatch-accent { background-color: var(--portfolio-accent-color) !important; }

    /* Typography preview */
    .portfolio-preview {
      font-family: var(--portfolio-font-family) !important;
    }

    /* Template selection highlighting */
    .template-preview-card.border-blue-500 {
      border-color: var(--portfolio-primary-color) !important;
      box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2) !important;
    }

    /* Background styles */
    #{background_css}
    </style>
    """
  end

  defp get_font_family_css(font_family) do
    case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end
  end

  defp get_background_css(background) do
    case background do
      "gradient-ocean" ->
        """
        .portfolio-bg {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
        }
        """
      "gradient-sunset" ->
        """
        .portfolio-bg {
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important;
        }
        """
      "dark-mode" ->
        """
        .portfolio-bg {
          background: #1a1a1a !important;
          color: #ffffff !important;
        }
        """
      _ ->
        """
        .portfolio-bg {
          background: #ffffff !important;
        }
        """
    end
  end

  defp update_color_with_preview(socket, color_field, color_value) do
    Logger.info("🎨 COLOR: Updating #{color_field} to #{color_value}")

    current_customization = socket.assigns.customization || %{}
    updated_customization = Map.put(current_customization, color_field, color_value)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        # Generate updated CSS
        customization_css = generate_template_css(socket.assigns.template_config, updated_customization)

        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:customization_css, customization_css)
          |> assign(:unsaved_changes, false)
          # FIXED: Push real-time color update
          |> push_event("color-updated", %{
            field: color_field,
            value: color_value,
            css: customization_css
          })

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update #{color_field}.")}
    end
  end

  defp extract_field_from_target(params) do
    case params["_target"] do
      [field] -> field
      field when is_binary(field) -> field
      _ -> params["field"]
    end
  end

  defp get_font_css_class(font_family) do
    case font_family do
      "Inter" -> "font-sans"
      "Merriweather" -> "font-serif"
      "JetBrains Mono" -> "font-mono"
      "Playfair Display" -> "font-serif"
      _ -> "font-sans"
    end
  end

  defp get_background_css_class(background) do
    case background do
      "gradient-ocean" -> "bg-gradient-to-br from-blue-400 to-purple-600"
      "gradient-sunset" -> "bg-gradient-to-br from-orange-400 to-pink-600"
      "dark-mode" -> "bg-gray-900"
      _ -> "bg-white"
    end
  end

  defp get_spacing_css_class(spacing) do
    case spacing do
      "compact" -> "space-y-4"
      "normal" -> "space-y-6"
      "spacious" -> "space-y-8"
      _ -> "space-y-6"
    end
  end

  defp get_css_variables(customization) do
    %{
      "--primary-color" => Map.get(customization, "primary_color", "#6366f1"),
      "--secondary-color" => Map.get(customization, "secondary_color", "#8b5cf6"),
      "--accent-color" => Map.get(customization, "accent_color", "#f59e0b")
    }
  end

  defp extract_phx_value_field(params) do
    # Phoenix converts phx-value-field="main_content" to a "field" key in params
    # But let's check for other possible formats
    cond do
      Map.has_key?(params, "field") -> params["field"]
      Map.has_key?(params, "_target") ->
        # Sometimes the field name is in _target
        case params["_target"] do
          [field] -> field
          field when is_binary(field) -> field
          _ -> nil
        end
      true ->
        # Last resort: look for any key that might be the field
        params
        |> Map.keys()
        |> Enum.find(fn key ->
          key not in ["value", "section_id", "section-id", "_target", "_csrf_token"]
        end)
    end
  end

  defp extract_update_params(params) do
    # Extract field, value, section_id and determine if it's content or field update
    field = params["field"] || extract_phx_value_field(params)
    value = params["value"]
    section_id = params["section_id"] || params["section-id"]

    update_type = if field in ["title", "visible", "position"], do: :field, else: :content

    if field && value && section_id do
      {field, value, section_id, update_type}
    else
      nil
    end
  end

  defp handle_update_section_media_layout_fallback(socket, %{"layout" => layout, "section-id" => section_id}) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns[:editing_section]
    sections = socket.assigns.sections

    if editing_section && editing_section.id == section_id_int do
      current_content = editing_section.content || %{}
      updated_content = Map.put(current_content, "media_layout", layout)

      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, updated_section)
          |> put_flash(:info, "Media layout updated")
          |> push_event("media-layout-updated", %{
            section_id: section_id_int,
            layout: layout
          })

          {:noreply, socket}

        {:error, changeset} ->
          socket = socket
          |> put_flash(:error, "Failed to update media layout")

          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp parse_enhanced_skills_data(skills_data) do
    # Handle both string and map input
    case skills_data do
      %{} = skills_map ->
        # Already a map, validate and enhance
        enhance_skills_map(skills_map)

      skills_string when is_binary(skills_string) ->
        # Parse string format (for bulk import)
        parse_skills_string_to_enhanced_format(skills_string)

      _ ->
        Logger.warn("🔍 SKILLS PARSE: Unknown skills data format")
        %{"skills" => [], "skill_categories" => %{}}
    end
  end

  defp enhance_skills_map(skills_map) do
    # Ensure required keys exist
    base_content = %{
      "skills" => Map.get(skills_map, "skills", []),
      "skill_categories" => Map.get(skills_map, "skill_categories", %{}),
      "skill_display_mode" => Map.get(skills_map, "skill_display_mode", "categorized"),
      "show_proficiency" => Map.get(skills_map, "show_proficiency", true),
      "show_years" => Map.get(skills_map, "show_years", true)
    }

    # Add enhanced metadata if not present
    if Map.has_key?(skills_map, "proficiency_legend") do
      base_content
    else
      Map.merge(base_content, %{
        "proficiency_legend" => get_default_proficiency_legend(),
        "category_colors" => get_default_category_colors()
      })
    end
  end

  defp parse_skills_string_to_enhanced_format(skills_string) do
    # Basic parsing for bulk import
    skills = skills_string
    |> String.split(~r/[,;\n]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn skill ->
      %{
        "name" => skill,
        "proficiency" => "intermediate",
        "category" => "Other"
      }
    end)

    %{
      "skills" => Enum.map(skills, &(&1["name"])),
      "skill_categories" => %{"Other" => skills},
      "skill_display_mode" => "categorized",
      "show_proficiency" => true,
      "show_years" => false,
      "proficiency_legend" => get_default_proficiency_legend(),
      "category_colors" => get_default_category_colors()
    }
  end

  defp get_default_proficiency_legend do
    %{
      "beginner" => %{"label" => "Beginner", "color" => "bg-blue-300"},
      "intermediate" => %{"label" => "Intermediate", "color" => "bg-blue-500"},
      "advanced" => %{"label" => "Advanced", "color" => "bg-blue-700"},
      "expert" => %{"label" => "Expert", "color" => "bg-blue-900"}
    }
  end

  defp get_default_category_colors do
    %{
      "Programming Languages" => "blue",
      "Frameworks & Libraries" => "indigo",
      "Tools & Platforms" => "orange",
      "Databases" => "green",
      "Design & Creative" => "purple",
      "Soft Skills" => "emerald",
      "Data & Analytics" => "cyan",
      "Other" => "gray"
    }
  end

  defp duplicate_portfolio(portfolio, user) do
    new_attrs = %{
      title: "#{portfolio.title} (Copy)",
      description: portfolio.description,
      theme: portfolio.theme,
      customization: portfolio.customization,
      visibility: :private  # Always create duplicates as private
    }

    case Portfolios.create_portfolio(user.id, new_attrs) do
      {:ok, new_portfolio} ->
        # Copy sections
        copy_portfolio_sections(portfolio, new_portfolio)
        {:ok, new_portfolio}

      {:error, changeset} ->
        {:error, "Failed to create portfolio copy"}
    end
  end

  defp copy_portfolio_sections(source_portfolio, target_portfolio) do
    sections = Portfolios.list_portfolio_sections(source_portfolio.id)

    Enum.each(sections, fn section ->
      section_attrs = %{
        portfolio_id: target_portfolio.id,
        title: section.title,
        section_type: section.section_type,
        content: section.content,
        position: section.position,
        visible: section.visible
      }

      Portfolios.create_section(section_attrs)
    end)
  end

  defp update_customization_field(socket, field, value) do
    updated_customization = Map.put(socket.assigns.customization, field, value)

    # Update in real-time and save
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> push_event("customization-updated", %{field: field, value: value})}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update #{field}.")}
    end
  end

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

    defp format_section_title(section_type) do
    case section_type do
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
      "custom" -> "Custom Section"
      _ -> String.capitalize(section_type |> String.replace("_", " "))
    end
  end

  defp format_changeset_errors(changeset) do
    changeset.errors
    |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
    |> Enum.join(", ")
  end

  # Helper function for default content
  defp get_default_content_for_section_type("intro") do
    %{
      "headline" => "Hello, I'm [Your Name]",
      "summary" => "A brief introduction about yourself and your professional journey.",
      "location" => "",
      "website" => "",
      "social_links" => %{
        "linkedin" => "",
        "github" => "",
        "twitter" => ""
      }
    }
  end

  defp get_default_content_for_section_type("experience") do
    %{
      "jobs" => []
    }
  end

  defp get_default_content_for_section_type("education") do
    %{
      "education" => []
    }
  end

  defp get_default_content_for_section_type("skills") do
    %{
      "skills" => [],
      "skill_categories" => %{}
    }
  end

  defp get_default_content_for_section_type("projects") do
    %{
      "projects" => []
    }
  end

  defp get_default_content_for_section_type("featured_project") do
    %{
      "title" => "",
      "description" => "",
      "technologies" => [],
      "url" => "",
      "github_url" => ""
    }
  end

  defp get_default_content_for_section_type("case_study") do
    %{
      "title" => "",
      "client" => "",
      "timeline" => "",
      "challenge" => "",
      "solution" => "",
      "results" => ""
    }
  end

  defp get_default_content_for_section_type("contact") do
    %{
      "email" => "",
      "phone" => "",
      "location" => "",
      "website" => "",
      "social_links" => %{}
    }
  end

  defp get_default_content_for_section_type("media_showcase") do
    %{
      "layout" => "grid",
      "title" => "",
      "description" => ""
    }
  end

  defp get_default_content_for_section_type("achievements") do
    %{
      "achievements" => []
    }
  end

  defp get_default_content_for_section_type("testimonial") do
    %{
      "testimonials" => []
    }
  end

  defp get_default_content_for_section_type("code_showcase") do
    %{
      "title" => "",
      "description" => "",
      "language" => "javascript",
      "code" => "",
      "explanation" => ""
    }
  end

  defp get_default_content_for_section_type(_), do: %{}
end
