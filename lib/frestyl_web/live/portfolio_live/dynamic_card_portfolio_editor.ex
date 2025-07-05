# lib/frestyl_web/live/portfolio_live/dynamic_card_portfolio_editor.ex
# FIXED VERSION - Extends PortfolioEditor for Dynamic Card Layouts

defmodule FrestylWeb.PortfolioLive.DynamicCardPortfolioEditor do
  @moduledoc """
  Extended Portfolio Editor specifically for Dynamic Card Layouts.
  Integrates with the existing PortfolioEditor framework while adding
  dynamic card layout capabilities with brand control and monetization.
  """

  use FrestylWeb, :live_view

  # Import the base PortfolioEditor framework
  alias FrestylWeb.PortfolioLive.PortfolioEditor
  alias FrestylWeb.PortfolioLive.DynamicCardLayoutManager
  alias Frestyl.Portfolios.ContentBlocks.DynamicCardBlocks
  alias Frestyl.Accounts.BrandSettings

  # ============================================================================
  # MOUNT - Extended from PortfolioEditor
  # ============================================================================

  @impl true
  def mount(%{"id" => portfolio_id}, session, socket) do
    # Delegate to base PortfolioEditor for core initialization
    case PortfolioEditor.mount(%{"id" => portfolio_id}, session, socket) do
      {:ok, base_socket} ->
        # Extend with dynamic card layout capabilities
        account = base_socket.assigns.account
        portfolio = base_socket.assigns.portfolio

        # Enhanced socket with dynamic card capabilities
        enhanced_socket = base_socket
        |> enhance_with_dynamic_card_capabilities(account, portfolio)
        |> assign_dynamic_layout_state()

        {:ok, enhanced_socket}

      error -> error
    end
  end

  # ============================================================================
  # DYNAMIC CARD LAYOUT ENHANCEMENT
  # ============================================================================

  defp enhance_with_dynamic_card_capabilities(socket, account, portfolio) do
    # Load brand settings
    brand_settings = get_or_create_brand_settings(account)

    # Determine if this is a dynamic card layout portfolio
    is_dynamic_layout = is_dynamic_card_layout?(portfolio)

    # Get available dynamic card blocks based on subscription
    available_dynamic_blocks = DynamicCardBlocks.get_blocks_by_monetization_tier(account.subscription_tier)

    # Load dynamic layout zones if applicable
    layout_zones = if is_dynamic_layout do
      load_dynamic_layout_zones(portfolio.id)
    else
      %{}
    end

    # Calculate layout metrics
    layout_metrics = calculate_layout_performance_metrics(portfolio.id)

    socket
    |> assign(:is_dynamic_layout, is_dynamic_layout)
    |> assign(:brand_settings, brand_settings)
    |> assign(:available_dynamic_blocks, available_dynamic_blocks)
    |> assign(:layout_zones, layout_zones)
    |> assign(:layout_metrics, layout_metrics)
  end

  defp assign_dynamic_layout_state(socket) do
    socket
    |> assign(:active_layout_zone, nil)
    |> assign(:show_dynamic_layout_manager, socket.assigns.is_dynamic_layout)
    |> assign(:show_brand_settings_editor, false)
    |> assign(:layout_preview_mode, false)
    |> assign(:active_category, :professional)
    |> assign(:preview_device, :desktop)
    |> assign(:content_block_count, 0)
  end

  # ============================================================================
  # DYNAMIC CARD SPECIFIC EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("toggle_layout_mode", %{"mode" => "dynamic"}, socket) do
    {:noreply, assign(socket, :show_dynamic_layout_manager, true)}
  end

  @impl true
  def handle_event("toggle_layout_mode", %{"mode" => "traditional"}, socket) do
    {:noreply, assign(socket, :show_dynamic_layout_manager, false)}
  end

  @impl true
  def handle_event("toggle_brand_settings", _params, socket) do
    show_settings = !socket.assigns.show_brand_settings_editor
    {:noreply, assign(socket, :show_brand_settings_editor, show_settings)}
  end

  @impl true
  def handle_event("toggle_preview_mode", _params, socket) do
    preview_mode = !socket.assigns.layout_preview_mode
    {:noreply, assign(socket, :layout_preview_mode, preview_mode)}
  end

  @impl true
  def handle_event("switch_device_preview", %{"device" => device}, socket) do
    {:noreply, assign(socket, :preview_device, String.to_atom(device))}
  end

  @impl true
  def handle_event("add_dynamic_block", %{"block_type" => block_type, "zone" => zone}, socket) do
    case create_dynamic_card_block(block_type, zone, socket) do
      {:ok, new_block} ->
        # Add to layout zones
        layout_zones = add_block_to_layout_zone(socket.assigns.layout_zones, zone, new_block)

        # Update content blocks cache
        content_blocks = add_block_to_content_cache(socket.assigns.content_blocks, new_block)

        socket = socket
        |> assign(:layout_zones, layout_zones)
        |> assign(:content_blocks, content_blocks)
        |> assign(:content_block_count, socket.assigns.content_block_count + 1)
        |> assign(:unsaved_changes, true)

        # Broadcast to live preview
        broadcast_dynamic_layout_update(socket)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to add block: #{reason}")}
    end
  end

  @impl true
  def handle_event("remove_dynamic_block", %{"block_id" => block_id, "zone" => zone}, socket) do
    # Remove from layout zones
    layout_zones = remove_block_from_layout_zone(socket.assigns.layout_zones, zone, block_id)

    # Remove from content blocks cache
    content_blocks = remove_block_from_content_cache(socket.assigns.content_blocks, block_id)

    socket = socket
    |> assign(:layout_zones, layout_zones)
    |> assign(:content_blocks, content_blocks)
    |> assign(:unsaved_changes, true)

    # Broadcast to live preview
    broadcast_dynamic_layout_update(socket)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_brand_settings", %{"brand" => brand_params}, socket) do
    case update_brand_settings(socket.assigns.account, brand_params) do
      {:ok, updated_brand_settings} ->
        socket = socket
        |> assign(:brand_settings, updated_brand_settings)
        |> assign(:unsaved_changes, true)

        # Regenerate design tokens
        design_tokens = generate_design_tokens_with_brand(socket.assigns.portfolio, updated_brand_settings)
        socket = assign(socket, :design_tokens, design_tokens)

        # Broadcast brand update
        broadcast_brand_update(socket, updated_brand_settings)

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update brand settings")}
    end
  end

  @impl true
  def handle_event("reorder_blocks", %{"zone" => zone, "block_ids" => block_ids}, socket) do
    layout_zones = reorder_blocks_in_zone(socket.assigns.layout_zones, zone, block_ids)

    socket = socket
    |> assign(:layout_zones, layout_zones)
    |> assign(:unsaved_changes, true)

    broadcast_dynamic_layout_update(socket)

    {:noreply, socket}
  end

  # ============================================================================
  # DYNAMIC CARD HELPER FUNCTIONS
  # ============================================================================

  defp get_or_create_brand_settings(account) do
    case BrandSettings.get_brand_settings(account.id) do
      nil -> BrandSettings.create_default_brand_settings(account.id)
      brand_settings -> brand_settings
    end
  end

  defp is_dynamic_card_layout?(portfolio) do
    portfolio.layout in ["dynamic_card", "professional_cards", "creative_cards"] ||
    Map.get(portfolio.customization || %{}, "use_dynamic_cards", false)
  end

  defp load_dynamic_layout_zones(portfolio_id) do
    # Load existing dynamic card layout zones
    %{
      hero: [],
      main_content: [],
      sidebar: [],
      footer: []
    }
  end

  defp calculate_layout_performance_metrics(_portfolio_id) do
    %{
      total_views: 0,
      conversion_rate: 0.0,
      avg_time_on_page: 0,
      bounce_rate: 0.0
    }
  end

  defp create_dynamic_card_block(block_type, zone, socket) do
    block_config = DynamicCardBlocks.get_block_config(String.to_atom(block_type))

    if block_config do
      {:ok, %{
        id: System.unique_integer([:positive]),
        block_type: String.to_atom(block_type),
        content_data: block_config.default_content,
        zone: zone,
        position: get_next_block_position_in_zone(socket, zone),
        created_at: DateTime.utc_now()
      }}
    else
      {:error, "Unknown block type: #{block_type}"}
    end
  end

  defp add_block_to_layout_zone(layout_zones, zone, new_block) do
    zone_atom = String.to_atom(zone)
    current_blocks = Map.get(layout_zones, zone_atom, [])
    Map.put(layout_zones, zone_atom, current_blocks ++ [new_block])
  end

  defp remove_block_from_layout_zone(layout_zones, zone, block_id) do
    zone_atom = String.to_atom(zone)
    block_id_int = if is_binary(block_id), do: String.to_integer(block_id), else: block_id

    current_blocks = Map.get(layout_zones, zone_atom, [])
    updated_blocks = Enum.reject(current_blocks, &(&1.id == block_id_int))

    Map.put(layout_zones, zone_atom, updated_blocks)
  end

  defp add_block_to_content_cache(content_blocks, new_block) do
    Map.update(content_blocks, :dynamic_cards, [new_block], fn existing ->
      [new_block | existing]
    end)
  end

  defp remove_block_from_content_cache(content_blocks, block_id) do
    block_id_int = if is_binary(block_id), do: String.to_integer(block_id), else: block_id

    Map.update(content_blocks, :dynamic_cards, [], fn existing ->
      Enum.reject(existing, &(&1.id == block_id_int))
    end)
  end

  defp reorder_blocks_in_zone(layout_zones, zone, block_ids) do
    zone_atom = String.to_atom(zone)
    current_blocks = Map.get(layout_zones, zone_atom, [])

    # Reorder blocks according to the new order
    reordered_blocks = Enum.map(block_ids, fn block_id ->
      block_id_int = if is_binary(block_id), do: String.to_integer(block_id), else: block_id
      Enum.find(current_blocks, &(&1.id == block_id_int))
    end)
    |> Enum.reject(&is_nil/1)

    Map.put(layout_zones, zone_atom, reordered_blocks)
  end

  defp get_next_block_position_in_zone(socket, zone) do
    zone_atom = String.to_atom(zone)
    current_blocks = Map.get(socket.assigns.layout_zones, zone_atom, [])
    length(current_blocks) + 1
  end

  defp update_brand_settings(account, brand_params) do
    case BrandSettings.get_brand_settings(account.id) do
      nil ->
        BrandSettings.create_brand_settings(account.id, brand_params)
      brand_settings ->
        BrandSettings.update_brand_settings(brand_settings, brand_params)
    end
  end

  defp generate_design_tokens_with_brand(portfolio, brand_settings) do
    base_tokens = generate_design_tokens(portfolio, %{})

    Map.merge(base_tokens, %{
      brand_primary: brand_settings.primary_color,
      brand_secondary: brand_settings.secondary_color,
      brand_accent: brand_settings.accent_color,
      brand_font: brand_settings.primary_font
    })
  end

  # Broadcasting helpers for dynamic cards
  defp broadcast_dynamic_layout_update(socket) do
    portfolio = socket.assigns.portfolio
    layout_zones = socket.assigns.layout_zones

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:dynamic_layout_update, layout_zones}
    )
  end

  defp broadcast_brand_update(socket, brand_settings) do
    portfolio = socket.assigns.portfolio

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:brand_update, brand_settings}
    )
  end

  # Delegate other events to PortfolioEditor
  defdelegate handle_event(event, params, socket), to: PortfolioEditor

  # Helper function to generate design tokens (imported from PortfolioEditor)
  defp generate_design_tokens(portfolio, brand_constraints) do
    customization = portfolio.customization || %{}

    %{
      primary_color: Map.get(customization, "primary_color", "#1e40af"),
      accent_color: Map.get(customization, "accent_color", "#f59e0b"),
      font_family: Map.get(customization, "font_family", "Inter")
    }
  end
end
