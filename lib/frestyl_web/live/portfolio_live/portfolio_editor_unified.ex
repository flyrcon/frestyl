# lib/frestyl_web/live/portfolio_live/portfolio_editor_unified.ex
defmodule FrestylWeb.PortfolioLive.PortfolioEditorUnified do
  @moduledoc """
  Unified Portfolio Editor - Clean, modern editing experience following portfolio_hub design patterns.
  Consolidates all editing functionality into one coherent LiveView with real-time preview.
  """

  use FrestylWeb, :live_view
  import Phoenix.HTML.Form

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.Portfolio
  alias Frestyl.Media
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.EnhancedVideoIntroComponent

    @section_types [
    "hero",
    "about",
    "experience",
    "education",
    "skills",
    "projects",
    "testimonials",
    "contact",
    "certifications",
    "achievements",
    "services",
    "blog",
    "gallery",
    "custom"
  ]

  @impl true
  def mount(%{"id" => portfolio_id}, session, socket) do
    IO.puts("🔥 MOUNT: Starting mount for portfolio #{portfolio_id}")

    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
    end

    current_user = get_current_user_from_session(session)
    IO.puts("🔥 MOUNT: Current user loaded")

    case Portfolios.get_portfolio_with_sections(portfolio_id) do
      {:ok, portfolio} ->
        IO.puts("🔥 MOUNT: Portfolio loaded successfully")
        IO.puts("🔥 MOUNT: About to call assign_portfolio_data_safely")

        socket = socket
        |> assign(:current_user, current_user)
        |> assign_portfolio_data_safely(portfolio)

        IO.puts("🔥 MOUNT: assign_portfolio_data_safely completed")

        socket = socket |> assign_ui_state()
        IO.puts("🔥 MOUNT: assign_ui_state completed")

        socket = socket |> assign_editor_state()
        IO.puts("🔥 MOUNT: assign_editor_state completed")

        {:ok, socket}

      error ->
        IO.puts("❌ MOUNT: Error: #{inspect(error)}")
        {:ok, socket
        |> assign(:current_user, current_user)
        |> put_flash(:error, "Error loading portfolio")
        |> redirect(to: ~p"/portfolios")}
    end
  end

defp assign_portfolio_data_safely(socket, portfolio) do
  IO.puts("🔥 ASSIGN: Starting with portfolio keys: #{inspect(Map.keys(portfolio))}")

  sections = Map.get(portfolio, :sections, [])
  IO.puts("🔥 ASSIGN: Got #{length(sections)} sections")

  customization = Map.get(portfolio, :customization, %{})
  hero_section = find_hero_section(sections)

  socket
  |> assign(:portfolio, portfolio)
  |> assign(:sections, sections)
  |> assign(:customization, customization)
  |> assign(:hero_section, hero_section)
end

defp assign_portfolio_data(socket, portfolio) do
  # Get sections from the portfolio (your Portfolios function already added this)
  sections = Map.get(portfolio, :sections, [])
  customization = Map.get(portfolio, :customization, %{})
  hero_section = find_hero_section(sections)

  socket
  |> assign(:portfolio, portfolio)
  |> assign(:sections, sections)
  |> assign(:customization, customization)
  |> assign(:hero_section, hero_section)
end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, socket
    |> assign(:live_action, socket.assigns.live_action)
    |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, _params) do
    socket
    |> assign(:page_title, "Edit Portfolio")
    |> assign(:editor_mode, :edit)
  end

  defp apply_action(socket, :preview, _params) do
    socket
    |> assign(:page_title, "Preview Portfolio")
    |> assign(:editor_mode, :preview)
  end

  @impl true
  def handle_params(%{"id" => portfolio_id} = params, uri, socket) do
    preview_mode = if String.contains?(uri, "/editor_preview"), do: :preview, else: :edit

    {:noreply, socket
    |> assign(:live_action, socket.assigns.live_action)
    |> assign(:preview_mode, preview_mode)
    |> maybe_setup_preview_iframe(params)}
  end

  defp maybe_setup_preview_iframe(socket, %{"id" => portfolio_id}) do
    if socket.assigns.preview_mode == :split do
      socket
      |> push_event("setup_preview_iframe", %{
        portfolio_id: portfolio_id,
        preview_url: "/portfolios/#{portfolio_id}/editor_preview"
      })
    else
      socket
    end
  end

  # Add this helper function:
  defp safe_get_sections(portfolio_id) do
    try do
      case Portfolios.list_portfolio_sections(portfolio_id) do
        sections when is_list(sections) -> sections
        _ -> []
      end
    rescue
      _error -> []
    end
  end


  # ============================================================================
  # CORE EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    new_mode = if socket.assigns.preview_mode == :split, do: :editor, else: :split
    {:noreply, assign(socket, :preview_mode, new_mode)}
  end

  @impl true
  def handle_event("create_section", %{"section_type" => section_type}, socket) do
    # Convert string to atom for enum compatibility
    section_type_atom = case section_type do
      "hero" -> :intro  # Map "hero" to :intro since that's in the enum
      "about" -> :narrative
      other -> String.to_atom(other)
    end

    section_params = %{
      section_type: section_type_atom,  # Use atom instead of string
      title: get_default_section_title(section_type),
      content: get_default_section_content(section_type),
      position: length(socket.assigns.sections),
      visible: true
    }

    IO.puts("🔥 SECTION PARAMS: #{inspect(section_params)}")

    case Portfolios.create_portfolio_section(socket.assigns.portfolio.id, section_params) do
      {:ok, section} ->
        sections = socket.assigns.sections ++ [section]

        # Update portfolio with ALL section fields for consistency
        updated_portfolio = socket.assigns.portfolio
                          |> Map.put(:sections, sections)
                          |> Map.put(:visible_sections, sections)
                          |> Map.put(:visible_non_hero_sections, Enum.reject(sections, &is_hero_section?/1))

        broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:sections, sections)
        |> assign(:editing_section, section)
        |> assign(:show_section_modal, true)
        |> put_flash(:info, "Section created successfully")}

      {:error, changeset} ->
        IO.puts("❌ SECTION CREATION ERROR: #{inspect(changeset.errors)}")
        {:noreply, socket
        |> put_flash(:error, "Failed to create section")
        |> assign(:section_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("reorder_sections", %{"sections" => section_order}, socket) do
    try do
      # Convert string IDs to integers and validate
      section_ids = Enum.map(section_order, fn id_str ->
        case Integer.parse(id_str) do
          {id, ""} -> id
          _ -> raise "Invalid section ID: #{id_str}"
        end
      end)

      # Verify all sections exist
      existing_ids = Enum.map(socket.assigns.sections, & &1.id)
      missing_ids = section_ids -- existing_ids

      if length(missing_ids) > 0 do
        raise "Missing sections: #{inspect(missing_ids)}"
      end

      # Reorder sections and update positions in database
      case update_section_positions(section_ids, socket.assigns.portfolio.id) do
        {:ok, updated_sections} ->
          # Update both visible_sections and sections in portfolio
          updated_portfolio = socket.assigns.portfolio
                            |> Map.put(:sections, updated_sections)
                            |> Map.put(:visible_sections, updated_sections)

          broadcast_preview_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          # Force UI refresh
          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:sections, updated_sections)
          |> push_event("sections_reordered", %{sections: updated_sections})
          |> put_flash(:info, "Section order updated successfully")}

        {:error, reason} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to reorder sections: #{reason}")}
      end
    rescue
      error ->
        IO.inspect(error, label: "Section reorder error")
        {:noreply, socket
        |> put_flash(:error, "Failed to reorder sections. Please try again.")}
    end
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        {:noreply, socket
        |> assign(:editing_section, section)
        |> assign(:show_section_modal, true)}
    end
  end

  @impl true
  def handle_event("save_section", params, socket) do
    section = socket.assigns.editing_section

    case Portfolios.update_portfolio_section(section, format_section_params(params)) do
      {:ok, updated_section} ->
        sections = update_section_in_list(socket.assigns.sections, updated_section)

        # Update portfolio with ALL section fields for consistency
        updated_portfolio = socket.assigns.portfolio
                          |> Map.put(:sections, sections)
                          |> Map.put(:visible_sections, sections)
                          |> Map.put(:visible_non_hero_sections, Enum.reject(sections, &is_hero_section?/1))

        broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:sections, sections)
        |> assign(:show_section_modal, false)
        |> assign(:editing_section, nil)
        |> put_flash(:info, "Section updated successfully")}

      {:error, changeset} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update section")
        |> assign(:section_changeset, changeset)}
    end
  end


  @impl true
  def handle_event("toggle_section_visibility", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, socket}

      section ->
        case Portfolios.update_portfolio_section(section, %{visible: !section.visible}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> push_event("section_visibility_changed", %{
              section_id: updated_section.id,
              visible: updated_section.visible
            })}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to update section visibility")}
        end
    end
  end

  @impl true
  def handle_event("delete_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, socket}

      section ->
        case Portfolios.delete_portfolio_section(section) do
          {:ok, _} ->
            sections = Enum.reject(socket.assigns.sections, &(&1.id == section.id))

            # Update portfolio with ALL section fields for consistency
            updated_portfolio = socket.assigns.portfolio
                              |> Map.put(:sections, sections)
                              |> Map.put(:visible_sections, sections)
                              |> Map.put(:visible_non_hero_sections, Enum.reject(sections, &is_hero_section?/1))

            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:portfolio, updated_portfolio)
            |> assign(:sections, sections)
            |> put_flash(:info, "Section deleted successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete section")}
        end
    end
  end

  @impl true
  def handle_event("update_customization", params, socket) do
    IO.puts("🔥 UPDATE_CUSTOMIZATION RECEIVED: #{inspect(params)}")

    # Extract only the customization fields, ignoring form metadata
    customization_params = extract_customization_params(params)
    IO.puts("🔥 EXTRACTED CUSTOMIZATION PARAMS: #{inspect(customization_params)}")

    if map_size(customization_params) == 0 do
      IO.puts("🔥 NO VALID CUSTOMIZATION PARAMS FOUND")
      {:noreply, socket}
    else
      # Immediately update UI for responsiveness
      updated_customization = Map.merge(socket.assigns.customization, customization_params)
      IO.puts("🔥 UPDATED CUSTOMIZATION: #{inspect(updated_customization)}")

      # Send immediate update to preview
      broadcast_preview_update(socket.assigns.portfolio.id, socket.assigns.sections, updated_customization)

      # Cancel any pending debounced update
      if socket.assigns[:debounce_timer] do
        Process.cancel_timer(socket.assigns.debounce_timer)
      end

      # Set up new debounced database update using ID
      timer = Process.send_after(self(), {:debounced_customization_update, socket.assigns.portfolio.id, customization_params}, 500)

      {:noreply, socket
      |> assign(:customization, updated_customization)
      |> assign(:debounce_timer, timer)
      |> push_event("design_updated", %{customization: updated_customization})}
    end
  end

@impl true
def handle_info({:debounced_customization_update, portfolio_id, customization_params}, socket) do
  case Portfolios.update_portfolio_customization_by_id(portfolio_id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> assign(:debounce_timer, nil)
      |> assign(:last_updated, DateTime.utc_now())}

    {:error, changeset} ->
      IO.inspect(changeset, label: "Customization Update Error")
      {:noreply, socket
      |> assign(:debounce_timer, nil)
      |> put_flash(:error, "Failed to save design changes")}
  end
end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:editing_section, nil)}
  end

  @impl true
  def handle_event("upload_media", _params, socket) do
    # Handle media upload for sections
    {:noreply, socket}
  end

  defp update_section_positions(section_ids, portfolio_id) do
    Portfolios.update_section_positions(section_ids, portfolio_id)
  end

  @impl true
  def handle_event("toggle_create_dropdown", _params, socket) do
    current_state = Map.get(socket.assigns, :show_create_dropdown, false)
    IO.puts("🔥 TOGGLING DROPDOWN: #{current_state} -> #{!current_state}")

    {:noreply, assign(socket, :show_create_dropdown, !current_state)}
  end

  @impl true
  def handle_event("update_single_color", params, socket) do
    IO.puts("🎨 SINGLE COLOR UPDATE: #{inspect(params)}")

    field = params["field"]
    value = params["value"] || params[field]

    if field && value do
      customization_params = %{field => value}

      case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
        {:ok, updated_portfolio} ->
          IO.puts("🎨 COLOR UPDATED - UPDATING SOCKET")

          updated_customization = updated_portfolio.customization
          broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_customization)

          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_customization)
          |> assign(:last_updated, DateTime.utc_now())
          |> push_event("design_updated", %{customization: updated_customization})}

        {:error, changeset} ->
          IO.puts("❌ COLOR UPDATE ERROR: #{inspect(changeset.errors)}")
          {:noreply, socket |> put_flash(:error, "Failed to update color")}
      end
    else
      {:noreply, socket}
    end
  end

  # Add this helper function to debug state
  defp debug_socket_state(socket, action) do
    IO.puts("🔍 SOCKET STATE DEBUG - #{action}")
    IO.puts("🔍 Portfolio ID: #{socket.assigns.portfolio.id}")
    IO.puts("🔍 Customization in socket: #{inspect(socket.assigns.customization)}")
    IO.puts("🔍 Customization in portfolio: #{inspect(socket.assigns.portfolio.customization)}")
    socket
  end

  @impl true
  def handle_event("update_typography", params, socket) do
    IO.puts("🔥 TYPOGRAPHY UPDATE: #{inspect(params)}")

    field = params["field"]
    value = params["value"] || params[field]

    if field && value do
      customization_params = %{field => value}

      case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
        {:ok, updated_portfolio} ->
          broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> assign(:last_updated, DateTime.utc_now())}

        {:error, _} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to update typography")}
      end
    else
      {:noreply, socket}
    end
  end

@impl true
def handle_event("update_hero_style", %{"style" => style}, socket) do
  customization_params = %{"hero_style" => style}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Hero style updated successfully")}

    {:error, _} ->
      {:noreply, socket
      |> put_flash(:error, "Failed to update hero style")}
  end
end

  @impl true
  def handle_event("update_hero_background", params, socket) do
    section_id = String.to_integer(params["section_id"])
    background_type = params["background_type"]

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Hero section not found")}

      section ->
        updated_content = Map.put(section.content || %{}, "background_type", background_type)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:hero_section, updated_section)
            |> put_flash(:info, "Hero background updated successfully")}

          {:error, _} ->
            {:noreply, socket
            |> put_flash(:error, "Failed to update hero background")}
        end
    end
  end

  @impl true
  def handle_event("toggle_hero_social", params, socket) do
    section_id = String.to_integer(params["section_id"])

    case Enum.find(socket.assigns.sections, &(&1.id == section_id)) do
      nil ->
        {:noreply, put_flash(socket, :error, "Hero section not found")}

      section ->
        current_value = get_in(section.content, ["show_social"]) == true
        updated_content = Map.put(section.content || %{}, "show_social", !current_value)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> assign(:hero_section, updated_section)
            |> put_flash(:info, "Social links setting updated")}

          {:error, _} ->
            {:noreply, socket
            |> put_flash(:error, "Failed to update social links setting")}
        end
    end
  end

@impl true
def handle_event("apply_color_preset", %{"preset" => preset_json}, socket) do
  IO.puts("🔥 APPLYING COLOR PRESET: #{preset_json}")

  case Jason.decode(preset_json) do
    {:ok, preset} ->
      customization_params = %{
        "primary_color" => preset["primary"],
        "secondary_color" => preset["secondary"],
        "accent_color" => preset["accent"]
      }

      # Use the helper function that takes ID
      case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
        {:ok, updated_portfolio} ->
          broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

          {:noreply, socket
          |> assign(:portfolio, updated_portfolio)
          |> assign(:customization, updated_portfolio.customization)
          |> put_flash(:info, "Color preset applied successfully")}

        {:error, _} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to apply color preset")}
      end

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Invalid color preset")}
  end
end

  @impl true
  def handle_event("update_hero_settings", params, socket) do
    hero_section = socket.assigns.hero_section

    case Portfolios.update_portfolio_section(hero_section, format_section_params(params)) do
      {:ok, updated_section} ->
        sections = update_section_in_list(socket.assigns.sections, updated_section)
        broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

        {:noreply, socket
        |> assign(:sections, sections)
        |> assign(:hero_section, updated_section)
        |> put_flash(:info, "Hero settings updated successfully")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update hero settings")}
    end
  end

  @impl true
  def handle_event("update_portfolio_settings", params, socket) do
    # Extract only portfolio-specific fields
    portfolio_params = %{
      "title" => params["title"],
      "description" => params["description"],
      "slug" => params["slug"],
      "visibility" => String.to_atom(params["visibility"] || "private")
    }

    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Portfolio settings updated successfully")}

      {:error, changeset} ->
        IO.inspect(changeset.errors, label: "Portfolio update errors")
        {:noreply, socket
        |> put_flash(:error, "Failed to update portfolio settings")}
    end
  end

  @impl true
  def handle_event("update_seo_settings", params, socket) do
    seo_params = %{
      "meta_description" => params["meta_description"],
      "keywords" => params["keywords"]
    }

    case Portfolios.update_portfolio_seo_settings(socket.assigns.portfolio, seo_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "SEO settings updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update SEO settings")}
    end
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        # Handle PDF export
        {:noreply, put_flash(socket, :info, "PDF export will be available soon")}

      "json" ->
        # Handle JSON export
        {:noreply, put_flash(socket, :info, "JSON export will be available soon")}

      _ ->
        {:noreply, put_flash(socket, :error, "Invalid export format")}
    end
  end

  @impl true
  def handle_event("add_section_item", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        content = section.content || %{}
        items = Map.get(content, "items", [])
        new_item = get_default_item_for_section_type(section.section_type)
        updated_content = Map.put(content, "items", items ++ [new_item])

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Item added successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to add item")}
        end
    end
  end

  @impl true
  def handle_event("remove_section_item", %{"section_id" => section_id, "item_index" => item_index}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        content = section.content || %{}
        items = Map.get(content, "items", [])
        index = String.to_integer(item_index)
        updated_items = List.delete_at(items, index)
        updated_content = Map.put(content, "items", updated_items)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} ->
            sections = update_section_in_list(socket.assigns.sections, updated_section)
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Item removed successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to remove item")}
        end
    end
  end

  @impl true
  def handle_event("duplicate_section", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Section not found")}

      section ->
        duplicate_params = %{
          section_type: section.section_type,
          title: "#{section.title} (Copy)",
          content: section.content,
          position: length(socket.assigns.sections),
          visible: section.visible
        }

        case Portfolios.create_portfolio_section(socket.assigns.portfolio.id, duplicate_params) do
          {:ok, new_section} ->
            sections = socket.assigns.sections ++ [new_section]
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Section duplicated successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to duplicate section")}
        end
    end
  end

    @impl true
  def handle_event("auto_save", params, socket) do
    # Process auto-save data
    case extract_auto_save_data(params) do
      {:ok, save_data} ->
        # Save relevant data
        {:noreply, socket
        |> assign(:last_saved, DateTime.utc_now())
        |> push_event("auto_save_success", %{timestamp: DateTime.utc_now()})}

      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp extract_auto_save_data(params) do
    # Extract and validate auto-save data
    {:ok, params}
  end

  @impl true
  def handle_event("show_video_recorder", _params, socket) do
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("show_video_uploader", _params, socket) do
    # For now, show recorder (can be extended to show upload modal)
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("edit_video_intro", _params, socket) do
    {:noreply, assign(socket, :show_video_recorder, true)}
  end

  @impl true
  def handle_event("delete_video_intro", %{"section_id" => section_id}, socket) do
    case Enum.find(socket.assigns.sections, &(&1.id == String.to_integer(section_id))) do
      nil ->
        {:noreply, put_flash(socket, :error, "Video section not found")}

      section ->
        case Portfolios.delete_portfolio_section(section) do
          {:ok, _} ->
            sections = Enum.reject(socket.assigns.sections, &(&1.id == section.id))
            broadcast_preview_update(socket.assigns.portfolio.id, sections, socket.assigns.customization)

            {:noreply, socket
            |> assign(:sections, sections)
            |> put_flash(:info, "Video introduction deleted successfully")}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to delete video introduction")}
        end
    end
  end

  @impl true
  def handle_event("show_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, true)}
  end

  @impl true
  def handle_event("close_resume_import", _params, socket) do
    {:noreply, assign(socket, :show_resume_import, false)}
  end

  @impl true
  def handle_event("validate_resume", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_resume", _params, socket) do
    case uploaded_entries(socket, :resume) do
      {[entry], _} ->
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # For now, just show success message
          # You can implement actual resume parsing later
          {:ok, :file_uploaded}
        end)

        {:noreply, socket
        |> assign(:show_resume_import, false)
        |> put_flash(:info, "Resume uploaded successfully! (Processing not yet implemented)")}

      _ ->
        {:noreply, socket
        |> put_flash(:error, "Please select a resume file")}
    end
  end

def update_portfolio_customization(%Portfolio{} = portfolio, customization_params) do
  IO.puts("🔥 UPDATING PORTFOLIO CUSTOMIZATION")
  IO.puts("🔥 Portfolio ID: #{portfolio.id}")
  IO.puts("🔥 Current: #{inspect(portfolio.customization)}")
  IO.puts("🔥 Params: #{inspect(customization_params)}")

  # Get current customization (with defaults)
  current_customization = portfolio.customization || %{
    "color_scheme" => "purple-pink",
    "layout_style" => "single_page",
    "section_spacing" => "normal",
    "font_style" => "inter",
    "fixed_navigation" => true,
    "dark_mode_support" => false
  }

  # Merge new parameters
  updated_customization = Map.merge(current_customization, customization_params)

  IO.puts("🔥 Merged: #{inspect(updated_customization)}")

  # Update using changeset
  result = portfolio
  |> Portfolio.changeset(%{customization: updated_customization})
  |> Repo.update()

  case result do
    {:ok, updated_portfolio} ->
      IO.puts("✅ CUSTOMIZATION UPDATED SUCCESSFULLY")
      {:ok, updated_portfolio}

    {:error, changeset} ->
      IO.puts("❌ CUSTOMIZATION UPDATE ERROR: #{inspect(changeset.errors)}")
      IO.puts("❌ CHANGESET DETAILS: #{inspect(changeset)}")
      {:error, changeset}
  end
end

  # ============================================================================
  # PUBSUB HANDLERS
  # ============================================================================

  @impl true
  def handle_info({:section_updated, section}, socket) do
    sections = update_section_in_list(socket.assigns.sections, section)
    {:noreply, assign(socket, :sections, sections)}
  end

  @impl true
  def handle_info({:preview_update, update_data}, socket) do
    # Handle preview updates from other sources
    {:noreply, socket
    |> assign(:sections, Map.get(update_data, :sections, socket.assigns.sections))
    |> assign(:customization, Map.get(update_data, :customization, socket.assigns.customization))}
  end

  @impl true
  def handle_info({:portfolio_updated, portfolio}, socket) do
    {:noreply, assign(socket, :portfolio, portfolio)}
  end

  # Handle messages from video component
  @impl true
  def handle_info(:close_video_recorder, socket) do
    {:noreply, assign(socket, :show_video_recorder, false)}
  end

  @impl true
  def handle_info({:video_intro_complete, video_data}, socket) do
    # Refresh sections to include the new video
    case Portfolios.get_portfolio_with_sections(socket.assigns.portfolio.id) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:sections, updated_portfolio.sections)
        |> assign(:show_video_recorder, false)
        |> put_flash(:info, "Video introduction added successfully!")}

      {:error, _} ->
        {:noreply, socket
        |> assign(:show_video_recorder, false)
        |> put_flash(:info, "Video saved! Refresh to see changes.")}
    end
  end

  @impl true
  def handle_info({:debounced_portfolio_update, params}, socket) do
    handle_event("update_portfolio_settings", params, socket)
  end

  @impl true
  def handle_info({:debounced_seo_update, params}, socket) do
    handle_event("update_seo_settings", params, socket)
  end

  @impl true
  def handle_info(msg, socket) do
    # Log unhandled messages for debugging
    IO.inspect(msg, label: "Unhandled handle_info message")
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_visibility", %{"visibility" => visibility}, socket) do
    portfolio_params = %{"visibility" => String.to_atom(visibility)}

    case Portfolios.update_portfolio(socket.assigns.portfolio, portfolio_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Visibility updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update visibility")}
    end
  end

  @impl true
  def handle_event("toggle_social_sharing", _params, socket) do
    portfolio = socket.assigns.portfolio
    current_seo_settings = Map.get(portfolio, :seo_settings, %{})
    current_value = Map.get(current_seo_settings, "social_sharing_enabled", false)

    seo_params = %{
      "social_sharing_enabled" => !current_value
    }

    case Portfolios.update_portfolio_seo_settings(portfolio, seo_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Social sharing setting updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update social sharing setting")}
    end
  end

  @impl true
  def handle_event("toggle_analytics", _params, socket) do
    portfolio = socket.assigns.portfolio
    current_settings = Map.get(portfolio, :settings, %{})
    current_value = Map.get(current_settings, "analytics_enabled", false)

    settings_params = %{
      "analytics_enabled" => !current_value
    }

    case Portfolios.update_portfolio_settings(portfolio, settings_params) do
      {:ok, updated_portfolio} ->
        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> put_flash(:info, "Analytics setting updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update analytics setting")}
    end
  end

  @impl true
  def handle_event("update_custom_css", %{"custom_css" => custom_css}, socket) do
    customization_params = %{"custom_css" => custom_css}

    case Portfolios.update_portfolio_customization(socket.assigns.portfolio, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Custom CSS updated")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update custom CSS")}
    end
  end

  @impl true
  def handle_event("update_portfolio_layout", %{"layout" => layout}, socket) do
    IO.puts("🔥 APPLYING LAYOUT CHANGE: #{layout}")  # Add this logging line

    customization_params = %{
      "portfolio_layout" => layout
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Layout updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update layout")}
    end
  end

  @impl true
  def handle_event("update_font_family", %{"font" => font}, socket) do
    IO.puts("🔥 APPLYING FONT CHANGE: #{font}")

    customization_params = %{
      "font_family" => font
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Font updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update font")}
    end
  end

  @impl true
  def handle_event("update_theme", %{"theme" => theme}, socket) do
    IO.puts("🔥 APPLYING THEME CHANGE: #{theme}")

    customization_params = %{
      "layout_style" => theme
    }

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_preview_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Theme updated successfully")}

      {:error, _} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to update theme")}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, "sections")
    |> assign(:preview_mode, :split)
    |> assign(:show_section_modal, false)
    |> assign(:editing_section, nil)
    |> assign(:section_changeset, nil)
    |> assign(:show_create_dropdown, false)
    |> assign(:show_video_recorder, false)
    |> assign(:show_resume_import, false)
    |> assign(:pending_customization_update, false)
    |> assign(:debounce_timer, nil)
    |> assign(:last_updated, DateTime.utc_now())
    |> assign(:section_types, @section_types)  # FIXED: Add this line
    |> allow_upload(:resume,
      accept: ~w(.pdf .doc .docx .txt),
      max_entries: 1,
      max_file_size: 5_000_000)
  end

  defp assign_editor_state(socket) do
    socket
    |> assign(:editor_mode, :edit)
    |> assign(:autosave_enabled, true)
    |> assign(:last_saved, DateTime.utc_now())
  end

  defp ensure_all_assigns(socket) do
    required_assigns = [
      :show_video_recorder,
      :pending_customization_update,
      :show_section_modal,
      :editing_section,
      :section_changeset,
      :show_create_dropdown,
      :current_user,
      :preview_mode,
      :autosave_enabled,
      :last_saved
    ]

    Enum.reduce(required_assigns, socket, fn assign_key, acc_socket ->
      if Map.has_key?(acc_socket.assigns, assign_key) do
        acc_socket
      else
        case assign_key do
          :show_video_recorder -> assign(acc_socket, :show_video_recorder, false)
          :pending_customization_update -> assign(acc_socket, :pending_customization_update, false)
          :show_section_modal -> assign(acc_socket, :show_section_modal, false)
          :editing_section -> assign(acc_socket, :editing_section, nil)
          :section_changeset -> assign(acc_socket, :section_changeset, nil)
          :show_create_dropdown -> assign(acc_socket, :show_create_dropdown, false)
          :current_user -> assign(acc_socket, :current_user, get_current_user_from_session(acc_socket))
          :preview_mode -> assign(acc_socket, :preview_mode, :split)
          :autosave_enabled -> assign(acc_socket, :autosave_enabled, true)
          :last_saved -> assign(acc_socket, :last_saved, DateTime.utc_now())
          _ -> acc_socket
        end
      end
    end)
  end

  defp is_hero_section?(section) do
    section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
    section_type == :hero or section_type == "hero"
  end

  defp find_hero_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section_type = Map.get(section, :section_type) || Map.get(section, "section_type")
      section_type == :hero or section_type == "hero"
    end)
  end
  defp find_hero_section(_), do: nil

  defp safe_get_sections(portfolio_id) do
    try do
      case Portfolios.list_portfolio_sections(portfolio_id) do
        sections when is_list(sections) -> sections
        _ -> []
      end
    rescue
      _error -> []
    end
  end

  defp get_current_user_from_session(session) do
    case session do
      %{"user_token" => user_token} when not is_nil(user_token) ->
        # Try to get user from token - adapt this to your auth system
        case Frestyl.Accounts.get_user_by_session_token(user_token) do
          %Frestyl.Accounts.User{} = user -> user
          _ -> create_fallback_user()
        end

      _ -> create_fallback_user()
    end
  rescue
    _ -> create_fallback_user()
  end

  defp create_fallback_user do
    %{
      id: -1,  # Use -1 to indicate this is a fallback user
      username: "User",
      name: "Anonymous User",
      email: "user@example.com",
      subscription_tier: "free",
      role: "user",
      verified: false,
      status: "active",
      preferences: %{},
      social_links: %{},
      avatar_url: nil,
      display_name: "User",
      full_name: nil,
      totp_enabled: false,
      backup_codes: [],
      created_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  defp get_default_section_title(section_type) do
    case section_type do
      "hero" -> "Welcome"
      "about" -> "About Me"
      "experience" -> "Experience"
      "education" -> "Education"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "testimonials" -> "Testimonials"
      "contact" -> "Contact"
      "certifications" -> "Certifications"
      "achievements" -> "Achievements"
      "services" -> "Services"
      "blog" -> "Blog"
      "gallery" -> "Gallery"
      "custom" -> "Custom Section"
      _ -> "New Section"
    end
  end

  defp get_default_section_content(section_type) do
    case section_type do
      "hero" -> %{
        "headline" => "Your Name Here",
        "tagline" => "Your Professional Title",
        "description" => "Brief description about yourself",
        "cta_text" => "Get In Touch",
        "cta_link" => "#contact"
      }
      "about" -> %{
        "content" => "Tell your story here...",
        "image_url" => "",
        "highlights" => []
      }
      "experience" -> %{
        "items" => []
      }
      "skills" -> %{
        "categories" => []
      }
      "projects" -> %{
        "items" => []
      }
      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "show_form" => true
      }
      _ -> %{
        "content" => "Add your content here..."
      }
    end
  end

  defp get_section_description(section_type) do
    case section_type do
      "hero" -> "Main banner with headline and call-to-action"
      "about" -> "Personal introduction and background"
      "experience" -> "Work history and career timeline"
      "education" -> "Academic background and qualifications"
      "skills" -> "Technical and professional abilities"
      "projects" -> "Portfolio projects and case studies"
      "testimonials" -> "Client reviews and recommendations"
      "contact" -> "Contact information and form"
      "certifications" -> "Professional certifications"
      "achievements" -> "Awards and accomplishments"
      "services" -> "Services offered with pricing"
      "blog" -> "Blog posts and articles"
      "gallery" -> "Image gallery showcase"
      "custom" -> "Flexible custom content section"
      _ -> "Additional portfolio content"
    end
  end

  defp format_section_params(params) do
    content = build_section_content(params)

    %{
      title: params["title"] || "",
      content: content,
      visible: params["visible"] != "false"
    }
  end

  defp build_section_content(params) do
    params
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      if key not in ["title", "visible", "section_id", "_target"] do
        Map.put(acc, key, value)
      else
        acc
      end
    end)
  end

  defp extract_customization_params(params) do
    IO.puts("🔥 EXTRACTING FROM PARAMS: #{inspect(params)}")

    # Define all possible customization fields
    customization_fields = [
      "primary_color", "secondary_color", "accent_color",
      "primary_color_text", "secondary_color_text", "accent_color_text",
      "font_family", "layout_style", "hero_style", "portfolio_layout"
    ]

    # Filter and extract valid customization fields
    result = params
    |> Enum.filter(fn {key, value} ->
      is_valid = key in customization_fields and not is_nil(value) and value != ""
      if is_valid do
        IO.puts("🔥 VALID PARAM: #{key} = #{value}")
      else
        IO.puts("🔥 FILTERED OUT: #{key} = #{inspect(value)}")
      end
      is_valid
    end)
    |> Map.new()

    IO.puts("🔥 EXTRACTION RESULT: #{inspect(result)}")
    result
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id, do: updated_section, else: section
    end)
  end

  defp reorder_sections_by_ids(sections, section_order) do
    # Reorder sections based on provided order and update positions
    sections
    |> Enum.sort_by(fn section ->
      Enum.find_index(section_order, &(&1 == to_string(section.id))) || 999
    end)
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      Map.put(section, :position, index)
    end)
  end

  defp broadcast_preview_update(portfolio_id, sections, customization) do
    IO.puts("🔄 BROADCASTING PREVIEW UPDATE")

    update_data = %{
      sections: sections,
      customization: customization,
      updated_at: DateTime.utc_now()
    }

    # Broadcast to preview LiveView
    PubSub.broadcast(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}", {
      :preview_update,
      update_data
    })

    IO.puts("✅ PREVIEW UPDATE BROADCASTED")
  end

  defp time_ago(datetime) when is_struct(datetime, DateTime) do
    case DateTime.diff(DateTime.utc_now(), datetime, :second) do
      seconds when seconds < 60 -> "just now"
      seconds when seconds < 3600 -> "#{div(seconds, 60)}m ago"
      seconds when seconds < 86400 -> "#{div(seconds, 3600)}h ago"
      seconds -> "#{div(seconds, 86400)}d ago"
    end
  end
  defp time_ago(_), do: "unknown"

  defp get_color_suggestions do
    [
      %{name: "Ocean Blue", primary: "#1e40af", secondary: "#64748b", accent: "#3b82f6"},
      %{name: "Forest Green", primary: "#059669", secondary: "#6b7280", accent: "#10b981"},
      %{name: "Sunset Orange", primary: "#ea580c", secondary: "#6b7280", accent: "#f97316"},
      %{name: "Royal Purple", primary: "#7c3aed", secondary: "#6b7280", accent: "#8b5cf6"},
      %{name: "Rose Gold", primary: "#be185d", secondary: "#6b7280", accent: "#ec4899"},
      %{name: "Charcoal", primary: "#374151", secondary: "#6b7280", accent: "#6366f1"}
    ]
  end

  defp get_font_preview_style(font) do
    case font do
      "inter" -> "font-family: 'Inter', sans-serif;"
      "serif" -> "font-family: 'Times New Roman', serif;"
      "mono" -> "font-family: 'Monaco', monospace;"
      "system" -> "font-family: -apple-system, BlinkMacSystemFont, sans-serif;"
      _ -> ""
    end
  end

  defp extract_portfolio_settings_params(params) do
    %{
      title: params["title"],
      description: params["description"],
      slug: params["slug"],
      visibility: String.to_atom(params["visibility"] || "private")
    }
  end

  defp extract_seo_settings_params(params) do
    %{
      seo_settings: %{
        "meta_description" => params["meta_description"],
        "keywords" => params["keywords"],
        "social_sharing_enabled" => params["social_sharing_enabled"] == "true"
      }
    }
  end

  defp get_default_item_for_section_type(section_type) do
    case section_type do
      "experience" -> %{
        "title" => "",
        "company" => "",
        "duration" => "",
        "description" => "",
        "location" => ""
      }

      "skills" -> %{
        "name" => "",
        "skills" => []
      }

      "projects" -> %{
        "title" => "",
        "description" => "",
        "technologies" => "",
        "url" => "",
        "image_url" => ""
      }

      "testimonials" -> %{
        "name" => "",
        "title" => "",
        "company" => "",
        "content" => "",
        "avatar_url" => "",
        "rating" => 5
      }

      "education" -> %{
        "degree" => "",
        "institution" => "",
        "duration" => "",
        "description" => "",
        "gpa" => ""
      }

      "certifications" -> %{
        "name" => "",
        "issuer" => "",
        "date" => "",
        "expiry" => "",
        "credential_id" => "",
        "url" => ""
      }

      "achievements" -> %{
        "title" => "",
        "organization" => "",
        "date" => "",
        "description" => ""
      }

      "services" -> %{
        "title" => "",
        "description" => "",
        "price" => "",
        "price_type" => "hour",
        "features" => "",
        "booking_enabled" => false
      }

      "blog" -> %{
        "title" => "",
        "excerpt" => "",
        "category" => "",
        "published_date" => "",
        "read_time" => "",
        "author" => "",
        "url" => "",
        "featured_image" => ""
      }

      "gallery" -> %{
        "url" => "",
        "caption" => "",
        "alt_text" => ""
      }

      _ -> %{
        "title" => "",
        "description" => ""
      }
    end
  end

  defp get_default_section_content(section_type) do
    case section_type do
      "hero" -> %{
        "headline" => "",
        "tagline" => "",
        "description" => "",
        "cta_text" => "",
        "cta_link" => "",
        "background_type" => "gradient",
        "show_social" => false,
        "video_enabled" => false
      }
      "about" -> %{
        "content" => "",
        "image_url" => "",
        "highlights" => []
      }
      "experience" -> %{
        "items" => []
      }
      "education" -> %{
        "items" => []
      }
      "skills" -> %{
        "categories" => []
      }
      "projects" -> %{
        "items" => []
      }
      "testimonials" -> %{
        "items" => []
      }
      "contact" -> %{
        "email" => "",
        "phone" => "",
        "location" => "",
        "social_links" => %{},
        "contact_form_enabled" => true
      }
      "certifications" -> %{
        "items" => []
      }
      "achievements" -> %{
        "items" => []
      }
      "services" -> %{
        "items" => []
      }
      "blog" -> %{
        "items" => []
      }
      "gallery" -> %{
        "images" => [],
        "layout_style" => "grid"
      }
      "custom" -> %{
        "title" => "",
        "content" => "",
        "layout_type" => "text",
        "images" => [],
        "video_url" => "",
        "embed_code" => "",
        "custom_css" => "",
        "background_color" => "#ffffff",
        "text_color" => "#000000",
        "show_border" => false,
        "padding" => "normal"
      }
      _ -> %{}
    end
  end

  defp get_section_content_safe(section) do
    case section.content do
      content when is_binary(content) -> content
      content when is_map(content) -> Map.get(content, "content", "")
      _ -> ""
    end
  end

  defp find_video_intro_section(sections) when is_list(sections) do
    Enum.find(sections, fn section ->
      section.section_type == :media_showcase or
      (is_binary(section.section_type) and section.section_type == "media_showcase") or
      (section.section_type == "video" or section.section_type == :video) or
      (get_in(section.content, ["video_type"]) == "introduction")
    end)
  end
  defp find_video_intro_section(_), do: nil

  defp get_user_tier(user) when is_map(user) do
    Map.get(user, :subscription_tier, "free")
  end
  defp get_user_tier(_), do: "free"

  defp format_video_duration(duration_seconds) when is_integer(duration_seconds) do
    minutes = div(duration_seconds, 60)
    seconds = rem(duration_seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(seconds), 2, "0")}"
  end
  defp format_video_duration(_), do: "Unknown"

  defp format_position_name(position) do
    case position do
      "hero" -> "Hero Section"
      "about" -> "About Section"
      "sidebar" -> "Sidebar"
      "footer" -> "Footer"
      _ -> "Hero Section"
    end
  end

  defp assign_defaults(assigns) do
    defaults = %{
      show_video_recorder: false,
      current_user: %{subscription_tier: "free"},
      hero_section: nil
    }

    Enum.reduce(defaults, assigns, fn {key, default_value}, acc ->
      if Map.has_key?(acc, key) do
        acc
      else
        Map.put(acc, key, default_value)
      end
    end)
  end

  # ============================================================================
  # RENDER FUNCTIONS
  # ============================================================================

  def render(assigns) do
    section_types = [
      "intro", "experience", "education", "skills", "projects",
      "testimonial", "contact", "custom", "achievements",
      "narrative", "journey", "timeline", "media_showcase"
    ]

    assigns = Map.merge(%{
      show_video_recorder: false,
      current_user: %{subscription_tier: "free"},
      hero_section: nil,
      show_section_modal: false,
      editing_section: nil,
      active_tab: "sections",
      preview_mode: :split,
      sections: [],
      customization: %{},
      portfolio: %{},
      section_types: @section_types  # FIXED: Add this
    }, assigns)

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <.nav {assigns} />

      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <!-- Editor Header -->
        <div class="mb-8">
          <h1 class="text-3xl font-bold text-gray-900">Portfolio Editor</h1>
          <p class="text-gray-600 mt-2">Customize your portfolio and preview changes in real-time</p>
        </div>

        <!-- Tab Navigation -->
        <div class="border-b border-gray-200 mb-8">
          <nav class="-mb-px flex space-x-8">
            <%= for {tab_id, tab_name} <- [{"sections", "Sections"}, {"design", "Design"}, {"settings", "Settings"}] do %>
              <button
                phx-click="switch_tab"
                phx-value-tab={tab_id}
                class={[
                  "py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                  if(Map.get(assigns, :active_tab, "sections") == tab_id,
                    do: "border-gray-900 text-gray-900",
                    else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                ]}>
                <%= tab_name %>
              </button>
            <% end %>
          </nav>
        </div>

        <!-- FIXED: Main content with proper grid layout -->
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Editor Panel -->
          <div class="space-y-6">
            <%= case Map.get(assigns, :active_tab, "sections") do %>
              <% "sections" -> %>
                <.render_sections_tab {assigns} />
              <% "design" -> %>
                <.render_design_tab {assigns} />
              <% "settings" -> %>
                <.render_settings_tab {assigns} />
              <% _ -> %>
                <.render_sections_tab {assigns} />
            <% end %>
          </div>

          <!-- Preview Panel -->
          <div class="lg:sticky lg:top-8 lg:h-screen">
            <div class="bg-white rounded-xl shadow-sm border overflow-hidden h-full">
              <div class="p-4 border-b border-gray-200 flex items-center justify-between">
                <h3 class="font-semibold text-gray-900">Live Preview</h3>
                <div class="flex items-center space-x-2">
                  <button
                    phx-click="toggle_preview"
                    class="text-sm text-gray-500 hover:text-gray-700">
                    <%= if Map.get(assigns, :preview_mode, :split) == :split, do: "Hide Preview", else: "Show Preview" %>
                  </button>
                  <a
                    href={"/portfolios/#{@portfolio.id}/preview"}
                    target="_blank"
                    class="text-sm text-blue-600 hover:text-blue-700">
                    Open in New Tab
                  </a>
                </div>
              </div>

              <%= if Map.get(assigns, :preview_mode, :split) == :split do %>
                <div class="h-full">
                  <iframe
                    id="portfolio-preview-frame"
                    src={"/portfolios/#{@portfolio.id}/preview"}
                    class="w-full h-full border-0"
                    phx-hook="PreviewFrame"
                    data-portfolio-id={@portfolio.id}>
                  </iframe>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Section Edit Modal -->
      <%= if Map.get(assigns, :show_section_modal, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden">
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 class="text-lg font-bold text-gray-900">
                Edit <%= Map.get(assigns, :editing_section, %{}) |> Map.get(:title, "Section") %>
              </h3>
              <button
                phx-click="close_section_modal"
                class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <div class="p-6 overflow-y-auto max-h-[calc(90vh-140px)]">
              <%= if Map.get(assigns, :editing_section) do %>
                <form phx-submit="save_section" class="space-y-6">
                  <input type="hidden" name="section_id" value={assigns.editing_section.id} />

                  <!-- Section Title -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
                    <input
                      type="text"
                      name="title"
                      value={assigns.editing_section.title}
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
                  </div>

                  <!-- Section Visibility -->
                  <div class="flex items-center">
                    <input
                      type="checkbox"
                      id="section_visible"
                      name="visible"
                      value="true"
                      checked={assigns.editing_section.visible}
                      class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                    <label for="section_visible" class="ml-2 block text-sm text-gray-900">
                      Show this section on portfolio
                    </label>
                  </div>

                  <!-- Basic content field for now -->
                  <div>
                    <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
                    <textarea
                      name="content"
                      rows="8"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                      placeholder="Add your content here..."><%= get_section_content_safe(assigns.editing_section) %></textarea>
                  </div>

                  <!-- Modal Actions -->
                  <div class="flex items-center justify-end space-x-3 pt-6 border-t border-gray-200">
                    <button
                      type="button"
                      phx-click="close_section_modal"
                      class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors">
                      Cancel
                    </button>
                    <button
                      type="submit"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors">
                      Save Section
                    </button>
                  </div>
                </form>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Video Intro Modal -->
      <%= if Map.get(assigns, :show_video_recorder, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <.live_component
            module={EnhancedVideoIntroComponent}
            id={"video-intro-recorder-modal-#{@portfolio.id}"}
            portfolio={Map.get(assigns, :portfolio, %{})}
            current_user={Map.get(assigns, :current_user, %{})}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp nav(assigns) do
    ~H"""
    <nav class="bg-white border-b border-gray-200 sticky top-0 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <!-- Left side - navigation links (unchanged) -->
          <div class="flex items-center space-x-4">
            <.link navigate={~p"/portfolios"} class="inline-flex items-center text-gray-600 hover:text-gray-900 transition-colors group">
              <svg class="w-5 h-5 mr-2 group-hover:transform group-hover:-translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 19l-7-7m0 0l7-7m-7 7h18"/>
              </svg>
              <span class="font-medium">My Portfolios</span>
            </.link>

            <div class="h-6 w-px bg-gray-300"></div>

            <.link navigate={~p"/"} class="text-xl font-bold text-gray-900">Frestyl</.link>

            <div class="hidden md:flex items-center space-x-2">
              <span class="text-gray-400">/</span>
              <span class="text-gray-700 font-medium"><%= Map.get(@portfolio, :title, "Portfolio") %></span>
            </div>
          </div>

          <!-- Right side - auto-save status and actions -->
          <div class="flex items-center space-x-4">
            <!-- Auto-save Status Indicator -->
            <div class="hidden sm:flex items-center space-x-2">
              <%= if Map.get(assigns, :debounce_timer) do %>
                <!-- Saving state -->
                <div class="flex items-center text-xs text-yellow-600">
                  <svg class="w-4 h-4 mr-1 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                  </svg>
                  Saving...
                </div>
              <% else %>
                <!-- Saved state -->
                <div class="flex items-center text-xs text-green-600">
                  <svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                    <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"/>
                  </svg>
                  Auto-saved <%= time_ago(Map.get(assigns, :last_updated, DateTime.utc_now())) %>
                </div>
              <% end %>
            </div>

            <!-- Preview Button -->
            <.link
              href={"/portfolios/#{Map.get(@portfolio, :id)}/preview"}
              target="_blank"
              class="inline-flex items-center px-3 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
              </svg>
              Preview
            </.link>

            <!-- User menu (unchanged) -->
            <%= if Map.get(assigns, :current_user) do %>
              <div class="flex items-center space-x-3">
                <span class="hidden md:block text-gray-700">
                  Hello, <%= Map.get(@current_user, :username, Map.get(@current_user, :name, "User")) %>
                </span>
                <.link navigate={~p"/logout"} class="text-red-600 hover:text-red-700 text-sm">Logout</.link>
              </div>
            <% else %>
              <.link navigate={~p"/login"} class="text-blue-600 hover:text-blue-700">Login</.link>
            <% end %>
          </div>
        </div>
      </div>
    </nav>
    """
  end

  def render_sections_tab(assigns) do
    sections = Map.get(assigns, :sections, [])
    assigns = assign(assigns, :sections, sections)

    # Find existing video intro section
    video_section = find_video_intro_section(Map.get(assigns, :sections, []))
    assigns = assign(assigns, :video_section, video_section)

    ~H"""
    <div class="space-y-6" id="sections-manager" phx-hook="DesignUpdater">

      <!-- Add Section Button -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h3 class="text-lg font-bold text-gray-900">Portfolio Sections</h3>
            <p class="text-gray-600 mt-1">Add and manage sections to showcase your work</p>
          </div>

          <!-- FIXED: Properly nested button container -->
          <div class="flex items-center space-x-3">
            <!-- Import Resume Button -->
            <button
              phx-click="show_resume_import"
              class="bg-green-600 hover:bg-green-700 text-white px-4 py-2 rounded-lg font-medium flex items-center">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              Import Resume
            </button>

            <!-- Add Section Dropdown -->
            <div class="relative">
              <button
                phx-click="toggle_create_dropdown"
                class="bg-gray-900 hover:bg-gray-800 text-white px-4 py-2 rounded-lg font-medium flex items-center">
                <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                </svg>
                Add Section
              </button>

              <%= if Map.get(assigns, :show_create_dropdown, false) do %>
                <div class="absolute right-0 mt-2 w-72 bg-white rounded-xl shadow-xl border border-gray-200 py-4 z-50">
                  <div class="px-4 pb-3 border-b border-gray-100">
                    <h4 class="font-semibold text-gray-900">Choose Section Type</h4>
                    <p class="text-sm text-gray-600">Select the type of content you want to add</p>
                  </div>

                  <div class="py-2">
                    <%= for section_type <- @section_types do %>
                      <button
                        phx-click="create_section"
                        phx-value-section_type={section_type}
                        class="w-full flex items-center space-x-3 px-4 py-3 hover:bg-gray-50 transition-colors text-left">
                        <div class="w-8 h-8 bg-gradient-to-br from-gray-100 to-gray-200 rounded-lg flex items-center justify-center">
                          <%= raw(get_section_icon(section_type)) %>
                        </div>
                        <div>
                          <div class="font-medium text-gray-900"><%= format_section_type(section_type) %></div>
                          <div class="text-sm text-gray-600"><%= get_section_description(section_type) %></div>
                        </div>
                      </button>
                    <% end %>
                  </div>
                </div>
              <% end %>
            </div>
          </div> <!-- ADDED: This was the missing closing div -->
        </div>

        <!-- Compact Video Management Section -->
        <div class="mt-6 p-4 bg-gradient-to-r from-purple-50 to-blue-50 border border-purple-200 rounded-lg">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3">
              <div class="w-10 h-10 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900">Video Introduction</h4>
                <%= if @video_section do %>
                  <p class="text-sm text-gray-600">
                    Duration: <%= format_video_duration(get_in(@video_section.content, ["duration"])) %> •
                    <%= case Map.get(assigns, :current_user, %{}) |> Map.get(:subscription_tier, "free") do %>
                      <% "free" -> %><span class="text-gray-500">1min max</span>
                      <% "pro" -> %><span class="text-blue-600">2min max</span>
                      <% "premium" -> %><span class="text-purple-600">3min max</span>
                      <% _ -> %><span class="text-gray-500">1min max</span>
                    <% end %>
                  </p>
                <% else %>
                  <p class="text-sm text-gray-600">
                    Add a personal video to welcome visitors •
                    <%= case Map.get(assigns, :current_user, %{}) |> Map.get(:subscription_tier, "free") do %>
                      <% "free" -> %><span class="text-gray-500">1min max</span>
                      <% "pro" -> %><span class="text-blue-600">2min max</span>
                      <% "premium" -> %><span class="text-purple-600">3min max</span>
                      <% _ -> %><span class="text-gray-500">1min max</span>
                    <% end %>
                  </p>
                <% end %>
              </div>
            </div>

            <div class="flex items-center space-x-2">
              <%= if @video_section do %>
                <!-- Edit/Manage Existing Video -->
                <button
                  phx-click="edit_video_intro"
                  class="bg-white hover:bg-gray-50 text-purple-700 px-3 py-2 rounded-lg text-sm font-medium border border-purple-200 transition-colors inline-flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                  </svg>
                  Update Video
                </button>

                <!-- Delete Video -->
                <button
                  phx-click="delete_video_intro"
                  phx-value-section_id={@video_section.id}
                  phx-data-confirm="Are you sure you want to delete your video introduction?"
                  class="text-red-600 hover:text-red-700 p-2 rounded-lg hover:bg-red-50 transition-colors"
                  title="Delete video">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                  </svg>
                </button>
              <% else %>
                <!-- Add New Video -->
                <button
                  phx-click="show_video_recorder"
                  class="bg-purple-600 hover:bg-purple-700 text-white px-3 py-2 rounded-lg text-sm font-medium transition-colors inline-flex items-center">
                  <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                  </svg>
                  Add Video
                </button>
              <% end %>
            </div>
          </div>

          <!-- Video Preview (if exists) -->
          <%= if @video_section && get_in(@video_section.content, ["video_url"]) do %>
            <div class="mt-3 flex justify-center">
              <video class="w-32 h-20 object-cover rounded border" controls>
                <source src={get_in(@video_section.content, ["video_url"])} type="video/webm">
                <source src={get_in(@video_section.content, ["video_url"])} type="video/mp4">
                Your browser does not support the video tag.
              </video>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Sections List with Sorting -->
      <%= if length(Map.get(assigns, :sections, [])) > 0 do %>
        <div class="bg-white rounded-xl shadow-sm border p-6">
          <div class="flex items-center justify-between mb-4">
            <h4 class="font-medium text-gray-900">Section Order</h4>
            <div class="text-sm text-gray-500">Drag sections to reorder them</div>
          </div>

          <!-- Sortable Sections Container -->
          <div
            class="space-y-3"
            id="sections-sortable"
            phx-hook="SortableSections"
            data-portfolio-id={Map.get(assigns, :portfolio, %{}) |> Map.get(:id)}>
            <%= for section <- Enum.sort_by(Map.get(assigns, :sections, []), & &1.position) do %>
              <div
                class="section-sortable-item cursor-move"
                data-section-id={section.id}
                data-position={section.position}>
                <.render_section_card section={section} />
              </div>
            <% end %>
          </div>

          <!-- Sorting Instructions -->
          <div class="mt-4 p-4 bg-blue-50 rounded-lg">
            <div class="flex items-start space-x-3">
              <svg class="w-5 h-5 text-blue-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
              <div>
                <h5 class="text-sm font-medium text-blue-900">Section Ordering</h5>
                <p class="text-sm text-blue-700 mt-1">
                  The order of sections here determines how they appear on your portfolio.
                  Drag sections up or down to reorder them.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% else %>
        <!-- Empty State -->
        <div class="bg-white rounded-xl shadow-sm border p-12 text-center">
          <div class="w-16 h-16 bg-gradient-to-br from-gray-100 to-gray-200 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>
          </div>
          <h3 class="text-lg font-semibold text-gray-900 mb-2">No sections yet</h3>
          <p class="text-gray-600 mb-6 max-w-md mx-auto">Start building your portfolio by adding your first section. Choose from our templates or create a custom section.</p>
          <button
            phx-click="create_section"
            phx-value-section_type="hero"
            class="bg-gray-900 hover:bg-gray-800 text-white px-6 py-3 rounded-lg font-medium transition-all transform hover:scale-105">
            Create Hero Section
          </button>
        </div>
      <% end %>

      <!-- Video Intro Modal -->
      <%= if Map.get(assigns, :show_video_recorder, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <.live_component
            module={EnhancedVideoIntroComponent}
            id="video-intro-recorder"
            portfolio={Map.get(assigns, :portfolio, %{})}
            current_user={Map.get(assigns, :current_user, %{})}
          />
        </div>
      <% end %>

      <!-- Resume Import Modal -->
      <%= if Map.get(assigns, :show_resume_import, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
          <div class="bg-white rounded-xl shadow-2xl max-w-2xl w-full max-h-[90vh] overflow-hidden">
            <!-- Header -->
            <div class="flex items-center justify-between p-6 border-b border-gray-200">
              <h3 class="text-lg font-bold text-gray-900 flex items-center">
                <svg class="w-6 h-6 mr-3 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                </svg>
                Import Resume
              </h3>
              <button phx-click="close_resume_import" class="text-gray-400 hover:text-gray-600">
                <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <!-- Content -->
            <div class="p-6">
              <div class="text-center mb-6">
                <p class="text-gray-600 mb-4">
                  Upload your resume to automatically populate portfolio sections with your experience, education, and skills.
                </p>
                <div class="text-sm text-gray-500">
                  Supported formats: PDF, DOC, DOCX, TXT (max 5MB)
                </div>
              </div>

              <!-- Form -->
              <form phx-submit="upload_resume" phx-change="validate_resume" class="space-y-4">
                <div class="relative">
                  <!-- Hidden file input -->
                  <.live_file_input upload={@uploads.resume} class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10" />

                  <!-- Visible dropzone -->
                  <div
                    class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-green-400 transition-colors cursor-pointer bg-gray-50 hover:bg-green-50"
                    phx-drop-target={@uploads.resume.ref}>

                    <svg class="w-12 h-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
                    </svg>

                    <p class="text-lg font-medium text-gray-900 mb-2">Drop your resume here</p>
                    <p class="text-gray-600">or click anywhere to browse</p>
                  </div>
                </div>

                <!-- Show selected files -->
                <%= for entry <- @uploads.resume.entries do %>
                  <div class="flex items-center justify-between p-3 bg-green-50 border border-green-200 rounded-lg">
                    <div class="flex items-center">
                      <svg class="w-8 h-8 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                      </svg>
                      <div>
                        <p class="font-medium text-gray-900"><%= entry.client_name %></p>
                        <p class="text-sm text-gray-600"><%= Float.round(entry.client_size / 1024 / 1024, 2) %> MB</p>
                      </div>
                    </div>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-red-600 hover:text-red-800">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                      </svg>
                    </button>
                  </div>
                <% end %>

                <!-- Upload errors -->
                <%= for err <- upload_errors(@uploads.resume) do %>
                  <div class="p-3 bg-red-50 border border-red-200 rounded-lg">
                    <p class="text-sm text-red-800"><%= error_to_string(err) %></p>
                  </div>
                <% end %>

                <!-- Actions -->
                <div class="flex justify-end space-x-3 pt-4 border-t border-gray-200">
                  <button
                    type="button"
                    phx-click="close_resume_import"
                    class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50">
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={Enum.empty?(@uploads.resume.entries)}
                    class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed">
                    Import Resume
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_design_tab(assigns) do
    customization = Map.get(assigns, :customization, %{})
    hero_section = Map.get(assigns, :hero_section)

    ~H"""
    <div class="space-y-6" id="design-updater" phx-hook="DesignUpdater">
      <!-- Portfolio Layout - Wrap in Form -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Layout</h3>

        <form phx-change="update_customization" class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Choose Layout Style</label>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for {layout, name, icon} <- [
                {"single_column", "Single Column", "<svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6h16M4 10h16M4 14h16M4 18h16'/></svg>"},
                {"dashboard", "Dashboard", "<svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 5a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM14 12a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1h-4a1 1 0 01-1-1v-7z'/></svg>"},
                {"grid", "Grid", "<svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z'/></svg>"},
                {"timeline", "Timeline", "<svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z'/></svg>"}
              ] do %>
                <button
                  type="button"
                  id={"layout-picker-#{layout}"}
                  phx-hook="LayoutPicker"
                  data-layout={layout}
                  class={[
                    "p-3 border-2 rounded-lg transition-colors text-left",
                    if(Map.get(customization, "portfolio_layout") == layout,
                      do: "border-blue-600 bg-blue-50",
                      else: "border-gray-200 hover:border-gray-300")
                  ]}>
                  <div class="flex items-center space-x-2">
                    <%= raw(icon) %>
                    <span class="text-sm font-medium text-gray-900"><%= name %></span>
                  </div>
                </button>
              <% end %>
            </div>
          </div>
        </form>
      </div>

      <!-- Typography & Theme - Wrap in Form -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Typography & Theme</h3>

        <form phx-change="update_customization" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Font Family -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Font Family</label>
                <%= for {font, name} <- [{"inter", "Inter"}, {"system", "System"}, {"serif", "Serif"}, {"mono", "Mono"}] do %>
                  <button
                    type="button"
                    id={"font-picker-#{font}"}
                    phx-hook="FontPicker"
                    data-font={font}
                    phx-value-font={font}
                    class={[
                      "p-3 border-2 rounded-lg transition-colors text-center",
                      if(Map.get(customization, "font_family") == font,
                        do: "border-blue-600 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
                    <div class="text-sm font-medium text-gray-900" style={get_font_preview_style(font)}><%= name %></div>
                  </button>
                <% end %>
            </div>

            <!-- Theme (renamed from Layout Style) -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Theme</label>
                <%= for {theme, name} <- [{"modern", "Modern"}, {"minimal", "Minimal"}, {"creative", "Creative"}, {"professional", "Professional"}] do %>
                  <button
                    type="button"
                    id={"theme-picker-#{theme}"}
                    phx-hook="ThemePicker"
                    data-theme={theme}
                    class={[
                      "p-3 border-2 rounded-lg transition-colors text-center",
                      if(Map.get(customization, "layout_style") == theme,
                        do: "border-blue-600 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
                    <div class="text-sm font-medium text-gray-900"><%= name %></div>
                  </button>
                <% end %>
            </div>
          </div>

          <!-- Hero Style -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Hero Section Style</label>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
              <%= for style <- ["gradient", "image", "video", "minimal"] do %>
                <label class="relative">
                  <input
                    type="radio"
                    name="hero_style"
                    value={style}
                    checked={Map.get(customization, "hero_style") == style}
                    class="sr-only peer">
                  <div class={[
                    "p-4 border-2 rounded-lg transition-colors text-center cursor-pointer",
                    "peer-checked:border-gray-900 peer-checked:bg-gray-50",
                    "border-gray-200 hover:border-gray-300"
                  ]}>
                    <div class="text-sm font-medium text-gray-900 capitalize"><%= style %></div>
                    <div class="text-xs text-gray-600 mt-1"><%= get_hero_style_description(style) %></div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </form>
      </div>

      <!-- Color Scheme -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Color Scheme</h3>

        <div class="space-y-6">
          <!-- Color Presets -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Quick Presets</label>
            <div class="grid grid-cols-2 gap-3">
              <%= for preset <- get_color_suggestions() do %>
                <button
                  type="button"
                  phx-click="apply_color_preset"
                  phx-value-preset={Jason.encode!(preset)}
                  class="flex items-center space-x-3 p-3 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors text-left">
                  <div class="flex space-x-1">
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.primary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.secondary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.accent}"}></div>
                  </div>
                  <span class="text-sm font-medium text-gray-900"><%= preset.name %></span>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Individual Color Inputs - FIXED WITH IDs -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
              <div class="flex items-center space-x-2">
                <!-- Color picker with required ID -->
                <input
                  id="primary-color-picker"
                  type="color"
                  name="primary_color"
                  value={Map.get(@customization, "primary_color", "#1e40af")}
                  phx-hook="ColorPicker"
                  phx-value-field="primary_color"
                  key={"primary-color-#{Map.get(@customization, "primary_color", "#1e40af")}"}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">

                <!-- Text input in its own form -->
                <form phx-change="update_single_color" phx-submit="update_single_color" class="flex-1">
                  <input type="hidden" name="field" value="primary_color">
                  <input
                    type="text"
                    name="value"
                    value={Map.get(customization, "primary_color", "#1e40af")}
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
                </form>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Secondary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  id="secondary-color-picker"
                  type="color"
                  name="secondary_color"
                  value={Map.get(customization, "secondary_color", "#64748b")}
                  phx-hook="ColorPicker"
                  phx-value-field="secondary_color"
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">

                <form phx-change="update_single_color" phx-submit="update_single_color" class="flex-1">
                  <input type="hidden" name="field" value="secondary_color">
                  <input
                    type="text"
                    name="value"
                    value={Map.get(customization, "secondary_color", "#64748b")}
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
                </form>
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
              <div class="flex items-center space-x-2">
                <input
                  id="accent-color-picker"
                  type="color"
                  name="accent_color"
                  value={Map.get(customization, "accent_color", "#3b82f6")}
                  phx-hook="ColorPicker"
                  phx-value-field="accent_color"
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">

                <form phx-change="update_single_color" phx-submit="update_single_color" class="flex-1">
                  <input type="hidden" name="field" value="accent_color">
                  <input
                    type="text"
                    name="value"
                    value={Map.get(customization, "accent_color", "#3b82f6")}
                    class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
                </form>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render_settings_tab(assigns) do
    # Safely extract portfolio data
    portfolio = Map.get(assigns, :portfolio, %{})

    # Helper function to safely get nested values from portfolio
    portfolio_title = if is_struct(portfolio), do: portfolio.title, else: Map.get(portfolio, :title, "")
    portfolio_slug = if is_struct(portfolio), do: portfolio.slug, else: Map.get(portfolio, :slug, "")
    portfolio_description = if is_struct(portfolio), do: portfolio.description, else: Map.get(portfolio, :description, "")
    portfolio_visibility = if is_struct(portfolio), do: portfolio.visibility, else: Map.get(portfolio, :visibility, :private)

    # Safe access to nested fields
    seo_settings = if is_struct(portfolio) do
      Map.get(portfolio, :seo_settings, %{})
    else
      Map.get(portfolio, :seo_settings, %{})
    end

    customization = if is_struct(portfolio) do
      Map.get(portfolio, :customization, %{})
    else
      Map.get(portfolio, :customization, %{})
    end

    settings = if is_struct(portfolio) do
      Map.get(portfolio, :settings, %{})
    else
      Map.get(portfolio, :settings, %{})
    end

    ~H"""
    <div class="space-y-6">

      <!-- Portfolio Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Settings</h3>

        <div class="space-y-6">
          <!-- Basic Info -->
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio Title</label>
              <input
                type="text"
                name="title"
                value={portfolio_title}
                phx-change="update_portfolio_settings"
                phx-debounce="1000"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
            </div>

            <div class="min-w-0"> <!-- Add min-w-0 to prevent overflow -->
              <label class="block text-sm font-medium text-gray-700 mb-2">URL Slug</label>
              <div class="flex max-w-full">
                <span class="inline-flex items-center px-3 rounded-l-lg border border-r-0 border-gray-300 bg-gray-50 text-gray-500 text-sm whitespace-nowrap">
                  frestyl.com/p/
                </span>
                <input
                  type="text"
                  name="slug"
                  value={portfolio_slug}
                  phx-change="update_portfolio_settings"
                  phx-debounce="1000"
                  class="flex-1 min-w-0 px-3 py-2 border border-gray-300 rounded-r-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              </div>
            </div>
          </div>

          <!-- Description -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea
              name="description"
              rows="3"
              phx-change="update_portfolio_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Brief description of your portfolio..."><%= portfolio_description %></textarea>
          </div>

          <!-- Visibility -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Visibility</label>
            <div class="space-y-3">
              <%= for {value, label, description} <- [
                {"public", "Public", "Anyone can find and view your portfolio"},
                {"link_only", "Link Only", "Only people with the link can view"},
                {"private", "Private", "Only you can view (perfect for drafts)"}
              ] do %>
                <label class="relative flex items-start cursor-pointer">
                  <input
                    type="radio"
                    name="visibility"
                    value={value}
                    checked={portfolio_visibility == String.to_atom(value)}
                    phx-click="update_visibility"
                    phx-value-visibility={value}
                    class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                  <div class="ml-3">
                    <div class="text-sm font-medium text-gray-900"><%= label %></div>
                    <div class="text-sm text-gray-600"><%= description %></div>
                  </div>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- SEO Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">SEO & Sharing</h3>

        <div class="space-y-4">
          <!-- Meta Description -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Meta Description</label>
            <textarea
              name="meta_description"
              rows="2"
              maxlength="160"
              phx-change="update_seo_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="Brief description for search engines..."><%= Map.get(seo_settings, "meta_description", "") %></textarea>
            <div class="text-xs text-gray-500 mt-1">
              <span id="meta-counter">0</span>/160 characters
            </div>
          </div>

          <!-- Keywords -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Keywords</label>
            <input
              type="text"
              name="keywords"
              value={Map.get(seo_settings, "keywords", "")}
              phx-change="update_seo_settings"
              phx-debounce="1000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              placeholder="design, portfolio, creative, freelancer">
            <div class="text-xs text-gray-500 mt-1">Separate keywords with commas</div>
          </div>

          <!-- Social Sharing -->
          <div class="flex items-center">
            <input
              type="checkbox"
              id="social_sharing"
              name="social_sharing_enabled"
              value="true"
              checked={Map.get(seo_settings, "social_sharing_enabled", false) != false}
              phx-click="toggle_social_sharing"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="social_sharing" class="ml-2 block text-sm text-gray-900">
              Enable social media sharing buttons
            </label>
          </div>
        </div>
      </div>

      <!-- Advanced Settings -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Advanced</h3>

        <div class="space-y-4">
          <!-- Custom CSS -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Custom CSS</label>
            <textarea
              name="custom_css"
              rows="4"
              phx-change="update_custom_css"
              phx-debounce="2000"
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-mono text-sm"
              placeholder="/* Add your custom CSS here */"><%= Map.get(customization, "custom_css", "") %></textarea>
          </div>

          <!-- Analytics -->
          <div class="flex items-center">
            <input
              type="checkbox"
              id="analytics_enabled"
              name="analytics_enabled"
              value="true"
              checked={Map.get(settings, "analytics_enabled", false) != false}
              phx-click="toggle_analytics"
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
            <label for="analytics_enabled" class="ml-2 block text-sm text-gray-900">
              Enable portfolio analytics tracking
            </label>
          </div>

          <!-- Export Options -->
          <div class="pt-4 border-t border-gray-200">
            <h4 class="text-sm font-medium text-gray-900 mb-3">Export Options</h4>
            <div class="flex space-x-3">
              <button
                type="button"
                phx-click="export_portfolio"
                phx-value-format="pdf"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                Export as PDF
              </button>
              <button
                type="button"
                phx-click="export_portfolio"
                phx-value-format="json"
                class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                Export Data
              </button>
            </div>
          </div>
        </div>
      </div>

    </div>
    """
  end

  def render_video_intro_section(assigns) do
    # Safely get values with defaults
    current_user = Map.get(assigns, :current_user, %{subscription_tier: "free"})
    show_video_recorder = Map.get(assigns, :show_video_recorder, false)
    sections = Map.get(assigns, :sections, [])
    portfolio = Map.get(assigns, :portfolio, %{})

    # Find existing video intro section
    video_section = find_video_intro_section(sections)

    assigns = assigns
    |> Map.put(:video_section, video_section)
    |> Map.put(:current_user, current_user)
    |> Map.put(:show_video_recorder, show_video_recorder)
    |> Map.put(:portfolio, portfolio)

    ~H"""
    <!-- Video Intro Management -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <div class="flex items-center justify-between mb-4">
        <div>
          <h3 class="text-lg font-bold text-gray-900">Video Introduction</h3>
          <p class="text-gray-600 mt-1">Add a personal video to welcome visitors to your portfolio</p>
        </div>

        <!-- Account Tier Badge -->
        <div class="text-xs">
          <%= case Map.get(@current_user, :subscription_tier, "free") do %>
            <% "free" -> %>
              <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded-full">Free: 30s max</span>
            <% "pro" -> %>
              <span class="bg-blue-100 text-blue-700 px-2 py-1 rounded-full">Pro: 2min max</span>
            <% "premium" -> %>
              <span class="bg-purple-100 text-purple-700 px-2 py-1 rounded-full">Premium: 5min max</span>
            <% _ -> %>
              <span class="bg-gray-100 text-gray-700 px-2 py-1 rounded-full">30s max</span>
          <% end %>
        </div>
      </div>

      <%= if @video_section do %>
        <!-- Existing Video -->
        <div class="bg-gradient-to-br from-purple-50 to-blue-50 border border-purple-200 rounded-lg p-4 mb-4">
          <div class="flex items-center space-x-4">
            <div class="flex-shrink-0">
              <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-lg flex items-center justify-center">
                <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>
            </div>

            <div class="flex-1">
              <h4 class="font-medium text-gray-900">Video Introduction Active</h4>
              <p class="text-sm text-gray-600 mb-2">
                Duration: <%= format_video_duration(get_in(@video_section.content, ["duration"])) %> •
                Position: <%= format_position_name(get_in(@video_section.content, ["position"])) %>
              </p>

              <!-- Video Preview -->
              <%= if get_in(@video_section.content, ["video_url"]) do %>
                <video class="w-24 h-16 object-cover rounded border mt-2" controls>
                  <source src={get_in(@video_section.content, ["video_url"])} type="video/webm">
                  <source src={get_in(@video_section.content, ["video_url"])} type="video/mp4">
                  Your browser does not support the video tag.
                </video>
              <% end %>
            </div>

            <div class="flex flex-col space-y-2">
              <button
                phx-click="edit_video_intro"
                class="bg-purple-100 hover:bg-purple-200 text-purple-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                </svg>
                Replace
              </button>
              <button
                phx-click="delete_video_intro"
                phx-value-section_id={@video_section.id}
                phx-data-confirm="Are you sure you want to delete your video introduction?"
                class="bg-red-100 hover:bg-red-200 text-red-700 px-3 py-2 rounded-lg text-sm font-medium transition-colors">
                <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
                Delete
              </button>
            </div>
          </div>
        </div>
      <% else %>
        <!-- No Video - Upload Options -->
        <div class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center hover:border-purple-400 transition-colors">
          <div class="w-16 h-16 bg-gradient-to-br from-purple-500 to-blue-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>
          </div>

          <h4 class="text-lg font-medium text-gray-900 mb-2">Add Video Introduction</h4>
          <p class="text-gray-600 mb-6">
            Welcome visitors with a personal video that showcases your personality and expertise.
            <%= case Map.get(@current_user, :subscription_tier, "free") do %>
              <% "free" -> %> <br><span class="text-sm text-gray-500">Free plan: Videos up to 30 seconds</span>
              <% "pro" -> %> <br><span class="text-sm text-blue-600">Pro plan: Videos up to 2 minutes</span>
              <% "premium" -> %> <br><span class="text-sm text-purple-600">Premium plan: Videos up to 5 minutes</span>
              <% _ -> %> <br><span class="text-sm text-gray-500">Videos up to 30 seconds</span>
            <% end %>
          </p>

          <div class="flex flex-col sm:flex-row gap-3 justify-center">
            <button
              phx-click="show_video_recorder"
              class="bg-purple-600 hover:bg-purple-700 text-white px-6 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
              Record Video
            </button>

            <button
              phx-click="show_video_uploader"
              class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-6 py-3 rounded-lg font-medium transition-colors inline-flex items-center justify-center">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"/>
              </svg>
              Upload Video
            </button>
          </div>

          <div class="mt-4 text-xs text-gray-500">
            Supported formats: MP4, WebM, MOV • Max file size: 50MB
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_design_tab(assigns) do
    # Safely extract customization data
    customization = Map.get(assigns, :customization, %{})

    ~H"""
    <div class="space-y-6">
      <!-- Color Scheme -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Color Scheme</h3>

        <!-- WRAP IN FORM TAG -->
        <form phx-change="update_customization" phx-submit="update_customization" class="space-y-6">
          <!-- Portfolio Layout Selection -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Portfolio Layout</label>
            <select
              name="portfolio_layout"
              value={Map.get(customization, "portfolio_layout", "dashboard")}
              class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
              <option value="single_column" selected={Map.get(customization, "portfolio_layout") == "single_column"}>Single Column</option>
              <option value="dashboard" selected={Map.get(customization, "portfolio_layout") == "dashboard"}>Dashboard</option>
              <option value="grid" selected={Map.get(customization, "portfolio_layout") == "grid"}>Grid Layout</option>
              <option value="timeline" selected={Map.get(customization, "portfolio_layout") == "timeline"}>Timeline</option>
            </select>
          </div>

          <!-- Color Presets -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Quick Presets</label>
            <div class="grid grid-cols-2 gap-3">
              <%= for preset <- get_color_suggestions() do %>
                <button
                  type="button"
                  phx-click="apply_color_preset"
                  phx-value-preset={Jason.encode!(preset)}
                  class="flex items-center space-x-3 p-3 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors text-left">
                  <div class="flex space-x-1">
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.primary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.secondary}"}></div>
                    <div class="w-4 h-4 rounded" style={"background-color: #{preset.accent}"}></div>
                  </div>
                  <span class="text-sm font-medium text-gray-900"><%= preset.name %></span>
                </button>
              <% end %>
            </div>
          </div>

          <!-- Individual Color Inputs -->
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="primary_color"
                  value={Map.get(customization, "primary_color", "#1e40af")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="primary_color_text"
                  value={Map.get(customization, "primary_color", "#1e40af")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Secondary Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="secondary_color"
                  value={Map.get(customization, "secondary_color", "#64748b")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="secondary_color_text"
                  value={Map.get(customization, "secondary_color", "#64748b")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
              <div class="flex items-center space-x-2">
                <input
                  type="color"
                  name="accent_color"
                  value={Map.get(customization, "accent_color", "#3b82f6")}
                  class="w-12 h-10 border border-gray-300 rounded-lg cursor-pointer">
                <input
                  type="text"
                  name="accent_color_text"
                  value={Map.get(customization, "accent_color", "#3b82f6")}
                  class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-sm font-mono">
              </div>
            </div>
          </div>
        </form>
      </div>

      <!-- Typography & Layout -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Typography & Layout</h3>

        <!-- SEPARATE FORM FOR TYPOGRAPHY -->
        <form phx-change="update_customization" phx-submit="update_customization" class="space-y-6">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <!-- Font Family -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Font Family</label>
              <select
                name="font_family"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="inter" selected={Map.get(customization, "font_family") == "inter"}>Inter (Modern)</option>
                <option value="system" selected={Map.get(customization, "font_family") == "system"}>System Default</option>
                <option value="serif" selected={Map.get(customization, "font_family") == "serif"}>Serif (Classic)</option>
                <option value="mono" selected={Map.get(customization, "font_family") == "mono"}>Monospace (Tech)</option>
              </select>
            </div>

            <!-- Layout Style -->
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">Layout Style</label>
              <select
                name="layout_style"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500">
                <option value="modern" selected={Map.get(customization, "layout_style") == "modern"}>Modern</option>
                <option value="minimal" selected={Map.get(customization, "layout_style") == "minimal"}>Minimal</option>
                <option value="creative" selected={Map.get(customization, "layout_style") == "creative"}>Creative</option>
                <option value="professional" selected={Map.get(customization, "layout_style") == "professional"}>Professional</option>
              </select>
            </div>
          </div>

          <!-- Hero Style -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Hero Section Style</label>
            <div class="grid grid-cols-1 md:grid-cols-4 gap-3">
              <%= for style <- ["gradient", "image", "video", "minimal"] do %>
                <button
                  type="button"
                  phx-click="update_hero_style"
                  phx-value-style={style}
                  class={[
                    "p-4 border-2 rounded-lg transition-colors text-center",
                    if(Map.get(customization, "hero_style") == style,
                      do: "border-blue-600 bg-blue-50",
                      else: "border-gray-200 hover:border-gray-300")
                  ]}>
                  <div class="text-sm font-medium text-gray-900 capitalize"><%= style %></div>
                  <div class="text-xs text-gray-600 mt-1"><%= get_hero_style_description(style) %></div>
                </button>
              <% end %>
            </div>
          </div>
        </form>
      </div>
    </div>
    """
  end

  defp render_section_form_fields(assigns, section) do
    section_type = section.section_type

    case section_type do
      "hero" -> render_hero_section_form(assigns)
      "about" -> render_about_section_form(assigns)
      "experience" -> render_experience_section_form(assigns)
      "education" -> render_education_section_form(assigns)
      "skills" -> render_skills_section_form(assigns)
      "projects" -> render_projects_section_form(assigns)
      "testimonials" -> render_testimonials_section_form(assigns)
      "contact" -> render_contact_section_form(assigns)
      "custom" -> render_custom_section_form(assigns)
      _ -> render_standard_section_form(assigns)
    end
  end

  def render_section_card(assigns) do
    assigns = assign(assigns, :section_gradient, get_section_gradient(assigns.section.section_type))
    assigns = assign(assigns, :section_preview, get_section_content_preview(assigns.section))

    ~H"""
    <div class={[
      "bg-white rounded-xl border border-gray-200 transition-all duration-300 group relative",
      "hover:shadow-lg hover:border-gray-300",
      unless(@section.visible, do: "opacity-75", else: "opacity-100")
    ]}
    style={unless(@section.visible, do: "background-color: #f9fafb;", else: "")}
    data-section-id={@section.id}
    id={"section-#{@section.id}"}>

      <!-- Card Header -->
      <div class={[
        "relative p-4 border-b border-gray-100 bg-gradient-to-br",
        @section_gradient
      ]}>
        <!-- Section Info -->
        <div class="flex items-center space-x-3 pr-4">
          <div class="w-10 h-10 bg-white/20 backdrop-blur-sm rounded-lg flex items-center justify-center">
            <%= raw(get_section_icon(@section.section_type)) %>
          </div>
          <div class="flex-1">
            <h3 class="font-bold text-white text-lg drop-shadow-sm"><%= @section.title %></h3>
            <div class="flex items-center space-x-2">
              <span class="text-sm text-white/80"><%= format_section_type(@section.section_type) %></span>
              <%= unless @section.visible do %>
                <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-yellow-100 text-yellow-800 rounded-full">
                  Hidden
                </span>
              <% end %>
            </div>
          </div>

          <!-- All Action Icons Grouped -->
          <div class="flex items-center space-x-2">
            <!-- Visibility Toggle -->
            <button
              phx-click="toggle_section_visibility"
              phx-value-section_id={@section.id}
              class={[
                "p-2 rounded-lg transition-colors",
                if(@section.visible,
                  do: "text-white/80 hover:text-white hover:bg-white/20",
                  else: "text-white/60 hover:text-white/80 hover:bg-white/10")
              ]}
              title={if @section.visible, do: "Hide section", else: "Show section"}>
              <%= if @section.visible do %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                </svg>
              <% else %>
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L12 12m0 0l3.122 3.122m0 0L21 21"/>
                </svg>
              <% end %>
            </button>

            <!-- Edit -->
            <button
              phx-click="edit_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Edit section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
              </svg>
            </button>

            <!-- Duplicate -->
            <button
              phx-click="duplicate_section"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Duplicate section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
            </button>

            <!-- Attach Media -->
            <button
              phx-click="attach_section_media"
              phx-value-section_id={@section.id}
              class="p-2 text-white/80 hover:text-white hover:bg-white/20 rounded-lg transition-colors"
              title="Attach media">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
              </svg>
            </button>

            <!-- Delete -->
            <button
              phx-click="delete_section"
              phx-value-section_id={@section.id}
              phx-data-confirm="Are you sure you want to delete this section?"
              class="p-2 text-red-200 hover:text-red-100 hover:bg-red-500/20 rounded-lg transition-colors"
              title="Delete section">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
              </svg>
            </button>
          </div>
        </div>
      </div>

      <!-- Card Content -->
      <div class="p-6">
        <!-- Section Preview -->
        <div class="text-sm text-gray-600 mb-4">
          <%= @section_preview %>
        </div>
      </div>
    </div>
    """
  end

  def render_layout_options(assigns) do
    ~H"""
    <!-- Portfolio Layout Style -->
    <div class="bg-white rounded-xl shadow-sm border p-6">
      <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Layout</h3>

      <form phx-change="update_customization" class="space-y-6">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-3">Choose your portfolio layout style</label>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <%= for {layout_id, layout_info} <- get_portfolio_layouts() do %>
              <label class="relative">
                <input
                  type="radio"
                  name="portfolio_layout"
                  value={layout_id}
                  checked={@customization["portfolio_layout"] == layout_id}
                  class="sr-only peer">
                <div class="p-4 border-2 border-gray-200 rounded-lg cursor-pointer peer-checked:border-blue-500 peer-checked:bg-blue-50 hover:border-gray-300 transition-colors">
                  <div class="flex items-start space-x-3">
                    <div class="flex-shrink-0 w-12 h-12 bg-gray-100 rounded-lg flex items-center justify-center">
                      <%= raw(layout_info.icon) %>
                    </div>
                    <div class="flex-1">
                      <h4 class="font-medium text-gray-900"><%= layout_info.name %></h4>
                      <p class="text-sm text-gray-600 mt-1"><%= layout_info.description %></p>
                    </div>
                  </div>
                </div>
              </label>
            <% end %>
          </div>
        </div>
      </form>
    </div>
    """
  end

  defp get_portfolio_layouts do
    %{
      "single_column" => %{
        name: "Single Column",
        description: "Traditional single-column layout with sections stacked vertically",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6h16M4 10h16M4 14h16M4 18h16'/></svg>"
      },
      "dashboard" => %{
        name: "Dashboard",
        description: "Card-based layout with varying sized sections like a dashboard",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 5a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1H5a1 1 0 01-1-1V5zM14 5a1 1 0 011-1h4a1 1 0 011 1v2a1 1 0 01-1 1h-4a1 1 0 01-1-1V5zM14 12a1 1 0 011-1h4a1 1 0 011 1v7a1 1 0 01-1 1h-4a1 1 0 01-1-1v-7z'/></svg>"
      },
      "grid" => %{
        name: "Grid Layout",
        description: "Pinterest/Behance-style masonry grid layout",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z'/></svg>"
      },
      "timeline" => %{
        name: "Timeline",
        description: "Chronological timeline layout perfect for career progression",
        icon: "<svg class='w-6 h-6 text-gray-600' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z'/></svg>"
      }
    }
  end

  defp get_section_content_preview(section) do
    case section.content do
      %{"main_content" => content} when is_binary(content) and content != "" ->
        content |> String.slice(0, 120) |> truncate_text()
      %{"content" => content} when is_binary(content) and content != "" ->
        content |> String.slice(0, 120) |> truncate_text()
      %{"headline" => headline} when is_binary(headline) and headline != "" ->
        headline |> String.slice(0, 120) |> truncate_text()
      %{"title" => title} when is_binary(title) and title != "" ->
        title |> String.slice(0, 120) |> truncate_text()
      %{"items" => items} when is_list(items) and length(items) > 0 ->
        "#{length(items)} item#{if length(items) == 1, do: "", else: "s"} added"
      %{"categories" => categories} when is_list(categories) and length(categories) > 0 ->
        "#{length(categories)} categor#{if length(categories) == 1, do: "y", else: "ies"} added"
      _ ->
        "No content added yet"
    end
  end

  defp truncate_text(text) when is_binary(text) do
    if String.length(text) > 100 do
      String.slice(text, 0, 100) <> "..."
    else
      text
    end
  end

  defp get_section_gradient(section_type) do
    case to_string(section_type) do
      "intro" -> "from-blue-500 to-purple-600"
      "about" -> "from-green-500 to-teal-600"
      "experience" -> "from-purple-500 to-pink-600"
      "education" -> "from-indigo-500 to-blue-600"
      "skills" -> "from-yellow-500 to-orange-600"
      "projects" -> "from-red-500 to-pink-600"
      "certifications" -> "from-emerald-500 to-cyan-600"
      "achievements" -> "from-amber-500 to-yellow-600"
      "services" -> "from-violet-500 to-purple-600"
      "blog" -> "from-slate-500 to-gray-600"
      "gallery" -> "from-rose-500 to-pink-600"
      "testimonials" -> "from-cyan-500 to-blue-600"
      "contact" -> "from-green-500 to-emerald-600"
      "custom" -> "from-gray-500 to-slate-600"
      _ -> "from-gray-400 to-gray-600"
    end
  end

  defp get_section_icon(section_type) do
    case to_string(section_type) do
      "hero" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6'/></svg>"
      "about" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z'/></svg>"
      "experience" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2'/></svg>"
      "education" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253'/></svg>"
      "skills" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M13 10V3L4 14h7v7l9-11h-7z'/></svg>"
      "projects" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10'/></svg>"
      "achievements" -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z'/></svg>"
      _ -> "<svg class='w-5 h-5 text-white' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z'/></svg>"
    end
  end

  defp format_section_type(section_type) do
    section_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp render_default_content(assigns) do
    ~H"""
    <%= if Map.get(@content, "content") do %>
      <div class="prose prose-lg max-w-none text-gray-700">
        <%= format_content_with_paragraphs(Map.get(@content, "content")) %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No content added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_hero_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
          <input type="text" name="headline" value={Map.get(content, "headline", "")}
                placeholder="Your Name Here"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
          <input type="text" name="tagline" value={Map.get(content, "tagline", "")}
                placeholder="Professional Title"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
        <textarea name="description" rows="4"
                  placeholder="Brief description about yourself..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "description", "") %></textarea>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Text</label>
          <input type="text" name="cta_text" value={Map.get(content, "cta_text", "")}
                placeholder="Get In Touch"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">CTA Button Link</label>
          <input type="text" name="cta_link" value={Map.get(content, "cta_link", "")}
                placeholder="#contact"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>
    </div>
    """
  end

  defp render_about_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">About Content</label>
        <textarea name="content" rows="8"
                  placeholder="Tell your story..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Profile Image URL</label>
        <input type="url" name="image_url" value={Map.get(content, "image_url", "")}
              placeholder="https://example.com/profile.jpg"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>
    </div>
    """
  end

  defp render_experience_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-blue-50 p-4 rounded-lg">
        <p class="text-sm text-blue-700">Add your work experience, internships, and professional history.</p>
      </div>

      <!-- Experience Items -->
      <div id="experience-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Job Title</label>
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  placeholder="Software Engineer"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Company</label>
                <input
                  type="text"
                  name={"items[#{index}][company]"}
                  value={Map.get(item, "company", "")}
                  placeholder="Company Name"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                <input
                  type="month"
                  name={"items[#{index}][start_date]"}
                  value={Map.get(item, "start_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                <input
                  type="month"
                  name={"items[#{index}][end_date]"}
                  value={Map.get(item, "end_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
              </div>

              <div class="flex items-center pt-6">
                <input
                  type="checkbox"
                  id={"current_#{index}"}
                  name={"items[#{index}][current]"}
                  checked={Map.get(item, "current", false)}
                  class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded">
                <label for={"current_#{index}"} class="ml-2 block text-sm text-gray-900">
                  Current Position
                </label>
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Location</label>
              <input
                type="text"
                name={"items[#{index}][location]"}
                value={Map.get(item, "location", "")}
                placeholder="City, State or Remote"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500" />
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Responsibilities & Achievements</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="4"
                placeholder="• Led a team of 5 developers&#10;• Increased system performance by 40%&#10;• Implemented new features using React and Node.js"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Experience
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Experience Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Work Experience
      </button>
    </div>
    """
  end

  defp render_education_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-indigo-50 p-4 rounded-lg">
        <p class="text-sm text-indigo-700">Add your educational background, degrees, and certifications.</p>
      </div>

      <!-- Education Items -->
      <div id="education-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Degree/Certification</label>
                <input
                  type="text"
                  name={"items[#{index}][degree]"}
                  value={Map.get(item, "degree", "")}
                  placeholder="Bachelor of Science in Computer Science"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Institution</label>
                <input
                  type="text"
                  name={"items[#{index}][institution]"}
                  value={Map.get(item, "institution", "")}
                  placeholder="University Name"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-3 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Start Date</label>
                <input
                  type="month"
                  name={"items[#{index}][start_date]"}
                  value={Map.get(item, "start_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">End Date</label>
                <input
                  type="month"
                  name={"items[#{index}][end_date]"}
                  value={Map.get(item, "end_date", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">GPA (Optional)</label>
                <input
                  type="text"
                  name={"items[#{index}][gpa]"}
                  value={Map.get(item, "gpa", "")}
                  placeholder="3.8/4.0"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Description (Optional)</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="3"
                placeholder="Relevant coursework, honors, activities, or achievements..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Education
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Education Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Education
      </button>
    </div>
    """
  end

  defp render_skills_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :categories, Map.get(content, "categories", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-green-50 p-4 rounded-lg">
        <p class="text-sm text-green-700">Organize your skills into categories like "Technical Skills", "Soft Skills", etc.</p>
      </div>

      <!-- Skills Categories -->
      <div id="skills-categories" class="space-y-4">
        <%= for {category, index} <- Enum.with_index(@categories) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Category Name</label>
              <input
                type="text"
                name={"categories[#{index}][name]"}
                value={Map.get(category, "name", "")}
                placeholder="Technical Skills"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500" />
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-1">Skills (comma-separated)</label>
              <textarea
                name={"categories[#{index}][skills]"}
                rows="3"
                placeholder="JavaScript, React, Node.js, Python, PostgreSQL, AWS"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-green-500 focus:border-green-500"><%= Enum.join(Map.get(category, "skills", []), ", ") %></textarea>
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_skills_category"
                phx-value-section_id={@editing_section.id}
                phx-value-category_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Category
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Category Button -->
      <button
        type="button"
        phx-click="add_skills_category"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Skills Category
      </button>
    </div>
    """
  end

  defp render_projects_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)
    assigns = assign(assigns, :items, Map.get(content, "items", []))

    ~H"""
    <div class="space-y-6">
      <div class="bg-purple-50 p-4 rounded-lg">
        <p class="text-sm text-purple-700">Showcase your best projects, case studies, and portfolio pieces.</p>
      </div>

      <!-- Project Items -->
      <div id="projects-items" class="space-y-4">
        <%= for {item, index} <- Enum.with_index(@items) do %>
          <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Project Title</label>
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  placeholder="E-commerce Platform"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Technologies Used</label>
                <input
                  type="text"
                  name={"items[#{index}][technologies]"}
                  value={Map.get(item, "technologies", "")}
                  placeholder="React, Node.js, PostgreSQL"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Project Description</label>
              <textarea
                name={"items[#{index}][description]"}
                rows="4"
                placeholder="Describe the project, your role, key features, and impact..."
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500"><%= Map.get(item, "description", "") %></textarea>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Live Demo URL (Optional)</label>
                <input
                  type="url"
                  name={"items[#{index}][demo_url]"}
                  value={Map.get(item, "demo_url", "")}
                  placeholder="https://myproject.com"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Source Code URL (Optional)</label>
                <input
                  type="url"
                  name={"items[#{index}][source_url]"}
                  value={Map.get(item, "source_url", "")}
                  placeholder="https://github.com/username/project"
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
              </div>
            </div>

            <div class="mt-4">
              <label class="block text-sm font-medium text-gray-700 mb-1">Project Image URL (Optional)</label>
              <input
                type="url"
                name={"items[#{index}][image_url]"}
                value={Map.get(item, "image_url", "")}
                placeholder="https://example.com/project-screenshot.jpg"
                class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-purple-500" />
            </div>

            <div class="mt-4 flex justify-end">
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@editing_section.id}
                phx-value-item_index={index}
                class="text-red-600 hover:text-red-700 text-sm font-medium">
                Remove Project
              </button>
            </div>
          </div>
        <% end %>
      </div>

      <!-- Add Project Button -->
      <button
        type="button"
        phx-click="add_section_item"
        phx-value-section_id={@editing_section.id}
        class="w-full border-2 border-dashed border-gray-300 rounded-lg p-6 text-gray-500 hover:border-gray-400 hover:text-gray-600 transition-colors">
        <svg class="w-6 h-6 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
        </svg>
        Add Project
      </button>
    </div>
    """
  end

  defp render_testimonials_section_form(assigns) do
    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Testimonials</label>
        <div class="text-sm text-gray-500 mb-4">
          Add client testimonials, recommendations, or reviews.
        </div>
        <div id="testimonials-items">
          <!-- Testimonials will be rendered here -->
        </div>
      </div>
    </div>
    """
  end

  defp render_contact_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Email</label>
          <input type="email" name="email" value={Map.get(content, "email", "")}
                placeholder="your@email.com"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Phone</label>
          <input type="tel" name="phone" value={Map.get(content, "phone", "")}
                placeholder="+1 (555) 123-4567"
                class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
        </div>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Location</label>
        <input type="text" name="location" value={Map.get(content, "location", "")}
              placeholder="City, State"
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div class="flex items-center">
        <input type="checkbox" name="contact_form_enabled"
              checked={Map.get(content, "contact_form_enabled", false)}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded" />
        <label class="ml-2 block text-sm text-gray-700">
          Enable contact form
        </label>
      </div>
    </div>
    """
  end

  defp render_custom_section_form(assigns) do
    content = get_section_content_map(assigns.editing_section)

    ~H"""
    <div class="space-y-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom Content</label>
        <textarea name="content" rows="8"
                  placeholder="Add your custom content here..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= Map.get(content, "content", "") %></textarea>
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Layout Type</label>
        <select name="layout_type" class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500">
          <option value="text" selected={Map.get(content, "layout_type") == "text"}>Text Only</option>
          <option value="image_text" selected={Map.get(content, "layout_type") == "image_text"}>Image + Text</option>
          <option value="video" selected={Map.get(content, "layout_type") == "video"}>Video</option>
          <option value="embed" selected={Map.get(content, "layout_type") == "embed"}>Embed Code</option>
        </select>
      </div>
    </div>
    """
  end

  defp render_standard_section_form(assigns) do
    ~H"""
    <div class="space-y-4">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Section Title</label>
        <input type="text" name="title" value={@editing_section.title}
              class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
        <textarea name="main_content" rows="8"
                  placeholder="Add your content here..."
                  class="w-full px-3 py-2 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"><%= get_section_content(@editing_section) %></textarea>
      </div>
    </div>
    """
  end

  # Helper function to get section content as map
  defp get_section_content_map(section) do
    case section.content do
      content when is_map(content) -> content
      content when is_binary(content) -> Jason.decode!(content)
      _ -> %{}
    end
  rescue
    _ -> %{}
  end

  # Helper function to get section content as string
  defp get_section_content(section) do
    case section.content do
      content when is_binary(content) -> content
      content when is_map(content) -> Map.get(content, "content", "")
      _ -> ""
    end
  end

  defp get_hero_style_description(style) do
    case style do
      "gradient" -> "Colorful background gradients"
      "image" -> "Background image with overlay"
      "video" -> "Background video integration"
      "minimal" -> "Clean and simple design"
      _ -> "Standard styling"
    end
  end

  defp render_section_preview(section) do
    content = section.content || %{}

    case section.section_type do
      "hero" ->
        headline = Map.get(content, "headline", "")
        tagline = Map.get(content, "tagline", "")

        if String.length(headline) > 0 do
          "#{headline}" <> if String.length(tagline) > 0, do: " • #{tagline}", else: ""
        else
          "No headline set"
        end

      "about" ->
        about_content = Map.get(content, "content", "")
        if String.length(about_content) > 0 do
          String.slice(about_content, 0, 100) <> if String.length(about_content) > 100, do: "...", else: ""
        else
          "No content added yet"
        end

      "custom" ->
        title = Map.get(content, "title", "")
        layout_type = Map.get(content, "layout_type", "text")

        if String.length(title) > 0 do
          "#{title} (#{String.capitalize(layout_type)} layout)"
        else
          "#{String.capitalize(layout_type)} layout • No title set"
        end

      _ ->
        items = Map.get(content, "items", [])
        "#{length(items)} items configured"
    end
  end

  defp format_content_with_paragraphs(content) when is_binary(content) do
    content
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&("<p class=\"mb-4\">#{&1}</p>"))
    |> Enum.join("")
    |> raw()
  end
  defp format_content_with_paragraphs(_), do: ""

  # Form field renderers for different section types

  defp render_hero_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Headline</label>
        <input
          type="text"
          name="headline"
          value={Map.get(@content, "headline", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Your Name or Main Message" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Tagline</label>
        <input
          type="text"
          name="tagline"
          value={Map.get(@content, "tagline", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Professional Title or Specialty" />
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
      <textarea
        name="description"
        rows="3"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Brief introduction about yourself..."><%= Map.get(@content, "description", "") %></textarea>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Call-to-Action Text</label>
        <input
          type="text"
          name="cta_text"
          value={Map.get(@content, "cta_text", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Get In Touch" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Call-to-Action Link</label>
        <input
          type="url"
          name="cta_link"
          value={Map.get(@content, "cta_link", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="https://example.com/contact" />
      </div>
    </div>
    """
  end

  defp render_about_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :highlights_text, format_highlights_for_input(Map.get(assigns.content, "highlights", [])))

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">About Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Tell your story, background, and what makes you unique..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Profile Image URL</label>
      <input
        type="url"
        name="image_url"
        value={Map.get(@content, "image_url", "")}
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="https://example.com/your-photo.jpg" />
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Key Highlights</label>
      <textarea
        name="highlights"
        rows="3"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="• 5+ years of experience in design&#10;• Award-winning creative work&#10;• Trusted by 50+ clients"><%= @highlights_text %></textarea>
      <div class="text-xs text-gray-500 mt-1">Enter each highlight on a new line starting with •</div>
    </div>
    """
  end

  defp render_custom_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :layout_type, Map.get(assigns.content, "layout_type", "text"))

    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom Title</label>
        <input
          type="text"
          name="custom_title"
          value={Map.get(@content, "title", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="Section Title" />
      </div>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Layout Type</label>
        <select
          name="layout_type"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500">
          <option value="text" selected={@layout_type == "text"}>Text Only</option>
          <option value="image_text" selected={@layout_type == "image_text"}>Image + Text</option>
          <option value="gallery" selected={@layout_type == "gallery"}>Image Gallery</option>
          <option value="video" selected={@layout_type == "video"}>Video</option>
          <option value="embed" selected={@layout_type == "embed"}>Embed Code</option>
        </select>
      </div>
    </div>

    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Add your custom content here..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <%= if @layout_type == "video" do %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Video URL</label>
        <input
          type="url"
          name="video_url"
          value={Map.get(@content, "video_url", "")}
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
          placeholder="https://youtube.com/watch?v=..." />
      </div>
    <% end %>

    <%= if @layout_type == "embed" do %>
      <div>
        <label class="block text-sm font-medium text-gray-700 mb-2">Embed Code</label>
        <textarea
          name="embed_code"
          rows="4"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 font-mono text-sm"
          placeholder='<iframe src="..." width="100%" height="400"></iframe>'><%= Map.get(@content, "embed_code", "") %></textarea>
      </div>
    <% end %>

    <!-- Styling Options -->
    <div class="border-t border-gray-200 pt-6">
      <h4 class="text-sm font-medium text-gray-900 mb-4">Styling Options</h4>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Background Color</label>
          <input
            type="color"
            name="background_color"
            value={Map.get(@content, "background_color", "#ffffff")}
            class="w-full h-10 border border-gray-300 rounded-lg cursor-pointer">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Text Color</label>
          <input
            type="color"
            name="text_color"
            value={Map.get(@content, "text_color", "#000000")}
            class="w-full h-10 border border-gray-300 rounded-lg cursor-pointer">
        </div>

        <div>
          <label class="block text-sm font-medium text-gray-700 mb-2">Padding</label>
          <select
            name="padding"
            class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500">
            <option value="compact" selected={Map.get(@content, "padding") == "compact"}>Compact</option>
            <option value="normal" selected={Map.get(@content, "padding") == "normal"}>Normal</option>
            <option value="spacious" selected={Map.get(@content, "padding") == "spacious"}>Spacious</option>
          </select>
        </div>
      </div>

      <div class="mt-4">
        <div class="flex items-center">
          <input
            type="checkbox"
            id="show_border"
            name="show_border"
            value="true"
            checked={Map.get(@content, "show_border", false)}
            class="h-4 w-4 text-gray-600 focus:ring-gray-500 border-gray-300 rounded">
          <label for="show_border" class="ml-2 block text-sm text-gray-900">
            Show section border
          </label>
        </div>
      </div>

      <div class="mt-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">Custom CSS</label>
        <textarea
          name="custom_css"
          rows="3"
          class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 font-mono text-sm"
          placeholder="/* Add custom CSS for this section */"
        ><%= Map.get(@content, "custom_css", "") %></textarea>
      </div>
    </div>
    """
  end

  defp render_default_form_fields(assigns) do
    assigns = assign(assigns, :content, assigns.section.content || %{})
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))
    assigns = assign(assigns, :is_list_section, assigns.section.section_type in ["experience", "skills", "projects", "testimonials"])

    ~H"""
    <div>
      <label class="block text-sm font-medium text-gray-700 mb-2">Content</label>
      <textarea
        name="content"
        rows="6"
        class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500"
        placeholder="Add your content here..."><%= Map.get(@content, "content", "") %></textarea>
    </div>

    <!-- Dynamic item management for list-based sections -->
    <%= if @is_list_section do %>
      <div class="border-t border-gray-200 pt-6">
        <div class="flex items-center justify-between mb-4">
          <h4 class="text-sm font-medium text-gray-900">
            <%= case @section.section_type do %>
              <% "experience" -> %> Work Experience Items
              <% "skills" -> %> Skill Categories
              <% "projects" -> %> Project Items
              <% "testimonials" -> %> Testimonial Items
              <% _ -> %> Items
            <% end %>
          </h4>
          <button
            type="button"
            phx-click="add_section_item"
            phx-value-section_id={@section.id}
            class="bg-gray-100 hover:bg-gray-200 text-gray-700 px-3 py-1 rounded-md text-sm font-medium">
            <svg class="w-4 h-4 mr-1 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Add Item
          </button>
        </div>

        <!-- Items list would be rendered here -->
        <div class="space-y-3">
          <%= for {item, index} <- Enum.with_index(@items) do %>
            <div class="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg">
              <div class="flex-1">
                <input
                  type="text"
                  name={"items[#{index}][title]"}
                  value={Map.get(item, "title", "")}
                  class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-gray-500 focus:border-gray-500 text-sm"
                  placeholder="Item title..." />
              </div>
              <button
                type="button"
                phx-click="remove_section_item"
                phx-value-section_id={@section.id}
                phx-value-item_index={index}
                class="p-2 text-red-600 hover:text-red-700 hover:bg-red-50 rounded-md">
                <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                </svg>
              </button>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_highlights_for_input(highlights) when is_list(highlights) do
    highlights
    |> Enum.map(&("• " <> &1))
    |> Enum.join("\n")
  end
  defp format_highlights_for_input(_), do: ""

  defp render_education_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- @items do %>
          <div class="flex space-x-4">
            <div class="flex-shrink-0">
              <div class="w-12 h-12 bg-indigo-600 rounded-full flex items-center justify-center">
                <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.746 0 3.332.477 4.5 1.253v13C20.832 18.477 19.246 18 17.5 18c-1.746 0-3.332.477-4.5 1.253"/>
                </svg>
              </div>
            </div>
            <div class="flex-1">
              <h4 class="text-xl font-semibold text-gray-900">
                <%= Map.get(item, "degree", "Degree") %>
              </h4>
              <p class="text-indigo-600 font-medium">
                <%= Map.get(item, "institution", "Institution Name") %>
              </p>
              <p class="text-gray-600 text-sm mb-3">
                <%= Map.get(item, "duration", "Duration") %>
              </p>
              <%= if Map.get(item, "description") do %>
                <p class="text-gray-700">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>
              <%= if Map.get(item, "gpa") do %>
                <p class="text-gray-600 text-sm mt-2">
                  GPA: <%= Map.get(item, "gpa") %>
                </p>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No education items added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_certifications_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <%= for item <- @items do %>
          <div class="bg-white rounded-lg p-6 shadow-sm border hover:shadow-md transition-shadow">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-green-600 rounded-lg flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
                  </svg>
                </div>
              </div>
              <div class="flex-1">
                <h4 class="text-lg font-semibold text-gray-900">
                  <%= Map.get(item, "name", "Certification Name") %>
                </h4>
                <p class="text-green-600 font-medium">
                  <%= Map.get(item, "issuer", "Issuing Organization") %>
                </p>
                <p class="text-gray-600 text-sm mb-2">
                  Earned: <%= Map.get(item, "date", "Date") %>
                </p>
                <%= if Map.get(item, "expiry") do %>
                  <p class="text-gray-600 text-sm mb-2">
                    Expires: <%= Map.get(item, "expiry") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "credential_id") do %>
                  <p class="text-gray-500 text-xs font-mono">
                    ID: <%= Map.get(item, "credential_id") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "url") do %>
                  <a
                    href={Map.get(item, "url")}
                    target="_blank"
                    class="inline-flex items-center text-green-600 hover:text-green-700 font-medium text-sm mt-2">
                    Verify
                    <svg class="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No certifications added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_achievements_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-6">
        <%= for item <- @items do %>
          <div class="bg-gradient-to-r from-yellow-50 to-orange-50 border border-yellow-200 rounded-xl p-6">
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="w-12 h-12 bg-gradient-to-br from-yellow-500 to-orange-500 rounded-full flex items-center justify-center">
                  <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
                  </svg>
                </div>
              </div>
              <div class="flex-1">
                <h4 class="text-xl font-semibold text-gray-900 mb-2">
                  <%= Map.get(item, "title", "Achievement Title") %>
                </h4>
                <%= if Map.get(item, "organization") do %>
                  <p class="text-orange-600 font-medium mb-2">
                    <%= Map.get(item, "organization") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "date") do %>
                  <p class="text-gray-600 text-sm mb-3">
                    <%= Map.get(item, "date") %>
                  </p>
                <% end %>
                <%= if Map.get(item, "description") do %>
                  <p class="text-gray-700">
                    <%= Map.get(item, "description") %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No achievements added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_services_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <%= for item <- @items do %>
          <div class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-lg transition-all group">
            <!-- Service Header -->
            <div class="bg-gradient-to-br from-purple-600 to-blue-600 p-6 text-white">
              <h4 class="text-xl font-semibold mb-2">
                <%= Map.get(item, "title", "Service Title") %>
              </h4>
              <%= if Map.get(item, "price") do %>
                <div class="text-2xl font-bold">
                  $<%= Map.get(item, "price") %>
                  <%= if Map.get(item, "price_type") do %>
                    <span class="text-sm font-normal opacity-90">/<%= Map.get(item, "price_type") %></span>
                  <% end %>
                </div>
              <% end %>
            </div>

            <!-- Service Content -->
            <div class="p-6">
              <%= if Map.get(item, "description") do %>
                <p class="text-gray-700 mb-4">
                  <%= Map.get(item, "description") %>
                </p>
              <% end %>

              <!-- Service Features -->
              <%= if Map.get(item, "features") do %>
                <ul class="space-y-2 mb-6">
                  <%= for feature <- String.split(Map.get(item, "features", ""), "\n") do %>
                    <%= if String.trim(feature) != "" do %>
                      <li class="flex items-center text-gray-700">
                        <svg class="w-4 h-4 text-green-500 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                        </svg>
                        <%= String.trim(feature) %>
                      </li>
                    <% end %>
                  <% end %>
                </ul>
              <% end %>

              <!-- CTA Button -->
              <%= if Map.get(item, "booking_enabled") do %>
                <button class="w-full bg-purple-600 hover:bg-purple-700 text-white font-medium py-3 px-6 rounded-lg transition-colors">
                  Book Service
                </button>
              <% else %>
                <button class="w-full bg-gray-100 hover:bg-gray-200 text-gray-700 font-medium py-3 px-6 rounded-lg transition-colors">
                  Learn More
                </button>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No services added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_blog_content(assigns) do
    assigns = assign(assigns, :items, Map.get(assigns.content, "items", []))

    ~H"""
    <%= if length(@items) > 0 do %>
      <div class="space-y-8">
        <%= for item <- @items do %>
          <article class="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden hover:shadow-md transition-shadow">
            <%= if Map.get(item, "featured_image") do %>
              <img
                src={Map.get(item, "featured_image")}
                alt={Map.get(item, "title", "Blog Post")}
                class="w-full h-48 object-cover" />
            <% end %>

            <div class="p-6">
              <div class="flex items-center space-x-4 mb-4">
                <%= if Map.get(item, "category") do %>
                  <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-blue-100 text-blue-800">
                    <%= Map.get(item, "category") %>
                  </span>
                <% end %>
                <%= if Map.get(item, "published_date") do %>
                  <span class="text-gray-500 text-sm">
                    <%= Map.get(item, "published_date") %>
                  </span>
                <% end %>
                <%= if Map.get(item, "read_time") do %>
                  <span class="text-gray-500 text-sm">
                    <%= Map.get(item, "read_time") %> min read
                  </span>
                <% end %>
              </div>

              <h4 class="text-xl font-semibold text-gray-900 mb-3">
                <%= Map.get(item, "title", "Blog Post Title") %>
              </h4>

              <%= if Map.get(item, "excerpt") do %>
                <p class="text-gray-700 mb-4">
                  <%= Map.get(item, "excerpt") %>
                </p>
              <% end %>

              <div class="flex items-center justify-between">
                <%= if Map.get(item, "author") do %>
                  <div class="flex items-center space-x-2">
                    <div class="w-8 h-8 bg-gray-300 rounded-full flex items-center justify-center">
                      <svg class="w-4 h-4 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                    <span class="text-sm text-gray-600">
                      <%= Map.get(item, "author") %>
                    </span>
                  </div>
                <% end %>

                <%= if Map.get(item, "url") do %>
                  <a
                    href={Map.get(item, "url")}
                    target="_blank"
                    class="inline-flex items-center text-blue-600 hover:text-blue-700 font-medium">
                    Read More
                    <svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
                    </svg>
                  </a>
                <% end %>
              </div>
            </div>
          </article>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <p>No blog posts added yet.</p>
      </div>
    <% end %>
    """
  end

  defp render_gallery_content(assigns) do
    assigns = assign(assigns, :images, Map.get(assigns.content, "images", []))
    assigns = assign(assigns, :layout_style, Map.get(assigns.content, "layout_style", "grid"))

    ~H"""
    <%= if length(@images) > 0 do %>
      <div class={[
        case @layout_style do
          "masonry" -> "columns-1 md:columns-2 lg:columns-3 gap-4 space-y-4"
          "carousel" -> "flex space-x-4 overflow-x-auto pb-4"
          _ -> "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"
        end
      ]}>
        <%= for {image, index} <- Enum.with_index(@images) do %>
          <div class={[
            "group cursor-pointer",
            if(@layout_style == "carousel", do: "flex-shrink-0 w-80", else: "")
          ]}>
            <div class="relative overflow-hidden rounded-lg shadow-md hover:shadow-lg transition-shadow">
              <img
                src={Map.get(image, "url", "")}
                alt={Map.get(image, "caption", "Gallery Image #{index + 1}")}
                class="w-full h-auto object-cover group-hover:scale-105 transition-transform duration-300" />

              <!-- Image Overlay -->
              <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all duration-300 flex items-center justify-center">
                <svg class="w-8 h-8 text-white opacity-0 group-hover:opacity-100 transition-opacity duration-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0zM10 7v3m0 0v3m0-3h3m-3 0H7"/>
                </svg>
              </div>
            </div>

            <%= if Map.get(image, "caption") do %>
              <p class="text-gray-600 text-sm mt-2 text-center">
                <%= Map.get(image, "caption") %>
              </p>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <div class="text-center text-gray-500 py-12">
        <div class="w-16 h-16 bg-gray-200 rounded-lg flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
        </div>
        <p>No images added to gallery yet.</p>
      </div>
    <% end %>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:not_accepted), do: "File type not supported"
  defp error_to_string(error), do: "Upload error: #{error}"

end
