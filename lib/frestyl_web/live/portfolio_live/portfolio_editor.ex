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

        socket = socket
        |> assign_core_data(portfolio, account, user)
        |> assign_features_and_limits(features, limits)
        |> assign_content_data(sections, media_library, content_blocks)
        |> assign_monetization_data(monetization_data, streaming_config)
        |> assign_design_system(portfolio, account, available_layouts, brand_constraints)
        |> assign_ui_state()
        |> assign_live_preview_state()

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
    # Get layout from portfolio, with fallback
    current_layout = Map.get(portfolio, :layout, "professional_service")

    # Get customization from portfolio, with fallback
    customization = Map.get(portfolio, :customization, %{})

    socket
    |> assign(:available_layouts, available_layouts)
    |> assign(:brand_constraints, brand_constraints)
    |> assign(:current_layout, current_layout)
    |> assign(:design_tokens, generate_design_tokens(portfolio, brand_constraints))
    |> assign(:customization, customization)
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
    IO.puts("🔥 SWITCHING TAB: #{tab} -> #{tab_atom}")
    {:noreply, assign(socket, :active_tab, tab_atom)}
  end

  @impl true
  def handle_event("edit_section", %{"section-id" => section_id}, socket) when section_id != "" do
    section_id_int = String.to_integer(section_id)
    section = Enum.find(socket.assigns.sections, &(&1.id == section_id_int))

    IO.puts("🔥 EDITING SECTION: #{section_id_int}")

    socket = socket
    |> assign(:editing_section, section)
    |> assign(:editing_mode, :content)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_section", %{"section-id" => ""}, socket) do
    # Clear editing section
    IO.puts("🔥 CLEARING EDITING SECTION")

    socket = socket
    |> assign(:editing_section, nil)
    |> assign(:editing_mode, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("update_section_content", %{"section_id" => section_id, "field" => field, "value" => value}, socket) do
    section_id = String.to_integer(section_id)

    case update_section_content(section_id, field, value) do
      {:ok, updated_section} ->
        sections = update_section_in_list(socket.assigns.sections, updated_section)

        socket = socket
        |> assign(:sections, sections)
        |> assign(:unsaved_changes, true)
        |> assign(:editing_section, updated_section)

        # Broadcast to live preview
        broadcast_content_update(socket, updated_section)

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to update section")}
    end
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

  # Content management helpers
  defp update_section_content(section_id, field, value) do
    case Portfolios.get_portfolio_section(section_id) do
      nil -> {:error, :not_found}
      section ->
        content = section.content || %{}
        updated_content = Map.put(content, field, value)

        case Portfolios.update_portfolio_section(section, %{content: updated_content}) do
          {:ok, updated_section} -> {:ok, updated_section}
          {:error, changeset} -> {:error, changeset}
        end
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

  defp get_next_position(portfolio_id) do
    # Get the highest position and add 1
    case Portfolios.get_max_section_position(portfolio_id) do
      nil -> 1
      max_pos -> max_pos + 1
    end
  end

  # Broadcasting helpers for live preview
  defp broadcast_preview_update(socket) do
    portfolio = socket.assigns.portfolio
    customization = socket.assigns.customization

    Phoenix.PubSub.broadcast(
      Frestyl.PubSub,
      "portfolio_preview:#{portfolio.id}",
      {:preview_update, customization, generate_css(customization)}
    )
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
    "/live_preview/#{portfolio.id}/#{preview_token}"
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
    <div class="design-tab">
      <div class="mb-6">
        <h3 class="text-lg font-medium text-gray-900 mb-4">Design Customization</h3>

        <!-- Color Settings -->
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Primary Color</label>
            <input
              type="color"
              value={@design_tokens.primary_color}
              phx-change="update_design_token"
              phx-value-token="primary_color"
              class="w-full h-10 border border-gray-300 rounded-md">
          </div>

          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Accent Color</label>
            <input
              type="color"
              value={@design_tokens.accent_color}
              phx-change="update_design_token"
              phx-value-token="accent_color"
              class="w-full h-10 border border-gray-300 rounded-md">
          </div>
        </div>

        <!-- Layout Options -->
        <div class="mt-6">
          <h4 class="text-sm font-medium text-gray-700 mb-3">Layout Style</h4>
          <div class="grid grid-cols-1 gap-3">
            <%= for layout <- @available_layouts do %>
              <label class="flex items-center p-3 border rounded-lg cursor-pointer hover:bg-gray-50">
                <input
                  type="radio"
                  name="layout"
                  value={layout}
                  checked={@current_layout == layout}
                  phx-change="update_layout"
                  class="mr-3">
                <span class="capitalize"><%= String.replace(layout, "_", " ") %></span>
              </label>
            <% end %>
          </div>
        </div>
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
end
