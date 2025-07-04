# lib/frestyl_web/live/portfolio_live/view.ex - FIXED VERSION

defmodule FrestylWeb.PortfolioLive.View do
  use FrestylWeb, :live_view
  alias Frestyl.Portfolios
  alias Frestyl.Portfolios.PortfolioTemplates
  alias Frestyl.Repo
  import Ecto.Query
  alias FrestylWeb.PortfolioLive.Components.EnhancedSkillsDisplay

  def mount(%{"slug" => slug}, _session, socket) do
    case Portfolios.get_portfolio_by_slug_with_sections_simple(slug) do
      {:error, :not_found} ->
        {:ok, socket
        |> put_flash(:error, "Portfolio not found")
        |> redirect(to: "/")}

      {:ok, portfolio} ->
        # 🔥 CRITICAL: Make sure sections are actually loaded
        IO.puts("🔥 PORTFOLIO MOUNT DEBUG:")
        IO.puts("🔥 Portfolio title: #{portfolio.title}")
        IO.puts("🔥 Raw sections: #{inspect(portfolio.sections)}")
        IO.puts("🔥 Sections count: #{length(portfolio.sections || [])}")

        # Ensure user is loaded
        portfolio = if Ecto.assoc_loaded?(portfolio.user) do
          portfolio
        else
          Repo.preload(portfolio, :user, force: true)
        end

        # 🔥 CRITICAL FIX: Get sections properly
        all_sections = portfolio.sections || []

        # Debug sections before filtering
        IO.puts("🔥 All sections before filtering:")
        Enum.each(all_sections, fn section ->
          IO.puts("  - #{section.title} (#{section.section_type}, visible: #{section.visible})")
        end)

        # 🔥 CRITICAL: Use the corrected function name
        {intro_video, filtered_sections} = separate_video_intro_and_sections(all_sections)

        # Debug after filtering
        IO.puts("🔥 After filtering:")
        IO.puts("🔥 Has intro video: #{if intro_video, do: "YES", else: "NO"}")
        IO.puts("🔥 Filtered sections count: #{length(filtered_sections)}")
        IO.puts("🔥 Filtered sections:")
        Enum.each(filtered_sections, fn section ->
          IO.puts("  - #{section.title} (#{section.section_type})")
        end)

        # Process customization and template data
        {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

        # 🔥 FIX: Prepare complete data structure for hero renderers
        social_links = extract_social_links(portfolio)
        contact_info = extract_contact_info(filtered_sections)
        portfolio_metrics = calculate_portfolio_metrics(portfolio)

        socket =
          socket
          |> assign(:page_title, portfolio.title)
          |> assign(:portfolio, portfolio)
          |> assign(:owner, portfolio.user)
          |> assign(:sections, filtered_sections)               # 🔥 CRITICAL
          |> assign(:all_sections, all_sections)                # 🔥 CRITICAL
          |> assign(:social_links, social_links)
          |> assign(:contact_info, contact_info)
          |> assign(:customization, portfolio.customization || %{})
          |> assign(:portfolio_metrics, portfolio_metrics)
          |> assign(:template_config, template_config)
          |> assign(:template_theme, normalize_theme(portfolio.theme))
          |> assign(:template_layout, template_layout)
          |> assign(:customization_css, customization_css)
          # 🔥 CRITICAL FIX: Video data for hero renderers
          |> assign(:intro_video, intro_video)
          |> assign(:intro_video_section, intro_video)          # 🔥 CRITICAL
          |> assign(:has_intro_video, intro_video != nil)
          |> assign(:video_url, get_video_url_safe(intro_video))
          |> assign(:video_content, get_video_content_safe(intro_video))
          |> assign(:show_video_modal, false)
          |> assign(:show_mobile_nav, false)

        IO.puts("🔥 FINAL SOCKET ASSIGNS:")
        IO.puts("🔥 sections count: #{length(socket.assigns.sections)}")
        IO.puts("🔥 has_intro_video: #{socket.assigns.has_intro_video}")

        {:ok, socket}
    end
  end

  # Handle share token view (collaboration links)
  defp mount_public_view(portfolio, socket) do
    # Extract video intro and filter sections
    sections = Map.get(portfolio, :portfolio_sections, [])
    {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(sections)

    # Process customization and template data
    {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

    # Prepare data structure
    social_links = extract_social_links(portfolio)
    contact_info = extract_contact_info(filtered_sections)
    portfolio_metrics = calculate_portfolio_metrics(portfolio)

    socket
    |> assign(:page_title, portfolio.title)
    |> assign(:portfolio, portfolio)
    |> assign(:owner, portfolio.user)
    |> assign(:sections, filtered_sections)
    |> assign(:all_sections, sections)
    |> assign(:social_links, social_links)
    |> assign(:contact_info, contact_info)
    |> assign(:customization, portfolio.customization || %{})
    |> assign(:portfolio_metrics, portfolio_metrics)
    |> assign(:template_config, template_config)
    |> assign(:template_theme, normalize_theme(portfolio.theme))
    |> assign(:template_layout, template_layout)
    |> assign(:customization_css, customization_css)
    |> assign(:intro_video, intro_video)
    |> assign(:intro_video_section, intro_video)
    |> assign(:has_intro_video, intro_video != nil)
    |> assign(:video_url, get_video_url_safe(intro_video))
    |> assign(:video_content, get_video_content_safe(intro_video))
    |> assign(:show_video_modal, false)
    |> assign(:show_mobile_nav, false)
    |> assign(:view_type, :public)
  end

  defp mount_share_view(portfolio, socket) do
    # Similar to public view but with sharing-specific settings
    sections = portfolio.sections || []
    {intro_video, filtered_sections} = extract_intro_video_and_filter_sections(sections)

    # Process customization and template data
    {template_config, customization_css, template_layout} = process_portfolio_customization_fixed(portfolio)

    socket
    |> assign(:page_title, "#{portfolio.title} - Shared Portfolio")
    |> assign(:portfolio, portfolio)
    |> assign(:owner, portfolio.user)
    |> assign(:sections, filtered_sections)
    |> assign(:all_sections, sections)
    |> assign(:customization, portfolio.customization || %{})
    |> assign(:template_config, template_config)
    |> assign(:template_theme, normalize_theme(portfolio.theme))
    |> assign(:template_layout, template_layout)
    |> assign(:customization_css, customization_css)
    |> assign(:intro_video, intro_video)
    |> assign(:intro_video_section, intro_video)
    |> assign(:has_intro_video, intro_video != nil)
    |> assign(:video_url, get_video_url_safe(intro_video))
    |> assign(:video_content, get_video_content_safe(intro_video))
    |> assign(:show_video_modal, false)
    |> assign(:show_mobile_nav, false)
    |> assign(:view_type, :share)
    |> assign(:is_shared_view, true)
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

    defp separate_video_intro_and_sections(sections) do
    # Filter out video intro sections for separate handling
    {video_sections, other_sections} = Enum.split_with(sections, fn section ->
      is_video_intro_section?(section)
    end)

    # Only show visible sections in main display
    visible_other_sections = Enum.filter(other_sections, fn section ->
      Map.get(section, :visible, true)
    end)

    # Get the first video intro section (should only be one)
    intro_video = case video_sections do
      [video_section | _] ->
        IO.puts("🔥 FOUND VIDEO INTRO SECTION: #{video_section.title}")
        IO.puts("🔥 Video intro visible: #{video_section.visible}")
        content = video_section.content || %{}
        video_url = Map.get(content, "video_url")
        IO.puts("🔥 VIDEO URL: #{video_url}")

        # Only return if visible
        if Map.get(video_section, :visible, true) do
          # 🔥 ENHANCED: Return a consistent structure that matches what we expect
          %{
            id: video_section.id,
            title: Map.get(content, "title", "Personal Introduction"),
            description: Map.get(content, "description", ""),
            video_url: video_url,
            filename: Map.get(content, "video_filename"),
            duration: Map.get(content, "duration", 0),
            created_at: Map.get(content, "created_at"),
            section_id: video_section.id,
            section: video_section,  # Include full section for compatibility
            content: content,        # 🔥 FIX: Include content at the top level
            visible: video_section.visible
          }
        else
          IO.puts("🔥 Video intro section exists but is not visible")
          nil
        end
      [] ->
        IO.puts("🔥 NO VIDEO INTRO SECTION FOUND")
        nil
    end

    IO.puts("🔥 INTRO VIDEO RESULT: #{if intro_video, do: "FOUND & VISIBLE", else: "NOT FOUND OR HIDDEN"}")
    IO.puts("🔥 VISIBLE OTHER SECTIONS COUNT: #{length(visible_other_sections)}")

    {intro_video, visible_other_sections}
  end

  # 🔥 FIX: Improved video intro section detection
  defp is_video_intro_section?(section) do
    result = case section do
      # Check section type and content
      %{section_type: :media_showcase, content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      %{section_type: "media_showcase", content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      # Check by title
      %{title: "Video Introduction"} ->
        true

      %{title: title} when is_binary(title) ->
        title_lower = String.downcase(title)
        String.contains?(title_lower, "video") and
        (String.contains?(title_lower, "intro") or String.contains?(title_lower, "introduction"))

      # Check if content has video_type
      %{content: content} when is_map(content) ->
        Map.get(content, "video_type") == "introduction"

      _ ->
        false
    end

    if result do
      IO.puts("🔥 SECTION IS VIDEO INTRO: #{section.title} (#{section.section_type})")
      IO.puts("🔥 CONTENT KEYS: #{inspect(Map.keys(section.content || %{}))}")
    end

    result
  end

  # 🔥 FIX: Safe video content extraction
  defp get_video_content_safe(intro_video_section) when intro_video_section == nil do
    %{
      "video_url" => "",
      "title" => "Personal Introduction",
      "description" => "",
      "duration" => 0
    }
  end

  defp get_video_content_safe(intro_video_section) do
    case intro_video_section do
      %{section: %{content: content}} when is_map(content) -> content
      %{content: content} when is_map(content) -> content
      %{"video_url" => _} = content when is_map(content) -> content
      video_data when is_map(video_data) ->
        %{
          "video_url" => Map.get(video_data, :video_url, ""),
          "title" => Map.get(video_data, :title, "Personal Introduction"),
          "description" => Map.get(video_data, :description, ""),
          "duration" => Map.get(video_data, :duration, 0)
        }
      _ ->
        %{
          "video_url" => "",
          "title" => "Personal Introduction",
          "description" => "",
          "duration" => 0
        }
    end
  end

  # 🔥 FIX: Safe video URL extraction
  defp get_video_url_safe(intro_video_section) when intro_video_section == nil, do: ""

  defp get_video_url_safe(intro_video_section) do
    case intro_video_section do
      %{video_url: url} when is_binary(url) -> url
      %{"video_url" => url} when is_binary(url) -> url
      %{content: %{"video_url" => url}} when is_binary(url) -> url
      %{section: %{content: %{"video_url" => url}}} when is_binary(url) -> url
      _ -> ""
    end
  end

  @impl true
  def render(assigns) do
    IO.puts("🔥 RENDER CALLED")
    IO.puts("🔥 Sections in render: #{length(assigns.sections)}")
    IO.puts("🔥 Has intro video: #{assigns.has_intro_video}")
    IO.puts("🔥 Template layout: #{assigns.template_layout}")

    # 🔥 FIX: Ensure template_layout is properly determined
    theme = assigns.portfolio.theme || "executive"
    customization = assigns.portfolio.customization || %{}

    # Get template layout from theme and customization
    template_layout = determine_template_layout(theme, customization)

    # 🔥 NEW: Handle video intro detection and display
    intro_video_section = assigns[:intro_video_section] || assigns[:intro_video]
    has_intro_video = intro_video_section != nil

    IO.puts("🔥 RENDERING PORTFOLIO VIEW")
    IO.puts("🔥 Theme: #{theme}")
    IO.puts("🔥 Template Layout: #{template_layout}")
    IO.puts("🔥 Has intro video: #{has_intro_video}")
    IO.puts("🔥 Display sections count: #{length(assigns.sections)}")

    # Update assigns with proper layout and video status
    assigns = assigns
    |> assign(:template_layout, template_layout)
    |> assign(:intro_video_section, intro_video_section)
    |> assign(:has_intro_video, has_intro_video)

    # 🔥 CRITICAL: Always render sections regardless of video intro
    case {template_layout, has_intro_video} do
      # Video intro takes precedence - use enhanced layouts
      {_, true} ->
        IO.puts("🔥 Rendering video enhanced layout")
        render_video_enhanced_layout(assigns)

      # Standard layouts without video
      {"dashboard", false} ->
        IO.puts("🔥 Rendering dashboard layout")
        render_dashboard_layout(assigns)

      {"gallery", false} ->
        IO.puts("🔥 Rendering gallery layout")
        render_gallery_layout(assigns)

      {"terminal", false} ->
        IO.puts("🔥 Rendering terminal layout")
        render_terminal_layout(assigns)

      {"case_study", false} ->
        IO.puts("🔥 Rendering case study layout")
        render_case_study_layout(assigns)

      {"minimal", false} ->
        IO.puts("🔥 Rendering minimal layout")
        render_minimal_layout(assigns)

      {"academic", false} ->
        IO.puts("🔥 Rendering academic layout")
        render_academic_layout(assigns)

      # 🔥 CRITICAL: Fallback that ALWAYS renders sections
      _ ->
        IO.puts("🔥 FALLBACK: Rendering basic layout with sections")
        render_basic_layout_with_sections(assigns)
    end
  end

  defp render_basic_layout_with_sections(assigns) do
    assigns = assigns |> assign(:css_content, Map.get(assigns, :customization_css, ""))

    ~H"""
    <%= Phoenix.HTML.raw(@css_content) %>

    <div class="min-h-screen portfolio-bg">
      <!-- Header -->
      <header class="bg-blue-600 text-white py-16">
        <div class="max-w-6xl mx-auto px-4 text-center">
          <h1 class="text-4xl font-bold mb-4"><%= @portfolio.title %></h1>
          <%= if @portfolio.description do %>
            <p class="text-xl text-blue-100"><%= @portfolio.description %></p>
          <% end %>
        </div>
      </header>

      <!-- 🔥 CRITICAL: Main Content Sections - GUARANTEED TO RENDER -->
      <main class="max-w-6xl mx-auto px-4 py-12">
        <div class="bg-yellow-100 border border-yellow-300 rounded p-4 mb-8">
          <p><strong>Debug Info:</strong></p>
          <p>Sections count: <%= length(@sections) %></p>
          <p>Has intro video: <%= @has_intro_video %></p>
          <p>Template layout: <%= @template_layout %></p>
        </div>

        <%= if length(@sections) > 0 do %>
          <div class="space-y-8">
            <%= for section <- @sections do %>
              <section class="bg-white rounded-lg shadow p-8 border-l-4 border-blue-500">
                <h2 class="text-2xl font-bold mb-4 text-gray-900"><%= section.title %></h2>
                <p class="text-gray-600 mb-4">Section Type: <%= section.section_type %></p>

                <!-- Render section content -->
                <div class="prose max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-16">
            <div class="bg-gray-100 rounded-xl p-8">
              <h3 class="text-lg font-medium text-gray-900 mb-2">No Sections Found</h3>
              <p class="text-gray-600">This portfolio doesn't have any sections yet.</p>
            </div>
          </div>
        <% end %>
      </main>
    </div>
    """
  end

  defp render_theme_with_video_support(assigns, theme) do
    # Get the customization CSS
    css_content = Map.get(assigns, :customization_css, "")

    assigns = assign(assigns, :css_content, css_content)

    ~H"""
    <%= Phoenix.HTML.raw(@css_content) %>

    <div class="min-h-screen portfolio-bg">
      <!-- Use existing hero renderer (which handles video) -->
      <%= render_theme_specific_hero(assigns) %>

      <!-- Portfolio Content Sections -->
      <div id="portfolio-sections" class="relative">
        <%= render_sections_grid(assigns) %>
      </div>

      <!-- Video Modal (if needed) -->
      <%= if @show_video_modal && @intro_video do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm"
            phx-click="hide_video_modal">
          <div class="relative max-w-6xl w-full mx-4 max-h-[90vh]" phx-click-away="hide_video_modal">
            <button phx-click="hide_video_modal"
                    class="absolute -top-12 right-0 text-white hover:text-gray-300 z-10">
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
            <video controls autoplay class="w-full h-auto rounded-xl shadow-2xl">
              <source src={get_video_url_from_intro(@intro_video)} type="video/mp4">
              <source src={get_video_url_from_intro(@intro_video)} type="video/webm">
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_theme_specific_hero(assigns) do
    theme = assigns.portfolio.theme || "executive"

    # Pass video data to hero renderers
    case theme do
      "executive" -> render_executive_hero(assigns)
      "developer" -> render_developer_hero(assigns)
      "designer" -> render_designer_hero(assigns)
      "consultant" -> render_consultant_hero(assigns)
      "academic" -> render_academic_hero(assigns)
      "minimalist" -> render_minimalist_hero(assigns)
      "creative" -> render_creative_hero(assigns)
      _ -> render_executive_hero(assigns)  # fallback
    end
  end

  # 🔥 HELPER: Extract video data from section
  defp extract_video_data_from_section(video_section) do
    content = video_section.content || %{}

    %{
      id: video_section.id,
      title: Map.get(content, "title", "Personal Introduction"),
      description: Map.get(content, "description", ""),
      video_url: Map.get(content, "video_url"),
      filename: Map.get(content, "video_filename"),
      duration: Map.get(content, "duration", 0),
      section_id: video_section.id,
      content: content
    }
  end

  # 🔥 HELPER: Check if video has valid URL
  defp has_valid_video_url?(intro_video) do
    video_url = get_video_url_from_intro(intro_video)
    video_url != nil && video_url != ""
  end

  # 🔥 HELPER: Get video URL from intro data
  defp get_video_url_from_intro(intro_video) do
    cond do
      Map.has_key?(intro_video, :video_url) -> Map.get(intro_video, :video_url)
      Map.has_key?(intro_video, "video_url") -> Map.get(intro_video, "video_url")
      Map.has_key?(intro_video, :content) -> get_in(intro_video, [:content, "video_url"])
      true -> nil
    end
  end

  defp render_video_enhanced_layout(assigns) do
    # Move all variable assignments to assigns
    assigns = assigns
    |> assign(:css_content, Map.get(assigns, :customization_css, ""))

    ~H"""
    <%= Phoenix.HTML.raw(@css_content) %>

    <div class="min-h-screen portfolio-bg">
      <!-- 🔥 VIDEO INTRO HERO SECTION -->
      <%= render_video_intro_hero(assigns) %>

      <!-- 🔥 PORTFOLIO CONTENT SECTIONS -->
      <div id="portfolio-sections" class="relative">
        <%= render_sections_grid(assigns) %>
      </div>

      <!-- Video Modal -->
      <%= if @show_video_modal && @intro_video do %>
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
              <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/mp4">
              <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/webm">
              Your browser does not support the video tag.
            </video>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_sections_grid(assigns) do
    # Filter out the video intro section since it's displayed in the hero
    display_sections = Enum.reject(assigns.sections, fn section ->
      is_video_intro_section?(section)
    end)

    assigns = assign(assigns, :display_sections, display_sections)

    ~H"""
    <div class="py-16 lg:py-24">
      <div class="container mx-auto px-6 lg:px-8 max-w-7xl">

        <!-- Sections Grid -->
        <div class="grid gap-6 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3">
          <%= for section <- @display_sections do %>
            <%= if section.visible do %>
              <div id={"section-#{section.id}"} class="portfolio-card shadow-lg rounded-xl border p-6 bg-white">
                <h2 class="text-xl font-bold portfolio-primary mb-4">
                  <%= section.title %>
                </h2>
                <div class="portfolio-secondary">
                  <%= render_section_content_safe(section) %>
                </div>
              </div>
            <% end %>
          <% end %>
        </div>

        <!-- Empty State -->
        <%= if length(@display_sections) == 0 do %>
          <div class="text-center py-20">
            <div class="w-24 h-24 bg-gray-100 rounded-2xl flex items-center justify-center mx-auto mb-6">
              <svg class="w-12 h-12 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
              </svg>
            </div>
            <h3 class="text-2xl font-bold text-gray-900 mb-3">Portfolio in Progress</h3>
            <p class="text-gray-600 max-w-md mx-auto">
              This portfolio is being built. Check back soon to see the amazing work!
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end



  defp render_video_intro_hero(assigns) do
    if assigns.intro_video == nil do
      # Render theme-specific header even without video
      render_theme_specific_header(assigns)
    else
      # Get video data safely
      video_content = get_video_content_safe(assigns.intro_video)
      # 🔥 FIX: Use single parameter function call
      video_url = get_video_url_safe(assigns.intro_video)

      # Get theme and create theme-specific styling
      theme = assigns.portfolio.theme || "executive"
      customization = assigns.customization || %{}

      # Generate theme-specific classes and content
      theme_config = get_theme_hero_config(theme, customization)

      assigns = assigns
      |> assign(:video_content, video_content)
      |> assign(:video_url, video_url)
      |> assign(:theme, theme)
      |> assign(:theme_config, theme_config)

      case theme do
        "executive" -> render_executive_hero(assigns)
        "developer" -> render_developer_hero(assigns)
        "designer" -> render_designer_hero(assigns)
        "minimalist" -> render_minimalist_hero(assigns)
        "consultant" -> render_consultant_hero(assigns)
        "academic" -> render_academic_hero(assigns)
        "creative" -> render_designer_hero(assigns)  # Use designer as fallback
        _ -> render_executive_hero(assigns)  # fallback
      end
    end
  end

  # ADD THESE MISSING HELPER FUNCTIONS TO view.ex

  # 🔥 MISSING: get_contact_section function
  defp get_contact_section(sections) do
    Enum.find(sections, fn section ->
      section.section_type == :contact || section.section_type == "contact"
    end)
  end

  defp get_video_content_safe(intro_video) do
    case intro_video do
      %{section: %{content: content}} -> content
      %{content: content} -> content
      %{"video_url" => _} = content -> content
      video_data ->
        %{
          "video_url" => Map.get(video_data, :video_url, ""),
          "title" => Map.get(video_data, :title, "Personal Introduction"),
          "description" => Map.get(video_data, :description, ""),
          "duration" => Map.get(video_data, :duration, 0)
        }
    end
  end

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

  defp extract_video_content(intro_video) do
    case intro_video do
      nil -> %{}
      %{content: content} when is_map(content) -> content
      video_data -> video_data
    end
  end

  defp get_theme_hero_config(theme, customization) do
    base_config = %{
      "primary_color" => get_in(customization, ["primary_color"]) || "#3b82f6",
      "secondary_color" => get_in(customization, ["secondary_color"]) || "#64748b",
      "accent_color" => get_in(customization, ["accent_color"]) || "#f59e0b"
    }

    # 🔥 ENHANCE: Add video-specific configuration
    video_config = %{
      "video_enabled" => true,
      "video_position" => "hero",
      "video_style" => get_video_style_for_theme(theme),
      "hero_expanded" => true  # Signal to hero renderers that video is present
    }

    theme_specific = case theme do
      "executive" -> %{
        "header_bg" => "linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%)",
        "text_color" => "#1e293b",
        "video_container" => "bg-white/10 backdrop-blur-xl rounded-3xl border border-white/20"
      }
      "developer" -> %{
        "header_bg" => "linear-gradient(135deg, #1f2937 0%, #111827 100%)",
        "text_color" => "#f9fafb",
        "video_container" => "bg-green-500/10 backdrop-blur-xl rounded-2xl border border-green-500/20"
      }
      "designer" -> %{
        "header_bg" => "linear-gradient(135deg, #a855f7 0%, #ec4899 100%)",
        "text_color" => "#ffffff",
        "video_container" => "bg-white/15 backdrop-blur-xl rounded-3xl border border-pink-300/30"
      }
      "minimalist" -> %{
        "header_bg" => "#ffffff",
        "text_color" => "#111827",
        "video_container" => "bg-gray-50 rounded-lg border border-gray-200"
      }
      _ -> %{
        "header_bg" => "#ffffff",
        "text_color" => "#374151",
        "video_container" => "bg-white rounded-lg border border-gray-200"
      }
    end

    base_config
    |> Map.merge(video_config)
    |> Map.merge(theme_specific)
  end

  defp get_video_style_for_theme(theme) do
    case theme do
      "executive" -> "professional"
      "developer" -> "terminal"
      "designer" -> "artistic"
      "minimalist" -> "clean"
      "consultant" -> "corporate"
      "academic" -> "scholarly"
      _ -> "default"
    end
  end

  # 🔥 MISSING: render_theme_specific_header function
  defp render_theme_specific_header(assigns) do
    theme = assigns.portfolio.theme || "executive"

    case theme do
      "executive" -> render_executive_hero(assigns)
      "developer" -> render_developer_hero(assigns)
      "designer" -> render_designer_hero(assigns)
      "consultant" -> render_consultant_hero(assigns)
      "academic" -> render_academic_hero(assigns)
      "minimalist" -> render_minimalist_hero(assigns)
      _ -> render_executive_hero(assigns)  # fallback
    end
  end

  # ============================================================================
  # THEME-SPECIFIC HERO RENDERERS
  # ============================================================================

  defp render_executive_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-gradient-to-br from-slate-50 via-blue-50 to-indigo-100 overflow-hidden">
      <!-- Professional Background Pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="absolute top-20 left-20 w-72 h-72 bg-blue-600 rounded-full mix-blend-multiply filter blur-xl animate-pulse"></div>
        <div class="absolute top-40 right-20 w-96 h-96 bg-indigo-600 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 2s;"></div>
        <div class="absolute bottom-20 left-40 w-80 h-80 bg-slate-600 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 4s;"></div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Executive Header -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-20">
        <div class="grid lg:grid-cols-12 gap-12 items-center max-w-7xl mx-auto">

          <!-- Professional Info Column -->
          <div class="lg:col-span-7 order-2 lg:order-1">
            <div class="bg-white/80 backdrop-blur-xl rounded-3xl p-8 shadow-2xl border border-white/20">
              <div class="flex items-center space-x-4 mb-6">
                <!-- Professional Badge -->
                <div class="w-16 h-16 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-2xl flex items-center justify-center">
                  <span class="text-2xl font-bold text-white">
                    <%= String.first(@portfolio.title) %>
                  </span>
                </div>
                <div>
                  <h1 class="text-4xl font-bold text-slate-900 leading-tight">
                    <%= @portfolio.title %>
                  </h1>
                  <p class="text-xl text-slate-600 font-light">
                    <%= @portfolio.description || "Executive Portfolio" %>
                  </p>
                </div>
              </div>

              <!-- Professional Stats -->
              <div class="grid grid-cols-3 gap-6 mb-8">
                <div class="text-center p-4 bg-blue-50 rounded-xl">
                  <div class="text-3xl font-bold text-blue-600"><%= length(@sections) %></div>
                  <div class="text-sm text-slate-600">Sections</div>
                </div>
                <div class="text-center p-4 bg-indigo-50 rounded-xl">
                  <div class="text-3xl font-bold text-indigo-600">5+</div>
                  <div class="text-sm text-slate-600">Years Exp</div>
                </div>
                <div class="text-center p-4 bg-slate-50 rounded-xl">
                  <div class="text-3xl font-bold text-slate-600">Active</div>
                  <div class="text-sm text-slate-600">Status</div>
                </div>
              </div>

              <!-- Contact Info -->
              <%= render_contact_info_executive(assigns) %>

              <!-- Professional Actions -->
              <div class="flex space-x-4">
                <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                        class="flex-1 bg-gradient-to-r from-blue-600 to-indigo-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-blue-700 hover:to-indigo-700 transition-all duration-300 shadow-lg hover:shadow-xl">
                  View Portfolio
                </button>
                <%= if get_contact_section(@sections) do %>
                  <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                          class="px-6 py-3 bg-white text-slate-700 rounded-xl font-semibold hover:bg-slate-50 transition-all duration-300 border border-slate-200">
                    Contact
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Video Column -->
          <div class="lg:col-span-5 order-1 lg:order-2">
            <%= if @video_url && @video_url != "" do %>
              <div class="relative group cursor-pointer" phx-click="show_video_modal">
                <div class="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl hover:scale-105 transition-all duration-500">
                  <div class="relative rounded-2xl overflow-hidden shadow-2xl bg-gradient-to-br from-blue-600 to-indigo-600">
                    <!-- Video Thumbnail -->
                    <div class="aspect-video flex items-center justify-center">
                      <div class="text-center text-white">
                        <div class="w-20 h-20 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform">
                          <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                          </svg>
                        </div>
                        <p class="text-lg font-semibold">Executive Introduction</p>
                        <p class="text-sm opacity-80">Click to watch</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Professional Avatar -->
              <div class="bg-gradient-to-br from-blue-600 to-indigo-600 rounded-3xl shadow-2xl flex items-center justify-center" style="height: 400px;">
                <span class="text-8xl font-bold text-white">
                  <%= String.first(@portfolio.title) %>
                </span>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>
    </section>
    """
  end

  defp render_developer_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-gray-900 text-green-400 overflow-hidden font-mono">
      <!-- Terminal Background -->
      <div class="absolute inset-0 opacity-20">
        <div class="grid grid-cols-12 gap-4 p-8">
          <%= for i <- 1..50 do %>
            <div class="h-1 bg-green-500 rounded animate-pulse" style={"animation-delay: #{rem(i, 10) * 0.1}s"}></div>
          <% end %>
        </div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Terminal Window -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-20">
        <div class="bg-gray-800 rounded-2xl border border-gray-700 shadow-2xl overflow-hidden">

          <!-- Terminal Header -->
          <div class="bg-gray-700 px-6 py-4 flex items-center space-x-3">
            <div class="flex space-x-2">
              <div class="w-3 h-3 bg-red-500 rounded-full"></div>
              <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
              <div class="w-3 h-3 bg-green-500 rounded-full"></div>
            </div>
            <span class="text-gray-300 text-sm">developer@portfolio:~$</span>
          </div>

          <!-- Terminal Content -->
          <div class="p-8 grid lg:grid-cols-2 gap-8 items-center">

            <!-- Terminal Text -->
            <div class="space-y-4">
              <div class="text-green-400">
                <span class="text-green-500">$</span> cat developer_profile.txt
              </div>

              <div class="text-white">
                <div class="mb-4">
                  <span class="text-yellow-400">Name:</span> <%= @portfolio.title %>
                </div>
                <div class="mb-4">
                  <span class="text-yellow-400">Role:</span> <%= @portfolio.description || "Full Stack Developer" %>
                </div>
                <div class="mb-4">
                  <span class="text-yellow-400">Status:</span> <span class="text-green-400 animate-pulse">● Available</span>
                </div>
              </div>

              <div class="text-green-400">
                <span class="text-green-500">$</span> ls -la skills/
              </div>

              <div class="text-gray-300 grid grid-cols-2 gap-2 text-sm">
                <div>drwxr-xr-x javascript/</div>
                <div>drwxr-xr-x python/</div>
                <div>drwxr-xr-x react/</div>
                <div>drwxr-xr-x elixir/</div>
              </div>

              <%= render_contact_info_developer(assigns) %>

              <!-- Terminal Actions -->
              <div class="flex space-x-4 mt-8">
                <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                        class="bg-green-600 text-gray-900 px-6 py-3 rounded-lg font-bold hover:bg-green-500 transition-all duration-300">
                  ./view_portfolio.sh
                </button>
                <%= if get_contact_section(@sections) do %>
                  <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                          class="bg-gray-700 text-green-400 px-6 py-3 rounded-lg font-bold hover:bg-gray-600 transition-all duration-300 border border-green-600">
                    ./contact.sh
                  </button>
                <% end %>
              </div>
            </div>

            <!-- Video/Code Window -->
            <div class="bg-gray-900 rounded-xl border border-gray-700 overflow-hidden">
              <%= if @video_url && @video_url != "" do %>
                <div class="cursor-pointer group" phx-click="show_video_modal">
                  <div class="bg-gray-800 px-4 py-2 text-sm text-gray-400 border-b border-gray-700">
                    <span class="text-green-400">●</span> video_intro.mp4
                  </div>
                  <div class="aspect-video flex items-center justify-center bg-gray-900 group-hover:bg-gray-800 transition-colors">
                    <div class="text-center">
                      <div class="w-16 h-16 bg-green-600 bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-3 group-hover:scale-110 transition-transform">
                        <svg class="w-6 h-6 text-green-400" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                        </svg>
                      </div>
                      <p class="text-green-400 font-mono">▶ Run video_intro.mp4</p>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="bg-gray-800 px-4 py-2 text-sm text-gray-400 border-b border-gray-700">
                  <span class="text-green-400">●</span> developer_avatar.js
                </div>
                <div class="aspect-video flex items-center justify-center bg-gray-900 text-6xl text-green-400">
                  &lt;/&gt;
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>
    </section>
    """
  end

  defp render_designer_hero(assigns) do
    theme_colors = get_designer_theme_colors(assigns[:customization] || %{})

    ~H"""
    <section class="relative min-h-screen overflow-hidden" style={"background: linear-gradient(135deg, #{theme_colors.primary}, #{theme_colors.secondary})"}>
      <!-- Rest of the function stays the same -->
      <!-- Creative Background Elements -->
      <div class="absolute inset-0 opacity-30">
        <div class="absolute top-20 left-20 w-64 h-64 bg-white rounded-full mix-blend-overlay filter blur-xl animate-float"></div>
        <div class="absolute top-60 right-40 w-80 h-80 bg-pink-300 rounded-full mix-blend-overlay filter blur-xl animate-float-delayed"></div>
        <div class="absolute bottom-40 left-60 w-72 h-72 bg-yellow-300 rounded-full mix-blend-overlay filter blur-xl animate-float-slow"></div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Creative Layout -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-20">
        <div class="grid lg:grid-cols-2 gap-12 items-center max-w-7xl mx-auto">

          <!-- Creative Info -->
          <div class="text-white">
            <div class="bg-white bg-opacity-10 backdrop-blur-xl rounded-3xl p-8 border border-white border-opacity-20">
              <h1 class="text-5xl font-black mb-6 leading-tight">
                <%= @portfolio.title %>
              </h1>
              <p class="text-2xl font-light mb-8 text-pink-100">
                <%= @portfolio.description || "Creative Designer & Visual Artist" %>
              </p>

              <!-- Creative Stats -->
              <div class="grid grid-cols-3 gap-4 mb-8">
                <div class="text-center p-4 bg-white bg-opacity-20 rounded-2xl backdrop-blur-sm">
                  <div class="text-3xl font-bold text-yellow-300"><%= length(@sections) %></div>
                  <div class="text-xs text-pink-100">Projects</div>
                </div>
                <div class="text-center p-4 bg-white bg-opacity-20 rounded-2xl backdrop-blur-sm">
                  <div class="text-3xl font-bold text-pink-300">∞</div>
                  <div class="text-xs text-pink-100">Ideas</div>
                </div>
                <div class="text-center p-4 bg-white bg-opacity-20 rounded-2xl backdrop-blur-sm">
                  <div class="text-3xl font-bold text-white">✨</div>
                  <div class="text-xs text-pink-100">Magic</div>
                </div>
              </div>

              <%= render_contact_info_designer(assigns) %>

              <!-- Creative Actions -->
              <div class="flex space-x-4">
                <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                        class="flex-1 bg-white bg-opacity-20 backdrop-blur-sm text-white px-6 py-4 rounded-2xl font-bold hover:bg-opacity-30 transition-all duration-300 border border-white border-opacity-30">
                  ✨ Explore My Work
                </button>
                <%= if get_contact_section(@sections) do %>
                  <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                          class="bg-gradient-to-r from-pink-500 to-yellow-500 text-white px-6 py-4 rounded-2xl font-bold hover:from-pink-600 hover:to-yellow-600 transition-all duration-300 shadow-2xl">
                    Let's Create
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Creative Video/Visual -->
          <div class="relative">
            <%= if assigns[:video_url] && @video_url != "" do %>
              <div class="relative group cursor-pointer transform hover:scale-105 transition-all duration-500" phx-click="show_video_modal">
                <div class="bg-white bg-opacity-10 backdrop-blur-xl rounded-3xl p-6 border border-white border-opacity-20">
                  <div class="relative rounded-2xl overflow-hidden">
                    <div class="aspect-video bg-gradient-to-br from-pink-500 via-purple-500 to-indigo-500 flex items-center justify-center">
                      <div class="text-center text-white">
                        <div class="w-24 h-24 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:rotate-12 transition-transform duration-300">
                          <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                          </svg>
                        </div>
                        <p class="text-xl font-bold">Creative Process</p>
                        <p class="text-sm opacity-80">Watch the magic happen</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Creative Avatar -->
              <div class="bg-gradient-to-br from-pink-500 via-purple-500 to-indigo-500 rounded-3xl shadow-2xl flex items-center justify-center" style="height: 400px;">
                <div class="text-center text-white">
                  <div class="text-8xl font-black mb-4">🎨</div>
                  <p class="text-2xl font-bold"><%= String.first(@portfolio.title) %></p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>

      <style>
        @keyframes float {
          0%, 100% { transform: translateY(0px) rotate(0deg); }
          50% { transform: translateY(-20px) rotate(5deg); }
        }
        @keyframes float-delayed {
          0%, 100% { transform: translateY(0px) rotate(0deg); }
          50% { transform: translateY(-30px) rotate(-5deg); }
        }
        @keyframes float-slow {
          0%, 100% { transform: translateY(0px) rotate(0deg); }
          50% { transform: translateY(-15px) rotate(3deg); }
        }
        .animate-float { animation: float 6s ease-in-out infinite; }
        .animate-float-delayed { animation: float-delayed 8s ease-in-out infinite; }
        .animate-float-slow { animation: float-slow 10s ease-in-out infinite; }
      </style>
    </section>
    """
  end

  defp render_consultant_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-gradient-to-br from-slate-100 via-blue-50 to-cyan-100 overflow-hidden">
      <!-- Professional Grid Background -->
      <div class="absolute inset-0 opacity-5">
        <div class="grid grid-cols-12 gap-4 p-8">
          <%= for i <- 1..144 do %>
            <div class="h-1 bg-blue-600 rounded" style={"animation-delay: #{rem(i, 20) * 0.05}s"}></div>
          <% end %>
        </div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Consultant Layout -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-20">
        <div class="grid lg:grid-cols-2 gap-16 items-center max-w-7xl mx-auto">

          <!-- Strategic Info -->
          <div class="space-y-8">
            <div class="bg-white/90 backdrop-blur-xl rounded-2xl p-8 shadow-xl border border-blue-200">
              <div class="flex items-center space-x-4 mb-6">
                <!-- Consultant Badge -->
                <div class="w-16 h-16 bg-gradient-to-br from-blue-600 to-cyan-600 rounded-xl flex items-center justify-center">
                  <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
                  </svg>
                </div>
                <div>
                  <h1 class="text-4xl font-bold text-slate-900 leading-tight">
                    <%= @portfolio.title %>
                  </h1>
                  <p class="text-lg text-blue-700 font-medium">
                    Strategic Consultant
                  </p>
                </div>
              </div>

              <p class="text-slate-700 text-lg leading-relaxed mb-8">
                <%= @portfolio.description || "Transforming businesses through strategic insights and data-driven solutions" %>
              </p>

              <!-- Consultant Metrics -->
              <div class="grid grid-cols-3 gap-4 mb-8">
                <div class="text-center p-4 bg-blue-50 rounded-xl">
                  <div class="text-2xl font-bold text-blue-600"><%= length(@sections) %></div>
                  <div class="text-sm text-slate-600">Case Studies</div>
                </div>
                <div class="text-center p-4 bg-cyan-50 rounded-xl">
                  <div class="text-2xl font-bold text-cyan-600">95%</div>
                  <div class="text-sm text-slate-600">Success Rate</div>
                </div>
                <div class="text-center p-4 bg-slate-50 rounded-xl">
                  <div class="text-2xl font-bold text-slate-600">Active</div>
                  <div class="text-sm text-slate-600">Status</div>
                </div>
              </div>

              <%= render_contact_info_consultant(assigns) %>

              <!-- Strategic Actions -->
              <div class="flex space-x-4">
                <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                        class="flex-1 bg-gradient-to-r from-blue-600 to-cyan-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-blue-700 hover:to-cyan-700 transition-all duration-300 shadow-lg">
                  View Case Studies
                </button>
                <%= if get_contact_section(@sections) do %>
                  <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                          class="px-6 py-3 bg-white text-blue-700 rounded-xl font-semibold hover:bg-blue-50 transition-all duration-300 border-2 border-blue-200">
                    Consult
                  </button>
                <% end %>
              </div>
            </div>
          </div>

          <!-- Strategic Visual/Video -->
          <div class="relative">
            <%= if @video_url && @video_url != "" do %>
              <div class="relative group cursor-pointer transform hover:scale-105 transition-all duration-500" phx-click="show_video_modal">
                <div class="bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl">
                  <div class="relative rounded-2xl overflow-hidden">
                    <div class="aspect-video bg-gradient-to-br from-blue-600 to-cyan-600 flex items-center justify-center">
                      <div class="text-center text-white">
                        <div class="w-24 h-24 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform">
                          <svg class="w-10 h-10" fill="currentColor" viewBox="0 0 20 20">
                            <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                          </svg>
                        </div>
                        <p class="text-xl font-bold">Strategic Overview</p>
                        <p class="text-sm opacity-80">Watch methodology</p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            <% else %>
              <!-- Strategic Chart Visual -->
              <div class="bg-gradient-to-br from-blue-600 to-cyan-600 rounded-3xl shadow-2xl p-8" style="height: 400px;">
                <div class="text-center text-white">
                  <svg class="w-32 h-32 mx-auto mb-4" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M2 11a1 1 0 011-1h2a1 1 0 011 1v5a1 1 0 01-1 1H3a1 1 0 01-1-1v-5zM8 7a1 1 0 011-1h2a1 1 0 011 1v9a1 1 0 01-1 1H9a1 1 0 01-1-1V7zM14 4a1 1 0 011-1h2a1 1 0 011 1v12a1 1 0 01-1 1h-2a1 1 0 01-1-1V4z"/>
                  </svg>
                  <p class="text-2xl font-bold">Strategic Growth</p>
                </div>
              </div>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>
    </section>
    """
  end

  defp render_theme_specific_hero(assigns) do
    theme = assigns.portfolio.theme || "executive"

    case theme do
      "executive" -> render_executive_hero(assigns)
      "developer" -> render_developer_hero(assigns)
      "designer" -> render_designer_hero(assigns)
      "consultant" -> render_consultant_hero(assigns)
      "academic" -> render_academic_hero(assigns)
      "minimalist" -> render_minimalist_hero(assigns)
      # 🔥 FIX: Map creative variations to designer (or create specific render_creative_hero)
      "creative" -> render_designer_hero(assigns)  # Use designer as fallback
      "creative_artistic" -> render_designer_hero(assigns)
      "creative_designer" -> render_designer_hero(assigns)
      _ -> render_executive_hero(assigns)  # fallback
    end
  end

  defp render_academic_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-gradient-to-br from-green-50 via-teal-50 to-blue-50 overflow-hidden">
      <!-- Academic Pattern -->
      <div class="absolute inset-0 opacity-10">
        <div class="grid grid-cols-8 gap-8 p-8">
          <%= for i <- 1..64 do %>
            <div class="aspect-square border border-green-300 rounded" style={"animation-delay: #{rem(i, 8) * 0.2}s; animation: fadeIn 2s ease-in-out infinite alternate"}></div>
          <% end %>
        </div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Academic Layout -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-20">
        <div class="max-w-6xl mx-auto">

          <!-- Academic Header -->
          <div class="text-center mb-16">
            <div class="inline-flex items-center space-x-4 mb-6">
              <div class="w-20 h-20 bg-gradient-to-br from-green-600 to-teal-600 rounded-full flex items-center justify-center">
                <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5"/>
                </svg>
              </div>
            </div>
            <h1 class="text-5xl lg:text-6xl font-bold text-slate-900 mb-6 leading-tight">
              <%= @portfolio.title %>
            </h1>
            <p class="text-2xl text-green-700 font-light mb-8 max-w-3xl mx-auto leading-relaxed">
              <%= @portfolio.description || "Academic Researcher & Scholar" %>
            </p>

            <!-- Academic Credentials -->
            <div class="flex justify-center space-x-8 mb-12">
              <div class="text-center">
                <div class="text-3xl font-bold text-green-600"><%= length(@sections) %></div>
                <div class="text-sm text-slate-600">Research Areas</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold text-teal-600">12+</div>
                <div class="text-sm text-slate-600">Publications</div>
              </div>
              <div class="text-center">
                <div class="text-3xl font-bold text-blue-600">Active</div>
                <div class="text-sm text-slate-600">Research</div>
              </div>
            </div>
          </div>

          <!-- Content Grid -->
          <div class="grid lg:grid-cols-2 gap-12 items-start">

            <!-- Video/Research Overview -->
            <div class="order-2 lg:order-1">
              <%= if @video_url && @video_url != "" do %>
                <div class="bg-white/80 backdrop-blur-xl rounded-2xl p-6 shadow-xl border border-green-200 cursor-pointer hover:scale-105 transition-all duration-500" phx-click="show_video_modal">
                  <div class="aspect-video bg-gradient-to-br from-green-600 to-teal-600 rounded-xl flex items-center justify-center">
                    <div class="text-center text-white">
                      <div class="w-20 h-20 bg-white bg-opacity-20 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform">
                        <svg class="w-8 h-8" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                        </svg>
                      </div>
                      <p class="text-lg font-semibold">Research Overview</p>
                      <p class="text-sm opacity-80">Academic introduction</p>
                    </div>
                  </div>
                </div>
              <% else %>
                <!-- Research Visual -->
                <div class="bg-gradient-to-br from-green-600 to-teal-600 rounded-2xl shadow-xl p-8" style="height: 300px;">
                  <div class="text-center text-white">
                    <svg class="w-24 h-24 mx-auto mb-4" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                    </svg>
                    <p class="text-2xl font-bold">Research Excellence</p>
                  </div>
                </div>
              <% end %>
            </div>

            <!-- Academic Info -->
            <div class="order-1 lg:order-2">
              <div class="bg-white/90 backdrop-blur-xl rounded-2xl p-8 shadow-xl border border-green-200">
                <%= render_contact_info_academic(assigns) %>

                <!-- Academic Actions -->
                <div class="flex flex-col space-y-4 mt-8">
                  <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                          class="w-full bg-gradient-to-r from-green-600 to-teal-600 text-white px-6 py-3 rounded-xl font-semibold hover:from-green-700 hover:to-teal-700 transition-all duration-300 shadow-lg">
                    View Research
                  </button>
                  <%= if get_contact_section(@sections) do %>
                    <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                            class="w-full bg-white text-green-700 px-6 py-3 rounded-xl font-semibold hover:bg-green-50 transition-all duration-300 border-2 border-green-200">
                      Collaborate
                    </button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>

      <style>
        @keyframes fadeIn {
          0% { opacity: 0.3; }
          100% { opacity: 0.8; }
        }
      </style>
    </section>
    """
  end

  defp render_minimalist_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-white overflow-hidden">
      <!-- Minimal Background -->
      <div class="absolute inset-0">
        <div class="absolute top-1/4 right-1/4 w-2 h-2 bg-gray-400 rounded-full"></div>
        <div class="absolute bottom-1/3 left-1/3 w-1 h-1 bg-gray-300 rounded-full"></div>
      </div>

      <!-- Mobile Navigation -->
      <%= render_mobile_navigation(assigns) %>

      <!-- Minimal Layout -->
      <div class="relative z-10 container mx-auto px-6 lg:px-8 pt-32">
        <div class="max-w-4xl mx-auto text-center">

          <!-- Minimal Header -->
          <div class="mb-16">
            <h1 class="text-6xl lg:text-8xl font-light text-gray-900 mb-8 tracking-tight">
              <%= @portfolio.title %>
            </h1>
            <p class="text-2xl text-gray-600 font-light mb-12 max-w-2xl mx-auto">
              <%= @portfolio.description || "Focused. Essential. Effective." %>
            </p>

            <!-- Minimal Line -->
            <div class="w-24 h-px bg-gray-900 mx-auto mb-12"></div>
          </div>

          <!-- Video Section -->
          <%= if @video_url && @video_url != "" do %>
            <div class="mb-16">
              <div class="max-w-2xl mx-auto cursor-pointer group" phx-click="show_video_modal">
                <div class="border border-gray-200 rounded-lg overflow-hidden hover:shadow-lg transition-all duration-300">
                  <div class="aspect-video bg-gray-50 flex items-center justify-center group-hover:bg-gray-100 transition-colors">
                    <div class="text-center">
                      <div class="w-16 h-16 border border-gray-900 rounded-full flex items-center justify-center mx-auto mb-4 group-hover:scale-110 transition-transform">
                        <svg class="w-6 h-6 text-gray-900" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                        </svg>
                      </div>
                      <p class="text-gray-900 font-light">Introduction</p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Minimal Stats -->
          <div class="grid grid-cols-3 gap-16 mb-16 max-w-lg mx-auto">
            <div class="text-center">
              <div class="text-4xl font-light text-gray-900 mb-2"><%= length(@sections) %></div>
              <div class="text-xs uppercase tracking-wide text-gray-500">Sections</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-light text-gray-900 mb-2">5+</div>
              <div class="text-xs uppercase tracking-wide text-gray-500">Years</div>
            </div>
            <div class="text-center">
              <div class="text-4xl font-light text-gray-900 mb-2">∞</div>
              <div class="text-xs uppercase tracking-wide text-gray-500">Ideas</div>
            </div>
          </div>

          <!-- Minimal Contact -->
          <%= render_contact_info_minimalist(assigns) %>

          <!-- Minimal Actions -->
          <div class="flex flex-col sm:flex-row gap-4 justify-center max-w-md mx-auto">
            <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
                    class="px-8 py-3 border border-gray-900 text-gray-900 font-light hover:bg-gray-900 hover:text-white transition-all duration-300">
              View Work
            </button>
            <%= if get_contact_section(@sections) do %>
              <button onclick={"document.getElementById('section-#{get_contact_section(@sections).id}').scrollIntoView({behavior: 'smooth'})"}
                      class="px-8 py-3 bg-gray-900 text-white font-light hover:bg-gray-700 transition-all duration-300">
                Contact
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <!-- Enhanced Video Modal -->
      <%= render_enhanced_video_modal(assigns) %>
    </section>
    """
  end

  defp render_creative_hero(assigns) do
    ~H"""
    <section class="relative min-h-screen bg-gradient-to-br from-purple-600 via-pink-600 to-indigo-600 overflow-hidden">
      <!-- Creative background elements -->
      <div class="absolute inset-0">
        <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-white/10 rounded-full blur-3xl animate-pulse"></div>
        <div class="absolute bottom-1/3 right-1/4 w-96 h-96 bg-yellow-400/20 rounded-full blur-3xl animate-pulse delay-1000"></div>
      </div>

      <div class="relative z-10 min-h-screen flex items-center px-6">
        <div class="max-w-7xl mx-auto text-center">
          <h1 class="text-5xl lg:text-7xl font-bold text-white mb-6 leading-tight">
            <%= @portfolio.title %>
          </h1>
          <p class="text-xl text-white/90 max-w-3xl mx-auto leading-relaxed mb-12">
            <%= @portfolio.description %>
          </p>

          <!-- Video integration point -->
          <%= if @has_intro_video do %>
            <div class="relative max-w-4xl mx-auto mb-12">
              <div class="absolute -inset-4 bg-gradient-to-r from-pink-500 to-violet-500 rounded-2xl blur opacity-75"></div>
              <div class="relative bg-white/10 backdrop-blur-sm rounded-2xl p-6 border border-white/20">
                <video
                  controls
                  class="w-full rounded-xl shadow-2xl">
                  <source src={@video_url} type="video/mp4">
                  <source src={@video_url} type="video/webm">
                  Your browser does not support the video tag.
                </video>
              </div>
            </div>
          <% end %>

          <!-- Contact and social info rendering -->
          <%= render_contact_info_creative(assigns) %>
        </div>
      </div>
    </section>
    """
  end


  defp render_contact_info_executive(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-4 mb-8">
      <%= if contact_section do %>
        <div class="space-y-3">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
              </div>
              <a href={"mailto:#{email}"} class="text-slate-700 hover:text-blue-600 transition-colors font-medium">
                <%= email %>
              </a>
            </div>
          <% end %>
          <%= if phone = get_in(contact_section.content, ["phone"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-indigo-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-indigo-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                </svg>
              </div>
              <a href={"tel:#{phone}"} class="text-slate-700 hover:text-indigo-600 transition-colors font-medium">
                <%= phone %>
              </a>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex items-center space-x-4 pt-4 border-t border-slate-200">
          <span class="text-sm font-medium text-slate-600">Connect:</span>
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="w-8 h-8 rounded-lg bg-slate-100 hover:bg-blue-100 flex items-center justify-center transition-all hover:scale-110">
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_info_developer(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="mt-6 space-y-3">
      <div class="text-green-400">
        <span class="text-green-500">$</span> cat contact.json
      </div>

      <div class="text-gray-300 space-y-2">
        <%= if contact_section do %>
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="flex items-center space-x-2">
              <span class="text-yellow-400">"email":</span>
              <a href={"mailto:#{email}"} class="text-green-300 hover:text-green-100 transition-colors">
                "<%= email %>"
              </a>
            </div>
          <% end %>
          <%= if github = Map.get(social_links, "github") do %>
            <div class="flex items-center space-x-2">
              <span class="text-yellow-400">"github":</span>
              <a href={github} target="_blank" class="text-green-300 hover:text-green-100 transition-colors">
                "<%= github %>"
              </a>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    """
  end

  defp render_contact_info_creative(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-6">
      <%= if contact_section do %>
        <div class="space-y-4">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="text-center">
              <a href={"mailto:#{email}"} class="text-white/90 hover:text-white transition-colors text-lg">
                <%= email %>
              </a>
            </div>
          <% end %>
          <%= if phone = get_in(contact_section.content, ["phone"]) do %>
            <div class="text-center">
              <a href={"tel:#{phone}"} class="text-white/90 hover:text-white transition-colors text-lg">
                <%= phone %>
              </a>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex justify-center space-x-6 pt-8">
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="w-12 h-12 rounded-full bg-white/20 hover:bg-white/30 flex items-center justify-center transition-all hover:scale-110">
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end


  defp render_contact_info_designer(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-4 mb-8">
      <%= if contact_section do %>
        <div class="space-y-3">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-white bg-opacity-20 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
              </div>
              <a href={"mailto:#{email}"} class="text-white hover:text-pink-200 transition-colors font-medium">
                <%= email %>
              </a>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex items-center space-x-4 pt-4 border-t border-white border-opacity-20">
          <span class="text-sm font-medium text-pink-200">Find me:</span>
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="w-8 h-8 rounded-lg bg-white bg-opacity-20 hover:bg-opacity-30 flex items-center justify-center transition-all hover:scale-110">
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_info_consultant(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-4 mb-8">
      <%= if contact_section do %>
        <div class="space-y-3">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
              </div>
              <a href={"mailto:#{email}"} class="text-slate-700 hover:text-blue-600 transition-colors font-medium">
                <%= email %>
              </a>
            </div>
          <% end %>
          <%= if phone = get_in(contact_section.content, ["phone"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-cyan-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-cyan-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                </svg>
              </div>
              <a href={"tel:#{phone}"} class="text-slate-700 hover:text-cyan-600 transition-colors font-medium">
                <%= phone %>
              </a>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex items-center space-x-4 pt-4 border-t border-blue-200">
          <span class="text-sm font-medium text-slate-600">Professional:</span>
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="w-8 h-8 rounded-lg bg-blue-100 hover:bg-blue-200 flex items-center justify-center transition-all hover:scale-110">
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_info_academic(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-4 mb-8">
      <h3 class="text-lg font-semibold text-slate-900 mb-4">Academic Contact</h3>

      <%= if contact_section do %>
        <div class="space-y-3">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
              </div>
              <a href={"mailto:#{email}"} class="text-slate-700 hover:text-green-600 transition-colors font-medium">
                <%= email %>
              </a>
            </div>
          <% end %>
          <%= if institution = get_in(contact_section.content, ["institution"]) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-teal-100 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-teal-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-4m-5 0H3m2 0h2M7 7h.01M7 3h5a2 2 0 012 2v13H7V3z"/>
                </svg>
              </div>
              <span class="text-slate-700 font-medium">
                <%= institution %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex items-center space-x-4 pt-4 border-t border-green-200">
          <span class="text-sm font-medium text-slate-600">Academic:</span>
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="w-8 h-8 rounded-lg bg-green-100 hover:bg-green-200 flex items-center justify-center transition-all hover:scale-110">
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp render_contact_info_minimalist(assigns) do
    contact_section = get_contact_section(assigns.sections)
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="mb-16">
      <%= if contact_section do %>
        <div class="space-y-2 mb-8">
          <%= if email = get_in(contact_section.content, ["email"]) do %>
            <div class="text-center">
              <a href={"mailto:#{email}"} class="text-gray-600 hover:text-gray-900 transition-colors font-light">
                <%= email %>
              </a>
            </div>
          <% end %>
          <%= if phone = get_in(contact_section.content, ["phone"]) do %>
            <div class="text-center">
              <a href={"tel:#{phone}"} class="text-gray-600 hover:text-gray-900 transition-colors font-light">
                <%= phone %>
              </a>
            </div>
          <% end %>
          <%= if location = get_in(contact_section.content, ["location"]) do %>
            <div class="text-center">
              <span class="text-gray-600 font-light">
                <%= location %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <%= if map_size(social_links) > 0 do %>
        <div class="flex justify-center space-x-6">
          <%= for {platform, url} <- social_links do %>
            <a href={url} target="_blank" class="text-gray-600 hover:text-gray-900 transition-colors" title={String.capitalize(platform)}>
              <%= render_social_icon(platform) %>
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_video_hero_theme_classes(theme) do
    case theme do
      "executive" -> %{
        background: "bg-gradient-to-br from-slate-900 via-blue-900 to-indigo-900",
        video_container: "bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl",
        text_color: "text-white",
        title_gradient: "bg-gradient-to-r from-white via-blue-100 to-slate-100 bg-clip-text text-transparent",
        subtitle_color: "text-blue-100"
      }
      "developer" -> %{
        background: "bg-gradient-to-br from-gray-900 via-green-900 to-emerald-900",
        video_container: "bg-green-500/10 backdrop-blur-xl rounded-2xl p-6 border border-green-500/20 shadow-2xl",
        text_color: "text-green-100",
        title_gradient: "bg-gradient-to-r from-green-100 via-emerald-100 to-white bg-clip-text text-transparent",
        subtitle_color: "text-green-200"
      }
      "designer" -> %{
        background: "bg-gradient-to-br from-purple-900 via-pink-900 to-rose-900",
        video_container: "bg-white/15 backdrop-blur-xl rounded-3xl p-6 border border-pink-300/30 shadow-2xl",
        text_color: "text-white",
        title_gradient: "bg-gradient-to-r from-white via-pink-100 to-purple-100 bg-clip-text text-transparent",
        subtitle_color: "text-pink-100"
      }
      "creative" -> %{
        background: "bg-gradient-to-br from-indigo-900 via-purple-900 to-pink-900",
        video_container: "bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl",
        text_color: "text-white",
        title_gradient: "bg-gradient-to-r from-white via-purple-100 to-pink-100 bg-clip-text text-transparent",
        subtitle_color: "text-purple-100"
      }
      "minimalist" -> %{
        background: "bg-gradient-to-br from-gray-100 via-slate-200 to-gray-300",
        video_container: "bg-white rounded-2xl p-6 border border-gray-200 shadow-lg",
        text_color: "text-gray-900",
        title_gradient: "text-gray-900",
        subtitle_color: "text-gray-700"
      }
      _ -> %{
        background: "bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900",
        video_container: "bg-white/10 backdrop-blur-xl rounded-3xl p-6 border border-white/20 shadow-2xl",
        text_color: "text-white",
        title_gradient: "bg-gradient-to-r from-white via-blue-100 to-purple-100 bg-clip-text text-transparent",
        subtitle_color: "text-blue-100"
      }
    end
  end

    defp extract_social_links_comprehensive(sections, user) do
    # Get user's social links as base
    user_social = Map.get(user, :social_links, %{}) || %{}

    # Find intro section and extract social links
    intro_social = case Enum.find(sections, fn s -> s.section_type == :intro end) do
      nil -> %{}
      intro_section ->
        content = intro_section.content || %{}

        # Extract from various possible locations
        social_links = %{}
        |> Map.merge(Map.get(content, "social_links", %{}))
        |> Map.merge(Map.get(content, "social", %{}))
        |> Map.merge(Map.get(content, "links", %{}))

        # Also check for individual social platforms
        social_links
        |> maybe_add_social_link("linkedin", content)
        |> maybe_add_social_link("github", content)
        |> maybe_add_social_link("twitter", content)
        |> maybe_add_social_link("instagram", content)
        |> maybe_add_social_link("facebook", content)
        |> maybe_add_social_link("website", content)
        |> maybe_add_social_link("portfolio", content)
    end

    # Find contact section and extract social links
    contact_social = case Enum.find(sections, fn s -> s.section_type == :contact end) do
      nil -> %{}
      contact_section ->
        content = contact_section.content || %{}
        Map.get(content, "social_links", %{}) || %{}
    end

    # Merge all sources (user < intro < contact for precedence)
    user_social
    |> Map.merge(intro_social)
    |> Map.merge(contact_social)
    |> filter_valid_social_links()
  end

  defp maybe_add_social_link(social_links, platform, content) do
    case Map.get(content, platform) do
      nil -> social_links
      "" -> social_links
      url -> Map.put(social_links, platform, url)
    end
  end

  defp filter_valid_social_links(social_links) do
    social_links
    |> Enum.filter(fn {_platform, url} ->
      is_binary(url) and String.length(String.trim(url)) > 0
    end)
    |> Enum.into(%{})
  end

  # 🔥 ENHANCED CONTACT INFO EXTRACTION
  defp extract_contact_info_comprehensive(sections) do
    # Primary contact section
    primary_contact = case Enum.find(sections, fn s -> s.section_type == :contact end) do
      nil -> %{}
      contact_section ->
        content = contact_section.content || %{}
        %{
          email: get_contact_field(content, ["email", "primary_email", "contact_email"]),
          phone: get_contact_field(content, ["phone", "mobile", "telephone"]),
          location: get_contact_field(content, ["location", "city", "address"]),
          website: get_contact_field(content, ["website", "portfolio_url", "personal_site"])
        }
    end

    # Also check intro section for contact info
    intro_contact = case Enum.find(sections, fn s -> s.section_type == :intro end) do
      nil -> %{}
      intro_section ->
        content = intro_section.content || %{}
        %{
          email: get_contact_field(content, ["email", "contact_email"]),
          phone: get_contact_field(content, ["phone", "mobile"]),
          location: get_contact_field(content, ["location", "city"]),
          website: get_contact_field(content, ["website", "portfolio"])
        }
    end

    # Merge with primary taking precedence
    intro_contact
    |> Map.merge(primary_contact)
    |> Enum.filter(fn {_key, value} ->
      value && String.trim(value) != ""
    end)
    |> Enum.into(%{})
  end

  defp get_contact_field(content, field_names) when is_list(field_names) do
    Enum.find_value(field_names, fn field ->
      case Map.get(content, field) do
        nil -> nil
        "" -> nil
        value when is_binary(value) -> String.trim(value)
        _ -> nil
      end
    end)
  end

  defp extract_social_links(portfolio) do
    # Extract social links from portfolio customization or user data
    customization = portfolio.customization || %{}

    Map.get(customization, "social_links", %{
      "linkedin" => "",
      "github" => "",
      "twitter" => "",
      "website" => ""
    })
  end

  defp extract_contact_info(sections) do
    # Find contact section and extract contact information
    contact_section = Enum.find(sections, fn section ->
      section.section_type == :contact || section.section_type == "contact"
    end)

    case contact_section do
      nil -> %{}
      section ->
        content = section.content || %{}
        %{
          "email" => Map.get(content, "email", ""),
          "phone" => Map.get(content, "phone", ""),
          "location" => Map.get(content, "location", ""),
          "website" => Map.get(content, "website", "")
        }
    end
  end

  # 🔥 ENHANCED SOCIAL ICON RENDERER WITH MORE PLATFORMS
  defp render_social_icon(platform) do
    icon_class = "w-5 h-5"

    case String.downcase(to_string(platform)) do
      "linkedin" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/>
        </svg>
        """)

      "github" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-gray-900" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z"/>
        </svg>
        """)

      "twitter" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-blue-400" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/>
        </svg>
        """)

      "instagram" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-pink-500" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 6.62 5.367 11.987 11.988 11.987s11.987-5.367 11.987-11.987C24.014 5.367 18.647.001 12.017.001zM8.449 20.25c-2.728 0-4.944-2.216-4.944-4.944s2.216-4.944 4.944-4.944 4.944 2.216 4.944 4.944-2.216 4.944-4.944 4.944zm7.718 0c-2.728 0-4.944-2.216-4.944-4.944s2.216-4.944 4.944-4.944 4.944 2.216 4.944 4.944-2.216 4.944-4.944 4.944z"/>
        </svg>
        """)

      "facebook" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-blue-500" fill="currentColor" viewBox="0 0 24 24">
          <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/>
        </svg>
        """)

      "dribbble" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-pink-400" fill="currentColor" viewBox="0 0 24 24">
          <path d="M12 0C5.374 0 0 5.374 0 12s5.374 12 12 12 12-5.374 12-12S18.626 0 12 0zm9.568 7.375c.71 1.296 1.114 2.772 1.114 4.332-.206-.045-2.246-.368-4.303-.207-.054-.132-.117-.27-.18-.403-.196-.415-.41-.844-.64-1.26 2.197-.893 3.785-2.222 4.009-2.462zm-6.568 16.477c-5.195 0-9.45-3.992-9.917-9.056.494.046 5.422.183 10.847-1.497.684 1.33 1.216 2.706 1.621 4.104-4.848 1.371-7.24 5.138-7.551 5.447zm-10.539-7.063c.024-.409.048-.817.088-1.218.692-.029 8.718-.398 13.396 1.73-.134.267-.273.528-.418.776-5.503-1.624-12.324.614-13.066.712zm13.621-11.657c.442.621.719 1.374.719 2.188 0 .033-.008.065-.011.098-2.01-.123-4.025.028-6.012.28.093-.193.189-.388.284-.583 2.016-4.001 4.942-1.983 5.019-1.983zm-7.493-1.415c.693.005 1.372.098 2.017.27-.63 1.253-.98 2.483-1.223 3.815-2.777.581-5.301.245-7.376-.12C3.516 3.826 7.595.152 12.111.737z"/>
        </svg>
        """)

      "behance" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-blue-600" fill="currentColor" viewBox="0 0 24 24">
          <path d="M6.938 4.503c.702 0 1.34.06 1.92.188.577.13 1.07.33 1.485.61.41.28.733.65.96 1.12.225.47.34 1.05.34 1.73 0 .74-.17 1.36-.507 1.86-.338.5-.837.9-1.502 1.22.906.26 1.576.72 2.022 1.37.448.66.665 1.45.665 2.36 0 .75-.13 1.39-.41 1.93-.28.55-.67 1-1.16 1.35-.48.348-1.05.6-1.69.767-.63.165-1.31.254-2.04.254H0V4.51h6.938v-.007zM3.495 8.612h2.881c.405 0 .766-.07 1.084-.21.318-.14.594-.338.83-.595.237-.256.415-.564.54-.92.122-.357.184-.75.184-1.18 0-.837-.21-1.46-.632-1.86-.42-.4-1.034-.6-1.844-.6H3.495v5.365zm0 2.164v6.003h3.707c.41 0 .805-.043 1.184-.13.378-.087.717-.23 1.022-.43.305-.2.55-.46.734-.78.18-.32.27-.71.27-1.18 0-.48-.078-.87-.233-1.19-.155-.32-.39-.56-.705-.73-.315-.17-.7-.285-1.153-.34-.45-.055-.96-.083-1.527-.083H3.495v-.14zm11.174-2.77c.275-.32.62-.56 1.036-.72.414-.16.87-.24 1.36-.24.676 0 1.274.18 1.794.54.52.36.88.87 1.08 1.53h-4.906c.15-.56.41-1-.364-1.11zm-3.096-5.274h8.027v2.006h-8.027V2.732zm-.04 12.064c0-.76.13-1.39.39-1.91.26-.52.6-.94 1.03-1.26.42-.32.9-.56 1.44-.72.54-.16 1.08-.24 1.64-.24.59 0 1.14.08 1.65.24.51.16.95.4 1.33.72.38.32.69.72.93 1.2.24.48.36 1.05.36 1.69v.67H9.72c.055.675.25 1.193.583 1.554.334.36.758.54 1.272.54.3 0 .573-.033.82-.1.247-.067.46-.18.64-.34.18-.16.32-.37.42-.62.1-.25.15-.56.15-.92h2.29c-.12 1.29-.53 2.31-1.23 3.06-.7.75-1.69 1.13-2.97 1.13-.48 0-.94-.06-1.38-.19-.44-.13-.83-.34-1.17-.63-.34-.29-.61-.67-.81-1.13-.2-.46-.3-1.01-.3-1.65v-.08z"/>
        </svg>
        """)

      "youtube" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-red-500" fill="currentColor" viewBox="0 0 24 24">
          <path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/>
        </svg>
        """)

      "website" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/>
        </svg>
        """)

      "portfolio" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """)

      "email" ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """)

      _ ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/>
        </svg>
        """)
    end
  end

  defp render_story_section(section) do
    content = section.content || %{}
    chapters = Map.get(content, "chapters", [])

    Phoenix.HTML.raw("""
    <section class="py-16 bg-gradient-to-br from-purple-50 to-pink-50">
      <div class="max-w-4xl mx-auto px-6">
        <h2 class="text-3xl font-bold text-gray-900 mb-4">#{Map.get(content, "title", "My Story")}</h2>
        <div class="prose prose-lg max-w-none mb-12">
          <p class="text-gray-600 leading-relaxed text-lg">#{Map.get(content, "narrative", "")}</p>
        </div>

        <div class="space-y-8">
          #{Enum.map(chapters, fn chapter ->
            """
            <div class="flex items-start space-x-6 bg-white rounded-lg p-6 shadow-sm">
              <div class="flex-shrink-0 w-16 h-16 bg-purple-100 rounded-full flex items-center justify-center">
                <span class="text-purple-600 font-semibold">#{Map.get(chapter, "year", "")}</span>
              </div>
              <div class="flex-1">
                <h3 class="text-xl font-semibold text-gray-900 mb-2">#{Map.get(chapter, "title", "")}</h3>
                <p class="text-gray-600 leading-relaxed">#{Map.get(chapter, "content", "")}</p>
              </div>
            </div>
            """
          end) |> Enum.join("")}
        </div>
      </div>
    </section>
    """)
  end

  defp render_timeline_section(section) do
    content = section.content || %{}
    events = Map.get(content, "events", [])

    Phoenix.HTML.raw("""
    <section class="py-16 bg-white">
      <div class="max-w-4xl mx-auto px-6">
        <h2 class="text-3xl font-bold text-gray-900 mb-4 text-center">#{Map.get(content, "title", "Timeline")}</h2>
        <p class="text-gray-600 text-center mb-12">#{Map.get(content, "description", "")}</p>

        <div class="relative">
          <div class="absolute left-1/2 transform -translate-x-px h-full w-0.5 bg-gray-300"></div>

          <div class="space-y-12">
            #{Enum.with_index(events) |> Enum.map(fn {event, index} ->
              is_left = rem(index, 2) == 0
              """
              <div class="relative flex items-center #{if is_left, do: "justify-start", else: "justify-end"}">
                <div class="#{if is_left, do: "mr-8 text-right", else: "ml-8 text-left"} w-5/12">
                  <div class="bg-white p-6 rounded-lg shadow-lg border">
                    <div class="text-sm text-blue-600 font-semibold mb-1">#{Map.get(event, "date", "")}</div>
                    <h3 class="text-lg font-semibold text-gray-900 mb-2">#{Map.get(event, "title", "")}</h3>
                    <p class="text-gray-600">#{Map.get(event, "description", "")}</p>
                  </div>
                </div>
                <div class="absolute left-1/2 transform -translate-x-1/2 w-4 h-4 bg-blue-500 rounded-full border-4 border-white"></div>
              </div>
              """
            end) |> Enum.join("")}
          </div>
        </div>
      </div>
    </section>
    """)
  end

  defp render_narrative_section(section) do
    content = section.content || %{}

    Phoenix.HTML.raw("""
    <section class="py-16 bg-gray-50">
      <div class="max-w-4xl mx-auto px-6">
        <h2 class="text-3xl font-bold text-gray-900 mb-4">#{Map.get(content, "title", "My Journey")}</h2>
        <h3 class="text-xl text-gray-600 mb-8">#{Map.get(content, "subtitle", "")}</h3>

        <div class="prose prose-lg max-w-none">
          <div class="text-gray-700 leading-relaxed whitespace-pre-line">
            #{Map.get(content, "narrative", "")}
          </div>
        </div>
      </div>
    </section>
    """)
  end

  defp render_journey_section(section) do
    content = section.content || %{}
    milestones = Map.get(content, "milestones", [])

    Phoenix.HTML.raw("""
    <section class="py-16 bg-gradient-to-br from-blue-50 to-indigo-50">
      <div class="max-w-6xl mx-auto px-6">
        <h2 class="text-3xl font-bold text-gray-900 mb-4 text-center">#{Map.get(content, "title", "Professional Journey")}</h2>
        <p class="text-gray-600 text-center mb-12 text-lg">#{Map.get(content, "introduction", "")}</p>

        <div class="grid md:grid-cols-3 gap-8">
          #{Enum.map(milestones, fn milestone ->
            """
            <div class="bg-white rounded-lg p-6 shadow-lg">
              <h3 class="text-xl font-semibold text-gray-900 mb-3">#{Map.get(milestone, "title", "")}</h3>
              <p class="text-gray-600 mb-4">#{Map.get(milestone, "description", "")}</p>
              <div class="border-t pt-4">
                <p class="text-sm font-medium text-blue-600">Impact:</p>
                <p class="text-sm text-gray-700">#{Map.get(milestone, "impact", "")}</p>
              </div>
            </div>
            """
          end) |> Enum.join("")}
        </div>
      </div>
    </section>
    """)
  end

  # 🔥 ENHANCED HEADER CONTACT/SOCIAL DISPLAY COMPONENT
  defp render_header_contact_social(assigns) do
    contact_info = assigns[:contact_info] || %{}
    social_links = assigns[:social_links] || %{}

    ~H"""
    <div class="space-y-4">
      <!-- Contact Information -->
      <%= if map_size(contact_info) > 0 do %>
        <div class="space-y-2">
          <%= if Map.get(contact_info, :email) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-white bg-opacity-20 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                </svg>
              </div>
              <a href={"mailto:#{contact_info.email}"} class="text-white hover:text-pink-200 transition-colors font-medium">
                <%= contact_info.email %>
              </a>
            </div>
          <% end %>

          <%= if Map.get(contact_info, :phone) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-white bg-opacity-20 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                </svg>
              </div>
              <a href={"tel:#{contact_info.phone}"} class="text-white hover:text-pink-200 transition-colors font-medium">
                <%= contact_info.phone %>
              </a>
            </div>
          <% end %>

          <%= if Map.get(contact_info, :location) do %>
            <div class="flex items-center space-x-3">
              <div class="w-8 h-8 bg-white bg-opacity-20 rounded-lg flex items-center justify-center">
                <svg class="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"/>
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"/>
                </svg>
              </div>
              <span class="text-white font-medium">
                <%= contact_info.location %>
              </span>
            </div>
          <% end %>
        </div>
      <% end %>

      <!-- Social Links -->
      <%= if map_size(social_links) > 0 do %>
        <div class="pt-4 border-t border-white border-opacity-20">
          <div class="flex items-center space-x-4">
            <span class="text-sm font-medium text-pink-200">Connect:</span>
            <div class="flex space-x-3">
              <%= for {platform, url} <- social_links do %>
                <a href={url} target="_blank"
                   class="w-8 h-8 rounded-lg bg-white bg-opacity-20 hover:bg-opacity-30 flex items-center justify-center transition-all hover:scale-110"
                   title={String.capitalize(platform)}>
                  <%= render_social_icon(platform) %>
                </a>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # 🔥 ALSO ADD THIS ENHANCED DASHBOARD LAYOUT (replace existing one if it exists):
  defp render_dashboard_layout(assigns) do
    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <div class="min-h-screen portfolio-bg">

      <!-- Dashboard Header -->
      <header class="portfolio-header border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12"
            style={get_template_header_styling(@portfolio.theme)}>
          <div class="grid lg:grid-cols-3 gap-8 items-center">
            <div class="lg:col-span-2">
              <h1 class="text-4xl lg:text-5xl font-bold mb-4"
                  style="color: inherit;">
                <%= @portfolio.title %>
              </h1>
              <p class="text-xl mb-6" style="color: inherit; opacity: 0.8;">
                <%= @portfolio.description %>
              </p>

              <!-- Social Icons in Header -->
              <%= if @social_links && map_size(@social_links) > 0 do %>
                <div class="flex items-center space-x-4 mb-6">
                  <span class="text-sm font-medium" style="color: inherit; opacity: 0.7;">Connect:</span>
                  <%= for {platform, url} <- @social_links do %>
                    <a href={url} target="_blank"
                      class="w-10 h-10 rounded-full bg-black bg-opacity-10 hover:bg-opacity-20 flex items-center justify-center transition-all hover:scale-110">
                      <%= render_social_icon(platform) %>
                    </a>
                  <% end %>
                </div>
              <% end %>

              <!-- Contact Info in Header -->
              <%= if contact_section = Enum.find(@sections, fn s -> s.section_type == :contact end) do %>
                <div class="flex items-center space-x-6 mb-6">
                  <%= if email = get_in(contact_section.content, ["email"]) do %>
                    <div class="flex items-center space-x-2">
                      <svg class="w-4 h-4" style="color: inherit; opacity: 0.7;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                      </svg>
                      <a href={"mailto:#{email}"} class="text-sm hover:underline" style="color: inherit; opacity: 0.8;">
                        <%= email %>
                      </a>
                    </div>
                  <% end %>
                  <%= if phone = get_in(contact_section.content, ["phone"]) do %>
                    <div class="flex items-center space-x-2">
                      <svg class="w-4 h-4" style="color: inherit; opacity: 0.7;" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                      </svg>
                      <a href={"tel:#{phone}"} class="text-sm hover:underline" style="color: inherit; opacity: 0.8;">
                        <%= phone %>
                      </a>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Metrics -->
              <div class="grid grid-cols-3 gap-6">
                <div class="text-center">
                  <div class="text-3xl font-bold" style="color: inherit; opacity: 0.9;"><%= length(@sections) %></div>
                  <div class="text-sm" style="color: inherit; opacity: 0.6;">Sections</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold" style="color: inherit; opacity: 0.9;">
                    <%= @sections |> Enum.map(fn s -> length(Map.get(s, :media_files, [])) end) |> Enum.sum() %>
                  </div>
                  <div class="text-sm" style="color: inherit; opacity: 0.6;">Projects</div>
                </div>
                <div class="text-center">
                  <div class="text-3xl font-bold" style="color: inherit; opacity: 0.9;">Active</div>
                  <div class="text-sm" style="color: inherit; opacity: 0.6;">Status</div>
                </div>
              </div>
            </div>

            <!-- Video thumbnail in header if available -->
            <div class="lg:justify-self-end">
              <%= if @intro_video do %>
                <div class="relative w-64 h-48 bg-black rounded-xl overflow-hidden shadow-2xl cursor-pointer"
                    phx-click="show_video_modal">
                  <img src="/images/video-placeholder.jpg" alt="Video Introduction"
                      class="w-full h-full object-cover" />
                  <!-- Play overlay -->
                  <div class="absolute inset-0 bg-black bg-opacity-30 flex items-center justify-center hover:bg-opacity-50 transition-all">
                    <div class="w-12 h-12 bg-white bg-opacity-90 rounded-full flex items-center justify-center">
                      <svg class="w-4 h-4 text-gray-900 ml-0.5" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class="w-64 h-64 bg-gradient-to-br from-purple-600 to-blue-600 rounded-xl shadow-2xl flex items-center justify-center">
                  <span class="text-6xl font-bold text-white">
                    <%= String.first(@portfolio.title) %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Main Content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if length(@sections) > 0 do %>
          <div class="grid gap-6 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3">
            <%= for section <- @sections do %>
              <div id={"section-#{section.id}"} class="portfolio-card shadow-lg rounded-xl border p-6">
                <h2 class="text-xl font-bold portfolio-primary mb-4">
                  <%= section.title %>
                </h2>
                <div class="portfolio-secondary">
                  <%= render_section_content_safe(section) %>
                </div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-16">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">No sections yet</h3>
            <p class="text-gray-600">This portfolio is still being built.</p>
          </div>
        <% end %>
      </main>
    </div>

    <!-- Video Modal -->
    <%= if @show_video_modal && @intro_video do %>
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
            <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/mp4">
            <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/webm">
            Your browser does not support the video tag.
          </video>
        </div>
      </div>
    <% end %>
    """
  end

  # 🔥 ADD THIS ENHANCED TERMINAL LAYOUT:
  defp render_dashboard_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-gray-50">
      <!-- Dashboard Header -->
      <header class="bg-white shadow-sm border-b">
        <div class="max-w-7xl mx-auto px-6 py-4">
          <div class="flex items-center justify-between">
            <div>
              <h1 class="text-3xl font-bold text-gray-900">
                <%= @portfolio.title %>
              </h1>
              <p class="text-gray-600 mt-1">
                <%= @portfolio.description %>
              </p>
            </div>
            <div class="text-right">
              <span class="text-sm text-gray-500">Portfolio</span>
            </div>
          </div>
        </div>
      </header>

      <!-- Dashboard Content -->
      <main class="max-w-7xl mx-auto px-6 py-8">
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
          <!-- Main Content Area -->
          <div class="lg:col-span-2 space-y-8">
            <%= for section <- @sections do %>
              <section class="bg-white rounded-xl shadow-sm border p-6">
                <h2 class="text-xl font-semibold text-gray-900 mb-4">
                  <%= section.title %>
                </h2>
                <div class="prose max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </section>
            <% end %>
          </div>

          <!-- Sidebar -->
          <div class="space-y-6">
            <div class="bg-white rounded-xl shadow-sm border p-6">
              <h3 class="font-semibold text-gray-900 mb-4">Quick Info</h3>
              <div class="space-y-3 text-sm">
                <div class="flex justify-between">
                  <span class="text-gray-600">Sections:</span>
                  <span class="font-medium"><%= length(@sections) %></span>
                </div>
                <div class="flex justify-between">
                  <span class="text-gray-600">Layout:</span>
                  <span class="font-medium">Dashboard</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end



  defp render_theme_background_elements(assigns) do
    # Move theme detection to assigns
    assigns = assign(assigns, :current_theme, assigns.portfolio.theme || "executive")

    case assigns.current_theme do
      "developer" ->
        ~H"""
        <!-- Matrix-style background for developer theme -->
        <div class="absolute inset-0 opacity-10">
          <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-green-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse"></div>
          <div class="absolute top-1/3 right-1/4 w-72 h-72 bg-emerald-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 2s;"></div>
        </div>
        """
      "designer" ->
        ~H"""
        <!-- Creative shapes for designer theme -->
        <div class="absolute inset-0 opacity-20">
          <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-pink-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse"></div>
          <div class="absolute top-1/3 right-1/4 w-72 h-72 bg-purple-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 2s;"></div>
          <div class="absolute bottom-1/4 left-1/3 w-80 h-80 bg-rose-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 4s;"></div>
        </div>
        """
      "minimalist" ->
        ~H"""
        <!-- Simple geometric shapes for minimalist theme -->
        <div class="absolute inset-0 opacity-5">
          <div class="absolute top-1/4 right-1/4 w-32 h-32 bg-gray-400 transform rotate-45"></div>
          <div class="absolute bottom-1/4 left-1/4 w-24 h-24 bg-gray-500 rounded-full"></div>
        </div>
        """
      _ ->
        ~H"""
        <!-- Default animated background elements -->
        <div class="absolute inset-0 opacity-20">
          <div class="absolute top-1/4 left-1/4 w-64 h-64 bg-purple-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse"></div>
          <div class="absolute top-1/3 right-1/4 w-72 h-72 bg-blue-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 2s;"></div>
          <div class="absolute bottom-1/4 left-1/3 w-80 h-80 bg-indigo-400 rounded-full mix-blend-multiply filter blur-xl animate-pulse" style="animation-delay: 4s;"></div>
        </div>
        """
    end
  end

  # 🔥 NEW: Video stats cards
  defp render_video_stats_cards(assigns) do
    # Move calculations to assigns
    assigns = assigns
    |> assign(:formatted_duration, format_video_duration(assigns.video_duration))
    |> assign(:sections_count, length(assigns.sections))

    ~H"""
    <div class="grid grid-cols-3 gap-4">
      <div class={"backdrop-blur-xl rounded-xl p-4 border text-center #{@hero_classes.video_container}"}>
        <div class="text-2xl font-black text-yellow-400">
          <%= @formatted_duration %>
        </div>
        <div class={"text-xs font-medium opacity-70 #{@hero_classes.text_color}"}>Duration</div>
      </div>
      <div class={"backdrop-blur-xl rounded-xl p-4 border text-center #{@hero_classes.video_container}"}>
        <div class="text-2xl font-black text-pink-400">
          <%= @sections_count %>
        </div>
        <div class={"text-xs font-medium opacity-70 #{@hero_classes.text_color}"}>Sections</div>
      </div>
      <div class={"backdrop-blur-xl rounded-xl p-4 border text-center #{@hero_classes.video_container}"}>
        <div class="text-2xl font-black text-cyan-400">Active</div>
        <div class={"text-xs font-medium opacity-70 #{@hero_classes.text_color}"}>Status</div>
      </div>
    </div>
    """
  end

  # 🔥 NEW: Hero action buttons
  defp render_hero_action_buttons(assigns) do
    # Find contact section and add to assigns
    assigns = assign(assigns, :contact_section, Enum.find(assigns.sections, fn s -> s.section_type == :contact end))

    ~H"""
    <div class="flex flex-col sm:flex-row gap-4">
      <button onclick="document.getElementById('portfolio-sections').scrollIntoView({behavior: 'smooth'})"
              class={"px-8 py-4 backdrop-blur-xl rounded-2xl font-bold border transition-all duration-300 flex items-center justify-center group #{@hero_classes.video_container} #{@hero_classes.text_color}"}>
        <span>Explore Portfolio</span>
        <svg class="w-5 h-5 ml-2 group-hover:translate-x-1 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 8l4 4m0 0l-4 4m4-4H3"/>
        </svg>
      </button>

      <%= if @contact_section do %>
        <button onclick={"document.getElementById('section-#{@contact_section.id}').scrollIntoView({behavior: 'smooth'})"}
                class="px-8 py-4 bg-gradient-to-r from-purple-600 to-blue-600 rounded-2xl text-white font-bold hover:from-purple-700 hover:to-blue-700 transition-all duration-300 shadow-2xl">
          Get In Touch
        </button>
      <% end %>
    </div>
    """
  end

  defp render_skills_content_simple(content) do
    skill_categories = Map.get(content, "skill_categories", %{})
    flat_skills = Map.get(content, "skills", [])

    cond do
      map_size(skill_categories) > 0 ->
        categories_html = skill_categories
        |> Enum.take(3) # Limit for dashboard view
        |> Enum.map(fn {category, skills} ->
          skills_html = skills
          |> Enum.take(5)
          |> Enum.with_index()
          |> Enum.map(fn {skill, index} ->
            skill_name = case skill do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> to_string(skill)
            end

            color_class = get_skill_color_by_index(index)

            """
            <span class="inline-flex items-center px-2 py-1 #{color_class} text-xs font-medium rounded-full">
              #{skill_name}
            </span>
            """
          end)
          |> Enum.join("")

          """
          <div class="mb-3">
            <h4 class="text-sm font-semibold text-gray-700 mb-2">#{category}</h4>
            <div class="flex flex-wrap gap-1">
              #{skills_html}
            </div>
          </div>
          """
        end)
        |> Enum.join("")

        Phoenix.HTML.raw(categories_html)

      length(flat_skills) > 0 ->
        skills_html = flat_skills
        |> Enum.take(8) # Limit for dashboard view
        |> Enum.with_index()
        |> Enum.map(fn {skill, index} ->
          skill_name = case skill do
            %{"name" => name} -> name
            name when is_binary(name) -> name
            _ -> to_string(skill)
          end

          color_class = get_skill_color_by_index(index)

          """
          <span class="inline-flex items-center px-2 py-1 #{color_class} text-xs font-medium rounded-full">
            #{skill_name}
          </span>
          """
        end)
        |> Enum.join("")

        Phoenix.HTML.raw("""
        <div class="flex flex-wrap gap-1">
          #{skills_html}
        </div>
        """)

      true ->
        Phoenix.HTML.raw("""
        <div class="text-gray-500 italic text-sm">No skills added yet</div>
        """)
    end
  end

  defp render_section_content(section) do
    content = section.content || %{}

    case section.section_type do
      :text_content ->
        render_text_content(content)
      "text_content" ->
        render_text_content(content)
      :intro ->
        render_intro_content(content)
      "intro" ->
        render_intro_content(content)
      :experience ->
        render_experience_content(content)
      "experience" ->
        render_experience_content(content)
      :projects ->
        render_projects_content(content)
      "projects" ->
        render_projects_content(content)
      :skills ->
        render_skills_content(content)
      "skills" ->
        render_skills_content(content)
      :education ->
        render_education_content(content)
      "education" ->
        render_education_content(content)
      :contact ->
        render_contact_content(content)
      "contact" ->
        render_contact_content(content)
      :media_showcase ->
        render_media_content(content)
      "media_showcase" ->
        render_media_content(content)
      _ ->
        render_generic_content(content, section)
    end
  end

  # ============================================================================
  # Content renderers for different section types
  # ============================================================================

  defp render_text_content(content) do
    text = Map.get(content, "text", Map.get(content, "content", ""))
    if text != "", do: Phoenix.HTML.raw(text), else: Phoenix.HTML.raw("<p>No content available.</p>")
  end

  defp render_intro_content(content) do
    headline = Map.get(content, "headline", "")
    summary = Map.get(content, "summary", "")
    location = Map.get(content, "location", "")

    headline_html = if headline != "", do: "<h3 class='text-xl font-semibold mb-2'>#{headline}</h3>", else: ""
    summary_html = if summary != "", do: "<p class='text-gray-700 mb-4'>#{summary}</p>", else: ""
    location_html = if location != "", do: "<p class='text-sm text-gray-500'><i class='fas fa-map-marker-alt'></i> #{location}</p>", else: ""

    Phoenix.HTML.raw("""
    <div class="intro-section">
      #{headline_html}
      #{summary_html}
      #{location_html}
    </div>
    """)
  end

  defp render_experience_content(content) do
    experiences = Map.get(content, "experiences", Map.get(content, "jobs", []))

    if length(experiences) > 0 do
      experience_items = Enum.map(experiences, fn exp ->
        position = Map.get(exp, "position", Map.get(exp, "title", ""))
        company = Map.get(exp, "company", "")
        duration = Map.get(exp, "duration", "#{Map.get(exp, "start_date", "")} - #{Map.get(exp, "end_date", "Present")}")
        description = Map.get(exp, "description", "")

        company_html = if company != "", do: "<p class='text-blue-600 font-medium'>#{company}</p>", else: ""
        duration_html = if duration != "", do: "<p class='text-sm text-gray-600'>#{duration}</p>", else: ""
        description_html = if description != "", do: "<p class='mt-2 text-gray-700'>#{description}</p>", else: ""

        """
        <div class="border-l-4 border-blue-500 pl-4">
          <h4 class="font-semibold text-lg">#{position}</h4>
          #{company_html}
          #{duration_html}
          #{description_html}
        </div>
        """
      end)

      Phoenix.HTML.raw("""
      <div class="space-y-6">
        #{Enum.join(experience_items, "")}
      </div>
      """)
    else
      Phoenix.HTML.raw("<p>Experience details coming soon...</p>")
    end
  end

  defp render_projects_content(content) do
    projects = Map.get(content, "projects", [])

    if length(projects) > 0 do
      project_items = Enum.map(projects, fn project ->
        name = Map.get(project, "name", Map.get(project, "title", ""))
        description = Map.get(project, "description", "")
        technologies = Map.get(project, "technologies", [])
        url = Map.get(project, "url", Map.get(project, "demo_url", ""))
        github = Map.get(project, "github_url", "")

        description_html = if description != "", do: "<p class='text-gray-600 mb-4'>#{description}</p>", else: ""

        # Handle technologies safely
        tech_html = if length(technologies) > 0 do
          tech_spans = Enum.map(technologies, fn tech ->
            "<span class='px-2 py-1 bg-blue-100 text-blue-800 rounded text-sm'>#{tech}</span>"
          end)
          "<div class='flex flex-wrap gap-2 mb-4'>#{Enum.join(tech_spans, "")}</div>"
        else
          ""
        end

        # Handle links safely
        url_link = if url != "", do: "<a href='#{url}' class='text-blue-600 hover:underline text-sm'>View Project</a>", else: ""
        github_link = if github != "", do: "<a href='#{github}' class='text-gray-600 hover:underline text-sm'>GitHub</a>", else: ""
        links_html = if url_link != "" or github_link != "" do
          "<div class='flex gap-2'>#{url_link}#{github_link}</div>"
        else
          ""
        end

        """
        <div class="bg-gray-50 rounded-lg p-6">
          <h4 class="font-semibold text-lg mb-2">#{name}</h4>
          #{description_html}
          #{tech_html}
          #{links_html}
        </div>
        """
      end)

      Phoenix.HTML.raw("""
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        #{Enum.join(project_items, "")}
      </div>
      """)
    else
      Phoenix.HTML.raw("<p>Projects coming soon...</p>")
    end
  end

  defp render_skills_content(content) do
    skills = Map.get(content, "skills", [])
    skill_categories = Map.get(content, "skill_categories", %{})

    cond do
      map_size(skill_categories) > 0 ->
        category_items = Enum.map(skill_categories, fn {category, category_skills} ->
          skill_spans = Enum.map(category_skills, fn skill ->
            skill_name = case skill do
              %{"name" => name} -> name
              skill_string -> skill_string
            end

            proficiency = case skill do
              %{"proficiency" => prof} -> prof
              _ -> ""
            end

            proficiency_class = case proficiency do
              "expert" -> "bg-green-100 text-green-800"
              "advanced" -> "bg-blue-100 text-blue-800"
              "intermediate" -> "bg-yellow-100 text-yellow-800"
              "beginner" -> "bg-gray-100 text-gray-800"
              _ -> "bg-blue-100 text-blue-800"
            end

            "<span class='px-3 py-1 #{proficiency_class} rounded-full text-sm font-medium'>#{skill_name}</span>"
          end)

          """
          <div>
            <h4 class="font-semibold text-lg mb-3">#{category}</h4>
            <div class="flex flex-wrap gap-2">
              #{Enum.join(skill_spans, "")}
            </div>
          </div>
          """
        end)

        Phoenix.HTML.raw("""
        <div class="space-y-6">
          #{Enum.join(category_items, "")}
        </div>
        """)

      length(skills) > 0 ->
        skill_spans = Enum.map(skills, fn skill ->
          skill_name = case skill do
            %{"name" => name} -> name
            skill_string -> skill_string
          end
          "<span class='px-3 py-1 bg-blue-100 text-blue-800 rounded-full text-sm font-medium'>#{skill_name}</span>"
        end)

        Phoenix.HTML.raw("""
        <div class="flex flex-wrap gap-2">
          #{Enum.join(skill_spans, "")}
        </div>
        """)

      true ->
        Phoenix.HTML.raw("<p>Skills information coming soon...</p>")
    end
  end

  defp render_education_content(content) do
    education = Map.get(content, "education", [])

    if length(education) > 0 do
      education_items = Enum.map(education, fn edu ->
        degree = Map.get(edu, "degree", "")
        field = Map.get(edu, "field", "")
        institution = Map.get(edu, "institution", "")
        year = Map.get(edu, "year", Map.get(edu, "end_date", ""))

        degree_with_field = if field != "", do: "#{degree} in #{field}", else: degree
        institution_html = if institution != "", do: "<p class='text-green-600 font-medium'>#{institution}</p>", else: ""
        year_html = if year != "", do: "<p class='text-sm text-gray-600'>#{year}</p>", else: ""

        """
        <div class="border-l-4 border-green-500 pl-4">
          <h4 class="font-semibold">#{degree_with_field}</h4>
          #{institution_html}
          #{year_html}
        </div>
        """
      end)

      Phoenix.HTML.raw("""
      <div class="space-y-4">
        #{Enum.join(education_items, "")}
      </div>
      """)
    else
      Phoenix.HTML.raw("<p>Education details coming soon...</p>")
    end
  end

  defp render_contact_content(content) do
    email = Map.get(content, "email", "")
    phone = Map.get(content, "phone", "")
    linkedin = Map.get(content, "linkedin", "")
    website = Map.get(content, "website", "")

    email_html = if email != "", do: "<p><strong>Email:</strong> <a href='mailto:#{email}' class='text-blue-600'>#{email}</a></p>", else: ""
    phone_html = if phone != "", do: "<p><strong>Phone:</strong> <a href='tel:#{phone}' class='text-blue-600'>#{phone}</a></p>", else: ""
    linkedin_html = if linkedin != "", do: "<p><strong>LinkedIn:</strong> <a href='#{linkedin}' class='text-blue-600' target='_blank'>#{linkedin}</a></p>", else: ""
    website_html = if website != "", do: "<p><strong>Website:</strong> <a href='#{website}' class='text-blue-600' target='_blank'>#{website}</a></p>", else: ""

    Phoenix.HTML.raw("""
    <div class="bg-blue-50 rounded-lg p-6">
      <h4 class="font-semibold text-lg mb-4">Get In Touch</h4>
      <div class="space-y-2">
        #{email_html}
        #{phone_html}
        #{linkedin_html}
        #{website_html}
      </div>
    </div>
    """)
  end

  defp render_media_content(content) do
    media_files = Map.get(content, "media_files", [])
    description = Map.get(content, "description", "")

    description_html = if description != "", do: "<p class='text-gray-700 mb-6'>#{description}</p>", else: ""

    media_html = if length(media_files) > 0 do
      media_items = Enum.map(media_files, fn media ->
        web_path = Map.get(media, "web_path", "")
        filename = Map.get(media, "original_filename", "Media file")
        content_type = Map.get(media, "content_type", "")

        cond do
          String.starts_with?(content_type, "image/") ->
            "<img src='#{web_path}' alt='#{filename}' class='rounded-lg shadow-sm w-full h-48 object-cover'>"
          String.starts_with?(content_type, "video/") ->
            """
            <video controls class='rounded-lg shadow-sm w-full h-48'>
              <source src='#{web_path}' type='#{content_type}'>
            </video>
            """
          true ->
            """
            <div class='bg-gray-100 rounded-lg p-4 text-center h-48 flex items-center justify-center'>
              <div>
                <p class='text-sm text-gray-600'>#{filename}</p>
                <a href='#{web_path}' class='text-blue-600 text-sm hover:underline'>Download</a>
              </div>
            </div>
            """
        end
      end)

      """
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        #{Enum.join(media_items, "")}
      </div>
      """
    else
      "<p>No media files uploaded yet.</p>"
    end

    Phoenix.HTML.raw("""
    <div>
      #{description_html}
      #{media_html}
    </div>
    """)
  end

  defp render_generic_content(content, section) do
    cond do
      Map.has_key?(content, "text") and Map.get(content, "text") != "" ->
        Phoenix.HTML.raw(Map.get(content, "text"))

      Map.has_key?(content, "content") and Map.get(content, "content") != "" ->
        Phoenix.HTML.raw(Map.get(content, "content"))

      Map.has_key?(content, "body") and Map.get(content, "body") != "" ->
        Phoenix.HTML.raw(Map.get(content, "body"))

      map_size(content) > 0 ->
        content_keys = Enum.join(Map.keys(content), ", ")
        content_inspect = inspect(content, pretty: true)

        Phoenix.HTML.raw("""
        <div class="bg-gray-50 rounded p-4">
          <p class="text-sm text-gray-600 mb-2">Section Type: #{section.section_type}</p>
          <p class="text-sm text-gray-500">Content keys: #{content_keys}</p>
          <details class="mt-2">
            <summary class="cursor-pointer text-sm text-blue-600">Show Raw Content</summary>
            <pre class="text-xs mt-2 bg-white p-2 rounded border overflow-auto">#{content_inspect}</pre>
          </details>
        </div>
        """)

      true ->
        Phoenix.HTML.raw("<p class='text-gray-500 italic'>No content available for this section.</p>")
    end
  end

  defp render_section_content_safe(section) do
    try do
      content = section.content || %{}

      # Simple content extraction that works with your existing data
      case normalize_section_type_simple(section.section_type) do
        :intro ->
          render_intro_simple(content)
        :experience ->
          render_experience_simple(content)
        :education ->
          render_education_simple(content)
        :skills ->
          render_skills_simple(content)
        :projects ->
          render_projects_simple(content)
        :featured_project ->
          render_featured_project_simple(content)
        :achievements ->
          render_achievements_simple(content)
        :case_study ->
          render_case_study_simple(content)
        :testimonial ->
          render_testimonial_simple(content)
        :contact ->
          render_contact_simple(content)
        _ ->
          render_generic_simple(content)
      end
    rescue
      _ ->
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Loading content...</p>")
    end
  end

  defp render_intro_simple(content) do
    headline = get_simple_value(content, ["headline", "title"])
    summary = get_simple_value(content, ["summary", "description", "bio"])
    location = get_simple_value(content, ["location"])

    parts = []
    parts = if headline != "", do: parts ++ ["<h3 class=\"text-lg font-semibold mb-2\">#{Phoenix.HTML.html_escape(headline)}</h3>"], else: parts
    parts = if summary != "", do: parts ++ ["<p class=\"mb-3\">#{Phoenix.HTML.html_escape(summary)}</p>"], else: parts
    parts = if location != "", do: parts ++ ["<p class=\"text-sm\">📍 #{Phoenix.HTML.html_escape(location)}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Introduction content...</p>")
    end
  end

  defp render_experience_simple(content) do
    jobs = get_simple_value(content, ["jobs", "experiences"])

    if is_list(jobs) and length(jobs) > 0 do
      job_html = Enum.take(jobs, 3) |> Enum.map(fn job ->
        title = get_simple_value(job, ["title", "position"])
        company = get_simple_value(job, ["company", "organization"])

        """
        <div class="mb-3">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(title)}</div>
          <div class="text-sm text-gray-600">#{Phoenix.HTML.html_escape(company)}</div>
        </div>
        """
      end) |> Enum.join("")

      Phoenix.HTML.raw(job_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Experience details...</p>")
    end
  end

  defp render_education_simple(content) do
    education = get_simple_value(content, ["education", "degrees"])

    if is_list(education) and length(education) > 0 do
      edu_html = Enum.take(education, 2) |> Enum.map(fn edu ->
        degree = get_simple_value(edu, ["degree", "title"])
        school = get_simple_value(edu, ["school", "institution"])

        """
        <div class="mb-2">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(degree)}</div>
          <div class="text-sm text-gray-600">#{Phoenix.HTML.html_escape(school)}</div>
        </div>
        """
      end) |> Enum.join("")

      Phoenix.HTML.raw(edu_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Education details...</p>")
    end
  end

  defp render_skills_simple(content) do
    skills = get_simple_value(content, ["skills"])

    if is_list(skills) and length(skills) > 0 do
      skills_html = Enum.take(skills, 8) |> Enum.map(fn skill ->
        skill_name = if is_binary(skill), do: skill, else: to_string(skill)
        "<span class=\"inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded mr-2 mb-1\">#{Phoenix.HTML.html_escape(skill_name)}</span>"
      end) |> Enum.join("")

      Phoenix.HTML.raw("<div class=\"flex flex-wrap\">#{skills_html}</div>")
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Skills list...</p>")
    end
  end

  defp render_projects_simple(content) do
    projects = get_simple_value(content, ["projects"])

    if is_list(projects) and length(projects) > 0 do
      project_html = Enum.take(projects, 2) |> Enum.map(fn project ->
        title = get_simple_value(project, ["title", "name"])
        description = get_simple_value(project, ["description", "summary"])

        """
        <div class="mb-2">
          <div class="font-semibold">#{Phoenix.HTML.html_escape(title)}</div>
          #{if description != "", do: "<p class=\"text-sm text-gray-600\">#{Phoenix.HTML.html_escape(String.slice(description, 0, 80))}...</p>", else: ""}
        </div>
        """
      end) |> Enum.join("")

      more_text = if length(projects) > 2, do: "<p class=\"text-xs text-gray-500\">+#{length(projects) - 2} more projects</p>", else: ""

      Phoenix.HTML.raw(project_html <> more_text)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Project showcase...</p>")
    end
  end

  defp render_featured_project_simple(content) do
    title = get_simple_value(content, ["title", "name"])
    description = get_simple_value(content, ["description", "summary"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if description != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(description)}</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Featured project details...</p>")
    end
  end

  defp render_achievements_simple(content) do
    achievements = get_simple_value(content, ["achievements", "awards"])

    if is_list(achievements) and length(achievements) > 0 do
      achievements_html = Enum.take(achievements, 3) |> Enum.map(fn achievement ->
        title = if is_binary(achievement), do: achievement, else: to_string(achievement)
        "<div class=\"flex items-center mb-1\"><span class=\"mr-2\">🏆</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(title)}</span></div>"
      end) |> Enum.join("")

      Phoenix.HTML.raw(achievements_html)
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Achievements and awards...</p>")
    end
  end

  defp render_case_study_simple(content) do
    title = get_simple_value(content, ["title"])
    overview = get_simple_value(content, ["overview", "summary"])

    parts = []
    parts = if title != "", do: parts ++ ["<h3 class=\"font-semibold mb-2\">#{Phoenix.HTML.html_escape(title)}</h3>"], else: parts
    parts = if overview != "", do: parts ++ ["<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(overview, 0, 120))}...</p>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Case study details...</p>")
    end
  end

  defp render_testimonial_simple(content) do
    testimonials = get_simple_value(content, ["testimonials"])

    if is_list(testimonials) and length(testimonials) > 0 do
      testimonial = List.first(testimonials)
      quote = get_simple_value(testimonial, ["quote", "text"])
      author = get_simple_value(testimonial, ["author", "name"])

      if quote != "" do
        Phoenix.HTML.raw("""
        <blockquote class="italic text-gray-600 border-l-4 border-blue-500 pl-4">
          "#{Phoenix.HTML.html_escape(String.slice(quote, 0, 100))}..."
          #{if author != "", do: "<cite class=\"block text-sm text-gray-500 mt-1\">— #{Phoenix.HTML.html_escape(author)}</cite>", else: ""}
        </blockquote>
        """)
      else
        Phoenix.HTML.raw("<p class=\"text-gray-400\">Client testimonial...</p>")
      end
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Client testimonials...</p>")
    end
  end

  defp render_contact_simple(content) do
    email = get_simple_value(content, ["email"])
    phone = get_simple_value(content, ["phone"])
    location = get_simple_value(content, ["location"])

    parts = []
    parts = if email != "", do: parts ++ ["<div class=\"flex items-center mb-1\"><span class=\"mr-2\">📧</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(email)}</span></div>"], else: parts
    parts = if phone != "", do: parts ++ ["<div class=\"flex items-center mb-1\"><span class=\"mr-2\">📞</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(phone)}</span></div>"], else: parts
    parts = if location != "", do: parts ++ ["<div class=\"flex items-center mb-1\"><span class=\"mr-2\">📍</span><span class=\"text-sm\">#{Phoenix.HTML.html_escape(location)}</span></div>"], else: parts

    if length(parts) > 0 do
      Phoenix.HTML.raw(Enum.join(parts, ""))
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Contact information...</p>")
    end
  end

  defp render_generic_simple(content) do
    # Try to find any meaningful content
    description = get_simple_value(content, ["description", "summary", "content", "text"])

    if description != "" do
      Phoenix.HTML.raw("<p class=\"text-sm\">#{Phoenix.HTML.html_escape(String.slice(description, 0, 150))}#{if String.length(description) > 150, do: "...", else: ""}</p>")
    else
      Phoenix.HTML.raw("<p class=\"text-gray-400\">Section content...</p>")
    end
  end

  # Simple helper functions
  defp get_simple_value(content, keys) when is_list(keys) do
    Enum.find_value(keys, "", fn key ->
      case Map.get(content, key) do
        nil -> nil
        "" -> nil
        value when is_binary(value) -> String.trim(value)
        value when is_list(value) -> value
        value when is_map(value) -> value
        value -> to_string(value)
      end
    end)
  end

  defp get_simple_value(content, key) when is_binary(key) do
    get_simple_value(content, [key])
  end

  defp normalize_section_type_simple(type) when is_atom(type), do: type
  defp normalize_section_type_simple(type) when is_binary(type), do: String.to_atom(type)
  defp normalize_section_type_simple(_), do: :generic

  defp render_story_content_enhanced(content) do
    chapters = Map.get(content, "chapters", [])
    narrative = Map.get(content, "narrative", "")

    Phoenix.HTML.raw("""
    <div class="story-section space-y-6">
      #{if narrative != "", do: """
      <div class="prose prose-sm max-w-none">
        <p class="text-gray-600 leading-relaxed">#{narrative}</p>
      </div>
      """, else: ""}

      <div class="space-y-4">
        #{Enum.map(chapters, fn chapter ->
          """
          <div class="flex items-start space-x-4 p-4 bg-purple-50 rounded-lg">
            <div class="flex-shrink-0 w-10 h-10 bg-purple-100 rounded-full flex items-center justify-center">
              <span class="text-purple-600 font-semibold text-sm">#{Map.get(chapter, "year", "")}</span>
            </div>
            <div class="flex-1 min-w-0">
              <h4 class="font-semibold text-gray-900 text-sm mb-1">#{Map.get(chapter, "title", "")}</h4>
              <p class="text-gray-600 text-sm leading-relaxed">#{Map.get(chapter, "content", "")}</p>
            </div>
          </div>
          """
        end) |> Enum.join("")}
      </div>
    </div>
    """)
  end

  defp render_timeline_content_enhanced(content) do
    events = Map.get(content, "events", [])
    description = Map.get(content, "description", "")

    Phoenix.HTML.raw("""
    <div class="timeline-section">
      #{if description != "", do: """
      <p class="text-gray-600 text-sm mb-4">#{description}</p>
      """, else: ""}

      <div class="space-y-3 relative">
        <div class="absolute left-3 top-0 bottom-0 w-0.5 bg-blue-200"></div>

        #{Enum.map(events, fn event ->
          """
          <div class="relative flex items-start">
            <div class="absolute left-2 w-2 h-2 bg-blue-500 rounded-full mt-2"></div>
            <div class="ml-6">
              <div class="text-xs text-blue-600 font-semibold">#{Map.get(event, "date", "")}</div>
              <h4 class="font-semibold text-gray-900 text-sm">#{Map.get(event, "title", "")}</h4>
              <p class="text-gray-600 text-sm">#{Map.get(event, "description", "")}</p>
            </div>
          </div>
          """
        end) |> Enum.join("")}
      </div>
    </div>
    """)
  end

  defp render_narrative_content_enhanced(content) do
    narrative = Map.get(content, "narrative", "")
    subtitle = Map.get(content, "subtitle", "")

    Phoenix.HTML.raw("""
    <div class="narrative-section space-y-4">
      #{if subtitle != "", do: """
      <h3 class="text-lg font-semibold text-gray-900">#{subtitle}</h3>
      """, else: ""}

      <div class="prose prose-sm max-w-none">
        <div class="text-gray-700 leading-relaxed whitespace-pre-line">#{narrative}</div>
      </div>
    </div>
    """)
  end

  defp render_journey_content_enhanced(content) do
    milestones = Map.get(content, "milestones", [])
    introduction = Map.get(content, "introduction", "")

    Phoenix.HTML.raw("""
    <div class="journey-section space-y-4">
      #{if introduction != "", do: """
      <p class="text-gray-600 text-sm">#{introduction}</p>
      """, else: ""}

      <div class="grid gap-3">
        #{Enum.map(milestones, fn milestone ->
          """
          <div class="bg-blue-50 rounded-lg p-4">
            <h4 class="font-semibold text-gray-900 text-sm mb-2">#{Map.get(milestone, "title", "")}</h4>
            <p class="text-gray-600 text-sm mb-2">#{Map.get(milestone, "description", "")}</p>
            <div class="border-t border-blue-200 pt-2">
              <p class="text-xs font-medium text-blue-600">Impact:</p>
              <p class="text-xs text-blue-800">#{Map.get(milestone, "impact", "")}</p>
            </div>
          </div>
          """
        end) |> Enum.join("")}
      </div>
    </div>
    """)
  end

  defp render_education_content_simple(content) do
    education = Map.get(content, "education", [])

    if length(education) > 0 do
      education_html = education
      |> Enum.take(2) # Limit for dashboard view
      |> Enum.map(fn edu ->
        degree = get_safe_value(edu, ["degree"], "Degree")
        institution = get_safe_value(edu, ["institution"], "Institution")
        field = get_safe_value(edu, ["field"], "")

        """
        <div class="mb-3">
          <h4 class="font-semibold text-gray-900 text-sm">#{degree}</h4>
          <p class="text-xs text-gray-600">#{institution}</p>
          #{if field != "", do: "<p class=\"text-xs text-gray-500\">#{field}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      Phoenix.HTML.raw(education_html)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No education added yet</div>
      """)
    end
  end

  defp render_experience_content_simple(content) do
    jobs = Map.get(content, "jobs", [])

    if length(jobs) > 0 do
      jobs_html = jobs
      |> Enum.take(2) # Limit for dashboard view
      |> Enum.map(fn job ->
        title = get_safe_value(job, ["title"], "Position")
        company = get_safe_value(job, ["company"], "Company")
        current = get_safe_value(job, ["current"], false)
        description = get_safe_value(job, ["description"], "")

        current_badge = if current, do: " • <span class=\"text-green-600 text-xs\">Current</span>", else: ""

        """
        <div class="mb-3 pb-3 border-b border-gray-100 last:border-b-0">
          <h4 class="font-semibold text-gray-900 text-sm">#{title}</h4>
          <p class="text-xs text-gray-600">#{company}#{current_badge}</p>
          #{if String.length(description) > 0, do: "<p class=\"text-xs text-gray-700 mt-1 line-clamp-2\">#{String.slice(description, 0, 100)}#{if String.length(description) > 100, do: "...", else: ""}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      Phoenix.HTML.raw(jobs_html)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No experience added yet</div>
      """)
    end
  end

  defp render_contact_content_simple(content) do
    email = get_safe_value(content, ["email", "primary_email"], "")
    phone = get_safe_value(content, ["phone"], "")
    location = get_safe_value(content, ["location"], "")

    contact_items = []
    contact_items = if email != "", do: contact_items ++ ["📧 #{email}"], else: contact_items
    contact_items = if phone != "", do: contact_items ++ ["📞 #{phone}"], else: contact_items
    contact_items = if location != "", do: contact_items ++ ["📍 #{location}"], else: contact_items

    if length(contact_items) > 0 do
      contact_html = contact_items
      |> Enum.map(fn item -> "<p class=\"text-sm text-gray-700 mb-1\">#{item}</p>" end)
      |> Enum.join("")

      Phoenix.HTML.raw(contact_html)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Contact information will be displayed here</div>
      """)
    end
  end

  defp render_intro_content_simple(content) do
    summary = get_safe_value(content, ["summary", "headline", "description"], "")

    if summary != "" do
      truncated_summary = if String.length(summary) > 150 do
        String.slice(summary, 0, 150) <> "..."
      else
        summary
      end

      Phoenix.HTML.raw("""
      <div class="text-gray-700 leading-relaxed">
        <p>#{truncated_summary}</p>
      </div>
      """)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Introduction content will be displayed here</div>
      """)
    end
  end

  defp render_projects_content_simple(content) do
    projects = Map.get(content, "projects", [])

    if length(projects) > 0 do
      projects_html = projects
      |> Enum.take(2)
      |> Enum.map(fn project ->
        title = get_safe_value(project, ["title"], "Project")
        description = get_safe_value(project, ["description"], "")

        """
        <div class="mb-3">
          <h4 class="font-semibold text-gray-900 text-sm">#{title}</h4>
          #{if description != "", do: "<p class=\"text-xs text-gray-600 line-clamp-2\">#{String.slice(description, 0, 80)}#{if String.length(description) > 80, do: "...", else: ""}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      count_text = "<p class=\"text-xs text-gray-500 mb-3\">#{length(projects)} project#{if length(projects) != 1, do: "s", else: ""} showcased</p>"

      Phoenix.HTML.raw(count_text <> projects_html)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No projects added yet</div>
      """)
    end
  end

  defp render_generic_content_simple(content) do
    text = get_safe_value(content, ["description", "summary", "content"], "")

    if text != "" do
      truncated_text = if String.length(text) > 100 do
        String.slice(text, 0, 100) <> "..."
      else
        text
      end

      Phoenix.HTML.raw("""
      <div class="text-gray-700 leading-relaxed">
        <p>#{truncated_text}</p>
      </div>
      """)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Content will be displayed here</div>
      """)
    end
  end

  # Helper function for safe value extraction
  defp get_safe_value(data, keys, default) when is_list(keys) do
    Enum.find_value(keys, default, fn key ->
      case Map.get(data, key) do
        nil -> nil
        "" -> nil
        value -> value
      end
    end)
  end

  defp get_safe_value(data, key, default) when is_binary(key) do
    case Map.get(data, key, default) do
      "" -> default
      nil -> default
      value -> value
    end
  end

  # Color coding for skills
  defp get_skill_color_by_index(index) do
    colors = [
      "bg-blue-100 text-blue-800",
      "bg-purple-100 text-purple-800",
      "bg-green-100 text-green-800",
      "bg-orange-100 text-orange-800",
      "bg-pink-100 text-pink-800",
      "bg-indigo-100 text-indigo-800",
      "bg-red-100 text-red-800",
      "bg-teal-100 text-teal-800"
    ]

    Enum.at(colors, rem(index, length(colors)))
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
    # 🔥 FIX: Use actual theme to determine layout instead of defaulting to dashboard
    case theme do
      "executive" -> "executive"
      "developer" -> "developer"
      "designer" -> "designer"
      "consultant" -> "consultant"
      "academic" -> "academic"
      "creative" -> "creative"
      "minimalist" -> "minimalist"
      "corporate" -> "corporate"
      _ -> "executive"                # Default fallback
    end
  end

  defp extract_intro_video_and_filter_sections(sections) when is_list(sections) do
    # This is the same as separate_video_intro_and_sections but with different name
    separate_video_intro_and_sections(sections)
  end

  defp extract_intro_video_and_filter_sections(_), do: {nil, []}

  # 🔥 FIX: Get template-specific CSS classes
  defp get_template_specific_classes(theme) do
    case theme do
      "executive" ->
        """
        /* Executive Theme Styles */
        .portfolio-bg {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .hero-section {
          background: var(--primary-color);
          color: white;
        }
        .section-card {
          background: white;
          border-radius: 12px;
          box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
        }
        """

      "developer" ->
        """
        /* Developer Theme Styles */
        body {
          font-family: 'JetBrains Mono', 'Monaco', 'Menlo', monospace;
          background-color: #0f172a;
          color: #e2e8f0;
        }
        .portfolio-bg {
          background-color: #0f172a;
          color: #e2e8f0;
        }
        .hero-section {
          background: #1e293b;
          border: 1px solid #334155;
        }
        .section-card {
          background: #1e293b;
          border: 1px solid #334155;
          color: #e2e8f0;
        }
        .text-primary { color: #10b981; }
        .terminal-prompt::before {
          content: "$ ";
          color: #10b981;
        }
        """

      "designer" ->
        """
        /* Designer Theme Styles */
        body {
          font-family: 'Inter', system-ui, sans-serif;
        }
        .portfolio-bg {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        .hero-section {
          background: linear-gradient(45deg, #7c3aed, #ec4899);
          color: white;
        }
        .section-card {
          background: white;
          border-radius: 20px;
          box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
          border: 2px solid transparent;
          background-clip: padding-box;
        }
        .section-card:hover {
          transform: translateY(-4px);
          transition: transform 0.3s ease;
        }
        """

      "minimalist" ->
        """
        /* Minimalist Theme Styles */
        body {
          font-family: 'Inter', system-ui, sans-serif;
        }
        .portfolio-bg {
          background-color: #ffffff;
          color: #111827;
        }
        .hero-section {
          background: #ffffff;
          color: #111827;
          border-bottom: 1px solid #e5e7eb;
        }
        .section-card {
          background: #ffffff;
          border: 1px solid #e5e7eb;
          border-radius: 8px;
        }
        h1, h2, h3 { font-weight: 400; }
        .minimal-line {
          height: 1px;
          background: #e5e7eb;
          margin: 2rem 0;
        }
        """

      "consultant" ->
        """
        /* Consultant Theme Styles */
        body {
          font-family: 'Inter', system-ui, sans-serif;
        }
        .portfolio-bg {
          background-color: #f9fafb;
        }
        .hero-section {
          background: linear-gradient(135deg, #0891b2 0%, #0284c7 100%);
          color: white;
        }
        .section-card {
          background: white;
          border-radius: 12px;
          box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
          border-left: 4px solid var(--primary-color);
        }
        .stats-grid {
          display: grid;
          grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
          gap: 1.5rem;
        }
        """

      "academic" ->
        """
        /* Academic Theme Styles */
        body {
          font-family: 'Crimson Text', Georgia, serif;
          line-height: 1.7;
        }
        .portfolio-bg {
          background-color: #fefefe;
          color: #374151;
        }
        .hero-section {
          background: #059669;
          color: white;
        }
        .section-card {
          background: white;
          border: 1px solid #d1d5db;
          border-radius: 8px;
        }
        h1, h2, h3 {
          font-family: 'Crimson Text', Georgia, serif;
          font-weight: 600;
        }
        .academic-citation {
          font-style: italic;
          color: #6b7280;
        }
        """

      _ ->
        """
        /* Default Theme Styles */
        body {
          font-family: system-ui, -apple-system, sans-serif;
        }
        .portfolio-bg {
          background-color: #ffffff;
        }
        .section-card {
          background: white;
          border-radius: 8px;
          box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1);
        }
        """
    end
  end

  # 🔥 FIX: Get template background CSS (used by get_theme_specific_css)
  defp get_template_background_css(theme, customization) do
    base_bg = Map.get(customization, "background_color", "#ffffff")

    case theme do
      "developer" -> "#0f172a"
      "designer" -> "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
      "minimalist" -> "#ffffff"
      "consultant" -> "#f9fafb"
      "academic" -> "#fefefe"
      "executive" -> base_bg
      _ -> base_bg
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
      "executive" ->
        """
        background: linear-gradient(135deg, rgba(248, 250, 252, 0.95) 0%, rgba(226, 232, 240, 0.95) 100%);
        backdrop-filter: blur(12px);
        border-bottom: 1px solid rgba(59, 130, 246, 0.2);
        color: #1e293b;
        """
      "developer" ->
        """
        background: linear-gradient(135deg, rgba(31, 41, 55, 0.95) 0%, rgba(17, 24, 39, 0.95) 100%);
        backdrop-filter: blur(12px);
        border-bottom: 1px solid rgba(16, 185, 129, 0.3);
        color: #f9fafb;
        """
      "designer" ->
        """
        background: linear-gradient(135deg, rgba(139, 92, 246, 0.15) 0%, rgba(219, 39, 119, 0.15) 100%);
        backdrop-filter: blur(16px);
        border-bottom: 1px solid rgba(255, 255, 255, 0.2);
        color: #ffffff;
        """
      "consultant" ->
        """
        background: linear-gradient(135deg, rgba(227, 242, 253, 0.95) 0%, rgba(243, 229, 245, 0.95) 100%);
        backdrop-filter: blur(8px);
        border-bottom: 1px solid rgba(59, 130, 246, 0.3);
        color: #1f2937;
        """
      "academic" ->
        """
        background: linear-gradient(135deg, rgba(240, 249, 255, 0.95) 0%, rgba(236, 253, 245, 0.95) 100%);
        backdrop-filter: blur(8px);
        border-bottom: 1px solid rgba(16, 185, 129, 0.2);
        color: #374151;
        """
      "minimalist" ->
        """
        background: rgba(255, 255, 255, 0.98);
        backdrop-filter: blur(8px);
        border-bottom: 1px solid rgba(229, 231, 235, 0.8);
        color: #111827;
        """
      _ ->
        """
        background: rgba(255, 255, 255, 0.95);
        backdrop-filter: blur(8px);
        border-bottom: 1px solid rgba(229, 231, 235, 0.5);
        color: #374151;
        """
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
      "public" -> true
      "link_only" -> true
      "private" -> false
      _ -> false
    end
  end

  # EVENT HANDLERS

  # PATCH: Add missing event handlers
    @impl true
    def handle_event("show_video_modal", _params, socket) do
      IO.puts("=== SHOW VIDEO MODAL EVENT RECEIVED ===")
      {:noreply, assign(socket, :show_video_modal, true)}
    end

    @impl true
    def handle_event("hide_video_modal", _params, socket) do
      IO.puts("=== HIDE VIDEO MODAL EVENT RECEIVED ===")
      {:noreply, assign(socket, :show_video_modal, false)}
    end

  @impl true
  def handle_event("toggle_mobile_nav", _params, socket) do
    {:noreply, assign(socket, :show_mobile_nav, !socket.assigns.show_mobile_nav)}
  end

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

    defp render_enhanced_video_modal(assigns) do
    ~H"""
    <%= if @show_video_modal && @intro_video do %>
      <div class="fixed inset-0 z-50 overflow-hidden bg-black bg-opacity-90 backdrop-blur-sm"
           phx-click="hide_video_modal">
        <div class="flex items-center justify-center min-h-screen p-4">

          <!-- Close Button -->
          <button phx-click="hide_video_modal"
                  class="absolute top-6 right-6 z-60 p-3 bg-white bg-opacity-20 hover:bg-opacity-30 rounded-full text-white transition-all duration-200 group">
            <svg class="w-6 h-6 group-hover:scale-110 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </button>

          <!-- Video Container -->
          <div class="relative max-w-6xl w-full max-h-[90vh] bg-black rounded-2xl overflow-hidden shadow-2xl"
               phx-click-away="hide_video_modal">

            <!-- Video Player -->
            <video controls autoplay
                   class="w-full h-auto max-h-[90vh] object-contain"
                   poster="/images/video-poster.jpg">
              <source src={get_video_url(@intro_video)} type="video/mp4">
              <source src={get_video_url(@intro_video)} type="video/webm">
              <p class="text-white p-8 text-center">
                Your browser doesn't support video playback.
                <a href={get_video_url(@intro_video)} class="text-blue-400 underline">Download the video</a>
              </p>
            </video>

            <!-- Video Info Overlay -->
            <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black via-black/50 to-transparent p-6">
              <div class="text-white">
                <h3 class="text-xl font-bold mb-2">
                  <%= @intro_video.title || "Video Introduction" %>
                </h3>
                <%= if @intro_video.description do %>
                  <p class="text-gray-300 text-sm">
                    <%= @intro_video.description %>
                  </p>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_video_url(intro_video) do
    cond do
      Map.has_key?(intro_video, :video_url) && intro_video.video_url != nil ->
        intro_video.video_url
      Map.has_key?(intro_video, :content) && is_map(intro_video.content) ->
        Map.get(intro_video.content, "video_url", "/uploads/videos/default.webm")
      true ->
        "/uploads/videos/default.webm"
    end
  end

  defp render_categorized_skills_with_colors(skill_categories) do
    categories_html = skill_categories
    |> Enum.with_index()
    |> Enum.map(fn {{category, skills}, category_index} ->
      render_skill_category_with_colors(category, skills, category_index)
    end)
    |> Enum.join("")

    """
    <div class="skills-enhanced-container space-y-6">
      #{categories_html}
    </div>
    """
  end

  defp render_skill_category_with_colors(category, skills, category_index) do
    category_color = get_category_color_system(category, category_index)

    skills_html = skills
    |> Enum.with_index()
    |> Enum.map(fn {skill, skill_index} ->
      render_enhanced_skill_tag(skill, skill_index, category, category_color)
    end)
    |> Enum.join("")

    """
    <div class="skill-category">
      <div class="flex items-center mb-4">
        <div class="w-4 h-4 rounded-full mr-3 #{category_color[:dot]}"></div>
        <h4 class="text-lg font-semibold text-gray-900">#{category}</h4>
        <span class="ml-3 px-3 py-1 #{category_color[:badge]} text-xs font-medium rounded-full">
          #{length(skills)} skills
        </span>
      </div>
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
        #{skills_html}
      </div>
    </div>
    """
  end

  defp render_enhanced_skill_tag(skill, index, category, category_colors) do
    {skill_name, proficiency, years} = parse_skill_data_enhanced(skill)

    colors = get_skill_tag_colors(proficiency, category, index, category_colors)

    proficiency_indicator = if proficiency do
      render_proficiency_indicator(proficiency)
    else
      ""
    end

    years_indicator = if years && years > 0 do
      """
      <div class="flex items-center ml-2 text-xs #{colors[:years_text]}">
        <svg class="w-3 h-3 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
        </svg>
        #{years}y
      </div>
      """
    else
      ""
    end

    """
    <div class="skill-tag group relative #{colors[:background]} #{colors[:border]} border-2 rounded-xl p-3 transition-all duration-300 hover:scale-105 hover:shadow-lg cursor-pointer">
      <div class="flex items-center justify-between">
        <span class="font-semibold #{colors[:text]} text-sm">#{skill_name}</span>
        #{proficiency_indicator}
      </div>
      #{years_indicator}

      <div class="skill-tooltip absolute bottom-full left-1/2 transform -translate-x-1/2 mb-3 px-4 py-3 bg-gray-900 text-white text-sm rounded-lg opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none whitespace-nowrap z-20 shadow-xl">
        <div class="text-center">
          <div class="font-semibold">#{skill_name}</div>
          #{if proficiency, do: "<div class=\"text-xs opacity-90\">#{String.capitalize(proficiency)} Level</div>", else: ""}
          #{if years && years > 0, do: "<div class=\"text-xs opacity-90\">#{years} years experience</div>", else: ""}
          <div class="text-xs opacity-75">#{category}</div>
        </div>
        <div class="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-900"></div>
      </div>
    </div>
    """
  end

  defp get_category_color_system(category, index) do
    case String.downcase(category) do
      "programming languages" -> %{
        dot: "bg-blue-500",
        badge: "bg-blue-100 text-blue-800",
        base: "blue"
      }
      "frameworks & libraries" -> %{
        dot: "bg-purple-500",
        badge: "bg-purple-100 text-purple-800",
        base: "purple"
      }
      "tools & platforms" -> %{
        dot: "bg-green-500",
        badge: "bg-green-100 text-green-800",
        base: "green"
      }
      "databases" -> %{
        dot: "bg-orange-500",
        badge: "bg-orange-100 text-orange-800",
        base: "orange"
      }
      "design & creative" -> %{
        dot: "bg-pink-500",
        badge: "bg-pink-100 text-pink-800",
        base: "pink"
      }
      "soft skills" -> %{
        dot: "bg-emerald-500",
        badge: "bg-emerald-100 text-emerald-800",
        base: "emerald"
      }
      "cloud & devops" -> %{
        dot: "bg-cyan-500",
        badge: "bg-cyan-100 text-cyan-800",
        base: "cyan"
      }
      _ ->
        colors = ["red", "indigo", "teal", "amber", "violet", "rose"]
        color = Enum.at(colors, rem(index, length(colors)))
        %{
          dot: "bg-#{color}-500",
          badge: "bg-#{color}-100 text-#{color}-800",
          base: color
        }
    end
  end

  defp get_skill_tag_colors(proficiency, category, index, category_colors) do
    base_color = category_colors[:base]

    case String.downcase(proficiency || "intermediate") do
      "expert" -> %{
        background: "bg-#{base_color}-200",
        border: "border-#{base_color}-400",
        text: "text-#{base_color}-900",
        years_text: "text-#{base_color}-700"
      }
      "advanced" -> %{
        background: "bg-#{base_color}-150",
        border: "border-#{base_color}-300",
        text: "text-#{base_color}-800",
        years_text: "text-#{base_color}-600"
      }
      "intermediate" -> %{
        background: "bg-#{base_color}-100",
        border: "border-#{base_color}-250",
        text: "text-#{base_color}-700",
        years_text: "text-#{base_color}-500"
      }
      "beginner" -> %{
        background: "bg-#{base_color}-50",
        border: "border-#{base_color}-200",
        text: "text-#{base_color}-600",
        years_text: "text-#{base_color}-400"
      }
      _ -> %{
        background: "bg-#{base_color}-100",
        border: "border-#{base_color}-250",
        text: "text-#{base_color}-700",
        years_text: "text-#{base_color}-500"
      }
    end
  end

  defp render_proficiency_indicator(proficiency) do
    level = case String.downcase(proficiency) do
      "expert" -> 4
      "advanced" -> 3
      "intermediate" -> 2
      "beginner" -> 1
      _ -> 2
    end

    dots = 1..4
    |> Enum.map(fn i ->
      opacity = if i <= level, do: "opacity-100", else: "opacity-30"
      "<div class=\"w-1.5 h-1.5 rounded-full bg-current #{opacity}\"></div>"
    end)
    |> Enum.join("")

    """
    <div class="flex items-center space-x-1 ml-2">
      #{dots}
    </div>
    """
  end

  defp render_flat_skills_with_colors(flat_skills) do
    if length(flat_skills) == 0 do
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
      skills_html = flat_skills
      |> Enum.with_index()
      |> Enum.map(fn {skill, index} ->
        {skill_name, proficiency, years} = parse_skill_data_enhanced(skill)
        color_class = get_flat_skill_color(index)

        years_text = if years && years > 0, do: " • #{years}y", else: ""
        proficiency_text = if proficiency, do: " • #{String.capitalize(proficiency)}", else: ""

        """
        <span class="inline-flex items-center px-4 py-2 rounded-lg text-sm font-medium transition-all duration-200 hover:scale-105 #{color_class}">
          #{skill_name}#{proficiency_text}#{years_text}
        </span>
        """
      end)
      |> Enum.join("")

      """
      <div class="space-y-6">
        <div class="flex flex-wrap gap-3">
          #{skills_html}
        </div>
        <div class="text-center text-sm text-gray-500">
          #{length(flat_skills)} skills total
        </div>
      </div>
      """
    end
  end

  defp parse_skill_data_enhanced(skill) do
    case skill do
      %{"name" => name, "proficiency" => prof, "years" => years} -> {name, prof, years}
      %{"name" => name, "proficiency" => prof} -> {name, prof, nil}
      %{"name" => name, "years" => years} -> {name, nil, years}
      %{"name" => name} -> {name, nil, nil}
      name when is_binary(name) -> {name, nil, nil}
      _ -> {"Unknown Skill", nil, nil}
    end
  end

  defp get_flat_skill_color(index) do
    colors = [
      "bg-blue-100 text-blue-800 border border-blue-200 hover:bg-blue-200",
      "bg-purple-100 text-purple-800 border border-purple-200 hover:bg-purple-200",
      "bg-green-100 text-green-800 border border-green-200 hover:bg-green-200",
      "bg-orange-100 text-orange-800 border border-orange-200 hover:bg-orange-200",
      "bg-pink-100 text-pink-800 border border-pink-200 hover:bg-pink-200",
      "bg-emerald-100 text-emerald-800 border border-emerald-200 hover:bg-emerald-200",
      "bg-red-100 text-red-800 border border-red-200 hover:bg-red-200",
      "bg-indigo-100 text-indigo-800 border border-indigo-200 hover:bg-indigo-200",
      "bg-teal-100 text-teal-800 border border-teal-200 hover:bg-teal-200",
      "bg-amber-100 text-amber-800 border border-amber-200 hover:bg-amber-200"
    ]

    Enum.at(colors, rem(index, length(colors)))
  end

    # 🔥 FIXED: Dashboard layout with proper section rendering
  defp render_dashboard_layout(assigns) do
    # Get theme-specific styling
    theme = assigns.portfolio.theme || "executive"
    header_style = get_dynamic_header_style(theme)

    assigns = assign(assigns, :header_style, header_style)

    ~H"""
    <!-- Inject Custom CSS -->
    <%= Phoenix.HTML.raw(@customization_css) %>

    <div class="min-h-screen portfolio-bg">
      <!-- Dynamic Theme Header -->
      <header class={@header_style.container_class} style={@header_style.container_style}>
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
          <div class="grid lg:grid-cols-3 gap-8 items-center">
            <div class="lg:col-span-2">
              <h1 class={@header_style.title_class} style={@header_style.title_style}>
                <%= @portfolio.title %>
              </h1>
              <p class={@header_style.subtitle_class} style={@header_style.subtitle_style}>
                <%= @portfolio.description %>
              </p>

              <!-- Social Icons -->
              <%= if @social_links && map_size(@social_links) > 0 do %>
                <div class="flex items-center space-x-4 mb-6">
                  <span class={@header_style.label_class}>Connect:</span>
                  <%= for {platform, url} <- @social_links do %>
                    <a href={url} target="_blank" class={@header_style.social_icon_class}>
                      <%= render_social_icon(platform) %>
                    </a>
                  <% end %>
                </div>
              <% end %>

              <!-- Contact Info -->
              <%= if contact_section = Enum.find(@sections, fn s -> s.section_type == :contact end) do %>
                <div class="flex items-center space-x-6 mb-6">
                  <%= if email = get_in(contact_section.content, ["email"]) do %>
                    <div class="flex items-center space-x-2">
                      <svg class={@header_style.icon_class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                      </svg>
                      <a href={"mailto:#{email}"} class={@header_style.link_class}><%= email %></a>
                    </div>
                  <% end %>
                  <%= if phone = get_in(contact_section.content, ["phone"]) do %>
                    <div class="flex items-center space-x-2">
                      <svg class={@header_style.icon_class} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                      </svg>
                      <a href={"tel:#{phone}"} class={@header_style.link_class}><%= phone %></a>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <!-- Metrics -->
              <div class="grid grid-cols-3 gap-6">
                <div class="text-center">
                  <div class={@header_style.metric_value_class}><%= length(@sections) %></div>
                  <div class={@header_style.metric_label_class}>Sections</div>
                </div>
                <div class="text-center">
                  <div class={@header_style.metric_value_class}><%= @sections |> Enum.map(fn s -> length(Map.get(s, :media_files, [])) end) |> Enum.sum() %></div>
                  <div class={@header_style.metric_label_class}>Projects</div>
                </div>
                <div class="text-center">
                  <div class={@header_style.metric_value_class}>Active</div>
                  <div class={@header_style.metric_label_class}>Status</div>
                </div>
              </div>
            </div>

            <!-- Video thumbnail or avatar -->
            <div class="lg:justify-self-end">
              <%= if @intro_video do %>
                <div class="relative w-64 h-48 bg-black rounded-xl overflow-hidden shadow-2xl cursor-pointer hover:scale-105 transition-transform"
                    phx-click="show_video_modal">
                  <div class="w-full h-full bg-gradient-to-br from-purple-600 to-blue-600 flex items-center justify-center">
                    <div class="text-center text-white">
                      <svg class="w-16 h-16 mx-auto mb-2" fill="currentColor" viewBox="0 0 20 20">
                        <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                      </svg>
                      <p class="text-sm font-medium">Click to Play</p>
                    </div>
                  </div>
                </div>
              <% else %>
                <div class={@header_style.avatar_class}>
                  <span class="text-6xl font-bold text-white">
                    <%= String.first(@portfolio.title) %>
                  </span>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </header>

      <!-- Rest of content -->
      <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <%= if length(@sections) > 0 do %>
          <div class="grid gap-6 grid-cols-1 lg:grid-cols-2 xl:grid-cols-3">
            <%= for section <- @sections do %>
              <div id={"section-#{section.id}"} class="portfolio-card shadow-lg rounded-xl border p-6 bg-white">
                <h2 class="text-xl font-bold portfolio-primary mb-4"><%= section.title %></h2>
                <div class="portfolio-secondary"><%= render_section_content_safe(section) %></div>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="text-center py-16">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">No sections available</h3>
            <p class="text-gray-600">This portfolio is still being built.</p>
          </div>
        <% end %>
      </main>

      <!-- Video Modal -->
      <%= if @show_video_modal && @intro_video do %>
        <div class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm"
            phx-click="hide_video_modal">
          <div class="relative max-w-6xl w-full mx-4 max-h-[90vh]" phx-click-away="hide_video_modal">
            <button phx-click="hide_video_modal"
                    class="absolute -top-12 right-0 text-white hover:text-gray-300 z-10">
              <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
            <video controls autoplay class="w-full h-auto rounded-xl shadow-2xl">
              <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/mp4">
              <source src={@intro_video.video_url || get_in(@intro_video, [:content, "video_url"]) || "/uploads/videos/portfolio_intro_3_1750295669.webm"} type="video/webm">
            </video>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_section_color(section_type) do
    case section_type do
      :intro -> "#059669"
      :experience -> "#3b82f6"
      :skills -> "#10b981"
      :education -> "#8b5cf6"
      :projects -> "#6366f1"
      :featured_project -> "#f59e0b"
      :case_study -> "#ec4899"
      :contact -> "#0891b2"
      :testimonial -> "#84cc16"
      :achievements -> "#eab308"
      :media_showcase -> "#6366f1"
      _ -> "#6b7280"
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

  # Enhanced section content renderer
  defp render_section_content_enhanced(section) do
    try do
      content = section.content || %{}

      case section.section_type do
        :skills ->
          render_skills_content_enhanced(content)
        :experience ->
          render_experience_content_enhanced(content)
        :education ->
          render_education_content_enhanced(content)
        :projects ->
          render_projects_content_enhanced(content)
        :contact ->
          render_contact_content_enhanced(content)
        :intro ->
          render_intro_content_enhanced(content)
        _ ->
          render_generic_content_enhanced(content)
      end
    rescue
      _ ->
        Phoenix.HTML.raw("""
        <div class="text-gray-500 italic">Content loading...</div>
        """)
    end
  end

  defp render_experience_content_enhanced(content) do
    jobs = Map.get(content, "jobs", [])

    if length(jobs) == 0 do
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No experience added yet</div>
      """)
    else
      jobs_html = jobs
      |> Enum.take(3)
      |> Enum.map(fn job ->
        current = if Map.get(job, "current", false), do: " • Current", else: ""

        """
        <div class="mb-3 pb-3 border-b border-gray-100 last:border-b-0">
          <h4 class="font-semibold text-gray-900 text-sm">#{Map.get(job, "title", "Position")}</h4>
          <p class="text-xs text-gray-600">#{Map.get(job, "company", "Company")}#{current}</p>
          #{if Map.get(job, "description"), do: "<p class=\"text-xs text-gray-700 mt-1 line-clamp-2\">#{Map.get(job, "description")}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      extra_text = if length(jobs) > 3 do
        "<p class=\"text-xs text-gray-500 italic\">And #{length(jobs) - 3} more positions...</p>"
      else
        ""
      end

      Phoenix.HTML.raw(jobs_html <> extra_text)
    end
  end

  defp render_education_content_enhanced(content) do
    education = Map.get(content, "education", [])

    if length(education) == 0 do
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No education added yet</div>
      """)
    else
      education_html = education
      |> Enum.take(2)
      |> Enum.map(fn edu ->
        """
        <div class="mb-3">
          <h4 class="font-semibold text-gray-900 text-sm">#{Map.get(edu, "degree", "Degree")}</h4>
          <p class="text-xs text-gray-600">#{Map.get(edu, "institution", "Institution")}</p>
          #{if Map.get(edu, "field"), do: "<p class=\"text-xs text-gray-500\">#{Map.get(edu, "field")}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      Phoenix.HTML.raw(education_html)
    end
  end

  defp render_projects_content_enhanced(content) do
    projects = Map.get(content, "projects", [])

    if length(projects) == 0 do
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">No projects added yet</div>
      """)
    else
      projects_html = projects
      |> Enum.take(2)
      |> Enum.map(fn project ->
        """
        <div class="mb-3">
          <h4 class="font-semibold text-gray-900 text-sm">#{Map.get(project, "title", "Project")}</h4>
          #{if Map.get(project, "description"), do: "<p class=\"text-xs text-gray-600 line-clamp-2\">#{Map.get(project, "description")}</p>", else: ""}
        </div>
        """
      end)
      |> Enum.join("")

      count_text = "<p class=\"text-xs text-gray-500 mb-3\">#{length(projects)} project#{if length(projects) != 1, do: "s", else: ""} showcased</p>"

      Phoenix.HTML.raw(count_text <> projects_html)
    end
  end

  defp render_contact_content_enhanced(content) do
    contact_info = []

    contact_info = if Map.get(content, "email"), do: contact_info ++ ["📧 #{content["email"]}"], else: contact_info
    contact_info = if Map.get(content, "phone"), do: contact_info ++ ["📞 #{content["phone"]}"], else: contact_info
    contact_info = if Map.get(content, "location"), do: contact_info ++ ["📍 #{content["location"]}"], else: contact_info

    if length(contact_info) == 0 do
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Contact information will be displayed here</div>
      """)
    else
      contact_html = contact_info
      |> Enum.map(fn info -> "<p class=\"text-sm text-gray-700 mb-1\">#{info}</p>" end)
      |> Enum.join("")

      Phoenix.HTML.raw(contact_html)
    end
  end

  defp render_intro_content_enhanced(content) do
    summary = Map.get(content, "summary") || Map.get(content, "headline") || Map.get(content, "description")

    if summary do
      Phoenix.HTML.raw("""
      <div class="text-gray-700 leading-relaxed">
        <p>#{summary}</p>
      </div>
      """)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Introduction content will be displayed here</div>
      """)
    end
  end

  defp render_generic_content_enhanced(content) do
    text = Map.get(content, "description") || Map.get(content, "summary") || Map.get(content, "content")

    if text do
      Phoenix.HTML.raw("""
      <div class="text-gray-700 leading-relaxed">
        <p>#{text}</p>
      </div>
      """)
    else
      Phoenix.HTML.raw("""
      <div class="text-gray-500 italic text-sm">Content will be displayed here</div>
      """)
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

  defp render_skills_content_enhanced(content) do
    skill_categories = Map.get(content, "skill_categories", %{})
    flat_skills = Map.get(content, "skills", [])

    cond do
      map_size(skill_categories) > 0 ->
        categories_html = skill_categories
        |> Enum.map(fn {category, skills} ->
          skills_html = skills
          |> Enum.with_index()
          |> Enum.map(fn {skill, index} ->
            skill_name = case skill do
              %{"name" => name} -> name
              name when is_binary(name) -> name
              _ -> to_string(skill)
            end

            skill_class = get_skill_class_by_category(category, index)

            """
            <span class="#{skill_class} px-3 py-1 rounded-full text-sm font-medium">
              #{skill_name}
            </span>
            """
          end)
          |> Enum.join("")

          """
          <div class="mb-4">
            <h4 class="text-sm font-semibold text-gray-700 mb-2">#{category}</h4>
            <div class="flex flex-wrap gap-2">
              #{skills_html}
            </div>
          </div>
          """
        end)
        |> Enum.join("")

        Phoenix.HTML.raw(categories_html)

      length(flat_skills) > 0 ->
        skills_html = flat_skills
        |> Enum.with_index()
        |> Enum.map(fn {skill, index} ->
          skill_name = case skill do
            %{"name" => name} -> name
            name when is_binary(name) -> name
            _ -> to_string(skill)
          end

          skill_class = get_skill_class_by_index(index)

          """
          <span class="#{skill_class} px-3 py-1 rounded-full text-sm font-medium">
            #{skill_name}
          </span>
          """
        end)
        |> Enum.join("")

        Phoenix.HTML.raw("""
        <div class="flex flex-wrap gap-2">
          #{skills_html}
        </div>
        """)

      true ->
        Phoenix.HTML.raw("""
        <div class="text-gray-500 italic text-sm">No skills added yet</div>
        """)
    end
  end

  defp get_skill_class_by_index(index) do
    [
      "bg-blue-100 text-blue-800",
      "bg-purple-100 text-purple-800",
      "bg-green-100 text-green-800",
      "bg-orange-100 text-orange-800",
      "bg-pink-100 text-pink-800",
      "bg-indigo-100 text-indigo-800"
    ]
    |> Enum.at(rem(index, 6))
  end

  defp get_skill_class_by_category(category, index) do
    category_lower = String.downcase(category)

    cond do
      String.contains?(category_lower, "technical") or String.contains?(category_lower, "programming") ->
        ["bg-blue-100 text-blue-800", "bg-indigo-100 text-indigo-800", "bg-cyan-100 text-cyan-800"]
        |> Enum.at(rem(index, 3))

      String.contains?(category_lower, "design") or String.contains?(category_lower, "creative") ->
        ["bg-purple-100 text-purple-800", "bg-pink-100 text-pink-800", "bg-rose-100 text-rose-800"]
        |> Enum.at(rem(index, 3))

      String.contains?(category_lower, "business") or String.contains?(category_lower, "management") ->
        ["bg-green-100 text-green-800", "bg-emerald-100 text-emerald-800", "bg-teal-100 text-teal-800"]
        |> Enum.at(rem(index, 3))

      true ->
        ["bg-orange-100 text-orange-800", "bg-amber-100 text-amber-800", "bg-yellow-100 text-yellow-800"]
        |> Enum.at(rem(index, 3))
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

  # PATCH: Add this new function for dynamic header styles
  defp get_dynamic_header_style(theme) do
    case theme do
      "executive" -> %{
        container_class: "portfolio-header border-b border-blue-200",
        container_style: "background: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%); color: #1e293b;",
        title_class: "text-4xl lg:text-5xl font-bold mb-4 text-slate-800",
        title_style: "",
        subtitle_class: "text-xl mb-6 text-slate-600",
        subtitle_style: "",
        label_class: "text-sm font-medium text-slate-600",
        social_icon_class: "w-10 h-10 rounded-full bg-slate-200 hover:bg-slate-300 flex items-center justify-center transition-all hover:scale-110",
        icon_class: "w-4 h-4 text-slate-600",
        link_class: "text-sm hover:underline text-slate-700 hover:text-slate-900",
        metric_value_class: "text-3xl font-bold text-blue-600",
        metric_label_class: "text-sm text-slate-600",
        avatar_class: "w-64 h-64 bg-gradient-to-br from-blue-600 to-indigo-600 rounded-xl shadow-2xl flex items-center justify-center"
      }
      "developer" -> %{
        container_class: "portfolio-header border-b border-green-500",
        container_style: "background: linear-gradient(135deg, #1f2937 0%, #111827 100%); color: #f9fafb;",
        title_class: "text-4xl lg:text-5xl font-bold mb-4 text-green-400",
        title_style: "",
        subtitle_class: "text-xl mb-6 text-gray-300",
        subtitle_style: "",
        label_class: "text-sm font-medium text-gray-400",
        social_icon_class: "w-10 h-10 rounded-full bg-green-900 hover:bg-green-800 flex items-center justify-center transition-all hover:scale-110",
        icon_class: "w-4 h-4 text-green-400",
        link_class: "text-sm hover:underline text-green-300 hover:text-green-100",
        metric_value_class: "text-3xl font-bold text-green-400",
        metric_label_class: "text-sm text-gray-400",
        avatar_class: "w-64 h-64 bg-gradient-to-br from-green-600 to-emerald-600 rounded-xl shadow-2xl flex items-center justify-center"
      }
      "designer" -> %{
        container_class: "portfolio-header border-b border-pink-300",
        container_style: "background: linear-gradient(135deg, #a855f7 0%, #ec4899 100%); color: #ffffff;",
        title_class: "text-4xl lg:text-5xl font-bold mb-4 text-white",
        title_style: "",
        subtitle_class: "text-xl mb-6 text-pink-100",
        subtitle_style: "",
        label_class: "text-sm font-medium text-pink-200",
        social_icon_class: "w-10 h-10 rounded-full bg-white bg-opacity-20 hover:bg-opacity-30 flex items-center justify-center transition-all hover:scale-110",
        icon_class: "w-4 h-4 text-pink-200",
        link_class: "text-sm hover:underline text-pink-100 hover:text-white",
        metric_value_class: "text-3xl font-bold text-yellow-300",
        metric_label_class: "text-sm text-pink-200",
        avatar_class: "w-64 h-64 bg-gradient-to-br from-pink-600 to-purple-600 rounded-xl shadow-2xl flex items-center justify-center"
      }
      "minimalist" -> %{
        container_class: "portfolio-header border-b border-gray-200",
        container_style: "background: #ffffff; color: #111827;",
        title_class: "text-4xl lg:text-5xl font-bold mb-4 text-gray-900",
        title_style: "",
        subtitle_class: "text-xl mb-6 text-gray-600",
        subtitle_style: "",
        label_class: "text-sm font-medium text-gray-500",
        social_icon_class: "w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-all hover:scale-110",
        icon_class: "w-4 h-4 text-gray-500",
        link_class: "text-sm hover:underline text-gray-600 hover:text-gray-900",
        metric_value_class: "text-3xl font-bold text-gray-800",
        metric_label_class: "text-sm text-gray-500",
        avatar_class: "w-64 h-64 bg-gray-900 rounded-xl shadow-2xl flex items-center justify-center"
      }
      _ -> %{
        container_class: "portfolio-header border-b border-gray-200",
        container_style: "background: #ffffff; color: #374151;",
        title_class: "text-4xl lg:text-5xl font-bold mb-4 text-gray-900",
        title_style: "",
        subtitle_class: "text-xl mb-6 text-gray-600",
        subtitle_style: "",
        label_class: "text-sm font-medium text-gray-500",
        social_icon_class: "w-10 h-10 rounded-full bg-gray-100 hover:bg-gray-200 flex items-center justify-center transition-all hover:scale-110",
        icon_class: "w-4 h-4 text-gray-500",
        link_class: "text-sm hover:underline text-gray-600 hover:text-gray-900",
        metric_value_class: "text-3xl font-bold text-purple-600",
        metric_label_class: "text-sm text-gray-500",
        avatar_class: "w-64 h-64 bg-gradient-to-br from-purple-600 to-blue-600 rounded-xl shadow-2xl flex items-center justify-center"
      }
    end
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
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-white">
      <!-- Gallery Header -->
      <header class="text-center py-16 px-6">
        <h1 class="text-4xl lg:text-6xl font-bold text-gray-900 mb-4">
          <%= @portfolio.title %>
        </h1>
        <p class="text-xl text-gray-600 max-w-3xl mx-auto">
          <%= @portfolio.description %>
        </p>
      </header>

      <!-- Gallery Content -->
      <main class="max-w-7xl mx-auto px-6 pb-16">
        <div class="columns-1 md:columns-2 lg:columns-3 gap-8 space-y-8">
          <%= for section <- @sections do %>
            <section class="break-inside-avoid bg-white rounded-xl shadow-lg border p-8 mb-8">
              <h2 class="text-2xl font-bold text-gray-900 mb-6">
                <%= section.title %>
              </h2>
              <div class="prose max-w-none">
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
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-black text-green-400 font-mono">
      <!-- Terminal Header -->
      <header class="p-6 border-b border-green-400">
        <div class="flex items-center space-x-2 mb-4">
          <div class="w-3 h-3 bg-red-500 rounded-full"></div>
          <div class="w-3 h-3 bg-yellow-500 rounded-full"></div>
          <div class="w-3 h-3 bg-green-500 rounded-full"></div>
          <span class="ml-4 text-green-400">terminal ~/portfolio</span>
        </div>
        <div class="space-y-2">
          <div class="flex items-center space-x-2">
            <span class="text-green-400">$</span>
            <span class="text-white">cat portfolio.txt</span>
          </div>
          <div class="ml-4">
            <h1 class="text-2xl text-white mb-2">
              <%= @portfolio.title %>
            </h1>
            <p class="text-green-300">
              <%= @portfolio.description %>
            </p>
          </div>
        </div>
      </header>

      <!-- Terminal Content -->
      <main class="p-6 space-y-8">
        <%= for {section, index} <- Enum.with_index(@sections) do %>
          <section class="space-y-4">
            <div class="flex items-center space-x-2">
              <span class="text-green-400">$</span>
              <span class="text-white">cat section_<%= index + 1 %>.txt</span>
            </div>
            <div class="ml-4 border-l-2 border-green-400 pl-4">
              <h2 class="text-xl text-white mb-4">
                # <%= section.title %>
              </h2>
              <div class="text-green-300 space-y-2">
                <%= render_section_content_safe(section) %>
              </div>
            </div>
          </section>
        <% end %>
      </main>
    </div>
    """
  end

  defp render_minimal_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-white">
      <!-- Minimal Header -->
      <header class="py-16 px-6 text-center border-b">
        <h1 class="text-4xl lg:text-6xl font-light text-gray-900 mb-4">
          <%= @portfolio.title %>
        </h1>
        <p class="text-xl text-gray-600 max-w-2xl mx-auto leading-relaxed">
          <%= @portfolio.description %>
        </p>
      </header>

      <!-- Minimal Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <div class="space-y-16">
          <%= for section <- @sections do %>
            <section class="border-b border-gray-100 pb-16 last:border-b-0">
              <h2 class="text-2xl font-light text-gray-900 mb-8">
                <%= section.title %>
              </h2>
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

  defp render_case_study_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-gray-50">
      <!-- Case Study Header -->
      <header class="bg-white py-16 px-6">
        <div class="max-w-4xl mx-auto text-center">
          <h1 class="text-4xl lg:text-5xl font-bold text-gray-900 mb-6">
            <%= @portfolio.title %>
          </h1>
          <p class="text-xl text-gray-600 max-w-3xl mx-auto leading-relaxed">
            <%= @portfolio.description %>
          </p>
        </div>
      </header>

      <!-- Case Study Content -->
      <main class="max-w-4xl mx-auto px-6 py-16">
        <%= for section <- @sections do %>
          <section class="mb-16">
            <div class="bg-white rounded-xl shadow-sm border overflow-hidden">
              <div class="p-8">
                <h2 class="text-3xl font-bold text-gray-900 mb-6">
                  <%= section.title %>
                </h2>
                <div class="prose prose-lg max-w-none">
                  <%= render_section_content_safe(section) %>
                </div>
              </div>
            </div>
          </section>
        <% end %>
      </main>
    </div>
    """
  end

  defp render_academic_layout(assigns) do
    ~H"""
    <%= Phoenix.HTML.raw(Map.get(assigns, :customization_css, "")) %>
    <div class="min-h-screen bg-white">
      <!-- Academic Header -->
      <header class="py-12 px-6 border-b-2 border-gray-200">
        <div class="max-w-4xl mx-auto">
          <h1 class="text-4xl font-serif font-bold text-gray-900 mb-4">
            <%= @portfolio.title %>
          </h1>
          <p class="text-lg text-gray-700 font-serif leading-relaxed">
            <%= @portfolio.description %>
          </p>
        </div>
      </header>

      <!-- Academic Content -->
      <main class="max-w-4xl mx-auto px-6 py-12">
        <div class="space-y-12">
          <%= for section <- @sections do %>
            <section class="space-y-6">
              <h2 class="text-2xl font-serif font-bold text-gray-900 border-b border-gray-300 pb-2">
                <%= section.title %>
              </h2>
              <div class="prose prose-lg max-w-none font-serif text-gray-800">
                <%= render_section_content_safe(section) %>
              </div>
            </section>
          <% end %>
        </div>
      </main>
    </div>
    """
  end

  # HELPER FUNCTIONS
  defp normalize_theme(theme) when is_binary(theme) do
    case theme do
      "executive" -> :executive
      "developer" -> :developer
      "designer" -> :designer
      "consultant" -> :consultant
      "academic" -> :academic
      "creative" -> :creative
      "minimalist" -> :minimalist
      "corporate" -> :corporate
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

    defp render_footer_video(assigns) do
    if assigns.intro_video do
      ~H"""
      <div class="mt-12 bg-gray-900 rounded-2xl overflow-hidden">
        <div class="aspect-video relative">
          <%= if @intro_video.video_url do %>
            <video
              class="w-full h-full object-cover"
              controls
              poster={@intro_video.thumbnail_url}
              preload="metadata">
              <source src={@intro_video.video_url} type="video/mp4" />
              Your browser does not support the video tag.
            </video>
          <% else %>
            <!-- Fallback for missing video -->
            <div class="w-full h-full bg-gradient-to-br from-gray-700 to-gray-900 flex items-center justify-center">
              <div class="text-center text-white">
                <svg class="w-16 h-16 mx-auto mb-4 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h1m4 0h1m-6 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <p class="text-lg font-medium">Video Introduction</p>
                <p class="text-sm opacity-75">Coming Soon</p>
              </div>
            </div>
          <% end %>

          <!-- Video overlay with title -->
          <div class="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-6">
            <h3 class="text-white text-xl font-bold mb-2">
              <%= @intro_video.title || "Introduction Video" %>
            </h3>
            <%= if @intro_video.description do %>
              <p class="text-white/90 text-sm">
                <%= @intro_video.description %>
              </p>
            <% end %>
          </div>
        </div>
      </div>
      """
    else
      ~H""
    end
  end

  defp render_about_video(assigns) do
    if assigns.intro_video do
      ~H"""
      <div class="mb-8">
        <div class="aspect-video bg-gray-100 rounded-xl overflow-hidden shadow-lg">
          <%= if @intro_video.video_url do %>
            <video
              class="w-full h-full object-cover"
              controls
              poster={@intro_video.thumbnail_url}
              preload="metadata">
              <source src={@intro_video.video_url} type="video/mp4" />
              Your browser does not support the video tag.
            </video>
          <% else %>
            <!-- Fallback when no video URL -->
            <div class="w-full h-full bg-gradient-to-br from-blue-50 to-indigo-100 flex items-center justify-center">
              <div class="text-center text-gray-600">
                <svg class="w-12 h-12 mx-auto mb-3 opacity-40" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
                <p class="font-medium">Personal Introduction</p>
                <p class="text-sm">Video coming soon</p>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Video caption/description -->
        <%= if @intro_video.title || @intro_video.description do %>
          <div class="mt-4 text-center">
            <%= if @intro_video.title do %>
              <h4 class="font-semibold text-gray-900 mb-1">
                <%= @intro_video.title %>
              </h4>
            <% end %>
            <%= if @intro_video.description do %>
              <p class="text-gray-600 text-sm">
                <%= @intro_video.description %>
              </p>
            <% end %>
          </div>
        <% end %>
      </div>
      """
    else
      ~H""
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS FOR VIDEO HANDLING
  # ============================================================================

  # Helper function to safely get video duration
  defp get_video_duration(intro_video) when is_map(intro_video) do
    case intro_video do
      %{duration: duration} when is_number(duration) -> format_duration(duration)
      _ -> nil
    end
  end
  defp get_video_duration(_), do: nil

  # Helper function to format video duration
  defp format_duration(seconds) when is_number(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)
    "#{minutes}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end
  defp format_duration(_), do: "0:00"

  # Helper function to check if video has valid URL
  defp has_valid_video_url?(intro_video) when is_map(intro_video) do
    case intro_video do
      %{video_url: url} when is_binary(url) and url != "" -> true
      _ -> false
    end
  end
  defp has_valid_video_url?(_), do: false

  # Helper function to get video thumbnail with fallback
  defp get_video_thumbnail(intro_video) when is_map(intro_video) do
    case intro_video do
      %{thumbnail_url: url} when is_binary(url) and url != "" -> url
      _ -> "/images/video-placeholder.jpg"  # Default placeholder
    end
  end
  defp get_video_thumbnail(_), do: "/images/video-placeholder.jpg"

  # Alternative render function with more features
  defp render_enhanced_video_intro(assigns) do
    if assigns.intro_video && has_valid_video_url?(assigns.intro_video) do
      ~H"""
      <div class="relative mb-8">
        <div class="aspect-video bg-black rounded-xl overflow-hidden shadow-2xl">
          <video
            class="w-full h-full object-cover"
            controls
            poster={get_video_thumbnail(@intro_video)}
            preload="metadata"
            controlsList="nodownload"
            disablePictureInPicture={false}>
            <source src={@intro_video.video_url} type="video/mp4" />
            <p class="text-white p-4">
              Your browser doesn't support HTML video. Here is a
              <a href={@intro_video.video_url} class="underline">link to the video</a> instead.
            </p>
          </video>

          <!-- Play button overlay (optional) -->
          <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
            <div class="w-20 h-20 bg-white/20 backdrop-blur-sm rounded-full flex items-center justify-center opacity-0 hover:opacity-100 transition-opacity">
              <svg class="w-8 h-8 text-white ml-1" fill="currentColor" viewBox="0 0 24 24">
                <path d="M8 5v14l11-7z"/>
              </svg>
            </div>
          </div>
        </div>

        <!-- Video metadata -->
        <div class="mt-4 flex items-center justify-between text-sm text-gray-600">
          <div class="flex items-center space-x-4">
            <%= if get_video_duration(@intro_video) do %>
              <span class="flex items-center">
                <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
                <%= get_video_duration(@intro_video) %>
              </span>
            <% end %>

            <span class="flex items-center">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
              </svg>
              Video Introduction
            </span>
          </div>
        </div>
      </div>
      """
    else
      ~H""
    end
  end

  # ============================================================================
  # YOUR EXISTING render_positioned_video_intro FUNCTION SHOULD LOOK LIKE THIS:
  # ============================================================================

  defp render_positioned_video_intro(assigns) do
    if assigns.intro_video do
      case assigns.intro_video.position do
        :footer ->
          render_footer_video(assigns)
        :about ->
          render_about_video(assigns)
        :hero ->
          render_enhanced_video_intro(assigns)
        _ ->
          render_about_video(assigns)  # Default fallback
      end
    else
      ~H""
    end
  end

  defp render_hero_video(assigns) do
    ~H"""
    <div class="hero-video-section bg-gradient-to-br from-purple-900 via-blue-900 to-indigo-900 text-white py-20">
      <div class="container mx-auto px-6 lg:px-8">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
          <!-- Text Content -->
          <div class="order-2 lg:order-1">
            <h1 class="text-5xl lg:text-6xl font-bold mb-6 leading-tight">
              <%= @portfolio.title %>
            </h1>
            <p class="text-xl text-purple-100 mb-8 leading-relaxed">
              <%= @portfolio.description || "Welcome to my professional portfolio" %>
            </p>

            <!-- Video Play Button -->
            <button phx-click="show_video_modal"
                    class="inline-flex items-center px-8 py-4 bg-white text-purple-900 font-semibold rounded-xl hover:bg-purple-50 transition-all duration-200 shadow-lg hover:shadow-xl">
              <svg class="w-6 h-6 mr-3" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
              Watch My Introduction
              <span class="ml-2 text-sm text-purple-600">(<%= format_video_duration(@intro_video.duration) %>)</span>
            </button>
          </div>

          <!-- Video Thumbnail -->
          <div class="order-1 lg:order-2">
            <div class="relative group cursor-pointer" phx-click="show_video_modal">
              <div class="aspect-w-16 aspect-h-9 rounded-2xl overflow-hidden shadow-2xl">
                <%= if @intro_video.thumbnail_url do %>
                  <img src={@intro_video.thumbnail_url} alt="Video preview"
                      class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
                <% else %>
                  <div class="w-full h-full bg-gradient-to-br from-purple-600 to-blue-600 flex items-center justify-center">
                    <svg class="w-24 h-24 text-white opacity-80" fill="currentColor" viewBox="0 0 20 20">
                      <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                    </svg>
                  </div>
                <% end %>
              </div>

              <!-- Play Overlay -->
              <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-20 rounded-2xl group-hover:bg-opacity-30 transition-all duration-200">
                <div class="w-20 h-20 bg-white bg-opacity-90 rounded-full flex items-center justify-center group-hover:scale-110 transition-transform duration-200">
                  <svg class="w-8 h-8 text-purple-900 ml-1" fill="currentColor" viewBox="0 0 20 20">
                    <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                  </svg>
                </div>
              </div>
            </div>

            <!-- Video Quality Badge -->
            <div class="mt-4 text-center">
              <span class="inline-flex items-center px-3 py-1 bg-white bg-opacity-20 text-white text-sm font-medium rounded-full">
                🎥 <%= @intro_video.quality || "HD" %> Quality
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp render_sidebar_video(assigns) do
    ~H"""
    <div class="fixed right-6 bottom-6 z-40 w-80 bg-white rounded-xl shadow-2xl overflow-hidden border border-gray-200">
      <div class="p-4">
        <h3 class="font-semibold text-gray-900 mb-3">Personal Introduction</h3>

        <div class="relative group cursor-pointer" phx-click="show_video_modal">
          <div class="aspect-w-16 aspect-h-9 rounded-lg overflow-hidden">
            <%= if @intro_video.thumbnail_url do %>
              <img src={@intro_video.thumbnail_url} alt="Video preview"
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300" />
            <% else %>
              <div class="w-full h-full bg-gradient-to-br from-purple-600 to-blue-600 flex items-center justify-center">
                <svg class="w-12 h-12 text-white opacity-80" fill="currentColor" viewBox="0 0 20 20">
                  <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                </svg>
              </div>
            <% end %>
          </div>

          <!-- Play Button Overlay -->
          <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-20 rounded-lg group-hover:bg-opacity-30 transition-all duration-200">
            <div class="w-12 h-12 bg-white bg-opacity-90 rounded-full flex items-center justify-center">
              <svg class="w-4 h-4 text-purple-900 ml-0.5" fill="currentColor" viewBox="0 0 20 20">
                <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
              </svg>
            </div>
          </div>
        </div>

        <div class="mt-3 text-center">
          <span class="text-sm text-gray-600">
            <%= format_video_duration(@intro_video.duration) %> • <%= @intro_video.quality || "HD" %>
          </span>
        </div>
      </div>
    </div>
    """
  end

  # 🔥 ENHANCED MOBILE NAVIGATION WITH FLOATING ACTION BUTTON
  defp render_enhanced_mobile_navigation(assigns) do
    theme = assigns.portfolio.theme || "executive"
    nav_style = get_mobile_nav_theme_style(theme)

    assigns = assign(assigns, :nav_style, nav_style)

    ~H"""
    <!-- Floating Action Button (Mobile Only) -->
    <div class="fixed bottom-6 right-6 z-50 lg:hidden">
      <button phx-click="toggle_mobile_nav"
              class={"w-14 h-14 rounded-full shadow-2xl flex items-center justify-center transition-all duration-300 transform hover:scale-110 #{@nav_style.fab_class}"}>
        <%= if @show_mobile_nav do %>
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        <% else %>
          <svg class="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
          </svg>
        <% end %>

        <!-- Pulse indicator for new content -->
        <div class="absolute -top-1 -right-1 w-4 h-4 bg-red-500 rounded-full animate-pulse hidden"></div>
      </button>
    </div>

    <!-- Enhanced Mobile Navigation Panel -->
    <%= if @show_mobile_nav do %>
      <div class="fixed inset-0 z-40 lg:hidden">
        <!-- Enhanced Backdrop with blur -->
        <div class="absolute inset-0 bg-black bg-opacity-60 backdrop-blur-md transition-opacity duration-300"
             phx-click="toggle_mobile_nav"></div>

        <!-- Sliding Navigation Panel -->
        <div class={"absolute top-0 right-0 h-full w-80 max-w-[85vw] shadow-2xl transform transition-transform duration-300 ease-out #{@nav_style.panel_class}"}>

          <!-- Navigation Header -->
          <div class="p-6 border-b border-opacity-20">
            <div class="flex items-center justify-between mb-4">
              <h3 class={"text-xl font-bold #{@nav_style.text_class}"}><%= @portfolio.title %></h3>
              <button phx-click="toggle_mobile_nav"
                      class={"w-8 h-8 rounded-lg flex items-center justify-center transition-colors #{@nav_style.close_button_class}"}>
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
                </svg>
              </button>
            </div>

            <p class={"text-sm #{@nav_style.subtitle_class}"}><%= @portfolio.description %></p>

            <!-- Quick Stats -->
            <div class="flex space-x-4 mt-4">
              <div class="text-center">
                <div class={"text-lg font-bold #{@nav_style.accent_class}"}><%= length(@sections) %></div>
                <div class={"text-xs #{@nav_style.muted_class}"}>Sections</div>
              </div>
              <div class="text-center">
                <div class={"text-lg font-bold #{@nav_style.accent_class}"}>
                  <%= if @social_links, do: map_size(@social_links), else: 0 %>
                </div>
                <div class={"text-xs #{@nav_style.muted_class}"}>Links</div>
              </div>
            </div>
          </div>

          <!-- Navigation Content -->
          <div class="flex-1 overflow-y-auto p-6">

            <!-- Section Navigation -->
            <div class="space-y-3 mb-8">
              <h4 class={"text-sm font-semibold uppercase tracking-wide #{@nav_style.section_header_class}"}>
                Portfolio Sections
              </h4>

              <%= for section <- @sections do %>
                <button onclick={"document.getElementById('section-#{section.id}').scrollIntoView({behavior: 'smooth'}); document.querySelector('[phx-click=\"toggle_mobile_nav\"]').click();"}
                        class={"w-full text-left px-4 py-3 rounded-xl transition-all duration-200 flex items-center space-x-3 group #{@nav_style.nav_item_class}"}>
                  <div class={"w-10 h-10 rounded-lg flex items-center justify-center transition-colors #{@nav_style.icon_bg_class}"}>
                    <%= render_section_icon_enhanced(section.section_type, @nav_style) %>
                  </div>
                  <div class="flex-1">
                    <div class={"font-medium #{@nav_style.text_class} group-hover:#{@nav_style.hover_text_class}"}>
                      <%= section.title %>
                    </div>
                    <div class={"text-xs #{@nav_style.muted_class}"}>
                      <%= format_section_type(section.section_type) %>
                    </div>
                  </div>
                  <svg class={"w-4 h-4 #{@nav_style.arrow_class} transform group-hover:translate-x-1 transition-transform"}
                       fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/>
                  </svg>
                </button>
              <% end %>
            </div>

            <!-- Quick Actions -->
            <%= if contact_section = get_contact_section(@sections) do %>
              <div class="mb-8">
                <h4 class={"text-sm font-semibold uppercase tracking-wide mb-3 #{@nav_style.section_header_class}"}>
                  Quick Actions
                </h4>

                <div class="space-y-3">
                  <button onclick={"document.getElementById('section-#{contact_section.id}').scrollIntoView({behavior: 'smooth'}); document.querySelector('[phx-click=\"toggle_mobile_nav\"]').click();"}
                          class={"w-full text-white px-6 py-3 rounded-xl font-semibold transition-all duration-300 shadow-lg #{@nav_style.primary_button_class}"}>
                    <div class="flex items-center justify-center space-x-2">
                      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                      </svg>
                      <span>Get In Touch</span>
                    </div>
                  </button>

                  <%= if @intro_video do %>
                    <button phx-click="show_video_modal"
                            onclick="document.querySelector('[phx-click=&quot;toggle_mobile_nav&quot;]').click();"
                            class={"w-full px-6 py-3 rounded-xl font-semibold transition-all duration-300 border-2 #{@nav_style.secondary_button_class}"}>
                      <div class="flex items-center justify-center space-x-2">
                        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                          <path d="M6.3 2.841A1.5 1.5 0 004 4.11V15.89a1.5 1.5 0 002.3 1.269l9.344-5.89a1.5 1.5 0 000-2.538L6.3 2.84z"/>
                        </svg>
                        <span>Watch Introduction</span>
                      </div>
                    </button>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Contact Information -->
            <%= if @contact_info && map_size(@contact_info) > 0 do %>
              <div class="mb-8">
                <h4 class={"text-sm font-semibold uppercase tracking-wide mb-3 #{@nav_style.section_header_class}"}>
                  Contact Info
                </h4>

                <div class="space-y-3">
                  <%= if Map.get(@contact_info, :email) do %>
                    <a href={"mailto:#{@contact_info.email}"}
                       class={"flex items-center space-x-3 p-3 rounded-lg transition-colors #{@nav_style.contact_item_class}"}>
                      <div class={"w-8 h-8 rounded-lg flex items-center justify-center #{@nav_style.contact_icon_bg}"}>
                        <svg class={"w-4 h-4 #{@nav_style.icon_class}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
                        </svg>
                      </div>
                      <span class={"text-sm font-medium #{@nav_style.text_class}"}><%= @contact_info.email %></span>
                    </a>
                  <% end %>

                  <%= if Map.get(@contact_info, :phone) do %>
                    <a href={"tel:#{@contact_info.phone}"}
                       class={"flex items-center space-x-3 p-3 rounded-lg transition-colors #{@nav_style.contact_item_class}"}>
                      <div class={"w-8 h-8 rounded-lg flex items-center justify-center #{@nav_style.contact_icon_bg}"}>
                        <svg class={"w-4 h-4 #{@nav_style.icon_class}"} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z"/>
                        </svg>
                      </div>
                      <span class={"text-sm font-medium #{@nav_style.text_class}"}><%= @contact_info.phone %></span>
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>

            <!-- Social Links -->
            <%= if @social_links && map_size(@social_links) > 0 do %>
              <div class="mb-8">
                <h4 class={"text-sm font-semibold uppercase tracking-wide mb-3 #{@nav_style.section_header_class}"}>
                  Connect
                </h4>

                <div class="grid grid-cols-4 gap-3">
                  <%= for {platform, url} <- @social_links do %>
                    <a href={url} target="_blank"
                       class={"aspect-square rounded-xl flex items-center justify-center transition-all hover:scale-110 #{@nav_style.social_item_class}"}
                       title={String.capitalize(platform)}>
                      <%= render_social_icon(platform) %>
                    </a>
                  <% end %>
                </div>
              </div>
            <% end %>
          </div>

          <!-- Navigation Footer -->
          <div class={"p-6 border-t #{@nav_style.footer_border_class}"}>
            <div class="text-center">
              <p class={"text-xs #{@nav_style.muted_class}"}>
                Built with Frestyl
              </p>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # 🔥 THEME-SPECIFIC MOBILE NAV STYLES
  defp get_mobile_nav_theme_style(theme) do
    case theme do
      "executive" -> %{
        fab_class: "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700",
        panel_class: "bg-white",
        text_class: "text-gray-900",
        subtitle_class: "text-gray-600",
        accent_class: "text-blue-600",
        muted_class: "text-gray-500",
        section_header_class: "text-gray-700",
        nav_item_class: "hover:bg-blue-50",
        hover_text_class: "text-blue-600",
        icon_bg_class: "bg-blue-100 group-hover:bg-blue-200",
        icon_class: "text-blue-600",
        arrow_class: "text-gray-400",
        primary_button_class: "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700",
        secondary_button_class: "border-blue-300 text-blue-600 hover:bg-blue-50",
        contact_item_class: "hover:bg-blue-50",
        contact_icon_bg: "bg-blue-100",
        social_item_class: "bg-blue-100 hover:bg-blue-200 text-blue-600",
        close_button_class: "hover:bg-gray-100 text-gray-600",
        footer_border_class: "border-gray-200"
      }

      "developer" -> %{
        fab_class: "bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700",
        panel_class: "bg-gray-900",
        text_class: "text-white",
        subtitle_class: "text-gray-300",
        accent_class: "text-green-400",
        muted_class: "text-gray-400",
        section_header_class: "text-gray-300",
        nav_item_class: "hover:bg-green-900 hover:bg-opacity-30",
        hover_text_class: "text-green-400",
        icon_bg_class: "bg-green-900 bg-opacity-50 group-hover:bg-opacity-70",
        icon_class: "text-green-400",
        arrow_class: "text-gray-400",
        primary_button_class: "bg-gradient-to-r from-green-600 to-emerald-600 hover:from-green-700 hover:to-emerald-700",
        secondary_button_class: "border-green-400 text-green-400 hover:bg-green-900 hover:bg-opacity-30",
        contact_item_class: "hover:bg-green-900 hover:bg-opacity-30",
        contact_icon_bg: "bg-green-900 bg-opacity-50",
        social_item_class: "bg-green-900 bg-opacity-50 hover:bg-opacity-70 text-green-400",
        close_button_class: "hover:bg-gray-800 text-gray-300",
        footer_border_class: "border-gray-700"
      }

      "designer" -> %{
        fab_class: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700",
        panel_class: "bg-gradient-to-br from-purple-50 to-pink-50",
        text_class: "text-gray-900",
        subtitle_class: "text-purple-700",
        accent_class: "text-purple-600",
        muted_class: "text-purple-500",
        section_header_class: "text-purple-700",
        nav_item_class: "hover:bg-white hover:bg-opacity-60",
        hover_text_class: "text-purple-600",
        icon_bg_class: "bg-purple-100 group-hover:bg-purple-200",
        icon_class: "text-purple-600",
        arrow_class: "text-purple-400",
        primary_button_class: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700",
        secondary_button_class: "border-purple-300 text-purple-600 hover:bg-white hover:bg-opacity-60",
        contact_item_class: "hover:bg-white hover:bg-opacity-60",
        contact_icon_bg: "bg-purple-100",
        social_item_class: "bg-purple-100 hover:bg-purple-200 text-purple-600",
        close_button_class: "hover:bg-white hover:bg-opacity-60 text-purple-600",
        footer_border_class: "border-purple-200"
      }

      "minimalist" -> %{
        fab_class: "bg-gray-900 hover:bg-gray-800",
        panel_class: "bg-white",
        text_class: "text-gray-900",
        subtitle_class: "text-gray-600",
        accent_class: "text-gray-900",
        muted_class: "text-gray-500",
        section_header_class: "text-gray-700",
        nav_item_class: "hover:bg-gray-50",
        hover_text_class: "text-gray-900",
        icon_bg_class: "bg-gray-100 group-hover:bg-gray-200",
        icon_class: "text-gray-600",
        arrow_class: "text-gray-400",
        primary_button_class: "bg-gray-900 hover:bg-gray-800",
        secondary_button_class: "border-gray-300 text-gray-700 hover:bg-gray-50",
        contact_item_class: "hover:bg-gray-50",
        contact_icon_bg: "bg-gray-100",
        social_item_class: "bg-gray-100 hover:bg-gray-200 text-gray-600",
        close_button_class: "hover:bg-gray-100 text-gray-600",
        footer_border_class: "border-gray-200"
      }

      "consultant" -> %{
        fab_class: "bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700",
        panel_class: "bg-white",
        text_class: "text-gray-900",
        subtitle_class: "text-blue-700",
        accent_class: "text-blue-600",
        muted_class: "text-gray-500",
        section_header_class: "text-blue-700",
        nav_item_class: "hover:bg-blue-50",
        hover_text_class: "text-blue-600",
        icon_bg_class: "bg-blue-100 group-hover:bg-blue-200",
        icon_class: "text-blue-600",
        arrow_class: "text-blue-400",
        primary_button_class: "bg-gradient-to-r from-blue-600 to-cyan-600 hover:from-blue-700 hover:to-cyan-700",
        secondary_button_class: "border-blue-300 text-blue-600 hover:bg-blue-50",
        contact_item_class: "hover:bg-blue-50",
        contact_icon_bg: "bg-blue-100",
        social_item_class: "bg-blue-100 hover:bg-blue-200 text-blue-600",
        close_button_class: "hover:bg-blue-100 text-blue-600",
        footer_border_class: "border-blue-200"
      }

      "academic" -> %{
        fab_class: "bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700",
        panel_class: "bg-white",
        text_class: "text-gray-900",
        subtitle_class: "text-green-700",
        accent_class: "text-green-600",
        muted_class: "text-gray-500",
        section_header_class: "text-green-700",
        nav_item_class: "hover:bg-green-50",
        hover_text_class: "text-green-600",
        icon_bg_class: "bg-green-100 group-hover:bg-green-200",
        icon_class: "text-green-600",
        arrow_class: "text-green-400",
        primary_button_class: "bg-gradient-to-r from-green-600 to-teal-600 hover:from-green-700 hover:to-teal-700",
        secondary_button_class: "border-green-300 text-green-600 hover:bg-green-50",
        contact_item_class: "hover:bg-green-50",
        contact_icon_bg: "bg-green-100",
        social_item_class: "bg-green-100 hover:bg-green-200 text-green-600",
        close_button_class: "hover:bg-green-100 text-green-600",
        footer_border_class: "border-green-200"
      }

      _ -> %{
        fab_class: "bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700",
        panel_class: "bg-white",
        text_class: "text-gray-900",
        subtitle_class: "text-gray-600",
        accent_class: "text-purple-600",
        muted_class: "text-gray-500",
        section_header_class: "text-gray-700",
        nav_item_class: "hover:bg-purple-50",
        hover_text_class: "text-purple-600",
        icon_bg_class: "bg-purple-100 group-hover:bg-purple-200",
        icon_class: "text-purple-600",
        arrow_class: "text-gray-400",
        primary_button_class: "bg-gradient-to-r from-purple-600 to-blue-600 hover:from-purple-700 hover:to-blue-700",
        secondary_button_class: "border-purple-300 text-purple-600 hover:bg-purple-50",
        contact_item_class: "hover:bg-purple-50",
        contact_icon_bg: "bg-purple-100",
        social_item_class: "bg-purple-100 hover:bg-purple-200 text-purple-600",
        close_button_class: "hover:bg-purple-100 text-purple-600",
        footer_border_class: "border-purple-200"
      }
    end
  end

  # 🔥 ENHANCED SECTION ICONS WITH THEME SUPPORT
  defp render_section_icon_enhanced(section_type, nav_style) do
    icon_class = nav_style.icon_class

    case section_type do
      :intro ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/>
        </svg>
        """)
      :experience ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 13.255A23.931 23.931 0 0112 15c-3.183 0-6.22-.62-9-1.745M16 6V4a2 2 0 00-2-2h-4a2 2 0 00-2-2v2m8 0V6a2 2 0 012 2v6a2 2 0 01-2 2H8a2 2 0 01-2-2V8a2 2 0 012-2h8z"/>
        </svg>
        """)
      :skills ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z"/>
        </svg>
        """)
      :education ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 14l9-5-9-5-9 5 9 5zm0 0v5m0-5h-.01M12 14l-9 5m9-5l9 5"/>
        </svg>
        """)
      :projects ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
        </svg>
        """)
      :contact ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/>
        </svg>
        """)
      _ ->
        Phoenix.HTML.raw("""
        <svg class="#{icon_class} w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/>
        </svg>
        """)
    end
  end

  defp get_designer_theme_colors(customization) when is_map(customization) do
    primary = get_in(customization, ["primary_color"]) || "#a855f7"
    secondary = get_in(customization, ["secondary_color"]) || "#ec4899"
    accent = get_in(customization, ["accent_color"]) || "#f59e0b"

    %{
      primary: primary,
      secondary: secondary,
      accent: accent
    }
  end

  defp get_designer_theme_colors(_) do
    %{
      primary: "#a855f7",
      secondary: "#ec4899",
      accent: "#f59e0b"
    }
  end

  defp render_mobile_navigation(assigns) do
    render_enhanced_mobile_navigation(assigns)
  end

  # Section content renderer for templates
  defp render_section_content_for_template(section, template_theme) do
    try do
      # Use existing render_section_content_safe function
      content = render_section_content_safe(section)

      # Wrap content in theme-appropriate styling
      content_class = case template_theme do
        :developer -> "text-gray-300 leading-relaxed"
        :creative -> "text-white/90 leading-relaxed"
        :academic -> "text-gray-700 leading-relaxed font-serif"
        :designer -> "text-gray-700 leading-relaxed"
        _ -> "text-gray-600 leading-relaxed"
      end

      Phoenix.HTML.raw("""
      <div class="#{content_class}">
        #{content}
      </div>
      """)
    rescue
      _ ->
        Phoenix.HTML.raw("""
        <div class="text-gray-500 italic">Content loading...</div>
        """)
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
    case section_type do
      :intro -> "Introduction"
      :experience -> "Experience"
      :skills -> "Skills"
      :education -> "Education"
      :projects -> "Projects"
      :featured_project -> "Featured Project"
      :case_study -> "Case Study"
      :contact -> "Contact"
      :testimonial -> "Testimonial"
      :achievements -> "Achievements"
      :media_showcase -> "Media Showcase"
      _ -> "Section"
    end
  end

  defp render_portfolio_metrics(assigns) do
    ~H"""
    <div class="grid grid-cols-3 gap-6">
      <%= for metric <- get_display_metrics(@portfolio) do %>
        <div class="text-center">
          <div class={[
            "text-3xl font-bold",
            case @template_theme do
              :executive -> "text-slate-600"
              :developer -> "text-green-400"
              :creative -> "text-yellow-400"
              :minimalist -> "text-gray-900"
              :corporate -> "text-blue-600"
              _ -> "portfolio-accent"
            end
          ]}>
            <%= metric.value %>
          </div>
          <div class={[
            "text-sm",
            case @template_theme do
              :executive -> "text-slate-500"
              :developer -> "text-gray-300"
              :creative -> "text-white/80"
              :minimalist -> "text-gray-600"
              :corporate -> "text-gray-600"
              _ -> "portfolio-secondary"
            end
          ]}>
            <%= metric.description %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp get_display_metrics(portfolio) do
    display_settings = get_in(portfolio.customization, ["display_settings"]) || %{}
    custom_metrics = Map.get(display_settings, "custom_metrics", [])

    # Default metrics if no custom ones are set
    if length(custom_metrics) == 0 do
      [
        %{"value" => "#{length(portfolio.portfolio_sections || [])}", "description" => "Sections"},
        %{"value" => "Active", "description" => "Status"},
        %{"value" => "Ready", "description" => "State"}
      ]
    else
      # Filter out empty metrics and limit to 3-4 for UI
      custom_metrics
      |> Enum.filter(fn metric ->
        Map.get(metric, "label", "") != "" and Map.get(metric, "value", "") != ""
      end)
      |> Enum.take(4)
      |> Enum.map(fn metric ->
        %{
          "value" => Map.get(metric, "value"),
          "description" => Map.get(metric, "description", Map.get(metric, "label"))
        }
      end)
    end
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

  defp calculate_portfolio_metrics(portfolio) do
    # Calculate basic portfolio metrics
    sections = portfolio.sections || []
    visible_sections = Enum.filter(sections, & &1.visible)

    %{
      total_sections: length(sections),
      visible_sections: length(visible_sections),
      completion_rate: calculate_completion_rate(portfolio),
      last_updated: portfolio.updated_at
    }
  end

  defp calculate_completion_rate(portfolio) do
    # Basic completion rate calculation
    score = 0

    score = if portfolio.title && portfolio.title != "", do: score + 20, else: score
    score = if portfolio.description && portfolio.description != "", do: score + 20, else: score

    sections = portfolio.sections || []
    section_score = min(length(sections) * 10, 40)
    score = score + section_score

    customization = portfolio.customization || %{}
    if map_size(customization) > 0, do: score + 20, else: score
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

    defp process_portfolio_customization_fixed(portfolio) do
    theme = portfolio.theme || "executive"
    customization = portfolio.customization || %{}

    # Get template layout from theme and customization
    template_layout = determine_template_layout(theme, customization)

    # Get enhanced template config
    template_config = get_enhanced_template_config(theme, customization)

    # Generate CSS for the portfolio
    customization_css = generate_portfolio_css(portfolio, template_config, theme)

    {template_config, customization_css, template_layout}
  end

  # 🔥 FIX: Template layout determination
  defp determine_template_layout(theme, customization) do
    # Check if layout is explicitly set in customization
    case Map.get(customization, "layout") do
      layout when is_binary(layout) and layout != "" -> layout
      _ ->
        # Determine layout from theme
        case theme do
          "executive" -> "dashboard"
          "developer" -> "terminal"
          "designer" -> "gallery"
          "minimalist" -> "minimal"
          "consultant" -> "case_study"
          "academic" -> "academic"
          _ -> "dashboard"  # Default fallback
        end
    end
  end

  # 🔥 FIX: Enhanced template configuration
  defp get_enhanced_template_config(theme, customization) do
    base_config = %{
      "primary_color" => "#3b82f6",
      "secondary_color" => "#64748b",
      "accent_color" => "#f59e0b",
      "background_color" => "#ffffff",
      "text_color" => "#1f2937",
      "layout" => "dashboard"
    }

    template_specific = case theme do
      "executive" -> %{
        "primary_color" => "#1e40af",
        "secondary_color" => "#64748b",
        "accent_color" => "#3b82f6",
        "layout" => "dashboard"
      }
      "developer" -> %{
        "primary_color" => "#059669",
        "secondary_color" => "#374151",
        "accent_color" => "#10b981",
        "layout" => "terminal",
        "background_color" => "#0f172a",
        "text_color" => "#e2e8f0"
      }
      "designer" -> %{
        "primary_color" => "#7c3aed",
        "secondary_color" => "#ec4899",
        "accent_color" => "#f59e0b",
        "layout" => "gallery"
      }
      "minimalist" -> %{
        "primary_color" => "#374151",
        "secondary_color" => "#6b7280",
        "accent_color" => "#059669",
        "layout" => "minimal"
      }
      "consultant" -> %{
        "primary_color" => "#0891b2",
        "secondary_color" => "#0284c7",
        "accent_color" => "#6366f1",
        "layout" => "case_study"
      }
      "academic" -> %{
        "primary_color" => "#059669",
        "secondary_color" => "#047857",
        "accent_color" => "#10b981",
        "layout" => "academic"
      }
      _ -> %{}
    end

    # Merge base config with template-specific and user customization
    base_config
    |> Map.merge(template_specific)
    |> Map.merge(customization)
  end

  # 🔥 FIX: Enhanced CSS generation
  defp generate_portfolio_css(portfolio, template_config, theme) do
    customization = portfolio.customization || %{}

    # Merge template config with user customization
    colors = Map.merge(template_config, customization)

    primary = Map.get(colors, "primary_color", "#3b82f6")
    secondary = Map.get(colors, "secondary_color", "#64748b")
    accent = Map.get(colors, "accent_color", "#f59e0b")
    background = Map.get(colors, "background_color", "#ffffff")
    text = Map.get(colors, "text_color", "#1f2937")

    """
    <style>
    :root {
      --primary-color: #{primary};
      --secondary-color: #{secondary};
      --accent-color: #{accent};
      --background-color: #{background};
      --text-color: #{text};
    }

    .portfolio-bg {
      background-color: var(--background-color);
      color: var(--text-color);
    }

    .text-primary { color: var(--primary-color); }
    .bg-primary { background-color: var(--primary-color); }
    .border-primary { border-color: var(--primary-color); }
    .text-secondary { color: var(--secondary-color); }
    .bg-secondary { background-color: var(--secondary-color); }
    .text-accent { color: var(--accent-color); }
    .bg-accent { background-color: var(--accent-color); }
    .text-portfolio { color: var(--text-color); }

    /* Ensure good contrast */
    .bg-primary, .bg-secondary, .bg-accent {
      color: white;
    }

    /* Template-specific styles */
    #{get_theme_specific_css(theme)}
    </style>
    """
  end

  # 🔥 FIX: Theme-specific CSS
  defp get_theme_specific_css(theme) do
    case theme do
      "developer" ->
        """
        body { font-family: 'JetBrains Mono', 'Monaco', 'Menlo', monospace; }
        .portfolio-bg { background-color: #0f172a; color: #e2e8f0; }
        """
      "designer" ->
        """
        body { font-family: 'Inter', system-ui, sans-serif; }
        .portfolio-bg { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
        """
      "minimalist" ->
        """
        body { font-family: 'Inter', system-ui, sans-serif; }
        .portfolio-bg { background-color: #ffffff; }
        section { border: none; box-shadow: none; }
        """
      "academic" ->
        """
        body { font-family: 'Crimson Text', Georgia, serif; }
        .portfolio-bg { background-color: #fefefe; }
        """
      _ ->
        """
        body { font-family: system-ui, -apple-system, sans-serif; }
        """
    end
  end

  defp render_skills_content_only(assigns) do
    skill_categories = assigns.skill_categories || %{}
    flat_skills = assigns.flat_skills || []

    cond do
      map_size(skill_categories) > 0 ->
        render_categorized_skills_view(assigns)
      length(flat_skills) > 0 ->
        render_flat_skills_view(assigns)
      true ->
        Phoenix.HTML.raw("""
        <div class="text-center py-8">
          <div class="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
            <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6"/>
            </svg>
          </div>
          <p class="text-gray-500">No skills added yet</p>
        </div>
        """)
    end
  end

  defp normalize_theme(theme) when is_binary(theme), do: theme
  defp normalize_theme(theme) when is_atom(theme), do: Atom.to_string(theme)
  defp normalize_theme(_), do: "executive"
end
