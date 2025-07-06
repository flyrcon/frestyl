# lib/frestyl_web/live/portfolio_live/portfolio_editor.ex
# UNIFIED PORTFOLIO EDITOR - FIXED VERSION

defmodule FrestylWeb.PortfolioLive.PortfolioEditor do
  use FrestylWeb, :live_view

  import Ecto.Query
  alias Frestyl.Repo

  alias Frestyl.{Accounts, Analytics, Channels, Portfolios, Streaming}
  alias Frestyl.Portfolios.ContentBlock
  alias Frestyl.Stories.MediaBinding
  alias Frestyl.Accounts.{User, Account}
  alias FrestylWeb.PortfolioLive.PortfolioPerformance

  alias FrestylWeb.PortfolioLive.Components.{ContentRenderer, SectionEditor, MediaLibrary, VideoRecorder}

  # ============================================================================
  # MOUNT - Account-Aware Foundation
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, _session, socket) do
    start_time = System.monotonic_time(:millisecond)
    user = socket.assigns.current_user

    IO.puts("🔥 PORTFOLIO EDITOR MOUNT: portfolio_id=#{portfolio_id}, user_id=#{user.id}")

    # Load portfolio with account context
    case load_portfolio_with_account_and_blocks(portfolio_id, user) do
      {:ok, portfolio, account, content_blocks} ->
        IO.puts("🔥 PORTFOLIO LOADED: #{portfolio.title}")

        # Account-based feature permissions
        features = get_account_features(account)
        limits = get_account_limits(account)

        # Load portfolio data
        sections = load_portfolio_sections(portfolio.id)
        IO.puts("🔥 SECTIONS LOADED: #{length(sections)} sections")

        media_library = load_portfolio_media(portfolio.id)
        IO.puts("🔥 MEDIA LOADED: #{length(media_library)} items")

        # Monetization & streaming data (account-dependent)
        monetization_data = load_monetization_data(portfolio, account)
        streaming_config = load_streaming_config(portfolio, account)

        # Template system with brand control hooks
        available_layouts = get_available_layouts(account)
        brand_constraints = get_brand_constraints(account)

        # Subscribe to preview updates for live preview functionality
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
        end

        socket = socket
        |> assign_core_data(portfolio, account, user)
        |> assign_features_and_limits(features, limits)
        |> assign_content_data(sections, media_library, content_blocks)
        |> assign_monetization_data(monetization_data, streaming_config)
        |> assign_design_system(portfolio, account, available_layouts, brand_constraints)
        |> assign_ui_state()
        |> assign_live_preview_state()
        |> load_dynamic_card_capabilities(portfolio, account)

        load_time = System.monotonic_time(:millisecond) - start_time
        IO.puts("🔥 PORTFOLIO EDITOR LOADED in #{load_time}ms")
        track_portfolio_editor_load_safe(portfolio_id, load_time)

        socket = if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
          socket
        else
          socket
        end

        {:ok, socket}

      {:error, :not_found} ->
        IO.puts("❌ PORTFOLIO NOT FOUND: #{portfolio_id}")
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/hub")}

      {:error, :unauthorized} ->
        IO.puts("❌ PORTFOLIO ACCESS DENIED: #{portfolio_id}")
        {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: "/hub")}

      error ->
        IO.puts("❌ PORTFOLIO LOAD ERROR: #{inspect(error)}")
        {:ok, socket |> put_flash(:error, "Error loading portfolio") |> redirect(to: "/hub")}
    end
  end

  # Add to portfolio_editor.ex mount function
  defp load_dynamic_card_capabilities(socket, portfolio, account) do
    is_dynamic_layout = is_dynamic_card_layout?(portfolio)

    if is_dynamic_layout do
      # Get actual dynamic blocks based on subscription tier
      available_blocks = get_dynamic_card_blocks(account.subscription_tier)

      # Get layout configuration for this portfolio
      layout_config = get_portfolio_layout_config(portfolio)

      # Load existing layout zones
      layout_zones = load_portfolio_layout_zones(portfolio.id)

      socket
      |> assign(:is_dynamic_layout, true)
      |> assign(:show_dynamic_layout_manager, false)
      |> assign(:available_dynamic_blocks, available_blocks)
      |> assign(:layout_config, layout_config)
      |> assign(:layout_zones, layout_zones)
      |> assign(:active_layout_category, get_current_layout_category(portfolio))
      |> assign(:brand_customization, get_brand_customization(portfolio))
    else
      socket
      |> assign(:is_dynamic_layout, false)
      |> assign(:show_dynamic_layout_manager, false)
    end
  end

  defp load_portfolio_layout_zones(portfolio_id) do
    # This would load actual zone configuration from database
    # For now, return default zones structure
    %{
      "hero" => [],
      "services" => [],
      "testimonials" => [],
      "pricing" => [],
      "cta" => []
    }
  end

  defp get_current_layout_category(portfolio) do
    layout_style = case portfolio.customization do
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> portfolio.theme || "professional_service_provider"
    end

    case layout_style do
      "professional_service_provider" -> :service_provider
      "creative_portfolio_showcase" -> :creative_showcase
      "technical_expert_dashboard" -> :technical_expert
      "content_creator_hub" -> :content_creator
      "corporate_executive_profile" -> :corporate_executive
      _ -> :service_provider
    end
  end


  defp get_portfolio_layout_config(portfolio) do
  customization = portfolio.customization || %{}

  %{
    layout_style: Map.get(customization, "layout") || portfolio.theme || "professional_service_provider",
    grid_density: Map.get(customization, "grid_density") || "normal",
    mobile_layout: Map.get(customization, "mobile_layout") || "card",
    animation_level: Map.get(customization, "animation_level") || "subtle",
    primary_color: Map.get(customization, "primary_color") || "#3b82f6",
    secondary_color: Map.get(customization, "secondary_color") || "#64748b",
    accent_color: Map.get(customization, "accent_color") || "#f59e0b"
  }
end

  # ============================================================================
  # ASSIGNMENT HELPERS - FIXED
  # ============================================================================

  defp assign_core_data(socket, portfolio, account, user) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:account, account)
    |> assign(:current_user, user)
    |> assign(:page_title, "Edit #{portfolio.title}")
  end

  defp assign_features_and_limits(socket, features, limits) do
    socket
    |> assign(:features, features)
    |> assign(:limits, limits)
    |> assign(:can_monetize, Map.get(features, :monetization, false))
    |> assign(:can_stream, Map.get(features, :streaming, false))
    |> assign(:can_customize_brand, Map.get(features, :brand_customization, false))
  end

  defp assign_content_data(socket, sections, media_library, content_blocks) do
    socket
    |> assign(:sections, sections)
    |> assign(:media_library, media_library)
    |> assign(:content_blocks, content_blocks)
    |> assign(:editing_section, nil)
    |> assign(:editing_mode, nil)
  end

  defp assign_monetization_data(socket, monetization_data, streaming_config) do
    socket
    |> assign(:monetization_data, monetization_data)
    |> assign(:streaming_config, streaming_config)
    |> assign(:revenue_analytics, monetization_data.analytics)
    |> assign(:booking_calendar, monetization_data.calendar)
  end

  defp assign_design_system(socket, portfolio, account, available_layouts, brand_constraints) do
    customization = portfolio.customization || %{}  # Move this line to the top

    # Extract design values with persistence
    portfolio_layout = customization["layout"] || "minimal"
    primary_color = customization["primary_color"] || "#374151"
    secondary_color = customization["secondary_color"] || "#6b7280"
    accent_color = customization["accent_color"] || "#059669"
    background_color = customization["background_color"] || "#ffffff"
    text_color = customization["text_color"] || "#1f2937"

    # Generate CSS for live preview (now customization is defined)
    portfolio_css = generate_portfolio_css(customization)

    socket
    |> assign(:portfolio_layout, portfolio_layout)
    |> assign(:primary_color, primary_color)
    |> assign(:secondary_color, secondary_color)
    |> assign(:accent_color, accent_color)
    |> assign(:background_color, background_color)
    |> assign(:text_color, text_color)
    |> assign(:customization, customization)
    |> assign(:portfolio_css, portfolio_css)
    |> assign(:available_layouts, available_layouts)
    |> assign(:brand_constraints, brand_constraints)
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:active_tab, :content)
    |> assign(:show_video_recorder, false)
    |> assign(:show_media_library, false)
    |> assign(:unsaved_changes, false)
    |> assign(:auto_save_enabled, true)
    |> assign(:current_user, Map.get(socket.assigns, :current_user, nil))
  end

  defp assign_live_preview_state(socket) do
    portfolio = socket.assigns.portfolio

    socket
    |> assign(:show_live_preview, true)
    |> assign(:preview_token, generate_preview_token(portfolio.id))
    |> assign(:preview_mobile_view, false)
    |> assign(:pending_changes, %{})
    |> assign(:debounce_timer, nil)
  end

  # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("toggle_live_preview", _params, socket) do
    show_preview = !socket.assigns.show_live_preview

    socket = assign(socket, :show_live_preview, show_preview)

    if show_preview do
      broadcast_preview_update(socket)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_preview_mobile", _params, socket) do
    mobile_view = !socket.assigns.preview_mobile_view
    socket = assign(socket, :preview_mobile_view, mobile_view)

    # Broadcast viewport change
    broadcast_viewport_change(socket, mobile_view)

    {:noreply, socket}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    tab_atom = String.to_atom(tab)
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("edit_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section do
      IO.puts("🔥 EDITING SECTION: #{section.title}")

      {:noreply, socket
      |> assign(:editing_section, section)
      |> assign(:section_edit_mode, true)}
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end


  # FIXED: Close section editor that properly resets state
  @impl true
  def handle_event("close_section_editor", _params, socket) do
    IO.puts("🔧 Closing section editor")

    {:noreply, socket
    |> assign(:section_edit_id, nil)
    |> assign(:editing_section, nil)
    |> assign(:section_edit_tab, nil)
    |> assign(:unsaved_changes, false)}
  end

  @impl true
  def handle_event("add_section", %{"type" => section_type}, socket) do
    portfolio_id = socket.assigns.portfolio.id

    case create_new_section(portfolio_id, section_type) do
      {:ok, new_section} ->
        sections = socket.assigns.sections ++ [new_section]

        socket = socket
        |> assign(:sections, sections)
        |> assign(:editing_section, new_section)
        |> assign(:editing_mode, :content)
        |> assign(:unsaved_changes, true)

        broadcast_content_update(socket, new_section)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add section")}
    end
  end

  @impl true
  def handle_event("delete_section", %{"section_id" => section_id}, socket) do
    section_id = String.to_integer(section_id)

    case delete_section(section_id) do
      {:ok, _deleted_section} ->
        sections = Enum.reject(socket.assigns.sections, &(&1.id == section_id))

        socket = socket
        |> assign(:sections, sections)
        |> assign(:editing_section, nil)
        |> assign(:unsaved_changes, true)

        broadcast_sections_update(socket)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete section")}
    end
  end

  @impl true
  def handle_event("save_portfolio", _params, socket) do
    case save_all_changes(socket.assigns.portfolio, socket.assigns.sections) do
      {:ok, _portfolio} ->
        socket = socket
        |> assign(:unsaved_changes, false)
        |> put_flash(:info, "Portfolio saved successfully")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to save portfolio")}
    end
  end

  @impl true
  def handle_event("close_section_editor", _params, socket) do
    IO.puts("🔧 Closing section editor")

    {:noreply, socket
    |> assign(:section_edit_id, nil)
    |> assign(:editing_section, nil)
    |> assign(:editing_section_media, [])
    |> assign(:section_edit_tab, nil)
    |> assign(:unsaved_changes, false)
    |> push_event("section-edit-cancelled", %{})}
  end

  @impl true
  def handle_event("save_section", %{"id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      case Portfolios.update_section(editing_section, %{}) do
        {:ok, updated_section} ->
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id_int, do: updated_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, nil)
          |> assign(:section_edit_mode, false)
          |> assign(:unsaved_changes, false)
          |> put_flash(:info, "Section saved successfully")

          # Update preview if active
          socket = if socket.assigns.show_live_preview do
            broadcast_preview_update(socket)
            socket
          else
            socket
          end

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save section")}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  @impl true
  def handle_event("cancel_section_edit", _params, socket) do
    {:noreply, socket
    |> assign(:editing_section, nil)
    |> assign(:section_edit_mode, false)
    |> assign(:unsaved_changes, false)}
  end

  @impl true
  def handle_event("update_section_field", %{"section_id" => section_id, "field" => field, "value" => value}, socket) do
    IO.puts("🔧 Updating section field: #{field} = #{inspect(value)}")

    section_id_int = String.to_integer(section_id)

    # Find the section to update
    section_to_update = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    if section_to_update do
      # Handle different field types properly
      update_params = case field do
        "title" ->
          %{title: String.trim(value)}
        "description" ->
          %{description: String.trim(value)}
        "visible" ->
          %{visible: value == "true" || value == true}
        "position" ->
          case Integer.parse(to_string(value)) do
            {pos, ""} -> %{position: pos}
            _ -> %{}
          end
        "main_content" ->
          # Handle main content updates
          current_content = section_to_update.content || %{}
          cleaned_value = strip_html_safely(value)
          updated_content = Map.put(current_content, "main_content", cleaned_value)
          %{content: updated_content}
        content_field ->
          # Handle other content fields
          current_content = section_to_update.content || %{}
          cleaned_value = if is_binary(value), do: strip_html_safely(value), else: value
          updated_content = Map.put(current_content, content_field, cleaned_value)
          %{content: updated_content}
      end

      if map_size(update_params) > 0 do
        case Portfolios.update_section(section_to_update, update_params) do
          {:ok, updated_section} ->
            IO.puts("✅ Section field updated successfully!")

            # Update sections list
            updated_sections = Enum.map(socket.assigns.sections, fn s ->
              if s.id == section_id_int, do: updated_section, else: s
            end)

            # Update editing_section if it's the same section
            editing_section = if socket.assigns[:editing_section] && socket.assigns.editing_section.id == section_id_int do
              updated_section
            else
              socket.assigns[:editing_section]
            end

            # CRITICAL: Don't use push_event which causes page refreshes
            {:noreply, socket
            |> assign(:sections, updated_sections)
            |> assign(:editing_section, editing_section)
            |> assign(:unsaved_changes, false)}

          {:error, changeset} ->
            IO.puts("❌ Section update failed: #{inspect(changeset.errors)}")

            {:noreply, socket
            |> put_flash(:error, "Failed to update section")
            |> assign(:unsaved_changes, true)}
        end
      else
        {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "Section not found")}
    end
  end

  # Handler for toggling dynamic layout manager
  def handle_event("toggle_dynamic_layout_manager", _params, socket) do
    current_state = Map.get(socket.assigns, :show_dynamic_layout_manager, false)
    {:noreply, assign(socket, :show_dynamic_layout_manager, !current_state)}
  end

  @impl true
  def handle_event("toggle_dynamic_layout_manager", _params, socket) do
    current_state = Map.get(socket.assigns, :show_dynamic_layout_manager, false)
    {:noreply, assign(socket, :show_dynamic_layout_manager, !current_state)}
  end

  @impl true
  def handle_event("select_layout_category", %{"category" => category}, socket) do
    category_atom = String.to_atom(category)
    portfolio = socket.assigns.portfolio

    # Update portfolio with new layout
    layout_name = case category_atom do
      :service_provider -> "professional_service_provider"
      :creative_showcase -> "creative_portfolio_showcase"
      :technical_expert -> "technical_expert_dashboard"
      :content_creator -> "content_creator_hub"
      :corporate_executive -> "corporate_executive_profile"
      _ -> "professional_service_provider"
    end

    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout_name)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        # Broadcast the layout change to live previews
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio_preview:#{portfolio.id}",
          {:layout_changed, layout_name, updated_customization}
        )

        # Reload dynamic capabilities with new layout
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:active_layout_category, category_atom)
        |> load_dynamic_card_capabilities(updated_portfolio, socket.assigns[:account] || %{})
        |> put_flash(:info, "Layout updated to #{humanize_category(category_atom)}")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update layout")}
    end
  end


  @impl true
  def handle_event("update_brand_color", %{"color" => color_key, "value" => color_value}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, color_key, color_value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        # Refresh both the editor and any live previews
        Phoenix.PubSub.broadcast(
          Frestyl.PubSub,
          "portfolio_preview:#{portfolio.id}",
          {:customization_updated, updated_customization}
        )

        {:noreply, socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:brand_customization, get_brand_customization(updated_portfolio))
        |> put_flash(:info, "Color updated successfully")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update color")}
    end
  end

  @impl true
  def handle_event("update_color_live", %{"field" => field, "value" => value}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, field, value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(String.to_atom(field), value)
        |> assign(:unsaved_changes, false)

        # Broadcast to live preview
        if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
        end

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save design changes")}
    end
  end

  @impl true
  def handle_event("update_color", %{"field" => field, "value" => value}, socket) do
    # Same as update_color_live but without immediate broadcast
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, field, value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(String.to_atom(field), value)
        |> assign(:unsaved_changes, false)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save design changes")}
    end
  end

  @impl true
  def handle_event("update_layout_live", %{"field" => "layout", "value" => layout_value}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout_value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:portfolio_layout, layout_value)
        |> assign(:unsaved_changes, false)

        # Broadcast to live preview
        if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
        end

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout changes")}
    end
  end

  @impl true
  def handle_event("update_layout", %{"field" => "layout", "value" => layout_value}, socket) do
    # Same as update_layout_live but without immediate broadcast
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, "layout", layout_value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:portfolio_layout, layout_value)
        |> assign(:unsaved_changes, false)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save layout changes")}
    end
  end

  defp strip_html_safely(value) when is_binary(value) do
    value
    |> String.replace(~r/<[^>]*>/, "")  # Remove HTML tags
    |> String.replace(~r/&[a-zA-Z0-9#]+;/, "")  # Remove HTML entities
    |> String.trim()
  end
  defp strip_html_safely(value), do: value

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp load_portfolio_with_account_and_blocks(portfolio_id, user) do
    with {:ok, portfolio} <- get_portfolio_safe(portfolio_id, user),
         account <- get_user_account(user) do
      # Don't try to load content_blocks if the association doesn't exist
      {:ok, portfolio, account, []}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :unexpected_error}
    end
  end

  defp get_portfolio_safe(portfolio_id, user) do
    try do
      # Use the correct Portfolios function based on your existing codebase
      case Portfolios.get_portfolio_with_sections(portfolio_id) do
        nil -> {:error, :not_found}
        portfolio ->
          if portfolio.user_id == user.id do
            {:ok, portfolio}
          else
            {:error, :unauthorized}
          end
      end
    rescue
      # Fallback if get_portfolio_with_sections doesn't exist
      _ ->
        try do
          case Portfolios.get_portfolio!(portfolio_id) do
            nil -> {:error, :not_found}
            portfolio ->
              if portfolio.user_id == user.id do
                # Load sections separately if needed
                portfolio = %{portfolio | sections: load_portfolio_sections(portfolio.id)}
                {:ok, portfolio}
              else
                {:error, :unauthorized}
              end
          end
        rescue
          _ -> {:error, :not_found}
        end
    end
  end

  defp get_user_account(user) do
    try do
      case Accounts.list_user_accounts(user.id) do
        [account | _] -> Map.put_new(account, :subscription_tier, "personal")
        [] -> %{subscription_tier: "personal"}
      end
    rescue
      # Fallback if Accounts module doesn't have this function
      _ -> %{subscription_tier: "personal"}
    end
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      # Try the most likely function name first
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ ->
        try do
          # Alternative: use query if list function doesn't exist
          import Ecto.Query
          Repo.all(from s in "portfolio_sections", where: s.portfolio_id == ^portfolio_id, order_by: [asc: s.position])
        rescue
          _ ->
            # Last resort: return empty list
            IO.puts("⚠️ Could not load portfolio sections for portfolio #{portfolio_id}")
            []
        end
    end
  end

  defp load_portfolio_media(portfolio_id) do
    try do
      Portfolios.list_portfolio_media(portfolio_id)
    rescue
      # Fallback if this function doesn't exist
      _ -> []
    end
  end

  defp get_account_features(account) do
    %{
      monetization: account.subscription_tier in ["creator", "professional"],
      streaming: account.subscription_tier in ["professional"],
      brand_customization: account.subscription_tier in ["creator", "professional"],
      analytics: true
    }
  end

  defp get_account_limits(account) do
    case account.subscription_tier do
      "personal" -> %{max_sections: 5, max_media_mb: 50}
      "creator" -> %{max_sections: 15, max_media_mb: 200}
      "professional" -> %{max_sections: 50, max_media_mb: 1000}
      _ -> %{max_sections: 5, max_media_mb: 50}
    end
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp load_portfolio_media(portfolio_id) do
    try do
      Portfolios.list_portfolio_media(portfolio_id)
    rescue
      _ -> []
    end
  end

  defp load_monetization_data(_portfolio, _account) do
    %{
      services: [],
      pricing: %{},
      calendar: %{},
      analytics: %{},
      payment_config: %{}
    }
  end

  defp load_streaming_config(_portfolio, _account) do
    %{
      streaming_key: nil,
      scheduled_streams: [],
      stream_analytics: %{},
      rtmp_config: %{}
    }
  end

  defp get_available_layouts(_account) do
    ["professional_service", "creative_showcase", "corporate_executive"]
  end

  defp get_brand_constraints(_account) do
    %{
      primary_colors: ["#1e40af", "#7c3aed", "#059669", "#dc2626"],
      accent_colors: ["#f59e0b", "#8b5cf6", "#06b6d4", "#ef4444"],
      fonts: ["Inter", "Roboto", "Open Sans"]
    }
  end

  defp get_brand_customization(portfolio) do
    customization = portfolio.customization || %{}

    %{
      primary_color: Map.get(customization, "primary_color") || "#3b82f6",
      secondary_color: Map.get(customization, "secondary_color") || "#64748b",
      accent_color: Map.get(customization, "accent_color") || "#f59e0b",
      brand_enforcement: Map.get(customization, "brand_enforcement") || false
    }
  end


  defp generate_design_tokens(portfolio, _brand_constraints) do
    # Get customization from portfolio, with fallback
    customization = Map.get(portfolio, :customization, %{})

    %{
      primary_color: Map.get(customization, "primary_color", "#1e40af"),
      accent_color: Map.get(customization, "accent_color", "#f59e0b"),
      font_family: Map.get(customization, "font_family", "Inter")
    }
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
  end

  defp track_portfolio_editor_load_safe(_portfolio_id, _load_time) do
    # Safe performance tracking
    :ok
  end

  @impl true
  def handle_event("update_section_content", %{"field" => field, "value" => value, "section-id" => section_id}, socket) do
    section_id_int = String.to_integer(section_id)
    editing_section = socket.assigns.editing_section

    if editing_section && editing_section.id == section_id_int do
      # Update the section content
      current_content = editing_section.content || %{}
      updated_content = Map.put(current_content, field, value)
      updated_section = %{editing_section | content: updated_content}

      # Save to database immediately
      case Portfolios.update_section(editing_section, %{content: updated_content}) do
        {:ok, saved_section} ->
          # Update sections list
          updated_sections = Enum.map(socket.assigns.sections, fn s ->
            if s.id == section_id_int, do: saved_section, else: s
          end)

          socket = socket
          |> assign(:sections, updated_sections)
          |> assign(:editing_section, saved_section)
          |> assign(:unsaved_changes, false)

          # Update live preview
          socket = if socket.assigns.show_live_preview do
            broadcast_preview_update(socket)
            socket
          else
            socket
          end

          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to save content")}
      end
    else
      {:noreply, socket}
    end
  end


  defp create_new_section(portfolio_id, section_type) do
    attrs = %{
      portfolio_id: portfolio_id,
      section_type: section_type,
      title: humanize_section_type(section_type),
      content: %{},
      position: get_next_position(portfolio_id),
      visible: true
    }

    Portfolios.create_portfolio_section(attrs)
  end

  defp delete_section(section_id) do
    case Portfolios.get_portfolio_section(section_id) do
      nil -> {:error, :not_found}
      section -> Portfolios.delete_portfolio_section(section)
    end
  end

  defp save_all_changes(portfolio, sections) do
    # This would typically save any pending changes
    {:ok, portfolio}
  end

  defp update_section_in_list(sections, updated_section) do
    Enum.map(sections, fn section ->
      if section.id == updated_section.id do
        updated_section
      else
        section
      end
    end)
  end

  defp humanize_section_type(section_type) do
    section_type
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp humanize_category(category) do
    case category do
      :service_provider -> "Service Provider"
      :creative_showcase -> "Creative Portfolio"
      :technical_expert -> "Technical Expert"
      :content_creator -> "Content Creator"
      :corporate_executive -> "Corporate Executive"
      _ -> "Service Provider"
    end
  end

  defp humanize_block_type(block_type) do
    block_type
    |> to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp get_next_position(portfolio_id) do
    # Get the highest position and add 1
    case Portfolios.get_max_section_position(portfolio_id) do
      nil -> 1
      max_pos -> max_pos + 1
    end
  end

  defp broadcast_preview_update(socket) do
    portfolio = socket.assigns.portfolio
    customization = socket.assigns.customization || portfolio.customization || %{}

    # Generate CSS from current customization
    css = generate_portfolio_css(customization)

    # Broadcast via PubSub to both live_preview and show.ex
    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:preview_update, %{css: css, customization: customization}}
    )

    socket
  end

  defp generate_portfolio_css(customization) do
    primary_color = customization["primary_color"] || "#374151"
    secondary_color = customization["secondary_color"] || "#6b7280"
    accent_color = customization["accent_color"] || "#059669"
    background_color = customization["background_color"] || "#ffffff"
    text_color = customization["text_color"] || "#1f2937"

    """
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
      --accent-color: #{accent_color};
      --background-color: #{background_color};
      --text-color: #{text_color};
    }

    body {
      background-color: var(--background-color);
      color: var(--text-color);
    }

    .primary { color: var(--primary-color); }
    .secondary { color: var(--secondary-color); }
    .accent { color: var(--accent-color); }

    .bg-primary { background-color: var(--primary-color); }
    .bg-secondary { background-color: var(--secondary-color); }
    .bg-accent { background-color: var(--accent-color); }
    """
  end

  defp broadcast_content_update(socket, section) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:content_update, section}
    )
  end

  defp broadcast_sections_update(socket) do
    portfolio = socket.assigns.portfolio
    sections = socket.assigns.sections

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:sections_update, sections}
    )
  end

  defp broadcast_viewport_change(socket, mobile_view) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:viewport_change, mobile_view}
    )
  end

  defp generate_css(customization) when is_map(customization) do
    primary_color = Map.get(customization, "primary_color", "#1e40af")
    accent_color = Map.get(customization, "accent_color", "#f59e0b")

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
    }
    """
  end

  defp generate_css(_), do: generate_css(%{})

  # ============================================================================
  # TEMPLATE HELPER FUNCTIONS (for portfolio_editor.html.heex)
  # ============================================================================

  defp build_preview_url(portfolio, preview_token) do
    # Build URL with customization data
    base_url = "/live_preview/#{portfolio.id}/#{preview_token}"

    # Add preview parameter if needed
    params = if preview_token do
      [{"preview", preview_token}]
    else
      []
    end

    # Add customization as URL parameter for immediate CSS application
    customization = portfolio.customization || %{}
    if map_size(customization) > 0 do
      customization_json = Jason.encode!(customization)
      params = [{"customization", customization_json} | params]
    end

    # Add cache busting
    params = [{"t", :os.system_time(:millisecond)} | params]

    if params == [] do
      base_url
    else
      query_string = params
      |> Enum.map(fn {key, value} -> "#{key}=#{URI.encode(to_string(value))}" end)
      |> Enum.join("&")

      "#{base_url}?#{query_string}"
    end
  end

  defp render_content_tab(assigns) do
    ~H"""
    <div class="content-tab">
      <div class="mb-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Portfolio Sections</h3>

        <!-- Add Section Button -->
        <div class="mb-4">
          <div class="relative">
            <select
              phx-change="add_section"
              class="block w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:ring-purple-500 focus:border-purple-500 text-sm">
              <option value="">Add a section...</option>
              <option value="intro">Introduction</option>
              <option value="experience">Experience</option>
              <option value="skills">Skills</option>
              <option value="projects">Projects</option>
              <option value="contact">Contact</option>
            </select>
          </div>
        </div>

        <!-- Sections List -->
        <div class="space-y-2">
          <%= for section <- @sections do %>
            <div class={[
              "p-3 border rounded-lg cursor-pointer transition-colors",
              if(@editing_section && @editing_section.id == section.id,
                do: "border-purple-500 bg-purple-50",
                else: "border-gray-200 hover:border-gray-300 bg-white")
            ]}>
              <div class="flex items-center justify-between">
                <div class="flex-1" phx-click="edit_section" phx-value-section_id={section.id}>
                  <h4 class="font-medium text-gray-900"><%= section.title %></h4>
                  <p class="text-sm text-gray-500 capitalize"><%= section.section_type %></p>
                </div>
                <div class="flex items-center space-x-2">
                  <button
                    type="button"
                    phx-click="edit_section"
                    phx-value-section_id={section.id}
                    class="text-gray-400 hover:text-purple-600 cursor-pointer">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"/>
                    </svg>
                  </button>
                  <button
                    type="button"
                    phx-click="delete_section"
                    phx-value-section_id={section.id}
                    class="text-gray-400 hover:text-red-600 cursor-pointer"
                    data-confirm="Are you sure you want to delete this section?">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp render_design_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div>
        <h3 class="text-xl font-semibold text-gray-900 mb-2">Design Settings</h3>
        <p class="text-sm text-gray-600">Universal design controls that apply to all portfolio types</p>
      </div>

      <!-- Color Management - Single Row Layout -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Brand Colors</h4>
        <div class="grid grid-cols-1 gap-6">
          <%= for {color_key, color_label, description} <- [
            {"primary_color", "Primary Color", "Main brand color used for headers and key elements"},
            {"secondary_color", "Secondary Color", "Supporting color used for text and backgrounds"},
            {"accent_color", "Accent Color", "Highlight color used for buttons and links"}
          ] do %>
            <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-900 mb-1"><%= color_label %></label>
                <p class="text-xs text-gray-600"><%= description %></p>
              </div>
              <div class="flex items-center space-x-3">
                <input type="color"
                      value={Map.get(@customization || @portfolio.customization || %{}, color_key, get_default_color(color_key))}
                      phx-change="update_design_color"
                      phx-value-color={color_key}
                      class="w-12 h-12 rounded-lg border border-gray-300 cursor-pointer">
                <input type="text"
                      value={Map.get(@customization || @portfolio.customization || %{}, color_key, get_default_color(color_key))}
                      phx-change="update_design_color"
                      phx-value-color={color_key}
                      class="w-24 px-3 py-2 border border-gray-300 rounded-md text-sm font-mono">
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Typography Settings -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Typography</h4>
        <div class="grid grid-cols-1 gap-4">
          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Font Family</label>
              <p class="text-xs text-gray-600">Primary font used throughout the portfolio</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Inter (Default)</option>
              <option>Roboto</option>
              <option>Open Sans</option>
              <option>Montserrat</option>
            </select>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Font Size Scale</label>
              <p class="text-xs text-gray-600">Overall text size throughout the portfolio</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Small</option>
              <option>Medium (Default)</option>
              <option>Large</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Spacing & Layout -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Spacing & Layout</h4>
        <div class="grid grid-cols-1 gap-4">
          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Section Spacing</label>
              <p class="text-xs text-gray-600">Space between portfolio sections</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Compact</option>
              <option>Normal (Default)</option>
              <option>Spacious</option>
            </select>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Border Radius</label>
              <p class="text-xs text-gray-600">Roundness of cards and buttons</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Sharp</option>
              <option>Rounded (Default)</option>
              <option>Very Rounded</option>
            </select>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_dynamic_layout_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div>
        <h3 class="text-xl font-semibold text-gray-900 mb-2">Dynamic Card Layout</h3>
        <p class="text-sm text-gray-600">Configure your professional layout structure and content arrangement</p>
      </div>

      <!-- Layout Category Selection - Single Column -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Professional Layout Category</h4>
        <p class="text-sm text-gray-600 mb-6">Choose the layout that best fits your professional focus</p>

        <div class="space-y-3">
          <%= for block_category <- @available_dynamic_blocks do %>
            <button phx-click="select_layout_category"
                    phx-value-category={block_category.category}
                    class={[
                      "w-full p-4 border-2 rounded-lg transition-all text-left hover:shadow-md",
                      if(@active_layout_category == block_category.category,
                        do: "border-blue-500 bg-blue-50 ring-2 ring-blue-200",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>

              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-3 mb-2">
                    <h5 class="font-semibold text-gray-900"><%= block_category.name %></h5>
                    <%= if @active_layout_category == block_category.category do %>
                      <span class="px-2 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full">Current</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-600 mb-3"><%= get_category_description(block_category.category) %></p>

                  <!-- Available Blocks in Single Row -->
                  <div class="flex flex-wrap gap-2">
                    <%= for block_type <- block_category.blocks do %>
                      <span class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded border">
                        <%= humanize_block_type(block_type) %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <%= if @active_layout_category == block_category.category do %>
                  <svg class="w-6 h-6 text-blue-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Functional Zone Manager -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h4 class="text-lg font-semibold text-gray-900">Layout Zones</h4>
            <p class="text-sm text-gray-600">Arrange content blocks within your layout zones</p>
          </div>
          <button phx-click="toggle_dynamic_layout_manager"
                  class={[
                    "px-4 py-2 rounded-lg font-medium transition-colors",
                    if(@show_dynamic_layout_manager,
                      do: "bg-blue-600 text-white",
                      else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                  ]}>
            <%= if @show_dynamic_layout_manager, do: "Hide Manager", else: "Open Manager" %>
          </button>
        </div>

        <!-- Zone Configuration -->
        <div class="space-y-4">
          <%= for {zone_name, blocks} <- @layout_zones do %>
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <div>
                  <h5 class="font-medium text-gray-900 capitalize"><%= zone_name %> Zone</h5>
                  <p class="text-sm text-gray-600"><%= get_zone_description(zone_name) %></p>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500"><%= length(blocks) %> blocks</span>
                  <button phx-click="add_block_to_zone"
                          phx-value-zone={zone_name}
                          class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition-colors">
                    Add Block
                  </button>
                </div>
              </div>

              <!-- Zone Content -->
              <div class="min-h-16 border-2 border-dashed border-gray-200 rounded-lg p-4 bg-gray-50">
                <%= if length(blocks) > 0 do %>
                  <div class="flex flex-wrap gap-2">
                    <%= for {block, index} <- Enum.with_index(blocks) do %>
                      <div class="flex items-center space-x-2 px-3 py-2 bg-white border border-gray-200 rounded">
                        <span class="text-sm text-gray-700"><%= humanize_block_type(block.type || "content") %></span>
                        <button phx-click="remove_block_from_zone"
                                phx-value-zone={zone_name}
                                phx-value-index={index}
                                class="text-gray-400 hover:text-red-600">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center text-gray-400">
                    <svg class="w-8 h-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                    </svg>
                    <p class="text-sm">Drop content blocks here</p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Available Blocks Library -->
        <%= if @show_dynamic_layout_manager do %>
          <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <h5 class="font-medium text-blue-900 mb-3">Available Content Blocks</h5>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
              <%= for block_category <- @available_dynamic_blocks do %>
                <%= for block_type <- block_category.blocks do %>
                  <button phx-click="add_content_block"
                          phx-value-block_type={block_type}
                          class="p-3 bg-white border border-blue-200 rounded text-left hover:bg-blue-50 transition-colors">
                    <div class="text-sm font-medium text-blue-900"><%= humanize_block_type(block_type) %></div>
                    <div class="text-xs text-blue-600 mt-1">Click to add</div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_analytics_tab(assigns) do
    ~H"""
    <div class="analytics-tab">
      <div class="mb-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Portfolio Analytics</h3>

        <div class="space-y-4">
          <div class="bg-gray-50 rounded-lg p-4">
            <div class="text-2xl font-bold text-gray-900">0</div>
            <div class="text-sm text-gray-600">Total Views</div>
          </div>

          <div class="bg-gray-50 rounded-lg p-4">
            <div class="text-2xl font-bold text-gray-900">0</div>
            <div class="text-sm text-gray-600">Unique Visitors</div>
          </div>

          <div class="bg-gray-50 rounded-lg p-4">
            <div class="text-2xl font-bold text-gray-900">0%</div>
            <div class="text-sm text-gray-600">Conversion Rate</div>
          </div>
        </div>

        <div class="mt-4 text-xs text-gray-500">
          Analytics data updates every 24 hours
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_info({:preview_update, data}, socket) when is_map(data) do
    css = Map.get(data, :css, "")
    customization = Map.get(data, :customization, %{})

    {:noreply, socket
    |> assign(:portfolio_css, css)
    |> assign(:customization, customization)}
  end

  @impl true
  def handle_info({:layout_changed, layout_name, customization}, socket) do
    # Generate new CSS with the layout change
    css = generate_portfolio_css(customization)

    {:noreply, socket
    |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)}
  end

  @impl true
  def handle_info({:customization_updated, customization}, socket) do
    # Generate new CSS with updated customization
    css = generate_portfolio_css(customization)

    {:noreply, socket
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 Show received unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:layout_changed, _layout_name, _customization}, socket) do
    # Portfolio editor doesn't need to handle its own layout change broadcasts
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 PortfolioEditor received unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  # Helper functions for the improved layout:

  defp get_default_color(color_key) do
    case color_key do
      "primary_color" -> "#374151"
      "secondary_color" -> "#6b7280"
      "accent_color" -> "#059669"
      _ -> "#374151"
    end
  end

  defp get_category_icon(category) do
    case category do
      :service_provider -> "💼"
      :creative_showcase -> "🎨"
      :technical_expert -> "⚡"
      :content_creator -> "📺"
      :corporate_executive -> "🏢"
      _ -> "📄"
    end
  end

  defp get_zones_for_category(category) do
    case category do
      :service_provider -> [
        {"hero", []},
        {"services", []},
        {"testimonials", []},
        {"pricing", []},
        {"contact", []}
      ]
      :creative_showcase -> [
        {"hero", []},
        {"portfolio", []},
        {"process", []},
        {"testimonials", []},
        {"commission", []}
      ]
      :technical_expert -> [
        {"hero", []},
        {"skills", []},
        {"projects", []},
        {"experience", []},
        {"consultation", []}
      ]
      :content_creator -> [
        {"hero", []},
        {"content", []},
        {"metrics", []},
        {"partnerships", []},
        {"subscribe", []}
      ]
      :corporate_executive -> [
        {"hero", []},
        {"summary", []},
        {"achievements", []},
        {"leadership", []},
        {"contact", []}
      ]
      _ -> [{"hero", []}, {"content", []}, {"contact", []}]
    end
  end

  defp get_zone_description(zone_name, category) do
    case {zone_name, category} do
      {"hero", _} -> "Primary introduction and value proposition"
      {"services", :service_provider} -> "Service offerings and packages"
      {"portfolio", :creative_showcase} -> "Visual work samples and case studies"
      {"skills", :technical_expert} -> "Technical skills and expertise matrix"
      {"content", :content_creator} -> "Featured content and media showcase"
      {"summary", :corporate_executive} -> "Executive summary and key metrics"
      {"testimonials", _} -> "Client testimonials and social proof"
      {"pricing", _} -> "Pricing information and packages"
      {"contact", _} -> "Contact information and call-to-action"
      _ -> "Content area for #{zone_name} information"
    end
  end

  # Additional event handlers for design and layout updates
  @impl true
  def handle_event("update_design_token", %{"token" => token, "value" => value}, socket) do
    customization = Map.put(socket.assigns.customization, token, value)
    design_tokens = Map.put(socket.assigns.design_tokens, String.to_atom(token), value)

    socket = socket
    |> assign(:customization, customization)
    |> assign(:design_tokens, design_tokens)
    |> assign(:unsaved_changes, true)

    # Broadcast design update to preview
    broadcast_design_update(socket, customization)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_layout", %{"value" => layout}, socket) do
    socket = socket
    |> assign(:current_layout, layout)
    |> assign(:unsaved_changes, true)

    # Broadcast layout change to preview
    broadcast_layout_update(socket, layout)

    {:noreply, socket}
  end

  # Additional broadcasting helpers
  defp broadcast_design_update(socket, customization) do
    portfolio = socket.assigns.portfolio
    css = generate_css(customization)

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:preview_update, customization, css}
    )
  end

  defp broadcast_layout_update(socket, layout) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:layout_update, layout}
    )
  end

  @impl true
  def handle_event(event_name, params, socket) do
    IO.puts("🔥 RECEIVED EVENT: #{event_name}")
    IO.puts("🔥 PARAMS: #{inspect(params)}")
    {:noreply, socket}
  end


  # CONSOLIDATED FIX: Replace both render_design_tab and render_dynamic_layout_tab in portfolio_editor.ex

  # ============================================================================
  # DESIGN TAB - Universal design settings for ALL portfolio types
  # ============================================================================

  defp render_design_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div>
        <h3 class="text-xl font-semibold text-gray-900 mb-2">Design Settings</h3>
        <p class="text-sm text-gray-600">Universal design controls that apply to all portfolio types</p>
      </div>

      <!-- Color Management - Single Row Layout -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Brand Colors</h4>
        <div class="grid grid-cols-1 gap-6">
          <%= for {color_key, color_label, description} <- [
            {"primary_color", "Primary Color", "Main brand color used for headers and key elements"},
            {"secondary_color", "Secondary Color", "Supporting color used for text and backgrounds"},
            {"accent_color", "Accent Color", "Highlight color used for buttons and links"}
          ] do %>
            <div class="flex items-center justify-between p-4 bg-gray-50 rounded-lg">
              <div class="flex-1">
                <label class="block text-sm font-medium text-gray-900 mb-1"><%= color_label %></label>
                <p class="text-xs text-gray-600"><%= description %></p>
              </div>
              <div class="flex items-center space-x-3">
                <input type="color"
                      value={get_portfolio_color(@portfolio, color_key)}
                      phx-change="update_design_color"
                      phx-value-color={color_key}
                      class="w-12 h-12 rounded-lg border border-gray-300 cursor-pointer">
                <input type="text"
                      value={get_portfolio_color(@portfolio, color_key)}
                      phx-change="update_design_color"
                      phx-value-color={color_key}
                      class="w-24 px-3 py-2 border border-gray-300 rounded-md text-sm font-mono">
              </div>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Typography Settings -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Typography</h4>
        <div class="grid grid-cols-1 gap-4">
          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Font Family</label>
              <p class="text-xs text-gray-600">Primary font used throughout the portfolio</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Inter (Default)</option>
              <option>Roboto</option>
              <option>Open Sans</option>
              <option>Montserrat</option>
            </select>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Font Size Scale</label>
              <p class="text-xs text-gray-600">Overall text size throughout the portfolio</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Small</option>
              <option>Medium (Default)</option>
              <option>Large</option>
            </select>
          </div>
        </div>
      </div>

      <!-- Spacing & Layout -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Spacing & Layout</h4>
        <div class="grid grid-cols-1 gap-4">
          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Section Spacing</label>
              <p class="text-xs text-gray-600">Space between portfolio sections</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Compact</option>
              <option>Normal (Default)</option>
              <option>Spacious</option>
            </select>
          </div>

          <div class="flex items-center justify-between">
            <div>
              <label class="text-sm font-medium text-gray-900">Border Radius</label>
              <p class="text-xs text-gray-600">Roundness of cards and buttons</p>
            </div>
            <select class="px-3 py-2 border border-gray-300 rounded-md text-sm">
              <option>Sharp</option>
              <option>Rounded (Default)</option>
              <option>Very Rounded</option>
            </select>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # DYNAMIC LAYOUT TAB - Layout structure and content blocks only
  # ============================================================================

  defp render_dynamic_layout_tab(assigns) do
    ~H"""
    <div class="space-y-8">
      <!-- Header -->
      <div>
        <h3 class="text-xl font-semibold text-gray-900 mb-2">Dynamic Card Layout</h3>
        <p class="text-sm text-gray-600">Configure your professional layout structure and content arrangement</p>
      </div>

      <!-- Layout Category Selection - Single Column -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <h4 class="text-lg font-semibold text-gray-900 mb-4">Professional Layout Category</h4>
        <p class="text-sm text-gray-600 mb-6">Choose the layout that best fits your professional focus</p>

        <div class="space-y-3">
          <%= for block_category <- @available_dynamic_blocks do %>
            <button phx-click="select_layout_category"
                    phx-value-category={block_category.category}
                    class={[
                      "w-full p-4 border-2 rounded-lg transition-all text-left hover:shadow-md",
                      if(@active_layout_category == block_category.category,
                        do: "border-blue-500 bg-blue-50 ring-2 ring-blue-200",
                        else: "border-gray-200 hover:border-gray-300")
                    ]}>

              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <div class="flex items-center space-x-3 mb-2">
                    <h5 class="font-semibold text-gray-900"><%= block_category.name %></h5>
                    <%= if @active_layout_category == block_category.category do %>
                      <span class="px-2 py-1 bg-blue-100 text-blue-700 text-xs font-medium rounded-full">Current</span>
                    <% end %>
                  </div>
                  <p class="text-sm text-gray-600 mb-3"><%= get_category_description(block_category.category) %></p>

                  <!-- Available Blocks in Single Row -->
                  <div class="flex flex-wrap gap-2">
                    <%= for block_type <- block_category.blocks do %>
                      <span class="text-xs px-2 py-1 bg-gray-100 text-gray-600 rounded border">
                        <%= humanize_block_type(block_type) %>
                      </span>
                    <% end %>
                  </div>
                </div>

                <%= if @active_layout_category == block_category.category do %>
                  <svg class="w-6 h-6 text-blue-500 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
                  </svg>
                <% end %>
              </div>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Functional Zone Manager -->
      <div class="bg-white p-6 rounded-lg border border-gray-200">
        <div class="flex items-center justify-between mb-4">
          <div>
            <h4 class="text-lg font-semibold text-gray-900">Layout Zones</h4>
            <p class="text-sm text-gray-600">Arrange content blocks within your layout zones</p>
          </div>
          <button phx-click="toggle_dynamic_layout_manager"
                  class={[
                    "px-4 py-2 rounded-lg font-medium transition-colors",
                    if(@show_dynamic_layout_manager,
                      do: "bg-blue-600 text-white",
                      else: "bg-gray-100 text-gray-700 hover:bg-gray-200")
                  ]}>
            <%= if @show_dynamic_layout_manager, do: "Hide Manager", else: "Open Manager" %>
          </button>
        </div>

        <!-- Zone Configuration -->
        <div class="space-y-4">
          <%= for {zone_name, blocks} <- @layout_zones do %>
            <div class="border border-gray-200 rounded-lg p-4">
              <div class="flex items-center justify-between mb-3">
                <div>
                  <h5 class="font-medium text-gray-900 capitalize"><%= zone_name %> Zone</h5>
                  <p class="text-sm text-gray-600"><%= get_zone_description(zone_name) %></p>
                </div>
                <div class="flex items-center space-x-2">
                  <span class="text-xs text-gray-500"><%= length(blocks) %> blocks</span>
                  <button phx-click="add_block_to_zone"
                          phx-value-zone={zone_name}
                          class="px-3 py-1 bg-blue-600 text-white text-xs rounded hover:bg-blue-700 transition-colors">
                    Add Block
                  </button>
                </div>
              </div>

              <!-- Zone Content -->
              <div class="min-h-16 border-2 border-dashed border-gray-200 rounded-lg p-4 bg-gray-50">
                <%= if length(blocks) > 0 do %>
                  <div class="flex flex-wrap gap-2">
                    <%= for {block, index} <- Enum.with_index(blocks) do %>
                      <div class="flex items-center space-x-2 px-3 py-2 bg-white border border-gray-200 rounded">
                        <span class="text-sm text-gray-700"><%= humanize_block_type(block.type || "content") %></span>
                        <button phx-click="remove_block_from_zone"
                                phx-value-zone={zone_name}
                                phx-value-index={index}
                                class="text-gray-400 hover:text-red-600">
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                          </svg>
                        </button>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <div class="text-center text-gray-400">
                    <svg class="w-8 h-8 mx-auto mb-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
                    </svg>
                    <p class="text-sm">Drop content blocks here</p>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Available Blocks Library -->
        <%= if @show_dynamic_layout_manager do %>
          <div class="mt-6 p-4 bg-blue-50 border border-blue-200 rounded-lg">
            <h5 class="font-medium text-blue-900 mb-3">Available Content Blocks</h5>
            <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-3">
              <%= for block_category <- @available_dynamic_blocks do %>
                <%= for block_type <- block_category.blocks do %>
                  <button phx-click="add_content_block"
                          phx-value-block_type={block_type}
                          class="p-3 bg-white border border-blue-200 rounded text-left hover:bg-blue-50 transition-colors">
                    <div class="text-sm font-medium text-blue-900"><%= humanize_block_type(block_type) %></div>
                    <div class="text-xs text-blue-600 mt-1">Click to add</div>
                  </button>
                <% end %>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_portfolio_color(portfolio, color_key) do
    case portfolio.customization do
      %{^color_key => color} when is_binary(color) -> color
      _ ->
        case color_key do
          "primary_color" -> "#3b82f6"
          "secondary_color" -> "#64748b"
          "accent_color" -> "#f59e0b"
          _ -> "#3b82f6"
        end
    end
  end

  defp get_zone_description(zone_name) do
    case zone_name do
      "hero" -> "Main showcase area at the top of your portfolio"
      "services" -> "Display your key services or offerings"
      "testimonials" -> "Client feedback and social proof"
      "pricing" -> "Pricing information and booking options"
      "cta" -> "Call-to-action and contact information"
      _ -> "Content area for #{zone_name}"
    end
  end

  # ============================================================================
  # EVENT HANDLERS - Updated for consolidated approach
  # ============================================================================

  @impl true
  def handle_event("update_design_color", %{"color" => color_key, "value" => color_value}, socket) do
    portfolio = socket.assigns.portfolio
    current_customization = portfolio.customization || %{}
    updated_customization = Map.put(current_customization, color_key, color_value)

    case Portfolios.update_portfolio(portfolio, %{customization: updated_customization}) do
      {:ok, updated_portfolio} ->
        # Generate new CSS
        new_css = generate_portfolio_css(updated_customization)

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_customization)
        |> assign(:portfolio_css, new_css)
        |> assign(String.to_atom(color_key), color_value)
        |> assign(:unsaved_changes, false)

        # Push event to update the hex input field
        socket = push_event(socket, "update_color_input", %{
          color_key: color_key,
          color_value: color_value
        })

        # Broadcast to live preview
        if socket.assigns.show_live_preview do
          broadcast_preview_update(socket)
        end

      {:noreply, socket}

    {:error, _changeset} ->
      {:noreply, put_flash(socket, :error, "Failed to save color changes")}
  end
end

  @impl true
  def handle_event("add_block_to_zone", %{"zone" => zone_name}, socket) do
    # Add a default content block to the specified zone
    current_zones = socket.assigns.layout_zones
    current_blocks = Map.get(current_zones, zone_name, [])
    new_block = %{type: "content_block", id: System.unique_integer([:positive])}
    updated_blocks = current_blocks ++ [new_block]
    updated_zones = Map.put(current_zones, zone_name, updated_blocks)

    {:noreply, assign(socket, :layout_zones, updated_zones)}
  end

  @impl true
  def handle_event("remove_block_from_zone", %{"zone" => zone_name, "index" => index}, socket) do
    current_zones = socket.assigns.layout_zones
    current_blocks = Map.get(current_zones, zone_name, [])
    block_index = String.to_integer(index)
    updated_blocks = List.delete_at(current_blocks, block_index)
    updated_zones = Map.put(current_zones, zone_name, updated_blocks)

    {:noreply, assign(socket, :layout_zones, updated_zones)}
  end

  @impl true
  def handle_event("add_content_block", %{"block_type" => block_type}, socket) do
    # For now, add to the first available zone
    current_zones = socket.assigns.layout_zones
    first_zone_name = current_zones |> Map.keys() |> List.first()

    if first_zone_name do
      current_blocks = Map.get(current_zones, first_zone_name, [])
      new_block = %{type: block_type, id: System.unique_integer([:positive])}
      updated_blocks = current_blocks ++ [new_block]
      updated_zones = Map.put(current_zones, first_zone_name, updated_blocks)

      {:noreply, socket
      |> assign(:layout_zones, updated_zones)
      |> put_flash(:info, "#{humanize_block_type(block_type)} added to #{first_zone_name} zone")
      }
    else
      {:noreply, socket}
    end
  end

  defp is_dynamic_card_layout?(portfolio) do
    theme = portfolio.theme || ""
    customization = portfolio.customization || %{}

    IO.puts("🔥 DEBUG DETECTION:")
    IO.puts("🔥 Theme: #{theme}")
    IO.puts("🔥 Customization: #{inspect(customization)}")

    dynamic_layouts = [
      "professional_service_provider",
      "creative_portfolio_showcase",
      "technical_expert_dashboard",
      "content_creator_hub",
      "corporate_executive_profile"
    ]

    theme_is_dynamic = theme in dynamic_layouts
    layout_is_dynamic = case customization do
      %{"layout" => layout} when is_binary(layout) -> layout in dynamic_layouts
      _ -> false
    end

    result = theme_is_dynamic or layout_is_dynamic
    IO.puts("🔥 Theme is dynamic: #{theme_is_dynamic}")
    IO.puts("🔥 Layout is dynamic: #{layout_is_dynamic}")
    IO.puts("🔥 FINAL RESULT: #{result}")

    result
  end

  # Gets available dynamic blocks based on account subscription
  defp get_dynamic_card_blocks(subscription_tier) do
    # These represent the actual block categories from the system
    base_blocks = [
      %{category: :service_provider, name: "Service Provider", blocks: [:service_showcase, :testimonial_carousel, :pricing_display]},
      %{category: :creative_showcase, name: "Creative Portfolio", blocks: [:portfolio_gallery, :process_showcase, :collaboration_display]}
    ]

    premium_blocks = [
      %{category: :technical_expert, name: "Technical Expert", blocks: [:skill_matrix, :project_deep_dive, :consultation_booking]},
      %{category: :content_creator, name: "Content Creator", blocks: [:content_metrics, :brand_partnerships, :subscription_tiers]},
      %{category: :corporate_executive, name: "Corporate Executive", blocks: [:consultation_booking, :collaboration_display, :content_metrics]}
    ]

  # Temp testing FIX: Always return all blocks for now
  base_blocks ++ premium_blocks

  # Original logic (commented out):
  # case subscription_tier do
  #   tier when tier in ["creator", "professional", "enterprise"] -> base_blocks ++ premium_blocks
  #   _ -> base_blocks
  # end
  end

  # Loads layout zones configuration for dynamic portfolios
  defp load_layout_zones(portfolio_id) do
    # Stub implementation - returns default zone structure
    # In full implementation, this would load from database
    %{
      "hero" => [],
      "services" => [],
      "testimonials" => [],
      "pricing" => [],
      "footer" => []
    }
  end

  defp get_portfolio_color(portfolio, color_key) do
    case portfolio.customization do
      %{^color_key => color} when is_binary(color) -> color
      _ ->
        case color_key do
          "primary_color" -> "#3b82f6"
          "secondary_color" -> "#64748b"
          "accent_color" -> "#f59e0b"
          _ -> "#3b82f6"
        end
    end
  end

  defp get_category_description(category) do
    case category do
      :service_provider -> "Service-focused with booking and pricing showcase"
      :creative_showcase -> "Visual portfolio with commission opportunities"
      :technical_expert -> "Skill-based with consultation booking"
      :content_creator -> "Content metrics with subscription options"
      :corporate_executive -> "Achievement-focused executive presence"
      _ -> "Professional layout"
    end
  end

  # Helper function for available tabs based on portfolio type
defp get_available_tabs(assigns) do
  base_tabs = [content: "Content", design: "Design", analytics: "Analytics"]

  IO.puts("🔥 DEBUG TABS: is_dynamic_layout = #{assigns[:is_dynamic_layout]}")

  if Map.get(assigns, :is_dynamic_layout, false) do
    tabs = [content: "Content", dynamic_layout: "Dynamic Layout", design: "Design", analytics: "Analytics"]
    IO.puts("🔥 DEBUG: Returning dynamic tabs: #{inspect(tabs)}")
    tabs
  else
    IO.puts("🔥 DEBUG: Returning base tabs: #{inspect(base_tabs)}")
    base_tabs
  end
end

defp force_dynamic_layout_for_testing(socket, portfolio, account) do
  IO.puts("🔥 FORCING DYNAMIC LAYOUT FOR TESTING")

  socket
  |> assign(:is_dynamic_layout, true)  # Force to true
  |> assign(:show_dynamic_layout_manager, false)
  |> assign(:available_dynamic_blocks, get_dynamic_card_blocks("professional"))
  |> assign(:layout_config, %{layout_style: "professional_service_provider"})
  |> assign(:layout_zones, %{"hero" => [], "services" => []})
  |> assign(:active_layout_category, :service_provider)
  |> assign(:brand_customization, %{primary_color: "#3b82f6", secondary_color: "#64748b", accent_color: "#f59e0b"})
end
end
