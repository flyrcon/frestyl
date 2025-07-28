# lib/frestyl_web/live/portfolio_live/enhanced_portfolio_editor.ex

defmodule FrestylWeb.PortfolioLive.EnhancedPortfolioEditor do
  @moduledoc """
  Enhanced Portfolio Editor LiveView - mobile-first design with dynamic sections
  """

  use FrestylWeb, :live_view

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.{Portfolio, EnhancedSectionSystem}
  alias Frestyl.Media
  alias Phoenix.PubSub

  alias FrestylWeb.PortfolioLive.Components.{
    DynamicSectionModal,
    EnhancedSectionRenderer,
    PortfolioLayoutEngine
  }

  @impl true
  def mount(%{"id" => portfolio_id}, session, socket) do
    if connected?(socket) do
      PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
      PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
    end

    current_user = get_current_user_from_session(session)

    case Portfolios.get_portfolio_with_sections(portfolio_id) do
      {:ok, portfolio_data} ->
        # Handle the nested structure - extract the actual portfolio
        portfolio = case portfolio_data do
          %{} = p -> p  # If it's already a map, use it
          other ->
            IO.inspect(other, label: "Unexpected portfolio structure")
            %{}  # Fallback to empty map
        end

        sections = case Map.get(portfolio, :sections) do
          sections when is_list(sections) -> sections
          _ ->
            case Map.get(portfolio, "sections") do
              sections when is_list(sections) -> sections
              _ -> []
            end
        end

        hero_section = find_hero_section(sections)

        socket = socket
        |> assign(:current_user, current_user)
        |> assign(:portfolio, portfolio)
        |> assign(:sections, sections)
        |> assign(:hero_section, hero_section)
        |> assign(:customization, get_portfolio_customization(portfolio))
        |> assign_ui_state()
        |> assign_editor_state()

        {:ok, socket}

      portfolio_data when is_map(portfolio_data) ->
        # Direct map case
        sections = get_sections_from_portfolio(portfolio_data)
        hero_section = find_hero_section(sections)

        socket = socket
        |> assign(:current_user, current_user)
        |> assign(:portfolio, portfolio_data)
        |> assign(:sections, sections)
        |> assign(:hero_section, hero_section)
        |> assign(:customization, get_portfolio_customization(portfolio_data))
        |> assign_ui_state()
        |> assign_editor_state()

        {:ok, socket}

      error ->
        IO.inspect(error, label: "Portfolio load error")
        {:ok, socket
        |> assign(:current_user, current_user)
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: ~p"/portfolios")}
    end
  end

  # Event Handlers
@impl true
def handle_event("switch_tab", %{"tab" => tab}, socket) do
  IO.puts("🎯 SWITCH TAB CALLED with tab: #{tab}")
  IO.puts("🎯 CURRENT ACTIVE TAB: #{Map.get(socket.assigns, :active_tab, "sections")}")

  new_socket = assign(socket, :active_tab, tab)

  IO.puts("🎯 NEW ACTIVE TAB: #{Map.get(new_socket.assigns, :active_tab, "sections")}")

  {:noreply, new_socket}
end

  @impl true
  def handle_event("toggle_preview", _params, socket) do
    new_mode = if Map.get(socket.assigns, :preview_mode, :editor) == :split, do: :editor, else: :split
    {:noreply, assign(socket, :preview_mode, new_mode)}
  end

  @impl true
  def handle_event("toggle_create_dropdown", _params, socket) do
    current_state = Map.get(socket.assigns, :show_create_dropdown, false)
    {:noreply, assign(socket, :show_create_dropdown, !current_state)}
  end

  @impl true
  def handle_event("close_create_dropdown", _params, socket) do
    {:noreply, assign(socket, :show_create_dropdown, false)}
  end

  @impl true
  def handle_event("create_section", %{"section_type" => section_type}, socket) do
    new_section = %{
      id: :rand.uniform(10000),
      title: "New #{String.capitalize(section_type)} Section",
      section_type: String.to_atom(section_type),
      content: %{},
      position: length(socket.assigns.sections) + 1,
      visible: true
    }

    updated_sections = socket.assigns.sections ++ [new_section]

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> assign(:show_create_dropdown, false)
    |> put_flash(:info, "Section created!")}
  end

  @impl true
  def handle_event("edit_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      {:noreply, socket
      |> assign(:show_section_modal, true)
      |> assign(:current_section_type, to_string(section.section_type))
      |> assign(:editing_section, section)}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("save_section", params, socket) do
    IO.puts("🔥 SAVE SECTION CALLED with: #{inspect(params)}")

    case params["action"] do
      "create" ->
        IO.puts("🔥 Creating new section")
        create_section_with_modal(socket, params)
      "update" ->
        IO.puts("🔥 Updating existing section")
        update_section_with_modal_fixed(socket, params)
      _ ->
        IO.puts("❌ Invalid action: #{params["action"]}")
        {:noreply, put_flash(socket, :error, "Invalid action")}
    end
  end

  defp update_section_with_modal_fixed(socket, params) do
    section_id = String.to_integer(params["section_id"])
    title = params["title"]
    visible = params["visible"] == "true"

    IO.puts("🔧 UPDATING SECTION: id=#{section_id}, title=#{title}, visible=#{visible}")

    # Find the section
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      content = extract_content_from_params(to_string(section.section_type), params)

      update_attrs = %{
        title: title,
        content: content,
        visible: visible
      }

      IO.puts("🔧 UPDATE ATTRS: #{inspect(update_attrs)}")

      # Use the CORRECT function name - check your Portfolios module
      case Portfolios.update_portfolio_section(section, update_attrs) do
        {:ok, updated_section} ->
          IO.puts("✅ SECTION UPDATED IN DATABASE")

          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          # Broadcast with COMPREHENSIVE data
          broadcast_comprehensive_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated and saved successfully!")}

        {:error, changeset} ->
          IO.puts("❌ SECTION UPDATE FAILED: #{inspect(changeset.errors)}")
          {:noreply, put_flash(socket, :error, "Failed to save section: #{inspect(changeset.errors)}")}
      end
    else
      IO.puts("❌ SECTION NOT FOUND: #{section_id}")
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp broadcast_comprehensive_update(portfolio_id, sections, customization) do
    IO.puts("🔄 BROADCASTING COMPREHENSIVE UPDATE")
    IO.puts("🔄 Portfolio: #{portfolio_id}")
    IO.puts("🔄 Sections: #{length(sections)}")
    IO.puts("🔄 Customization: #{inspect(customization)}")

    update_data = %{
      sections: sections,
      customization: customization,
      updated_at: DateTime.utc_now(),
      portfolio_id: portfolio_id
    }

    # Broadcast to ALL possible channels
    channels = [
      "portfolio_preview:#{portfolio_id}",
      "portfolio:#{portfolio_id}",
      "portfolio_show:#{portfolio_id}"
    ]

    Enum.each(channels, fn channel ->
      IO.puts("🔄 Broadcasting to: #{channel}")

      # Send multiple message types to ensure at least one is caught
      PubSub.broadcast(Frestyl.PubSub, channel, {:preview_update, update_data})
      PubSub.broadcast(Frestyl.PubSub, channel, {:sections_updated, sections})
      PubSub.broadcast(Frestyl.PubSub, channel, {:portfolio_sections_changed, update_data})
      PubSub.broadcast(Frestyl.PubSub, channel, {:customization_updated, customization})
    end)

    IO.puts("✅ BROADCAST COMPLETE")
  end

  @impl true
  def handle_event("close_section_modal", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)}
  end

  @impl true
  def handle_event("close_modal_on_escape", _params, socket) do
    {:noreply, socket
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)}
  end

  @impl true
  def handle_event("save_section", params, socket) do
    case params["action"] do
      "create" -> create_section_with_modal(socket, params)
      "update" -> update_section_with_modal(socket, params)
      _ -> {:noreply, put_flash(socket, :error, "Invalid action")}
    end
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    updated_sections = Enum.map(socket.assigns.sections, fn section ->
      if section.id == section_id do
        new_visible = !section.visible
        # Update the section with new visibility
        %{section | visible: new_visible}
      else
        section
      end
    end)

    # Find the updated section to show appropriate message
    updated_section = Enum.find(updated_sections, &(&1.id == section_id))
    message = if updated_section.visible, do: "Section is now visible", else: "Section is now hidden"

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> put_flash(:info, message)}
  end

  @impl true
  def handle_event("move_section_up", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon!")}
  end

  @impl true
  def handle_event("move_section_down", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon!")}
  end

  @impl true
  def handle_event("delete_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)
    IO.puts("🔥 DELETE SECTION CALLED: #{section_id}")

    # Find the section first
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      IO.puts("🔧 DELETING SECTION: #{section.title}")

      # Use the CORRECT function name
      case Portfolios.delete_portfolio_section(section) do
        {:ok, _} ->
          IO.puts("✅ SECTION DELETED FROM DATABASE")

          updated_sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id))

          # Broadcast comprehensive update
          broadcast_comprehensive_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> put_flash(:info, "Section deleted successfully")}

        {:error, reason} ->
          IO.puts("❌ SECTION DELETE FAILED: #{inspect(reason)}")
          {:noreply, put_flash(socket, :error, "Failed to delete section: #{inspect(reason)}")}
      end
    else
      IO.puts("❌ SECTION NOT FOUND FOR DELETE: #{section_id}")
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("publish_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio publishing feature coming soon!")}
  end

  @impl true
  def handle_event("set_preview_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :preview_device, mode)}
  end

@impl true
def handle_event("change_color_scheme", %{"scheme" => scheme}, socket) do
  IO.puts("🎨 COLOR SCHEME CHANGE: #{scheme}")

  customization_params = %{"color_scheme" => scheme}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Color scheme updated to #{scheme}!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update color scheme")}
  end
end

@impl true
def handle_event("change_font_style", %{"font" => font}, socket) do
  IO.puts("🔤 FONT CHANGE: #{font}")

  customization_params = %{"font_style" => font}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Font updated to #{font}!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update font")}
  end
end

@impl true
def handle_event("change_primary_color", %{"color" => color}, socket) do
  IO.puts("🎨 PRIMARY COLOR CHANGE: #{color}")

  customization_params = %{"primary_color" => color}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Primary color updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update primary color")}
  end
end

@impl true
def handle_event("change_secondary_color", %{"color" => color}, socket) do
  IO.puts("🎨 SECONDARY COLOR CHANGE: #{color}")

  customization_params = %{"secondary_color" => color}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Secondary color updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update secondary color")}
  end
end

@impl true
def handle_event("change_accent_color", %{"color" => color}, socket) do
  IO.puts("🎨 ACCENT COLOR CHANGE: #{color}")

  customization_params = %{"accent_color" => color}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Accent color updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update accent color")}
  end
end

@impl true
def handle_event("change_section_spacing", %{"spacing" => spacing}, socket) do
  IO.puts("📏 SPACING CHANGE: #{spacing}")

  customization_params = %{"section_spacing" => spacing}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Section spacing updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update section spacing")}
  end
end

@impl true
def handle_event("change_corner_radius", %{"radius" => radius}, socket) do
  IO.puts("📐 CORNER RADIUS CHANGE: #{radius}")

  customization_params = %{"corner_radius" => radius}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Corner radius updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update corner radius")}
  end
end

@impl true
def handle_event("change_font_family", %{"font_family" => font_family}, socket) do
  IO.puts("🔤 FONT FAMILY CHANGE: #{font_family}")

  customization_params = %{"font_family" => font_family}

  case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
    {:ok, updated_portfolio} ->
      broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

      {:noreply, socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization)
      |> put_flash(:info, "Font family updated!")}

    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update font family")}
  end
end

  @impl true
  def handle_event("change_layout_style", %{"layout" => layout_style}, socket) do
    IO.puts("🎨 LAYOUT CHANGE: #{layout_style}")

    customization_params = %{"layout_style" => layout_style}

    case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, customization_params) do
      {:ok, updated_portfolio} ->
        broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization)
        |> put_flash(:info, "Layout updated!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout")}
    end
  end

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    case format do
      "pdf" ->
        {:noreply, put_flash(socket, :info, "PDF export feature coming soon! Your portfolio will be exported as a professional PDF document.")}
      "html" ->
        {:noreply, put_flash(socket, :info, "HTML export feature coming soon! Your portfolio will be exported as a static website.")}
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid export format")}
    end
  end

  @impl true
  def handle_event("backup_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Backup feature coming soon! This will create a complete backup of your portfolio.")}
  end

  @impl true
  def handle_event("reset_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio reset feature coming soon! This will remove all sections and reset customizations.")}
  end

  @impl true
  def handle_event("delete_portfolio", _params, socket) do
    {:noreply, put_flash(socket, :error, "Portfolio deletion feature coming soon! Use this with extreme caution.")}
  end

  @impl true
  def handle_event("toggle_section_visibility", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section visibility toggle coming soon! Section ID: #{section_id}")}
  end

  @impl true
  def handle_event("move_section_up", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon! Moving section #{section_id} up.")}
  end

  @impl true
  def handle_event("move_section_down", %{"section_id" => section_id}, socket) do
    {:noreply, put_flash(socket, :info, "Section reordering coming soon! Moving section #{section_id} down.")}
  end

  @impl true
  def handle_event("change_section_spacing", %{"spacing" => spacing}, socket) do
    current_customization = Map.get(socket.assigns, :customization, %{})
    updated_customization = Map.put(current_customization, "section_spacing", spacing)
    {:noreply, assign(socket, :customization, updated_customization)}
  end

  @impl true
  def handle_event("change_corner_radius", %{"radius" => radius}, socket) do
    current_customization = Map.get(socket.assigns, :customization, %{})
    updated_customization = Map.put(current_customization, "corner_radius", radius)
    {:noreply, assign(socket, :customization, updated_customization)}
  end

  @impl true
  def handle_event("add_array_item", %{"field" => field_name}, socket) do
    # Update the component's internal state to add a new array item
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    updated_array = current_array ++ [""]
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("remove_array_item", %{"field" => field_name, "index" => index}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    index = String.to_integer(index)
    updated_array = List.delete_at(current_array, index)
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("add_complex_array_item", %{"field" => field_name}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    updated_array = current_array ++ [%{}]
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("remove_complex_array_item", %{"field" => field_name, "index" => index}, socket) do
    current_data = Map.get(socket.assigns, :form_data, %{})
    current_array = Map.get(current_data, field_name, [])
    index = String.to_integer(index)
    updated_array = List.delete_at(current_array, index)
    updated_data = Map.put(current_data, field_name, updated_array)

    {:noreply, assign(socket, :form_data, updated_data)}
  end

  @impl true
  def handle_event("add_map_item", %{"field" => field_name}, socket) do
    # Handle adding map items (like social links)
    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_map_item", %{"field" => field_name, "key" => key}, socket) do
    # Handle removing map items
    {:noreply, socket}
  end

  # Catch-all for unhandled events
  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔥 Unhandled event: #{event_name} with params: #{inspect(params)}")
    {:noreply, socket}
  end

  defp broadcast_section_update(portfolio_id, sections, customization) do
    IO.puts("🔄 BROADCASTING SECTION UPDATE to both channels")

    update_data = %{
      sections: sections,
      customization: customization,
      updated_at: DateTime.utc_now()
    }

    # Broadcast to preview channel (for editor preview)
    PubSub.broadcast(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}", {
      :preview_update,
      update_data
    })

    # Broadcast to main portfolio channel (for show.ex)
    PubSub.broadcast(Frestyl.PubSub, "portfolio:#{portfolio_id}", {
      :sections_updated,
      sections
    })

    # Also broadcast individual section updates
    PubSub.broadcast(Frestyl.PubSub, "portfolio_show:#{portfolio_id}", {
      :portfolio_sections_changed,
      %{sections: sections, customization: customization}
    })
  end

  # Helper Functions
  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, "sections")
    |> assign(:preview_mode, :editor)
    |> assign(:preview_device, "desktop")
    |> assign(:show_section_modal, false)
    |> assign(:show_create_dropdown, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)
  end

  defp assign_editor_state(socket) do
    socket
    |> assign(:editor_mode, :edit)
    |> assign(:autosave_enabled, true)
    |> assign(:last_saved, DateTime.utc_now())
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
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

  defp get_sections_from_portfolio(portfolio) do
    case Map.get(portfolio, :sections) do
      sections when is_list(sections) -> sections
      _ ->
        case Map.get(portfolio, "sections") do
          sections when is_list(sections) -> sections
          _ -> []
        end
    end
  end

  defp get_portfolio_customization(portfolio) do
    case Map.get(portfolio, :customization) do
      customization when is_map(customization) -> customization
      _ ->
        case Map.get(portfolio, "customization") do
          customization when is_map(customization) -> customization
          _ -> get_default_customization()
        end
    end
  end

  defp create_section_with_modal(socket, params) do
    section_type = params["section_type"]
    title = params["title"]
    visible = params["visible"] == "true"

    # Extract content from form params
    content = extract_content_from_params(section_type, params)

    new_section = %{
      id: :rand.uniform(10000),
      title: title,
      section_type: String.to_atom(section_type),
      content: content,
      position: length(socket.assigns.sections) + 1,
      visible: visible
    }

    updated_sections = socket.assigns.sections ++ [new_section]

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> assign(:show_section_modal, false)
    |> assign(:current_section_type, nil)
    |> assign(:editing_section, nil)
    |> put_flash(:info, "Section created successfully!")}
  end

  defp update_section_with_modal(socket, params) do
    section_id = String.to_integer(params["section_id"])
    title = params["title"]
    visible = params["visible"] == "true"

    # Find the section
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      content = extract_content_from_params(to_string(section.section_type), params)

      # Use the correct function name from Portfolios module
      case Portfolios.update_section(section, %{title: title, content: content, visible: visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          # Broadcast to BOTH channels
          broadcast_section_update(socket.assigns.portfolio.id, updated_sections, socket.assigns.customization)

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated successfully!")}

        {:error, changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to update section: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end


  defp extract_content_from_params(section_type, params) do
    # Simple content extraction - adapt based on your section types
    case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || "",
          "website" => params["website"] || "",
          "social_links" => %{}
        }
      "experience" ->
        %{
          "jobs" => [%{
            "title" => params["title"] || "",
            "company" => params["company"] || "",
            "description" => params["description"] || "",
            "start_date" => params["start_date"] || "",
            "end_date" => params["end_date"] || "",
            "current" => params["current"] == "true"
          }]
        }
      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "social_links" => %{}
        }
      _ ->
        %{
          "content" => params["content"] || "Add your content here..."
        }
    end
  end

  defp generate_preview_css(customization) do
    layout_style = Map.get(customization, "layout_style", "mobile_single")
    color_scheme = Map.get(customization, "color_scheme", "blue")
    font_style = Map.get(customization, "font_style", "inter")
    section_spacing = Map.get(customization, "section_spacing", "normal")
    corner_radius = Map.get(customization, "corner_radius", "rounded")

    # Color scheme definitions
    colors = case color_scheme do
      "blue" -> %{primary: "#3B82F6", secondary: "#1D4ED8", accent: "#60A5FA"}
      "purple" -> %{primary: "#8B5CF6", secondary: "#7C3AED", accent: "#A78BFA"}
      "green" -> %{primary: "#10B981", secondary: "#059669", accent: "#34D399"}
      "red" -> %{primary: "#EF4444", secondary: "#DC2626", accent: "#F87171"}
      "orange" -> %{primary: "#F97316", secondary: "#EA580C", accent: "#FB923C"}
      "pink" -> %{primary: "#EC4899", secondary: "#DB2777", accent: "#F472B6"}
      "dark" -> %{primary: "#1F2937", secondary: "#111827", accent: "#374151"}
      "slate" -> %{primary: "#475569", secondary: "#334155", accent: "#64748B"}
      "neutral" -> %{primary: "#525252", secondary: "#404040", accent: "#737373"}
      "midnight" -> %{primary: "#0F172A", secondary: "#1E293B", accent: "#334155"}
      "charcoal" -> %{primary: "#18181B", secondary: "#27272A", accent: "#3F3F46"}
      "graphite" -> %{primary: "#171717", secondary: "#262626", accent: "#525252"}
      _ -> %{primary: "#3B82F6", secondary: "#1D4ED8", accent: "#60A5FA"}
    end

    # Font families
    font_family = case font_style do
      "inter" -> "Inter, system-ui, sans-serif"
      "poppins" -> "Poppins, system-ui, sans-serif"
      "playfair" -> "Playfair Display, Georgia, serif"
      "source_sans" -> "Source Sans Pro, system-ui, sans-serif"
      _ -> "Inter, system-ui, sans-serif"
    end

    # Spacing values
    spacing = case section_spacing do
      "compact" -> "0.5rem"
      "normal" -> "1rem"
      "spacious" -> "2rem"
      _ -> "1rem"
    end

    # Border radius values
    radius = case corner_radius do
      "sharp" -> "0"
      "rounded" -> "0.5rem"
      "very-rounded" -> "1rem"
      _ -> "0.5rem"
    end

    """
    .portfolio-preview {
      font-family: #{font_family};
      --primary-color: #{colors.primary};
      --secondary-color: #{colors.secondary};
      --accent-color: #{colors.accent};
      --section-spacing: #{spacing};
      --border-radius: #{radius};
    }

    .portfolio-preview h1, .portfolio-preview h2, .portfolio-preview h3 {
      color: var(--primary-color);
    }

    .portfolio-preview .section-card {
      margin-bottom: var(--section-spacing);
      border-radius: var(--border-radius);
      border-color: var(--accent-color);
    }

    .portfolio-preview .layout-#{layout_style} {
      #{get_layout_css(layout_style)}
    }
    """
  end

  defp get_layout_css(layout_style) do
    case layout_style do
      "mobile_single" -> "display: flex; flex-direction: column; gap: 1rem;"
      "grid_uniform" -> "display: grid; grid-template-columns: repeat(2, 1fr); gap: 1rem;"
      "dashboard" -> "display: grid; grid-template-columns: 2fr 1fr; gap: 1rem;"
      "creative_modern" -> "display: grid; grid-template-columns: 1fr 1fr; gap: 1.5rem; transform: rotate(0.5deg);"
      _ -> "display: flex; flex-direction: column; gap: 1rem;"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <!-- Simple inline navigation -->
    <nav class="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 z-40">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div class="flex justify-between items-center h-16">
          <div class="flex items-center">
            <div class="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center mr-3">
              <span class="text-white font-bold text-sm">F</span>
            </div>
            <span class="text-xl font-bold text-gray-900">Frestyl Portfolio Editor</span>
          </div>
          <div class="flex items-center space-x-3">
            <span class="text-sm text-gray-700">
              <%= Map.get(assigns[:current_user] || %{}, :name, "User") %>
            </span>
          </div>
        </div>
      </div>
    </nav>

    <div class="pt-16 min-h-screen bg-gray-50">
      <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">

        <!-- Editor Header -->
        <div class="bg-white rounded-xl shadow-sm border mb-6">
          <div class="p-6 border-b border-gray-200">
            <div class="flex flex-col sm:flex-row sm:items-center justify-between">
              <div>
                <h1 class="text-2xl font-bold text-gray-900 flex items-center">
                  <div class="w-8 h-8 bg-gradient-to-br from-blue-600 to-purple-600 rounded-lg flex items-center justify-center mr-3">
                    <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </div>
                  Editing: <%= Map.get(assigns[:portfolio] || %{}, :title, "Untitled Portfolio") %>
                </h1>
                <p class="text-gray-600 mt-1">Create your professional portfolio with smart sections</p>
              </div>

              <div class="flex items-center space-x-3 mt-4 sm:mt-0">
                <!-- Preview Toggle -->
                <button
                  phx-click="toggle_preview"
                  class={[
                    "flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-colors",
                    if(Map.get(assigns, :preview_mode, :editor) == :split,
                      do: "bg-blue-100 text-blue-700",
                      else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                  ]}>
                  <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                  </svg>
                  <%= if Map.get(assigns, :preview_mode, :editor) == :split, do: "Hide Preview", else: "Show Preview" %>
                </button>

                <!-- Publish Button -->
                <button phx-click="publish_portfolio"
                        class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors font-medium">
                  <svg class="w-4 h-4 inline mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
                  </svg>
                  Publish
                </button>
              </div>
            </div>
          </div>

          <!-- Tab Navigation -->
          <div class="px-6">
            <nav class="flex space-x-8">
              <button phx-click="switch_tab"
                      phx-value-tab="sections"
                      class={[
                        "py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                        if(Map.get(assigns, :active_tab, "sections") == "sections",
                          do: "border-blue-500 text-blue-600",
                          else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                Sections
              </button>
              <button phx-click="switch_tab"
                      phx-value-tab="design"
                      class={[
                        "py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                        if(Map.get(assigns, :active_tab, "sections") == "design",
                          do: "border-blue-500 text-blue-600",
                          else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                Design
              </button>
              <button phx-click="switch_tab"
                      phx-value-tab="settings"
                      class={[
                        "py-4 px-1 border-b-2 font-medium text-sm transition-colors",
                        if(Map.get(assigns, :active_tab, "sections") == "settings",
                          do: "border-blue-500 text-blue-600",
                          else: "border-transparent text-gray-500 hover:text-gray-700 hover:border-gray-300")
                      ]}>
                Settings
              </button>
            </nav>
          </div>
        </div>

        <!-- Main Content Area -->
        <div class={[
          "grid gap-8",
          if(Map.get(assigns, :preview_mode, :editor) == :split,
            do: "lg:grid-cols-12",
            else: "grid-cols-1")
        ]}>
          <!-- Editor Panel -->
          <div class={[
            if(Map.get(assigns, :preview_mode, :editor) == :split,
              do: "lg:col-span-7 col-span-1",
              else: "col-span-1")
          ]}>
            <%= case Map.get(assigns, :active_tab, "sections") do %>
              <% "sections" -> %>
                <%= render_sections_tab(assigns) %>
              <% "design" -> %>
                <%= render_design_tab(assigns) %>
              <% "settings" -> %>
                <%= render_settings_tab(assigns) %>
              <% _ -> %>
                <%= render_sections_tab(assigns) %>
            <% end %>
          </div>

          <!-- Preview Panel -->
          <%= if Map.get(assigns, :preview_mode, :editor) == :split do %>
            <div class="lg:col-span-5 col-span-1">
              <div class="bg-white rounded-xl shadow-sm border overflow-hidden lg:sticky lg:top-8">
                <div class="p-4 bg-gray-50 border-b border-gray-200">
                  <div class="flex items-center justify-between">
                    <h3 class="font-medium text-gray-900">Live Preview</h3>
                    <div class="flex items-center space-x-2">
                      <div class="flex bg-gray-200 rounded-lg p-1">
                        <button phx-click="set_preview_mode"
                                phx-value-mode="mobile"
                                class={[
                                  "px-2 py-1 rounded text-xs font-medium transition-colors",
                                  if(Map.get(assigns, :preview_device, "desktop") == "mobile",
                                    do: "bg-white text-gray-900 shadow-sm",
                                    else: "text-gray-600")
                                ]}>
                          📱 Mobile
                        </button>
                        <button phx-click="set_preview_mode"
                                phx-value-mode="desktop"
                                class={[
                                  "px-2 py-1 rounded text-xs font-medium transition-colors",
                                  if(Map.get(assigns, :preview_device, "desktop") == "desktop",
                                    do: "bg-white text-gray-900 shadow-sm",
                                    else: "text-gray-600")
                                ]}>
                          💻 Desktop
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="h-96 overflow-y-auto bg-gray-100 p-4">
                  <!-- Apply dynamic CSS -->
                  <style>
                    <%= generate_preview_css(assigns[:customization] || %{}) %>
                  </style>

                  <div class={[
                    "bg-white rounded-lg shadow-sm overflow-hidden transition-all duration-300 portfolio-preview",
                    "layout-#{Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single")}",
                    if(Map.get(assigns, :preview_device, "desktop") == "mobile", do: "max-w-sm mx-auto", else: "w-full")
                  ]}>
                    <div class="p-6">
                      <h3 class="font-bold text-lg mb-4">
                        <%= Map.get(assigns[:portfolio] || %{}, :title, "Portfolio Preview") %>
                      </h3>

                      <!-- Show current customization with visual styling -->
                      <div class={[
                        "space-y-4",
                        "layout-#{Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single")}"
                      ]}>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Active Layout</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "layout_style", "mobile_single") |> String.replace("_", " ") %>
                          </p>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Color Scheme</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "color_scheme", "blue") %>
                          </p>
                          <div class="flex space-x-1 mt-2">
                            <div class="w-3 h-3 rounded" style="background-color: var(--primary-color)"></div>
                            <div class="w-3 h-3 rounded" style="background-color: var(--secondary-color)"></div>
                            <div class="w-3 h-3 rounded" style="background-color: var(--accent-color)"></div>
                          </div>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Typography</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "font_style", "inter") %>
                          </p>
                        </div>
                        <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                          <h4 class="font-medium text-sm">Spacing</h4>
                          <p class="text-xs text-gray-500 capitalize">
                            <%= Map.get(assigns[:customization] || %{}, "section_spacing", "normal") %>
                          </p>
                        </div>

                        <%= for section <- Enum.take(assigns[:sections] || [], 3) do %>
                          <div class="section-card border rounded-lg p-3" style="border-color: var(--accent-color)">
                            <h4 class="font-medium text-sm"><%= section.title %></h4>
                            <p class="text-xs text-gray-500"><%= String.capitalize(to_string(section.section_type)) %></p>
                          </div>
                        <% end %>

                        <%= if length(assigns[:sections] || []) > 3 do %>
                          <div class="text-center text-xs text-gray-500">
                            + <%= length(assigns[:sections] || []) - 3 %> more sections
                          </div>
                        <% end %>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <!-- Section Creation Dropdown -->
    <%= if Map.get(assigns, :show_create_dropdown, false) do %>
      <%= render_section_creation_dropdown(assigns) %>
    <% end %>

    <!-- Section Modal -->
    <%= if Map.get(assigns, :show_section_modal, false) do %>
      <.live_component
        module={FrestylWeb.PortfolioLive.Components.DynamicSectionModal}
        id="section-modal"
        section_type={Map.get(assigns, :current_section_type, "intro")}
        editing_section={Map.get(assigns, :editing_section, nil)} />
    <% end %>
    """
  end

  # Sections Tab Renderer
  defp render_sections_tab(assigns) do
    ~H"""
    <div class="sections-tab space-y-6">

      <!-- Add Section Button -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-900">Portfolio Sections</h3>
          <button phx-click="toggle_create_dropdown"
                  class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
            <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
            </svg>
            Add Section
          </button>
        </div>

        <p class="text-gray-600 text-sm">
          Sections are the building blocks of your portfolio. Each section is a fixed-height, scrollable block that showcases different aspects of your work and experience.
        </p>
      </div>

      <!-- Current Sections -->
      <div class="bg-white rounded-xl shadow-sm border">
        <div class="p-6 border-b border-gray-200">
          <h4 class="font-medium text-gray-900">Current Sections (<%= length(@sections) %>)</h4>
        </div>

        <%= if length(@sections) > 0 do %>
          <div class="p-6">
            <div class="space-y-4" id="sections-list">
              <%= for section <- Enum.sort_by(@sections, & &1.position) do %>
                <div class="section-item flex items-center justify-between p-4 border border-gray-200 rounded-lg hover:border-gray-300 transition-colors"
                     data-section-id={section.id}>

                  <!-- Section Info -->
                  <div class="flex items-center flex-1">
                    <div class="w-8 h-8 rounded-lg flex items-center justify-center mr-3"
                         style={"background: linear-gradient(135deg, #{get_section_color(section.section_type)} 0%, #{darken_color(get_section_color(section.section_type))} 100%)"}>
                      <span class="text-white text-sm"><%= get_section_icon(section.section_type) %></span>
                    </div>

                    <div class="flex-1">
                      <h5 class="font-medium text-gray-900"><%= section.title %></h5>
                      <div class="flex items-center space-x-3 text-sm text-gray-500">
                        <span><%= get_section_type_name(section.section_type) %></span>
                        <span>•</span>
                        <span>Position <%= section.position %></span>
                        <%= unless section.visible do %>
                          <span>•</span>
                          <span class="text-red-500">Hidden</span>
                        <% end %>
                      </div>
                    </div>
                  </div>

                  <!-- Section Actions -->
                  <div class="flex items-center space-x-2">
                    <!-- Visibility Toggle -->
                    <button phx-click="toggle_section_visibility"
                            phx-value-section_id={section.id}
                            class={[
                              "p-2 rounded-lg transition-colors",
                              if(section.visible,
                                do: "text-green-600 hover:bg-green-50",
                                else: "text-gray-400 hover:bg-gray-50")
                            ]}
                            title={if(section.visible, do: "Hide section", else: "Show section")}>
                      <%= if section.visible do %>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
                        </svg>
                      <% else %>
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L15 15"/>
                        </svg>
                      <% end %>
                    </button>

                    <!-- Edit Button -->
                    <button phx-click="edit_section"
                            phx-value-section_id={section.id}
                            class="p-2 text-blue-600 hover:bg-blue-50 rounded-lg transition-colors"
                            title="Edit section">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                      </svg>
                    </button>

                    <!-- Move Up/Down -->
                    <div class="flex flex-col">
                      <button phx-click="move_section_up"
                              phx-value-section_id={section.id}
                              class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-50 rounded transition-colors"
                              title="Move up">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7"/>
                        </svg>
                      </button>
                      <button phx-click="move_section_down"
                              phx-value-section_id={section.id}
                              class="p-1 text-gray-400 hover:text-gray-600 hover:bg-gray-50 rounded transition-colors"
                              title="Move down">
                        <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
                        </svg>
                      </button>
                    </div>

                    <!-- Delete Button -->
                    <button phx-click="delete_section"
                            phx-value-section_id={section.id}
                            data-confirm="Are you sure you want to delete this section? This action cannot be undone."
                            class="p-2 text-red-600 hover:bg-red-50 rounded-lg transition-colors"
                            title="Delete section">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                      </svg>
                    </button>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        <% else %>
          <div class="p-12 text-center">
            <div class="text-gray-400 mb-4">
              <svg class="w-16 h-16 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
            </div>
            <h3 class="text-lg font-medium text-gray-900 mb-2">No sections yet</h3>
            <p class="text-gray-500 mb-6">Start building your portfolio by adding your first section.</p>
            <button phx-click="toggle_create_dropdown"
                    class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors font-medium">
              <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
              </svg>
              Add Your First Section
            </button>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # Design Tab Renderer
  defp render_design_tab(assigns) do
    ~H"""
    <div class="design-tab space-y-6">

      <!-- Layout Selection -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Layout Style</h3>
        <p class="text-gray-600 text-sm mb-6">Choose how your sections are arranged on the page.</p>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <%= for {key, config} <- [
            {"mobile_single", %{name: "Single Column", description: "Mobile-first single column", icon: "📱", best_for: "mobile users, simple portfolios"}},
            {"grid_uniform", %{name: "Grid Layout", description: "Uniform grid blocks", icon: "⬜", best_for: "visual portfolios, galleries"}},
            {"dashboard", %{name: "Dashboard", description: "Variable-sized blocks", icon: "📊", best_for: "data-heavy portfolios, analytics"}},
            {"creative_modern", %{name: "Creative Modern", description: "Asymmetric layout", icon: "🎨", best_for: "creative professionals, designers"}}
          ] do %>
            <div class="layout-option">
              <button type="button"
                    phx-click="change_layout_style"
                    phx-value-layout={key}
                    class={[
                      "w-full text-left p-4 border-2 rounded-lg cursor-pointer transition-all hover:shadow-sm",
                      if(Map.get(@customization, "layout_style", "mobile_single") == key,
                        do: "border-blue-500 bg-blue-50",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
                <div class="flex items-center justify-between mb-3">
                  <div class="flex items-center">
                    <span class="text-2xl mr-3"><%= config.icon %></span>
                    <div>
                      <h4 class="font-medium text-gray-900"><%= config.name %></h4>
                      <p class="text-sm text-gray-500"><%= config.description %></p>
                    </div>
                  </div>
                  <%= if Map.get(@customization, "layout_style", "mobile_single") == key do %>
                    <div class="w-5 h-5 bg-blue-500 rounded-full flex items-center justify-center">
                      <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                      </svg>
                    </div>
                  <% end %>
                </div>

                <!-- Layout Preview -->
                <div class="layout-preview h-16 bg-gray-100 rounded border mb-3 overflow-hidden">
                  <%= case key do %>
                    <% "mobile_single" -> %>
                      <div class="h-full p-2 flex flex-col space-y-1">
                        <div class="h-2 bg-blue-300 rounded w-full"></div>
                        <div class="h-2 bg-blue-200 rounded w-full"></div>
                        <div class="h-2 bg-blue-200 rounded w-3/4"></div>
                      </div>
                    <% "grid_uniform" -> %>
                      <div class="h-full p-2 grid grid-cols-2 gap-1">
                        <div class="bg-green-300 rounded"></div>
                        <div class="bg-green-300 rounded"></div>
                        <div class="bg-green-200 rounded"></div>
                        <div class="bg-green-200 rounded"></div>
                      </div>
                    <% "dashboard" -> %>
                      <div class="h-full p-2 grid grid-cols-3 gap-1">
                        <div class="bg-purple-300 rounded col-span-2"></div>
                        <div class="bg-purple-200 rounded"></div>
                        <div class="bg-purple-200 rounded"></div>
                        <div class="bg-purple-300 rounded col-span-2"></div>
                      </div>
                    <% "creative_modern" -> %>
                      <div class="h-full p-2 relative">
                        <div class="absolute top-1 left-1 w-6 h-4 bg-pink-300 rounded transform rotate-12"></div>
                        <div class="absolute top-2 right-1 w-5 h-3 bg-pink-200 rounded"></div>
                        <div class="absolute bottom-1 left-2 w-8 h-3 bg-pink-300 rounded transform -rotate-6"></div>
                        <div class="absolute bottom-2 right-2 w-4 h-4 bg-pink-200 rounded-full"></div>
                      </div>
                  <% end %>
                </div>

                <p class="text-xs text-gray-600">Best for: <%= config.best_for %></p>
              </button>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Color Scheme -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Color Scheme</h3>
        <p class="text-gray-600 text-sm mb-6">Choose colors that reflect your personal brand.</p>

        <div class="grid grid-cols-3 md:grid-cols-6 gap-3">
          <%= for {scheme_name, colors} <- [
            {"blue", ["#3B82F6", "#1D4ED8", "#60A5FA"]},
            {"purple", ["#8B5CF6", "#7C3AED", "#A78BFA"]},
            {"green", ["#10B981", "#059669", "#34D399"]},
            {"red", ["#EF4444", "#DC2626", "#F87171"]},
            {"orange", ["#F97316", "#EA580C", "#FB923C"]},
            {"pink", ["#EC4899", "#DB2777", "#F472B6"]},
            {"dark", ["#1F2937", "#111827", "#374151"]},
            {"slate", ["#475569", "#334155", "#64748B"]},
            {"neutral", ["#525252", "#404040", "#737373"]},
            {"midnight", ["#0F172A", "#1E293B", "#334155"]},
            {"charcoal", ["#18181B", "#27272A", "#3F3F46"]},
            {"graphite", ["#171717", "#262626", "#525252"]}
          ] do %>
            <button phx-click="change_color_scheme"
                    phx-value-scheme={scheme_name}
                    class={[
                      "color-scheme-option p-3 border-2 rounded-lg transition-all hover:shadow-sm",
                      if(Map.get(@customization, "color_scheme", "blue") == scheme_name,
                        do: "border-gray-800 shadow-md",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>
              <div class="flex space-x-1 mb-2">
                <%= for color <- colors do %>
                  <div class="w-4 h-4 rounded-full" style={"background-color: #{color}"}></div>
                <% end %>
              </div>
              <p class="text-xs font-medium text-gray-700 capitalize"><%= scheme_name %></p>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Typography -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Typography</h3>
        <p class="text-gray-600 text-sm mb-6">Select fonts that match your style.</p>

        <div class="space-y-3">
          <%= for {font_key, font_info} <- [
            {"inter", %{name: "Inter", css_name: "Inter, system-ui, sans-serif", description: "Modern and clean, great for professional portfolios"}},
            {"poppins", %{name: "Poppins", css_name: "Poppins, system-ui, sans-serif", description: "Friendly and approachable, perfect for creative work"}},
            {"playfair", %{name: "Playfair Display", css_name: "Playfair Display, Georgia, serif", description: "Elegant serif font for sophisticated portfolios"}},
            {"source_sans", %{name: "Source Sans Pro", css_name: "Source Sans Pro, system-ui, sans-serif", description: "Clean and readable, ideal for text-heavy content"}}
          ] do %>
            <label class="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50 transition-colors">
              <input type="radio"
                    name="font_style"
                    value={font_key}
                    checked={Map.get(@customization, "font_style", "inter") == font_key}
                    phx-click="change_font_style"
                    phx-value-font={font_key}
                    class="text-blue-600 focus:ring-blue-500">
              <div class="ml-3">
                <p class="font-medium text-gray-900" style={"font-family: #{font_info.css_name}"}>
                  <%= font_info.name %>
                </p>
                <p class="text-sm text-gray-500"><%= font_info.description %></p>
              </div>
            </label>
          <% end %>
        </div>
      </div>

      <!-- Spacing & Style -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Spacing & Style</h3>

        <div class="space-y-6">
          <!-- Section Spacing -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Section Spacing</label>
            <div class="flex space-x-4">
              <%= for spacing <- ["compact", "normal", "spacious"] do %>
                <label class="flex items-center">
                  <input type="radio"
                        name="section_spacing"
                        value={spacing}
                        checked={Map.get(@customization, "section_spacing", "normal") == spacing}
                        phx-click="change_section_spacing"
                        phx-value-spacing={spacing}
                        class="text-blue-600 focus:ring-blue-500">
                  <span class="ml-2 text-sm text-gray-700 capitalize"><%= spacing %></span>
                </label>
              <% end %>
            </div>
          </div>

          <!-- Corner Radius -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Corner Style</label>
            <div class="flex space-x-4">
              <%= for radius <- ["sharp", "rounded", "very-rounded"] do %>
                <label class="flex items-center">
                  <input type="radio"
                        name="corner_radius"
                        value={radius}
                        checked={Map.get(@customization, "corner_radius", "rounded") == radius}
                        phx-click="change_corner_radius"
                        phx-value-radius={radius}
                        class="text-blue-600 focus:ring-blue-500">
                  <span class="ml-2 text-sm text-gray-700 capitalize"><%= String.replace(radius, "-", " ") %></span>
                </label>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Settings Tab Renderer
  defp render_settings_tab(assigns) do
    portfolio = Map.get(assigns, :portfolio, %{})
    customization = Map.get(assigns, :customization, %{})
    sections = Map.get(assigns, :sections, [])

    ~H"""
    <div class="settings-tab space-y-6">

      <!-- Portfolio Info -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Information</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio Title</label>
            <input type="text"
                   name="title"
                   value={Map.get(portfolio, :title, "")}
                   phx-change="update_portfolio_info"
                   phx-debounce="1000"
                   class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                   placeholder="Your Portfolio Title">
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Description</label>
            <textarea name="description"
                      rows="3"
                      phx-change="update_portfolio_info"
                      phx-debounce="1000"
                      class="w-full px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-y"
                      placeholder="Describe your portfolio..."><%= Map.get(portfolio, :description, "") %></textarea>
          </div>
        </div>
      </div>

      <!-- Privacy & Sharing -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Privacy & Sharing</h3>

        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-3">Portfolio Visibility</label>
            <div class="space-y-3">
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="public"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Public</div>
                  <div class="text-sm text-gray-600">Anyone can find and view your portfolio</div>
                </div>
              </label>
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="unlisted"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Unlisted</div>
                  <div class="text-sm text-gray-600">Only people with the link can view</div>
                </div>
              </label>
              <label class="relative flex items-start cursor-pointer">
                <input type="radio"
                       name="visibility"
                       value="private"
                       checked="true"
                       class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 mt-1">
                <div class="ml-3">
                  <div class="text-sm font-medium text-gray-900">Private</div>
                  <div class="text-sm text-gray-600">Only you can view (perfect for drafts)</div>
                </div>
              </label>
            </div>
          </div>

          <!-- Portfolio URL -->
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Portfolio URL</label>
            <div class="flex">
              <span class="inline-flex items-center px-3 rounded-l-lg border border-r-0 border-gray-300 bg-gray-50 text-gray-500 text-sm">
                frestyl.com/
              </span>
              <input type="text"
                     name="slug"
                     value={Map.get(portfolio, :slug, "")}
                     phx-change="update_portfolio_slug"
                     phx-debounce="1000"
                     class="flex-1 px-3 py-2 border border-gray-300 rounded-r-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                     placeholder="your-name">
            </div>
            <p class="mt-1 text-sm text-gray-500">Choose a custom URL for your portfolio</p>
          </div>
        </div>
      </div>

      <!-- Portfolio Stats -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-4">Portfolio Stats</h3>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="text-center p-4 bg-blue-50 rounded-lg">
            <div class="text-2xl font-bold text-blue-600"><%= length(sections) %></div>
            <div class="text-sm text-blue-700">Total Sections</div>
          </div>
          <div class="text-center p-4 bg-green-50 rounded-lg">
            <div class="text-2xl font-bold text-green-600">
              <%= Enum.count(sections, fn s -> Map.get(s, :visible, true) end) %>
            </div>
            <div class="text-sm text-green-700">Visible Sections</div>
          </div>
          <div class="text-center p-4 bg-purple-50 rounded-lg">
            <div class="text-2xl font-bold text-purple-600">Active</div>
            <div class="text-sm text-purple-700">Status</div>
          </div>
        </div>
      </div>

      <!-- Export & Actions -->
      <div class="bg-white rounded-xl shadow-sm border p-6">
        <h3 class="text-lg font-bold text-gray-900 mb-6">Portfolio Actions</h3>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <!-- Export Options -->
          <button phx-click="export_portfolio" phx-value-format="pdf"
                  class="group relative p-4 border border-gray-200 rounded-xl hover:border-blue-300 hover:shadow-sm transition-all text-left">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-blue-100 rounded-lg flex items-center justify-center mr-3 group-hover:bg-blue-200 transition-colors">
                <svg class="w-5 h-5 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900 group-hover:text-blue-900">Export PDF</h4>
                <p class="text-sm text-gray-500">Download as PDF</p>
              </div>
            </div>
          </button>

          <button phx-click="backup_portfolio"
                  class="group relative p-4 border border-gray-200 rounded-xl hover:border-green-300 hover:shadow-sm transition-all text-left">
            <div class="flex items-center">
              <div class="w-10 h-10 bg-green-100 rounded-lg flex items-center justify-center mr-3 group-hover:bg-green-200 transition-colors">
                <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
                </svg>
              </div>
              <div>
                <h4 class="font-medium text-gray-900 group-hover:text-green-900">Create Backup</h4>
                <p class="text-sm text-gray-500">Save complete copy</p>
              </div>
            </div>
          </button>
        </div>
      </div>

      <!-- Danger Zone -->
      <div class="bg-red-50 rounded-xl border border-red-200 p-6">
        <h3 class="text-lg font-bold text-red-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L4.082 15.5c-.77.833.192 2.5 1.732 2.5z"/>
          </svg>
          Danger Zone
        </h3>

        <div class="space-y-3">
          <button phx-click="reset_portfolio"
                  phx-data-confirm="Reset portfolio? This will remove all sections but keep basic info."
                  class="w-full p-3 bg-white border border-yellow-300 rounded-lg text-yellow-800 hover:bg-yellow-50 transition-colors text-sm font-medium">
            Reset Portfolio
          </button>

          <button phx-click="delete_portfolio"
                  phx-data-confirm="⚠️ DELETE PORTFOLIO? This cannot be undone!"
                  class="w-full p-3 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors text-sm font-medium">
            Delete Forever
          </button>
        </div>
      </div>
    </div>
    """
  end

  # Section Creation Dropdown
  defp render_section_creation_dropdown(assigns) do
    section_categories = EnhancedSectionSystem.get_sections_by_category()
    assigns = Map.put(assigns, :section_categories, section_categories)

    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-25 flex items-start justify-center pt-20 z-50"
         phx-click="close_create_dropdown">
      <div class="bg-white rounded-xl shadow-2xl max-w-4xl w-full mx-4 max-h-[80vh] overflow-hidden"
           phx-click-away="close_create_dropdown">

        <div class="p-6 border-b border-gray-200">
          <div class="flex items-center justify-between">
            <h3 class="text-xl font-bold text-gray-900">Add New Section</h3>
            <button phx-click="close_create_dropdown"
                    class="p-2 text-gray-400 hover:text-gray-600 rounded-lg hover:bg-gray-100 transition-colors">
              <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
          <p class="text-gray-600 mt-2">Choose a section type that best represents the content you want to showcase.</p>
        </div>

        <div class="p-6 overflow-y-auto max-h-[60vh]">
          <%= for {category, sections} <- @section_categories do %>
            <div class="mb-8">
              <h4 class="text-lg font-semibold text-gray-900 mb-4 capitalize">
                <%= String.replace(category, "_", " ") %>
              </h4>

              <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                <%= for {section_key, section_config} <- sections do %>
                  <button phx-click="create_section"
                          phx-value-section_type={section_key}
                          class="section-type-card text-left p-4 border border-gray-200 rounded-lg hover:border-blue-300 hover:shadow-sm transition-all group">
                    <div class="flex items-start">
                      <div class="w-10 h-10 rounded-lg flex items-center justify-center mr-3 group-hover:scale-110 transition-transform"
                           style={"background: linear-gradient(135deg, #{get_section_color_by_category(category)} 0%, #{darken_color(get_section_color_by_category(category))} 100%)"}>
                        <span class="text-white text-lg"><%= section_config.icon %></span>
                      </div>
                      <div class="flex-1">
                        <h5 class="font-medium text-gray-900 group-hover:text-blue-600 transition-colors">
                          <%= section_config.name %>
                        </h5>
                        <p class="text-sm text-gray-600 mt-1 line-clamp-2">
                          <%= section_config.description %>
                        </p>
                      </div>
                    </div>
                  </button>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end


  defp find_hero_section(sections) do
    Enum.find(sections, fn section ->
      to_string(section.section_type) == "hero"
    end)
  end

  defp get_current_user_from_session(_session) do
    # Implement your user session logic here
    %{id: 1, name: "Demo User", email: "demo@example.com"}
  end

  defp get_default_customization do
    %{
      "layout_style" => "mobile_single",
      "color_scheme" => "blue",
      "font_style" => "inter",
      "section_spacing" => "normal",
      "corner_radius" => "rounded"
    }
  end

  defp create_section(socket, params) do
    section_type = params["section_type"]
    title = params["title"]
    visible = params["visible"] == "true"

    # Extract content from params based on section type
    content = extract_section_content_from_params(section_type, params)

    # Get next position
    next_position = length(socket.assigns.sections) + 1

    section_attrs = %{
      portfolio_id: socket.assigns.portfolio.id,
      section_type: String.to_atom(section_type),
      title: title,
      content: content,
      visible: visible,
      position: next_position
    }

    case Portfolios.create_section(section_attrs) do
      {:ok, new_section} ->
        updated_sections = socket.assigns.sections ++ [new_section]
        hero_section = if section_type == "hero", do: new_section, else: socket.assigns.hero_section

        {:noreply, socket
        |> assign(:sections, updated_sections)
        |> assign(:hero_section, hero_section)
        |> assign(:show_section_modal, false)
        |> assign(:current_section_type, nil)
        |> assign(:editing_section, nil)
        |> put_flash(:info, "Section created successfully")}

      {:error, changeset} ->
        {:noreply, socket
        |> put_flash(:error, "Failed to create section: #{inspect(changeset.errors)}")}
    end
  end

  defp update_section(socket, params) do
    section_id = String.to_integer(params["section_id"])
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id))

    if section do
      title = params["title"]
      visible = params["visible"] == "true"
      content = extract_section_content_from_params(to_string(section.section_type), params)

      case Portfolios.update_section(section, %{title: title, content: content, visible: visible}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id, do: updated_section, else: s
          end)

          hero_section = if to_string(section.section_type) == "hero" do
            updated_section
          else
            socket.assigns.hero_section
          end

          {:noreply, socket
          |> assign(:sections, updated_sections)
          |> assign(:hero_section, hero_section)
          |> assign(:show_section_modal, false)
          |> assign(:current_section_type, nil)
          |> assign(:editing_section, nil)
          |> put_flash(:info, "Section updated successfully")}

        {:error, changeset} ->
          {:noreply, socket
          |> put_flash(:error, "Failed to update section: #{inspect(changeset.errors)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  defp extract_complex_array_from_params(params, field_key, field_config) do
    IO.puts("🔍 EXTRACTING COMPLEX ARRAY: #{field_key}")

    item_fields = Map.get(field_config, :item_fields, %{})

    # Find all items by looking for indexed parameters
    item_indices = params
    |> Map.keys()
    |> Enum.filter(&String.starts_with?(&1, "#{field_key}["))
    |> Enum.map(fn key ->
      case Regex.run(~r/#{field_key}\[(\d+)\]/, key) do
        [_, index] -> String.to_integer(index)
        _ -> nil
      end
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
    |> Enum.sort()

    # Extract each item
    items = Enum.map(item_indices, fn index ->
      Enum.reduce(item_fields, %{}, fn {sub_field_name, _sub_field_config}, item_acc ->
        sub_field_key = "#{field_key}[#{index}][#{sub_field_name}]"
        value = params[sub_field_key] || ""
        Map.put(item_acc, Atom.to_string(sub_field_name), value)
      end)
    end)

    %{field_key => items}
  end

  defp extract_section_content_from_params(section_type, params) do
    IO.puts("🔍 EXTRACTING CONTENT FOR: #{section_type}")

    # Simplified content extraction that doesn't rely on complex field configs
    case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || params["content"] || "",
          "website" => params["website"] || "",
          "email" => params["email"] || "",
          "phone" => params["phone"] || ""
        }

      "experience" ->
        %{
          "title" => params["title"] || params["job_title"] || "",
          "company" => params["company"] || "",
          "description" => params["description"] || params["content"] || "",
          "start_date" => params["start_date"] || "",
          "end_date" => params["end_date"] || "",
          "current" => params["current"] == "true"
        }

      "skills" ->
        skills_text = params["skills"] || params["content"] || ""
        skills = if skills_text != "" do
          skills_text
          |> String.split([",", "\n", ";"])
          |> Enum.map(&String.trim/1)
          |> Enum.reject(&(&1 == ""))
        else
          []
        end

        %{
          "skills" => skills,
          "description" => params["description"] || ""
        }

      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "website" => params["website"] || ""
        }

      _ ->
        # Generic fallback for any section type
        %{
          "content" => params["content"] || params["description"] || "Add your content here...",
          "title" => params["title"] || "",
          "description" => params["description"] || "",
          "main_content" => params["main_content"] || params["content"] || ""
        }
    end
  end

  defp extract_content_from_params(section_type, params) do
    IO.puts("🔍 SIMPLE CONTENT EXTRACTION FOR: #{section_type}")
    IO.puts("🔍 PARAMS: #{inspect(Map.keys(params))}")

    # Just grab the main content field and title
    content = %{
      "content" => params["content"] || params["description"] || params["summary"] || "",
      "title" => params["title"] || "",
      "description" => params["description"] || ""
    }

    # Add any other fields that exist in params
    additional_content = params
    |> Enum.filter(fn {key, value} ->
      key not in ["title", "content", "description", "visible", "section_id", "_target", "action"] and
      value != "" and not is_nil(value)
    end)
    |> Map.new()

    final_content = Map.merge(content, additional_content)

    IO.puts("🔍 FINAL CONTENT: #{inspect(final_content)}")
    final_content
  end

  defp find_hero_section(sections) do
    Enum.find(sections, fn section ->
      section_type = case section.section_type do
        atom when is_atom(atom) -> Atom.to_string(atom)
        string when is_binary(string) -> string
        _ -> ""
      end
      section_type == "hero"
    end)
  end

  # Missing function: get_default_customization/0
  defp get_default_customization do
    %{
      "layout_style" => "mobile_single",
      "color_scheme" => "blue",
      "font_style" => "inter",
      "section_spacing" => "normal",
      "corner_radius" => "rounded",
      "theme" => "professional",
      "primary_color" => "#3B82F6",
      "secondary_color" => "#1D4ED8",
      "accent_color" => "#60A5FA"
    }
  end

  # Missing function: get_current_user_from_session/1
  defp get_current_user_from_session(_session) do
    # This should extract user from session - implement based on your auth system
    %{id: 1, name: "Demo User", email: "demo@example.com"}
  end

  # Missing function: update_section_in_list/2
  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        updated_section
      else
        section
      end
    end)
  end

  defp extract_customization_params(params) do
    IO.puts("🔍 EXTRACTING CUSTOMIZATION FROM: #{inspect(params)}")

    # Define all possible customization fields that your system supports
    valid_customization_fields = [
      "primary_color", "secondary_color", "accent_color",
      "font_family", "font_style", "layout_style", "hero_style",
      "portfolio_layout", "color_scheme", "theme",
      "section_spacing", "corner_radius", "border_radius",
      "custom_css", "professional_type"
    ]

    # Filter and extract only valid customization fields
    result = params
    |> Enum.filter(fn {key, value} ->
      is_valid = key in valid_customization_fields and
                not is_nil(value) and
                value != "" and
                key != "_target"  # Exclude LiveView form metadata

      if is_valid do
        IO.puts("✅ VALID CUSTOMIZATION PARAM: #{key} = #{value}")
      else
        IO.puts("❌ FILTERED OUT: #{key} = #{inspect(value)}")
      end

      is_valid
    end)
    |> Map.new()

    IO.puts("🔍 EXTRACTION RESULT: #{inspect(result)}")
    result
  end

  # Add this function to handle content extraction from form params:
  defp extract_content_from_params(section_type, params) do
    IO.puts("🔍 EXTRACTING CONTENT FOR: #{section_type}")
    IO.puts("🔍 FROM PARAMS: #{inspect(params)}")

    # Basic content extraction - adapt based on your section types
    content = case section_type do
      "intro" ->
        %{
          "summary" => params["summary"] || params["content"] || "",
          "website" => params["website"] || "",
          "social_links" => extract_social_links(params)
        }

      "experience" ->
        %{
          "jobs" => extract_jobs_from_params(params)
        }

      "contact" ->
        %{
          "email" => params["email"] || "",
          "phone" => params["phone"] || "",
          "location" => params["location"] || "",
          "social_links" => extract_social_links(params)
        }

      "skills" ->
        %{
          "skills" => extract_skills_from_params(params),
          "description" => params["description"] || params["content"] || ""
        }

      _ ->
        # Generic content for other section types
        %{
          "content" => params["content"] || params["description"] || "Add your content here...",
          "title" => params["title"] || "",
          "description" => params["description"] || ""
        }
    end

    IO.puts("🔍 EXTRACTED CONTENT: #{inspect(content)}")
    content
  end

  # Helper function to extract social links from params
  defp extract_social_links(params) do
    social_platforms = ["linkedin", "twitter", "github", "website", "instagram"]

    social_platforms
    |> Enum.reduce(%{}, fn platform, acc ->
      key = "social_#{platform}"
      case params[key] do
        nil -> acc
        "" -> acc
        url -> Map.put(acc, platform, url)
      end
    end)
  end

  # Helper function to extract jobs from experience params
  defp extract_jobs_from_params(params) do
    # Look for job-related fields
    job = %{
      "title" => params["job_title"] || params["title"] || "",
      "company" => params["company"] || "",
      "description" => params["job_description"] || params["description"] || params["content"] || "",
      "start_date" => params["start_date"] || "",
      "end_date" => params["end_date"] || "",
      "current" => params["current"] == "true"
    }

    # Return as array (can be extended to handle multiple jobs)
    [job]
  end

  # Helper function to extract skills from params
  defp extract_skills_from_params(params) do
    skills_text = params["skills"] || params["content"] || ""

    # Split by comma, newline, or semicolon and clean up
    skills_text
    |> String.split(~r/[,\n;]/)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn skill -> %{"name" => skill} end)
  end

  @impl true
  def handle_event("update_customization", params, socket) do
    IO.puts("🎨 CUSTOMIZATION UPDATE RECEIVED")
    IO.puts("🎨 PARAMS: #{inspect(params)}")

    # Simple extraction - just get the first non-metadata param
    customization_param = params
    |> Enum.find(fn {key, value} ->
      key not in ["_target", "_csrf_token"] and value != ""
    end)

    case customization_param do
      {field, value} ->
        IO.puts("🎨 UPDATING: #{field} = #{value}")

        # Update customization directly
        updated_customization = Map.put(socket.assigns.customization, field, value)

        # Try to save to database
        case Portfolios.update_portfolio_customization_by_id(socket.assigns.portfolio.id, %{field => value}) do
          {:ok, updated_portfolio} ->
            IO.puts("✅ CUSTOMIZATION SAVED")

            # Broadcast update
            broadcast_comprehensive_update(updated_portfolio.id, socket.assigns.sections, updated_portfolio.customization)

            {:noreply, socket
            |> assign(:portfolio, updated_portfolio)
            |> assign(:customization, updated_portfolio.customization)}

          {:error, reason} ->
            IO.puts("❌ SAVE FAILED: #{inspect(reason)}")

            # Still update UI even if save fails
            {:noreply, socket
            |> assign(:customization, updated_customization)
            |> put_flash(:error, "Design change applied but not saved")}
        end

      nil ->
        IO.puts("❌ NO VALID CUSTOMIZATION PARAM FOUND")
        {:noreply, socket}
    end
  end

  defp broadcast_preview_update(portfolio_id, sections, customization) do
    PubSub.broadcast(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}",
      {:preview_update, %{sections: sections, customization: customization}})
  end

  # Color scheme definitions
  defp get_color_schemes do
    %{
      "blue" => ["#3B82F6", "#1D4ED8", "#60A5FA"],
      "purple" => ["#8B5CF6", "#7C3AED", "#A78BFA"],
      "green" => ["#10B981", "#059669", "#34D399"],
      "red" => ["#EF4444", "#DC2626", "#F87171"],
      "orange" => ["#F97316", "#EA580C", "#FB923C"],
      "pink" => ["#EC4899", "#DB2777", "#F472B6"],
      "indigo" => ["#6366F1", "#4F46E5", "#818CF8"],
      "gray" => ["#6B7280", "#4B5563", "#9CA3AF"]
    }
  end

  # Font options
  defp get_font_options do
    %{
      "inter" => %{
        name: "Inter",
        css_name: "Inter, system-ui, sans-serif",
        description: "Modern and clean, great for professional portfolios"
      },
      "poppins" => %{
        name: "Poppins",
        css_name: "Poppins, system-ui, sans-serif",
        description: "Friendly and approachable, perfect for creative work"
      },
      "playfair" => %{
        name: "Playfair Display",
        css_name: "Playfair Display, Georgia, serif",
        description: "Elegant serif font for sophisticated portfolios"
      },
      "source_sans" => %{
        name: "Source Sans Pro",
        css_name: "Source Sans Pro, system-ui, sans-serif",
        description: "Clean and readable, ideal for text-heavy content"
      }
    }
  end

  # Section helper functions
  defp get_section_icon(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{icon: icon} -> icon
      _ -> "📄"
    end
  end

  defp get_section_color(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{category: "introduction"} -> "#3B82F6"
      %{category: "professional"} -> "#059669"
      %{category: "education"} -> "#7C3AED"
      %{category: "skills"} -> "#DC2626"
      %{category: "work"} -> "#EA580C"
      %{category: "creative"} -> "#DB2777"
      %{category: "business"} -> "#1F2937"
      %{category: "recognition"} -> "#F59E0B"
      %{category: "credentials"} -> "#6366F1"
      %{category: "social_proof"} -> "#10B981"
      %{category: "content"} -> "#8B5CF6"
      %{category: "network"} -> "#06B6D4"
      %{category: "contact"} -> "#EF4444"
      %{category: "narrative"} -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp get_section_color_by_category(category) do
    case category do
      "introduction" -> "#3B82F6"
      "professional" -> "#059669"
      "education" -> "#7C3AED"
      "skills" -> "#DC2626"
      "work" -> "#EA580C"
      "creative" -> "#DB2777"
      "business" -> "#1F2937"
      "recognition" -> "#F59E0B"
      "credentials" -> "#6366F1"
      "social_proof" -> "#10B981"
      "content" -> "#8B5CF6"
      "network" -> "#06B6D4"
      "contact" -> "#EF4444"
      "narrative" -> "#F97316"
      _ -> "#6B7280"
    end
  end

  defp darken_color(hex_color) do
    case hex_color do
      "#3B82F6" -> "#1D4ED8"
      "#059669" -> "#047857"
      "#7C3AED" -> "#5B21B6"
      "#DC2626" -> "#B91C1C"
      "#EA580C" -> "#C2410C"
      "#DB2777" -> "#BE185D"
      "#1F2937" -> "#111827"
      "#F59E0B" -> "#D97706"
      "#6366F1" -> "#4F46E5"
      "#10B981" -> "#059669"
      "#8B5CF6" -> "#7C3AED"
      "#06B6D4" -> "#0891B2"
      "#EF4444" -> "#DC2626"
      "#F97316" -> "#EA580C"
      _ -> "#4B5563"
    end
  end

  defp get_section_type_name(section_type) do
    case EnhancedSectionSystem.get_section_config(to_string(section_type)) do
      %{name: name} -> name
      _ -> String.capitalize(to_string(section_type))
    end
  end

  # PubSub handlers
  @impl true
  def handle_info({:section_updated, section}, socket) do
    updated_sections = Enum.map(socket.assigns.sections, fn s ->
      if s.id == section.id, do: section, else: s
    end)

    hero_section = if to_string(section.section_type) == "hero" do
      section
    else
      socket.assigns.hero_section
    end

    {:noreply, socket
    |> assign(:sections, updated_sections)
    |> assign(:hero_section, hero_section)}
  end

  @impl true
  def handle_info({:portfolio_updated, portfolio}, socket) do
    {:noreply, assign(socket, :portfolio, portfolio)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp debug_socket_state(socket, label) do
    IO.puts("🐛 #{label}")
    IO.puts("🐛 Portfolio ID: #{socket.assigns.portfolio.id}")
    IO.puts("🐛 Sections: #{length(socket.assigns.sections)}")
    IO.puts("🐛 Customization: #{inspect(Map.keys(socket.assigns.customization))}")
    IO.puts("🐛 ====================================")
    socket
  end
end
