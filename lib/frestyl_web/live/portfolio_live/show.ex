# lib/frestyl_web/live/portfolio_live/show.ex

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view
  import Phoenix.LiveView.Helpers
  import Phoenix.Controller, only: [get_csrf_token: 0]
  import Phoenix.HTML, only: [raw: 1, html_escape: 1]

  alias Frestyl.Portfolios
  alias Phoenix.PubSub

  alias FrestylWeb.PortfolioLive.EnhancedPortfolioEditor
  alias Frestyl.ResumeExporter
  alias FrestylWeb.PortfolioLive.Components.{EnhancedHeroRenderer,
    DynamicSectionModal,
    EnhancedSectionRenderer,

  }


  @impl true
  def mount(params, _session, socket) do
    IO.puts("🌍 MOUNTING PORTFOLIO SHOW with params: #{inspect(params)}")

    result = case params do
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
        IO.puts("❌ Invalid portfolio URL parameters")
        {:ok,
        socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}
    end

    case result do
      {:ok, socket} ->
        # Subscribe to ALL portfolio channels if connected and portfolio exists
        if connected?(socket) && socket.assigns[:portfolio] do
          portfolio_id = socket.assigns.portfolio.id
          IO.puts("🔄 SUBSCRIBING to portfolio channels: #{portfolio_id}")

          # Subscribe to ALL 4 channels for comprehensive coverage
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_show:#{portfolio_id}")
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_editor:#{portfolio_id}")

          IO.puts("✅ SUBSCRIBED to all portfolio channels")
        end
        {:ok, socket}
      error ->
        error
    end
  end


  defp mount_portfolio(portfolio, socket) do
    IO.puts("📁 MOUNTING PORTFOLIO DATA: #{portfolio.title}")

    # Subscribe to live updates from editor
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio.id}")
    end

    # Track portfolio visit safely
    track_portfolio_visit_safe(portfolio, socket)

    # Load portfolio sections safely
    sections = load_portfolio_sections_safe(portfolio.id)
    IO.puts("📋 Loaded #{length(sections)} sections")

    # Extract intro video if present
    {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(sections)

    # ENHANCED: Extract theme settings for enhanced components
    theme = portfolio.theme || "professional"
    customization = portfolio.customization || %{}
    layout_type = Map.get(customization, "layout", "standard")
    color_scheme = Map.get(customization, "color_scheme", "blue")

    # NEW: Extract video display settings
    video_aspect_ratio = Map.get(customization, "video_aspect_ratio", "16:9")
    video_display_mode = Map.get(customization, "video_display_mode", "original")

    # Create display options for video rendering
    video_display_options = %{
      aspect_ratio: video_aspect_ratio,
      display_mode: video_display_mode
    }

    # ENHANCED: Generate complete theme CSS using our enhanced system
    # Basic assignments with enhanced theme data
    socket = socket
    |> assign(:page_title, portfolio.title)
    |> assign(:portfolio, portfolio)
    |> assign(:owner, get_portfolio_owner_safe(portfolio))
    |> assign(:sections, filtered_sections)
    |> assign(:all_sections, sections)
    |> assign(:customization, customization)
    |> assign(:theme, theme)
    |> assign(:layout_type, layout_type)
    |> assign(:color_scheme, color_scheme)
    |> assign(:use_enhanced_display, true)  # FIXED: Enable enhanced display
    |> assign(:video_display_options, video_display_options)  # NEW: Video display settings

    |> assign(:intro_video, intro_video)
    |> assign(:intro_video_section, intro_video)
    |> assign(:has_intro_video, intro_video != nil)
    |> assign(:video_url, get_video_url_safe(intro_video))
    |> assign(:video_content, get_video_content_safe(intro_video))
    |> assign(:show_contact_modal, false)
    |> assign(:show_share_modal, false)
    |> assign(:show_export_modal, false)
    |> assign(:show_video_modal, false)
    |> assign(:show_mobile_nav, false)
    |> assign(:active_lightbox_media, nil)
    |> assign(:seo_title, portfolio.title)
    |> assign(:seo_image, "/images/default-portfolio.jpg")
    |> assign(:seo_description, portfolio.description || "Professional portfolio")
    |> assign(:canonical_url, "/p/#{portfolio.slug}")
    |> assign(:show_floating_actions, true)  # ADDED: Enable floating actions
    |> assign(:template_class, "template-#{theme}")  # ADDED: Template class
    |> assign(:public_view_settings, %{
      show_contact_info: true,
      show_social_links: true,
      show_download_resume: false,
      enable_animations: true,
      show_visitor_count: false,
      allow_comments: false,
      enable_back_to_top: true,
      sticky_header: true,
      show_progress_bar: true,
      enable_smooth_scroll: true
    })

    {:ok, socket}
  end

  defp mount_public_portfolio(slug, socket) do
    IO.puts("🌍 MOUNTING PUBLIC PORTFOLIO: /p/#{slug}")

    try do
      case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
        {:ok, portfolio} ->
          case mount_portfolio(portfolio, socket) do
            {:ok, updated_socket} ->
              {:ok, updated_socket
              |> assign(:view_type, :public)}
            error -> error
          end
        {:error, :not_found} ->
          {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
      end
    rescue
      _ ->
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  defp mount_shared_portfolio(token, socket) do
    IO.puts("🔗 MOUNTING SHARED PORTFOLIO: /share/#{token}")

    case load_portfolio_by_share_token(token) do
      {:ok, portfolio, share} ->
        # Track share visit
        track_share_visit_safe(portfolio, share, socket)

        # Use mount_portfolio/2 function, then add view_type and share
        case mount_portfolio(portfolio, socket) do
          {:ok, updated_socket} ->
            {:ok, updated_socket
            |> assign(:view_type, :shared)
            |> assign(:share, share)
            |> assign(:is_shared_view, true)}
          error -> error
        end

      {:error, :not_found} ->
        {:ok,
        socket
        |> put_flash(:error, "Invalid or expired share link")
        |> redirect(to: "/")}

      {:error, reason} ->
        IO.puts("❌ Shared portfolio loading error: #{inspect(reason)}")
        {:ok,
        socket
        |> put_flash(:error, "Unable to access shared portfolio")
        |> redirect(to: "/")}
    end
  end


  defp mount_preview_portfolio(id, token, socket) do
    IO.puts("👁️ MOUNTING PREVIEW PORTFOLIO: /preview/#{id}/#{token}")

    case load_portfolio_for_preview(id, token) do
      {:ok, portfolio} ->
        # Use mount_portfolio/2 function, then add view_type
        case mount_portfolio(portfolio, socket) do
          {:ok, updated_socket} ->
            {:ok, assign(updated_socket, :view_type, :preview)}
          error -> error
        end

      {:error, :invalid_token} ->
        {:ok,
        socket
        |> put_flash(:error, "Invalid preview token")
        |> redirect(to: "/")}

      {:error, reason} ->
        IO.puts("❌ Preview portfolio loading error: #{inspect(reason)}")
        {:ok,
        socket
        |> put_flash(:error, "Unable to load portfolio preview")
        |> redirect(to: "/")}
    end
  end

  defp mount_authenticated_portfolio(id, socket) do
    IO.puts("🔐 MOUNTING AUTHENTICATED PORTFOLIO: #{id}")

    user = socket.assigns.current_user
    case load_portfolio_by_id(id) do
      {:ok, portfolio} ->
        if can_view_portfolio?(portfolio, user) do
          # Use mount_portfolio/2 function, then add view_type
          case mount_portfolio(portfolio, socket) do
            {:ok, updated_socket} ->
              {:ok, assign(updated_socket, :view_type, :authenticated)}
            error -> error
          end
        else
          {:ok,
          socket
          |> put_flash(:error, "Access denied")
          |> redirect(to: "/")}
        end

      {:error, :not_found} ->
        {:ok,
        socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      # ADD THIS MISSING CASE:
      {:error, :database_error} ->
        {:ok,
        socket
        |> put_flash(:error, "Unable to load portfolio due to a database error")
        |> redirect(to: "/")}

      # ADD THIS CATCH-ALL CASE:
      {:error, reason} ->
        IO.puts("❌ Portfolio loading error: #{inspect(reason)}")
        {:ok,
        socket
        |> put_flash(:error, "Unable to load portfolio")
        |> redirect(to: "/")}
    end
  end

  defp mount_portfolio_safe(portfolio, socket) do
    if portfolio do
      mount_portfolio(portfolio, socket)
    else
      {:ok,
      socket
      |> put_flash(:error, "Portfolio not found")
      |> redirect(to: "/")}
    end
  end


# GROUP 6: Preview System Fix
# File: lib/frestyl_web/live/portfolio_live/show.ex
# Fix preview system to handle portfolio updates correctly

# Update the handle_info function to properly handle all message types
@impl true
def handle_info(msg, socket) do
  case msg do
    # Handle preview updates from editor
    {:preview_update, data} when is_map(data) ->
      IO.puts("🔄 SHOW: Handling preview_update")

      sections = Map.get(data, :sections, socket.assigns.sections)
      customization = Map.get(data, :customization, socket.assigns.customization)

      # Update socket with new data
      socket = socket
      |> assign(:sections, sections)
      |> assign(:customization, customization)
      |> push_event("update_preview_content", %{
        sections: sections,
        customization: customization
      })

      {:noreply, socket}

    # Handle section updates
    {:sections_updated, sections} ->
      IO.puts("🔄 SHOW: Handling sections_updated")

      socket = socket
      |> assign(:sections, sections)
      |> push_event("update_sections", %{sections: sections})

      {:noreply, socket}

    # Handle portfolio sections changed (comprehensive update)
    {:portfolio_sections_changed, data} when is_map(data) ->
      IO.puts("🔄 SHOW: Handling portfolio_sections_changed")

      sections = Map.get(data, :sections, socket.assigns.sections)
      customization = Map.get(data, :customization, socket.assigns.customization)

      socket = socket
      |> assign(:sections, sections)
      |> assign(:customization, customization)
      |> push_event("comprehensive_update", %{
        sections: sections,
        customization: customization
      })

      {:noreply, socket}

    # Handle customization updates
    {:customization_updated, customization} ->
      IO.puts("🔄 SHOW: Handling customization_updated")

      socket = socket
      |> assign(:customization, customization)
      |> push_event("update_css_variables", customization)

      {:noreply, socket}

    # Handle section visibility changes
    {:section_visibility_changed, data} when is_map(data) ->
      IO.puts("🔄 SHOW: Handling section_visibility_changed")

      sections = Map.get(data, :sections, socket.assigns.sections)

      socket = socket
      |> assign(:sections, sections)
      |> push_event("update_section_visibility", %{sections: sections})

      {:noreply, socket}

    # Handle design updates
    {:design_update, data} when is_map(data) ->
      IO.puts("🔄 SHOW: Handling design_update")
      handle_design_update(data, socket)

    {:design_complete_update, data} when is_map(data) ->
      IO.puts("🔄 SHOW: Handling design_complete_update")
      handle_design_update(data, socket)

    # Handle layout changes
    {:layout_changed, layout_name, customization} ->
      IO.puts("🔄 SHOW: Handling layout_changed")

      socket = socket
      |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
      |> assign(:customization, customization)
      |> push_event("layout_changed", %{layout: layout_name})

      {:noreply, socket}

    # Handle content updates for individual sections
    {:content_update, section} ->
      IO.puts("🔄 SHOW: Handling content_update")

      sections = update_section_in_list(socket.assigns.sections, section)

      socket = socket
      |> assign(:sections, sections)
      |> push_event("update_section_content", %{
        section_id: section.id,
        content: section.content
      })

      {:noreply, socket}

    # Handle portfolio updates (legacy)
    {:portfolio_updated, updated_portfolio} ->
      IO.puts("🔄 SHOW: Handling portfolio_updated")

      socket = socket
      |> assign(:portfolio, updated_portfolio)
      |> assign(:customization, updated_portfolio.customization || %{})

      {:noreply, socket}

    # Handle viewport changes
    {:viewport_change, mobile_view} ->
      socket = assign(socket, :mobile_view, mobile_view)
      {:noreply, socket}

    # Catch-all for unhandled messages
    unknown_msg ->
      IO.puts("⚠️ SHOW: Unhandled message: #{inspect(unknown_msg)}")
      {:noreply, socket}
  end
end

# Helper function to handle design updates
defp handle_design_update(design_data, socket) do
  IO.puts("🎨 SHOW PAGE processing design update")

  customization = Map.get(design_data, :customization, socket.assigns.customization)
  css = Map.get(design_data, :css, "")
  template_class = Map.get(design_data, :template_class, "template-professional-dashboard")

  socket = socket
  |> assign(:customization, customization)
  |> assign(:custom_css, css)
  |> assign(:template_class, template_class)
  |> push_event("apply_comprehensive_design", design_data)
  |> push_event("apply_portfolio_design", design_data)
  |> push_event("inject_design_css", %{css: css})
  |> push_event("update_css_variables", customization)

  {:noreply, socket}
end

# Ensure proper mount subscription to all channels
@impl true
def mount(params, _session, socket) do
  IO.puts("🌍 MOUNTING PORTFOLIO SHOW with params: #{inspect(params)}")

  result = case params do
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
      IO.puts("❌ Invalid portfolio URL parameters")
      {:ok,
      socket
      |> put_flash(:error, "Portfolio not found")
      |> redirect(to: "/")}
  end

  case result do
    {:ok, socket} ->
      # Subscribe to ALL portfolio channels if connected and portfolio exists
      if connected?(socket) && socket.assigns[:portfolio] do
        portfolio_id = socket.assigns.portfolio.id
        IO.puts("🔄 SUBSCRIBING to portfolio channels: #{portfolio_id}")

        # Subscribe to ALL 4 channels for comprehensive coverage
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_show:#{portfolio_id}")
        Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_editor:#{portfolio_id}")

        IO.puts("✅ SUBSCRIBED to all portfolio channels")
      end
      {:ok, socket}
    error ->
      error
  end
end

# Helper function to update section in list (if not already defined)
defp update_section_in_list(sections, updated_section) do
  Enum.map(sections, fn section ->
    if section.id == updated_section.id do
      updated_section
    else
      section
    end
  end)
end

# Add error handling for missing data
defp mount_portfolio_safe(portfolio, socket) do
  if portfolio do
    mount_portfolio(portfolio, socket)
  else
    {:ok,
    socket
    |> put_flash(:error, "Portfolio not found")
    |> redirect(to: "/")}
  end
end

# Enhanced error handling for portfolio loading
defp load_portfolio_safe(portfolio_id) do
  try do
    case Portfolios.get_portfolio_with_sections(portfolio_id) do
      {:ok, portfolio} -> portfolio
      {:error, :not_found} -> nil
      _ -> nil
    end
  rescue
    _ -> nil
  end
end

# Enhanced error handling for section loading
defp load_portfolio_sections_safe(portfolio_id) do
  try do
    case Portfolios.list_portfolio_sections(portfolio_id) do
      sections when is_list(sections) -> sections
      _ -> []
    end
  rescue
    _ -> []
  end
end

  defp can_view_portfolio_safe?(portfolio, user) do
    case portfolio.visibility do
      :public -> true
      :private -> user && portfolio.user_id == user.id
      _ -> false
    end
  end

  defp get_portfolio_owner(portfolio) do
    case portfolio do
      %{user: %Ecto.Association.NotLoaded{}} ->
        # Load user if not loaded
        try do
          portfolio = Repo.preload(portfolio, :user)
          portfolio.user
        rescue
          _ -> %{name: "Portfolio Owner", email: ""}
        end
      %{user: user} when not is_nil(user) ->
        user
      _ ->
        %{name: "Portfolio Owner", email: ""}
    end
  end

  @impl true
  def handle_info({:design_complete_update, design_data}, socket) do
    IO.puts("🎨 SHOW PAGE received comprehensive design update")

    template_class = Map.get(design_data, :template_class, "template-professional-dashboard")

    socket = socket
    |> assign(:customization, design_data.customization)
    |> assign(:custom_css, design_data.css)
    |> assign(:template_class, template_class)
    |> push_event("apply_comprehensive_design", design_data)
    |> push_event("apply_portfolio_design", design_data)
    |> push_event("inject_design_css", %{css: design_data.css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:update_portfolio_design, design_update}, socket) do
    IO.puts("🎨 SHOW: Received direct design update")

    # Update local state immediately for responsive UI
    updated_customization = Map.merge(socket.assigns.customization, design_update)

    {:noreply, socket
      |> assign(:customization, updated_customization)
      |> push_event("apply_portfolio_design", %{
        layout: Map.get(updated_customization, "layout_style", "single"),
        color_scheme: Map.get(updated_customization, "color_scheme", "professional"),
        customization: updated_customization
      })}
  end

  @impl true
  def handle_info({:design_update, design_data}, socket) do
    handle_info({:design_complete_update, design_data}, socket)
  end

  @impl true
  def handle_info(msg, socket) do
    case msg do
      # Handle preview updates from editor
      {:preview_update, data} when is_map(data) ->
        IO.puts("🔄 SHOW: Handling preview_update")

        sections = Map.get(data, :sections, socket.assigns.sections)
        customization = Map.get(data, :customization, socket.assigns.customization)

        # Update socket with new data
        socket = socket
        |> assign(:sections, sections)
        |> assign(:customization, customization)
        |> push_event("update_preview_content", %{
          sections: sections,
          customization: customization
        })

        {:noreply, socket}

      # Handle section updates
      {:sections_updated, sections} ->
        IO.puts("🔄 SHOW: Handling sections_updated")

        socket = socket
        |> assign(:sections, sections)
        |> push_event("update_sections", %{sections: sections})

        {:noreply, socket}

      # Handle portfolio sections changed (comprehensive update)
      {:portfolio_sections_changed, data} when is_map(data) ->
        IO.puts("🔄 SHOW: Handling portfolio_sections_changed")

        sections = Map.get(data, :sections, socket.assigns.sections)
        customization = Map.get(data, :customization, socket.assigns.customization)

        socket = socket
        |> assign(:sections, sections)
        |> assign(:customization, customization)
        |> push_event("comprehensive_update", %{
          sections: sections,
          customization: customization
        })

        {:noreply, socket}

      # Handle customization updates
      {:customization_updated, customization} ->
        IO.puts("🔄 SHOW: Handling customization_updated")

        socket = socket
        |> assign(:customization, customization)
        |> push_event("update_css_variables", customization)

        {:noreply, socket}

      # Handle section visibility changes
      {:section_visibility_changed, data} when is_map(data) ->
        IO.puts("🔄 SHOW: Handling section_visibility_changed")

        sections = Map.get(data, :sections, socket.assigns.sections)

        socket = socket
        |> assign(:sections, sections)
        |> push_event("update_section_visibility", %{sections: sections})

        {:noreply, socket}

      # Handle design updates
      {:design_update, data} when is_map(data) ->
        IO.puts("🔄 SHOW: Handling design_update")
        handle_design_update(data, socket)

      {:design_complete_update, data} when is_map(data) ->
        IO.puts("🔄 SHOW: Handling design_complete_update")
        handle_design_update(data, socket)

      # Handle layout changes
      {:layout_changed, layout_name, customization} ->
        IO.puts("🔄 SHOW: Handling layout_changed")

        socket = socket
        |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
        |> assign(:customization, customization)
        |> push_event("layout_changed", %{layout: layout_name})

        {:noreply, socket}

      # Handle content updates for individual sections
      {:content_update, section} ->
        IO.puts("🔄 SHOW: Handling content_update")

        sections = update_section_in_list(socket.assigns.sections, section)

        socket = socket
        |> assign(:sections, sections)
        |> push_event("update_section_content", %{
          section_id: section.id,
          content: section.content
        })

        {:noreply, socket}

      # Handle portfolio updates (legacy)
      {:portfolio_updated, updated_portfolio} ->
        IO.puts("🔄 SHOW: Handling portfolio_updated")

        socket = socket
        |> assign(:portfolio, updated_portfolio)
        |> assign(:customization, updated_portfolio.customization || %{})

        {:noreply, socket}

      # Handle viewport changes
      {:viewport_change, mobile_view} ->
        socket = assign(socket, :mobile_view, mobile_view)
        {:noreply, socket}

      # Catch-all for unhandled messages
      unknown_msg ->
        IO.puts("⚠️ SHOW: Unhandled message: #{inspect(unknown_msg)}")
        {:noreply, socket}
    end
  end

  defp handle_design_update(design_data, socket) do
    IO.puts("🎨 SHOW PAGE processing design update")

    customization = Map.get(design_data, :customization, socket.assigns.customization)
    css = Map.get(design_data, :css, "")
    template_class = Map.get(design_data, :template_class, "template-professional-dashboard")

    socket = socket
    |> assign(:customization, customization)
    |> assign(:custom_css, css)
    |> assign(:template_class, template_class)
    |> push_event("apply_comprehensive_design", design_data)
    |> push_event("apply_portfolio_design", design_data)
    |> push_event("inject_design_css", %{css: css})
    |> push_event("update_css_variables", customization)

    {:noreply, socket}
  end


  defp load_portfolio_by_slug(slug) do
    try do
      case Portfolios.get_portfolio_by_slug_with_sections(slug) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp load_portfolio_by_token(token) do
    try do
      case Portfolios.get_portfolio_by_share_token_simple(token) do
        {:ok, portfolio, _share} -> {:ok, portfolio}
        {:error, reason} -> {:error, reason}
      end
    rescue
      _ -> {:error, :not_found}
    end
  end

  defp load_portfolio_by_id(id) do
    try do
      case Portfolios.get_portfolio_with_sections(id) do
        nil -> {:error, :not_found}
        portfolio -> {:ok, portfolio}
      end
    rescue
      e ->
        IO.puts("❌ Error loading portfolio by id #{id}: #{inspect(e)}")
        {:error, :database_error}
    end
  end

  defp load_portfolio_for_preview(id, token) do
    try do
      expected_token = generate_preview_token(id)

      if token == expected_token do
        case Portfolios.get_portfolio_with_sections(id) do
          nil -> {:error, :not_found}
          portfolio -> {:ok, portfolio}
        end
      else
        {:error, :invalid_token}
      end
    rescue
      e ->
        IO.puts("❌ Error loading preview portfolio: #{inspect(e)}")
        {:error, :database_error}
    end
  end

  defp load_portfolio_by_slug_safe(slug) do
    IO.puts("🔍 Loading portfolio by slug: #{slug}")

    try do
      case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
        {:ok, portfolio} ->  # CHANGE: Handle the new tuple format
          # Ensure user is loaded
          portfolio = if Ecto.assoc_loaded?(portfolio.user) do
            portfolio
          else
            Frestyl.Repo.preload(portfolio, :user)
          end

          IO.puts("✅ Portfolio loaded: #{portfolio.title}")
          {:ok, portfolio}

        {:error, :not_found} ->  # CHANGE: Handle the error tuple
          IO.puts("❌ No portfolio found with slug: #{slug}")
          {:error, :not_found}

        {:error, reason} ->  # CHANGE: Handle other errors
          IO.puts("❌ Error from portfolio function: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        IO.puts("❌ Error loading portfolio by slug #{slug}: #{inspect(e)}")
        {:error, :database_error}
    end
  end


  defp load_portfolio_sections_safe(portfolio_id) do
    try do
      sections = Portfolios.list_portfolio_sections(portfolio_id)
      IO.puts("📋 Found #{length(sections)} sections for portfolio #{portfolio_id}")
      sections
    rescue
      e ->
        IO.puts("❌ Error loading sections for portfolio #{portfolio_id}: #{inspect(e)}")
        []
    end
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

  defp ensure_sections_assigned(socket, portfolio) do
    # Safely extract sections from portfolio
    sections = case portfolio do
      %{sections: sections} when is_list(sections) ->
        sections
      %{sections: %Ecto.Association.NotLoaded{}} ->
        # Load sections if not loaded
        load_portfolio_sections_safe(portfolio.id)
      _ ->
        # Load sections if missing
        load_portfolio_sections_safe(portfolio.id)
    end

    # Always assign sections to socket - this prevents the KeyError
    assign(socket, :sections, sections || [])
  end

  defp load_portfolio_sections_safe(portfolio_id) do
    try do
      Portfolios.list_portfolio_sections(portfolio_id)
    rescue
      _ -> []
    end
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

  defp get_color_scheme_safe(customization) do
    %{
      primary: Map.get(customization, "primary_color", "#3b82f6"),
      secondary: Map.get(customization, "secondary_color", "#64748b"),
      accent: Map.get(customization, "accent_color", "#f59e0b")
    }
  end

  defp get_color_scheme_name(scheme) do
    case scheme do
      "blue" -> "Ocean Blue"
      "green" -> "Forest Green"
      "purple" -> "Royal Purple"
      "red" -> "Warm Red"
      "orange" -> "Sunset Orange"
      "teal" -> "Modern Teal"
      _ -> "Ocean Blue"
    end
  end

  defp get_modal_video_classes(video_display_options) do
    aspect_ratio = Map.get(video_display_options, :aspect_ratio, "16:9")

    case aspect_ratio do
      "16:9" -> "aspect-video bg-black rounded-lg overflow-hidden"
      "9:16" -> "aspect-[9/16] bg-black rounded-lg overflow-hidden max-h-[80vh]"
      "1:1" -> "aspect-square bg-black rounded-lg overflow-hidden max-w-[80vh]"
      _ -> "aspect-video bg-black rounded-lg overflow-hidden"
    end
  end

  defp get_modal_video_object_fit(video_display_options) do
    display_mode = Map.get(video_display_options, :display_mode, "original")

    case display_mode do
      "original" -> "object-contain"
      "crop_" <> _ -> "object-cover"
      _ -> "object-contain"  # Default to contain for modals to ensure full video is visible
    end
  end

  defp extract_intro_video_and_filter_sections(sections) do
    intro_section = Enum.find(sections, fn section ->
      section.section_type == "intro" &&
      get_in(section, [:content, "video_url"])
    end)

    case intro_section do
      nil ->
        {nil, sections}
      section ->
        # Preserve video display settings in the intro video data
        enhanced_section = %{section |
          content: Map.merge(section.content || %{}, %{
            "preserved_aspect_ratio" => Map.get(section.content || %{}, "video_aspect_ratio"),
            "preserved_display_mode" => Map.get(section.content || %{}, "video_display_mode")
          })
        }

        filtered_sections = Enum.reject(sections, &(&1.id == section.id))
        {enhanced_section, filtered_sections}
    end
  end

  defp get_video_url_safe(nil), do: nil
  defp get_video_url_safe(intro_video), do: Map.get(intro_video, :url)

  defp get_video_content_safe(nil), do: nil
  defp get_video_content_safe(intro_video), do: intro_video

  defp is_portfolio_public?(portfolio) do
    case portfolio.visibility do
      :public -> true
      "public" -> true
      _ -> false
    end
  end

  defp can_view_portfolio?(portfolio, user) do
    cond do
      user && portfolio.user_id == user.id -> true
      is_portfolio_public?(portfolio) -> true
      true -> false
    end
  end

  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      current_user = Map.get(socket.assigns, :current_user, nil)

      # SAFER: Handle nil peer_data
      peer_data = get_connect_info(socket, :peer_data)
      ip_address = case peer_data do
        %{address: address} when address != nil ->
          :inet.ntoa(address) |> to_string()
        _ ->
          "127.0.0.1"  # Default fallback
      end

      user_agent = get_connect_info(socket, :user_agent) || ""

      # SAFER: Handle nil connect_params
      connect_params = get_connect_params(socket)
      referrer = if is_map(connect_params), do: Map.get(connect_params, "ref"), else: nil

      visit_attrs = %{
        portfolio_id: portfolio.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: referrer
      }

      visit_attrs = if current_user do
        Map.put(visit_attrs, :user_id, current_user.id)
      else
        visit_attrs
      end

      Portfolios.create_visit(visit_attrs)
      IO.puts("📊 Portfolio visit tracked")
    rescue
      e ->
        IO.puts("❌ Error tracking portfolio visit: #{inspect(e)}")
        :ok
    end
  end

  defp track_share_visit_safe(portfolio, share, socket) do
    try do
      ip_address = get_connect_info(socket, :peer_data)
                  |> Map.get(:address, {127, 0, 0, 1})
                  |> :inet.ntoa()
                  |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      visit_attrs = %{
        portfolio_id: portfolio.id,
        share_id: share.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
      }

      Portfolios.create_visit(visit_attrs)
      IO.puts("📊 Share visit tracked")
    rescue
      e ->
        IO.puts("❌ Error tracking share visit: #{inspect(e)}")
        :ok
    end
  end

  defp generate_preview_token(portfolio_id) do
    :crypto.hash(:sha256, "preview_#{portfolio_id}_#{Date.utc_today()}")
    |> Base.encode16(case: :lower)
  end

  defp get_portfolio_owner_safe(portfolio) do
    if Ecto.assoc_loaded?(portfolio.user) do
      portfolio.user
    else
      try do
        Frestyl.Repo.preload(portfolio, :user).user
      rescue
        _ -> %{name: "Portfolio Owner", email: ""}
      end
    end
  end

  defp can_view_portfolio?(portfolio, user) do
    cond do
      user && portfolio.user_id == user.id -> true
      is_portfolio_public?(portfolio) -> true
      true -> false
    end
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

  def handle_event("open_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, true)}
  end

  def handle_event("close_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, false)}
  end

  # Handle live updates from editor
  def handle_info({:portfolio_updated, portfolio_id, _sections, customization, _type}, socket) do
    if socket.assigns.portfolio.id == portfolio_id do
      # Update video display options when portfolio is updated
      video_aspect_ratio = Map.get(customization, "video_aspect_ratio", "16:9")
      video_display_mode = Map.get(customization, "video_display_mode", "original")

      video_display_options = %{
        aspect_ratio: video_aspect_ratio,
        display_mode: video_display_mode
      }

      {:noreply, socket
        |> assign(:customization, customization)
        |> assign(:video_display_options, video_display_options)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:design_complete_update, design_data}, socket) do
    IO.puts("🎨 SHOW PAGE received comprehensive design update")

    template_class = Map.get(design_data, :template_class, "template-professional-dashboard")

    socket = socket
    |> assign(:customization, design_data.customization)
    |> assign(:custom_css, design_data.css)
    |> assign(:template_class, template_class)
    |> push_event("apply_comprehensive_design", design_data)
    |> push_event("apply_portfolio_design", design_data)
    |> push_event("inject_design_css", %{css: design_data.css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:design_update, design_data}, socket) do
    handle_info({:design_complete_update, design_data}, socket)
  end


  # ============================================================================
  # LIVE UPDATE HANDLERS (from editor)
  # ============================================================================

  @impl true
  def handle_info({:layout_changed, layout_name, customization}, socket) do
    # Generate new CSS with the layout change
    socket = socket
    |> assign(:portfolio_layout, Map.get(customization, "layout", "minimal"))
    |> assign(:customization, customization)

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
  def handle_info({:viewport_change, mobile_view}, socket) do
    socket = assign(socket, :mobile_view, mobile_view)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:design_update, data}, socket) do
    {:noreply, socket
    |> assign(:customization, data.customization)
    |> assign(:portfolio, data.portfolio)}
  end

  @impl true
  def handle_info({:preview_update, data}, socket) when is_map(data) do
    IO.puts("🔄 SHOW: preview_update received with #{map_size(data)} fields")

    sections = Map.get(data, :sections, socket.assigns.sections)
    customization = Map.get(data, :customization, socket.assigns.customization)

    IO.puts("🔄 SHOW: Updating #{length(sections)} sections")
    IO.puts("🔄 SHOW: Customization keys: #{inspect(Map.keys(customization))}")

    {:noreply, socket
    |> assign(:sections, sections)
    |> assign(:customization, customization)

    |> push_event("portfolio_updated", %{
      sections: sections,
      customization: customization,

    })}
  end


  @impl true
  def handle_info({:sections_updated, sections}, socket) do
    IO.puts("🔄 SHOW: sections_updated received - #{length(sections)} sections")
    {:noreply, assign(socket, :sections, sections)}
  end

  @impl true
  def handle_info({:portfolio_sections_changed, data}, socket) do
    IO.puts("🔄 SHOW: portfolio_sections_changed received")

    sections = Map.get(data, :sections, socket.assigns.sections)
    customization = Map.get(data, :customization, socket.assigns.customization)

    {:noreply, socket
    |> assign(:sections, sections)
    |> assign(:customization, customization)
    |> push_event("apply_portfolio_design", %{
      layout: Map.get(customization, "layout_style", "mobile_single"),
      color_scheme: Map.get(customization, "color_scheme", "blue"),
      customization: customization
    })}
  end

  def render(assigns) do
    # Extract layout settings with proper defaults
    layout_style = Map.get(assigns.customization, "layout_style", "single")
    color_scheme = Map.get(assigns.customization, "color_scheme", "professional")
    typography = Map.get(assigns.customization, "typography", "sans")

    IO.puts("🎨 SHOW RENDER: Layout=#{layout_style}, Color=#{color_scheme}, Typography=#{typography}")

    ~H"""
    <div class="portfolio-show">
      <!-- Dynamic CSS Variables -->
      <style id="portfolio-dynamic-css" phx-update="replace">
        :root {
          --primary-color: <%= Map.get(@customization, "primary_color", "#1e40af") %>;
          --secondary-color: <%= Map.get(@customization, "secondary_color", "#3b82f6") %>;
          --accent-color: <%= Map.get(@customization, "accent_color", "#60a5fa") %>;
          --font-family: <%= get_typography_css(typography) %>;
        }

        body {
          font-family: var(--font-family);
        }
      </style>

      <!-- Enhanced Layout Rendering - FIXED: Check if function exists with 6 parameters -->
      <%= if function_exported?(FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer, :render_portfolio_layout, 6) do %>
        <%= raw(
          FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer.render_portfolio_layout(
            @portfolio,
            @sections,
            layout_style,
            color_scheme,
            typography,
            @video_display_options
          )
        ) %>
      <% else %>
        <!-- Fallback: Call without video display options -->
        <%= raw(
          FrestylWeb.PortfolioLive.Components.EnhancedLayoutRenderer.render_portfolio_layout(
            @portfolio,
            @sections,
            layout_style,
            color_scheme,
            typography
          )
        ) %>
      <% end %>

      <!-- Video Introduction Modal with Aspect Ratio Support -->
      <%= if @show_video_modal && @intro_video do %>
        <div class="fixed inset-0 bg-black bg-opacity-75 flex items-center justify-center z-50"
            phx-click="close_video_modal">
          <div class="relative max-w-4xl w-full mx-4" phx-click="ignore">
            <button phx-click="close_video_modal"
                    class="absolute -top-12 right-0 text-white hover:text-gray-300 transition-colors">
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>

            <div class={"video-modal-container #{get_modal_video_classes(@video_display_options)}"}>
              <video controls autoplay class={"w-full h-full #{get_modal_video_object_fit(@video_display_options)}"}>
                <source src={@video_url} type="video/mp4">
                <source src={@video_url} type="video/webm">
                Your browser does not support the video tag.
              </video>
            </div>
          </div>
        </div>
      <% end %>

      <!-- Contact Modal -->
      <%= if Map.get(assigns, :show_contact_modal, false) do %>
        <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
            phx-click="close_contact_modal">
          <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4" phx-click-away="close_contact_modal">
            <h3 class="text-lg font-bold mb-4">Get in Touch</h3>
            <p class="text-gray-600 mb-4">Ready to discuss your project?</p>

            <form phx-submit="send_contact_message">
              <div class="space-y-4">
                <input type="text" name="name" placeholder="Your Name" required
                      class="w-full p-3 border rounded-lg">
                <input type="email" name="email" placeholder="Your Email" required
                      class="w-full p-3 border rounded-lg">
                <textarea name="message" placeholder="Your Message" rows="4" required
                          class="w-full p-3 border rounded-lg"></textarea>
              </div>
              <div class="flex justify-end space-x-3 mt-6">
                <button type="button" phx-click="close_contact_modal"
                        class="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded-lg">
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
      <% end %>
    </div>
    """
  end

  defp get_typography_css(typography) do
    case typography do
      "sans" -> "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif"
      "serif" -> "'Crimson Text', 'Times New Roman', serif"
      "mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      _ -> "-apple-system, BlinkMacSystemFont, 'Inter', sans-serif"
    end
  end

  defp get_layout_css("mobile_single"), do: "display: flex; flex-direction: column; gap: 1.5rem;"
  defp get_layout_css("grid_uniform"), do: "display: grid; grid-template-columns: repeat(2, 1fr); gap: 1.5rem;"
  defp get_layout_css("dashboard"), do: "display: grid; grid-template-columns: 2fr 1fr; gap: 1.5rem;"
  defp get_layout_css("creative_modern"), do: "display: grid; grid-template-columns: 1fr 1fr; gap: 2rem;"
  defp get_layout_css(_), do: "display: flex; flex-direction: column; gap: 1.5rem;"

  defp get_section_spacing("compact"), do: "0.75rem"
  defp get_section_spacing("normal"), do: "1.5rem"
  defp get_section_spacing("spacious"), do: "3rem"
  defp get_section_spacing(_), do: "1.5rem"

  defp get_border_radius("sharp"), do: "0"
  defp get_border_radius("rounded"), do: "0.5rem"
  defp get_border_radius("very-rounded"), do: "1.25rem"
  defp get_border_radius(_), do: "0.5rem"

  # ============================================================================
  # RENDER HELPERS
  # ============================================================================


  defp render_floating_actions(assigns) do
    ~H"""
    <div class="fixed bottom-6 right-6 z-40 space-y-3">
      <!-- Back to Top -->
      <%= if Map.get(assigns, :enable_back_to_top, true) do %>
        <button onclick="window.scrollTo({top: 0, behavior: 'smooth'})"
                class="w-12 h-12 bg-white shadow-lg rounded-full flex items-center justify-center hover:bg-gray-50 transition-all duration-200"
                title="Back to top">
          <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 10l7-7m0 0l7 7m-7-7v18"/>
          </svg>
        </button>
      <% end %>
    </div>
    """
  end

  defp render_export_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
        phx-click="hide_export_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
          phx-click="prevent_close">
        <div class="p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Export Portfolio</h3>
          <div class="space-y-4">
            <p class="text-gray-600">Export your portfolio in various formats.</p>
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
    """
  end

  defp render_share_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
        phx-click="hide_share_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
          phx-click="prevent_close">
        <div class="p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Share Portfolio</h3>
          <div class="space-y-4">
            <p class="text-gray-600">Share your portfolio with others.</p>
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
    """
  end

  defp render_contact_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"
        phx-click="hide_contact_modal">
      <div class="bg-white rounded-lg shadow-xl max-w-md w-full mx-4"
          phx-click="prevent_close">
        <div class="p-6">
          <h3 class="text-lg font-semibold text-gray-900 mb-4">Contact</h3>
          <div class="space-y-4">
            <p class="text-gray-600">Get in touch.</p>
            <div class="flex justify-end space-x-3">
              <button phx-click="hide_contact_modal"
                      class="px-4 py-2 text-gray-600 hover:text-gray-800">
                Close
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_lightbox(assigns) do
    ~H"""
    <div class="fixed inset-0 bg-black bg-opacity-90 flex items-center justify-center z-50"
        phx-click="hide_lightbox">
      <div class="relative max-w-7xl max-h-full p-4">
        <button class="absolute top-4 right-4 z-10 w-10 h-10 bg-white bg-opacity-20 rounded-full flex items-center justify-center text-white hover:bg-opacity-30"
                phx-click="hide_lightbox">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
        <div class="lightbox-content">
          <p class="text-white text-center">Lightbox content</p>
        </div>
      </div>
    </div>
    """
  end

  defp render_section_content(section, _color_scheme \\ "blue") do
    try do
      render_basic_section_content(section)
      |> raw()
    rescue
      _ ->
        raw("<p>Content loading...</p>")
    end
  end


  defp render_basic_section_content(section) do
    content = Map.get(section, :content, %{})

    case section.section_type do
      "experience" ->
        jobs = Map.get(content, "jobs", [])
        if length(jobs) > 0 do
          job_html = Enum.map(jobs, fn job ->
            title = Map.get(job, "title", "Position")
            company = Map.get(job, "company", "Company")
            "<div style='margin-bottom: 1rem;'><strong>#{title}</strong> at #{company}</div>"
          end) |> Enum.join("")
          "<div>#{job_html}</div>"
        else
          "<p>Work experience information</p>"
        end

      "skills" ->
        skills = Map.get(content, "skills", [])
        if length(skills) > 0 do
          skill_html = Enum.map(skills, fn skill ->
            skill_name = if is_map(skill), do: Map.get(skill, "name", skill), else: skill
            "<span style='display: inline-block; background: #e5e7eb; padding: 0.25rem 0.5rem; margin: 0.25rem; border-radius: 0.25rem;'>#{skill_name}</span>"
          end) |> Enum.join("")
          "<div>#{skill_html}</div>"
        else
          "<p>Skills and expertise</p>"
        end

      _ ->
        # Generic content rendering
        main_content = Map.get(content, "main_content") ||
                      Map.get(content, "description") ||
                      Map.get(content, "summary") ||
                      "Section content"
        "<p>#{main_content}</p>"
    end
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


  defp safe_capitalize(value) when is_atom(value) do
    value |> Atom.to_string() |> String.capitalize()
  end

  defp safe_capitalize(value) when is_binary(value) do
    String.capitalize(value)
  end

  defp safe_capitalize(_), do: "Section"

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
  # HELPER FUNCTIONS
  # ============================================================================



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




  defp assign_seo_data(socket, portfolio) do
    socket
    |> assign(:page_title, portfolio.title)
    |> assign(:meta_description, portfolio.description || "")
    |> assign(:meta_image, get_portfolio_meta_image(portfolio))
  end

  defp get_portfolio_meta_image(portfolio) do
    # Extract first image from sections or use default
    case portfolio do
      %{sections: sections} when is_list(sections) ->
        find_first_image_in_sections(sections)
      _ ->
        "/images/default-portfolio-preview.jpg"
    end
  end

  defp find_first_image_in_sections(sections) do
    sections
    |> Enum.find_value(fn section ->
      case get_in(section, [:content, "image_url"]) do
        nil -> nil
        url when is_binary(url) -> url
      end
    end) || "/images/default-portfolio-preview.jpg"
  end

  defp get_section_spacing(spacing) do
    case spacing do
      "compact" -> "1rem"
      "normal" -> "1.5rem"
      "spacious" -> "3rem"
      _ -> "1.5rem"
    end
  end

  defp get_border_radius(radius) do
    case radius do
      "sharp" -> "0"
      "rounded" -> "0.5rem"
      "very-rounded" -> "1rem"
      _ -> "0.5rem"
    end
  end

  # ============================================================================
  # PORTFOLIO DATA LOADING
  # ============================================================================


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
      case Portfolios.get_share_by_token(token) do
        nil -> {:error, :not_found}
        share ->
          case Portfolios.get_portfolio_with_sections(share.portfolio_id) do
            nil -> {:error, :not_found}
            portfolio -> {:ok, portfolio, share}
          end
      end
    rescue
      e ->
        IO.puts("❌ Error loading shared portfolio: #{inspect(e)}")
        {:error, :database_error}
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

  defp generate_design_tokens(portfolio) do
    customization = Map.get(portfolio, :customization, %{})

    %{
      primary_color: Map.get(customization, "primary_color", "#1e40af"),
      accent_color: Map.get(customization, "accent_color", "#f59e0b"),
      font_family: Map.get(customization, "font_family", "Inter")
    }
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



  defp has_hero_section?(sections) do
    Enum.any?(sections, &(&1.section_type == "hero"))
  end

  defp filter_non_hero_sections(sections) do
    Enum.reject(sections, &(&1.section_type == "hero"))
  end

  defp get_section_content_map(section) do
    case section do
      %{content: content} when is_map(content) -> content
      _ -> %{}
    end
  end

  # Safe video content extraction
  defp get_video_content_safe(intro_video) do
    case intro_video do
      %{content: content} when is_map(content) -> content
      _ -> %{}
    end
  end

  # Safe video URL extraction
  defp get_video_url_safe(intro_video) do
    case intro_video do
      %{content: %{"video_url" => url}} when is_binary(url) -> url
      _ -> nil
    end
  end

  # Format video duration
  defp format_video_duration(seconds) when is_integer(seconds) and seconds > 0 do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(to_string(remaining_seconds), 2, "0")}"
  end

  defp format_video_duration(_), do: "0:00"

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


  defp is_portfolio_public?(portfolio) do
    case portfolio.visibility do
      :public -> true
      "public" -> true
      _ -> false
    end
  end

  defp safe_to_string({:safe, content}), do: content
  defp safe_to_string(content) when is_binary(content), do: content
  defp safe_to_string(content), do: to_string(content)

  # Basic HTML stripping
  defp strip_html_basic(html) when is_binary(html) do
    html
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&\w+;/, " ")
    |> String.trim()
  end

  defp strip_html_basic(content), do: to_string(content)

  # Safe section type getter
  defp safe_section_type(section_type) do
    try do
      case section_type do
        atom when is_atom(atom) -> atom |> Atom.to_string() |> String.capitalize()
        string when is_binary(string) -> String.capitalize(string)
        _ -> "Section"
      end
    rescue
      _ -> "Section"
    end
  end
end
