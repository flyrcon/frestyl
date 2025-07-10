# lib/frestyl_web/live/portfolio_live/show.ex
# FIXED VERSION - Renders portfolios with dynamic card layout support

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view
  import Phoenix.LiveView.Helpers
  import Phoenix.Controller, only: [get_csrf_token: 0]

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.DynamicCardCssManager

  alias FrestylWeb.PortfolioLive.{DynamicCardLayoutManager, DynamicCardPublicRenderer}
  alias Frestyl.ResumeExporter


  @impl true
  def mount(params, _session, socket) do
    case params do
      # Public view via slug
      %{"slug" => slug} ->
        mount_public_portfolio(slug, socket)

      # Shared view via token
      %{"token" => token} ->
        mount_shared_portfolio(token, socket)

      # Preview for editor
      %{"id" => id, "preview_token" => token} ->
        mount_preview_portfolio(id, token, socket)

      # Authenticated view by ID
      %{"id" => id} ->
        mount_authenticated_portfolio(id, socket)

      _ ->
        {:ok, socket |> put_flash(:error, "Invalid portfolio") |> redirect(to: "/")}
    end
  end

  defp mount_portfolio(portfolio, socket, view_type) do
    # Subscribe to live updates from editor
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
    end

    # Track portfolio visit
    track_portfolio_visit_safe(portfolio, socket)

    socket = socket
    |> assign_portfolio_data(portfolio)
    |> assign_dynamic_card_layout_data(portfolio)  # NEW: Use Dynamic Card engine
    |> assign_view_context(view_type)              # NEW: Track view context
    |> assign_ui_state()
    |> enhance_portfolio_for_public_view()         # NEW: Add Dynamic Card Layout integration
    |> assign(:customization_css, "")
    |> assign(:custom_css, portfolio.custom_css || "")
    |> assign_dynamic_layout_data()
    |> assign_seo_data(portfolio)
    |> assign(:view_type, view_type)
    # NEW: Add modal states for the missing functions
    |> assign(:show_export_modal, false)
    |> assign(:show_share_modal, false)
    |> assign(:show_contact_modal, false)
    |> assign(:show_lightbox, false)
    |> assign(:lightbox_media, nil)

    {:ok, socket}
  end
  defp mount_public_portfolio(slug, socket) do
    case load_portfolio_by_slug(slug) do
      {:ok, portfolio} ->
        mount_portfolio(portfolio, socket, :public)
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  defp mount_authenticated_portfolio(id, socket) do
    user = socket.assigns.current_user
    case load_portfolio_by_id(id) do
      {:ok, portfolio} ->
        if can_view_portfolio?(portfolio, user) do
          mount_portfolio(portfolio, socket, :authenticated)
        else
          {:ok, socket |> put_flash(:error, "Access denied") |> redirect(to: "/portfolios")}
        end
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/portfolios")}
    end
  end

  defp mount_shared_portfolio(token, socket) do
    case load_portfolio_by_share_token(token) do
      {:ok, portfolio} ->
        mount_portfolio(portfolio, socket, :shared)
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Invalid share link") |> redirect(to: "/")}
    end
  end

  defp mount_preview_portfolio(id, preview_token, socket) do
    case load_portfolio_by_id(id) do
      {:ok, portfolio} ->
        if verify_preview_token(portfolio.id, preview_token) do
          mount_portfolio(portfolio, socket, :preview)
        else
          {:ok, socket |> put_flash(:error, "Invalid preview link") |> redirect(to: "/")}
        end
      {:error, :not_found} ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  defp enhance_portfolio_for_public_view(socket) do
    portfolio = socket.assigns.portfolio

    # Get or load sections if not already loaded
    sections = case Map.get(socket.assigns, :sections, []) do
      [] -> load_portfolio_sections(portfolio.id)
      sections when is_list(sections) -> sections
      _ -> []
    end

    # Convert sections to content blocks (same as editor)
    content_blocks = convert_sections_to_content_blocks(sections)

    # Get brand settings
    brand_settings = get_portfolio_brand_settings(portfolio)

    # Generate CSS for public view
    customization = portfolio.customization || %{}
    dynamic_card_css = try do
      FrestylWeb.PortfolioLive.DynamicCardCssManager.generate_portfolio_css(
        portfolio,
        brand_settings,
        customization
      )
    rescue
      _ ->
        # Fallback CSS if DynamicCardCssManager is not available
        generate_fallback_css(customization, brand_settings)
    end

    # Create layout zones
    layout_zones = organize_content_into_layout_zones(content_blocks, portfolio)

    socket
    |> assign(:sections, sections)
    |> assign(:content_blocks, content_blocks)
    |> assign(:brand_settings, brand_settings)
    |> assign(:layout_zones, layout_zones)
    |> assign(:customization_css, dynamic_card_css)
  end

  defp generate_fallback_css(customization, brand_settings) do
    primary = Map.get(brand_settings, :primary_color) || "#3b82f6"
    secondary = Map.get(brand_settings, :secondary_color) || "#64748b"
    accent = Map.get(brand_settings, :accent_color) || "#f59e0b"
    background = Map.get(customization, "background_color") || "#ffffff"
    text = Map.get(customization, "text_color") || "#1f2937"

    """
    :root {
      --primary-color: #{primary};
      --secondary-color: #{secondary};
      --accent-color: #{accent};
      --background-color: #{background};
      --text-color: #{text};
    }

    body {
      font-family: system-ui, sans-serif;
      color: var(--text-color);
      background-color: var(--background-color);
    }

    .portfolio-public-view {
      min-height: 100vh;
    }
    """
  end

  defp get_portfolio_layout(portfolio) do
    case portfolio.customization do
      %{"layout" => layout} when is_binary(layout) -> layout
      _ -> portfolio.theme || "dynamic_card_layout"
    end
  end

  defp assign_dynamic_layout_data(socket) do
    portfolio = socket.assigns.portfolio
    sections = socket.assigns.sections

    use_dynamic = should_use_dynamic_card_layout?(portfolio)

    if use_dynamic do
      content_blocks = convert_sections_to_content_blocks(sections)
      layout_zones = organize_content_into_layout_zones(content_blocks, portfolio)

      socket
      |> assign(:use_dynamic_layout, true)
      |> assign(:content_blocks, content_blocks)
      |> assign(:layout_zones, layout_zones)
    else
      socket
      |> assign(:use_dynamic_layout, false)
      |> assign(:content_blocks, [])
      |> assign(:layout_zones, %{})
    end
  end

  defp assign_dynamic_card_layout_data(socket, portfolio) do
    # Get the portfolio's account for brand settings
    account = get_portfolio_account(portfolio)

    socket
    |> assign(:account, account)
    |> assign(:portfolio, portfolio)
  end

  defp get_portfolio_account(portfolio) do
    case portfolio do
      %{account: %{} = account} -> account
      %{user: %{accounts: [account | _]}} -> account
      %{user: %{} = user} ->
        # Load account from user
        case Frestyl.Accounts.list_user_accounts(user.id) do
          [account | _] -> account
          [] -> create_default_account_for_user(user)
        end
      _ ->
        # Create a default account structure
        %{
          id: nil,
          subscription_tier: "personal",
          features: %{}
        }
    end
  rescue
    _ ->
      %{
        id: nil,
        subscription_tier: "personal",
        features: %{}
      }
  end

  defp default_brand_settings do
    %{
      primary_color: "#3b82f6",
      secondary_color: "#64748b",
      accent_color: "#f59e0b",
      font_family: "system-ui, sans-serif",
      logo_url: nil
    }
  end

  defp portfolio_owned_by?(portfolio, user) do
    portfolio.user_id == user.id
  end

  defp create_default_account_for_user(user) do
    case Frestyl.Accounts.create_account_for_user(user.id) do
      {:ok, account} -> account
      _ -> %{id: nil, subscription_tier: "personal", features: %{}}
    end
  rescue
    _ -> %{id: nil, subscription_tier: "personal", features: %{}}
  end

  defp load_portfolio_sections(portfolio_id) do
    try do
      Frestyl.Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
  end


  # ADD THESE HELPER FUNCTIONS:
  defp can_view_portfolio?(portfolio, user) do
    # Add your authorization logic here
    portfolio.user_id == user.id || portfolio.visibility == :public
  end

  defp can_edit_portfolio?(portfolio, user) do
    portfolio.user_id == user.id
  end


  defp verify_preview_token(portfolio_id, token) do
    expected_token = :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
                    |> Base.encode16(case: :lower)
    token == expected_token
  end

    # ============================================================================
  # EVENT HANDLERS
  # ============================================================================

  @impl true
  def handle_event("export_portfolio", %{"format" => format}, socket) do
    portfolio = socket.assigns.portfolio

    case ResumeExporter.export_portfolio(portfolio, String.to_atom(format)) do
      {:ok, file_info} ->
        download_url = generate_download_url(file_info)
        {:noreply, push_event(socket, "download_file", %{url: download_url})}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Export failed: #{reason}")}
    end
  end

  @impl true
  def handle_event("share_portfolio", %{"platform" => platform}, socket) do
    portfolio = socket.assigns.portfolio
    share_url = generate_share_url(portfolio, platform)

    {:noreply, push_event(socket, "open_share_window", %{url: share_url, platform: platform})}
  end

  @impl true
  def handle_event("toggle_mobile_nav", _params, socket) do
    {:noreply, assign(socket, :mobile_nav_open, !socket.assigns.mobile_nav_open)}
  end

  @impl true
  def handle_event("open_lightbox", %{"media_id" => media_id}, socket) do
    # Find media in portfolio
    media = find_portfolio_media(socket.assigns.portfolio, media_id)
    {:noreply, assign(socket, :active_lightbox_media, media)}
  end

  @impl true
  def handle_event("close_lightbox", _params, socket) do
    {:noreply, assign(socket, :active_lightbox_media, nil)}
  end

  @impl true
  def handle_event("contact_owner", params, socket) do
    # Handle contact form submission
    case send_portfolio_contact_message(socket.assigns.portfolio, params) do
      {:ok, _} ->
        {:noreply, socket
         |> put_flash(:info, "Message sent successfully!")
         |> assign(:show_contact_modal, false)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to send message: #{reason}")}
    end
  end

  # Handle live updates from editor
  @impl true
  def handle_info({:portfolio_updated, updated_portfolio}, socket) do
    if updated_portfolio.id == socket.assigns.portfolio.id do
      socket = socket
      |> assign(:portfolio, updated_portfolio)
      |> assign_dynamic_layout_system(updated_portfolio)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end


  # ============================================================================
  # LIVE UPDATE HANDLERS (from editor)
  # ============================================================================

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

    socket = socket
    |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)
    |> push_event("update_portfolio_styles", %{css: css})  # Add this line

    {:noreply, socket}
  end

  @impl true
  def handle_info({:customization_updated, customization}, socket) do
    # Generate new CSS with updated customization
    css = generate_portfolio_css(customization)

    socket = socket
    |> assign(:customization, customization)
    |> assign(:portfolio_css, css)
    |> push_event("update_portfolio_styles", %{css: css})  # Add this line

    {:noreply, socket}
  end

  # Catch-all for unhandled messages
  @impl true
  def handle_info(msg, socket) do
    IO.puts("🔥 Show received unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:content_update, section}, socket) do
    sections = update_section_in_list(socket.assigns.sections, section)

    socket = socket
    |> assign(:sections, sections)
    |> push_event("update_section_content", %{
      section_id: section.id,
      content: section.content
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:sections_update, sections}, socket) do
    socket = assign(socket, :sections, sections)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:dynamic_layout_update, layout_zones}, socket) do
    socket = socket
    |> assign(:layout_zones, layout_zones)
    |> assign(:is_dynamic_layout, true)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:brand_update, brand_settings}, socket) do
    # Regenerate design tokens with new brand settings
    design_tokens = generate_design_tokens_with_brand(socket.assigns.portfolio, brand_settings)
    custom_css = generate_brand_css(brand_settings)

    socket = socket
    |> assign(:brand_settings, brand_settings)
    |> assign(:design_tokens, design_tokens)
    |> assign(:custom_css, custom_css)
    |> push_event("update_styles", %{css: custom_css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:viewport_change, mobile_view}, socket) do
    socket = assign(socket, :mobile_view, mobile_view)
    {:noreply, socket}
  end

  # ============================================================================
  # RENDERING LOGIC
  # ============================================================================

  @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="scroll-smooth">
      <head>
        <%= render_seo_meta(assigns) %>
        <style><%= @custom_css %></style>
        <script phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      </head>

      <body class="portfolio-public-view bg-gray-50">
        <!-- Portfolio Content -->
        <div class="portfolio-container min-h-screen">
          <%= if @is_dynamic_layout do %>
            <.live_component
              module={FrestylWeb.PortfolioLive.Components.DynamicCardLayoutManager}
              id={"public-renderer-#{@portfolio.id}"}
              portfolio={@portfolio}
              sections={@sections}
              layout_type={@layout_type}
              show_edit_controls={false}
            />
          <% else %>
            <%= render_traditional_public_view(assigns) %>
          <% end %>
        </div>

        <!-- Floating Action Buttons -->
        <%= render_floating_actions(assigns) %>

        <!-- Modals -->
        <%= if @show_export_modal do %>
          <%= render_export_modal(assigns) %>
        <% end %>

        <%= if @show_share_modal do %>
          <%= render_share_modal(assigns) %>
        <% end %>

        <%= if @show_contact_modal do %>
          <%= render_contact_modal(assigns) %>
        <% end %>

        <!-- Lightbox -->
        <%= if @active_lightbox_media do %>
          <%= render_lightbox(assigns) %>
        <% end %>

        <!-- Flash Messages -->
        <div id="flash-messages" class="fixed top-4 left-1/2 transform -translate-x-1/2 z-50">
          <%= if live_flash(@flash, :info) do %>
            <div class="bg-green-500 text-white px-6 py-3 rounded-lg shadow-lg mb-2">
              <%= live_flash(@flash, :info) %>
            </div>
          <% end %>

          <%= if live_flash(@flash, :error) do %>
            <div class="bg-red-500 text-white px-6 py-3 rounded-lg shadow-lg mb-2">
              <%= live_flash(@flash, :error) %>
            </div>
          <% end %>
        </div>
      </body>
    </html>
    """
  end

  # ============================================================================
  # RENDER HELPERS
  # ============================================================================

  defp render_seo_meta(assigns) do
    ~H"""
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="csrf-token" content={get_csrf_token()} />

    <!-- SEO Meta Tags -->
    <title><%= @seo_title %></title>
    <meta name="description" content={@seo_description} />
    <link rel="canonical" href={@canonical_url} />

    <!-- Open Graph Meta Tags -->
    <meta property="og:title" content={@seo_title} />
    <meta property="og:description" content={@seo_description} />
    <meta property="og:image" content={@seo_image} />
    <meta property="og:url" content={@canonical_url} />
    <meta property="og:type" content="profile" />

    <!-- Twitter Card Meta Tags -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={@seo_title} />
    <meta name="twitter:description" content={@seo_description} />
    <meta name="twitter:image" content={@seo_image} />

    <!-- JSON-LD Structured Data -->
    <script type="application/ld+json">
      <%= raw(generate_json_ld(@portfolio)) %>
    </script>
    """
  end

  defp render_floating_actions(assigns) do
    ~H"""
    <div class="fixed bottom-6 right-6 z-40 space-y-3">
      <!-- Back to Top -->
      <%= if @public_view_settings.enable_back_to_top do %>
        <button onclick="window.scrollTo({top: 0, behavior: 'smooth'})"
                class="w-12 h-12 bg-white shadow-lg rounded-full flex items-center justify-center hover:bg-gray-50 transition-all duration-200">
          <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
          </svg>
        </button>
      <% end %>

      <!-- More Actions Menu -->
      <div class="relative">
        <button class="w-12 h-12 bg-blue-600 text-white shadow-lg rounded-full flex items-center justify-center hover:bg-blue-700 transition-all duration-200"
                phx-click="toggle_actions_menu">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
          </svg>
        </button>
      </div>
    </div>
    """
  end

  defp render_traditional_public_view(assigns) do
    ~H"""
    <div class="traditional-portfolio-view max-w-4xl mx-auto py-8 px-4">
      <!-- Portfolio Header -->
      <header class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <%= if @portfolio.description do %>
          <p class="text-xl text-gray-600 max-w-2xl mx-auto"><%= @portfolio.description %></p>
        <% end %>
      </header>

      <!-- Portfolio Sections -->
      <div class="space-y-8">
        <%= for section <- @sections do %>
          <section class="bg-white rounded-lg shadow-md p-6">
            <h2 class="text-2xl font-semibold text-gray-900 mb-4"><%= section.title %></h2>
            <div class="prose max-w-none">
              <%= render_section_content_safe(section) %>
            </div>
          </section>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_export_modal(assigns) do
    ~H"""
    <%= if @show_export_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          phx-click="hide_export_modal">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
            phx-click="prevent_close">
          <div class="p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Export Portfolio</h3>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Export Format</label>
                <select class="w-full border border-gray-300 rounded-lg px-3 py-2">
                  <option value="pdf">PDF Resume</option>
                  <option value="json">JSON Data</option>
                </select>
              </div>

              <div class="flex justify-end space-x-3">
                <button phx-click="hide_export_modal"
                        class="px-4 py-2 text-gray-600 hover:text-gray-800">
                  Cancel
                </button>
                <button phx-click="export_portfolio"
                        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                  Export
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_share_modal(assigns) do
    ~H"""
    <%= if @show_share_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          phx-click="hide_share_modal">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
            phx-click="prevent_close">
          <div class="p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Share Portfolio</h3>

            <div class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-2">Public URL</label>
                <div class="flex">
                  <input type="text"
                        value={get_portfolio_public_url(@portfolio)}
                        readonly
                        class="flex-1 border border-gray-300 rounded-l-lg px-3 py-2 bg-gray-50">
                  <button class="px-4 py-2 bg-blue-600 text-white rounded-r-lg hover:bg-blue-700"
                          phx-click="copy_portfolio_url">
                    Copy
                  </button>
                </div>
              </div>

              <div class="flex justify-end space-x-3">
                <button phx-click="hide_share_modal"
                        class="px-4 py-2 text-gray-600 hover:text-gray-800">
                  Close
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_contact_modal(assigns) do
    ~H"""
    <%= if @show_contact_modal do %>
      <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
          phx-click="hide_contact_modal">
        <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
            phx-click="prevent_close">
          <div class="p-6">
            <h3 class="text-lg font-semibold text-gray-900 mb-4">Contact</h3>

            <form phx-submit="send_contact_message" class="space-y-4">
              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Name</label>
                <input type="text" name="name" required
                      class="w-full border border-gray-300 rounded-lg px-3 py-2">
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Email</label>
                <input type="email" name="email" required
                      class="w-full border border-gray-300 rounded-lg px-3 py-2">
              </div>

              <div>
                <label class="block text-sm font-medium text-gray-700 mb-1">Message</label>
                <textarea name="message" rows="4" required
                          class="w-full border border-gray-300 rounded-lg px-3 py-2"></textarea>
              </div>

              <div class="flex justify-end space-x-3">
                <button type="button" phx-click="hide_contact_modal"
                        class="px-4 py-2 text-gray-600 hover:text-gray-800">
                  Cancel
                </button>
                <button type="submit"
                        class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                  Send Message
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp render_lightbox(assigns) do
    ~H"""
    <%= if @show_lightbox do %>
      <div class="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50"
          phx-click="hide_lightbox">
        <div class="relative max-w-7xl max-h-full p-4">
          <!-- Close button -->
          <button class="absolute top-4 right-4 z-10 w-10 h-10 bg-white bg-opacity-20 rounded-full flex items-center justify-center text-white hover:bg-opacity-30"
                  phx-click="hide_lightbox">
            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>

          <!-- Media content -->
          <%= if @lightbox_media do %>
            <%= if @lightbox_media.type == "video" do %>
              <video controls class="max-w-full max-h-full">
                <source src={@lightbox_media.url} type="video/mp4">
              </video>
            <% else %>
              <img src={@lightbox_media.url}
                  alt={@lightbox_media.alt || "Media"}
                  class="max-w-full max-h-full object-contain">
            <% end %>

            <%= if @lightbox_media.caption do %>
              <div class="absolute bottom-4 left-4 right-4 bg-black bg-opacity-70 text-white p-3 rounded">
                <%= @lightbox_media.caption %>
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
    """
  end

  @impl true
  def handle_event("show_export_modal", _params, socket) do
    {:noreply, assign(socket, :show_export_modal, true)}
  end

  @impl true
  def handle_event("hide_export_modal", _params, socket) do
    {:noreply, assign(socket, :show_export_modal, false)}
  end

  @impl true
  def handle_event("show_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, true)}
  end

  @impl true
  def handle_event("hide_share_modal", _params, socket) do
    {:noreply, assign(socket, :show_share_modal, false)}
  end

  @impl true
  def handle_event("show_contact_modal", _params, socket) do
    {:noreply, assign(socket, :show_contact_modal, true)}
  end

  @impl true
  def handle_event("hide_contact_modal", _params, socket) do
    {:noreply, assign(socket, :show_contact_modal, false)}
  end

  @impl true
  def handle_event("show_lightbox", %{"media_id" => media_id}, socket) do
    # Find the media item by ID
    media = find_media_by_id(socket.assigns.portfolio, media_id)

    {:noreply, socket
    |> assign(:show_lightbox, true)
    |> assign(:lightbox_media, media)}
  end

  @impl true
  def handle_event("hide_lightbox", _params, socket) do
    {:noreply, socket
    |> assign(:show_lightbox, false)
    |> assign(:lightbox_media, nil)}
  end

  @impl true
  def handle_event("export_portfolio", _params, socket) do
    # Handle portfolio export logic here
    {:noreply, socket
    |> assign(:show_export_modal, false)
    |> put_flash(:info, "Portfolio export started...")}
  end

  @impl true
  def handle_event("copy_portfolio_url", _params, socket) do
    {:noreply, put_flash(socket, :info, "Portfolio URL copied to clipboard!")}
  end

  @impl true
  def handle_event("send_contact_message", params, socket) do
    # Handle contact message sending here
    {:noreply, socket
    |> assign(:show_contact_modal, false)
    |> put_flash(:info, "Message sent successfully!")}
  end

  @impl true
  def handle_event("prevent_close", _params, socket) do
    {:noreply, socket}
  end


  # Simple helper function for section content
  defp render_section_content_safe(section) do
    content = Map.get(section, :content, %{})

    text = case content do
      %{"main_content" => text} when is_binary(text) -> text
      %{"summary" => text} when is_binary(text) -> text
      %{"description" => text} when is_binary(text) -> text
      %{"headline" => text} when is_binary(text) -> text
      _ -> "Section content..."
    end

    Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(text)}</p>")
  end

  defp get_portfolio_public_url(portfolio) do
    FrestylWeb.Router.Helpers.portfolio_show_url(FrestylWeb.Endpoint, :show, portfolio.slug)
  end

  defp find_media_by_id(portfolio, media_id) do
    # This would find media across all sections/blocks
    # For now, return a placeholder
    %{
      id: media_id,
      type: "image",
      url: "/images/placeholder.jpg",
      alt: "Media item",
      caption: nil
    }
  end

  # ============================================================================
  # LAYOUT RENDERING FUNCTIONS
  # ============================================================================

  defp render_dynamic_card_layout(assigns) do
    ~H"""
    <div class="dynamic-card-layout">
      <!-- Hero Zone -->
      <%= if Map.get(@layout_zones, :hero, []) != [] do %>
        <div class="layout-zone hero-zone">
          <%= for block <- Map.get(@layout_zones, :hero, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>
      <% end %>

      <!-- Main Content Zone -->
      <div class="main-content-wrapper">
        <div class="layout-zone main-content-zone">
          <%= for block <- Map.get(@layout_zones, :main_content, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>

        <!-- Sidebar Zone -->
        <%= if Map.get(@layout_zones, :sidebar, []) != [] do %>
          <div class="layout-zone sidebar-zone">
            <%= for block <- Map.get(@layout_zones, :sidebar, []) do %>
              <%= render_dynamic_card_block(block, assigns) %>
            <% end %>
          </div>
        <% end %>
      </div>

      <!-- Footer Zone -->
      <%= if Map.get(@layout_zones, :footer, []) != [] do %>
        <div class="layout-zone footer-zone">
          <%= for block <- Map.get(@layout_zones, :footer, []) do %>
            <%= render_dynamic_card_block(block, assigns) %>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_traditional_layout(assigns) do
    ~H"""
    <div class="traditional-layout">
      <!-- Always show edit button for owner at top -->
      <%= if Map.get(assigns, :current_user) && Map.get(assigns.current_user, :id) == Map.get(@portfolio, :user_id) do %>
        <div class="owner-actions" style="text-align: center; margin-bottom: 2rem;">
          <.link navigate={"/portfolios/#{@portfolio.id}/edit"}
                class="btn-primary">
            Edit Portfolio
          </.link>
        </div>
      <% end %>

      <%= if length(@sections) > 0 do %>
        <%= for section <- @sections do %>
          <%= if Map.get(section, :visible, true) do %>
            <div class={["portfolio-section", "section-#{Map.get(section, :section_type, "generic")}"]}
                data-section-id={Map.get(section, :id)}>
              <%= render_portfolio_section(section, assigns) %>
            </div>
          <% end %>
        <% end %>
      <% else %>
        <!-- Empty state (without edit button since it's moved above) -->
        <div class="empty-portfolio">
          <div class="empty-content">
            <svg class="empty-icon" width="64" height="64" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
            </svg>
            <h3>Portfolio Under Construction</h3>
            <p>This portfolio is being set up. Check back soon!</p>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_dynamic_card_block(block, assigns) do
    assigns = assign(assigns, :block, block)

    ~H"""
    <div class={["dynamic-card-block", "block-#{@block.block_type}"]}
         data-block-id={@block.id}>
      <%= case @block.block_type do %>
        <% :intro_card -> %>
          <%= render_intro_card_block(@block, assigns) %>
        <% :experience_card -> %>
          <%= render_experience_card_block(@block, assigns) %>
        <% :skills_card -> %>
          <%= render_skills_card_block(@block, assigns) %>
        <% :projects_card -> %>
          <%= render_projects_card_block(@block, assigns) %>
        <% :contact_card -> %>
          <%= render_contact_card_block(@block, assigns) %>
        <% _ -> %>
          <%= render_generic_card_block(@block, assigns) %>
      <% end %>
    </div>
    """
  end

  defp render_portfolio_section(section, assigns) do
    assigns = assign(assigns, :section, section)

    ~H"""
    <div class="section-content">
      <%= if @section.title do %>
        <h2 class="section-title"><%= @section.title %></h2>
      <% end %>

      <%= case @section.section_type do %>
        <% "intro" -> %>
          <%= render_intro_section(@section, assigns) %>
        <% "experience" -> %>
          <%= render_experience_section(@section, assigns) %>
        <% "skills" -> %>
          <%= render_skills_section(@section, assigns) %>
        <% "projects" -> %>
          <%= render_projects_section(@section, assigns) %>
        <% "contact" -> %>
          <%= render_contact_section(@section, assigns) %>
        <% _ -> %>
          <%= render_generic_section(@section, assigns) %>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # CARD BLOCK RENDERERS
  # ============================================================================

  defp render_intro_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="intro-card">
      <%= if @content["title"] do %>
        <h3 class="card-title"><%= @content["title"] %></h3>
      <% end %>
      <%= if @content["description"] do %>
        <p class="card-description"><%= @content["description"] %></p>
      <% end %>
      <%= if @content["image_url"] do %>
        <img src={@content["image_url"]} alt="Profile" class="card-image" />
      <% end %>
    </div>
    """
  end

  defp render_experience_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="experience-card">
      <%= if @content["company"] do %>
        <h4 class="company-name"><%= @content["company"] %></h4>
      <% end %>
      <%= if @content["position"] do %>
        <p class="position-title"><%= @content["position"] %></p>
      <% end %>
      <%= if @content["duration"] do %>
        <p class="duration"><%= @content["duration"] %></p>
      <% end %>
      <%= if @content["description"] do %>
        <p class="description"><%= @content["description"] %></p>
      <% end %>
    </div>
    """
  end

  defp render_skills_card_block(block, assigns) do
    content = block.content_data || %{}
    skills = content["skills"] || []
    assigns = assign(assigns, :skills, skills)

    ~H"""
    <div class="skills-card">
      <h4 class="card-title">Skills</h4>
      <div class="skills-list">
        <%= for skill <- @skills do %>
          <span class="skill-tag"><%= skill %></span>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_projects_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="projects-card">
      <%= if @content["title"] do %>
        <h4 class="project-title"><%= @content["title"] %></h4>
      <% end %>
      <%= if @content["description"] do %>
        <p class="project-description"><%= @content["description"] %></p>
      <% end %>
      <%= if @content["technologies"] do %>
        <div class="technologies">
          <%= for tech <- @content["technologies"] do %>
            <span class="tech-tag"><%= tech %></span>
          <% end %>
        </div>
      <% end %>
      <%= if @content["link"] do %>
        <a href={@content["link"]} class="project-link" target="_blank">View Project</a>
      <% end %>
    </div>
    """
  end

  defp render_contact_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="contact-card">
      <h4 class="card-title">Contact</h4>
      <%= if @content["email"] do %>
        <p class="contact-item">
          <span class="contact-label">Email:</span>
          <a href={"mailto:#{@content["email"]}"} class="contact-link"><%= @content["email"] %></a>
        </p>
      <% end %>
      <%= if @content["phone"] do %>
        <p class="contact-item">
          <span class="contact-label">Phone:</span>
          <a href={"tel:#{@content["phone"]}"} class="contact-link"><%= @content["phone"] %></a>
        </p>
      <% end %>
      <%= if @content["linkedin"] do %>
        <p class="contact-item">
          <span class="contact-label">LinkedIn:</span>
          <a href={@content["linkedin"]} class="contact-link" target="_blank">Profile</a>
        </p>
      <% end %>
    </div>
    """
  end

  defp render_generic_card_block(block, assigns) do
    content = block.content_data || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="generic-card">
      <%= if @content["title"] do %>
        <h4 class="card-title"><%= @content["title"] %></h4>
      <% end %>
      <%= if @content["content"] do %>
        <div class="card-content"><%= raw(@content["content"]) %></div>
      <% end %>
    </div>
    """
  end

  # ============================================================================
  # TRADITIONAL SECTION RENDERERS
  # ============================================================================

  defp render_intro_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="intro-section">
      <%= if @content["main_content"] do %>
        <div class="intro-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_experience_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="experience-section">
      <%= if @content["main_content"] do %>
        <div class="experience-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_skills_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="skills-section">
      <%= if @content["main_content"] do %>
        <div class="skills-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_projects_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="projects-section">
      <%= if @content["main_content"] do %>
        <div class="projects-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_contact_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="contact-section">
      <%= if @content["main_content"] do %>
        <div class="contact-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_generic_section(section, assigns) do
    content = section.content || %{}
    assigns = assign(assigns, :content, content)

    ~H"""
    <div class="generic-section">
      <%= if @content["main_content"] do %>
        <div class="section-content"><%= raw(@content["main_content"]) %></div>
      <% end %>
    </div>
    """
  end

  defp render_service_provider_layout(assigns) do
    ~H"""
    <div class="service-provider-layout">
      <!-- Hero Section with Service Focus -->
      <section class="hero-section py-20" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.secondary} 100%)"}>
        <div class="container mx-auto px-6 text-center">
          <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-white/90 mb-8 max-w-2xl mx-auto"><%= @portfolio.description %></p>

          <!-- Service CTAs -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
              Book Consultation
            </button>
            <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
              View Services
            </button>
          </div>
        </div>
      </section>

      <!-- Services Grid -->
      <section class="services-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Services</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "services", "skills"]) do %>
              <div class="service-card bg-white rounded-xl p-6 shadow-lg hover:shadow-xl transition-shadow">
                <h3 class="text-xl font-semibold mb-4" style={"color: #{@brand_colors.primary}"}><%= section.title %></h3>
                <p class="text-gray-600 mb-4"><%= get_section_excerpt(section) %></p>
                <button class="text-sm font-medium hover:underline" style={"color: #{@brand_colors.accent}"}>
                  Learn More →
                </button>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <!-- Trust Building: Testimonials + Pricing -->
      <section class="trust-section py-16">
        <div class="container mx-auto px-6">
          <div class="grid grid-cols-1 lg:grid-cols-3 gap-12">
            <!-- Testimonials -->
            <div class="lg:col-span-2">
              <h2 class="text-3xl font-bold mb-8">Client Testimonials</h2>
              <div class="space-y-6">
                <%= for section <- filter_sections_by_type(@sections, ["testimonial"]) do %>
                  <div class="testimonial-card bg-white p-6 rounded-xl border border-gray-200">
                    <p class="text-gray-700 mb-4 italic">"<%= get_section_excerpt(section) %>"</p>
                    <div class="flex items-center">
                      <div class="w-12 h-12 rounded-full mr-4" style={"background: #{@brand_colors.primary}"}></div>
                      <div>
                        <h4 class="font-semibold"><%= section.title %></h4>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <!-- Pricing -->
            <div class="lg:col-span-1">
              <h2 class="text-3xl font-bold mb-8">Pricing</h2>
              <div class="pricing-card bg-white p-6 rounded-xl border-2" style={"border-color: #{@brand_colors.accent}"}>
                <h3 class="text-xl font-semibold mb-4">Consultation</h3>
                <div class="text-4xl font-bold mb-4" style={"color: #{@brand_colors.primary}"}>$150<span class="text-lg text-gray-600">/hour</span></div>
                <ul class="space-y-2 mb-6">
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Expert consultation</li>
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Action plan included</li>
                  <li class="flex items-center"><span class="w-2 h-2 rounded-full mr-3" style={"background: #{@brand_colors.accent}"}></span>Follow-up support</li>
                </ul>
                <button class="w-full py-3 rounded-lg font-semibold text-white transition-colors" style={"background: #{@brand_colors.primary}"}>
                  Book Now
                </button>
              </div>
            </div>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_creative_showcase_layout(assigns) do
    ~H"""
    <div class="creative-showcase-layout">
      <!-- Visual Hero -->
      <section class="hero-section min-h-screen bg-gradient-to-br from-purple-900 via-pink-800 to-orange-600 relative overflow-hidden">
        <div class="absolute inset-0 bg-black/20"></div>
        <div class="relative z-10 container mx-auto px-6 flex items-center min-h-screen">
          <div class="max-w-3xl">
            <h1 class="text-6xl lg:text-7xl font-bold text-white mb-6 leading-tight"><%= @portfolio.title %></h1>
            <p class="text-2xl text-white/90 mb-8"><%= @portfolio.description %></p>
            <div class="flex gap-4">
              <button class="px-8 py-4 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
                View Portfolio
              </button>
              <button class="px-8 py-4 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
                Commission Work
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Portfolio Masonry Grid -->
      <section class="portfolio-section py-20">
        <div class="container mx-auto px-6">
          <h2 class="text-4xl font-bold text-center mb-16">Recent Work</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "featured_project", "media_showcase"]) do %>
              <div class="portfolio-item group cursor-pointer">
                <div class="aspect-square bg-gradient-to-br rounded-2xl overflow-hidden" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.accent} 100%)"}>
                  <div class="w-full h-full flex items-center justify-center bg-black/20 group-hover:bg-black/40 transition-colors">
                    <div class="text-center text-white p-6">
                      <h3 class="text-xl font-bold mb-2"><%= section.title %></h3>
                      <p class="text-white/80 opacity-0 group-hover:opacity-100 transition-opacity">
                        <%= get_section_excerpt(section) %>
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_content_creator_layout(assigns) do
    ~H"""
    <div class="content-creator-layout">
      <!-- Streaming Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-purple-600 via-pink-600 to-orange-500">
        <div class="container mx-auto px-6 text-center">
          <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
          <p class="text-xl text-white/90 mb-8 max-w-2xl mx-auto"><%= @portfolio.description %></p>

          <!-- Creator CTAs -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
              Subscribe
            </button>
            <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
              Collaborate
            </button>
          </div>
        </div>
      </section>

      <!-- Content Metrics -->
      <section class="metrics-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Creator Stats</h2>
          <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>100K+</div>
              <div class="text-gray-600">Followers</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>1M+</div>
              <div class="text-gray-600">Views</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>500+</div>
              <div class="text-gray-600">Videos</div>
            </div>
            <div class="metric-card text-center p-6 bg-white rounded-xl shadow-lg">
              <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>98%</div>
              <div class="text-gray-600">Positive Rating</div>
            </div>
          </div>
        </div>
      </section>

      <!-- Content Showcase -->
      <section class="content-section py-16">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Latest Content</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "media_showcase"]) do %>
              <div class="content-card bg-white rounded-xl overflow-hidden shadow-lg hover:shadow-xl transition-shadow">
                <div class="aspect-video bg-gradient-to-br rounded-t-xl" style={"background: linear-gradient(135deg, #{@brand_colors.primary} 0%, #{@brand_colors.accent} 100%)"}>
                  <div class="w-full h-full flex items-center justify-center">
                    <div class="text-white text-center">
                      <h3 class="text-lg font-bold"><%= section.title %></h3>
                    </div>
                  </div>
                </div>
                <div class="p-6">
                  <p class="text-gray-600 mb-4"><%= get_section_excerpt(section) %></p>
                  <button class="text-sm font-medium hover:underline" style={"color: #{@brand_colors.accent}"}>
                    Watch Now →
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_corporate_executive_layout(assigns) do
    ~H"""
    <div class="corporate-executive-layout">
      <!-- Executive Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-slate-900 to-blue-900">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl mx-auto text-center">
            <h1 class="text-5xl font-bold text-white mb-6"><%= @portfolio.title %></h1>
            <p class="text-xl text-white/90 mb-8"><%= @portfolio.description %></p>

            <!-- Executive CTAs -->
            <div class="flex flex-col sm:flex-row gap-4 justify-center">
              <button class="px-8 py-3 bg-white text-gray-900 rounded-lg font-semibold hover:bg-gray-100 transition-colors">
                Schedule Meeting
              </button>
              <button class="px-8 py-3 border-2 border-white text-white rounded-lg font-semibold hover:bg-white hover:text-gray-900 transition-colors">
                Download Resume
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Executive Summary -->
      <section class="summary-section py-16 bg-white">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl mx-auto">
            <h2 class="text-3xl font-bold text-center mb-12">Executive Summary</h2>
            <div class="grid grid-cols-1 md:grid-cols-3 gap-8">
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>15+</div>
                <div class="text-gray-600">Years Experience</div>
              </div>
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>$50M+</div>
                <div class="text-gray-600">Revenue Generated</div>
              </div>
              <div class="stat-card text-center p-6">
                <div class="text-4xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}>200+</div>
                <div class="text-gray-600">Team Members Led</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Leadership Experience -->
      <section class="experience-section py-16 bg-gray-50">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold text-center mb-12">Leadership Experience</h2>
          <div class="max-w-4xl mx-auto space-y-8">
            <%= for section <- filter_sections_by_type(@sections, ["experience", "achievements"]) do %>
              <div class="experience-card bg-white p-8 rounded-xl shadow-lg">
                <div class="flex items-start justify-between mb-4">
                  <div>
                    <h3 class="text-xl font-bold mb-2" style={"color: #{@brand_colors.primary}"}><%= section.title %></h3>
                    <p class="text-gray-600"><%= get_section_excerpt(section) %></p>
                  </div>
                  <div class="text-right">
                    <div class="text-sm text-gray-500">2020 - Present</div>
                  </div>
                </div>
                <div class="flex flex-wrap gap-2">
                  <span class="px-3 py-1 bg-blue-100 text-blue-800 rounded text-sm">Strategy</span>
                  <span class="px-3 py-1 bg-green-100 text-green-800 rounded text-sm">Growth</span>
                  <span class="px-3 py-1 bg-purple-100 text-purple-800 rounded text-sm">Leadership</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_technical_expert_layout(assigns) do
    ~H"""
    <div class="technical-expert-layout bg-gray-900 text-white">
      <!-- Terminal-Style Hero -->
      <section class="hero-section py-20 bg-gradient-to-br from-gray-900 to-gray-800">
        <div class="container mx-auto px-6">
          <div class="max-w-4xl">
            <div class="font-mono text-green-400 mb-4">~/$ whoami</div>
            <h1 class="text-5xl font-bold mb-6"><%= @portfolio.title %></h1>
            <div class="font-mono text-green-400 mb-4">~/$ cat about.txt</div>
            <p class="text-xl text-gray-300 mb-8"><%= @portfolio.description %></p>
            <div class="font-mono text-green-400 mb-6">~/$ ls services/</div>
            <div class="flex gap-4">
              <button class="px-6 py-3 bg-green-600 text-white rounded font-semibold hover:bg-green-700 transition-colors">
                ./hire_me.sh
              </button>
              <button class="px-6 py-3 border border-green-600 text-green-400 rounded font-semibold hover:bg-green-600 hover:text-white transition-colors">
                cat portfolio.md
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- Skills Matrix -->
      <section class="skills-section py-16 bg-gray-800">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold mb-12 text-center">Technical Expertise</h2>
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            <%= for section <- filter_sections_by_type(@sections, ["skills", "experience"]) do %>
              <div class="skill-card bg-gray-700 p-6 rounded-lg border border-gray-600">
                <h3 class="text-lg font-semibold mb-4 text-green-400"><%= section.title %></h3>
                <div class="space-y-2">
                  <div class="flex justify-between text-sm">
                    <span>Proficiency</span>
                    <span>90%</span>
                  </div>
                  <div class="w-full bg-gray-600 rounded-full h-2">
                    <div class="bg-green-500 h-2 rounded-full w-[90%]"></div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>

      <!-- Project Deep Dive -->
      <section class="projects-section py-16 bg-gray-900">
        <div class="container mx-auto px-6">
          <h2 class="text-3xl font-bold mb-12 text-center">Featured Projects</h2>
          <div class="space-y-8">
            <%= for section <- filter_sections_by_type(@sections, ["projects", "featured_project"]) do %>
              <div class="project-card bg-gray-800 p-8 rounded-xl border border-gray-700">
                <h3 class="text-2xl font-bold mb-4 text-green-400"><%= section.title %></h3>
                <p class="text-gray-300 mb-6"><%= get_section_excerpt(section) %></p>
                <div class="flex flex-wrap gap-2 mb-6">
                  <span class="px-3 py-1 bg-green-600 text-white rounded text-sm">React</span>
                  <span class="px-3 py-1 bg-blue-600 text-white rounded text-sm">Node.js</span>
                  <span class="px-3 py-1 bg-purple-600 text-white rounded text-sm">PostgreSQL</span>
                </div>
                <div class="flex gap-4">
                  <button class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700 transition-colors">
                    View Code
                  </button>
                  <button class="px-4 py-2 border border-green-600 text-green-400 rounded hover:bg-green-600 hover:text-white transition-colors">
                    Live Demo
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </section>
    </div>
    """
  end

  defp render_traditional_public_view(assigns) do
    ~H"""
    <%= if length(@sections || []) > 0 do %>
      <%= for section <- (@sections || []) do %>
        <%= if Map.get(section, :visible, true) do %>
          <div class="section">
            <h2 class="section-title"><%= section.title %></h2>
            <div class="section-content">
              <%= render_section_content_safe(section) %>
            </div>
          </div>
        <% end %>
      <% end %>
    <% else %>
      <div class="section text-center">
        <h2 class="section-title">Portfolio Under Construction</h2>
        <p class="section-content">This portfolio is being set up. Check back soon!</p>
      </div>
    <% end %>
    """
  end

  defp render_dynamic_card_public_view(assigns) do
    ~H"""
    <%= if map_size(@layout_zones || %{}) > 0 do %>
      <%= for {zone_name, blocks} <- (@layout_zones || %{}) do %>
        <%= if length(blocks) > 0 do %>
          <%= render_zone_public(zone_name, blocks, assigns) %>
        <% end %>
      <% end %>
    <% else %>
      <div class="section text-center">
        <h2 class="section-title">Portfolio</h2>
        <p class="section-content">Content loading...</p>
      </div>
    <% end %>
    """
  end

  defp render_zone_public(zone_name, blocks, assigns) do
    zone_class = get_zone_css_class(zone_name)
    assigns = assign(assigns, :zone_name, zone_name) |> assign(:blocks, blocks)

    ~H"""
    <section class={"#{zone_class} py-12"}>
      <%= for block <- @blocks do %>
        <%= render_content_block_public(block, assigns) %>
      <% end %>
    </section>
    """
  end

  defp get_zone_css_class(zone_name) do
    case zone_name do
      :hero -> "hero-zone"
      :about -> "about-zone"
      :experience -> "experience-zone"
      :skills -> "skills-zone"
      :projects -> "projects-zone"
      :services -> "services-zone"
      :contact -> "contact-zone"
      _ -> "content-zone"
    end
  end

  defp render_content_block_public(block, assigns) do
    block_type = block.block_type
    content = block.content_data
    assigns = assign(assigns, :block, block) |> assign(:content, content)

    ~H"""
    <%= case block_type do %>
      <% :hero_card -> %>
        <div class="hero-card text-center py-16 px-6">
          <h1 class="text-5xl font-bold mb-6" style="color: var(--primary-color);">
            <%= @content.title %>
          </h1>
          <%= if @content.subtitle && @content.subtitle != "" do %>
            <p class="text-xl text-gray-600 mb-8 max-w-3xl mx-auto">
              <%= @content.subtitle %>
            </p>
          <% end %>
          <%= if @content.content && @content.content != "" do %>
            <p class="text-lg text-gray-700 mb-8 max-w-4xl mx-auto">
              <%= @content.content %>
            </p>
          <% end %>
          <%= if @content.video_url do %>
            <div class="max-w-md mx-auto mb-8">
              <video controls class="w-full rounded-lg shadow-lg" style="aspect-ratio: 4/5;">
                <source src={@content.video_url} type="video/webm">
                Your browser does not support the video tag.
              </video>
            </div>
          <% end %>
        </div>

      <% :about_card -> %>
        <div class="about-card bg-white rounded-lg shadow-sm border p-8 mb-8">
          <h2 class="text-3xl font-bold mb-6" style="color: var(--primary-color);">
            <%= @content.title %>
          </h2>
          <%= if @content.subtitle && @content.subtitle != "" do %>
            <p class="text-xl text-gray-600 mb-4">
              <%= @content.subtitle %>
            </p>
          <% end %>
          <%= if @content.content && @content.content != "" do %>
            <div class="text-gray-700 leading-relaxed">
              <%= raw(String.replace(@content.content, "\n", "<br>")) %>
            </div>
          <% end %>
        </div>

      <% :experience_card -> %>
        <div class="experience-card bg-white rounded-lg shadow-sm border p-8 mb-8">
          <h2 class="text-3xl font-bold mb-6" style="color: var(--primary-color);">
            <%= @content.title %>
          </h2>
          <%= if @content.jobs && length(@content.jobs) > 0 do %>
            <div class="space-y-6">
              <%= for job <- @content.jobs do %>
                <div class="border-l-4 pl-6" style="border-color: var(--accent-color);">
                  <h3 class="text-xl font-semibold text-gray-900">
                    <%= Map.get(job, "title", "Position") %>
                  </h3>
                  <p class="text-lg text-gray-700 mb-2">
                    <%= Map.get(job, "company", "Company") %>
                  </p>
                  <p class="text-gray-600 mb-3">
                    <%= Map.get(job, "start_date", "") %>
                    <%= if Map.get(job, "current", false), do: " - Present", else: " - #{Map.get(job, "end_date", "")}" %>
                  </p>
                  <%= if Map.get(job, "description") do %>
                    <p class="text-gray-700 mb-4">
                      <%= String.slice(Map.get(job, "description", ""), 0, 300) %>
                      <%= if String.length(Map.get(job, "description", "")) > 300, do: "..." %>
                    </p>
                  <% end %>
                  <%= if Map.get(job, "responsibilities") && length(Map.get(job, "responsibilities", [])) > 0 do %>
                    <ul class="list-disc list-inside space-y-1 text-gray-700">
                      <%= for responsibility <- Enum.take(Map.get(job, "responsibilities", []), 3) do %>
                        <li><%= responsibility %></li>
                      <% end %>
                    </ul>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% else %>
            <p class="text-gray-700"><%= @content.content || @content.description %></p>
          <% end %>
        </div>

      <% :achievement_card -> %>
        <div class="achievement-card bg-white rounded-lg shadow-sm border p-8 mb-8">
          <h2 class="text-3xl font-bold mb-6" style="color: var(--primary-color);">
            <%= @content.title %>
          </h2>
          <%= if @content.content && @content.content != "" do %>
            <div class="text-gray-700 leading-relaxed mb-6">
              <%= raw(String.replace(@content.content, "\n", "<br>")) %>
            </div>
          <% end %>
          <%= if @content.achievements && length(@content.achievements) > 0 do %>
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <%= for achievement <- @content.achievements do %>
                <div class="bg-gray-50 rounded-lg p-4 border-l-4" style="border-color: var(--accent-color);">
                  <h3 class="font-semibold text-gray-900">
                    <%= Map.get(achievement, "title", "Achievement") %>
                  </h3>
                  <%= if Map.get(achievement, "description") do %>
                    <p class="text-gray-700 mt-2">
                      <%= Map.get(achievement, "description") %>
                    </p>
                  <% end %>
                  <%= if Map.get(achievement, "date") do %>
                    <p class="text-sm text-gray-500 mt-2">
                      <%= Map.get(achievement, "date") %>
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
          <%= if @content.awards && length(@content.awards) > 0 do %>
            <div class="mt-6">
              <h3 class="text-xl font-semibold mb-4" style="color: var(--accent-color);">Awards</h3>
              <div class="space-y-3">
                <%= for award <- @content.awards do %>
                  <div class="flex items-center">
                    <div class="w-3 h-3 rounded-full mr-3" style="background-color: var(--accent-color);"></div>
                    <span class="text-gray-700"><%= award %></span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>

      <% _ -> %>
        <div class="content-card bg-white rounded-lg shadow-sm border p-6 mb-6">
          <h2 class="text-2xl font-bold mb-4" style="color: var(--primary-color);">
            <%= @content.title %>
          </h2>
          <div class="text-gray-700">
            <%= if @content.content && @content.content != "" do %>
              <%= raw(String.replace(@content.content, "\n", "<br>")) %>
            <% else %>
              <p>Section type: <%= @content.section_type || "unknown" %></p>
              <p>Available data: <%= inspect(Map.keys(@content)) %></p>
            <% end %>
          </div>
        </div>
    <% end %>
    """
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  # Add to show.ex mount function
  defp determine_portfolio_layout_type(portfolio) do
    customization = portfolio.customization || %{}

    # Check for dynamic card layout
    layout_style = Map.get(customization, "layout") || portfolio.theme

    dynamic_layouts = [
      "professional_service_provider",
      "creative_portfolio_showcase",
      "technical_expert_dashboard",
      "content_creator_hub",
      "corporate_executive_profile"
    ]

    if layout_style in dynamic_layouts do
      {:dynamic_card, layout_style}
    else
      {:traditional, "default"}
    end
  end

  defp render_portfolio_layout(assigns) do
    # Use the customization layout setting
    layout = assigns.portfolio_layout

    case layout do
      "dashboard" -> render_dashboard_layout(assigns)
      "gallery" -> render_gallery_layout(assigns)
      "minimal" -> render_minimal_layout(assigns)
      _ -> render_minimal_layout(assigns)  # fallback
    end
  end

  defp get_dynamic_layout_config(portfolio, layout_style) do
    customization = portfolio.customization || %{}

    %{
      layout_style: layout_style,
      primary_color: Map.get(customization, "primary_color") || "#3b82f6",
      secondary_color: Map.get(customization, "secondary_color") || "#64748b",
      accent_color: Map.get(customization, "accent_color") || "#f59e0b",
      grid_density: Map.get(customization, "grid_density") || "normal"
    }
  end

  defp get_brand_colors(portfolio) do
    customization = portfolio.customization || %{}

    %{
      primary: Map.get(customization, "primary_color") || "#3b82f6",
      secondary: Map.get(customization, "secondary_color") || "#64748b",
      accent: Map.get(customization, "accent_color") || "#f59e0b"
    }
  end

  defp filter_sections_by_type(sections, types) do
    Enum.filter(sections, fn section ->
      section_type = to_string(section.section_type)
      section_type in types and section.visible
    end)
  end

  defp get_section_excerpt(section) do
    content = section.content || %{}

    # Try to get main content or description
    main_content = Map.get(content, "main_content") ||
                  Map.get(content, "description") ||
                  Map.get(content, "summary") ||
                  ""

    # Truncate to reasonable length
    if String.length(main_content) > 150 do
      String.slice(main_content, 0, 147) <> "..."
    else
      main_content
    end
  end

  defp render_traditional_sections(assigns) do
    ~H"""
    <!-- Your existing traditional section rendering -->
    <div class="traditional-portfolio">
      <%= for section <- @sections do %>
        <%= if section.visible do %>
          <section class="mb-8">
            <h2 class="text-2xl font-bold mb-4"><%= section.title %></h2>
            <div class="prose max-w-none">
              <%= get_section_excerpt(section) %>
            </div>
          </section>
        <% end %>
      <% end %>
    </div>
    """
  end

  defp render_dynamic_card_layout(assigns, layout_style) do
    # Get layout configuration
    layout_config = get_dynamic_layout_config(assigns.portfolio, layout_style)

    assigns = assigns
    |> assign(:layout_style, layout_style)
    |> assign(:layout_config, layout_config)
    |> assign(:brand_colors, get_brand_colors(assigns.portfolio))

    case layout_style do
      "professional_service_provider" ->
        render_service_provider_layout(assigns)

      "creative_portfolio_showcase" ->
        render_creative_showcase_layout(assigns)

      "technical_expert_dashboard" ->
        render_technical_expert_layout(assigns)

      "content_creator_hub" ->
        render_content_creator_layout(assigns)

      "corporate_executive_profile" ->
        render_corporate_executive_layout(assigns)

      _ ->
        render_service_provider_layout(assigns)  # Default fallback
    end
  end

    defp assign_portfolio_data(socket, portfolio) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:owner, portfolio.user)
    |> assign(:page_title, portfolio.title)
    |> assign(:customization, Map.get(portfolio, :customization, %{}))
  end

  defp assign_view_context(socket, view_type) do
    socket
    |> assign(:view_type, view_type)
    |> assign(:is_owner, view_type == :authenticated && socket.assigns[:current_user] && socket.assigns.current_user.id == socket.assigns.portfolio.user_id)
    |> assign(:show_edit_controls, false)
    |> assign(:enable_analytics, view_type in [:public, :shared])
  end

  defp assign_ui_state(socket) do
    socket
    |> assign(:show_export_modal, false)
    |> assign(:show_share_modal, false)
    |> assign(:show_contact_modal, false)
    |> assign(:active_lightbox_media, nil)
    |> assign(:mobile_nav_open, false)
  end

  defp assign_seo_data(socket, portfolio) do
    title = portfolio.title
    description = extract_portfolio_description(portfolio)
    og_image = extract_portfolio_og_image(portfolio)

    socket
    |> assign(:seo_title, title)
    |> assign(:seo_description, description)
    |> assign(:seo_image, og_image)
    |> assign(:canonical_url, generate_canonical_url(portfolio))
  end

  defp assign_rendering_data(socket, portfolio) do
    # Use Dynamic Card Layout system as the rendering engine
    case determine_layout_type_safe(portfolio) do
      {:dynamic_card, layout_config} ->
        layout_zones = load_dynamic_layout_zones_safe(portfolio.id)
        custom_css = generate_safe_portfolio_css(portfolio.customization || %{}, layout_config)

        socket
        |> assign(:is_dynamic_layout, true)
        |> assign(:layout_type, :dynamic_card)
        |> assign(:layout_config, layout_config)
        |> assign(:layout_zones, layout_zones)
        |> assign(:sections, [])  # Dynamic card layouts use zones, not sections
        |> assign(:custom_css, custom_css)

      {:traditional, layout_config} ->
        sections = load_portfolio_sections_for_display(portfolio)
        # For traditional layouts, still use sections but prepare for dynamic rendering
        custom_css = generate_safe_portfolio_css(portfolio.customization || %{}, layout_config)

        socket
        |> assign(:is_dynamic_layout, false)
        |> assign(:layout_type, :traditional)
        |> assign(:layout_config, layout_config)
        |> assign(:layout_zones, %{})
        |> assign(:sections, sections)
        |> assign(:custom_css, custom_css)
    end
    |> assign(:customization, Map.get(portfolio, :customization, %{}))
    |> assign(:template_config, get_template_config(portfolio.theme || "professional"))
    |> assign(:design_tokens, generate_design_tokens(portfolio))
    |> assign(:brand_settings, nil)
  end

  defp determine_layout_type_safe(portfolio) do
    try do
      # Try to use Dynamic Card Layout system if available
      if Code.ensure_loaded?(DynamicCardLayoutManager) do
        DynamicCardLayoutManager.determine_layout_type(portfolio)
      else
        {:traditional, get_template_config(portfolio.theme || "professional")}
      end
    rescue
      _ ->
        {:traditional, get_template_config(portfolio.theme || "professional")}
    end
  end

  defp load_dynamic_layout_zones_safe(portfolio_id) do
    try do
      if Code.ensure_loaded?(DynamicCardLayoutManager) do
        DynamicCardLayoutManager.load_layout_zones(portfolio_id)
      else
        %{}
      end
    rescue
      _ -> %{}
    end
  end


  # Safe CSS generation function
  defp generate_safe_portfolio_css(customization, template_config) do
    # Extract colors safely - prioritize customization over template
    primary_color = Map.get(customization, "primary_color") ||
                   Map.get(template_config, "primary_color") ||
                   "#1e40af"

    accent_color = Map.get(customization, "accent_color") ||
                  Map.get(template_config, "accent_color") ||
                  "#f59e0b"

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
    }

    .portfolio-show {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.6;
      color: #333;
    }

    .portfolio-header {
      text-align: center;
      padding: 2rem 1rem;
      background: var(--primary-color);
      color: white;
    }

    .portfolio-title {
      font-size: 2.5rem;
      font-weight: bold;
      margin-bottom: 0.5rem;
    }

    .portfolio-description {
      font-size: 1.2rem;
      opacity: 0.9;
    }

    .traditional-layout {
      max-width: 800px;
      margin: 0 auto;
      padding: 2rem 1rem;
    }

    .portfolio-section {
      background: white;
      border-radius: 8px;
      padding: 2rem;
      margin-bottom: 2rem;
      box-shadow: 0 2px 4px rgba(0,0,0,0.1);
    }

    .section-title {
      font-size: 1.8rem;
      font-weight: bold;
      margin-bottom: 1rem;
      color: var(--primary-color);
    }

    .empty-portfolio {
      text-align: center;
      padding: 4rem 2rem;
      min-height: 400px;
      display: flex;
      align-items: center;
      justify-content: center;
    }

    .empty-content {
      max-width: 400px;
    }

    .empty-icon {
      color: #9ca3af;
      margin: 0 auto 1.5rem;
    }

    .empty-content h3 {
      font-size: 1.5rem;
      font-weight: bold;
      color: #374151;
      margin-bottom: 0.5rem;
    }

    .empty-content p {
      color: #6b7280;
      margin-bottom: 2rem;
    }

    .btn-primary {
      display: inline-block;
      background: var(--primary-color);
      color: white;
      padding: 0.75rem 1.5rem;
      border-radius: 8px;
      text-decoration: none;
      font-weight: medium;
      transition: background-color 0.2s;
    }

    .btn-primary:hover {
      opacity: 0.9;
    }

    .debug-info {
      font-family: monospace;
      font-size: 0.75rem;
      line-height: 1.4;
    }

    .portfolio-footer {
      text-align: center;
      padding: 2rem;
      background: #f8f9fa;
      color: #666;
    }
    """
  end

    defp assign_dynamic_layout_system(socket, portfolio) do
    # Determine layout type and configuration
    layout_detection = DynamicCardLayoutManager.determine_layout_type(portfolio)

    case layout_detection do
      {:dynamic_card, layout_config} ->
        layout_zones = DynamicCardLayoutManager.load_layout_zones(portfolio.id)
        custom_css = generate_portfolio_css(portfolio)

        socket
        |> assign(:is_dynamic_layout, true)
        |> assign(:layout_type, :dynamic_card)
        |> assign(:layout_config, layout_config)
        |> assign(:layout_zones, layout_zones)
        |> assign(:custom_css, custom_css)
        |> assign(:public_view_settings, get_public_view_settings(portfolio))

      {:traditional, layout_config} ->
        sections = load_portfolio_sections_for_display(portfolio)
        custom_css = generate_portfolio_css(portfolio)

        socket
        |> assign(:is_dynamic_layout, false)
        |> assign(:layout_type, :traditional)
        |> assign(:layout_config, layout_config)
        |> assign(:sections, sections)
        |> assign(:custom_css, custom_css)
        |> assign(:public_view_settings, %{})
    end
  end

  defp get_public_view_settings(portfolio) do
    customization = portfolio.customization || %{}

    %{
      layout_type: Map.get(customization, "public_layout_type", "dashboard"),
      enable_sticky_nav: Map.get(customization, "enable_sticky_nav", true),
      enable_back_to_top: Map.get(customization, "enable_back_to_top", true),
      mobile_expansion_style: Map.get(customization, "mobile_expansion_style", "in_place"),
      video_autoplay: Map.get(customization, "video_autoplay", "muted"),
      gallery_lightbox: Map.get(customization, "gallery_lightbox", true),
      color_scheme: Map.get(customization, "color_scheme", "professional"),
      font_family: Map.get(customization, "font_family", "inter"),
      enable_animations: Map.get(customization, "enable_animations", true)
    }
  end

  # ============================================================================
  # PORTFOLIO DATA LOADING
  # ============================================================================

  defp load_portfolio_by_slug(slug) do
    try do
      case Portfolios.get_portfolio_by_slug(slug) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp load_portfolio_by_id(id) do
    try do
      case Portfolios.get_portfolio(id) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp load_portfolio_by_share_token(token) do
    try do
      case Portfolios.get_portfolio_by_share_token(token) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp load_portfolio_sections_for_display(portfolio) do
    # First try to get sections from portfolio association
    sections = case Map.get(portfolio, :sections) do
      %Ecto.Association.NotLoaded{} ->
        # Association not loaded, try to load manually
        load_sections_manually(portfolio.id)
      sections when is_list(sections) ->
        sections
      _ ->
        # No sections or unexpected format
        load_sections_manually(portfolio.id)
    end

    # Also try portfolio_sections association
    if length(sections) == 0 do
      case Map.get(portfolio, :portfolio_sections) do
        %Ecto.Association.NotLoaded{} ->
          load_sections_manually(portfolio.id)
        portfolio_sections when is_list(portfolio_sections) ->
          portfolio_sections
        _ ->
          []
      end
    else
      sections
    end
  end

  defp load_sections_manually(portfolio_id) do
    try do
      # Try standard function first
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ ->
        try do
          # Try alternative function name
          Portfolios.get_portfolio_sections(portfolio_id)
        rescue
          _ ->
            try do
              # Try direct query as last resort
              import Ecto.Query

              # Query the portfolio_sections table directly
              query = from ps in "portfolio_sections",
                where: ps.portfolio_id == ^portfolio_id,
                order_by: [asc: ps.position],
                select: %{
                  id: ps.id,
                  portfolio_id: ps.portfolio_id,
                  title: ps.title,
                  section_type: ps.section_type,
                  content: ps.content,
                  position: ps.position,
                  visible: ps.visible
                }

              Repo.all(query)
            rescue
              _ ->
                IO.puts("⚠️ Could not load sections for portfolio #{portfolio_id}")
                []
            end
        end
    end
  end

  defp is_dynamic_card_layout?(portfolio) do
    # Get layout safely with fallback
    layout = Map.get(portfolio, :layout, "traditional")

    layout in ["dynamic_card", "professional_cards", "creative_cards"] ||
    Map.get(Map.get(portfolio, :customization, %{}), "use_dynamic_cards", false)
  end

  defp load_dynamic_layout_zones(_portfolio_id) do
    # This would load from database in real implementation
    %{
      hero: [],
      main_content: [],
      sidebar: [],
      footer: []
    }
  end

  defp get_template_config(theme) do
    try do
      case PortfolioTemplates.get_template_config(theme || "professional") do
        config when is_map(config) -> config
        _ -> get_default_template_config()
      end
    rescue
      _ -> get_default_template_config()
    end
  end

  defp get_default_template_config do
    %{
      "primary_color" => "#1e40af",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "layout" => "traditional"
    }
  end

  defp generate_design_tokens(portfolio) do
    customization = Map.get(portfolio, :customization, %{})

    %{
      primary_color: Map.get(customization, "primary_color", "#1e40af"),
      accent_color: Map.get(customization, "accent_color", "#f59e0b"),
      font_family: Map.get(customization, "font_family", "Inter")
    }
  end

  defp generate_design_tokens_with_brand(portfolio, brand_settings) do
    base_tokens = generate_design_tokens(portfolio)

    # Handle both atom and string keys for brand_settings
    brand_primary = case brand_settings do
      %{primary_color: color} -> color
      %{"primary_color" => color} -> color
      _ -> "#1e40af"
    end

    brand_secondary = case brand_settings do
      %{secondary_color: color} -> color
      %{"secondary_color" => color} -> color
      _ -> "#64748b"
    end

    brand_accent = case brand_settings do
      %{accent_color: color} -> color
      %{"accent_color" => color} -> color
      _ -> "#f59e0b"
    end

    Map.merge(base_tokens, %{
      brand_primary: brand_primary,
      brand_secondary: brand_secondary,
      brand_accent: brand_accent
    })
  end

  defp generate_brand_css(brand_settings) do
    # Handle both atom and string keys for brand_settings
    primary = case brand_settings do
      %{primary_color: color} -> color
      %{"primary_color" => color} -> color
      _ -> "#1e40af"
    end

    secondary = case brand_settings do
      %{secondary_color: color} -> color
      %{"secondary_color" => color} -> color
      _ -> "#64748b"
    end

    accent = case brand_settings do
      %{accent_color: color} -> color
      %{"accent_color" => color} -> color
      _ -> "#f59e0b"
    end

    """
    :root {
      --brand-primary: #{primary};
      --brand-secondary: #{secondary};
      --brand-accent: #{accent};
    }
    """
  end

  defp portfolio_layout_class(portfolio) do
    layout = Map.get(portfolio, :layout, "traditional")

    case layout do
      "dynamic_card" -> "layout-dynamic-card"
      "professional_cards" -> "layout-professional-cards"
      "creative_cards" -> "layout-creative-cards"
      _ -> "layout-traditional"
    end
  end

  defp should_use_dynamic_card_layout?(portfolio) do
    customization = portfolio.customization || %{}
    layout = Map.get(customization, "layout", portfolio.theme)

    layout in [
      "dynamic_card_layout",
      "professional_service_provider",
      "creative_portfolio_showcase",
      "technical_expert_dashboard",
      "content_creator_hub",
      "corporate_executive_profile"
    ]
  end

  # ADD the same content block conversion functions (copy from portfolio_editor.ex):
  defp convert_sections_to_content_blocks(sections) do
    sections
    |> Enum.with_index()
    |> Enum.map(fn {section, index} ->
      %{
        id: section.id,
        portfolio_id: section.portfolio_id,
        block_type: map_section_type_to_block_type(section.section_type),
        position: index,
        content_data: extract_content_from_section(section),
        original_section: section
      }
    end)
  end

  defp map_section_type_to_block_type(section_type) do
    case to_string(section_type) do
      "intro" -> :hero_card
      "media_showcase" -> :hero_card
      "experience" -> :experience_card
      "achievements" -> :achievement_card
      "skills" -> :skill_card
      "portfolio" -> :project_card
      "projects" -> :project_card
      "services" -> :service_card
      "testimonials" -> :testimonial_card
      "contact" -> :contact_card
      _ -> :text_card
    end
  end

  defp extract_content_from_section(section) do
    content = section.content || %{}

    case section.section_type do
      :intro ->
        %{
          title: section.title,
          subtitle: Map.get(content, "headline", ""),
          content: Map.get(content, "main_content", Map.get(content, "summary", "")),
          call_to_action: %{text: "Learn More", url: "#about"}
        }

      :media_showcase ->
        %{
          title: section.title,
          subtitle: Map.get(content, "description", ""),
          video_url: Map.get(content, "video_url"),
          background_type: "video"
        }

      :experience ->
        %{
          title: section.title,
          jobs: Map.get(content, "jobs", []),
          content: Map.get(content, "main_content", "")
        }

      :achievements ->
        %{
          title: section.title,
          achievements: Map.get(content, "achievements", []),
          content: Map.get(content, "main_content", ""),
          description: Map.get(content, "description", ""),
          awards: Map.get(content, "awards", [])
        }

      _ ->
        %{
          title: section.title,
          content: Map.get(content, "main_content", Map.get(content, "summary", "")),
          description: Map.get(content, "description", "")
        }
    end
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

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      current_user = Map.get(socket.assigns, :current_user, nil)

      visit_attrs = %{
        portfolio_id: portfolio.id,
        ip_address: get_client_ip(socket),
        user_agent: get_user_agent(socket),
        referrer: get_referrer(socket)
      }

      visit_attrs = if current_user do
        Map.put(visit_attrs, :user_id, current_user.id)
      else
        visit_attrs
      end

      Portfolios.create_portfolio_visit(visit_attrs)
    rescue
      _ -> :ok
    end
  end

  defp get_client_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> :inet.ntoa(address) |> to_string()
      _ -> "127.0.0.1"
    end
  end

  defp get_user_agent(socket) do
    get_connect_info(socket, :user_agent) || ""
  end

  defp get_referrer(socket) do
    get_connect_params(socket)["ref"]
  end

  defp generate_portfolio_css(portfolio) do
    customization = portfolio.customization || %{}

    primary_color = Map.get(customization, "primary_color", "#1e40af")
    accent_color = Map.get(customization, "accent_color", "#f59e0b")
    font_family = Map.get(customization, "font_family", "Inter")

    """
    :root {
      --primary-color: #{primary_color};
      --accent-color: #{accent_color};
      --font-family: #{font_family}, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }

    .portfolio-public-view {
      font-family: var(--font-family);
    }

    /* Dynamic Card Layout Styles */
    .dynamic-card-layout {
      /* Layout-specific styles will be injected by DynamicCardPublicRenderer */
    }

    /* Responsive utilities */
    @media (max-width: 768px) {
      .mobile-stack {
        flex-direction: column;
      }

      .mobile-full-width {
        width: 100%;
      }
    }
    """
  end

  defp extract_portfolio_description(portfolio) do
    description = portfolio.description || "Professional portfolio and showcase"
    String.slice(description, 0, 160)
  end

  defp extract_portfolio_og_image(portfolio) do
    # Try to find a hero image from portfolio media
    case get_portfolio_hero_image(portfolio) do
      nil -> "/images/default-portfolio-og.jpg"
      image_url -> image_url
    end
  end

  defp generate_canonical_url(portfolio) do
    FrestylWeb.Endpoint.url() <> "/p/#{portfolio.slug}"
  end

  defp generate_json_ld(portfolio) do
    Jason.encode!(%{
      "@context" => "https://schema.org",
      "@type" => "Person",
      "name" => portfolio.user.name || portfolio.title,
      "url" => generate_canonical_url(portfolio),
      "description" => portfolio.description || "Professional portfolio",
      "sameAs" => extract_social_links(portfolio)
    })
  end

  # Safe helpers
  defp render_section_content_safe(section) do
    content = Map.get(section, :content, %{})
    text = case content do
      %{"main_content" => text} when is_binary(text) -> text
      %{"summary" => text} when is_binary(text) -> text
      %{"description" => text} when is_binary(text) -> text
      %{"headline" => text} when is_binary(text) -> text
      _ -> "Section content..."
    end
    Phoenix.HTML.raw("<p>#{Phoenix.HTML.html_escape(text)}</p>")
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      Portfolios.track_portfolio_visit(portfolio, %{
        ip_address: get_connect_info(socket, :peer_data).address,
        user_agent: get_connect_info(socket, :user_agent)
      })
    rescue
      _ -> :ok
    end
  end

  defp can_view_portfolio?(portfolio, user) do
    portfolio.user_id == (user && user.id) || portfolio.visibility in [:public, :link_only]
  end

  defp valid_preview_token?(portfolio, token) do
    # Implement token validation logic
    String.length(token) > 0
  end

  # Placeholder implementations
  defp get_portfolio_hero_image(_portfolio), do: nil
  defp extract_social_links(_portfolio), do: []
  defp generate_download_url(_file_info), do: "#"
  defp generate_share_url(_portfolio, _platform), do: "#"
  defp find_portfolio_media(_portfolio, _media_id), do: nil
  defp send_portfolio_contact_message(_portfolio, _params), do: {:ok, :sent}

  # Layout rendering functions
  defp render_portfolio_layout(assigns) do
    # Use the customization layout setting
    layout = assigns[:portfolio_layout] || "minimal"

    case layout do
      "dashboard" -> render_dashboard_layout(assigns)
      "gallery" -> render_gallery_layout(assigns)
      "minimal" -> render_minimal_layout(assigns)
      _ -> render_minimal_layout(assigns)  # fallback
    end
  end


  # Safe value extraction function
  defp get_simple_value(content, keys) when is_list(keys) do
    Enum.find_value(keys, "", fn key ->
      case Map.get(content, key) do
        nil -> nil
        "" -> nil
        {:safe, safe_content} when is_binary(safe_content) ->
          String.trim(safe_content)
        {:safe, safe_content} when is_list(safe_content) ->
          safe_content |> Enum.join("") |> String.trim()
        {:safe, safe_content} ->
          "#{safe_content}" |> String.trim()
        value when is_binary(value) ->
          String.trim(value)
        value ->
          "#{value}" |> String.trim()
      end
      |> case do
        "" -> nil
        result -> result
      end
    end)
  end

  defp render_dashboard_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Dashboard Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <h1 class="text-3xl font-bold text-gray-900"><%= @portfolio.title %></h1>
          <p class="text-gray-600 mt-1"><%= @portfolio.description %></p>
        </div>
      </header>

      <!-- Dashboard Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
            <%= for section <- @sections do %>
              <section class="bg-white rounded-xl shadow-sm border p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-4"><%= section.title %></h2>
                <div class="prose max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>
          <div class="space-y-6">
            <div class="bg-white rounded-xl shadow-sm border p-6">
              <h3 class="font-semibold text-gray-900 mb-4">Info</h3>
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Sections:</span>
                  <span class="font-medium"><%= length(@sections) %></span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_gallery_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Gallery Header -->
      <header class="py-16 px-6 text-center">
        <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <p class="text-xl text-gray-600"><%= @portfolio.description %></p>
      </header>

      <!-- Gallery Content -->
      <main class="px-6 py-8">
        <div class="max-w-6xl mx-auto">
          <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
            <%= for section <- @sections do %>
              <section class="break-inside-avoid bg-gray-50 rounded-lg p-6 mb-8">
                <h2 class="text-lg font-semibold text-gray-900 mb-3"><%= section.title %></h2>
                <div class="text-gray-700">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_minimal_layout(assigns) do
    ~H"""
    <div class="min-h-screen bg-white">
      <!-- Minimal Header -->
      <header class="py-16 px-6 text-center border-b">
        <h1 class="text-4xl lg:text-6xl font-light text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <p class="text-xl text-gray-600 max-w-2xl mx-auto"><%= @portfolio.description %></p>
      </header>

      <!-- Minimal Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <div class="space-y-16">
          <%= for section <- @sections do %>
            <section class="border-b border-gray-100 pb-16 last:border-b-0">
              <h2 class="text-2xl font-light text-gray-900 mb-8"><%= section.title %></h2>
              <div class="prose prose-lg max-w-none text-gray-700">
                <%= render_section_content_safe(section) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  defp convert_section_to_content_blocks(section, position) do
    base_block = %{
      id: section.id,
      portfolio_id: section.portfolio_id,
      section_id: section.id,
      position: position,
      created_at: section.inserted_at || DateTime.utc_now(),
      updated_at: section.updated_at || DateTime.utc_now()
    }

    case section.section_type do
      "hero" ->
        [Map.merge(base_block, %{
          block_type: :hero_card,
          content_data: %{
            title: section.title,
            subtitle: section.content,
            background_image: get_section_media_url(section, :background),
            call_to_action: extract_cta_from_section(section)
          }
        })]

      "about" ->
        [Map.merge(base_block, %{
          block_type: :about_card,
          content_data: %{
            title: section.title,
            content: section.content,
            profile_image: get_section_media_url(section, :profile),
            highlights: extract_highlights_from_section(section)
          }
        })]

      "skills" ->
        skills = extract_skills_from_section(section)
        Enum.with_index(skills, fn skill, idx ->
          Map.merge(base_block, %{
            id: "#{section.id}_skill_#{idx}",
            block_type: :skill_card,
            position: position + (idx * 0.1),
            content_data: %{
              name: skill.name,
              proficiency: skill.level,
              category: skill.category,
              description: skill.description
            }
          })
        end)

      "portfolio" ->
        projects = extract_projects_from_section(section)
        Enum.with_index(projects, fn project, idx ->
          Map.merge(base_block, %{
            id: "#{section.id}_project_#{idx}",
            block_type: :project_card,
            position: position + (idx * 0.1),
            content_data: %{
              title: project.title,
              description: project.description,
              image_url: project.image_url,
              project_url: project.url,
              technologies: project.technologies || []
            }
          })
        end)

      "services" ->
        services = extract_services_from_section(section)
        Enum.with_index(services, fn service, idx ->
          Map.merge(base_block, %{
            id: "#{section.id}_service_#{idx}",
            block_type: :service_card,
            position: position + (idx * 0.1),
            content_data: %{
              title: service.title,
              description: service.description,
              price: service.price,
              features: service.features || [],
              booking_enabled: service.booking_enabled || false
            }
          })
        end)

      "testimonials" ->
        testimonials = extract_testimonials_from_section(section)
        Enum.with_index(testimonials, fn testimonial, idx ->
          Map.merge(base_block, %{
            id: "#{section.id}_testimonial_#{idx}",
            block_type: :testimonial_card,
            position: position + (idx * 0.1),
            content_data: %{
              content: testimonial.content,
              author: testimonial.author,
              title: testimonial.title,
              avatar_url: testimonial.avatar_url,
              rating: testimonial.rating
            }
          })
        end)

      "contact" ->
        [Map.merge(base_block, %{
          block_type: :contact_card,
          content_data: %{
            title: section.title,
            content: section.content,
            contact_methods: extract_contact_methods_from_section(section),
            show_form: true
          }
        })]

      _ ->
        # Default text block for any other section type
        [Map.merge(base_block, %{
          block_type: :text_card,
          content_data: %{
            title: section.title,
            content: section.content
          }
        })]
    end
  end

  defp organize_content_into_layout_zones(content_blocks, portfolio) do
    layout_category = determine_portfolio_category(portfolio)
    base_zones = get_base_zones_for_category(layout_category)

    Enum.reduce(content_blocks, base_zones, fn block, zones ->
      zone_name = determine_zone_for_block(block.block_type, layout_category)
      current_blocks = Map.get(zones, zone_name, [])
      Map.put(zones, zone_name, current_blocks ++ [block])
    end)
  end

  defp determine_portfolio_category(portfolio) do
    customization = portfolio.customization || %{}
    layout = Map.get(customization, "layout", portfolio.theme)

    case layout do
      "professional_service_provider" -> :service_provider
      "creative_portfolio_showcase" -> :creative_showcase
      "technical_expert_dashboard" -> :technical_expert
      "content_creator_hub" -> :content_creator
      "corporate_executive_profile" -> :corporate_executive
      theme when theme in ["professional_service", "consultant"] -> :service_provider
      theme when theme in ["creative", "designer", "artist"] -> :creative_showcase
      theme when theme in ["developer", "engineer", "tech"] -> :technical_expert
      _ -> :service_provider
    end
  end

  defp get_base_zones_for_category(category) do
    case category do
      :service_provider ->
        %{hero: [], about: [], services: [], experience: [], testimonials: [], contact: []}
      :creative_showcase ->
        %{hero: [], about: [], portfolio: [], skills: [], experience: [], contact: []}
      :technical_expert ->
        %{hero: [], about: [], skills: [], experience: [], projects: [], achievements: [], contact: []}
      :content_creator ->
        %{hero: [], about: [], content: [], social: [], monetization: [], contact: []}
      :corporate_executive ->
        %{hero: [], about: [], experience: [], achievements: [], leadership: [], contact: []}
    end
  end

  defp determine_zone_for_block(block_type, category) do
    case {block_type, category} do
      {:hero_card, _} -> :hero
      {:about_card, _} -> :about
      {:experience_card, _} -> :experience
      {:achievement_card, _} -> :achievements
      {:skill_card, :technical_expert} -> :skills
      {:skill_card, :creative_showcase} -> :skills
      {:project_card, :technical_expert} -> :projects
      {:project_card, :creative_showcase} -> :portfolio
      {:service_card, _} -> :services
      {:testimonial_card, _} -> :testimonials
      {:contact_card, _} -> :contact
      {_, _} -> :about # fallback
    end
  end

  defp get_portfolio_brand_settings(portfolio) do
    account = get_portfolio_account(portfolio)

    case account do
      %{id: nil} -> default_brand_settings()
      account ->
        case Frestyl.Accounts.BrandSettings.get_by_account(account.id) do
          nil -> default_brand_settings()
          brand_settings -> brand_settings
        end
    end
  rescue
    _ -> default_brand_settings()
  end

  defp is_portfolio_owner?(portfolio, nil), do: false
  defp is_portfolio_owner?(portfolio, current_user) do
    portfolio.user_id == current_user.id
  end

  # Helper functions for section data extraction
  defp determine_layout_category(portfolio) do
    case portfolio.theme do
      theme when theme in ["professional_service", "consultant", "freelancer"] -> :service_provider
      theme when theme in ["creative", "designer", "artist", "photographer"] -> :creative_showcase
      theme when theme in ["developer", "engineer", "tech", "technical"] -> :technical_expert
      theme when theme in ["creator", "influencer", "content", "media"] -> :content_creator
      _ -> :corporate_executive
    end
  end

  defp filter_blocks_by_type(content_blocks, types) do
    Enum.filter(content_blocks, fn block ->
      block.block_type in types
    end)
    |> Enum.sort_by(& &1.position)
  end

  defp get_section_media_url(section, type) do
    case section.media do
      media when is_list(media) ->
        media
        |> Enum.find(fn m -> m.media_type == to_string(type) end)
        |> case do
          nil -> nil
          media_item -> media_item.url
        end
      _ -> nil
    end
  end

  defp extract_cta_from_section(section) do
    case section.content do
      content when is_binary(content) ->
        %{text: "Get Started", url: "#contact"}
      _ -> nil
    end
  end

  defp extract_highlights_from_section(_section), do: []

  defp extract_skills_from_section(section) do
    case section.content do
      content when is_binary(content) ->
        [%{name: "Skill", level: "intermediate", category: "general", description: content}]
      _ -> []
    end
  end

  defp extract_projects_from_section(section) do
    [%{
      title: section.title || "Project",
      description: section.content || "",
      image_url: get_section_media_url(section, :image),
      url: nil,
      technologies: []
    }]
  end

  defp extract_services_from_section(section) do
    [%{
      title: section.title || "Service",
      description: section.content || "",
      price: nil,
      features: [],
      booking_enabled: false
    }]
  end

  defp extract_testimonials_from_section(section) do
    [%{
      content: section.content || "",
      author: "Client",
      title: "Customer",
      avatar_url: nil,
      rating: 5
    }]
  end

  defp extract_contact_methods_from_section(_section) do
    [%{type: "email", value: "contact@example.com", label: "Email"}]
  end
end
