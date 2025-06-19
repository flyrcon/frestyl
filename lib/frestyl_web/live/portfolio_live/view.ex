# lib/frestyl_web/live/portfolio_live/view.ex - FIXED VERSION

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Repo
  import Ecto.Query
  alias FrestylWeb.PortfolioLive.Components.EnhancedSkillsDisplay

  # 🔥 FIXED: Handle both public portfolio view and share token view
  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      {:ok, portfolio} ->
        portfolio = if Ecto.assoc_loaded?(portfolio.user) do
          portfolio
        else
          Repo.preload(portfolio, :user, force: true)
        end

        if portfolio_accessible?(portfolio) do
          track_portfolio_visit(portfolio, socket)

          # 🔥 NEW: Extract intro video and filter sections
          {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(portfolio.sections || [])

          {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

          socket =
            socket
            |> assign(:page_title, portfolio.title)
            |> assign(:portfolio, portfolio)
            |> assign(:owner, portfolio.user)
            |> assign(:sections, filtered_sections)  # 🔥 UPDATED: Use filtered sections
            |> assign(:template_config, template_config)
            |> assign(:template_theme, normalize_theme(portfolio.theme))
            |> assign(:template_layout, template_layout)
            |> assign(:customization_css, customization_css)
            |> assign(:intro_video, intro_video)  # 🔥 UPDATED: Use extracted video
            |> assign(:share, nil)
            |> assign(:is_shared_view, false)
            |> assign(:show_stats, false)
            |> assign(:portfolio_stats, %{})
            |> assign(:collaboration_enabled, false)
            |> assign(:feedback_panel_open, false)

          {:ok, socket}
        else
          {:ok, socket
          |> put_flash(:error, "This portfolio is private")
          |> redirect(to: "/")}
        end
    end
  end

  # Handle share token view (collaboration links)
  @impl true
  def mount(%{"token" => token} = params, _session, socket) do
    mount_share_view(token, socket)
  end

  # 🔥 FIXED: Mount public portfolio view with proper section loading
  defp mount_public_view(slug, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      {:ok, portfolio} ->
        IO.puts("🔥 MOUNTING PORTFOLIO VIEW")
        IO.puts("🔥 Portfolio theme: #{portfolio.theme}")
        IO.puts("🔥 Portfolio customization: #{inspect(portfolio.customization)}")

        # Force preload user if not loaded
        portfolio = if Ecto.assoc_loaded?(portfolio.user) do
          portfolio
        else
          Repo.preload(portfolio, :user, force: true)
        end

        # Check if portfolio is publicly accessible
        if portfolio_accessible?(portfolio) do
          # 🔥 FIX: Track visit only if we have user info, or track anonymously
          track_portfolio_visit_safe(portfolio, socket)

          # 🔥 NEW: Extract intro video and filter sections
          {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(Map.get(portfolio, :portfolio_sections, []))

          # Process customization data
          {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

          IO.puts("🔥 Generated CSS length: #{String.length(customization_css)}")
          IO.puts("🔥 Template layout: #{template_layout}")

          socket =
            socket
            |> assign(:page_title, portfolio.title)
            |> assign(:portfolio, portfolio)
            |> assign(:owner, portfolio.user)
            |> assign(:sections, filtered_sections)  # 🔥 CHANGED: Use filtered sections
            |> assign(:template_config, template_config)
            |> assign(:template_theme, normalize_theme(portfolio.theme))
            |> assign(:template_layout, template_layout)
            |> assign(:customization_css, customization_css)
            |> assign(:intro_video, intro_video)  # 🔥 CHANGED: Use extracted video
            |> assign(:share, nil)
            |> assign(:is_shared_view, false)
            |> assign(:show_stats, false)
            |> assign(:portfolio_stats, %{})
            |> assign(:collaboration_enabled, false)
            |> assign(:feedback_panel_open, false)

          {:ok, socket}
        else
          {:ok, socket
          |> put_flash(:error, "This portfolio is private")
          |> redirect(to: "/")}
        end
    end
  end

  # 🔥 NEW: Safe version of track_portfolio_visit that handles nil current_user
  defp track_portfolio_visit_safe(portfolio, socket) do
    try do
      # Get current user safely
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

      # Add user_id only if user is logged in
      visit_attrs = if current_user do
        Map.put(visit_attrs, :user_id, current_user.id)
      else
        visit_attrs
      end

      Portfolios.create_visit(visit_attrs)
    rescue
      _ -> :ok
    end
  end

  # 🔥 FIXED: Mount share token view with proper section loading
  defp mount_share_view(token, socket) do
    case Portfolios.get_portfolio_by_share_token_simple(token) do
      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio link not found or expired")
        |> redirect(to: "/")}

      {:ok, portfolio, share} ->
        # Track share visit
        Portfolios.increment_share_view_count(token)
        track_share_visit(portfolio, share, socket)

        # Check if this is a collaboration request
        collaboration_mode = get_connect_params(socket)["collaboration"] == "true"

        # 🔥 NEW: Extract intro video and filter sections for share view
        {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(portfolio.sections || [])

        # Process customization data
        {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

        socket =
          socket
          |> assign(:page_title, "#{portfolio.title} - Shared")
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, filtered_sections)  # 🔥 CHANGED: Use filtered sections
          |> assign(:template_config, template_config)
          |> assign(:template_theme, normalize_theme(portfolio.theme))
          |> assign(:template_layout, template_layout)
          |> assign(:customization_css, customization_css)
          |> assign(:intro_video, intro_video)  # 🔥 CHANGED: Use extracted video
          |> assign(:share, share)
          |> assign(:is_shared_view, true)
          |> assign(:show_stats, true)
          |> assign(:portfolio_stats, %{})
          |> assign(:collaboration_enabled, collaboration_mode)
          |> assign(:feedback_panel_open, false)

        {:ok, socket}
    end
  end

  defp extract_intro_video_and_filter_sections(sections) do
    {video_sections, other_sections} = Enum.split_with(sections, fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)

    intro_video = case video_sections do
      [video_section | _] ->
        content = video_section.content || %{}
        %{
          id: video_section.id,
          title: Map.get(content, "title", "Personal Introduction"),
          description: Map.get(content, "description", ""),
          video_url: Map.get(content, "video_url"),
          filename: Map.get(content, "video_filename"),
          duration: Map.get(content, "duration", 0),
          created_at: Map.get(content, "created_at"),
          section_id: video_section.id
        }
      [] ->
        nil
    end

    {intro_video, other_sections}
  end

  defp format_video_duration(duration) when is_number(duration) do
    minutes = div(duration, 60)
    seconds = rem(duration, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(seconds), 2, "0")}"
  end
  defp format_video_duration(_), do: "0:00"

  defp get_video_thumbnail_url(intro_video) do
    # For now, return a placeholder - you can implement video thumbnail generation later
    "/images/video-placeholder.jpg"
  end

  # 🔥 NEW: Get portfolio with complete section data
  defp get_portfolio_with_complete_sections(slug) do
    query = from p in Frestyl.Portfolios.Portfolio,
      where: p.slug == ^slug,
      preload: [
        :user,
        portfolio_sections: [:portfolio_media]
      ]

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      portfolio ->
        # 🔥 CRITICAL: Transform to expected structure
        normalized_portfolio = %{
          portfolio |
          sections: transform_portfolio_sections(portfolio.portfolio_sections)
        }

        {:ok, normalized_portfolio}
    end
  end

  # 🔥 NEW: Get portfolio by share token with complete section data
  defp get_portfolio_by_share_token_with_complete_sections(token) do
    query = from s in Frestyl.Portfolios.PortfolioShare,
      where: s.token == ^token,
      join: p in Frestyl.Portfolios.Portfolio, on: p.id == s.portfolio_id,
      preload: [
        portfolio: [
          :user,
          portfolio_sections: [:portfolio_media]
        ]
      ]

    case Repo.one(query) do
      nil ->
        {:error, :not_found}

      share ->
        # 🔥 CRITICAL: Transform to expected structure
        normalized_portfolio = %{
          share.portfolio |
          sections: transform_portfolio_sections(share.portfolio.portfolio_sections)
        }

        {:ok, normalized_portfolio, share}
    end
  end

  # 🔥 CRITICAL: Transform portfolio_sections to expected sections format
  defp transform_portfolio_sections(portfolio_sections) when is_list(portfolio_sections) do
    portfolio_sections
    |> Enum.filter(fn section -> Map.get(section, :visible, true) end)
    |> Enum.sort_by(fn section -> section.position end)
    |> Enum.map(fn section ->
      %{
        id: section.id,
        title: section.title,
        section_type: section.section_type,
        content: section.content || %{},
        position: section.position,
        visible: Map.get(section, :visible, true),
        media_files: transform_media_files(Map.get(section, :portfolio_media, []))
      }
    end)
  end
  defp transform_portfolio_sections(_), do: []

  # 🔥 CRITICAL: Transform media files to expected format
  defp transform_media_files(portfolio_media) when is_list(portfolio_media) do
    Enum.map(portfolio_media, fn media ->
      %{
        id: media.id,
        title: media.title || "Untitled",
        description: media.description,
        media_type: String.to_atom(media.media_type || "image"),
        file_path: media.file_path,
        file_size: media.file_size,
        mime_type: media.mime_type,
        url: get_media_url(media)
      }
    end)
  end
  defp transform_media_files(_), do: []

  # 🔥 FIXED: Normalize sections for display consistency
  defp normalize_sections_for_display(sections) when is_list(sections) do
    sections
    |> Enum.filter(fn section -> Map.get(section, :visible, true) end)
    |> Enum.sort_by(fn section -> Map.get(section, :position, 999) end)
    |> Enum.map(fn section ->
      # Ensure all required fields exist
      %{
        id: Map.get(section, :id),
        title: Map.get(section, :title, "Untitled Section"),
        section_type: normalize_section_type(Map.get(section, :section_type)),
        content: Map.get(section, :content, %{}),
        position: Map.get(section, :position, 0),
        visible: Map.get(section, :visible, true),
        media_files: Map.get(section, :media_files, [])
      }
    end)
  end
  defp normalize_sections_for_display(_), do: []

  # 🔥 FIXED: Normalize section types
  defp normalize_section_type(section_type) when is_atom(section_type), do: section_type
  defp normalize_section_type(section_type) when is_binary(section_type) do
    case section_type do
      "intro" -> :intro
      "experience" -> :experience
      "education" -> :education
      "skills" -> :skills
      "projects" -> :projects
      "featured_project" -> :featured_project
      "case_study" -> :case_study
      "achievements" -> :achievements
      "testimonial" -> :testimonial
      "media_showcase" -> :media_showcase
      "contact" -> :contact
      _ -> :custom
    end
  end
  defp normalize_section_type(_), do: :custom

  # 🔥 FIXED: Process portfolio customization with better error handling
  defp process_portfolio_customization_fixed(portfolio) do
    IO.puts("🔥 PROCESSING PORTFOLIO CUSTOMIZATION")
    IO.puts("🔥 Portfolio theme: #{portfolio.theme}")

    # Get base template config from the template system
    theme = portfolio.theme || "executive"
    base_template_config = get_safe_template_config(theme)

    # Get user customization from database
    user_customization = normalize_customization_map(portfolio.customization || %{})

    # Deep merge user customization over template defaults
    merged_config = deep_merge_maps(base_template_config, user_customization)

    # Determine layout from merged config
    template_layout = get_template_layout(merged_config, theme)

    # FIXED: Generate CSS variables from merged config with proper template application
    css_variables = generate_portfolio_css_variables_with_template(merged_config, theme)

    IO.puts("🔥 CSS variables generated: #{String.length(css_variables)} characters")

    {merged_config, css_variables, template_layout}
  end

  defp generate_custom_css(customization) do
    # Basic CSS generation - you can expand this
    primary_color = Map.get(customization, "primary_color", "#3b82f6")

    """
    <style>
      :root {
        --portfolio-primary: #{primary_color};
      }
      .custom-primary { color: var(--portfolio-primary); }
      .custom-primary-bg { background-color: var(--portfolio-primary); }
    </style>
    """
  end

  # 🔥 SAFE: Get template config with fallback
  defp get_safe_template_config(theme) do
    try do
      PortfolioTemplates.get_template_config(theme)
    rescue
      _ ->
        # Fallback template config
        %{
          "primary_color" => "#3b82f6",
          "secondary_color" => "#64748b",
          "accent_color" => "#f59e0b",
          "background" => "default",
          "layout" => "professional",
          "typography" => %{
            "font_family" => "Inter"
          }
        }
    end
  end

  # 🔥 SAFE: Normalize customization map
  defp normalize_customization_map(customization) when is_map(customization) do
    customization
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {to_string(key), normalize_value(value)}
      {key, value} when is_binary(key) -> {key, normalize_value(value)}
    end)
    |> Enum.into(%{})
  end
  defp normalize_customization_map(_), do: %{}

  # 🔥 SAFE: Normalize nested values
  defp normalize_value(value) when is_map(value) do
    value
    |> Enum.map(fn
      {key, val} when is_atom(key) -> {to_string(key), normalize_value(val)}
      {key, val} when is_binary(key) -> {key, normalize_value(val)}
    end)
    |> Enum.into(%{})
  end
  defp normalize_value(value), do: value

  # 🔥 SAFE: Deep merge two maps
  defp deep_merge_maps(left, right) when is_map(left) and is_map(right) do
    Map.merge(left, right, fn _k, v1, v2 ->
      if is_map(v1) and is_map(v2) do
        deep_merge_maps(v1, v2)
      else
        v2  # User customization takes precedence
      end
    end)
  end
  defp deep_merge_maps(_left, right), do: right

  # 🔥 SAFE: Get layout from config
  defp get_template_layout(config, theme) do
    case config do
      %{"layout" => layout} when is_binary(layout) -> layout
      %{:layout => layout} when is_binary(layout) -> layout
      %{"layout" => layout} when is_atom(layout) -> to_string(layout)
      %{:layout => layout} when is_atom(layout) -> to_string(layout)
      _ ->
        # Fallback to theme-based layout
        case theme do
          "executive" -> "dashboard"
          "developer" -> "terminal"
          "designer" -> "gallery"
          "consultant" -> "case_study"
          "academic" -> "academic"
          "creative" -> "gallery"
          "minimalist" -> "minimal"
          _ -> "dashboard"
        end
    end
  end

  # 🔥 SAFE: Generate CSS variables with error handling
  defp generate_portfolio_css_variables_with_template(config, theme) do
    try do
      # Extract colors with safe fallbacks
      primary_color = get_config_value_safe(config, "primary_color", "#3b82f6")
      secondary_color = get_config_value_safe(config, "secondary_color", "#64748b")
      accent_color = get_config_value_safe(config, "accent_color", "#f59e0b")

      # Extract typography safely
      typography = get_config_value_safe(config, "typography", %{})
      font_family = get_config_value_safe(typography, "font_family", "Inter")

      # Extract background safely
      background = get_config_value_safe(config, "background", "default")

      # FIXED: Get template-specific classes
      template_classes = get_template_specific_classes(theme)
      background_css = get_template_background_css(background, theme)

      """
      <style>
      /* 🔥 PORTFOLIO CSS VARIABLES */
      :root {
        --portfolio-primary-color: #{primary_color};
        --portfolio-secondary-color: #{secondary_color};
        --portfolio-accent-color: #{accent_color};
        --portfolio-font-family: #{get_font_family_css_safe(font_family)};
        #{get_background_css_vars_safe(background)}
      }

      /* 🔥 APPLY VARIABLES TO ELEMENTS */
      body, html {
        font-family: var(--portfolio-font-family) !important;
        color: var(--portfolio-text-color) !important;
      }

      /* 🔥 TEMPLATE-SPECIFIC STYLING */
      #{template_classes}

      /* 🔥 BACKGROUND STYLING */
      #{background_css}

      /* 🔥 COLOR CLASSES */
      .portfolio-primary { color: var(--portfolio-primary-color) !important; }
      .portfolio-secondary { color: var(--portfolio-secondary-color) !important; }
      .portfolio-accent { color: var(--portfolio-accent-color) !important; }
      .portfolio-bg-primary { background-color: var(--portfolio-primary-color) !important; }
      .portfolio-bg-secondary { background-color: var(--portfolio-secondary-color) !important; }
      .portfolio-bg-accent { background-color: var(--portfolio-accent-color) !important; }

      /* 🔥 TEMPLATE-SPECIFIC OVERRIDES */
      .portfolio-card {
        background-color: var(--portfolio-card-bg) !important;
        color: var(--portfolio-text-color) !important;
        #{get_template_card_styling(theme)}
      }

      /* 🔥 HEADER CUSTOMIZATION */
      .portfolio-header {
        #{get_template_header_styling(theme)}
      }

      /* Fix text colors based on template */
      .text-gray-900 { color: var(--portfolio-text-color) !important; }
      .text-gray-600 { color: var(--portfolio-secondary-text) !important; }
      .bg-blue-600 { background-color: var(--portfolio-primary-color) !important; }
      .text-blue-600 { color: var(--portfolio-primary-color) !important; }
      </style>
      """
    rescue
      error ->
        IO.puts("🔥 ERROR generating CSS: #{inspect(error)}")
        ""
    end
  end

  defp get_template_specific_classes(theme) do
    case theme do
      "executive" ->
        """
        .portfolio-bg { background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%); }
        .portfolio-card { box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }
        """
      "developer" ->
        """
        .portfolio-bg { background: #1f2937; color: #f9fafb; }
        .portfolio-card { background: #374151; border: 1px solid #4b5563; }
        """
      "designer" ->
        """
        .portfolio-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        .portfolio-card { backdrop-filter: blur(10px); background: rgba(255, 255, 255, 0.1); }
        """
      "consultant" ->
        """
        .portfolio-bg { background: linear-gradient(135deg, #e3f2fd 0%, #f3e5f5 100%); }
        .portfolio-card { border-left: 4px solid var(--portfolio-primary-color); }
        """
      "academic" ->
        """
        .portfolio-bg { background: linear-gradient(135deg, #f0f9ff 0%, #ecfdf5 100%); }
        .portfolio-card { border: 1px solid #d1d5db; }
        """
      _ ->
        """
        .portfolio-bg { background: #ffffff; }
        .portfolio-card { border: 1px solid #e5e7eb; }
        """
    end
  end

    defp get_template_background_css(background, theme) do
    case background do
      "gradient-ocean" ->
        ".portfolio-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important; }"
      "gradient-sunset" ->
        ".portfolio-bg { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%) !important; }"
      "dark-mode" ->
        ".portfolio-bg { background: #1a1a1a !important; color: #ffffff !important; }"
      _ ->
        get_template_specific_classes(theme)
    end
  end

  defp get_template_card_styling(theme) do
    case theme do
      "executive" -> "border-radius: 12px; border: 1px solid #e2e8f0;"
      "developer" -> "border-radius: 8px; border: 1px solid #4b5563;"
      "designer" -> "border-radius: 16px; border: 1px solid rgba(255, 255, 255, 0.2);"
      "consultant" -> "border-radius: 10px; border-left: 4px solid var(--portfolio-primary-color);"
      "academic" -> "border-radius: 8px; border: 1px solid #d1d5db;"
      _ -> "border-radius: 8px; border: 1px solid #e5e7eb;"
    end
  end

  defp get_template_header_styling(theme) do
    case theme do
      "executive" -> "background: rgba(248, 250, 252, 0.95); backdrop-filter: blur(8px);"
      "developer" -> "background: rgba(31, 41, 55, 0.95); backdrop-filter: blur(8px);"
      "designer" -> "background: rgba(255, 255, 255, 0.1); backdrop-filter: blur(16px);"
      "consultant" -> "background: rgba(227, 242, 253, 0.95); backdrop-filter: blur(8px);"
      "academic" -> "background: rgba(240, 249, 255, 0.95); backdrop-filter: blur(8px);"
      _ -> "background: rgba(255, 255, 255, 0.95); backdrop-filter: blur(8px);"
    end
  end

  # 🔥 SAFE: Get config value with fallback
  defp get_config_value_safe(config, key, default) when is_map(config) do
    config[key] || config[String.to_atom(key)] || default
  end
  defp get_config_value_safe(_, _, default), do: default

  # 🔥 SAFE: Get font family CSS
  defp get_font_family_css_safe(font_family) do
    case font_family do
      "Inter" -> "'Inter', system-ui, sans-serif"
      "Roboto" -> "'Roboto', system-ui, sans-serif"
      "JetBrains Mono" -> "'JetBrains Mono', 'Fira Code', monospace"
      "Merriweather" -> "'Merriweather', Georgia, serif"
      "Playfair Display" -> "'Playfair Display', Georgia, serif"
      _ -> "system-ui, sans-serif"
    end
  end

  # 🔥 SAFE: Get background CSS vars
  defp get_background_css_vars_safe(background) do
    case background do
      "gradient-ocean" ->
        """
        --portfolio-bg: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: rgba(255, 255, 255, 0.8);
        --portfolio-card-bg: rgba(255, 255, 255, 0.1);
        """
      "gradient-sunset" ->
        """
        --portfolio-bg: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: rgba(255, 255, 255, 0.8);
        --portfolio-card-bg: rgba(255, 255, 255, 0.15);
        """
      "dark-mode" ->
        """
        --portfolio-bg: #1a1a1a;
        --portfolio-text-color: #ffffff;
        --portfolio-secondary-text: #cccccc;
        --portfolio-card-bg: #2a2a2a;
        """
      _ ->
        """
        --portfolio-bg: #ffffff;
        --portfolio-text-color: #1f2937;
        --portfolio-secondary-text: #6b7280;
        --portfolio-card-bg: #ffffff;
        """
    end
  end

  # Check if portfolio is accessible to public
  defp portfolio_accessible?(portfolio) do
    case portfolio.visibility do
      :public -> true
      :link_only -> true
      :private -> false
    end
  end

  # EVENT HANDLERS
  @impl true
  def handle_event("toggle_stats", _params, socket) do
    new_show_stats = !socket.assigns.show_stats
    {:noreply, assign(socket, :show_stats, new_show_stats)}
  end

  @impl true
  def handle_event("toggle_feedback_panel", _params, socket) do
    new_state = !socket.assigns.feedback_panel_open
    {:noreply, assign(socket, :feedback_panel_open, new_state)}
  end

  @impl true
  def handle_event("submit_feedback", %{"feedback" => feedback_content, "section_id" => section_id}, socket) do
    if socket.assigns.is_shared_view and socket.assigns.collaboration_enabled do
      attrs = %{
        content: feedback_content,
        feedback_type: :comment,
        portfolio_id: socket.assigns.portfolio.id,
        section_id: section_id,
        share_id: get_share_id(socket),
        section_reference: "section-#{section_id}"
      }

      case Portfolios.create_feedback(attrs) do
        {:ok, _feedback} ->
          {:noreply,
           socket
           |> put_flash(:info, "Feedback submitted successfully!")
           |> push_event("feedback_submitted", %{})}

        {:error, _changeset} ->
          {:noreply, put_flash(socket, :error, "Failed to submit feedback. Please try again.")}
      end
    else
      {:noreply, put_flash(socket, :error, "Feedback is only available for collaboration sessions.")}
    end
  end

  @impl true
  def handle_event("export_resume", _params, socket) do
    portfolio = socket.assigns.portfolio

    # Set loading state
    socket = assign(socket, :exporting_resume, true)

    # Start PDF export in background task
    Task.start(fn ->
      case Frestyl.PdfExport.export_portfolio_with_template(portfolio.slug, :resume) do
        {:ok, export_info} ->
          send(self(), {:resume_export_complete, export_info})
        {:error, reason} ->
          send(self(), {:resume_export_error, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:resume_export_complete, export_info}, socket) do
    socket =
      socket
      |> assign(:exporting_resume, false)
      |> put_flash(:info, "Resume downloaded successfully!")
      |> push_event("download_file", %{
          url: export_info.url,
          filename: export_info.filename
        })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:resume_export_error, reason}, socket) do
    socket =
      socket
      |> assign(:exporting_resume, false)
      |> put_flash(:error, "Export failed: #{reason}")

    {:noreply, socket}
  end

  # New export functions....
  @impl true
  def handle_event("export_pdf", _params, socket) do
    portfolio = socket.assigns.portfolio

    # Set loading state
    socket = assign(socket, :exporting_pdf, true)

    # Start PDF export in background task
    Task.start(fn ->
      case export_portfolio_to_pdf(portfolio) do
        {:ok, pdf_info} ->
          send(self(), {:pdf_export_complete, pdf_info})
        {:error, reason} ->
          send(self(), {:pdf_export_error, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_print_preview", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_print_preview, true)
    |> push_event("open-print-preview", %{})}
  end

  @impl true
  def handle_event("close_print_preview", _params, socket) do
    {:noreply, assign(socket, :show_print_preview, false)}
  end

  # Add these message handlers:

  @impl true
  def handle_info({:pdf_export_complete, pdf_info}, socket) do
    socket =
      socket
      |> assign(:exporting_pdf, false)
      |> put_flash(:info, "PDF exported successfully!")
      |> push_event("download_file", %{
          url: pdf_info.url,
          filename: pdf_info.filename
        })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pdf_export_error, reason}, socket) do
    socket =
      socket
      |> assign(:exporting_pdf, false)
      |> put_flash(:error, "PDF export failed: #{reason}")

    {:noreply, socket}
  end

  # Add the PDF export function:
  defp export_portfolio_to_pdf(portfolio) do
    try do
      # Create a simple PDF export using a library like PdfGenerator or Puppeteer
      # For now, we'll create a simple HTML-to-PDF export

      html_content = generate_pdf_html(portfolio)
      filename = "#{portfolio.slug}_portfolio_#{Date.utc_today()}.pdf"

      # Use a PDF generation library (you'll need to add this to your deps)
      case PdfGenerator.generate(html_content, page_size: "A4") do
        {:ok, pdf_binary} ->
          # Save to uploads directory
          upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "exports"])
          File.mkdir_p(upload_dir)

          file_path = Path.join(upload_dir, filename)
          File.write!(file_path, pdf_binary)

          {:ok, %{
            filename: filename,
            url: "/uploads/exports/#{filename}",
            file_path: file_path
          }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  defp generate_pdf_html(portfolio) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>#{portfolio.title} - Portfolio</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { text-align: center; margin-bottom: 30px; border-bottom: 2px solid #333; padding-bottom: 20px; }
        .section { margin-bottom: 25px; page-break-inside: avoid; }
        .section-title { font-size: 18px; font-weight: bold; color: #333; margin-bottom: 10px; border-bottom: 1px solid #ccc; padding-bottom: 5px; }
        .content { margin-left: 10px; }
        .job-entry, .education-entry { margin-bottom: 15px; }
        .job-title { font-weight: bold; }
        .company { font-style: italic; }
        .dates { color: #666; font-size: 14px; }
        .skills { display: flex; flex-wrap: wrap; gap: 5px; }
        .skill { background: #f0f0f0; padding: 3px 8px; border-radius: 3px; font-size: 12px; }
        @media print { .page-break { page-break-before: always; } }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{portfolio.title}</h1>
        <p>#{portfolio.description}</p>
      </div>

      #{generate_sections_html(portfolio.sections)}
    </body>
    </html>
    """
  end

  defp generate_sections_html(sections) do
    sections
    |> Enum.filter(fn section -> Map.get(section, :visible, true) end)
    |> Enum.sort_by(fn section -> Map.get(section, :position, 0) end)
    |> Enum.map(&generate_section_html/1)
    |> Enum.join("\n")
  end

  defp generate_section_html(section) do
    content = section.content || %{}

    case section.section_type do
      :intro ->
        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <p><strong>#{Map.get(content, "headline", "")}</strong></p>
            <p>#{Map.get(content, "summary", "")}</p>
            <p>📍 #{Map.get(content, "location", "")}</p>
          </div>
        </div>
        """

      :experience ->
        jobs_html = (Map.get(content, "jobs", []))
        |> Enum.map(fn job ->
          """
          <div class="job-entry">
            <div class="job-title">#{Map.get(job, "title", "")}</div>
            <div class="company">#{Map.get(job, "company", "")}</div>
            <div class="dates">#{Map.get(job, "start_date", "")} - #{Map.get(job, "end_date", "Present")}</div>
            <div>#{Map.get(job, "description", "")}</div>
          </div>
          """
        end)
        |> Enum.join("")

        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">#{jobs_html}</div>
        </div>
        """

      :skills ->
        skills_html = (Map.get(content, "skills", []))
        |> Enum.map(fn skill -> "<span class=\"skill\">#{skill}</span>" end)
        |> Enum.join("")

        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <div class="skills">#{skills_html}</div>
          </div>
        </div>
        """

      _ ->
        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <p>#{inspect(content)}</p>
          </div>
        </div>
        """
    end
  end

    # 🔥 FIXED: Main render function with proper layout routing
    @impl true
    def render(assigns) do
      layout = assigns[:template_layout] || "dashboard"

      IO.puts("🔥 RENDERING LAYOUT: #{layout}")
      IO.puts("🔥 SECTIONS COUNT: #{length(assigns[:sections] || [])}")

      case layout do
        "dashboard" -> render_dashboard_layout(assigns)
        "gallery" -> render_gallery_layout(assigns)
        "terminal" -> render_terminal_layout(assigns)
        "case_study" -> render_case_study_layout(assigns)
        "minimal" -> render_minimal_layout(assigns)
        "academic" -> render_academic_layout(assigns)
        _ -> render_dashboard_layout(assigns)  # fallback
      end
    end

    # 🔥 FIXED: Dashboard layout with proper section rendering
  defp render_dashboard_layout(assigns) do
    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <!-- 🆕 ENHANCED NAVIGATION STYLES -->
    <style>
    /* Navigation System Styles */
    .floating-nav {
      backdrop-filter: blur(12px);
      background: rgba(255, 255, 255, 0.9);
      border: 1px solid rgba(0, 0, 0, 0.1);
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    }

    .nav-dot {
      transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      cursor: pointer;
    }

    .nav-dot:hover {
      transform: scale(1.4);
    }

    .nav-dot.active {
      transform: scale(1.6);
      box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
    }

    .nav-progress-ring {
      transition: stroke-dashoffset 0.3s ease;
      transform: rotate(-90deg);
      transform-origin: center;
    }

    /* Enhanced card scrolling */
    .portfolio-card {
      max-height: 400px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }

    .portfolio-card-header {
      flex-shrink: 0;
    }

    .portfolio-card-content {
      flex: 1;
      overflow-y: auto;
      min-height: 0;
      padding: 1rem;
    }

    .portfolio-card-content::-webkit-scrollbar {
      width: 6px;
    }

    .portfolio-card-content::-webkit-scrollbar-track {
      background: #f1f1f1;
      border-radius: 3px;
    }

    .portfolio-card-content::-webkit-scrollbar-thumb {
      background: #c1c1c1;
      border-radius: 3px;
    }

    .portfolio-card-content::-webkit-scrollbar-thumb:hover {
      background: #a8a8a8;
    }

    /* Quick access toolbar */
    .quick-access-toolbar {
      position: fixed;
      top: 50%;
      right: 2rem;
      transform: translateY(-50%);
      z-index: 40;
      backdrop-filter: blur(12px);
      background: rgba(255, 255, 255, 0.9);
      border: 1px solid rgba(0, 0, 0, 0.1);
      border-radius: 16px;
      padding: 1rem;
      box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
    }

    /* Sticky navigation progress */
    .nav-progress {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      height: 4px;
      background: rgba(59, 130, 246, 0.2);
      z-index: 50;
    }

    .nav-progress-bar {
      height: 100%;
      background: linear-gradient(90deg, #3b82f6, #8b5cf6);
      transition: width 0.3s ease;
      width: 0%;
    }
    </style>

    <div class="min-h-screen portfolio-bg">
      <!-- 🆕 SCROLL PROGRESS BAR -->
      <div class="nav-progress">
        <div class="nav-progress-bar" id="scroll-progress"></div>
      </div>

      <!-- 🆕 FLOATING NAVIGATION (Sidebar Style) -->
      <nav class="fixed left-6 top-1/2 transform -translate-y-1/2 z-40 floating-nav rounded-2xl p-4">
        <div class="flex flex-col space-y-4">
          <!-- Portfolio Title -->
          <div class="text-center mb-4">
            <div class="w-12 h-12 portfolio-bg-primary rounded-xl flex items-center justify-center mb-2">
              <span class="text-white font-bold text-lg">
                <%= String.first(@portfolio.title) %>
              </span>
            </div>
            <p class="text-xs text-gray-600 font-medium">Portfolio</p>
          </div>

          <!-- Navigation Dots -->
          <%= for {section, index} <- Enum.with_index(@sections) do %>
            <button
              onclick={"document.getElementById('section-#{section.id}').scrollIntoView({behavior: 'smooth'}); updateActiveNav('section-#{section.id}');"}
              data-section-id={"section-#{section.id}"}
              class="nav-dot w-4 h-4 rounded-full portfolio-bg-secondary opacity-60 hover:opacity-100 relative group"
              title={section.title}
            >
              <!-- Tooltip -->
              <div class="absolute left-full ml-3 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap">
                <%= section.title %>
                <div class="absolute right-full top-1/2 transform -translate-y-1/2 w-0 h-0 border-t-4 border-b-4 border-r-4 border-transparent border-r-gray-900"></div>
              </div>
            </button>
          <% end %>

          <!-- Scroll to Top -->
          <button
            onclick="window.scrollTo({top: 0, behavior: 'smooth'})"
            class="nav-dot w-4 h-4 rounded-full bg-gray-300 hover:bg-gray-400 transition-colors group mt-4"
            title="Back to Top"
          >
            <div class="absolute left-full ml-3 px-3 py-2 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap">
              Back to Top
              <div class="absolute right-full top-1/2 transform -translate-y-1/2 w-0 h-0 border-t-4 border-b-4 border-r-4 border-transparent border-r-gray-900"></div>
            </div>
          </button>
        </div>
      </nav>

      <!-- 🆕 QUICK ACCESS TOOLBAR -->
      <div class="quick-access-toolbar">
        <div class="flex flex-col space-y-3">
          <!-- Actions Dropdown -->
          <div class="relative group">
            <button class="w-12 h-12 bg-gray-100 hover:bg-gray-200 rounded-xl flex items-center justify-center transition-colors group-hover:scale-105">
              <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z"/>
              </svg>
            </button>

            <!-- Dropdown Menu -->
            <div class="absolute right-full mr-3 bottom-0 opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all duration-200">
              <div class="bg-white rounded-xl shadow-lg border border-gray-200 py-2 min-w-[180px]">
                <button phx-click="export_pdf"
                        disabled={assigns[:exporting_pdf] || false}
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center space-x-3 text-sm">
                  <%= if assigns[:exporting_pdf] do %>
                    <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
                    </svg>
                    <span>Generating PDF...</span>
                  <% else %>
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                    </svg>
                    <span>Export PDF</span>
                  <% end %>
                </button>

                <button phx-click="show_print_preview"
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center space-x-3 text-sm">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4a2 2 0 00-2-2H9a2 2 0 00-2 2v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/>
                  </svg>
                  <span>Print Preview</span>
                </button>

                <hr class="my-2 border-gray-200">

                <button onclick="sharePortfolio()"
                        class="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center space-x-3 text-sm">
                  <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8.684 13.342C8.886 12.938 9 12.482 9 12c0-.482-.114-.938-.316-1.342m0 2.684a3 3 0 110-2.684m0 2.684l6.632 3.316m-6.632-6.632a3 3 0 105.367-2.684 3 3 0 00-5.367 2.684zm0 9.316a3 3 0 105.368 2.684 3 3 0 00-5.368-2.684z"/>
                  </svg>
                  <span>Share Portfolio</span>
                </button>
              </div>
            </div>
          </div>

          <!-- Contact Button -->
          <%= if contact_section = Enum.find(@sections, fn s -> s.section_type == :contact end) do %>
            <button
              onclick={"document.getElementById('section-#{contact_section.id}').scrollIntoView({behavior: 'smooth'});"}
              class="w-12 h-12 bg-blue-600 hover:bg-blue-700 rounded-xl flex items-center justify-center transition-colors text-white hover:scale-105"
              title="Contact"
            >
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
              </svg>
            </button>
          <% end %>
        </div>
      </div>

      <!-- Dashboard Header -->
      <header class="portfolio-header border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div class="grid lg:grid-cols-3 gap-8 items-center">
            <div class="lg:col-span-2">
              <h1 class="text-4xl lg:text-5xl font-bold mb-4 portfolio-primary">
                <%= @portfolio.title %>
              </h1>
              <p class="text-xl mb-6 portfolio-secondary">
                <%= @portfolio.description %>
              </p>

              <!-- Metrics -->
              <div class="grid grid-cols-3 gap-6">
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-accent"><%= length(@sections) %></div>
                  <div class="text-sm portfolio-secondary">Sections</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-primary">
                    <%= @sections |> Enum.map(fn s -> length(Map.get(s, :media_files, [])) end) |> Enum.sum() %>
                  </div>
                  <div class="text-sm portfolio-secondary">Projects</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold portfolio-accent">Active</div>
                  <div class="text-sm portfolio-secondary">Status</div>
                </div>
              </div>

              <!-- 🆕 SOCIAL LINKS UNDER INTRO -->
              <%= if intro_section = Enum.find(@sections, fn s -> s.section_type == :intro end) do %>
                <% social_links = get_in(intro_section, [:content, "social_links"]) || %{} %>
                <%= if map_size(social_links) > 0 do %>
                  <div class="mt-6 flex items-center space-x-4">
                    <span class="text-sm text-gray-600 font-medium">Connect:</span>
                    <%= for {platform, url} <- social_links, url != "" do %>
                      <a href={url} target="_blank"
                         class="w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-colors group">
                        <%= render_social_icon(platform) %>
                      </a>
                    <% end %>
                  </div>
                <% end %>
              <% end %>
            </div>

            <div class="lg:justify-self-end">
              <div class="w-64 h-64 portfolio-bg-primary rounded-xl shadow-2xl flex items-center justify-center">
                <span class="text-6xl font-bold text-white">
                  <%= String.first(@portfolio.title) %>
                </span>
              </div>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content with Fixed Card Heights -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8 ml-20">
        <%= if length(@sections) > 0 do %>
          <div class="grid gap-6 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3">
            <%= for section <- @sections do %>
              <div id={"section-#{section.id}"} class="portfolio-card shadow-lg rounded-xl border">
                <!-- Card Header (Fixed) -->
                <div class="portfolio-card-header p-4 border-b">
                  <div class="flex items-center justify-between">
                    <div>
                      <h2 class="text-xl font-bold portfolio-primary">
                        <%= section.title %>
                      </h2>
                      <!-- 🆕 SUBTLE SECTION TYPE LABEL -->
                      <span class="text-xs text-gray-500 font-medium uppercase tracking-wide">
                        <%= format_section_type(section.section_type) %>
                      </span>
                    </div>
                    <!-- Section indicator dot -->
                    <div class="w-3 h-3 rounded-full" style={"background-color: #{get_section_color(section.section_type)}"}></div>
                  </div>
                </div>

                <!-- Card Content (Scrollable) -->
                <div class="portfolio-card-content">
                  <%= render_section_content_safe(section) %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-16">
            <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            <h3 class="text-lg font-semibold text-gray-900 mb-2">No sections available</h3>
            <p class="text-gray-600">This portfolio is still being built.</p>
          </div>
        <% end %>
      </main>

      <!-- 🆕 JAVASCRIPT FOR NAVIGATION -->
      <script>
      document.addEventListener('DOMContentLoaded', function() {
        // Update scroll progress
        function updateScrollProgress() {
          const scrollTop = window.pageYOffset;
          const docHeight = document.documentElement.scrollHeight - window.innerHeight;
          const scrollPercent = (scrollTop / docHeight) * 100;
          document.getElementById('scroll-progress').style.width = scrollPercent + '%';
        }

        // Update active navigation dot
        function updateActiveNav(activeSectionId) {
          document.querySelectorAll('.nav-dot').forEach(dot => {
            if (dot.dataset.sectionId === activeSectionId) {
              dot.classList.add('active', 'portfolio-bg-primary');
              dot.classList.remove('portfolio-bg-secondary', 'opacity-60');
            } else {
              dot.classList.remove('active', 'portfolio-bg-primary');
              dot.classList.add('portfolio-bg-secondary', 'opacity-60');
            }
          });
        }

        // Intersection Observer for automatic navigation updates
        const sections = document.querySelectorAll('[id^="section-"]');
        if (sections.length > 0) {
          const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
              if (entry.isIntersecting) {
                updateActiveNav(entry.target.id);
              }
            });
          }, {
            threshold: 0.5,
            rootMargin: '-20% 0px -20% 0px'
          });

          sections.forEach(section => observer.observe(section));
        }

        // Scroll event listener
        window.addEventListener('scroll', updateScrollProgress);
        updateScrollProgress(); // Initial call

        // Make updateActiveNav globally available
        window.updateActiveNav = updateActiveNav;

        // Share function
        window.sharePortfolio = function() {
          if (navigator.share) {
            navigator.share({
              title: '<%= @portfolio.title %>',
              text: '<%= @portfolio.description %>',
              url: window.location.href
            });
          } else {
            // Fallback: copy to clipboard
            navigator.clipboard.writeText(window.location.href).then(() => {
              alert('Portfolio link copied to clipboard!');
            });
          }
        };
      });
      </script>
    </div>
    """
  end

    defp render_social_icon(platform) do
    case String.downcase(platform) do
      "linkedin" ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-gray-600 group-hover:text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
        </svg>
        """)
      "github" ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-gray-600 group-hover:text-gray-900" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
        </svg>
        """)
      "twitter" ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-gray-600 group-hover:text-blue-400" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
        </svg>
        """)
      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-5 h-5 text-gray-600 group-hover:text-gray-900" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """)
    end
  end

  defp get_section_color(section_type) do
    case section_type do
      :featured_project -> "#f59e0b"  # Amber
      :experience -> "#3b82f6"       # Blue
      :skills -> "#10b981"           # Emerald
      :education -> "#8b5cf6"        # Violet
      :case_study -> "#ec4899"       # Pink
      :media_showcase -> "#6366f1"   # Indigo
      :intro -> "#059669"            # Emerald
      :contact -> "#0891b2"          # Cyan
      :testimonial -> "#84cc16"      # Lime
      :awards -> "#eab308"           # Yellow
      :certifications -> "#06b6d4"   # Cyan
      :publications -> "#7c3aed"     # Violet
      :languages -> "#14b8a6"        # Teal
      _ -> "#6b7280"                 # Gray (default)
    end
  end

  @impl true
  def handle_event("export_pdf", _params, socket) do
    portfolio = socket.assigns.portfolio

    # Set loading state
    socket = assign(socket, :exporting_pdf, true)

    # Start PDF export in background task
    Task.start(fn ->
      case export_portfolio_to_pdf(portfolio) do
        {:ok, pdf_info} ->
          send(self(), {:pdf_export_complete, pdf_info})
        {:error, reason} ->
          send(self(), {:pdf_export_error, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("show_print_preview", _params, socket) do
    {:noreply,
    socket
    |> assign(:show_print_preview, true)
    |> push_event("open-print-preview", %{})}
  end

  @impl true
  def handle_event("close_print_preview", _params, socket) do
    {:noreply, assign(socket, :show_print_preview, false)}
  end

  # Add these message handlers:

  @impl true
  def handle_info({:pdf_export_complete, pdf_info}, socket) do
    socket =
      socket
      |> assign(:exporting_pdf, false)
      |> put_flash(:info, "PDF exported successfully!")
      |> push_event("download_file", %{
          url: pdf_info.url,
          filename: pdf_info.filename
        })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:pdf_export_error, reason}, socket) do
    socket =
      socket
      |> assign(:exporting_pdf, false)
      |> put_flash(:error, "PDF export failed: #{reason}")

    {:noreply, socket}
  end

  # Add the PDF export function:
  defp export_portfolio_to_pdf(portfolio) do
    try do
      # Create a simple PDF export using a library like PdfGenerator or Puppeteer
      # For now, we'll create a simple HTML-to-PDF export

      html_content = generate_pdf_html(portfolio)
      filename = "#{portfolio.slug}_portfolio_#{Date.utc_today()}.pdf"

      # Use a PDF generation library (you'll need to add this to your deps)
      case PdfGenerator.generate(html_content, page_size: "A4") do
        {:ok, pdf_binary} ->
          # Save to uploads directory
          upload_dir = Path.join([Application.app_dir(:frestyl, "priv"), "static", "uploads", "exports"])
          File.mkdir_p(upload_dir)

          file_path = Path.join(upload_dir, filename)
          File.write!(file_path, pdf_binary)

          {:ok, %{
            filename: filename,
            url: "/uploads/exports/#{filename}",
            file_path: file_path
          }}

        {:error, reason} ->
          {:error, reason}
      end
    rescue
      error ->
        {:error, Exception.message(error)}
    end
  end

  # Generate HTML for PDF export:
  defp generate_pdf_html(portfolio) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8">
      <title>#{portfolio.title} - Portfolio</title>
      <style>
        body { font-family: Arial, sans-serif; margin: 20px; line-height: 1.6; }
        .header { text-align: center; margin-bottom: 30px; border-bottom: 2px solid #333; padding-bottom: 20px; }
        .section { margin-bottom: 25px; page-break-inside: avoid; }
        .section-title { font-size: 18px; font-weight: bold; color: #333; margin-bottom: 10px; border-bottom: 1px solid #ccc; padding-bottom: 5px; }
        .content { margin-left: 10px; }
        .job-entry, .education-entry { margin-bottom: 15px; }
        .job-title { font-weight: bold; }
        .company { font-style: italic; }
        .dates { color: #666; font-size: 14px; }
        .skills { display: flex; flex-wrap: wrap; gap: 5px; }
        .skill { background: #f0f0f0; padding: 3px 8px; border-radius: 3px; font-size: 12px; }
        @media print { .page-break { page-break-before: always; } }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{portfolio.title}</h1>
        <p>#{portfolio.description}</p>
      </div>

      #{generate_sections_html(portfolio.sections)}
    </body>
    </html>
    """
  end

  defp generate_sections_html(sections) do
    sections
    |> Enum.filter(fn section -> Map.get(section, :visible, true) end)
    |> Enum.sort_by(fn section -> Map.get(section, :position, 0) end)
    |> Enum.map(&generate_section_html/1)
    |> Enum.join("\n")
  end

  defp generate_section_html(section) do
    content = section.content || %{}

    case section.section_type do
      :intro ->
        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <p><strong>#{Map.get(content, "headline", "")}</strong></p>
            <p>#{Map.get(content, "summary", "")}</p>
            <p>📍 #{Map.get(content, "location", "")}</p>
          </div>
        </div>
        """

      :experience ->
        jobs_html = (Map.get(content, "jobs", []))
        |> Enum.map(fn job ->
          """
          <div class="job-entry">
            <div class="job-title">#{Map.get(job, "title", "")}</div>
            <div class="company">#{Map.get(job, "company", "")}</div>
            <div class="dates">#{Map.get(job, "start_date", "")} - #{Map.get(job, "end_date", "Present")}</div>
            <div>#{Map.get(job, "description", "")}</div>
          </div>
          """
        end)
        |> Enum.join("")

        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">#{jobs_html}</div>
        </div>
        """

      :skills ->
        skills_html = (Map.get(content, "skills", []))
        |> Enum.map(fn skill -> "<span class=\"skill\">#{skill}</span>" end)
        |> Enum.join("")

        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <div class="skills">#{skills_html}</div>
          </div>
        </div>
        """

      _ ->
        """
        <div class="section">
          <h2 class="section-title">#{section.title}</h2>
          <div class="content">
            <p>#{inspect(content)}</p>
          </div>
        </div>
        """
    end
  end

  # 🔥 FIXED: Safe section content renderer
  defp render_section_content_safe(section) do
    try do
      content = section.content || %{}

      case section.section_type do
        :skills ->
          # 🔥 USE THE ENHANCED SKILLS DISPLAY COMPONENT
          render_enhanced_skills_section(section)

        :experience ->
          render_enhanced_experience_section(section)

        :education ->
          render_enhanced_education_section(section)

        :projects ->
          render_enhanced_projects_section(section)

        _ ->
          # For other section types, use existing logic
          case content do
            %{"summary" => summary} when is_binary(summary) and summary != "" ->
              summary
            %{"description" => desc} when is_binary(desc) and desc != "" ->
              desc
            %{"content" => content_text} when is_binary(content_text) and content_text != "" ->
              content_text
            %{"headline" => headline} when is_binary(headline) and headline != "" ->
              headline
            _ ->
              "Content available - click to view details"
          end
      end
    rescue
      _ -> "Unable to load content"
    end
  end


  # 🔥 Helper functions for section summaries
  defp render_experience_summary(jobs) do
    total_years = calculate_total_experience_years(jobs)
    current_job = Enum.find(jobs, fn job ->
      Map.get(job, "current", false) || String.downcase(Map.get(job, "end_date", "")) == "present"
    end)

    companies = jobs |> Enum.map(&Map.get(&1, "company", "")) |> Enum.reject(&(&1 == "")) |> Enum.uniq()

    """
    <div class="mt-8 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl border border-blue-200">
      <h4 class="text-lg font-semibold text-gray-900 mb-4">Experience Summary</h4>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="text-center">
          <div class="text-3xl font-bold text-blue-600">#{Float.round(total_years, 1)}</div>
          <div class="text-sm text-gray-600">Years Experience</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-indigo-600">#{length(companies)}</div>
          <div class="text-sm text-gray-600">Companies</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-purple-600">#{length(jobs)}</div>
          <div class="text-sm text-gray-600">Positions</div>
        </div>
      </div>
      #{if current_job do
        """
        <div class="mt-4 pt-4 border-t border-blue-200">
          <p class="text-sm text-gray-700 text-center">
            Currently working as <strong>#{Map.get(current_job, "title", "")}</strong>
            at <strong>#{Map.get(current_job, "company", "")}</strong>
          </p>
        </div>
        """
      else
        ""
      end}
    </div>
    """
  end

  # Helper functions:
  defp sort_jobs_by_date(jobs) do
    jobs
    |> Enum.sort_by(fn job ->
      start_date = Map.get(job, "start_date", "")
      current = Map.get(job, "current", false)

      # Current jobs go first, then sort by start date (most recent first)
      cond do
        current -> {0, parse_date_for_sorting(start_date)}
        true -> {1, parse_date_for_sorting(start_date)}
      end
    end, :desc)
  end

  defp parse_date_for_sorting(date_str) when is_binary(date_str) do
    # Simple date parsing for sorting - extract year
    case Regex.run(~r/(\d{4})/, date_str) do
      [_, year] -> String.to_integer(year)
      _ -> 0
    end
  end

  defp format_date_range(start_date, end_date, current) do
    formatted_start = format_date_simple(start_date)

    cond do
      current || String.downcase(end_date) == "present" ->
        "#{formatted_start} - Present"
      end_date != "" ->
        "#{formatted_start} - #{format_date_simple(end_date)}"
      true ->
        formatted_start
    end
  end

  defp format_date_simple(date_str) when is_binary(date_str) and date_str != "" do
    # Handle various date formats
    cond do
      String.match?(date_str, ~r/^\d{4}$/) -> date_str
      String.match?(date_str, ~r/^\w+ \d{4}$/) -> date_str
      String.match?(date_str, ~r/^\d{1,2}\/\d{4}$/) -> date_str
      true -> date_str
    end
  end
  defp format_date_simple(_), do: ""

  defp calculate_job_duration_display(start_date, end_date, current) do
    case calculate_job_duration_months(start_date, end_date, current) do
      months when months >= 12 ->
        years = div(months, 12)
        remaining_months = rem(months, 12)

        cond do
          remaining_months == 0 -> "#{years} yr#{if years > 1, do: "s", else: ""}"
          years == 0 -> "#{remaining_months} mo#{if remaining_months > 1, do: "s", else: ""}"
          true -> "#{years} yr#{if years > 1, do: "s", else: ""} #{remaining_months} mo#{if remaining_months > 1, do: "s", else: ""}"
        end
      months when months > 0 ->
        "#{months} mo#{if months > 1, do: "s", else: ""}"
      _ ->
        nil
    end
  end

  defp calculate_job_duration_months(start_date, end_date, current) do
    with {:ok, start_parsed} <- parse_resume_date(start_date),
        end_parsed <- if(current, do: Date.utc_today(), else: parse_resume_date(end_date)) do
      case end_parsed do
        {:ok, end_date_parsed} ->
          Date.diff(end_date_parsed, start_parsed) / 30 |> round()
        _ ->
          0
      end
    else
      _ -> 0
    end
  end

  defp calculate_total_experience_years(jobs) do
    jobs
    |> Enum.map(fn job ->
      start_date = Map.get(job, "start_date", "")
      end_date = Map.get(job, "end_date", "")
      current = Map.get(job, "current", false)

      months = calculate_job_duration_months(start_date, end_date, current)
      months / 12.0
    end)
    |> Enum.sum()
  end


  defp render_enhanced_skills_section(section) do
    content = section.content || %{}
    skill_categories = Map.get(content, "skill_categories", %{})
    flat_skills = Map.get(content, "skills", [])

    # Create assigns map for the component
    assigns = %{
      section: section,
      skill_categories: skill_categories,
      flat_skills: flat_skills,
      show_proficiency: Map.get(content, "show_proficiency", true),
      show_years: Map.get(content, "show_years", true),
      display_mode: Map.get(content, "skill_display_mode", "categorized")
    }

    Phoenix.HTML.raw("""
    <div class="skills-enhanced-container">
      #{render_skills_content_only(assigns)}
    </div>
    """)
  end



  defp render_skills_summary(content) do
    skills = Map.get(content, "skills", [])
    skill_categories = Map.get(content, "skill_categories", %{})

    total_skills = length(skills) + (skill_categories |> Map.values() |> List.flatten() |> length())

    case total_skills do
      0 -> "No skills added yet"
      1 -> "1 skill"
      count -> "#{count} skills"
    end
  end

  defp render_skills_content_only(assigns) do
    total_skills = calculate_total_skills(assigns.skill_categories, assigns.flat_skills)

    if total_skills == 0 do
      """
      <div class="text-center py-8">
        <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
          </svg>
        </div>
        <p class="text-gray-500">No skills added yet</p>
      </div>
      """
    else
      display_mode = assigns.display_mode

      if display_mode == "categorized" && map_size(assigns.skill_categories) > 0 do
        render_categorized_skills_view(assigns)
      else
        render_flat_skills_view(assigns)
      end
    end
  end

  # 🔥 NEW: Render categorized skills for portfolio view
  defp render_categorized_skills_view(assigns) do
    categories_html = assigns.skill_categories
    |> Enum.map(fn {category, skills} ->
      render_category_section(category, skills, assigns)
    end)
    |> Enum.join("")

    """
    <div class="space-y-6">
      #{categories_html}
      #{render_skills_summary_view(assigns)}
    </div>
    """
  end

  # 🔥 NEW: Render individual category section
  defp render_category_section(category, skills, assigns) do
    category_color = get_category_color_class(category)
    skills_html = skills
    |> Enum.with_index()
    |> Enum.map(fn {skill, index} ->
      render_skill_card_view(skill, index, category, assigns)
    end)
    |> Enum.join("")

    """
    <div class="skill-category mb-6">
      <div class="flex items-center mb-3">
        <div class="w-3 h-3 rounded-full mr-3 #{category_color}"></div>
        <h4 class="text-lg font-semibold text-gray-900">#{category}</h4>
        <span class="ml-2 px-2 py-1 bg-gray-100 text-gray-600 text-xs font-medium rounded-full">
          #{length(skills)} skills
        </span>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
        #{skills_html}
      </div>
    </div>
    """
  end

  # 🔥 NEW: Render individual skill card
  defp render_skill_card_view(skill, index, category, assigns) do
    {skill_name, proficiency, years} = parse_skill_data_view(skill)
    card_style = get_skill_card_style_view(proficiency, category)
    proficiency_dots = if assigns.show_proficiency && proficiency, do: render_proficiency_dots_view(proficiency), else: ""
    proficiency_badge = if assigns.show_proficiency && proficiency, do: render_proficiency_badge_view(proficiency), else: ""
    years_badge = if assigns.show_years && years && years > 0, do: render_years_badge_view(years), else: ""

    """
    <div class="skill-card group relative p-4 rounded-xl border-2 transition-all duration-300 hover:scale-105 hover:shadow-lg cursor-pointer #{card_style}">
      <div class="flex items-start justify-between mb-2">
        <h5 class="font-semibold text-gray-900 text-sm leading-tight">#{skill_name}</h5>
        #{proficiency_dots}
      </div>
      <div class="flex items-center justify-between">
        #{proficiency_badge}
        #{years_badge}
      </div>
      #{render_skill_tooltip_view(skill_name, proficiency, years, category)}
    </div>
    """
  end

  # 🔥 NEW: Render flat skills view
  defp render_flat_skills_view(assigns) do
    skills_html = assigns.flat_skills
    |> Enum.with_index()
    |> Enum.map(fn {skill, index} ->
      skill_name = case skill do
        %{"name" => name} -> name
        name when is_binary(name) -> name
        _ -> to_string(skill)
      end
      color_class = get_simple_skill_color_view(index)

      """
      <span class="inline-flex items-center px-3 py-2 rounded-lg text-sm font-medium transition-all duration-200 hover:scale-105 #{color_class}">
        #{skill_name}
      </span>
      """
    end)
    |> Enum.join("")

    """
    <div class="space-y-6">
      <div class="flex flex-wrap gap-3">
        #{skills_html}
      </div>
      #{render_skills_summary_view(assigns)}
    </div>
    """
  end

  # 🔥 NEW: Enhanced experience section renderer
  defp render_enhanced_experience_section(section) do
    content = section.content || %{}
    jobs = Map.get(content, "jobs", [])

    case length(jobs) do
      0 ->
        render_empty_experience_state()
      _ ->
        render_experience_timeline(jobs)
    end
  end

  defp render_enhanced_experience_section(section) do
    content = section.content || %{}
    jobs = Map.get(content, "jobs", [])

    case length(jobs) do
      0 ->
        render_empty_experience_state()
      _ ->
        render_experience_timeline(jobs)
    end
  end

  defp render_empty_experience_state() do
    """
    <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-3">
        <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
      </div>
      <p class="text-gray-500 text-sm">No work experience added yet</p>
    </div>
    """
  end

  defp render_experience_timeline(jobs) do
    # Sort jobs by start date (most recent first)
    sorted_jobs = sort_jobs_by_date(jobs)

    jobs_html = sorted_jobs
    |> Enum.with_index()
    |> Enum.map(fn {job, index} ->
      render_job_card(job, index, length(sorted_jobs))
    end)
    |> Enum.join("")

    """
    <div class="space-y-4">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Career Journey</h3>
        <span class="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
          #{length(sorted_jobs)} Position#{if length(sorted_jobs) != 1, do: "s", else: ""}
        </span>
      </div>

      <div class="relative">
        <!-- Timeline line -->
        <div class="absolute left-6 top-0 bottom-0 w-0.5 bg-gray-200"></div>
        #{jobs_html}
      </div>

      <!-- Experience Summary -->
      #{render_experience_summary(sorted_jobs)}
    </div>
    """
  end

  defp render_empty_experience_state() do
    """
    <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-3">
        <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
      </div>
      <p class="text-gray-500 text-sm">No work experience added yet</p>
    </div>
    """
  end

  defp render_job_card(job, index, total_jobs) do
    title = clean_html_content(Map.get(job, "title", "Position"))
    company = clean_html_content(Map.get(job, "company", "Company"))
    location = clean_html_content(Map.get(job, "location", ""))
    start_date = clean_html_content(Map.get(job, "start_date", ""))
    end_date = clean_html_content(Map.get(job, "end_date", ""))
    current = Map.get(job, "current", false)
    description = clean_html_content(Map.get(job, "description", ""))
    employment_type = clean_html_content(Map.get(job, "employment_type", "Full-time"))

    # Calculate duration
    duration = calculate_job_duration_display(start_date, end_date, current)

    # Determine if this is the current job
    is_current = current || String.downcase(end_date) == "present"

    """
    <div class="relative flex items-start space-x-4 pb-8">
      <!-- Timeline dot -->
      <div class="relative flex-shrink-0">
        <div class="w-12 h-12 #{if is_current, do: "bg-green-500", else: "bg-blue-500"} rounded-full flex items-center justify-center shadow-lg">
          #{if is_current do
            """
            <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            """
          else
            """
            <div class="w-4 h-4 bg-white rounded-full"></div>
            """
          end}
        </div>
        #{if is_current do
          """
          <div class="absolute -top-1 -right-1 w-4 h-4 bg-green-400 rounded-full animate-pulse"></div>
          """
        else
          ""
        end}
      </div>

      <!-- Job content -->
      <div class="flex-1 min-w-0 bg-white rounded-xl border border-gray-200 p-6 shadow-sm hover:shadow-md transition-shadow">
        <!-- Header -->
        <div class="flex items-start justify-between mb-4">
          <div class="flex-1">
            <h4 class="text-lg font-semibold text-gray-900 mb-1">#{title}</h4>
            <div class="flex items-center space-x-2 text-gray-600 mb-2">
              <span class="font-medium">#{company}</span>
              #{if location != "" do
                """
                <span class="text-gray-400">•</span>
                <span class="text-sm">#{location}</span>
                """
              else
                ""
              end}
            </div>
            <div class="flex items-center space-x-3 text-sm text-gray-500">
              <span class="inline-flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
                #{format_date_range(start_date, end_date, current)}
              </span>
              #{if duration do
                """
                <span class="text-gray-400">•</span>
                <span>#{duration}</span>
                """
              else
                ""
              end}
              <span class="text-gray-400">•</span>
              <span class="px-2 py-1 bg-gray-100 text-gray-700 rounded-full text-xs font-medium">
                #{employment_type}
              </span>
            </div>
          </div>

          #{if is_current do
            """
            <span class="inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">
              <span class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></span>
              Current
            </span>
            """
          else
            ""
          end}
        </div>

        <!-- Description -->
        #{if description != "" do
          """
          <div class="text-gray-700 leading-relaxed">
            <p>#{description}</p>
          </div>
          """
        else
          ""
        end}

        <!-- Skills/Technologies -->
        #{render_job_skills(job)}
      </div>
    </div>
    """
  end


  defp render_job_skills(job) do
    skills = Map.get(job, "skills", [])
    technologies = Map.get(job, "technologies", [])
    all_skills = (skills ++ technologies) |> Enum.uniq() |> Enum.reject(&(&1 == ""))

    if length(all_skills) > 0 do
      skills_html = all_skills
      |> Enum.take(6) # Limit to 6 skills for clean display
      |> Enum.map(fn skill ->
        """
        <span class="inline-flex items-center px-2 py-1 bg-blue-50 text-blue-700 text-xs font-medium rounded">
          #{clean_html_content(skill)}
        </span>
        """
      end)
      |> Enum.join("")

      remaining_count = max(0, length(all_skills) - 6)

      """
      <div class="mt-4 pt-4 border-t border-gray-100">
        <div class="flex flex-wrap gap-2">
          #{skills_html}
          #{if remaining_count > 0 do
            """
            <span class="inline-flex items-center px-2 py-1 bg-gray-100 text-gray-600 text-xs font-medium rounded">
              +#{remaining_count} more
            </span>
            """
          else
            ""
          end}
        </div>
      </div>
      """
    else
      ""
    end
  end

  defp render_experience_summary(jobs) do
    total_years = calculate_total_experience_years(jobs)
    current_job = Enum.find(jobs, fn job ->
      Map.get(job, "current", false) || String.downcase(Map.get(job, "end_date", "")) == "present"
    end)

    companies = jobs |> Enum.map(&Map.get(&1, "company", "")) |> Enum.reject(&(&1 == "")) |> Enum.uniq()

    """
    <div class="mt-8 p-6 bg-gradient-to-r from-blue-50 to-indigo-50 rounded-xl border border-blue-200">
      <h4 class="text-lg font-semibold text-gray-900 mb-4">Experience Summary</h4>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="text-center">
          <div class="text-3xl font-bold text-blue-600">#{Float.round(total_years, 1)}</div>
          <div class="text-sm text-gray-600">Years Experience</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-indigo-600">#{length(companies)}</div>
          <div class="text-sm text-gray-600">Companies</div>
        </div>
        <div class="text-center">
          <div class="text-3xl font-bold text-purple-600">#{length(jobs)}</div>
          <div class="text-sm text-gray-600">Positions</div>
        </div>
      </div>
      #{if current_job do
        """
        <div class="mt-4 pt-4 border-t border-blue-200">
          <p class="text-sm text-gray-700 text-center">
            Currently working as <strong>#{Map.get(current_job, "title", "")}</strong>
            at <strong>#{Map.get(current_job, "company", "")}</strong>
          </p>
        </div>
        """
      else
        ""
      end}
    </div>
    """
  end

  # Helper functions:
  defp sort_jobs_by_date(jobs) do
    jobs
    |> Enum.sort_by(fn job ->
      start_date = Map.get(job, "start_date", "")
      current = Map.get(job, "current", false)

      # Current jobs go first, then sort by start date (most recent first)
      cond do
        current -> {0, parse_date_for_sorting(start_date)}
        true -> {1, parse_date_for_sorting(start_date)}
      end
    end, :desc)
  end

  defp parse_date_for_sorting(date_str) when is_binary(date_str) do
    # Simple date parsing for sorting - extract year
    case Regex.run(~r/(\d{4})/, date_str) do
      [_, year] -> String.to_integer(year)
      _ -> 0
    end
  end

  defp format_date_range(start_date, end_date, current) do
    formatted_start = format_date_simple(start_date)

    cond do
      current || String.downcase(end_date) == "present" ->
        "#{formatted_start} - Present"
      end_date != "" ->
        "#{formatted_start} - #{format_date_simple(end_date)}"
      true ->
        formatted_start
    end
  end

  defp format_date_simple(date_str) when is_binary(date_str) and date_str != "" do
    # Handle various date formats
    cond do
      String.match?(date_str, ~r/^\d{4}$/) -> date_str
      String.match?(date_str, ~r/^\w+ \d{4}$/) -> date_str
      String.match?(date_str, ~r/^\d{1,2}\/\d{4}$/) -> date_str
      true -> date_str
    end
  end
  defp format_date_simple(_), do: ""

  defp calculate_job_duration_display(start_date, end_date, current) do
    case calculate_job_duration_months(start_date, end_date, current) do
      months when months >= 12 ->
        years = div(months, 12)
        remaining_months = rem(months, 12)

        cond do
          remaining_months == 0 -> "#{years} yr#{if years > 1, do: "s", else: ""}"
          years == 0 -> "#{remaining_months} mo#{if remaining_months > 1, do: "s", else: ""}"
          true -> "#{years} yr#{if years > 1, do: "s", else: ""} #{remaining_months} mo#{if remaining_months > 1, do: "s", else: ""}"
        end
      months when months > 0 ->
        "#{months} mo#{if months > 1, do: "s", else: ""}"
      _ ->
        nil
    end
  end

  defp calculate_job_duration_months(start_date, end_date, current) do
    with {:ok, start_parsed} <- parse_resume_date(start_date),
        end_parsed <- if(current, do: Date.utc_today(), else: parse_resume_date(end_date)) do
      case end_parsed do
        {:ok, end_date_parsed} ->
          Date.diff(end_date_parsed, start_parsed) / 30 |> round()
        _ ->
          0
      end
    else
      _ -> 0
    end
  end

  defp calculate_total_experience_years(jobs) do
    jobs
    |> Enum.map(fn job ->
      start_date = Map.get(job, "start_date", "")
      end_date = Map.get(job, "end_date", "")
      current = Map.get(job, "current", false)

      months = calculate_job_duration_months(start_date, end_date, current)
      months / 12.0
    end)
    |> Enum.sum()
  end

  defp render_enhanced_experience_section(section) do
    content = section.content || %{}
    jobs = Map.get(content, "jobs", [])

    case length(jobs) do
      0 ->
        render_empty_experience_state()
      _ ->
        render_experience_timeline(jobs)
    end
  end

  defp render_empty_experience_state() do
    """
    <div class="text-center py-8 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
      <div class="w-12 h-12 bg-gray-200 rounded-full flex items-center justify-center mx-auto mb-3">
        <svg class="w-6 h-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
      </div>
      <p class="text-gray-500 text-sm">No work experience added yet</p>
    </div>
    """
  end

  defp render_experience_timeline(jobs) do
    # Sort jobs by start date (most recent first)
    sorted_jobs = sort_jobs_by_date(jobs)

    jobs_html = sorted_jobs
    |> Enum.with_index()
    |> Enum.map(fn {job, index} ->
      render_job_card(job, index, length(sorted_jobs))
    end)
    |> Enum.join("")

    """
    <div class="space-y-4">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Career Journey</h3>
        <span class="px-3 py-1 bg-blue-100 text-blue-800 text-sm font-medium rounded-full">
          #{length(sorted_jobs)} Position#{if length(sorted_jobs) != 1, do: "s", else: ""}
        </span>
      </div>

      <div class="relative">
        <!-- Timeline line -->
        <div class="absolute left-6 top-0 bottom-0 w-0.5 bg-gray-200"></div>
        #{jobs_html}
      </div>

      <!-- Experience Summary -->
      #{render_experience_summary(sorted_jobs)}
    </div>
    """
  end

  # 🔥 NEW: Enhanced education section renderer
  defp render_enhanced_education_section(section) do
    content = section.content || %{}
    education = Map.get(content, "education", [])
    certifications = Map.get(content, "certifications", [])

    if length(education) == 0 and length(certifications) == 0 do
      render_empty_education_state()
    else
      render_education_timeline(education, certifications)
    end
  end

  defp render_empty_education_state() do
    """
    <div class="text-center py-12 bg-purple-50 rounded-xl border-2 border-dashed border-purple-300">
      <div class="w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center mx-auto mb-4">
        <svg class="w-8 h-8 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5"/>
        </svg>
      </div>
      <h3 class="text-lg font-semibold text-gray-900 mb-2">No education background yet</h3>
      <p class="text-gray-600 mb-6">Educational information will appear here when added</p>
    </div>
    """
  end

  defp render_education_timeline(education, certifications) do
    # Sort education by date (most recent first)
    sorted_education = sort_education_by_date(education)

    education_html = sorted_education
    |> Enum.with_index()
    |> Enum.map(fn {edu, index} ->
      render_education_card(edu, index, length(sorted_education))
    end)
    |> Enum.join("")

    certifications_html = if length(certifications) > 0 do
      certs_html = certifications
      |> Enum.map(&render_certification_card/1)
      |> Enum.join("")

      """
      <div class="mt-8">
        <h4 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <svg class="w-5 h-5 mr-2 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
          </svg>
          Certifications
        </h4>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          #{certs_html}
        </div>
      </div>
      """
    else
      ""
    end

    """
    <div class="space-y-6">
      <div class="flex items-center justify-between mb-6">
        <h3 class="text-lg font-semibold text-gray-900">Educational Background</h3>
        <span class="px-3 py-1 bg-purple-100 text-purple-800 text-sm font-medium rounded-full">
          #{length(education)} Degree#{if length(education) != 1, do: "s", else: ""}
        </span>
      </div>

      <div class="space-y-6">
        #{education_html}
      </div>

      #{certifications_html}
    </div>
    """
  end

    defp render_education_card(education, index, total_count) do
    # FIXED: Clean HTML content before rendering
    institution = clean_html_content(Map.get(education, "institution", ""))
    degree = clean_html_content(Map.get(education, "degree", ""))
    field = clean_html_content(Map.get(education, "field", ""))
    location = clean_html_content(Map.get(education, "location", ""))
    start_date = clean_html_content(Map.get(education, "start_date", ""))
    end_date = clean_html_content(Map.get(education, "end_date", ""))
    status = clean_html_content(Map.get(education, "status", "Completed"))
    gpa = clean_html_content(Map.get(education, "gpa", ""))
    description = clean_html_content(Map.get(education, "description", ""))

    is_current = String.downcase(status) in ["in progress", "current"]

    """
    <div class="bg-white rounded-xl border border-gray-200 p-6 hover:shadow-md transition-all duration-200">
      <div class="flex items-start justify-between mb-4">
        <div class="flex-1">
          <h4 class="text-lg font-semibold text-gray-900 mb-1">#{degree}</h4>
          <p class="text-purple-600 font-medium mb-1">#{field}</p>
          <div class="flex items-center text-gray-600 mb-2">
            <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-4m-5 0H3m2 0h2M7 7h.01M7 3h5a2 2 0 012 2v13H7V3z"/>
            </svg>
            <span class="font-medium">#{institution}</span>
            #{if location != "" do
              " • #{location}"
            end}
          </div>

          <div class="flex items-center space-x-3 text-sm text-gray-500 mb-3">
            <span class="inline-flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
              </svg>
              #{format_education_date_range(start_date, end_date, is_current)}
            </span>
            #{if gpa != "" do
              """
              <span class="text-gray-400">•</span>
              <span class="font-medium">GPA: #{gpa}</span>
              """
            end}
          </div>
        </div>

        #{if is_current do
          """
          <span class="inline-flex items-center px-3 py-1 bg-blue-100 text-blue-800 text-xs font-medium rounded-full">
            <span class="w-2 h-2 bg-blue-400 rounded-full mr-2 animate-pulse"></span>
            In Progress
          </span>
          """
        else
          """
          <span class="inline-flex items-center px-3 py-1 bg-green-100 text-green-800 text-xs font-medium rounded-full">
            <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>
            #{status}
          </span>
          """
        end}
      </div>

      #{if description != "" do
        """
        <div class="text-gray-700 text-sm leading-relaxed">
          <p>#{description}</p>
        </div>
        """
      end}
    </div>
    """
  end

  defp sort_education_by_date(education) do
    education
    |> Enum.sort_by(fn edu ->
      start_date = Map.get(edu, "start_date", "")
      is_current = String.downcase(Map.get(edu, "status", "")) == "in progress"

      # Current education goes first, then sort by start date (most recent first)
      cond do
        is_current -> {0, parse_education_date_for_sorting(start_date)}
        true -> {1, parse_education_date_for_sorting(start_date)}
      end
    end, :desc)
  end

  defp parse_education_date_for_sorting(date_str) when is_binary(date_str) do
    case Regex.run(~r/(\d{4})/, date_str) do
      [_, year] -> String.to_integer(year)
      _ -> 0
    end
  end

  defp format_education_date_range(start_date, end_date, is_current) do
    formatted_start = format_date_simple(start_date)

    cond do
      is_current -> "#{formatted_start} - Present"
      end_date != "" -> "#{formatted_start} - #{format_date_simple(end_date)}"
      true -> formatted_start
    end
  end

  defp render_certification_card(certification) do
    name = clean_html_content(Map.get(certification, "name", ""))
    issuer = clean_html_content(Map.get(certification, "issuer", ""))
    date = clean_html_content(Map.get(certification, "date", ""))
    credential_id = clean_html_content(Map.get(certification, "credential_id", ""))

    """
    <div class="bg-gradient-to-r from-green-50 to-emerald-50 rounded-lg border border-green-200 p-4">
      <div class="flex items-start justify-between">
        <div class="flex-1">
          <h5 class="font-semibold text-gray-900 mb-1">#{name}</h5>
          <p class="text-green-700 font-medium text-sm mb-1">#{issuer}</p>
          #{if date != "" do
            """
            <p class="text-gray-600 text-sm">#{date}</p>
            """
          end}
          #{if credential_id != "" do
            """
            <p class="text-xs text-gray-500 mt-2">ID: #{credential_id}</p>
            """
          end}
        </div>
        <div class="w-8 h-8 bg-green-100 rounded-full flex items-center justify-center">
          <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4M7.835 4.697a3.42 3.42 0 001.946-.806 3.42 3.42 0 014.438 0 3.42 3.42 0 001.946.806 3.42 3.42 0 013.138 3.138 3.42 3.42 0 00.806 1.946 3.42 3.42 0 010 4.438 3.42 3.42 0 00-.806 1.946 3.42 3.42 0 01-3.138 3.138 3.42 3.42 0 00-1.946.806 3.42 3.42 0 01-4.438 0 3.42 3.42 0 00-1.946-.806 3.42 3.42 0 01-3.138-3.138 3.42 3.42 0 00-.806-1.946 3.42 3.42 0 010-4.438 3.42 3.42 0 00.806-1.946 3.42 3.42 0 013.138-3.138z"/>
          </svg>
        </div>
      </div>
    </div>
    """
  end

    defp clean_html_content(content) when is_binary(content) do
    content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.replace(~r/&nbsp;/, " ")
    |> String.replace(~r/&amp;/, "&")
    |> String.replace(~r/&lt;/, "<")
    |> String.replace(~r/&gt;/, ">")
    |> String.replace(~r/&quot;/, "\"")
    |> String.replace(~r/&#39;/, "'")
    |> String.trim()
  end
  defp clean_html_content(content), do: to_string(content)

  # 🔥 NEW: Enhanced projects section renderer
  defp render_enhanced_projects_section(section) do
    content = section.content || %{}
    projects = Map.get(content, "projects", [])

    case length(projects) do
      0 ->
        "No projects added yet"
      count when count <= 2 ->
        # Show actual project names for small lists
        project_names = projects
        |> Enum.take(2)
        |> Enum.map(fn project -> Map.get(project, "title", "Project") end)
        |> Enum.join(", ")

        "#{count} projects: #{project_names}"
      count ->
        "#{count} projects"
    end
  end

  # 🔥 HELPER FUNCTIONS

  defp parse_skill_data_view(skill) do
    case skill do
      %{"name" => name, "proficiency" => prof, "years" => years} -> {name, prof, years}
      %{"name" => name, "proficiency" => prof} -> {name, prof, nil}
      %{"name" => name} -> {name, nil, nil}
      name when is_binary(name) -> {name, nil, nil}
      _ -> {"Unknown Skill", nil, nil}
    end
  end

  defp get_category_color_class(category) do
    case String.downcase(category) do
      "programming languages" -> "bg-blue-500"
      "frameworks & libraries" -> "bg-purple-500"
      "tools & platforms" -> "bg-green-500"
      "databases" -> "bg-orange-500"
      "design & creative" -> "bg-pink-500"
      "soft skills" -> "bg-emerald-500"
      "data & analytics" -> "bg-red-500"
      "mobile development" -> "bg-indigo-500"
      "devops & cloud" -> "bg-teal-500"
      _ -> "bg-gray-500"
    end
  end

  defp get_skill_card_style_view(proficiency, category) do
    base_color = get_category_base_color_view(category)
    intensity = case String.downcase(proficiency || "intermediate") do
      "expert" -> "200"
      "advanced" -> "150"
      "intermediate" -> "100"
      "beginner" -> "50"
      _ -> "100"
    end

    "bg-#{base_color}-#{intensity} border-#{base_color}-300"
  end

  defp get_category_base_color_view(category) do
    case String.downcase(category) do
      "programming languages" -> "blue"
      "frameworks & libraries" -> "purple"
      "tools & platforms" -> "green"
      "databases" -> "orange"
      "design & creative" -> "pink"
      "soft skills" -> "emerald"
      "data & analytics" -> "red"
      "mobile development" -> "indigo"
      "devops & cloud" -> "teal"
      _ -> "gray"
    end
  end

  defp render_proficiency_dots_view(proficiency) do
    level = case String.downcase(proficiency) do
      "expert" -> 4
      "advanced" -> 3
      "intermediate" -> 2
      "beginner" -> 1
      _ -> 2
    end

    dots = 1..4
    |> Enum.map(fn i ->
      opacity = if i <= level, do: "opacity-100", else: "opacity-20"
      "<div class=\"w-2 h-2 rounded-full bg-current #{opacity}\"></div>"
    end)
    |> Enum.join("")

    "<div class=\"flex space-x-1 ml-2\">#{dots}</div>"
  end

  defp render_proficiency_badge_view(proficiency) do
    {bg_class, text_class} = case String.downcase(proficiency) do
      "expert" -> {"bg-green-100", "text-green-800"}
      "advanced" -> {"bg-blue-100", "text-blue-800"}
      "intermediate" -> {"bg-yellow-100", "text-yellow-800"}
      "beginner" -> {"bg-gray-100", "text-gray-800"}
      _ -> {"bg-purple-100", "text-purple-800"}
    end

    """
    <span class="px-2 py-1 text-xs font-medium rounded-full #{bg_class} #{text_class} border">
      #{String.capitalize(proficiency)}
    </span>
    """
  end

  defp render_years_badge_view(years) do
    """
    <div class="flex items-center space-x-1 text-xs text-gray-600">
      <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
      </svg>
      <span class="font-medium">#{years}y</span>
    </div>
    """
  end

  defp render_skill_tooltip_view(skill_name, proficiency, years, category) do
    proficiency_text = if proficiency, do: "Proficiency: #{String.capitalize(proficiency)}", else: ""
    years_text = if years && years > 0, do: "Experience: #{years} years", else: ""

    content_lines = [proficiency_text, years_text, category]
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&("<div class=\"text-xs opacity-90\">#{&1}</div>"))
    |> Enum.join("")

    """
    <div class="skill-tooltip absolute bottom-full left-1/2 transform -translate-x-1/2 mb-3 px-4 py-3 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-20 shadow-xl">
      <div class="text-center">
        <div class="font-semibold">#{skill_name}</div>
        #{content_lines}
      </div>
      <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
    </div>
    """
  end

  defp get_simple_skill_color_view(index) do
    colors = [
      "bg-blue-100 text-blue-800 hover:bg-blue-200",
      "bg-purple-100 text-purple-800 hover:bg-purple-200",
      "bg-green-100 text-green-800 hover:bg-green-200",
      "bg-orange-100 text-orange-800 hover:bg-orange-200",
      "bg-pink-100 text-pink-800 hover:bg-pink-200",
      "bg-emerald-100 text-emerald-800 hover:bg-emerald-200",
      "bg-red-100 text-red-800 hover:bg-red-200",
      "bg-indigo-100 text-indigo-800 hover:bg-indigo-200"
    ]

    Enum.at(colors, rem(index, length(colors)))
  end

  defp render_skills_summary_view(assigns) do
    total_skills = calculate_total_skills(assigns.skill_categories, assigns.flat_skills)
    categories_count = map_size(assigns.skill_categories)

    """
    <div class="mt-6 p-4 bg-gradient-to-r from-gray-50 to-blue-50 rounded-xl border border-gray-200">
      <div class="flex items-center justify-between">
        <div class="flex items-center space-x-6">
          <div class="text-center">
            <div class="text-2xl font-bold text-blue-600">#{total_skills}</div>
            <div class="text-xs text-gray-600 uppercase tracking-wide">Total Skills</div>
          </div>
          #{if categories_count > 0 do
            """
            <div class="text-center">
              <div class="text-2xl font-bold text-purple-600">#{categories_count}</div>
              <div class="text-xs text-gray-600 uppercase tracking-wide">Categories</div>
            </div>
            """
          else
            ""
          end}
        </div>
      </div>
    </div>
    """
  end

  defp calculate_total_skills(skill_categories, flat_skills) do
    categorized_count = skill_categories
    |> Map.values()
    |> List.flatten()
    |> length()

    if categorized_count > 0, do: categorized_count, else: length(flat_skills)
  end

  defp render_education_summary(content) do
    education = Map.get(content, "education", [])
    case length(education) do
      0 -> "No education added yet"
      1 -> "1 degree/certification"
      count -> "#{count} degrees/certifications"
    end
  end

  defp render_projects_summary(content) do
    projects = Map.get(content, "projects", [])
    case length(projects) do
      0 -> "No projects added yet"
      1 -> "1 project"
      count -> "#{count} projects"
    end
  end

  # 🔥 OTHER LAYOUT RENDERERS
  defp render_gallery_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(@customization_css) %>
    <div class="min-h-screen">
      <header class="h-screen flex items-center justify-center relative overflow-hidden">
        <div class="relative text-center z-10">
          <h1 class="text-6xl lg:text-8xl font-bold mb-6 portfolio-primary">
            <%= @portfolio.title %>
          </h1>
          <p class="text-2xl lg:text-3xl portfolio-secondary opacity-90 max-w-4xl mx-auto leading-relaxed">
            <%= @portfolio.description %>
          </p>
        </div>
      </header>

      <main class="px-6 py-16">
        <div class="max-w-7xl mx-auto columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
          <%= for section <- @sections do %>
            <section class="break-inside-avoid portfolio-card p-8 mb-8">
              <h2 class="text-2xl font-bold mb-6 portfolio-primary">
                <%= section.title %>
              </h2>
              <div class="portfolio-secondary">
                <%= render_section_content_safe(section) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  defp render_terminal_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(@customization_css) %>
    <div class="min-h-screen">
      <header class="border-b portfolio-header">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center space-x-4">
            <div class="flex space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <span class="portfolio-secondary">~/portfolio/<%= String.downcase(String.replace(@portfolio.title, " ", "_")) %></span>
          </div>
        </div>
      </header>

      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="terminal-window mb-6">
          <div class="portfolio-header border-b px-4 py-2">
            <span class="portfolio-primary">$</span>
            <span class="portfolio-accent">cat</span>
            <span class="portfolio-primary">README.md</span>
          </div>
          <div class="portfolio-card p-6">
            <h1 class="text-2xl font-bold portfolio-primary mb-4"># <%= @portfolio.title %></h1>
            <p class="portfolio-secondary mb-4"><%= @portfolio.description %></p>
          </div>
        </div>

        <%= for section <- @sections do %>
          <div class="terminal-window mb-6">
            <div class="portfolio-header border-b px-4 py-2">
              <span class="portfolio-primary">$</span>
              <span class="portfolio-accent">cat</span>
              <span class="portfolio-primary"><%= String.downcase(String.replace(section.title, " ", "_")) %>.md</span>
            </div>
            <div class="portfolio-card p-6">
              <h2 class="portfolio-primary font-bold mb-4"># <%= section.title %></h2>
              <div class="portfolio-secondary">
                <%= render_section_content_safe(section) %>
              </div>
            </div>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  # Other layout renderers (fallback to dashboard)
  defp render_case_study_layout(assigns), do: render_dashboard_layout(assigns)
  defp render_minimal_layout(assigns), do: render_dashboard_layout(assigns)
  defp render_academic_layout(assigns), do: render_dashboard_layout(assigns)

  # HELPER FUNCTIONS
  defp normalize_theme(theme) when is_binary(theme) do
    case theme do
      "executive" -> :executive
      "developer" -> :developer
      "designer" -> :designer
      "consultant" -> :consultant
      "academic" -> :academic
      "creative" -> :creative
      "corporate" -> :corporate
      "minimalist" -> :minimalist
      _ -> :executive
    end
  end
  defp normalize_theme(theme) when is_atom(theme), do: theme
  defp normalize_theme(_), do: :executive

  defp track_portfolio_visit(portfolio, socket) do
    try do
      ip_address = get_connect_info(socket, :peer_data) |> Map.get(:address, {127, 0, 0, 1}) |> :inet.ntoa() |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      Portfolios.create_visit(%{
        portfolio_id: portfolio.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
      })
    rescue
      _ -> :ok
    end
  end

  defp track_share_visit(portfolio, share, socket) do
    try do
      ip_address = get_connect_info(socket, :peer_data) |> Map.get(:address, {127, 0, 0, 1}) |> :inet.ntoa() |> to_string()
      user_agent = get_connect_info(socket, :user_agent) || ""

      Portfolios.create_visit(%{
        portfolio_id: portfolio.id,
        share_id: share.id,
        ip_address: ip_address,
        user_agent: user_agent,
        referrer: get_connect_params(socket)["ref"]
      })
    rescue
      _ -> :ok
    end
  end

  defp get_intro_video(portfolio) do
    # Find video intro section
    intro_video_section = Enum.find(portfolio.sections || [], fn section ->
      section.title == "Video Introduction" ||
      (section.content && Map.get(section.content, "video_type") == "introduction")
    end)

    if intro_video_section do
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
  end

  defp get_share_id(socket) do
    case socket.assigns.share do
      %{"id" => id} -> id
      _ -> nil
    end
  end

  defp get_media_url(media) do
    try do
      Portfolios.get_media_url(media)
    rescue
      _ -> "/images/placeholder.jpg"
    end
  end

    # Portfolio layout class helper
  defp get_portfolio_layout_class(template_theme) do
    case template_theme do
      :creative -> "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8 auto-rows-auto"
      :corporate -> "grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-8"
      :minimalist -> "grid grid-cols-1 lg:grid-cols-2 gap-12 max-w-5xl mx-auto"
      _ -> "grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-8"
    end
  end

  # Card theme class helper
  defp get_card_theme_class(template_theme) do
    case template_theme do
      :creative -> "bg-white/10 backdrop-blur-xl rounded-3xl border border-white/20 shadow-2xl"
      :corporate -> "bg-white rounded-xl shadow-lg border border-gray-200"
      :minimalist -> "bg-white rounded-2xl shadow-sm border border-gray-100"
      _ -> "bg-white rounded-xl shadow-lg border border-gray-200"
    end
  end

  # Icon background class helper
  defp get_icon_bg_class(template_theme, section_type) do
    base_color = case section_type do
      :intro -> "from-blue-500 to-blue-600"
      :experience -> "from-green-500 to-green-600"
      :skills -> "from-purple-500 to-purple-600"
      :education -> "from-orange-500 to-orange-600"
      :projects -> "from-indigo-500 to-indigo-600"
      :contact -> "from-pink-500 to-pink-600"
      _ -> "from-gray-500 to-gray-600"
    end

    case template_theme do
      :creative -> "bg-gradient-to-br #{base_color}"
      :corporate -> "bg-gradient-to-br #{base_color}"
      :minimalist -> "bg-gray-900"
      _ -> "bg-gradient-to-br #{base_color}"
    end
  end

  # Title class helper
  defp get_title_class(template_theme) do
    case template_theme do
      :creative -> "text-white"
      :corporate -> "text-gray-900"
      :minimalist -> "text-gray-900"
      _ -> "text-gray-900"
    end
  end

  # Badge class helper
  defp get_badge_class(template_theme, section_type) do
    case template_theme do
      :creative -> "bg-white/20 text-white border border-white/30"
      :corporate -> "bg-blue-100 text-blue-600 border border-blue-200"
      :minimalist -> "bg-gray-100 text-gray-600 border border-gray-200"
      _ -> "bg-blue-100 text-blue-600 border border-blue-200"
    end
  end

  # Section icon renderer
  defp render_section_icon(section_type, template_theme) do
    icon_color = case template_theme do
      :creative -> "text-white"
      :corporate -> "text-white"
      :minimalist -> "text-white"
      _ -> "text-white"
    end

    case section_type do
      :intro ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """)

      :experience ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
        """)

      :skills ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """)

      :education ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5m0 0l-9 5-9-5m9-5l-9 5"/>
        </svg>
        """)

      :projects ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """)

      :contact ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="w-6 h-6 #{icon_color}" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zm10 0a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
        </svg>
        """)
    end
  end

  # Section content renderer for templates
  defp render_section_content_for_template(section, template_theme) do
    try do
      # Use the imported helper function
      summary = FrestylWeb.PortfolioLive.Edit.HelperFunctions.get_section_content_summary(section)

      # Create a component that returns the rendered content
      render_section_template_content(%{
        section: section,
        summary: summary,
        template_theme: template_theme
      })
    rescue
      _ ->
        render_loading_content()
    end
  end

  # Separate component function for the main content
  defp render_section_template_content(assigns) do
    ~H"""
    <div class="space-y-4">
      <p class={[
        "leading-relaxed",
        case @template_theme do
          :creative -> "text-white/90"
          :corporate -> "text-gray-600"
          :minimalist -> "text-gray-600"
          _ -> "text-gray-600"
        end
      ]}>
        <%= @summary %>
      </p>

      <%= if length(Map.get(@section, :media_files, [])) > 0 do %>
        <div class="flex items-center space-x-2 text-sm">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
          </svg>
          <span class={case @template_theme do
            :creative -> "text-white/70"
            :corporate -> "text-gray-500"
            :minimalist -> "text-gray-500"
            _ -> "text-gray-500"
          end}>
            <%= length(@section.media_files) %> media file<%= if length(@section.media_files) != 1, do: "s" %>
          </span>
        </div>
      <% end %>
    </div>
    """
  end

  # Separate component function for the loading state
  defp render_loading_content(assigns \\ %{}) do
    ~H"""
    <div class="text-center py-4">
      <p class="text-gray-500 italic">Content loading...</p>
    </div>
    """
  end

  defp format_section_type(section_type) do
    FrestylWeb.PortfolioLive.Edit.HelperFunctions.format_section_type(section_type)
  end

  # Calculation helper functions for portfolio metrics
  defp calculate_projects_count(sections) do
    sections
    |> Enum.map(fn section ->
      case section.section_type do
        :projects ->
          projects = get_in(section, [:content, "projects"]) || []
          length(projects)
        :featured_project -> 1
        :case_study -> 1
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp calculate_skills_count(sections) do
    sections
    |> Enum.map(fn section ->
      case section.section_type do
        :skills ->
          content = section.content || %{}
          skills = Map.get(content, "skills", [])
          skill_categories = Map.get(content, "skill_categories", %{})

          categorized_count = skill_categories
          |> Map.values()
          |> List.flatten()
          |> length()

          if categorized_count > 0, do: categorized_count, else: length(skills)
        _ -> 0
      end
    end)
    |> Enum.sum()
  end

  defp calculate_experience_years(sections) do
    sections
    |> Enum.filter(fn section -> section.section_type == :experience end)
    |> Enum.map(fn section ->
      content = section.content || %{}
      jobs = Map.get(content, "jobs", [])
      calculate_total_experience_from_jobs(jobs)
    end)
    |> Enum.sum()
    |> max(0)
    |> Float.round(1)
  end

  defp calculate_total_experience_from_jobs(jobs) do
    jobs
    |> Enum.map(&calculate_job_duration_years/1)
    |> Enum.sum()
  end

  defp calculate_job_duration_years(job) do
    start_date = Map.get(job, "start_date", "")
    end_date = Map.get(job, "end_date", "")
    current = Map.get(job, "current", false)

    cond do
      current ->
        # Calculate from start date to now
        parse_date_and_calculate_years(start_date, Date.utc_today())
      start_date != "" and end_date != "" ->
        # Calculate between start and end dates
        with {:ok, start_parsed} <- parse_resume_date(start_date),
            {:ok, end_parsed} <- parse_resume_date(end_date) do
          Date.diff(end_parsed, start_parsed) / 365.25
        else
          _ -> 1.0 # Default to 1 year if parsing fails
        end
      true ->
        1.0 # Default assumption
    end
  end

  defp parse_date_and_calculate_years(start_date_str, end_date) do
    case parse_resume_date(start_date_str) do
      {:ok, start_date} ->
        Date.diff(end_date, start_date) / 365.25
      _ ->
        1.0
    end
  end

  # Date parsing functions
  defp parse_resume_date(date_str) when is_binary(date_str) and date_str != "" do
    # Clean the date string
    cleaned = String.trim(date_str)

    cond do
      # Just year (e.g., "2020")
      String.match?(cleaned, ~r/^\d{4}$/) ->
        year = String.to_integer(cleaned)
        {:ok, Date.new!(year, 1, 1)}

      # Month Year (e.g., "January 2020", "Jan 2020")
      String.match?(cleaned, ~r/^\w+ \d{4}$/) ->
        [month_str, year_str] = String.split(cleaned, " ")
        year = String.to_integer(year_str)
        month = parse_month_name(month_str)
        {:ok, Date.new!(year, month, 1)}

      # MM/YYYY format
      String.match?(cleaned, ~r/^\d{1,2}\/\d{4}$/) ->
        [month_str, year_str] = String.split(cleaned, "/")
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)
        {:ok, Date.new!(year, month, 1)}

      # MM-YYYY format
      String.match?(cleaned, ~r/^\d{1,2}-\d{4}$/) ->
        [month_str, year_str] = String.split(cleaned, "-")
        year = String.to_integer(year_str)
        month = String.to_integer(month_str)
        {:ok, Date.new!(year, month, 1)}

      # Full date formats (YYYY-MM-DD, MM/DD/YYYY, etc.)
      String.match?(cleaned, ~r/^\d{4}-\d{2}-\d{2}$/) ->
        Date.from_iso8601(cleaned)

      # Handle "Present" or similar
      String.downcase(cleaned) in ["present", "current", "now"] ->
        {:ok, Date.utc_today()}

      true ->
        {:error, :invalid_format}
    end
  rescue
    _ -> {:error, :parse_error}
  end

  defp parse_resume_date(""), do: {:error, :empty_string}
  defp parse_resume_date(nil), do: {:error, :nil_value}
  defp parse_resume_date(_), do: {:error, :invalid_input}

  defp parse_month_name(month_str) do
    case String.downcase(month_str) do
      m when m in ["jan", "january"] -> 1
      m when m in ["feb", "february"] -> 2
      m when m in ["mar", "march"] -> 3
      m when m in ["apr", "april"] -> 4
      m when m in ["may"] -> 5
      m when m in ["jun", "june"] -> 6
      m when m in ["jul", "july"] -> 7
      m when m in ["aug", "august"] -> 8
      m when m in ["sep", "september"] -> 9
      m when m in ["oct", "october"] -> 10
      m when m in ["nov", "november"] -> 11
      m when m in ["dec", "december"] -> 12
      _ -> 1 # Default to January if can't parse
    end
  end

  # Fix the calculate_job_duration_months function that was causing errors
  defp calculate_job_duration_months(start_date, end_date, current) do
    with {:ok, start_parsed} <- parse_resume_date(start_date) do
      end_parsed = if current do
        {:ok, Date.utc_today()}
      else
        parse_resume_date(end_date)
      end

      case end_parsed do
        {:ok, end_date_parsed} ->
          Date.diff(end_date_parsed, start_parsed) / 30 |> round() |> max(0)
        _ ->
          0
      end
    else
      _ -> 0
    end
  end

  # Helper for safe content access
  defp safe_get_content(section, key, default \\ %{}) do
    case section do
      %{content: content} when is_map(content) -> Map.get(content, key, default)
      _ -> default
    end
  end

  # Alternative simpler calculation functions if the above are too complex
  defp calculate_projects_count_simple(sections) do
    sections
    |> Enum.count(fn section ->
      section.section_type in [:projects, :featured_project, :case_study]
    end)
  end

  defp calculate_skills_count_simple(sections) do
    sections
    |> Enum.filter(fn section -> section.section_type == :skills end)
    |> Enum.map(fn section ->
      content = section.content || %{}
      skills = Map.get(content, "skills", [])
      length(skills)
    end)
    |> Enum.sum()
    |> max(1) # Show at least 1 if there's a skills section
  end

  defp calculate_experience_years_simple(sections) do
    experience_sections = Enum.filter(sections, fn section ->
      section.section_type == :experience
    end)

    case length(experience_sections) do
      0 -> 0
      _ ->
        # Simple estimation: assume 2 years per job entry
        total_jobs = experience_sections
        |> Enum.map(fn section ->
          content = section.content || %{}
          jobs = Map.get(content, "jobs", [])
          length(jobs)
        end)
        |> Enum.sum()

        max(total_jobs * 2, 1) # At least 1 year if there are jobs
    end
  end
end
