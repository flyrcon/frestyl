# File: lib/frestyl_web/live/portfolio_live/components/enhanced_hero_renderer.ex

defmodule FrestylWeb.PortfolioLive.Components.EnhancedHeroRenderer do
  @moduledoc """
  ENHANCED VERSION: Enhanced hero section rendering with improved layouts from temp_show.ex.
  Incorporates video/social precedence logic, enhanced animations, and superior styling.
  Video takes precedence, social links display nearby, smart fallbacks when neither present.
  """

  use Phoenix.Component
  import FrestylWeb.CoreComponents
  import Phoenix.HTML, only: [raw: 1]
  alias FrestylWeb.PortfolioLive.Components.ThemeConsistencyManager

  # ============================================================================
  # MAIN HERO SECTION RENDERER
  # ============================================================================

  def render_enhanced_hero(portfolio, sections, color_scheme \\ "blue", display_options \\ %{}) do
    # Extract hero content from portfolio and sections
    hero_data = extract_hero_data(portfolio, sections)

    # Determine hero layout based on available content
    hero_layout = determine_hero_layout(hero_data)

    # Get theme-based styling with enhanced features
    theme_config = get_enhanced_hero_theme_config(portfolio.theme || "professional", color_scheme)

    # Render based on determined layout with enhanced features
    case hero_layout do
      :video_primary -> render_enhanced_video_primary_hero(hero_data, theme_config, display_options)
      :social_primary -> render_enhanced_social_primary_hero(hero_data, theme_config, display_options)
      :content_only -> render_enhanced_content_only_hero(hero_data, theme_config, display_options)
      :minimal -> render_enhanced_minimal_hero(hero_data, theme_config, display_options)
    end
  end

  # ============================================================================
  # HERO DATA EXTRACTION AND ANALYSIS
  # ============================================================================

  defp extract_hero_data(portfolio, sections) do
    # Find hero section if it exists
    hero_section = Enum.find(sections, fn section ->
      normalize_section_type(section.section_type) in [:hero, :intro, :about]
    end)

    # Extract video content (takes precedence)
    video_data = extract_video_content(portfolio, hero_section)

    # Extract social content
    social_data = extract_social_content(portfolio, hero_section, sections)

    # Extract basic profile content
    profile_data = extract_profile_content(portfolio, hero_section)

    # Extract contact information
    contact_data = extract_contact_content(sections)

    %{
      video: video_data,
      social: social_data,
      profile: profile_data,
      contact: contact_data,
      portfolio: portfolio,
      hero_section: hero_section
    }
  end

  defp extract_video_content(portfolio, hero_section) do
    video_sources = []

    # Check hero section content
    if hero_section do
      section_content = hero_section.content || %{}

      # Multiple possible video field names
      video_fields = ["video_url", "intro_video", "video", "media_url"]
      video_url = Enum.find_value(video_fields, fn field ->
        value = Map.get(section_content, field)
        if value && String.trim(value) != "", do: value, else: nil
      end)

      if video_url do
        video_sources = [%{
          url: video_url,
          type: detect_video_type(video_url),
          source: "hero_section",
          title: Map.get(section_content, "video_title", "Introduction Video")
        } | video_sources]
      end
    end

    # Check portfolio-level video settings
    portfolio_customization = portfolio.customization || %{}
    if portfolio_video = Map.get(portfolio_customization, "intro_video_url") do
      video_sources = [%{
        url: portfolio_video,
        type: detect_video_type(portfolio_video),
        source: "portfolio_settings",
        title: "Portfolio Introduction"
      } | video_sources]
    end

    # Return the first (highest priority) video found
    %{
      has_video: length(video_sources) > 0,
      primary_video: List.first(video_sources),
      all_videos: video_sources
    }
  end

  defp extract_social_content(portfolio, hero_section, sections) do
    social_links = %{}

    # Check hero section social links
    if hero_section do
      section_social = get_in(hero_section.content || %{}, ["social_links"]) || %{}
      social_links = Map.merge(social_links, section_social)
    end

    # Check portfolio-level social links
    portfolio_social = get_in(portfolio.customization || %{}, ["social_links"]) || %{}
    social_links = Map.merge(social_links, portfolio_social)

    # Check contact section for additional social links
    contact_section = Enum.find(sections, fn section ->
      normalize_section_type(section.section_type) == :contact
    end)

    if contact_section do
      contact_social = get_in(contact_section.content || %{}, ["social_links"]) || %{}
      social_links = Map.merge(social_links, contact_social)
    end

    # Filter out empty links
    social_links = social_links
    |> Enum.filter(fn {_platform, url} ->
      url && String.trim(url) != ""
    end)
    |> Enum.into(%{})

    %{
      has_social: map_size(social_links) > 0,
      links: social_links,
      platforms: Map.keys(social_links)
    }
  end

  defp extract_profile_content(portfolio, hero_section) do
    content = %{
      name: portfolio.title || "",
      headline: "",
      summary: "",
      tagline: "",
      location: "",
      avatar_url: ""
    }

    # Extract from hero section if available
    if hero_section do
      section_content = hero_section.content || %{}

      content = content
      |> Map.put(:headline, Map.get(section_content, "headline", content.headline))
      |> Map.put(:summary, Map.get(section_content, "summary", content.summary))
      |> Map.put(:tagline, Map.get(section_content, "tagline", content.tagline))
      |> Map.put(:location, Map.get(section_content, "location", content.location))
    end

    # Extract from portfolio customization
    customization = portfolio.customization || %{}
    content = content
    |> Map.put(:avatar_url, Map.get(customization, "avatar_url", content.avatar_url))
    |> Map.put(:tagline, Map.get(customization, "tagline", content.tagline))

    # Use portfolio description as fallback summary
    if content.summary == "" do
      content = Map.put(content, :summary, portfolio.description || "")
    end

    %{
      has_content: has_meaningful_profile_content?(content),
      data: content
    }
  end

  defp extract_contact_content(sections) do
    contact_section = Enum.find(sections, fn section ->
      normalize_section_type(section.section_type) == :contact
    end)

    if contact_section do
      content = contact_section.content || %{}
      %{
        email: Map.get(content, "email", ""),
        phone: Map.get(content, "phone", ""),
        location: Map.get(content, "location", ""),
        website: Map.get(content, "website", "")
      }
    else
      %{email: "", phone: "", location: "", website: ""}
    end
  end

  # ============================================================================
  # HERO LAYOUT DETERMINATION LOGIC
  # ============================================================================

  defp determine_hero_layout(hero_data) do
    cond do
      # Video takes precedence - if video exists, use video-primary layout
      hero_data.video.has_video ->
        :video_primary

      # If no video but has social links and meaningful profile content
      hero_data.social.has_social && hero_data.profile.has_content ->
        :social_primary

      # If has meaningful profile content (no video, maybe limited social)
      hero_data.profile.has_content ->
        :content_only

      # Minimal fallback - basic portfolio info only
      true ->
        :minimal
    end
  end

  defp has_meaningful_profile_content?(content) do
    meaningful_fields = [:headline, :summary, :tagline]
    Enum.any?(meaningful_fields, fn field ->
      value = Map.get(content, field, "")
      String.trim(value) != ""
    end)
  end

  defp get_video_aspect_ratio_class(display_options \\ %{}) do
    aspect_ratio = Map.get(display_options, :aspect_ratio, "16/9")
    case aspect_ratio do
      "16/9" -> "aspect-video"
      "9/16" -> "aspect-[9/16]"
      "1/1" -> "aspect-square"
      _ -> "aspect-video"
    end
  end

  defp get_video_object_fit(display_options \\ %{}) do
    display_mode = Map.get(display_options, :display_mode, "original")
    case display_mode do
      "original" -> "object-contain"
      "crop_" <> _ -> "object-cover"
      _ -> "object-cover"
    end
  end

  # ============================================================================
  # ENHANCED VIDEO-PRIMARY HERO LAYOUT (from temp_show.ex)
  # ============================================================================

  defp render_enhanced_video_primary_hero(hero_data, theme_config, display_options) do
    video = hero_data.video.primary_video
    profile = hero_data.profile.data
    social = hero_data.social

    """
    <section class="enhanced-video-hero relative overflow-hidden min-h-screen #{theme_config.background_class}">
      <!-- Enhanced Animated Background Elements -->
      <div class="absolute inset-0">
        <div class="absolute top-10 left-10 w-20 h-20 bg-white bg-opacity-10 rounded-full animate-pulse"></div>
        <div class="absolute top-32 right-20 w-16 h-16 bg-white bg-opacity-5 rounded-full animate-pulse delay-1000"></div>
        <div class="absolute bottom-20 left-32 w-24 h-24 bg-white bg-opacity-10 rounded-full animate-pulse delay-2000"></div>
      </div>

      <!-- Enhanced Video Background (if available) with display options -->
      #{if video.url, do: render_enhanced_video_background(video.url, display_options), else: ""}

      <!-- Hero Overlay with Enhanced Gradient -->
      <div class="hero-overlay absolute inset-0 bg-gradient-to-br from-black/30 via-black/20 to-transparent"></div>

      <!-- Enhanced Hero Content -->
      <div class="relative z-10 min-h-screen flex items-center">
        <div class="max-w-7xl mx-auto px-6 py-20">
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 items-center">
            <!-- Enhanced Left Column: Content -->
            <div class="#{theme_config.text_primary}">
              <!-- Status Indicator -->
              <div class="inline-flex items-center px-4 py-2 bg-white bg-opacity-20 backdrop-blur-sm rounded-full text-sm font-medium mb-6">
                <span class="w-2 h-2 bg-green-400 rounded-full mr-2 animate-pulse"></span>
                Available for opportunities
              </div>

              <h1 class="text-4xl lg:text-6xl font-bold mb-6 leading-tight">
                #{profile.name || "Professional Portfolio"}
              </h1>

              <p class="text-xl lg:text-2xl #{theme_config.text_secondary} mb-8 leading-relaxed">
                #{profile.title || "Creating exceptional digital experiences"}
              </p>

              <!-- Enhanced CTA Buttons -->
              <div class="flex flex-col sm:flex-row gap-4">
                <button class="enhanced-primary-cta #{theme_config.primary_button} px-8 py-4 rounded-xl font-semibold text-lg transition-all duration-300 transform hover:scale-105">
                  View My Work
                </button>
                <button class="enhanced-secondary-cta #{theme_config.secondary_button} px-8 py-4 rounded-xl font-semibold text-lg transition-all duration-300">
                  Get In Touch
                </button>
              </div>
            </div>

            <!-- Enhanced Right Column: Video Player -->
            <div class="lg:order-last">
              #{render_enhanced_video_player(video, theme_config, display_options)}
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end


  # ============================================================================
  # ENHANCED SOCIAL-PRIMARY HERO LAYOUT (from temp_show.ex)
  # ============================================================================

  defp render_enhanced_social_primary_hero(hero_data, theme_config, display_options \\ %{}) do
    profile = hero_data.profile.data
    social = hero_data.social
    contact = hero_data.contact

    """
    <section class="enhanced-social-hero relative overflow-hidden min-h-screen #{theme_config.background_class}">
      <!-- Enhanced Geometric Background -->
      <div class="absolute inset-0">
        <svg class="absolute inset-0 w-full h-full" viewBox="0 0 1200 800" fill="none">
          <defs>
            <pattern id="enhanced-hero-pattern" x="0" y="0" width="100" height="100" patternUnits="userSpaceOnUse">
              <circle cx="50" cy="50" r="1" fill="white" opacity="0.1"/>
            </pattern>
          </defs>
          <rect width="1200" height="800" fill="url(#enhanced-hero-pattern)"/>
        </svg>
      </div>

      <!-- Enhanced Content -->
      <div class="relative z-10 min-h-screen flex items-center">
        <div class="max-w-6xl mx-auto px-6 py-20 text-center">

          <!-- Enhanced Avatar/Profile Image -->
          #{if profile.avatar_url != "", do: render_enhanced_profile_avatar(profile.avatar_url, theme_config), else: render_enhanced_default_avatar(profile.name, theme_config)}

          <!-- Enhanced Profile Content -->
          <div class="enhanced-profile-content mt-8">
            #{if profile.name != "", do: "<h1 class='text-4xl lg:text-6xl font-bold #{theme_config.text_primary} mb-6'>#{profile.name}</h1>", else: ""}
            #{if profile.headline != "", do: "<h2 class='text-xl lg:text-3xl #{theme_config.text_secondary} mb-8'>#{profile.headline}</h2>", else: ""}
            #{if profile.tagline != "", do: "<p class='text-lg lg:text-xl #{theme_config.text_muted} mb-8 max-w-3xl mx-auto'>#{profile.tagline}</p>", else: ""}
            #{if profile.summary != "", do: "<p class='#{theme_config.text_body} leading-relaxed mb-12 max-w-4xl mx-auto text-lg'>#{profile.summary}</p>", else: ""}
          </div>

          <!-- Enhanced Prominent Social Links -->
          #{render_enhanced_prominent_social_links(social, theme_config)}

          <!-- Enhanced Contact Information -->
          #{if has_contact_info?(contact), do: render_enhanced_contact_bar(contact, theme_config), else: ""}

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # ENHANCED CONTENT-ONLY HERO LAYOUT (from temp_show.ex)
  # ============================================================================

  defp render_enhanced_content_only_hero(hero_data, theme_config, display_options \\ %{}) do
    profile = hero_data.profile.data
    social = hero_data.social

    """
    <section class="enhanced-content-hero relative overflow-hidden min-h-screen #{theme_config.background_class}">
      <!-- Enhanced Background Pattern -->
      <div class="absolute inset-0 opacity-20">
        <div class="absolute top-10 left-10 w-64 h-64 bg-white rounded-full mix-blend-overlay filter blur-xl animate-float"></div>
        <div class="absolute top-60 right-40 w-80 h-80 #{theme_config.accent_color} rounded-full mix-blend-overlay filter blur-xl animate-float-delayed"></div>
        <div class="absolute bottom-40 left-60 w-72 h-72 #{theme_config.secondary_color} rounded-full mix-blend-overlay filter blur-xl animate-float-slow"></div>
      </div>

      <div class="relative z-10 min-h-screen flex items-center">
        <div class="max-w-5xl mx-auto px-6 py-20 text-center">

          #{if profile.avatar_url != "", do: render_enhanced_profile_avatar(profile.avatar_url, theme_config), else: ""}

          <div class="enhanced-profile-content #{if profile.avatar_url != "", do: "mt-8", else: ""}">
            #{if profile.name != "", do: "<h1 class='text-4xl lg:text-5xl font-bold #{theme_config.text_primary} mb-6'>#{profile.name}</h1>", else: ""}
            #{if profile.headline != "", do: "<h2 class='text-xl lg:text-2xl #{theme_config.text_secondary} mb-6'>#{profile.headline}</h2>", else: ""}
            #{if profile.tagline != "", do: "<p class='text-lg #{theme_config.text_muted} mb-8 max-w-3xl mx-auto'>#{profile.tagline}</p>", else: ""}
            #{if profile.summary != "", do: "<div class='#{theme_config.text_body} leading-relaxed mb-10 max-w-4xl mx-auto text-lg'><p>#{profile.summary}</p></div>", else: ""}

            <!-- Enhanced Action Buttons -->
            <div class="flex flex-col sm:flex-row gap-4 justify-center mb-8">
              <button class="enhanced-primary-cta #{theme_config.primary_button} px-8 py-3 rounded-lg font-semibold transition-all duration-300 transform hover:scale-105">
                View My Work
              </button>
              <button class="enhanced-secondary-cta #{theme_config.secondary_button} px-8 py-3 rounded-lg font-semibold transition-all duration-300">
                Get In Touch
              </button>
            </div>

            <!-- Enhanced Social Links (if available) -->
            #{if social.has_social, do: render_enhanced_social_links_bar(social, theme_config), else: ""}
          </div>

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # ENHANCED MINIMAL HERO LAYOUT (from temp_show.ex)
  # ============================================================================

  defp render_enhanced_minimal_hero(hero_data, theme_config, display_options \\ %{}) do
    portfolio = hero_data.portfolio

    """
    <section class="enhanced-minimal-hero relative overflow-hidden min-h-screen #{theme_config.background_class}">
      <!-- Subtle Background Pattern -->
      <div class="absolute inset-0 opacity-5">
        <div class="grid grid-cols-12 gap-4 p-8">
          #{Enum.map(1..144, fn i ->
            """
            <div class="aspect-square border #{theme_config.border_color} rounded" style="animation-delay: #{rem(i, 12) * 0.1}s; animation: fadeIn 3s ease-in-out infinite alternate"></div>
            """
          end) |> Enum.join("")}
        </div>
      </div>

      <div class="relative z-10 min-h-screen flex items-center">
        <div class="max-w-4xl mx-auto px-6 py-20 text-center">

          <h1 class="text-3xl lg:text-4xl font-bold #{theme_config.text_primary} mb-4">
            #{portfolio.title}
          </h1>

          #{if portfolio.description && portfolio.description != "", do: "<p class='text-lg #{theme_config.text_body} leading-relaxed max-w-2xl mx-auto mb-8'>#{portfolio.description}</p>", else: ""}

          <div class="flex flex-col sm:flex-row gap-4 justify-center">
            <button class="enhanced-minimal-cta #{theme_config.primary_button} px-6 py-3 rounded-lg font-semibold transition-all duration-300 transform hover:scale-105">
              Explore Portfolio
            </button>
          </div>

        </div>
      </div>
    </section>
    """
  end

  # ============================================================================
  # ENHANCED COMPONENT RENDERERS (from temp_show.ex)
  # ============================================================================

  defp render_enhanced_video_player(video, theme_config, display_options \\ %{}) do
    case video.type do
      :youtube -> render_enhanced_youtube_embed(video.url, theme_config, display_options)
      :vimeo -> render_enhanced_vimeo_embed(video.url, theme_config, display_options)
      :direct -> render_enhanced_direct_video(video.url, theme_config, display_options)
      _ -> render_enhanced_video_placeholder(video.title, theme_config, display_options)
    end
  end

  defp render_enhanced_youtube_embed(url, theme_config, display_options \\ %{}) do
    embed_id = extract_youtube_id(url)
    aspect_class = get_video_aspect_ratio_class(display_options)

    """
    <div class="enhanced-video-wrapper #{aspect_class} bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
      <iframe
        src="https://www.youtube.com/embed/#{embed_id}?rel=0&modestbranding=1&autoplay=0"
        frameborder="0"
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
        allowfullscreen
        class="w-full h-full">
      </iframe>
    </div>
    """
  end

  defp render_enhanced_vimeo_embed(url, theme_config, display_options \\ %{}) do
    embed_id = extract_vimeo_id(url)
    aspect_class = get_video_aspect_ratio_class(display_options)

    """
    <div class="enhanced-video-wrapper #{aspect_class} bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
      <iframe
        src="https://player.vimeo.com/video/#{embed_id}?badge=0&autopause=0&player_id=0&app_id=58479"
        frameborder="0"
        allow="autoplay; fullscreen; picture-in-picture"
        allowfullscreen
        class="w-full h-full">
      </iframe>
    </div>
    """
  end

  defp render_enhanced_direct_video(url, theme_config, display_options \\ %{}) do
    aspect_class = get_video_aspect_ratio_class(display_options)
    object_fit = get_video_object_fit(display_options)

    """
    <div class="enhanced-video-wrapper #{aspect_class} bg-gray-900 rounded-xl overflow-hidden shadow-2xl">
      <video controls class="w-full h-full #{object_fit}" preload="metadata">
        <source src="#{url}" type="video/mp4">
        <source src="#{url}" type="video/webm">
        <source src="#{url}" type="video/ogg">
        Your browser does not support the video tag.
      </video>
    </div>
    """
  end

  defp render_enhanced_video_placeholder(title, theme_config, display_options \\ %{}) do
    aspect_class = get_video_aspect_ratio_class(display_options)

    """
    <div class="enhanced-video-placeholder #{aspect_class} #{theme_config.card_background} rounded-xl border-2 border-dashed #{theme_config.border_color} flex items-center justify-center">
      <div class="text-center">
        <svg class="w-16 h-16 #{theme_config.text_muted} mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"></path>
        </svg>
        <p class="#{theme_config.text_muted} font-medium">#{title}</p>
        <p class="#{theme_config.text_muted} text-sm">Video content will appear here</p>
      </div>
    </div>
    """
  end


  defp render_enhanced_profile_avatar(avatar_url, theme_config) do
    """
    <div class="enhanced-avatar-container mb-6">
      <img src="#{avatar_url}" alt="Profile" class="w-32 h-32 lg:w-40 lg:h-40 rounded-full mx-auto object-cover shadow-xl ring-4 #{theme_config.avatar_ring} transition-transform duration-300 hover:scale-105">
    </div>
    """
  end

  defp render_enhanced_default_avatar(name, theme_config) do
    initials = name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join("")
    |> String.upcase()

    """
    <div class="enhanced-avatar-container mb-6">
      <div class="w-32 h-32 lg:w-40 lg:h-40 #{theme_config.avatar_background} rounded-full mx-auto flex items-center justify-center shadow-xl ring-4 #{theme_config.avatar_ring} transition-transform duration-300 hover:scale-105">
        <span class="text-2xl lg:text-3xl font-bold #{theme_config.avatar_text}">#{initials}</span>
      </div>
    </div>
    """
  end

  defp render_enhanced_social_links_bar(social, theme_config) do
    social_items = Enum.map(social.links, fn {platform, url} ->
      icon = get_enhanced_social_icon(platform)
      platform_name = format_platform_name(platform)

      """
      <a href="#{url}" target="_blank" rel="noopener noreferrer"
         class="enhanced-social-link #{theme_config.social_link} hover:#{theme_config.social_link_hover} p-3 rounded-lg transition-all duration-200 transform hover:scale-110 flex items-center space-x-2"
         title="#{platform_name}">
        #{icon}
        <span class="hidden sm:inline font-medium">#{platform_name}</span>
      </a>
      """
    end)

    """
    <div class="enhanced-social-links-bar">
      <div class="flex flex-wrap justify-center gap-3 mt-6">
        #{Enum.join(social_items, "")}
      </div>
    </div>
    """
  end

  defp render_enhanced_prominent_social_links(social, theme_config) do
    social_items = Enum.map(social.links, fn {platform, url} ->
      icon = get_enhanced_social_icon(platform)
      platform_name = format_platform_name(platform)

      """
      <a href="#{url}" target="_blank" rel="noopener noreferrer"
         class="enhanced-prominent-social #{theme_config.prominent_social} hover:#{theme_config.prominent_social_hover} p-4 rounded-xl transition-all duration-300 transform hover:scale-105 flex flex-col items-center space-y-2 min-w-[120px]"
         title="Connect on #{platform_name}">
        <div class="text-2xl">#{icon}</div>
        <span class="font-semibold text-sm">#{platform_name}</span>
      </a>
      """
    end)

    """
    <div class="enhanced-prominent-social-links mb-12">
      <h3 class="text-lg #{theme_config.text_secondary} mb-6">Connect With Me</h3>
      <div class="flex flex-wrap justify-center gap-4">
        #{Enum.join(social_items, "")}
      </div>
    </div>
    """
  end

  defp render_enhanced_hero_social_links(social, theme_config) do
    if length(Map.keys(social.links)) > 0 do
      links_html = social.links
      |> Enum.map(fn {platform, url} ->
        icon = get_enhanced_social_icon_for_hero(platform)
        """
        <a href="#{url}" target="_blank" rel="noopener"
          class="w-12 h-12 bg-white bg-opacity-20 backdrop-blur-sm rounded-full flex items-center justify-center #{theme_config.text_primary} hover:bg-opacity-30 transition-all duration-300 transform hover:scale-110"
          title="#{String.capitalize(to_string(platform))}">
          #{icon}
        </a>
        """
      end)
      |> Enum.join("")

      """
      <div class="enhanced-hero-social flex items-center space-x-4 mb-8">
        <span class="#{theme_config.text_muted} mr-4">Connect:</span>
        #{links_html}
      </div>
      """
    else
      ""
    end
  end

  defp render_enhanced_contact_bar(contact, theme_config) do
    contact_items = []

    if contact.email != "" do
      contact_items = ["<a href='mailto:#{contact.email}' class='enhanced-contact-link #{theme_config.contact_link} hover:#{theme_config.contact_link_hover} flex items-center space-x-2 transition-all duration-300 transform hover:scale-105'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z'></path></svg><span>#{contact.email}</span></a>" | contact_items]
    end

    if contact.phone != "" do
      contact_items = ["<a href='tel:#{contact.phone}' class='enhanced-contact-link #{theme_config.contact_link} hover:#{theme_config.contact_link_hover} flex items-center space-x-2 transition-all duration-300 transform hover:scale-105'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z'></path></svg><span>#{contact.phone}</span></a>" | contact_items]
    end

    if contact.location != "" do
      contact_items = ["<div class='enhanced-contact-item #{theme_config.contact_item} flex items-center space-x-2'><svg class='w-4 h-4' fill='none' stroke='currentColor' viewBox='0 0 24 24'><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z'></path><path stroke-linecap='round' stroke-linejoin='round' stroke-width='2' d='M15 11a3 3 0 11-6 0 3 3 0 016 0z'></path></svg><span>#{contact.location}</span></div>" | contact_items]
    end

    if length(contact_items) > 0 do
      """
      <div class="enhanced-contact-bar mt-8 pt-8 border-t #{theme_config.border_color}">
        <div class="flex flex-wrap justify-center gap-6">
          #{Enum.join(Enum.reverse(contact_items), "")}
        </div>
      </div>
      """
    else
      ""
    end
  end

  defp render_enhanced_video_background(url, display_options \\ %{}) do
    aspect_class = get_video_aspect_ratio_class(display_options)
    object_fit = get_video_object_fit(display_options)

    """
    <div class="absolute inset-0 #{aspect_class} overflow-hidden">
      <video autoplay muted loop playsinline class="w-full h-full #{object_fit}">
        <source src="#{url}" type="video/mp4">
        <source src="#{url}" type="video/webm">
        Your browser does not support video backgrounds.
      </video>
      <div class="absolute inset-0 bg-black bg-opacity-40"></div>
    </div>
    """
  end

  defp render_enhanced_video_modal(video, theme_config) do
    """
    <div id="enhanced-video-modal" class="fixed inset-0 z-50 flex items-center justify-center bg-black bg-opacity-75 backdrop-blur-sm hidden">
      <div class="relative max-w-6xl w-full mx-4 max-h-[90vh]">
        <!-- Enhanced Close button -->
        <button onclick="closeVideoModal()" class="absolute -top-12 right-0 text-white hover:text-gray-300 z-10 transition-all duration-300 transform hover:scale-110">
          <svg class="w-8 h-8" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>

        <!-- Enhanced Video player -->
        <div class="enhanced-modal-video aspect-video bg-black rounded-xl shadow-2xl overflow-hidden">
          #{if video do
            case video.type do
              :youtube -> "<iframe src='https://www.youtube.com/embed/#{extract_youtube_id(video.url)}?autoplay=1' class='w-full h-full' frameborder='0' allowfullscreen></iframe>"
              :vimeo -> "<iframe src='https://player.vimeo.com/video/#{extract_vimeo_id(video.url)}?autoplay=1' class='w-full h-full' frameborder='0' allowfullscreen></iframe>"
              :direct -> "<video controls autoplay class='w-full h-full'><source src='#{video.url}' type='video/mp4'></video>"
              _ -> "<div class='w-full h-full flex items-center justify-center text-white'>Video unavailable</div>"
            end
          else
            "<div class='w-full h-full flex items-center justify-center text-white'>No video available</div>"
          end}
        </div>
      </div>
    </div>

    <script>
      function openVideoModal() {
        document.getElementById('enhanced-video-modal').classList.remove('hidden');
        document.body.style.overflow = 'hidden';
      }

      function closeVideoModal() {
        document.getElementById('enhanced-video-modal').classList.add('hidden');
        document.body.style.overflow = 'auto';

        // Stop video playback
        const modal = document.getElementById('enhanced-video-modal');
        const iframe = modal.querySelector('iframe');
        const video = modal.querySelector('video');

        if (iframe) {
          iframe.src = iframe.src; // Reset iframe
        }
        if (video) {
          video.pause();
        }
      }

      // Close modal on backdrop click
      document.getElementById('enhanced-video-modal').addEventListener('click', function(e) {
        if (e.target === this) {
          closeVideoModal();
        }
      });

      // Close modal on ESC key
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
          closeVideoModal();
        }
      });
    </script>
    """
  end

  # ============================================================================
  # ENHANCED THEME CONFIGURATION (improved from temp_show.ex)
  # ============================================================================

  defp get_enhanced_hero_theme_config(theme, color_scheme) do
    base_colors = get_enhanced_color_scheme_colors(color_scheme)

    case theme do
      "professional" -> %{
        background_class: "bg-gradient-to-br from-slate-50 via-white to-blue-50",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-600",
        text_body: "text-gray-700",
        primary_button: "bg-#{color_scheme}-600 hover:bg-#{color_scheme}-700 text-white shadow-lg hover:shadow-xl",
        secondary_button: "border-2 border-#{color_scheme}-600 text-#{color_scheme}-600 hover:bg-#{color_scheme}-600 hover:text-white shadow-lg",
        card_background: "bg-white/80 backdrop-blur-sm",
        border_color: "border-gray-200",
        avatar_ring: "ring-#{color_scheme}-500",
        avatar_background: "bg-gradient-to-br from-#{color_scheme}-500 to-#{color_scheme}-600",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-700 hover:shadow-md",
        social_link_hover: "bg-#{color_scheme}-500 text-white shadow-lg",
        prominent_social: "bg-white/90 backdrop-blur-sm border-2 border-gray-200 text-gray-700 shadow-md",
        prominent_social_hover: "border-#{color_scheme}-500 bg-#{color_scheme}-50 shadow-xl",
        contact_link: "text-gray-600",
        contact_link_hover: "text-#{color_scheme}-600",
        contact_item: "text-gray-600",
        accent_color: "bg-#{color_scheme}-500",
        secondary_color: "bg-#{color_scheme}-200"
      }

      "creative" -> %{
        background_class: "bg-gradient-to-br from-purple-50 via-pink-50 to-orange-50",
        text_primary: "text-gray-900",
        text_secondary: "text-purple-700",
        text_muted: "text-purple-600",
        text_body: "text-gray-700",
        primary_button: "bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 text-white shadow-xl hover:shadow-2xl",
        secondary_button: "border-2 border-purple-600 text-purple-600 hover:bg-purple-600 hover:text-white shadow-lg",
        card_background: "bg-white/80 backdrop-blur-sm",
        border_color: "border-purple-200",
        avatar_ring: "ring-purple-500",
        avatar_background: "bg-gradient-to-br from-purple-500 to-pink-500",
        avatar_text: "text-white",
        social_link: "bg-purple-100 text-purple-700 hover:shadow-md",
        social_link_hover: "bg-purple-500 text-white shadow-lg",
        prominent_social: "bg-white/90 backdrop-blur-sm border-2 border-purple-200 text-purple-700 shadow-md",
        prominent_social_hover: "border-purple-500 bg-purple-50 shadow-xl",
        contact_link: "text-purple-600",
        contact_link_hover: "text-purple-700",
        contact_item: "text-purple-600",
        accent_color: "bg-purple-500",
        secondary_color: "bg-pink-300"
      }

      "minimal" -> %{
        background_class: "bg-white",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-500",
        text_body: "text-gray-600",
        primary_button: "bg-gray-900 hover:bg-gray-800 text-white shadow-lg hover:shadow-xl",
        secondary_button: "border-2 border-gray-900 text-gray-900 hover:bg-gray-900 hover:text-white shadow-lg",
        card_background: "bg-gray-50/80 backdrop-blur-sm",
        border_color: "border-gray-200",
        avatar_ring: "ring-gray-400",
        avatar_background: "bg-gray-700",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-600 hover:shadow-md",
        social_link_hover: "bg-gray-900 text-white shadow-lg",
        prominent_social: "bg-white/90 backdrop-blur-sm border-2 border-gray-200 text-gray-600 shadow-md",
        prominent_social_hover: "border-gray-900 bg-gray-50 shadow-xl",
        contact_link: "text-gray-500",
        contact_link_hover: "text-gray-900",
        contact_item: "text-gray-500",
        accent_color: "bg-gray-500",
        secondary_color: "bg-gray-200"
      }

      "modern" -> %{
        background_class: "bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50",
        text_primary: "text-gray-900",
        text_secondary: "text-blue-700",
        text_muted: "text-blue-600",
        text_body: "text-gray-700",
        primary_button: "bg-gradient-to-r from-blue-600 to-indigo-600 hover:from-blue-700 hover:to-indigo-700 text-white shadow-xl hover:shadow-2xl",
        secondary_button: "border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white shadow-lg",
        card_background: "bg-white/80 backdrop-blur-sm",
        border_color: "border-blue-200",
        avatar_ring: "ring-blue-500",
        avatar_background: "bg-gradient-to-br from-blue-500 to-indigo-500",
        avatar_text: "text-white",
        social_link: "bg-blue-100 text-blue-700 hover:shadow-md",
        social_link_hover: "bg-blue-500 text-white shadow-lg",
        prominent_social: "bg-white/90 backdrop-blur-sm border-2 border-blue-200 text-blue-700 shadow-md",
        prominent_social_hover: "border-blue-500 bg-blue-50 shadow-xl",
        contact_link: "text-blue-600",
        contact_link_hover: "text-blue-700",
        contact_item: "text-blue-600",
        accent_color: "bg-blue-500",
        secondary_color: "bg-indigo-200"
      }

      _ -> %{
        background_class: "bg-gradient-to-br from-gray-50 via-white to-slate-50",
        text_primary: "text-gray-900",
        text_secondary: "text-gray-700",
        text_muted: "text-gray-600",
        text_body: "text-gray-700",
        primary_button: "bg-blue-600 hover:bg-blue-700 text-white shadow-lg hover:shadow-xl",
        secondary_button: "border-2 border-blue-600 text-blue-600 hover:bg-blue-600 hover:text-white shadow-lg",
        card_background: "bg-white/80 backdrop-blur-sm",
        border_color: "border-gray-200",
        avatar_ring: "ring-blue-500",
        avatar_background: "bg-blue-500",
        avatar_text: "text-white",
        social_link: "bg-gray-100 text-gray-700 hover:shadow-md",
        social_link_hover: "bg-blue-500 text-white shadow-lg",
        prominent_social: "bg-white/90 backdrop-blur-sm border-2 border-gray-200 text-gray-700 shadow-md",
        prominent_social_hover: "border-blue-500 bg-blue-50 shadow-xl",
        contact_link: "text-gray-600",
        contact_link_hover: "text-blue-600",
        contact_item: "text-gray-600",
        accent_color: "bg-blue-500",
        secondary_color: "bg-blue-200"
      }
    end
  end

  # ============================================================================
  # ENHANCED UTILITY FUNCTIONS (from temp_show.ex)
  # ============================================================================

  defp normalize_section_type(section_type) do
    case section_type do
      "hero" -> :hero
      "intro" -> :intro
      "about" -> :about
      "contact" -> :contact
      atom when is_atom(atom) -> atom
      _ -> :other
    end
  end

  defp detect_video_type(url) when is_binary(url) do
    cond do
      String.contains?(url, "youtube.com") || String.contains?(url, "youtu.be") -> :youtube
      String.contains?(url, "vimeo.com") -> :vimeo
      String.ends_with?(url, [".mp4", ".webm", ".ogg", ".mov", ".avi"]) -> :direct
      true -> :unknown
    end
  end

  defp detect_video_type(_), do: :unknown

  defp extract_youtube_id(url) do
    cond do
      String.contains?(url, "youtu.be/") ->
        url |> String.split("youtu.be/") |> List.last() |> String.split("?") |> List.first()
      String.contains?(url, "watch?v=") ->
        url |> String.split("watch?v=") |> List.last() |> String.split("&") |> List.first()
      true ->
        "invalid"
    end
  end

  defp extract_vimeo_id(url) do
    url
    |> String.split("/")
    |> List.last()
    |> String.split("?")
    |> List.first()
  end

  defp get_enhanced_color_scheme_colors(scheme) do
    case scheme do
      "blue" -> ["#1e40af", "#3b82f6", "#60a5fa"]
      "green" -> ["#065f46", "#059669", "#34d399"]
      "purple" -> ["#581c87", "#7c3aed", "#a78bfa"]
      "red" -> ["#991b1b", "#dc2626", "#f87171"]
      "orange" -> ["#ea580c", "#f97316", "#fb923c"]
      "teal" -> ["#0f766e", "#14b8a6", "#5eead4"]
      _ -> ["#3b82f6", "#60a5fa", "#93c5fd"]
    end
  end

  defp has_contact_info?(contact) do
    contact.email != "" || contact.phone != "" || contact.location != ""
  end

  defp format_platform_name(platform) do
    platform
    |> to_string()
    |> String.capitalize()
    |> case do
      "Github" -> "GitHub"
      "Linkedin" -> "LinkedIn"
      "Youtube" -> "YouTube"
      other -> other
    end
  end

  # Enhanced social icons with better styling
  defp get_enhanced_social_icon(platform) do
    case String.downcase(to_string(platform)) do
      "linkedin" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M16.338 16.338H13.67V12.16c0-.995-.017-2.277-1.387-2.277-1.39 0-1.601 1.086-1.601 2.207v4.248H8.014v-8.59h2.559v1.174h.037c.356-.675 1.227-1.387 2.526-1.387 2.703 0 3.203 1.778 3.203 4.092v4.711zM5.005 6.575a1.548 1.548 0 11-.003-3.096 1.548 1.548 0 01.003 3.096zm-1.337 9.763H6.34v-8.59H3.667v8.59zM17.668 1H2.328C1.595 1 1 1.581 1 2.298v15.403C1 18.418 1.595 19 2.328 19h15.34c.734 0 1.332-.582 1.332-1.299V2.298C19 1.581 18.402 1 17.668 1z" clip-rule="evenodd"></path>
        </svg>
        """

      "github" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"></path>
        </svg>
        """

      "twitter" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.29 18.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0020 3.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.073 4.073 0 01.8 7.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 010 16.407a11.616 11.616 0 006.29 1.84"></path>
        </svg>
        """

      "instagram" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 0C7.284 0 6.944.012 5.877.06 2.246.227.227 2.242.06 5.877.012 6.944 0 7.284 0 10s.012 3.056.06 4.123c.167 3.632 2.182 5.65 5.817 5.817C6.944 19.988 7.284 20 10 20s3.056-.012 4.123-.06c3.629-.167 5.652-2.182 5.817-5.817C19.988 13.056 20 12.716 20 10s-.012-3.056-.06-4.123C19.833 2.245 17.815.227 14.183.06 13.056.012 12.716 0 10 0zm0 1.802c2.67 0 2.987.01 4.042.059 2.71.123 3.975 1.409 4.099 4.099.048 1.054.057 1.37.057 4.04 0 2.672-.01 2.988-.057 4.042-.124 2.687-1.387 3.975-4.1 4.099-1.054.048-1.37.058-4.041.058-2.67 0-2.987-.01-4.04-.058-2.717-.124-3.977-1.416-4.1-4.1-.048-1.054-.058-1.37-.058-4.041 0-2.67.01-2.986.058-4.04.124-2.69 1.387-3.977 4.1-4.1 1.054-.048 1.37-.058 4.04-.058zM10 4.865a5.135 5.135 0 100 10.27 5.135 5.135 0 000-10.27zm0 8.468a3.333 3.333 0 110-6.666 3.333 3.333 0 010 6.666zm5.338-9.87a1.2 1.2 0 100 2.4 1.2 1.2 0 000-2.4z" clip-rule="evenodd"></path>
        </svg>
        """

      "youtube" ->
        """
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path d="M10 0C4.477 0 0 4.484 0 10.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0110 4.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.203 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.942.359.31.678.921.678 1.856 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0020 10.017C20 4.484 15.522 0 10 0z" clip-rule="evenodd"></path>
        </svg>
        """

      "website" ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"></path>
        </svg>
        """

      "email" ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 4.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
        </svg>
        """

      _ ->
        """
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"></path>
        </svg>
        """
    end
  end

  # Enhanced social icons for hero sections (larger, more prominent)
  defp get_enhanced_social_icon_for_hero(platform) do
    case String.downcase(to_string(platform)) do
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
      "youtube" -> """
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>
      """
      "website" -> """
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 01-9 9m9-9a9 9 0 00-9-9m9 9H3m9 9a9 9 0 01-9-9m9 9c1.657 0 3-4.03 3-9s-1.343-9-3-9m0 18c-1.657 0-3-4.03-3-9s1.343-9 3-9m-9 9a9 9 0 019-9"/></svg>
      """
      _ -> """
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1"/></svg>
      """
    end
  end

  # ============================================================================
  # ENHANCED HELPER FUNCTIONS (from temp_show.ex)
  # ============================================================================

  # Enhanced experience calculation
  defp get_experience_years(portfolio) do
    # Try to calculate from sections or use default
    case Date.utc_today().year - 2020 do
      years when years > 0 -> "#{years}+"
      _ -> "5+"
    end
  end

  # Enhanced projects count calculation
  defp get_projects_count(portfolio) do
    sections = portfolio.sections || []
    project_sections = Enum.filter(sections, &(&1.section_type == "projects"))
    case length(project_sections) do
      0 -> "10+"
      count when count > 0 -> "#{count * 5}+"
    end
  end

  # Enhanced CSS animations and utilities
  defp add_enhanced_css_animations() do
    """
    <style>
      /* Enhanced Hero Animations */
      @keyframes float {
        0%, 100% { transform: translateY(0px); }
        50% { transform: translateY(-20px); }
      }

      @keyframes float-delayed {
        0%, 100% { transform: translateY(0px); }
        50% { transform: translateY(-15px); }
      }

      @keyframes float-slow {
        0%, 100% { transform: translateY(0px); }
        50% { transform: translateY(-10px); }
      }

      @keyframes fadeIn {
        0% { opacity: 0; }
        100% { opacity: 1; }
      }

      @keyframes slideInUp {
        0% {
          opacity: 0;
          transform: translateY(30px);
        }
        100% {
          opacity: 1;
          transform: translateY(0);
        }
      }

      @keyframes slideInLeft {
        0% {
          opacity: 0;
          transform: translateX(-30px);
        }
        100% {
          opacity: 1;
          transform: translateX(0);
        }
      }

      @keyframes slideInRight {
        0% {
          opacity: 0;
          transform: translateX(30px);
        }
        100% {
          opacity: 1;
          transform: translateX(0);
        }
      }

      @keyframes scaleIn {
        0% {
          opacity: 0;
          transform: scale(0.9);
        }
        100% {
          opacity: 1;
          transform: scale(1);
        }
      }

      /* Animation Classes */
      .animate-float {
        animation: float 6s ease-in-out infinite;
      }

      .animate-float-delayed {
        animation: float-delayed 8s ease-in-out infinite;
      }

      .animate-float-slow {
        animation: float-slow 10s ease-in-out infinite;
      }

      .animate-fade-in {
        animation: fadeIn 1s ease-out;
      }

      .animate-slide-up {
        animation: slideInUp 0.8s ease-out;
      }

      .animate-slide-left {
        animation: slideInLeft 0.8s ease-out;
      }

      .animate-slide-right {
        animation: slideInRight 0.8s ease-out;
      }

      .animate-scale-in {
        animation: scaleIn 0.6s ease-out;
      }

      /* Enhanced Hero Specific Styles */
      .enhanced-video-hero {
        position: relative;
        overflow: hidden;
      }

      .enhanced-video-hero::before {
        content: '';
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        bottom: 0;
        background: linear-gradient(135deg, rgba(0,0,0,0.1) 0%, rgba(0,0,0,0.3) 100%);
        z-index: 1;
      }

      .enhanced-social-hero {
        background-attachment: fixed;
        background-size: cover;
        background-position: center;
      }

      .enhanced-content-hero {
        background-image: radial-gradient(circle at 25% 25%, rgba(255,255,255,0.1) 0%, transparent 50%),
                          radial-gradient(circle at 75% 75%, rgba(255,255,255,0.05) 0%, transparent 50%);
      }

      .enhanced-minimal-hero {
        background-image: linear-gradient(45deg, rgba(0,0,0,0.02) 25%, transparent 25%),
                          linear-gradient(-45deg, rgba(0,0,0,0.02) 25%, transparent 25%),
                          linear-gradient(45deg, transparent 75%, rgba(0,0,0,0.02) 75%),
                          linear-gradient(-45deg, transparent 75%, rgba(0,0,0,0.02) 75%);
        background-size: 20px 20px;
        background-position: 0 0, 0 10px, 10px -10px, -10px 0px;
      }

      /* Enhanced Video Player */
      .enhanced-video-wrapper {
        position: relative;
        overflow: hidden;
        border-radius: 12px;
        box-shadow: 0 25px 50px rgba(0,0,0,0.25);
        transition: transform 0.3s ease, box-shadow 0.3s ease;
      }

      .enhanced-video-wrapper:hover {
        transform: translateY(-5px);
        box-shadow: 0 35px 70px rgba(0,0,0,0.3);
      }

      /* Enhanced Buttons */
      .enhanced-primary-cta {
        position: relative;
        overflow: hidden;
      }

      .enhanced-primary-cta::before {
        content: '';
        position: absolute;
        top: 0;
        left: -100%;
        width: 100%;
        height: 100%;
        background: linear-gradient(90deg, transparent, rgba(255,255,255,0.2), transparent);
        transition: left 0.5s;
      }

      .enhanced-primary-cta:hover::before {
        left: 100%;
      }

      .enhanced-secondary-cta {
        backdrop-filter: blur(10px);
        background: rgba(255,255,255,0.1);
      }

      .enhanced-video-cta {
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.2);
      }

      .enhanced-minimal-cta {
        position: relative;
        overflow: hidden;
      }

      .enhanced-minimal-cta::after {
        content: '';
        position: absolute;
        top: 50%;
        left: 50%;
        width: 0;
        height: 0;
        background: rgba(255,255,255,0.2);
        border-radius: 50%;
        transform: translate(-50%, -50%);
        transition: width 0.6s, height 0.6s;
      }

      .enhanced-minimal-cta:hover::after {
        width: 300px;
        height: 300px;
      }

      /* Enhanced Social Links */
      .enhanced-social-link {
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255,255,255,0.1);
      }

      .enhanced-prominent-social {
        backdrop-filter: blur(15px);
        border: 2px solid rgba(255,255,255,0.1);
      }

      .enhanced-hero-social a {
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.2);
      }

      /* Enhanced Contact Links */
      .enhanced-contact-link {
        transition: all 0.3s ease;
      }

      .enhanced-contact-link:hover {
        transform: translateY(-2px);
      }

      .enhanced-contact-item {
        transition: all 0.3s ease;
      }

      /* Enhanced Avatar */
      .enhanced-avatar-container img,
      .enhanced-avatar-container div {
        border: 3px solid rgba(255,255,255,0.2);
        box-shadow: 0 20px 40px rgba(0,0,0,0.15);
      }

      /* Enhanced Modal */
      .enhanced-modal-video {
        backdrop-filter: blur(20px);
        border: 1px solid rgba(255,255,255,0.1);
      }

      /* Responsive Enhancements */
      @media (max-width: 768px) {
        .enhanced-video-hero .grid {
          grid-template-columns: 1fr;
          gap: 2rem;
        }

        .enhanced-social-hero h1 {
          font-size: 2.5rem;
        }

        .enhanced-content-hero h1 {
          font-size: 2.25rem;
        }

        .enhanced-minimal-hero h1 {
          font-size: 2rem;
        }

        .enhanced-video-wrapper {
          margin-top: 2rem;
        }

        .enhanced-prominent-social-links .flex {
          grid-template-columns: repeat(2, 1fr);
          display: grid;
        }
      }

      /* Print Styles */
      @media print {
        .enhanced-video-hero,
        .enhanced-social-hero,
        .enhanced-content-hero,
        .enhanced-minimal-hero {
          background: white !important;
          color: black !important;
        }

        .enhanced-video-wrapper,
        .enhanced-modal-video {
          display: none;
        }

        .enhanced-primary-cta,
        .enhanced-secondary-cta,
        .enhanced-video-cta {
          border: 2px solid black;
          background: white;
          color: black;
        }
      }

      /* Dark Mode Support */
      @media (prefers-color-scheme: dark) {
        .enhanced-minimal-hero {
          background: #1a1a1a;
          color: white;
        }

        .enhanced-avatar-container img,
        .enhanced-avatar-container div {
          border-color: rgba(255,255,255,0.3);
        }
      }

      /* Reduced Motion */
      @media (prefers-reduced-motion: reduce) {
        .animate-float,
        .animate-float-delayed,
        .animate-float-slow,
        .animate-fade-in,
        .animate-slide-up,
        .animate-slide-left,
        .animate-slide-right,
        .animate-scale-in {
          animation: none;
        }

        .enhanced-video-wrapper:hover {
          transform: none;
        }

        .enhanced-primary-cta::before,
        .enhanced-minimal-cta::after {
          display: none;
        }
      }
    </style>
    """
  end

  # ============================================================================
  # ENHANCED JAVASCRIPT FUNCTIONALITY (from temp_show.ex)
  # ============================================================================

  defp add_enhanced_javascript() do
    """
    <script>
      // Enhanced Hero Functionality
      document.addEventListener('DOMContentLoaded', function() {
        initializeEnhancedHero();
      });

      function initializeEnhancedHero() {
        // Initialize scroll animations
        initializeScrollAnimations();

        // Initialize intersection observers
        initializeIntersectionObservers();

        // Initialize enhanced interactions
        initializeEnhancedInteractions();

        // Initialize video functionality
        initializeVideoFunctionality();

        // Initialize parallax effects
        initializeParallaxEffects();

        // Initialize performance optimizations
        initializePerformanceOptimizations();
      }

      function initializeScrollAnimations() {
        const heroElements = document.querySelectorAll('.enhanced-video-hero, .enhanced-social-hero, .enhanced-content-hero, .enhanced-minimal-hero');

        heroElements.forEach(hero => {
          const scrollIndicator = hero.querySelector('.animate-bounce');
          if (scrollIndicator) {
            scrollIndicator.addEventListener('click', () => {
              const nextSection = hero.nextElementSibling;
              if (nextSection) {
                nextSection.scrollIntoView({ behavior: 'smooth' });
              }
            });
          }
        });
      }

      function initializeIntersectionObservers() {
        const observerOptions = {
          threshold: 0.1,
          rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              entry.target.classList.add('animate-fade-in');

              // Stagger child animations
              const children = entry.target.querySelectorAll('.enhanced-primary-cta, .enhanced-secondary-cta, .enhanced-social-link, .enhanced-prominent-social');
              children.forEach((child, index) => {
                setTimeout(() => {
                  child.classList.add('animate-slide-up');
                }, index * 100);
              });
            }
          });
        }, observerOptions);

        const heroSections = document.querySelectorAll('.enhanced-video-hero, .enhanced-social-hero, .enhanced-content-hero, .enhanced-minimal-hero');
        heroSections.forEach(section => observer.observe(section));
      }

      function initializeEnhancedInteractions() {
        // Enhanced button hover effects
        const enhancedButtons = document.querySelectorAll('.enhanced-primary-cta, .enhanced-secondary-cta, .enhanced-video-cta');

        enhancedButtons.forEach(button => {
          button.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-2px) scale(1.02)';
          });

          button.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0) scale(1)';
          });

          button.addEventListener('mousedown', function() {
            this.style.transform = 'translateY(0) scale(0.98)';
          });

          button.addEventListener('mouseup', function() {
            this.style.transform = 'translateY(-2px) scale(1.02)';
          });
        });

        // Enhanced social link interactions
        const socialLinks = document.querySelectorAll('.enhanced-social-link, .enhanced-prominent-social, .enhanced-hero-social a');

        socialLinks.forEach(link => {
          link.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-3px) scale(1.1)';
            this.style.boxShadow = '0 10px 25px rgba(0,0,0,0.2)';
          });

          link.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0) scale(1)';
            this.style.boxShadow = '';
          });
        });

        // Enhanced avatar interactions
        const avatars = document.querySelectorAll('.enhanced-avatar-container img, .enhanced-avatar-container div');

        avatars.forEach(avatar => {
          avatar.addEventListener('mouseenter', function() {
            this.style.transform = 'scale(1.05) rotate(2deg)';
          });

          avatar.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1) rotate(0deg)';
          });
        });
      }

      function initializeVideoFunctionality() {
        // Enhanced video modal functionality
        window.openVideoModal = function() {
          const modal = document.getElementById('enhanced-video-modal');
          if (modal) {
            modal.classList.remove('hidden');
            document.body.style.overflow = 'hidden';

            // Focus trap
            const focusableElements = modal.querySelectorAll('button, iframe, video, [tabindex]:not([tabindex="-1"])');
            if (focusableElements.length > 0) {
              focusableElements[0].focus();
            }

            // Analytics
            if (typeof gtag !== 'undefined') {
              gtag('event', 'video_modal_opened', {
                'event_category': 'engagement',
                'event_label': 'hero_video'
              });
            }
          }
        };

        window.closeVideoModal = function() {
          const modal = document.getElementById('enhanced-video-modal');
          if (modal) {
            modal.classList.add('hidden');
            document.body.style.overflow = 'auto';

            // Stop video playback
            const iframe = modal.querySelector('iframe');
            const video = modal.querySelector('video');

            if (iframe) {
              const src = iframe.src;
              iframe.src = '';
              setTimeout(() => iframe.src = src, 100);
            }
            if (video) {
              video.pause();
              video.currentTime = 0;
            }

            // Return focus to trigger button
            const videoButton = document.querySelector('.enhanced-video-cta');
            if (videoButton) {
              videoButton.focus();
            }
          }
        };

        // Video background optimization
        const videoBackgrounds = document.querySelectorAll('video[autoplay]');
        videoBackgrounds.forEach(video => {
          video.addEventListener('canplay', function() {
            this.style.opacity = '1';
          });

          video.addEventListener('error', function() {
            this.style.display = 'none';
          });
        });
      }

      function initializeParallaxEffects() {
        const parallaxElements = document.querySelectorAll('.hero-overlay, .animate-float, .animate-float-delayed, .animate-float-slow');

        function updateParallax() {
          const scrolled = window.pageYOffset;
          const rate = scrolled * -0.5;

          parallaxElements.forEach((element, index) => {
            const speed = (index + 1) * 0.1;
            element.style.transform = `translate3d(0, ${rate * speed}px, 0)`;
          });
        }

        // Throttled scroll event
        let ticking = false;
        function requestTick() {
          if (!ticking) {
            requestAnimationFrame(updateParallax);
            ticking = true;
          }
        }

        window.addEventListener('scroll', () => {
          requestTick();
          ticking = false;
        });
      }

      function initializePerformanceOptimizations() {
        // Lazy load video backgrounds
        const videoBackgrounds = document.querySelectorAll('video[data-src]');
        const videoObserver = new IntersectionObserver((entries) => {
          entries.forEach(entry => {
            if (entry.isIntersecting) {
              const video = entry.target;
              video.src = video.dataset.src;
              video.load();
              videoObserver.unobserve(video);
            }
          });
        });

        videoBackgrounds.forEach(video => videoObserver.observe(video));

        // Preload critical resources
        const criticalImages = document.querySelectorAll('.enhanced-avatar-container img');
        criticalImages.forEach(img => {
          const link = document.createElement('link');
          link.rel = 'preload';
          link.as = 'image';
          link.href = img.src;
          document.head.appendChild(link);
        });

        // Optimize animations for mobile
        if (window.innerWidth <= 768) {
          const heavyAnimations = document.querySelectorAll('.animate-float, .animate-float-delayed, .animate-float-slow');
          heavyAnimations.forEach(element => {
            element.style.animation = 'none';
          });
        }

        // Memory management
        window.addEventListener('beforeunload', () => {
          // Clean up event listeners and observers
          if (window.heroObserver) {
            window.heroObserver.disconnect();
          }
          if (window.videoObserver) {
            window.videoObserver.disconnect();
          }
        });
      }

      // Enhanced keyboard navigation
      document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
          closeVideoModal();
        }

        if (e.key === 'Enter' || e.key === ' ') {
          const focused = document.activeElement;
          if (focused.classList.contains('enhanced-video-cta')) {
            e.preventDefault();
            openVideoModal();
          }
        }
      });

      // Enhanced accessibility
      function enhanceAccessibility() {
        // Add ARIA labels to interactive elements
        const videoButtons = document.querySelectorAll('.enhanced-video-cta');
        videoButtons.forEach(button => {
          button.setAttribute('aria-label', 'Play introduction video');
          button.setAttribute('role', 'button');
        });

        const socialLinks = document.querySelectorAll('.enhanced-social-link, .enhanced-prominent-social, .enhanced-hero-social a');
        socialLinks.forEach(link => {
          const platform = link.title || 'social media';
          link.setAttribute('aria-label', `Visit ${platform} profile`);
        });

        // Add screen reader announcements
        const heroSections = document.querySelectorAll('.enhanced-video-hero, .enhanced-social-hero, .enhanced-content-hero, .enhanced-minimal-hero');
        heroSections.forEach(section => {
          section.setAttribute('role', 'banner');
          section.setAttribute('aria-label', 'Hero section');
        });

        // Enhanced focus indicators
        const focusableElements = document.querySelectorAll('button, a, [tabindex]:not([tabindex="-1"])');
        focusableElements.forEach(element => {
          element.addEventListener('focus', function() {
            this.style.outline = '3px solid #4A90E2';
            this.style.outlineOffset = '2px';
          });

          element.addEventListener('blur', function() {
            this.style.outline = '';
            this.style.outlineOffset = '';
          });
        });
      }

      // Initialize accessibility enhancements
      document.addEventListener('DOMContentLoaded', enhanceAccessibility);

      // Enhanced error handling
      window.addEventListener('error', function(e) {
        console.warn('Enhanced Hero Error:', e.error);

        // Fallback for video errors
        const videos = document.querySelectorAll('video');
        videos.forEach(video => {
          video.addEventListener('error', function() {
            const placeholder = document.createElement('div');
            placeholder.className = 'video-error-placeholder bg-gray-200 flex items-center justify-center text-gray-600';
            placeholder.innerHTML = '<p>Video temporarily unavailable</p>';
            this.parentNode.replaceChild(placeholder, this);
          });
        });
      });

      // Performance monitoring
      if (typeof performance !== 'undefined' && performance.mark) {
        performance.mark('enhanced-hero-start');

        window.addEventListener('load', () => {
          performance.mark('enhanced-hero-end');
          performance.measure('enhanced-hero-duration', 'enhanced-hero-start', 'enhanced-hero-end');

          const measure = performance.getEntriesByName('enhanced-hero-duration')[0];
          if (measure && measure.duration > 3000) {
            console.warn('Enhanced Hero took longer than expected to load:', measure.duration + 'ms');
          }
        });
      }

      // Touch device optimizations
      if ('ontouchstart' in window) {
        // Remove hover effects on touch devices
        const hoverElements = document.querySelectorAll('.enhanced-primary-cta, .enhanced-secondary-cta, .enhanced-social-link');
        hoverElements.forEach(element => {
          element.style.transition = 'transform 0.1s ease';
        });

        // Add touch feedback
        document.addEventListener('touchstart', function(e) {
          if (e.target.matches('.enhanced-primary-cta, .enhanced-secondary-cta, .enhanced-video-cta')) {
            e.target.style.transform = 'scale(0.95)';
          }
        });

        document.addEventListener('touchend', function(e) {
          if (e.target.matches('.enhanced-primary-cta, .enhanced-secondary-cta, .enhanced-video-cta')) {
            setTimeout(() => {
              e.target.style.transform = '';
            }, 100);
          }
        });
      }

      // Export functions for external use
      window.EnhancedHero = {
        openVideoModal: window.openVideoModal,
        closeVideoModal: window.closeVideoModal,
        initializeEnhancedHero: initializeEnhancedHero
      };
    </script>
    """
  end

end
