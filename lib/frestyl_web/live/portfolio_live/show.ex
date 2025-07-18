# lib/frestyl_web/live/portfolio_live/show.ex

defmodule FrestylWeb.PortfolioLive.Show do
  use FrestylWeb, :live_view
  import Phoenix.LiveView.Helpers
  import Phoenix.Controller, only: [get_csrf_token: 0]
  import Phoenix.HTML, only: [raw: 1, html_escape: 1]

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Phoenix.PubSub

  alias FrestylWeb.PortfolioLive.{PorfolioEditorFixed}
  alias Frestyl.ResumeExporter

  alias FrestylWeb.PortfolioLive.Components.{
    EnhancedContentRenderer,
    EnhancedLayoutRenderer,
    EnhancedHeroRenderer,
    ThemeConsistencyManager,
    EnhancedSectionCards
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
        if connected?(socket) && socket.assigns[:portfolio] do
          portfolio_id = socket.assigns.portfolio.id
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_preview:#{portfolio_id}")
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio:#{portfolio_id}")
          Phoenix.PubSub.subscribe(Frestyl.PubSub, "portfolio_show:#{portfolio_id}")
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

    # ENHANCED: Generate complete theme CSS using our enhanced system
    complete_css = try do
      # Build theme settings structure expected by ThemeConsistencyManager
      theme_settings = %{
        theme: theme,
        layout: layout_type,
        color_scheme: color_scheme,
        customization: customization,
        portfolio: portfolio,
        # ADD THE MISSING COLORS KEY:
        colors: %{
          primary: Map.get(customization, "primary_color", "#7c3aed"),
          secondary: Map.get(customization, "secondary_color", "#ec4899"),
          accent: Map.get(customization, "accent_color", "#f59e0b"),
          background: "#ffffff",
          text: "#1f2937"
        },
        # ADD ADDITIONAL REQUIRED KEYS:
        theme_config: %{
          typography: %{
            font_family: "Inter, system-ui, sans-serif",
            heading_weight: "font-semibold",
            body_weight: "font-normal"
          },
          spacing: %{
            section_gap: "space-y-16",
            card_padding: "p-6"
          },
          borders: %{
            radius: "rounded-xl",
            card_border: "border border-gray-200"
          },
          # ADD THE MISSING SHADOWS:
          shadows: %{
            card: "shadow-lg",
            hover: "hover:shadow-xl",
            subtle: "shadow-sm"
          },
          # ADD ANIMATIONS TOO (likely needed):
          animations: %{
            transition: "transition-all duration-300",
            hover_scale: "hover:scale-[1.02]",
            button_transition: "transition-colors duration-200"
          }
        },
        layout_config: %{
          container_max_width: "max-w-4xl",
          grid_columns: "single-column",
          card_height: "auto",
          section_spacing: "space-y-16"
        },
        color_config: %{
          primary: Map.get(customization, "primary_color", "#7c3aed"),
          secondary: Map.get(customization, "secondary_color", "#ec4899"),
          accent: Map.get(customization, "accent_color", "#f59e0b"),
          name: get_color_scheme_name(color_scheme),
          css_class_prefix: color_scheme
        }
      }

      ThemeConsistencyManager.generate_complete_theme_css(theme_settings)
    rescue
      error ->
        IO.puts("⚠️ Theme CSS generation failed: #{inspect(error)}")
        # Fallback to basic CSS generation
        generate_basic_portfolio_css(portfolio)
    end

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
    |> assign(:complete_theme_css, complete_css)
    |> assign(:custom_css, complete_css)  # Backwards compatibility
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
  def handle_info({:design_update, design_data}, socket) do
    handle_info({:design_complete_update, design_data}, socket)
  end

  @impl true
def handle_info(msg, socket) do
  IO.puts("🔥 LivePreview received unhandled message: #{inspect(msg)}")
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

  defp extract_intro_video_and_filter_sections(sections) do
    intro_video_section = Enum.find(sections, fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)

    filtered_sections = if intro_video_section do
      Enum.reject(sections, &(&1.id == intro_video_section.id))
    else
      sections
    end

    intro_video = if intro_video_section do
      content = intro_video_section.content || %{}
      %{
        url: Map.get(content, "video_url"),
        duration: Map.get(content, "duration"),
        title: Map.get(content, "title", "Personal Introduction"),
        description: Map.get(content, "description"),
        filename: Map.get(content, "video_filename")
      }
    else
      nil
    end

    {intro_video, filtered_sections}
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

  # Handle live updates from editor
  @impl true
  def handle_info({:portfolio_updated, updated_portfolio}, socket) do
    if updated_portfolio.id == socket.assigns.portfolio.id do
      socket = socket
      |> assign(:portfolio, updated_portfolio)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:design_complete_update, design_data}, socket) do
    IO.puts("🎨 Received design update in show.ex: theme=#{design_data.theme}, layout=#{design_data.layout}, colors=#{design_data.color_scheme}")

    # Apply the CSS update to the live view
    socket = socket
    |> push_event("apply_portfolio_design", design_data)
    |> push_event("inject_design_css", %{css: design_data.css})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:design_update, data}, socket) do
    # Handle legacy design update format
    IO.puts("🎨 Received legacy design update")
    {:noreply, socket}
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
  def handle_info({:viewport_change, mobile_view}, socket) do
    socket = assign(socket, :mobile_view, mobile_view)
    {:noreply, socket}
  end

 @impl true
  def render(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en" class="scroll-smooth">
      <head>
        <%= render_seo_meta(assigns) %>
        <style id="portfolio-server-css"><%= raw(@complete_theme_css || @custom_css || "") %></style>
        <style id="portfolio-base-styles">
          .portfolio-section {
            scroll-margin-top: 2rem;
            transition: transform 0.2s ease !important;
          }

          .portfolio-section:hover {
            transform: translateY(-2px);
          }

          /* Ensure our styles have priority over any app.css */
          .portfolio-container,
          .portfolio-public-view,
          body.portfolio-public-view {
            isolation: isolate !important;
            position: relative !important;
            z-index: 1 !important;
          }

          /* Base responsive layout */
          @media (max-width: 768px) {
            .portfolio-container {
              padding: 1rem !important;
            }

            .portfolio-section {
              margin-bottom: 1rem !important;
              padding: 1.5rem !important;
            }
          }
        </style>
        <script phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      </head>

      <body class="portfolio-public-view bg-gray-50">
        <!-- Enhanced CSS Update Handler -->
        <script>
          // Handle comprehensive design updates
          window.addEventListener('phx:apply_comprehensive_design', (e) => {
            console.log('🎨 APPLYING DESIGN UPDATE:', e.detail);

            // Remove old CSS
            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            // Inject new CSS
            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css;
            document.head.appendChild(style);

            // Update body class with template
            document.body.className = `portfolio-public-view ${e.detail.template_class}`;

            // Update container classes
            const container = document.querySelector('.portfolio-container');
            if (container) {
              container.className = `portfolio-container ${e.detail.template_class} min-h-screen`;
            }

            console.log('✅ Design applied successfully');
          });

          // Handle portfolio design updates
          window.addEventListener('phx:apply_portfolio_design', (e) => {
            console.log('🎨 APPLYING PORTFOLIO DESIGN:', e.detail);

            // Remove old CSS
            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            // Inject new CSS
            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css;
            document.head.appendChild(style);
          });

          // Handle CSS injection
          window.addEventListener('phx:inject_design_css', (e) => {
            console.log('🎨 INJECTING CSS:', e.detail);

            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css;
            document.head.appendChild(style);
          });
        </script>

        <!-- Portfolio Content -->
        <div class="portfolio-container min-h-screen">
          <%= render_traditional_public_view(assigns) %>
        </div>

        <!-- Floating Action Buttons -->
        <%= if Map.get(assigns, :show_floating_actions, true) do %>
          <%= render_floating_actions(assigns) %>
        <% end %>

        <!-- Modals - Only render if assigns exist -->
        <%= if Map.get(assigns, :show_export_modal, false) do %>
          <%= render_export_modal(assigns) %>
        <% end %>

        <%= if Map.get(assigns, :show_share_modal, false) do %>
          <%= render_share_modal(assigns) %>
        <% end %>

        <%= if Map.get(assigns, :show_contact_modal, false) do %>
          <%= render_contact_modal(assigns) %>
        <% end %>

        <!-- Lightbox - Only render if media exists -->
        <%= if Map.get(assigns, :active_lightbox_media) do %>
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

  defp render_traditional_public_view(assigns) do
    ~H"""
    <div class="traditional-portfolio-view">
      <!-- Portfolio Header -->
      <header class="portfolio-header text-center mb-8 p-6 bg-white rounded-lg shadow-sm">
        <h1 class="text-4xl font-bold text-gray-900 mb-4"><%= @portfolio.title %></h1>
        <%= if @portfolio.description do %>
          <p class="text-xl text-gray-600 max-w-2xl mx-auto"><%= @portfolio.description %></p>
        <% end %>
      </header>

      <!-- Portfolio Sections -->
      <div class="portfolio-sections">
        <%= if length(Map.get(assigns, :sections, [])) > 0 do %>
          <%= for section <- @sections do %>
            <%= if Map.get(section, :visible, true) do %>
              <section class="portfolio-section bg-white rounded-lg shadow-sm p-6 mb-6">
                <h2 class="text-2xl font-semibold text-gray-900 mb-4"><%= section.title %></h2>
                <div class="prose max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          <% end %>
        <% else %>
          <!-- Empty state -->
          <div class="empty-portfolio text-center py-12">
            <div class="empty-content max-w-md mx-auto">
              <svg class="empty-icon w-16 h-16 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
              <h3 class="text-xl font-semibold text-gray-900 mb-2">Portfolio Under Construction</h3>
              <p class="text-gray-600">This portfolio is being set up. Check back soon!</p>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

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

  defp render_section_content_safe(section) do
    try do
      # Get color scheme from socket assigns if available, fallback to blue
      color_scheme = "blue"  # Default fallback

      # Try to use EnhancedContentRenderer, fall back to basic rendering
      enhanced_content = try do
        EnhancedContentRenderer.render_enhanced_section_content(section, color_scheme)
      rescue
        _ ->
          # Fallback to basic rendering if enhanced component fails
          render_basic_section_content(section)
      end

      # Return as safe HTML
      raw(enhanced_content)
    rescue
      _ ->
        # Ultimate fallback for any errors
        raw("<p>Content loading...</p>")
    end
  end


defp generate_portfolio_css(portfolio) when is_map(portfolio) do
  # Extract theme settings from portfolio
  customization = portfolio.customization || %{}
  theme = portfolio.theme || "professional"
  layout = Map.get(customization, "layout", "standard")
  color_scheme = Map.get(customization, "color_scheme", "blue")

  # Build theme settings structure for ThemeConsistencyManager
  theme_settings = %{
    theme: theme,
    layout: layout,
    color_scheme: color_scheme,
    customization: customization,
    portfolio: portfolio
  }

  try do
    ThemeConsistencyManager.generate_complete_theme_css(theme_settings)
  rescue
    error ->
      IO.puts("⚠️ ThemeConsistencyManager failed: #{inspect(error)}")
      generate_basic_portfolio_css(portfolio)
  end
end

  defp generate_portfolio_css(customization) when is_map(customization) do
    # Legacy support for when only customization is passed
    theme = Map.get(customization, "theme", "professional")
    layout = Map.get(customization, "layout", "standard")
    color_scheme = Map.get(customization, "color_scheme", "blue")

    # Create minimal portfolio structure for ThemeConsistencyManager
    portfolio = %{
      theme: theme,
      customization: customization,
      title: "Portfolio",
      description: ""
    }

    theme_settings = %{
      theme: theme,
      layout: layout,
      color_scheme: color_scheme,
      customization: customization,
      portfolio: portfolio
    }

    try do
      ThemeConsistencyManager.generate_complete_theme_css(theme_settings)
    rescue
      error ->
        IO.puts("⚠️ ThemeConsistencyManager failed: #{inspect(error)}")
        generate_basic_portfolio_css(portfolio)
    end
  end

  defp generate_portfolio_css(portfolio, sections \\ []) do
    # Extract theme settings
    customization = portfolio.customization || %{}
    theme = portfolio.theme || "professional"
    layout = Map.get(customization, "layout", "standard")
    color_scheme = Map.get(customization, "color_scheme", "blue")

    # Enhanced: Apply complete theme consistency with sections
    try do
      {_enhanced_assigns, complete_css, _theme_settings} =
        ThemeConsistencyManager.apply_theme_to_all_components(portfolio, sections, %{})

      complete_css
    rescue
      error ->
        IO.puts("⚠️ Complete theme application failed: #{inspect(error)}")

        # Fallback: Try basic CSS generation
        theme_settings = %{
          theme: theme,
          layout: layout,
          color_scheme: color_scheme,
          customization: customization,
          portfolio: portfolio
        }

        try do
          ThemeConsistencyManager.generate_complete_theme_css(theme_settings)
        rescue
          _error2 ->
            generate_basic_portfolio_css(portfolio)
        end
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

  defp generate_basic_portfolio_css(portfolio) do
    customization = portfolio.customization || %{}
    theme = portfolio.theme || "professional"

    primary_color = Map.get(customization, "primary_color", "#1e40af")
    secondary_color = Map.get(customization, "secondary_color", "#64748b")

    """
    <style id="basic-portfolio-css">
    :root {
      --primary-color: #{primary_color};
      --secondary-color: #{secondary_color};
    }

    .portfolio-container {
      font-family: 'Inter', system-ui, sans-serif;
      background-color: #fafafa;
      min-height: 100vh;
      padding: 2rem;
    }

    .portfolio-section {
      background: white;
      padding: 2rem;
      margin-bottom: 1.5rem;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
    }

    .section-title {
      color: var(--primary-color);
      font-size: 1.5rem;
      font-weight: bold;
      margin-bottom: 1rem;
    }

    .hero-section {
      background: var(--primary-color);
      color: white;
      text-align: center;
      padding: 4rem 2rem;
      margin-bottom: 2rem;
      border-radius: 12px;
    }
    </style>
    """
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
  # TRADITIONAL SECTION RENDERERS
  # ============================================================================


  defp render_traditional_public_view(assigns) do
    # Extract theme settings with fallbacks
    theme = Map.get(assigns, :theme, "professional")
    layout_type = Map.get(assigns, :layout_type, "standard")
    color_scheme = Map.get(assigns, :color_scheme, "blue")
    portfolio = assigns.portfolio
    sections = Map.get(assigns, :sections, [])

    # Try to use EnhancedLayoutRenderer, fall back to basic layout
    enhanced_html = try do
      EnhancedLayoutRenderer.render_portfolio_layout(
        portfolio,
        sections,
        layout_type,
        color_scheme,
        theme
      )
    rescue
      error ->
        IO.puts("⚠️ Enhanced layout rendering failed: #{inspect(error)}")
        # Fallback to basic layout
        render_basic_portfolio_layout(assigns)
    end

    raw(enhanced_html)
  end

    defp render_basic_portfolio_layout(assigns) do
    sections = Map.get(assigns, :sections, [])

    """
    <div class="basic-portfolio-layout">
      <!-- Basic Hero -->
      <header class="hero-section">
        <h1>#{assigns.portfolio.title}</h1>
        <p>#{assigns.portfolio.description || ""}</p>
      </header>

      <!-- Basic Sections -->
      <main class="portfolio-sections">
        #{if length(sections) > 0 do
          Enum.map(sections, fn section ->
            if Map.get(section, :visible, true) do
              "<section class='portfolio-section'>
                <h2 class='section-title'>#{section.title}</h2>
                <div class='section-content'>
                  #{render_basic_section_content(section)}
                </div>
              </section>"
            else
              ""
            end
          end) |> Enum.join("")
        else
          "<div class='empty-portfolio'>
            <h3>Portfolio Under Construction</h3>
            <p>This portfolio is being set up. Check back soon!</p>
          </div>"
        end}
      </main>
    </div>
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

  defp assign_portfolio_data(socket, portfolio) do
    socket
    |> assign(:portfolio, portfolio)
    |> assign(:owner, portfolio.user)
    |> assign(:page_title, portfolio.title)
    |> assign(:customization, Map.get(portfolio, :customization, %{}))
  end

  defp assign_view_context(socket, view_type) do
    socket
    |> assign(:view_mode, view_type)
    |> assign(:show_edit_controls, view_type in [:preview, :authenticated])
    |> assign(:is_public_view, view_type == :public)
    |> assign(:can_edit, view_type in [:preview, :authenticated])
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


  defp get_section_badge_class(section_type) do
    case safe_capitalize(section_type) do
      "Hero" -> "bg-purple-100 text-purple-800"
      "About" -> "bg-blue-100 text-blue-800"
      "Experience" -> "bg-green-100 text-green-800"
      "Skills" -> "bg-yellow-100 text-yellow-800"
      "Projects" -> "bg-red-100 text-red-800"
      "Contact" -> "bg-indigo-100 text-indigo-800"
      "Education" -> "bg-orange-100 text-orange-800"
      "Testimonials" -> "bg-pink-100 text-pink-800"
      "Custom" -> "bg-gray-100 text-gray-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  # Helper function to format section type names
  defp format_section_type(section_type) do
    case safe_capitalize(section_type) do
      "Hero" -> "Hero Section"
      "About" -> "About Me"
      "Experience" -> "Work Experience"
      "Skills" -> "Skills & Expertise"
      "Projects" -> "Projects Portfolio"
      "Contact" -> "Contact Information"
      "Education" -> "Education & Certifications"
      "Testimonials" -> "Testimonials & Reviews"
      "Custom" -> "Custom Content"
      _ -> safe_capitalize(section_type)
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

  defp determine_section_zone(section) do
    case section.section_type do
      "hero" -> :hero
      "about" -> :main_content
      "experience" -> :main_content
      "skills" -> :sidebar
      "portfolio" -> :main_content
      "contact" -> :footer
      "services" -> :main_content
      "testimonials" -> :sidebar
      _ -> :main_content
    end
  end

  defp convert_sections_to_content_blocks(_), do: %{}

  defp map_section_type_to_block_type(section_type) do
    case section_type do
      "hero" -> :hero_card
      "about" -> :about_card
      "experience" -> :experience_card
      "skills" -> :skills_card
      "portfolio" -> :project_card
      "contact" -> :contact_card
      "services" -> :service_card
      "testimonials" -> :testimonial_card
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



  defp get_color_palette(scheme) do
    case scheme do
      "blue" ->
        %{primary: "#1e40af", secondary: "#3b82f6", accent: "#60a5fa", background: "#fafafa", surface: "#ffffff", text_primary: "#1f2937", text_secondary: "#6b7280"}
      "green" ->
        %{primary: "#065f46", secondary: "#059669", accent: "#34d399", background: "#f0fdf4", surface: "#ffffff", text_primary: "#064e3b", text_secondary: "#6b7280"}
      "purple" ->
        %{primary: "#581c87", secondary: "#7c3aed", accent: "#a78bfa", background: "#faf5ff", surface: "#ffffff", text_primary: "#581c87", text_secondary: "#6b7280"}
      "red" ->
        %{primary: "#991b1b", secondary: "#dc2626", accent: "#f87171", background: "#fef2f2", surface: "#ffffff", text_primary: "#991b1b", text_secondary: "#6b7280"}
      "orange" ->
        %{primary: "#ea580c", secondary: "#f97316", accent: "#fb923c", background: "#fff7ed", surface: "#ffffff", text_primary: "#ea580c", text_secondary: "#6b7280"}
      "teal" ->
        %{primary: "#0f766e", secondary: "#14b8a6", accent: "#5eead4", background: "#f0fdfa", surface: "#ffffff", text_primary: "#134e4a", text_secondary: "#6b7280"}
      _ ->
        %{primary: "#1e40af", secondary: "#3b82f6", accent: "#60a5fa", background: "#fafafa", surface: "#ffffff", text_primary: "#1f2937", text_secondary: "#6b7280"}
    end
  end

  defp get_portfolio_template_class(assigns) do
    customization = Map.get(assigns, :customization, %{})
    theme = Map.get(customization, "theme", "professional")
    layout = Map.get(customization, "layout", "dashboard")

    case {theme, layout} do
      {"professional", "dashboard"} -> "template-professional-dashboard"
      {"professional", "grid"} -> "template-professional-grid"
      {"creative", "dashboard"} -> "template-creative-dashboard"
      {"creative", "timeline"} -> "template-creative-timeline"
      {"minimal", _} -> "template-minimal-#{layout}"
      {"modern", _} -> "template-modern-#{layout}"
      {theme, layout} -> "template-#{theme}-#{layout}"
    end
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

  defp render_enhanced_hero_section(assigns) do
    portfolio = assigns.portfolio
    sections = Map.get(assigns, :sections, [])
    color_scheme = Map.get(assigns, :color_scheme, "blue")

    # Use EnhancedHeroRenderer for complete hero section rendering
    enhanced_hero_html = EnhancedHeroRenderer.render_enhanced_hero(portfolio, sections, color_scheme)

    raw(enhanced_hero_html)
  end

  defp render_dashboard_layout(assigns) do
    sections = Map.get(assigns, :sections, [])
    theme_settings = Map.get(assigns, :theme_settings, %{})

    # Create card configuration from theme settings
    card_config = %{
      color_scheme: Map.get(assigns, :color_scheme, "blue"),
      theme: Map.get(assigns, :theme, "professional")
    }

    # Render sections using enhanced section cards
    section_cards = sections
    |> Enum.map(fn section ->
      EnhancedSectionCards.render_section_card(section, card_config, "dashboard")
    end)
    |> Enum.join("\n")

    ~H"""
    <div class="min-h-screen bg-gray-50">
      <!-- Dashboard Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <h1 class="text-3xl font-bold text-gray-900"><%= @portfolio.title %></h1>
          <p class="text-gray-600 mt-1"><%= @portfolio.description %></p>
        </div>
      </header>

      <!-- Enhanced Dashboard Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <div class="lg:col-span-2 space-y-8">
            <%= raw(section_cards) %>
          </div>
          <div class="space-y-6">
            <div class="bg-white rounded-xl shadow-sm border p-6">
              <h3 class="font-semibold text-gray-900 mb-4">Portfolio Info</h3>
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Sections:</span>
                  <span class="font-medium"><%= length(@sections) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Theme:</span>
                  <span class="font-medium"><%= String.capitalize(@theme) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Layout:</span>
                  <span class="font-medium"><%= String.capitalize(@layout_type) %></span>
                </div>
              </div>
            </div>
          </div>
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

  defp has_hero_section?(sections) do
    Enum.any?(sections, &(&1.section_type == "hero"))
  end

  defp filter_non_hero_sections(sections) do
    Enum.reject(sections, &(&1.section_type == "hero"))
  end

  defp render_hero_with_template(assigns) do
    hero_section = Enum.find(assigns.sections, &(&1.section_type == "hero"))

    if hero_section do
      assigns = assign(assigns, :hero_section, hero_section)

      ~H"""
      <div class="hero-content">
        <h1 class="hero-title"><%= @hero_section.title %></h1>
        <div class="hero-body">
          <%= render_section_content_safe(@hero_section) %>
        </div>
      </div>
      """
    else
      ~H"<div></div>"
    end
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
      %{"video_url" => _} = content -> content
      video_data when is_map(video_data) ->
        %{
          "video_url" => Map.get(video_data, :video_url, ""),
          "title" => Map.get(video_data, :title, "Personal Introduction"),
          "description" => Map.get(video_data, :description, ""),
          "duration" => Map.get(video_data, :duration, 0)
        }
      _ -> %{}
    end
  end

  # Safe video URL extraction
  defp get_video_url_safe(intro_video) do
    case intro_video do
      nil -> nil
      %{video_url: url} when is_binary(url) -> url
      %{"video_url" => url} when is_binary(url) -> url
      %{content: %{"video_url" => url}} when is_binary(url) -> url
      %{content: content} when is_map(content) -> Map.get(content, "video_url")
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
