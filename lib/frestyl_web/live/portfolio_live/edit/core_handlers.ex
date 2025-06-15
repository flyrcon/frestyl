# lib/frestyl_web/live/portfolio_live/edit/core_handlers.ex - PHASE 5 UPDATED
defmodule FrestylWeb.PortfolioLive.Edit.CoreHandlers do
  @moduledoc """
  Core handlers for portfolio editing interface including initialization,
  navigation, basic portfolio operations, PDF export, and user limits.
  """
  import Phoenix.LiveView
  import Phoenix.Component

  alias Frestyl.Portfolios
  alias Frestyl.Accounts.User
  alias FrestylWeb.Services.PortfolioPdfExport

  def initialize_socket(socket, portfolio) do
    # Get user limits and check permissions
    user = socket.assigns.current_user
    limits = Portfolios.get_portfolio_limits(user)
    current_portfolio_count = length(Portfolios.list_user_portfolios(user.id))

    can_duplicate = case limits.max_portfolios do
      -1 -> true  # unlimited
      max when current_portfolio_count < max -> true
      _ -> false
    end

    duplicate_disabled_reason = if can_duplicate do
      nil
    else
      case limits.max_portfolios do
        -1 -> nil
        max -> "You've reached your limit of #{max} portfolios. Upgrade to create more."
      end
    end

    # Get portfolio data
    sections = Portfolios.list_portfolio_sections(portfolio.id)
    customization = portfolio.customization || get_default_customization()

    # Create form changeset
    form = Portfolios.change_portfolio(portfolio) |> to_form()

    socket
    |> assign(:portfolio, portfolio)
    |> assign(:sections, sections)
    |> assign(:customization, customization)
    |> assign(:limits, limits)
    |> assign(:current_portfolio_count, current_portfolio_count)
    |> assign(:can_duplicate, can_duplicate)
    |> assign(:duplicate_disabled_reason, duplicate_disabled_reason)
    |> assign(:form, form)
    |> assign(:active_tab, :overview)
    |> assign(:active_customization_tab, "colors")
    |> assign(:show_preview, false)
    |> assign(:preview_device, :desktop)
    |> assign(:unsaved_changes, false)
    |> assign(:section_edit_id, nil)
    |> assign(:editing_section, nil)
    |> assign(:show_add_section_dropdown, false)  # NEW
    |> assign(:section_edit_tab, "content")       # NEW
    |> assign(:show_stats_card, true)            # NEW
    |> assign(:editing_section_media, [])        # NEW
    |> assign(:show_resume_import_modal, false)
    |> assign(:show_video_intro, false)
    |> assign(:video_intro_component_id, nil)
    |> assign(:parsing_resume, false)
    |> assign(:parsed_resume_data, nil)
    |> assign(:resume_parsing_error, nil)
    |> configure_uploads()
  end

  defp setup_uploads(socket, limits) do
    socket
    |> allow_upload(:media,
        accept: ~w(.jpg .jpeg .png .gif .mp4 .mov .avi .pdf .doc .docx),
        max_entries: 10,
        max_file_size: limits.max_media_size_mb * 1_048_576)

    # Phase 3: Resume upload
    |> allow_upload(:resume,
        accept: ~w(.pdf .doc .docx .txt .rtf),
        max_entries: 1,
        max_file_size: 10 * 1_048_576)
  end

  # Portfolio count and limits helpers
  defp count_user_portfolios(user_id) do
    Portfolios.list_user_portfolios(user_id) |> length()
  end

  defp can_user_duplicate_portfolio?(limits, current_count) do
    case limits.max_portfolios do
      -1 -> true  # Unlimited
      max_count -> current_count < max_count
    end
  end

  defp get_duplicate_disabled_reason(limits, current_count) do
    case limits.max_portfolios do
      -1 -> nil
      max_count when current_count >= max_count ->
        "You've reached your portfolio limit (#{max_count}). Upgrade your plan to create more portfolios."
      _ -> nil
    end
  end

  def handle_navigation_params(socket, params) do
    # Handle any URL parameter changes
    socket
  end

  def handle_tab_change(socket, %{"tab" => tab}) do
    {:noreply, assign(socket, :active_tab, String.to_atom(tab))}
  end

  def handle_template_event_with_preview(socket, event_name, params) do
    # Use the existing TemplateManager
    updated_socket = FrestylWeb.PortfolioLive.Edit.TemplateManager.handle_template_event(socket, event_name, params)

    # Handle preview refresh in CoreHandlers (which has access to push_event)
    case updated_socket do
      {:noreply, socket_result} ->
        final_socket = handle_preview_refresh_if_needed(socket_result, event_name)
        {:noreply, final_socket}
      socket_result ->
        final_socket = handle_preview_refresh_if_needed(socket_result, event_name)
        {:noreply, final_socket}
    end
  end

  defp handle_preview_refresh_if_needed(socket, event_name) do
    if socket.assigns[:show_preview] do
      case event_name do
        "select_template" ->
          # Immediate refresh for template changes
          push_event(socket, "refresh_portfolio_preview", %{
            timestamp: System.system_time(:millisecond)
          })

        event when event in ["update_background", "update_primary_color", "update_secondary_color", "update_accent_color", "update_typography"] ->
          # Debounced refresh for other changes
          push_event(socket, "schedule_preview_refresh", %{
            delay: 500,
            timestamp: System.system_time(:millisecond)
          })

        _ ->
          # Default debounced refresh for any other customization changes
          push_event(socket, "schedule_preview_refresh", %{
            delay: 500,
            timestamp: System.system_time(:millisecond)
          })
      end
    else
      socket
    end
  end

  def render(assigns) do
    TabRenderer.render_main_layout(assigns)
  end

  def handle_portfolio_update(socket, %{"portfolio" => portfolio_params}) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, portfolio} ->
        form = portfolio |> Portfolios.change_portfolio() |> to_form()

        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> assign(:form, form)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Portfolio updated successfully!")

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = changeset |> to_form()

        socket =
          socket
          |> assign(:form, form)
          |> put_flash(:error, "There were errors updating your portfolio")

        {:noreply, socket}
    end
  end

  def handle_portfolio_validation(socket, %{"portfolio" => portfolio_params}) do
    changeset =
      socket.assigns.portfolio
      |> Portfolios.change_portfolio(portfolio_params)
      |> Map.put(:action, :validate)

    form = changeset |> to_form()

    socket =
      socket
      |> assign(:form, form)
      |> assign(:unsaved_changes, true)

    {:noreply, socket}
  end

  def handle_preview_toggle(socket, _params) do
    {:noreply, assign(socket, :show_preview, !socket.assigns.show_preview)}
  end

  def handle_preview_device_change(socket, %{"device" => device}) do
    {:noreply, assign(socket, :preview_device, String.to_atom(device))}
  end

  def handle_show_video_intro(socket, _params) do
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  def handle_hide_video_intro(socket, _params) do
    # FIXED: Always allow closing the modal
    {:noreply, assign(socket, :show_video_intro, false)}
  end

  def handle_video_intro_complete(socket, _data) do
    socket =
      socket
      |> assign(:show_video_intro, false)
      |> put_flash(:info, "Video introduction saved!")

    {:noreply, socket}
  end

  def handle_update_visibility(socket, %{"visibility" => visibility}) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{visibility: String.to_atom(visibility)}) do
      {:ok, portfolio} ->
        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> put_flash(:info, "Portfolio visibility updated!")

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to update visibility")
        {:noreply, socket}
    end
  end

  def handle_toggle_approval_required(socket, _params) do
    new_value = !socket.assigns.portfolio.approval_required

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{approval_required: new_value}) do
      {:ok, portfolio} ->
        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> put_flash(:info, "Approval setting updated!")

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to update approval setting")
        {:noreply, socket}
    end
  end

  def handle_toggle_resume_export(socket, _params) do
    new_value = !socket.assigns.portfolio.allow_resume_export

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{allow_resume_export: new_value}) do
      {:ok, portfolio} ->
        socket =
          socket
          |> assign(:portfolio, portfolio)
          |> put_flash(:info, "Resume export setting updated!")

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to update resume export setting")
        {:noreply, socket}
    end
  end

  def handle_duplicate_portfolio(socket, _params) do
    # Check if user can duplicate
    unless socket.assigns.can_duplicate do
      socket = put_flash(socket, :error, socket.assigns.duplicate_disabled_reason)
      {:noreply, socket}
    else

      user = socket.assigns.current_user
      original_portfolio = socket.assigns.portfolio

      case duplicate_portfolio(original_portfolio, user) do
        {:ok, new_portfolio} ->
          socket =
            socket
            |> put_flash(:info, "Portfolio duplicated successfully!")
            |> push_navigate(to: "/portfolios/#{new_portfolio.id}/edit")

          {:noreply, socket}

        {:error, reason} ->
          socket = put_flash(socket, :error, "Failed to duplicate portfolio: #{reason}")
          {:noreply, socket}
      end
    end
  end

  def handle_delete_portfolio(socket, _params) do
    case Portfolios.delete_portfolio(socket.assigns.portfolio) do
      {:ok, _portfolio} ->
        socket =
          socket
          |> put_flash(:info, "Portfolio deleted successfully")
          |> push_navigate(to: "/portfolios")

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to delete portfolio")
        {:noreply, socket}
    end
  end

  def handle_export_portfolio(socket, params \\ %{}) do
    portfolio = socket.assigns.portfolio
    user = socket.assigns.current_user

    # Set export status
    socket = assign(socket, :pdf_export_status, :generating)

    # Start async PDF export with ATS optimization
    pid = self()

    Task.start(fn ->
      export_opts = %{
        template: Map.get(params, "template", "resume"),
        pdf_options: [
          # ATS-optimized settings with longer timeout
          print_background: false,
          format: :letter,
          margin_top: 0.75,
          margin_bottom: 0.75,
          margin_left: 0.75,
          margin_right: 0.75,
          timeout: 60_000,  # 60 second timeout
          wait_until: :networkidle0,
          no_sandbox: true,
          disable_gpu: true
        ]
      }

      case PortfolioPdfExport.export_portfolio(portfolio.id, user.id, export_opts) do
        {:ok, pdf_data} ->
          send(pid, {:pdf_export_complete, pdf_data})
        {:error, reason} ->
          send(pid, {:pdf_export_error, reason})
      end
    end)

    socket = put_flash(socket, :info, "Generating ATS-optimized PDF export... This may take up to 60 seconds.")
    {:noreply, socket}
  end

  def handle_pdf_export_complete(socket, pdf_data) do
    # Trigger browser download dialog with the PDF binary
    socket =
      socket
      |> assign(:pdf_export_status, :complete)
      |> put_flash(:info, "Portfolio exported successfully! Download should start automatically.")
      |> push_event("download_pdf", %{
        filename: pdf_data.filename,
        content_type: pdf_data.content_type,
        size: pdf_data.size,
        # Convert binary to base64 for JavaScript download
        data: Base.encode64(pdf_data.pdf_binary)
      })

    {:noreply, socket}
  end

  def handle_pdf_export_error(socket, reason) do
    socket =
      socket
      |> assign(:pdf_export_status, :error)
      |> put_flash(:error, "Export failed: #{reason}")

    {:noreply, socket}
  end

  def handle_video_intro_complete(socket, _data) do
    socket =
      socket
      |> assign(:show_video_intro, false)
      |> put_flash(:info, "Video introduction saved!")

    {:noreply, socket}
  end

  # Template and Design handlers

  def handle_preview_template(socket, %{"template" => template_name}) do
    template_config = Frestyl.Portfolios.PortfolioTemplates.get_template_config(template_name)

    socket =
      socket
      |> assign(:template_preview_mode, true)
      |> assign(:pending_template_changes, %{
        theme: template_name,
        customization: template_config
      })
      |> assign(:has_unsaved_template_changes, true)

    {:noreply, socket}
  end

  def handle_save_template_changes(socket, _params) do
    pending_changes = socket.assigns.pending_template_changes
    portfolio = socket.assigns.portfolio

    update_attrs = %{
      theme: pending_changes[:theme] || portfolio.theme,
      customization: pending_changes[:customization] || portfolio.customization
    }

    case Portfolios.update_portfolio(portfolio, update_attrs) do
      {:ok, updated_portfolio} ->
        socket =
          socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> assign(:template_preview_mode, false)
          |> assign(:pending_template_changes, %{})
          |> assign(:has_unsaved_template_changes, false)
          |> put_flash(:info, "Template changes saved successfully!")

        {:noreply, socket}

      {:error, _changeset} ->
        socket = put_flash(socket, :error, "Failed to save template changes")
        {:noreply, socket}
    end
  end

  def handle_cancel_template_preview(socket, _params) do
    socket =
      socket
      |> assign(:template_preview_mode, false)
      |> assign(:pending_template_changes, %{})
      |> assign(:has_unsaved_template_changes, false)

    {:noreply, socket}
  end

  # Private helper functions

  defp configure_uploads(socket) do
    socket
    |> Phoenix.LiveView.allow_upload(:resume,
      accept: ~w(.pdf .doc .docx),
      max_entries: 1,
      max_file_size: 10_000_000,  # 10MB
      auto_upload: false
    )
    |> Phoenix.LiveView.allow_upload(:media,
      accept: [
        # Images - all well supported
        ".jpg", ".jpeg", ".png", ".gif", ".webp", ".svg",
        # Videos - basic formats
        ".mp4", ".webm", ".mov",
        # Audio - only most basic
        ".mp3", ".wav",
        # Documents - standard office formats
        ".pdf", ".txt", ".doc", ".docx"
      ],
      max_entries: 10,
      max_file_size: 50_000_000,  # 50MB
      auto_upload: false
    )
  end

  defp get_default_customization do
    %{
      "color_scheme" => "purple-pink",
      "primary_color" => "#6366f1",
      "secondary_color" => "#8b5cf6",
      "accent_color" => "#f59e0b",
      "layout_style" => "single_page",
      "section_spacing" => "normal",
      "font_family" => "Inter",
      "font_style" => "inter",
      "fixed_navigation" => true,
      "dark_mode_support" => false,
      "background" => "gradient-vibrant",
      "typography" => %{
        "font_family" => "Inter",
        "heading_weight" => "semibold",
        "body_weight" => "normal",
        "line_height" => "normal"
      },
      "animations" => %{
        "fade_in" => true,
        "slide_up" => false,
        "hover_effects" => true,
        "smooth_scroll" => true
      },
      "animation_speed" => "normal",
      "scroll_behavior" => "smooth",
      "card_style" => "minimal",
      "grid_layout" => "single",
      "custom_css" => ""
    }
  end

  defp duplicate_portfolio(original_portfolio, user) do
    # Check if user can create more portfolios (double-check)
    if Portfolios.can_create_portfolio?(user) do
      new_attrs = %{
        title: "#{original_portfolio.title} (Copy)",
        slug: generate_unique_slug("#{original_portfolio.slug}-copy"),
        description: original_portfolio.description,
        theme: original_portfolio.theme,
        customization: original_portfolio.customization,
        visibility: :private,
        user_id: user.id
      }

      case Portfolios.create_portfolio(user.id, new_attrs) do
        {:ok, new_portfolio} ->
          # Copy sections (existing logic works)
          copy_portfolio_sections(original_portfolio.id, new_portfolio.id)
          {:ok, new_portfolio}

        {:error, changeset} ->
          {:error, "Failed to create duplicate"}
      end
    else
      limits = Portfolios.get_portfolio_limits(user)
      {:error, "Portfolio limit reached for your subscription tier (#{limits.max_portfolios} max)"}
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

  defp generate_unique_slug(base_slug) do
    # Add timestamp to ensure uniqueness
    timestamp = System.unique_integer([:positive])
    "#{base_slug}-#{timestamp}"
  end
end
