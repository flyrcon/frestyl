# lib/frestyl_web/live/portfolio_live/show.ex
# FIXED VERSION - Renders portfolios with dynamic card layout support

defmodule FrestylWeb.PortfolioLive.ShowTEMP do
  use FrestylWeb, :live_view
  import Phoenix.LiveView.Helpers
  import Phoenix.Controller, only: [get_csrf_token: 0]
  import Phoenix.HTML, only: [raw: 1, html_escape: 1]

  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Phoenix.PubSub
  alias FrestylWeb.PortfolioLive.Components.{
    EnhancedContentRenderer,
    EnhancedLayoutRenderer,
    EnhancedHeroRenderer,
    ThemeConsistencyManager,
    EnhancedSectionCards
  }
  alias FrestylWeb.PortfolioLive.{PorfolioEditorFixed}
  alias Frestyl.ResumeExporter


  @impl true
  def mount(params, _session, socket) do
    IO.puts("🌍 MOUNTING PORTFOLIO SHOW with params: #{inspect(params)}")

    result = case params do
      # Public view via slug
      %{"slug" => slug} ->
        IO.puts("🌐 Public portfolio mount for slug: #{slug}")
        mount_public_portfolio(slug, socket)

      # Shared view via token
      %{"token" => token} ->
        IO.puts("🔗 Shared portfolio mount for token: #{token}")
        mount_shared_portfolio(token, socket)

      # Preview for editor
      %{"id" => id, "preview_token" => token} ->
        IO.puts("👁️ Preview portfolio mount for id: #{id}")
        mount_preview_portfolio(id, token, socket)

      # Authenticated view by ID
      %{"id" => id} ->
        IO.puts("🔐 Authenticated portfolio mount for id: #{id}")
        mount_authenticated_portfolio(id, socket)

      _ ->
        IO.puts("❌ Invalid portfolio URL parameters: #{inspect(params)}")
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

  defp mount_public_portfolio(slug, socket) do
    IO.puts("🌍 MOUNTING PUBLIC PORTFOLIO: /p/#{slug}")

    try do
      case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
        {:ok, portfolio} ->
          IO.puts("✅ Portfolio found: #{portfolio.title}")
          case mount_portfolio(portfolio, socket) do
            {:ok, updated_socket} ->
              # Use your existing CSS generation (not the enhanced one)
              custom_css = generate_portfolio_css(portfolio)
              {:ok, updated_socket
              |> assign(:view_type, :public)
              |> assign(:custom_css, custom_css)
              |> assign(:is_public_view, true)}
            error ->
              IO.puts("❌ Error mounting portfolio: #{inspect(error)}")
              error
          end
        {:error, :not_found} ->
          IO.puts("❌ Portfolio not found with slug: #{slug}")
          {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
        {:error, reason} ->
          IO.puts("❌ Error loading portfolio: #{inspect(reason)}")
          {:ok, socket |> put_flash(:error, "Unable to load portfolio") |> redirect(to: "/")}
      end
    rescue
      e ->
        IO.puts("❌ Exception in mount_public_portfolio: #{inspect(e)}")
        {:ok, socket |> put_flash(:error, "Portfolio not found") |> redirect(to: "/")}
    end
  end

  defp mount_shared_portfolio(token, socket) do
    IO.puts("🔗 MOUNTING SHARED PORTFOLIO: /share/#{token}")

    case load_portfolio_by_share_token(token) do
      {:ok, portfolio, share} ->
        IO.puts("✅ Shared portfolio found: #{portfolio.title}")
        # Track share visit
        track_share_visit_safe(portfolio, share, socket)

        case mount_portfolio(portfolio, socket) do
          {:ok, updated_socket} ->
            custom_css = generate_portfolio_css(portfolio)
            {:ok, updated_socket
            |> assign(:view_type, :shared)
            |> assign(:share, share)
            |> assign(:is_shared_view, true)
            |> assign(:custom_css, custom_css)}
          error -> error
        end

      {:error, :not_found} ->
        IO.puts("❌ Invalid share token: #{token}")
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

  defp mount_authenticated_portfolio(id, socket) do
    IO.puts("🔐 MOUNTING AUTHENTICATED PORTFOLIO: #{id}")

    user = socket.assigns.current_user
    case load_portfolio_by_id(id) do
      {:ok, portfolio} ->
        IO.puts("✅ Portfolio found: #{portfolio.title}")
        if can_view_portfolio?(portfolio, user) do
          case mount_portfolio(portfolio, socket) do
            {:ok, updated_socket} ->
              custom_css = generate_portfolio_css(portfolio)
              {:ok, updated_socket
              |> assign(:view_type, :authenticated)
              |> assign(:custom_css, custom_css)
              |> assign(:can_edit, portfolio.user_id == (user && user.id))}
            error -> error
          end
        else
          IO.puts("❌ Access denied for user: #{user && user.id}")
          {:ok,
          socket
          |> put_flash(:error, "Access denied")
          |> redirect(to: "/")}
        end

      {:error, :not_found} ->
        IO.puts("❌ Portfolio not found with id: #{id}")
        {:ok,
        socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}
    end
  end

  defp mount_preview_portfolio(id, token, socket) do
    IO.puts("👁️ MOUNTING PREVIEW PORTFOLIO: /preview/#{id}/#{token}")

    case load_portfolio_for_preview(id, token) do
      {:ok, portfolio} ->
        IO.puts("✅ Preview portfolio found: #{portfolio.title}")
        case mount_portfolio(portfolio, socket) do
          {:ok, updated_socket} ->
            custom_css = generate_portfolio_css(portfolio)
            {:ok, updated_socket
            |> assign(:view_type, :preview)
            |> assign(:custom_css, custom_css)
            |> assign(:is_preview, true)}
          error -> error
        end

      {:error, :invalid_token} ->
        IO.puts("❌ Invalid preview token: #{token}")
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

  defp mount_portfolio(portfolio, socket) do
    IO.puts("📁 MOUNTING PORTFOLIO WITH ENHANCED COMPONENTS: #{portfolio.title}")

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

    # 🔥 NEW: Enhanced theme and layout extraction
    {theme, layout_type, color_scheme} = extract_enhanced_theme_settings(portfolio)
    IO.puts("🎨 Theme Settings - Theme: #{theme}, Layout: #{layout_type}, Colors: #{color_scheme}")

    # 🔥 SAFE: Get enhanced theme data without socket assignment issues
    enhanced_theme_data = safe_get_enhanced_theme_data(portfolio, filtered_sections, theme, layout_type, color_scheme)

    # 🔥 SAFE: Generate comprehensive CSS using ThemeConsistencyManager
    comprehensive_css = safe_generate_comprehensive_css(theme, layout_type, color_scheme, portfolio.customization || %{})

    socket = socket
    |> assign(:page_title, portfolio.title)
    |> assign(:portfolio, portfolio)
    |> assign(:theme, theme)
    |> assign(:layout_type, layout_type)
    |> assign(:color_scheme, color_scheme)
    |> assign(:owner, get_portfolio_owner_safe(portfolio))
    |> assign(:sections, filtered_sections)
    |> assign(:all_sections, sections)
    |> assign(:customization, portfolio.customization || %{})
    |> assign(:intro_video, intro_video)
    |> assign(:intro_video_section, intro_video)
    |> assign(:has_intro_video, intro_video != nil)
    |> assign(:video_url, get_video_url_safe(intro_video))
    |> assign(:video_content, get_video_content_safe(intro_video))
    # 🔥 SAFE: Enhanced assigns from safe theme data extraction
    |> assign(:enhanced_theme_config, enhanced_theme_data.theme_config)
    |> assign(:layout_config, enhanced_theme_data.layout_config)
    |> assign(:section_card_config, enhanced_theme_data.section_card_config)
    |> assign(:comprehensive_css, comprehensive_css)
    # Existing modal and UI assigns
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

  defp extract_enhanced_theme_settings(portfolio) do
    customization = portfolio.customization || %{}

    # Extract theme with fallback
    theme = case Map.get(customization, "theme", portfolio.theme) do
      theme when theme in ["professional", "creative", "minimal", "modern"] -> theme
      _ -> "professional"
    end

    # Extract layout type with fallback
    layout_type = case Map.get(customization, "layout") do
      layout when layout in ["standard", "dashboard", "masonry_grid", "timeline", "magazine", "minimal"] -> layout
      _ -> "standard"
    end

    # Extract color scheme with fallback
    color_scheme = case Map.get(customization, "color_scheme") do
      scheme when scheme in ["blue", "green", "purple", "red", "orange", "teal"] -> scheme
      _ -> determine_scheme_from_color(Map.get(customization, "primary_color", "#3b82f6"))
    end

    {theme, layout_type, color_scheme}
  end

  defp extract_color_scheme_from_portfolio(portfolio) do
    customization = portfolio.customization || %{}

    # Check if a specific color scheme is set, otherwise determine from colors
    case Map.get(customization, "color_scheme") do
      scheme when scheme in ["blue", "green", "purple", "red", "orange", "teal"] ->
        scheme
      _ ->
        # Determine scheme from primary color if no explicit scheme is set
        primary_color = Map.get(customization, "primary_color", "#3b82f6")
        determine_scheme_from_color(primary_color)
    end
  end

  defp extract_layout_type_from_portfolio(portfolio) do
    customization = portfolio.customization || %{}
    Map.get(customization, "layout", "standard")
  end

  defp extract_enhanced_theme_settings(portfolio) do
    customization = portfolio.customization || %{}

    # Extract theme with fallback
    theme = case Map.get(customization, "theme", portfolio.theme) do
      theme when theme in ["professional", "creative", "minimal", "modern"] -> theme
      _ -> "professional"
    end

    # Extract layout type with fallback
    layout_type = case Map.get(customization, "layout") do
      layout when layout in ["standard", "dashboard", "masonry_grid", "timeline", "magazine", "minimal"] -> layout
      _ -> "standard"
    end

    # Extract color scheme with fallback
    color_scheme = case Map.get(customization, "color_scheme") do
      scheme when scheme in ["blue", "green", "purple", "red", "orange", "teal"] -> scheme
      _ -> determine_scheme_from_color(Map.get(customization, "primary_color", "#3b82f6"))
    end

    {theme, layout_type, color_scheme}
  end

  defp determine_scheme_from_color(color) do
    case color do
      "#1e40af" -> "blue"     # Ocean Blue primary
      "#3b82f6" -> "blue"     # Ocean Blue secondary
      "#065f46" -> "green"    # Forest Green primary
      "#059669" -> "green"    # Forest Green secondary
      "#581c87" -> "purple"   # Royal Purple primary
      "#7c3aed" -> "purple"   # Royal Purple secondary
      "#991b1b" -> "red"      # Warm Red primary
      "#dc2626" -> "red"      # Warm Red secondary
      "#ea580c" -> "orange"   # Sunset Orange primary
      "#f97316" -> "orange"   # Sunset Orange secondary
      "#0f766e" -> "teal"     # Modern Teal primary
      "#14b8a6" -> "teal"     # Modern Teal secondary
      _ -> "blue"             # Default fallback
    end
  end

  @impl true
  def handle_info({:design_complete_update, design_data}, socket) do
    IO.puts("🎨 SHOW PAGE received ENHANCED design update")

    # 🔥 SAFE: Use enhanced CSS with fallback
    comprehensive_css = safe_generate_comprehensive_css(
      design_data.theme,
      design_data.layout,
      design_data.color_scheme,
      design_data.customization
    )

    template_class = safe_get_template_class(design_data.theme, design_data.layout)

    enhanced_design_data = Map.merge(design_data, %{
      css: comprehensive_css,
      template_class: template_class
    })

    socket = socket
    |> assign(:customization, design_data.customization)
    |> assign(:comprehensive_css, comprehensive_css)
    |> assign(:template_class, template_class)
    |> assign(:theme, design_data.theme)
    |> assign(:layout_type, design_data.layout)
    |> assign(:color_scheme, design_data.color_scheme)
    |> push_event("apply_comprehensive_design", enhanced_design_data)

    {:noreply, socket}
  end

  defp safe_get_template_class(theme, layout) do
    try do
      ThemeConsistencyManager.get_template_class(theme, layout)
    rescue
      _ -> "template-#{theme}-#{layout}"
    end
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

  defp generate_simple_design_css(design_data) do
    theme = Map.get(design_data, :theme, "professional")
    layout = Map.get(design_data, :layout, "standard")
    color_scheme = Map.get(design_data, :color_scheme, "blue")
    customization = Map.get(design_data, :customization, %{})

    colors = get_simple_color_palette(color_scheme)

    """
    /* Simple Design Update CSS */
    :root {
      --portfolio-primary: #{colors.primary};
      --portfolio-secondary: #{colors.secondary};
      --portfolio-accent: #{colors.accent};
      --portfolio-background: #{colors.background};
      --portfolio-text: #{colors.text_primary};
    }

    .portfolio-container {
      background-color: var(--portfolio-background);
      color: var(--portfolio-text);
    }

    .portfolio-section {
      background: white;
      border: 1px solid #e5e7eb;
      border-radius: 8px;
      padding: 2rem;
      margin-bottom: 1.5rem;
    }

    .section-title {
      color: var(--portfolio-primary);
    }
    """
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

  defp get_color_scheme_name(colors) do
    # Try to determine the color scheme from the primary color
    case colors.primary do
      "#1e40af" -> "blue"
      "#065f46" -> "green"
      "#581c87" -> "purple"
      "#991b1b" -> "red"
      "#ea580c" -> "orange"
      "#0f766e" -> "teal"
      _ -> "blue"
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

      ip_address = get_connect_info(socket, :peer_data)
                  |> Map.get(:address, {127, 0, 0, 1})
                  |> :inet.ntoa()
                  |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      visit_attrs = %{
        portfolio_id: portfolio.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
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

  defp safe_get_enhanced_theme_data(portfolio, sections, theme, layout_type, color_scheme) do
    try do
      ThemeConsistencyManager.apply_theme_to_all_components(
        portfolio,
        sections,
        %{theme: theme, layout_type: layout_type, color_scheme: color_scheme}
      )
    rescue
      e ->
        IO.puts("⚠️ ThemeConsistencyManager not available, using fallback: #{inspect(e)}")
        get_fallback_theme_data(theme, layout_type, color_scheme)
    end
  end

  defp safe_generate_comprehensive_css(theme, layout_type, color_scheme, customization) do
    try do
      ThemeConsistencyManager.generate_comprehensive_css(
        theme,
        layout_type,
        color_scheme,
        customization
      )
    rescue
      e ->
        IO.puts("⚠️ ThemeConsistencyManager CSS not available, using fallback: #{inspect(e)}")
        generate_fallback_comprehensive_css(theme, layout_type, color_scheme, customization)
    end
  end

  defp get_fallback_theme_data(theme, layout_type, color_scheme) do
    colors = get_simple_color_palette(color_scheme)

    %{
      theme_config: %{
        theme: theme,
        primary_color: colors.primary,
        accent_color: colors.accent,
        font_family: get_font_for_theme(theme)
      },
      layout_config: %{
        layout_type: layout_type,
        grid_columns: get_columns_for_layout(layout_type),
        card_spacing: get_spacing_for_layout(layout_type)
      },
      section_card_config: %{
        card_type: :fixed_height,
        enable_modal: true,
        show_icons: true,
        card_height: get_card_height_for_layout(layout_type),
        colors: colors
      }
    }
  end

  defp get_card_height_for_layout(layout_type) do
    case layout_type do
      "dashboard" -> "320px"
      "masonry_grid" -> "auto"
      "timeline" -> "auto"
      _ -> "300px"
    end
  end

  defp generate_fallback_comprehensive_css(theme, layout_type, color_scheme, customization) do
    colors = get_simple_color_palette(color_scheme)

    """
    /* Fallback Comprehensive CSS */
    :root {
      --portfolio-primary: #{colors.primary};
      --portfolio-secondary: #{colors.secondary};
      --portfolio-accent: #{colors.accent};
      --portfolio-background: #{colors.background};
      --portfolio-text: #{colors.text_primary};
      --portfolio-theme: #{theme};
      --portfolio-layout: #{layout_type};
    }

    .portfolio-container {
      font-family: #{get_font_for_theme(theme)};
      background-color: var(--portfolio-background);
      color: var(--portfolio-text);
    }

    #{get_layout_specific_css(layout_type)}
    #{get_theme_specific_css(theme, colors)}
    """
  end

  defp get_color_for_scheme(scheme, type) do
    colors = get_simple_color_palette(scheme)
    Map.get(colors, type, "#3b82f6")
  end

  defp get_font_for_theme(theme) do
    case theme do
      "creative" -> "'Poppins', sans-serif"
      "minimal" -> "'Inter', system-ui, sans-serif"
      "modern" -> "'Roboto', sans-serif"
      _ -> "'Inter', system-ui, sans-serif"
    end
  end

  defp get_columns_for_layout(layout) do
    case layout do
      "dashboard" -> "repeat(auto-fit, minmax(350px, 1fr))"
      "masonry_grid" -> "repeat(auto-fill, minmax(300px, 1fr))"
      "timeline" -> "1fr"
      _ -> "1fr"
    end
  end

  defp get_spacing_for_layout(layout) do
    case layout do
      "dashboard" -> "2rem"
      "masonry_grid" -> "1.5rem"
      "timeline" -> "3rem"
      _ -> "2rem"
    end
  end

  defp get_layout_specific_css(layout_type) do
    case layout_type do
      "dashboard" -> """
        .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
          gap: 2rem;
          max-width: 1400px;
          margin: 0 auto;
          padding: 2rem;
        }
      """
      "masonry_grid" -> """
        .portfolio-sections {
          display: grid;
          grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
          gap: 1.5rem;
          max-width: 1200px;
          margin: 0 auto;
          padding: 2rem;
        }
      """
      "timeline" -> """
        .portfolio-sections {
          max-width: 900px;
          margin: 0 auto;
          padding: 2rem;
          position: relative;
        }
        .portfolio-sections::before {
          content: '';
          position: absolute;
          left: 2rem;
          top: 0;
          bottom: 0;
          width: 2px;
          background: var(--portfolio-accent);
        }
        .portfolio-section {
          margin-left: 4rem;
          margin-bottom: 3rem;
          position: relative;
        }
        .portfolio-section::before {
          content: '';
          position: absolute;
          left: -3rem;
          top: 1rem;
          width: 12px;
          height: 12px;
          border-radius: 50%;
          background: var(--portfolio-accent);
          border: 3px solid var(--portfolio-background);
        }
      """
      _ -> """
        .portfolio-sections {
          max-width: 1200px;
          margin: 0 auto;
          padding: 2rem;
        }
      """
    end
  end

  defp get_theme_specific_css(theme, colors) do
    case theme do
      "creative" -> """
        .portfolio-section {
          border-left: 5px solid #{colors.accent};
          transform: rotate(-0.5deg);
          transition: transform 0.3s ease;
        }
        .portfolio-section:hover {
          transform: rotate(0deg);
      }
    """
    "minimal" -> """
      .portfolio-section {
        border: 2px solid #{colors.primary};
        box-shadow: none;
      }
    """
    "modern" -> """
      .portfolio-section {
        border-top: 4px solid #{colors.primary};
        box-shadow: 0 8px 20px rgba(0,0,0,0.12);
      }
    """
    _ -> ""
  end
end


  @impl true
  def handle_info({:design_complete_update, design_data}, socket) do
    IO.puts("🎨 SHOW PAGE received ENHANCED design update")

    # 🔥 ENHANCED: Use ThemeConsistencyManager for complete CSS generation
    comprehensive_css = ThemeConsistencyManager.generate_comprehensive_css(
      design_data.theme,
      design_data.layout,
      design_data.color_scheme,
      design_data.customization
    )

    template_class = ThemeConsistencyManager.get_template_class(
      design_data.theme,
      design_data.layout
    )

    enhanced_design_data = Map.merge(design_data, %{
      css: comprehensive_css,
      template_class: template_class
    })

    socket = socket
    |> assign(:customization, design_data.customization)
    |> assign(:comprehensive_css, comprehensive_css)
    |> assign(:template_class, template_class)
    |> assign(:theme, design_data.theme)
    |> assign(:layout_type, design_data.layout)
    |> assign(:color_scheme, design_data.color_scheme)
    |> push_event("apply_comprehensive_design", enhanced_design_data)

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
        <!-- Enhanced CSS from ThemeConsistencyManager -->
        <style id="portfolio-comprehensive-css"><%= raw(@comprehensive_css || @custom_css || "") %></style>
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

          /* Enhanced Layout Styles */
          .dashboard-layout .portfolio-container {
            background: linear-gradient(135deg, #f8fafc 0%, #f1f5f9 100%);
          }

          .timeline-layout .portfolio-container {
            background: #fafafa;
          }

          .masonry-layout .portfolio-container {
            background: #ffffff;
          }

          /* Theme-specific overrides */
          .template-creative-dashboard .portfolio-section:nth-child(odd) {
            transform: rotate(-0.5deg);
            border-left: 5px solid var(--portfolio-accent);
          }

          .template-creative-dashboard .portfolio-section:nth-child(even) {
            transform: rotate(0.5deg);
            border-right: 5px solid var(--portfolio-accent);
          }

          .template-minimal-standard .portfolio-section {
            box-shadow: none;
            border: 2px solid var(--portfolio-primary);
          }

          .template-modern-dashboard .portfolio-section {
            border-top: 4px solid var(--portfolio-primary);
            box-shadow: 0 8px 20px rgba(0,0,0,0.12);
          }
        </style>
        <script phx-track-static type="text/javascript" src={~p"/assets/app.js"}></script>
      </head>

      <body class={["portfolio-public-view", get_template_body_class(assigns)]}>
        <!-- Enhanced CSS Update Handler -->
        <script>
          // Handle comprehensive design updates from portfolio_editor_fixed.ex
          window.addEventListener('phx:apply_comprehensive_design', (e) => {
            console.log('🎨 APPLYING ENHANCED DESIGN UPDATE:', e.detail);

            // Remove old CSS
            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            // Inject new CSS
            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css;
            document.head.appendChild(style);

            // Update body class with template
            if (e.detail.template_class) {
              document.body.className = `portfolio-public-view ${e.detail.template_class}`;
            }

            // Update container classes
            const container = document.querySelector('.portfolio-container');
            if (container && e.detail.template_class) {
              container.className = `portfolio-container ${e.detail.template_class} min-h-screen`;
            }

            console.log('✅ Enhanced design applied successfully');
          });

          // Handle legacy design updates (fallback)
          window.addEventListener('phx:apply_portfolio_design', (e) => {
            console.log('🎨 APPLYING LEGACY DESIGN UPDATE:', e.detail);

            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css || '';
            document.head.appendChild(style);
          });

          // Handle CSS injection
          window.addEventListener('phx:inject_design_css', (e) => {
            console.log('🎨 INJECTING CSS:', e.detail);

            const oldCSS = document.getElementById('comprehensive-portfolio-design');
            if (oldCSS) oldCSS.remove();

            const style = document.createElement('style');
            style.id = 'comprehensive-portfolio-design';
            style.innerHTML = e.detail.css || '';
            document.head.appendChild(style);
          });

          // Video introduction functionality
          function playIntroVideo() {
            const video = document.getElementById('intro-video');
            if (video) {
              if (video.paused) {
                video.play();
              } else {
                video.pause();
              }
            }
          }

          // Smooth scroll to sections
          function scrollToSection(sectionId) {
            const element = document.getElementById(sectionId);
            if (element) {
              element.scrollIntoView({ behavior: 'smooth' });
            }
          }

          // Hero animations on scroll
          window.addEventListener('scroll', function() {
            const hero = document.querySelector('.video-enhanced-hero, .section-enhanced-hero, .default-enhanced-hero');
            if (hero) {
              const scrolled = window.pageYOffset;
              const parallax = hero.querySelector('.hero-overlay');
              if (parallax) {
                parallax.style.transform = `translateY(${scrolled * 0.5}px)`;
              }
            }
          });

          // Section card modal functionality
          function openSectionModal(sectionId) {
            console.log('Opening modal for section:', sectionId);

            // Create modal backdrop
            const backdrop = document.createElement('div');
            backdrop.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
            backdrop.id = 'section-modal-' + sectionId;

            // Create modal content
            const modal = document.createElement('div');
            modal.className = 'bg-white rounded-xl shadow-2xl max-w-4xl w-full max-h-[90vh] overflow-hidden';
            modal.innerHTML = `
              <div class="flex items-center justify-between p-6 border-b border-gray-200">
                <h2 class="text-2xl font-bold text-gray-900">Section Details</h2>
                <button onclick="closeSectionModal('${sectionId}')" class="w-8 h-8 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors">
                  <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                  </svg>
                </button>
              </div>
              <div class="p-6 overflow-y-auto max-h-[70vh]">
                <div class="prose max-w-none">
                  <p>Full section content would be loaded here...</p>
                </div>
              </div>
            `;

            backdrop.appendChild(modal);
            document.body.appendChild(backdrop);

            // Close on backdrop click
            backdrop.addEventListener('click', function(e) {
              if (e.target === backdrop) {
                closeSectionModal(sectionId);
              }
            });

            // Animate in
            setTimeout(() => {
              backdrop.style.opacity = '1';
              modal.style.transform = 'scale(1)';
            }, 10);
          }

          function closeSectionModal(sectionId) {
            const modal = document.getElementById('section-modal-' + sectionId);
            if (modal) {
              modal.style.opacity = '0';
              setTimeout(() => {
                modal.remove();
              }, 300);
            }
          }

          // Expandable card functionality
          function toggleCardExpansion(sectionId) {
            const content = document.getElementById('content-' + sectionId);
            const indicator = content.parentElement.querySelector('.expand-indicator svg');

            if (content.style.maxHeight === '0px' || content.style.maxHeight === '') {
              // Expand
              content.style.maxHeight = content.scrollHeight + 'px';
              indicator.style.transform = 'rotate(180deg)';
            } else {
              // Collapse
              content.style.maxHeight = '0px';
              indicator.style.transform = 'rotate(0deg)';
            }
          }

          // Enhanced card hover effects
          document.addEventListener('DOMContentLoaded', function() {
            const cards = document.querySelectorAll('.enhanced-section-card, .expandable-section-card, .modal-section-card');

            cards.forEach(card => {
              card.addEventListener('mouseenter', function() {
                this.style.transform = 'translateY(-4px)';
                this.style.boxShadow = '0 20px 40px rgba(0,0,0,0.1)';
              });

              card.addEventListener('mouseleave', function() {
                this.style.transform = 'translateY(0)';
                this.style.boxShadow = '';
              });
            });
          });

          // Smooth scroll to card
          function scrollToCard(sectionId) {
            const card = document.querySelector(`[data-section-id="${sectionId}"]`);
            if (card) {
              card.scrollIntoView({ behavior: 'smooth', block: 'center' });
            }
          }
        </script>

        <!-- Enhanced Portfolio Content -->
        <div class={["portfolio-container", get_template_container_class(assigns), "min-h-screen"]}>
          <%= render_enhanced_portfolio_layout(assigns) %>
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

        <!-- Video Modal for Hero Videos -->
        <%= if Map.get(assigns, :show_video_modal, false) && Map.get(assigns, :intro_video) do %>
          <%= render_video_modal(assigns) %>
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

  defp get_template_body_class(assigns) do
    theme = Map.get(assigns, :theme, "professional")
    layout_type = Map.get(assigns, :layout_type, "standard")
    template_class = Map.get(assigns, :template_class, "template-#{theme}-#{layout_type}")

    "#{layout_type}-layout #{template_class}"
  end

  defp get_template_container_class(assigns) do
    theme = Map.get(assigns, :theme, "professional")
    layout_type = Map.get(assigns, :layout_type, "standard")
    template_class = Map.get(assigns, :template_class, "template-#{theme}-#{layout_type}")

    template_class
  end

  defp render_enhanced_portfolio_layout(assigns) do
    # Use EnhancedLayoutRenderer for complete layout rendering with heroes
    layout_html = safe_render_enhanced_layout(
      assigns.portfolio,
      assigns.sections,
      assigns.layout_type,
      assigns.color_scheme,
      assigns.theme
    )

    raw(layout_html)
  end

  defp safe_render_enhanced_layout(portfolio, sections, layout_type, color_scheme, theme) do
    try do
      EnhancedLayoutRenderer.render_portfolio_layout(
        portfolio,
        sections,
        layout_type,
        color_scheme,
        theme
      )
    rescue
      e ->
        IO.puts("⚠️ EnhancedLayoutRenderer not available, using fallback: #{inspect(e)}")
        render_fallback_enhanced_layout(portfolio, sections, layout_type, color_scheme, theme)
    end
  end

  defp render_fallback_enhanced_layout(portfolio, sections, layout_type, color_scheme, theme) do
    colors = get_simple_color_palette(color_scheme)

    case layout_type do
      "dashboard" ->
        render_dashboard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
      "masonry_grid" ->
        render_masonry_enhanced_layout_with_hero(portfolio, sections, colors, theme)
      "timeline" ->
        render_timeline_enhanced_layout_with_hero(portfolio, sections, colors, theme)
      "magazine" ->
        render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
      "minimal" ->
        render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
      _ ->
        render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
    end
  end

  defp render_dashboard_enhanced_layout_with_hero(portfolio, sections, colors, theme) do
    """
    <!-- Enhanced Hero Section -->
    #{safe_render_enhanced_hero(portfolio, sections, get_color_scheme_name(colors))}

    <div class="dashboard-layout" style="background: linear-gradient(135deg, #{colors.background} 0%, #f8fafc 100%);">
      <!-- Dashboard Header -->
      <header class="dashboard-header bg-white shadow-sm border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-6 py-6">
          <div class="flex items-center justify-between">
            <div>
              <h2 class="text-2xl font-bold" style="color: #{colors.primary};">Portfolio Sections</h2>
              <p class="text-gray-600 mt-1">Explore my professional journey and expertise</p>
            </div>
            <div class="flex items-center space-x-4">
              <div class="px-4 py-2 rounded-lg" style="background: #{colors.primary}15; color: #{colors.primary};">
                <span class="text-sm font-medium">#{length(sections)} Sections</span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Dashboard Grid -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Content Area -->
          <div class="lg:col-span-2">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              #{render_dashboard_cards(sections, colors, theme)}
            </div>
          </div>

          <!-- Sidebar -->
          <div class="space-y-6">
            #{render_dashboard_sidebar(portfolio, colors)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_timeline_enhanced_layout_with_hero(portfolio, sections, colors, theme) do
    """
    <!-- Enhanced Hero Section -->
    #{safe_render_enhanced_hero(portfolio, sections, get_color_scheme_name(colors))}

    <div class="timeline-layout" style="background: #{colors.background};">
      <!-- Timeline Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <div class="text-center mb-16">
          <h2 class="text-3xl font-bold mb-4" style="color: #{colors.primary};">Professional Journey</h2>
          <p class="text-lg text-gray-600">Follow my career progression and key milestones</p>
        </div>

        <div class="relative">
          <!-- Timeline Line -->
          <div class="absolute left-8 top-0 bottom-0 w-0.5" style="background: #{colors.accent};"></div>

          <!-- Timeline Items -->
          <div class="space-y-12">
            #{render_timeline_items(sections, colors, theme)}
          </div>
        </div>
      </main>
    </div>
    """
  end

  defp render_masonry_enhanced_layout_with_hero(portfolio, sections, colors, theme) do
    """
    <!-- Enhanced Hero Section -->
    #{safe_render_enhanced_hero(portfolio, sections, get_color_scheme_name(colors))}

    <div class="masonry-layout" style="background: #{colors.background};">
      <!-- Masonry Section Header -->
      <header class="masonry-section-header py-16 text-center bg-white">
        <div class="max-w-6xl mx-auto px-6">
          <h2 class="text-4xl font-light mb-6" style="color: #{colors.primary};">Portfolio Showcase</h2>
          <p class="text-xl text-gray-600 max-w-3xl mx-auto">A curated collection of my work, experience, and expertise</p>
        </div>
      </header>

      <!-- Masonry Grid -->
      <main class="max-w-6xl mx-auto px-6 py-12">
        <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
          #{render_masonry_cards(sections, colors, theme)}
        </div>
      </main>
    </div>
    """
  end

  defp render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme) do
    """
    <!-- Enhanced Hero Section -->
    #{safe_render_enhanced_hero(portfolio, sections, get_color_scheme_name(colors))}

    <div class="standard-layout" style="background: #{colors.background};">
      <!-- Standard Sections -->
      <main class="max-w-4xl mx-auto px-6 py-12">
        <div class="text-center mb-12">
          <h2 class="text-3xl font-bold mb-4" style="color: #{colors.primary};">About & Experience</h2>
          <p class="text-lg text-gray-600">Learn more about my background and expertise</p>
        </div>

        <div class="space-y-8">
          #{render_standard_sections(sections, colors, theme)}
        </div>
      </main>
    </div>
    """
  end


  # ============================================================================
  # PATCH 2.6: ADD CARD RENDERING FUNCTIONS
  # ============================================================================
  # Add these card rendering functions:

defp render_dashboard_cards(sections, colors, theme) do
  sections
  |> Enum.with_index()
  |> Enum.map(fn {section, index} ->
    config = %{
      colors: colors,
      card_height: "300px",
      enable_modal: true,
      show_icons: true
    }
    render_fallback_enhanced_section_card(section, config, :fixed_height)
  end)
  |> Enum.join("")
end

defp render_timeline_items(sections, colors, theme) do
  sections
  |> Enum.with_index()
  |> Enum.map(fn {section, index} ->
    """
    <div class="timeline-item flex items-start">
      <!-- Timeline Marker -->
      <div class="flex-shrink-0 w-16 h-16 rounded-full flex items-center justify-center relative z-10" style="background: #{colors.accent};">
        #{get_section_icon_simple(section.section_type, "text-white")}
      </div>

      <!-- Enhanced Timeline Content -->
      <div class="ml-8 flex-1">
        #{render_fallback_enhanced_section_card(section, %{colors: colors, enable_modal: true}, :expandable)}
      </div>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_masonry_cards(sections, colors, theme) do
  sections
  |> Enum.map(fn section ->
    config = %{
      colors: colors,
      enable_modal: true,
      show_icons: true
    }
    render_fallback_enhanced_section_card(section, config, :modal)
  end)
  |> Enum.join("")
end

  defp render_dashboard_sidebar(portfolio, colors) do
    """
    <div class="sidebar-widget bg-white rounded-xl shadow-lg p-6 border border-gray-100">
      <h4 class="text-lg font-semibold mb-4" style="color: #{colors.primary};">Portfolio Stats</h4>
      <div class="space-y-3">
        <div class="flex justify-between">
          <span class="text-gray-600">Sections</span>
          <span class="font-medium">#{length(portfolio.sections || [])}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-600">Theme</span>
          <span class="font-medium capitalize">#{portfolio.theme || "Professional"}</span>
        </div>
        <div class="flex justify-between">
          <span class="text-gray-600">Status</span>
          <span class="text-green-600 font-medium">Live</span>
        </div>
      </div>
    </div>
    """
  end

  # ============================================================================
  # PATCH 2.7: ADD UTILITY FUNCTIONS
  # ============================================================================
  # Add these utility functions:

  defp get_section_icon(section_type, color_class \\ "text-gray-600") do
    case section_type do
      "hero" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z"/>
        </svg>
        """
      "about" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """
      "experience" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
        """
      "skills" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """
      "projects" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """
      "contact" ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """
      _ ->
        """
        <svg class="w-5 h-5 #{color_class}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
        """
    end
  end

  defp get_section_preview(section, max_length) do
    content = section.content || %{}
    preview = Map.get(content, "main_content") ||
            Map.get(content, "summary") ||
            Map.get(content, "description") ||
            "Content available in full view"

    if String.length(preview) > max_length do
      String.slice(preview, 0, max_length) <> "..."
    else
      preview
    end
  end

  defp format_section_type(section_type) do
    case section_type do
      "hero" -> "Hero Section"
      "about" -> "About Me"
      "experience" -> "Experience"
      "skills" -> "Skills"
      "projects" -> "Projects"
      "contact" -> "Contact"
      _ -> String.capitalize(to_string(section_type))
    end
  end

  defp get_random_card_height do
    heights = ["min-h-64", "min-h-80", "min-h-96", "min-h-72"]
    Enum.random(heights)
  end

  # ============================================================================
  # PATCH 2.8: ADD REMAINING LAYOUT RENDERERS
  # ============================================================================
  # Add the remaining layout renderers:

  defp render_magazine_enhanced_layout(portfolio, sections, colors, theme) do
    render_standard_enhanced_layout(portfolio, sections, colors, theme)
  end

  defp render_minimal_enhanced_layout(portfolio, sections, colors, theme) do
    render_standard_enhanced_layout(portfolio, sections, colors, theme)
  end

  defp render_standard_sections(sections, colors, theme) do
    sections
    |> Enum.map(fn section ->
      config = %{
        colors: colors,
        enable_modal: false,
        show_icons: true
      }
      render_fallback_enhanced_section_card(section, config, :standard)
    end)
    |> Enum.join("")
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

defp render_enhanced_skills_content(section, colors) do
  content = section.content || %{}
  skills = Map.get(content, "skills", [])
  main_content = Map.get(content, "main_content", "")

  main_html = if String.length(main_content) > 0 do
    "<div class=\"prose max-w-none text-gray-700 mb-8\">#{format_enhanced_text(main_content)}</div>"
  else
    ""
  end

  skills_html = if length(skills) > 0 do
    "<div class=\"flex flex-wrap gap-2\">#{render_enhanced_skills_list(skills, colors)}</div>"
  else
    ""
  end

  """
  <div class="enhanced-skills-content">
    #{main_html}
    #{skills_html}
  </div>
  """
end

defp render_enhanced_skill_categories(skill_categories, colors) do
  "Skills categories: #{map_size(skill_categories)} categories"
end

defp render_enhanced_skills_list(skills, colors) do
  "Skills: #{length(skills)} skills"
end

defp render_enhanced_hero_section(assigns) do
  # Use EnhancedHeroRenderer for hero section
  hero_html = safe_render_enhanced_hero(
    assigns.portfolio,
    assigns.sections,
    assigns.color_scheme
  )

  raw(hero_html)
end

  defp safe_render_enhanced_hero(portfolio, sections, color_scheme) do
    try do
      EnhancedHeroRenderer.render_enhanced_hero(
        portfolio,
        sections,
        color_scheme
      )
    rescue
      e ->
        IO.puts("⚠️ EnhancedHeroRenderer not available, using fallback: #{inspect(e)}")
        render_fallback_enhanced_hero(portfolio, sections, color_scheme)
    end
  end

defp render_fallback_enhanced_hero(portfolio, sections, color_scheme) do
  colors = get_simple_color_palette(color_scheme)

  # Check for hero section
  hero_section = Enum.find(sections, &(&1.section_type == "hero"))

  # Check for intro video
  intro_video = find_intro_video_in_sections(sections)

  # Determine hero type based on available content
  cond do
    intro_video -> render_video_enhanced_hero(portfolio, intro_video, colors)
    hero_section -> render_section_enhanced_hero(portfolio, hero_section, colors)
    true -> render_default_enhanced_hero(portfolio, colors)
  end
end

defp render_section_enhanced_hero(portfolio, hero_section, colors) do
  content = hero_section.content || %{}
  headline = Map.get(content, "headline", hero_section.title)
  tagline = Map.get(content, "tagline", portfolio.description)
  main_content = Map.get(content, "main_content", "")
  cta_text = Map.get(content, "cta_text", "")
  cta_link = Map.get(content, "cta_link", "")
  social_links = extract_social_links_from_portfolio(portfolio)

  """
  <section class="section-enhanced-hero relative overflow-hidden" style="background: linear-gradient(135deg, #{colors.primary} 0%, #{colors.secondary} 100%);">
    <!-- Animated Background Elements -->
    <div class="absolute inset-0">
      <div class="absolute top-10 left-10 w-20 h-20 bg-white bg-opacity-10 rounded-full animate-pulse"></div>
      <div class="absolute top-32 right-20 w-16 h-16 bg-white bg-opacity-5 rounded-full animate-pulse delay-1000"></div>
      <div class="absolute bottom-20 left-32 w-24 h-24 bg-white bg-opacity-10 rounded-full animate-pulse delay-2000"></div>
    </div>

    <!-- Hero Content -->
    <div class="relative z-10 min-h-screen flex items-center">
      <div class="max-w-6xl mx-auto px-6 py-20 text-center">
        <div class="max-w-4xl mx-auto">
          <!-- Main Headline -->
          <h1 class="text-5xl lg:text-7xl font-bold text-white mb-8 leading-tight">
            #{headline}
          </h1>

          <!-- Tagline -->
          #{if tagline do
            """
            <p class="text-2xl lg:text-3xl text-white opacity-90 mb-8 font-light">
              #{tagline}
            </p>
            """
          else
            ""
          end}

          <!-- Main Content -->
          #{if String.length(main_content) > 0 do
            """
            <div class="text-lg text-white opacity-80 mb-12 max-w-3xl mx-auto leading-relaxed">
              #{main_content}
            </div>
            """
          else
            ""
          end}

          <!-- CTA Buttons -->
          <div class="flex flex-col sm:flex-row gap-6 justify-center mb-12">
            #{if String.length(cta_text) > 0 and String.length(cta_link) > 0 do
              """
              <a href="#{cta_link}" class="inline-flex items-center px-8 py-4 bg-white text-gray-900 rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
                #{cta_text}
                <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
                </svg>
              </a>
              """
            else
              """
              <button class="inline-flex items-center px-8 py-4 bg-white text-gray-900 rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
                Explore Portfolio
                <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
                </svg>
              </button>
              """
            end}

            <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:text-gray-900 transition-all duration-300">
              Contact Me
            </button>
          </div>

          <!-- Social Links -->
          #{if length(social_links) > 0, do: render_hero_social_links(social_links, colors), else: ""}
        </div>
      </div>
    </div>

    <!-- Scroll Indicator -->
    <div class="absolute bottom-8 left-1/2 transform -translate-x-1/2 text-white animate-bounce">
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 14l-7 7m0 0l-7-7m7 7V3"/>
      </svg>
    </div>
  </section>
  """
end

defp render_default_enhanced_hero(portfolio, colors) do
  social_links = extract_social_links_from_portfolio(portfolio)

  """
  <section class="default-enhanced-hero relative overflow-hidden" style="background: linear-gradient(135deg, #{colors.primary} 0%, #{colors.secondary} 100%);">
    <!-- Geometric Background -->
    <div class="absolute inset-0">
      <svg class="absolute inset-0 w-full h-full" viewBox="0 0 1200 800" fill="none">
        <defs>
          <pattern id="hero-pattern" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
            <circle cx="50" cy="50" r="1" fill="white" opacity="0.1"/>
          </pattern>
        </defs>
        <rect width="1200" height="800" fill="url(#hero-pattern)"/>
      </svg>
    </div>

    <!-- Hero Content -->
    <div class="relative z-10 min-h-screen flex items-center">
      <div class="max-w-6xl mx-auto px-6 py-20">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <!-- Left Column: Content -->
          <div class="text-white">
            <div class="inline-flex items-center px-4 py-2 bg-white bg-opacity-20 backdrop-blur-sm rounded-full text-sm font-medium mb-6">
              <span class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></span>
              Available for opportunities
            </div>

            <h1 class="text-5xl lg:text-6xl font-bold mb-6 leading-tight">
              #{portfolio.title}
            </h1>

            <p class="text-xl lg:text-2xl mb-8 text-white opacity-90 leading-relaxed">
              #{portfolio.description || "Professional Portfolio showcasing expertise, experience, and achievements in my field."}
            </p>

            <!-- Quick Stats -->
            <div class="grid grid-cols-3 gap-6 mb-8">
              <div class="text-center">
                <div class="text-2xl font-bold">#{length(portfolio.sections || [])}</div>
                <div class="text-sm opacity-75">Sections</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold">#{get_experience_years(portfolio)}</div>
                <div class="text-sm opacity-75">Years Exp</div>
              </div>
              <div class="text-center">
                <div class="text-2xl font-bold">#{get_projects_count(portfolio)}</div>
                <div class="text-sm opacity-75">Projects</div>
              </div>
            </div>

            <!-- CTA Buttons -->
            <div class="flex flex-col sm:flex-row gap-4 mb-8">
              <button class="px-8 py-4 bg-white text-gray-900 rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
                View My Work
              </button>
              <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:text-gray-900 transition-all duration-300">
                Download Resume
              </button>
            </div>

            <!-- Social Links -->
            #{if length(social_links) > 0, do: render_hero_social_links(social_links, colors), else: ""}
          </div>

          <!-- Right Column: Visual Element -->
          <div class="lg:block hidden">
            <div class="relative">
              <div class="aspect-square bg-white bg-opacity-10 backdrop-blur-sm rounded-3xl p-8 transform rotate-3 hover:rotate-0 transition-transform duration-500">
                <div class="h-full bg-white bg-opacity-10 rounded-2xl flex items-center justify-center">
                  <div class="text-center text-white">
                    <div class="w-24 h-24 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4">
                      <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                      </svg>
                    </div>
                    <h3 class="text-xl font-semibold">Professional</h3>
                    <p class="text-sm opacity-75">Portfolio</p>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
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
      # Use enhanced content renderer with default color scheme
      render_enhanced_section_content(section, "blue")
    rescue
      _ ->
        raw("<p>Content loading...</p>")
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

  @impl true
  def handle_event("show_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, true)}
  end

  @impl true
  def handle_event("hide_video_modal", _params, socket) do
    {:noreply, assign(socket, :show_video_modal, false)}
  end


  defp render_hero_section_enhanced(assigns) do
    raw(EnhancedHeroRenderer.render_enhanced_hero(assigns.portfolio, assigns.sections, assigns.color_scheme))
  end

  defp render_video_enhanced_layout(assigns) do
  # Use the enhanced hero for video layouts
  hero_html = EnhancedHeroRenderer.render_enhanced_hero(assigns.portfolio, assigns.sections, assigns.color_scheme)

  # Then render the rest of your layout
  """
  #{raw(hero_html)}

  <!-- Rest of your existing layout content -->
  <main class="portfolio-content">
    <!-- Your existing sections rendering -->
  </main>
  """
end






  defp render_hero_section_content(content) do
    try do
      headline = get_safe_text(content, "headline")
      tagline = get_safe_text(content, "tagline")
      main_content = get_safe_content(content, "main_content")
      cta_text = get_safe_text(content, "cta_text")
      cta_link = get_safe_text(content, "cta_link")
      show_social = Map.get(content, "show_social", false)
      social_links = Map.get(content, "social_links", %{})

      hero_html = """
      <div class="hero-content text-center py-8">
        #{if String.length(headline) > 0, do: "<h1 class='text-4xl font-bold text-gray-900 mb-4'>#{headline}</h1>", else: ""}
        #{if String.length(tagline) > 0, do: "<p class='text-xl text-blue-600 font-medium mb-6'>#{tagline}</p>", else: ""}
        #{if String.length(main_content) > 0, do: "<div class='text-gray-700 mb-8 max-w-2xl mx-auto'>#{main_content}</div>", else: ""}
        #{if String.length(cta_text) > 0 and String.length(cta_link) > 0, do: "<a href='#{cta_link}' class='inline-flex items-center px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 transition-colors'>#{cta_text}</a>", else: ""}
        #{if show_social, do: render_social_links_safe(social_links), else: ""}
      </div>
      """

      raw(hero_html)
    rescue
      error ->
        IO.puts("❌ Error in render_hero_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Hero content is being processed...</p>
        </div>
        """)
    end
  end

  defp render_experience_section_content(content) do
    try do
      # Try multiple possible keys for jobs data
      jobs = Map.get(content, "jobs", [])
            |> case do
              [] -> Map.get(content, :jobs, [])
              jobs when is_list(jobs) -> jobs
              _ -> []
            end

      if length(jobs) > 0 do
        jobs_html = jobs
        |> Enum.map(fn job ->
          # Handle both string and atom keys, multiple possible field names
          title = get_job_field(job, ["title", "job_title", "position"])
          company = get_job_field(job, ["company", "company_name", "employer"])
          start_date = get_job_field(job, ["start_date", "startDate", "from"])
          end_date = get_job_field(job, ["end_date", "endDate", "to"])
          current = get_job_boolean(job, ["current", "is_current", "present"])
          description = get_job_field(job, ["description", "responsibilities", "details", "summary"])

          # Format date range
          date_range = cond do
            current -> "#{start_date} - Present"
            String.length(end_date) > 0 -> "#{start_date} - #{end_date}"
            String.length(start_date) > 0 -> "#{start_date} - Present"
            true -> ""
          end

          """
          <div class="experience-item mb-8 pb-8 border-b border-gray-200 last:border-b-0">
            <div class="flex flex-col md:flex-row md:items-start md:justify-between mb-4">
              <div>
                <h3 class="text-xl font-semibold text-gray-900">#{title}</h3>
                <p class="text-lg text-blue-600 font-medium">#{company}</p>
              </div>
              #{if String.length(date_range) > 0, do: "<div class='text-sm text-gray-500 md:text-right mt-2 md:mt-0'>#{date_range}</div>", else: ""}
            </div>
            #{if String.length(description) > 0, do: "<div class='text-gray-700'>#{description}</div>", else: ""}
          </div>
          """
        end)
        |> Enum.join("")

        raw("""
        <div class="experience-content">
          #{jobs_html}
        </div>
        """)
      else
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Work experience will be displayed here.</p>
        </div>
        """)
      end
    rescue
      error ->
        IO.puts("❌ Error in render_experience_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Experience content is being processed...</p>
        </div>
        """)
    end
  end

  defp render_skills_section_content(content) do
    try do
      # Try multiple possible keys for skills data
      skills = Map.get(content, "skills", [])
              |> case do
                [] -> Map.get(content, :skills, [])
                skills when is_list(skills) -> skills
                _ -> []
              end

      if length(skills) > 0 do
        skills_html = skills
        |> Enum.group_by(fn skill ->
          category = get_skill_field(skill, ["category", "skill_category", "type"])
          if String.length(category) > 0, do: category, else: "General"
        end)
        |> Enum.map(fn {category, category_skills} ->
          skills_list = category_skills
          |> Enum.map(fn skill ->
            name = get_skill_field(skill, ["name", "skill_name", "title"])
            level = get_skill_field(skill, ["level", "proficiency", "expertise"])

            level_class = case String.downcase(level) do
              l when l in ["beginner", "basic", "novice"] -> "bg-yellow-100 text-yellow-800"
              l when l in ["intermediate", "proficient", "good"] -> "bg-blue-100 text-blue-800"
              l when l in ["advanced", "excellent", "strong"] -> "bg-green-100 text-green-800"
              l when l in ["expert", "master", "exceptional"] -> "bg-purple-100 text-purple-800"
              _ -> "bg-gray-100 text-gray-800"
            end

            if String.length(name) > 0 do
              """
              <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{level_class} mr-2 mb-2">
                #{name}
              </span>
              """
            else
              ""
            end
          end)
          |> Enum.reject(&(&1 == ""))
          |> Enum.join("")

          if String.length(skills_list) > 0 do
            """
            <div class="skill-category mb-6">
              <h4 class="text-lg font-semibold text-gray-900 mb-3">#{category}</h4>
              <div class="flex flex-wrap">
                #{skills_list}
              </div>
            </div>
            """
          else
            ""
          end
        end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("")

        if String.length(skills_html) > 0 do
          raw("""
          <div class="skills-content">
            #{skills_html}
          </div>
          """)
        else
          raw("""
          <div class="text-center py-8 text-gray-500">
            <p>Skills and expertise will be displayed here.</p>
          </div>
          """)
        end
      else
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Skills and expertise will be displayed here.</p>
        </div>
        """)
      end
    rescue
      error ->
        IO.puts("❌ Error in render_skills_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Skills content is being processed...</p>
        </div>
        """)
    end
  end

  defp render_projects_section_content(content) do
    try do
      # Try multiple possible keys for projects data
      projects = Map.get(content, "projects", [])
                |> case do
                  [] -> Map.get(content, :projects, [])
                  projects when is_list(projects) -> projects
                  _ -> []
                end

      if length(projects) > 0 do
        projects_html = projects
        |> Enum.map(fn project ->
          title = get_project_field(project, ["title", "name", "project_name"])
          description = get_project_field(project, ["description", "summary", "details"])
          demo_url = get_project_field(project, ["demo_url", "url", "link", "demo_link"])
          github_url = get_project_field(project, ["github_url", "code_url", "repository", "repo"])
          technologies = get_project_technologies(project, ["technologies", "tech", "stack", "tools"])
          year = get_project_field(project, ["year", "date", "created"])
          status = get_project_field(project, ["status", "state"])

          status_class = case String.downcase(status) do
            s when s in ["completed", "done", "finished"] -> "bg-green-100 text-green-800"
            s when s in ["in-progress", "ongoing", "active"] -> "bg-yellow-100 text-yellow-800"
            s when s in ["concept", "idea", "planned"] -> "bg-blue-100 text-blue-800"
            _ -> "bg-gray-100 text-gray-800"
          end

          tech_tags = if length(technologies) > 0 do
            technologies
            |> Enum.take(5)
            |> Enum.map(fn tech ->
              safe_tech = get_safe_text_from_value(tech)
              if String.length(safe_tech) > 0 do
                """
                <span class="inline-block px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded mr-1 mb-1">
                  #{safe_tech}
                </span>
                """
              else
                ""
              end
            end)
            |> Enum.join("")
          else
            ""
          end

          links_html = [
            if(String.length(demo_url) > 0, do: "<a href='#{demo_url}' target='_blank' class='inline-flex items-center px-3 py-1 bg-blue-600 text-white text-sm rounded hover:bg-blue-700 mr-2'>View Demo</a>", else: ""),
            if(String.length(github_url) > 0, do: "<a href='#{github_url}' target='_blank' class='inline-flex items-center px-3 py-1 bg-gray-800 text-white text-sm rounded hover:bg-gray-900'>View Code</a>", else: "")
          ] |> Enum.reject(&(&1 == "")) |> Enum.join("")

          """
          <div class="project-item bg-white rounded-lg border border-gray-200 p-6 mb-6">
            <div class="flex items-start justify-between mb-4">
              <div>
                <h3 class="text-xl font-semibold text-gray-900">#{title}</h3>
                <div class="flex items-center space-x-2 mt-2">
                  #{if String.length(status) > 0, do: "<span class='px-2 py-1 text-xs font-medium rounded #{status_class}'>#{String.capitalize(status)}</span>", else: ""}
                  #{if String.length(year) > 0, do: "<span class='text-sm text-gray-500'>#{year}</span>", else: ""}
                </div>
              </div>
            </div>
            #{if String.length(description) > 0, do: "<p class='text-gray-700 mb-4'>#{description}</p>", else: ""}
            #{if String.length(tech_tags) > 0, do: "<div class='mb-4'>#{tech_tags}</div>", else: ""}
            #{if String.length(links_html) > 0, do: "<div class='flex items-center space-x-2'>#{links_html}</div>", else: ""}
          </div>
          """
        end)
        |> Enum.join("")

        raw("""
        <div class="projects-content">
          #{projects_html}
        </div>
        """)
      else
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Projects and portfolio work will be displayed here.</p>
        </div>
        """)
      end
    rescue
      error ->
        IO.puts("❌ Error in render_projects_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Projects content is being processed...</p>
        </div>
        """)
    end
  end

  defp render_contact_section_content(content) do
    main_content = safe_html_content(Map.get(content, "main_content", ""))
    email = safe_text_content(Map.get(content, "email", ""))
    phone = safe_text_content(Map.get(content, "phone", ""))
    location = safe_text_content(Map.get(content, "location", ""))
    website = safe_text_content(Map.get(content, "website", ""))
    show_social = Map.get(content, "show_social", false)
    social_links = Map.get(content, "social_links", %{})

    contact_info = [
      if(email != "", do: "<div class='flex items-center mb-3'><span class='text-blue-600 mr-3'>📧</span><a href='mailto:#{email}' class='text-blue-600 hover:text-blue-800'>#{email}</a></div>", else: ""),
      if(phone != "", do: "<div class='flex items-center mb-3'><span class='text-blue-600 mr-3'>📱</span><a href='tel:#{phone}' class='text-blue-600 hover:text-blue-800'>#{phone}</a></div>", else: ""),
      if(location != "", do: "<div class='flex items-center mb-3'><span class='text-blue-600 mr-3'>📍</span><span class='text-gray-700'>#{location}</span></div>", else: ""),
      if(website != "", do: "<div class='flex items-center mb-3'><span class='text-blue-600 mr-3'>🌐</span><a href='#{website}' target='_blank' class='text-blue-600 hover:text-blue-800'>#{website}</a></div>", else: "")
    ] |> Enum.reject(&(&1 == "")) |> Enum.join("")

    Phoenix.HTML.raw("""
      <div class="contact-content">
        #{if main_content != "", do: "<div class='text-gray-700 mb-6 text-center'>#{main_content}</div>", else: ""}
        #{if contact_info != "", do: "<div class='bg-gray-50 rounded-lg p-6 mb-6'>#{contact_info}</div>", else: ""}
        #{if show_social, do: render_social_links_safe(social_links), else: ""}
      </div>
    """)
  end

  defp render_about_section_content(content) do
    try do
      main_content = get_safe_content(content, "main_content")
      subtitle = get_safe_text(content, "subtitle")
      show_stats = Map.get(content, "show_stats", false)
      stats = Map.get(content, "stats", %{})

      stats_html = if show_stats and map_size(stats) > 0 do
        stats_items = stats
        |> Enum.map(fn {key, value} ->
          safe_value = get_safe_text_from_value(value)
          if String.length(safe_value) > 0 do
            label = key |> to_string() |> String.replace("_", " ") |> String.capitalize()
            """
            <div class="text-center">
              <div class="text-2xl font-bold text-blue-600">#{safe_value}</div>
              <div class="text-sm text-gray-600">#{html_escape(label)}</div>
            </div>
            """
          else
            ""
          end
        end)
        |> Enum.reject(&(&1 == ""))
        |> Enum.join("")

        if String.length(stats_items) > 0 do
          """
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4 bg-gray-50 rounded-lg p-6 mt-6">
            #{stats_items}
          </div>
          """
        else
          ""
        end
      else
        ""
      end

      about_html = """
      <div class="about-content">
        #{if String.length(subtitle) > 0, do: "<p class='text-lg text-blue-600 font-medium mb-4'>#{subtitle}</p>", else: ""}
        #{if String.length(main_content) > 0, do: "<div class='text-gray-700 leading-relaxed'>#{main_content}</div>", else: ""}
        #{stats_html}
      </div>
      """

      raw(about_html)
    rescue
      error ->
        IO.puts("❌ Error in render_about_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>About content is being processed...</p>
        </div>
        """)
    end
  end


  defp render_education_section_content(content) do
    education = Map.get(content, "education", [])

    if length(education) > 0 do
      education_html = education
      |> Enum.map(fn edu ->
        degree = Map.get(edu, "degree", "")
        school = Map.get(edu, "school", "")
        year = Map.get(edu, "year", "")
        description = Map.get(edu, "description", "")

        """
        <div class="education-item mb-6 pb-6 border-b border-gray-200 last:border-b-0">
          <div class="flex flex-col md:flex-row md:items-start md:justify-between mb-2">
            <div>
              <h3 class="text-lg font-semibold text-gray-900">#{Phoenix.HTML.html_escape(degree)}</h3>
              <p class="text-blue-600 font-medium">#{Phoenix.HTML.html_escape(school)}</p>
            </div>
            #{if year != "", do: "<div class='text-sm text-gray-500 md:text-right mt-1 md:mt-0'>#{Phoenix.HTML.html_escape(year)}</div>", else: ""}
          </div>
          #{if description != "", do: "<p class='text-gray-700'>#{Phoenix.HTML.html_escape(description)}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      Phoenix.HTML.raw("""
        <div class="education-content">
          #{education_html}
        </div>
      """)
    else
      Phoenix.HTML.raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Educational background will be displayed here.</p>
        </div>
      """)
    end
  end

  defp render_custom_section_content(content) do
    main_content = Map.get(content, "main_content", "")
    section_subtype = Map.get(content, "section_subtype", "text")

    Phoenix.HTML.raw("""
      <div class="custom-content">
        #{if main_content != "", do: "<div class='text-gray-700'>#{Phoenix.HTML.html_escape(main_content)}</div>", else: "<div class='text-center py-8 text-gray-500'><p>Custom content will be displayed here.</p></div>"}
      </div>
    """)
  end

  defp generate_portfolio_css(portfolio) do
    customization = portfolio.customization || %{}
    {theme, layout_type, color_scheme} = extract_enhanced_theme_settings(portfolio)

    # 🔥 SAFE: Use enhanced CSS with fallback
    safe_generate_comprehensive_css(theme, layout_type, color_scheme, customization)
  end

  defp get_simple_color_palette(scheme) do
    case scheme do
      "blue" -> %{
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa",
        background: "#fafafa",
        text_primary: "#1f2937"
      }
      "green" -> %{
        primary: "#065f46",
        secondary: "#059669",
        accent: "#34d399",
        background: "#f0fdf4",
        text_primary: "#064e3b"
      }
      "purple" -> %{
        primary: "#581c87",
        secondary: "#7c3aed",
        accent: "#a78bfa",
        background: "#faf5ff",
        text_primary: "#581c87"
      }
      "red" -> %{
        primary: "#991b1b",
        secondary: "#dc2626",
        accent: "#f87171",
        background: "#fef2f2",
        text_primary: "#991b1b"
      }
      "orange" -> %{
        primary: "#ea580c",
        secondary: "#f97316",
        accent: "#fb923c",
        background: "#fff7ed",
        text_primary: "#ea580c"
      }
      "teal" -> %{
        primary: "#0f766e",
        secondary: "#14b8a6",
        accent: "#5eead4",
        background: "#f0fdfa",
        text_primary: "#134e4a"
      }
      _ -> %{
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa",
        background: "#fafafa",
        text_primary: "#1f2937"
      }
    end
  end

  defp get_show_color_palette(scheme) do
    case scheme do
      "blue" -> %{
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa",
        background: "#fafafa",
        text_primary: "#1f2937"
      }
      "green" -> %{
        primary: "#065f46",
        secondary: "#059669",
        accent: "#34d399",
        background: "#f0fdf4",
        text_primary: "#064e3b"
      }
      "purple" -> %{
        primary: "#581c87",
        secondary: "#7c3aed",
        accent: "#a78bfa",
        background: "#faf5ff",
        text_primary: "#581c87"
      }
      _ -> %{
        primary: "#1e40af",
        secondary: "#3b82f6",
        accent: "#60a5fa",
        background: "#fafafa",
        text_primary: "#1f2937"
      }
    end
  end

  defp get_show_template_class(theme, layout) do
    "template-#{theme}-#{layout}"
  end

  defp get_show_layout_styles(layout) do
    case layout do
      "dashboard" -> """
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
        gap: 2rem;
        max-width: 1400px;
        margin: 0 auto;
        padding: 2rem;
      """
      "grid" -> """
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
        gap: 1.5rem;
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
      """
      "timeline" -> """
        display: flex;
        flex-direction: column;
        max-width: 900px;
        margin: 0 auto;
        padding: 2rem;
        gap: 3rem;
      """
      "magazine" -> """
        column-count: 2;
        column-gap: 2rem;
        max-width: 1000px;
        margin: 0 auto;
        padding: 2rem;
      """
      "minimal" -> """
        max-width: 800px;
        margin: 0 auto;
        padding: 4rem 2rem;
      """
      _ -> """
        max-width: 1200px;
        margin: 0 auto;
        padding: 2rem;
      """
    end
  end

  defp get_show_theme_styles(theme, colors) do
    case theme do
      "creative" -> """
        .template-creative-dashboard .portfolio-section:nth-child(odd) {
          transform: rotate(-1deg);
          border-left: 5px solid #{colors.accent};
        }
        .template-creative-dashboard .portfolio-section:nth-child(even) {
          transform: rotate(1deg);
          border-right: 5px solid #{colors.accent};
        }
      """
      "minimal" -> """
        .template-minimal-dashboard .portfolio-section {
          box-shadow: none;
          border: 2px solid #{colors.primary};
          background: white;
        }
      """
      "modern" -> """
        .template-modern-dashboard .portfolio-section {
          border-top: 4px solid #{colors.primary};
          box-shadow: 0 8px 20px rgba(0,0,0,0.12);
        }
      """
      _ -> ""
    end
  end

  defp render_generic_section_content(content) do
    try do
      main_content = get_safe_content(content, "main_content")

      if String.length(main_content) > 0 do
        raw("""
        <div class="generic-content text-gray-700">
          #{main_content}
        </div>
        """)
      else
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Content will be displayed here when added.</p>
        </div>
        """)
      end
    rescue
      error ->
        IO.puts("❌ Error in render_generic_section_content: #{inspect(error)}")
        raw("""
        <div class="text-center py-8 text-gray-500">
          <p>Content is being processed...</p>
        </div>
        """)
    end
  end

  defp render_social_links_safe(social_links) when is_map(social_links) do
    try do
      if map_size(social_links) > 0 do
        links_html = social_links
        |> Enum.filter(fn {_, url} ->
          safe_url = get_safe_text_from_value(url)
          String.length(safe_url) > 0
        end)
        |> Enum.map(fn {platform, url} ->
          safe_platform = get_safe_text_from_value(platform)
          safe_url = get_safe_text_from_value(url)

          icon = case safe_platform do
            "linkedin" -> "💼"
            "github" -> "👨‍💻"
            "twitter" -> "🐦"
            "instagram" -> "📸"
            "facebook" -> "👥"
            "youtube" -> "📺"
            "website" -> "🌐"
            "email" -> "📧"
            _ -> "🔗"
          end

          """
          <a href="#{safe_url}" target="_blank" class="inline-flex items-center justify-center w-10 h-10 bg-gray-100 hover:bg-gray-200 rounded-full transition-colors mr-2 mb-2" title="#{String.capitalize(safe_platform)}">
            <span class="text-lg">#{icon}</span>
          </a>
          """
        end)
        |> Enum.join("")

        if String.length(links_html) > 0 do
          """
          <div class="social-links mt-6 text-center">
            <h4 class="text-lg font-medium text-gray-900 mb-4">Connect with me</h4>
            <div class="flex justify-center flex-wrap">
              #{links_html}
            </div>
          </div>
          """
        else
          ""
        end
      else
        ""
      end
    rescue
      _ -> ""
    end
  end

  defp render_social_links_safe(_), do: ""

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
  # LAYOUT RENDERING FUNCTIONS
  # ============================================================================

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
              <%= raw(EnhancedContentRenderer.render_enhanced_section_content(section, @color_scheme)) %>
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
      # Try to load from database or create default zones
      %{
        hero: [],
        main_content: [],
        sidebar: [],
        footer: []
      }
    rescue
      _ ->
        IO.puts("⚠️ Could not load dynamic layout zones for portfolio #{portfolio_id}")
        %{}
    end
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

  defp get_section_icon_simple(section_type, color_class \\ "text-gray-600") do
    case section_type do
      "hero" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M11.049 2.927c.3-.921 1.603-.921 1.902 0l1.519 4.674a1 1 0 00.95.69h4.915c.969 0 1.371 1.24.588 1.81l-3.976 2.888a1 1 0 00-.363 1.118l1.518 4.674c.3.922-.755 1.688-1.538 1.118l-3.976-2.888a1 1 0 00-1.176 0l-3.976 2.888c-.783.57-1.838-.197-1.538-1.118l1.518-4.674a1 1 0 00-.363-1.118l-3.976-2.888c-.784-.57-.38-1.81.588-1.81h4.914a1 1 0 00.951-.69l1.519-4.674z\"/></svg>"

      "about" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z\"/></svg>"

      "experience" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z\"/></svg>"

      "skills" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z\"/></svg>"

      "projects" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10\"/></svg>"

      "portfolio" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10\"/></svg>"

      "contact" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z\"/></svg>"

      "education" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 14l9-5-9-5-9 5 9 5z\"/><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 14l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14z\"/><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M12 14l9-5-9-5-9 5 9 5zm0 0l6.16-3.422a12.083 12.083 0 01.665 6.479A11.952 11.952 0 0012 20.055a11.952 11.952 0 00-6.824-2.998 12.078 12.078 0 01.665-6.479L12 14zm-4 6v-7.5l4-2.222\"/></svg>"

      "testimonials" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z\"/></svg>"

      "achievements" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z\"/></svg>"

      "services" ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z\"/><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M15 12a3 3 0 11-6 0 3 3 0 016 0z\"/></svg>"

      _ ->
        "<svg class=\"w-5 h-5 #{color_class}\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z\"/></svg>"
    end
  end

  defp render_enhanced_section_card(section, assigns) do
  # Use EnhancedSectionCards for individual section rendering
  card_html = safe_render_enhanced_section_card(
    section,
    assigns.section_card_config,
    :fixed_height
  )

  raw(card_html)
end

defp safe_render_enhanced_section_card(section, config, card_type) do
  try do
    EnhancedSectionCards.render_section_card(
      section,
      config,
      card_type
    )
  rescue
    e ->
      IO.puts("⚠️ EnhancedSectionCards not available, using fallback: #{inspect(e)}")
      render_fallback_enhanced_section_card(section, config, card_type)
  end
end

# ============================================================================
# PATCH 4.2: ADD FALLBACK ENHANCED SECTION CARDS
# ============================================================================
# Add this fallback section card renderer:

defp render_fallback_enhanced_section_card(section, config, card_type) do
  colors = Map.get(config, :colors, get_simple_color_palette("blue"))

  case card_type do
    :fixed_height ->
      render_fixed_height_card(section, colors, config)
    :expandable ->
      render_expandable_card(section, colors, config)
    :modal ->
      render_modal_card(section, colors, config)
    _ ->
      render_standard_card(section, colors, config)
  end
end

# ============================================================================
# PATCH 4.3: ADD FIXED HEIGHT CARD RENDERER
# ============================================================================
# Add this fixed height card renderer:

defp render_fixed_height_card(section, colors, config) do
  card_height = Map.get(config, :card_height, "350px")
  enable_modal = Map.get(config, :enable_modal, true)

  """
  <div class="enhanced-section-card bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden hover:shadow-xl transition-all duration-300 transform hover:-translate-y-1"
       style="height: #{card_height};"
       data-section-id="#{section.id}">

    <!-- Card Header -->
    <div class="card-header p-6 border-b border-gray-100" style="background: linear-gradient(135deg, #{colors.primary}10 0%, #{colors.accent}10 100%);">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 rounded-lg flex items-center justify-center" style="background: #{colors.primary}; color: white;">
            #{get_section_icon_simple(section.section_type, "text-white")}
          </div>
          <div>
            <h3 class="text-lg font-semibold" style="color: #{colors.primary};">#{section.title}</h3>
            <span class="text-xs text-gray-500 uppercase tracking-wide">#{format_section_type(section.section_type)}</span>
          </div>
        </div>

        #{if enable_modal do
          """
          <button class="expand-button w-8 h-8 rounded-full flex items-center justify-center transition-colors"
                  style="background: #{colors.accent}20; color: #{colors.accent};"
                  onclick="openSectionModal('#{section.id}')"
                  title="Expand section">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8V4m0 0h4M4 4l5 5m11-1V4m0 0h-4m4 0l-5 5M4 16v4m0 0h4m-4 0l5-5m11 5l-5-5m5 5v-4m0 4h-4"/>
            </svg>
          </button>
          """
        else
          ""
        end}
      </div>
    </div>

    <!-- Card Content (Scrollable) -->
    <div class="card-content p-6 overflow-y-auto" style="height: calc(#{card_height} - 120px);">
      <div class="prose prose-sm max-w-none text-gray-700">
        #{get_enhanced_section_preview(section, 300)}
      </div>

      <!-- Content Fade Effect -->
      <div class="absolute bottom-0 left-0 right-0 h-8 bg-gradient-to-t from-white to-transparent pointer-events-none"></div>
    </div>

    <!-- Card Footer -->
    <div class="card-footer absolute bottom-0 left-0 right-0 p-4 bg-white border-t border-gray-100">
      <div class="flex items-center justify-between">
        <div class="text-xs text-gray-500">
          #{get_section_word_count(section)} words
        </div>
        #{if enable_modal do
          """
          <button class="text-xs font-medium hover:underline"
                  style="color: #{colors.accent};"
                  onclick="openSectionModal('#{section.id}')">
            Read More →
          </button>
          """
        else
          ""
        end}
      </div>
    </div>
  </div>
  """
end

# ============================================================================
# PATCH 4.4: ADD EXPANDABLE CARD RENDERER
# ============================================================================
# Add this expandable card renderer:

defp render_expandable_card(section, colors, config) do
  """
  <div class="expandable-section-card bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden transition-all duration-500"
       data-section-id="#{section.id}">

    <!-- Card Header (Always Visible) -->
    <div class="card-header p-6 cursor-pointer"
         style="background: linear-gradient(135deg, #{colors.primary}10 0%, #{colors.accent}10 100%);"
         onclick="toggleCardExpansion('#{section.id}')">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-3">
          <div class="w-10 h-10 rounded-lg flex items-center justify-center" style="background: #{colors.primary}; color: white;">
            #{get_section_icon_simple(section.section_type, "text-white")}
          </div>
          <div>
            <h3 class="text-lg font-semibold" style="color: #{colors.primary};">#{section.title}</h3>
            <span class="text-xs text-gray-500 uppercase tracking-wide">#{format_section_type(section.section_type)}</span>
          </div>
        </div>

        <div class="expand-indicator transition-transform duration-300">
          <svg class="w-5 h-5" style="color: #{colors.accent};" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7"/>
          </svg>
        </div>
      </div>
    </div>

    <!-- Expandable Content -->
    <div class="card-content max-h-0 overflow-hidden transition-all duration-500" id="content-#{section.id}">
      <div class="p-6">
        <div class="prose max-w-none text-gray-700">
          #{get_enhanced_section_content(section)}
        </div>
      </div>
    </div>
  </div>
  """
end

# ============================================================================
# PATCH 4.5: ADD MODAL CARD RENDERER
# ============================================================================
# Add this modal card renderer:

defp render_modal_card(section, colors, config) do
  """
  <div class="modal-section-card bg-white rounded-xl shadow-lg border border-gray-100 overflow-hidden hover:shadow-xl transition-all duration-300"
       data-section-id="#{section.id}">

    <!-- Card Preview -->
    <div class="card-preview p-6 cursor-pointer" onclick="openSectionModal('#{section.id}')">
      <div class="flex items-center space-x-3 mb-4">
        <div class="w-12 h-12 rounded-lg flex items-center justify-center" style="background: #{colors.primary}; color: white;">
          #{get_section_icon_simple(section.section_type, "text-white")}
        </div>
        <div>
          <h3 class="text-xl font-semibold" style="color: #{colors.primary};">#{section.title}</h3>
          <span class="text-sm text-gray-500 uppercase tracking-wide">#{format_section_type(section.section_type)}</span>
        </div>
      </div>

      <div class="text-gray-700 mb-4">
        #{get_enhanced_section_preview(section, 150)}
      </div>

      <div class="flex items-center justify-between">
        <span class="text-xs text-gray-500">#{get_section_word_count(section)} words</span>
        <span class="text-sm font-medium" style="color: #{colors.accent};">
          Click to expand →
        </span>
      </div>
    </div>
  </div>
  """
end

# ============================================================================
# PATCH 4.6: ADD STANDARD CARD RENDERER
# ============================================================================
# Add this standard card renderer:

defp render_standard_card(section, colors, config) do
  """
  <div class="standard-section-card bg-white rounded-lg shadow-sm border border-gray-100 p-6">
    <div class="flex items-center space-x-3 mb-4">
      <div class="w-8 h-8 rounded-lg flex items-center justify-center" style="background: #{colors.primary}; color: white;">
        #{get_section_icon_simple(section.section_type, "text-white")}
      </div>
      <h3 class="text-lg font-semibold" style="color: #{colors.primary};">#{section.title}</h3>
    </div>

    <div class="prose max-w-none text-gray-700">
      #{get_enhanced_section_content(section)}
    </div>
  </div>
  """
end

# ============================================================================
# PATCH 4.7: ADD SECTION CARD UTILITY FUNCTIONS
# ============================================================================
# Add these utility functions:

defp get_enhanced_section_preview(section, max_length) do
  content = section.content || %{}

  # Try multiple content fields
  preview = Map.get(content, "main_content") ||
           Map.get(content, "summary") ||
           Map.get(content, "description") ||
           extract_text_from_structured_content(content) ||
           "Content available in full view"

  # Clean and truncate
  clean_preview = preview
  |> strip_html_basic()
  |> String.trim()

  if String.length(clean_preview) > max_length do
    String.slice(clean_preview, 0, max_length) <> "..."
  else
    clean_preview
  end
end

defp get_enhanced_section_content(section) do
  # Use the new enhanced content renderer
  render_fallback_enhanced_content(section, "blue") # Use default blue scheme for previews
end

defp extract_text_from_structured_content(content) do
  # Extract text from structured content like jobs, skills, projects
  cond do
    Map.has_key?(content, "jobs") ->
      jobs = Map.get(content, "jobs", [])
      jobs |> Enum.map(&Map.get(&1, "title", "")) |> Enum.join(", ")

    Map.has_key?(content, "skills") ->
      skills = Map.get(content, "skills", [])
      skills |> Enum.map(&get_skill_name/1) |> Enum.join(", ")

    Map.has_key?(content, "projects") ->
      projects = Map.get(content, "projects", [])
      projects |> Enum.map(&Map.get(&1, "title", "")) |> Enum.join(", ")

    true ->
      nil
  end
end

defp get_skill_name(skill) when is_map(skill), do: Map.get(skill, "name", "")
defp get_skill_name(skill) when is_binary(skill), do: skill
defp get_skill_name(_), do: ""

defp get_section_word_count(section) do
  content = get_enhanced_section_content(section)

  content
  |> strip_html_basic()
  |> String.split()
  |> length()
end

# ============================================================================
# PATCH 4.8: ADD STRUCTURED CONTENT RENDERERS
# ============================================================================
# Add these structured content renderers:

defp render_experience_card_content(content) do
  # Create a mock section for enhanced rendering
  mock_section = %{
    section_type: "experience",
    content: content
  }

  # Use enhanced content renderer but strip HTML for card preview
  enhanced_html = render_fallback_enhanced_content(mock_section, "blue")

  # Return HTML directly for card display
  enhanced_html
end

defp render_skills_card_content(content) do
  mock_section = %{
    section_type: "skills",
    content: content
  }

  render_fallback_enhanced_content(mock_section, "blue")
end

defp render_projects_card_content(content) do
  mock_section = %{
    section_type: "projects",
    content: content
  }

  render_fallback_enhanced_content(mock_section, "blue")
end

defp render_education_card_content(content) do
  mock_section = %{
    section_type: "education",
    content: content
  }

  render_fallback_enhanced_content(mock_section, "blue")
end

defp render_contact_card_content(content) do
  email = Map.get(content, "email", "")
  phone = Map.get(content, "phone", "")
  location = Map.get(content, "location", "")

  contact_items = [
    if(String.length(email) > 0, do: "📧 #{email}", else: nil),
    if(String.length(phone) > 0, do: "📱 #{phone}", else: nil),
    if(String.length(location) > 0, do: "📍 #{location}", else: nil)
  ]
  |> Enum.reject(&is_nil/1)

  if length(contact_items) > 0 do
    contact_items |> Enum.join("<br>")
  else
    Map.get(content, "main_content", "Contact information not available")
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

  defp get_safe_content(content_map, key) when is_map(content_map) do
    try do
      value = Map.get(content_map, key, "")
      extract_safe_html(value)
    rescue
      _ -> ""
    end
  end

  defp get_safe_content(_, _), do: ""

  # Ultra-safe text getter that always escapes
  defp get_safe_text(content_map, key) when is_map(content_map) do
    try do
      value = Map.get(content_map, key, "")
      extract_safe_text(value)
    rescue
      _ -> ""
    end
  end

  defp get_safe_text(_, _), do: ""

  # Ultra-safe value converter
  defp get_safe_text_from_value(value) do
    try do
      extract_safe_text(value)
    rescue
      _ -> ""
    end
  end

  defp extract_safe_html(value) do
    case value do
      {:safe, html_content} when is_binary(html_content) ->
        html_content
      content when is_binary(content) ->
        html_escape(content) |> safe_to_string()
      nil ->
        ""
      _ ->
        value |> to_string() |> html_escape() |> safe_to_string()
    end
  end

  # Extract safe text content (always escaped)
  defp extract_safe_text(value) do
    case value do
      {:safe, html_content} when is_binary(html_content) ->
        html_content |> strip_html_basic() |> html_escape() |> safe_to_string()
      content when is_binary(content) ->
        html_escape(content) |> safe_to_string()
      nil ->
        ""
      _ ->
        value |> to_string() |> html_escape() |> safe_to_string()
    end
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


  defp get_enhanced_hero_styles(theme, colors) do
    case theme do
      "creative" ->
        "background: linear-gradient(135deg, #{colors.primary}, #{colors.accent}) !important; color: white !important;"
      "minimal" ->
        "background: #{colors.surface} !important; color: #{colors.text_primary} !important; border: 2px solid #{colors.primary} !important;"
      "modern" ->
        "background: linear-gradient(45deg, #{colors.primary}15, #{colors.accent}15) !important; color: #{colors.text_primary} !important; border-left: 6px solid #{colors.primary} !important;"
      _ ->
        "background: #{colors.primary} !important; color: white !important;"
    end
  end

  defp get_theme_specific_overrides(theme, colors) do
    case theme do
      "creative" -> """
        .portfolio-section:nth-child(odd) {
          transform: rotate(-0.5deg) !important;
          border-left: 6px solid #{colors.accent} !important;
        }
        .portfolio-section:nth-child(even) {
          transform: rotate(0.5deg) !important;
          border-right: 6px solid #{colors.accent} !important;
        }
      """
      "minimal" -> """
        .portfolio-section {
          box-shadow: none !important;
          border: 2px solid #{colors.primary} !important;
        }
      """
      "modern" -> """
        .portfolio-section {
          border-top: 4px solid #{colors.primary} !important;
          box-shadow: 0 20px 40px rgba(0,0,0,0.1) !important;
        }
      """
      _ -> ""
    end
  end

  defp get_theme_padding(theme) do
    case theme do
      "creative" -> "2.5rem"
      "minimal" -> "1.5rem"
      "modern" -> "2rem"
      _ -> "2rem"
    end
  end

  defp get_theme_weight(theme) do
    case theme do
      "creative" -> "800"
      "minimal" -> "300"
      "modern" -> "600"
      _ -> "700"
    end
  end

  defp get_theme_border(theme, colors) do
    case theme do
      "creative" -> "4px solid #{colors.secondary}"
      "minimal" -> "2px solid #{colors.primary}"
      "modern" -> "1px solid rgba(0,0,0,0.1)"
      _ -> "1px solid rgba(0,0,0,0.05)"
    end
  end

  defp get_hero_text_color(theme) do
    case theme do
      "minimal" -> "#1f2937"
      _ -> "white"
    end
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

  defp get_theme_font(theme) do
    case theme do
      "professional" -> "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif"
      "creative" -> "'Poppins', 'Helvetica Neue', Arial, sans-serif"
      "minimal" -> "'Source Sans Pro', 'Helvetica Neue', Arial, sans-serif"
      "modern" -> "'Roboto', 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif"
      _ -> "system-ui, -apple-system, sans-serif"
    end
  end

  defp get_theme_radius(theme) do
    case theme do
      "creative" -> "15px"
      "minimal" -> "4px"
      "modern" -> "10px"
      _ -> "8px"
    end
  end

  defp get_theme_shadow(theme) do
    case theme do
      "creative" -> "0 10px 30px rgba(0,0,0,0.1)"
      "minimal" -> "0 1px 2px rgba(0,0,0,0.05)"
      "modern" -> "0 8px 20px rgba(0,0,0,0.1)"
      _ -> "0 2px 10px rgba(0,0,0,0.1)"
    end
  end

  defp get_hero_bg(theme, colors) do
    case theme do
      "creative" -> "linear-gradient(135deg, #{colors.primary}, #{colors.accent})"
      "minimal" -> colors.surface
      "modern" -> "linear-gradient(45deg, #{colors.primary}15, #{colors.accent}15)"
      _ -> colors.primary
    end
  end

  defp get_layout_css(layout) do
    case layout do
      "grid" -> """
        .portfolio-container .portfolio-section {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
          gap: 1.5rem;
        }
      """
      "timeline" -> """
        .portfolio-container {
          max-width: 900px;
          margin: 0 auto;
        }
      """
      _ -> ""
    end
  end

  defp get_theme_css(theme, colors) do
    case theme do
      "creative" -> """
        .portfolio-section {
          border-left: 5px solid #{colors.accent} !important;
        }
      """
      "minimal" -> """
        .portfolio-section {
          border: 2px solid #{colors.primary} !important;
        }
      """
      _ -> ""
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

  defp render_portfolio_with_template(assigns, template_class) do
    assigns = assign(assigns, :template_class, template_class)

    ~H"""
    <div class={["portfolio-content", template_class]}>
      <!-- Hero Section - Enhanced with Video Support -->
      <%= render_enhanced_hero_section(assigns) %>

      <!-- Portfolio Sections with Layout Structure -->
      <div class="portfolio-sections">
        <%= for section <- filter_non_hero_sections(@sections) do %>
          <%= if Map.get(section, :visible, true) do %>
            <section class="portfolio-section">
              <h2 class="section-title"><%= section.title %></h2>
              <div class="section-content">
                <%= raw(EnhancedContentRenderer.render_enhanced_section_content(section, @color_scheme)) %>
              </div>
            </section>
          <% end %>
        <% end %>
      </div>

      <!-- Video Modal for Hero Videos -->
      <%= if Map.get(assigns, :show_video_modal, false) && Map.get(assigns, :intro_video) do %>
        <%= render_video_modal(assigns) %>
      <% end %>
    </div>
    """
  end

  defp find_intro_video_in_sections(sections) do
    Enum.find(sections, fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)
  end

  defp get_video_url_from_intro(intro_video) do
    case intro_video do
      nil -> nil
      %{content: content} when is_map(content) -> Map.get(content, "video_url")
      _ -> nil
    end
  end

  defp get_video_title_from_intro(intro_video) do
    case intro_video do
      nil -> nil
      %{content: content} when is_map(content) -> Map.get(content, "title", "Personal Introduction")
      _ -> nil
    end
  end

  defp get_video_thumbnail(intro_video) do
    case intro_video do
      nil -> ""
      %{content: content} when is_map(content) -> Map.get(content, "thumbnail", "")
      _ -> ""
    end
  end

  defp extract_social_links_from_portfolio(portfolio) do
    contact_info = portfolio.contact_info || %{}
    customization = portfolio.customization || %{}

    # Extract from contact_info and customization
    social_platforms = ["linkedin", "twitter", "github", "instagram", "website"]

    Enum.reduce(social_platforms, [], fn platform, acc ->
      url = Map.get(contact_info, platform) || Map.get(customization, "#{platform}_url")
      if url && String.length(url) > 0 do
        [{platform, url} | acc]
      else
        acc
      end
    end)
    |> Enum.reverse()
  end

  defp render_hero_social_links(social_links, colors) do
    if length(social_links) > 0 do
      links_html = social_links
      |> Enum.map(fn {platform, url} ->
        icon = get_social_icon_for_hero(platform)
        """
        <a href="#{url}" target="_blank" rel="noopener"
          class="w-12 h-12 bg-white bg-opacity-20 backdrop-blur-sm rounded-full flex items-center justify-center text-white hover:bg-opacity-30 transition-all duration-300 transform hover:scale-110"
          title="#{String.capitalize(platform)}">
          #{icon}
        </a>
        """
      end)
      |> Enum.join("")

      """
      <div class="flex items-center space-x-4">
        <span class="text-white opacity-75 mr-4">Connect:</span>
        #{links_html}
      </div>
      """
    else
      ""
    end
  end

  defp get_social_icon_for_hero(platform) do
    case platform do
      "linkedin" -> """
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>
      """
      "github" -> """
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/></svg>
      """
      "twitter" -> """
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>"""
      "instagram" -> """
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
      """
      "website" -> """
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>
      """
      _ -> """
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/></svg>
      """
    end
  end

  defp render_video_background(video_url) do
    """
    <video autoplay muted loop class="absolute inset-0 w-full h-full object-cover opacity-20">
      <source src="#{video_url}" type="video/mp4">
      <source src="#{video_url}" type="video/webm">
    </video>
    """
  end

  defp get_experience_years(portfolio) do
    # Simple calculation - you can make this more sophisticated
    case Date.utc_today().year - 2020 do
      years when years > 0 -> "#{years}+"
      _ -> "2+"
    end
  end

  defp get_projects_count(portfolio) do
    sections = portfolio.sections || []
    project_sections = Enum.filter(sections, &(&1.section_type == "projects"))
    case length(project_sections) do
      0 -> "5+"
      count when count > 0 -> "#{count * 3}+"
    end
  end

defp render_enhanced_hero_section(assigns) do
  # Use safe fallback hero rendering
  hero_html = safe_render_enhanced_hero(
    assigns.portfolio,
    assigns.sections,
    assigns.color_scheme
  )

  raw(hero_html)
end

defp render_video_enhanced_hero(portfolio, intro_video, colors) do
  video_url = get_video_url_from_intro(intro_video)
  video_title = get_video_title_from_intro(intro_video)
  social_links = extract_social_links_from_portfolio(portfolio)

  """
  <section class="video-enhanced-hero relative overflow-hidden" style="background: linear-gradient(135deg, #{colors.primary} 0%, #{colors.secondary} 100%);">
    <!-- Video Background (if available) -->
    #{if video_url, do: render_video_background(video_url), else: ""}

    <!-- Hero Overlay -->
    <div class="hero-overlay absolute inset-0 bg-black bg-opacity-30"></div>

    <!-- Hero Content -->
    <div class="relative z-10 min-h-screen flex items-center">
      <div class="max-w-7xl mx-auto px-6 py-20">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <!-- Left Column: Content -->
          <div class="text-white">
            <h1 class="text-5xl lg:text-6xl font-bold mb-6 leading-tight">
              #{portfolio.title}
            </h1>
            <p class="text-xl lg:text-2xl mb-8 text-white opacity-90 leading-relaxed">
              #{portfolio.description || "Professional Portfolio & Personal Brand"}
            </p>

            <!-- Video Introduction -->
            #{if video_url do
              """
              <div class="mb-8">
                <button class="inline-flex items-center px-8 py-4 bg-white bg-opacity-20 backdrop-blur-sm rounded-xl text-white font-semibold hover:bg-opacity-30 transition-all duration-300" onclick="playIntroVideo()">
                  <svg class="w-6 h-6 mr-3" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M8 5v14l11-7z"/>
                  </svg>
                  Watch Introduction
                </button>
                <p class="text-sm text-white opacity-75 mt-2">#{video_title || "Personal introduction video"}</p>
              </div>
              """
            else
              ""
            end}

            <!-- Social Links -->
            #{if length(social_links) > 0, do: render_hero_social_links(social_links, colors), else: ""}

            <!-- CTA Buttons -->
            <div class="flex flex-col sm:flex-row gap-4">
              <button class="px-8 py-4 bg-white text-gray-900 rounded-xl font-semibold hover:bg-gray-100 transition-all duration-300 transform hover:scale-105">
                View Portfolio
              </button>
              <button class="px-8 py-4 border-2 border-white text-white rounded-xl font-semibold hover:bg-white hover:text-gray-900 transition-all duration-300">
                Get In Touch
              </button>
            </div>
          </div>

          <!-- Right Column: Video Player -->
          #{if video_url do
            """
            <div class="lg:block hidden">
              <div class="aspect-video bg-black bg-opacity-20 backdrop-blur-sm rounded-2xl overflow-hidden">
                <video
                  id="intro-video"
                  class="w-full h-full object-cover"
                  poster="#{get_video_thumbnail(intro_video)}"
                  controls>
                  <source src="#{video_url}" type="video/mp4">
                  <source src="#{video_url}" type="video/webm">
                  Your browser does not support the video tag.
                </video>
              </div>
            </div>
            """
          else
            """
            <div class="lg:block hidden">
              <div class="aspect-square bg-white bg-opacity-10 backdrop-blur-sm rounded-2xl flex items-center justify-center">
                <div class="text-center text-white">
                  <svg class="w-24 h-24 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
                  </svg>
                  <p class="text-lg opacity-75">Professional Portfolio</p>
                </div>
              </div>
            </div>
            """
          end}
        </div>
      </div>
    </div>
  </section>
  """
end

  defp render_standard_hero(assigns) do
    hero_content = get_section_content_map(assigns.hero_section)

    assigns = assign(assigns, :hero_content, hero_content)

    ~H"""
    <section class={["hero-section", "standard-hero", @template_class]}>
      <div class="hero-container">
        <div class="hero-content">
          <h1 class="hero-title">
            <%= Map.get(@hero_content, "headline", @hero_section.title) %>
          </h1>

          <%= if Map.get(@hero_content, "tagline") do %>
            <p class="hero-tagline">
              <%= Map.get(@hero_content, "tagline") %>
            </p>
          <% end %>

          <%= if Map.get(@hero_content, "main_content") do %>
            <div class="hero-description">
              <%= raw(Map.get(@hero_content, "main_content")) %>
            </div>
          <% end %>

          <!-- CTA Buttons -->
          <%= if Map.get(@hero_content, "cta_text") && Map.get(@hero_content, "cta_link") do %>
            <div class="hero-actions">
              <a href={Map.get(@hero_content, "cta_link")} class="hero-cta-button">
                <%= Map.get(@hero_content, "cta_text") %>
              </a>
            </div>
          <% end %>

          <!-- Social Links -->
          <%= if Map.get(@hero_content, "show_social") do %>
            <%= render_hero_social_links(Map.get(@hero_content, "social_links", %{})) %>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  defp render_portfolio_header(assigns) do
    ~H"""
    <header class={["portfolio-header", @template_class]}>
      <div class="header-container">
        <h1 class="portfolio-title"><%= @portfolio.title %></h1>
        <%= if @portfolio.description do %>
          <p class="portfolio-description"><%= @portfolio.description %></p>
        <% end %>
      </div>
    </header>
    """
  end

  defp render_video_modal(assigns) do
    ~H"""
    <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm"
        phx-click="hide_video_modal">
      <div class="relative max-w-6xl w-full mx-4 max-h-[90vh]" phx-click-away="hide_video_modal">
        <!-- Close button -->
        <button phx-click="hide_video_modal"
                class="absolute -top-12 right-0 text-white hover:text-gray-300 z-10">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>

        <!-- Video player -->
        <video controls autoplay class="w-full h-auto rounded-xl shadow-2xl">
          <source src={get_video_url_safe(@intro_video)} type="video/mp4">
          <source src={get_video_url_safe(@intro_video)} type="video/webm">
          Your browser does not support the video tag.
        </video>
      </div>
    </div>
    """
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
                  <%= raw(EnhancedContentRenderer.render_enhanced_section_content(section, @color_scheme)) %>
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
                  <%= raw(EnhancedContentRenderer.render_enhanced_section_content(section, @color_scheme)) %>
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
                <%= raw(EnhancedContentRenderer.render_enhanced_section_content(section, @color_scheme)) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  defp render_enhanced_section_content(section, color_scheme) do
    # Use EnhancedContentRenderer for section-specific content
    content_html = safe_render_enhanced_content(section, color_scheme)

    raw(content_html)
  end

  defp safe_render_enhanced_content(section, color_scheme) do
    try do
      EnhancedContentRenderer.render_enhanced_section_content(
        section,
        color_scheme
      )
    rescue
      e ->
        IO.puts("⚠️ EnhancedContentRenderer not available, using fallback: #{inspect(e)}")
        render_fallback_enhanced_content(section, color_scheme)
    end
  end

  defp render_fallback_enhanced_content(section, color_scheme) do
  colors = get_simple_color_palette(color_scheme)

  case section.section_type do
    "hero" ->
      render_enhanced_hero_content(section, colors)
    "about" ->
      render_enhanced_about_content(section, colors)
    "experience" ->
      render_enhanced_experience_content(section, colors)
    "skills" ->
      render_enhanced_skills_content(section, colors)
    "projects" ->
      render_enhanced_projects_content(section, colors)
    "education" ->
      render_enhanced_education_content(section, colors)
    "contact" ->
      render_enhanced_contact_content(section, colors)
    "achievements" ->
      render_enhanced_achievements_content(section, colors)
    "services" ->
      render_enhanced_services_content(section, colors)
    "testimonials" ->
      render_enhanced_testimonials_content(section, colors)
    _ ->
      render_enhanced_generic_content(section, colors)
  end
end

# ============================================================================
# PATCH 5.3: ADD ENHANCED HERO CONTENT RENDERER
# ============================================================================
# Add enhanced hero content renderer:

defp render_enhanced_hero_content(section, colors) do
  content = section.content || %{}
  headline = Map.get(content, "headline", section.title)
  tagline = Map.get(content, "tagline", "")
  main_content = Map.get(content, "main_content", "")
  cta_text = Map.get(content, "cta_text", "")
  cta_link = Map.get(content, "cta_link", "")

  """
  <div class="enhanced-hero-content text-center">
    <h1 class="text-4xl lg:text-6xl font-bold mb-6" style="color: #{colors.primary};">
      #{headline}
    </h1>

    #{if String.length(tagline) > 0 do
      """
      <p class="text-xl lg:text-2xl font-medium mb-6" style="color: #{colors.accent};">
        #{tagline}
      </p>
      """
    else
      ""
    end}

    #{if String.length(main_content) > 0 do
      """
      <div class="text-lg text-gray-700 mb-8 max-w-3xl mx-auto leading-relaxed">
        #{main_content}
      </div>
      """
    else
      ""
    end}

    #{if String.length(cta_text) > 0 and String.length(cta_link) > 0 do
      """
      <div class="flex justify-center">
        <a href="#{cta_link}"
           class="inline-flex items-center px-8 py-4 rounded-xl font-semibold text-white transition-all duration-300 transform hover:scale-105"
           style="background: #{colors.primary};">
          #{cta_text}
          <svg class="w-5 h-5 ml-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
          </svg>
        </a>
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.4: ADD ENHANCED ABOUT CONTENT RENDERER
# ============================================================================
# Add enhanced about content renderer:

defp render_enhanced_about_content(section, colors) do
  content = section.content || %{}
  main_content = Map.get(content, "main_content", "")
  subtitle = Map.get(content, "subtitle", "")
  highlights = Map.get(content, "highlights", [])
  stats = Map.get(content, "stats", %{})

  """
  <div class="enhanced-about-content">
    #{if String.length(subtitle) > 0 do
      """
      <p class="text-xl font-medium mb-6" style="color: #{colors.accent};">
        #{subtitle}
      </p>
      """
    else
      ""
    end}

    #{if String.length(main_content) > 0 do
      """
      <div class="prose prose-lg max-w-none text-gray-700 leading-relaxed mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(highlights) > 0 do
      """
      <div class="mb-8">
        <h4 class="text-lg font-semibold mb-4" style="color: #{colors.primary};">Key Highlights</h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          #{render_highlights_list(highlights, colors)}
        </div>
      </div>
      """
    else
      ""
    end}

    #{if map_size(stats) > 0 do
      """
      <div class="grid grid-cols-2 md:grid-cols-4 gap-6 bg-gray-50 rounded-xl p-6">
        #{render_stats_grid(stats, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.5: ADD ENHANCED EXPERIENCE CONTENT RENDERER
# ============================================================================
# Add enhanced experience content renderer:

defp render_enhanced_experience_content(section, colors) do
  content = section.content || %{}
  jobs = Map.get(content, "jobs", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-experience-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(jobs) > 0 do
      """
      <div class="space-y-8">
        #{render_enhanced_jobs_list(jobs, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.6: ADD ENHANCED SKILLS CONTENT RENDERER
# ============================================================================
# Add enhanced skills content renderer:

defp render_enhanced_skills_content(section, colors) do
  content = section.content || %{}
  skills = Map.get(content, "skills", [])
  skill_categories = Map.get(content, "skill_categories", %{})
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-skills-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if map_size(skill_categories) > 0 do
      """
      <div class="space-y-6">
        #{render_enhanced_skill_categories(skill_categories, colors)}
      </div>
      """
    else
      if length(skills) > 0 do
        """
        <div class="flex flex-wrap gap-2">
          #{render_enhanced_skills_list(skills, colors)}
        </div>
        """
      else
        ""
      end
    end}
  </div>
  """
end

defp render_magazine_enhanced_layout(portfolio, sections, colors, theme) do
  render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
end

defp render_minimal_enhanced_layout(portfolio, sections, colors, theme) do
  render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
end

defp render_standard_enhanced_layout(portfolio, sections, colors, theme) do
  render_standard_enhanced_layout_with_hero(portfolio, sections, colors, theme)
end

# ============================================================================
# PATCH 5.7: ADD ENHANCED PROJECTS CONTENT RENDERER
# ============================================================================
# Add enhanced projects content renderer:

defp render_enhanced_projects_content(section, colors) do
  content = section.content || %{}
  projects = Map.get(content, "projects", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-projects-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(projects) > 0 do
      """
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        #{render_enhanced_projects_grid(projects, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.8: ADD ENHANCED EDUCATION CONTENT RENDERER
# ============================================================================
# Add enhanced education content renderer:

defp render_enhanced_education_content(section, colors) do
  content = section.content || %{}
  education = Map.get(content, "education", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-education-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(education) > 0 do
      """
      <div class="space-y-6">
        #{render_enhanced_education_list(education, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.9: ADD ENHANCED CONTACT CONTENT RENDERER
# ============================================================================
# Add enhanced contact content renderer:

defp render_enhanced_contact_content(section, colors) do
  content = section.content || %{}
  email = Map.get(content, "email", "")
  phone = Map.get(content, "phone", "")
  location = Map.get(content, "location", "")
  website = Map.get(content, "website", "")
  social_links = Map.get(content, "social_links", %{})
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-contact-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8 text-center">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    <div class="bg-gray-50 rounded-xl p-8">
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        #{render_enhanced_contact_methods(email, phone, location, website, colors)}
      </div>

      #{if map_size(social_links) > 0 do
        """
        <div class="mt-8 pt-8 border-t border-gray-200">
          <h4 class="text-lg font-semibold text-center mb-6" style="color: #{colors.primary};">Connect With Me</h4>
          <div class="flex justify-center space-x-4">
            #{render_enhanced_social_links(social_links, colors)}
          </div>
        </div>
        """
      else
        ""
      end}
    </div>
  </div>
  """
end

# ============================================================================
# PATCH 5.10: ADD ENHANCED CONTENT UTILITY FUNCTIONS
# ============================================================================
# Add these enhanced content utility functions:

defp format_enhanced_text(text) do
  text
  |> String.replace("\n\n", "</p><p class=\"mb-4\">")
  |> String.replace("\n", "<br>")
  |> (fn content -> "<p class=\"mb-4\">#{content}</p>" end).()
end

defp render_highlights_list(highlights, colors) do
  highlights
  |> Enum.map(fn highlight ->
    """
    <div class="flex items-start space-x-3">
      <div class="w-2 h-2 rounded-full mt-2" style="background: #{colors.accent};"></div>
      <span class="text-gray-700">#{highlight}</span>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_stats_grid(stats, colors) do
  stats
  |> Enum.map(fn {key, value} ->
    label = key |> to_string() |> String.replace("_", " ") |> String.capitalize()
    """
    <div class="text-center">
      <div class="text-3xl font-bold mb-1" style="color: #{colors.primary};">#{value}</div>
      <div class="text-sm text-gray-600">#{label}</div>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_jobs_list(jobs, colors) do
  jobs
  |> Enum.map(fn job ->
    title = Map.get(job, "title", "Position")
    company = Map.get(job, "company", "Company")
    start_date = Map.get(job, "start_date", "")
    end_date = Map.get(job, "end_date", "")
    current = Map.get(job, "current", false)
    description = Map.get(job, "description", "")
    responsibilities = Map.get(job, "responsibilities", [])

    date_range = if current, do: "#{start_date} - Present", else: "#{start_date} - #{end_date}"

    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <div class="flex flex-col md:flex-row md:items-start md:justify-between mb-4">
        <div>
          <h3 class="text-xl font-semibold mb-1" style="color: #{colors.primary};">#{title}</h3>
          <p class="text-lg font-medium" style="color: #{colors.accent};">#{company}</p>
        </div>
        <div class="text-sm text-gray-500 mt-2 md:mt-0">
          #{date_range}
        </div>
      </div>

      #{if String.length(description) > 0 do
        """
        <div class="text-gray-700 mb-4">
          #{format_enhanced_text(description)}
        </div>
        """
      else
        ""
      end}

      #{if length(responsibilities) > 0 do
        """
        <div>
          <h4 class="font-medium text-gray-900 mb-2">Key Responsibilities:</h4>
          <ul class="list-disc list-inside space-y-1 text-gray-700">
            #{responsibilities |> Enum.map(fn resp -> "<li>#{resp}</li>" end) |> Enum.join("")}
          </ul>
        </div>
        """
      else
        ""
      end}
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_skill_categories(skill_categories, colors) do
  skill_categories
  |> Enum.map(fn {category, skills} ->
    category_name = category |> to_string() |> String.capitalize()
    """
    <div class="mb-6">
      <h4 class="text-lg font-semibold mb-3" style="color: #{colors.primary};">#{category_name}</h4>
      <div class="flex flex-wrap gap-2">
        #{render_enhanced_skills_list(skills, colors)}
      </div>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_skills_list(skills, colors) do
  skills
  |> Enum.map(fn skill ->
    name = get_skill_name(skill)
    level = get_skill_level(skill)
    level_color = get_skill_level_color(level, colors)

    """
    <span class="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium transition-colors #{level_color}">
      #{name}
      #{if level && level != "", do: " • #{level}", else: ""}
    </span>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_projects_grid(projects, colors) do
  projects
  |> Enum.map(fn project ->
    title = Map.get(project, "title", "Project")
    description = Map.get(project, "description", "")
    technologies = Map.get(project, "technologies", [])
    demo_url = Map.get(project, "demo_url", "")
    github_url = Map.get(project, "github_url", "")
    year = Map.get(project, "year", "")

    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm hover:shadow-lg transition-shadow">
      <div class="flex items-start justify-between mb-4">
        <h3 class="text-xl font-semibold" style="color: #{colors.primary};">#{title}</h3>
        #{if String.length(year) > 0 do
          """
          <span class="text-sm text-gray-500 bg-gray-100 px-2 py-1 rounded">#{year}</span>
          """
        else
          ""
        end}
      </div>

      #{if String.length(description) > 0 do
        """
        <p class="text-gray-700 mb-4">#{description}</p>
        """
      else
        ""
      end}

      #{if length(technologies) > 0 do
        """
        <div class="mb-4">
          <div class="flex flex-wrap gap-1">
            #{technologies |> Enum.map(fn tech ->
              "<span class=\"px-2 py-1 bg-gray-100 text-gray-700 text-xs rounded\">#{tech}</span>"
            end) |> Enum.join("")}
          </div>
        </div>
        """
      else
        ""
      end}

      <div class="flex space-x-3">
        #{if String.length(demo_url) > 0 do
          """
          <a href="#{demo_url}" target="_blank"
             class="inline-flex items-center px-3 py-1 text-sm font-medium text-white rounded transition-colors"
             style="background: #{colors.primary};">
            Demo
            <svg class="w-3 h-3 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>
          </a>
          """
        else
          ""
        end}

        #{if String.length(github_url) > 0 do
          """
          <a href="#{github_url}" target="_blank"
             class="inline-flex items-center px-3 py-1 text-sm font-medium border rounded transition-colors"
             style="border-color: #{colors.primary}; color: #{colors.primary};">
            Code
            <svg class="w-3 h-3 ml-1" fill="currentColor" viewBox="0 0 24 24">
              <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
            </svg>
          </a>
          """
        else
          ""
        end}
      </div>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_education_list(education, colors) do
  education
  |> Enum.map(fn edu ->
    degree = Map.get(edu, "degree", "Degree")
    school = Map.get(edu, "school", "Institution")
    year = Map.get(edu, "year", "")
    description = Map.get(edu, "description", "")
    gpa = Map.get(edu, "gpa", "")

    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <div class="flex flex-col md:flex-row md:items-start md:justify-between mb-3">
        <div>
          <h3 class="text-xl font-semibold mb-1" style="color: #{colors.primary};">#{degree}</h3>
          <p class="text-lg font-medium" style="color: #{colors.accent};">#{school}</p>
        </div>
        <div class="text-sm text-gray-500 mt-2 md:mt-0">
          #{year}
          #{if String.length(gpa) > 0, do: " • GPA: #{gpa}", else: ""}
        </div>
      </div>

      #{if String.length(description) > 0 do
        """
        <div class="text-gray-700">
          #{format_enhanced_text(description)}
        </div>
        """
      else
        ""
      end}
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_enhanced_contact_methods(email, phone, location, website, colors) do
  contact_methods = [
    if(String.length(email) > 0, do: {"email", "📧", email, "mailto:#{email}"}, else: nil),
    if(String.length(phone) > 0, do: {"phone", "📱", phone, "tel:#{phone}"}, else: nil),
    if(String.length(location) > 0, do: {"location", "📍", location, nil}, else: nil),
    if(String.length(website) > 0, do: {"website", "🌐", website, website}, else: nil)
  ]
  |> Enum.reject(&is_nil/1)

  contact_methods
  |> Enum.map(fn {type, icon, value, link} ->
    content = """
    <div class="flex items-center space-x-3 p-3 rounded-lg hover:bg-white transition-colors">
      <div class="text-2xl">#{icon}</div>
      <div>
        <div class="text-sm text-gray-500 uppercase tracking-wide">#{String.capitalize(type)}</div>
        #{if link do
          """
          <a href="#{link}" class="font-medium hover:underline" style="color: #{colors.primary};">#{value}</a>
          """
        else
          """
          <div class="font-medium text-gray-900">#{value}</div>
          """
        end}
      </div>
    </div>
    """
    content
  end)
  |> Enum.join("")
end

defp render_enhanced_social_links(social_links, colors) do
  social_links
  |> Enum.filter(fn {_, url} -> String.length(url) > 0 end)
  |> Enum.map(fn {platform, url} ->
    icon = get_social_icon_for_hero(platform)
    """
    <a href="#{url}" target="_blank" rel="noopener"
       class="w-12 h-12 rounded-full flex items-center justify-center text-white transition-all duration-300 transform hover:scale-110"
       style="background: #{colors.primary};"
       title="#{String.capitalize(platform)}">
      #{icon}
    </a>
    """
  end)
  |> Enum.join("")
end

# ============================================================================
# PATCH 5.11: ADD SKILL UTILITY FUNCTIONS
# ============================================================================

defp get_skill_level(skill) when is_map(skill), do: Map.get(skill, "level", "")
defp get_skill_level(_), do: ""

defp get_skill_level_color(level, colors) do
  case String.downcase(level) do
    l when l in ["beginner", "basic", "novice"] -> "bg-yellow-100 text-yellow-800"
    l when l in ["intermediate", "proficient", "good"] -> "bg-blue-100 text-blue-800"
    l when l in ["advanced", "excellent", "strong"] -> "bg-green-100 text-green-800"
    l when l in ["expert", "master", "exceptional"] -> "bg-purple-100 text-purple-800"
    _ -> "bg-gray-100 text-gray-800"
  end
end

# ============================================================================
# PATCH 5.12: ADD REMAINING CONTENT RENDERERS
# ============================================================================

defp render_enhanced_achievements_content(section, colors) do
  content = section.content || %{}
  achievements = Map.get(content, "achievements", [])
  awards = Map.get(content, "awards", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-achievements-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(achievements) > 0 or length(awards) > 0 do
      """
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        #{render_achievements_and_awards(achievements, awards, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

defp render_enhanced_services_content(section, colors) do
  content = section.content || %{}
  services = Map.get(content, "services", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-services-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(services) > 0 do
      """
      <div class="space-y-6">
        #{render_services_list(services, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

defp render_enhanced_testimonials_content(section, colors) do
  content = section.content || %{}
  testimonials = Map.get(content, "testimonials", [])
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-testimonials-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700 mb-8">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      ""
    end}

    #{if length(testimonials) > 0 do
      """
      <div class="space-y-6">
        #{render_testimonials_list(testimonials, colors)}
      </div>
      """
    else
      ""
    end}
  </div>
  """
end

defp render_enhanced_generic_content(section, colors) do
  content = section.content || %{}
  main_content = Map.get(content, "main_content", "")

  """
  <div class="enhanced-generic-content">
    #{if String.length(main_content) > 0 do
      """
      <div class="prose max-w-none text-gray-700">
        #{format_enhanced_text(main_content)}
      </div>
      """
    else
      """
      <div class="text-center py-8 text-gray-500">
        <p>Content will be displayed here when added.</p>
      </div>
      """
    end}
  </div>
  """
end

# ============================================================================
# PATCH 5.13: ADD REMAINING UTILITY FUNCTIONS
# ============================================================================

defp render_achievements_and_awards(achievements, awards, colors) do
  achievement_html = if length(achievements) > 0 do
    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <h4 class="text-lg font-semibold mb-4" style="color: #{colors.primary};">Achievements</h4>
      <div class="space-y-3">
        #{achievements |> Enum.map(fn achievement ->
          title = if is_map(achievement), do: Map.get(achievement, "title", achievement), else: achievement
          """
          <div class="flex items-start space-x-3">
            <div class="w-2 h-2 rounded-full mt-2" style="background: #{colors.accent};"></div>
            <span class="text-gray-700">#{title}</span>
          </div>
          """
        end) |> Enum.join("")}
      </div>
    </div>
    """
  else
    ""
  end

  awards_html = if length(awards) > 0 do
    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <h4 class="text-lg font-semibold mb-4" style="color: #{colors.primary};">Awards</h4>
      <div class="space-y-3">
        #{awards |> Enum.map(fn award ->
          title = if is_map(award), do: Map.get(award, "title", award), else: award
          """
          <div class="flex items-start space-x-3">
            <div class="w-6 h-6 rounded-full flex items-center justify-center" style="background: #{colors.accent}20; color: #{colors.accent};">
              <svg class="w-3 h-3" fill="currentColor" viewBox="0 0 24 24">
                <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
              </svg>
            </div>
            <span class="text-gray-700">#{title}</span>
          </div>
          """
        end) |> Enum.join("")}
      </div>
    </div>
    """
  else
    ""
  end

  achievement_html <> awards_html
end

defp render_services_list(services, colors) do
  services
  |> Enum.map(fn service ->
    title = Map.get(service, "title", "Service")
    description = Map.get(service, "description", "")
    price = Map.get(service, "price", "")
    features = Map.get(service, "features", [])

    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <div class="flex items-start justify-between mb-4">
        <h3 class="text-xl font-semibold" style="color: #{colors.primary};">#{title}</h3>
        #{if String.length(price) > 0 do
          """
          <div class="text-right">
            <div class="text-2xl font-bold" style="color: #{colors.accent};">#{price}</div>
          </div>
          """
        else
          ""
        end}
      </div>

      #{if String.length(description) > 0 do
        """
        <p class="text-gray-700 mb-4">#{description}</p>
        """
      else
        ""
      end}

      #{if length(features) > 0 do
        """
        <div>
          <h4 class="font-medium text-gray-900 mb-2">Features:</h4>
          <ul class="space-y-1">
            #{features |> Enum.map(fn feature ->
              """
              <li class="flex items-center space-x-2">
                <div class="w-1.5 h-1.5 rounded-full" style="background: #{colors.accent};"></div>
                <span class="text-gray-700 text-sm">#{feature}</span>
              </li>
              """
            end) |> Enum.join("")}
          </ul>
        </div>
        """
      else
        ""
      end}
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_testimonials_list(testimonials, colors) do
  testimonials
  |> Enum.map(fn testimonial ->
    content = Map.get(testimonial, "content", "")
    author = Map.get(testimonial, "author", "Anonymous")
    title = Map.get(testimonial, "title", "")
    company = Map.get(testimonial, "company", "")
    rating = Map.get(testimonial, "rating", 5)

    """
    <div class="bg-white rounded-xl p-6 border border-gray-100 shadow-sm">
      <!-- Rating Stars -->
      <div class="flex items-center mb-4">
        #{render_star_rating(rating, colors)}
      </div>

      <!-- Testimonial Content -->
      #{if String.length(content) > 0 do
        """
        <blockquote class="text-gray-700 italic mb-4">
          "#{content}"
        </blockquote>
        """
      else
        ""
      end}

      <!-- Author Info -->
      <div class="flex items-center">
        <div class="w-10 h-10 rounded-full flex items-center justify-center mr-3" style="background: #{colors.primary}20; color: #{colors.primary};">
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
          </svg>
        </div>
        <div>
          <div class="font-semibold text-gray-900">#{author}</div>
          #{if String.length(title) > 0 or String.length(company) > 0 do
            """
            <div class="text-sm text-gray-500">
              #{if String.length(title) > 0, do: title, else: ""}
              #{if String.length(title) > 0 and String.length(company) > 0, do: " at ", else: ""}
              #{if String.length(company) > 0, do: company, else: ""}
            </div>
            """
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end)
  |> Enum.join("")
end

defp render_star_rating(rating, colors) do
  full_stars = min(rating, 5)
  empty_stars = 5 - full_stars

  full_star_html = """
  <svg class="w-4 h-4" style="color: #{colors.accent};" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
  </svg>
  """

  empty_star_html = """
  <svg class="w-4 h-4 text-gray-300" fill="currentColor" viewBox="0 0 24 24">
    <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
  </svg>
  """

  String.duplicate(full_star_html, full_stars) <> String.duplicate(empty_star_html, empty_stars)
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

  # Render hero social links
  defp render_hero_social_links(social_links) when is_map(social_links) do
    social_items = social_links
    |> Enum.filter(fn {_, url} -> url && url != "" end)
    |> Enum.map(fn {platform, url} ->
      {platform, url, get_social_icon(platform)}
    end)

    assigns = %{social_items: social_items}

    ~H"""
    <%= if length(@social_items) > 0 do %>
      <div class="hero-social-links">
        <%= for {platform, url, icon} <- @social_items do %>
          <a href={url} target="_blank" rel="noopener" class="social-link" title={String.capitalize(platform)}>
            <%= icon %>
          </a>
        <% end %>
      </div>
    <% end %>
    """
  end

  defp render_hero_social_links(_), do: ""

  # Get social platform icons
  defp get_social_icon(platform) do
    case String.downcase(to_string(platform)) do
      "linkedin" -> "💼"
      "github" -> "👨‍💻"
      "twitter" -> "🐦"
      "instagram" -> "📸"
      "website" -> "🌐"
      "email" -> "📧"
      _ -> "🔗"
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

  defp get_job_field(job, possible_keys) when is_map(job) do
    possible_keys
    |> Enum.reduce_while("", fn key, acc ->
      value = case Map.get(job, key) do
        nil -> Map.get(job, String.to_atom(key), "")
        val -> val
      end
      safe_value = get_safe_text_from_value(value)
      if String.length(safe_value) > 0, do: {:halt, safe_value}, else: {:cont, acc}
    end)
  end

  defp get_job_field(_, _), do: ""

  # Get job boolean field
  defp get_job_boolean(job, possible_keys) when is_map(job) do
    possible_keys
    |> Enum.reduce_while(false, fn key, acc ->
      value = case Map.get(job, key) do
        nil -> Map.get(job, String.to_atom(key), false)
        val -> val
      end
      case value do
        true -> {:halt, true}
        "true" -> {:halt, true}
        _ -> {:cont, acc}
      end
    end)
  end

  defp get_job_boolean(_, _), do: false

  # Get skill field with multiple possible keys
  defp get_skill_field(skill, possible_keys) when is_map(skill) do
    possible_keys
    |> Enum.reduce_while("", fn key, acc ->
      value = case Map.get(skill, key) do
        nil -> Map.get(skill, String.to_atom(key), "")
        val -> val
      end
      safe_value = get_safe_text_from_value(value)
      if String.length(safe_value) > 0, do: {:halt, safe_value}, else: {:cont, acc}
    end)
  end

  defp get_skill_field(_, _), do: ""

  # Get project field with multiple possible keys
  defp get_project_field(project, possible_keys) when is_map(project) do
    possible_keys
    |> Enum.reduce_while("", fn key, acc ->
      value = case Map.get(project, key) do
        nil -> Map.get(project, String.to_atom(key), "")
        val -> val
      end
      safe_value = get_safe_text_from_value(value)
      if String.length(safe_value) > 0, do: {:halt, safe_value}, else: {:cont, acc}
    end)
  end

  defp get_project_field(_, _), do: ""

  # Get project technologies (handle arrays)
  defp get_project_technologies(project, possible_keys) when is_map(project) do
    possible_keys
    |> Enum.reduce_while([], fn key, acc ->
      value = case Map.get(project, key) do
        nil -> Map.get(project, String.to_atom(key), [])
        val -> val
      end

      technologies = case value do
        list when is_list(list) -> list
        string when is_binary(string) ->
          string |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
        _ -> []
      end

      if length(technologies) > 0, do: {:halt, technologies}, else: {:cont, acc}
    end)
  end

  defp get_project_technologies(_, _), do: []

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

  defp safe_html_content(content) do
    case content do
      {:safe, html_content} when is_binary(html_content) ->
        html_content
      content when is_binary(content) ->
        Phoenix.HTML.html_escape(content)
      nil ->
        ""
      _ ->
        content |> to_string() |> Phoenix.HTML.html_escape()
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

  defp safe_text_content(content) do
    case content do
      {:safe, html_content} when is_binary(html_content) ->
        # Strip HTML tags and escape
        html_content |> strip_html_tags() |> Phoenix.HTML.html_escape()
      content when is_binary(content) ->
        Phoenix.HTML.html_escape(content)
      nil ->
        ""
      _ ->
        content |> to_string() |> Phoenix.HTML.html_escape()
    end
  end

  defp strip_html_tags(html) when is_binary(html) do
    html
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&nbsp;/, " ")
    |> String.replace(~r/&amp;/, "&")
    |> String.replace(~r/&lt;/, "<")
    |> String.replace(~r/&gt;/, ">")
    |> String.replace(~r/&quot;/, "\"")
    |> String.replace(~r/&#39;/, "'")
    |> String.trim()
  end

  defp strip_html_tags(content), do: to_string(content)

end
