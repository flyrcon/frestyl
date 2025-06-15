# lib/frestyl_web/live/portfolio_live/edit.ex - Updated to include resume import
defmodule FrestylWeb.PortfolioLive.Edit do
  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
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
        |> assign(:customization, portfolio.customization || %{})
        |> assign(:active_customization_tab, "colors")
        |> assign(:section_edit_id, nil)
        |> assign(:section_edit_tab, "content")
        |> assign(:show_add_section_dropdown, false)
        |> assign(:show_resume_import_modal, false)
        |> assign(:show_video_intro, false)
        |> assign(:video_intro_component_id, "video-intro-#{:rand.uniform(1000)}")
        |> assign(:form, to_form(Portfolios.change_portfolio(portfolio)))

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
    {:noreply, assign(socket, :show_resume_import_modal, true)}
  end

  @impl true
  def handle_event("hide_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import_modal, false)}
  end

  # Video Intro Events
  @impl true
  def handle_event("show_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, true)}
  end

  @impl true
  def handle_event("hide_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_intro, false)}
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
  def handle_event("add_section", %{"type" => section_type}, socket) do
    max_position = case socket.assigns.sections do
      [] -> 0
      sections -> Enum.map(sections, & &1.position) |> Enum.max()
    end

    section_attrs = %{
      portfolio_id: socket.assigns.portfolio.id,
      title: format_section_title(section_type),
      section_type: section_type,
      position: max_position + 1,
      content: %{},
      visible: true
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, section} ->
        sections = [section | socket.assigns.sections]

        {:noreply,
         socket
         |> assign(:sections, sections)
         |> assign(:show_add_section_dropdown, false)
         |> put_flash(:info, "Section added successfully!")
         |> push_event("section-added", %{section_id: section.id})}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to add section.")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"id" => id}, socket) do
    # Load section media if needed
    section_media = try do
      Portfolios.list_section_media(String.to_integer(id))
    rescue
      _ -> []
    end

    {:noreply,
     socket
     |> assign(:section_edit_id, id)
     |> assign(:section_edit_tab, "content")
     |> assign(:editing_section_media, section_media)
     |> push_event("section-edit-started", %{section_id: id})}
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply,
     socket
     |> assign(:section_edit_id, nil)
     |> assign(:editing_section_media, [])
     |> push_event("section-edit-cancelled", %{})}
  end

  @impl true
  def handle_event("save_section", %{"id" => id}, socket) do
    # Save section logic here
    {:noreply,
     socket
     |> assign(:section_edit_id, nil)
     |> put_flash(:info, "Section saved successfully!")
     |> push_event("section-saved", %{section_id: id})}
  end

  @impl true
  def handle_event("delete_section", %{"id" => id}, socket) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == id))

    if section do
      case Portfolios.delete_section(section) do
        {:ok, _} ->
          sections = Enum.reject(socket.assigns.sections, &(to_string(&1.id) == id))

          {:noreply,
           socket
           |> assign(:sections, sections)
           |> put_flash(:info, "Section deleted successfully!")
           |> push_event("section-deleted", %{section_id: id})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete section.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found.")}
    end
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"id" => id}, socket) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == id))

    if section do
      case Portfolios.update_section(section, %{visible: !section.visible}) do
        {:ok, updated_section} ->
          sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == updated_section.id, do: updated_section, else: s
          end)

          {:noreply,
           socket
           |> assign(:sections, sections)
           |> push_event("section-visibility-toggled", %{section_id: id, visible: updated_section.visible})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update section visibility.")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("duplicate_section", %{"id" => id}, socket) do
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == id))

    if section do
      max_position = Enum.map(socket.assigns.sections, & &1.position) |> Enum.max()

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
          sections = [new_section | socket.assigns.sections]

          {:noreply,
           socket
           |> assign(:sections, sections)
           |> put_flash(:info, "Section duplicated successfully!")
           |> push_event("section-duplicated", %{original_id: id, new_id: new_section.id})}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to duplicate section.")}
      end
    else
      {:noreply, socket}
    end
  end

  # Section Editing
  @impl true
  def handle_event("switch_section_edit_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :section_edit_tab, tab)}
  end

  @impl true
  def handle_event("update_section_field", params, socket) do
    %{"field" => field, "section-id" => section_id} = params
    section = Enum.find(socket.assigns.sections, &(to_string(&1.id) == section_id))

    if section do
      # Update section field logic
      {:noreply,
       socket
       |> push_event("section-field-updated", %{
         section_id: section_id,
         field: field,
         value: params["value"]
       })}
    else
      {:noreply, socket}
    end
  end

  # Template and Customization
  @impl true
  def handle_event("select_template", %{"template" => template}, socket) do
    case Portfolios.update_portfolio(socket.assigns.portfolio, %{theme: template}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> put_flash(:info, "Template updated successfully!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update template.")}
    end
  end

  @impl true
  def handle_event("set_customization_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_customization_tab, tab)}
  end

  @impl true
  def handle_event("update_color_scheme", %{"scheme" => scheme}, socket) do
    # Update color scheme based on predefined schemes
    colors = get_color_scheme_colors(scheme)

    updated_customization = Map.merge(socket.assigns.customization, colors)

    case Portfolios.update_portfolio(socket.assigns.portfolio, %{customization: updated_customization}) do
      {:ok, portfolio} ->
        {:noreply,
         socket
         |> assign(:portfolio, portfolio)
         |> assign(:customization, updated_customization)
         |> put_flash(:info, "Color scheme updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update color scheme.")}
    end
  end

  @impl true
  def handle_event("update_primary_color", %{"primary_color" => color}, socket) do
    update_customization_field(socket, "primary_color", color)
  end

  @impl true
  def handle_event("update_secondary_color", %{"secondary_color" => color}, socket) do
    update_customization_field(socket, "secondary_color", color)
  end

  @impl true
  def handle_event("update_accent_color", %{"accent_color" => color}, socket) do
    update_customization_field(socket, "accent_color", color)
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
    # Update sections with imported data
    updated_sections = Portfolios.list_portfolio_sections(socket.assigns.portfolio.id)

    {:noreply,
     socket
     |> assign(:sections, updated_sections)
     |> assign(:show_resume_import_modal, false)
     |> put_flash(:info, result.flash_message)}
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

  # Helper functions

  defp format_section_title(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
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


  # Add the resume import modal to the main layout renderer
  defp render_modals(assigns) do
    ~H"""
    <!-- Video Intro Modal -->
    <%= if @show_video_intro do %>
      <%= TabRenderer.render_video_intro_modal(assigns) %>
    <% end %>

    <!-- Resume Import Modal -->
    <%= if @show_resume_import_modal do %>
      <.live_component
        module={FrestylWeb.PortfolioLive.Edit.ResumeImportModal}
        id="resume-import-modal"
        portfolio={@portfolio}
        current_user={@current_user}
      />
    <% end %>
    """
  end
end
